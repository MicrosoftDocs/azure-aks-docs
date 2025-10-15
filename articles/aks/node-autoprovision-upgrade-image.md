--- 
title: Node Image Updates for Node Auto-Provisioning (NAP) in Azure Kubernetes Service (AKS)
description: Learn about node image updates for NAP in AKS, including how it works, recommended maintenance windows, and examples to get started.
ms.topic: overview
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.date: 09/29/2025
ms.author: wilsondarko
author: wdarko1
# Customer intent: As a cluster operator or developer, I want to understand how node image updates work for my AKS clusters using node auto-provisioning, so that I can effectively manage and maintain the health and security of my cluster nodes.
---

# Node image updates for node auto-provisioning (NAP) in Azure Kubernetes Service (AKS)

This article provides an overview of node image updates for node auto-provisioning (NAP) in Azure Kubernetes Service (AKS), including how it works, recommended maintenance windows, and examples to get started.

## How do node image updates work for node auto-provisioning nodes?

By default, NAP node pool virtual machines (VMs) are automatically updated when a new image version is available. You can configure an [AKS-managed node operating system (OS) upgrade schedule maintenance window](#node-os-upgrade-maintenance-windows-for-nap) to control when new images are picked up and applied to your NAP nodes, or [use Karpenter Node Disruption Budgets and Pod Disruption Budgets](#karpenter-node-disruption-budgets-and-pod-disruption-budgets-for-nap) to control how and when disruption occurs during upgrades.

> [!NOTE]
> NAP forces the latest image version to be picked up if the existing node image version is older than 90 days. This bypasses any existing maintenance window.

## Node OS upgrade maintenance windows for NAP

You can use the [AKS planned maintenance feature](./planned-maintenance.md) with a [node OS auto-upgrade channel](./auto-upgrade-node-os-image.md) to configure a `aksManagedNodeOSUpgradeSchedule` maintenance window that controls when to perform node OS security patching scheduled by your designated node OS auto-upgrade channel.

### Node OS upgrade maintenance window behavior and considerations

Keep the following information in mind when configuring a node OS upgrade maintenance window for NAP:

- The `aksManagedNodeOSUpgradeSchedule` maintenance configuration determines the window during which NAP picks up a new image. This configuration doesn't necessarily determine when existing nodes are disrupted.
- The upgrade mechanism and decision criteria are specific to NAP/Karpenter and are evaluated by NAP's drift logic. NAP respects Karpenter Node Disruption Budgets and Pod Disruption Budgets. For more information about drift, see the [Karpenter drift  documentation](https://karpenter.sh/docs/concepts/disruption/#drift).
- These NAP upgrade decisions are separate from the cluster `NodeImage` and `SecurityPatch` channels. However, the `aksManagedNodeOSUpgradeSchedule` maintenance configuration applies them as well.
- We recommend using a maintenance window of four hours or more for reliable operation.
- If no maintenance configuration exists, AKS might use a fallback schedule to pick up new images, which can cause images to be picked up at unexpected times. You can avoid unexpected timing of new images and upgrades by defining an explicit `aksManagedNodeOSUpgradeSchedule`.
- Allow at least 30 minutes between creating or updating a maintenance configuration and the scheduled start time to ensure AKS has time to reconcile the new configuration.

### Recommended schedule pattern for NAP-managed nodes

We recommend the following schedule pattern for NAP-managed nodes:

- **Weekly cadence**: Recommended for routine node image roll outs (for example: _Every week on Sunday_).

## Create a node OS maintenance schedule example

The following sections show you how to create a weekly maintenance window for NAP-managed nodes using the Azure CLI and a JSON configuration file and how to update, view, list, and delete the maintenance configuration.

### Create a maintenance configuration

1. Create a JSON file named `nodeosMaintenance.json` with a weekly maintenance window (for example: _Sunday at 01:00 UTC for 4 hours_).

    ```json
    {
      "properties": {
        "maintenanceWindow": {
          "durationHours": 4,
          "schedule": {
            "weekly": {
              "intervalWeeks": 1,
              "dayOfWeek": "Sunday"
            }
          },
          "startDate": "2025-01-01",
          "startTime": "01:00",
          "utcOffset": "+00:00"
        }
      }
    }
    ```

1. Add the maintenance configuration to your cluster using the [`az aks maintenanceconfiguration add`](/cli/azure/aks/maintenanceconfiguration#az-aks-maintenanceconfiguration-add) command.

    ```azurecli-interactive
    az aks maintenanceconfiguration add \
      --resource-group $RESOURCE_GROUP \
      --cluster-name $CLUSTER_NAME \
      --name aksManagedNodeOSUpgradeSchedule \
      --config-file ./nodeosMaintenance.json
    ```

### Update, view, list, or delete a maintenance configuration

You can use the following commands to update, view, list, or delete a maintenance configuration for NAP-managed nodes:

- Update a maintenance configuration by modifying the JSON file and then running the [`az aks maintenanceconfiguration update`](/cli/azure/aks/maintenanceconfiguration#az-aks-maintenanceconfiguration-update) command.

    ```azurecli-interactive
    az aks maintenanceconfiguration update \
      --resource-group $RESOURCE_GROUP \
      --cluster-name $CLUSTER_NAME \
      --name aksManagedNodeOSUpgradeSchedule \
      --config-file ./nodeosMaintenance.json
    ```

- View the details of a maintenance configuration using the [`az aks maintenanceconfiguration show`](/cli/azure/aks/maintenanceconfiguration#az-aks-maintenanceconfiguration-show) command.

    ```azurecli-interactive
    az aks maintenanceconfiguration show \
      --resource-group $RESOURCE_GROUP \
      --cluster-name $CLUSTER_NAME \
      --name aksManagedNodeOSUpgradeSchedule
    ```

- List all maintenance configurations for your cluster using the [`az aks maintenanceconfiguration list`](/cli/azure/aks/maintenanceconfiguration#az-aks-maintenanceconfiguration-list) command.

    ```azurecli-interactive
    az aks maintenanceconfiguration list \
      --resource-group $RESOURCE_GROUP \
      --cluster-name $CLUSTER_NAME
    ```

- Delete a maintenance configuration using the [`az aks maintenanceconfiguration delete`](/cli/azure/aks/maintenanceconfiguration#az-aks-maintenanceconfiguration-delete) command.

    ```azurecli-interactive
    az aks maintenanceconfiguration delete \
      --resource-group $RESOURCE_GROUP \
      --cluster-name $CLUSTER_NAME \
      --name aksManagedNodeOSUpgradeSchedule
    ```

For complete details, examples, and advanced scenarios, see [Use Planned Maintenance to schedule maintenance windows for your AKS cluster](./planned-maintenance.md).

## Karpenter Node Disruption Budgets and Pod Disruption Budgets for NAP

For more information on configuring Karpenter Node Disruption Budgets and Pod Disruption Budgets for NAP, see the following resources from the official Karpenter documentation:

- [Node pool disruption budgets](https://karpenter.sh/docs/concepts/disruption/#nodepool-disruption-budgets)
- [Pod-level controls for disruption](https://karpenter.sh/docs/concepts/disruption/#pod-level-controls)

## Next steps

For more information on node auto-provisioning in AKS, see the following articles:

- [Use node auto-provisioning in a custom virtual network](./node-autoprovisioning-custom-vnet.md)
- [Configure networking for node auto-provisioning on AKS](./node-autoprovision-networking.md)
- [Configure node pools for node auto-provisioning on AKS](./node-autoprovision-node-pools.md)
- [Configure disruption policies for node auto-provisioning on AKS](./node-autoprovision-disruption.md)
