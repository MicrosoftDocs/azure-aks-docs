---
title: Solution overview for deploying a Kafka cluster on Azure Kubernetes Service (AKS) using Strimzi
description: In this article, we provide an overview of deploying a Kafka cluster on Azure Kubernetes Service (AKS) using the Strimzi Operator.
ms.topic: overview
ms.custom: azure-kubernetes-service
ms.date: 03/31/2025
author: senavar
ms.author: senavar
---

# Deploy a Kafka cluster on Azure Kubernetes Service (AKS) using Strimzi

In this guide, we review the prerequisites, architecture considerations, and key components for deploying and operating a highly available Apache Kafka cluster on [Azure Kubernetes Service (AKS)][what-is-aks] using the Strimzi Operator.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## What is Strimzi?

[Strimzi][strimzi] is an open-source project that simplifies the deployment, management, and operation of Apache Kafka on Kubernetes. It provides a set of Kubernetes Operators and container images that automate complex Kafka operational tasks through declarative configuration.

The Strimzi operators follow the Kubernetes operator pattern to automate Kafka operations. It continuously reconciles the declared state of Kafka components with their actual state, handling complex operational tasks automatically.

//<insert diagram>//

To learn more about Strimzi, review the [Strimzi documentation][https://strimzi.io/documentation/].

## Architecture

### Strimzi Cluster Operator

The Strimzi Cluster Operator is the central component that manages the entire Kafka ecosystem. When deployed, it can also provision the Entity Operator, which consists of:

* **Topic Operator**: Automates the creation, modification, and deletion of Kafka topics based on `KafkaTopic` custom resources.  
* **User Operator**: Manages Kafka users and their Access Control Lists (ACLs) through `KafkaUser` custom resources.  

Together, these operators create a fully declarative management system where your Kafka infrastructure is defined as Kubernetes resources that you can version control, audit, and consistently deploy across environments.  

### Kafka Cluster

 The Strimzi Cluster Operator manages Kafka clusters through specialized custom resources:

* **KafkaNodePools**: Define groups of Kafka nodes with specific roles (broker, controller, or both).  
* **Kafka**: The main custom resource that ties everything together, defining cluster-wide configurations.  

A typical deployment of `KafkaNodePools` and `Kafka` includes:

* Dedicated broker nodes that handle client traffic and data storage.
* Dedicated controller nodes that manage cluster metadata and coordination.
* Multiple replicas of each component distributed across availability zones.  

Together, these components create a fully declarative management system where your Kafka infrastructure is defined as Kubernetes resources that you can version control, audit, and consistently deploy across environments.

### Cruise Control 

[Cruise Control](https://github.com/linkedin/cruise-control) is an advanced component that provides automated workload balancing and monitoring for Kafka clusters. When deployed as part of a Strimzi-managed Kafka cluster, Cruise Control offers:  

* **Automated partition rebalancing**: Redistributes partitions across brokers to optimize resource utilization.  
* **Anomaly detection**: Identifies and alerts on abnormal cluster behavior.  
* **Self-healing capabilities**: Automatically remedies common cluster imbalance issues.  
* **Workload analysis**: Provides insights into cluster performance and resource usage.  

Cruise Control helps maintain optimal performance as your workload changes over time, reducing the need for manual intervention during scaling events or following broker failures.  

### Drain Cleaner

[Strimzi Drain Cleaner](https://strimzi.io/blog/2021/09/24/drain-cleaner/) is a utility designed to help manage Kafka broker pods deployed by Strimzi during Kubernetes node draining. Strimzi Drain Cleaner intercepts Kubernetes node drain operations through its admission webhook to coordinate graceful maintenance of Kafka clusters. When an eviction request is made for Kafka broker pods, the request is detected and the Drain Cleaner annotates the pods to signal the Strimzi Cluster Operator to handle the restart, ensuring that the Kafka cluster remains in a healthy state. This process maintains cluster health and data reliability during routine maintenance operations or unexpected node failures.

## Key considerations for Kafka on AKS  

### Azure Container Storage

[Azure Container Storage](https://learn.microsoft.com/en-us/azure/storage/container-storage/container-storage-introduction) is a managed Kubernetes storage solution that dynamically provisions persistent volumes for stateful applications like Kafka. Based on the OpenEBS open-source project, it provides enterprise-grade storage capabilities specifically optimized for containerized workloads.

For Kafka deployments, Strimzi leverages [JBOD (Just a Bunch of Disks)](https://strimzi.io/docs/operators/latest/deploying#considerations-for-data-storage-str) configuration to manage data persistence. To ensure high availability across infrastructure failures, a [zone-redundant storage pool](https://learn.microsoft.com/en-us/azure/storage/container-storage/enable-multi-zone-redundancy) with Azure Container Storage should be configured to distribute underlying disks across all availability zones. Each zone will use Locally Redundant Storage (LRS) with Premium SSD v2 disks. Zone-Redundant Storage (ZRS) is unnecessary since Kafka provides built-in data replication at the application level. Premium SSD v2 can deliver the latency, high IOPS, and consistent throughput required by IO-intensive Kafka workloads at an optimized cost structure.

>[!NOTE]
>Ephemeral storage is not recommended for production Kafka clusters. When using ephemeral storage, broker restarts trigger full data replication across the cluster, which can significantly impact performance and recovery times.
>

The following table provides starting points for Premium SSD v2 disk configurations across different Kafka cluster sizes:

| Kafka Cluster Size | Disk Size | IOPS | Bandwidth |
|--------------------|-----------|------|-----------|
| **Small**<br>(3-9 brokers) | 1 TB | 5,000 | 250 MB/s |
| **Medium**<br>(10-19 brokers) | 2 TB | 10,000 | 500 MB/s |
| **Large**<br>(20+ brokers) | 4 TB | 20,000 | 1,000 MB/s |

The required IOPS, bandwidth, and disk size will vary based on your specific Kafka workload characteristics. These properties can evolve over time as your application's throughput and retention requirements change.

## Node Pools

Selecting the appropriate node pools for your Kafka deployment on AKS is a critical architectural decision that directly impacts performance, availability, and cost efficiency. Kafka workloads have unique resource utilization patterns—characterized by high throughput demands, storage I/O intensity, and the need for consistent performance under varying loads.
Kafka is typically more memory-intensive than CPU-intensive. However, CPU requirements can increase significantly with message compression/decompression, SSL/TLS encryption, or high-throughput scenarios with many small messages. 

Considering Strimzi's Kubernetes-native architecture where each Kafka broker runs as an individual pod, your AKS node selection strategy should optimize for horizontal scaling rather than single-node vertical scaling. Proper node pool configuration on AKS ensures efficient resource utilization while maintaining the performance isolation that Kafka components require to operate reliably.

Kafka runs using a Java Virtual Machines (JVM). Tuning the JVM is critical for optimal Kafka performance, especially in production environments. LinkedIn, the creators of Kafka, shared the typical arguments for running Kafka on Java for one of LinkedIn's busiest clusters: [Apache Kafka Java Configuration](https://kafka.apache.org/documentation/#java). A memory heap of 6GB will be used as a baseline for brokers, with an additional 2GB allocated to accommodate off-heap memory usage, and 3GB will be used as a baseline for controllers, with an additional 1GB as overhead. 

When sizing VMs for your Kafka deployment, consider these workload-specific factors:

| Workload Factor | Impact on Sizing | Considerations |
|-----------------|------------------|----------------|
| **Message Throughput** | Higher throughput requires more CPU, memory, and network capacity | - Monitor bytes in/out per second<br>- Consider peak vs. average throughput<br>- Account for future growth projections |
| **Message Size** | Larger messages consume more network bandwidth and disk I/O | - Small messages (≤1KB) are CPU-bound<br>- Large messages (>1MB) are network-bound<br>- Very large messages may require specialized tuning |
| **Retention Period** | Longer retention increases storage requirements | - Calculate total storage needs based on throughput × retention<br> |
| **Consumer Count** | More consumers increase CPU and network load | - Each consumer group adds overhead<br>- High fan-out patterns require additional resources |
| **Topic Partitioning** | Higher partition counts increase memory utilization | - Each partition consumes memory resources<br>- Over-partitioning can degrade performance |
| **Infrastructure Overhead** | Additional system components impact available resources for Kafka | - Azure Container Storage requires 1 vCPU per node minimum<br>- Monitoring agents, Logging components,  Network policies and security tools add further overhead<br>- Reserve an overhead for system components |


> [!IMPORTANT]
> The following recommendations serve as starting guidance only. Your optimal VM SKU selection should be tailored to your specific Kafka workload characteristics, data patterns, and performance requirements. Each broker pod is estimated to have ~8GB of reserved memory. Each controller pod is estimated to have ~4GB of reserved memory. Your JVM and off-heap memory requirements may be larger or smaller.

 **Small-Medium sized Kafka clusters**

| VM SKU | vCPUs | RAM | Network | Broker Density (Estimates) | Key Benefits |
|--------|-------|-----|---------|----------------|-------------|
| **Standard_D8ds**  | 8 | 32 GB | 12,500 Mbps | 1-3 per node | - Aligns with Kubernetes fault isolation<br>- Adequate resources for high-performing brokers<br>- Proper zone distribution with anti-affinity<br>- Cost-effective for horizontal scaling |
| **Standard_D16ds**  | 16 | 64 GB | 12,500 Mbps | 3-6 per node | - Better consolidation for medium clusters (6-12 brokers)<br>- More efficient resource utilization<br>- Reduced node count for easier management |

**Large sized Kafka clusters**

| VM SKU | vCPUs | RAM | Network | Broker Density (Estimates) | Key Benefits |
|--------|-------|-----|---------|----------------|-------------|
| **Standard_E16ds**  | 16 | 128 GB | 12,500 Mbps | 6+ per node | - Additional memory for larger heaps and OS cache<br>- Better performance for data-intensive operations<br>- Enhanced throughput for high-volume clusters |

Before finalizing your production environment:

1. Perform load testing with representative data volumes and patterns
2. Monitor CPU, memory, disk, and network utilization during peak loads
3. Adjust AKS node pool SKUs based on observed bottlenecks

### High availability and resilience  

To ensure high availability of your Kafka deployment:  

* Deploy across multiple availability zones.  
* Configure proper replica distribution constraints.  
* Implement appropriate pod disruption budgets.  
* Configure Cruise Control for topic partition rebalancing.
* Use Strimzi Drain Cleaner to handle node maintenance operations.  

### Monitoring and operations 

Effective monitoring of Kafka clusters includes:  

* JMX metrics collection configuration. 
* Consumer lag monitoring with Kafka Exporter.  
* Integration with Azure Managed Prometheus and Azure Managed Grafana.  
* Alerting on key performance indicators and health metrics.  

## When to use kafka on AKS  

Consider running Kafka on AKS when:  

* You need complete control over Kafka configuration and operations.  
* Your use case requires specific Kafka features not available in managed offerings.  
* You want to integrate Kafka with other containerized applications running on AKS.  
* You need to deploy in regions where managed Kafka services aren't available.  
* Your organization has existing expertise in Kubernetes and container orchestration.  

For simpler use cases or when operational overhead is a concern, consider fully managed services like [Azure Event Hubs](/azure/event-hubs/event-hubs-about). 

## Next step  

> [!div class="nextstepaction"]  
> [Create the infrastructure resources for running Kafka on AKS][./kafka-infrastructure.md]  

## Contributors  

*Microsoft maintains this article. The following contributors originally wrote it:*  

* Sergio Navar | Senior Customer Engineer  
* Erin Schaffer | Content Developer 2  