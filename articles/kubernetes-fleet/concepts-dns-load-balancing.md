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

Azure Kubernetes Fleet Manager can be used to set up and manage DNS-based multi-cluster public load balancing for workloads deployed across member clusters.

[!INCLUDE [preview features note](./includes/preview/preview-callout-data-plane-network-alpha.md)]

:::image type="content" source="./media/dns-load-balancing/fleet-dns-load-balance-conceptual.png" alt-text="A diagram showing a conceptual overview of how Fleet Manager supports DNS load balancing across three member clusters using Azure Traffic Manager and Kubernetes ServiceExport resources." lightbox="./media/dns-load-balancing/fleet-dns-load-balance-conceptual.png":::

To deliver multi-cluster public load balancing with DNS, Fleet Manager utilizes [Azure Traffic Manager][traffic-manager-overview] with a [weighted routing profile][traffic-manager-weighted] to act as a frontend for `Services` exported from member clusters. 

Fleet administrators use `kubectl` to create and configure `TrafficManagerProfile` and `TrafficManagerBackend` resources on the Fleet Manager hub cluster. The `TrafficManagerProfile` defines an Azure Traffic Manager Profile that includes [endpoint health monitoring][traffic-manager-health-check] configuration, with the associated `TrafficManagerBackend` defining the `Service` to be load balanced.

Services on member clusters can be added to the load balancing by creating a `ServiceExport` on the cluster and providing a `ResourceOverride` to configure a unique DNS name for the Service. Optional weights can be defined that configure traffic routing behavior between clusters.

The creation and configuration of the associated Traffic Manager is handled entirely by Fleet Manager, with fleet administrators able to drive the end to end experience via the `kubectl` CLI.

## Next steps

* [Set up DNS load balancing across Azure Kubernetes Fleet Manager member clusters](./howto-dns-load-balancing.md).

<!-- INTERNAL LINKS -->
[traffic-manager-overview]: /azure/traffic-manager/traffic-manager-overview
[traffic-manager-weighted]: azure/traffic-manager/traffic-manager-routing-methods#weighted-traffic-routing-method
[traffic-manager-health-check]: azure/traffic-manager/traffic-manager-monitoring#configure-endpoint-monitoring
