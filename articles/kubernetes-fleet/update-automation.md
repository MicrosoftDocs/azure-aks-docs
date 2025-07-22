---
title: "Automate upgrades of Kubernetes and node images across multiple clusters using Azure Kubernetes Fleet Manager"
description: Learn how to configure automated upgrades of Kubernetes and node images across multiple clusters by using Azure Kubernetes Fleet Manager.
ms.topic: how-to
ms.date: 06/16/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
# Customer intent: "As a platform admin managing multiple Kubernetes clusters, I want to automate upgrades of Kubernetes and node images using auto-upgrade profiles, so that I can ensure safe and consistent updates without manual intervention."
---

# Automate upgrades of Kubernetes and node images across multiple clusters using Azure Kubernetes Fleet Manager

Platform admins managing large number of clusters often have problems with staging the updates of multiple clusters (for example, upgrading node OS image or Kubernetes versions) in a safe and predictable way. To address this challenge, Azure Kubernetes Fleet Manager (Fleet) allows you to orchestrate updates across multiple clusters using update runs.

Update runs consist of stages, groups, and strategies and can be applied either manually, for one-time updates, or automatically, for ongoing regular updates using auto-upgrade profiles. All update runs (manual or automated) honor member cluster maintenance windows.

This article covers how to use auto-upgrade profiles to automatically trigger update runs when new Kubernetes or node image versions are made available. 

## Prerequisites

* Read the [conceptual overview of auto-upgrade profiles](./concepts-update-orchestration.md#understanding-auto-upgrade-profiles), which provides an explanation of configurations referenced in this guide.

* You must have a Fleet resource with one or more member clusters. If not, follow the [quickstart][fleet-quickstart] to create a Fleet resource and join Azure Kubernetes Service (AKS) clusters as members.

* To use an update strategy, configure one using the instructions in the [update run how-to article](./update-orchestration.md#create-an-update-run-using-update-strategies). You need the update strategy resource identifier to use with an auto-upgrade profile.

* Set the following environment variables:

    ```bash
    export GROUP=<resource-group>
    export FLEET=<fleet-name>
    export AUTOUPGRADEPROFILE=<upgrade-profile-name>
    # Optional
    export STRATEGYID=<strategy-id>
    export CLUSTER=<aks-cluster-name>
    ```

* You need Azure CLI version 2.70.0 or later installed. To install or upgrade, see [Install the Azure CLI][azure-cli-install].

* You also need the `fleet` Azure CLI extension version 1.5.0 or later, which you can install by running the following command:

  ```azurecli-interactive
  az extension add --name fleet
  ```

  Run the following command to update to the latest version of the extension released:

  ```azurecli-interactive
  az extension update --name fleet
  ```

> [!NOTE]
> Auto-upgrade triggered update runs honor [planned maintenance windows](/azure/aks/planned-maintenance) that you set at the AKS cluster level. For more information, see [planned maintenance across multiple member clusters](./concepts-update-orchestration.md#planned-maintenance) which explains how update runs handle member clusters with configured planned maintenance windows.

## Create auto-upgrade profiles  

### [Azure portal](#tab/azure-portal)

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, under **Settings**, select **Multi-cluster update** > **Auto-upgrade profiles**.
1. Select **Create**, enter a name for the profile, and then select whether the profile is **Enabled** or not. Disabled auto-upgrade profiles don't trigger when new versions are released.
1. Select the update sequence of either **Stages** or **One by one**.

    :::image type="content" source="./media/auto-upgrade/create-auto-upgrade-profile-01.png" alt-text="Screenshot of the Azure Kubernetes Fleet Manager Azure portal pane for creating auto-upgrade profile that updates clusters using a strategy." lightbox="./media/auto-upgrade/create-auto-upgrade-profile-01.png":::

1. Select one of the following options for the **Channel**:

    * **Stable** - update clusters with patches for N-1 Kubernetes generally available minor version. 
    * **Rapid** - update clusters with patches for the latest (N) Kubernetes generally available minor version.
    * **Node image** - update node image version only.
    * **Target Kubernetes version** - update clusters to a specific target Kubernetes version that you define. When you select this option, you must specify the target Kubernetes version in the format "{major version}.{minor version}" (for example, "1.30").

1. If you select either the **Stable**, **Rapid**, or **Target Kubernetes version** channel, you can choose how node image updates are applied:

    * **Latest image**: Updates every AKS cluster in the auto-upgrade profile to the latest image available for that cluster in its Azure region.
    * **Consistent image**: It's possible for an auto-upgrade to have AKS clusters across multiple Azure regions where the latest available node images can be different (check [release tracker](/azure/aks/release-tracker) for more information). Selecting this option ensures the auto-upgrade picks the **latest common** image across all Azure regions to achieve consistency.

    :::image type="content" source="./media/auto-upgrade/create-auto-upgrade-profile-02.png" alt-text="Screenshot of the Azure Kubernetes Fleet Manager Azure portal pane for creating auto-upgrade profile, defining how the update is triggered." lightbox="./media/auto-upgrade/create-auto-upgrade-profile-02.png":::

    > [!NOTE]
    > The **Node image** channel always uses **consistent image**.

1. If you selected an update sequence using **Stages**, select or create a **Strategy**.

    :::image type="content" source="./media/auto-upgrade/create-auto-upgrade-profile-03.png" alt-text="Screenshot of the Azure Kubernetes Fleet Manager Azure portal pane for creating auto-upgrade profile, selecting the update strategy to use." lightbox="./media/auto-upgrade/create-auto-upgrade-profile-03.png":::

1. Select **Create** to create the auto-upgrade profile.

### [Azure CLI](#tab/cli)

Use the [`az fleet autoupgradeprofile create`][az-fleet-autoupgradeprofile-create] command to create profiles as shown.

You can create a disabled auto-upgrade profile by passing the `--disabled` argument when using the `create` command. In order to enable the auto-upgrade profile, you must reissue the entire `create` command and omit the `--disabled` argument.

> [!NOTE]
> Disabling an auto-upgrade profile doesn't affect any in-progess update runs, however no new update runs are generated until you re-enable the profile.

#### Stable channel Kubernetes updates

Update to the latest supported Kubernetes patch release on minor version N-1, where N is the latest supported minor version.

Update member clusters sequentially one-by-one.

```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --channel Stable
```

Update member clusters using an existing update strategy.
 
```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --update-strategy-id $STRATEGYID \
  --channel Stable
```

Update member clusters using an existing update strategy, ensuring the same node image version is used in every Azure region. All member clusters run the same node image version.
 
```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --update-strategy-id $STRATEGYID \
  --channel Stable \
  --node-image-selection Consistent
```

Update member clusters using an existing update strategy, using the latest available node image version for each Azure region. Member clusters may run multiple node image versions. 
 
```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --update-strategy-id $STRATEGYID \
  --channel Stable \
  --node-image-selection Latest
```

#### Target Kubernetes version updates

Update to a specific target Kubernetes version that you defines. You defines the Kubernetes minor version (in the format "{major version}.{minor version}") by using `--target-kubernetes-version` parameter. Fleet Autoupgrade automatically upgrades member clusters to the latest patch release of the specified target version when it becomes available.

> [!NOTE]
> When using the `TargetKubernetesVersion` channel, you must specify the `--target-kubernetes-version` parameter. For other channels (Rapid, Stable, NodeImage), this parameter must not be provided.

> [!NOTE]
> The `--long-term-support` (LTS) flag is only available when using the `TargetKubernetesVersion` channel. When enabled, Fleet AutoUpgrade will generate update runs for patches of minor versions earlier than N-2 (where N is the latest supported minor version) if those minor versions support Long-Term Support (LTS). If disabled, Fleet AutoUpgrade will not generate update runs for patches of such versions.
> 
> For other channels, this flag must be set to False.

Setup to automatically update member clusters to latest patch of Kubernetes version 1.33. 

```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --channel TargetKubernetesVersion \
  --target-kubernetes-version "1.33"
```

Setup to automatically update member clusters to latest patch of Kubernetes version 1.29. Assuming 1.33 is the latest Kubernetes minor version, notice how you need to enable `longTermSupport` on the auto upgrade profile.

```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --channel TargetKubernetesVersion \
  --target-kubernetes-version "1.29" \
  --long-term-support
```

#### Node image updates

Update nodes with a newly patched VHD containing security fixes and bug fixes.

Update node images for member clusters, processing clusters sequentially one-by-one.

```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --channel NodeImage
```

Update node images for member clusters, processing clusters using an existing update strategy.

```azurecli-interactive
az fleet autoupgradeprofile create \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE \
  --update-strategy-id $STRATEGYID \
  --channel NodeImage 
```

---

## View auto-upgrade profile

### [Azure portal](#tab/azure-portal)

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, under **Settings**, select **Multi-cluster update** > **Auto-upgrade profiles**.

    :::image type="content" source="./media/auto-upgrade/view-auto-upgrade-profile-01.png" alt-text="Screenshot of the Azure Kubernetes Fleet Manager Azure portal pane for viewing available auto-upgrade profiles." lightbox="./media/auto-upgrade/view-auto-upgrade-profile-01.png":::
 
1. To view its configuration, select the desired auto-upgrade profile.

    :::image type="content" source="./media/auto-upgrade/view-auto-upgrade-profile-02.png" alt-text="Screenshot of the Azure Kubernetes Fleet Manager Azure portal pane show the configuration of a single auto-upgrade profile." lightbox="./media/auto-upgrade/view-auto-upgrade-profile-02.png":::

### [Azure CLI](#tab/cli)

You can use the [`az fleet autoupgradeprofile list`][az-fleet-autoupgradeprofile-list] or [`az fleet autoupgradeprofile show`][az-fleet-autoupgradeprofile-show] commands to view the auto-upgrade profile.

List all auto-upgrade profiles for a Fleet.

```azurecli-interactive
az fleet autoupgradeprofile list \
  --resource-group $GROUP \
  --fleet-name $FLEET
```

Show a specific auto-upgrade profile for a Fleet.

```azurecli-interactive
az fleet autoupgradeprofile list \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE
```

---

## Delete auto-upgrade profile

### [Azure portal](#tab/azure-portal)

1. In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
1. From the service menu, under **Settings**, select **Multi-cluster update** > **Auto-upgrade profiles**.

    :::image type="content" source="./media/auto-upgrade/view-auto-upgrade-profile-01.png" alt-text="Screenshot of the Azure Kubernetes Fleet Manager Azure portal pane for viewing available auto-upgrade profiles." lightbox="./media/auto-upgrade/view-auto-upgrade-profile-01.png":::

1. Select the desired profile in the list and then select **Delete** to delete the profile.

### [Azure CLI](#tab/cli)

Use the [`az fleet autoupgradeprofile delete`][az-fleet-autoupgradeprofile-delete] command to delete an existing auto-upgrade profile. You're asked to confirm the deletion. If you wish to immediately delete the profile, include `--yes`.

```azurecli-interactive
az fleet autoupgradeprofile delete \
  --resource-group $GROUP \
  --fleet-name $FLEET \
  --name $AUTOUPGRADEPROFILE
```

---

> [!NOTE]
> Deleting an auto-upgrade profile doesn't affect any in-progress update runs.

## Validate auto-upgrade

Auto-upgrades happen only when new Kubernetes or node images are made available. When auto-upgrade is triggered, a linked update run is created, so you can use [manage update run](./update-orchestration.md#manage-an-update-run) to see the results of the auto-upgrade.

You can also check your existing versions as a baseline as follows.

```azurecli-interactive
# Get Kubernetes version for a member cluster
az aks show \
  --resource-group $GROUP \
  --name $CLUSTER \
  --query currentKubernetesVersion
```

```azurecli-interactive
# Get NodeImage version for a member cluster
az aks show \
  --resource-group $GROUP \
  --name $CLUSTER \
  --query "agentPoolProfiles[].{name:name,mode:mode, nodeImageVersion:nodeImageVersion, osSku:osSku, osType:osType}"
```

Once update runs finish, you can rerun these commands and view the updated versions that are deployed.

---

## Use an auto-upgrade profile to generate an update run  

When you create an auto-upgrade profile, your clusters can be on various versions of Kubernetes or node image. Depending on your selected auto-upgrade channel, it may be some time before a new Kubernetes or node image version triggers auto-upgrade to create and execute an update run. Auto-upgrade provides the `generate-update-run` command that generates a new update run using the current AKS-published Kubernetes or node image version.

For more information on creating an on-demand update run from an auto-upgrade profile, see [generate an update run from an auto-upgrade profile](./update-orchestration.md#generate-an-update-run-from-an-auto-upgrade-profile).

## Next steps

* [How-to: Monitor update runs for Azure Kubernetes Fleet Manager](./howto-monitor-update-runs.md).
* [Multi-cluster updates FAQs](./faq.md#multi-cluster-updates---automated-or-manual-faqs).

<!-- INTERNAL LINKS -->
[az-fleet-autoupgradeprofile-create]: /cli/azure/fleet/autoupgradeprofile#az-fleet-autoupgradeprofile-create
[az-fleet-autoupgradeprofile-list]: /cli/azure/fleet/autoupgradeprofile#az-fleet-autoupgradeprofile-list
[az-fleet-autoupgradeprofile-show]: /cli/azure/fleet/autoupgradeprofile#az-fleet-autoupgradeprofile-show
[az-fleet-autoupgradeprofile-delete]: /cli/azure/fleet/autoupgradeprofile#az-fleet-autoupgradeprofile-delete
[azure-cli-install]: /cli/azure/install-azure-cli

<!-- LINKS -->
[fleet-quickstart]: quickstart-create-fleet-and-members.md
