---
title: 'Deploy a MongoDB cluster on Azure Kubernetes Service (AKS)'
description: Learn how to deploy a MongoDB cluster on AKS.
ms.topic: overview
ms.date: 09/05/2024
author: fossygirl
ms.author: carols
ms.custom: aks-related-content
---

# Deploy a MongoDB cluster on Azure Kubernetes Service (AKS)

> [!NOTE]
> MongoDB Community Edition is not open source software, it is licensed under the [Server Side Public License](https://en.wikipedia.org/wiki/Server_Side_Public_License) with "source available."

## What is MongoDB?
[MongoDB](https://www.mongodb.com/) is a popular NoSQL database management system designed to handle large volumes of unstructured data. Unlike traditional relational databases that use tables and rows, MongoDB uses a flexible, document-oriented approach.

### MongoDB Sharded Cluster
A MongoDB Sharded Cluster is a setup designed to handle large datasets and high throughput by distributing data across multiple servers or shards. This architecture enables horizontal scaling, which is essential for applications with growing data and performance needs. Here’s a breakdown of its key components and how it works:

1. **Shards**: Shards are individual MongoDB instances that hold subsets of the data. Each shard is a replica set (a group of MongoDB instances that replicate data among themselves), ensuring high availability and fault tolerance.
2. **Config Servers**: Config servers store metadata and configuration settings for the sharded cluster. They keep track of the cluster’s data distribution and routing information. There are typically three config servers to provide redundancy.
3. **Mongos Instances**: Mongos is a routing service that directs client requests to the appropriate shard. It acts as an intermediary between the client and the shards, managing query routing and aggregating results from multiple shards.
4. **Shard Key**: When data is distributed across shards, it is based on a shard key, which is either a single indexed field or multiple fields in the documents. The shard key determines how data is partitioned among the shards. A well-chosen shard key ensures even data distribution and efficient querying.
5. **Data Distribution**: Data is distributed across shards based on the shard key. This distribution helps balance the load and manage large datasets effectively. MongoDB uses a range-based or hash-based sharding strategy depending on the shard key.
6. **High Availability**: Each shard is a replica set, meaning it replicates its data across multiple nodes. This setup ensures that data remains available even if one or more nodes fail.

### What is Percona Operator for MongoDB?

The Percona Operator for MongoDB is an open-source tool developed by [Percona](https://www.percona.com/) designed to automate the deployment, management, and scaling of MongoDB clusters within Kubernetes environments. It simplifies operations by handling tasks such as provisioning, scaling, backup, and recovery, all while ensuring high availability and performance of MongoDB clusters. The Operator uses Kubernetes Custom Resource Definitions (CRDs) to manage MongoDB configurations declaratively and handles failovers, monitoring, and alerts, which results in reduced administrative overhead and consistent management practices. Ideal for development, testing, and production scenarios, the Percona Operator enhances the efficiency and reliability of MongoDB deployments, particularly in cloud-native applications.

![MongoDB Cluster](../media/mongodb-shared-cluster.png)

## MongoDB solution overview

We will explain the challenges of applying Azure availability zones correctly when running a MongoDB cluster on AKS. We propose a solution and we make some considerations on how to run MongoDB on AKS.

### Deployment Strategy

**Sharded Cluster**: Sharding is enabled to distribute data across multiple shards, improving scalability and performance.

**Configuration Servers**: Managed by a three-member replica set, to ensure fault tolerance and high availability, with anti-affinity rules to distribute these servers across different failure domains.

**Mongos Instances**: Three query routers handle client requests, distributed across availability zones, and exposed internally within the cluster for load balancing and resiliency.

This strategy ensures that the MongoDB cluster can handle large datasets and high-throughput operations effectively. It also maintains high availability and fault tolerance through the use of replica sets, anti-affinity rules, and proper resource allocation.

## Next steps

> [!div class="nextstepaction"]
> [Create the infrastructure resources for running a MongoDB cluster on AKS](./create-mongodb-infrastructure.md)