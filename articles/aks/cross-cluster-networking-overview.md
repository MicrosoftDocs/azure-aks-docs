---
title: Choose Cross-Cluster Networking for AKS
description: Compare Cilium Cluster Mesh and Azure Kubernetes Application Network for cross-cluster connectivity, service discovery, and traffic policies.
author: jack4it
ms.author: mjac
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: concept-article
ms.date: 11/08/2026
ai-usage: ai-generated
---

# Choose cross-cluster networking for AKS

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

When services communicate across AKS clusters, plan both the network path between workloads and the service identity and traffic policies you need. Cilium Cluster Mesh and Azure Kubernetes Application Network provide different ways to address these needs.

## Compare the options

Use this comparison to find the documentation that matches your requirements.

| Option | Main focus | Configuration requirements |
| --- | --- | --- |
| [Cilium Cluster Mesh (preview)](./cross-cluster-networking-fleet-use-cases.md) | Direct pod IP routing, shared service discovery, and network policies across clusters, managed through Azure Kubernetes Fleet Manager. | Azure CNI with Cilium, Advanced Container Networking Services (ACNS), and direct cross-cluster pod IP reachability. |
| [Azure Kubernetes Application Network (preview)](./application-network-multi-cluster.md) | Managed workload identity, mutual TLS (mTLS), and optional layer 7 routing and authorization through a sidecar-free service network. | Workload enrollment, participating services, and reachability through direct pod IP paths or east-west gateways. |

## Choose by workload needs

Both options support direct cross-cluster pod connectivity. Choose based on the networking and service-mesh capabilities your workloads need:

- **Cilium-based networking across clusters**: Review [Cilium Cluster Mesh](./cross-cluster-networking-fleet-use-cases.md) for shared service discovery and cross-cluster network policies.
- **A managed, sidecar-free service mesh across clusters**: Review [Application Network](./application-network-multi-cluster.md) for workload identity, mTLS, and optional layer 7 traffic policies, with direct pod connectivity or east-west gateways.

You can't currently use Cilium Cluster Mesh and Application Network together on the same AKS cluster.

## Check connectivity requirements

Application Network doesn't create the underlying connectivity between clusters. For clusters that use Azure CNI Overlay, VNet peering alone doesn't provide direct cross-cluster pod IP reachability. See [Application Network topology requirements](../application-network/multi-cluster-connectivity.md#choose-a-topology).

## Next steps

- [Explore Cilium Cluster Mesh use cases](./cross-cluster-networking-fleet-use-cases.md)
- [Plan service connectivity with Application Network](./application-network-multi-cluster.md)
- [Configure Application Network connectivity](../application-network/multi-cluster-connectivity.md)
