---
title: Solution overview for deploying the Strimzi Operator and highly available Kafka cluster on Azure Kubernetes Service (AKS)
description: In this article, we provide an overview of deploying a Kafka cluster on Azure Kubernetes Service (AKS) using the Strimzi Operator.
ms.topic: overview
ms.custom: azure-kubernetes-service
ms.date: 08/15/2024
author: senavar
ms.author: senavar
zone_pivot_groups: azure-cli-or-terraform
---

## Infrastructure Overview 

The target AKS architecture to run Kafka maintains a focus on high availability. To accomplish this, we create a zone redundant AKS cluster, which automatically distributes that AKS control plane components across availability zones. Dedicated node pools for Kafka are recommended to limit any noisy neighbor scenario. Three (3) node pools are required, one per availability zone. This ensures that with cluster autoscaler enabled, nodes in each zone are predictably scaled during a node outage. This is important because the target architecture will have persistent volumes that have zonal affinity. If a new node is not correctly added to the necessary zone, pods will remain in a pending state. Having this zonal resiliency will allow you to deploy multiple replicas of the Strimzi Cluster Operator and Kafka Cluster and ensure high availability within the target region.

### Azure Container Storage

[Azure Container Storage](https://learn.microsoft.com/en-us/azure/storage/container-storage/container-storage-introduction) allows you to dynamically and automatically provision persistent volumes to store data for stateful applications, like Kafka, running on Kubernetes clusters. It is derived from OpenEBS, an open-source solution that provides container storage capabilities for Kubernetes. 

Strimzi handles message and log storage by configuring [JBOD (Just a Bunch of Disks)](https://strimzi.io/docs/operators/latest/deploying#considerations-for-data-storage-str) volumes. JBOD storage allows you to configure your Kafka cluster to use multiple disks or volumes as ephemeral or persistent storage. The persistent storage type integrates with Kubernetes Persistent Volumes (PVs) through Persistent Volume Claims (PVCs), ensuring Kafka data is stored reliably. Using Azure Container Storage for the Persistent Volumes offers dynamic provisioning, high availability, and volume resizing, enhancing the scalability and reliability of the Kafka cluster. 

A [zone-redundant storage pool](https://learn.microsoft.com/en-us/azure/storage/container-storage/enable-multi-zone-redundancy) is required so that the underlying disks are distributed to each availability zone. The underlying storage for Azure Container Storage in each of the zones should be configured as Locally Redundant Storage (LRS) PremiumV2 SSD. Zone Redundant Storage (ZRS) is not required because Kafka provides provides built-in data replication. Azure Premium SSD v2 is designed for IO-intense enterprise workloads that require sub-millisecond disk latencies and high IOPS and throughput at a low cost. 

>[!NOTE]
>Ephemeral storage is not recommended, as larger Kafka clusters will take time to constantly replicate data across new ephemeral instances and can impact performance.
>

The required IOPS, bandwidth and disk size will vary per workload. These properties are adjustable to meet your workload's evolving needs. 

### Node Pools


:::zone pivot="azure-cli"

:::



## Deploy Infrastructure 

### via CLI (Pivot Group)
### via Terraform (Pivot Group)
