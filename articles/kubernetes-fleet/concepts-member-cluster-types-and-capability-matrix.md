---
title: "Azure Fleet Manager member cluster types & capability matrix"
description: This article provides a conceptual overview of Azure Kubernetes Fleet Manager and member clusters.
ms.date: 09/02/2025
author: ealianis
ms.author: sehobbs
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
---

# Azure Fleet Manager Member cluster types

Azure Fleet Manager supports two types of member clusters: Azure Kubernetes Service (AKS) clusters and Arc-Enabled Kubernetes clusters (currently in Preview).
To learn more about each, see their respective documentation:

- [Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/)
- [Arc-Enabled Kubernetes clusters](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/overview)

## Member cluster capability matrix

The following table outlines which Azure Fleet Manager Capabilities are supported for each member cluster type.

| Capability | AKS Cluster | Arc-Enabled Cluster | Note|
|-----|----|-----------| ----|
| Join / Leave    |✅ GA | ✅ Preview    | For Arc-Enabled Kubernetes clusters, review [important considerations](#arc-enabled-kubernetes-clusters-important-considerations). |
| Managed Namespaces | ✅ Preview  | ✅ Preview  | |
| Multi-Cluster Networking | ✅ GA| ❌ Not supported||
| Multi-Cluster Update |✅ GA | ❌ Not supported||
| Workload-Orchestration |✅ GA| ✅ Preview||

## Arc-Enabled Kubernetes Clusters important considerations

Depending upon your networking configurations, you may experience limitations with respect the Arc-Enabled Kubernetes cluster communicating with an Azure Fleet Manager's Hub Cluster. The following caveats to be aware of:

*Fleet Type Considerations:*

1. If you create a Private Fleet, then your Arc-Enabled Kubernetes cluster must also be configured to use [Azure Arc Gateway](https://learn.microsoft.com/azure/azure-arc/servers/arc-gateway).

*Cluster Considerations:*

1. Azure Fleet Manager creates a special namespace on your cluster named `fleet-system`. It is **CRITICAL** that this namespace is not deleted or modified in any way. It is managed by the Azure Fleet Manager dataplane components. Perversion of this namespace may cause the core functionality to break.
2. Azure Fleet Manager requires running 3 pods on the Arc-Enabled Cluster. Ensure the underlying cluster's max_pod count / capacity supports this requirement.

*Networking Egress Considerations:*

1. TLS Terminating proxies are not supported.
2. Passthrough proxy usage requires that your Arc-Enabled Kubernetes cluster must also be configured to use [Azure Arc Gateway](https://learn.microsoft.com/azure/azure-arc/servers/arc-gateway).
