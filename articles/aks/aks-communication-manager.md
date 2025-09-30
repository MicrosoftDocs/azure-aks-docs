---
title: AKS Communication Manager
description: Learn how to set up and receive notices in Azure Resource Notifications for Azure Kubernetes Service maintenance events.
ms.date: 08/28/2025
ms.custom: aks communication manager
ms.topic: concept-article
author: kaarthis
ms.author: kaarthis
ms.subservice: aks-upgrade
# Customer intent: As a Kubernetes administrator, I want to set up notifications for AKS maintenance events so that I can receive timely alerts and reduce operational issues related to monitoring upgrades and failures.
---

# Azure Kubernetes Service Communication Manager

The Azure Kubernetes Service (AKS) Communication Manager streamlines notifications for all your AKS maintenance tasks by using Azure Resource Notifications and Azure Resource Graph frameworks. This tool enables you to closely monitor your upgrades because it provides you with timely alerts on event triggers and outcomes. If maintenance fails, it notifies you with the reasons for the failure, reducing operational hassles related to observability and follow-ups. You can set up notifications for all types of autoupgrades that utilize maintenance windows by following these steps.

## Prerequisites

- Configure your cluster for either [Autoupgrade channel][aks-auto-upgrade] or [Node autoupgrade channel][aks-node-auto-upgrade].

- Create a [planned maintenance window][planned-maintenance] for your autoupgrade configuration.

> [!NOTE]  
> Once set up, the communication manager sends advance notices - one week before maintenance starts and one day before maintenance starts. This is in addition to the timely alerts during the maintenance operation.

> [!NOTE]
> For each query, be sure to update the `where id contains` path to reference your resources for subscription ID, resource group name, and cluster name.

## How to set up communication manager

1. Go to the resource, then choose Monitoring and select Alerts and then click into Alert Rules.

2. The Condition for the alert should be a Custom log search.

   :::image type="content" source="./media/auto-upgrade-cluster/custom-log-search.jpg" alt-text="The screenshot of the custom log search in the alert rule blade.":::

3. In the opened "Search query" box, paste one of the following custom queries and click "Review+Create" button.

### Query for cluster auto upgrade notifications

```kusto
arg("").containerserviceeventresources
| where type == "microsoft.containerservice/managedclusters/scheduledevents"
| where id contains "/subscriptions/<subid>/resourcegroups/<rgname>/providers/Microsoft.ContainerService/managedClusters/<clustername>"
| where properties has "eventStatus"
| extend status = substring(properties, indexof(properties, "eventStatus") + strlen("eventStatus") + 3, 50)
| extend status = substring(status, 0, indexof(status, ",") - 1)
| where status != ""
| where properties has "eventDetails"
| extend details = parse_json(tostring(properties.eventDetails))
| extend upgradeType = case(
                           properties has "K8sVersionUpgrade",
                           "K8sVersionUpgrade",
                           properties has "NodeOSUpgrade",
                           "NodeOSUpgrade",
                           ""
                       )
| extend details = parse_json(tostring(properties.eventDetails))
| where properties has "lastUpdateTime"
| extend eventTime = substring(properties, indexof(properties, "lastUpdateTime") + strlen("lastUpdateTime") + 3, 50)
| extend eventTime = substring(eventTime, 0, indexof(eventTime, ",") - 1)
| extend eventTime = todatetime(tostring(eventTime))
| where eventTime >= ago(30m) // Ensure this matches aggregation granularity & frequency
| where upgradeType == "K8sVersionUpgrade"
| project
    eventTime,
    upgradeType,
    status,
    properties,
    name,
    details
| order by eventTime asc
```

### Query for Node OS auto upgrade notifications

```kusto
arg("").containerserviceeventresources
| where type == "microsoft.containerservice/managedclusters/scheduledevents"
| where id contains "/subscriptions/<subid>/resourcegroups/<rgname>/providers/Microsoft.ContainerService/managedClusters/<clustername>"
| where properties has "eventStatus"
| extend status = substring(properties, indexof(properties, "eventStatus") + strlen("eventStatus") + 3, 50)
| extend status = substring(status, 0, indexof(status, ",") - 1)
| where status != ""
| where properties has "eventDetails"
| extend details = parse_json(tostring(properties.eventDetails))
| extend upgradeType = case(
                           properties has "K8sVersionUpgrade",
                           "K8sVersionUpgrade",
                           properties has "NodeOSUpgrade",
                           "NodeOSUpgrade",
                           ""
                       )
| extend details = parse_json(tostring(properties.eventDetails))
| where properties has "lastUpdateTime"
| extend eventTime = substring(properties, indexof(properties, "lastUpdateTime") + strlen("lastUpdateTime") + 3, 50)
| extend eventTime = substring(eventTime, 0, indexof(eventTime, ",") - 1)
| extend eventTime = todatetime(tostring(eventTime))
| where eventTime >= ago(30m) // Ensure this matches aggregation granularity & frequency
| where upgradeType == "NodeOSUpgrade"
| project
    eventTime,
    upgradeType,
    status,
    properties,
    name,
    details
| order by eventTime asc
```

4. Configure the alert conditions with the following settings:
   - **Measurement**: Select "Table rows"
   - **Aggregation**: Select "Count"
   - **Aggregation granularity**: Select "30 minutes"
   - **Threshold value**: Keep at 0
   - **Split by dimensions**: Select "status" and choose "Include all future values"

:::image type="content" source="./media/auto-upgrade-cluster/edit-alert-rule.jpg" alt-text="The screenshot of the configuration options for alert conditions.":::

5. When selecting "status" in the **Split by dimensions** dropdown, the available values are: Scheduled, Started, Completed, Canceled, and Failed.

   > [!NOTE]
   > These status values will only appear if your cluster has previously executed auto upgrade operations. For new clusters or clusters that haven't undergone auto upgrades yet, the dropdown may appear empty or show no available dimensions. Once your cluster performs its first auto upgrade, these status values will become available for selection.

:::image type="content" source="./media/auto-upgrade-cluster/by-dimension.jpg" alt-text="The screenshot of the split by dimensions drop down.":::

6. Check an action group with the correct email address exists, to receive the notifications.

:::image type="content" source="./media/auto-upgrade-cluster/action-group.png" alt-text="The screenshot of entering appropriate email or SMS into an action group.":::

7.  Assign system assigned managed identity: while creating the alert, assign a managed identity so you can grant access to the necessary resources. To assign a managed identity during creation:
    - In the **Create an alert rule** screen go to **Details** > **Identity**
    - Select **System assigned managed identity**.
    - Continue with the alert creation.

    :::image type="content" source="./media/auto-upgrade-cluster/system-assigned-identity.jpg" alt-text="The screenshot of where to assign Managed System Identity.":::

8.  Make sure to assign the appropriate Reader roles.

    After you create the alert rule, assign a managed identity. In the alert rule, go to **Settings** > **Identity** > **System assigned managed identity** > **Azure role assignments** > **Add role assignment**.

    Choose the **Reader** role and assign it to the resource group. Repeat "Add role assignment" for the subscription if needed.

    > [!TIP]
    > If you don't see the Identity option, make sure your alert rule has been created and you have the necessary permissions. Assigning the managed identity is always a separate step after alert rule creation.

    > [!NOTE]
    > After Communication Manager is set up, it sends advance notices one week before maintenance starts and one day before maintenance starts. It also sends you timely alerts during the maintenance operation.

## Set up Communication Manager

1. Go to the resource, select **Monitoring**, select **Alerts**, and then select **Alert Rules**.

1. On the **Condition** tab, for **Signal name**, select **Custom log search**.

   :::image type="content" source="./media/auto-upgrade-cluster/custom-log-search.jpg" alt-text="Screenshot that shows the custom log search in the alert rule pane.":::

1. In the **Search query** box, paste one of the following custom queries and then select the **Review+Create** button.

   The following query is for cluster autoupgrade notifications:

   ```console
   arg("").containerserviceeventresources
   | where type == "microsoft.containerservice/managedclusters/scheduledevents"
   | where id contains "/subscriptions/<subid>/resourcegroups/<rgname>/providers/Microsoft.ContainerService/managedClusters/<clustername>"
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
                              ""
                          )
   | extend details = parse_json(tostring(properties.eventDetails))
   | where properties has "lastUpdateTime"
   | extend eventTime = substring(properties, indexof(properties, "lastUpdateTime") + strlen("lastUpdateTime") + 3, 50)
   | extend eventTime = substring(eventTime, 0, indexof(eventTime, ",") - 1)
   | extend eventTime = todatetime(tostring(eventTime))
   | where eventTime >= ago(30m) // Ensure this matches aggregation granularity & frequency
   | where upgradeType == "K8sVersionUpgrade"
   | project
       eventTime,
       upgradeType,
       status,
       properties,
       name,
       details
   | order by eventTime asc
   ```
   
   The following query is for Node OS autoupgrade notifications:
   
   ```console
   arg("").containerserviceeventresources
   | where type == "microsoft.containerservice/managedclusters/scheduledevents"
   | where id contains "/subscriptions/<subid>/resourcegroups/<rgname>/providers/Microsoft.ContainerService/managedClusters/<clustername>"
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
                              ""
                          )
   | extend details = parse_json(tostring(properties.eventDetails))
   | where properties has "lastUpdateTime"
   | extend eventTime = substring(properties, indexof(properties, "lastUpdateTime") + strlen("lastUpdateTime") + 3, 50)
   | extend eventTime = substring(eventTime, 0, indexof(eventTime, ",") - 1)
   | extend eventTime = todatetime(tostring(eventTime))
   | where eventTime >= ago(30m) // Ensure this matches aggregation granularity & frequency
   | where upgradeType == "NodeOSUpgrade"
   | project
       eventTime,
       upgradeType,
       status,
       properties,
       name,
       details
   | order by eventTime asc
   ```

1. The interval should be 30 minutes, and the threshold should be 1.

1. Make sure that an action group with the correct email address exists, so that you can receive the notifications.

1. Make sure to give the **Read** role to the resource group and to the subscription to the managed identity of the log search alert rule.

1. Go to the alert rule: **Settings** > **Identity** > **System assigned managed identity** > **Azure role assignments** > **Add role assignment**.

1. Select the **Reader** role and assign it to the resource group. Repeat **Add role assignment** for the subscription.

### Verification

To upgrade the cluster, wait for the autoupgrader to start. Then verify that you promptly receive notices on the email configured to receive notices.

Check the Azure Resource Graph database for the scheduled notification record. Each scheduled event notification should be listed as one record in the `containerserviceeventresources` table.

:::image type="content" source="./media/auto-upgrade-cluster/azure-resource-graph.jpeg" alt-text="Screenshot that shows how to look up Azure Resource Graph.":::

## Related content

- See how you can set up a [planned maintenance][planned-maintenance] window for your upgrades.
- See how you can optimize your [upgrades][upgrade-cluster].

<!-- LINKS - internal -->

[aks-auto-upgrade]: auto-upgrade-cluster.md
[aks-node-auto-upgrade]: auto-upgrade-node-os-image.md
[planned-maintenance]: planned-maintenance.md
[upgrade-cluster]: upgrade-cluster.md
