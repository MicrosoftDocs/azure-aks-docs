---
title: Overview of Azure Kubernetes Application Network for AKS (Preview)
description: Learn about Azure Kubernetes Application Network, a fully managed, ambient-based service network solution for Azure Kubernetes Service (AKS) that enables secure, policy-driven communication between services without sidecars or changes to your applications.
author: kochhars
ms.author: kochhars
ms.service: azure-kubernetes-app-net
ms.topic: overview
ms.date: 11/04/2025
ms.custom: references_regions
---

# Overview of Azure Kubernetes Application Network for AKS (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Azure Kubernetes Application Network provides a fully managed, [ambient-based](https://istio.io/latest/docs/ambient/) service network solution for Azure Kubernetes Service (AKS). It enables secure, policy-driven communication between services without requiring sidecars or changes to your applications. Azure manages both the control plane and data plane, so you can focus on your workloads instead of operating and maintaining service-network infrastructure.

When you create an Application Network resource, a dedicated, fully managed control and data plane is provisioned for service-to-service communication. You can then connect one or more AKS clusters to the Application Network resource to onboard them to the service network. Once connected, Application Network manages configuration, service identity, and version upgrades, providing consistent security and traffic policies across workloads with minimal configuration and operational overhead.

> [!IMPORTANT]
> Azure Kubernetes Application Network manages only service network-related components and policies. It doesn't manage or upgrade your AKS cluster, Kubernetes version, or node images.

> [!IMPORTANT]
> Azure Kubernetes Application Network doesn't store any customer data.

## Core capabilities

Application Network delivers a streamlined approach to zero-trust networking in AKS. Key capabilities include:

- **Ambient architecture**: Provides mesh functionality without sidecars, reducing resource usage and simplifying operations.
- **Automatic mutual TLS (mTLS)**: Secures service-to-service traffic by default, supporting both encrypted and unencrypted connections automatically.
- **Managed certificate authority**: Issues and rotates SPIFFE compliant workload certificates automatically.
- **Version and upgrade control**:  Select minor versions manually or use release channels for automated upgrades. Rollout and patching are always managed by Application Network.
- **Integrated lifecycle management**: Operates as part of the AKS platform with control plane operations fully managed by Azure.

## Architecture overview

Application Network uses an **ambient mesh model** composed of lightweight node-level and optional L7 proxies:

- **Node-level proxies** secure all L4 service-to-service traffic in the cluster through mTLS, eliminating the need for sidecars.
- **Optional L7 proxies** provide advanced routing and policy enforcement at the service level.

This design separates the data plane from individual workloads, improving efficiency, and simplifying adoption. For more details, see [Azure Kubernetes Application Network architecture](./architecture.md).

## Supported scenarios

Application Network supports single-cluster AKS deployments running **Linux-based node pools**. It's ideal for applications that require secure, in-cluster communication and simplified mesh management without managing sidecars or control plane components.

## Limitations

Application Network currently has the following limitations:

- AKS [private clusters](../aks/private-clusters.md) aren't currently supported.
- Linux only. Windows node pools aren't supported.
- Switching between upgrade modes `SelfManaged` and `FullyManaged` isn't supported.
- Currently supported only in the following regions:
  - centralus
  - eastus2
  - westus2
  - westus3
  - northeurope
  - southeastasia
- Enabling the [Istio-based service mesh add-on for AKS](/azure/aks/istio-about) isn't supported on clusters connected to Application Network.

## Related content

To learn more about Azure Kubernetes Application Network, see the following articles:

- [Get started with Azure Kubernetes Application Network for AKS](./get-started.md)
- [Azure Kubernetes Application Network architecture](./architecture.md)
- [Overview of Azure Kubernetes Application Network observability](./observability.md)
- [Overview of Azure Kubernetes Application Network security](./security.md)
- [Azure Kubernetes Application Network supported versions](./supported-versions.md)
- [Configure Azure Kubernetes Application Network upgrades](./upgrades.md)
