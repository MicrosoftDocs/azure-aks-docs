---
title: "Update Kubernetes and node images across multiple member clusters"
description: This article describes the concept of update orchestration across multiple clusters.
ms.date: 03/06/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: conceptual
---

# Update Kubernetes and node images across multiple member clusters

Platform admins managing large number of clusters often have problems with staging the updates of multiple clusters (for example, upgrading node OS image or Kubernetes versions) in a safe and predictable way. To address this challenge, Azure Kubernetes Fleet Manager (Fleet) allows you to orchestrate updates across multiple clusters using update runs. 

Update runs consist of stages, groups, and strategies and can be applied either manually, for one-time updates, or automatically, for ongoing regular updates using auto-upgrade profiles. All update runs (manual or automated) honor member cluster [maintenance windows][aks-maintenance-windows].

## Understanding update runs

The following image visualizes an upgrade run containing two update stages, each containing two update groups with two member clusters. A wait period is configured between the first and second stages.

:::image type="content" source="./media/conceptual-update-orchestration-inline.png" alt-text="A diagram showing an upgrade run containing two update stages, each containing two update groups with two member clusters." lightbox="./media/conceptual-update-orchestration.png":::

* **Update run**: An update run represents an update being applied to a collection of AKS clusters, consisting of the update goal and sequence. The update goal describes the desired updates (for example, upgrading to Kubernetes version 1.28.3). The update sequence describes the exact order to apply the update to multiple member clusters, expressed using stages and groups. If unspecified, all the member clusters are updated one by one sequentially. An update run can be stopped and started.
* **Update stage**: Update runs are divided into stages, which are applied sequentially. For example, a first update stage might update test environment member clusters, and a second update stage would then later update production environment member clusters. A wait time can be specified to delay between the application of subsequent update stages.
* **Update group**: Each update stage contains one or more update groups, which are used to select the member clusters to be updated. Update groups are also used to order the application of updates to member clusters. Within an update stage, updates are applied to all the different update groups in parallel; within an update group, member clusters update sequentially. Each member cluster of the fleet can only be a part of one update group.
* **Update strategy**: An update strategy describes the update sequence with stages and groups and allows you to reuse an update run configuration instead of defining the sequence repeatedly in each run. An update strategy doesn't include desired Kubernetes or node image versions.

Currently, the supported update operations on member cluster are upgrades. There are three types of upgrades you can choose from:

- Upgrade Kubernetes versions for the Kubernetes control plane and the nodes (which includes upgrading the node images).
- Upgrade Kubernetes versions for only the control plane of the clusters.
- Upgrade only the node images.

You can specify the target Kubernetes version to upgrade to, but you can't specify the exact target node image version. This is because the latest available node image version may vary depending on the Azure region of the cluster (check the AKS [release tracker](/azure/aks/release-tracker) for more information).

The target node image versions are automatically selected for you based on your preferences:

- `Latest`: Use the latest node images available in the Azure region of a cluster when the upgrade of the cluster starts. As a result, different image versions could be used depending on which Azure region a cluster is in and when its upgrade actually starts.
- `Consistent`: When the update run starts, it picks the **latest common** image versions across the Azure regions of the member clusters in this run, such that the same, consistent image versions are used across clusters.

You should choose `Latest` to use fresher image versions and minimize security risks, and choose `Consistent` to improve reliability by using and verifying those images in clusters in earlier stages before using them in later clusters.

## Planned maintenance

Update runs honor [planned maintenance windows](/azure/aks/planned-maintenance) that you set at the Azure Kubernetes Service (AKS) cluster level.

Within an update run (for both [One by one](./update-orchestration.md#update-all-clusters-one-by-one) or [Stages](./update-orchestration.md#update-clusters-using-groups-and-stages) type update runs), update run prioritizes upgrading the clusters in the following order: 
  1. Member with an open ongoing maintenance window.
  2. Member with maintenance window opening in the next four hours.
  3. Member with no maintenance window.
  4. Member with a closed maintenance window.

## Update run states

An update run can be in one of the following states:

- **Not Started**: Update run hasn't started.
- **Running**: Update run is in progress for at least one member cluster.
- **Pending**: 
  - **Member cluster**: A member cluster can be in the `Pending` state for any of the following reasons which can be viewed in the message field.
    - Maintenance window isn't open. Message indicates next opening time.
    - Target Kubernetes version isn't yet available in the member's Azure region. Message links to the AKS release tracker so you can check status of the release across regions.
    - Target node image version isn't yet available in the member's Azure region. Message links to the AKS release tracker.
  - **Update group**: A group is `Pending` if all members in the group are `Pending` or not started. When a member moves to `Pending`, the update run will attempt to upgrade the next member in the group. If all members are `Pending`, the group moves to `Pending` state. If a group is `Pending`, the update run waits for the group to complete before moving on to the next update stage.
  - **Update stage**: A stage is `Pending` if all update groups in the stage are `Pending` or not started.
  - **Run**: A run is in `Pending` state if the current stage is in `Pending` state.
- **Skipped**: All levels of an update run can be skipped. Skipping can be system or user-initiated.
  - **Member cluster**:
    - User skipped update for the member, group, or stage.
    - Member cluster is already at the target Kubernetes version (if update run mode is `Full` or `ControlPlaneOnly`).
    - Member cluster is already at the target Kubernetes version and all node pools are at the target node image version.
    - When consistent node image is chosen for an update run, if it's not possible to find the target image version for one of the node pools, then the upgrade is skipped for that cluster. As an example, this can occur when a new node pool with a new Virtual Machine (VM) SKU is added after an update run has started.
  - **Update group**:
    - User skipped update for the group.
    - All member clusters were detected as `Skipped` by the system.
  - **Update stage**:
    - User skipped update for the stage.
    - All update groups in the stage were detected as `Skipped` by the system.
  - **Update run**:
    - All stages were detected as `Skipped` by the system.
- **Stopped**: All levels of an update run can be stopped. There are two possibilities for entering a stopped state:
  - User stopped the update run, at which point update run stopped tracking all operations. If an operation was already initiated by update run (for example, a cluster upgrade is in progress), then that operation isn't aborted for that individual cluster.
  - If a failure is encountered during the update run (for example upgrades failed on one of the clusters), the entire update run enters into a stopped state. Operations are not attempted for any subsequent cluster in the update run.
- **Failed**: A failure to upgrade a cluster results in the following actions:
  - Marks the `MemberUpdateStatus` as `Failed` on the member cluster.
  - Marks all parents (group -> stage -> run) as `Failed` with a summary error message.
  - Stops the update run from progressing any further.
- **Completed**: The update run has been successfully finished.

> [!NOTE]
> You can re-run an update run at any time in order to re-apply upgrades that may have been skipped or failed.

## Understanding auto-upgrade profiles (preview)

Auto-upgrade profiles are used to automatically trigger update runs when new Kubernetes or node image versions are made available for AKS. 

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

In an auto-upgrade profile you can configure:

- a `Channel` (Stable, Rapid, NodeImage) which determines the type of auto-upgrade that is applied to the clusters.
- an `UpdateStrategy` which configures the sequence in which the clusters are upgraded. If a strategy isn't supplied, clusters are updated one by one sequentially.
- the `NodeImageSelectionType` (Latest, Consistent) to specify how the node image is selected when upgrading the Kubernetes version.

### Stable channel

The Stable channel is always the latest AKS-supported Kubernetes patch release on minor version *N-1*, where *N* is the latest supported minor version.

Examples: 

- The latest supported minor Kubernetes version is *1.30*. Any patch releases in the *1.29* minor range would be considered for Stable channel updates.
- A new minor Kubernetes version of *1.31* is published. Any patch release in the *1.30* minor range would be considered for Stable channel updates. Any cluster previously receiving updates from *1.29* would be updated to the most recent patch for *1.30*.

### Rapid channel

The Rapid channel is always the most recent AKS-supported Kubernetes minor release.

Examples: 

- The latest supported minor version is *1.30*. Any patch release in the *1.30* minor range would be considered for Rapid channel updates.
- A new minor Kubernetes version of *1.31* is published. *1.30* shifts to the Stable channel. Any cluster previously receiving updates from *1.30* would be updated to the most recent patch for *1.31* which is now the Rapid channel.

### NodeImage channel

Member cluster nodes are updated with a newly patched VHD containing security fixes and bug fixes on a weekly cadence. The update to the new VHD is disruptive, following maintenance windows and surge settings. No extra VHD cost is incurred when choosing this option.

If you use this channel, Linux unattended upgrades are disabled by default. Node image upgrades support patch versions that are deprecated, so long as the minor Kubernetes version is still supported. Node images are AKS-tested, fully managed, and applied with safe deployment practices.

Nodes on different operating systems will be updated in accordance with the node image versions aligned to those operating systems. 

Example:

- A cluster has nodes with a NodeImage of *AKSWindows-2022-containerd* of version *20348.2582.240716*. A new NodeImage version *20348.2582.240916* is released and the cluster nodes are automatically upgraded to version *20348.2582.240916*.

### Minor version skipping behavior

Auto-upgrade does not move clusters between minor Kubernetes versions when there's more than one minor Kubernetes version difference (for example: 1.28 to 1.30). Where administrators have a diverse set of Kubernetes versions it's recommended to first use one or more [update run](#understanding-update-runs) to bring member clusters into a set of consistently versioned releases so that configured `Stable` or `Rapid` channel updates ensure consistency is maintained in future.

> [!NOTE]
>
> Keep the following information in mind when using auto upgrade:
>
> * Auto-upgrade requires version 1.3.0 or later of the Fleet Azure CLI extension.
>
> * Auto-upgrade only updates to GA versions of Kubernetes and doesn't update to preview versions.
>
> * Auto-upgrade requires the cluster's Kubernetes version to be within the [AKS support window][supported-kubernetes-versions].
>
> * If a cluster has no defined planned maintenance window it will be upgraded immediately when the update run reaches the cluster.
>
> * If you want to have your Kubernetes version upgraded, you need to create an `autoupgradeprofile` with `Rapid` or `Stable` channels.
>
> * If you want to have your NodeImage version upgraded, you need to create an `autoupgradeprofile` with `NodeImage` channel.
>
> * You can create multiple auto-upgrade profiles for the same Fleet.

## Next steps

* [How-to: Upgrade multiple clusters using Azure Kubernetes Fleet Manager update runs](./update-orchestration.md).
* [How-to: Automatically upgrade multiple clusters using Azure Kubernetes Fleet Manager](./update-automation.md).
* [How-to: Monitor update runs for Azure Kubernetes Fleet Manager](./howto-monitor-update-runs.md).

<!-- INTERNAL LINKS -->
[supported-kubernetes-versions]: /azure/aks/supported-kubernetes-versions
[aks-maintenance-windows]: /azure/aks/planned-maintenance
