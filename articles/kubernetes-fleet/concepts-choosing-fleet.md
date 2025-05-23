---
title: "Choose an Azure Kubernetes Fleet Manager option"
description: This article provides a conceptual overview of the various Azure Kubernetes Fleet Manager options and why you may choose a specific configuration.
ms.date: 05/23/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
---

# Choosing an Azure Kubernetes Fleet Manager option

This article provides an overview of the various Azure Kubernetes Fleet Manager options and the considerations you should use to guide your selection of a specific configuration.

## Fleet types

A Fleet Manager resource can be created with or without a hub cluster. A hub cluster is a managed Azure Kubernetes Service (AKS) cluster that acts as a hub to stage Kubernetes resources ready for placement. 

Let's compares the scenarios enabled by the using a hub cluster.

| Capability | Fleet Manager without hub cluster | Fleet Manager with hub cluster |
|----|----|----|
|**Hub cluster hosting**| <span class='red-x'>&#10060;</span> |<span class='green-check'>&#9989;</span> |
|**Kubernetes and node image updates**| <span class='green-check'>&#9989;</span> | <span class='green-check'>&#9989;</span> |
|**Workload placement**| <span class='red-x'>&#10060;</span> | <span class='green-check'>&#9989;</span> |
|**DNS load balancing**| <span class='red-x'>&#10060;</span> | <span class='green-check'>&#9989;</span> |
|**Billing considerations**| No cost | You pay cost associated with the hub, which is a single node standard-tier AKS-cluster. |
|**Converting fleet types**| Can upgrade to a Fleet Manager with a hub cluster. | Can't be downgraded to a Fleet Manager resource without a hub cluster.|

## Fleet Manager without hub cluster

Without a hub cluster, Fleet Manager acts solely as a grouping entity in Azure Resource Manager (ARM). Certain features, such as Kubernetes and node image update runs and auto-upgrades, don't require a Kubernetes API and thus don't require a hub cluster. To take full advantage of all the features available, you need a Fleet Manager with a hub cluster.

For more information, see [Create a Kubernetes Fleet resource without a hub cluster][create-fleet-without-hub].

## Fleet Manager with hub cluster

A Fleet Manager with a hub cluster has an associated AKS-managed cluster, which hosts the open source [KubeFleet][fleet-github] solution for workload placement and the [fleet network manager][fleet-networking-github] for network management and load balancing.

Upon the creation of a Fleet Manager with a hub cluster, a hub AKS cluster is automatically created in the same Azure subscription under a managed resource group that begins with `FL_`. To improve reliability, hub clusters are deny any user-initiated mutations to the corresponding AKS cluster (under the Fleet-managed resource group `FL_`) and their underlying Azure resources (under the AKS-managed resource group `MC_FL_*`), such as virtual machines (VMs). 

Control plane operations, such as changing the hub cluster's configuration through Azure Resource Manager (ARM) or deleting the cluster entirely, are denied. Data plane operations, such as connecting to the hub cluster's Kubernetes API server in order to configure workload placement, are allowed.

Hub clusters are exempted from [Azure policies][azure-policy-overview] to avoid undesirable policy effects.

### Network access modes for hub cluster

For a Fleet Manager with a hub cluster, there are two network access modes:

- **Public hub clusters** expose the hub cluster to the internet. This means that with the right credentials, anyone on the internet can connect to the hub cluster. This configuration can be useful during the development and testing phase, but represents a security concern, which is largely undesirable in production.

For more information, see [Create a Kubernetes Fleet resource with a public hub cluster][create-public-hub-cluster].

- **Private hub clusters** use a [private AKS cluster][aks-private-cluster] as the hub, which prevents open access over the internet. All considerations for a private AKS cluster apply, so review the prerequisites and limitations to determine whether a Fleet Manager with a private hub cluster meets your needs.

Some other details to consider:

- Whether you choose a public or private hub, the type can't be changed after creation.
- When using an AKS private cluster, you have the ability to configure fully qualified domain names (FQDNs) and FQDN subdomains. This functionality doesn't apply to the private hub cluster of the Fleet Manager.
- When you connect to a private hub cluster, you can use the same methods that you would use to [connect to any private AKS cluster][aks-private-cluster-connect]. However, connecting using AKS command invoke and private endpoints aren't currently supported.
- When you use private hub clusters, you're required to specify the subnet in which the Fleet Manager hub cluster's node VMs reside. This process differs slightly from the AKS private cluster equivalent. For more information, see [create a Fleet Manager with a private hub cluster][create-private-hub-cluster].


## Next steps

Now that you understand the different types of Kubernetes fleet resources, see [Create an Azure Kubernetes Fleet Manager resource and join member clusters][quickstart-create-fleet].

<!-- LINKS -->
[aks-private-cluster]: /azure/aks/private-clusters
[aks-private-cluster-connect]: /azure/aks/private-clusters?tabs=azure-portal#options-for-connecting-to-the-private-cluster
[azure-policy-overview]: /azure/governance/policy/overview
[quickstart-create-fleet]: quickstart-create-fleet-and-members.md
[create-fleet-without-hub]: quickstart-create-fleet-and-members.md?tabs=without-hub-cluster#create-a-fleet-manager-resource
[create-public-hub-cluster]: quickstart-create-fleet-and-members.md?tabs=with-hub-cluster#public-hub-cluster
[create-private-hub-cluster]: quickstart-create-fleet-and-members.md?tabs=with-hub-cluster#private-hub-cluster

<!-- LINKS - external -->
[fleet-github]: https://kubefleet-dev.github.io/website/docs/
[fleet-networking-github]: https://github.com/Azure/fleet-networking