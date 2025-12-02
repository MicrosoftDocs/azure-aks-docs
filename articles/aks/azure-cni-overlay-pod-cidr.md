---
title: Expand Pod CIDR Space in Azure CNI Overlay Clusters on Azure Kubernetes Service (AKS)
description: Learn how to expand Pod CIDR space in AKS CNI Overlay clusters with Linux nodes and validate the new Pod CIDR block.
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 08/16/2024
# Customer intent: "As a Kubernetes administrator, I want to learn about Pod CIDR expansion in AKS Overlay clusters so that I can manage and scale my cluster's networking effectively."
---

# Pod CIDR expansion in Azure CNI Overlay clusters on Azure Kubernetes Service (AKS)

You can expand your Pod CIDR space on AKS Overlay clusters with Linux nodes only. The operation uses the [`az aks update`](/cli/azure/aks#az_aks_update) command and allows expansions without the need to recreate your AKS cluster.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Limitations

- Windows nodes and hybrid node scenarios aren't supported.
- This feature is currently only supported with Kubernetes version 1.33.
- Only expansion is allowed without changing the base IP. Shrinking or changing the pod CIDR returns an error.
- Adding a discontinuous pod CIDR isn't supported. The new pod CIDR must be a larger superset that contains the complete original range.
- IPv6 pod CIDR expansion isn't supported.
- Changing multiple pod CIDR blocks via `--pod-cidrs` isn't supported.
- If an [Azure Availability Zone](./availability-zones.md) is down during the expansion operation, new nodes might appear as _unready_. You can expect these nodes to reconcile once the availability zone is up.

## Prerequisites

- An Azure subscription. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/) before you begin.
- Azure CLI version 2.48.0 or later. To install or upgrade Azure CLI, see [Install Azure CLI](/cli/azure/install-azure-cli).
- An existing [AKS cluster using Azure CNI Overlay networking](./azure-cni-overlay.md) with Linux nodes.
- The [`EnableAzureCNIOverlayPodCIDRExpansion` feature flag registered](#register-the-enableazurecnioverlaypodcidrexpansion-feature-flag) in your subscription.

### Register the `EnableAzureCNIOverlayPodCIDRExpansion` feature flag

1. Register the `EnableAzureCNIOverlayPodCIDRExpansion` feature flag using the [`az feature register`](/cli/azure/feature#az_feature_register) command.

    ```azurecli-interactive
    az feature register --namespace Microsoft.ContainerService --name EnableAzureCNIOverlayPodCIDRExpansion
    ```

1. Verify successful registration using the [`az feature show`](/cli/azure/feature#az_feature_show) command. It takes a few minutes for the registration to complete.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "EnableAzureCNIOverlayPodCIDRExpansion"
    ```

1. Once the feature shows `Registered`, refresh the registration of the `Microsoft.ContainerService` resource provider using the [`az provider register`](/cli/azure/provider#az_provider_register) command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

## Expand pod CIDR on an AKS Overlay cluster

- Starting from a Pod CIDR block of `10.244.0.0/18`, you can expand the pod CIDR space using the [`az aks update`](/cli/azure/aks#az_aks_update) command. For example:

    ```azurecli-interactive
    # Set environment variables
    RESOURCE_GROUP=<your-resource-group>
    CLUSTER_NAME=<your-aks-cluster-name>
    
    # Update the pod CIDR to a larger block
    az aks update \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --pod-cidr 10.244.0.0/16
    ```

    > [!NOTE]
    > Although the update operation might successfully complete and show the new pod CIDR in the network profile, make sure to [validate the new cluster state through the `NodeNetworkConfig`](#validate-new-pod-cidr-block).

## Validate new pod CIDR block

- Verify the state of the upgrade operation by checking the `NodeNetworkConfig` to view the state using the `kubectl get` command.

    ```bash-interactive
    kubectl get nnc -A -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.networkContainers[0].subnetAddressSpace}{"\n"}{end}'
    ```

    Your output should reflect the new Pod CIDR block, as shown in the following example output:

    ```output
    aks-nodepool1-12345678-vmss000000 10.244.0.0/16
    aks-nodepool1-12345678-vmss000001 10.244.0.0/16
    aks-nodepool1-12345678-vmss000002 10.244.0.0/16
    ```

## Related content

- To learn more about Azure CNI Overlay networking, see [Azure Container Networking Interface (CNI) Overlay networking in Azure Kubernetes Service (AKS) overview](./concepts-network-azure-cni-overlay.md).
- To learn how to upgrade existing clusters to Azure CNI Overlay, see [Upgrade Azure CNI IPAM modes and data plane technology](./upgrade-azure-cni.md).
