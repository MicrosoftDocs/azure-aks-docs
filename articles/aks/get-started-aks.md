---
title: Get Started With Azure Kubernetes Service (AKS) Basics
description: Learn the basics of Azure Kubernetes Service (AKS) and start with AKS Automatic as the recommended production-ready default for most workloads.
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.topic: get-started
ms.date: 06/05/2026
# Customer intent: As a new user, I want to get started with Azure Kubernetes Service (AKS) so that I can deploy and manage containerized applications.
---

# Get started with Azure Kubernetes Service (AKS) basics

This guide provides resources to help you learn the basics of [Azure Kubernetes Service (AKS)](./what-is-aks.md).

For most production workloads, start with [**AKS Automatic**](./intro-aks-automatic.md). AKS Automatic is the recommended production-ready default in AKS and provides preconfigured best-practice defaults for scaling, security, networking, monitoring, and upgrades.

Use AKS Standard when you need deeper control over platform configuration and lifecycle operations.

## AKS cluster modes

AKS supports two cluster modes:

- **AKS Automatic (recommended default)**: Best for most production workloads and faster time to value with preconfigured production-ready defaults.
- **AKS Standard**: Best when you require advanced customization for networking, identity, node topology, or upgrade behavior.

For detailed differences, see [AKS Automatic and AKS Standard feature comparison](./intro-aks-automatic.md#aks-automatic-and-standard-feature-comparison).

> [!NOTE]
> AKS Automatic is the recommended starting point for most production-ready AKS workloads. If your requirements demand deeper infrastructure customization, AKS Standard remains fully supported.

## Learn the basics of AKS

The resources in the following sections provide an introduction to AKS fundamentals and common platform areas.

### AKS fundamentals

- [What is AKS?](./what-is-aks.md)
- [What is AKS Automatic?](./intro-aks-automatic.md)
- [Core concepts](./core-aks-concepts.md)
- [Deploy clusters with AKS Automatic lab](https://azure-samples.github.io/aks-labs/docs/getting-started/aks-automatic/)
- [Kubernetes and AKS fundamentals lab](https://azure-samples.github.io/aks-labs/docs/getting-started/k8s-aks-fundamentals/)
- Create an AKS cluster
  - [Create a Linux-based AKS Automatic cluster](./automatic/quick-automatic-from-code.md)
  - [Create a Linux-based AKS cluster](./learn/quick-kubernetes-deploy-cli.md)
  - [Create a Windows-based AKS cluster](./learn/quick-windows-container-deploy-cli.md)

### Networking

- [AKS networking overview](./concepts-network.md)
- [AKS networking best practices video](https://www.youtube.com/watch?v=mAGqnX2WW1M)
- [Istio service mesh on AKS lab](https://azure-samples.github.io/aks-labs/docs/networking/istio-lab/)

### Access and identity

- [Access and identity concepts](./concepts-identity.md)
- [Workload identity lab](https://azure-samples.github.io/aks-labs/docs/security/workload-identity-lab/)

### Storage

- [Storage concepts](./concepts-storage.md)
- [Advanced storage concepts lab](https://azure-samples.github.io/aks-labs/docs/storage/advanced-storage-concepts/)

## Next steps

- [Create an AKS Automatic cluster](./automatic/quick-automatic-from-code.md)
- [Learn about advanced AKS concepts](./advanced-aks-concepts.md)
