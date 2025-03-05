---
title: Solution overview for deploying the Strimzi Operator and highly available Kafka cluster on Azure Kubernetes Service (AKS)
description: In this article, we provide an overview of deploying a Kafka cluster on Azure Kubernetes Service (AKS) using the Strimzi Operator.
ms.topic: overview
ms.custom: azure-kubernetes-service
ms.date: 08/15/2024
author: senavar
ms.author: senavar
---

In this article, you deploy the Strimzi Cluster Operator and a highly available Kafka cluster on AKS.

* If you haven't created the required infrastructure for this deployment, follow the steps in [Create infrastructure for deploying a highly available Kafka cluster on AKS][kafka-infrastructure] to get set-up, and then you can return to this article.

## Strimzi Deployment

The Strimzi Cluster Operator is deployed to its own namespace, *Strimzi Operator*, and is configured to watch the namespace, *Kafka*, where the Kafka cluster components are deployed to. To ensure high availability, the operator is deployed with multiple replicas and with leader election enabled to allow for multiple replicas to run concurrently. One replica is chosen as the active leader to manage the deployed resources, while the others remain on standby. If the leader stops functioning or fails, a standby replica is elected to take over and manage the resources. To ensure availability if a zonal outage occurs, three replicas are required, one per availability zone. A pod anti-affinity rule is configured to prevent replicas from being created in the same availability zone. A pod disruption budget is created by the Cluster Operator deployment and ensures that at minimum of one replica is always available. 

### Install Cluster Operator using Helm

A Helm chart is available to deploy the Strimzi Cluster Operator. 

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

Strimzi Drain Cleaner ensures smooth node draining by preventing Kafka partition replicas from becoming under-replicated, maintaining cluster health and reliability. Drainer Cleaner can also be deployed with multiple replicas and pod disruption budgets to ensure availability in case of a zonal outage or cluster upgrade

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

## Kafka Cluster Deployment


The Strimzi Cluster Operator allows us to declaratively define a Kafka Cluster on AKS using custom resource definitions. Beginning with Strimzi 0.46, Kafka clusters no longer require ZooKeeper. Instead, Kafka clusters are configured with KRaft. A KRaft Kafka Cluster consists of Kafka brokers, which handle data storage and processing, and Kafka controllers, which manage metadata using the Raft consensus protocol, eliminating the need for ZooKeeper. Strimzi uses a KafkaNodePool customer resource to create the brokers and controllers that will make up the Kafka cluster. KafkaNodePools must be assigned a specific role: broker, controller, or both. For the desired architecture, two KafkaNodePools are defined for broker and controllers, respectively, with a minimum of three (3) replicas. This setup simplifies the architecture, improves scalability, and enhances fault tolerance. Each broker and controller exists as its own respective set of pods within AKS to ensure performance and can be scaled or changed independently to meet workload requirements. 

<---INSERT Possible Diagram>

The KafkaNodePools are configured with Topology Spread Constraints so that the resulting pods are evenly distributed across availability zones and AKS nodes. This ensures resiliency in case of an availability zone outage or a node outage. A pod affinity rule with a *preferredDuringScheduling* rule is also configured between broker pods and controller pods. This ensures optimal use of node resources within a given availability zone if cluster autoscaler is enabled.  Otherwise, if a new node is added, there could be a scenario that a broker pod runs on an existing node and the controller pod on the scaled node. 

Persistent volume claims are established using the Storage Class generated by Azure Container Storage. Adjustments to the volume sizes should be made to fit your workload needs. The broker KafkaNodePool leverages two volumes, one for messages and the other for metadata. This ensures that the metadata operations do not impact any messaging operations. 

### Deploy Kafka Node Pools

1. Create two (2) Kafka Node Pools, one for brokers and controllers, respectively

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
            size: 2Gi  #adjust to fit workload needs
            kraftMetadata: shared
            deleteClaim: false
            class: acstor-azuredisk-zr
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
            size: 2Gi #adjust to fit workload needs
            deleteClaim: false
            class: acstor-azuredisk-zr
          - id: 1
            type: persistent-claim
            size: 2Gi #adjust to fit workload needs
            kraftMetadata: shared
            deleteClaim: false
            class: acstor-azuredisk-zr
    EOF
    ```

Once the KafkaNodePools are defined, a Kafka Cluster custom resource is created that is associated to the KafkaNodePools. A Kafka Cluster custom resource is where the Cruise Control, jmxPrometheusExporter, listeners, and Kafka specific configurations are declared. 

### Deploy Kafka Cluster

1. Before creating the Kafka cluster, create a ConfigMap for the Kafka cluster's jmxPrometheusExporter configuration to enable metrics to be exposed for Prometheus.

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

1. Deploy the Kafka Cluster definition. This is where Cruise Control and the Entity Operator (Topic and User Operator) are also defined and deployed. 

    ```bash
    kubectl apply -n kafka -f - <<EOF
    ---
    apiVersion: kafka.strimzi.io/v1beta2
    kind: Kafka
    metadata:
      name: kafka-cluster 
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
          - name: int
            port: 9092
            type: internal
            tls: true
        config:
          offsets.topic.replication.factor: 3
          transaction.state.log.replication.factor: 3
          transaction.state.log.min.isr: 2
          default.replication.factor: 3
          min.insync.replicas: 2
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

1. Once deployed, review your AKS cluster to ensure your KafkaNodePools and Kafka Cluster and their correlating pods are deployed and running

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

### Create a Kafka User and Topic 

The Strimzi Entity Operator is a component created by the Strimzi Cluster Operator, designed to simplify the management of Kafka topics and users in Kubernetes environments. It allows you to declaratively create and manage Kafka Topics and Users. 

> [!Note] 
> Creating Kafka Topics and Users declaratively using the Entity Operator is optional. Topics and  can also be created using imperative commands. 
>

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

Strimzi integrates with Prometheus by using the Prometheus JMX Exporter to expose Kafka metrics, which Prometheus then scrapes. This setup allows for monitoring and alerting on Kafka clusters, with pre-configured Grafana dashboards available for visualization.

Additionally, Azure Managed Prometheus can be leveraged to simplify the deployment and management of Prometheus in Azure Kubernetes Service (AKS). It provides a fully managed, scalable environment with high availability and integrates seamlessly with Azure Managed Grafana for comprehensive monitoring. 

### Create Pod Monitor

A PodMonitor is needed to ensure that Prometheus can effectively scrape metrics from the Kafka pods. The Kafka Cluster is should already be configured with the JMX Exporter. Review the steps to deploy a Kafka Cluster if not. 

1. Create the PodMonitor

> [!Note] 
> The pod monitors apiVersion must be set to azmonitoring.coreos.com/v1 when using Azure Managed Prometheus
>
>The pod monitors here also assume that the namespace where the kafka workload is deployed in 'kafka'. Update it accordingly if the workloads are deployed in another namespace.
>

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

Pre-created Grafana dashboards are readily available in the strimzi github repository for metrics exposed by strimzi: [grafana-dashboards-for-strimzi](https://github.com/strimzi/strimzi-kafka-operator/tree/main/examples/metrics/grafana-dashboards) 

Upload the dashboards that best suit your observability requirements. 

### Kafka Exporter

The Kafka Exporter is an open-source tool used to enhance the monitoring of Apache Kafka clusters managed by Strimzi. It extracts additional metrics related to Kafka brokers, consumer groups, consumer lag, and topics, which are not available through the standard JMX metrics. These metrics are then exposed in a format that Prometheus can scrape, providing deeper insights into the performance and health of the Kafka cluster. 

A Helm chart is available to deploy the Kafka Exporter.

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

 [!Note] 
> This Grafana dashboard uses the AngularJS plugin that will be deprecated in future versions of Grafana: [Angular support deprecation](https://grafana.com/docs/grafana/latest/developers/angular_deprecation/). Kafka Exporter metrics will still be available but users may need to create their own dashboards once the deprecation occurs. 
>
    
## Accessing the Kafka Cluster

In a Strimzi Kafka Cluster, a listener is a configuration component that defines how Kafka clients and brokers communicate within the cluster. It supports various listener types like plain, TLS, and SASL, catering to different security needs. To know more about listeners, review the Strimzi documentation for [configuring listeners for client access](https://strimzi.io/docs/operators/latest/configuring.html#type-GenericKafkaListener-reference). 

You can configure listeners to expose Kafka clusters over different Kubernetes service types such as ClusterIP or LoadBalancer. Multiple listeners can be created, with each listener having a unique name. The listener configurations also allows for annotations to be declared and will be passed to the underlying kubernetes service configuration that is created.. 

### Expose with ClusterIP

The Kafka cluster that was deployed in the previous steps creates a ClusterIP service with TLS enabled and with port 9092 exposed. The *internal* listener type instructs the Strimzi Cluster Operator to create a ClusterIP service to expose the Kafka cluster within the AKS cluster.

  ```yaml
  apiVersion: kafka.strimzi.io/v1beta2
  kind: Kafka
  metadata:
    name: kafka-aks-cluster
    annotations:
      strimzi.io/node-pools: enabled
      strimzi.io/kraft: enabled
  spec:
    kafka:
    ...
      listeners:
      - name: int
        port: 9092
        type: internal
        tls: true
    ...
  ```

### Expose via External Load Balancer

When deploying a Strimzi Kafka cluster on AKS using the LoadBalancer listener type, Strimzi creates a Kubernetes Service of type `LoadBalancer` for each Kafka broker. As a result, Azure provisions a new public IP address frontend on the Azure Load Balancer per broker and for the external bootstrap service. It's best practice to use the bootstrap entry created by Strimzi for client connections instead of the public IP of each broker, as this simplifies configuration and ensures better load balancing and failover management. This setup ensures seamless traffic routing across all brokers. To learn more about how the `LoadBalancer` listener type works review the [Strimzi documentation on load balancers](https://strimzi.io/blog/2019/05/13/accessing-kafka-part-4/).

  ```yaml
  apiVersion: kafka.strimzi.io/v1beta2
  kind: Kafka
  metadata:
    name: kafka-aks-cluster
    annotations:
      strimzi.io/node-pools: enabled
      strimzi.io/kraft: enabled
  spec:
    kafka:
    ...
      listeners:
      - name: extelb
        port: 9092
        type: loadbalancer
        tls: false
    ...
  ```

To avoid having each broker publicly accessible via a public IP, you can update individual broker listener configurations and use annotations to use a private load balancer for each broker. After you specify these annotations, they'll be passed by Strimzi to the Kubernetes services, and the load balancers will be created accordingly. Doing so associates a private IP to each broker. 

  ```yaml
  apiVersion: kafka.strimzi.io/v1beta2
  kind: Kafka
  metadata:
    name: kafka-aks-cluster
    annotations:
      strimzi.io/node-pools: enabled
      strimzi.io/kraft: enabled
  spec:
    kafka:
    ...
      listeners:
      - name: extelb
        port: 9092
        type: loadbalancer
        tls: false
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
    ...
  ```
>[!NOTE]
> If brokers are added to the cluster, the listener configuration for each new broker has to be added to `listener.configuration.brokers[]`. Otherwise, a public IP will be associated to each new broker.
>

### Expose via Private Load Balancer and Private Endpoint

To deploy an internal Azure load balancer and configure private endpoints for a Strimzi Kafka cluster, you can use annotations in the the listener configuration. After you specify these annotations, they'll be passed by Strimzi to the Kubernetes services, and the load balancer and private link service (pls) will be created accordingly. 

  ```yaml
  apiVersion: kafka.strimzi.io/v1beta2
  kind: Kafka
  metadata:
    name: kafka-aks-cluster
    annotations:
      strimzi.io/node-pools: enabled
      strimzi.io/kraft: enabled
  spec:
    kafka:
    ...
      listeners:
      - name: extilbpe
        port: 9095
        type: loadbalancer
        tls: true
        configuration:
          bootstrap:
            annotations:
              service.beta.kubernetes.io/azure-load-balancer-internal: "true"
              service.beta.kubernetes.io/azure-pls-create: "true"
              service.beta.kubernetes.io/azure-pls-name: "pls-kafka-ilb"
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
    ...
  ```

This configuration will expose both the bootstrap service and brokers with private IPs. Only the bootstrap service will have a private link service associated to it. If you wish to expose a specific broker via private endpoint, add the `service.beta.kubernetes.io/azure-pls-create: "true"` annotation to the individual broker configuration.

Once the private link service is created, follow the steps for [creating a private endpoint to the Azure Load Balancer Private Link Service](internal-lb?tabs=set-service-annotations#create-a-private-endpoint-to-the-private-link-service).