---
title: "Automate Azure Kubernetes Fleet Manager Approval Gates with Event Grid Events"
description: Learn how to use Approval Gate events delivered via Event Grid to build automations to process approval gates using health checks and other integration types.
ms.topic: how-to
ms.date: 09/22/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
# Customer intent: "As a fleet administrator, I want to configure Event Grid Sytem Topics for Azure Kubernetes Fleet Manager update runs, so that I can use the events to deliver alerts or provide automation triggers."
---

# Automate Azure Kubernetes Fleet Manager Approval Gates with Event Grid Events (Preview)

**Applies to:** :heavy_check_mark: Fleet Manager :heavy_check_mark: Fleet Manager with hub cluster

Fleet Manager update run [approval gates](./update-strategies-gates-approvals.md) provide more control over when update groups or stages are processed.

Approval gates publish events via an Event Grid System Topic. Event subscriptions on the Topic can be used as a trigger for automations to control the clearance of pending approvals. 

Automations can include integration with other Azure services, or with external systems to perform actions such as raising service desk tickets, or using health check APIs to ensure cluster workloads are healthy before allowing an update run to continue.

This article provides instructions on how to configure Event Grid and event subscriptions to access published events.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## Understanding Approval Gate Event Grid Events

There are three update run gate event types that can be used in event subscriptions. 

| Event Grid Event Type                                         | Description |
|---------------------------------------------------------------|-------------|
| Microsoft.ResourceNotifications.AKSResources.FleetGateCreated | Raised when an update run reaches an instance of a Gate resource.         |
| Microsoft.ResourceNotifications.AKSResources.FleetGateUpdated | Raised when the status of a gate changes (Pending to Completed).           |
| Microsoft.ResourceNotifications.AKSResources.FleetGateDeleted | Raised when an update run that contains an instance of a Gate is deleted. |
 
To process events for an update run gate instance, use the following event properties in advanced Event Grid Event Subscription filters.   

| Event property name | Example | Description |
|---------------------|---------|-------------|
| data.resourceInfo.id | Azure Resource ID |  The full Azure resource identifier for the approval gate instance generating the event.  |
| data.resourceInfo.name | 1eb18051-fff5-4c09-a15f-9eebd2e3b906 |  A unique value that represents the instance of the approval gate.  |
| data.resourceInfo.properties.displayName | "Check with sales teams" | The optional name provided when defining the approval gate in the update strategy.   |
| data.resourceInfo.properties.gateType    | "Approval"               | The type of the gate. There's only one valid choice of "Approval" for now.           |
| data.resourceInfo.properties.state       | "Pending" / "Completed"   | The state of the gate. "Pending" = waiting approval; "Completed" = approval applied.  |
| data.resourceInfo.properties.target.id              | Azure Resource ID          | The full Azure resource identifier for the update run generating the event.        |
| data.resourceInfo.properties.target.updateRunProperties.name | "update-k8s-1.33" | The name of the update run generating the event.                                   |
| data.resourceInfo.properties.target.updateRunProperties.stage | "dev"            | The name of the update stage. Can appear for stage gates and group gates within the stage. |
| data.resourceInfo.properties.target.updateRunProperties.group | "blue"           | The name of the update group where the gate is applied. Only present for groups.   |
| data.resourceInfo.properties.target.updateRunProperties.timing | "Before" / "After" | Denotes if the gate is applied before or after the stage or group.              |

A raw Event Grid Event follows. It's contained in a JSON array, though most event handlers will receive only a single event.

```json
[
    {
        "id": "1b6e818e-5ec3-4c22-9e9c-03c1fd05ac21",
        "topic": "/subscriptions/xxxxxxxxxx",
        "subject": "/subscriptions/xxxxxxxxxx/resourceGroups/sw-ms-demo-01/providers/Microsoft.ContainerService/fleets/flt-mgr-approvals-01/gates/1eb18051-fff5-4c09-a15f-9eebd2e3b906",
        "data": {
            "resourceInfo": {
                "id": "/subscriptions/xxxxxxxxxx/resourceGroups/sw-ms-demo-01/providers/Microsoft.ContainerService/fleets/flt-mgr-approvals-01/gates/1eb18051-fff5-4c09-a15f-9eebd2e3b906",
                "name": "1eb18051-fff5-4c09-a15f-9eebd2e3b906",
                "type": "Microsoft.ContainerService/fleets/gates",
                "properties": {
                    "displayName": "Check with sales team",
                    "gateType": "Approval",
                    "provisioningState": "Succeeded",
                    "state": "Pending",
                    "target": {
                        "id": "/subscriptions/xxxxxxxxxx/resourceGroups/sw-ms-demo-01/providers/Microsoft.ContainerService/fleets/flt-mgr-approvals-01/updateRuns/test-01",
                        "updateRunProperties": {
                            "name": "test-01",
                            "stage": "west-eu-development",
                            "timing": "Before"
                        }
                    }
                }
            },
            "operationalInfo": {
                "resourceEventTime": "2025-09-23T02:50:21.2604165+00:00"
            },
            "apiVersion": "2025-04-01-preview"
        },
        "eventType": "Microsoft.ResourceNotifications.AksResources.FleetGateCreated",
        "dataVersion": "1",
        "metadataVersion": "1",
        "eventTime": "2025-09-23T02:50:21.2604165Z"
    }
]
```
  


## Before you begin

* Read the [conceptual overview of Fleet updates](./concepts-update-orchestration.md), which provides an explanation of update runs, stages, groups, and strategies referenced in this guide.

* You must have a Fleet Manager with one or more member clusters. If not, follow the [quickstart][fleet-quickstart] to create a Fleet resource and join Azure Kubernetes Service (AKS) clusters as members.

* You must have an Update Strategy that contains at least one [Approval Gate](./update-strategies-gates-approvals.md).

* Ensure any automation holds either the [Azure Kubernetes Fleet Manager Contributor][azure-rbac-fleet-manager-contributor-role] Azure RBAC role, or a custom RBAC role that includes the `Microsoft.ContainerService/fleets/gates/write` Action.

* You need Azure CLI version 2.70.0 or later installed. To install or upgrade, see [Install the Azure CLI][azure-cli-install].

* You also need the `fleet` Azure CLI extension version 1.6.2 or later, which you can install by running the following command:

  ```azurecli-interactive
  az extension add --name fleet
  ```

  Run the [`az extension update`][az-extension-update] command to update to the latest version of the extension released:

  ```azurecli-interactive
  az extension update --name fleet
  ```

* Set the following environment variables:

    ```bash
    export GROUP=<resource-group>
    export FLEET=<fleet-name>
    export SUBSCRIPTION_ID=<fleet-manager-subscriptionid>
    ```

## Create Event Grid System Topic

Approval Gates publish events via an Event Grid System Topic that can be created at the Azure Subscription level. Only one Event Grid System Topic of the type `Microsoft.ResourceNotifications.AKSResources` can be created.

Create a new system topic by using the [az eventgrid system-topic create][azure-even-grid-topic-create] command as shown.

```azurecli-interactive
az eventgrid system-topic create \
  --name stpc-aks-resource-notifications \
  --resource-group $GROUP \
  --source /subscriptions/$SUBSCRIPTION_ID \
  --topic-type Microsoft.ResourceNotifications.AKSResources \
  --location Global
```

## Create Event Subscription

In this example, we create a subscription for pending Approval Gate events originating from a specific Fleet Manager `flt-mgr-approvals-01`. The Approval Gate must be named `Check with sales teams` and be applied `Before` the `Dev` stage in any update run. Finally, the events are routed to an existing Azure Function which processes the events. 

Create a new subscription by using the [az eventgrid system-topic event-subscription create][azure-event-grid-sub-create] command as shown.

```azurecli-interactive
az eventgrid system-topic event-subscription create \
  --name stes-fleet-gates-sales-before-dev \
  --resource-group $GROUP \
  --system-topic-name stpc-aks-resource-notifications \
  --included-event-types Microsoft.ResourceNotifications.AKSResources.FleetGateCreated \
  --advanced-filter data.resourceInfo.properties.target.id StringContains "fleets/flt-mgr-approvals-01" \
  --advanced-filter data.resourceInfo.properties.displayName StringContains "Check with sales teams" \
  --advanced-filter data.resourceInfo.properties.state StringIn Pending \
  --advanced-filter data.resourceInfo.properties.target.updateRunProperties.timing StringIn Before \
  --advanced-filter data.resourceInfo.properties.target.updateRunProperties.stage StringIn Dev \
  --endpoint-type azurefunction \
  --endpoint /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$GROUP/providers/Microsoft.Web/sites/fap-process-fleet-events/functions/fa-handle-pre-dev-events \
  --max-delivery-attempts 10 \
  --event-ttl 120
```

## Handle Event Grid Subscription Event

Azure Event Grid Event Subscriptions support many different [event handler endpoint types][azure-event-grid-event-handlers] including Azure Functions, Service Bus Queues, Azure Logic Apps, or other third party systems via webhooks.

In this example, we use a Python Azure Function to process the event raised by the gate. The Azure Function also uses the [Fleet Manager Python library](https://pypi.org/project/azure-mgmt-containerservicefleet/) to mark the approval as completed.

The identity executing the Azure Function must have the [Azure Kubernetes Fleet Manager Contributor][azure-rbac-fleet-manager-contributor-role] Azure RBAC role.

```python
import logging
import azure.functions as func

from azure.identity import DefaultAzureCredential
from azure.mgmt.containerservicefleet import ContainerServiceFleetMgmtClient
from azure.core.exceptions import AzureError

app = func.FunctionApp()

@app.event_grid_trigger(arg_name="azeventgrid")
def HandleFleetGateEvent(azeventgrid: func.EventGridEvent):
    logging.info('Processing gate created event.')
    
    try:
        event_data = azeventgrid.get_json()

        target_resource_id = event_data["resourceInfo"]["properties"]["target"]["id"]
        parts = target_resource_id.split('/')

        # Extract the values required to update gate resource later

        subscription_id = parts[2]  # subscriptions/{subscription_id}
        resource_group = parts[4]   # resourceGroups/{resource_group}
        fleet_name = parts[8]       # fleets/{fleet_name}

        # The UUID of the instance of the gate. This is required to
        # integrate with just this instance.
        gate_name_uuid = event_data["resourceInfo"]["name"]

        #
        # Perform activities here to check if OK to proceed
        #

        # Update the Gate instance to mark it as 'Completed'
      
        # Create new Fleet Service Management client 
        # Requires v4.0.0b1 of azure-mgmt-containerservicefleet
        client = ContainerServiceFleetMgmtClient(
            credential=DefaultAzureCredential(),
            subscription_id=subscription_id
        )

        # End request to update gate status
        response = client.gates.begin_update(
            resource_group_name=resource_group,
            fleet_name=fleet_name,
            gate_name=gate_name_uuid,
            properties={"properties": {"state": "Completed"}}
        ).result()
        
        logging.info(f"Successfully updated gate {gate_name_uuid} to Completed state")
        
    except KeyError as e:
        logging.error(f"Missing required field in event data: {e}")
        
    except IndexError as e:
        logging.error(f"Error parsing target_id - unexpected format: {e}")
        
    except AzureError as e:
        logging.error(f"Azure API error: {e}")
        
    except Exception as e:
        logging.error(f"Unexpected error: {e}")
```

Your `requirements.txt` must include the shown modules.

```
azure-common
azure-core
azure-functions
azure-identity
azure-mgmt-containerservicefleet==4.0.0b1
azure-mgmt-core
```

In this article, we explored how you can configure Event Grid to deliver Approval Gate events to an Azure Function for processing, including how to use the Fleet Manager Python library to mark an Approval Gate as completed,  allowing the update run to continue.  

## Next steps

* [How-to: Monitor update runs for Azure Kubernetes Fleet Manager](./howto-monitor-update-runs.md).
* [Multi-cluster updates FAQs](./faq.md#multi-cluster-updates---automated-or-manual-faqs).

<!-- INTERNAL LINKS -->
[azure-rbac-fleet-manager-contributor-role]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-fleet-manager-contributor-role

[azure-cli-install]: /cli/azure/install-azure-cli
[az-extension-update]: /cli/azure/extension#az-extension-update
[azure-even-grid-topic-create]: /cli/azure/eventgrid/system-topic#az-eventgrid-system-topic-create
[azure-event-grid-sub-create]: /cli/azure/eventgrid/system-topic/event-subscription#az-eventgrid-system-topic-event-subscription-create
[azure-event-grid-event-handlers]: /azure/event-grid/event-handlers

<!-- LINKS -->
[fleet-quickstart]: quickstart-create-fleet-and-members.md
