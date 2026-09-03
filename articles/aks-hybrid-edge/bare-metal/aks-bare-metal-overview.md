---
title: What is Azure Kubernetes Service on bare metal? (preview)
description: Learn about Azure Kubernetes Service (AKS) on bare metal, a deployment option that runs Kubernetes directly on hardware without a hypervisor layer.
ms.topic: overview
ms.date: 09/01/2026
author: SummerSmith
ms.author: sumsmith
ms.custom: bare-metal
---

# What is Azure Kubernetes Service on bare metal? (preview)

> [!IMPORTANT]
> Azure Kubernetes Service on bare metal is currently in preview. See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability. Azure Kubernetes Service on bare metal previews are partially covered by customer support on a best-effort basis.

Azure Kubernetes Service (AKS) on bare metal is a deployment option that runs Kubernetes clusters directly on physical hardware without a hypervisor layer. It extends the unified AKS experience to bare metal infrastructure, giving you the same Azure management plane, APIs, and tooling you use with AKS in the cloud - while eliminating virtualization overhead.


## Key benefits

- **No hypervisor overhead** - Run Kubernetes directly on hardware, dedicating all compute resources to your workloads.
- **Unified Azure management** - Create, manage, and monitor clusters through the Azure portal, ARM templates, or Bicep - the same tools you use for AKS everywhere else.
- **Arc-connected** - Clusters are automatically connected to Azure Arc, enabling Azure Policy, Azure Monitor, GitOps, and other Azure services.
- **Consistent Kubernetes experience** - Same core APIs, lifecycle management, and operational tooling as AKS across cloud, hybrid, and edge.

## When to use AKS on bare metal

AKS on bare metal is ideal for scenarios where:

- **Maximum performance matters** - Workloads that can't tolerate hypervisor overhead.
- **Edge and remote locations** - Small-footprint deployments at retail stores, factories, or field sites where a full hyperconverged infrastructure isn't needed.
- **Sovereign and regulated environments** - Deployments that must remain on-premises with full Azure management capabilities.
- **Resource-constrained hardware** - Single-machine deployments where every CPU cycle and byte of memory counts.

## How it works

AKS on bare metal deploys a Kubernetes cluster directly onto an Azure Arc-enabled machine. The deployment creates:
- **Logical Network** — Configures networking with IP pools for the cluster (not needed for single node clusters)
- **AKS cluster** — A fully managed Kubernetes cluster running directly on the hardware

You manage all resources through Azure Resource Manager and see them in the Azure portal.

## Public preview scope

See the [AKS on bare metal preview limitations page](aks-bare-metal-preview-limitations.md) for an overview of what is available during public preview. 

## Next steps

- [System requirements and prerequisites](aks-bare-metal-system-requirements.md)
- [Create a Kubernetes cluster using the Azure portal](aks-bare-metal-create-cluster-portal.md)
