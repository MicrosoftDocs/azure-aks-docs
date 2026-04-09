---
title: Schedule Upgrades for Azure Kubernetes Application Network Members using Planned Maintenance (Preview)
description: Learn how to use planned maintenance to schedule component upgrades for Azure Kubernetes Application Network members, including in-cluster data plane components and control plane components.
author: kochhars
ms.author: kochhars
ms.service: azure-kubernetes-app-net
ms.topic: how-to
ms.date: 03/13/2026
---

# Use planned maintenance to schedule upgrades for Azure Kubernetes Application Network members (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

This article shows you how to use planned maintenance to schedule component upgrades for Azure Kubernetes Application Network members.

## Overview of planned maintenance for Application Network

Maintenance operations refer to the upgrade of in-cluster [data plane components](./architecture.md#data-plane) and Application Network [control plane components](./architecture.md#control-plane) that run outside the cluster, such as Istiod.

Two of the key in-cluster components are the **ztunnel node proxies** and **Istio CNI node agents**. These resources are per-node DaemonSets, so their upgrades affect an entire node at a time and might cause disruptions of long-lived TCP connections. To isolate node-level disruptions to a common window, Application Network uses the same `aksManagedNodeOSUpgradeSchedule` maintenance schedule as [Azure Kubernetes Service (AKS) node operating system (OS) automatic upgrades][node-os-autoupgrades], if configured.

Note that while the maintenance _window_ is the same, Application Network member upgrades and node OS upgrades are independent events within the window that occur for one or both components, depending on availability of upgrades. Neither upgrade impacts the timing or process of the other. If both components upgrade within the same window, there might be separate connection disruptions for each upgrade within that window.

> [!NOTE]
> It's not required to opt in to node OS automatic upgrades to use planned maintenance for Application Network. Creating an `aksManagedNodeOSUpgradeSchedule` doesn't enable or disable node OS automatic upgrades.

## Prerequisites

- An existing AKS cluster onboarded as a member of an Application Network resource. If you don't have an Application Network resource or haven't onboarded your cluster yet, see [Get started with Azure Kubernetes Application Network](./get-started.md).
- Azure CLI version is 2.84.0 or later. Check your version using the `az --version` command. To install or update, see [Install Azure CLI](/cli/azure/install-azure-cli).
- We recommend reviewing the [Maintenance window documentation](/azure/aks/planned-maintenance#create-a-maintenance-window) to understand the configuration fields and how maintenance windows work in AKS.

## Considerations

Keep the following considerations in mind when using planned maintenance to schedule Application Network upgrades:

- Application Network reserves the right to break planned maintenance windows for unplanned, reactive maintenance operations that are urgent or critical. These maintenance operations might even run during the `notAllowedTime` or `notAllowedDates` periods defined in your configuration.
- Maintenance operations are considered _best effort only_ and aren't guaranteed to occur within a specified window.
- If an attempted upgrade isn't completed when the window closes, it continues to attempt reconciliation until it completes.

## Mode-specific behavior

You can use planned maintenance to schedule the timing of fully-managed upgrades and self-managed upgrades, but enabling or disabling planned maintenance doesn't impact your upgrade mode itself. Maintenance windows gate different types of upgrades depending on the upgrade mode of your cluster.

- [**Fully-managed mode**](./upgrades.md#fully-managed-mode): Maintenance windows gate both minor and patch upgrades. However, if you initiate a release channel change, the associated version change takes effect immediately.
- [**Self-managed mode**](./upgrades.md#self-managed-mode): Maintenance windows apply only to patch upgrades. If you initiate a minor version change, it takes effect immediately.

## Add a maintenance window

- Add a `aksManagedNodeOSUpgradeSchedule` maintenance window configuration to an AKS cluster using the [`az aks maintenanceconfiguration add`][az-aks-maintenanceconfiguration-add] command. The following example adds a new `aksManagedNodeOSUpgradeSchedule` configuration that schedules maintenance to run every third Friday between 12:00 AM and 8:00 AM in the `UTC+5:30` time zone:

    ```azurecli-interactive
    az aks maintenanceconfiguration add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name aksManagedNodeOSUpgradeSchedule --schedule-type Weekly --day-of-week Friday --interval-weeks 3 --duration 8 --utc-offset +05:30 --start-time 00:00
    ```

## Update an existing maintenance window

- Update an existing maintenance configuration using the [`az aks maintenanceconfiguration update`][az-aks-maintenanceconfiguration-update] command. The following example updates the `aksManagedNodeOSUpgradeSchedule` configuration to schedule maintenance to run every Friday from 2:00 AM to 6:00 AM:

    ```azurecli-interactive
    az aks maintenanceconfiguration update --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name aksManagedNodeOSUpgradeSchedule --schedule-type Weekly --day-of-week Friday --interval-weeks 1 --duration 4 --utc-offset +00:00 --start-time 02:00
    ```

## Show the maintenance configuration for a cluster

- View a specific maintenance configuration window in your AKS cluster using the [`az aks maintenanceconfiguration show`][az-aks-maintenanceconfiguration-show] command with the `--name` parameter.

    ```azurecli-interactive
    az aks maintenanceconfiguration show --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name aksManagedNodeOSUpgradeSchedule
    ```

    The following example output shows the maintenance window for `aksManagedNodeOSUpgradeSchedule`:

    ```output
    {
      "id": "/subscriptions/<subscription>/resourceGroups/myResourceGroup/providers/Microsoft.ContainerService/managedClusters/myAKSCluster/maintenanceConfigurations/aksManagedNodeOSUpgradeSchedule",
      "maintenanceWindow": {
        "durationHours": 4,
        "notAllowedDates": [
          {
            "end": "2024-01-05",
            "start": "2023-12-23"
          }
        ],
        "schedule": {
          "absoluteMonthly": {
            "dayOfMonth": 1,
            "intervalMonths": 3
          },
          "daily": null,
          "relativeMonthly": null,
          "weekly": null
        },
        "startDate": "2023-01-20",
        "startTime": "09:00",
        "utcOffset": "-08:00"
      },
      "name": "aksManagedNodeOSUpgradeSchedule",
      "notAllowedTime": null,
      "resourceGroup": "myResourceGroup",
      "systemData": null,
      "timeInWeek": null,
      "type": null
    }
    ```

## Delete a maintenance configuration for a cluster

- Delete a maintenance configuration window in your AKS cluster using the [`az aks maintenanceconfiguration delete`][az-aks-maintenanceconfiguration-delete] command.

    ```azurecli-interactive
    az aks maintenanceconfiguration delete --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name aksManagedNodeOSUpgradeSchedule
    ```

## Related content

To learn more about Azure Kubernetes Application Network, see the following articles:

- [Configure upgrades for Azure Kubernetes Application Network members](./upgrades.md)
- [Azure Kubernetes Application Network architecture](./architecture.md)
- [Overview of Azure Kubernetes Application Network observability](./observability.md)

<!--- LINKS --->
[node-os-autoupgrades]: /azure/aks/auto-upgrade-node-os-image
[az-aks-maintenanceconfiguration-add]: /cli/azure/aks/maintenanceconfiguration#az-aks-maintenanceconfiguration-add
[az-aks-maintenanceconfiguration-update]: /cli/azure/aks/maintenanceconfiguration#az-aks-maintenanceconfiguration-update
[az-aks-maintenanceconfiguration-show]: /cli/azure/aks/maintenanceconfiguration#az-aks-maintenanceconfiguration-show
[az-aks-maintenanceconfiguration-delete]: /cli/azure/aks/maintenanceconfiguration#az-aks-maintenanceconfiguration-delete
