---
title: Troubleshoot known issues in AKS Hybrid and Edge
description: Learn about known issues and workarounds in AKS Hybrid and Edge.
ms.topic: how-to
author: davidsmatlak
ms.date: 09/01/2026
ms.author: davidsmatlak
ms.lastreviewed: 02/11/2026
ms.custom: hyperconverged

---

# Known issues in AKS Hybrid and Edge

This article identifies known issues and their workarounds in AKS. These release notes are continuously updated, and as you discover issues that require a workaround, add them here.

If you encounter an issue that isn't listed here, [open a support request](help-support.md).

> [!IMPORTANT]
> AKS on Azure Local is supported only when the underlying Azure Local instance is within its six-month support window. If your Azure Local version falls out of support, update to a supported version before troubleshooting further. For details, see [End of support for Azure Local versions](/azure/azure-local/release-information-23h2#end-of-support-for-azure-local-versions) and [AKS on Azure Local support policies](aks-on-azure-local-support-policy.md#azure-local-version-support-window).

## Known issues

The following section describes known issues for AKS Hybrid and Edge:

| AKS CRUD operation | Issue | Fix status |
|------------------------|-------|------------|
| AKS cluster upgrade    | [Cluster with Azure Policy or Gatekeeper unhealthy after upgrade](cluster-unhealthy-after-kubernetes-upgrade.md)|Active|
| AKS cluster create     | [Cluster create fails after Azure Local update from 2510](cluster-create-fails-after-azure-local-upgrade.md)|Active|
| AKS cluster create     | [Can't create AKS cluster with GPU-enabled default node pool](gpu-enabled-cluster-issue.md)|Active|
| AKS cluster delete     | [Deleted AKS cluster still visible on Azure portal](deleted-cluster-visible.md) | Active |

## Next steps

- [What is AKS Hybrid and Edge?](../../aks-overview.md)
- [Support policies for AKS on Azure Local](aks-on-azure-local-support-policy.md)
- [Impact to clusters when Arc resource bridge is deleted or recovered](azure-arc-resource-bridge-deleted-recovered.md)
