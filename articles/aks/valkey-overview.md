---
title: Solution overview for deploying a Valkey cluster on Azure Kubernetes Service (AKS)
description: In this article, we provide an overview of deploying a Valkey cluster on Azure Kubernetes Service (AKS) using the Kubernetes stateful framework.
ms.topic: overview
ms.custom: azure-kubernetes-service
ms.date: 08/15/2024
author: schaffererin
ms.author: schaffererin
---

# Deploy a Valkey cluster on Azure Kubernetes Service (AKS)

In this article, we review the challenges of properly using Azure availability zones when running a Valkey cluster on AKS, share some scaling considerations, and propose a solution.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## What is Valkey?

[Valkey][valkey] is a fork of the [Redis project][redis] that preserves its original open-source license. Valkey is a high performance database that supports a key-value datastore, and you can use it for caching, session storage, message queues, and more. A *Valkey cluster* has multiple nodes that are responsible for hosting your Valkey data stores. Valkey shards data into smaller portions and disperses it among the nodes. In a simplified Valkey cluster consisting of *three* primary nodes, a single replica node supports each node to enable basic failover capabilities. The data is distributed across the nodes, enabling the cluster to continue functioning even if one of the nodes fails.

:::image type="content" source="./media/valkey-stateful-workload/valkey-cluster.png" alt-text="Screenshot of a Valkey cluster on AKS.":::

For more information, see the [Valkey documentation][valkey-docs].

## Valkey solution overview

The goal of this solution is to deploy Valkey on AKS with the same level of service as the [Azure Cache for Redis][azure-cache-for-redis] Premium tier.

The following table lists key features of the Azure Cache for Redis Premium tier and the proposed Valkey solution:

| Azure Cache for Redis Premium tier | Valkey solution |
| --- | --- |
| **Memory up to 1.2 TB** | Using *three* Valkey primaries running on the `Standard_E64_v5` SKU. |
| **Replication** | Adding at least *one* replica pod per primary pod. |
| **Zone redundancy** | Placing primary and replica pods in different availability zones. |

We create two distinct [`StatefulSet`][kubernetes-stateful-sets] resources: one for the Valkey primaries and one for the replicas. The `spec.affinity` of the `StatefulSet` API places the primary pods in two different availability zones and the replica pods in another third availability zone. This approach ensures that a single zone failure doesn't impact the availability for any Valkey shard.

> [!NOTE]
> Note that the solution suggested in this article differs from the Valkey documentation, where cluster Pods belong to a single `StatefulSet`, and the `spec.affinity` only ensures that the Pods are placed on different nodes. The automatic Valkey cluster initialization presented in the Valkey documentation doesn't ensure that the primary and replica Pods for the same shard are placed in different availability zones.

## Next steps

> [!div class="nextstepaction"]
> [Create the infrastructure resources for running a Valkey cluster on AKS][create-valkey-infrastructure]

## Contributors

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

<!-- External links -->
[valkey]: https://valkey.io/
[redis]: https://redis.io/
[valkey-docs]: https://valkey.io/docs/
[kubernetes-stateful-sets]: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/

<!-- Internal links -->
[azure-cache-for-redis]: /azure/azure-cache-for-redis/cache-overview#feature-comparison
[create-valkey-infrastructure]: ./create-valkey-infrastructure.md
