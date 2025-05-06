---
title: "Frequently asked questions - Azure Kubernetes Fleet Manager"
description: This article covers the frequently asked questions for Azure Kubernetes Fleet Manager
ms.date: 10/03/2022
author: shashankbarsin
ms.author: shasb
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
---

# Frequently Asked Questions - Azure Kubernetes Fleet Manager

This article covers the frequently asked questions for Azure Kubernetes Fleet Manager.

## Relationship to Azure Kubernetes Service clusters

Azure Kubernetes Service (AKS) simplifies deploying a managed Kubernetes cluster in Azure by offloading the operational overhead to Azure. As a hosted Kubernetes service, Azure handles critical tasks, like health monitoring and maintenance. Since the Kubernetes control plane is managed by Azure, you only manage and maintain the agent nodes. You run your actual workloads on the AKS clusters.

Azure Kubernetes Fleet Manager (Fleet) will help you address at-scale and multi-cluster scenarios for Azure Kubernetes Service clusters. Azure Kubernetes Fleet Manager provides a group representation for your AKS clusters and helps users with orchestrating cluster updates, Kubernetes resource propagation and multi-cluster load balancing. User workloads can't be run on the fleet cluster itself. 

## Creation of AKS clusters from fleet resource

Today, Azure Kubernetes Fleet Manager supports joining existing AKS clusters as fleet members. Creation and lifecycle management of new AKS clusters from fleet cluster is in the [roadmap](https://aka.ms/fleet/roadmap).

## Number of clusters

Fleets support joining up to 100 AKS clusters, regardless of whether they have a hub cluster or not.

## AKS clusters that can be joined as members

Fleet supports joining the following types of AKS clusters as member clusters:

* AKS clusters across same or different resource groups within same subscription
* AKS clusters across different subscriptions of the same Microsoft Entra tenant
* AKS clusters from different regions but within the same tenant

## Relationship to Azure-Arc enabled Kubernetes

Today, Azure Kubernetes Fleet Manager supports joining AKS clusters as member clusters. Support for joining member clusters to the fleet resource is in the [roadmap](https://aka.ms/fleet/roadmap).

## Regional or global

Azure Kubernetes Fleet Manager resource is a regional resource. Support for region failover for disaster recovery use cases is in the [roadmap](https://aka.ms/fleet/roadmap).

## What happens when the user changes the cluster identity of a joined cluster?
Changing the identity of a member AKS cluster will break the communication between fleet and that member cluster. While the member agent will use the new identity to communicate with the fleet cluster, fleet still needs to be made aware of this new identity. To achieve this, run the following command:

```azurecli
az fleet member create \
    --resource-group ${GROUP} \
    --fleet-name ${FLEET} \
    --name ${MEMBER_NAME} \
    --member-cluster-id ${MEMBER_CLUSTER_ID}
```  

## Roadmap

The roadmap for Azure Kubernetes Fleet Manager resource is available [here](https://aka.ms/fleet/roadmap).

## Next steps

* [Create a fleet and join member clusters](./quickstart-create-fleet-and-members.md).