---
title: "Frequently asked questions - Azure Kubernetes Fleet Manager"
description: This article covers the frequently asked questions for Azure Kubernetes Fleet Manager
ms.date: 06/19/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: As a cloud administrator, I want to manage multiple Azure Kubernetes Service clusters through a centralized fleet, so that I can streamline updates, resource propagation, and load balancing across various clusters.
---

# Frequently Asked Questions - Azure Kubernetes Fleet Manager

This article covers the frequently asked questions for Azure Kubernetes Fleet Manager.

## Fleet Manager service FAQs

### Is Fleet Manager a regional or global resource?

Fleet Manager is a regional resource. Support for region failover for disaster recovery use cases is on the [roadmap](https://github.com/Azure/AKS/issues/3268).

### How many clusters can I join to Fleet Manager?

Fleet Manager (with or without a hub cluster) supports joining up to 100 AKS clusters.

If you would like Fleet Manager to support more than 100 clusters, [add feedback](https://github.com/Azure/AKS/issues/5066).

### What AKS clusters can be joined as members?

Fleet Manager allows appropriately authorized users to add any AKS cluster in any Azure subscription and region as long as the Azure subscription is associated with the same Microsoft Entra ID tenant as the Fleet Manager. 

### Does Fleet Manager support managed identities?

Yes, Fleet Manager supports both system-assigned and user-assigned managed identities. For more information, see the documentation on [using managed identities with Fleet Manager](./use-managed-identity.md).

### What happens when the cluster identity of a joined cluster is changed?

Changing the identity of a member cluster breaks the communication between Fleet Manager and that member cluster. While the member agent uses the new identity to communicate with the Fleet Manager, Fleet Manager still needs to be made aware of the new identity. Run this command to resolve:

```azurecli
az fleet member create \
    --resource-group ${GROUP} \
    --fleet-name ${FLEET} \
    --name ${MEMBER_NAME} \
    --member-cluster-id ${MEMBER_CLUSTER_ID}
```  

### Relationship to Azure Arc-enabled Kubernetes

Fleet Manager supports joining only AKS clusters as member clusters. 

Support for joining non-AKS clusters is on our roadmap. Provide [feedback](https://github.com/Azure/AKS/issues/3410) if support for non-AKS clusters is important for you.

### Relationship to Azure Kubernetes Service clusters

Azure Kubernetes Service (AKS) simplifies deploying a managed Kubernetes cluster in Azure by offloading the operational overhead to Azure. As a hosted Kubernetes service, Azure handles critical tasks, like health monitoring and maintenance. Since the Kubernetes control plane is Azure-managed, you only maintain the agent nodes. You run your actual workloads on the AKS clusters.

Azure Kubernetes Fleet Manager helps you address at-scale and multi-cluster scenarios for Azure Kubernetes Service clusters. Azure Kubernetes Fleet Manager provides a group representation for your AKS clusters and helps users with orchestrating cluster updates, Kubernetes resource propagation, and multi-cluster load balancing. User workloads can't be run on the Fleet Manager hub cluster. 

### Can I provision new AKS clusters from Fleet Manager?

Creation and lifecycle management of new AKS clusters is on our roadmap. Provide [feedback](https://github.com/Azure/AKS/issues/3270) if support for cluster creation is an important scenario for you.

### Do I need to manage updates to the Fleet Manager hub cluster?

No. Fleet Manager's hub cluster is a Microsoft-managed resource. Microsoft automatically updates the hub cluster to the latest version of Kubernetes or node image as they become available.

If you attempt to update or modify the hub cluster (which is a single node AKS cluster named `hub`), a set of deny rules will block your changes from being applied.

## Multi-cluster updates - automated or manual FAQs

### What AKS update channels does Fleet Manager support?

Supported AKS update channels:

* **Rapid**: Updates for the most recent AKS-supported Kubernetes release (N).
* **Stable**: Updates for Kubernetes stable channel (N-1) where 'N' is the most recent AKS-supported Kubernetes release.
* **NodeImage**: node image VHD patched (bug and security) with a weekly release schedule.

Currently unsupported AKS channels:

* **Patch**: Updates for Kubernetes patch releases (y) for a specified AKS-supported Kubernetes minor (N) release (1.N.y).
* **SecurityPatch**: node image OS updates that provide AKS-managed security patches applied to the existing VHD running on the node.
* **Unmanaged**: node image OS updates applied directly through OS in-built patching (Linux nodes only).

If you're using any of the channels that Fleet Manager doesn't support, it's recommended you leave those channels enabled on your AKS clusters.

### What happens if I leave AKS cluster auto-upgrades enabled?

If you leave AKS cluster auto-upgrades enabled, then the update of that cluster could be performed by Fleet Manager or AKS cluster auto-upgrade, depending on which one runs first.

Fleet Manager doesn't alter the configuration of AKS cluster auto-upgrade settings. If you want Fleet Manager to manage auto-upgrades, you must disable auto-upgrade on each individual member AKS cluster.

### Maintenance window support

Fleet Manager honors the per-cluster maintenance window settings for each member cluster.

### What is the scope of consistent node image upgrades?

If you want all member clusters to use the same node image, then all member clusters must be in the same [update run][update-run] with the `consistent image` option selected. 

There's no consistency guarantee for node image versions across separate update runs.

### My update run has been in a pending state for quite some time. What should I do?

Fleet Manager update runs can be in a pending state for a number of reasons. You can view the status of an update run either via the Azure portal, or by following our [monitoring documentation](./howto-monitor-update-runs.md).

The two most common reasons for long pending states are:

* Member cluster maintenance windows: If a member cluster's maintenance window isn't open then the update run can enter a paused state. This pause can block completion of the update group or stage until the next maintenance window opens. If you wish to continue the update run, manually skip the cluster. If you skip the cluster, it will be out of sync with the rest of the member clusters in the update run.

* Kubernetes or node image version not in Azure region: If the new Kubernetes or node image version isn't published to the Azure region in which a member clusters exists, then the update run can enter a pending state. You can check the [AKS release tracker](https://releases.aks.azure.com/) to see the regional status of the version. While you can skip the member cluster, if there are other clusters in the same Azure region they'll also be unable to update.

### My auto-upgrade run started, then immediately entered a pending state. Why?

See the previous question.

## Cluster resource placement FAQs

### Can I select resources inside a namespace for propagation?

Fleet Manager only currently supports propagating resources at the cluster and namespace level. You can't select individual resources inside a namespace for propagation.

Provide [feedback](https://github.com/Azure/AKS/issues/5067) if support for intra-namespace resource placement is important for you.

## Automated Deployments FAQs

### How does this compare to AKS Automated Deployments?

AKS Automated Deployments supports only a single AKS cluster where the deployed workload runs. Fleet Manager's Automated Deployments stages the workload definitions on the Fleet Manager hub cluster, making them available for propagation to member clusters via [cluster resource placement](./concepts-resource-propagation.md). 

Fleet Manager Automated Deployments also requires the use of an existing Azure Container Registry (ACR) and Fleet Manager hub cluster namespace.

### Can I connect to the same Git repository multiple times?

Yes, you can connect to the same repository multiple times to allow you to deploy different resource or branches from the same repository.

## Roadmap

The roadmap for Azure Kubernetes Fleet Manager resource is available [on GitHub](https://aka.ms/kubernetes-fleet/roadmap).

## Next steps

* [Create a fleet and join member clusters](./quickstart-create-fleet-and-members.md).
* [Troubleshooting guides for Fleet Manager](/troubleshoot/azure/kubernetes-fleet/welcome-azure-kubernetes-fleet).

<!-- INTERNAL LINKS -->
[update-run]: ./concepts-update-orchestration.md#understanding-update-runs