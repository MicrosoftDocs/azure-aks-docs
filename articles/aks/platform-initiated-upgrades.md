---
title: Platform-initiated upgrades in Azure Kubernetes Service (AKS)
description: Learn how Azure Kubernetes Service (AKS) automatically upgrades clusters that stay on an unsupported Kubernetes version, and how to keep control of your own upgrades.
author: kaarthis
ms.author: kaarthis
ms.date: 09/17/2026
ms.topic: concept-article
ms.service: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.custom: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: "As a cluster operator, I want to understand when and how AKS automatically upgrades clusters that fall out of support, so that I can upgrade on my own terms before the platform does it for me."
---

# Platform-initiated upgrades in Azure Kubernetes Service (AKS)

Azure Kubernetes Service (AKS) automatically upgrades any cluster that stays on an unsupported Kubernetes version after its [platform support grace period](#platform-support-grace-period) ends. This automatic upgrade is called a **platform-initiated upgrade**.

A cluster running an unsupported Kubernetes version no longer receives community patches, bug fixes, or CVE remediation. Platform-initiated upgrades ensure that every AKS cluster returns to a supported version, even if no one takes action.

> [!WARNING]
> Unlike an upgrade that you start while the cluster is in support, a platform-initiated upgrade doesn't stop when the [deprecated API breaking-change check](./stop-cluster-upgrade-api-breaking-changes.md) detects usage of an API that the target Kubernetes version removes. The upgrade proceeds, and workloads, clients, or controllers that depend on the removed API might stop working. AKS also doesn't validate self-managed add-ons for compatibility with the target version. Update manifests and upgrade or replace incompatible self-managed add-ons before the platform-initiated upgrade begins. For more information, see [AKS upgrade options and recommendations](./upgrade-options.md#validations-used-in-the-upgrade-process).
>
> A platform-initiated upgrade also doesn't follow your maintenance window and can override a Pod Disruption Budget (PDB) that prevents a node from draining. Workloads might be disrupted.
>
> Keeping your cluster on a supported version is the only way to avoid a platform-initiated upgrade. See [How to avoid platform-initiated upgrades](#how-to-avoid-platform-initiated-upgrades).

Platform-initiated upgrades don't change your billing tier, your upgrade channel, or your support tier. They apply only to clusters that already fell out of support.

## Prepare before AKS starts the upgrade

Take these steps before your cluster's platform-initiated upgrade month:

1. **Find clusters that are out of support or approaching end of life.** Use the [Azure Resource Graph query](#find-clusters-at-risk) and check the [release calendar](./supported-kubernetes-versions.md#aks-kubernetes-release-calendar-and-upcoming-versions).
1. **Remove dependencies on deprecated APIs.** In the Azure portal, go to **Diagnose and solve problems** > **Kubernetes API deprecations**. Update workloads, manifests, clients, controllers, and self-managed add-ons that use APIs removed from the target Kubernetes version. A platform-initiated upgrade doesn't stop when it detects this usage.
1. **Validate self-managed add-ons.** Check the Kubernetes version compatibility of each self-managed add-on, including its custom resource definitions and controllers. Upgrade or replace an add-on that's incompatible with the target Kubernetes version before AKS upgrades the cluster.
1. **Secure upgrade capacity.** Review [VM family quota, regional SKU availability, and subnet IP capacity](./quotas-skus-regions.md) before the expected upgrade month. Request quota increases or work with Azure support on regional capacity constraints early. Tune [`maxSurge`](./upgrade-aks-node-pools-rolling.md#customize-node-surge) for the capacity you can obtain. If extra surge capacity isn't available, consider [`maxUnavailable`](./upgrade-aks-node-pools-rolling.md#customize-unavailable-nodes), which upgrades eligible user node pools in place with no surge nodes but can reduce workload capacity during the upgrade.
1. **Use a predictable upgrade cadence.** For an individual cluster, use the [`stable` cluster auto-upgrade channel](./auto-upgrade-cluster.md#cluster-autoupgrade-channels) with [planned maintenance](./planned-maintenance.md) to keep the cluster on a supported minor version and run upgrades during a window you choose. The `patch` channel automatically applies patches within the current minor version, but it doesn't move the cluster to a newer minor version. For multiple clusters, consider a [Fleet Manager auto-upgrade profile and update strategy](/azure/kubernetes-fleet/concepts-update-orchestration) to stage upgrades across update groups with wait periods between stages. This approach provides a repeatable cadence while giving you time to validate each stage before the next one begins.
1. **Prepare PDBs for node drains.** Test that your PDBs allow a node drain to complete. If PDB management is difficult, consider [automatic PDB management (preview)](./automatic-pod-disruption-budget-management.md), which can create missing PDBs and temporarily add replicas when a PDB blocks a drain.
1. **Upgrade on your own schedule.** See [Upgrade an AKS cluster control plane](./upgrade-aks-control-plane.md), or follow [How to avoid platform-initiated upgrades](#how-to-avoid-platform-initiated-upgrades) to keep future upgrades under your control.
1. **Consider long-term support.** If you need a specific minor version supported for longer, evaluate [AKS long-term support](./long-term-support.md).

To upgrade a cluster with the Azure CLI:

```azurecli-interactive
# List the versions available in your region
az aks get-versions --location <region> --output table

# Upgrade the cluster
az aks upgrade --resource-group <resource-group> --name <cluster-name> --kubernetes-version <target-version>
```

## Platform-initiated upgrades compared to upgrades you control

Every other way to upgrade an AKS cluster respects the controls you configure. Platform-initiated upgrades don't, because their purpose is to return an unsupported cluster to a supported version.

| Upgrade method | Follows your maintenance window | Runs the deprecated API check | Honors PDBs and surge settings |
| -------------- | ------------------------------- | ----------------------------- | ------------------------------ |
| Manual upgrade with `az aks upgrade` | Not applicable — you choose when the upgrade runs | Yes | Yes |
| [Cluster auto-upgrade channel](./auto-upgrade-cluster.md) (`patch`, `stable`, `rapid`) | Yes | Yes | Yes |
| [Fleet Manager update runs and auto-upgrade profiles](/azure/kubernetes-fleet/concepts-update-orchestration) | Yes | Yes | Yes |
| **Platform-initiated upgrade** | **No** | **No** | **Best effort only** |

Because you keep full control with any of the first three methods, upgrading before your cluster falls out of support is always preferable to letting a platform-initiated upgrade run.

## Platform support grace period

When a Kubernetes minor version reaches end of life, community support ends and the version enters the AKS [platform support](./supported-kubernetes-versions.md#platform-support-policy) window. The **platform support grace period** is the 60-day window that follows, during which you can still upgrade on your own terms.

| Phase | What happens |
| ----- | ------------ |
| Community support | The version receives upstream patches, bug fixes, and CVE remediation. |
| End of life | Community support ends. The cluster enters platform support and the 60-day grace period starts. |
| Grace period (60 days) | Azure supports the platform — cluster connectivity, node health, and upgrade execution — but not Kubernetes bugs or CVEs in the unsupported version. Upgrade during this window to stay in control. |
| Grace period ends | The cluster becomes eligible for an AKS-initiated upgrade to a supported version. |

The grace period starts the day after the end-of-life date and lasts 60 days. For example, if a Kubernetes version reaches end of support on June 30, 2027, the grace period runs from July 1 through August 29, 2027. A cluster still on that version becomes eligible for a platform-initiated upgrade after the grace period. The release calendar shows the planned rollout month, not the date when a particular cluster is upgraded.

To see the platform-initiated upgrade month for every version, see the [AKS Kubernetes release calendar](./supported-kubernetes-versions.md#aks-kubernetes-release-calendar-and-upcoming-versions).

### Initial rollout

Through **May 31, 2027**, identify clusters running unsupported Kubernetes versions and upgrade them at your own pace. This customer-paced upgrade window is the grace period for the initial rollout.

Starting on **June 1, 2027**, AKS begins platform-initiated upgrades for clusters that remain on unsupported versions. Standard community-support clusters are expected to run Kubernetes 1.36 or later, and clusters enrolled in LTS are expected to run Kubernetes 1.33 LTS or later. AKS doesn't automatically enroll clusters in LTS.

After the initial rollout, every end-of-support event has a 60-day grace period before platform-initiated upgrades begin.

### Timing isn't exact

AKS rate-limits platform-initiated upgrades by region, subscription, and source version so that upgrades don't run everywhere at once. Your cluster is upgraded during or after the month shown in the release calendar, not on a specific date.

Don't plan around a precise upgrade time. Plan to be on a supported version before the grace period ends.

## How to avoid platform-initiated upgrades

A platform-initiated upgrade only runs on a cluster that's already out of support. Staying in support is what keeps you out of this path, and it also keeps every upgrade inside your maintenance window.

### For individual clusters

1. **Set an auto-upgrade channel.** The [`stable` channel](./auto-upgrade-cluster.md#cluster-autoupgrade-channels) keeps your cluster on a supported minor version automatically. The `patch` channel only applies patches within the current minor version. The `none` channel, or no channel at all, lets the cluster drift out of support.
1. **Configure a maintenance window.** Pair the channel with [planned maintenance](./planned-maintenance.md) so upgrades run during low-traffic periods. Use a window of at least four hours.
1. **Subscribe to notifications.** Set up [AKS Communication Manager](./aks-communication-manager.md) so you hear about upgrades before they run.
1. **Keep workloads upgrade-ready.** Test your PDBs, and consider [automatic Pod Disruption Budget management](./automatic-pod-disruption-budget-management.md) to keep node drains unblocked.

### For fleets

If you manage many clusters, use [Azure Kubernetes Fleet Manager](/azure/kubernetes-fleet/overview) to keep every member cluster in support:

1. **Create an auto-upgrade profile.** A [Fleet Manager auto-upgrade profile](/azure/kubernetes-fleet/concepts-update-orchestration) with the `Stable` or `Rapid` channel keeps member clusters on supported versions automatically.
1. **Use update runs and update groups.** [Update orchestration](/azure/kubernetes-fleet/update-orchestration) upgrades member clusters in a controlled sequence, so you can stage upgrades across environments.
1. **Stage with update strategies.** Group clusters into stages — for example, test before production — and add wait times between stages to validate each one.
1. **Track member versions.** Review the Kubernetes version of every member cluster against the [release calendar](./supported-kubernetes-versions.md#aks-kubernetes-release-calendar-and-upcoming-versions), or use the [Azure Resource Graph query](#find-clusters-at-risk).

> [!IMPORTANT]
> Fleet Manager update runs and update groups apply only to clusters that are still in support. Once a member cluster falls out of support, AKS acts on it directly with a platform-initiated upgrade that bypasses Fleet Manager sequencing. Keep member clusters in support so your fleet sequencing stays in effect.

## Which Kubernetes version AKS chooses

AKS upgrades the cluster to the **lowest supported version within its current support tier**:

| Current support tier | Target version |
| -------------------- | -------------- |
| Community support | The lowest supported community minor version. |
| [Long-term support (LTS)](./long-term-support.md) | The applicable LTS version. |

AKS always selects the latest available patch release within the target minor version.

Platform-initiated upgrades never cross support tiers. A community-support cluster isn't enrolled in LTS, and an LTS cluster isn't dropped to a community version. Because LTS is an opt-in that requires the Premium tier, AKS never enrolls a cluster in LTS on your behalf and never changes your billing tier. For more information, see [Enable long-term support](./long-term-support.md#enable-long-term-support).

### Clusters several minor versions behind

Kubernetes doesn't allow skipping minor versions during a control plane upgrade. If your cluster is several minor versions behind, AKS moves it **one minor version at a time** until it reaches a supported version.

A cluster that's far behind takes longer to return to support and carries a higher risk of workload problems, because each minor version can remove APIs that your workloads depend on. Upgrading these clusters yourself is strongly recommended.

### Control plane and node pools

A platform-initiated upgrade brings the entire cluster to the target version. AKS upgrades the [control plane](./upgrade-aks-control-plane.md) first, then the [node pools](./upgrade-node-pools.md), using the same upgrade orchestration as `az aks upgrade`.

## What AKS overrides during a platform-initiated upgrade

To ensure the upgrade finishes, AKS overrides some of the controls that apply to every other upgrade method.

| Control | Behavior during a platform-initiated upgrade |
| ------- | ------------------------------------------- |
| [Maintenance window](./planned-maintenance.md) | Not honored. The upgrade can start at any time from the platform-initiated upgrade month onward. |
| [Auto-upgrade channel](./auto-upgrade-cluster.md) | Ignored. Clusters with no channel configured, or with the `none` or `patch` channel, are still upgraded. |
| [Fleet Manager update runs and update groups](/azure/kubernetes-fleet/concepts-update-orchestration) | Not honored. AKS acts on the member cluster directly. |
| [Deprecated API check](./stop-cluster-upgrade-api-breaking-changes.md) | Bypassed. The upgrade proceeds even when deprecated API usage is detected. |
| [Pod Disruption Budgets (PDBs)](./best-practices-app-cluster-reliability.md#pod-disruption-budgets-pdbs) | Honored on a best-effort basis. AKS attempts a normal node drain first and overrides a PDB only if the drain times out or fails. |
| Node surge settings | Honored on a best-effort basis. If AKS can't create surge capacity, it falls back to upgrading one node at a time (`maxSurge=0`, `maxUnavailable=1`). |
| [Blue-green node pool upgrades](./blue-green-node-pool-upgrade.md) | Executed as a rolling upgrade. Your stored strategy isn't changed. |

Because AKS can override a PDB and can bypass the deprecated API check, a platform-initiated upgrade is a **best-effort upgrade with no workload availability guarantee**. Workloads might be disrupted.

Platform-initiated upgrades can't be rolled back. You [can't roll back to an unsupported version](./roll-back-node-pool-version.md), so the version you were running before the upgrade isn't available again.

### Your configuration isn't changed

AKS ignores these settings at execution time, but it doesn't modify them. After a platform-initiated upgrade, the following settings are unchanged:

- Auto-upgrade profile and upgrade channel
- Maintenance window configuration
- Node pool upgrade strategy, including blue-green
- Maximum surge and maximum unavailable settings
- Billing tier and LTS enrollment

## Find clusters at risk

Use this Azure Resource Graph query in the [Azure portal](https://portal.azure.com/#blade/HubsExtension/ArgQueryBlade) or with the Azure CLI to list AKS clusters across your subscriptions with their current Kubernetes version and support tier:

```kusto
resources
| where type =~ 'microsoft.containerservice/managedclusters'
| project
    clusterName = name,
    resourceGroup,
    subscriptionId,
    location,
    kubernetesVersion = properties.kubernetesVersion,
    tier = properties.sku.tier,
    supportPlan = properties.supportPlan,
    upgradeChannel = properties.autoUpgradeProfile.upgradeChannel,
    powerState = properties.powerState.code
| order by kubernetesVersion asc, clusterName asc
```

To run the query with the Azure CLI:

```azurecli-interactive
az graph query -q "resources | where type =~ 'microsoft.containerservice/managedclusters' | project clusterName = name, resourceGroup, subscriptionId, kubernetesVersion = properties.kubernetesVersion, tier = properties.sku.tier, supportPlan = properties.supportPlan | order by kubernetesVersion asc" --output table
```

Compare the `kubernetesVersion` values against the [AKS Kubernetes release calendar](./supported-kubernetes-versions.md#aks-kubernetes-release-calendar-and-upcoming-versions) to find clusters that are out of support or approaching end of life. A `supportPlan` value of `AKSLongTermSupport` indicates that the cluster is enrolled in LTS.

## How you're notified

AKS surfaces at-risk clusters through several channels before any platform-initiated upgrade runs:

- **Azure Resource Health**: A cluster in the platform support window reports a **Degraded** health status that names the current version and when AKS upgrades the cluster.
- **Azure portal**: A banner on the cluster resource warns that the version is out of support and that AKS upgrades the cluster automatically.
- **Azure Advisor**: A recommendation identifies clusters running unsupported versions.
- **[AKS Communication Manager](./aks-communication-manager.md)**: Sends email notifications about upcoming and completed platform-initiated upgrades.
- **Diagnose and solve problems**: Shows cluster upgrade status and deprecated API usage in the Azure portal.

These channels share the same underlying state, so they don't disagree with each other. For a scheduled or retrying upgrade, you can see the lifecycle state, retry count, next retry time, and last error.

### Audit a platform-initiated upgrade

Platform-initiated upgrades appear in the [Azure Activity Log](/azure/azure-monitor/essentials/activity-log) with metadata that distinguishes them from upgrades you trigger:

| Property | Value |
| -------- | ----- |
| `initiatedBy` | `System` |
| `upgradeTrigger` | `PlatformInitiatedUnsupportedVersion` |
| `upgradeSource` | `PlatformInitiated` |

The event also records the source and target Kubernetes versions. Filter the Activity Log on these properties to attribute the change during a change-management or compliance review.

## When an upgrade can't complete

If a platform-initiated upgrade fails, AKS automatically retries it on a system-determined schedule. The cluster stays on an unsupported version until the upgrade succeeds.

A blocker doesn't exempt your cluster from the policy; it only leaves the cluster unsupported for longer. Common blockers include:

- An add-on or feature that isn't supported on the target version. For LTS clusters, see [add-on and feature lifecycle considerations](./long-term-support.md#add-on-and-feature-lifecycle-considerations).
- A retired VM size in a node pool.
- Insufficient IP addresses in the node subnet.
- Regional capacity constraints.
- A resource lock on the cluster or its resource group.
- An Azure Policy assignment that denies changes to the Kubernetes version.

Check the failure reason in Azure Resource Health or **Diagnose and solve problems**, resolve the blocker, and then upgrade the cluster yourself. If you can't identify the cause, [open a support request](./aks-support-help.md).

### Clusters that AKS skips

AKS doesn't run platform-initiated upgrades on:

- **Stopped clusters.** AKS defers the upgrade while the cluster is stopped. After you start the cluster, it runs normally and is reevaluated for a platform-initiated upgrade on the next cycle. Starting a cluster doesn't trigger an immediate upgrade.
- **Clusters being deleted.**
- **Clusters in a failed provisioning state.** Resolve the failed state first.

## Availability

Platform-initiated upgrades apply to AKS in the Azure public cloud. Availability in Azure Government and Microsoft Azure operated by 21Vianet follows [Azure safe deployment practices](/azure/well-architected/operational-excellence/safe-deployments) and is announced separately.

AKS enabled by Azure Arc and AKS on Azure Local are out of scope. Those offerings have their own lifecycle and upgrade models.

## Frequently asked questions

### Can I opt out of platform-initiated upgrades?

No. There's no opt-out setting. You keep control by keeping the cluster on either a supported community minor version or an LTS version that you explicitly enrolled in. Platform-initiated upgrades act only on clusters that remain on an unsupported version after the 60-day platform support grace period ends.

### Can I cancel a platform-initiated upgrade that already started?

No. An in-flight platform-initiated upgrade can't be canceled.

### Does this change my billing or service tier?

No. There are no billing or tier changes. If you don't opt into LTS, your cluster is upgraded to a supported community version at no extra cost.

### Does AKS enroll my cluster in long-term support?

No. LTS is a separately priced opt-in that requires the Premium tier. AKS never enrolls a cluster in LTS on your behalf. To keep a specific minor version supported for longer, [enroll the cluster in LTS](./long-term-support.md#enable-long-term-support) yourself.

### My cluster is enrolled in LTS and its LTS end of life passed. What version does AKS choose?

The cluster stays on the LTS track and is upgraded to the next supported LTS version. It isn't dropped to a community-supported version.

### Will my workloads experience downtime?

Possibly. AKS attempts a normal node drain and honors PDBs where it can, but it overrides a PDB if the drain times out or fails. A platform-initiated upgrade is best effort and carries no workload availability guarantee. Test your PDBs and upgrade settings before your cluster's platform-initiated upgrade month, or upgrade the cluster yourself so that your maintenance window and PDBs are fully honored.

### Does the upgrade honor my maintenance window?

No. Platform-initiated upgrades don't follow maintenance windows and can start at any time from the platform-initiated upgrade month onward. Maintenance windows still apply to manual upgrades, cluster auto-upgrade, and Fleet Manager update runs.

### Does my auto-upgrade channel affect this?

No. Your channel setting doesn't exempt the cluster. Clusters with no channel configured, or with the `none` or `patch` channel, are still upgraded when they're out of support. Your channel configuration isn't modified.

The `stable` channel helps keep the cluster on a supported minor version. The `patch` channel applies patches within the current minor version but doesn't move the cluster to a newer minor version. For more information, see [How to avoid platform-initiated upgrades](#how-to-avoid-platform-initiated-upgrades).

### Does Fleet Manager protect my member clusters from platform-initiated upgrades?

Fleet Manager helps you keep member clusters in support, which is what avoids platform-initiated upgrades. However, once a member cluster falls out of support, AKS acts on it directly and doesn't follow Fleet Manager update runs, update groups, or maintenance windows. For more information, see [For fleets](#for-fleets).

### Does the upgrade also update node images or the OS SKU?

Platform-initiated upgrades target the Kubernetes version. Nodes are reimaged as part of the upgrade and come up on the current node image for the target version. The OS SKU isn't changed. To manage node images separately, see [Upgrade AKS node images](./upgrade-node-image.md).

### What if my node pools are far behind the control plane?

AKS upgrades the control plane first, then brings node pools to the target version within the [Kubernetes version upgrade rules](./upgrade-aks-control-plane.md#kubernetes-version-upgrade-rules). If a node pool is too far behind, AKS upgrades it in steps along with the control plane.

### Can I roll back after a platform-initiated upgrade?

No. AKS doesn't support downgrades, and you can't roll back to an unsupported version. For more information, see [Roll back an AKS node pool](./roll-back-node-pool-version.md).

### Is a workload issue caused by a platform-initiated upgrade supportable?

You can open a support request for help with the cluster and the upgrade itself. However, a platform-initiated upgrade is best effort and carries no workload availability guarantee, and clusters running unsupported versions have no runtime guarantees. Validate workload compatibility with the target version before your cluster's platform-initiated upgrade month.

### How much notice do I get?

Your cluster enters the platform support window at end of life, which gives you a 60-day grace period before it becomes eligible for a platform-initiated upgrade. The [release calendar](./supported-kubernetes-versions.md#aks-kubernetes-release-calendar-and-upcoming-versions) publishes planned rollout months in advance, and Azure Resource Health, Azure Advisor, and AKS Communication Manager notify you during the grace period.

## Related content

- [Supported Kubernetes versions in AKS](./supported-kubernetes-versions.md)
- [Long-term support for AKS versions](./long-term-support.md)
- [Upgrade an AKS cluster control plane](./upgrade-aks-control-plane.md)
- [Automatically upgrade an AKS cluster](./auto-upgrade-cluster.md)
- [Use planned maintenance to schedule and control upgrades](./planned-maintenance.md)
- [Update orchestration across multiple clusters with Fleet Manager](/azure/kubernetes-fleet/update-orchestration)
- [Best practices for application and cluster reliability](./best-practices-app-cluster-reliability.md)
