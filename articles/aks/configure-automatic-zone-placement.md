---
title: Automatic zone placement in Azure Kubernetes Service (Preview)
description: Learn how to use automatic zone placement (--zones auto) to let AKS dynamically select availability zones for your node pools.
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 07/23/2026
author: yudian
ms.author: yudian
# Customer intent: "As a cloud architect, I want AKS to automatically select the optimal availability zones for my node pools, so that I don't have to track zone availability per region or SKU and my deployments stay resilient as Azure adds zone capacity."
---

# Automatic zone placement in Azure Kubernetes Service (Preview)

Automatic zone placement in Azure Kubernetes Service (AKS) dynamically selects the best set of [availability zones][availability-zones] for a node pool. You don't need to specify the zones manually for each region and VM SKU combination. When you create or update a node pool with `--zones auto`, AKS places virtual machines (VMs) in availability zones that have capacity for the requested SKU in the target region and applies a maximum instance percentage of 50% per zone.


This article shows you how to create or update AKS node pools that use automatic zone placement.

## How automatic zone placement works

When you specify `--zones auto` (or `availabilityZones: ["auto"]` in the agent pool profile), AKS uses the Azure Compute automatic zone placement policy to select zones and distribute nodes. You don't need to specify zone numbers or maintain different zone configurations for each region and VM SKU.

Automatic zone placement works as follows:

1. AKS evaluates which availability zones in the target region can support the requested VM SKU.
1. AKS initially selects up to three available zones and places nodes according to the automatic zone placement policy. By default, no single zone can contain more than 50% of the node pool.
1. During later scale-out operations, AKS reevaluates zone availability. If Azure adds a zone to the region or makes the VM SKU available in another zone, AKS might place new nodes in that zone when the placement policy and available capacity allow it. You don't need to update the node pool configuration.

> [!IMPORTANT]
> The 50% limit is a maximum concentration per zone, not a guarantee that nodes are always distributed equally. The actual distribution depends on the node count, the zones that support the selected VM SKU, and the capacity available when nodes are provisioned. A create or scale operation can still fail if Azure can't allocate the requested nodes while honoring the per-zone limit.

This approach addresses common pain points with manually specifying zones:

- **Region-agnostic deployments**: Use consistent configurations across regions without worrying about zone availability differences.
- **Improved resilience**: Automatically achieve multizone redundancy for better application availability.
- **Automatic zone expansion**: Seamlessly leverage new availability zones when regions expand (for example, from three to four zones).
- **Reduced deployment failures**: Reduce creation and scaling allocation failures caused by capacity constraints in specific zone based on your workload tolerance of zonal balancing.

## Limitations and considerations

- Automatic zone placement supports creating and updating both Virtual Machine Scale Sets-based and Virtual Machines-based node pools.
- The default per-zone cap is 50% of nodes.
- Automatic zone placement is intended for [zone-spanning][zone-spanning] workloads. For [zone-aligned][zone-aligned] workloads (where each node pool is pinned to a single zone), continue specifying the zone explicitly by using `--zones 1`, `--zones 2`, and so on.

## Prerequisites

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

- AKS API version `2026-01-02-preview` or later.
- The latest version of the [aks-preview Azure CLI extension][aks-preview-extension].
- A region that supports availability zones. For more information, see the [List of Azure regions][azure-regions].
- The `VmssAutomaticZonePlacement` feature flag registered in your subscription. Register the feature flag by using the [`az feature register`][az-feature-register] command:

  ```azurecli-interactive
  az feature register \
    --namespace Microsoft.Compute \
    --name VmssAutomaticZonePlacement
  ```

  Check the registration status by using the [`az feature show`][az-feature-show] command:

  ```azurecli-interactive
  az feature show \
    --namespace Microsoft.Compute \
    --name VmssAutomaticZonePlacement \
    --query properties.state \
    --output tsv
  ```

  Wait until the command returns `Registered` before you continue.

## Create an AKS cluster with automatic zone placement (Preview)

Create a new AKS cluster with a Virtual Machine Scale Sets-based or [Virtual Machines-based][vm-node-pools] system node pool that uses automatic zone placement by using the [`az aks create`][az-aks-create] command with `--zones auto`:

```azurecli-interactive
az aks create \
  --resource-group example-rg \
  --name example-cluster \
  --node-vm-size Standard_D8s_v5 \
  --node-count 10 \
  --zones auto
```

AKS picks the zones that have capacity for `Standard_D8s_v5` in the target region and spreads the 10 nodes across them, with no single zone holding more than 50% of the nodes.

## Add a node pool with automatic zone placement (Preview)

Add a new Virtual Machine Scale Sets-based or [Virtual Machines-based][vm-node-pools] node pool to an existing cluster by using the [`az aks nodepool add`][az-aks-nodepool-add] command with `--zones auto`:

```azurecli-interactive
az aks nodepool add \
  --resource-group example-rg \
  --cluster-name example-cluster \
  --name userpoolauto \
  --node-vm-size Standard_D8s_v5 \
  --node-count 6 \
  --zones auto
```

## Update an existing node pool to use automatic zone placement (Preview)

Update an existing Virtual Machine Scale Sets-based or [Virtual Machines-based][vm-node-pools] node pool to use automatic zone placement by using the [`az aks nodepool update`][az-aks-nodepool-update] command with `--zones auto`:

```azurecli-interactive
az aks nodepool update \
  --resource-group example-rg \
  --cluster-name example-cluster \
  --name nodepool1 \
  --zones auto
```

AKS updates the existing node pool through a rolling operation:

1. AKS adds surge nodes that use automatic zone placement.
1. AKS cordons and drains the existing nodes.
1. AKS removes the existing nodes after their workloads move to the surge nodes.

The operation honors the following upgrade settings that you configure on the node pool:

- **Max surge (`--max-surge`)**: Controls how many extra nodes AKS adds during the update. A higher value completes the update faster but requires more compute quota and subnet IP capacity.
- **Node drain timeout (`--drain-timeout`)**: Controls how long AKS waits for pod eviction on a node before the drain operation fails.
- **Node soak duration (`--node-soak-duration`)**: Controls how long AKS waits after a new node becomes ready before continuing to the next batch.

Before you start the update, make sure that you have enough compute quota and subnet IP capacity for the surge nodes and that your pod disruption budgets allow nodes to drain.

## Verify zone placement

After creating or updating the cluster or node pool, verify the zones that AKS selected by using the [`az aks show`][az-aks-show] command.

```azurecli-interactive
az aks show \
 --name example-cluster \
 --resource-group example-rg \
 --query agentPoolProfiles[].availabilityZones \
 --output tsv
```

You can also use `kubectl` to confirm node distribution across zones.  

```bash
kubectl get nodes -o custom-columns='NAME:metadata.name, REGION:metadata.labels.topology\.kubernetes\.io/region, ZONE:metadata.labels.topology\.kubernetes\.io/zone'
```

Example output:

```output
NAME                                REGION   ZONE
aks-nodepool1-12345678-vmss000000   eastus   eastus-1
aks-nodepool1-12345678-vmss000001   eastus   eastus-2
aks-nodepool1-12345678-vmss000002   eastus   eastus-3
...
```

## Related content

- [Configure availability zones in Azure Kubernetes Service (AKS)][configure-availability-zones]
- [Zone resiliency recommendations for AKS][zone-resiliency-recommendations]
- [Reliability in AKS][reliability-aks]
- [Cluster autoscaler in AKS][cluster-autoscaler]

<!-- LINKS - internal -->
[availability-zones]: /azure/reliability/availability-zones-overview
[azure-regions]: /azure/reliability/regions-list
[cluster-autoscaler]: ./cluster-autoscaler-overview.md
[configure-availability-zones]: ./reliability-availability-zones-configure.md
[reliability-aks]: /azure/reliability/reliability-aks
[vm-node-pools]: ./virtual-machines-node-pools.md
[zone-aligned]: ./reliability-availability-zones-configure.md#zone-aligned-node-pools
[zone-resiliency-recommendations]: ./reliability-zone-resiliency-recommendations.md
[zone-spanning]: ./reliability-availability-zones-configure.md#zone-spanning-node-pools
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[az-aks-show]: /cli/azure/aks#az-aks-show
[aks-preview-extension]: /cli/azure/azure-cli-extensions-list
