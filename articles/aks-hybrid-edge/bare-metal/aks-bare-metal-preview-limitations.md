---
title: Public preview limitations for AKS on bare metal (preview)
description: Known limitations and scope for the Azure Kubernetes Service on bare metal public preview.
ms.topic: concept-article
ms.date: 09/01/2026
author: SummerSmith
ms.author: sumsmith
ms.custom: bare-metal
---

# Public preview limitations (preview)

> [!IMPORTANT]
> Azure Kubernetes Service on bare metal is currently in preview. For legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability, see the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/). Azure Kubernetes Service on bare metal previews are partially covered by customer support on a best-effort basis.

This article lists the known limitations and scope boundaries for the AKS on bare metal public preview.

## Supported scope

| Feature | Status |
|---------|--------|
| Single-node clusters | ✅ Supported |
| Cluster creation via Azure portal | ✅ Supported |
| Cluster creation via Bicep | ✅ Supported |
| Cluster creation via ARM template | ✅ Supported |
| Kubernetes 1.34.2 | ✅ Supported |
| Kubernetes 1.34.3 | ✅ Supported |
| Small form factor Azure Local host | ✅ Supported |
| Azure Arc connectivity | ✅ Supported |
| Azure RBAC for Kubernetes | ✅ Supported |
| Cilium CNI | ✅ Supported |
| Cluster upgrades (patch versions) | ✅ Supported |
| `az connectedk8s proxy` for cluster access | ✅ Supported |

## Billing

AKS on bare metal public preview uses **zero-rated billing meters**. There are no charges for the AKS cluster resources during the preview period. Standard Azure charges for the underlying Arc-enabled machine and any Azure services (Monitor, Policy, and so on) still apply.

## Support

Customer support provides **best-effort** assistance for public preview features. Preview features:

- Aren't recommended for production workloads.
- Might have limited or no SLA.
- Might introduce breaking changes before GA.
- Might be deprecated or removed.

## Next steps

- [What is AKS on bare metal?](aks-bare-metal-overview.md)
- [System requirements and prerequisites](aks-bare-metal-system-requirements.md)
