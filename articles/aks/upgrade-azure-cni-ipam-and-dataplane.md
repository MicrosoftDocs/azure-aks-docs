---
title: Upgrade Azure CNI IPAM modes and Dataplane Technology
description: Learn how to upgrade existing Azure Kubernetes Service (AKS) clusters IPAM modes and dataplane technology.
author: msftjonw
ms.author: jonw
ms.subservice: aks-networking
ms.topic: how-to
ms.custom: references_regions, devx-track-azurecli
ms.date: 11/26/2024
---

# Upgrade Azure CNI IPAM modes and Dataplane Technology

There are always new IP assignment management (IPAM) modes and dataplane technology supporting Azure Kubernetes Service (AKS). Existing AKS clusters inevitably need to upgrade to newer IPAM modes and dataplane technology to access the latest features and supportability. This article provides guidance on upgrading an existing AKS cluster to use Azure CNI overlay for IPAM mode and Azure CNI powered by Cilium as its dataplane.

## Upgrade to Azure CNI Overlay

> [!NOTE]
> You can update an existing Azure CNI cluster to Overlay if the cluster meets the following criteria:
>
> - The cluster is on Kubernetes version 1.22+.
> - Doesn't use the dynamic pod IP allocation feature.
> - Doesn't have network policies enabled. Network Policy engine can be uninstalled before the upgrade, see [Uninstall Azure Network Policy Manager or Calico](use-network-policies.md#uninstall-azure-network-policy-manager-or-calico).
> - Doesn't use any Windows node pools with docker as the container runtime.

> [!NOTE]
> Upgrading an existing cluster to CNI Overlay is an irreversible process.

> [!WARNING]
> Before Windows OS Build 20348.1668, there was a limitation around Windows Overlay pods incorrectly SNATing packets from host network pods, which had a more detrimental effect for clusters upgrading to Overlay. To avoid this issue, **use Windows OS Build greater than or equal to 20348.1668**.

> [!WARNING]
> If using a custom azure-ip-masq-agent config to include additional IP ranges that shouldn't SNAT packets from pods, upgrading to Azure CNI Overlay can break connectivity to these ranges. Pod IPs from the overlay space is unreachable by anything outside the cluster nodes.
> Additionally, for sufficiently old clusters there might be a ConfigMap left over from a previous version of azure-ip-masq-agent. If this ConfigMap, named `azure-ip-masq-agent-config`, exists, and isn't intentionally in-place it should be deleted before running the update command.
> If not using a custom ip-masq-agent config, only the `azure-ip-masq-agent-config-reconciled` ConfigMap should exist with respect to Azure ip-masq-agent ConfigMaps and is updated automatically during the upgrade process.

The upgrade process triggers each node pool to be reimaged simultaneously. Upgrading each node pool separately to Overlay isn't supported. Any disruptions to cluster networking are similar to a node image upgrade or Kubernetes version upgrade where each node in a node pool is reimaged.

### Azure CNI Cluster Upgrade

Update an existing Azure CNI cluster to use Overlay using the [`az aks update`][az-aks-update] command.

```azurecli-interactive
clusterName="myOverlayCluster"
resourceGroup="myResourceGroup"
location="westcentralus"

az aks update --name $clusterName \
--resource-group $resourceGroup \
--network-plugin-mode overlay \
--pod-cidr 192.168.0.0/16
```

The `--pod-cidr` parameter is required when you upgrade from legacy CNI because the pods need to get IPs from a new overlay space, which doesn't overlap with the existing node subnet. The pod CIDR also can't overlap with any VNet address of the node pools. For example, if your VNet address is *10.0.0.0/8*, and your nodes are in the subnet *10.240.0.0/16*, the `--pod-cidr` can't overlap with *10.0.0.0/8* or the existing service CIDR on the cluster.


### Kubenet Cluster Upgrade

Update an existing Kubenet cluster to use Azure CNI Overlay using the [`az aks update`][az-aks-update] command.

```azurecli-interactive
clusterName="myOverlayCluster"
resourceGroup="myResourceGroup"
location="westcentralus"

az aks update --name $clusterName \
--resource-group $resourceGroup \
--network-plugin azure \
--network-plugin-mode overlay 
```

Since the cluster is already using a private CIDR for pods which doesn't overlap with the VNet IP space, you don't need to specify the `--pod-cidr` parameter and the Pod CIDR remains the same if the parameter isn't used.

> [!NOTE]
> When upgrading from Kubenet to CNI Overlay, the route table is no longer required for pod routing. If the cluster is using a customer provided route table, the routes which were being used to direct pod traffic to the correct node is automatically deleted during the migration operation. If the cluster is using a managed route table (AKS creates the route table which lives in the node resource group), then that route table is deleted as part of the migration.


## Upgrade to Azure CNI Powered by Cilium

> [!NOTE]
> You can update an existing cluster to Azure CNI Powered by Cilium if the cluster meets the following criteria:
>
> - The cluster does not have any Windows node pools.
> [!NOTE]
> When you enable Cilium in a cluster with a different network policy engine (Azure NPM or Calico), the network policy engine is uninstalled and replaced with Cilium. For more information, see [Uninstall Azure Network Policy Manager or Calico](./use-network-policies.md#uninstall-azure-network-policy-manager-or-calico).
> [!WARNING]
> The upgrade process triggers each node pool to be reimaged simultaneously. Upgrading each node pool separately isn't supported. Any disruptions to cluster networking are similar to a node image upgrade or [Kubernetes version upgrade](./upgrade-cluster.md) where each node in a node pool is reimaged.
Cilium will begin enforcing network policies only after all nodes are reimaged.

To perform the upgrade, you need Azure CLI version 2.52.0 or later. Run `az --version` to see the currently installed version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).

Use the following command to upgrade an existing cluster to Azure CNI Powered by Cilium. Replace the values for `<clusterName>` and `<resourceGroupName>`:

```azurecli-interactive
az aks update --name <clusterName> --resource-group <resourceGroupName> \
  --network-dataplane cilium
```

<!-- LINKS - Internal -->
[az-aks-update]: /cli/azure/aks#az_aks_update
