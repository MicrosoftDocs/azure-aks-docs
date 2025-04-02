---
title: Deploy Strimzi and Kafka components on Azure Kubernetes Service (AKS)
description: In this article, we provide guidance for deploying the Strimzi Operator and a Kafka cluster on Azure Kubernetes Service (AKS). 
ms.topic: how-to
ms.custom: azure-kubernetes-service
ms.date: 03/31/2025
author: senavar
ms.author: senavar
---

# Configure and deploy Strimzi and Kafka components on Azure Kubernetes Service (AKS)  

In this article, you deploy the Strimzi Cluster Operator and a highly available Kafka cluster on AKS.

> [!NOTE]
> If you haven't created the required infrastructure for this deployment, follow the steps in [Prepare the infrastructure for deploying Kafka on Azure Kubernetes Service (AKS)](./kafka-infrastructure.md) to get set up, and then you can return to this article.

## Strimzi deployment  

The Strimzi Cluster Operator is deployed in its own namespace, `strimzi-operator`, and is configured to watch the `kafka` namespace where Kafka cluster components are deployed. For high availability, the operator uses:

* **Multiple replicas with leader election**: One replica serves as the active leader managing deployed resources, while others remain on standby. If the leader fails, a standby replica takes over.  
* **Zonal distribution**: Three replicas (one per availability zone) provide resilience against zonal outages. Pod anti-affinity rules prevent multiple replicas from being scheduled in the same zone.  
* **Pod Disruption Budget**: Created automatically by the Operator deployment to ensure at least one replica remains available during voluntary disruptions.  

This architecture ensures the Strimzi Cluster Operator remains highly available even during infrastructure maintenance or partial outages.

### Install Strimzi Cluster Operator using Helm  

1. Create the namespaces for the Strimzi Cluster Operator and Kafka cluster using the `kubectl create namespace` command.  

    ```bash  
    kubectl create namespace strimzi-operator  
    kubectl create namespace kafka  
    ```  

1. Using the following script, create a `values.yaml` file to provide specific configurations for the Helm chart: 

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
 
1. Install the Strimzi Cluster Operator using the `helm install` command.  

    ```bash  
    helm install strimzi-cluster-operator oci://quay.io/strimzi-helm/strimzi-kafka-operator \
    --namespace strimzi-operator \
    --values values.yaml
    ```  

1. Verify that the Strimzi Cluster Operator successfully deployed and that all pods are a running state using the `kubectl get` command.  

    ```bash  
    kubectl get pods -n strimzi-operator  
    ```  

    Your output should look similar to the following example output:  

    ```output  
    NAME                                        READY   STATUS    RESTARTS      AGE  
    strimzi-cluster-operator-6f7588bb79-bvfdp   1/1     Running   0             1d22h  
    strimzi-cluster-operator-6f7588bb79-lfcp6   1/1     Running   0             1d22h  
    strimzi-cluster-operator-6f7588bb79-qdlm8   1/1     Running   0             1d22h  
    ```  

### Install Strimzi Drain Cleaner using Helm

Strimzi Drain Cleaner ensures smooth Kubernetes node draining by intercepting drain requests for broker pods. This prevents Kafka partition replicas from becoming under-replicated, maintaining Kafka cluster health and reliability. Drainer Cleaner should also be deployed with multiple replicas and pod disruption budgets to ensure availability in case of a zonal outage or cluster upgrade.  

For high availability, Drain Cleaner can be deployed with multiple replicas across availability zones and configured with pod disruption budgets, ensuring it remains functional during zonal outages or cluster upgrades.

A Helm chart is available for the installation of Strimzi Drain Cleaner:

1. Create the namespace for Drain Cleaner using the `kubectl create namespace` command.  

    ```bash  
    kubectl create namespace strimzi-drain-cleaner  
    ```  

1. Create a `values.yaml` file to override specific configurations for the Helm chart using the following script:  

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

1. Install the Strimzi Drain Cleaner using the `helm install` command.  

    ```bash  
    helm install strimzi-drain-cleaner oci://quay.io/strimzi-helm/strimzi-drain-cleaner \
    --namespace strimzi-drain-cleaner \
    --values values.yaml
    ```  

1. Verify the Strimzi Drain Cleaner successfully deployed and that all pods are a running state using the `kubectl get` command.  

    ```bash  
    kubectl get pods -n strimzi-drain-cleaner  
    ```  

    Your output should look similar to the following example output:  

    ```output  
    NAME                                     READY   STATUS    RESTARTS   AGE  
    strimzi-drain-cleaner-6d694bd55b-dshkp   1/1     Running   0          1d22h  
    strimzi-drain-cleaner-6d694bd55b-l8cbf   1/1     Running   0          1d22h  
    strimzi-drain-cleaner-6d694bd55b-wj6xx   1/1     Running   0          1d22h  
    ```  


## Kafka cluster architecture and considerations  

The Strimzi Cluster Operator enables declarative Kafka deployment on AKS using custom resource definitions. Beginning with Strimzi 0.46, Kafka clusters use [KRaft](https://strimzi.io/blog/2024/03/21/kraft-migration/) directly within Kafka instead of ZooKeeper. 

Strimzi uses the KafkaNodePool custom resource, where each pool is assigned a specific role (broker, controller, or both):

* **Kafka brokers** handle processing and storage of messages.  
* **Kafka controllers** manage Kafka metadata using the Raft consensus protocol.  

For high availability, our target architecture is defined by:

* Separate KafkaNodePools for brokers and controllers, each with three replicas.  
* Topology Spread Constraints that distribute pods across availability zones and nodes.  
* Node affinity rules that optimize resource utilization with specific node pools.  
* Persistent volumes from Azure Container Storage with separate volumes for broker messages and metadata.  

This architecture improves scalability and fault tolerance while allowing brokers and controllers to be independently scaled to meet workload requirements.

### JVM configuration for production Kafka clusters  

Tuning the Java Virtual Machine (JVM) is critical for optimal Kafka broker and controller performance, especially in production environments. Properly configured JVM settings help maximize throughput, minimize latency, and ensure stability under heavy load for each broker.

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

## Deploy Kafka node pools  

In this section, we create two Kafka node pools: one for brokers and one for controllers.  

* Apply the YAML manifest to create the two Kafka node pools using the `kubectl apply` command.  

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
          memory: 4Gi
        limits:
          memory: 6Gi
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

After creating the Kafka node pools, the next step is to define a Kafka cluster custom resource that binds these pools into a functioning Kafka ecosystem. This architecture follows a separation of concerns pattern, where Kafka node pools manage the infrastructure aspects while the Kafka cluster resource handles application-level configurations. 

## Deploy the Kafka cluster  

1. Before creating the Kafka cluster, create a ConfigMap that contains the JMX Prometheus Exporter configuration using the `kubectl apply` command. This ConfigMap defines how Kafka's internal JMX metrics are transformed and exposed in Prometheus format, enabling comprehensive monitoring of your Kafka ecosystem. The patterns defined in this configuration map JMX metric paths to properly formatted Prometheus metrics with appropriate types and labels.  

    ```bash
    kubectl apply -n kafka -f - <<'EOF'
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

1. Deploy the Kafka cluster resource, which connects the previously created node pools into a complete Kafka ecosystem, using the `kubectl apply` command. This custom resource configures several critical components:  

    * **Kafka core configuration**: Defines replication factors, listener settings, and other Kafka-specific parameters.  
    * **Cruise Control**: Provides automated cluster balancing and monitoring capabilities.  
    * **Entity Operator**: Deploys the Topic and User Operators that manage Kafka topics and users declaratively through Kubernetes resources.  
    * **JMX metrics**: Configures metrics exposure using the previously defined ConfigMaps.  

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
          - name: internal
            port: 9092
            type: internal
            tls: true
        config:
          offsets.topic.replication.factor: 3
          transaction.state.log.replication.factor: 3
          transaction.state.log.min.isr: 2
          default.replication.factor: 3
          min.insync.replicas: 2
          log.segment.bytes: 1073741824  
          log.retention.hours: 168  
          log.retention.check.interval.ms: 300000 
        metricsConfig:
          type: jmxPrometheusExporter
          valueFrom:
            configMapKeyRef:
              name: kafka-metrics
              key: kafka-metrics-config.yaml
      cruiseControl:
        metricsConfig:
          type: jmxPrometheusExporter
          valueFrom:
            configMapKeyRef:
              name: cruise-control-metrics
              key: metrics-config.yaml
      entityOperator:
        topicOperator: {}
        userOperator: {}
    EOF
    ```

1. Once deployed, verify your Kafka deployment by checking that all KafkaNodePools, Kafka cluster resources, and their corresponding pods are created and in a running state using the `kubectl get` command.  

    ```bash
    kubectl get pods,kafkanodepool,kafka -n kafka
    ```

    Your output should look similar to the following example output:  

    ```output
    NAME                                                     READY   STATUS    RESTARTS   AGE
    pod/kafka-aks-cluster-broker-0                           1/1     Running   0          1d22h
    pod/kafka-aks-cluster-broker-1                           1/1     Running   0          1d22h
    pod/kafka-aks-cluster-broker-2                           1/1     Running   0          1d22h
    pod/kafka-aks-cluster-controller-3                       1/1     Running   0          1d22h
    pod/kafka-aks-cluster-controller-4                       1/1     Running   0          1d22h
    pod/kafka-aks-cluster-controller-5                       1/1     Running   0          1d22h
    pod/kafka-aks-cluster-cruise-control-844b69848-87rf6     1/1     Running   0          1d22h
    pod/kafka-aks-cluster-entity-operator-6f949f6774-t8wql   2/2     Running   0          1d22h

    NAME                                        DESIRED REPLICAS   ROLES            NODEIDS
    kafkanodepool.kafka.strimzi.io/broker       3                  ["broker"]       [0,1,2]
    kafkanodepool.kafka.strimzi.io/controller   3                  ["controller"]   [3,4,5]

    NAME                                       DESIRED KAFKA REPLICAS   DESIRED ZK REPLICAS   READY   METADATA STATE   WARNINGS
    kafka.kafka.strimzi.io/kafka-aks-cluster 
    ```

## Create a Kafka User and Topic

The Strimzi Entity Operator, deployed with the Kafka cluster custom resource, translates Kubernetes custom resources (`KafkaTopic` and `KafkaUser`) into actual Kafka resources, enabling GitOps workflows and consistent configuration management.  

> [!NOTE] 
> Creating Kafka Topics and Users declaratively using the Entity Operator is optional. You can also create them using traditional Kafka CLI tools or APIs. However, the declarative approach offers benefits such as version control, audit trails, and consistent management across environments.  

1. Create a Kafka Topic with the Topic Operator using the `kubectl apply` command.  

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

1. Verify the Kafka Topic was successfully created using the `kubectl get` command.  

    ```bash  
    kubectl get kafkatopic -n kafka  
    ```  

    Your output should look similar to the following example output:  

    ```output  
    NAME         CLUSTER             PARTITIONS   REPLICATION FACTOR   READY  
    test-topic   kafka-aks-cluster   4            3                    True  
    ```  

For more information, see [using the Topic Operator to manage Kafka topics](https://strimzi.io/docs/operators/latest/deploying#using-the-topic-operator-str).  

1. Create a Kafka User with the User Operator using the `kubectl apply` command.  

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
For more information, see [using the User Operator to manage Kafka users](https://strimzi.io/docs/operators/latest/deploying#assembly-using-the-user-operator-str).

## Next step  

> [!div class="nextstepaction"]  
> [Configure monitoring and networking for a Kafka cluster on AKS using the Strimzi Operator](./kafka-configure.md)  

## Contributors  

*Microsoft maintains this article. The following contributors originally wrote it:*  

* Sergio Navar | Senior Customer Engineer  
* Erin Schaffer | Content Developer 2  
