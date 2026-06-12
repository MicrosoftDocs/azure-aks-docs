---
title: AKS end of support notifications
description: Learn how to receive and set up alerts for Kubernetes version end of support notifications in Azure Kubernetes Service.
ms.date: 06/11/2026
ms.custom: aks end-of-support notifications
ms.topic: concept-article
author: jdbencardinop
ms.author: jubencar
ms.subservice: aks-upgrade
# Customer intent: As a Kubernetes administrator, I want to receive notifications when my cluster's Kubernetes version is approaching end of support so that I can plan upgrades and avoid running unsupported versions.
---

# Azure Kubernetes Service end of support notifications

Azure Kubernetes Service (AKS) proactively notifies you when your cluster's Kubernetes version is approaching or has passed its end of support date. These notifications are published as scheduled events to Azure Resource Graph (ARG) through the AKS Communication Manager, using the same Azure Resource Notifications pipeline as [maintenance notifications][aks-communication-manager].

End of support notifications are automatic and don't require auto-upgrade or a maintenance window to be configured. No cluster monitoring add-on is required.

## Notification types

AKS evaluates your cluster's Kubernetes version against the [AKS Kubernetes release calendar][supported-versions] and sends notifications at the following intervals:

| Notification | When it fires | Description |
|-------------|---------------|-------------|
| `KubernetesVersionEOLTwoWeeks` | 14 or more days before end of support | Your cluster version reaches end of support within two weeks |
| `KubernetesVersionEOLOneWeek` | 7 to 14 days before end of support | Your cluster version reaches end of support within one week |
| `KubernetesVersionOutOfSupport` | After end of support date | Your cluster version is past end of support (repeats weekly) |

> [!NOTE]
> Clusters using [Long Term Support (LTS)][long-term-support] are evaluated against the LTS end of support date, which is later than the community end of support date. For current lifecycle dates, see the [AKS Kubernetes release calendar][supported-versions].

### Notification payload

Each notification includes structured event details that you can use for automation or reporting:

```json
{
  "description": "KubernetesVersionEOLOneWeek",
  "eventSource": "EOLNotification",
  "eventStatus": "Scheduled",
  "eventDetails": {
    "kubernetesVersion": "1.32.3",
    "eolDate": "2026-03-01T00:00:00Z",
    "supportType": "Community",
    "daysUntilEOL": 5,
    "region": "eastus"
  },
  "scheduledTime": "2026-03-01T00:00:00Z"
}
```

The `eventDetails` field contains:
- **kubernetesVersion**: The full version running on your cluster
- **eolDate**: The end of support date for this version
- **supportType**: `Community` or `LTS`, depending on your cluster's support plan
- **daysUntilEOL**: Days remaining until end of support (negative if already past)
- **region**: The Azure region of the cluster

## Query notifications in Azure Resource Graph

You can check whether your cluster has end of support notifications by querying Azure Resource Graph directly. No cluster monitoring is required for these queries.

> [!NOTE]
> For each query, update the `where id contains` path to reference your subscription ID, resource group name, and cluster name.

### Query for a specific cluster

```kusto
containerserviceeventresources
| where type == "microsoft.containerservice/managedclusters/scheduledevents"
| where id contains "/subscriptions/<subid>/resourcegroups/<rgname>/providers/Microsoft.ContainerService/managedClusters/<clustername>"
| where properties has "EOLNotification"
| extend description = tostring(properties.description)
| extend details = parse_json(tostring(properties.eventDetails))
| project name, description, details, properties
```

### Query for all notifications across subscriptions

```kusto
containerserviceeventresources
| where type == "microsoft.containerservice/managedclusters/scheduledevents"
| where properties has "EOLNotification"
| extend description = tostring(properties.description)
| extend details = parse_json(tostring(properties.eventDetails))
| project name, description, details, properties
| order by name asc
```

### Query from the Azure portal

You can run these queries directly in the Azure portal:

1. Go to the [Azure portal](https://portal.azure.com) and search for **Resource Graph Explorer**.
2. Paste one of the queries above into the query editor.
3. Select **Run query** to see results.

You can also access Azure Resource Graph from **Azure Monitor** without needing the monitoring add-on enabled on your cluster.

## Set up email alerts

To receive email notifications when your cluster approaches its end of support date, create a log search alert rule. This follows the same pattern as [maintenance notifications][aks-communication-manager].

1. Go to the resource, then choose **Monitoring** and select **Alerts** and then select **Alert Rules**.

2. The Condition for the alert should be a **Custom log search**.

   :::image type="content" source="./media/auto-upgrade-cluster/custom-log-search.jpg" alt-text="Screenshot of the custom log search in the alert rule blade.":::

3. In the opened "Search query" box, paste the following query. Update the path placeholders with your subscription ID, resource group name, and cluster name.

```kusto
arg("").containerserviceeventresources
| where type == "microsoft.containerservice/managedclusters/scheduledevents"
| where id contains "/subscriptions/<subid>/resourcegroups/<rgname>/providers/Microsoft.ContainerService/managedClusters/<clustername>"
| where properties has "EOLNotification"
| extend description = tostring(properties.description)
| extend details = parse_json(tostring(properties.eventDetails))
| extend eventTime = todatetime(tostring(properties.lastUpdateTime))
| where eventTime >= ago(2h)
| project eventTime, description, details, name, properties
| order by eventTime asc
```

4. Configure the alert conditions with the following settings:
   - **Measurement**: Select "Table rows"
   - **Aggregation**: Select "Count"
   - **Aggregation granularity**: Select "30 minutes"
   - **Threshold value**: Keep at 0
   - **Split by dimensions**: Select "description" and choose "Include all future values"

   :::image type="content" source="./media/auto-upgrade-cluster/edit-alert-rule.jpg" alt-text="Screenshot of the configuration options for alert conditions.":::

   > [!NOTE]
   > Splitting by the "description" dimension creates separate alerts for each notification type: `KubernetesVersionEOLTwoWeeks`, `KubernetesVersionEOLOneWeek`, and `KubernetesVersionOutOfSupport`. These values only appear after your cluster has received its first notification.

5. Check that an action group with the correct email address exists to receive the notifications.

   :::image type="content" source="./media/auto-upgrade-cluster/action-group.png" alt-text="Screenshot of entering appropriate email or SMS into an action group.":::

6. Assign Managed System Identity: After you create the alert rule, assign a managed identity so it can access the necessary resources. To assign a managed identity:
    - In the Azure portal, go to **Monitor** > **Alerts** > **Alert rules**, then select your alert rule.
    - In the alert rule pane, under **Settings**, select **Identity**.
    - Set **System assigned managed identity** to **On**.
    - Select **Save** to enable the managed identity for the alert rule.

    :::image type="content" source="./media/auto-upgrade-cluster/system-assigned-identity.jpg" alt-text="Screenshot of where to assign Managed System Identity.":::

    > [!TIP]
    > If you don't see the Identity option, make sure your alert rule has been created and you have the necessary permissions. Assigning the managed identity is always a separate step after alert rule creation.

7. Make sure to assign the appropriate Reader roles.

    In the alert rule, go to **Settings** > **Identity** > **System assigned managed identity** > **Azure role assignments** > **Add role assignment**.

    Choose the **Reader** role and assign it to the resource group. Repeat "Add role assignment" for the subscription if needed.

### Verification

Check the Azure Resource Graph for notification records using the [query above](#query-for-a-specific-cluster). Each notification is listed as one record in the `containerserviceeventresources` table.

:::image type="content" source="./media/auto-upgrade-cluster/azure-resource-graph.jpeg" alt-text="Screenshot that shows how to look up Azure Resource Graph.":::

## Subscribe to real-time notifications with Event Grid

In addition to querying Azure Resource Graph and setting up log search alerts, you can receive real-time notifications through [Azure Event Grid][event-grid] webhooks. This approach pushes notifications to your endpoint (such as a Logic App, Azure Function, or custom webhook) as soon as they're published.

All AKS scheduled events, including end of support notifications and [maintenance notifications][aks-communication-manager], are published through the same Event Grid system topic.

### Create a system topic

Create an Azure Resource Notifications (ARN) system topic for your subscription. This only needs to be done once per subscription.

```azurecli
az eventgrid system-topic create \
  --name aks-scheduled-events \
  --resource-group <resource-group> \
  --source /subscriptions/<subscription-id> \
  --topic-type microsoft.resourcenotifications.containerserviceeventresources \
  --location global
```

### Create an event subscription

Create an event subscription that routes notifications to your endpoint:

```azurecli
az eventgrid event-subscription create \
  --name aks-eol-notifications \
  --source-resource-id /subscriptions/<subscription-id> \
  --endpoint <your-webhook-url> \
  --included-event-types Microsoft.ResourceNotifications.ContainerServiceEventResources.ScheduledEventEmitted
```

To filter notifications to a specific resource group, add subject filtering:

```azurecli
  --subject-begins-with /subscriptions/<subscription-id>/resourcegroups/<resource-group-name>
```

> [!NOTE]
> The Event Grid system topic delivers all `scheduledEvents` for the subscription, including both maintenance and end of support notifications. Filter by `eventSource` in your endpoint logic: `EOLNotification` for end of support events, `AutoUpgrader` for maintenance events.

## AKS scheduled event notification types

AKS publishes notifications through the `containerserviceeventresources` table in Azure Resource Graph. The following table lists all notification types:

| Category | Event source | Notifications | Description |
|----------|-------------|---------------|-------------|
| End of support | `EOLNotification` | `KubernetesVersionEOLTwoWeeks`, `KubernetesVersionEOLOneWeek`, `KubernetesVersionOutOfSupport` | Proactive alerts when a cluster's Kubernetes version is approaching or has passed end of support |
| Maintenance | `AutoUpgrader` | `Scheduled`, `Started`, `Completed`, `Failed`, `Cancelled` | Notifications about upcoming and in-progress auto-upgrade maintenance windows |

Both categories use the same `scheduledEvents` resource type and can be queried, alerted on, and subscribed to using the same approaches described on this page and the [AKS Communication Manager][aks-communication-manager] page.

## How notifications work

End of support notifications are evaluated periodically by the system for every cluster. No configuration is required on the cluster itself.

- **Community vs LTS**: The system checks your cluster's support plan. Community clusters are evaluated against the community end of support date. [LTS][long-term-support] clusters use the later LTS end of support date.
- **Notification frequency**: Each notification type (`KubernetesVersionEOLTwoWeeks`, `KubernetesVersionEOLOneWeek`) is sent once per cluster version. After the end of support date has passed, `KubernetesVersionOutOfSupport` notifications are sent weekly as a reminder.
- **Version upgrade resets notifications**: If you upgrade your cluster to a newer Kubernetes version, the notification status resets and new notifications are evaluated against the new version's end of support date.
- **No monitoring required**: These notifications are written to Azure Resource Graph and don't require the monitoring add-on to be enabled on your cluster. You can query them from any Azure Resource Graph client, including the Azure portal Resource Graph Explorer, Azure Monitor, Azure CLI, or the REST API.

## Related content

- [AKS Kubernetes release calendar][supported-versions] for current version lifecycle dates.
- [Set up the AKS Communication Manager][aks-communication-manager] for maintenance notification alerts.
- [Long Term Support for AKS][long-term-support] for extended support on Kubernetes versions.
- [Subscribe to AKS events with Event Grid][event-grid] for real-time webhook notifications.
- [Upgrade options for AKS clusters][upgrade-cluster] when your version approaches end of support.

<!-- LINKS - internal -->

[aks-communication-manager]: aks-communication-manager.md
[supported-versions]: supported-kubernetes-versions.md
[long-term-support]: long-term-support.md
[upgrade-cluster]: upgrade-cluster.md
[event-grid]: quickstart-event-grid.md
