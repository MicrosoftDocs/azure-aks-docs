---
title: Update Azure CNI IP Address Management (IPAM) Mode and Data Plane Technology
description: Learn how to update existing Azure Kubernetes Service (AKS) clusters to use the latest Azure CNI IPAM modes and data plane technologies.
author: msftjonw
ms.author: jonw
ms.subservice: aks-networking
ms.topic: how-to
ms.custom: references_regions, devx-track-azurecli
ms.date: 11/26/2024
# Customer intent: As a cloud infrastructure engineer, I want to update existing AKS clusters to use the latest IPAM modes and data plane technologies, so that I can access improved features and ensure optimal performance and supportability.
---

# Update Azure CNI IPAM mode and data plane technology for Azure Kubernetes Service (AKS) clusters

Existing Azure Kubernetes Service (AKS) clusters inevitably need an update to newer IP assignment management (IPAM) modes and data plane technologies to access the latest features and supportability. This article provides guidance on updating an existing AKS cluster to use Azure CNI Overlay for the IPAM mode and Azure CNI Powered by Cilium as the data plane.

## Supported migration path
AKS supports a single, forward‑only networking migration path for existing clusters. Migration is supported to Azure CNI Overlay only. 

The following migrations are the the only supported:
- Azure CNI (Node Subnet) → Azure CNI Overlay
- Kubenet → Azure CNI Overlay

Updating a cluster to Azure CNI Overlay is a one‑way, irreversible operation. After the cluster is updated, it can’t be migrated back to a Node Subnet–based networking mode.

## Update the IPAM mode to Azure CNI Overlay

Updating an existing cluster to Azure CNI Overlay is an irreversible process.

You can update an existing AKS cluster to Azure CNI Overlay if the cluster:

- Is on Kubernetes version 1.27 or later.
- Doesn't use the [dynamic IP allocation](./configure-azure-cni-dynamic-ip-allocation.md) feature.
- Doesn't have network policies enabled. If you need to uninstall the network policy engine before updating your cluster, follow the steps in [Uninstall Azure Network Policy Manager or Calico](use-network-policies.md#uninstall-azure-network-policy-manager-or-calico).
- Doesn't use any Windows node pools with Docker as the container runtime.

Before Windows OS build 20348.1668, there was a limitation around Windows overlay pods incorrectly routing packets from host network pods via Source Network Address Translation (SNAT). This limitation had a detrimental effect for clusters that were updating to Azure CNI Overlay. To avoid this issue, use Windows OS build 20348.1668 or later.

> [!WARNING]
>
> - If you're using a custom `azure-ip-masq-agent` configuration to include additional IP ranges that shouldn't send SNAT packets from pods, updating to Azure CNI Overlay can break connectivity to these ranges. Pod IPs from the overlay space are unreachable by anything outside the cluster nodes.
>
> - For old clusters, a ConfigMap might be left over from a previous version of `azure-ip-masq-agent`. If this ConfigMap (named `azure-ip-masq-agent-config`) exists and isn't intentionally in place, you should delete it before updating.
>
> - If you're not using a custom `ip-masq-agent` configuration, only the `azure-ip-masq-agent-config-reconciled` ConfigMap should exist with respect to Azure `ip-masq-agent` ConfigMap. It's updated automatically during the update process.

The update process triggers node pools to be reimaged simultaneously. Updating each node pool separately to Azure CNI Overlay isn't supported. Any disruptions to cluster networking are similar to a node image update or Kubernetes version upgrade where each node in a node pool is reimaged.

### [Azure CNI](#tab/azure-cni)

Update an existing Azure Container Networking Interface (CNI) cluster to use Azure CNI Overlay by using the [`az aks update`][az-aks-update] command.

```azurecli-interactive
az aks update \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --network-plugin-mode overlay \
  --pod-cidr 192.168.0.0/16
```

The `--pod-cidr` parameter is required when you update from legacy CNI plugins because the pods need to get IPs from a new overlay space. The new overlay space doesn't overlap with the existing Azure CNI Node Subnet plugin.

Classless Inter-Domain Routing (CIDR) for the pod also can't overlap with any virtual network address of the node pools. For example, if your virtual network address is 10.0.0.0/8, and your nodes are in the subnet 10.240.0.0/16, the `--pod-cidr` parameter can't overlap with 10.0.0.0/8 or the existing service CIDR on the cluster.

### [Kubenet](#tab/kubenet)

> [!IMPORTANT]
> Keep the following information in mind when updating from Kubenet to Azure CNI Overlay:
>
> - Clusters with Kubenet networking enabled have an associated route table attached to the VNet to handle routing from the VNet to the cluster. This route table isn't required for Azure CNI Overlay and needs to be detached in order for you to update. To remove the route table, you need a **user-assigned managed identity** on the cluster. System-assigned managed identities aren't supported.
> - If the cluster uses a customer-provided route table, the routes that were used to direct pod traffic to the correct node are automatically deleted during the migration operation.
> - If the cluster uses a managed route table (AKS creates the route table in the node resource group), that route table is deleted as part of the migration.

Update an existing Kubenet cluster to use Azure CNI Overlay by using the [`az aks update`][az-aks-update] command.

```azurecli-interactive
az aks update \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
# --pod-cidr 192.168.0.0/16 \
  --network-plugin azure \
  --network-plugin-mode overlay
```

If you want to expand the pod CIDR to accommodate a larger cluster during the update, specify the new range by using `--pod-cidr`. The pod CIDR remains the same if you don't use the parameter.

### [Azure CNI Node Subnet](#tab/node-subnet)

Update an existing Azure CNI Node Subnet cluster to use Azure CNI Overlay by using the [`az aks update`][az-aks-update] command.

```azurecli-interactive
az aks update \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --network-plugin azure \
  --network-plugin-mode overlay
```

When you update Azure CNI Node Subnet, update either the IPAM networking mode or the data plane. Updating both in a single operation isn't supported.

---

## Update the data plane to Azure CNI Powered by Cilium

Azure CNI Powered by Cilium is the recommended and supported long‑term networking configuration for AKS. It combines Azure CNI control plane with Cilium data plane to deliver scalable networking and advanced security capabilities.

### Update considerations

- The IPAM mode and the data plane can’t be updated in a single operation.
If you plan to migrate to Azure CNI Overlay and Azure CNI Powered by Cilium, you must:
1. Update the IPAM mode to Azure CNI Overlay first.
2. Update the data plane to Azure CNI Powered by Cilium as a separate operation.
- When enabling Cilium on a cluster that uses another network policy engine (Azure Network Policy Manager or Calico), the existing engine is uninstalled and replaced by Cilium. This may impact network policy behavior.For more information, see [Migrate from Network Policy Manager (NPM) to Cilium Network Policy] (./migrate-from-npm-to-cilium-network-policy.md)
- Updating the data plane to Azure CNI Powered by Cilium isn’t supported on clusters with Windows node pools.
- Clusters with node auto-provisioning (NAP) enabled can’t be updated to Azure CNI Powered by Cilium.As a workaround, disable NAP before the update, then re‑enable it after the update completes.

> [!WARNING]
> The update process triggers node pools to be reimaged simultaneously. Updating each node pool separately isn't supported. Any disruptions to cluster networking are similar to a node image update or [Kubernetes version upgrade](./upgrade-cluster.md) where each node in a node pool is reimaged. Cilium begins enforcing network policies only after all nodes are reimaged.

To perform the update, you need Azure CLI version 2.52.0 or later. Run `az --version` to see the currently installed version. If you need to install or upgrade, see [Install the Azure CLI](/cli/azure/install-azure-cli).

Update an existing cluster to Azure CNI Powered by Cilium by using the [`az aks update`][az-aks-update] command.

```azurecli-interactive
az aks update \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --network-dataplane cilium
```

<!-- LINKS - Internal -->
[az-aks-update]: /cli/azure/aks#az-aks-update
