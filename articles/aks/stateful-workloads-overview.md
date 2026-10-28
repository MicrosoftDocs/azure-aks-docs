---
title: Stateful Workloads in Azure Kubernetes Service (AKS)
description: Learn about running stateful workloads in Azure Kubernetes Service (AKS).
ms.topic: overview
ms.service: azure-kubernetes-service
ms.date: 07/10/2026
author: schaffererin
ms.author: schaffererin
ms.collection: 
 - migration
ms.custom: 'stateful-workloads'
# Customer intent: As a cloud architect, I want to understand how to deploy stateful workloads on Azure Kubernetes Service, so that I can ensure data persistence and reliability for critical applications in a scalable environment.
---

# Stateful workloads in Azure Kubernetes Service (AKS)

This article provides an overview of running and migrating stateful workloads on Azure Kubernetes Service (AKS): design patterns, storage options, and migration on‑ramps for databases and stateful services.

## What are stateful workloads?

A _stateful workload_ is an application that uses persistent data storage to preserve state across multiple instances, ensuring a seamless and personalized user experience. This design is vital for services like online banking, online shopping, and email, where data consistency, session history, and reliability are crucial. Stateful workloads also offer efficiency in high performance and near real-time processing scenarios that benefit from advanced features like failover and recovery, ensuring business continuity.

While stateful workloads offer many benefits, they also present certain challenges. For example, stateful workloads often introduce complex processing patterns that can lead to increased overhead and performance costs. It's important that you understand and consider the specific needs of your application to help determine the right balance between statefulness and statelessness.

Given the critical role of stateful workloads, Azure provides several approaches for running them effectively. This section outlines best practices for deploying stateful workloads on Azure Kubernetes Service (AKS), helping developers and organizations choose the most suitable option for their needs.

## Migrating stateful workloads to AKS

If you're moving existing stateful applications into AKS, follow this short migration on-ramp to reduce risk and speed delivery:

1. **Assess storage and availability requirements**: Document IOPS, throughput, latency, durability, and HA needs for your data. Identify whether your workload needs block (Azure Disk), file (Azure Files), or specialized CSI-backed storage.
1. **Choose a CSI driver and storage topology**: Pick the AKS-supported CSI driver that matches those requirements (for example, Azure Disk CSI for block storage, Azure Files CSI for shared file storage, or a third-party CSI for advanced features). Verify volume snapshot and replication requirements are supported.
1. **Deploy using StatefulSets or an operator**: Migrate replicas with StatefulSets or use a database operator to manage failover, membership, and backups. Validate restoration, failover, and rolling upgrade behavior in a test environment before cutover.

For more information, see [Considerations for migrating stateful workloads to AKS](./aks-migration.md#considerations-for-stateful-applications).

### Common stateful migration scenarios

- **PostgreSQL**: Assess storage IOPS and HA needs, choose block or CSI-backed replicated storage, and deploy with a StatefulSet or a PostgreSQL operator. See [PostgreSQL guidance](#postgresql).
- **MongoDB**: Validate write-concern, journaling, and replica set topology; select storage that meets throughput and durability requirements, and deploy using StatefulSets or the MongoDB operator. See [MongoDB guidance](#mongodb).

## Kubernetes stateful framework foundation stack

The Kubernetes stateful framework begins with a common foundation stack. In this case, use the _KATE_ stack, a popular, standardized stack used for many infrastructure projects. The _KATE_ stack uses the following open-source tools:

- [Kubernetes](https://kubernetes.io/)
- [ArgoCD](https://argoproj.github.io/cd)
- [Terraform](https://www.terraform.io/)
- [External Secrets Operator](https://external-secrets.io/latest/)

The AKS guides don't implement ArgoCD or Terraform because they're designed for _Day 1_ operations. However, as your deployment scales and requirements evolve, it should be easier for you to integrate ArgoCD and Terraform since the guides use part of the KATE stack.

## Kubernetes stateful framework for Azure

With the foundation stack established, we now need to enhance the framework to support stateful workloads on Azure, specifically by integrating the essential resources for running data infrastructure on [Azure Kubernetes Service (AKS)](what-is-aks.md).

Supporting complex stateful workloads, such as databases or message queues, requires storage capabilities that exceed ephemeral options. Specifically, you need systems that offer increased resilience and availability to address various events, such as application failures or workload reassignments to different hosts. You can achieve this resilience by using the [_PersistentVolume subsystem_](https://kubernetes.io/docs/concepts/storage/persistent-volumes/), which comprises three interconnected Kubernetes resources: _PersistentVolumes_, _PersistentVolumeClaims_, and _StorageClasses_. This subsystem provides an API for users and administrators to abstract the details of how storage is provided from how the storage is consumed.

Most stateful workloads need data from secrets, such as connection strings, usernames, passwords, and certificates. [Azure Key Vault](/azure/key-vault/general/overview) provides a secure store for secrets that we use to hold the necessary stateful frameworks secrets.

We also need a Kubernetes Controller or Kubernetes Operator, like the [Secrets Store CSI Driver](https://github.com/kubernetes-sigs/secrets-store-csi-driver) or the [External Secrets Operator](https://external-secrets.io/latest/) to synchronize secret store secrets as Kubernetes Secrets.

:::image type="content" source="media/stateful-workloads-overview/stateful-foundation-stack.png" alt-text="Screenshot of a diagram showing the Kubernetes stateful framework for Azure.":::

## Design and deploy stateful workloads on Azure

If you're migrating an existing stateful workload to AKS, start with the [Migration stateful workloads to AKS on-ramp](#migrating-stateful-workloads-to-aks) to review migration-specific assessment and validation steps.

The following sections provide links to design and deployment information for stateful workload scenarios on Azure.

### MongoDB

- [MongoDB stateful workload design overview](mongodb-overview.md)
- [Create the infrastructure for running a MongoDB cluster on Azure Kubernetes Service (AKS)](create-mongodb-infrastructure.md)
- [Configure and deploy a MongoDB cluster on Azure Kubernetes Service (AKS)](deploy-mongodb-cluster.md)
- [Deploy a client application to connect to a MongoDB cluster on Azure Kubernetes Service (AKS)](validate-mongodb-cluster.md)
- [Validate resiliency of a MongoDB cluster on Azure Kubernetes Service (AKS)](resiliency-mongodb-cluster.md)
- [Validate MongoDB resiliency during an Azure Kubernetes Service (AKS) node pool upgrade](upgrade-mongodb-cluster.md)
- [Set up monitoring for a MongoDB cluster on Azure Kubernetes Service (AKS)](monitor-aks-mongodb.md)

### PostgreSQL

- [PostgreSQL stateful workload design overview](postgresql-ha-overview.md)
- [Create the infrastructure for running a highly available PostgreSQL database on Azure Kubernetes Service (AKS)](create-postgresql-ha.md)
- [Deploy a highly available PostgreSQL database on Azure Kubernetes Service (AKS)](deploy-postgresql-ha.md)

### Valkey

- [Valkey stateful workload design overview](valkey-overview.md)
- [Create the infrastructure for running a Valkey cluster on Azure Kubernetes Service (AKS)](create-valkey-infrastructure.md)
- [Configure and deploy a Valkey cluster on Azure Kubernetes Service (AKS)](deploy-valkey-cluster.md)
- [Validate resiliency of a Valkey cluster on Azure Kubernetes Service (AKS)](validate-valkey-cluster.md)
- [Validate Valkey resiliency during an Azure Kubernetes Service (AKS) node pool upgrade](upgrade-valkey-aks-nodepool.md)

### Apache Airflow

- [Apache Airflow stateful workload design overview](airflow-overview.md)
- [Create the infrastructure for running Apache Airflow on Azure Kubernetes Service (AKS)](airflow-create-infrastructure.md)
- [Configure and deploy Airflow on Azure Kubernetes Service (AKS)](airflow-deploy.md)

### Apache Kafka with Strimzi

- [Deploy a Kafka cluster on Azure Kubernetes Service (AKS) using Strimzi overview](kafka-overview.md)
- [Prepare the infrastructure for deploying Kafka on Azure Kubernetes Service (AKS)](kafka-infrastructure.md)
- [Configure and deploy Strimzi and Kafka components on Azure Kubernetes Service (AKS)](kafka-deploy.md)
- [Configure monitoring and networking for a Kafka cluster on Azure Kubernetes Service (AKS)](kafka-configure.md)

## GitHub Actions with Azure Files

- [Solution overview for deploying highly available GitHub Actions on Azure Kubernetes Service (AKS)](./github-actions-azure-files-overview.md)
- [Create the infrastructure for deploying highly available GitHub Actions on Azure Kubernetes Service (AKS)](./github-actions-azure-files-create-infrastructure.md)
- [Deploy and test GitHub Actions on Azure Kubernetes Service (AKS)](./github-actions-azure-files-deploy-test.md)

> [!NOTE]
> Although StatefulSets provide persistent identities and storage, [Azure Spot node pools](spot-node-pool.md) aren't recommended for production-critical stateful workloads.
> Spot VMs can be evicted with little notice when Azure reclaims capacity, resulting in abrupt node termination and potential delays in volume recovery or pod rescheduling. For workloads that depend on persistent data and high availability, use regular node pools and appropriate storage resiliency mechanisms.
> Azure Spot node pools should be reserved for interruptible workloads that can tolerate unexpected node loss.

## Contributors

_Microsoft maintains this article. The following contributors originally wrote it:_

- Don High | Principal Customer Engineer
- Colin Mixon | Product Manager
- Erin Schaffer | Content Developer 2
