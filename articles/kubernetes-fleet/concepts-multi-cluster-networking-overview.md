---
title: "Azure Kubernetes Fleet Manager multi-cluster networking concepts"
description: This article provides a conceptual overview of Azure Kubernetes Fleet Manager multi-cluster networking. 
ms.date: 03/18/2026
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: As a Kubernetes administrator, I want to manage the eviction and disruption budgets of resources in my cluster, so that I can ensure key workloads remain stable while removing unnecessary resources as needed.
---

# Azure Kubernetes Fleet Manager multi-cluster networking overview

In Kubernetes networking, traffic patterns are often described using the north-south and east-west metaphors. These concepts help clarify where traffic originates, where it’s going, and which networking components handle it.

As platform teams scale from one Kubernetes cluster to many, networking quickly becomes a key area to address - moving from an **intra**-cluster to an **inter**-cluster scope. Workloads across clusters require highly available north–south entry points, resilient east-west failover with consistent secured east–west service discovery between clusters. 

## Seamless service‑to‑service across clusters (east–west)

Azure Kubernetes Fleet Manager delivers capabilities that extends the Kubernetes datapath across clusters, meaning endpoints can talk directly with full network‑policy enforcement and the option to configure global services. 

Multiple cross-cluster networks can be defined in Fleet Manager, providing administrators with the flexibility to control which member clusters can publish and access global services integrated with standard Kubernetes Services and CoreDNS.

For more information, see [configure and use cross-cluster networking](./concepts-cross-cluster-networking.md).

## Resilient public entry point across clusters (north–south)

Fleet Manager exposes a Kubernetes‑driven entry point by configuring Azure Traffic Manager with a weighted routing profile to spread traffic across services exported from member clusters. 

Fleet administrators deploy Kubernetes Custom Resource Definitions (CRDs) `TrafficManagerProfile` and `TrafficManagerBackend` on the Fleet Manager hub cluster, then opt in `Services` by creating a `ServiceExport` on appropriate member clusters. Fleet Manager wires the exported Service into Traffic Manager, providing a unique public DNS name that provides access to the exported Services. You can run both L4 and L7 apps behind this DNS since the decision is made at the DNS layer.

For more information, see [overview of DNS load balancing](./concepts-dns-load-balancing.md).

## Distribute traffic across clusters inside a virtual network (north–south)

Using Fleet Manager's Layer 4 (L4) load balancing capability, administrators declare a `MultiClusterService` that instructs each member cluster's Azure Load Balancer to route traffic not only to local endpoints but also to endpoints of the same `Service` in other member clusters. 

For more information, see [overview of layer 4 load balancing](./concepts-l4-load-balancing.md).

## Next steps

* [How to: Set up DNS load balancing across Azure Kubernetes Fleet Manager member clusters (preview)](./howto-dns-load-balancing.md).
* [Set up multi-cluster layer 4 load balancing across Azure Kubernetes Fleet Manager member clusters (preview)](./l4-load-balancing.md).
