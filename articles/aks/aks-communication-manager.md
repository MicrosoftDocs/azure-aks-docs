---
title: AKS Communication Manager
description: Start here to learn how to set up and recieve notices in Azure Resource Notification for AKS Maintenance events. 
ms.date: 10/16/2024
ms.custom: aks communication manager
ms.topic: conceptual
author: kaarthis
ms.author: kaarthis
ms.subservice: aks-maintenances
---

# Azure Kubernetes Service Communication Manager

The AKS Communication Manager facilitates notifications for all your AKS maintenance activities using the power of Azure Resource Notification and Azure Resource Graph frameworks. Currently in preview, you can follow these steps to set up notifications for all types of auto upgrades that utilize maintenance windows.

## Prerequisites

1. Configure your cluster for either [Auto upgrade channel][aks-auto-upgrade] or [Node Auto upgrade channel][aks-node-auto-upgrade].

2. Create [Planned maintenance window][planned-maintenance] as mentioned here for your auto upgrade above. 

## How to set up communication manager

1. Create Logic Apps as below

Create an Azure "Logic App" resource. It will be used to send auto upgrade event notices to your email.

    :::image type="content" source="./media/auto-upgrade-cluster/Logic_apps.jpg" alt-text="The screenshot of the create blade for an Azure Logic Apps in the Azure portal. The plan type field shows 'Consumption' selected.":::

2. Open the created Logic App and click "Logic app designer" on the left, then click "Add a trigger" button.

 :::image type="content" source="./media/auto-upgrade-cluster/Logic_App1.jpeg" alt-text="The screenshot shows how to add a trigger.":::

 3. In the opened "Add a trigger" box, type "http" in the search box, and then select "When a HTTP request is received" trigger.

  :::image type="content" source="./media/auto-upgrade-cluster/Trigger1.jpeg" alt-text="The screenshot shows HTTP request is received.":::

  4. In the opened "When a HTTP request is received", click "Use sample payload to generate schema".

  :::image type="content" source="./media/auto-upgrade-cluster/Trigger2.jpeg" alt-text="The screenshot shows Sample Payload is used.":::

  5. In the opened "Enter or paste a sample JSON payload" box, paste the following JSON data and click "Done" button

   ```[
  {
    "id": "5bdb52cf-5489-4845-86c8-7fe94a4fc6c1",
    "topic": "/subscriptions/26fe00f8-9173-4872-9134-bb1d2e00343a",
    "subject": "/subscriptions/26fe00f8-9173-4872-9134-bb1d2e00343a/resourcegroups/jusu-test/providers/Microsoft.ContainerService/managedClusters/jusu-sp/scheduledEvents/eb3646f9-4ec9-46d5-8a9d-440a75ee2845",
    "data": {
      "resourceInfo": {
        "id": "/subscriptions/26fe00f8-9173-4872-9134-bb1d2e00343a/resourcegroups/jusu-test/providers/Microsoft.ContainerService/managedClusters/jusu-sp/scheduledEvents/eb3646f9-4ec9-46d5-8a9d-440a75ee2845",
        "name": "eb3646f9-4ec9-46d5-8a9d-440a75ee2845",
        "type": "Microsoft.ContainerService/managedClusters/scheduledEvents",
        "location": "westus2",
        "properties": {
          "description": "ScheduledEvents",
          "eventId": "bbe82027-0444-4f73-897a-0bbfe3af66f1",
          "eventSource": "AutoUprader",
          "eventStatus": "Started",
          "eventDetails": "Start to upgrade security vhd",
          "scheduledTime": "2024-04-16T22:17:12.103268606Z",
          "startTime": "0001-01-01T00:00:00.0000000Z",
          "lastUpdateTime": "0001-01-01T00:00:00.0000000Z",
          "resources": [
            "/subscriptions/26fe00f8-9173-4872-9134-bb1d2e00343a/resourcegroups/jusu-test/providers/Microsoft.ContainerService/managedClusters/jusu-sp"
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
6. Click the "+" button and "Add an action"

   :::image type="content" source="./media/auto-upgrade-cluster/Add_an_Action.jpeg" alt-text="The screenshot shows how to add an action.":::

7. In the opened "Add an action" box, type "outlook" in the search box, and then select "Send an email (V2)" action.

 :::image type="content" source="./media/auto-upgrade-cluster/Add_Action2.jpeg" alt-text="The screenshot shows how to add an action.":::

8. Customize by providing recipient email. Click the Subject and Body fields, and there is a tiny lighting icon which provides encapsulated data fields from the message, to facilitate orchestrion of the email content.

 :::image type="content" source="./media/auto-upgrade-cluster/Customize_email.jpeg" alt-text="The screenshot shows how to customize email.":::

 9. Click the "Save" button.

 :::image type="content" source="./media/auto-upgrade-cluster/Save.jpeg" alt-text="The screenshot shows how to save.":::

 10. Click the "When a HTTP request is received" button and copy the URL in the "HTTP POST URL" field. This URL will be used shortly to configure event subscription web hook.

 :::image type="content" source="./media/auto-upgrade-cluster/Http_post.jpeg" alt-text="The screenshot shows how to copy Http post URL.":::

## Create ARN system topic and event subscription.

Click "Event Subscription" to create an event subscription of the above system topic.

:::image type="content" source="./media/auto-upgrade-cluster/System_Topic.jpeg" alt-text="The screenshot shows how to create an event subscription.":::

Then fill in the event subscription information, in the "EndPoint Type", choose "Web hook", and configure it using the URL when configure "When a HTTP request is received" trigger.

:::image type="content" source="./media/auto-upgrade-cluster/Event_subscription.jpeg" alt-text="The screenshot shows how to configure endpoint.":::

Configure receive notifications for resources in a resource group, enable subject filtering with the resource group URI.

:::image type="content" source="./media/auto-upgrade-cluster/Endpoint_type.jpeg" alt-text="The screenshot shows how to configure endpoint type":::

## Verification:
Wait for the auto upgrader to start to upgrade the cluster. Then verify.

Check Azure Resource Graph database for the scheduled notification record. Each scheduled event notification should be listed as one record in the "containerserviceeventresources" table.
!

:::image type="content" source="./media/auto-upgrade-cluster/ARG.jpeg" alt-text="How to look up ARG":::

<!-- INTERNAL LINKS -->
[aks-auto-upgrade]:./auto-upgrade-cluster.md
[aks-node-auto-upgrade]:./auto-upgrade-node-os-image.md
[planned-maintenance]:./planned-maintenance.md