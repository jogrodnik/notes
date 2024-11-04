
# Kafka Disaster Recovery (DR) Procedure for Region Outage: `india2`

This procedure provides a step-by-step approach for handling a Kafka KRaft cluster disaster recovery (DR) scenario. In this scenario, region `india2` is down due to a technical issue, and we need to reconfigure our Kafka controllers and brokers in `india1` to maintain cluster availability. This procedure includes detailed steps for controller quorum adjustments, partition reassignment, and client redirection.

---

## Prerequisites

- **Access** to Kafka’s management scripts (`kafka-storage.sh`, `kafka-reassign-partitions.sh`, and `kafka-topics.sh`).
- **SSH or Kubernetes Access** to brokers and controllers in `india1`.
- **Persistent Volume Claim (PVC)** setup for data persistence in Kubernetes (to retain `quorum-state` and other metadata).

---

## Step 1: Stop All Controllers in `india1`

Start by stopping any active controllers in `india1`. This ensures that no controllers attempt to form a quorum with the unavailable controllers in `india2`.

```bash
# Stop controllers in `india1`
kubectl exec -it <controller-pod-in-india1> -- /bin/bash -c "kafka-server-stop.sh"
```

> **Note**: Stopping all controllers ensures a clean reconfiguration and prevents stale or inconsistent quorum states.

---

## Step 2: Modify `quorum-state` to Exclude `india2` Controllers

Update the `quorum-state` file on each controller in `india1` to remove references to controllers in `india2`. This change enables `india1` controllers to form a quorum independently.

1. **Access the `quorum-state` file**: Typically found in Kafka’s data directory (e.g., `/var/lib/kafka/data/cluster_metadata-0/quorum-state`).
2. **Edit the file**:
   - Remove all entries related to `india2` controllers.
   - Save the modified file.

```bash
# Inside each `india1` controller
kubectl exec -it <controller-pod-in-india1> -- /bin/bash
nano /var/lib/kafka/data/cluster_metadata-0/quorum-state
# Remove `india2` entries and save the file
exit
```

> **Note**: By removing `india2` references, controllers in `india1` no longer attempt connections to `india2`, allowing standalone quorum formation.

---

## Step 3: Start Controllers in `india1`

After editing `quorum-state`, start the controllers in `india1` to form a quorum without dependency on `india2`.

```bash
kubectl exec -it <controller-pod-in-india1> -- /bin/bash -c "kafka-server-start.sh /path/to/kafka/config/controller.properties"
```

> **Note**: Monitor logs to verify that controllers form a quorum successfully. Any failures here could indicate remaining references to `india2`.

---

## Step 4: Identify Under-Replicated or Offline Partitions

Use Kafka management commands to identify partitions that may be under-replicated or have leaders in `india2`, which is unavailable.

```bash
kubectl exec -it <broker-pod-in-india1> -- /bin/bash -c "kafka-topics.sh --describe --bootstrap-server <india1-broker>:9092 --under-replicated-partitions"
```

> **Note**: Partitions without available leaders appear as offline or under-replicated. Reassigning them ensures continuity for critical topics.

---

## Step 5: Generate and Edit a New Partition Reassignment File

To reassign partitions with leaders in `india2` to `india1` brokers, generate a new partition reassignment plan.

1. **Generate the Reassignment Plan**:
   - Create a JSON file listing the affected topics.
   
   ```bash
   echo '{
       "topics": [
           {"topic": "example_topic_1"},
           {"topic": "example_topic_2"}
       ],
       "version": 1
   }' > topics-to-reassign.json

   kafka-reassign-partitions.sh --bootstrap-server <india1-broker>:9092 --generate --topics-to-move-json-file topics-to-reassign.json > reassign-plan.json
   ```

2. **Edit the JSON File**:
   - Remove references to `india2` brokers and reassign partitions to `india1` brokers.

> **Note**: Ensuring the plan references only `india1` brokers prevents Kafka from attempting to use unavailable `india2` brokers.

---

## Step 6: Execute the Partition Reassignment

Apply the modified partition reassignment plan to transfer partition leadership and replicas to `india1` brokers.

```bash
kubectl exec -it <broker-pod-in-india1> -- /bin/bash -c "kafka-reassign-partitions.sh --bootstrap-server <india1-broker>:9092 --reassignment-json-file reassign-plan.json --execute"
```

> **Note**: This step is critical to ensure that `india1` brokers take over leadership roles for partitions that had leaders in `india2`.

---

## Step 7: Verify Partition Availability

After the reassignment, verify that all critical topics and partitions are available with leaders in `india1`.

```bash
kubectl exec -it <broker-pod-in-india1> -- /bin/bash -c "kafka-topics.sh --describe --bootstrap-server <india1-broker>:9092"
```

> **Note**: Ensuring that all partitions have leaders in `india1` confirms availability for Kafka clients during the `india2` outage.

---

## Step 8: Redirect Client Connections

If clients are configured for multi-region access, update them to connect only to `india1` brokers. Alternatively, set up DNS failover to redirect traffic automatically.

> **Note**: Redirecting client connections to `india1` brokers is essential to avoid connection issues due to unreachable `india2` brokers.

---

## Step 9: Restoring Full Configuration After `india2` Recovery

Once `india2` becomes available again:

1. **Update `quorum-state`** to include `india2` controllers.
2. **Restart `india2` brokers** and reassign partitions to restore the original distribution across both regions.

> **Note**: Gradually reintegrate `india2` to maintain a balanced, high-availability setup without disrupting the current `india1` configuration.

---

## Quick Reference: DR Commands

```bash
# Stop controllers in india1
kubectl exec -it <controller-pod-in-india1> -- /bin/bash -c "kafka-server-stop.sh"

# Start controllers in india1
kubectl exec -it <controller-pod-in-india1> -- /bin/bash -c "kafka-server-start.sh /path/to/kafka/config/controller.properties"

# Check for under-replicated or offline partitions
kubectl exec -it <broker-pod-in-india1> -- /bin/bash -c "kafka-topics.sh --describe --bootstrap-server <india1-broker>:9092 --under-replicated-partitions"

# Generate reassignment plan
kafka-reassign-partitions.sh --bootstrap-server <india1-broker>:9092 --generate --topics-to-move-json-file topics-to-reassign.json > reassign-plan.json

# Execute reassignment
kubectl exec -it <broker-pod-in-india1> -- /bin/bash -c "kafka-reassign-partitions.sh --bootstrap-server <india1-broker>:9092 --reassignment-json-file reassign-plan.json --execute"

# Verify partitions
kubectl exec -it <broker-pod-in-india1> -- /bin/bash -c "kafka-topics.sh --describe --bootstrap-server <india1-broker>:9092"
```

This comprehensive DR procedure enables `india1` to operate independently when `india2` is down, ensuring continued Kafka service availability for all clients.
