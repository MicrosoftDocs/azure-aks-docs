---
title: AKS Communication Manager 
description: Start here to learn how to set up and receive notices in Azure Resource Notification for AKS Maintenance events. 
ms.date: 10/16/2024
ms.custom: aks communication manager
ms.topic: conceptual
author: kaarthis
ms.author: kaarthis
ms.subservice: aks-upgrade
---

# Azure Kubernetes Service Communication Manager
The AKS Communication Manager streamlines notifications for all your AKS maintenance tasks by using Azure Resource Notification and Azure Resource Graph frameworks. This tool enables you to monitor your upgrades closely by providing timely alerts on event triggers and outcomes. If maintenance fails, it notifies you with the reasons for the failure, reducing operational hassles related to observability and follow-ups. You can set up notifications for all types of auto upgrades that utilize maintenance windows by following these steps.

## Prerequisites

- Configure your cluster for either [Auto upgrade channel][aks-auto-upgrade] or [Node Auto upgrade channel][aks-node-auto-upgrade].

- Create [Planned maintenance window][planned-maintenance] as mentioned here for your auto upgrade configuration. 

> [!NOTE]
> Once set up, the communication manager sends advance notices - one week before maintenance starts and one day before maintenance starts. This is in addition to the timely alerts during the maintenance operation. 

## How to set up communication manager

1. Go to the resource, then choose Monitoring and select Alerts and then click into Alert Rules. 

2. The Condition for the  alert should be a Custom log search.


     :::image type="content" source="./media/auto-upgrade-cluster/custom-log-search.jpg" alt-text="The screenshot of the custom log search in the alert rule blade.":::

3. In the opened "Search query" box, paste one of the following custom queries and click "Review+Create" button.

Query for cluster auto upgrade notifications:

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
Query for Node OS auto upgrade notifications:

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
| where upgradeType == "NodeOSUpgrade"
| project
    eventTime,
    upgradeType,
    status,
    properties
| order by eventTime asc
 ```
4. Configuration for alert Conditions. For measurement, select Measure by "Table rows", and for Aggregation, select "Count" and aggregation granularity "30 minutes". Keep Threshold value at 0. For Split by dimesions, select "status" and "Include all future values".

:::image type="content" source="./media/auto-upgrade-cluster/edit-alert-rule.jpg" alt-text="The screenshot of the configuration options for alert conditions.":::

5. The only values that appear are "Scheduled,""Started,""Completed,""Canceled,""Failed", but they wont show if the cluster never had an auto upgrade operation.

:::image type="content" source="./media/auto-upgrade-cluster/by-dimension.jpg" alt-text="The screenshot of the split by dimensions drop down.":::

6. Check an action group with the correct email address exists, to receive the notifications.

7. Assign Managed System Identity: the alert should have a managed identiy assigned to it. You can use an existing one or let the system assign one.

:::image type="content" source="./media/auto-upgrade-cluster/system-assigned-identity.jpg" alt-text="The screenshot of where to assign Managed System Identity.":::

8. Make sure to give the Read roles appropriately.

    Choose under alert rule, Settings -> Identity -> System assigned managed identity -> Azure role assignments -> Add role assignment

    Choose the role Reader and assign it to the resource group. Repeat "Add role assignment" for the subscription.

### Verification

Wait for the auto upgrader to start to upgrade the cluster. Then verify if you receive notices promptly on the email configured to receive these notices.

Check Azure Resource Graph database for the scheduled notification record. Each scheduled event notification should be listed as one record in the "containerserviceeventresources" table.
!

:::image type="content" source="./media/auto-upgrade-cluster/azure-resource-graph.jpeg" alt-text="Screenshot of how to look up Azure resource graph.":::

### Next Steps
See how you can set up a [planned maintenance][planned-maintenance] window for your upgrades.
See how you can optimize your [upgrades][upgrade-cluster].

<!-- LINKS - internal -->
[aks-auto-upgrade]: auto-upgrade-cluster.md
[aks-node-auto-upgrade]: auto-upgrade-node-os-image.md
[planned-maintenance]: planned-maintenance.md
[upgrade-cluster]:upgrade-cluster.md