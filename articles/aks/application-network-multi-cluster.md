---
title: Multi-Cluster Service Connectivity with Application Network (Preview)
description: Plan service-to-service connectivity across AKS clusters and find the Application Network topology and configuration guides.
author: jack4it
ms.author: mjac
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: concept-article
ms.date: 11/07/2026
ai-usage: ai-generated
---

# Multi-cluster service connectivity with Application Network (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

[Azure Kubernetes Application Network (Application Network)](./application-network-overview.md) connects participating services across AKS member clusters through an ambient service network. Use it for service-to-service communication with workload identity, mutual TLS (mTLS), and optional layer 7 routing.

For configuration steps, see [Configure multi-cluster connectivity](../application-network/multi-cluster-connectivity.md) in the [Application Network documentation](../application-network/index.yml).

## Choose the service traffic path

Join the clusters to the same Application Network, and then choose a topology based on pod IP reachability. Clusters with a flat, routable pod address space can communicate directly. Clusters with separate pod address spaces that aren't directly reachable, or that overlap, communicate through east-west gateways.

| Topology | Service traffic path | Connectivity you provide |
| --- | --- | --- |
| Flat, routable pod address space | Direct pod IP communication through the ambient data plane. | Bidirectional reachability between non-overlapping pod IP addresses. |
| Separate pod address spaces without direct reachability, or overlapping address spaces | Communication through east-west gateways. | Reachability from each member cluster's data plane to the other member clusters' gateways. |

When you join a cluster, use `--network-name` on `az appnet member join` to identify which member clusters share direct pod IP reachability. Assign the same name only to members with bidirectional reachability between non-overlapping pod addresses; use different names for members that require gateways. The name declares connectivity; it doesn't create it. Virtual network (VNet) peering alone doesn't make Azure CNI Overlay pod IP addresses directly reachable across clusters. An east-west gateway carries cross-cluster service traffic, not application ingress. See [Configure multi-cluster connectivity](../application-network/multi-cluster-connectivity.md).

## Enroll workloads and export services

Joining clusters doesn't automatically enroll workloads or export services. Enroll workloads in the ambient data plane by labeling their namespace with `istio.io/dataplane-mode=ambient`. Mark each service you want other member clusters to discover as a global service with `istio.io/global="true"`. To configure enrollment, global services, and optional waypoints, follow the [traffic management walkthrough](../application-network/traffic-management-use-cases.md).

## Next steps

- [Choose a topology and configure member connectivity](../application-network/multi-cluster-connectivity.md)
- [Check private-cluster eligibility and connectivity requirements](../application-network/private-connectivity.md)
- [Review Application Network architecture](../application-network/architecture.md) and [current limitations](../application-network/overview.md#limitations)
