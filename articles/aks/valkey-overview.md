---
title: Solution Overview for Deploying a Valkey Cluster on Azure Kubernetes Service (AKS)
description: In this article, we provide an overview of deploying a Valkey cluster on Azure Kubernetes Service (AKS) using the Kubernetes stateful framework.
ms.topic: overview
ms.service: azure-kubernetes-service
ms.date: 09/15/2025
author: schaffererin
ms.author: schaffererin
ms.custom: 'stateful-workloads'
# Customer intent: As a cloud architect, I want to deploy a Valkey cluster on Azure Kubernetes Service, so that I can ensure high availability and scalability similar to the Azure Cache for Redis Premium tier while effectively utilizing availability zones.
---

# Deploy a Valkey cluster on Azure Kubernetes Service (AKS)

This article summarizes the steps to deploy Valkey, an open source (BSD) high-performance key/value datastore, on Azure Kubernetes Service (AKS). The Valkey deployment focuses on leveraging replicas and availability zones for high availability and resilience. We also provide guidance to test the resilience of your Valkey deployment using the [Locust load testing framework](https://github.com/locustio/locust).

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## What is Valkey?

[Valkey][valkey] is a fork of the [Redis project][redis] that preserves its original open-source license. Valkey is a high performance database that supports a key-value datastore, and you can use it for caching, session storage, message queues, and more. A _Valkey cluster_ has multiple nodes that are responsible for hosting your Valkey data stores. Valkey shards data into smaller portions and disperses it among the nodes. In a simplified Valkey cluster consisting of _three_ primary nodes, a single replica node supports each node to enable basic failover capabilities. The data is distributed across the nodes, enabling the cluster to continue functioning even if one of the nodes fails.

:::image type="content" source="./media/valkey-stateful-workload/valkey-cluster.png" alt-text="Architecture diagram of Valkey deployed on AKS with three primary nodes and one replica for each primary.":::

For more information, see the [Valkey documentation][valkey-docs].

## Valkey solution overview

This solution deploys three Valkey primary pods across two availability zones with one replica pod per primary in a third zone, running on `Standard_E64_v5` SKU nodes. We create two distinct `StatefulSet` resources with `spec.affinity` rules ensuring zone distribution for high availability. The goal of this solution is to deploy Valkey on AKS with the same level of service as the [Azure Cache for Redis][azure-cache-for-redis] Premium tier.

The following table lists key features of the Azure Cache for Redis Premium tier and the proposed Valkey solution:

| Azure Cache for Redis Premium tier | Valkey solution |
| --- | --- |
| **Memory up to 1.2 TB** | Using _three_ primary nodes running on the `Standard_E64_v5` SKU. |
| **Replication** | Adding at least _one_ replica pod per primary pod. |
| **Zone redundancy** | Placing primary and replica pods in different availability zones. |

We create two distinct [`StatefulSet`][kubernetes-stateful-sets] resources: one for the Valkey primary pods and one for the replica pods. The `spec.affinity` of the `StatefulSet` API places the primary pods in two different availability zones and the replica pods in another third availability zone.

> [!NOTE]
> Note that the solution suggested in this article differs from the Valkey documentation, where cluster Pods belong to a single `StatefulSet`, and the `spec.affinity` only ensures that the Pods are placed on different nodes. The automatic Valkey cluster initialization presented in the Valkey documentation doesn't ensure that the primary and replica Pods for the same shard are placed in different availability zones.

## Next step

> [!div class="nextstepaction"]
> [Create the infrastructure resources for running a Valkey cluster on AKS][create-valkey-infrastructure]

## Contributors

_Microsoft maintains this article. The following contributors originally wrote it:_

- Nelly Kiboi | Service Engineer
- Saverio Proto | Principal Customer Experience Engineer
- Don High | Principal Customer Engineer
- LaBrina Loving | Principal Service Engineer
- Ken Kilty | Principal TPM
- Russell de Pina | Principal TPM
- Colin Mixon | Product Manager
- Ketan Chawda | Senior Customer Engineer
- Naveed Kharadi | Customer Experience Engineer
- Erin Schaffer | Content Developer 2

<!-- External links -->
[valkey]: https://valkey.io/
[redis]: https://redis.io/
[valkey-docs]: https://valkey.io/docs/
[kubernetes-stateful-sets]: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/

<!-- Internal links -->
[azure-cache-for-redis]: /azure/azure-cache-for-redis/cache-overview#feature-comparison
[create-valkey-infrastructure]: ./create-valkey-infrastructure.md
