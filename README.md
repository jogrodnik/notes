### Instructions for Building Confluent Docker Images

This guide provides the necessary steps to create Docker images for `confluent-community-7.5.1`, ready for deployment on Kubernetes.

### Build and Push Docker Images

Follow these steps to build the base and GKE Docker images and then push them to the Nexus repository:

1. **Build Base Confluent Docker  Images**:
   - Run the following script to build the Docker images:
     ```bash
     ./docker-build.sh
     ```
   - This script will create the Docker images for Confluent Kafka.

2. **Push Images to Nexus Repository**:
   - Once the images are built, push them to the Nexus repository using the following command:
     ```bash
     ./docker-push
     ```
   - This command will upload the built images to the specified Nexus repository, making them available for deployment on Kubernetes.

Ensure you have the necessary permissions and access to the Nexus repository before executing these commands.


### Detailed explanation and comments for each part of the provided Dockerfile:

```dockerfile
# Define a build-time argument for specifying the Java version
ARG JAVA_VERSION

# Set the base image using the specified Java version from a private Nexus repository
FROM nexus3.systems.uk.hsbc:18096/com/hsbc/group/itid/es/mw/java/azuljava-jdk-ubuntu-$JAVA_VERSION

# Define additional build-time arguments
ARG VERSION
ARG owner=aomu
ARG group=common

# Switch to the root user to perform administrative tasks
USER root

# Create a new group and user with specified IDs and names
RUN groupadd -g 40001  ${group}
RUN useradd -l -u 40001 -g ${group} -m ${owner}

# Configure the APT sources to use a specific Nexus repository for package installation
RUN echo '\
deb [trusted=yes] https://FHCnA14F:6hntyTEIqOgZUcZNlawDNvlvjjkhY98C9QTEDPw6qnD3@nexus3.systems.uk.hsbc:8081/nexus/repository/apt-proxy-ubuntu-n3p_q/ubuntu/ focal main universe \n\
deb [trusted=yes] https://FHCnA14F:6hntyTEIqOgZUcZNlawDNvlvjjkhY98C9QTEDPw6qnD3@nexus3.systems.uk.hsbc:8081/nexus/repository/apt-proxy-ubuntu-n3p_q/ubuntu/ focal-updates main universe \n\
deb [trusted=yes] https://FHCnA14F:6hntyTEIqOgZUcZNlawDNvlvjjkhY98C9QTEDPw6qnD3@nexus3.systems.uk.hsbc:8081/nexus/repository/apt-proxy-ubuntu-n3p_q/ubuntu/ focal-security main universe \n\
' > /etc/apt/sources.list

# Update package lists and install various utilities
RUN apt-get update \ 
    && apt-get install -y zip \
    && apt-get install -y dos2unix \
    && apt-get install -y vim \
    && apt-get install -y less \
    && apt-get install -yqq inetutils-ping \
    && apt-get install -y net-tools \
    && apt-get install -y jq \
    && apt-get install -y dnsutils \
    && apt-get install -y netcat \
    && apt-get install -y iperf3 \
    && apt-get install -y sockperf \
    && apt-get install -y iproute2 \
    && apt-get install -y tcpdump \
    && rm -rf /var/lib/apt/lists/*

# Create a symbolic link for 'jq' utility
RUN ln -sf /usr/bin/jq /usr/local/bin/jq

# Copy CA certificates to the container and update the CA certificates
COPY ca/*.crt /usr/local/share/ca-certificates/
RUN /usr/sbin/update-ca-certificates

# Add and extract the Confluent package to the specified directory
ADD artifacts/confluent-community-${VERSION}.tar /apps/confluent/
RUN mkdir -p /apps/confluent/confluent-${VERSION}/logs \
    && ln -sf /apps/confluent/confluent-${VERSION} /apps/confluent/current

# Add Confluent binaries to the PATH environment variable
ENV PATH ${PATH}:/apps/confluent/current/bin

# Create necessary directories for JMX and operations
RUN mkdir -p /apps/confluent/monitor \
    && mkdir -p /apps/confluent/ops \
    && mkdir -p /apps/scripts \
    && mkdir -p /confluent

# Copy the JMX Prometheus Java agent to the monitoring directory
COPY artifacts/jmx_prometheus_javaagent-0.20.0.jar /apps/confluent/monitor
RUN ln -sf /apps/confluent/monitor/jmx_prometheus_javaagent-0.20.0.jar /apps/confluent/monitor/jmx_prometheus_javaagent.jar

# Copy Kubernetes-specific scripts to the operations directory
COPY ./docker-k8s-kraft /apps/confluent/ops

# Set ownership and permissions for the directories and scripts
RUN chown -R ${owner}:${group} /confluent \
    && chown -R ${owner}:${group} /apps \
    && chmod 755 /apps/confluent/ops/docker-k8s-kraft 

# Switch to the specified user for running the application
USER ${owner}

# Set the working directory for the container
WORKDIR /apps/confluent/ops/

# Define the entry point for the container
ENTRYPOINT ["./docker-k8s-kraft"]
```
