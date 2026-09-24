---
title: "Azure Kubernetes Fleet Manager member cluster types"
description: This article provides a conceptual overview of the different types of member clusters supported in Azure Kubernetes Fleet Manager.
ms.date: 09/24/2026
author: ealianis
ms.author: sehobbs
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
---
    
# Member cluster types for Azure Kubernetes Fleet Manager

Azure Kubernetes Fleet Manager supports two types of member clusters:

- [Azure Kubernetes Service (AKS) clusters](/azure/aks/).
- [Arc-enabled Kubernetes clusters](/azure/azure-arc/kubernetes/overview).

The following table outlines which Azure Kubernetes Fleet Manager capabilities are supported for each member cluster type.

| Capability                         | AKS cluster | Arc-enabled Kubernetes cluster |
|------------------------------------|-------------|--------------------------------|
| Kubernetes and node image updates  | ✅ GA       | ❌ Unsupported                |
| Cross-cluster networking           | ✅ Preview  | ❌ Unsupported                |
| Workload placement                 | ✅ GA       | ✅ GA                         |
| DNS load balancing                 | ✅ GA       | ❌ Unsupported                |
| Managed Namespaces                 | ✅ GA       | ❌ Unsupported                |
| Managed Namespace RBAC             | ✅ GA       | ❌ Unsupported                |
| Non-public Azure regions           | ✅ GA       | ❌ Unsupported                |

## Arc-enabled Kubernetes clusters important considerations

Depending on your environment and configuration, certain limitations might apply when connecting an Arc-enabled Kubernetes cluster to an Azure Kubernetes Fleet Manager hub. Review the following considerations.

> [!NOTE]
> When you delete an Azure Arc-enabled Kubernetes cluster without first removing it from Fleet Manager, the Fleet Manager member cluster resource remains active, even though the target cluster no longer exists. We expect to address this limitation in a future release.

### Cluster resource requirements

When you add an Arc-enabled Kubernetes cluster to Fleet Manager, the member cluster must meet the following conditions:

- At least **210 MB** memory and **2%** of one CPU core available.
- Reserve **3 pods** for the Azure Kubernetes Fleet Manager Arc extension agents.
- Create the **fleet-system** namespace for Fleet-related components and don't directly modify it.

### Private Fleet

For **Private Fleets**, configure your Arc-enabled Kubernetes cluster to use [Azure Arc Gateway](/azure/azure-arc/servers/arc-gateway).

### Networking

**TLS-terminating proxies aren't supported.**  If you use a **passthrough proxy**, configure your Arc-enabled Kubernetes cluster to use [Azure Arc Gateway](/azure/azure-arc/servers/arc-gateway).

## Non-public region limitation

Fleet Manager Arc-enabled Kubernetes cluster support is available only in Azure public cloud regions due to the dependency on Azure Arc Gateway.

If you attempt to create an Arc-enabled member cluster in a non-public cloud region, you receive an error of type `FeatureNotAvailableInCloud` with the message `The feature 'Arc Member Cluster' is not available in cloud environment`.

Track the status of Azure Arc Gateway regional availability via its [official documentation][azure-arc-gateway].

<!-- LINKS -->
[azure-arc-gateway]: /azure/azure-arc/kubernetes/arc-gateway-simplify-networking
