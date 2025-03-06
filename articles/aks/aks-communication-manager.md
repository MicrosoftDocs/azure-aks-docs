---
title: AKS Communication Manager (Preview)
description: Start here to learn how to set up and receive notices in Azure Resource Notification for AKS Maintenance events. 
ms.date: 10/16/2024
ms.custom: aks communication manager
ms.topic: conceptual
author: kaarthis
ms.author: kaarthis
ms.subservice: aks-upgrade
---

# Azure Kubernetes Service Communication Manager(Preview)
The AKS Communication Manager streamlines notifications for all your AKS maintenance tasks by using Azure Resource Notification and Azure Resource Graph frameworks. This tool enables you to monitor your upgrades closely by providing timely alerts on event triggers and outcomes. If maintenance fails, it notifies you with the reasons for the failure, reducing operational hassles related to observability and follow-ups. Currently in preview, you can set up notifications for all types of auto upgrades that utilize maintenance windows by following these steps.

## Prerequisites

- Configure your cluster for either [Auto upgrade channel][aks-auto-upgrade] or [Node Auto upgrade channel][aks-node-auto-upgrade].

- Create [Planned maintenance window][planned-maintenance] as mentioned here for your auto upgrade configuration. 

> [!NOTE]
> Once set up, the communication manager sends advance notices - one week before maintenance starts and one day before maintenance starts. This is in addition to the timely alerts during the maintenance operation. 

## How to set up communication manager

1. Create an Azure "Logic App" resource. It's used to send auto upgrade event notices to your email.

 :::image type="content" source="./media/auto-upgrade-cluster/logic-apps.jpg" alt-text="The screenshot of the created blade for an Azure Logic Apps in the Azure portal. The plan type field shows 'Consumption' selected.":::

2. Open the created Logic App and click "Logic app designer," then click "Add a trigger" button.

 :::image type="content" source="./media/auto-upgrade-cluster/logic-app-1.jpeg" alt-text="The screenshot shows how to add a trigger.":::
 
3. In the opened "Add a trigger" box, type "http" in the search box, and then select "When an HTTP request is received" trigger.

  :::image type="content" source="./media/auto-upgrade-cluster/trigger-1.jpeg" alt-text="The screenshot shows HTTP request is received.":::

4. In the opened "When an HTTP request is received," click "Use sample payload to generate schema".

  :::image type="content" source="./media/auto-upgrade-cluster/trigger-2.jpeg" alt-text="The screenshot shows Sample Payload is used.":::

5. In the opened "Enter or paste a sample JSON payload" box, paste the following JSON data and click "Done" button.

 ```[
  {
    "id": "11112222-bbbb-3333-cccc-4444dddd5555",
    "topic": "/subscriptions/66667777-aaaa-8888-bbbb-9999cccc0000",
    "subject": "/subscriptions/66667777-aaaa-8888-bbbb-9999cccc0000/resourcegroups/comms-test/providers/Microsoft.ContainerService/managedClusters/comms-sp/scheduledEvents/55556666-ffff-7777-aaaa-8888bbbb9999",
    "data": {
      "resourceInfo": {
        "id": "/subscriptions/66667777-aaaa-8888-bbbb-9999cccc0000/resourcegroups/comms-test/providers/Microsoft.ContainerService/managedClusters/comms-sp/scheduledEvents/55556666-ffff-7777-aaaa-8888bbbb9999",
        "name": "55556666-ffff-7777-aaaa-8888bbbb9999",
        "type": "Microsoft.ContainerService/managedClusters/scheduledEvents",
        "location": "westus2",
        "properties": {
          "description": "ScheduledEvents",
          "eventId": "22223333-cccc-4444-dddd-5555eeee6666",
          "eventSource": "AutoUprader",
          "eventStatus": "Started",
          "eventDetails": "Start to upgrade security vhd",
          "scheduledTime": "2024-04-16T22:17:12.103268606Z",
          "startTime": "0001-01-01T00:00:00.0000000Z",
          "lastUpdateTime": "0001-01-01T00:00:00.0000000Z",
          "resources": [
            "/subscriptions/66667777-aaaa-8888-bbbb-9999cccc0000/resourcegroups/comms-test/providers/Microsoft.ContainerService/managedClusters/comms-sp"
          ],
          "resourceType": "ManagedCluster"
        }
      },
      "operationalInfo": {
        "resourceEventTime": "2024-04-16T22:17:12.1032748"
      },
      "apiVersion": "2023-11-02-preview"
    },
    "eventType": "Microsoft.ResourceNotifications.MaintenanceResources.ScheduledEventEmitted",
    "dataVersion": "1",
    "metadataVersion": "1",
    "eventTime": "2024-04-16T22:17:12.1032748Z",
    "EventProcessedUtcTime": "2024-04-16T22:36:09.9073134Z",
    "PartitionId": 0,
    "EventEnqueuedUtcTime": "2024-04-16T22:17:13.1700000Z"
  }
 ]
 ```
6. Click the "+" button and "Add an action". Then sign into your preferred email account in outlook.com with password.

   :::image type="content" source="./media/auto-upgrade-cluster/add-action.jpeg" alt-text="The screenshot shows how to add an action.":::

7. In the opened "Add an action" box, type "outlook" in the search box, and then select "Send an email (V2)" action.

 :::image type="content" source="./media/auto-upgrade-cluster/add-action-2.jpg" alt-text="The screenshot shows how to send an email.":::

8. Customize by providing recipient email. Click the Subject and Body fields, and there's a tiny lighting icon which provides encapsulated data fields from the message, to facilitate orchestration of the email content.

 :::image type="content" source="./media/auto-upgrade-cluster/customize-email.jpg" alt-text="The screenshot shows how to customize email.":::

9. Click the "Save" button.

 :::image type="content" source="./media/auto-upgrade-cluster/save.png" alt-text="The screenshot shows how to save.":::

10. Click the "When a HTTP request is received" button and copy the URL in the "HTTP POST URL" field. This URL is used shortly to configure event subscription web hook.

 :::image type="content" source="./media/auto-upgrade-cluster/http-post.png" alt-text="The screenshot shows how to copy Http post URL.":::

## Create ARN system topic and event subscription.

Click "Event Subscription" to create an event subscription of the system topic.

:::image type="content" source="./media/auto-upgrade-cluster/event-sub-1.jpg" alt-text="The screenshot shows how to create an event subscription.":::

Then fill in the event subscription information, in the "EndPoint Type," choose "Web hook," and configure it using the URL when configure "When a HTTP request is received" trigger.

:::image type="content" source="./media/auto-upgrade-cluster/event-sub-2.jpg" alt-text="The screenshot shows how to configure endpoint.":::

You can also do it via CLI as shown here

```azurecli-interactive
    az eventgrid system-topic create --name arnSystemTopic --resource-group testrg --source /subscriptions/TestSub --topic-type microsoft.resourcenotifications.containerserviceeventresources --location global 
```

Configure receive notifications for resources in a resource group, enable subject filtering with the resource group URI.

:::image type="content" source="./media/auto-upgrade-cluster/endpoint-type.jpg" alt-text="The screenshot shows how to configure endpoint type.":::

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