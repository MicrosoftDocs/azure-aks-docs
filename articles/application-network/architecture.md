---
title: Azure Kubernetes Application Network Architecture (Preview)
description: Learn about the architecture of Azure Kubernetes Application Network including management plane, control plane, data plane, and multi-cluster service discovery.
author: kochhars
ms.author: kochhars
ms.service: azure-kubernetes-app-net
ms.topic: concept-article
ms.date: 10/30/2026
ai-usage: ai-assisted
---

# Azure Kubernetes Application Network architecture (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Azure Kubernetes Application Network architecture is organized into three layers: a **management plane**, a **control plane**, and a **data plane**. Each layer has distinct responsibilities that together provide a fully managed, Ambient-based service network solution for Azure Kubernetes Service (AKS). This architecture enables secure, policy-driven communication between services without requiring sidecars or changes to your applications.

This article provides an overview of the architectural layers of Azure Kubernetes Application Network, how they interact, and the multi-cluster service discovery model that enables scalable cross-cluster communication. For more information about Azure Kubernetes Application Network, see the [Overview of Azure Kubernetes Application Network for AKS](./overview.md).

## Overview of Application Network architectural layers

The architectural layers manage the following responsibilities:

- **Management plane**: Handles Azure resource operations such as creating, updating, and deleting Application Network resources and managing cluster membership.
- **Control plane**: Manages mesh configuration, certificate lifecycle, and service discovery for each member cluster.
- **Data plane**: Secures service-to-service traffic directly in the member cluster using ambient mode, which requires no sidecars or changes to your applications.

For multi-cluster deployments, Application Network synchronizes discovery for participating global services across member clusters. You configure workload enrollment, service participation, and the underlying connectivity required by your topology.

The following diagram illustrates the architectural layers of Azure Kubernetes Application Network and how they interact with each other and with your AKS clusters:

:::image type="content" source="./media/architecture/application-network-architecture.png" alt-text="Screenshot of a diagram illustrating the architectural layers of Azure Kubernetes Application Network and how they interact with each other and with AKS clusters." lightbox="./media/architecture/application-network-architecture.png":::

## Management plane

The management plane is the Azure resource provider that handles all Application Network resource operations. When you create an Application Network resource or join a member cluster, the management plane validates the request, provisions supporting Azure resources such as Azure Key Vault for certificate storage, and orchestrates the creation of a regional control plane for the member.

You interact with the management plane through the Azure CLI ([`az appnet`][az-appnet]) or the ARM API. The management plane coordinates all downstream provisioning so that control plane and data plane components are deployed without manual intervention.

## Control plane

The control plane is fully managed infrastructure that runs outside your AKS cluster. When a member cluster joins an Application Network, a dedicated control plane is provisioned in the same Azure region as the member cluster, keeping latency between control and data plane components low.

> [!NOTE]
> Members in different Azure regions have control planes deployed in their respective regions.

The control plane includes the following components:

- **Istiod**: Connects to the member cluster's Kubernetes API server to discover services and watch for configuration changes. It pushes xDS configuration to ztunnel and waypoint proxies in the data plane. In multi-cluster deployments, Istiod also connects to the Kubernetes API servers of other member clusters to obtain service discovery information, enabling cross-cluster service discovery.
- **Certificate management**: Provisions and rotates CA certificates backed by Azure Key Vault. A root CA establishes a shared trust boundary across all member clusters, and each member receives an intermediate CA that issues short-lived workload certificates. For more information, see the [Overview of Azure Kubernetes Application Network security](./security.md).
- **Lifecycle management**: Deploys and upgrades all data plane components in the member cluster, including ztunnel, Istio CNI, waypoint proxies, and custom resource definitions (CRDs). For more information, see [Configure upgrades for Azure Kubernetes Application Network members](./upgrades.md).

## Data plane

The data plane consists of components deployed into the member cluster's `applink-system` namespace. Application Network uses Istio ambient mode, so there are no sidecars injected into your workloads.

The data plane includes the following components:

- **Ztunnel**: A node-level L4 proxy deployed as a DaemonSet. Ztunnel intercepts service-to-service traffic on the node, establishes mTLS connections transparently, and enforces L4 authorization policies.
- **Waypoint proxies**: Optional per-namespace L7 proxies that provide HTTP routing, traffic shifting, fault injection, and L7 authorization. For deployment and enrollment steps, see the [traffic management walkthrough](./traffic-management-use-cases.md#install-waypoint-and-mark-services-as-global).
- **East-west gateway**: Handles traffic between member clusters in different mesh networks. Members in the same network use direct pod-IP connectivity instead. You're responsible for providing the reachability required by either path. For more information, see [Multi-cluster service discovery](#multi-cluster-service-discovery).
- **Istio CNI**: A DaemonSet that configures pod networking for ambient mesh traffic interception.
- **CRDs**: Kubernetes custom resource definitions for configuring traffic management and security policies.

When a request is made between services, ztunnel intercepts the traffic, establishes an mTLS connection with the destination's ztunnel, and delivers the request to the destination workload. If the service is enrolled with a waypoint, traffic routes through that proxy before reaching its destination. For cross-cluster traffic, the network identities and available reachability determine whether traffic uses direct pod addresses or east-west gateways.

## Multi-cluster service discovery

Application Network supports connecting multiple AKS clusters into a unified service mesh. Enrolled workloads can communicate with participating services in other member clusters, with mTLS across cluster boundaries. Joining a cluster registers it as a member; it doesn't automatically enroll every workload or export every service.

Configure workload namespaces for ambient mode and mark the services that should participate in cross-cluster discovery with `istio.io/global="true"`. For L7 routing, also configure the required waypoints and their cross-cluster service participation. See the [traffic management walkthrough](./traffic-management-use-cases.md#install-waypoint-and-mark-services-as-global).

Each member has a mesh network identity. Members with the same network name require direct, bidirectional reachability between their pod IP addresses. Members in different networks use east-west gateways, for which you provide reachability through VNet peering, VPN, or another connectivity solution. If a custom name isn't provided, Application Network uses a distinct default identity for each member. A shared name describes the direct traffic path; it doesn't create connectivity or disable gateway provisioning. See [Configure multi-cluster connectivity](./multi-cluster-connectivity.md) for topology selection and CLI examples.

## How components interact

The control plane connects to the member cluster's Kubernetes API server, watches for service and configuration changes, and pushes xDS updates to ztunnel and waypoint proxies. When multiple members exist, Application Network synchronizes discovery for participating global services so the control planes can configure cross-cluster communication.

Certificate management provisions a root CA when the Application Network resource is created and issues intermediate CAs for each member cluster. Workload certificates are issued with a 24-hour validity period and rotated automatically every 12 hours. The entire certificate lifecycle, from root CA through intermediate and workload certificates, is managed without manual intervention.

For the full certificate hierarchy and rotation schedule, see the [Overview of Azure Kubernetes Application Network security](./security.md).

## Related content

For more information about Azure Kubernetes Application Network, see the following articles:

- [Configure multi-cluster connectivity](./multi-cluster-connectivity.md)
- [Overview of Azure Kubernetes Application Network for AKS](./overview.md)
- [Azure Kubernetes Application Network supported versions](./supported-versions.md)

<!--- LINKS --->
[az-appnet]: /cli/azure/appnet
