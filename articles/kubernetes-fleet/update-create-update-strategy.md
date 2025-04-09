---
title: "Define re-useable update strategies for multi-clusters updates using Azure Kubernetes Fleet Manager"
description: See how you can define staged update strategies that can be re-used across multiple update runs and auto-upgrade profiles in Azure Kubernetes Fleet Manager.
ms.topic: how-to
ms.date: 11/11/2024
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
---

# Define re-usable update strategies using Azure Kubernetes Fleet Manager

Administrators can control the sequence of updates to Fleet-managed clusters by defining stages, groups and optional inter-stage pauses. These sequences can be saved as update strategies which can be managed independently of update runs or auto-upgrades, allowing strategies to be reused as required.

This article covers how to define update strategies using groups and stages. 

:::image type="content" source="./media/conceptual-update-orchestration-inline.png" alt-text="A diagram showing an example update strategy containing two update stages. Each update stage contains two update groups. Each update group contains two member clusters." lightbox="./media/conceptual-update-orchestration-inline.png":::

## Prerequisites

* Read the [conceptual overview of Fleet updates](./concepts-update-orchestration.md), which provides an explanation of update runs, stages, groups, and strategies referenced in this guide.

* You must have a Fleet resource with one or more member clusters. If not, follow the [quickstart][fleet-quickstart] to create a Fleet resource and join Azure Kubernetes Service (AKS) clusters as members.

* Set the following environment variables:

    ```bash
    export GROUP=<resource-group>
    export FLEET=<fleet-name>
    export CLUSTERID=<aks-cluster-resource-id>
    export STRATEGY=<strategy-name>
    ```

* If you're following the Azure CLI instructions in this article, you need Azure CLI version 2.70.0 or later installed. To install or upgrade, see [Install the Azure CLI][azure-cli-install].

* You also need the `fleet` Azure CLI extension version 1.5.0 or later, which you can install by running the following command:

  ```azurecli-interactive
  az extension add --name fleet
  ```

  Run the [`az extension update`][az-extension-update] command to update to the latest version of the extension released:

  ```azurecli-interactive
  az extension update --name fleet
  ```

## Assign clusters to update groups

Before clusters can be used in update strategies they must be added to update groups which can be used in update stages. Within an update stage, updates are applied to each update group in parallel. Within an update group, member clusters update sequentially.

You can assign a member cluster to a specific update group in one of two ways:

* [Assign to group when adding member cluster to the fleet](#assign-to-group-when-adding-member-cluster-to-the-fleet).
* [Assign an existing fleet member to an update group](#assign-an-existing-fleet-member-to-an-update-group).

> [!NOTE]
> A fleet member can only be a part of one update group, but an update group can have multiple fleet members assigned to it.
> An update group itself is not a separate resource type. Update groups are only strings representing references from the fleet members. So, if all fleet members with references to a common update group are deleted, that specific update group will cease to exist as well.

### Assign to group when adding member cluster to the fleet

#### [Azure portal](#tab/azure-portal)

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, under **Settings**, select **Member clusters** > **Add**.

    :::image type="content" source="./media/create-update-strategy/add-members-inline.png" alt-text="Screenshot of the Azure portal page for Azure Kubernetes Fleet Manager for adding member clusters." lightbox="./media/create-update-strategy/add-members.png":::

1. Select the cluster that you want to add, and then select **Next: Review + add**.

1. Enter the name of the update group that you want to assign the cluster to, and then select **Add**.

    :::image type="content" source="./media/create-update-strategy/add-members-assign-group-inline.png" alt-text="Screenshot of the Azure portal page for Azure Kubernetes Fleet Manager review and add step for member clusters." lightbox="./media/create-update-strategy/add-members-assign-group.png":::

#### [Azure CLI](#tab/cli)

Assign a member cluster to an update group when adding the member cluster to the fleet using the [`az fleet member create`][az-fleet-member-create] command with the `--update-group` parameter set to the name of the update group.

```azurecli-interactive
az fleet member create \
    --resource-group $GROUP \
    --fleet-name $FLEET \
    --name member1 \
    --member-cluster-id $CLUSTERID \
    --update-group group-1a
```

---

### Assign an existing fleet member to an update group

#### [Azure portal](#tab/azure-portal)

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, under **Settings**, select **Member clusters**.
1. Select the clusters that you want to assign to an update group, and then select **Assign update group**

    :::image type="content" source="./media/create-update-strategy/existing-members-assign-group-inline.png" alt-text="Screenshot of the Azure portal page for assigning existing member clusters to a group." lightbox="./media/create-update-strategy/existing-members-assign-group.png":::

1. Enter the name of the update group that you want to assign the cluster to, and then select **Assign**.

    :::image type="content" source="./media/create-update-strategy/group-name-inline.png" alt-text="Screenshot of the Azure portal page for member clusters that shows the form for updating a member cluster's group." lightbox="./media/create-update-strategy/group-name.png":::

#### [Azure CLI](#tab/cli)

Assign an existing fleet member to an update group using the [`az fleet member update`][az-fleet-member-update] command with the `--update-group` flag set to the name of the update group.

```azurecli-interactive
az fleet member update \
 --resource-group $GROUP \
 --fleet-name $FLEET \
 --name member1 \
 --update-group group-1a
```

---

## Create an update strategy

An update strategy consists of one or more stages, where a stage can contain one or more update groups.

### [Azure portal](#tab/azure-portal)

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, under **Settings**, select **Multi-cluster update** > **Strategies**, then **Create**.
1. Enter a name for the strategy.
1. The first time you view the page, an update strategy explanation diagram is displayed which can help visualize how strategies function.

    :::image type="content" source="./media/create-update-strategy/create-strategy-inline.png" alt-text="A screenshot of the Azure portal showing creation of update strategy." lightbox="./media/create-update-strategy/create-strategy-lightbox.png":::

1. Select **Create Stage** and enter:
    * **Stage name** - name the stage - it must be unique across all stage names in the fleet.
    * **(Optional) Pause after stage** - select this option if you would like to define a pause before moving to the next stage.
    * **(Optional) Pause duration** - select a pre-defined duration, or enter a custom value in seconds.

    :::image type="content" source="./media/create-update-strategy/create-stage-basics-inline.png" alt-text="A screenshot of the Azure portal showing creation of Azure Kubernetes Fleet Manager update strategy stage." lightbox="./media/create-update-strategy/create-stage-basics.png":::

1. Assign one or more **Update Group** to the stage, and then select **Create**.

    :::image type="content" source="./media/create-update-strategy/create-stage-choose-groups-inline.png" alt-text="A screenshot of the Azure portal showing creation of Azure Kubernetes Fleet Manager update strategy stage, selecting update groups to include." lightbox="./media/create-update-strategy/create-stage-choose-groups.png":::

### [Azure CLI](#tab/cli)

For this scenario, we'll create stages and groups to match the details used for the Azure portal process.  

1. Create a JSON file to define the stages and groups for the update run. Here's an example of input from the stages file (*example-stages.json*) that represents the strategy shown for creation via the Azure portal:

    ```json
    {
        "stages": [
            {
                "name": "stage-1",
                "groups": [
                    {
                        "name": "group-1"
                    },
                    {
                        "name": "group-2"
                    }
                ],
                "afterStageWaitInSeconds": 300
            },
            {
                "name": "stage-2",
                "groups": [
                    {
                        "name": "group-3"
                    }
                ]
            }
        ]
    }
    ```

1. Create a new update strategy using the [`az fleet updatestrategy create`][az-fleet-updatestrategy-create] command with the `--stages` flag set to the name of your JSON file.

    ```azurecli-interactive
    az fleet updatestrategy create \
     --resource-group $GROUP \
     --fleet-name $FLEET \
     --name $STRATEGY \
     --stages example-stages.json
    ```

---

## Next steps

You can use an update strategy as part of a manual update run or an auto-upgrade profile. See:

* [How-to: Upgrade multiple clusters using Azure Kubernetes Fleet Manager update runs](./update-orchestration.md).
* [How-to: Automatically upgrade multiple clusters using Azure Kubernetes Fleet Manager](./update-automation.md).

<!-- LINKS -->
[fleet-quickstart]: quickstart-create-fleet-and-members.md
[azure-cli-install]: /cli/azure/install-azure-cli
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-fleet-member-create]: /cli/azure/fleet/member#az-fleet-member-create
[az-fleet-member-update]: /cli/azure/fleet/member#az-fleet-member-update
[az-fleet-updatestrategy-create]: /cli/azure/fleet/updatestrategy#az-fleet-updatestrategy-create