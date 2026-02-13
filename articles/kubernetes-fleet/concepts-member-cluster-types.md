---
title: "Azure Kubernetes Fleet Manager member cluster types"
description: This article provides a conceptual overview of the different types of member clusters supported in Azure Kubernetes Fleet Manager.
ms.date: 12/11/2025
author: ealianis
ms.author: sehobbs
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
---
    
# Member cluster types for Azure Kubernetes Fleet Manager

Azure Kubernetes Fleet Manager supports two types of member clusters:

- [Azure Kubernetes Service (AKS) clusters](/azure/aks/)
- [Arc-enabled Kubernetes clusters](/azure/azure-arc/kubernetes/overview) (Preview).

> [!IMPORTANT]
> Azure Kubernetes Fleet Manager's support for Arc-enabled Kubernetes clusters is currently in Preview.

The following table outlines which Azure Kubernetes Fleet Manager capabilities are supported for each member cluster type.

| Capability | AKS cluster | Arc-enabled Kubernetes cluster |
|------------|-------------|--------------------------------|
| Kubernetes and node image updates |✅ GA | ❌ Unsupported |
| Workload placement |✅ GA| ✅ Preview |
| DNS load balancing | ✅ GA| ❌ Unsupported|
| Managed Namespaces | ✅ Preview  | ✅ Preview  |
| Managed Namespace RBAC | ✅ Preview  | ❌ Unsupported |
| Non-public Azure regions | ✅ GA  | ❌ Unsupported |

## Arc-enabled Kubernetes Clusters important considerations

Depending on your environment and configuration, certain limitations may apply when connecting an Arc-enabled Kubernetes cluster to an Azure Kubernetes Fleet Manager hub. Review the following considerations:

### Cluster resource requirements

When you add an Arc-enabled Kubernetes cluster to Fleet Manager, the following conditions apply on the member cluster:

- At least **210 MB** memory and **2%** of one CPU core available.
- The cluster should reserve **3 pods** for the Azure Kubernetes Fleet Manager Arc extension agents.
- The **fleet-system** namespace is created for Fleet-related components and shouldn't be directly modified.

### Private Fleet

For **Private Fleets**, your Arc-enabled Kubernetes cluster **must** be configured to use [Azure Arc Gateway](/azure/azure-arc/servers/arc-gateway).

### Networking

**TLS-terminating proxies are not supported.**  If using a **passthrough proxy**, your Arc-enabled Kubernetes cluster **must** also be configured to use [Azure Arc Gateway](/azure/azure-arc/servers/arc-gateway).

## Non-public region limitation

Fleet Manager Arc-enabled Kubernetes cluster support is only currently available in Azure public cloud regions.

If you attempt to create an Arc-enabled member cluster in a non-public cloud region, an error of type `FeatureNotAvailableInCloud` with the message `The feature 'Arc Member Cluster' is not available in cloud environment` is returned.

When Azure Arc Gateway is available in Azure non-public cloud regions the restriction will be lifted.

You can track the status of Azure Arc Gateway via its [official documentation][azure-arc-gateway].

<!-- LINKS -->
[azure-arc-gateway]: /azure/azure-arc/kubernetes/arc-gateway-simplify-networking
