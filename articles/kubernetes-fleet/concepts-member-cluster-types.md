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
- [Arc-Enabled Kubernetes clusters](/azure/azure-arc/kubernetes/overview) (Preview).

> [!IMPORTANT]
> Azure Kubernetes Fleet Manager's support for Arc-Enabled Kubernetes clusters is currently in Preview. [See below for limitations and requirements](#arc-enabled-kubernetes-clusters-important-considerations).


The following table outlines which Azure Kubernetes Fleet Manager capabilities are supported for each member cluster type.

| Capability | AKS cluster | Arc-Enabled Kubernetes cluster |
|-----|----|-----------|
| Managed Namespaces | ✅ Preview  | ✅ Preview  |
| Multi-cluster networking | ✅ GA| ❌ Not supported|
| Multi-cluster Kubernetes and node image upgrades |✅ GA | ❌ Not supported|
| Multi-cluster workload management |✅ GA| ✅ Preview|

## Arc-Enabled Kubernetes Clusters important considerations

Depending on your environment and configuration, certain limitations may apply when connecting an Arc-enabled Kubernetes cluster to an Azure Kubernetes Fleet Manager hub. Review the following considerations:

### Fleet Type

- For **Private Fleets**, your Arc-enabled Kubernetes cluster **must** be configured to use [Azure Arc Gateway](/azure/azure-arc/servers/arc-gateway).

### Cluster Configuration

Cluster requirements:
- At least **210 MB** memory and **~2 %** of one CPU core available
- The cluster should reserve **3 pods** for the Azure Fleet Manager Arc extension agents
- The namespace **fleet-system** will be created for related components.
  - Do **not delete or modify** this namespace, it is required for core functionality.

### Networking

- **TLS-terminating proxies are not supported.**  
- If using a **passthrough proxy**, your Arc-enabled Kubernetes cluster **must** also be configured to use [Azure Arc Gateway](/azure/azure-arc/servers/arc-gateway).