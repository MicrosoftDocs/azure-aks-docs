---
title: "Frequently asked questions - Azure Kubernetes Fleet Manager"
description: This article covers the frequently asked questions for Azure Kubernetes Fleet Manager
ms.date: 08/21/2026
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: As a cloud administrator, I want to manage multiple Azure Kubernetes Service clusters through a centralized fleet, so that I can streamline updates, resource propagation, and load balancing across various clusters.
---

# Frequently Asked Questions - Azure Kubernetes Fleet Manager

**Applies to:** :heavy_check_mark: Fleet Manager :heavy_check_mark: Fleet Manager with hub cluster

This article covers the frequently asked questions for Azure Kubernetes Fleet Manager.

## Fleet Manager service FAQs

### Is Fleet Manager a regional or global resource?

Fleet Manager is a regional resource. Support for region failover for disaster recovery use cases is on the [roadmap](https://github.com/Azure/AKS/issues/3268).

### How many clusters can I join to Fleet Manager?

Fleet Manager (with or without a hub cluster) supports joining up to 1,000 Kubernetes clusters. Member clusters can be a mix of AKS and Arc-enabled Kubernetes.

If you want Fleet Manager to support more than 1,000 clusters, [add feedback](https://github.com/Azure/AKS/issues/5066).

### What Kubernetes clusters can I join as members?

Fleet Manager allows authorized users to add any AKS, AKS Automatic, or Arc-enabled Kubernetes cluster in any Azure subscription and region as long as the Azure subscription is associated with the same Microsoft Entra ID tenant as the Fleet Manager. 

### Does Fleet Manager support managed identities?

Yes, Fleet Manager supports both system-assigned and user-assigned managed identities. For more information, see the documentation on [using managed identities with Fleet Manager](./use-managed-identity.md).

### What happens when I change the cluster identity of a joined cluster?

Changing the identity of a member cluster breaks the communication between Fleet Manager and that member cluster. While the member agent uses the new identity to communicate with the Fleet Manager, Fleet Manager still needs to be made aware of the new identity. Run this command to resolve:

```azurecli
az fleet member create \
    --resource-group ${GROUP} \
    --fleet-name ${FLEET} \
    --name ${MEMBER_NAME} \
    --member-cluster-id ${MEMBER_CLUSTER_ID}
```  

### Relationship to Azure Arc-enabled Kubernetes

Fleet Manager supports both Azure-hosted AKS clusters and Azure Arc-enabled Kubernetes clusters as member clusters.

### Relationship to Azure Kubernetes Service clusters

Azure Kubernetes Service (AKS) simplifies deploying a managed Kubernetes cluster in Azure by offloading the operational overhead to Azure. As a hosted Kubernetes service, Azure handles critical tasks, like health monitoring and maintenance. Since the Kubernetes control plane is Azure-managed, you only maintain the agent nodes. You run your actual workloads on the AKS clusters.

Azure Kubernetes Fleet Manager helps you address at-scale and multi-cluster scenarios for Azure Kubernetes Service clusters. Azure Kubernetes Fleet Manager provides a group representation for your AKS clusters and helps users with orchestrating cluster updates, Kubernetes resource propagation, and multi-cluster load balancing. User workloads can't be run on the Fleet Manager hub cluster. 

### Can I provision new AKS clusters from Fleet Manager?

Creation and lifecycle management of new AKS clusters is on our roadmap. Provide [feedback](https://github.com/Azure/AKS/issues/3270) if support for cluster creation is an important scenario for you.

### Do I need to manage updates to the Fleet Manager hub cluster?

No. Fleet Manager's hub cluster is a Microsoft-managed resource. Microsoft automatically updates the hub cluster to the latest version of Kubernetes or node image as they become available.

If you attempt to update or modify the hub cluster (which is a single node AKS cluster named `hub`), a set of deny rules block your changes from being applied.

### Why did my Fleet Manager hub cluster transition from Failed to Running?

The Fleet Manager hub cluster is a Microsoft-managed AKS cluster created in your subscription. You don't need to take any action on the hub cluster.

If there's an issue in provisioning or operating the hub cluster, it can move to a `Failed` state.

Fleet Manager automatically reconciles the hub cluster as part of periodic standard service operations, which can move the hub cluster to a `Running` state.

When a hub cluster is `Failed` it doesn't generate a cost, but when it moves to `Running` a cost is generated. 

## Multi-cluster updates - automated or manual FAQs

### What clusters does multi-cluster updates support?

| Cluster type                    | Supported | Details        | Roadmap |
|---------------------------------|-----------|----------------|---------|
| AKS in Azure                    | ✅        | Full support.  |   -  |
| AKS Automatic                   | ⚠️        | Partially supported. You can't disable cluster-level auto-upgrade, so the cluster can update out of sequence. | [5811](https://github.com/Azure/AKS/issues/5811) |
| AKS with NAP                    | ⚠️        | Partially supported. Only Kubernetes control plane upgrades are supported. | [5812](https://github.com/Azure/AKS/issues/5812) |
| AKS connected clusters          | ❌        | Unsupported for AKS on bare metal, Edge Essentials, and Azure Local. | [5813](https://github.com/Azure/AKS/issues/5813) |
| Arc-enabled Kubernetes clusters | ❌        | Unsupported. | [5813](https://github.com/Azure/AKS/issues/5813) |

### What AKS update channels does Fleet Manager support?

Fleet Manager supports the following AKS update channels:

* **Rapid**: Updates for the most recent AKS-supported Kubernetes release (N).
* **Stable**: Updates for Kubernetes stable channel (N-1) where 'N' is the most recent AKS-supported Kubernetes release.
* **NodeImage**: Node image VHD patched (bug and security) with a weekly release schedule.
* **TargetKubernetesVersion (Kubernetes Patch)**: Upgrades clusters to the latest patch release of the specified target version when the patch is available. Supports Kubernetes minor versions that are available only via AKS Long-Term Support (LTS).
* **SecurityPatch (Linux node images)**: Node image OS updates that provide AKS-managed security patches applied to the existing VHD running on the node.

Currently unsupported AKS channels:

* **Unmanaged**: Node image OS updates applied directly through OS in-built patching (Linux nodes only). There are currently no plans for Fleet Manager to support this option.

### The target Kubernetes minor version in my auto-upgrade profile is out of community support. What can I do?

You can:

* Allow Long Term Support (LTS) in the auto-upgrade profile and enable it for any clusters in your fleet you wish to retain on the specific minor. Ensure that only LTS clusters are included in the update strategy you use.
* Update the auto-upgrade profile to a new target Kubernetes minor version. Clusters are updated to the most recent patch in the specified Kubernetes minor when released.

For information on enabling LTS in auto-upgrade profiles, see [Target Kubernetes version updates](./update-automation.md#target-kubernetes-minor-version-updates). For information on enabling LTS on managed clusters, see [Long Term Support](../aks/long-term-support.md).

> [!NOTE]
> To review detailed information if failures occur and to understand the specific actions to take, check the auto-upgrade profile status.

### What happens if I leave AKS cluster auto-upgrades enabled?

If you leave AKS cluster auto-upgrades enabled, either Fleet Manager or AKS cluster auto-upgrade performs the update, depending on which one runs first.

Fleet Manager doesn't change the configuration of AKS cluster auto-upgrade settings.

If you want Fleet Manager to manage auto-upgrades, disable auto-upgrade on each member AKS cluster.

### AKS cluster maintenance window support

A maintenance window defines when a cluster can safely be upgraded.

Fleet Manager respects the [per-cluster maintenance window settings][aks-maintenance-windows] for each member cluster.

When a maintenance window opens, upgrades don't start immediately. Reasons include:

* Concurrency limits: even if a maintenance window opens, a cluster might not be upgraded due to the concurrency settings for the strategy. 
* Regular polling: Fleet Manager polls for open maintenance windows every 60 minutes, so the maximum wait time is 60 minutes from window open.


### What is the scope of consistent node image upgrades?

Node consistency is only guaranteed for all clusters contained in a single [update run][update-run] where you choose the `consistent image` option.

There's no consistency guarantee for node image versions across separate update runs.

### How can I find out which node images were used in an update run?

The update run lists the selected node images used for the run. You can access this information even if the update run hasn't started.

More than one node image can be selected because different node pools operate across all clusters selected for update.

To find the images selected, use this Azure CLI command:

```azurecli
az fleet updaterun show \
    --resource-group ${GROUP} \
    --fleet-name ${FLEET} \
    --name ${UPDATE_RUN_NAME} \
    --query "status.nodeImageSelection.selectedNodeImageVersions"
```

You can also use the `View JSON` option in the Update Run Overview page in the Azure portal to view the raw data for an update run.

### My update run is in a pending state for quite some time. What should I do?

Fleet Manager update runs can be in a pending state for many reasons. You can view the status of an update run either via the Azure portal, or by following the [monitoring documentation](./howto-monitor-update-runs.md).

The two most common reasons for long pending states are:

* Member cluster maintenance windows: If a member cluster's maintenance window isn't open, the update run enters a paused state. This pause blocks completion of the update group or stage until the next maintenance window opens. To continue the update run, manually skip the cluster. If you skip the cluster, it's out of sync with the rest of the member clusters in the update run.

* Kubernetes or node image version not in Azure region: If the new Kubernetes or node image version isn't published to the Azure region in which a member clusters exists, the update run enters a pending state. You can check the [AKS release tracker](https://releases.aks.azure.com/) to see the regional status of the version. While you can skip the member cluster, if there are other clusters in the same Azure region they also can't update.

### My auto-upgrade run started, then immediately entered a pending state. Why?

See the previous question.

### I tried generating an update run from my auto-upgrade profile, but I can't see the update run.

When you manually [generate an update run from an auto-upgrade profile](./update-orchestration.md#generate-an-update-run-from-an-auto-upgrade-profile), the resulting update run might already exist.

This scenario can arise if the auto-upgrade profile automatically generated the update run, or if the update run was previously manually generated.

The name of the generated update run is based on the auto-upgrade profile's upgrade specification which only changes when properties such as node image or Kubernetes version are updated.

You most commonly see this issue in the Azure portal where the existing update run isn't the most recent update run. If you run into this issue and can't find the update run, use the Azure CLI to generate the run to view the update run name. Microsoft plans to fix this issue in the Azure portal in future.

If you generate an update run and it exists, the existing update run isn't modified.
 
### Editing my update strategy didn't change the existing update runs that used it. Why not?

When you create an update run, the strategy is copied to the update run so that changes to the strategy don't affect executing update runs.

### How do I prevent a single cluster failure from stopping my entire update run?

Use the `maxAllowedFailures` setting on your update strategy stages and groups (available starting with API version 2026-06-02-preview). This setting lets you specify how many member cluster failures are tolerated before the group or stage is marked as failed. Values can be a fixed integer (for example, `"3"`) or a percentage (for example, `"25%"`). When unset or `"0"`, a single failure stops the entire run.

For more information, see [Maximum allowed failures (preview)](./concepts-update-orchestration.md#maximum-allowed-failures-preview).

### Why does my update run or group show Completed even though members failed?

When you set `maxAllowedFailures`, Fleet Manager evaluates only the number of failed member updates. It doesn't enforce a minimum success rate. An update run, stage, or group can therefore end in `Completed` even if some or all members failed, as long as the configured threshold isn't exceeded when Fleet Manager makes its scheduling decisions.

This outcome is expected and intentional, not a bug. Always inspect `FailureCount`, member-level statuses, and failure reasons before you treat the rollout as healthy. For most update strategies, percentage-based thresholds are easier to reason about than absolute values.

### What rules and limitations should I know when using maxAllowedFailures?

Keep the following rules in mind:

- The feature is available starting with API version 2026-06-02-preview.
- When you unset `maxAllowedFailures` or set it to `"0"`, Fleet Manager uses fail-fast behavior and stops after the first failed member update.
- The threshold is evaluated against failure count only. It doesn't enforce a minimum success rate.
- A run, stage, or group can show `Completed` even when failures occur, as long as the configured threshold isn't exceeded.
- `FailureCount` can be greater than `maxAllowedFailures` when updates run in parallel, because multiple member updates might fail before Fleet Manager stops scheduling more work.
- Stage-level and group-level thresholds are evaluated independently, and stage-level failures aggregate across all groups in the stage.
- For most rollouts, percentage-based thresholds are easier to reason about and scale better than fixed numbers, especially in small groups.

### Can I preapprove an approval?

No. You can approve an upgrade only after you verify that the member clusters are ready for upgrade or that the upgrade is completed successfully. If you want to preapprove, consider not configuring an approval in your strategy at all.

### Do approvals expire?

No, approvals wait until they're approved. You can't configure a time window for approvals.

### Can I skip an approval?

If you want to skip the member cluster upgrades together with the gating approval, skip the encompassing group or stage. If you want to proceed with the upgrades, you must grant the approval.

### How do I delete an approval?

As in the previous question, if you want to proceed with an upgrade, you must grant the approval. If you're trying to clean up the underlying gate resource, you must delete the associated update run, which deletes all gates linked to the update run.

### Can I configure an after-stage approval together with an after-stage wait?

Yes. The after-stage wait begins at the same time as the approval. Both must be completed before the update run continues.

### Can I add approvals to existing update strategies?

Yes. You can edit the existing strategy to include approvals. However, existing update runs that you created by using the strategy aren't updated.

### How do scheduled start gates interact with AKS cluster maintenance windows?

Scheduled start gates and AKS cluster [planned maintenance windows](/azure/aks/planned-maintenance) are independent controls. Both conditions must be met before a cluster starts upgrading. For example, if a scheduled start gate completes at 2:00 AM but a cluster's maintenance window doesn't open until 6:00 AM, the cluster waits until 6:00 AM to begin its upgrade.

### How can I control the order of cluster updates in an update run?

Member labels and update groups are two different ways to select which clusters are included in each stage and group of your update strategy. Each member cluster can be assigned to one update group but can have multiple labels. Member labels (using `memberSelector`) offer more flexibility and support complex selection scenarios, so they're the recommended way to select fleet members for update strategies. For more information, see [Group clusters using member labels](./concepts-update-orchestration.md#group-clusters-using-member-labels-preview).

### Do I need to specify groups if I set a member selector at the stage level?

No. When you set `memberSelector` on a stage without defining any groups, all matching clusters are treated as a single group. The stage's `maxConcurrency` controls how many clusters upgrade concurrently. You only need to define groups within a stage if you want to partition the matching members into parallel subsets with different concurrency settings.

### What happens to update groups if I set a member selector at the group level?

If you set a `memberSelector` at the group level, the group's `name` field is used only as a display identifier for status reporting and logging. The `memberSelector` takes precedence over the update group name when selecting clusters for the group.

## Cluster resource placement FAQs

### Can I select resources inside a namespace for propagation?

Yes. Fleet Manager supports both cluster-scoped and namespace-scoped resource placement:

* **ClusterResourcePlacement**: Propagates cluster-scoped resources and entire namespaces (including all their contents) to member clusters. For more information, see [Using ClusterResourcePlacement to deploy cluster-scoped resources](./concepts-resource-placement.md).
* **ResourcePlacement**: Provides fine-grained control to select and propagate specific namespace-scoped resources (such as ConfigMaps, Secrets, Deployments) within a namespace. For more information, see [Using ResourcePlacement to deploy namespace-scoped resources](./concepts-namespace-scoped-resource-propagation.md).

## Roadmap

The Azure Kubernetes Fleet Manager roadmap is available [on GitHub](https://aka.ms/kubernetes-fleet/roadmap). The team welcomes feature requests, questions, and bug reports.

## Next steps

* [Create a fleet and join member clusters](./quickstart-create-fleet-and-members.md).
* [Troubleshooting guides for Fleet Manager](/troubleshoot/azure/kubernetes-fleet/welcome-azure-kubernetes-fleet).

<!-- INTERNAL LINKS -->
[update-run]: ./concepts-update-orchestration.md#understanding-update-runs
[aks-maintenance-windows]: /azure/aks/planned-maintenance
