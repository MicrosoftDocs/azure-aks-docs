---
title: What is Azure Kubernetes Service on bare metal? (preview)
description: Learn how Azure Kubernetes Service on bare metal runs Kubernetes directly on Azure Linux or Ubuntu hosts without a hypervisor.
ms.topic: overview
ms.date: 09/14/2026
ai-usage: ai-assisted
author: SummerSmith
ms.author: sumsmith
ms.custom: bare-metal
---

# What is Azure Kubernetes Service on bare metal? (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Azure Kubernetes Service (AKS) on bare metal deploys Kubernetes directly on a supported host operating system without a hypervisor. The Kubernetes control plane and worker components run on the host hardware, and Azure Arc connects the cluster and host to Azure for management.

## Key benefits

- **No hypervisor overhead**: Run Kubernetes directly on the host operating system and hardware.
- **Azure-connected management**: Use Azure Arc and the AKS resource provider to manage the Kubernetes lifecycle from Azure.
- **Consistent Kubernetes experience**: Use standard Kubernetes APIs and tools to manage workloads.
- **Flexible infrastructure choices**: Deploy on validated Azure Local hardware with Azure Linux or on customer-provided hardware with Ubuntu.

## Choose a host operating system

AKS on bare metal currently supports two host operating systems:

- **Azure Linux** runs on validated and supported Azure Local small form factor hardware. Use this option for a new-infrastructure deployment managed through the Azure Local platform lifecycle. Create clusters by using the Azure portal, an Azure Resource Manager template, or Bicep.
- **Ubuntu** runs on customer-provided hardware that meets the published requirements. Use this option to add AKS to existing infrastructure without reimaging the host. You install, configure, patch, and maintain Ubuntu, while AKS manages the Kubernetes layer. Create and manage clusters by using the Azure CLI extension.

The supported interfaces for cluster creation, upgrade, and deletion differ by host operating system. Follow the procedure for your host option.

For a detailed comparison, see [Compare Azure Linux and Ubuntu](aks-bare-metal-compare-azure-linux-ubuntu.md).

## When to use AKS on bare metal

Use AKS on bare metal when you need to:

- Run workloads without hypervisor overhead.
- Deploy Kubernetes at retail stores, factories, field sites, or other edge locations.
- Keep workloads and data on-premises while managing the Kubernetes layer through Azure.
- Deploy AKS to an existing Ubuntu host or deploy new validated Azure Local hardware.

## How it works

AKS on bare metal has three layers:

- **Azure management and Azure Arc** connect the host and Kubernetes cluster to Azure.
- **The AKS-managed Kubernetes layer** provides the control plane and worker components.
- **The host operating system and hardware layer** provides compute, storage, and networking.

AKS manages the Kubernetes layer for both host options. Host ownership differs: Azure Linux follows the Azure Local platform lifecycle, while you maintain the Ubuntu host operating system and hardware.

## Public preview scope

During public preview, capabilities and limitations can differ between Azure Linux and Ubuntu. See [AKS on bare metal preview limitations](aks-bare-metal-preview-limitations.md) before you deploy.

## Next steps

- [Compare Azure Linux and Ubuntu](aks-bare-metal-compare-azure-linux-ubuntu.md).
- [Review the Azure Linux system requirements](aks-bare-metal-system-requirements.md).
- [Review the Ubuntu system requirements and prepare your host](aks-bare-metal-ubuntu-system-requirements.md).
