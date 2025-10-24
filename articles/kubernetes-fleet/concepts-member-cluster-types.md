---
title: "Azure Kubernetes Fleet Manager member cluster types"
description: This article provides a conceptual overview of the different types of member clusters supported in Azure Kubernetes Fleet Manager.
ms.date: 09/30/2025
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
> Azure Kubernetes Fleet Manager's support for Arc-enabled Kubernetes clusters is currently in Preview. [See below for limitations and requirements](#arc-enabled-kubernetes-clusters-important-considerations).

[!INCLUDE [preview features note](./includes/preview/preview-callout-data-plane-beta.md)]

The following table outlines which Azure Kubernetes Fleet Manager capabilities are supported for each member cluster type.

| Capability | AKS cluster | Arc-enabled Kubernetes cluster |
|-----|----|-----------|
| Kubernetes and node image updates |✅ GA | ❌ Unsupported|
| Workload placement |✅ GA| ✅ Preview|
| DNS load balancing | ✅ GA| ❌ Unsupported|
| Managed Namespaces | ✅ Preview  | ✅ Preview  |
| Managed Namespace RBAC | ✅ Preview  | ❌ Unsupported  |

## Arc-enabled Kubernetes Clusters important considerations

Depending on your environment and configuration, certain limitations may apply when connecting an Arc-enabled Kubernetes cluster to an Azure Kubernetes Fleet Manager hub. Review the following considerations:

### Private Fleet

- For **Private Fleets**, your Arc-enabled Kubernetes cluster **must** be configured to use [Azure Arc Gateway](/azure/azure-arc/servers/arc-gateway).

### Cluster resource requirements

When adding an Arc-enabled Kubernetes cluster to Fleet Manager, the following conditions apply:
- At least **210 MB** memory and **2%** of one CPU core available
- The cluster should reserve **3 pods** for the Azure Kubernetes Fleet Manager Arc extension agents
- The namespace **fleet-system** will be created for related components.
  - Do **not delete or modify** this namespace, it is required for core functionality.

### Networking

- **TLS-terminating proxies are not supported.**  
- If using a **passthrough proxy**, your Arc-enabled Kubernetes cluster **must** also be configured to use [Azure Arc Gateway](/azure/azure-arc/servers/arc-gateway).