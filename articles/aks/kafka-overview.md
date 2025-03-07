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

Key benefits of Strimzi include:

* **Kubernetes-native management** - Define Kafka infrastructure as code using custom resources
* **Simplified operations** - Automated configuration, scaling, upgrades, and security management
* **Cloud-agnostic design** - Works consistently across any Kubernetes environment including AKS
* **Production-ready features** - Built-in monitoring, scalability, and security controls

//<insert diagram>//

For more information, see the [Strimzi documentation][strimzi-docs].

## Strimzi Operator Overview

The Strimzi Operator follows the Kubernetes operator pattern to automate Kafka operations. It continuously reconciles the declared state of Kafka components with their actual state, handling complex operational tasks automatically.

Key capabilities of the Strimzi Operator include:

* Provisioning and managing Kafka clusters with KRaft consensus protocol
* Automatically configuring TLS encryption and authentication
* Managing topics and user access control through custom resources
* Coordinating rolling updates and scaling operations with minimal disruption
* Integrating with monitoring systems through Prometheus metrics exporters

<<Insert strimzi operator diagram>>

## Architecture

### Strimzi Operator

The Strimzi Cluster Operator is the central component that manages the entire Kafka ecosystem. When deployed, it can also provision the Entity Operator, which consists of:

* **Topic Operator**: Automates the creation, modification, and deletion of Kafka topics based on `KafkaTopic` custom resources
* **User Operator**: Manages Kafka users and their ACLs (Access Control Lists) through `KafkaUser` custom resources

Together, these operators create a fully declarative management system where your Kafka infrastructure is defined as Kubernetes resources that can be version-controlled, audited, and consistently deployed across environments.

### Kafka Cluster

Modern Kafka deployments use the Kafka Raft (KRaft) mode, which eliminates the need for ZooKeeper by implementing the [Raft consensus protocol](https://strimzi.io/blog/2024/03/21/kraft-migration/) directly within Kafka. The Strimzi Operator manages Kafka clusters through specialized custom resources:

* **KafkaNodePools**: Define groups of Kafka nodes with specific roles (broker, controller, or both)
* **Kafka**: The main custom resource that ties everything together, defining cluster-wide configurations

A typical production deployment includes:

* Dedicated broker nodes that handle client traffic and data storage
* Dedicated controller nodes that manage cluster metadata and coordination
* Multiple replicas of each component distributed across availability zones

This separation of concerns improves scalability and resilience by allowing independent scaling and optimization of each component.

### Cruise Control

Cruise Control is an advanced component initially developed by LinkedIn that provides automated workload balancing and monitoring for Kafka clusters. When deployed as part of a Strimzi-managed Kafka cluster, Cruise Control offers:

* **Automated partition rebalancing**: Redistributes partitions across brokers to optimize resource utilization
* **Anomaly detection**: Identifies and alerts on abnormal cluster behavior
* **Self-healing capabilities**: Automatically remedies common cluster imbalance issues
* **Workload analysis**: Provides insights into cluster performance and resource usage

Cruise Control helps maintain optimal performance as your workload changes over time, reducing the need for manual intervention during scaling events or following broker failures.

### Drain Cleaner

[Strimzi Drain Cleaner](https://strimzi.io/blog/2021/09/24/drain-cleaner/) is a utility designed to help manage Apache Kafka pods deployed by Strimzi during Kubernetes node draining. Strimzi Drain Cleaner intercepts Kubernetes node drain operations through its admission webhook to coordinate graceful maintenance of Kafka clusters. When an eviction request is made for Kafka broker pods, the request is detected and the Drain Cleaner annotates the pods to signal the Strimzi Cluster Operator to handle the restart, ensuring that the Kafka cluster remains in a healthy state. This process maintains cluster health and data reliability during routine maintenance operations or unexpected node failures. For high availability, Drain Cleaner itself can be deployed with multiple replicas across availability zones and configured with pod disruption budgets, ensuring it remains functional during zonal outages or cluster upgrades.

## Key Considerations for Kafka on AKS

### Storage and Performance

Kafka is both I/O and memory-intensive. For optimal performance on AKS:

* Use Premium SSD v2 managed disks for Kafka's persistent storage
* Configure separate storage volumes for Kafka's data and logs
* Size node pools appropriately for your expected message throughput and retention
* Consider using dedicated node pools with optimized VM sizes for Kafka workloads

### High Availability and Resilience

To ensure high availability of your Kafka deployment:

* Deploy across multiple availability zones
* Configure proper replica distribution constraints
* Implement appropriate pod disruption budgets
* Use Strimzi Drain Cleaner to handle node maintenance operations

### Monitoring and Operations

Effective monitoring of Kafka clusters includes:

* JMX metrics collection via Prometheus exporters
* Consumer lag monitoring with Kafka Exporter
* Integration with Azure Managed Prometheus and Azure Managed Grafana
* Alerting on key performance indicators and health metrics

## When to Use Kafka on AKS

Consider running Kafka on AKS when:

* You need complete control over Kafka configuration and operations
* Your use case requires specific Kafka features not available in managed offerings
* You want to integrate Kafka with other containerized applications running on AKS
* You need to deploy in regions where managed Kafka services aren't available
* Your organization has existing expertise in Kubernetes and container orchestration

For simpler use cases or when operational overhead is a concern, consider fully managed services like Azure Event Hubs.

## Next Steps

After understanding the architecture and components of Kafka on AKS, proceed to:
* [Prepare the AKS infrastructure for Kafka deployment](kafka-infrastructure.md)
* [Deploy and configure Strimzi and Kafka components](kafka-deploy.md)