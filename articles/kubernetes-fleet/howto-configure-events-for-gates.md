---
title: "Trigger Notifications and Integrations using Approval Gate Events for Azure Kubernetes Fleet Manager"
description: Learn how to set up Event Grid to use Approval Gate events to deliver notifications and provide triggers for automations such as health checks.
ms.topic: how-to
ms.date: 09/22/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
# Customer intent: "As a fleet administrator, I want to configure Event Grid Sytem Topics for Azure Kubernetes Fleet Manager update runs, so that I can use the events to deliver alerts or provide automation triggers."
---

# Trigger Notifications and Integrations using Approval Gate Events for Azure Kubernetes Fleet Manager (Preview)

**Applies to:** :heavy_check_mark: Fleet Manager :heavy_check_mark: Fleet Manager with hub cluster

Fleet Manager update run [approval gates](./update-strategies-gates-approvals.md) provide more controls over when groups or stages in an update run are processed.

Approval gates publish events via an Event Grid System Topic, allowing you to configure event subscriptions to drive notifications via channels like email or trigger automated integration through custom health check endpoints. 

This article provides instructions on how to configure Event Grid so you can take advantage of the published events.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## Understanding Approval Gate Event Grid Event properties

There are three update run gate event types that can be subscribed. 

| Event Grid Event Type                                         | Description |
|---------------------------------------------------------------|-------------|
| Microsoft.ResourceNotifications.AKSResources.FleetGateCreated | Raised when an update run reaches an instance of a Gate resource.         |
| Microsoft.ResourceNotifications.AKSResources.FleetGateUpdated | Raised when the status of a gate changes (Pending to Approved).           |
| Microsoft.ResourceNotifications.AKSResources.FleetGateDeleted | Raised when an update run that contains an instance of a Gate is deleted. |
 
To process events for a specific update run gate, use the following properties to define an advanced Event Grid Event Subscription filter.   

| Event property name | Example | Description |
|---------------------|---------|-------------|
| data.resourceInfo.id | Azure Resource ID |  The full Azure resource identifier for the approval gate instance generating the event.  |
| data.resourceInfo.name | 1eb18051-fff5-4c09-a15f-9eebd2e3b906 |  A unique value that represents the instance of the approval gate.  |
| data.resourceInfo.properties.displayName | "Check with sales teams" | The optional name provided when defining the approval gate in the update strategy.   |
| data.resourceInfo.properties.gateType    | "Approval"               | The type of the gate. There's only one valid choice of "Approval" for now.           |
| data.resourceInfo.properties.state       | "Pending" / "Approved"   | The state of the gate. "Pending" = waiting approval; "Approved" = approval applied.  |
| data.resourceInfo.properties.target.id              | Azure Resource ID          | The full Azure resource identifier for the update run generating the event.        |
| data.resourceInfo.properties.target.updateRunProperties.name | "update-k8s-1.33" | The name of the update run generating the event.                                   |
| data.resourceInfo.properties.target.updateRunProperties.stage | "dev"            | The name of the update stage where the gate is applied. Only present for stages.   |
| data.resourceInfo.properties.target.updateRunProperties.group | "blue"           | The name of the update group where the gate is applied. Only present for groups.   |
| data.resourceInfo.properties.target.updateRunProperties.timing | "Before" / "After" | Denotes if the gate is applied before or after the stage or group.              |

## Before you begin

* Read the [conceptual overview of Fleet updates](./concepts-update-orchestration.md), which provides an explanation of update runs, stages, groups, and strategies referenced in this guide.

* You must have a Fleet resource with one or more member clusters. If not, follow the [quickstart][fleet-quickstart] to create a Fleet resource and join Azure Kubernetes Service (AKS) clusters as members.

* Set the following environment variables:

    ```bash
    export GROUP=<resource-group>
    export FLEET=<fleet-name>
    export SUBSCRIPTION_ID=<fleet-manager-subscriptionid>
    export STRATEGY=<strategy-name>
    ```

* If you're following the Azure CLI instructions in this article, you need Azure CLI version 2.70.0 or later installed. To install or upgrade, see [Install the Azure CLI][azure-cli-install].

* You also need the `fleet` Azure CLI extension version 1.6.0 or later, which you can install by running the following command:

  ```azurecli-interactive
  az extension add --name fleet
  ```

  Run the [`az extension update`][az-extension-update] command to update to the latest version of the extension released:

  ```azurecli-interactive
  az extension update --name fleet
  ```

* When automating the approvals process, any automation must be granted either the [Azure Kubernetes Fleet Manager Contributor][azure-rbac-fleet-manager-contributor-role] Azure RBAC role, or use a custom role that includes the `Microsoft.ContainerService/fleets/gates/write` Action.

## Create Event Grid System Topic

Approval Gates publish events via an Event Grid System Topic that can be created at the Azure Subscription level. Only one Event Grid System Topic of this type (Microsoft.ResourceNotifications.AKSResources) can be created.

Create a new system topic by using the [az eventgrid system-topic create][azure-even-grid-topic-create] command as shown.

  ```azurecli-interactive
  az eventgrid system-topic create \
    --name stpc-fleet-approvals-01 \
    --resource-group $GROUP \
    --source /subscriptions/$SUBSCRIPTION_ID \
    --topic-type Microsoft.ResourceNotifications.AKSResources \
    --location Global
  ```

## Create Event Subscription

In this sample we create a subscription for pending Approval Gate events named "Check with sales team" that applied before the "Dev" stage in any update run, using an existing Azure Function process the events. 

Create a new subscription by using the [az eventgrid system-topic event-subscription create][azure-event-grid-sub-create] command as shown.

  ```azurecli-interactive
  az eventgrid system-topic event-subscription create \
    --name stes-fleet-gates-sales-before-dev \
    --resource-group $GROUP \
    --system-topic-name stpc-fleet-approvals-01 \
    --included-event-types Microsoft.ResourceNotifications.AKSResources.FleetGateCreated \
    --advanced-filter data.resourceInfo.properties.displayName StringContains "Check with sales teams" \
    --advanced-filter data.resourceInfo.properties.state StringIn Pending \
    --advanced-filter data.resourceinfo.properties.target.updateRunProperties.timing StringIn Before \
    --advanced-filter data.resourceinfo.properties.target.updateRunProperties.stage StringIn Dev \
    --endpoint-type azurefunction
    --endpoint /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$GROUP/providers/Microsoft.Web/sites/{functionappname}/functions/{functionname}
    --max-delivery-attempts 10 \
    --event-ttl 120
  ```

## Handle Event Grid Subscription Event

Azure Event Grid Event Subscriptions support a number of different [event handler endpoint types][azure-event-grid-event-handlers] including Azure Functions, Service Bus Queues or Azure Logic Apps via webhooks.

In this example we use a Python Azure Function to handle the event and mark the approval as completed.

We can use the Fleet Manger Python libraries to simplfy the call back mark the gate as completed.

As noted earlier, the identity for the Azure Function must have been granted the [Azure Kubernetes Fleet Manager Contributor][azure-rbac-fleet-manager-contributor-role] Azure RBAC role.

```python
import logging
import azure.functions as func

from types import SimpleNamespace
from azure.identity import DefaultAzureCredential
from azure.mgmt.containerservicefleet import ContainerServiceFleetMgmtClient

app = func.FunctionApp()

@app.event_grid_trigger(arg_name="azeventgrid")
def HandleApprovalGateEvent(azeventgrid: func.EventGridEvent):
    logging.info('Python EventGrid trigger processed an event')

    event = json.loads(json.dumps(azeventgrid.get_json()), object_hook=lambda d: SimpleNamespace(**d))

    target_id = event.data.resourceInfo.properties.target.id
    parts = target_id.split('/')

    # Extract the values
    subscription_id = parts[2]  # subscriptions/{subscription_id}
    resource_group = parts[4]   # resourceGroups/{resource_group}
    fleet_name = parts[8]       # fleets/{fleet_name}

    data = azeventgrid.get_json()

    # read the name value for the gate
    gate_name_uuid = data["resourceInfo"]["name"]

    # perform other functions
    # ....
    # ....

    client = ContainerServiceFleetMgmtClient(
      credential=DefaultAzureCredential(),
      subscription_id=subscription_id,
    )

    response = client.gates.begin_update(
      resource_group_name="rg1",
      fleet_name="fleet1",
      gate_name=gate_name_uuid,
      properties={"properties": {"state": "Completed"}},
    ).result()
```

## Next steps

* [How-to: Monitor update runs for Azure Kubernetes Fleet Manager](./howto-monitor-update-runs.md).
* [Multi-cluster updates FAQs](./faq.md#multi-cluster-updates---automated-or-manual-faqs).

<!-- INTERNAL LINKS -->
[azure-rbac-fleet-manager-contributor-role]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-fleet-manager-contributor-role
[gates-update-rest-api]: /rest/api/fleet/gates/update?view=rest-fleet-2025-04-01-preview&tabs=Python#gatestate

[az-fleet-autoupgradeprofile-create]: /cli/azure/fleet/autoupgradeprofile#az-fleet-autoupgradeprofile-create
[az-fleet-autoupgradeprofile-list]: /cli/azure/fleet/autoupgradeprofile#az-fleet-autoupgradeprofile-list
[az-fleet-autoupgradeprofile-show]: /cli/azure/fleet/autoupgradeprofile#az-fleet-autoupgradeprofile-show
[az-fleet-autoupgradeprofile-delete]: /cli/azure/fleet/autoupgradeprofile#az-fleet-autoupgradeprofile-delete
[azure-cli-install]: /cli/azure/install-azure-cli
[azure-event-grid-sys-topics]: /azure/event-grid/system-topics
[azure-even-grid-topic-create]: /cli/azure/eventgrid/system-topic#az-eventgrid-system-topic-create
[azure-event-grid-sub-create]: /cli/azure/eventgrid/system-topic/event-subscription#az-eventgrid-system-topic-event-subscription-create
[azure-event-grid-event-handlers]: /azure/event-grid/event-handlers
[az-fleet-updaterun-generate]: /cli/azure/fleet/autoupgradeprofile#az-fleet-autoupgradeprofile-generate-update-run

<!-- LINKS -->
[fleet-quickstart]: quickstart-create-fleet-and-members.md
