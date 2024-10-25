---
title: 'Solution overview for deploying a MongoDB cluster on Azure Kubernetes Service (AKS)'
description: This article provides an overview for deploying a MongoDB cluster on AKS.
ms.topic: overview
ms.date: 09/05/2024
author: fossygirl
ms.author: carols
ms.custom: aks-related-content
---

# Deploy a MongoDB cluster on Azure Kubernetes Service (AKS)

This article walks through prerequisite information for deploying a MongoDB cluster on [Azure Kubernetes Service (AKS)](what-is-aks.md). It also provides an overview of the deployment strategy.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## What is MongoDB?

[MongoDB](https://www.mongodb.com/) is a popular NoSQL database management system that's designed to handle large volumes of unstructured data. Unlike traditional relational databases that use tables and rows, MongoDB uses a flexible, document-oriented approach.

> [!NOTE]
> MongoDB Community Edition isn't open-source software. It's licensed under the [Server Side Public License](https://www.mongodb.com/legal/licensing/server-side-public-license) with "source available."

### MongoDB sharded cluster

A [MongoDB sharded cluster](https://www.mongodb.com/docs/manual/core/sharded-cluster-components/) handles large datasets and high throughput by distributing data across multiple servers or shards. This architecture enables horizontal scaling, which is essential for applications that have growing data and performance needs.

Here's a breakdown of the key components of a MongoDB sharded cluster and how it works:

* **Shards**: Individual MongoDB instances called [shards](https://www.mongodb.com/docs/manual/core/sharded-cluster-shards/) hold subsets of the data. Each shard is a replica set, or a group of MongoDB instances that replicate data among themselves. Replica sets help ensure high availability and fault tolerance.
* **Config servers**: The servers that store metadata and configuration settings for the sharded cluster are called [config servers](https://www.mongodb.com/docs/manual/core/sharded-cluster-config-servers/). They keep track of the cluster's data distribution and routing information. A cluster typically has three config servers to provide redundancy.
* **Mongos instances**: [Mongos](https://www.mongodb.com/docs/manual/core/sharded-cluster-query-router/) is a routing service that directs client requests to the appropriate shard. It acts as an intermediary between the client and the shards. An instance of Mongos manages query routing and aggregates results from shards.
* **Shard key**: When data is distributed across shards, it's based on a [shard key](https://www.mongodb.com/docs/manual/core/sharding-shard-key/), which is either a single indexed field or multiple fields in the documents. The shard key determines how data is partitioned among the shards. A well-chosen shard key helps ensure even data distribution and efficient querying.
* **Data distribution**: Data is distributed across shards based on the shard key. This distribution helps balance the load and manage large datasets effectively. MongoDB uses a [range-based](https://www.mongodb.com/docs/manual/core/ranged-sharding/) or [hash-based](https://www.mongodb.com/docs/manual/core/hashed-sharding/) sharding strategy, depending on the shard key.
* **High availability**: Each shard is a replica set, which means that it replicates its data across multiple nodes. This setup ensures that data remains available even if one or more nodes fail.

### Percona Operator for MongoDB

The Percona Operator for MongoDB is an open-source tool developed by [Percona](https://www.percona.com/). It automates the deployment, management, and scaling of MongoDB clusters within Kubernetes environments. It simplifies operations by handling tasks such as provisioning, scaling, backup, and recovery. Its handling of all those tasks helps ensure high availability and performance of MongoDB clusters.

The operator uses Kubernetes custom resource definitions (CRDs) to manage MongoDB configurations declaratively and to handle failovers, monitoring, and alerts. The result is reduced administrative overhead and consistent management practices. The Percona Operator enhances the efficiency and reliability of MongoDB deployments, particularly in cloud-native applications. It's well suited for development, testing, and production scenarios.

:::image source="../aks/media/mongodb-overview/mongodb-shared-cluster.png" alt-text="Diagram that show how the Percona Operator relates to a MongoDB cluster." lightbox="../aks/media/mongodb-overview/mongodb-shared-cluster.png":::

## MongoDB solution overview

The goal of the proposed solution is to:

* Ensure that the MongoDB cluster can effectively handle large datasets and high-throughput operations.
* Maintain high availability and fault tolerance.

It will accomplish this goal through the use of replica sets, anti-affinity rules, and proper resource allocation.

### Deployment strategy

The MongoDB deployment strategy consists of the following components:

* A *sharded cluster* to enable the distribution of data across multiple shards, improving scalability and performance.
* *Configuration servers* managed by a three-member replica set to help ensure fault tolerance and high availability. Anti-affinity rules distribute these servers across failure domains.
* Three *Mongos instances* distributed across availability zones and exposed internally within the cluster. They provide load balancing and resiliency to route client requests.

## Contributors

*This article is maintained by Microsoft. It was originally written by the following contributors*:

* Nelly Kiboi | Service Engineer
* Saverio Proto | Principal Customer Experience Engineer
* Don High | Principal Customer Engineer
* LaBrina Loving | Principal Service Engineer
* Ken Kilty | Principal TPM
* Russell de Pina | Principal TPM
* Colin Mixon | Product Manager
* Ketan Chawda | Senior Customer Engineer
* Naveed Kharadi | Customer Experience Engineer
* Erin Schaffer | Content Developer 2
* Carol Smith | Senior Content Developer

## Next step

> [!div class="nextstepaction"]
> [Create the infrastructure resources for running a MongoDB cluster on AKS](./create-mongodb-infrastructure.md)
