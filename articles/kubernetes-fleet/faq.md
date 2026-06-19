---
title: "Frequently asked questions - Azure Kubernetes Fleet Manager"
description: This article covers the frequently asked questions for Azure Kubernetes Fleet Manager
ms.date: 06/19/2026
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

Fleet Manager supports both Azure-hosted AKS clusters and Arc-enabled Kubernetes clusters as member clusters.

### Relationship to Azure Kubernetes Service clusters

Azure Kubernetes Service (AKS) simplifies deploying a managed Kubernetes cluster in Azure by offloading the operational overhead to Azure. As a hosted Kubernetes service, Azure handles critical tasks, like health monitoring and maintenance. Since the Kubernetes control plane is Azure-managed, you only maintain the agent nodes. You run your actual workloads on the AKS clusters.

Azure Kubernetes Fleet Manager helps you address at-scale and multi-cluster scenarios for Azure Kubernetes Service clusters. Azure Kubernetes Fleet Manager provides a group representation for your AKS clusters and helps users with orchestrating cluster updates, Kubernetes resource propagation, and multi-cluster load balancing. User workloads can't be run on the Fleet Manager hub cluster. 

### Can I provision new AKS clusters from Fleet Manager?

Creation and lifecycle management of new AKS clusters is on our roadmap. Provide [feedback](https://github.com/Azure/AKS/issues/3270) if support for cluster creation is an important scenario for you.

### Do I need to manage updates to the Fleet Manager hub cluster?

No. Fleet Manager's hub cluster is a Microsoft-managed resource. Microsoft automatically updates the hub cluster to the latest version of Kubernetes or node image as they become available.

If you attempt to update or modify the hub cluster (which is a single node AKS cluster named `hub`), a set of deny rules block your changes from being applied.

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
* **NodeSecurityPatch (preview)**: Node image OS updates that provide AKS-managed security patches applied to the existing VHD running on the node.

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

### AKS Cluster maintenance window support

Fleet Manager respects the per-cluster maintenance window settings for each member cluster.

Maintenance windows don't trigger updates, and updates don't begin immediately when a window opens. Maintenance windows only define when updates can be applied to a cluster.

For more information, see the documentation for [AKS cluster maintenance windows][aks-maintenance-windows].

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

### Editing my update strategy didn't change the existing update runs that used it. Why not?

When you create an update run, the strategy is copied to the update run so that changes to the strategy don't affect executing update runs.

### Can I preapprove an approval?

No. You can approve an upgrade only after you verify that the member clusters are ready for upgrade or that the upgrade is completed successfully. If you want to preapprove, consider not configuring an approval in your strategy at all.

### Do approvals expire?

No, approvals wait until they're approved. You can't configure a time window for approvals.

### Can I skip an approval?

If you want to skip the member cluster upgrades together with the gating approval, skip the encompassing group or stage. If you want to proceed with the upgrades, you must grant the approval.

### How do I delete an approval?

As in the previous question, if you want to proceed with an upgrade, you must grant the approval. If you're trying to clean up the underlying gate resource, you must delete the associated update run, which deletes all gates linked to the update run.

### Can I configure an after stage approval together with an after stage wait?

Yes. The after stage wait begins at the same time as the approval. Both must be completed before the update run continues.

### Can approvals be added to existing update strategies?

Yes. You can edit the existing strategy to include approvals. However, existing update runs that you created by using the strategy aren't updated.

## Cluster resource placement FAQs

### Can I select resources inside a namespace for propagation?

Yes. Fleet Manager supports both cluster-scoped and namespace-scoped resource placement:

* **ClusterResourcePlacement**: Propagates cluster-scoped resources and entire namespaces (including all their contents) to member clusters. For more information, see [Using ClusterResourcePlacement to deploy cluster-scoped resources](./concepts-resource-placement.md).
* **ResourcePlacement**: Provides fine-grained control to select and propagate specific namespace-scoped resources (such as ConfigMaps, Secrets, Deployments) within a namespace. For more information, see [Using ResourcePlacement to deploy namespace-scoped resources](./concepts-namespace-scoped-resource-propagation.md).

## Automated Deployments FAQs

### How does this compare to AKS Automated Deployments?

AKS Automated Deployments supports only a single AKS cluster where the deployed workload runs. Fleet Manager's Automated Deployments stages the workload definitions on the Fleet Manager hub cluster, making them available for propagation to member clusters via [cluster resource placement](./concepts-resource-placement.md). 

Fleet Manager Automated Deployments also requires the use of an existing Azure Container Registry (ACR) and Fleet Manager hub cluster namespace.

### Can I connect to the same Git repository multiple times?

Yes, you can connect to the same repository multiple times to deploy different resources or branches from the same repository.

## Roadmap

The roadmap for Azure Kubernetes Fleet Manager resource is available [on GitHub](https://aka.ms/kubernetes-fleet/roadmap).

## Next steps

* [Create a fleet and join member clusters](./quickstart-create-fleet-and-members.md).
* [Troubleshooting guides for Fleet Manager](/troubleshoot/azure/kubernetes-fleet/welcome-azure-kubernetes-fleet).

<!-- INTERNAL LINKS -->
[update-run]: ./concepts-update-orchestration.md#understanding-update-runs
[aks-maintenance-windows]: /azure/aks/planned-maintenance
