---
title: Compare Azure Linux and Ubuntu for AKS on bare metal
description: Compare infrastructure, host preparation, lifecycle ownership, and cluster management for Azure Linux and Ubuntu on AKS on bare metal.
ms.topic: concept-article
ms.date: 09/14/2026
ai-usage: ai-assisted
author: RishiMody
ms.author: rmody
ms.custom: bare-metal
---

# Compare Azure Linux and Ubuntu for AKS on bare metal

Azure Kubernetes Service (AKS) on bare metal supports Azure Linux and Ubuntu hosts. Choose the host operating system that matches your infrastructure and management model.

| Area | Azure Linux | Ubuntu |
| --- | --- | --- |
| **Infrastructure** | Validated and supported Azure Local small form factor hardware. | Customer-provided hardware that meets the published requirements. |
| **Typical scenario** | New infrastructure. | Existing infrastructure. |
| **Host preparation** | Azure Local provisioning workflow. | You install and prepare Ubuntu, then connect the host to Azure Arc. |
| **Cluster creation** | Azure portal, Azure Resource Manager template, or Bicep. | Azure CLI. |
| **Host OS lifecycle** | Azure Local platform lifecycle. | Customer-managed. |
| **Kubernetes lifecycle** | AKS-managed. | AKS-managed. |
| **Portal experience** | Cluster creation, status, and patch-version upgrades. | Read-only cluster status. Use Azure CLI for lifecycle operations. |

Both options deploy Kubernetes directly on the host operating system without a hypervisor. Both use Azure Arc to connect the host and Kubernetes cluster to Azure.

## Choose Azure Linux

Choose Azure Linux when you want to deploy new, validated Azure Local small form factor hardware. Start with the [Azure Linux system requirements](aks-bare-metal-system-requirements.md), then select a cluster creation method:

- [Azure portal](aks-bare-metal-create-cluster-portal.md).
- [Azure Resource Manager template](aks-bare-metal-create-cluster-arm-template.md).
- [Bicep](aks-bare-metal-create-cluster-bicep.md).

## Choose Ubuntu

Choose Ubuntu when you want to use customer-provided hardware and maintain the host operating system yourself. Start with [System requirements and prepare your Ubuntu host](aks-bare-metal-ubuntu-system-requirements.md), then [create a cluster with Azure CLI](aks-bare-metal-create-cluster-ubuntu-cli.md).

## Next steps

- [Learn how AKS on bare metal works](aks-bare-metal-overview.md#how-it-works).
- [Review the preview limitations](aks-bare-metal-preview-limitations.md).
