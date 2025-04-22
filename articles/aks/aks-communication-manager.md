---
title: AKS Communication Manager 
description: Learn how to set up and receive notices in Azure Resource Notifications for Azure Kubernetes Service maintenance events. 
ms.date: 10/16/2024
ms.custom: aks communication manager
ms.topic: conceptual
author: kaarthis
ms.author: kaarthis
ms.subservice: aks-upgrade
---

# Azure Kubernetes Service Communication Manager

The Azure Kubernetes Service (AKS) Communication Manager streamlines notifications for all your AKS maintenance tasks by using Azure Resource Notifications and Azure Resource Graph frameworks. This tool enables you to closely monitor your upgrades because it provides you with timely alerts on event triggers and outcomes. If maintenance fails, it notifies you with the reasons for the failure, reducing operational hassles related to observability and follow ups. You can set up notifications for all types of autoupgrades that utilize maintenance windows by following these steps.

## Prerequisites

- Configure your cluster for either [Autoupgrade channel][aks-auto-upgrade] or [Node autoupgrade channel][aks-node-auto-upgrade].

- Create a [planned maintenance window][planned-maintenance] for your autoupgrade configuration.

> [!NOTE]
> After Communication Manager is set up, it sends advance notices one week before maintenance starts and one day before maintenance starts. You also receive timely alerts during the maintenance operation.

## Set up Communication Manager

1. Go to the resource, select **Monitoring**, select **Alerts**, and then select **Alert Rules**.

1. Under the **Condition** tab, select **Custom log search** in the **Signal name** dropdown menu.

     :::image type="content" source="./media/auto-upgrade-cluster/custom-log-search.jpg" alt-text="Screenshot that shows the custom log search in the alert rule pane.":::

1. In the **Search query** box, paste one of the following custom queries and select the **Review+Create** button.

The following query is for cluster autoupgrade notifications:

 ```arg("").containerserviceeventresources
| where type == "microsoft.containerservice/managedclusters/scheduledevents"
| where id contains "/subscriptions/subid/resourcegroups/rgname/providers/Microsoft.ContainerService/managedClusters/clustername"
| where properties has "eventStatus"
| extend status = substring(properties, indexof(properties, "eventStatus") + strlen("eventStatus") + 3, 50)
| extend status = substring(status, 0, indexof(status, ",") - 1)
| where status != ""
| where properties has "eventDetails"
| extend upgradeType = case(
                           properties has "K8sVersionUpgrade",
                           "K8sVersionUpgrade",
                           properties has "NodeOSUpgrade",
                           "NodeOSUpgrade",
                           status == "Completed" or status == "Failed",
                           case(
    properties has '"type":1',
    "K8sVersionUpgrade",
    properties has '"type":2',
    "NodeOSUpgrade",
    ""
),
                           ""
                       )
| where properties has "lastUpdateTime"
| extend eventTime = substring(properties, indexof(properties, "lastUpdateTime") + strlen("lastUpdateTime") + 3, 50)
| extend eventTime = substring(eventTime, 0, indexof(eventTime, ",") - 1)
| extend eventTime = todatetime(tostring(eventTime))
| where eventTime >= ago(2h)
| where upgradeType == "K8sVersionUpgrade"
| project
    eventTime,
    upgradeType,
    status,
    properties
| order by eventTime asc
 ```

The following query is for Node OS autoupgrade notifications:

 ```arg("").containerserviceeventresources
| where type == "microsoft.containerservice/managedclusters/scheduledevents"
| where id contains "/subscriptions/subid/resourcegroups/rgname/providers/Microsoft.ContainerService/managedClusters/clustername"
| where properties has "eventStatus"
| extend status = substring(properties, indexof(properties, "eventStatus") + strlen("eventStatus") + 3, 50)
| extend status = substring(status, 0, indexof(status, ",") - 1)
| where status != ""
| where properties has "eventDetails"
| extend upgradeType = case(
                           properties has "K8sVersionUpgrade",
                           "K8sVersionUpgrade",
                           properties has "NodeOSUpgrade",
                           "NodeOSUpgrade",
                           status == "Completed" or status == "Failed",
                           case(
    properties has '"type":1',
    "K8sVersionUpgrade",
    properties has '"type":2',
    "NodeOSUpgrade",
    ""
),
                           ""
                       )
| where properties has "lastUpdateTime"
| extend eventTime = substring(properties, indexof(properties, "lastUpdateTime") + strlen("lastUpdateTime") + 3, 50)
| extend eventTime = substring(eventTime, 0, indexof(eventTime, ",") - 1)
| extend eventTime = todatetime(tostring(eventTime))
| where eventTime >= ago(2h)
| where upgradeType == "K8sVersionUpgrade"
| project
    eventTime,
    upgradeType,
    status,
    properties
| order by eventTime asc
 ```

1. The interval should be 30 minutes, and the threshold should be 1.

1. Make sure that an action group with the correct email address exists, so that you can receive the notifications.

1. Make sure to give the **Read** role to the resource group and to the subscription to the MSI of the log search alert rule.

1. Go to alert rule: **Settings** > **Identity** > **System assigned managed identity** > **Azure role assignments** > **Add role assignment**.

1. Select the **Reader** role and assign it to the resource group. Repeat **Add role assignment** for the subscription.

### Verification

To upgrade the cluster, wait for the autoupgrader to start. Then verify that you promptly receive notices on the email configured to receive notices.

Check the Azure Resource Graph database for the scheduled notification record. Each scheduled event notification should be listed as one record in the `containerserviceeventresources` table.

:::image type="content" source="./media/auto-upgrade-cluster/azure-resource-graph.jpeg" alt-text="Screenshot that shows how to look up Azure Resource Graph.":::

### Related content
See how you can set up a [planned maintenance][planned-maintenance] window for your upgrades.
See how you can optimize your [upgrades][upgrade-cluster].

<!-- LINKS - internal -->
[aks-auto-upgrade]: auto-upgrade-cluster.md
[aks-node-auto-upgrade]: auto-upgrade-node-os-image.md
[planned-maintenance]: planned-maintenance.md
[upgrade-cluster]:upgrade-cluster.md
