

# Helm Charts for Kafka + Controller

Kubernetes is a platform for managing containerized applications, enabling automated deployment, scaling, and operations. Helm is a package manager for Kubernetes that simplifies managing Kubernetes applications through Helm charts. This tutorial covers the procedure for setting up a Kafka KRaft environment in KOPS for the CorAct System.

## Table of Contents

1. [Introduction to Kafka KRaft](#introduction-to-kafka-kraft)
2. [Generate Certificates for Cluster Namespace](#generate-certificates-for-cluster-namespace)
3. [Install the Controller](#install-the-controller)
4. [Install the Broker](#install-the-broker)

## 1. Introduction to Kafka KRaft

Kafka KRaft (Kafka Raft Metadata Mode) is a mode of Apache Kafka that replaces the use of ZooKeeper with Kafka’s own consensus protocol, Raft, for metadata management. This streamlines the Kafka architecture by embedding metadata management within Kafka itself, simplifying operations, enhancing scalability, and improving reliability. Kafka KRaft is designed to handle all the metadata operations within a Kafka cluster, including topic configurations, ACLs, and quotas, making Kafka clusters easier to manage and more robust.

## 2. Generate Certificates for Cluster Namespace

### Create Certificate and Keystore

**Preparation:**
- Required access:
  - Venafi self-service access
  - Venafi policy (Policy DN)
- Update the envfile used for certificate and keystore creation located at:
  - `certificate-helper/envfile/*`
- **Expected time: < 10 mins**

#### Environment Variables

```bash
export vedsdk_clientid=MSSITRUWOEL_GB
export vedsdk_policy_dn='Policy\\Automation\\MSSITRUWOEL_GB\\Non-Prod'
export instances=5
export cluster=dev1cls
export project=hsbc-12064156-evlayer1-dev
export gcp_project_env_typ=dev
export region=uk
export cert_owner_contact_email=mayank.mishra@hsbc.co.in
export cert_escalation_contact_email=pravat.kumar.sahoo@hsbc.co.in
export cert_business_contact_email=anand.lal@hsbc.co.in
export namespace=ns-coract-dev-apps
```

#### Secret Environment File

Create a `secret.env` file containing your Venafi credentials:

```bash
export vedsdk_username=XXXX
export vedsdk_password=XXXX
```

#### Commands to Generate Certificates

```bash
cd certificate-helper/
source envfiles/coract-dev.env
source secret.env

# Provide your personal ID and password
export vedsdk_username=login
export vedsdk_password=password

# Generate the server certificate
bash create_cert.sh

# Generate the keystore and truststore
bash create_store.sh

# Look under <cluster>/<namespace>/kafka_secrets for the generated files
cd ..
```

#### Expected Output

```bash
$ ls -l dev1cls/ns-evlayer-preprod-apps/kafka-secrets/
```
### `key.password`
- **Description**: This file contains the password for accessing the private key used in the keystore. It is essential for securing the private key and should be handled with care.
- **Content**: A plaintext password used to unlock the private key.

### `keystore.password`
- **Description**: This file contains the password for accessing the keystore file (`ks`). The keystore holds the private key and certificate(s) used for SSL/TLS communication.
- **Content**: A plaintext password used to unlock the keystore.

### `ks`
- **Description**: This file is the keystore file itself. It stores the private key and the associated public key certificate (and potentially a chain of certificates).
- **Content**: Binary data representing the keystore, which includes the private key and certificate(s).

### `server.key`
- **Description**: This file contains the private key for the server. The private key is used in conjunction with the server certificate (`server.pem`) to establish SSL/TLS connections.
- **Content**: PEM-formatted private key. It should be kept confidential and secure.

### `server.pem`
- **Description**: This file contains the server\' public certificate. The certificate is used in SSL/TLS handshakes to verify the server's identity to clients.
- **Content**: PEM-formatted public certificate. It may include the server's certificate along with the intermediate and root certificates.

### `truststore.password`
- **Description**: This file contains the password for accessing the truststore file. The truststore contains trusted certificates, such as Certificate Authority (CA) certificates, which are used to verify the certificates presented by clients or other servers.
- **Content**: A plaintext password used to unlock the truststore.


## 3. Install the Controller

Copy Certificates for Controller and Namespace

```bash
cd ./charts
cp -R ./certificate-helper/geos-coract-dev/ ./controller/
```

Run the following command to verify the chart:

```bash
helm upgrade --install ctrl charts/controller -f controllervalues-dev.yaml --set clusterid=0123456789012345678901 --debug --namespace ns-coract-dev-apps --dry-run
```

Run the following command to install Kafka Controller 

```bash
helm upgrade --install ctrl charts/controller -f controllervalues-dev.yaml --set clusterid=0123456789012345678901 --debug --namespace ns-coract-dev-apps
```

### Configuration Parameters

In the `./controller/conf` directory, you can adjust extra parameters:

- `jmx-exporter.yaml`: JMX exporter rules
- `log4j.properties`: log4j properties

### Full List of Parameters

Refer to `./controller/values.yaml` for a full list of parameters. The ready-to-use configuration for CorAct can be found in `./controllervalues-dev.yaml`.

Certainly! Here is a detailed description of each Kafka KRaft controller parameter:

### Kafka KRaft Controller Parameters

1. **process.roles=controller**
   - **Description**: Defines the role of the Kafka node. In this case, the node is configured to act as a controller.
   - **Example**: `process.roles=controller`

2. **listener.security.protocol.map=CONTROLLER_INTERNAL:SSL**
   - **Description**: Maps listener names to security protocols. This setup specifies that the internal communication for the controller should use SSL.
   - **Example**: `listener.security.protocol.map=CONTROLLER_INTERNAL:SSL`

3. **controller.listener.names=CONTROLLER_INTERNAL**
   - **Description**: Defines the names of the listeners used by the controller. This property must match the listeners defined in the `listener.security.protocol.map` property.
   - **Example**: `controller.listener.names=CONTROLLER_INTERNAL`

4. **num.network.threads=2**
   - **Description**: Number of threads handling network requests. More threads can improve performance by handling more concurrent connections.
   - **Example**: `num.network.threads=2`

5. **num.io.threads=3**
   - **Description**: Number of threads performing I/O operations. More threads can improve I/O performance.
   - **Example**: `num.io.threads=3`

6. **socket.send.buffer.bytes=102400**
   - **Description**: Size of the socket send buffer in bytes. This buffer size can impact throughput and latency.
   - **Example**: `socket.send.buffer.bytes=102400`

7. **socket.receive.buffer.bytes=102400**
   - **Description**: Size of the socket receive buffer in bytes. This buffer size can impact throughput and latency.
   - **Example**: `socket.receive.buffer.bytes=102400`

8. **socket.request.max.bytes=104857600**
   - **Description**: Maximum size of a request that the controller can handle. This limits the size of messages that can be produced or consumed.
   - **Example**: `socket.request.max.bytes=104857600`

9. **log.dirs=/confluent/controller/data**
   - **Description**: Directory where the controller stores its log data. This should be a persistent storage location.
   - **Example**: `log.dirs=/confluent/controller/data`

10. **num.partitions=1**
    - **Description**: Default number of partitions per topic. This can be overridden at the topic level.
    - **Example**: `num.partitions=1`

11. **num.recovery.threads.per.data.dir=1**
    - **Description**: Number of threads per data directory for log recovery at startup and flushing at shutdown.
    - **Example**: `num.recovery.threads.per.data.dir=1`

12. **offsets.topic.replication.factor=1**
    - **Description**: Replication factor for the offsets topic. This ensures fault tolerance for the offsets topic.
    - **Example**: `offsets.topic.replication.factor=1`

13. **transaction.state.log.replication.factor=1**
    - **Description**: Replication factor for the transaction state log topic. This ensures fault tolerance for transactional state.
    - **Example**: `transaction.state.log.replication.factor=1`

14. **transaction.state.log.min.isr=1**
    - **Description**: Minimum in-sync replicas for the transaction state log topic. This ensures a certain level of availability.
    - **Example**: `transaction.state.log.min.isr=1`

15. **log.flush.interval.messages=10000**
    - **Description**: Number of messages between log flushes to disk. This impacts durability and performance.
    - **Example**: `log.flush.interval.messages=10000`

16. **log.flush.interval.ms=1000**
    - **Description**: Interval in milliseconds between log flushes. This impacts durability and performance.
    - **Example**: `log.flush.interval.ms=1000`

17. **log.retention.hours=168**
    - **Description**: Time in hours to retain log segments before deletion. This impacts the amount of disk space used.
    - **Example**: `log.retention.hours=168`

18. **log.retention.bytes=1073741824**
    - **Description**: Maximum size of log segments in bytes before they are deleted. This limits the disk space used for log retention.
    - **Example**: `log.retention.bytes=1073741824`

19. **log.segment.bytes=1073741824**
    - **Description**: Size of each log segment in bytes. This impacts how often log segments are rolled over and deleted.
    - **Example**: `log.segment.bytes=1073741824`

20. **log.retention.check.interval.ms=300000**
    - **Description**: Interval in milliseconds to check for log retention. This impacts how frequently old log segments are deleted.
    - **Example**: `log.retention.check.interval.ms=300000`

21. **ssl.client.auth=required**
    - **Description**: Whether client authentication is required for SSL connections. This adds an extra layer of security.
    - **Example**: `ssl.client.auth=required`

22. **authorizer.class.name=org.apache.kafka.metadata.authorizer.StandardAuthorizer**
    - **Description**: The class name of the authorizer implementation. This configures access control for the controller.
    - **Example**: `authorizer.class.name=org.apache.kafka.metadata.authorizer.StandardAuthorizer`

By configuring these parameters, you can effectively set up and manage the Kafka KRaft controller to ensure secure and efficient operation.

## 4. Install the Broker

### Copy Certificates for Cluster and Namespace

```bash
cd ./charts
cp -R ./certificate-helper/geos-coract-dev/ ./kafka/
```

Run the following command to install Kafka Broker

```bash
helm upgrade --install kafka charts/kafka -f kafkavalues-dev.yaml --set clusterid=0123456789012345678901 --debug --namespace ns-coract-dev-apps
```

### Configuration Parameters

In the `./kafka/conf` directory, you can adjust extra parameters:

- `jmx-exporter.yaml`: JMX exporter rules
- `log4j.properties`: log4j properties

### Full List of Parameters

Refer to `./kafka/values.yaml` for a full list of parameters. The ready-to-use configuration for CorAct can be found in `./kafkavalues-dev.yaml`.

Certainly! Here is a detailed description of each Kafka KRaft broker parameter:

### Kafka KRaft Broker Parameters

1. **process.roles=broker**
   - **Description**: Defines the role of the Kafka node. In this case, the node is configured to act as a broker.
   - **Example**: `process.roles=broker`

2. **listener.security.protocol.map=BROKER_INTERNAL:SSL,CONTROLLER_INTERNAL:SSL**
   - **Description**: Maps listener names to security protocols. This setup specifies that the internal communication between brokers and controllers should use SSL.
   - **Example**: `listener.security.protocol.map=BROKER_INTERNAL:SSL,CONTROLLER_INTERNAL:SSL`

3. **num.network.threads=3**
   - **Description**: Number of threads handling network requests. More threads can improve performance by handling more concurrent connections.
   - **Example**: `num.network.threads=3`

4. **num.io.threads=2**
   - **Description**: Number of threads performing I/O operations. More threads can improve I/O performance.
   - **Example**: `num.io.threads=2`

5. **socket.send.buffer.bytes=102400**
   - **Description**: Size of the socket send buffer in bytes. This buffer size can impact throughput and latency.
   - **Example**: `socket.send.buffer.bytes=102400`

6. **socket.receive.buffer.bytes=102400**
   - **Description**: Size of the socket receive buffer in bytes. This buffer size can impact throughput and latency.
   - **Example**: `socket.receive.buffer.bytes=102400`

7. **socket.request.max.bytes=104857600**
   - **Description**: Maximum size of a request that the broker can handle. This limits the size of messages that can be produced or consumed.
   - **Example**: `socket.request.max.bytes=104857600`

8. **log.dirs=/confluent/broker/data**
   - **Description**: Directory where the broker stores its log data. This should be a persistent storage location.
   - **Example**: `log.dirs=/confluent/broker/data`

9. **num.partitions=1**
   - **Description**: Default number of partitions per topic. This can be overridden at the topic level.
   - **Example**: `num.partitions=1`

10. **num.recovery.threads.per.data.dir=1**
    - **Description**: Number of threads per data directory for log recovery at startup and flushing at shutdown.
    - **Example**: `num.recovery.threads.per.data.dir=1`

11. **offsets.topic.replication.factor=1**
    - **Description**: Replication factor for the offsets topic. This ensures fault tolerance for the offsets topic.
    - **Example**: `offsets.topic.replication.factor=1`

12. **transaction.state.log.replication.factor=1**
    - **Description**: Replication factor for the transaction state log topic. This ensures fault tolerance for transactional state.
    - **Example**: `transaction.state.log.replication.factor=1`

13. **transaction.state.log.min.isr=1**
    - **Description**: Minimum in-sync replicas for the transaction state log topic. This ensures a certain level of availability.
    - **Example**: `transaction.state.log.min.isr=1`

14. **log.flush.interval.messages=10000**
    - **Description**: Number of messages between log flushes to disk. This impacts durability and performance.
    - **Example**: `log.flush.interval.messages=10000`

15. **log.flush.interval.ms=1000**
    - **Description**: Interval in milliseconds between log flushes. This impacts durability and performance.
    - **Example**: `log.flush.interval.ms=1000`

16. **log.retention.hours=168**
    - **Description**: Time in hours to retain log segments before deletion. This impacts the amount of disk space used.
    - **Example**: `log.retention.hours=168`

17. **log.segment.bytes=1073741824**
    - **Description**: Size of each log segment in bytes. This impacts how often log segments are rolled over and deleted.
    - **Example**: `log.segment.bytes=1073741824`

18. **log.retention.check.interval.ms=300000**
    - **Description**: Interval in milliseconds to check for log retention. This impacts how frequently old log segments are deleted.
    - **Example**: `log.retention.check.interval.ms=300000`

19. **group.initial.rebalance.delay.ms=5000**
    - **Description**: Delay in milliseconds before the initial consumer group rebalance. This can reduce churn when new consumers join.
    - **Example**: `group.initial.rebalance.delay.ms=5000`

20. **unclean.leader.election.enable=false**
    - **Description**: Whether to allow unclean leader election. Disabling this prevents data loss at the expense of availability.
    - **Example**: `unclean.leader.election.enable=false`

21. **min.insync.replicas=1**
    - **Description**: Minimum number of in-sync replicas required to acknowledge a write. This impacts durability and availability.
    - **Example**: `min.insync.replicas=1`

22. **num.replica.fetchers=1**
    - **Description**: Number of threads for fetching data from replicas. More threads can improve replication performance.
    - **Example**: `num.replica.fetchers=1`

23. **auto.create.topics.enable=true**
    - **Description**: Whether to automatically create topics when they are referenced. This can simplify configuration but may lead to unexpected topics.
    - **Example**: `auto.create.topics.enable=true`

24. **default.replication.factor=1**
    - **Description**: Default replication factor for automatically created topics. This can be overridden at the topic level.
    - **Example**: `default.replication.factor=1`

25. **inter.broker.protocol.version=3.5**
    - **Description**: The protocol version used for inter-broker communication. This should match the version of Kafka running.
    - **Example**: `inter.broker.protocol.version=3.5`

26. **log.message.format.version=3.5**
    - **Description**: The message format version used by the broker. This should match the version of Kafka running.
    - **Example**: `log.message.format.version=3.5`

27. **ssl.client.auth=required**
    - **Description**: Whether client authentication is required for SSL connections. This adds an extra layer of security.
    - **Example**: `ssl.client.auth=required`

28. **authorizer.class.name=org.apache.kafka.metadata.authorizer.StandardAuthorizer**
    - **Description**: The class name of the authorizer implementation. This configures access control for the broker.
    - **Example**: `authorizer.class.name=org.apache.kafka.metadata.authorizer.StandardAuthorizer`
```
