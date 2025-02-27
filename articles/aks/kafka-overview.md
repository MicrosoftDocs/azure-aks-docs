---
title: Solution overview for deploying a Kafka cluster on Azure Kubernetes Service (AKS) using Strimzi
description: In this article, we provide an overview of deploying a Kafka cluster on Azure Kubernetes Service (AKS) using the Strimzi Operator.
ms.topic: overview
ms.custom: azure-kubernetes-service
ms.date: 08/15/2024
author: senavar
ms.author: senavar
---

# Deploy a Kafka cluster on Azure Kubernetes Service (AKS) using Strimzi

In this article, we review the prerequisites and considerations for a deploying and operating a highly available Kafka cluster on [Azure Kubernetes Service (AKS)][what-is-aks] by using the Strimzi Operator.
[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## What is Strimzi?

[Strimzi][strimzi] is an open-source project that simplifies the deployment, management, and operation of Apache Kafka on Kubernetes. It provides a set of Kubernetes Operators and container images that automate the tasks of running Kafka clusters, including configuration, scaling, and security. Strimzi supports the deployment of Kafka components such as Kafka brokers, Kafka controllers, Cruise Control, and Kafka Mirror Maker. It enables the declarative management of Kafka, allowing you to define the desired state of Kafka brokers, controllers, topics, users, and other components using Kubernetes custom resources, which the operator then reconciles with the actual cluster state. Designed for flexibility, Strimzi is a robust solution for managing Kafka on Kubernetes and meeting different customer requirements.

//<insert diagram>//

For more information, see the [Strimzi documentation][strimzi-docs].

## Strimzi Operator Overview

The Strimzi Operator is a Kubernetes Operator designed to manage Apache Kafka clusters. The operator uses Kubernetes custom resources to define the desired state of Kafka clusters, topics, users, and other components, and continuously reconciles this desired state with the actual state of the Kafka cluster. This declarative approach simplifies complex tasks such as scaling Kafka brokers, configuring TLS encryption and authentication. It can also deploy an additional operator, the Entity Operator, to manage Kafka users and topics.  

<<Insert strizi operator diagram>>

## Architecture

### Strimzi Operator

### Kafka Cluster

Once deployed, the Strimzi Operator allows you to begin deploying the desired Kafka cluster architecture

### Cruise Control

### Drain Cleaner

Strimzi Drain Cleaner is a utility designed to help manage Apache Kafka pods deployed by Strimzi during Kubernetes node draining. When a Kubernetes node is drained for maintenance or upgrades, pods running on that node need to be moved. Strimzi Drain Cleaner ensures that this process is handled smoothly by the Strimzi operator rather than Kubernetes itself.

The main advantage of using Strimzi Drain Cleaner is that it prevents Kafka partition replicas from becoming under-replicated during the node draining process. It uses Kubernetes Admission Control features and Validating Webhooks to detect when an eviction request is made for Kafka broker pods. When such a request is detected, the Drain Cleaner annotates the pods to signal the Strimzi Cluster Operator to handle the restart, ensuring that the Kafka cluster remains in a healthy state.
