---
title: Configure Node Disruption Policy in Azure Kubernetes Service (AKS) (Preview)
description: Learn how to configure and manage Node Disruption Policy to control when operations that require node reimage are allowed in Azure Kubernetes Service (AKS).
author: yudian
ms.author: yudian
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.custom: devx-track-azurecli
ms.date: 03/11/2026
# Customer intent: As a cluster operator, I want to configure Node Disruption Policy so I can control when disruptive operations that require node reimage are allowed.
---

# Configure Node Disruption Policy in Azure Kubernetes Service (AKS) (Preview)

This article shows you how to configure and manage Node Disruption Policy to control when operations that require node reimage and trigger node redeployment are allowed in your Azure Kubernetes Service (AKS) cluster.

## Prerequisites

- Review the [Node Disruption Policy overview][node-disruption-policy-overview] to learn [how Node Disruption Policy works][how-node-disruption-policy-works] and the [operations covered by Node Disruption Policy][operations-covered-by-node-disruption-policy].
- Azure CLI version 2.76.0 or later installed and configured. To find your CLI version, run the `az --version` command. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
- An existing AKS cluster, or you can create a new one with Node Disruption Policy configured.
- [Install the `aks-preview` Azure CLI extension](#install-the-aks-preview-azure-cli-extension) and [register the Node Disruption Policy preview feature](#register-the-node-disruption-policy-preview-feature).

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

### Install the `aks-preview` Azure CLI extension

1. Install the `aks-preview` extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

2. Update to the latest version of the extension using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the Node Disruption Policy preview feature

Register the Node Disruption Policy preview feature using the [`az feature register`][az-feature-register] command.

az feature register --namespace "Microsoft.ContainerService" --name "NodeDisruptionProfile"

It takes a few minutes for the status to show as *Registered*.

## Configure Node Disruption Policy on a new cluster

Create a new AKS cluster with Node Disruption Policy configured by using the [`az aks create`][az-aks-create] command with the `--node-disruption-policy` parameter set to one of the following policy configurations: [`Allow`](./node-disruption-policy.md#policy-options) (default), [`AllowDuringMaintenanceWindow`](./node-disruption-policy.md#policy-options), or [`Block`](./node-disruption-policy.md#policy-options).

### Allow disruptive operations at any time (default)

```azurecli-interactive
az aks create \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --node-count 3 \
    --node-disruption-policy Allow \
    --generate-ssh-keys
```

### Allow disruptive operations only during maintenance windows

```azurecli-interactive
az aks create \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --node-count 3 \
    --node-disruption-policy AllowDuringMaintenanceWindow \
    --generate-ssh-keys
```

> [!IMPORTANT]
> When you use `AllowDuringMaintenanceWindow`, ensure you configure an `aksManagedNodeOSUpgradeSchedule` maintenance window. Otherwise, disruptive operations are allowed indefinitely. For more information, see [Use planned maintenance to schedule and control upgrades for your Azure Kubernetes Service cluster][planned-maintenance].

### Block all disruptive operations

```azurecli-interactive
az aks create \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --node-count 3 \
    --node-disruption-policy Block \
    --generate-ssh-keys
```

## Update Node Disruption Policy on an existing cluster

Update the Node Disruption Policy on an existing AKS cluster by using the [`az aks update`][az-aks-update] command with the `--node-disruption-policy` parameter set to one of the following policy configurations: [`Allow`](./node-disruption-policy.md#policy-options) (default), [`AllowDuringMaintenanceWindow`](./node-disruption-policy.md#policy-options), or [`Block`](./node-disruption-policy.md#policy-options).

### Change policy to allow operations during maintenance windows

```azurecli-interactive
az aks update \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --node-disruption-policy AllowDuringMaintenanceWindow
```

### Change policy to block all disruptive operations

```azurecli-interactive
az aks update \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --node-disruption-policy Block
```

### Change policy back to allow operations at any time

```azurecli-interactive
az aks update \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --node-disruption-policy Allow
```

## Verify Node Disruption Policy configuration

Verify the Node Disruption Policy configuration by using the [`az aks show`][az-aks-show] command.

```azurecli-interactive
az aks show \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --query "nodeDisruptionProfile.nodeDisruptionPolicy" \
    --output tsv
```

The output shows the current policy setting, such as `Allow`, `AllowDuringMaintenanceWindow`, or `Block`.

## Handle blocked operations

When the Node Disruption Policy blocks a disruptive operation, you can [wait for the maintenance window](#wait-for-the-maintenance-window) or [temporarily change the policy](#temporarily-change-the-policy).

### Wait for the maintenance window

If you're using `AllowDuringMaintenanceWindow`, schedule the operation to occur during the next maintenance window. You can view your configured maintenance windows by using the [`az aks maintenanceconfiguration list`](/cli/azure/aks/maintenanceconfiguration#az-aks-maintenanceconfiguration-list) command.

```azurecli-interactive
az aks maintenanceconfiguration list \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster
```

### Temporarily change the policy

1. Update the policy to `Allow` by using the [`az aks update`](/cli/azure/aks#az-aks-update) command with `--node-disruption-policy` set to `Allow`.

    ```azurecli-interactive
    az aks update \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --node-disruption-policy Allow
     ```

1. Perform your disruptive operation. The following example updates the custom CA certificates by using the [`az aks update`](/cli/azure/aks#az-aks-update) command:

    ```azurecli-interactive
    az aks update \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --custom-ca-trust-certificates <path-to-certificate-file>
    ```

1. Restore the original policy by using the [`az aks update`](/cli/azure/aks#az-aks-update) command. The following example restores `--node-disruption-policy` to `Block`:

    ```azurecli-interactive
    az aks update \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --node-disruption-policy Block
    ```

## Operations that require manual node pool upgrade

Some operations that Node Disruption Policy **doesn't control** require a manual node pool upgrade after any configuration changes. These operations include:

- SSH configuration changes, such as changing SSH access methods or updating SSH public keys.
- IMDS restriction changes, such as enabling or disabling IMDS restriction.
- Bootstrap profile ACR name changes for network isolated clusters.
- Outbound type changes, such as changing cluster egress routing.

For these operations, you must manually run the [`az aks nodepool upgrade`](/cli/azure/aks/nodepool#az-aks-nodepool-upgrade) command after making the configuration change. For example:

```azurecli-interactive
az aks nodepool upgrade \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name <nodepool-name> \
    --node-image-only
```

For more information about operations covered by Node Disruption Policy, see the [Node Disruption Policy overview][node-disruption-policy-overview].

## Troubleshoot Node Disruption Policy issues

### Operation blocked unexpectedly

If an operation is blocked unexpectedly, use the following steps to troubleshoot the issue:

1. Check the current policy setting by using the [`az aks show`](/cli/azure/aks#az-aks-show) command.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query "nodeDisruptionProfile.nodeDisruptionPolicy" \
        --output tsv
    ```

1. If you're using `AllowDuringMaintenanceWindow`, verify the maintenance window configuration by using the [`az aks maintenanceconfiguration show`](/cli/azure/aks/maintenanceconfiguration#az-aks-maintenanceconfiguration-show) command.

    ```azurecli-interactive
    az aks maintenanceconfiguration show \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name aksManagedNodeOSUpgradeSchedule
    ```

1. Check if the current time falls within the maintenance window.

### No maintenance window configured

If you set the policy to `AllowDuringMaintenanceWindow` but don't configure a maintenance window, all disruptive operations are **allowed**.

Configure a maintenance window by using the [`az aks maintenanceconfiguration add`](/cli/azure/aks/maintenanceconfiguration#az-aks-maintenanceconfiguration-add) command.

```azurecli-interactive
az aks maintenanceconfiguration add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name aksManagedNodeOSUpgradeSchedule \
    --schedule-type Weekly \
    --day-of-week Sunday \
    --interval-weeks 1 \
    --duration 4 \
    --start-hour 2
```

## Related content

- [Node Disruption Policy overview][node-disruption-policy-overview]
- [Use planned maintenance to schedule and control upgrades for your Azure Kubernetes Service cluster][planned-maintenance]

<!-- LINKS INTERNAL -->
[install-azure-cli]: /cli/azure/install-azure-cli
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-show]: /cli/azure/aks#az-aks-show
[node-disruption-policy-overview]: ./node-disruption-policy.md
[how-node-disruption-policy-works]: ./node-disruption-policy.md#how-node-disruption-policy-works
[operations-covered-by-node-disruption-policy]: ./node-disruption-policy.md#operations-covered-by-node-disruption-policy
[planned-maintenance]: ./planned-maintenance.md
