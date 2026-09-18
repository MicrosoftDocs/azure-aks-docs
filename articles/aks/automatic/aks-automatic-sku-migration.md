---
title: Migrate AKS Automatic clusters and managed system node pools
description: Learn how to migrate AKS Automatic clusters between managed system node pool and AKS Standard configurations.
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 09/08/2026
author: wangyira
ms.author: wangamanda

---

# Migrate AKS Automatic clusters and managed system node pools

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

This article shows you how to migrate AKS Automatic clusters between supported [managed system node pool](./aks-automatic-managed-system-node-pools-about.md) and AKS Standard configurations.

## Supported migration paths

| Migration path | Support |
|---|---|
| AKS Automatic with managed system node pools to AKS Standard (`base` SKU) | Supported |
| AKS Automatic without managed system node pools to AKS Automatic with managed system node pools | Supported in preview in regions where managed system node pools are generally available |
| AKS Standard (`base` SKU) to AKS Automatic with managed system node pools | Coming soon |
| AKS Automatic with managed system node pools to AKS Automatic without managed system node pools | Not supported |

## Migrate from an AKS Automatic cluster with managed system node pools to an AKS Standard cluster

### How the migration works

An AKS Automatic cluster with managed system node pools runs its system components on system node pools that AKS provisions, scales, and upgrades for you.

> [!IMPORTANT]
> An AKS Standard (`base` SKU) cluster doesn't enable managed system node pools, so you're responsible for running, managing, and upgrading the system node pool and the system components.

To migrate from AKS Automatic to AKS Standard, complete the following high-level steps:

1. Add a self-managed system node pool to your AKS Automatic cluster.
1. Update the cluster SKU from `automatic` to `base`.

After you update the SKU, the cluster runs as an AKS Standard cluster, and your system components run on the system node pool that you added and manage.

### Migrate to an AKS Standard cluster

1. Add a self-managed system node pool to your existing AKS Automatic cluster by using the [`az aks nodepool add`](/cli/azure/aks/nodepool#az-aks-nodepool-add) command. Set the node pool mode to `System` so it can run system components after migration.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group "${RESOURCE_GROUP}" \
        --cluster-name "${RESOURCE_NAME}" \
        --name systempool \
        --mode System \
        --node-count 3
    ```

1. Update the cluster SKU from `automatic` to `base` by using the [`az aks update`](/cli/azure/aks#az-aks-update) command.

    ```azurecli-interactive
    az aks update \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${RESOURCE_NAME}" \
        --sku base
    ```

### Verify the migration

1. Confirm that the cluster now uses the `base` SKU by using the [`az aks show`](/cli/azure/aks#az-aks-show) command.

    ```azurecli-interactive
    az aks show \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${RESOURCE_NAME}" \
        --query "sku" \
        --output table
    ```

1. List the node pools on the cluster to confirm your self-managed system node pool is present and in the `System` mode by using the [`az aks nodepool list`](/cli/azure/aks/nodepool#az-aks-nodepool-list) command.

    ```azurecli-interactive
    az aks nodepool list \
        --resource-group "${RESOURCE_GROUP}" \
        --cluster-name "${RESOURCE_NAME}" \
        --query "[].{Name:name, Mode:mode, Count:count}" \
        --output table
    ```

## Migrate from an AKS Automatic cluster without managed system node pools to AKS Automatic with managed system node pools (preview)

AKS Automatic supports preview migration from non-managed system node pools to managed system node pools in regions where managed system node pools are generally available. This migration keeps the cluster on the `automatic` SKU and moves AKS system components to a system node pool managed by AKS.

### Prerequisites

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

- An existing AKS Automatic cluster without managed system node pools.
- Azure CLI version 2.86.0 or later. To find the version, run `az --version`. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
- The latest version of the `aks-preview` Azure CLI extension.
- The `Microsoft.ContainerService/NonHoboToHoboConversionPreview` feature flag registered in your subscription.

Register the `NonHoboToHoboConversionPreview` feature flag by using the [`az feature register`](/cli/azure/feature#az-feature-register) command:

```azurecli-interactive
az feature register \
    --namespace Microsoft.ContainerService \
    --name NonHoboToHoboConversionPreview
```

Check the registration status by using the [`az feature show`](/cli/azure/feature#az-feature-show) command:

```azurecli-interactive
az feature show \
    --namespace Microsoft.ContainerService \
    --name NonHoboToHoboConversionPreview \
    --query properties.state \
    --output tsv
```

Wait until the command returns `Registered` before you continue. Then, refresh the `Microsoft.ContainerService` resource provider registration.

```azurecli-interactive
az provider register --namespace Microsoft.ContainerService
```

Install or update the `aks-preview` extension:

```azurecli-interactive
az extension add --name aks-preview
az extension update --name aks-preview
```

### Migrate an AKS-managed virtual network cluster

For an AKS Automatic cluster that uses AKS-managed networking, migrate to managed system node pools by using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--enable-hosted-system` parameter:

```azurecli-interactive
az aks update \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${RESOURCE_NAME}" \
    --enable-hosted-system
```

### Migrate a custom virtual network cluster

For an AKS Automatic cluster that uses a custom virtual network, provide a subnet for the managed system node pool by using the `--system-node-subnet-id` parameter. The system node subnet must:

- Be in the same virtual network and region as the cluster.
- Be at least `/26`.
- Not be delegated to another service.
- Be different from the node subnet.

The `--node-subnet-id` parameter is optional. If you don't provide it, AKS uses the existing system node pool subnet.

```azurecli-interactive
az aks update \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${RESOURCE_NAME}" \
    --enable-hosted-system \
    --system-node-subnet-id "${SYSTEM_NODE_SUBNET_ID}" \
    --node-subnet-id "${NODE_SUBNET_ID}"
```

### Verify the migration

Confirm the cluster uses managed system node pools by using the [`az aks show`](/cli/azure/aks#az-aks-show) command:

```azurecli-interactive
az aks show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${RESOURCE_NAME}" \
    --query hostedSystemProfile \
    --output json
```

The following example output shows the `hostedSystemProfile.enabled` property set to `true`:

```output
{
  "enabled": true,
  "nodeSubnetId": "<node-subnet-resource-id>",
  "systemNodeSubnetId": "<system-node-subnet-resource-id>"
}
```
