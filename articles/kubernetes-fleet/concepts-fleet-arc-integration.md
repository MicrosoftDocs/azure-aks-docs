---
title: "Azure Kubernetes Fleet Manager with Arc-enabled Kubernetes clusters"
description: This article provides a conceptual overview of Azure Kubernetes Fleet Manager integration with Azure Arc-enabled Kubernetes clusters.
ms.date: 06/25/2026
author: ealianis
ms.author: sehobbs
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: "As a platform administrator managing hybrid and multicloud Kubernetes infrastructure, I want to understand how Azure Kubernetes Fleet Manager integrates with Arc-enabled Kubernetes clusters, so that I can centrally manage my entire fleet regardless of where clusters are running."
---

# Azure Kubernetes Fleet Manager with Arc-enabled Kubernetes clusters

**Applies to:** :heavy_check_mark: Fleet Manager :heavy_check_mark: Fleet Manager with hub cluster

This article provides a conceptual overview of how Azure Kubernetes Fleet Manager integrates with Azure Arc-enabled Kubernetes clusters to enable unified multicluster management across hybrid and multicloud environments.

If you're unfamiliar with Azure Kubernetes Fleet Manager, start with the [Azure Kubernetes Fleet Manager overview](./overview.md).

## What does the integration solve?

The integration between Azure Kubernetes Fleet Manager and Azure Arc-enabled Kubernetes clusters extends centralized multicluster resource management beyond Azure-native AKS clusters, including many of the most popular Kubernetes distributions running anywhere:

- **Supported distributions**: [AKS on bare metal][aks-bare-metal] (preview), EKS (Amazon Elastic Kubernetes Service), GKE (Google Kubernetes Engine), K3s (Lightweight Kubernetes), OCP (Red Hat OpenShift), and Rancher (RKE).

## Key benefits and capabilities

Azure Kubernetes Fleet Manager integration with Arc-enabled Kubernetes clusters enables unified, intelligent, policy-driven multicluster resource management across hybrid and multicloud environments.

### Centralized policy-driven fleet governance

Azure Kubernetes Fleet Manager uses a hub-spoke architecture that creates a single control plane for the fleet. It enables fleet administrators to apply uniform cloud native policies on every member cluster, whether they reside in public clouds, private data centers, or edge locations. The hub-spoke architecture greatly simplifies governance across large, geographically distributed fleets spanning hybrid and multicloud environments.

### Progressive resource rollouts with safeguards

Azure Kubernetes Fleet Manager provides a cloud native progressive rollout by using [staged update runs](./concepts-rollout-strategy.md). The application owner can stop a rollout or roll back to previous versions when they observe failures, limiting the blast radius. Progressive rollouts keep multicluster application deployments reliable and predictable spanning edge, on-premises, and cloud environments.

### Powerful multicluster scheduling

Azure Kubernetes Fleet Manager scheduler evaluates member cluster properties, available capacity, and declarative placement policies to select optimal destinations for workloads. It supports cluster affinity and anti-affinity rules, topology spread constraints to distribute workloads across failure domains, and resource-based placement to ensure sufficient compute, memory, and storage. The scheduler continuously reconciles as fleet conditions change, automatically adapting to cluster additions, removals, or capacity shifts across edge, on-premises, and cloud environments. For more details on the various scheduling capabilities, see the multicluster workload management section.

## Supported capabilities, prerequisites, and considerations

Before adding Arc-enabled Kubernetes clusters to Fleet Manager, review the important considerations noted in the [member cluster types documentation](./concepts-member-cluster-types.md).

## Architecture overview

The Fleet Manager and Azure Arc integration uses the same hub-and-spoke architecture as AKS clusters:

When you join an Arc-enabled Kubernetes cluster to a Fleet Manager, you install the Fleet Manager Arc extension on your Arc-enabled Kubernetes cluster. This extension deploys the Fleet's member agents onto your underlying cluster. These agents communicate directly with the Fleet's hub cluster. 

**Key components:**

- **Hub cluster**: Centralized control plane for managing the entire fleet.
- **Fleet extension**: Deployed to Arc-enabled clusters to enable Fleet Manager integration via the Fleet Arc Extension.
- **Member cluster representation**: Arc-enabled clusters appear as `MemberCluster` resources in the hub.

### Fleet extension resource requirements

When you add an Arc-enabled Kubernetes cluster to Fleet Manager, you deploy an extension that has these requirements:

- At least **210 MB** memory and **2%** of one CPU core available.
- The cluster reserves **3 pods** for the Azure Kubernetes Fleet Manager Arc extension agents.
- The **fleet-system** namespace is created for Fleet-related components and you shouldn't directly modify it.

## Getting started 

To begin using Fleet Manager with Arc-enabled Kubernetes clusters:

1. **Connect clusters to Azure Arc**: Connect your Kubernetes clusters to Azure Arc. For instructions, see [Connect an existing Kubernetes cluster to Azure Arc](/azure/azure-arc/kubernetes/quickstart-connect-cluster).
1. **Create or upgrade your fleet**: Create or upgrade a fleet resource with a hub cluster, and then join your Arc-enabled clusters. For instructions, see [Create a fleet and join member clusters](./quickstart-create-fleet-and-members.md).
1. **Configure workload placement**: Create `ClusterResourcePlacement` resources for your applications. For guidance, see [Kubernetes resource propagation concepts](./concepts-resource-placement.md).

## Public region limitation

Fleet Manager support for Arc-enabled Kubernetes clusters is currently available only in Azure public cloud regions.

If you attempt to create an Arc-enabled member cluster in a non-public cloud region, the operation returns an error of type `FeatureNotAvailableInCloud` with the message `The feature 'Arc Member Cluster' is not available in cloud environment`.

When Azure Arc Gateway is available in Azure non-public cloud regions, Microsoft removes the restriction.

You can track the status of Azure Arc Gateway via its [official documentation][azure-arc-gateway].

<!-- LINKS -->
[azure-arc-gateway]: /azure/azure-arc/kubernetes/arc-gateway-simplify-networking
[aks-bare-metal]: https://aka.ms/aks-edge-baremetal