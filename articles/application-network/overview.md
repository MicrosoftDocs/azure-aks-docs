---
title: Overview of Azure Kubernetes Application Network for AKS (Preview)
description: Learn about Azure Kubernetes Application Network, a fully managed, ambient-based service network solution for Azure Kubernetes Service (AKS) that enables secure, policy-driven communication between services without sidecars or changes to your applications.
author: kochhars
ms.author: kochhars
ms.service: azure-kubernetes-app-net
ms.topic: overview
ms.date: 11/05/2026
ms.custom: references_regions
ai-usage: ai-assisted
---

# Overview of Azure Kubernetes Application Network for AKS (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Azure Kubernetes Application Network is a fully managed, [ambient-based](https://istio.io/latest/docs/ambient/) service network for Azure Kubernetes Service (AKS). It enables secure, policy-driven service-to-service communication without sidecars or application changes. Azure manages the control plane and data plane so you can focus on your workloads.

## Watch an overview

Watch the AKS Me Anything conversation with Jorge and Jack for an introduction to Application Network.

> [!VIDEO https://www.youtube.com/embed/Rg21m1YTdBA]

You can also [watch the interview on YouTube](https://www.youtube.com/watch?v=Rg21m1YTdBA). To try it yourself, follow the [get-started guide](./get-started.md) and check the [currently supported versions](./supported-versions.md).

## Core capabilities

Application Network provides the following security and lifecycle capabilities:

- **Automatic mutual TLS (mTLS)**: Secures service-to-service traffic by default, supporting both encrypted and unencrypted connections automatically.
- **Managed certificate authority**: Issues and rotates SPIFFE compliant workload certificates automatically.
- **Version and upgrade control**: Select minor versions manually or use release channels for automated upgrades. Application Network always manages rollout and patching.

## Architecture overview

Application Network uses an **ambient mesh model** composed of lightweight node-level and optional L7 proxies:

- **Node-level proxies** secure all L4 service-to-service traffic in the cluster through mTLS.
- **Optional L7 proxies** provide advanced routing and policy enforcement at the service level.

Separating the data plane from individual workloads reduces resource usage and simplifies operations. For more details, see [Azure Kubernetes Application Network architecture](./architecture.md).

## Supported scenarios

Create an Application Network resource to provision a dedicated control plane and data plane, then connect one or more AKS clusters as members. Application Network manages configuration and service identity for communication within and across member clusters.

For multi-cluster deployments, choose a topology that matches your network reachability. Members in the same mesh network require direct pod-IP connectivity; members in different networks communicate through east-west gateways. Application Network doesn't create the underlying connectivity for either path. For configuration steps, see [Configure multi-cluster connectivity](./multi-cluster-connectivity.md).

Joining a cluster doesn't automatically enroll all application workloads or export every service. Enroll the intended workloads in ambient mode and configure global services as described in the [traffic management walkthrough](./traffic-management-use-cases.md).

## Limitations

> [!IMPORTANT]
> Azure Kubernetes Application Network manages only service network-related components and policies. It doesn't manage or upgrade your AKS cluster, Kubernetes version, or node images.

> [!IMPORTANT]
> Azure Kubernetes Application Network doesn't store any customer data.

Application Network currently has the following limitations:

- Application Network requires AKS version 1.30 or higher. Refer to [Application Network supported versions](./supported-versions.md) for each AKS version's specific compatibility information.
- AKS [private clusters](../aks/private-clusters.md) require service enablement and `Microsoft.AppLink/PrivatePath` registration. To check eligibility and subnet requirements, see [Connect private AKS clusters][appnet-private-connectivity]. Public AKS clusters can't use the private-connect path. Ordinary public-cluster onboarding stays the same.
- Linux only. Windows node pools aren't supported.
- Switching between upgrade modes `SelfManaged` and `FullyManaged` isn't supported.
- Currently supported only in the following regions:
  - canadacentral
  - centralindia
  - centralus
  - eastus
  - eastus2
  - japaneast
  - northcentralus
  - northeurope
  - southindia
  - southeastasia
  - swedencentral
  - westcentralus
  - westus2
  - westus3
- Enabling the [Istio-based service mesh add-on for AKS](/azure/aks/istio-about) isn't supported on clusters connected to Application Network.
- An Application Network resource's location, subscription, and resource group are fixed when you create it and can't be changed afterward.
- An Application Network member resource's parent Application Network, location, subscription, and resource group are fixed when it joins and can't be changed afterward.

## Related content

To learn more about Azure Kubernetes Application Network, see the following articles:

- [Get started with Azure Kubernetes Application Network for AKS](./get-started.md)
- [Connect private AKS clusters to Application Network][appnet-private-connectivity]
- [Azure Kubernetes Application Network architecture](./architecture.md)
- [Configure multi-cluster connectivity](./multi-cluster-connectivity.md)
- [Overview of Azure Kubernetes Application Network observability](./observability.md)
- [Overview of Azure Kubernetes Application Network security](./security.md)
- [Azure Kubernetes Application Network supported versions](./supported-versions.md)
- [Configure Azure Kubernetes Application Network upgrades](./upgrades.md)

<!--- LINKS --->
[appnet-private-connectivity]: ./private-connectivity.md
