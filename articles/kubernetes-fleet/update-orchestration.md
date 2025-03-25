---
title: "Update Kubernetes and node images across multiple clusters using Azure Kubernetes Fleet Manager"
description: Learn how to orchestrate updates across multiple clusters using Azure Kubernetes Fleet Manager.
ms.topic: how-to
ms.date: 11/06/2023
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.custom:
  - devx-track-azurecli
  - ignite-2023
  - build-2024
---

# Update Kubernetes and node images across multiple clusters using Azure Kubernetes Fleet Manager

Platform admins managing large number of clusters often have problems with staging the updates of multiple clusters (for example, upgrading node OS image or Kubernetes versions) in a safe and predictable way. To address this challenge, Azure Kubernetes Fleet Manager (Fleet) allows you to orchestrate updates across multiple clusters using update runs.

Update runs consist of stages, groups, and strategies and can be applied manually for one-time updates, or automatically, for ongoing regular updates using auto-upgrade profiles. All update runs (manual or automated) honor member cluster maintenance windows.

This guide covers how to configure and manually execute update runs. 

## Prerequisites

* Read the [conceptual overview of this feature](./concepts-update-orchestration.md), which provides an explanation of update strategies, runs, stages, and groups referenced in this guide.

* You must have a Fleet resource with one or more member clusters. If not, follow the [quickstart][fleet-quickstart] to create a Fleet resource and join Azure Kubernetes Service (AKS) clusters as members.

* Set the following environment variables:

    ```bash
    export GROUP=<resource-group>
    export FLEET=<fleet-name>
    export AKS_CLUSTER_ID=<aks-cluster-resource-id>
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

## Creating update runs

Update run supports two options for the cluster upgrade sequence:

* **One by one**: If you don't care about controlling the cluster upgrade sequence, `one-by-one` provides a simple approach to upgrade all member clusters of the fleet in sequence one at a time.
* **Control sequence of clusters using update groups and stages**: If you want to control the cluster upgrade sequence, you can structure member clusters in update groups and update stages. You can store this sequence as a template in the form of an [update strategy](./update-create-update-strategy.md). You can create update runs later using the update strategies instead of defining the sequence every time you need to create an update run.

> [!NOTE]
> Update runs honor the [planned maintenance windows](/azure/aks/planned-maintenance) that you set at the AKS cluster level. For more information, see [planned maintenance across multiple member clusters](./concepts-update-orchestration.md#planned-maintenance), which explains how update runs handle member clusters configured with planned maintenance windows.

## Update all clusters one by one

### [Azure portal](#tab/azure-portal)

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, under **Settings**, select **Multi-cluster update** > **Create a run**.
1. Enter a name for the update run, and then select **One by one** for the upgrade type.

    :::image type="content" source="./media/update-orchestration/update-run-one-by-one.png" alt-text="Screenshot of the Azure portal pane for creating update runs that update clusters one by one in Azure Kubernetes Fleet Manager." lightbox="./media/update-orchestration/update-run-one-by-one.png":::

1. Select one of the following options for the **Upgrade scope**:

    * Kubernetes version for both control plane and node pools
    * Kubernetes version for only control plane of the cluster
    * Node image version only

1. Select one of the following options for the **Node image**:

    * **Latest image**: Updates every AKS cluster in the update run to the latest image available for that cluster in its region.
    * **Consistent image**: As it's possible for an update run to have AKS clusters across multiple regions where the latest available node images can be different (check [release tracker](/azure/aks/release-tracker) for more information). The update run picks the **latest common** image across all these regions to achieve consistency.

    :::image type="content" source="./media/update-orchestration/upgrade-scope.png" alt-text="Screenshot of the Azure portal pane for creating update runs. The upgrade scope section is shown." lightbox="./media/update-orchestration/upgrade-scope.png":::

1. Select **Create** to create the update run.

### [Azure CLI](#tab/cli)

1. Create an update run using the [`az fleet updaterun create`][az-fleet-updaterun-create] command with your chosen values for the `--upgrade-type` and `--node-image-selection` flags. The following command creates an update run that upgrades the Kubernetes version for both control plane and node pools and uses the latest node image available for each cluster in its region.

    The `--upgrade-type` flag supports the following values:

    * `Full` upgrades Kubernetes version for control plane and node pools along with the node images.
    * `ControlPlaneOnly` only upgrades the Kubernetes version for the control plane of the cluster.
    * `NodeImageOnly` only upgrades the node images.

    The `--node-image-selection` flag supports the following values:

    * `Latest`: Updates every AKS cluster in the update run to the latest image available for that cluster in its region.
    * `Consistent`: As it's possible for an update run to have AKS clusters across multiple regions where the latest available node images can be different (check [release tracker](/azure/aks/release-tracker) for more information). The update run picks the **latest common** image across all these regions to achieve consistency.

    ```azurecli-interactive
    az fleet updaterun create \
     --resource-group $GROUP \
     --fleet-name $FLEET \
     --name run-1 \
     --upgrade-type Full \
     --kubernetes-version 1.26.0 \
     --node-image-selection Latest
    ```

1. Start the update run using the [`az fleet updaterun start`][az-fleet-updaterun-start] command.

    ```azurecli-interactive
    az fleet updaterun start \
     --resource-group $GROUP \
     --fleet-name $FLEET \
     --name run-1
    ```

When creating an update run, you have the ability to control the scope of the update run. The `--upgrade-type` flag supports the following values: 
- `ControlPlaneOnly` only upgrades the Kubernetes version for the control plane of the cluster. 
- `Full` upgrades Kubernetes version for control plane and node pools along with the node images.
- `NodeImageOnly` only upgrades the node images.

Also, `--node-image-selection` flag supports the following values:
- **Latest**: Updates every AKS cluster in the update run to the latest image available for that cluster in its region.
- **Consistent**: As it's possible for an update run to have AKS clusters across multiple regions where the latest available node images can be different (check [release tracker](/azure/aks/release-tracker) for more information). The update run picks the **latest common** image across all these regions to achieve consistency.

**Starting an update run**:

To start update runs, run the following command:

```azurecli-interactive
az fleet updaterun start \
 --resource-group $GROUP \
 --fleet-name $FLEET \
 --name <run-name>
```
---

## Update clusters using groups and stages

You can define an update run using update stages to sequentially order the application of updates to different update groups. For example, a first update stage might update test environment member clusters, and a second update stage would then update production environment member clusters. You can also specify a wait time between the update stages. You can store this sequence as a template in the form of an [update strategy](./update-create-update-strategy.md).

#### [Azure portal](#tab/azure-portal)

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, under **Settings**, select **Multi-cluster update** > **Create a run**.
1. Enter a name for the update run, and then select **Stages** for the update sequence type.

    :::image type="content" source="./media/update-orchestration/update-run-stages-inline.png" alt-text="Screenshot of the Azure portal page for choosing stages mode within update run." lightbox="./media/update-orchestration/update-run-stages-lightbox.png":::

1. Select **Create stage**, and then enter a name for the stage and the wait time between stages.

    :::image type="content" source="./media/update-orchestration/create-stage-basics-inline.png" alt-text="Screenshot of the Azure portal page for creating a stage and defining wait time." lightbox="./media/update-orchestration/create-stage-basics.png":::

1. Select the update groups that you want to include in this stage. You can also specify the order of the update groups if you want to update them in a specific sequence. When you're done, select **Create**.

    :::image type="content" source="./media/update-orchestration/create-stage-choose-groups-inline.png" alt-text="Screenshot of the Azure portal page for stage creation that shows the selection of upgrade groups." lightbox="./media/update-orchestration/create-stage-choose-groups.png":::

1. Select one of the following options for the **Upgrade scope**:

    * Kubernetes version for both control plane and node pools
    * Kubernetes version for only control plane of the cluster
    * Node image version only

1. Select one of the following options for the **Node image**:

    * **Latest image**: Updates every AKS cluster in the update run to the latest image available for that cluster in its region.
    * **Consistent image**: As it's possible for an update run to have AKS clusters across multiple regions where the latest available node images can be different (check [release tracker](/azure/aks/release-tracker) for more information). The update run picks the **latest common** image across all these regions to achieve consistency.

    :::image type="content" source="./media/update-orchestration/upgrade-scope.png" alt-text="Screenshot of the Azure portal pane for creating update runs. The upgrade scope section is shown." lightbox="./media/update-orchestration/upgrade-scope.png":::

1. Select **Create** to create the update run.

    Specifying stages and their order every time when creating an update run can get repetitive and cumbersome. Update strategies simplify this process by allowing you to store templates for update runs. For more information, see [update strategy creation and usage](#create-an-update-run-using-update-strategies).

1. In the **Multi-cluster update** menu, select the update run, and then select **Start**.

#### [Azure CLI](#tab/cli)

1. Create a JSON file to define the stages and groups for the update run. Here's an example of input from the stages file (*example-stages.json*):

    ```json
    {
        "stages": [
            {
                "name": "stage1",
                "groups": [
                    {
                        "name": "group-1a"
                    },
                    {
                        "name": "group-1b"
                    },
                    {
                        "name": "group-1c"
                    }
                ],
                "afterStageWaitInSeconds": 3600
            },
            {
                "name": "stage2",
                "groups": [
                    {
                        "name": "group-2a"
                    },
                    {
                        "name": "group-2b"
                    },
                    {
                        "name": "group-2c"
                    }
                ]
            }
        ]
    }
    ```

1. Create an update run using the [`az fleet updaterun create`][az-fleet-updaterun-create] command with the `--stages` flag set to the name of your JSON file and your chosen values for the `--upgrade-type` and `--node-image-selection` flags. The following command creates an update run that upgrades the Kubernetes version for both control plane and node pools and uses the latest node image available for each cluster in its region.

    The `--upgrade-type` flag supports the following values:

    * `Full` upgrades Kubernetes version for control plane and node pools along with the node images.
    * `ControlPlaneOnly` only upgrades the Kubernetes version for the control plane of the cluster.
    * `NodeImageOnly` only upgrades the node images.

    The `--node-image-selection` flag supports the following values:

    * `Latest`: Updates every AKS cluster in the update run to the latest image available for that cluster in its region.
    * `Consistent`: As it's possible for an update run to have AKS clusters across multiple regions where the latest available node images can be different (check [release tracker](/azure/aks/release-tracker) for more information). The update run picks the **latest common** image across all these regions to achieve consistency.

    ```azurecli-interactive
    az fleet updaterun create \
     --resource-group $GROUP \
     --fleet-name $FLEET \
     --name run-1 \
     --upgrade-type Full \
     --kubernetes-version 1.26.0 \
     --node-image-selection Latest \
     --stages example-stages.json
    ```

1. Start the update run using the [`az fleet updaterun start`][az-fleet-updaterun-start] command.

    ```azurecli-interactive
    az fleet updaterun start \
     --resource-group $GROUP \
     --fleet-name $FLEET \
     --name run-1
    ```

---

## Create an update run using update strategies

Creating an update run requires you to specify the stages, groups, order each time. Update strategies simplify this process by allowing you to store templates for update runs.

> [!NOTE]
> It's possible to create multiple update runs with unique names from the same update strategy.

You can create an update strategy using one of the following methods:

* [Create a new update strategy and then reference it when creating an update run](./update-create-update-strategy.md).
* [Save an update strategy while creating an update run using the Azure portal](#save-an-update-strategy-while-creating-an-update-run).

### Save an update strategy while creating an update run

* Save an update strategy while creating an update run in the Azure portal:

    :::image type="content" source="./media/update-orchestration/update-strategy-creation-from-run-inline.png" alt-text="A screenshot of the Azure portal showing update run stages being saved as an update strategy." lightbox="./media/update-orchestration/update-strategy-creation-from-run-lightbox.png":::

### Manage an update run 

The following sections explain how to manage an update run using the Azure portal and Azure CLI.

### [Azure portal](#tab/azure-portal)

* On the **Multi-cluster update** page of the fleet resource, you can **Start** an update run that's either in **Not started** or **Failed** state:

     :::image type="content" source="./media/update-orchestration/run-start.png" alt-text="A screenshot of the Azure portal showing how to start an update run in the 'Not started' state." lightbox="./media/update-orchestration/run-start.png":::

* On the **Multi-cluster update** page of the fleet resource, you can **Stop** a currently **Running** update run:

    :::image type="content" source="./media/update-orchestration/run-stop.png" alt-text="A screenshot of the Azure portal showing how to stop an update run in the 'Running' state." lightbox="./media/update-orchestration/run-stop.png":::

* Within any update run in the **Not Started**, **Failed**, or **Running** state, you can select any **Stage** and **Skip** the upgrade:

    :::image type="content" source="./media/update-orchestration/skip-stage.png" alt-text="A screenshot of the Azure portal showing how to skip upgrade for a specific stage in an update run." lightbox="./media/update-orchestration/skip-stage.png":::

    You can similarly skip the upgrade at the update group or member cluster level too.

### [Azure CLI](#tab/cli)

* You can **Start** an update run that's either in **Not started** or **Failed** state using the [`az fleet updaterun start`][az-fleet-updaterun-start] command:

    ```azurecli-interactive
    az fleet updaterun start \
     --resource-group $GROUP \
     --fleet-name $FLEET \
     --name <run-name>
    ```

* You can **Stop** a currently **Running** update run using the [`az fleet updaterun stop`][az-fleet-updaterun-stop] command:

    ```azurecli-interactive
    az fleet updaterun stop \
     --resource-group $GROUP \
     --fleet-name $FLEET \
     --name <run-name>
    ```

* You can skip update stages or groups by specifying them in the `--targets` flag using the [`az fleet updaterun skip`][az-fleet-updaterun-skip] command:

    ```azurecli-interactive
    az fleet updaterun skip \
     --resource-group $GROUP \
     --fleet-name $FLEET \
     --name <run-name> \
     --targets Group:my-group-name Stage:my-stage-name
    ```

    For more information, see [conceptual overview on the update run states and skip behavior](concepts-update-orchestration.md#update-run-states) on runs/stages/groups.

## Automate update runs using auto-upgrade profiles

Auto-upgrade profiles are used to automatically execute update runs across member clusters when new Kubernetes or node image versions are made available. 

For more information on configuring auto-upgrade profiles, see [automate upgrades of Kubernetes and node images using Azure Kubernetes Fleet Manager](./update-automation.md).

---

For more information, see the [conceptual overview on the update run states and skip behavior](concepts-update-orchestration.md#update-run-states) on runs/stages/groups.

## Next steps

* [How-to: Automatically upgrade multiple clusters using Azure Kubernetes Fleet Manager](./update-automation.md).
* [How-to: Monitor update runs for Azure Kubernetes Fleet Manager](./howto-monitor-update-runs.md).

<!-- LINKS -->
[fleet-quickstart]: quickstart-create-fleet-and-members.md
[azure-cli-install]: /cli/azure/install-azure-cli
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-fleet-updaterun-create]: /cli/azure/fleet/updaterun#az-fleet-updaterun-create
[az-fleet-updaterun-start]: /cli/azure/fleet/updaterun#az-fleet-updaterun-start
[az-fleet-updaterun-stop]: /cli/azure/fleet/updaterun#az-fleet-updaterun-stop
[az-fleet-updaterun-skip]: /cli/azure/fleet/updaterun#az-fleet-updaterun-skip
