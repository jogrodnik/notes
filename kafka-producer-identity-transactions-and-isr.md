# Kafka Producer Identity, Transactions, and ISR

## Introduction

This tutorial explains how the following Kafka concepts relate to one another:

- `transactional.id`
- Producer ID (`producerId` or PID)
- Producer epoch
- Per-partition sequence numbers
- Kafka transactions
- ISR (`In-Sync Replicas`)

The examples assume an Apache Kafka cluster running in **KRaft mode**, without ZooKeeper. KRaft changes how Kafka stores and coordinates cluster metadata, but the producer, idempotence, transaction, and ISR concepts described here remain broker-level Kafka mechanisms.

## 1. Overview

| Concept | Assigned by | Purpose |
|---|---|---|
| `transactional.id` | Application/operator | Stable logical identity of a transactional producer |
| Producer ID | Kafka | Internal identity used by the producer protocol |
| Producer epoch | Kafka | Version of a producer identity; fences obsolete instances |
| Sequence number | Producer protocol | Detects duplicate and out-of-order batches per partition |
| Transaction | Producer and transaction coordinator | Makes writes to multiple partitions atomically visible |
| ISR | Kafka brokers | Identifies replicas sufficiently synchronized with the leader |

The simplified relationship is:

```text
transactional.id
    -> Producer ID
    -> producer epoch
    -> per-partition sequence numbers
    -> records written to partition leaders
    -> replication to ISR
    -> transaction COMMIT or ABORT
```

Each element solves a different problem. Producer identity and sequence numbers protect write correctness; transactions control atomic visibility; ISR protects durability and availability.

## 2. `transactional.id`: the stable logical identity

The application configures `transactional.id`:

```properties
transactional.id=payments-worker-01
```

It should be:

- Stable across restarts of the same logical producer
- Unique among concurrently active producer instances
- Meaningful enough to identify the owning workload

Examples:

```text
payments-prod-eu1-worker-01
payments-prod-eu1-worker-02
orders-prod-instance-01
```

The transactional ID lets Kafka recognize a logical producer after a restart. It also lets Kafka resolve an unfinished transaction left by an earlier producer session.

Do not give two active instances the same transactional ID. If they share it, one instance will fence the other.

## 3. Producer ID: Kafka's internal producer identity

Before a transactional producer begins work, it initializes transactions:

```java
producer.initTransactions();
```

Kafka determines the transaction coordinator for the configured transactional ID. The coordinator supplies internal producer identity information, for example:

```text
transactional.id = payments-worker-01
producerId       = 42817
producerEpoch    = 0
```

The application configures the transactional ID but does **not** assign the Producer ID. Kafka owns and manages the PID.

For an idempotent producer without a transactional ID, Kafka also assigns a Producer ID. However, without a stable `transactional.id`, the identity does not provide the same continuity and recovery semantics across producer sessions.

## 4. Producer epoch: the version of a producer

The producer epoch is a version associated with the producer identity.

The first producer session might use:

```text
producerId=42817
producerEpoch=0
```

After another producer initializes with the same `transactional.id`, Kafka advances the identity to a newer epoch:

```text
producerId=42817
producerEpoch=1
```

The older producer now has a stale epoch. Kafka rejects its later writes or transaction operations. This mechanism is called **producer fencing**.

The old process may receive an exception such as:

```text
ProducerFencedException
```

Fencing prevents a paused, partitioned, or accidentally duplicated producer instance from continuing to write after a replacement instance has taken ownership.

### Restart example

```text
Old instance: transactional.id=payments-worker-01, PID=42817, epoch=0
New instance: transactional.id=payments-worker-01, PID=42817, epoch=1
```

If the old instance attempts a commit with epoch `0`, Kafka rejects it because epoch `1` is now authoritative.

## 5. Sequence numbers and idempotence

Kafka assigns sequence numbers to produced batches for each topic partition. The sequence is tracked independently per partition.

For `orders-0`:

```text
PID=42817 epoch=1 sequence=0
PID=42817 epoch=1 sequence=1
PID=42817 epoch=1 sequence=2
```

For `orders-1`, the sequence starts independently:

```text
PID=42817 epoch=1 sequence=0
PID=42817 epoch=1 sequence=1
```

Suppose Kafka writes sequence `2`, but the acknowledgement is lost. The producer retries the same batch. The partition leader recognizes that the same producer and epoch already wrote that sequence and avoids creating a duplicate.

Conceptually, duplicate detection uses this identity:

```text
Producer ID + producer epoch + topic partition + sequence number
```

Sequence numbers also let the broker detect out-of-order batches. They are part of Kafka's idempotent producer protocol.

## 6. Transactions

A transaction groups records and, optionally, consumed offsets into one atomic operation.

The producer starts a transaction:

```java
producer.beginTransaction();
```

It may then write to several partitions:

```text
orders-0: record A
orders-1: record B
audit-0:  record C
```

Kafka associates the transaction with the producer identity:

```text
transactional.id=payments-worker-01
producerId=42817
producerEpoch=1
```

The producer completes it with either:

```java
producer.commitTransaction();
```

or:

```java
producer.abortTransaction();
```

Kafka's transaction coordinator records transaction state in the internal compacted topic:

```text
__transaction_state
```

The coordinator sends transaction markers to participating partitions. A committed transaction receives commit markers; an aborted transaction receives abort markers.

A consumer configured with:

```properties
isolation.level=read_committed
```

returns committed transactional records and ordinary non-transactional records. It does not return records belonging to aborted transactions.

## 7. How producer identity protects transactions

Producer ID, epoch, and transactional ID work together during recovery:

1. A producer starts with `transactional.id=payments-worker-01`.
2. Kafka associates the transactional ID with a PID and epoch.
3. The producer begins a transaction and writes records.
4. The producer crashes before commit or abort.
5. A replacement starts with the same transactional ID.
6. Kafka advances the epoch and fences the previous producer session.
7. Kafka resolves the unfinished transaction before allowing normal work to continue.
8. The replacement producer begins a new transaction.

Without fencing, the old and new processes could both believe they own the same transactional workload.

## 8. ISR: In-Sync Replicas

ISR is the set of replicas that are sufficiently synchronized with a partition leader.

Example:

```text
Topic partition: orders-0
Leader:          broker-1
Replicas:        broker-1, broker-2, broker-3
ISR:             broker-1, broker-2, broker-3
```

The producer sends a record to the partition leader. Followers replicate the leader's log. With:

```properties
acks=all
min.insync.replicas=2
```

Kafka acknowledges a write only while the partition has enough in-sync replicas to satisfy the configured durability requirement.

If the ISR shrinks to one replica while `min.insync.replicas=2`, a write can fail with an error such as:

```text
NotEnoughReplicasException
```

ISR does not identify a producer and does not detect duplicate records. It protects the replicated availability and durability of the partition log.

## 9. ISR and transaction state

Transaction metadata must also be durable. The `__transaction_state` topic is partitioned and replicated like other Kafka topics.

Common production settings are:

```properties
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2
```

If a `__transaction_state` partition cannot satisfy its minimum ISR, its transaction coordinator may be unable to durably record state transitions. Applications can then experience initialization, commit, abort, coordinator, or timeout errors.

Therefore, transactions depend on ISR at two levels:

1. User-topic partitions must durably store the produced records and transaction markers.
2. `__transaction_state` must durably store coordinator state.

ISR does not decide whether a transaction commits. It provides the replication conditions required to store the records and transaction state safely.

## 10. Complete failure scenario

### Initial session

```text
transactional.id=payments-worker-01
producerId=42817
epoch=0
```

The producer opens a transaction and writes records to `orders-0` and `audit-0`. Those records replicate through each partition's ISR. The producer crashes before committing.

### Replacement session

A new process starts with:

```text
transactional.id=payments-worker-01
```

Kafka identifies the previous producer session, advances the epoch, and fences the earlier instance:

```text
producerId=42817
epoch=1
```

Kafka resolves the previous unfinished transaction. The replacement can then begin new transactional work.

### Old session returns

The old process tries to commit using:

```text
producerId=42817
epoch=0
```

Kafka rejects it because epoch `1` is current. This prevents the obsolete session from changing transaction state.

## 11. KRaft considerations

KRaft replaces ZooKeeper for Kafka cluster metadata and controller quorum management. It does not remove:

- Partition leaders and followers
- ISR
- Group coordinators
- Transaction coordinators
- `__consumer_offsets`
- `__transaction_state`

Normal administration commands should connect to broker listeners through `--bootstrap-server`. They should not normally use the controller listener.

## 12. Inspecting transactions with Bash

Define reusable variables:

```bash
KAFKA_BIN="/opt/kafka/bin"
KAFKA_BOOTSTRAP="broker-1:9093,broker-2:9093,broker-3:9093"
KAFKA_CONFIG="/etc/kafka/admin.properties"
```

List transactions:

```bash
"$KAFKA_BIN/kafka-transactions.sh" \
  --bootstrap-server "$KAFKA_BOOTSTRAP" \
  --command-config "$KAFKA_CONFIG" \
  list
```

Describe a transactional ID:

```bash
"$KAFKA_BIN/kafka-transactions.sh" \
  --bootstrap-server "$KAFKA_BOOTSTRAP" \
  --command-config "$KAFKA_CONFIG" \
  describe \
  --transactional-id payments-worker-01
```

Depending on the Kafka release, the output can include:

- Transactional ID
- Producer ID
- Producer epoch
- Transaction state
- Transaction start time
- Participating partitions

Always check the syntax installed with your Kafka version:

```bash
"$KAFKA_BIN/kafka-transactions.sh" --help
```

## 13. Inspecting ISR with Bash

Describe a user topic:

```bash
"$KAFKA_BIN/kafka-topics.sh" \
  --bootstrap-server "$KAFKA_BOOTSTRAP" \
  --command-config "$KAFKA_CONFIG" \
  --describe \
  --topic orders
```

Example fields:

```text
Leader: 1
Replicas: 1,2,3
Isr: 1,2,3
```

Find under-replicated partitions:

```bash
"$KAFKA_BIN/kafka-topics.sh" \
  --bootstrap-server "$KAFKA_BOOTSTRAP" \
  --command-config "$KAFKA_CONFIG" \
  --describe \
  --under-replicated-partitions
```

Inspect transaction-state replication:

```bash
"$KAFKA_BIN/kafka-topics.sh" \
  --bootstrap-server "$KAFKA_BOOTSTRAP" \
  --command-config "$KAFKA_CONFIG" \
  --describe \
  --topic __transaction_state
```

Do not delete, repartition, or write directly to `__transaction_state`.

## 14. Diagnosing common problems

### `ProducerFencedException`

Likely causes:

- Two active producers use the same `transactional.id`.
- An older producer instance resumed after a replacement advanced the epoch.
- A container or VM identity scheme reused an ID unexpectedly.

Check which application instances own the transactional ID and ensure each concurrent producer has a unique stable ID.

### `OutOfOrderSequenceException`

Kafka observed an unexpected per-partition sequence. Possible causes include an invalid producer state, unsupported custom retry behavior, or serious ordering problems. The affected producer instance should generally be closed and recreated.

### `NotEnoughReplicasException`

The current ISR cannot satisfy `min.insync.replicas`. Check broker availability, replica lag, disk health, networking, and topic replication.

### Transaction commit timeout

Investigate:

- ISR for participating user partitions
- ISR for `__transaction_state`
- Transaction coordinator availability
- `transaction.timeout.ms`
- `transaction.max.timeout.ms`
- Broker and application logs
- Whether the same transactional ID is being fenced repeatedly

## 15. Operational rules

1. Assign a stable `transactional.id` to each logical transactional producer.
2. Ensure concurrently active instances never share the same transactional ID.
3. Never configure Producer ID or epoch manually.
4. Let the Kafka producer client manage sequence numbers and retries.
5. Use `acks=all` with an appropriate `min.insync.replicas` policy.
6. Use at least three replicas and a minimum ISR of two for important production topics when the cluster size permits it.
7. Protect `__transaction_state` with production-grade replication.
8. Monitor under-replicated partitions and long-running transactions.
9. Treat administrative transaction abort as an incident-recovery operation.
10. Never modify Kafka internal-topic records directly.

## 16. Final mental model

Use this model when troubleshooting:

```text
transactional.id
    Stable application identity
            |
            v
Producer ID + epoch
    Current Kafka producer session
            |
            v
Sequence numbers
    Deduplication and ordering per partition
            |
            v
Partition leader and ISR
    Durable replicated storage
            |
            v
Transaction coordinator
    Atomic COMMIT or ABORT
```

In one sentence: **the transactional ID identifies the logical producer, the Producer ID and epoch identify its current Kafka session, sequence numbers make retries idempotent, transactions control atomic visibility, and ISR provides replicated durability for both data and transaction state.**
