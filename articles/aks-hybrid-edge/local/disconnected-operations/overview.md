---
title: AKS on Azure Local with disconnected operations (preview)
description: Learn about Azure Kubernetes Service (AKS) enabled by Azure Arc for Azure Local with disconnected operations (preview), including supported scenarios, prerequisites, and limitations.
ms.topic: overview
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.custom: disconnected-operations
ai-usage: ai-assisted
---

# AKS on Azure Local with disconnected operations (preview)

[!INCLUDE [IMPORTANT](../../includes/aks-disconnected-operations-preview.md)]

[Disconnected operations](/azure/azure-local/manage/disconnected-operations-overview) is an Azure Local capability that you use to deploy and manage Azure Local instances without a connection to the Azure public cloud. Use select Azure Arc-enabled services from a local control plane. Azure Kubernetes Service (AKS) enabled by Azure Arc is one of the services supported for disconnected operations. You get the same familiar Azure portal, Azure CLI, and Azure Resource Manager experience for creating and managing Kubernetes clusters, entirely from the local control plane.

> [!NOTE]
> Disconnected operations is a distinct Azure Local deployment mode with its own local control plane and hardware requirements. It's not the same as the [connectivity modes](../hyperconverged/connectivity-modes.md) that describe how a standard, cloud-connected AKS on Azure Local cluster behaves during a temporary loss of connectivity to Azure.

## Why use disconnected operations for AKS

Use disconnected operations for AKS on Azure Local for scenarios such as:

- **Sovereign requirements and compliance**: Sectors like government, healthcare, and finance often have data residency and sovereignty requirements that are hard to meet by using public sovereign cloud controls. Running disconnected keeps data, operations, and control within your organization's boundaries.
- **Remote or isolated locations**: Sites with limited or no network infrastructure, such as oil rigs or manufacturing floors, can still get an Azure portal and Azure CLI experience for managing Kubernetes clusters without relying on internet connectivity.
- **Security**: Industries with strict security requirements can reduce their attack surface by not exposing systems to external networks.

## How it works

AKS for disconnected operations closely mirrors AKS capabilities on Azure Local: you use the same Azure CLI extensions and largely the same commands to create logical networks, create and manage Kubernetes clusters, and retrieve `kubeconfig` files. The key difference is that the local control plane serves all these operations instead of the Azure public cloud. You maintain a consistent management and operational experience even without internet connectivity.

## Prerequisites

- [Azure Command-Line Interface (CLI)](/azure/azure-local/manage/disconnected-operations-cli) installed on your local machine.
- An Azure subscription associated with disconnected operations.
- Understanding of AKS and Azure Arc concepts.
- Complete [Identity for Azure Local with disconnected operations](/azure/azure-local/manage/disconnected-operations-identity).
- Complete [Networking for Azure Local with disconnected operations](/azure/azure-local/manage/disconnected-operations-network).
- Complete [Public key infrastructure (PKI) for Azure Local with disconnected operations](/azure/azure-local/manage/disconnected-operations-pki).
- Complete [Hardware for Azure Local with disconnected operations](/azure/azure-local/manage/disconnected-operations-overview#eligibility-criteria).
- Complete [Set up for Azure Local with disconnected operations](/azure/azure-local/manage/disconnected-operations-set-up).

## Limitations

Limitations for disconnected operations with AKS include:

- Support for disconnected operations begins with the 2408 release.
- Supported Kubernetes versions: 1.33.4 and 1.33.5.
- Windows node pools aren't supported.
- Microsoft Entra ID (formerly Azure Active Directory) isn't supported for disconnected operations.
- GPUs aren't supported.
- Arc Gateway isn't supported for configuring outbound URLs.
- Create logical networks by using the CLI only. The portal isn't supported.
- Create SSH keys by using the CLI only. The portal isn't supported.

## Related content

- [Create and manage an AKS cluster with disconnected operations](create-manage-cluster.md)
- [What is AKS on Azure Local?](../aks-local-overview.md)
- [Connectivity modes in AKS on Azure Local](../hyperconverged/connectivity-modes.md)
