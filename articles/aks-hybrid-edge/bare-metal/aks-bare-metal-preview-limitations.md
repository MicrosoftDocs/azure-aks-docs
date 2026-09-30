---
title: Public preview limitations for AKS on bare metal (preview)
description: Known limitations and scope for the Azure Kubernetes Service on bare metal public preview.
ms.topic: concept-article
ms.date: 09/14/2026
ai-usage: ai-assisted
author: SummerSmith
ms.author: sumsmith
ms.custom: bare-metal
---

# Public preview limitations (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

This article lists the known limitations and scope boundaries for the AKS on bare metal public preview.

## Supported scope

| Area | Azure Linux | Ubuntu |
| --- | --- | --- |
| **Host infrastructure** | Validated Azure Local small form factor hardware. | Customer-provided hardware that meets the published requirements. |
| **Host operating system** | Azure Linux 3.0. | Ubuntu 24.04.3 LTS or 24.04.4 LTS. |
| **Processor architecture** | x86_64. | x86_64. |
| **Cluster topology** | Single-node cluster. | Single-node cluster, with one cluster per host. |
| **Kubernetes version** | Kubernetes 1.34. | Kubernetes 1.33.3 by default. See [Supported Kubernetes versions](aks-bare-metal-create-cluster-ubuntu-cli.md#supported-kubernetes-versions) for the versions and parameter values available during deployment. |
| **Cluster creation** | Azure portal, Azure Resource Manager template, or Bicep. | Azure CLI |
| **Patch-version upgrades** | Azure portal. | Azure CLI. |
| **Cluster deletion** | Ordered Azure resource deletion. | Use Azure CLI for structured deletion of cluster and dependent resources. |
| **Portal experience** | Cluster creation, status, and patch-version upgrades. | Read-only cluster status. |
| **Cluster access** | `az connectedk8s proxy`. | `az connectedk8s proxy` or `az aksarc get-credentials`. |
| **Container networking** | Cilium CNI. | Cilium CNI. |

## Known limitations

| Limitation | Azure Linux | Ubuntu |
| --- | --- | --- |
| **Multi-node clusters and scaling** | Not supported. | Not supported. |
| **Multiple clusters per host** | Not supported. | Not supported. |
| **Region** | East US only. | East US only. |
| **Kubernetes upgrades** | Patch-version upgrades only. | Patch-version upgrades only. |
| **Cluster creation through the Azure portal** | Supported. | Not supported. Use Azure CLI. |
| **Cluster creation with ARM or Bicep** | Supported. | Not supported. Use Azure CLI. |
| **Host OS lifecycle** | Use the Azure Local platform lifecycle. | Customer-managed. |

### Ubuntu 24.04.5 LTS isn't supported yet

AKS on bare metal doesn't currently support Ubuntu 24.04.5 LTS. Support is planned for a future update. Until support is available, use Ubuntu 24.04.3 LTS or 24.04.4 LTS.

## Transition to general availability

> [!IMPORTANT]
> Clusters you create during the public preview might not support an in-place upgrade to the generally available version. When general availability is released, you might need to delete and recreate your cluster. Plan to back up and redeploy your workloads.

## Billing

AKS on bare metal public preview uses **zero-rated billing meters**. There are no charges for the AKS cluster resources during the preview period. Standard Azure charges for the underlying Arc-enabled machine and any Azure services (Monitor, Policy, and so on) still apply.

## Support

Customer support provides **best-effort** assistance for public preview features. Preview features:

- Aren't recommended for production workloads.
- Might have limited or no SLA.
- Might introduce breaking changes before GA.
- Might be deprecated or removed.

## Next steps

- [Compare Azure Linux and Ubuntu](aks-bare-metal-compare-azure-linux-ubuntu.md).
- [Review the Azure Linux system requirements](aks-bare-metal-system-requirements.md).
- [Review the Ubuntu system requirements](aks-bare-metal-ubuntu-system-requirements.md).
