---
title: Expand Pod CIDR Space in Azure CNI Overlay Azure Kubernetes Service (AKS) Clusters
description: Learn how to expand pod CIDR space in Azure CNI Overlay AKS clusters with Linux nodes and validate the new pod CIDR block.
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 08/16/2024
# Customer intent: "As a Kubernetes administrator, I want to learn about pod CIDR expansion in AKS Overlay clusters so that I can manage and scale my cluster's networking effectively."
---

# Expand pod CIDR space in Azure CNI Overlay Azure Kubernetes Service (AKS) clusters

You can expand your pod Classless Inter-Domain Routing (CIDR) space on Azure CNI Overlay clusters in Azure Kubernetes Service with Linux nodes only. The operation uses the [`az aks update`](/cli/azure/aks#az_aks_update) command and allows expansions without the need to re-create your AKS cluster.

## Requirements and parameters

| Requirement or parameter | Supported versions or values | Description |
| ------------------------ | ---------------------------- | ----------- |
| Azure CLI version | 2.48.0 or later | The Azure CLI version must be 2.48.0 or later to support the pod CIDR expansion feature. |
| Node operating system | Linux | Pod CIDR expansion is supported only on Azure CNI Overlay AKS clusters with Linux nodes. |
| Networking mode | Azure CNI Overlay | Pod CIDR expansion is supported only on AKS clusters that use Azure CNI Overlay networking. |
| Example original pod CIDR | `10.244.0.0/18` | This is an example of a starting pod CIDR block. |
| Example expanded pod CIDR | `10.244.0.0/16` | This is an example of a target expanded pod CIDR block. |

## Limitations

- Windows nodes and hybrid node scenarios aren't supported.
- Shrinking or changing the pod CIDR isn't supported.
- Adding a discontinuous pod CIDR isn't supported. The new pod CIDR must be a larger superset that contains the complete original range.
- IPv6 pod CIDR expansion isn't supported.
- Changing multiple pod CIDR blocks via `--pod-cidrs` isn't supported.
- If an [Azure availability zone](./availability-zones.md) is down during the expansion operation, new nodes might appear as `unready`. You can expect these nodes to reconcile after the availability zone is up.

## Prerequisites

- You need an Azure subscription. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/) before you begin.
- Ensure that you meet the requirements listed in the [Requirements and parameters](#requirements-and-parameters) section.

## Update an Azure CNI Overlay AKS cluster to expand the pod CIDR space

1. Starting from a pod CIDR block of `10.244.0.0/18`, you can expand the pod CIDR space by using the [`az aks update`](/cli/azure/aks#az_aks_update) command. For example:

    ```azurecli-interactive
    az aks update \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --pod-cidr 10.244.0.0/16
    ```

    > [!NOTE]
    > Although the update operation might successfully finish and show the new pod CIDR in the network profile, be sure to validate the new cluster state through `NodeNetworkConfig` (`nnc`).

1. Verify the state of the upgrade operation by checking `NodeNetworkConfig` (`nnc`) via the `kubectl get nnc` command. In the output, all node pools should match your new pod CIDR block (for example, `10.244.0.0/16`).

    ```bash-interactive
    kubectl get nnc -A -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.networkContainers[0].subnetAddressSpace}{"\n"}{end}'
    ```

## Related content

To learn more about Azure CNI Overlay networking on AKS, see the following articles:

- [Overview of Azure CNI Overlay networking in Azure Kubernetes Service (AKS)](./concepts-network-azure-cni-overlay.md)
- [Update Azure CNI IPAM mode and data plane technology](./upgrade-azure-cni.md)
