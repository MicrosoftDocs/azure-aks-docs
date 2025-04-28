---
title: "Multi-cluster DNS-based load balancing with Azure Kubernetes Fleet Manager"
description: Understand how Fleet Manager supports DNS-based load balancing for placed workloads.
ms.date: 04/28/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: conceptual
---

# Multi-cluster DNS-based load balancing with Azure Kubernetes Fleet Manager (preview)

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

Azure Kubernetes Fleet Manager (Fleet) can be used to set up layer 4 multi-cluster load balancing across workloads deployed across member clusters.

[ ![Diagram that shows how multi-cluster load balancing works.](./media/conceptual-load-balancing.png) ](./media/conceptual-load-balancing.png#lightbox)

For multi-cluster load balancing, Fleet requires target clusters to be using [Azure CNI networking](/azure/aks/configure-azure-cni). Azure CNI networking enables pod IPs to be directly addressable on the Azure virtual network so that they can be routed to from the Azure Load Balancer.

The `ServiceExport` itself can be propagated from the fleet cluster to a member cluster using the Kubernetes resource propagation feature, or it can be created directly on the member cluster. Once this `ServiceExport` resource is created, it results in a `ServiceImport` being created on the fleet cluster, and all other member clusters to build the awareness of the service.

The user can then create a `MultiClusterService` custom resource to indicate that they want to set up Layer 4 multi-cluster load balancing. This `MultiClusterService` results in the member cluster mapped Azure Load Balancer being configured to load balance incoming traffic across endpoints of this service on multiple member clusters.

## Next steps

* [Set up multi-cluster layer-4 load balancing](./l4-load-balancing.md).