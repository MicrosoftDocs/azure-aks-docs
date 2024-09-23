---
title: "Update Kubernetes and node images across multiple member clusters"
description: This article describes the concept of update orchestration across multiple clusters.
ms.date: 03/04/2024
author: sjwaight
ms.author: simonwaight
ms.service: kubernetes-fleet
ms.custom:
  - build-2024
ms.topic: conceptual
---

# Update Kubernetes and node images across multiple member clusters

Platform admins managing large number of clusters often have problems with staging the updates of multiple clusters (for example, upgrading node OS image or Kubernetes versions) in a safe and predictable way. To address this challenge, Azure Kubernetes Fleet Manager (Fleet) allows you to orchestrate updates across multiple clusters using update runs. 

Update runs consist of stages, groups, and strategies and can be applied either manually, for one-time updates, or automatically, for ongoing regular updates using autoupgrade profiles. All update runs (manual or automated) honor member cluster maintenance windows.

## Understanding update runs

The following image visualizes an upgrade run containing two update stages, each containing two update groups with two member clusters. A wait period is configured between the first and second stages.

:::image type="content" source="./media/conceptual-update-orchestration-inline.png" alt-text="A diagram showing an upgrade run containing two update stages, each containing two update groups with two member clusters." lightbox="./media/conceptual-update-orchestration.png":::

* **Update run**: An update run represents an update being applied to a collection of AKS clusters, consisting of the update goal and sequence. The update goal describes the desired updates (for example, upgrading to Kubernetes version 1.28.3). The update sequence describes the exact order to apply the update to multiple member clusters, expressed using stages and groups. If unspecified, all the member clusters are updated one by one sequentially. An update run can be stopped and started.
* **Update stage**: Update runs are divided into stages, which are applied sequentially. For example, a first update stage might update test environment member clusters, and a second update stage would then later update production environment member clusters. A wait time can be specified to delay between the application of subsequent update stages.
* **Update group**: Each update stage contains one or more update groups, which are used to select the member clusters to be updated. Update groups are also used to order the application of updates to member clusters. Within an update stage, updates are applied to all the different update groups in parallel; within an update group, member clusters update sequentially. Each member cluster of the fleet can only be a part of one update group.
* **Update strategy**: An update strategy describes the update sequence with stages and groups and allows you to reuse an update run configuration instead of defining the sequence repeatedly in each run. An update strategy does not include desired Kubernetes or node image versions.

Currently, the supported update operations on member cluster are upgrades. There are three types of upgrades you can choose from:

- Upgrade Kubernetes versions for the Kubernetes control plane and the nodes (which includes upgrading the node images).
- Upgrade Kubernetes versions for only the control plane of the clusters.
- Upgrade only the node images.

You can specify the target Kubernetes version to upgrade to, but you can't specify the exact target node image version. This is because the latest available node image version may vary depending on the Azure region of the cluster (check the AKS [release tracker](/azure/aks/release-tracker) for more information).

The target node image versions are automatically selected for you based on your preferences:

- `Latest`: Use the latest node images available in the Azure region of a cluster when the upgrade of the cluster starts. As a result, different image versions could be used depending on which Azure region a cluster is in and when its upgrade actually starts.
- `Consistent`: When the update run starts, it picks the **latest common** image versions across the Azure regions of the member clusters in this run, such that the same, consistent image versions are used across clusters.

You should choose `Latest` to use fresher image versions and minimize security risks, and choose `Consistent` to improve reliability by using and verifying those images in clusters in earlier stages before using them in later clusters.

### Update run states

An update run can be in one of the following states:

- **NotStarted**: Update run has not started.
- **Running**: Upgrade is in progress for at least one of the member clusters in the update run.
- **Pending**: 
  - **Member cluster**: A member cluster can be in the pending state for any of the following reasons which can be viewed in the message field.
    - Maintenance window is not open. Message indicates next opening time.
    - Target Kubernetes version is not yet available in the Azure region of the member. Message links to the release tracker so that you can check status of the release across regions.
    - Target node image version is not yet available in the Azure region of the member. Message links to the release tracker so that you can check status of the release across regions.
  - **Group**: A group is in `Pending` state if all members in the group are in `Pending` state or not started. When a member moves to `Pending`, the update run will attempt to upgrade the next member in the group. If all members are `Pending`, the group moves to `Pending` state. If a group is in `Pending` state, the update run waits for the group to complete before moving on to the next stage for execution.
  - **Stage**: A stage is in `Pending` state if all groups under that stage are in `Pending` state or not started.
  - **Run**: A run is in `Pending` state if the current stage that should be running is in `Pending` state.
- **Skipped**: All levels of an update run can be skipped and this could either be system or user-initiated.
  - **Member**:
    - You have skipped upgrade for a member, group or stage.
    - Member cluster is already at the target Kubernetes version (if update run mode is `Full` or `ControlPlaneOnly`).
    - Member cluster is already at the target Kubernetes version and all node pools are at the target node image version.
    - When consistent node image is chosen for an upgrade run, if it's not possible to find the target image version for one of the node pools, then upgrade is skipped for that cluster. An example situation for this is when a new node pool with a new VM SKU is added after an update run has started.
  - **Group**:
    - All member clusters were detected as `Skipped` by the system.
    - You initiated a skip at the group level.
  - **Stage**:
    - All groups in the stage were detected as `Skipped` by the system.
    - You initiated a skip at the stage level.
  - **Run**:
    - All stages were detected as `Skipped` by the system.
- **Stopped**: All levels of an update run can be stopped. There are two possibilities for entering a stopped state:
  - You stop the update run, at which point update run stops tracking all operations. If an operation was already initiated by update run (for example, a cluster upgrade is in progress), then that operation is not aborted for that individual cluster.
  - If a failure is encountered during the update run (for example upgrades failed on one of the clusters), the entire update run enters into a stop state and operated are not attempted for any subsequent cluster in the update run.
- **Failed**: A failure to upgrade a cluster will result in the following actions:
  - Marks the `MemberUpdateStatus` as `Failed` on the member cluster.
  - Marks all parents (group -> stage -> run) as `Failed` with a summary error message.
  - Stops the update run from progressing any further.

You can re-run an update run at any time in order to re-apply upgrades that may have been skipped or failed.

## Planned maintenance

Update runs honor [planned maintenance windows](/azure/aks/planned-maintenance) that you set at the Azure Kubernetes Service (AKS) cluster level.

Within an update run (for both [One by one](./update-orchestration.md#update-all-clusters-one-by-one) or [Stages](./update-orchestration.md#update-clusters-in-a-specific-order) type update runs), update run prioritizes upgrading the clusters in the following order: 
  1. Member with an open ongoing maintenance window.
  1. Member with maintenance window opening in the next four hours.
  1. Member with no maintenance window.
  1. Member with a closed maintenance window.

## Understanding autoupgrade profiles (preview)

Autoupgrade profiles are used to automatically trigger update runs when new Kubernetes or node image versions are made available. 

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

In an autoupgrade profile you can configure:

- a `Channel` (Stable, Rapid, NodeImage) which determines the type of autoupgrade that will be applied to the clusters. For further information see the following table.
- an `UpdateStrategy` which configures the sequence in which the clusters will be upgraded. If a strategy is not supplied, clusters are updated one by one sequentially.
- the `NodeImageSelectionType` (Latest, Consistent) to specify how the node image will be selected when upgrading the Kubernetes version.

The Channel behaviors are shown in the table.

|Channel| Action | Example
|---|---|---|
| `Stable`| Automatically upgrades member clusters to the latest supported patch release on minor version *N-1*, where *N* is the latest supported minor version.| If a member cluster runs version *1.28.12* and version *1.29.7* is made available, the member cluster upgrades to *1.29.7*.|
| `Rapid`| Automatically upgrades member clusters to the latest supported patch release on the latest supported minor version. | In cases where a member cluster's Kubernetes version is an *N-2* minor version, where *N* is the latest supported minor version, the member cluster first upgrades to the latest supported patch version on *N-1* minor version. For example, if a member cluster runs version *1.28.9* and versions *1.28.12*, *1.29.2*, *1.29.4* are available, and *1.30.2* is made available, the member cluster first upgrades to *1.29.4*, then upgrades to *1.30.2*.|
| `NodeImage` | Member cluster nodes are updated with a newly patched VHD containing security fixes and bug fixes on a weekly cadence. The update to the new VHD is disruptive, following maintenance windows and surge settings. No extra VHD cost is incurred when choosing this option. If you use this channel, Linux unattended upgrades are disabled by default. Node image upgrades support patch versions that are deprecated, so long as the minor Kubernetes version is still supported. Node images are AKS-tested, fully managed, and applied with safe deployment practices. | If your member clusters have a NodeImage of *AKSWindows-2022-containerd* with a version of *20348.2582.240716*, and a new version *20348.2582.240916* is released, your member clusters NodeImage will automatically be upgraded to version *20348.2582.240916*. |

> [!NOTE]
>
> Keep the following information in mind when using auto upgrade:
>
> * Autoupgrade only updates to GA versions of Kubernetes and doesn't update to preview versions.
>
> * Autoupgrade requires the cluster's Kubernetes version to be within the [AKS support window][supported-kubernetes-versions].
>
> * If you want to have your Kubernetes version upgraded, you need to create an `autoupgradeprofile` with `Rapid` or `Stable` Channels.
>
> * If you want to have your NodeImage version upgraded, you need to create an `autoupgradeprofile` with `NodeImage` Channel.
>
> * You can create multiple autoupgrade profiles for the same Fleet.

## Next steps

* [How-to: Upgrade multiple clusters using Azure Kubernetes Fleet Manager update runs](./update-orchestration.md).
* [How-to: Automatically upgrade multiple clusters using Azure Kubernetes Fleet Manager](./update-automation.md).

<!-- INTERNAL LINKS -->
[supported-kubernetes-versions]: /azure/aks/supported-kubernetes-versions