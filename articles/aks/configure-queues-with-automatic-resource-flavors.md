---
title: Configure queues with managed Kueue using default workload priority on Azure Kubernetes Service (AKS)
description: Simplify workload queueing and prioritization on AKS with managed Kueue automatically generated resource flavors and default workload priority classes 
ms.topic: how-to
ms.date: 10/08/2026
author: colinmixon
ms.author: colinmixon
ms.service: azure-kubernetes-service
# Customer intent: As an AKS administrator, I want to configure Kueue queues and priorities so that critical workloads receive constrained capacity first.
---

# Configure queues with managed Kueue using default priority classes on Azure Kubernetes Service (AKS)

Managed Kueue on Azure Kubernetes Service (AKS) simplifies workload queueing and prioritization by providing managed resource flavors when you add any node pool to a cluster and three default workload priority classes from low to high priority.

In this article, you learn how to:

- Configure a ClusterQueue using the generated `aks-cpu` ResourceFlavor.
- Create a LocalQueue for submitting workloads.
- Use managed workload priority classes to control admission and preemption.

## Understand managed Kueue resources

Managed Kueue provides AKS-managed resources that you can reference when configuring queues and workloads. For CPU workloads, managed Kueue provides the `aks-cpu` ResourceFlavor. You can reference this ResourceFlavor from a `ClusterQueue` to associate queue quota with eligible CPU nodes.

Managed Kueue also provides the following workload priority classes:

| Priority class | Value |
|---|---|
| `aks-low-priority` | `100` |
| `aks-medium-priority` | `500` |
| `aks-high-priority` | `1000` |

When workloads compete for limited quota, Kueue uses workload priority as part of admission ordering. You can also configure preemption on the ClusterQueue to allow higher-priority workloads to reclaim quota from lower-priority workloads.

## Prerequisites

Before you begin, ensure you have the following resources and tools:

- An AKS cluster with the managed Kueue extension installed.
- [Azure CLI](/cli/azure/install-azure-cli) 
- [kubectl][install-kubectl]
- An Azure subscription with permissions to create AKS node pools.
- The `RESOURCE_GROUP` and `CLUSTER_NAME` environment variables set for your AKS cluster.

## Add a CPU user node pool

Add a CPU user node pool to your AKS cluster:

```bash
az aks nodepool add \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$CLUSTER_NAME" \
  --name cpupool \
  --node-count 1 \
  --node-vm-size Standard_D2s_v3 \
  --mode User
```

Wait for the node to become ready:

```bash
kubectl wait \
  --for=condition=Ready nodes \
  --selector kubernetes.azure.com/agentpool=cpupool \
  --timeout=10m
```

The managed Kueue extension creates an `aks-cpu` ResourceFlavor for eligible CPU user nodes. A `ClusterQueue` can use this ResourceFlavor to associate queue quota with those nodes.

> [!NOTE]
> The managed Kueue extension manages resources prefixed with `aks-`, such as `aks-cpu`. Use these resources in your Kueue configuration instead of creating replacements with the same `aks-` prefix.

## Create a ClusterQueue and LocalQueue

Kueue uses two queue resources: a `ClusterQueue` and a `LocalQueue`. A `ClusterQueue` defines cluster-level resource quotas and admission policies. A `LocalQueue` provides a namespaced queue that workloads reference when submitting work.

You can combine the automatically generated `aks-cpu` ResourceFlavor with workload priority and preemption policies in the same `ClusterQueue`. This configuration lets workloads share managed CPU capacity while giving higher-priority workloads access to constrained quota when needed.

This configuration:

1. Provides the `ClusterQueue` with three CPUs of nominal quota through the automatically generated `aks-cpu` ResourceFlavor.
2. Creates the `kueue-demo-queue` `LocalQueue` for workloads in the `kueue-demo` namespace.
3. Sets `withinClusterQueue` to `LowerPriority`, which allows a higher-priority workload to reclaim quota from a lower-priority workload in the same `ClusterQueue`.

Create a file named `kueue-demo.yaml` with the following configuration:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kueue-demo
---
apiVersion: kueue.x-k8s.io/v1beta2
kind: ClusterQueue
metadata:
  name: kueue-demo-cq
spec:
  namespaceSelector: {}
  queueingStrategy: BestEffortFIFO
  preemption:
    withinClusterQueue: LowerPriority
  resourceGroups:
  - coveredResources:
    - cpu
    flavors:
    - name: aks-cpu
      resources:
      - name: cpu
        nominalQuota: "3"
---
apiVersion: kueue.x-k8s.io/v1beta2
kind: LocalQueue
metadata:
  name: kueue-demo-queue
  namespace: kueue-demo
spec:
  clusterQueue: kueue-demo-cq
Apply the configuration:
```

```batch
kubectl apply -f kueue-demo.yaml
```

## Use workload priority and preemption

When you submit workloads to the `LocalQueue`, you can assign one of the managed workload priority classes:

* Use `aks-high-priority` for workloads that should receive constrained queue capacity ahead of lower-priority work.
* Use `aks-medium-priority` for workloads with standard priority requirements.
* Use `aks-low-priority` for workloads that can wait when queue capacity is constrained.

When you configure `withinClusterQueue` to `LowerPriority`, a higher-priority workload can preempt a lower-priority workload when both workloads require quota from the same `ClusterQueue`. When quota becomes available again, the lower-priority workload remains eligible for admission.

This approach lets you use AKS-managed ResourceFlavors and priority classes without creating and maintaining custom ResourceFlavor or workload priority resources.

## Next steps

After you configure a `ClusterQueue` and `LocalQueue` with the automatically generated ResourceFlavor, and default priority classes, submit and schedule workloads by using your configured queues.

> [!div class="nextstepaction"]
> LINK-TO-SCHEDULING-ARTICLE

<!-- LINKS -->
[install-helm]: https://helm.sh/docs/intro/install/
