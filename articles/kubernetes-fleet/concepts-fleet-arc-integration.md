---
title: "Azure Kubernetes Fleet Manager with Arc-enabled Kubernetes clusters"
description: This article provides a conceptual overview of Azure Kubernetes Fleet Manager integration with Azure Arc-enabled Kubernetes clusters.
ms.date: 10/16/2025
author: sehobbs
ms.author: sehobbs
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: "As a platform administrator managing hybrid and multi-cloud Kubernetes infrastructure, I want to understand how Azure Kubernetes Fleet Manager integrates with Arc-enabled Kubernetes clusters, so that I can centrally manage my entire fleet regardless of where clusters are running."
---

# Azure Kubernetes Fleet Manager with Arc-enabled Kubernetes clusters

This article provides a conceptual overview of how Azure Kubernetes Fleet Manager integrates with Azure Arc-enabled Kubernetes clusters to enable unified multi-cluster management across hybrid and multi-cloud environments.

If you are unfamiliar with Azure Kubernetes Fleet Manager, start with the [Azure Kubernetes Fleet Manager overview](./concepts-fleet-manager-overview.md).

> [!IMPORTANT]
> Azure Kubernetes Fleet Manager's support for Arc-enabled Kubernetes clusters is currently in public preview.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## What does the integration solve?

The integration between Azure Kubernetes Fleet Manager and Azure Arc-enabled Kubernetes clusters extends centralized multi-cluster resource management beyond Azure-native AKS clusters, including many of the most popular Kubernetes distributions running anywhere:

- **Supported distributions**: AKS (Azure Kubernetes Service), K3s (Lightweight Kubernetes), OCP (Red Hat OpenShift), EKS (Amazon Elastic Kubernetes Service), GKE (Google Kubernetes Engine), and Rancher (RKE).

## Key benefits and capabilities

Azure Kubernetes Fleet Manager integration with Arc-enabled Kubernetes clusters enables unified, intelligent, policy-driven multi-cluster resource management across hybrid and multi-cloud environments.

### Centralized policy-driven fleet governance

Azure Kubernetes Fleet Manager utilizes a hub-spoke architecture that creates a single control plane for the fleet. It allows fleet administrators to apply uniform cloud native policies on every member cluster, whether they reside in public clouds, private data centers, or edge locations. This greatly simplifies governance across large, geographically distributed fleets spanning hybrid and multi-cloud environments.

### Progressive Rollouts with Safeguards

Azure Kubernetes Fleet Manager provides a cloud native progressive rollout plans sequence updates across the entire fleet with health verification at each step. The application owner can stop a rollout or rollback to any previous versions when they observe failures, limiting blast radius. This keeps multi-cluster application deployments reliable and predictable spanning edge, on-premises, and cloud environments.

### Powerful Multi-Cluster Scheduling

Azure Kubernetes Fleet Manager scheduler evaluates member cluster properties, available capacity, and declarative placement policies to select optimal destinations for workloads. It supports cluster affinity and anti-affinity rules, topology spread constraints to distribute workloads across failure domains, and resource-based placement to ensure sufficient compute, memory, and storage. The scheduler continuously reconciles as fleet conditions change, automatically adapting to cluster additions, removals, or capacity shifts across edge, on-premises, and cloud environments. For more details on the various scheduling capabilities, please see the multi-cluster workload management section.

## Supported capabilities, prerequisites and considerations

Before integrating Arc-enabled Kubernetes clusters with Fleet Manager, review these important considerations
noted within the [member cluster types documentation](./concepts-member-cluster-types.md).

## Architecture overview

The Fleet Manager and Arc integration follows the same hub-and-spoke architecture used for AKS clusters:

When you join an Arc-enabled Kubernetes cluster to a Fleet, the Fleet Arc Extension is installed on your Arc-Enabled Kubernetes cluster, deploying the Fleet's member agents onto your underlying cluster. These agents will communicate directly with the Fleet's hub cluster. 

**Key components:**

- **Hub cluster**: Centralized control plane for managing the entire fleet
- **Fleet extension**: Deployed to Arc-enabled clusters to enable Fleet Manager integration via the Fleet Arc Extension.
- **Member cluster representation**: Arc-enabled clusters appear as `MemberCluster` resources in the hub

## Getting started 

To begin using Fleet Manager with Arc-enabled Kubernetes clusters:

1. **Connect clusters to Azure Arc**: Connect your Kubernetes clusters to Azure Arc. For instructions, see [Connect an existing Kubernetes cluster to Azure Arc](/azure/azure-arc/kubernetes/quickstart-connect-cluster).
2. **Create or upgrade your fleet**: Create (or upgrade) a fleet resource with a hub cluster, then join your Arc-enabled clusters. For instructions, see [Create a fleet and join member clusters](./quickstart-create-fleet-and-members.md).
3. **Configure workload placement**: Create `ClusterResourcePlacement` resources for your applications. For guidance, see [Kubernetes resource propagation concepts](./concepts-resource-propagation.md).