---
title: "Automate Upgrades of Kubernetes and Node Images Across Multiple Clusters using Azure Kubernetes Fleet Manager"
description: Learn how to configure automated upgrades of Kubernetes and node images across multiple clusters by using Azure Kubernetes Fleet Manager.
ms.topic: how-to
ms.date: 08/25/2026
author: sjwaight
ms.author: simonwaight
ms.reviewer: schaffererin
ms.service: azure-kubernetes-fleet-manager
zone_pivot_groups: azure-portal-azure-cli
# Customer intent: "As a platform admin managing multiple Kubernetes clusters, I want to automate upgrades of Kubernetes and node images using auto-upgrade profiles, so that I can ensure safe and consistent updates without manual intervention."
---

# Automate upgrades of Kubernetes and node images across multiple clusters using Azure Kubernetes Fleet Manager

**Applies to**: :heavy_check_mark: Fleet Manager :heavy_check_mark: Fleet Manager with hub cluster

Keeping clusters updated in a timely and safe fashion is a key concern of platform administrators. When you adopt Azure Kubernetes Fleet Manager [Update Runs](./update-orchestration.md) and [Strategies](./update-create-update-strategy.md), you can use auto-upgrade profiles to automate the execution of update runs when new Kubernetes or node image versions are released.

This article explains how to use auto-upgrade profiles to automatically create and execute update runs when Azure Kubernetes Service (AKS) releases new Kubernetes or node image versions.

> [!NOTE]
> Auto-upgrade triggered update runs honor [planned maintenance windows](/azure/aks/planned-maintenance) that you set at the AKS cluster level. For more information, see [planned maintenance across multiple member clusters](./concepts-update-orchestration.md#planned-maintenance-windows) that learn how update runs handle member clusters with configured planned maintenance windows.

## Before you begin

- Read the [conceptual overview of auto-upgrade profiles](./concepts-update-orchestration.md#auto-upgrade-profiles-overview), which explains the configurations referenced in this guide.
- Set up a Fleet Manager with one or more member clusters. If you don't have one, follow the [quickstart][fleet-quickstart] to create a Fleet Manager and join AKS clusters as members.
- Configure an update strategy. Use the instructions in the [update run how-to article](./update-orchestration.md#create-an-update-run-using-update-strategies). You need the update strategy resource identifier to use with an auto-upgrade profile when using the Azure CLI.

:::zone target="docs" pivot="azure-cli"

- Set the following environment variables to use in the Azure CLI commands:

    ```bash
    export GROUP=<resource-group>
    export FLEET=<fleet-name>
    export AUTOUPGRADEPROFILE=<upgrade-profile-name>
    # Optional
    export STRATEGYID=<strategy-id>
    export CLUSTER=<aks-cluster-name>
    ```

- Install latest Azure CLI version. To install or upgrade, see [Install the Azure CLI][azure-cli-install].
- Install the latest `fleet` Azure CLI extension. Use the [`az extension add`](/cli/azure/extension#az-extension-add) command to install the extension.

  ```azurecli-interactive
  az extension add --name fleet
  ```

  Use the [`az extension update`](/cli/azure/extension#az-extension-update) command to update to the latest version of the extension.

  ```azurecli-interactive
  az extension update --name fleet
  ```

:::zone-end

> [!NOTE]
> Clusters with agent pools created from [node pool snapshots](/azure/aks/node-pool-snapshot) are affected as follows based on the selected auto-upgrade channel and node image option:
>
> - **Node image channel**: The node image upgrades to the version determined by Fleet Manager. The reference to the snapshot (`creationData`) is removed from the agent pool.
> - **Stable**, **Rapid**, or **Target Kubernetes minor version** channels with node image set to:
>   - **Consistent image**: The node image upgrades to the version determined by Fleet Manager. The reference to the snapshot (`creationData`) is removed from the agent pool.
>   - **Latest image**: The agent pool keeps its reference to the snapshot (`creationData`), and the node image isn't modified.
>
> For more information, see [understanding node image upgrades and snapshots](./concepts-update-orchestration.md#understanding-node-image-upgrades-and-snapshots).

:::zone target="docs" pivot="azure-cli"

## Create auto-upgrade profiles

Create auto-upgrade profiles by using the [`az fleet autoupgradeprofile create`][az-fleet-autoupgradeprofile-create] command.

You can disable an auto-upgrade profile by including the `--disabled` flag with the [`az fleet autoupgradeprofile create`][az-fleet-autoupgradeprofile-create] command. To reenable a disabled auto-upgrade profile, rerun the [`az fleet autoupgradeprofile create`][az-fleet-autoupgradeprofile-create] command without the `--disabled` flag.

> [!NOTE]
> Disabling an auto-upgrade profile doesn't affect any in-progress update runs. However, the process stops generating new update runs until you reenable the profile.

### Stable channel Kubernetes updates

Update to the latest supported Kubernetes patch release on minor version _N-1_, where _N_ is the latest supported minor version.

#### Update member clusters one by one

Update member clusters sequentially by using the [`az fleet autoupgradeprofile create`][az-fleet-autoupgradeprofile-create] command.

```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --channel Stable
```

#### Update member clusters by using an existing update strategy

Update member clusters by using an existing update strategy. Use the [`az fleet autoupgradeprofile create`][az-fleet-autoupgradeprofile-create] command with the `--update-strategy-id` parameter set to the ID of the existing update strategy.

```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --update-strategy-id $STRATEGYID \
  --channel Stable
```

#### Update member clusters by using an existing update strategy with consistent node image

Update member clusters by using an existing update strategy, and ensure the same node image version is used in every Azure region. Use the [`az fleet autoupgradeprofile create`][az-fleet-autoupgradeprofile-create] command with the `--node-image-selection` parameter set to `Consistent`. All member clusters run the same node image version.

```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --update-strategy-id $STRATEGYID \
  --channel Stable \
  --node-image-selection Consistent
```

#### Update member clusters by using an existing update strategy with latest node image

Update member clusters by using an existing update strategy, and ensure the latest available node image version is used for each Azure region. Use the [`az fleet autoupgradeprofile create`][az-fleet-autoupgradeprofile-create] command with the `--node-image-selection` parameter set to `Latest`. Member clusters can run multiple node image versions.

```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --update-strategy-id $STRATEGYID \
  --channel Stable \
  --node-image-selection Latest
```

### Node image channel updates

Update nodes with a newly patched machine image that includes security fixes and bug fixes.

#### Update node images one by one

Update node images for member clusters sequentially by using the [`az fleet autoupgradeprofile create`][az-fleet-autoupgradeprofile-create] command.

```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --channel NodeImage
```

#### Update node images by using an existing update strategy

Update node images for member clusters by using an existing update strategy. Use the [`az fleet autoupgradeprofile create`][az-fleet-autoupgradeprofile-create] command and set the `--update-strategy-id` parameter to the ID of the existing update strategy.

```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --update-strategy-id $STRATEGYID \
  --channel NodeImage 
```

### Target Kubernetes minor version updates

Update to a defined target Kubernetes minor version by using the `--target-kubernetes-version` parameter. Supply the version in the _{major version}.{minor version}_ format (for example, 1.33). Fleet Manager Auto-upgrade automatically upgrades member clusters to the latest patch release of the specified target version when the patch is available.

> [!IMPORTANT]
> Keep the following information in mind when using the _Target Kubernetes minor version_ channel:
>
> - You must specify the `--target-kubernetes-version` parameter. This parameter isn't supported for other auto-upgrade channels (Rapid, Stable, Node image, and Security patch).
> - The long-term support (LTS) flag, `--long-term-support`, is only available when using the _Target Kubernetes minor version_ channel. For other channels, set this flag to `False`.
> - You can only select LTS Kubernetes versions (_N-2_) for an auto-upgrade profile with the `--long-term-support` flag. For Fleet auto-upgrade to keep working in this scenario, ensure that the clusters in the generated update run are all enabled with LTS. Non-LTS clusters cause the update run to fail when the first non-LTS cluster is encountered.
> - You can't set the target Kubernetes version to a future Kubernetes version that AKS hasn't released.

#### Update member clusters to a specific Kubernetes minor version

Update member clusters to a specific Kubernetes minor version by using the [`az fleet autoupgradeprofile create`][az-fleet-autoupgradeprofile-create] command with the `--target-kubernetes-version` parameter set to the desired version. The following example updates member clusters to Kubernetes version 1.33.

```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --channel TargetKubernetesVersion \
  --target-kubernetes-version "1.33"
```

#### Update member clusters with LTS enabled to a specific Kubernetes minor version

Update member clusters with LTS enabled to a specific Kubernetes minor version by using the [`az fleet autoupgradeprofile create`][az-fleet-autoupgradeprofile-create] command with the `--target-kubernetes-version` parameter set to the desired version and the `--long-term-support` flag enabled. The following example updates member clusters to Kubernetes version 1.29 with LTS enabled.

```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --channel TargetKubernetesVersion \
  --target-kubernetes-version "1.29" \
  --long-term-support
```

### Security patch channel updates

Update Linux nodes with security fixes. Apply updates by using live patching when possible. Otherwise, deploy a newly patched machine image that contains security fixes.

#### Update nodes with security patches one by one

Update node images for member clusters sequentially by using the [`az fleet autoupgradeprofile create`][az-fleet-autoupgradeprofile-create] command.

```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --channel SecurityPatch
```

#### Update nodes with security patches by using an existing update strategy

Update node images for member clusters by using an existing update strategy. Use the [`az fleet autoupgradeprofile create`][az-fleet-autoupgradeprofile-create] command and set the `--update-strategy-id` parameter to the ID of the existing update strategy.

```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --update-strategy-id $STRATEGYID \
  --channel SecurityPatch 
```

## View auto-upgrade profiles

Auto-upgrade profiles are Fleet-level resources. They aren't attached directly to individual AKS clusters. To determine which profiles can update your AKS clusters, first list the Fleet members and confirm that the clusters are members of the Fleet.

```azurecli-interactive
az fleet member list \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --query "[].{memberName:name,clusterResourceId:clusterResourceId}" \
  --output table
```

List all auto-upgrade profiles for the Fleet using the [`az fleet autoupgradeprofile list`][az-fleet-autoupgradeprofile-list] command.

```azurecli-interactive
az fleet autoupgradeprofile list \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --output table
```

Show a specific auto-upgrade profile for the Fleet using the [`az fleet autoupgradeprofile show`][az-fleet-autoupgradeprofile-show] command. Review the channel, status, and `updateStrategyId` in the output.

```azurecli-interactive
az fleet autoupgradeprofile show \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE
```

If `updateStrategyId` is empty, the profile uses the **One by one** update sequence and includes the Fleet's member clusters sequentially. If `updateStrategyId` contains a resource ID, show the referenced strategy to review the stages, groups, or member selectors that determine which Fleet members the generated update runs include.

```azurecli-interactive
PROFILE_STRATEGY_ID=$(az fleet autoupgradeprofile show \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --query updateStrategyId \
  --output tsv)

if [[ -n "$PROFILE_STRATEGY_ID" ]]; then
  az fleet updatestrategy show \
    --resource-group $GROUP \
    --fleet-name $FLEET \
    --name "${PROFILE_STRATEGY_ID##*/}"
fi
```

## Delete an auto-upgrade profile

Use the [`az fleet autoupgradeprofile delete`][az-fleet-autoupgradeprofile-delete] command to delete an existing auto-upgrade profile. After running this command, you're prompted to confirm deletion. To bypass the confirmation and immediately delete the profile, include `--yes` in the command.

```azurecli-interactive
az fleet autoupgradeprofile delete \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE
```

> [!NOTE]
> Deleting an auto-upgrade profile doesn't affect any in-progress update runs.

:::zone-end

:::zone target="docs" pivot="azure-portal"

## Create auto-upgrade profiles

### [Stable channel](#tab/stable)

Update to the latest supported Kubernetes patch release on minor version _N-1_, where _N_ is the latest supported minor version.

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, under **Settings**, select **Multicluster update** > **Auto-upgrade profiles** > **+ Create**.
1. On **Create an auto-upgrade profile**, configure the following options:

    - Under **Auto-upgrade details**:
      - **Auto-upgrade profile name**: Enter a name for the auto-upgrade profile.
      - **Status**: Select **Enabled** or **Disabled**. Disabled auto-upgrade profiles don't trigger when new versions are released.
      - **Update sequence**: Select **Stages** or **One by one**.
    - Under **Auto-upgrade triggers**:
      - **Channel**: Select **Stable**.
      - **Node image**: Select **Latest image** or **Consistent image**.
    - Under **Strategy details**:
      - If you selected an **Update sequence** using **Stages**, select an existing strategy or create a new one.
1. Select **Create** to create the auto-upgrade profile.

    :::image type="content" source="./media/auto-upgrade/create-auto-upgrade-profile-stable.png" alt-text="Screenshot of the Azure Kubernetes Fleet Manager Azure portal pane for creating auto-upgrade profile using the Stable channel." lightbox="./media/auto-upgrade/create-auto-upgrade-profile-stable.png":::

### [Rapid channel](#tab/rapid)

Update to the latest supported Kubernetes patch release on the latest (_N_) minor version.

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, under **Settings**, select **Multicluster update** > **Auto-upgrade profiles** > **+ Create**.
1. On **Create an auto-upgrade profile**, configure the following options:

    - Under **Auto-upgrade details**:
      - **Auto-upgrade profile name**: Enter a name for the auto-upgrade profile.
      - **Status**: Select **Enabled** or **Disabled**. Disabled auto-upgrade profiles don't trigger when new versions are released.
      - **Update sequence**: Select **Stages** or **One by one**.
    - Under **Auto-upgrade triggers**:
      - **Channel**: Select **Rapid**.
      - **Node image**: Select **Latest image** or **Consistent image**.
    - Under **Strategy details**:
      - If you selected an **Update sequence** using **Stages**, select an existing strategy or create a new one.
1. Select **Create** to create the auto-upgrade profile.

    :::image type="content" source="./media/auto-upgrade/create-auto-upgrade-profile-rapid.png" alt-text="Screenshot of the Azure Kubernetes Fleet Manager Azure portal pane for creating auto-upgrade profile using the Rapid channel." lightbox="./media/auto-upgrade/create-auto-upgrade-profile-rapid.png":::

### [Node image channel](#tab/node-image)

Update nodes with a newly patched machine image that includes security fixes and bug fixes.

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, under **Settings**, select **Multicluster update** > **Auto-upgrade profiles** > **+ Create**.
1. On **Create an auto-upgrade profile**, configure the following options:

    - Under **Auto-upgrade details**:
      - **Auto-upgrade profile name**: Enter a name for the auto-upgrade profile.
      - **Status**: Select **Enabled** or **Disabled**. Disabled auto-upgrade profiles don't trigger when new versions are released.
      - **Update sequence**: Select **Stages** or **One by one**.
    - Under **Auto-upgrade triggers**:
      - **Channel**: Select **Node image**.

1. Select **Create** to create the auto-upgrade profile.

    :::image type="content" source="./media/auto-upgrade/create-auto-upgrade-profile-node-image.png" alt-text="Screenshot of the Azure Kubernetes Fleet Manager Azure portal pane for creating auto-upgrade profile using the Node image channel." lightbox="./media/auto-upgrade/create-auto-upgrade-profile-node-image.png":::

### [Target Kubernetes minor](#tab/target-kubernetes-minor-version)

Update to a defined target Kubernetes minor version. Fleet Manager Auto-upgrade automatically upgrades member clusters to the latest patch release of the specified target version when the patch is available. Clusters only upgrade patches in the selected minor. At end of a minor version's support, you must manually update to the next desired minor version.

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, under **Settings**, select **Multicluster update** > **Auto-upgrade profiles** > **+ Create**.
1. On **Create an auto-upgrade profile**, configure the following options:

    - Under **Auto-upgrade details**:
      - **Auto-upgrade profile name**: Enter a name for the auto-upgrade profile.
      - **Status**: Select **Enabled** or **Disabled**. Disabled auto-upgrade profiles don't trigger when new versions are released.
      - **Update sequence**: Select **Stages** or **One by one**.
    - Under **Auto-upgrade triggers**:
      - **Channel**: Select **Target Kubernetes minor version**.
      - **Allow LTS minor versions**: Select whether to allow Kubernetes minor versions available only for AKS long term support (LTS) clusters.
      - **Target Kubernetes minor version**: Select the Kubernetes minor version trigger. Clusters at a lower minor are updated to it first, then only patch updates are applied.
      - **Node image**: Select **Latest image** or **Consistent image**.
    - Under **Strategy details**:
      - If you selected an **Update sequence** using **Stages**, select an existing strategy or create a new one.
1. Select **Create** to create the auto-upgrade profile.

    :::image type="content" source="./media/auto-upgrade/create-auto-upgrade-profile-kubernetes-minor.png" alt-text="Screenshot of the Azure Kubernetes Fleet Manager Azure portal pane for creating auto-upgrade profile using the Target Kubernetes minor version channel." lightbox="./media/auto-upgrade/create-auto-upgrade-profile-kubernetes-minor.png":::

### [Security patch (preview)](#tab/node-security-patch)

Update Linux nodes with just security fixes, by using either live patching or a prepatched node image.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, under **Settings**, select **Multicluster update** > **Auto-upgrade profiles** > **+ Create**.
1. On **Create an auto-upgrade profile**, configure the following options:

    - Under **Auto-upgrade details**:
      - **Auto-upgrade profile name**: Enter a name for the auto-upgrade profile.
      - **Status**: Select **Enabled** or **Disabled**. Disabled auto-upgrade profiles don't trigger when new versions are released.
      - **Update sequence**: Select **Stages** or **One by one**.
    - Under **Auto-upgrade triggers**:
      - **Channel**: Select **Security patch (preview)**.

1. Select **Create** to create the auto-upgrade profile.

    :::image type="content" source="./media/auto-upgrade/create-auto-upgrade-profile-security-patch.png" alt-text="Screenshot of the Azure Kubernetes Fleet Manager Azure portal pane for creating auto-upgrade profile using the Node image channel." lightbox="./media/auto-upgrade/create-auto-upgrade-profile-security-patch.png":::

---

## View auto-upgrade profiles

Auto-upgrade profiles are Fleet-level resources. They aren't attached directly to individual AKS clusters. To determine which profiles can update your AKS clusters, confirm that the clusters are members of the Fleet, and then review the Fleet's profiles and their update sequences.

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, select **Fleet members**, and confirm that your AKS clusters appear in the member list.
1. Under **Settings**, select **Multicluster update** > **Auto-upgrade profiles**.
1. Select an auto-upgrade profile to view its channel, status, and update sequence.
1. If the update sequence is **One by one**, the profile includes the Fleet's member clusters sequentially. If the update sequence uses **Stages**, review the associated strategy's stages, groups, and member selectors to determine which Fleet members the generated update runs include.

## Delete an auto-upgrade profile

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, under **Settings**, select **Multicluster update** > **Auto-upgrade profiles**.
1. Select the profile you want to delete, and then select **Delete** > **Yes** to confirm.

> [!NOTE]
> Deleting an auto-upgrade profile doesn't affect any in-progress update runs.

:::zone-end

## Validate auto-upgrades

Auto-upgrades happen only when new Kubernetes or node images are available. When auto-upgrade is triggered, a linked update run is created, so you can use [manage update run](./update-orchestration.md#manage-an-update-run) to see the results of the auto-upgrade.

You can also check your existing versions as a baseline.

Get the current Kubernetes version for a member cluster by using the [`az aks show`](/cli/azure/aks#az-aks-show) command with the `--query` parameter to filter the output for the `currentKubernetesVersion` property.

```azurecli-interactive
az aks show \
  --resource-group $GROUP \
  --name $CLUSTER \
  --query currentKubernetesVersion
```

Get the current node image version for a member cluster by using the [`az aks show`](/cli/azure/aks#az-aks-show) command with the `--query` parameter to filter the output for the `nodeImageVersion` property.

```azurecli-interactive
az aks show \
  --resource-group $GROUP \
  --name $CLUSTER \
  --query "agentPoolProfiles[].{name:name,mode:mode, nodeImageVersion:nodeImageVersion, osSku:osSku, osType:osType}"
```

When update runs finish, you can rerun these commands and view the updated versions that are deployed.

## Generate an update run from an auto-upgrade profile

After you create an auto-upgrade profile, some time might pass before a new Kubernetes or node image version triggers auto-upgrade to create and execute an update run. Auto-upgrade allows you to generate a new update run at any time by using the [`az fleet autoupgradeprofile generate-update-run`][az-fleet-updaterun-generate] command. The resulting update run is based on the current AKS-published Kubernetes or node image version.

For more information about creating an on-demand update run from an auto-upgrade profile, see [Generate an update run from an auto-upgrade profile](./update-orchestration.md#generate-an-update-run-from-an-auto-upgrade-profile).

## Related content

- [Monitor update runs for Azure Kubernetes Fleet Manager](./howto-monitor-update-runs.md).
- [Multi-cluster updates FAQs](./faq.md#multi-cluster-updates---automated-or-manual-faqs).

<!-- INTERNAL LINKS -->
[az-fleet-autoupgradeprofile-create]: /cli/azure/fleet/autoupgradeprofile#az-fleet-autoupgradeprofile-create
[az-fleet-autoupgradeprofile-list]: /cli/azure/fleet/autoupgradeprofile#az-fleet-autoupgradeprofile-list
[az-fleet-autoupgradeprofile-show]: /cli/azure/fleet/autoupgradeprofile#az-fleet-autoupgradeprofile-show
[az-fleet-autoupgradeprofile-delete]: /cli/azure/fleet/autoupgradeprofile#az-fleet-autoupgradeprofile-delete
[azure-cli-install]: /cli/azure/install-azure-cli
[az-fleet-updaterun-generate]: /cli/azure/fleet/autoupgradeprofile#az-fleet-autoupgradeprofile-generate-update-run

<!-- LINKS -->
[fleet-quickstart]: quickstart-create-fleet-and-members.md
