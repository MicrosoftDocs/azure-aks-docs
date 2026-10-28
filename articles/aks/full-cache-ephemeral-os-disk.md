---
title: Full Caching Mode for Ephemeral OS Disks in Azure Kubernetes Service (AKS) (Preview)
description: Learn how to enable full caching for ephemeral OS disks in Azure Kubernetes Service (AKS) to improve resiliency and performance.
ms.author: schaffererin
author: schaffererin
ms.topic: how-to
ms.date: 07/17/2026
ms.service: azure-kubernetes-service
# Customer intent: "As a stateful application developer, I want to understand how to enable full caching for ephemeral OS disks in Azure Kubernetes Service (AKS) so that I can improve the resiliency and performance of my applications."
---

# Full caching mode for ephemeral OS disks in Azure Kubernetes Service (AKS) (preview)

Ephemeral OS disks with full caching enhance the standard ephemeral OS disk by fully caching the OS disk onto the local disk. This feature improves the resiliency of general-purpose virtual machines (VMs) and virtual machine scale sets by ensuring the OS disk remains available even during storage disruptions.

This article provides guidance on how to enable full caching for ephemeral OS disks in AKS.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## How full caching works

When you create a VM with full caching enabled, the following actions occur:

- The temporary disk size is reduced by two times the OS disk size, and the freed space is used to create the OS disk.
- The OS disk is cached in the background after the VM boots up. This caching process ensures no impact on VM creation times.

## Limitations

- You can only enable full-cache ephemeral OS disks during node pool creation; you can't update existing node pools to use full caching.
- The feature requires an ephemeral OS disk configuration.
- You can access the feature only through preview AKS API versions and tooling.
- Full-cache ephemeral OS disks are designed for stateless workloads; they're not recommended for stateful workloads.
- The local disk size must be greater than (2x the OS disk size + 1 GiB) to support full caching.
- All VM SKUs are supported except for 2-core and 4-core VMs.

## Prerequisites

- Azure CLI version 2.76.0 or later. Check your version using the `az --version` command. To install or update the Azure CLI, see [Install the Azure CLI](/cli/azure/install-azure-cli).
- AKS REST API version 2026-04-02-preview or later.
- The `aks-preview` extension installed and updated to version 21.0.0.b2 or later. To install or update the `aks-preview` extension, see [Install the `aks-preview` extension](#install-the-aks-preview-extension).
- The `FullCachePreview` feature flag registered on your subscription. To register the feature flag, see [Register the `FullCachePreview` feature flag](#register-the-fullcachepreview-feature-flag).

### Install the `aks-preview` extension

Install the `aks-preview` extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

```azurecli-interactive
az extension add --name aks-preview
```

Update the `aks-preview` extension to the latest version using the [`az extension update`](/cli/azure/extension#az-extension-update) command.

```azurecli-interactive
az extension update --name aks-preview
```

### Register the `FullCachePreview` feature flag

1. Register the `FullCachePreview` feature flag using the [`az feature register`](/cli/azure/feature#az-feature-register) command.

    ```azurecli-interactive
    az feature register --namespace Microsoft.ContainerService --name FullCachePreview
    ```

1. Check the registration status using the [`az feature show`](/cli/azure/feature#az-feature-show) command. The registration process can take several minutes to complete.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name FullCachePreview
    ```

1. After the feature flag is registered, refresh the provider registration using the [`az provider register`](/cli/azure/provider#az-provider-register) command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

## Create a node pool with full-cache ephemeral OS disks

Create a new node pool with full caching enabled for ephemeral OS disks using the [`az aks nodepool add`](/cli/azure/aks/nodepool#az-aks-nodepool-add) command with the `--enable-osdisk-full-caching` flag.

> [!NOTE]
> You can also use the abbreviated flag `--enable-osdisk-fc` to enable full caching.

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<resource-group>
export CLUSTER_NAME=<cluster-name>
export NODE_POOL_NAME=<node-pool-name>

# Create a new node pool with full caching enabled for ephemeral OS disks
az aks nodepool add \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME \
    --name $NODE_POOL_NAME \
    --enable-osdisk-full-caching
```

## Related content

To learn more about storage options for AKS, see the following articles:

- [Best practices for storage and backups in Azure Kubernetes Service (AKS)](./operator-best-practices-storage.md)
- [Best practices for ephemeral NVMe data disks in Azure Kubernetes Service (AKS)](./best-practices-storage-nvme.md)
