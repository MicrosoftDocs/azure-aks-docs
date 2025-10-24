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

> [!IMPORTANT]
> Azure Kubernetes Fleet Manager's support for Arc-enabled Kubernetes clusters is currently in public preview.


[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## What does the integration solve?

The integration between Azure Kubernetes Fleet Manager and Azure Arc-enabled Kubernetes clusters extends the power of centralized multi-cluster workload management beyond Azure-native AKS clusters to include any many CNCF-certified Kubernetes cluster running anywhere.

- **Supported distributions**: AKS (Azure Kubernetes Service), K3s (Lightweight Kubernetes), OCP (Red Hat OpenShift), EKS (Amazon Elastic Kubernetes Service), GKE (Google Kubernetes Engine), and Rancher (RKE).

### Key benefits of Arc integration

#### Cross-environment workload placement

The integration enables intelligent workload placement across diverse environments:

- **Hybrid placement policies**: Deploy workloads based on cluster properties like location, cost, available resources, or custom labels.
- **Edge-to-cloud scenarios**: Place workloads strategically between edge locations and cloud regions for optimal performance
- **Cost optimization**: Leverage lower-cost on-premises or edge resources while maintaining cloud connectivity
- **Compliance and data residency**: Ensure workloads run in appropriate locations based on regulatory requirements

### Supported scenarios

The Fleet Manager and Arc integration enables several key scenarios for hybrid and multi-cloud Kubernetes management:

#### Hybrid cloud applications

Deploy applications that span both cloud and on-premises resources:
- **Data processing pipelines** that move data between edge locations and cloud storage
- **Content delivery networks** with edge caching and cloud origin servers
- **IoT applications** that process data locally at the edge and aggregate results in the cloud

#### Multi-cloud strategy

Manage Kubernetes clusters across different cloud providers:
- **Vendor diversity** to avoid cloud provider lock-in
- **Geographic coverage** using the best cloud provider for each region
- **Cost optimization** by leveraging different pricing models across providers

#### Edge computing

Extend your Kubernetes fleet to edge locations:
- **Manufacturing environments** with local processing requirements
- **Retail locations** needing low-latency applications
- **Remote sites** with limited connectivity that require local compute capacity


## Fleet Manager capabilities with Arc-enabled clusters

When you join Arc-enabled Kubernetes clusters to Fleet Manager, you gain access to specific capabilities:

### Resource propagation (Preview)

Deploy Kubernetes resources consistently across both AKS and Arc-enabled clusters:
- **ClusterResourcePlacement**: Use placement policies to target specific clusters based on labels and properties
- **Envelope objects**: Safely propagate resources without affecting the hub cluster
- **Progressive rollouts**: Control how updates are rolled out across your fleet

### Intelligent scheduling

Leverage cluster properties for intelligent workload placement:
- **Cost-based placement**: Consider per-CPU and per-memory costs when placing workloads
- **Resource availability**: Place workloads based on available CPU, memory, and storage
- **Geographic distribution**: Use location labels for geographic placement strategies
- **Custom properties**: Define and use custom cluster properties for placement decisions

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

1. **Connect clusters to Azure Arc**: Ensure your Kubernetes clusters are connected to Azure Arc
2. **Create a Fleet Manager resource**: Set up a fleet with a hub cluster
3. **Join Arc-enabled clusters**: Add your Arc-enabled clusters as fleet members
4. **Configure workload placement**: Set up `ClusterResourcePlacement` resources for your applications
5. **Monitor and manage**: Use Azure portal and Azure CLI to monitor your hybrid fleet

## Next steps

- [Azure Kubernetes Fleet Manager member cluster types](./concepts-member-cluster-types.md)
- [Kubernetes resource placement from hub cluster to member clusters](./concepts-resource-propagation.md)
- [Create a fleet and join member clusters](./quickstart-create-fleet-and-members.md)
- [Azure Arc-enabled Kubernetes overview](/azure/azure-arc/kubernetes/overview)
- [Connect an existing Kubernetes cluster to Azure Arc](/azure/azure-arc/kubernetes/quickstart-connect-cluster)
