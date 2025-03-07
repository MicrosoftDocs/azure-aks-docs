---
title: Deploy and configure Strimzi and Kafka components on Azure Kubernetes Service (AKS)
description: In this article, we provide guidance for deploying the Strimzi Operator and a Kafka cluster on Azure Kubernetes Service (AKS). 
ms.topic: overview
ms.custom: azure-kubernetes-service
ms.date: 03/31/2025
author: senavar
ms.author: senavar
---

In this article, you deploy the Strimzi Cluster Operator and a highly available Kafka cluster on AKS.

* If you haven't created the required infrastructure for this deployment, follow the steps in [Create infrastructure for deploying a highly available Kafka cluster on AKS][kafka-infrastructure] to get set-up, and then you can return to this article.

## Strimzi Deployment

The Strimzi Cluster Operator is deployed in its own namespace, `strimzi-operator`, and configured to watch the `kafka` namespace where Kafka cluster components are deployed. For high availability, the operator uses:

* **Multiple replicas with leader election**: One replica serves as the active leader managing deployed resources, while others remain on standby. If the leader fails, a standby replica takes over.

* **Zonal distribution**: Three replicas (one per availability zone) provide resilience against zonal outages. Pod anti-affinity rules prevent multiple replicas from being scheduled in the same zone.

* **Pod Disruption Budget**: Created automatically by the Operator deployment to ensure at least one replica remains available during voluntary disruptions.

This architecture ensures the Strimzi Cluster Operator remains highly available even during infrastructure maintenance or partial outages.

### Install Cluster Operator using Helm

A Helm chart is available to deploy the Strimzi Cluster Operator

1. Create the namespaces for the Cluster Operator and Kafka cluster

    ```bash
    kubectl create namespace strimzi-operator
    kubectl create namespace kafka
    ```

1. Create a values.yaml file to override specific configurations for the Helm chart

    ```bash
    cat <<EOF > values.yaml
    replicas: 3
    watchNamespaces: 
      - kafka
    leaderElection:
      enabled: true
    podDisruptionBudget:
      enabled: true
    affinity:
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
                - key: name
                  operator: In
                  values:
                    - strimzi-cluster-operator
            topologyKey: topology.kubernetes.io/zone
    EOF
    ```
 
1. Install the Strimzi Cluster Operator using [`helm install`][helm-install]

    ```bash
    helm install strimzi-cluster-operator oci://quay.io/strimzi-helm/strimzi-kafka-operator \
        --namespace strimzi-operator \
        --values values.yaml
    ```

1. Verify the Strimzi Cluster Operator is deployed and all pods are a running state

    ```bash
    kubectl get pods -n strimzi-operator
    ```

    ```output
    NAME                                        READY   STATUS    RESTARTS      AGE
    strimzi-cluster-operator-6f7588bb79-bvfdp   1/1     Running   0             1d22h
    strimzi-cluster-operator-6f7588bb79-lfcp6   1/1     Running   0             1d22h
    strimzi-cluster-operator-6f7588bb79-qdlm8   1/1     Running   0             1d22h
    ```

### Install Strimzi Drain Cleaner using Helm

Strimzi Drain Cleaner ensures smooth kubernetes node draining by intercepting drain requests for broker pods. This prevents Kafka partition replicas from becoming under-replicated, maintaining kafka cluster health and reliability. Drainer Cleaner should also be deployed with multiple replicas and pod disruption budgets to ensure availability in case of a zonal outage or cluster upgrade.

A Helm chart is available for the installation of Strimzi Drain Cleaner:

1. Create the namespaces for the Cluster Operator and Kafka cluster

    ```bash
    kubectl create namespace strimzi-drain-cleaner
    ```

1. Create a values.yaml file to override specific configurations for the Helm chart

    ```bash
    cat <<EOF > values.yaml
    replicaCount: 3
    namespace:
      create: false
    podDisruptionBudget:
      create: true
    affinity:
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
                - key: app
                  operator: In
                  values:
                    - strimzi-drain-cleaner
            topologyKey: topology.kubernetes.io/zone
    EOF
    ```

1. Install the Strimzi Drain Cleaner using [`helm install`][helm-install]

    ```bash
    helm install strimzi-drain-cleaner oci://quay.io/strimzi-helm/strimzi-drain-cleaner \
        --namespace strimzi-drain-cleaner \
        --values values.yaml
    ```

1. Verify the Strimzi Drain Cleaner is deployed and all pods are in a running state

    ```bash
    kubectl get pods -n strimzi-drain-cleaner
    ```

    ```output
    NAME                                     READY   STATUS    RESTARTS   AGE
    strimzi-drain-cleaner-6d694bd55b-dshkp   1/1     Running   0          1d22h
    strimzi-drain-cleaner-6d694bd55b-l8cbf   1/1     Running   0          1d22h
    strimzi-drain-cleaner-6d694bd55b-wj6xx   1/1     Running   0          1d22h
    ```

## Kafka Cluster Architecture and Considerations

The Strimzi Cluster Operator enables declarative Kafka deployment on AKS using custom resource definitions. Starting with Strimzi 0.46, Kafka clusters use KRaft instead of ZooKeeper, with dedicated components:

* **Kafka brokers**: Handle data storage and processing
* **Kafka controllers**: Manage metadata using the Raft consensus protocol

Strimzi implements this architecture using the KafkaNodePool custom resource, where each pool is assigned a specific role (broker, controller, or both). For optimal high availability, the deployment uses:

* Separate KafkaNodePools for brokers and controllers, each with three replicas
* Topology Spread Constraints that distribute pods across availability zones and nodes
* Node affinity rules that optimize resource utilization with specific node pools
* Persistent volumes from Azure Container Storage with separate volumes for broker messages and metadata

This architecture improves scalability and fault tolerance while allowing brokers and controllers to be independently scaled to meet workload requirements.

### JVM Configuration for Production Kafka Clusters

Tuning the Java Virtual Machine (JVM) is critical for optimal Kafka performance, especially in production environments. Properly configured JVM settings help maximize throughput, minimize latency, and ensure stability under heavy load for each broker.

LinkedIn, the creators of Kafka, shared the typical arguments for running Kafka on Java for one of LinkedIn's busiest clusters: [Apache Kafka Java Configuration](https://kafka.apache.org/documentation/#java). We will use this configuration as a baseline for the configuration of the Kafka brokers. Changes can be made to meet your specific workloads requirements.

```yaml
jvmOptions:
  # Sets initial and maximum heap size to 6GB - critical for memory-intensive Kafka operations
  # Equal sizing prevents resizing pauses
  "-Xms": "6g"
  "-Xmx": "6g"
  "-XX":
    # Initial metaspace size (class metadata storage area) at 96MB
    "MetaspaceSize": "96m"
    
    # Enables the Garbage-First (G1) garbage collector, optimized for better predictability and lower pause times
    "UseG1GC": "true"
    
    # Targets maximum GC pause time of 20ms - keeps latency predictable
    "MaxGCPauseMillis": "20"
    
    # Starts concurrent GC cycle when heap is 35% full - balances CPU overhead and frequency
    "InitiatingHeapOccupancyPercent": "35"
    
    # Sets G1 heap region size to 16MB - affects collection efficiency and pause times
    "G1HeapRegionSize": "16M"
    
    # Keeps at least 50% free space after metaspace GC - prevents frequent resizing
    "MinMetaspaceFreeRatio": "50"
    
    # Limits expansion to allow up to 80% free space in metaspace after GC
    "MaxMetaspaceFreeRatio": "80"
    
    # Makes explicit System.gc() calls run concurrently instead of stopping all threads
    "ExplicitGCInvokesConcurrent": "true"
```

## Deploy Kafka Node Pools

1. Create two (2) Kafka Node Pools, one for brokers and controllers, respectively:

    ```bash
    kubectl apply -n kafka -f - <<EOF
    ---
    apiVersion: kafka.strimzi.io/v1beta2
    kind: KafkaNodePool
    metadata:
      name: controller
      labels:
        strimzi.io/cluster: kafka-aks-cluster
    spec:
      replicas: 3
      roles:
        - controller
      resources:
        requests:
          memory: 3Gi
        limits:
          memory: 4Gi
      template:
        pod:
          metadata:
            labels:
              kafkaRole: controller
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                - matchExpressions:
                  - key: app
                    operator: In
                    values:
                    - kafka
            podAffinity:
              preferredDuringSchedulingIgnoredDuringExecution:
                - weight: 100
                  podAffinityTerm:
                    labelSelector:
                      matchLabels:
                        kafkaRole: broker
                    topologyKey: kubernetes.io/hostname
          topologySpreadConstraints:
            - labelSelector:
                matchLabels:
                  kafkaRole: controller
              maxSkew: 1
              topologyKey: topology.kubernetes.io/zone
              whenUnsatisfiable: ScheduleAnyway
            - labelSelector:
                matchLabels:
                  kafkaRole: controller
              maxSkew: 1
              topologyKey: kubernetes.io/hostname
              whenUnsatisfiable: ScheduleAnyway
      storage:
        type: jbod
        volumes:
          - id: 0
            type: persistent-claim
            size: 25Gi
            kraftMetadata: shared
            deleteClaim: false
            class: acstor-azuredisk-zr
      jvmOptions:
        "-Xms": "3g"
        "-Xmx": "3g"
        "-XX":
          "MetaspaceSize": "96m"
          "UseG1GC": "true"
          "MaxGCPauseMillis": "20"
          "InitiatingHeapOccupancyPercent": "35"
          "G1HeapRegionSize": "16M"
          "MinMetaspaceFreeRatio": "50"
          "MaxMetaspaceFreeRatio": "80"
          "ExplicitGCInvokesConcurrent": "true" 
    ---
    apiVersion: kafka.strimzi.io/v1beta2
    kind: KafkaNodePool
    metadata:
      name: broker
      labels:
        strimzi.io/cluster: kafka-aks-cluster
    spec:
      replicas: 3
      roles:
        - broker
      resources:
        requests:
          memory: 8Gi
        limits:
          memory: 10Gi
      template:
        pod:
          metadata:
            labels:
              kafkaRole: broker
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                - matchExpressions:
                  - key: app
                    operator: In
                    values:
                    - kafka
            podAffinity:
              preferredDuringSchedulingIgnoredDuringExecution:
                - weight: 100
                  podAffinityTerm:
                    labelSelector:
                      matchLabels:
                        kafkaRole: controller
                    topologyKey: kubernetes.io/hostname
          topologySpreadConstraints:
            - labelSelector:
                matchLabels:
                  kafkaRole: broker
              maxSkew: 1
              topologyKey: topology.kubernetes.io/zone
              whenUnsatisfiable: ScheduleAnyway
            - labelSelector:
                matchLabels:
                  kafkaRole: broker
              maxSkew: 1
              topologyKey: kubernetes.io/hostname
              whenUnsatisfiable: ScheduleAnyway 
      storage:
        type: jbod
        volumes:
          - id: 0
            type: persistent-claim
            size: 50Gi
            deleteClaim: false
            class: acstor-azuredisk-zr
          - id: 1
            type: persistent-claim
            size: 25Gi
            kraftMetadata: shared
            deleteClaim: false
            class: acstor-azuredisk-zr
      jvmOptions:
        "-Xms": "6g"
        "-Xmx": "6g"
        "-XX":
          "MetaspaceSize": "96m"
          "UseG1GC": "true"
          "MaxGCPauseMillis": "20"
          "InitiatingHeapOccupancyPercent": "35"
          "G1HeapRegionSize": "16M"
          "MinMetaspaceFreeRatio": "50"
          "MaxMetaspaceFreeRatio": "80"
          "ExplicitGCInvokesConcurrent": "true" 
    EOF
    ```

After creating KafkaNodePools, the next step is to define a Kafka Cluster custom resource that binds these pools into a functioning Kafka ecosystem. This architecture follows a separation of concerns pattern, where Kafka Node Pools manage the infrastructure aspects while the Kafka Cluster resource handles application-level configurations. 

## Deploy Kafka Cluster

1. Before creating the Kafka cluster, create a ConfigMap that contains the JMX Prometheus Exporter configuration. This ConfigMap defines how Kafka's internal JMX metrics are transformed and exposed in Prometheus format, enabling comprehensive monitoring of your Kafka ecosystem. The patterns defined in this configuration map JMX metric paths to properly formatted Prometheus metrics with appropriate types and labels:

    ```bash
    kubectl apply -n kafka -f - <<EOF
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: kafka-metrics
      labels:
        app: strimzi
    data:
      kafka-metrics-config.yaml: |
        # See https://github.com/prometheus/jmx_exporter for more info about JMX Prometheus Exporter metrics
        lowercaseOutputName: true
        rules:
        # Special cases and very specific rules
        - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), topic=(.+), partition=(.*)><>Value
          name: kafka_server_$1_$2
          type: GAUGE
          labels:
            clientId: "$3"
            topic: "$4"
            partition: "$5"
        - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), brokerHost=(.+), brokerPort=(.+)><>Value
          name: kafka_server_$1_$2
          type: GAUGE
          labels:
            clientId: "$3"
            broker: "$4:$5"
        - pattern: kafka.server<type=(.+), cipher=(.+), protocol=(.+), listener=(.+), networkProcessor=(.+)><>connections
          name: kafka_server_$1_connections_tls_info
          type: GAUGE
          labels:
            cipher: "$2"
            protocol: "$3"
            listener: "$4"
            networkProcessor: "$5"
        - pattern: kafka.server<type=(.+), clientSoftwareName=(.+), clientSoftwareVersion=(.+), listener=(.+), networkProcessor=(.+)><>connections
          name: kafka_server_$1_connections_software
          type: GAUGE
          labels:
            clientSoftwareName: "$2"
            clientSoftwareVersion: "$3"
            listener: "$4"
            networkProcessor: "$5"
        - pattern: "kafka.server<type=(.+), listener=(.+), networkProcessor=(.+)><>(.+-total):"
          name: kafka_server_$1_$4
          type: COUNTER
          labels:
            listener: "$2"
            networkProcessor: "$3"
        - pattern: "kafka.server<type=(.+), listener=(.+), networkProcessor=(.+)><>(.+):"
          name: kafka_server_$1_$4
          type: GAUGE
          labels:
            listener: "$2"
            networkProcessor: "$3"
        - pattern: kafka.server<type=(.+), listener=(.+), networkProcessor=(.+)><>(.+-total)
          name: kafka_server_$1_$4
          type: COUNTER
          labels:
            listener: "$2"
            networkProcessor: "$3"
        - pattern: kafka.server<type=(.+), listener=(.+), networkProcessor=(.+)><>(.+)
          name: kafka_server_$1_$4
          type: GAUGE
          labels:
            listener: "$2"
            networkProcessor: "$3"
        # Some percent metrics use MeanRate attribute
        # Ex) kafka.server<type=(KafkaRequestHandlerPool), name=(RequestHandlerAvgIdlePercent)><>MeanRate
        - pattern: kafka.(\w+)<type=(.+), name=(.+)Percent\w*><>MeanRate
          name: kafka_$1_$2_$3_percent
          type: GAUGE
        # Generic gauges for percents
        - pattern: kafka.(\w+)<type=(.+), name=(.+)Percent\w*><>Value
          name: kafka_$1_$2_$3_percent
          type: GAUGE
        - pattern: kafka.(\w+)<type=(.+), name=(.+)Percent\w*, (.+)=(.+)><>Value
          name: kafka_$1_$2_$3_percent
          type: GAUGE
          labels:
            "$4": "$5"
        # Generic per-second counters with 0-2 key/value pairs
        - pattern: kafka.(\w+)<type=(.+), name=(.+)PerSec\w*, (.+)=(.+), (.+)=(.+)><>Count
          name: kafka_$1_$2_$3_total
          type: COUNTER
          labels:
            "$4": "$5"
            "$6": "$7"
        - pattern: kafka.(\w+)<type=(.+), name=(.+)PerSec\w*, (.+)=(.+)><>Count
          name: kafka_$1_$2_$3_total
          type: COUNTER
          labels:
            "$4": "$5"
        - pattern: kafka.(\w+)<type=(.+), name=(.+)PerSec\w*><>Count
          name: kafka_$1_$2_$3_total
          type: COUNTER
        # Generic gauges with 0-2 key/value pairs
        - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.+), (.+)=(.+)><>Value
          name: kafka_$1_$2_$3
          type: GAUGE
          labels:
            "$4": "$5"
            "$6": "$7"
        - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.+)><>Value
          name: kafka_$1_$2_$3
          type: GAUGE
          labels:
            "$4": "$5"
        - pattern: kafka.(\w+)<type=(.+), name=(.+)><>Value
          name: kafka_$1_$2_$3
          type: GAUGE
        # Emulate Prometheus 'Summary' metrics for the exported 'Histogram's.
        # Note that these are missing the '_sum' metric!
        - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.+), (.+)=(.+)><>Count
          name: kafka_$1_$2_$3_count
          type: COUNTER
          labels:
            "$4": "$5"
            "$6": "$7"
        - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.*), (.+)=(.+)><>(\d+)thPercentile
          name: kafka_$1_$2_$3
          type: GAUGE
          labels:
            "$4": "$5"
            "$6": "$7"
            quantile: "0.$8"
        - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.+)><>Count
          name: kafka_$1_$2_$3_count
          type: COUNTER
          labels:
            "$4": "$5"
        - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.*)><>(\d+)thPercentile
          name: kafka_$1_$2_$3
          type: GAUGE
          labels:
            "$4": "$5"
            quantile: "0.$6"
        - pattern: kafka.(\w+)<type=(.+), name=(.+)><>Count
          name: kafka_$1_$2_$3_count
          type: COUNTER
        - pattern: kafka.(\w+)<type=(.+), name=(.+)><>(\d+)thPercentile
          name: kafka_$1_$2_$3
          type: GAUGE
          labels:
            quantile: "0.$4"
        # KRaft overall related metrics
        # distinguish between always increasing COUNTER (total and max) and variable GAUGE (all others) metrics
        - pattern: "kafka.server<type=raft-metrics><>(.+-total|.+-max):"
          name: kafka_server_raftmetrics_$1
          type: COUNTER
        - pattern: "kafka.server<type=raft-metrics><>(current-state): (.+)"
          name: kafka_server_raftmetrics_$1
          value: 1
          type: UNTYPED
          labels:
            $1: "$2"
        - pattern: "kafka.server<type=raft-metrics><>(.+):"
          name: kafka_server_raftmetrics_$1
          type: GAUGE
        # KRaft "low level" channels related metrics
        # distinguish between always increasing COUNTER (total and max) and variable GAUGE (all others) metrics
        - pattern: "kafka.server<type=raft-channel-metrics><>(.+-total|.+-max):"
          name: kafka_server_raftchannelmetrics_$1
          type: COUNTER
        - pattern: "kafka.server<type=raft-channel-metrics><>(.+):"
          name: kafka_server_raftchannelmetrics_$1
          type: GAUGE
        # Broker metrics related to fetching metadata topic records in KRaft mode
        - pattern: "kafka.server<type=broker-metadata-metrics><>(.+):"
          name: kafka_server_brokermetadatametrics_$1
          type: GAUGE
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: cruise-control-metrics
      labels:
        app: strimzi
    data:
      metrics-config.yaml: |
        # See https://github.com/prometheus/jmx_exporter for more info about JMX Prometheus Exporter metrics
        lowercaseOutputName: true
        rules:
        - pattern: kafka.cruisecontrol<name=(.+)><>(\w+)
          name: kafka_cruisecontrol_$1_$2
          type: GAUGE
    EOF
    ```

1. Deploy the Kafka Cluster definition, which connects the previously created KafkaNodePools into a complete Kafka ecosystem. This custom resource configures several critical components:

    * **Kafka core configuration**: Defines replication factors, listener settings, and other Kafka-specific parameters
    * **Cruise Control**: Provides automated cluster balancing and monitoring capabilities
    * **Entity Operator**: Deploys the Topic and User Operators that manage Kafka topics and users declaratively through Kubernetes resources
    * **JMX metrics**: Configures metrics exposure using the previously defined ConfigMaps

The Kafka custom resource acts as the central definition that ties all components together into a functioning Kafka cluster.

  ```bash
    
    kubectl apply -n kafka -f - <<EOF
    ---
    apiVersion: kafka.strimzi.io/v1beta2
    kind: Kafka
    metadata:
      name: kafka-aks-cluster
      annotations:
        strimzi.io/node-pools: enabled
        strimzi.io/kraft: enabled
    spec:
      kafka:
        version: 3.9.0
        metadataVersion: 3.9-IV0
        rack:
          topologyKey: topology.kubernetes.io/zone
        template:
          podDisruptionBudget:
            maxUnavailable: 2
        listeners:
          - name: extilbpe
            port: 9092
            type: loadbalancer
            tls: true
            configuration:
              brokers:
                - broker: 0
                  annotations:
                    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
                - broker: 1
                  annotations:
                    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
                - broker: 2
                  annotations:
                    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
        config:
          offsets.topic.replication.factor: 3
          transaction.state.log.replication.factor: 3
          transaction.state.log.min.isr: 2
          default.replication.factor: 3
          min.insync.replicas: 2
          log.segment.bytes: 1073741824  # 1GB
          log.retention.hours: 168  # 7 days
          log.retention.check.interval.ms: 300000 # 5 minutes       
        metricsConfig:
          type: jmxPrometheusExporter
          valueFrom:
            configMapKeyRef:
              name: kafka-metrics
              key: kafka-metrics-config.yml
      cruiseControl:
        metricsConfig:
          type: jmxPrometheusExporter
          valueFrom:
            configMapKeyRef:
              name: cruise-control-metrics
              key: metrics-config.yml
      entityOperator:
        topicOperator: {}
        userOperator: {}
    EOF

  ```

1. Once deployed, verify your Kafka deployment by checking that all KafkaNodePools, Kafka cluster resources, and their corresponding pods are created and in a running state:

    ```bash
    kubectl get pods, kafkanodepool, kafka -n kafka
    ```

    ```output
    NAME                                                     READY   STATUS    RESTARTS   AGE
    pod/kafka-aks-cluster-broker-0                           1/1     Running   0          7d22h
    pod/kafka-aks-cluster-broker-1                           1/1     Running   0          7d22h
    pod/kafka-aks-cluster-broker-2                           1/1     Running   0          7d22h
    pod/kafka-aks-cluster-controller-3                       1/1     Running   0          7d22h
    pod/kafka-aks-cluster-controller-4                       1/1     Running   0          7d22h
    pod/kafka-aks-cluster-controller-5                       1/1     Running   0          7d22h
    pod/kafka-aks-cluster-cruise-control-844b69848-87rf6     1/1     Running   0          7d22h
    pod/kafka-aks-cluster-entity-operator-6f949f6774-t8wql   2/2     Running   0          7d22h

    NAME                                        DESIRED REPLICAS   ROLES            NODEIDS
    kafkanodepool.kafka.strimzi.io/broker       3                  ["broker"]       [0,1,2]
    kafkanodepool.kafka.strimzi.io/controller   3                  ["controller"]   [3,4,5]

    NAME                                       DESIRED KAFKA REPLICAS   DESIRED ZK REPLICAS   READY   METADATA STATE   WARNINGS
    kafka.kafka.strimzi.io/kafka-aks-cluster 
    ```

## Create a Kafka User and Topic

The Strimzi Entity Operator extends Kubernetes' declarative resource management to Kafka topics and users. This component, deployed automatically by the Strimzi Cluster Operator, translates Kubernetes custom resources (`KafkaTopic` and `KafkaUser`) into actual Kafka resources, enabling GitOps workflows and consistent configuration management.

> [!NOTE] 
> Creating Kafka Topics and Users declaratively using the Entity Operator is optional. Topics and users can also be created using traditional Kafka CLI tools or APIs. However, the declarative approach offers benefits such as version control, audit trails, and consistent management across environments.

1. Create a Kafka Topic using the Topic Operator:

    ```bash
    kubectl apply -n kafka -f - << EOF
    apiVersion: kafka.strimzi.io/v1beta2
    kind: KafkaTopic
    metadata:
      name: test-topic
      labels:
        strimzi.io/cluster: kafka-aks-cluster 
    spec:
      replicas: 3
      partitions: 4
      config:
        retention.ms: 7200000
        segment.bytes: 1073741824
    EOF
    ```

1. Review that the Kafka Topic was created

    ```bash
    kubectl get kafkatopic -n kafka
    ```

    ```output
    NAME         CLUSTER             PARTITIONS   REPLICATION FACTOR   READY
    test-topic   kafka-aks-cluster   4            3                    True
    ```

1. Create a Kafka User using the User Operator

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: kafka.strimzi.io/v1beta2
    kind: KafkaUser
    metadata:
      name: test-user
      labels:
        strimzi.io/cluster: kafka-aks-cluster
    spec:
      authentication:
        type: tls
      authorization:
        type: simple
        acls:
          - resource:
              type: topic
              name: test-topic
              patternType: literal
            operations:
              - Describe
              - Read
            host: "*"
          - resource:
              type: group
              name: test-group
              patternType: literal
            operations:
              - Read
            host: "*"
          - resource:
              type: topic
              name: test-topic
              patternType: literal
            operations:
              - Create
              - Describe
              - Write
            host: "*"
    EOF
    ```

## Configure Kafka Cluster Monitoring with Azure Managed Prometheus and Grafana

Comprehensive monitoring is critical for maintaining reliable Kafka clusters. Strimzi implements monitoring by exposing JMX metrics through Prometheus JMX Exporter, which transforms Kafka's internal performance data into a format that Prometheus can collect and analyze. This monitoring pipeline enables real-time visibility into:

* Broker health and performance metrics
* Producer and consumer throughput
* Partition leadership distribution
* Replication lag and potential data loss risks
* Resource utilization patterns

Azure Managed Prometheus offers significant advantages for AKS-hosted Kafka clusters by providing a fully managed, scalable monitoring backend without the operational overhead of managing your own Prometheus instances. When paired with Azure Managed Grafana, you gain access to comprehensive visualization capabilities with pre-built dashboards specifically designed for Kafka monitoring.

### Create Pod Monitor

PodMonitors are Kubernetes custom resources that instruct Prometheus on which pods to collect metrics from and how to collect them. For Kafka monitoring, you'll need to define PodMonitors that target various Strimzi components.

Before proceeding, ensure your Kafka Cluster has been deployed with JMX Exporter configuration as described in the earlier sections. Without this configuration, metrics will not be available for collection.

1. Create the PodMonitor resources:

> [!NOTE] 
> When using Azure Managed Prometheus:
> * The PodMonitor apiVersion must be `azmonitoring.coreos.com/v1` instead of the standard `monitoring.coreos.com/v1`
> * The namespace selector in the examples below assumes your Kafka workloads are deployed in the `kafka` namespace - modify accordingly if you've used a different namespace

  ```bash

    kubectl apply -f - <<EOF
    ---
    apiVersion: azmonitoring.coreos.com/v1
    kind: PodMonitor
    metadata:
      name: azmon-cluster-operator-metrics
      labels:
        app: strimzi
    spec:
      selector:
        matchLabels:
          strimzi.io/kind: cluster-operator
      namespaceSelector:
        matchNames:
          - kafka
      podMetricsEndpoints:
      - path: /metrics
        port: http
    ---
    apiVersion: azmonitoring.coreos.com/v1
    kind: PodMonitor
    metadata:
      name: azmon-entity-operator-metrics
      labels:
        app: strimzi
    spec:
      selector:
        matchLabels:
          app.kubernetes.io/name: entity-operator
      namespaceSelector:
        matchNames:
          - kafka
      podMetricsEndpoints:
      - path: /metrics
        port: healthcheck
    ---
    apiVersion: azmonitoring.coreos.com/v1
    kind: PodMonitor
    metadata:
      name: azmon-bridge-metrics
      labels:
        app: strimzi
    spec:
      selector:
        matchLabels:
          strimzi.io/kind: KafkaBridge
      namespaceSelector:
        matchNames:
          - kafka
      podMetricsEndpoints:
      - path: /metrics
        port: rest-api
    ---
    apiVersion: azmonitoring.coreos.com/v1
    kind: PodMonitor
    metadata:
      name: azmon-kafka-resources-metrics
      labels:
        app: strimzi
    spec:
      selector:
        matchExpressions:
          - key: "strimzi.io/kind"
            operator: In
            values: ["Kafka", "KafkaConnect", "KafkaMirrorMaker", "KafkaMirrorMaker2"]
      namespaceSelector:
        matchNames:
          - kafka
      podMetricsEndpoints:
      - path: /metrics
        port: tcp-prometheus
        relabelings:
        - separator: ;
          regex: __meta_kubernetes_pod_label_(strimzi_io_.+)
          replacement: $1
          action: labelmap
        - sourceLabels: [__meta_kubernetes_namespace]
          separator: ;
          regex: (.*)
          targetLabel: namespace
          replacement: $1
          action: replace
        - sourceLabels: [__meta_kubernetes_pod_name]
          separator: ;
          regex: (.*)
          targetLabel: kubernetes_pod_name
          replacement: $1
          action: replace
        - sourceLabels: [__meta_kubernetes_pod_node_name]
          separator: ;
          regex: (.*)
          targetLabel: node_name
          replacement: $1
          action: replace
        - sourceLabels: [__meta_kubernetes_pod_host_ip]
          separator: ;
          regex: (.*)
          targetLabel: node_ip
          replacement: $1
          action: replace
    EOF
  ```

### Upload Grafana Dashboards

Strimzi provides ready-to-use Grafana dashboards designed specifically for monitoring Kafka clusters in the [strimzi/strimzi-kafka-operator](https://github.com/strimzi/strimzi-kafka-operator/tree/main/examples/metrics/grafana-dashboards) GitHub repository. These dashboards visualize the metrics exposed by the JMX Prometheus Exporter configured earlier.

To implement Kafka monitoring with Grafana:

1. Select dashboards based on your specific monitoring needs
1. Download the JSON dashboard files from the repository
1. Import them into your Azure Managed Grafana instance through the Grafana UI (+ > Import)

### Kafka Exporter

While the JMX Prometheus Exporter provides internal Kafka metrics, the Kafka Exporter complements this by focusing specifically on consumer lag monitoring and topic-level insights. This exporter:

* Tracks consumer group offsets and calculates lag metrics
* Monitors topic status including under-replicated partitions
* Provides metrics for topic message counts and sizes

These additional metrics are critical for production environments where monitoring consumer performance and ensuring data processing SLAs are essential.

A Helm chart is available to deploy the Kafka Exporter alongside your existing monitoring pipeline.

1. Create a namespace to deploy the Kafka Exporter or use an existing namespace

    ```bash
    kubectl create namespace azmon-kafka-exporter
    ```
    
1. Add the *prometheus-community* Helm repository using [`helm repo add`][helm-repo-add]

    ```bash
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    ```
1. Create a values.yaml file to override specific configurations for the Helm chart

    ```bash
    cat <<EOF > values.yaml
    kafkaServer:
      - <kafka-bootstrap-fqdn-or-privateip>:9092 #additional kafka clusters can be added to the list
    prometheus:
      serviceMonitor:
        namespace: azmon-kafka-exporter #ensure namespace is the same as in step 1
        enabled: true
        apiVersion: azmonitoring.coreos.com/v1
    EOF
    ```

1. Install the Strimzi Cluster Operator using [`helm install`][helm-install]

    ```bash
    helm install azmon-kafka-exporter prometheus-community/prometheus-kafka-exporter \
         --version 2.11.0 \
         --namespace azmon-kafka-exporter \
         --values values.yaml
    ```

1. Upload the [Kafka Exporter Dashboard](https://grafana.com/grafana/dashboards/7589-kafka-exporter-overview/) to Grafana

 [!NOTE]
> This Grafana dashboard uses the AngularJS plugin that will be deprecated in future versions of Grafana: [Angular support deprecation](https://grafana.com/docs/grafana/latest/developers/angular_deprecation/). Kafka Exporter metrics will still be available but users may need to create their own dashboards once the deprecation occurs.
>

## Accessing the Kafka Cluster

Strimzi offers flexible options for exposing your Kafka cluster to clients through *listeners*. Each listener defines how clients connect to your Kafka brokers with specific protocols, authentication methods, and network exposure patterns.

A listener configuration defines:

* Which port Kafka accepts connections on
* The security protocol (Plain, TLS, SASL)
* How the connection endpoint is exposed (Kubernetes service type)

Kafka uses a two-phase connection process that influences how you should configure networking. When configuring listeners for your Strimzi Kafka deployment on AKS, it's essential to understand this process:

1. **Phase 1**: Client connects to bootstrap service, which then connects to any of the brokers to retrieve metadata. The metadata contains the information about the topics, their partitions and brokers which host these partitions.
1. **Phase 2**: Client then establishes a brand new connection directly to an individual broker using the advertised address it obtained from the metadata.

This means your network architecture must account for both the bootstrap service and individual broker connectivity.

 For comprehensive details, see the [Strimzi documentation on configuring client access](https://strimzi.io/blog/2019/04/17/accessing-kafka-part-1/).

### Option 1: Internal Cluster Access (ClusterIP)

For applications running within the same Kubernetes cluster as the Kafka cluster, expose Kafka via ClusterIP:

  ```yaml
  listeners:
    - name: internal
      port: 9092
      type: internal
      tls: true
  ```

This creates a ClusterIP for the bootstrap service and brokers accessible only within the Kubernetes network.

### Option 2: External Access via Public Load Balancer

For external clients, the `loadbalancer` listener type creates an Azure Load Balancer configuration with public IP addresses:

  ```yaml
  listeners:
    - name: external
      port: 9092
      type: loadbalancer
      tls: false
  ```

When using this configuration:

* A Kubernetes LoadBalancer service is created for each broker and the bootstrap service
* Azure provisions public IP addresses for each service
* Clients should connect using the bootstrap service address for initial requests

### Option 3: External Access via Private Load Balancer

If you wish to access the Kafka cluster outside of the AKS cluster but within an Azure Virtual network, you can expose the bootstrap service and brokers through an internal load balancer with private IP addresses:

  ```yaml
  listeners:
    - name: private-lb
      port: 9094
      type: loadbalancer
      tls: false
      configuration: 
        bootstrap:
          annotations:
            service.beta.kubernetes.io/azure-load-balancer-internal: "true"
        brokers:
          - broker: 0
            annotations:
              service.beta.kubernetes.io/azure-load-balancer-internal: "true"
          - broker: 1
            annotations:
              service.beta.kubernetes.io/azure-load-balancer-internal: "true"
          - broker: 2
            annotations:
              service.beta.kubernetes.io/azure-load-balancer-internal: "true"
  ```

> [!IMPORTANT]
> When adding new brokers to your cluster, you must update the listener configuration with corresponding annotations for each new broker. Otherwise, those brokers will be exposed with public IP addresses.

### Option 4: External Access via Private Link Service

For more secure internal networking or accessing across non-peered Azure virtual networks, you can expose your Kafka cluster through Azure Private Link Services:

  ```yaml
  listeners:
    - name: private-link
      port: 9095
      type: loadbalancer
      tls: true
      configuration:
        bootstrap:
          annotations:
            service.beta.kubernetes.io/azure-load-balancer-internal: "true"
            service.beta.kubernetes.io/azure-pls-create: "true"
            service.beta.kubernetes.io/azure-pls-name: "pls-kafka-bootstrap" 
        brokers:
          - broker: 0
            advertisedHost: kafka-broker-0.<privatedomain>.com
            annotations:
              service.beta.kubernetes.io/azure-load-balancer-internal: "true"
              service.beta.kubernetes.io/azure-pls-create: "true"
              service.beta.kubernetes.io/azure-pls-name: "pls-kafka-broker-0"
          - broker: 1
            advertisedHost: kafka-broker-1.<privatedomain>.com   
            annotations:
              service.beta.kubernetes.io/azure-load-balancer-internal: "true"
              service.beta.kubernetes.io/azure-pls-create: "true"
              service.beta.kubernetes.io/azure-pls-name: "pls-kafka-broker-1"
          - broker: 2
            advertisedHost: kafka-broker-2.<privatedomain>.com
            annotations:
              service.beta.kubernetes.io/azure-load-balancer-internal: "true"
              service.beta.kubernetes.io/azure-pls-create: "true"
              service.beta.kubernetes.io/azure-pls-name: "pls-kafka-broker-2"
  ```

This configuration:

* Creates internal load balancer services with private IPs for all components
* Establishes a Private Link Service for the bootstrap service and the individual brokers, respectively
* Enables connection via Private Endpoints from other virtual networks
* Configures the `advertisedHost`. This is required to ensure Kafka advertises the private DNS entry of the private endpoint backing each broker. It also adds it to the broker certificate so that it can be used for TLS hostname verification

> [!IMPORTANT]
> When adding new brokers to your cluster, you must update the listener configuration with corresponding annotations for each new broker. Otherwise, those brokers will be exposed with public IP addresses.
> 
> The `service.beta.kubernetes.io/azure-pls-name:` can be changed to any name you decide

After deploying this configuration, follow the steps for [creating a private endpoint to the Azure Load Balancer Private Link Service.](internal-lb?tabs=set-service-annotations#create-a-private-endpoint-to-the-private-link-service)