---
title: Configure rolling upgrades for Azure Kubernetes Service (AKS) node pools
description: Learn how to configure and customize rolling upgrades for Azure Kubernetes Service (AKS) node pools, including surge settings, drain timeout, and soak time.
ms.topic: how-to
ms.subservice: aks-upgrade
ms.service: azure-kubernetes-service
ms.date: 12/09/2025
author: kaarthis
ms.author: schaffererin
# Customer intent: "As a cluster operator, I want to configure rolling upgrades for my AKS node pools so that I can upgrade nodes with minimal workload disruption."
---

# Configure rolling upgrades for Azure Kubernetes Service (AKS) node pools

A rolling upgrade strategy upgrades nodes one at a time (or a few at a time), minimizing workload disruption while ensuring the node pool remains available throughout the upgrade process. This article explains how to configure rolling upgrades for AKS node pools, including surge settings, drain timeout, and soak time.

## Before you begin

- Ensure your control plane is already upgraded to the target Kubernetes version. You can't upgrade node pools to a version higher than the control plane. For more information, see [Upgrade the AKS cluster control plane](./upgrade-aks-control-plane.md).
- If you're using the Azure CLI, this article requires Azure CLI version 2.34.1 or later. Use the `az --version` command to find the version. If you need to install or upgrade, see [Install Azure CLI][azure-cli-install].
- You need the `Microsoft.ContainerService/managedClusters/agentPools/write` RBAC role permission to configure rolling upgrades for AKS node pools.

## Overview of rolling upgrade behavior

During a rolling upgrade, AKS performs the following operations for each node in the node pool:

1. **Add surge nodes**: Add new buffer nodes based on max surge (`--max-surge`) settings to maintain capacity during the upgrade.
1. **Cordon and drain nodes**: [Cordon and drain][kubernetes-drain] the old nodes one at a time to minimize disruption to running applications. If you're using max surge, it cordons and drains as many nodes at the same time as the number of buffer nodes specified.
1. **Wait for soak time** (optional): Wait for a configured [soak duration](#set-node-soak-time-value) before proceeding to allow workloads to stabilize on the new nodes before continuing the upgrade.
1. **Reimage old nodes**: When the old nodes are drained, they're reimaged to receive the new version. The reimaged nodes become the buffer nodes for the next set of nodes to be upgraded.
1. **Repeat**: The process repeats until all nodes in the node pool are upgraded.
1. **Remove surge nodes**: After all nodes are upgraded, any remaining buffer nodes are removed, maintaining the original node pool size and balance.

## Configure rolling upgrade settings

### Customize node surge

> [!IMPORTANT]
>
> - Node surges require subscription quota for the requested max surge count for each upgrade operation. For example, a cluster that has five node pools, each with a count of four nodes, has a total of 20 nodes. If each node pool has a max surge value of 50%, extra compute and IP quota of 10 nodes (_two_ nodes × _five_ pools) is required to complete the upgrade.
> - The max surge setting on a node pool is persistent. Subsequent Kubernetes upgrades or node version upgrades use this setting. You can change the max surge value for your node pools at any time. For production node pools, we recommend a max surge setting of 33%.
> - If you're using Azure CNI, validate there are available IPs in the subnet to [satisfy IP requirements of Azure CNI](./configure-azure-cni.md).

AKS configures upgrades to surge with one extra node by default. A default value of _one_ for the max surge setting enables AKS to minimize workload disruption by creating an extra node before the cordon/drain of existing applications to replace an older versioned node. You can customize the max surge value per node pool. When you increase the max surge value, the upgrade process completes faster, but you might experience more disruptions during the upgrade process.

For example, a max surge value of `100%` provides the fastest possible upgrade process but also causes all nodes in the node pool to be drained simultaneously. You might want to use a higher value like this for testing environments. For production node pools, we recommend a max surge setting of `33%`.

AKS accepts both integer values and a percentage value for max surge. For example:

| Value type | Example | Description |
|------------|---------|-------------|
| Integer | `5` | Five extra nodes to surge |
| Percentage | `50%` | Surge value of half the current node count in the pool |

Max surge percent values can be a minimum of `1%` and a maximum of `100%`. A percent value is rounded up to the nearest node count. If the max surge value is higher than the required number of nodes to be upgraded, the number of nodes to be upgraded is used for the max surge value.

#### Set max surge value

Set max surge values for new or existing node pools using the [`az aks nodepool add`][az-aks-nodepool-add] or [`az aks nodepool update`][az-aks-nodepool-update] command with the `--max-surge` parameter. For example:

```azurecli-interactive
# Set max surge for a new node pool
az aks nodepool add \
    --name <node-pool-name> \
    --resource-group <resource-group-name> \
    --cluster-name <cluster-name> \
    --max-surge 33%

# Update max surge for an existing node pool 
az aks nodepool update \
    --name <node-pool-name> \
    --resource-group <resource-group-name> \
    --cluster-name <cluster-name> \
    --max-surge 5
```

### Customize unavailable nodes

> [!IMPORTANT]
>
> - You must set max surge to `0` in order to set a max unavailable value. The two values can't both be active at the same time.
> - Max unavailable doesn't create surge nodes during the upgrade process. Instead, AKS cordons _n_ nodes (the max unavailable value) at a time and evicts the pods to other nodes in the agent pool. This might cause workload disruptions if the pods can't be scheduled.
> - Max unavailable might cause more failures due to unsatisfied Pod Disruption Budgets (PDBs) since there are fewer resources for pods to be scheduled on. For more information, see [Troubleshooting for Pod Disruption Budgets][pdb-troubleshooting].
> - You can't set max unavailable on system node pools.

AKS can also configure upgrades to not use a surge node and upgrade the nodes in place. The max unavailable value determines how many nodes can be simultaneously cordoned and drained from the existing node pool nodes.

AKS accepts both integer values and a percentage value for max unavailable. For example:

| Value type | Example | Description |
|------------|---------|-------------|
| Integer | `5` | Five nodes are cordoned from the existing nodes |
| Percentage | `50%` | Half the current node count in the pool will be unavailable |

Max unavailable percent values can be a minimum of `1%` and a maximum of `100%`. A percent value is rounded up to the nearest node count.

#### Set max unavailable value

Set max unavailable values for new or existing node pools using the [`az aks nodepool add`][az-aks-nodepool-add], [`az aks nodepool update`][az-aks-nodepool-update], or the [`az aks nodepool upgrade`][az-aks-nodepool-upgrade] command with the `--max-unavailable` parameter. For example:

```azurecli-interactive
# Set max unavailable for a new node pool
az aks nodepool add \
    --name <node-pool-name> \
    --resource-group <resource-group-name> \
    --cluster-name <cluster-name> \
    --max-surge 0 \
    --max-unavailable 5

# Update max unavailable for an existing node pool 
az aks nodepool update \
    --name <node-pool-name> \
    --resource-group <resource-group-name> \
    --cluster-name <cluster-name> \
    --max-surge 0 \
    --max-unavailable 5

# Set max unavailable at upgrade time
az aks nodepool upgrade \
    --name <node-pool-name> \
    --resource-group <resource-group-name> \
    --cluster-name <cluster-name> \
    --max-surge 0 \
    --max-unavailable 5
```

### Customize node drain timeout

You might have long-running workloads on certain pods that you can't reschedule to another node during runtime. For example, a memory-intensive stateful workload that must finish running. In these cases, you can configure a node drain timeout that AKS respects in the upgrade workflow.

The default node drain timeout value is 30 minutes. Node drain timeout values can be a minimum of 5 minutes and a maximum of 24 hours.

If the drain timeout value elapses and pods are still running, the upgrade operation stops. Any subsequent `PUT` operation resumes the stopped upgrade.

> [!TIP]
> For long-running pods, you should also configure the [`terminationGracePeriodSeconds`](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/) in your pod spec.

#### Set node drain timeout value

Set node drain timeout (in minutes) for new or existing node pools using the [`az aks nodepool add`][az-aks-nodepool-add] or [`az aks nodepool update`][az-aks-nodepool-update] command with the `--drain-time-out` parameter.

```azurecli-interactive
# Set drain timeout for a new node pool
az aks nodepool add \
    --name <node-pool-name> \
    --resource-group <resource-group-name> \
    --cluster-name <cluster-name> \
    --drain-time-out 100

# Update drain timeout for an existing node pool
az aks nodepool update \
    --name <node-pool-name> \
    --resource-group <resource-group-name> \
    --cluster-name <cluster-name> \
    --drain-time-out 45
```

### Customize node soak time

To enable a waiting period for a specified duration of time between draining a node and proceeding to reimage it and move on to the next node, you can set the soak time. This soak time gives you the opportunity to perform other tasks during the upgrade process, such as checking application health from a monitoring dashboard.

The default node soak time is 0 minutes. Node soak time values can be a minimum of 0 minutes and a maximum of 30 minutes. We recommend keeping soak time as short as reasonably possible. A higher node soak time increases the total upgrade duration and delays discovery of issues.

#### Set node soak time value

Set node soak time (in minutes) for new or existing node pools using the [`az aks nodepool add`][az-aks-nodepool-add], [`az aks nodepool update`][az-aks-nodepool-update], or [`az aks nodepool upgrade`][az-aks-nodepool-upgrade] command with the `--node-soak-duration` flag.

```azurecli-interactive
# Set node soak time for a new node pool
az aks nodepool add \
    --name <node-pool-name> \
    --resource-group <resource-group-name> \
    --cluster-name <cluster-name> \
    --node-soak-duration 10

# Update node soak time for an existing node pool
az aks nodepool update \
    --name <node-pool-name> \
    --resource-group <resource-group-name> \
    --cluster-name <cluster-name> \
    --max-surge 33% \
    --node-soak-duration 5

# Set node soak time when upgrading an existing node pool
az aks nodepool upgrade \
    --name <node-pool-name> \
    --resource-group <resource-group-name> \
    --cluster-name <cluster-name> \
    --max-surge 33% \
    --node-soak-duration 20
```

## View AKS node upgrade events

View upgrade events using the `kubectl get events` command to monitor the rolling upgrade progress.

```bash
kubectl get events --field-selector reason=Drain,reason=Surge,reason=Upgrade
```

Example output during an upgrade event:

```output
default  2m1s  Normal  Drain    node/aks-nodepool1-12345678-vmss000001  Draining node: [aks-nodepool1-12345678-vmss000001]
default  9m22s Normal  Surge    node/aks-nodepool1-12345678-vmss000002  Created a surge node [aks-nodepool1-12345678-vmss000002 nodepool1] for agentpool nodepool1
default  1m45s Normal  Upgrade  node/aks-nodepool1-12345678-vmss000001  Soak duration 5m0s after draining node: aks-nodepool1-12345678-vmss000001
```

## Recommended AKS node pool upgrade settings for production workloads

The following table outlines recommended node pool upgrade settings for production workloads:

| Setting | Recommendation |
|----------|----------------|
| **Max surge** | Set to 33% for production node pools |
| **Drain timeout** | Configure based on your longest-running pod's requirements |
| **Soak time** | Use a short duration (0-5 minutes) unless you need manual verification |
| **Pod Disruption Budgets** | Configure PDBs for critical workloads to control pod eviction |
| **Upgrade order** | Upgrade non-production node pools first to validate the new version |

## Related content

- [Configure automatic cluster upgrades](./auto-upgrade-cluster.md)
- [Upgrade the AKS cluster control plane](./upgrade-aks-control-plane.md)
- [Upgrade node OS images](./node-image-upgrade.md)

<!-- LINKS - internal -->
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[az-aks-nodepool-upgrade]: /cli/azure/aks/nodepool#az-aks-nodepool-upgrade
[pdb-troubleshooting]: /troubleshoot/azure/azure-kubernetes/create-upgrade-delete/error-code-poddrainfailure

<!-- LINKS - external -->
[kubernetes-drain]: https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/
