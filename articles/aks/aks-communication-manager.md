---
title: AKS Communication Manager
description: Learn how to set up and receive notices in Azure Resource Notifications for Azure Kubernetes Service maintenance events.
ms.date: 08/28/2025
ms.custom: aks communication manager
ms.topic: how-to
author: kaarthis
ms.author: kaarthis
ms.subservice: aks-upgrade
# Customer intent: As a Kubernetes administrator, I want to set up notifications for AKS maintenance events so that I can receive timely alerts and reduce operational issues related to monitoring upgrades and failures.
---

# Set up an Azure Kubernetes Service communication manager

An Azure Kubernetes Service (AKS) communication manager streamlines notifications for all your AKS maintenance tasks by using Azure Resource Notifications and Azure Resource Graph frameworks. The communication manager gives you timely alerts on event triggers and outcomes, so that you can closely monitor your upgrades.

If maintenance fails, the communication manager notifies you with the reasons for the failure. This information reduces operational hassles related to observability and follow-ups.

By following the steps in this article, you can set up notifications for all types of automatic upgrades that use maintenance windows.

## Prerequisites

- Configure your cluster for either the [automatic upgrade channel][aks-auto-upgrade] or the [automatic upgrade channel for nodes][aks-node-auto-upgrade].

- Create a [planned maintenance window][planned-maintenance] for your configuration of automatic upgrades.

After you set up automatic upgrades, the communication manager sends advance notices: one week before maintenance starts and one day before maintenance starts. This communication is in addition to the timely alerts during the maintenance operation.

## Set up a communication manager

1. In the Azure portal, go to the resource.

1. Select **Monitoring** > **Alerts** > **Alert Rules**, and then select **Create**.

1. On the **Condition** tab, for **Signal name**, select **Custom log search**.

   :::image type="content" source="./media/auto-upgrade-cluster/custom-log-search.jpg" alt-text="Screenshot that shows the selection of a custom log search on the pane for creating an alert rule.":::

1. In the **Search query** box, paste one of the following custom queries. Be sure to update the `where id contains` path to reference your resources for subscription ID, resource group name, and cluster name.

   The following query is for notifications of automatic upgrades for clusters:

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

   The following query is for notifications of automatic upgrades for NodeOS:

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

1. Go to the **Review + create** tab. Configure the alert conditions with the following settings:

   - **Measure**: Select **Table rows**.
   - **Aggregation type**: Select **Count**.
   - **Aggregation granularity**: Select **30 minutes**.
   - **Threshold value**: Keep at **0**.
   - **Split by dimensions**: For **Dimension name**, select **status**. Then select the **Include all future values** checkbox.

   :::image type="content" source="./media/auto-upgrade-cluster/edit-alert-rule.jpg" alt-text="Screenshot of the configuration options for alert conditions.":::

1. In the **Split by dimensions** area, for **Dimension values**, select a value. Because you selected **status** for the dimension name, the available values are **Scheduled**, **Started**, **Completed**, **Canceled**, and **Failed**.

   > [!NOTE]
   > These status values appear only if your cluster previously executed automatic upgrade operations. For new clusters or for clusters that haven't undergone automatic upgrades yet, the dropdown list might appear empty or show no available dimensions. After your cluster performs its first automatic upgrade, these status values become available for selection.

   :::image type="content" source="./media/auto-upgrade-cluster/by-dimension.jpg" alt-text="Screenshot of the dropdown list boxes in the area for splitting by dimensions.":::

1. Make sure that an action group with the correct email address exists, so that you can receive the notifications.

   :::image type="content" source="./media/auto-upgrade-cluster/action-group.png" alt-text="Screenshot of the pane for entering email information for an action group.":::

1. Assign a managed identity so that you can grant access to the necessary resources:

    1. On the **Create an alert rule** pane, go to the **Details** tab.
    1. In the **Identity** area, select **System assigned managed identity**.

    :::image type="content" source="./media/auto-upgrade-cluster/system-assigned-identity.jpg" alt-text="Screenshot that shows selections for assigning a system-assigned managed identity.":::

1. Select **Create** to finish creating the alert rule.

1. Assign the appropriate roles:

   1. In the alert rule, go to **Settings** > **Identity** > **System assigned managed identity** > **Azure role assignments**.
   1. Select **Add role assignment**, select the **Reader** role, and assign it to the resource group.
   1. Select **Add role assignment** again, select the **Reader** role, and assign it to the subscription.

    > [!TIP]
    > If you don't see the **Identity** option, make sure that you created your alert rule and that you have the necessary permissions. Assigning the managed identity is always a separate step after creation of the alert rule.

After you set up the communication manager, it sends advance notices one week before maintenance starts and one day before maintenance starts. It also sends you timely alerts during the maintenance operation.

## Verify the configuration

To upgrade the cluster, wait for the automatic upgrader to start. Then verify that you promptly receive notices on the email address that you configured to receive notices.

Check the Azure Resource Graph database for the scheduled notification record. Each scheduled event notification should be listed as one record in the `ContainerServiceEventResources` table.

:::image type="content" source="./media/auto-upgrade-cluster/azure-resource-graph.jpeg" alt-text="Screenshot that shows a notification record in Azure Resource Graph.":::

## Related content

- [Use planned maintenance to schedule and control upgrades for your Azure Kubernetes Service cluster][planned-maintenance]
- [Upgrade options and recommendations for Azure Kubernetes Service clusters][upgrade-cluster]

<!-- LINKS - internal -->

[aks-auto-upgrade]: auto-upgrade-cluster.md
[aks-node-auto-upgrade]: auto-upgrade-node-os-image.md
[planned-maintenance]: planned-maintenance.md
[upgrade-cluster]: upgrade-cluster.md
