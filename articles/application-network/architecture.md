---
title: Azure Kubernetes Application Network Architecture (Preview)
description: Learn about the architecture of Azure Kubernetes Application Network including management plane, control plane, data plane, and multi-cluster service discovery.
author: kochhars
ms.author: kochhars
ms.service: azure-kubernetes-app-net
ms.topic: concept-article
ms.date: 03/05/2026
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

For multi-cluster deployments, Application Network synchronizes service discovery information across member clusters so that services can communicate transparently across cluster boundaries.

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
- **Waypoint proxies**: Optional per-namespace L7 proxies that provide HTTP routing, traffic shifting, fault injection, and L7 authorization. Waypoint proxies are deployed only when L7 policies are configured for a namespace.
- **East-west gateway**: Handles cross-cluster traffic in multi-cluster deployments. You're responsible for providing network connectivity between east-west gateways in each member cluster. For more information, see [Multi-cluster service discovery](#multi-cluster-service-discovery).
- **Istio CNI**: A DaemonSet that configures pod networking for ambient mesh traffic interception.
- **CRDs**: Kubernetes custom resource definitions for configuring traffic management and security policies.

When a request is made between services, ztunnel intercepts the traffic, establishes an mTLS connection with the destination's ztunnel, and delivers the request to the destination workload. If L7 policies are configured, traffic routes through a waypoint proxy before reaching its destination. For cross-cluster traffic, ztunnel routes through the east-west gateway to reach workloads in remote member clusters.

## Multi-cluster service discovery

Application Network supports connecting multiple AKS clusters into a unified service mesh. Services in one member cluster can communicate with services in other member clusters, with mTLS enforced end-to-end across cluster boundaries.

In open-source Istio multi-cluster deployments, control planes typically connect to the Kubernetes API servers of other clusters to discover services and configuration changes. Application Network follows a similar service discovery model, where control planes obtain service information from member clusters so that services can be discovered across cluster boundaries. This approach enables workloads in one member cluster to resolve and communicate with services running in other clusters without requiring application changes. Adding a new member cluster expands the mesh membership so that services in the new cluster become discoverable by other members.

Cross-cluster traffic flows through east-west gateways deployed in each member cluster. You're responsible for providing network reachability between the east-west gateways of your member clusters — for example, through VNet peering, VPN, or other connectivity solutions. All cross-cluster traffic is encrypted with mTLS.

## How components interact

The control plane connects to the member cluster's Kubernetes API server, watches for service and configuration changes, and pushes xDS updates to ztunnel and waypoint proxies. When multiple members exist, each control plane also exchanges service information through managed messaging so that every member has a consistent view of all services across the mesh.

Certificate management provisions a root CA when the Application Network resource is created and issues intermediate CAs for each member cluster. Workload certificates are issued with a 24-hour validity period and rotated automatically every 12 hours. The entire certificate lifecycle, from root CA through intermediate and workload certificates, is managed without manual intervention.

For the full certificate hierarchy and rotation schedule, see the [Overview of Azure Kubernetes Application Network security](./security.md).

## Related content

For more information about Azure Kubernetes Application Network, see the following articles:

- [Overview of Azure Kubernetes Application Network for AKS](./overview.md)
- [Azure Kubernetes Application Network supported versions](./supported-versions.md)

<!--- LINKS --->
[az-appnet]: /cli/azure/appnet
