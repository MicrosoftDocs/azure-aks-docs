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

Administrators can control the sequence of updates to Fleet-managed clusters by defining stages, groups and optional inter-stage pauses. These sequences can be saved as update strategies which can be managed indepdendently of update runs or auto-upgrades, allowing them to be reused as required.

:::image type="content" source="./media/conceptual-update-orchestration-inline.png" alt-text="An example updated strategy containing two update stages, each containing two update groups with two member clusters." lightbox="./media/conceptual-update-orchestration-inline.png":::

This article covers how to define update strategies using groups and stages. 

## Prerequisites

* Read the [conceptual overview of Fleet updates](./concepts-update-orchestration.md), which provides an explanation of update runs, stages, groups, and strategies referenced in this guide.

* You must have a Fleet resource with one or more member cluster. If not, follow the [quickstart][fleet-quickstart] to create a Fleet resource and join Azure Kubernetes Service (AKS) clusters as members.

* Set the following environment variables:

    ```bash
    export GROUP=<resource-group>
    export FLEET=<fleet-name>
    export CLUSTERID=<aks-cluster-resource-id>
    export STRATEGY=<strategy-name>
    ```

* If you're following the Azure CLI instructions in this article, you need Azure CLI version 2.58.0 or later installed. To install or upgrade, see [Install the Azure CLI][azure-cli-install].

* You also need the `fleet` Azure CLI extension, which you can install by running the following command:

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

### Assign to group when adding member cluster to the fleet

#### [Azure portal](#tab/azure-portal)

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, under **Settings**, select **Member clusters** > **Add**.

    :::image type="content" source="./media/update-orchestration/add-members-inline.png" alt-text="Screenshot of the Azure portal page for Azure Kubernetes Fleet Manager member clusters." lightbox="./media/update-orchestration/add-members.png":::

1. Select the cluster that you want to add, and then select **Next: Review + add**.

1. Enter the name of the update group that you want to assign the cluster to, and then select **Add**.

    :::image type="content" source="./media/update-orchestration/add-members-assign-group-inline.png" alt-text="Screenshot of the Azure portal page for Azure Kubernetes Fleet Manager member clusters." lightbox="./media/update-orchestration/add-members-assign-group.png":::

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

    :::image type="content" source="./media/update-orchestration/existing-members-assign-group-inline.png" alt-text="Screenshot of the Azure portal page for assigning existing member clusters to a group." lightbox="./media/update-orchestration/existing-members-assign-group.png":::

1. Enter the name of the update group that you want to assign the cluster to, and then select **Assign**.

    :::image type="content" source="./media/update-orchestration/group-name-inline.png" alt-text="Screenshot of the Azure portal page for member clusters that shows the form for updating a member cluster's group." lightbox="./media/update-orchestration/group-name.png":::

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

> [!NOTE]
> A fleet member can only be a part of one update group, but an update group can have multiple fleet members assigned to it.
> An update group itself is not a separate resource type. Update groups are only strings representing references from the fleet members. So, if all fleet members with references to a common update group are deleted, that specific update group will cease to exist as well.

## Create an update strategy

An update strategy consists of one or more stage, where a stage can contain one or more update group.

### [Azure portal](#tab/azure-portal)

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, under **Settings**, select **Multi-cluster update** > **Strategies**, then **Create**.
1. Enter a name for the strategy.
1. The first time you view the page, an update strategy explanation diagram is displayed which can help visualize how strategies function.

    :::image type="content" source="./media/update-orchestration/create-strategy-inline.png" alt-text="A screenshot of the Azure portal showing creation of update strategy." lightbox="./media/update-orchestration/create-strategy-lightbox.png":::

1. Select **Create Stage** and enter:
    * **Stage name** - name the stage - it must be unique across all stage names in the fleet.
    * **(Optional) Pause after stage** - select this option if you would like to define a pause before moving to the next stage.
    * **(Optional) Pause duration** - select a pre-defined duration, or enter a custom value in seconds.

    :::image type="content" source="./media/update-orchestration/create-strategy-stage-detail.png" alt-text="A screenshot of the Azure portal showing creation of Azure Kubernetes Fleet Manager update strategy stage." lightbox="./media/update-orchestration/create-strategy-stage-detail.png":::

1. Assign one or more **Update Group** to the stage, and then select **Create**.

    :::image type="content" source="./media/update-orchestration/create-strategy-select-groups.png" alt-text="A screenshot of the Azure portal showing creation of Azure Kubernetes Fleet Manager update strategy stage, selecting update groups to include." lightbox="./media/update-orchestration/create-strategy-select-groups.png":::

### [Azure CLI](#tab/cli)

For this scenario we will create stage and group detail that matches those used for the Azure portal process.  

1. Create a JSON file to define the stages and groups for the update run. Here's an example of input from the stages file (*example-stages.json*) that represents the strategy shown for creation via the Azure portal:

    ```json
    {
        "stages": [
            {
                "name": "ring0",
                "groups": [
                    {
                        "name": "canary"
                    },
                    {
                        "name": "europe"
                    }
                ],
                "afterStageWaitInSeconds": 600
            },
            {
                "name": "ring1",
                "groups": [
                    {
                        "name": "apac"
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

#### Use strategy with an update run

Create an update run using the [`az fleet updaterun create`][az-fleet-updaterun-create] command with the `--update-strategy-name` flag set to the name of the update strategy.

    ```azurecli-interactive
    az fleet updaterun create \
     --resource-group $GROUP \
     --fleet-name $FLEET \
     --name run-5 \
     --update-strategy-name $STRATEGY \
     --upgrade-type NodeImageOnly \
     --node-image-selection Consistent
    ```

#### Use strategy with an auto-upgrade profile

Create an auto-upgrade profile using the [`az fleet autoupgradeprofile create`][az-fleet-autoupgradeprofile-create] command with the `--update-strategy-id` set to the resource identifier of the update strategy.

    ```azurecli-interactive
    az fleet autoupgradeprofile create \
      --resource-group $GROUP \
      --fleet-name $FLEET \
      --name $AUTOUPGRADEPROFILE \
      --update-strategy-id $STRATEGY_ID \
      --channel NodeImage 
    ```

---

## Next steps

* [How-to: Upgrade multiple clusters using Azure Kubernetes Fleet Manager update runs](./update-orchestration.md).
* [How-to: Automatically upgrade multiple clusters using Azure Kubernetes Fleet Manager](./update-automation.md).

<!-- LINKS -->
[fleet-quickstart]: quickstart-create-fleet-and-members.md
[azure-cli-install]: /cli/azure/install-azure-cli
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-fleet-updaterun-create]: /cli/azure/fleet/updaterun#az-fleet-updaterun-create
[az-fleet-member-create]: /cli/azure/fleet/member#az-fleet-member-create
[az-fleet-member-update]: /cli/azure/fleet/member#az-fleet-member-update
[az-fleet-updatestrategy-create]: /cli/azure/fleet/updatestrategy#az-fleet-updatestrategy-create
[az-fleet-autoupgradeprofile-create]: /cli/azure/fleet/autoupgradeprofile#az-fleet-autoupgradeprofile-create