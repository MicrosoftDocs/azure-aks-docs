---
title: AKS Automatic cluster SKU Migration
description: Learn how to migrate to or from an Azure Kubernetes Service (AKS) Automatic cluster with managed system node pool.
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 07/24/2026
author: wangyira
ms.author: wangamanda

---

# Migrate between AKS Automatic and AKS Base Clusters

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

This article shows you how to migrate to or from an [Azure Kubernetes Service (AKS) Automatic with managed system node pool](./aks-automatic-managed-system-node-pools-about.md). 

> [!NOTE]
> This article covers migrating an AKS Automatic cluster with a managed system node pool to an AKS Standard (`base` SKU) cluster. Other migration paths, such as migrating from an AKS Standard cluster to an AKS Automatic cluster with a managed system node pool and migrating from an AKS Automatic cluster without a managed system node pool to one with a managed system node pool, are coming soon.

## Migrate from AKS Automatic cluster with managed system node pool to AKS Standard Cluster (Base SKU)

### How the migration works

An AKS Automatic cluster with a managed system node pool runs its system components on a system node pool that AKS provisions, scales, and upgrades for you. 

> [!IMPORTANT]
> An AKS Standard (`base` SKU) cluster doesn't enable managed system node pool, so you're responsible for running, managing, and upgrading the system node pool and the system components.

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
