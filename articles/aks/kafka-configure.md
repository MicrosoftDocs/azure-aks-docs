---
title: Configure monitoring and networking for a Kafka cluster on AKS using Strimzi  
description: In this article, we provide guidance for configuring monitoring and networking for a Kafka cluster on Azure Kubernetes Service (AKS) deployed using Strimzi. 
ms.topic: how-to
ms.custom: azure-kubernetes-service
ms.date: 03/31/2025
author: senavar
ms.author: senavar
---

# Configure monitoring and networking for a Kafka cluster on Azure Kubernetes Service (AKS)  

In this article, we configure monitoring and networking for a Kafka cluster on Azure Kubernetes Service (AKS).  

## Monitoring with Azure Managed Prometheus and Grafana  

Strimzi implements monitoring by exposing JMX metrics through Prometheus JMX Exporter, which transforms Kafka's internal performance data into a format that Prometheus can collect and analyze. This monitoring pipeline enables real-time visibility into:  

* Broker health and performance metrics  
* Producer and consumer throughput  
* Partition leadership distribution  
* Replication lag and potential data loss risks  
* Resource utilization patterns  

Azure Managed Prometheus provides a fully managed, scalable monitoring backend without the operational overhead of managing your own Prometheus instances. When paired with Azure Managed Grafana, you gain access to comprehensive visualization capabilities with pre-built dashboards specifically designed for Kafka monitoring.

### Create PodMonitor  

PodMonitors are Kubernetes custom resources that instruct Prometheus on which pods to collect metrics from and how to collect them. For Kafka monitoring, you need to define PodMonitors that target various Strimzi components.  

Before proceeding, ensure your Kafka cluster was deployed with the [JMX Exporter configuration](./kafka-deploy.md#deploy-the-kafka-cluster). Without this configuration, metrics won't be available for collection.  

1. Create the PodMonitor resources using the `kubectl apply` command.  

    > [!NOTE] 
    > When using Azure Managed Prometheus:  
    >  
    > * The PodMonitor apiVersion must be `azmonitoring.coreos.com/v1` instead of the standard `monitoring.coreos.com/v1`.  
    > * The namespace selector in the following examples assumes your Kafka workloads are deployed in the `kafka` namespace. Modify accordingly if using a different namespace.  
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

### Upload Grafana dashboards for Kafka monitoring

Strimzi provides ready-to-use Grafana dashboards designed specifically for monitoring Kafka clusters in the [strimzi/strimzi-kafka-operator GitHub repository](https://github.com/strimzi/strimzi-kafka-operator/tree/main/examples/metrics/grafana-dashboards). These dashboards visualize the metrics exposed by the JMX Prometheus Exporter configured earlier.  

To implement Kafka monitoring with Grafana:  

1. Select dashboards from the GitHub repository based on your specific monitoring needs.  
1. Download the JSON dashboard files from the repository.  
1. [Import the dashboards](/azure/managed-grafana/how-to-create-dashboard?tabs=azure-portal#import-a-grafana-dashboard) into your Azure Managed Grafana instance through the Grafana UI.  

### Configure Kafka Exporter to enable enhanced Prometheus metrics 

While the JMX Prometheus Exporter provides internal Kafka metrics, the Kafka Exporter complements this by focusing specifically on consumer lag monitoring and topic-level insights. This exporter:  

* Tracks consumer group offsets and calculates lag metrics.  
* Monitors topic status including under-replicated partitions.  
* Provides metrics for topic message counts and sizes.  

These additional metrics can be critical for production environments where monitoring consumer performance and meeting data processing SLAs are essential.  

A Helm chart is available to deploy the Kafka Exporter alongside your existing monitoring pipeline.

1. Create a namespace to deploy the Kafka Exporter using the `kubectl create namespace` command. You can also use an existing namespace if you prefer.  

    ```bash  
    kubectl create namespace azmon-kafka-exporter  
    ```  
    
1. Add and update the *prometheus-community* Helm repository using the `helm repo add` and `helm repo update` commands.  

    ```bash  
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts  
    helm repo update  
    ```  

1. Create a `values.yaml` file to override specific configurations for the Helm chart. The kafka bootstrap endpoint must be updated before running the script:  

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

1. Install the Strimzi Cluster Operator using the `helm install` command.  

    ```bash  
    helm install azmon-kafka-exporter prometheus-community/prometheus-kafka-exporter \
    --version 2.11.0 \
    --namespace azmon-kafka-exporter \
    --values values.yaml
    ```  

1. Upload the [Kafka Exporter Dashboard](https://grafana.com/grafana/dashboards/7589-kafka-exporter-overview/) to Grafana.  

> [!NOTE]  
> This Grafana dashboard uses the AngularJS plugin that will be deprecated in future versions of Grafana. For more information, see [Angular support deprecation](https://grafana.com/docs/grafana/latest/developers/angular_deprecation/). Kafka Exporter metrics will still be available, but you might need to create your own dashboards once the deprecation occurs.  
>  

### Monitoring Azure Container Storage performance using Prometheus

  Prometheus metrics are automatically enabled for Azure Container Storage. However, these metrics are only available when using Azure Managed Prometheus. For detailed information about available metrics and collection methods, see [Collecting Azure Container Storage Prometheus metrics](/azure/storage/container-storage/enable-monitoring#collect-azure-container-storage-prometheus-metrics).  
 

## Client connectivity to Kafka cluster  

Strimzi offers flexible options for exposing your Kafka cluster to clients through *listeners*. Each listener defines how clients connect to your Kafka brokers with specific protocols, authentication methods, and network exposure patterns.  

A listener configuration defines:  

* Which port Kafka accepts connections on.  
* The security protocol (Plain, TLS, SASL).  
* How the connection endpoint is exposed (Kubernetes service type).

Kafka uses a two-phase connection process that influences how you should configure networking. When configuring listeners for your Strimzi Kafka deployment on AKS, it's essential to understand the following process:  

1. **Phase 1**: Client connects to bootstrap service, which then connects to any of the brokers to retrieve metadata. The metadata contains the information about the topics, their partitions and brokers which host these partitions.  
1. **Phase 2**: Client then establishes a brand-new connection directly to an individual broker using the advertised address it obtained from the metadata.  

This means your network architecture must account for both the bootstrap service and individual broker connectivity.  

For more information, see the [Strimzi documentation on configuring client access](https://strimzi.io/blog/2019/04/17/accessing-kafka-part-1/).  

### Option 1: Internal cluster access (ClusterIP)

For applications running within the same Kubernetes cluster as the Kafka cluster, expose Kafka via ClusterIP:

  ```yaml
  listeners:
    - name: internal
      port: 9092
      type: internal
      tls: true
  ```

This creates a ClusterIP for the bootstrap service and brokers accessible only within the Kubernetes network.

### Option 2: External access via Public Load Balancer

For external clients, the `loadbalancer` listener type creates an Azure Load Balancer configuration with public IP addresses:

  ```yaml
  listeners:
    - name: external
      port: 9094
      type: loadbalancer
      tls: false
  ```

When using this configuration:

* A Kubernetes LoadBalancer service is created for each broker and the bootstrap service.  
* Azure provisions public IP addresses for each service.  

If you wish to use custom DNS names, you must configure the [`advertisedHost`](https://strimzi.io/docs/operators/latest/full/configuring.html#type-GenericKafkaListenerConfigurationBroker-reference) for each broker and the [`alternativeNames`](https://strimzi.io/docs/operators/latest/full/configuring.html#property-listener-config-altnames-reference) for the bootstrap service. This is required to ensure Kafka properly advertises the custom hostname backing each broker back to a client. It also adds the information to the respective broker or bootstrap certificate so that it can be used for TLS hostname verification.

  ```yaml
  listeners:
    - name: external
      port: 9094
      type: loadbalancer
      tls: true
      configuration: 
        bootstrap:
          alternativeNames: 
          - kafka-bootstrap.example.com
        brokers:
          - broker: 0
            advertisedHost: kafka-broker-0.example.com
  ```

### Option 3: External access via Private Load Balancer

If you want to access the Kafka cluster outside of the AKS cluster but within an Azure virtual network, you can expose the bootstrap service and brokers through an internal load balancer with private IP addresses:  

  ```yaml
  listeners:
    - name: private-lb
      port: 9094
      type: loadbalancer
      tls: true
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

If you wish to use custom DNS names, you must configure the [`advertisedHost`](https://strimzi.io/docs/operators/latest/full/configuring.html#type-GenericKafkaListenerConfigurationBroker-reference) for each broker and the [`alternativeNames`](https://strimzi.io/docs/operators/latest/full/configuring.html#property-listener-config-altnames-reference) for the bootstrap service. This is required to ensure Kafka properly advertises the custom hostname backing each broker back to a client. It also adds the information to the respective broker or bootstrap certificate so that it can be used for TLS hostname verification.

```yaml
  listeners:
    - name: private-lb
      port: 9094
      type: loadbalancer
      tls: true
      configuration: 
        bootstrap:
          alternativeNames: 
          - kafka-bootstrap.example.com
          annotations:
            service.beta.kubernetes.io/azure-load-balancer-internal: "true"
        brokers:
          - broker: 0
            advertisedHost: kafka-broker-0.example.com
            annotations:
              service.beta.kubernetes.io/azure-load-balancer-internal: "true"
```

### Option 4: External access via Private Link Service

For more secure internal networking or accessing across non-peered Azure virtual networks, you can expose your Kafka cluster through Azure Private Link Services:

  ```yaml
  listeners:
    - name: private-link
      port: 9094
      type: loadbalancer
      tls: true
      configuration:
        bootstrap:
          alternativeNames: 
          - kafka-bootstrap.<privatedomain-pe>.com
          annotations:
            service.beta.kubernetes.io/azure-load-balancer-internal: "true"
            service.beta.kubernetes.io/azure-pls-create: "true"
            service.beta.kubernetes.io/azure-pls-name: "pls-kafka-bootstrap" 
        brokers:
          - broker: 0
            advertisedHost: kafka-broker-0.<privatedomain-pe>.com
            annotations:
              service.beta.kubernetes.io/azure-load-balancer-internal: "true"
              service.beta.kubernetes.io/azure-pls-create: "true"
              service.beta.kubernetes.io/azure-pls-name: "pls-kafka-broker-0"
          - broker: 1
            advertisedHost: kafka-broker-1.<privatedomain-pe>.com   
            annotations:
              service.beta.kubernetes.io/azure-load-balancer-internal: "true"
              service.beta.kubernetes.io/azure-pls-create: "true"
              service.beta.kubernetes.io/azure-pls-name: "pls-kafka-broker-1"
          - broker: 2
            advertisedHost: kafka-broker-2.<privatedomain-pe>.com
            annotations:
              service.beta.kubernetes.io/azure-load-balancer-internal: "true"
              service.beta.kubernetes.io/azure-pls-create: "true"
              service.beta.kubernetes.io/azure-pls-name: "pls-kafka-broker-2"
  ```

This configuration:

* Creates internal load balancer services with private IPs for all components.  
* Establishes a Private Link Service for the bootstrap service and the individual brokers, respectively. This enables connection via Private Endpoints from other virtual networks. 
* Configures the [`alternativeNames`](https://strimzi.io/docs/operators/latest/full/configuring.html#property-listener-config-altnames-reference). This is required to ensure Strimzi adds the alternative bootstrap service names to the TLS certificate so that they can be used for TLS hostname verification.  
* Configures the [`advertisedHost`](https://strimzi.io/docs/operators/latest/full/configuring.html#type-GenericKafkaListenerConfigurationBroker-reference). This is required to ensure Kafka advertises the private DNS entry of the private endpoint configured for each broker. The `advertisedHost` is also added to the broker certificate so that it can be used for TLS hostname verification.  

> [!IMPORTANT]
> When adding new brokers to your cluster, you must update the listener configuration with corresponding annotations for each new broker. Otherwise, those brokers will be exposed with public IP addresses.
> 
> You can change the `service.beta.kubernetes.io/azure-pls-name:` to any name you prefer.  

After deploying this configuration, follow the steps for [creating a private endpoint to the Azure Load Balancer Private Link Service](./internal-lb.md#create-a-private-endpoint-to-the-private-link-service).  

## Contributors  

*Microsoft maintains this article. The following contributors originally wrote it:*  

* Sergio Navar | Senior Customer Engineer  
* Erin Schaffer | Content Developer 2  