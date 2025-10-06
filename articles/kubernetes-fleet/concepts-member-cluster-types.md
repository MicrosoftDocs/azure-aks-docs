---
title: "Azure Fleet Manager member cluster types & capability matrix"
description: This article provides a conceptual overview of the different types of member clusters supported in Azure Fleet Manager.
ms.date: 09/02/2025
author: ealianis
ms.author: sehobbs
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
---

# Azure Fleet Manager Member cluster types

Azure Fleet Manager supports two types of member clusters: Azure Kubernetes Service (AKS) clusters and Arc-Enabled Kubernetes clusters (Preview).
To learn more about each, see their respective documentation:

- [Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/)
- [Arc-Enabled Kubernetes](https://learn.microsoft.com/azure/azure-arc/kubernetes/overview)

> [!IMPORTANT]
> Azure Fleet Manager's support for Arc-Enabled Kubernetes clusters is currently in Preview. [See below for limitations and requirements](#arc-enabled-kubernetes-clusters-important-considerations).

## Member cluster capability matrix

The following table outlines which Azure Fleet Manager Capabilities are supported for each member cluster type.

| Capability | AKS cluster | Arc-Enabled Kubernetes cluster |
|-----|----|-----------|
| Managed Namespaces | ✅ Preview  | ✅ Preview  |
| Multi-cluster networking | ✅ GA| ❌ Not supported|
| Multi-cluster Kubernetes and node image upgrades |✅ GA | ❌ Not supported|
| Multi-cluster workload management |✅ GA| ✅ Preview|



## Arc-Enabled Kubernetes Clusters important considerations

Depending on your environment and configuration, certain limitations may apply when connecting an Arc-enabled Kubernetes cluster to an Azure Fleet Manager hub. Review the following considerations:

| **Category** | **Requirement / Consideration** |
|:--------------|:--------------------------------|
| **Fleet Type** | • For Private Fleets: your Arc-enabled Kubernetes cluster **must** be configured to use [Azure Arc Gateway](https://learn.microsoft.com/azure/azure-arc/servers/arc-gateway). |
| **Cluster Configuration** | • Azure Fleet Manager automatically creates a **`fleet-system`** namespace.<br> – Do **not** delete or modify this namespace.<br> – It’s managed by Fleet dataplane components and required for core functionality.<br><br>• Azure Fleet Manager requires **3 pods** to run on each Arc-enabled cluster.<br> – Verify your cluster’s **max_pods / capacity** supports this requirement. |
| **Networking** | • **TLS-terminating proxies are not supported.**<br>• If using a **passthrough proxy**, your Arc-enabled Kubernetes cluster **must** also be configured with [Azure Arc Gateway](https://learn.microsoft.com/azure/azure-arc/servers/arc-gateway). |
