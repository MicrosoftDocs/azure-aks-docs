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

:::image type="content" source="./media/concepts-dns-load-balancing/fleet-dns-load-balance-conceptual.png" alt-text="A diagram showing a conceptual overview of how Fleet Manager supports DNS load balancing across three member clusters using Azure Traffic Manager and Kubernetes ServiceExport resources." lightbox="./media/concepts-dns-load-balancing/fleet-dns-load-balance-conceptual.png":::

To deliver multi-cluster public load balancing with DNS, Fleet Manager utilizes [Azure Traffic Manager][traffic-manager-overview] with a [weighted routing profile][traffic-manager-weighted] to act as a frontend for `Services` exported from member clusters. As this capability is delivered via DNS it can be used to provide layer 4 and 7 load balancing as required.

Fleet administrators use `kubectl` to create and configure `TrafficManagerProfile` and `TrafficManagerBackend` resources on the Fleet Manager hub cluster. The `TrafficManagerProfile` defines an Azure Traffic Manager Profile that includes [endpoint health monitoring][traffic-manager-health-check] configuration, with the associated `TrafficManagerBackend` defining the `Service` to be load balanced.

Services on member clusters can be added to the load balancing by creating a `ServiceExport` on the cluster and providing a `ResourceOverride` to configure a unique DNS name for the Service. Optional weights can be defined that configure traffic routing behavior between clusters.

The creation and configuration of the associated Traffic Manager is handled entirely by Fleet Manager, with fleet administrators able to drive the end to end experience via the `kubectl` CLI.

## TrafficManagerProfile properties

The `TrafficManagerProfile` resource provides a Kubernetes object representation of a standard Azure Traffic Manager Profile.

```yml
apiVersion: networking.fleet.azure.com/v1alpha1
kind: TrafficManagerProfile
metadata:
  name: myatm
  namespace: work
spec:
  monitorConfig:
    protocol: HTTP
    path: /
    port: 8080
    intervalInSeconds: 30
    timeoutInSeconds: 10
    toleratedNumberOfFailures: 3
```

The important properties to understand include:

* `name`: this is used as the DNS prefix for the `trafficmanager.net` DNS name. It must be unique and if already in use, deployment will fail.
* `namespace`: this must be the same as the corresponding `TrafficManagerBackend` and `Service` resource.
* `monitorCOnfig`: maps to the standard Azure Traffic Manager monitoring configuration. Unsupported Azure Traffic Manager endpoint monitoring options are: Custom header settings; expected status codes.

## TrafficManagerBackend properties

```yml
apiVersion: networking.fleet.azure.com/v1alpha1
kind: TrafficManagerBackend
metadata:
  name: app
  namespace: work
spec:
  profile:
    name: myatm
  backend:
    name: app
  weight: 100
```

The important properties to understand include:

* `spec/profile/name`: must match the corresponding `TrafficManagerProfile`.
* `spec/backend/name`: must match the exported service name that will be load balanced. 
* `spec/weight`: weight (out of 100) to apply to this backend configuration.

## Nested Traffic Manager Profiles

It is possible to use [nested Traffic Manager Profiles][traffic-manager-nested] though this is an advanced topic not currently covered in our documentation.

## Next steps

* [Set up DNS load balancing across Azure Kubernetes Fleet Manager member clusters](./howto-dns-load-balancing.md).

<!-- INTERNAL LINKS -->
[traffic-manager-overview]: /azure/traffic-manager/traffic-manager-overview
[traffic-manager-weighted]: /azure/traffic-manager/traffic-manager-routing-methods#weighted-traffic-routing-method
[traffic-manager-health-check]: /azure/traffic-manager/traffic-manager-monitoring#configure-endpoint-monitoring
[traffic-manager-nested]: /azure/traffic-manager/traffic-manager-nested-profiles
