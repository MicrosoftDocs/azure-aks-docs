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

This article identifies known issues and their workarounds in AKS. These release notes are continuously updated, and as issues that require a workaround are discovered, they're added here.

If you encounter an issue that isn't listed here, please [open a support request](help-support.md).

## Known issues

The following section describes known issues for AKS Hybrid and Edge:

| AKS CRUD operation | Issue | Fix status |
|------------------------|-------|------------|
| AKS cluster upgrade    | [Cluster with Azure Policy or Gatekeeper unhealthy after upgrade](cluster-unhealthy-after-kubernetes-upgrade.md)|Active|
| AKS cluster create     | [Cluster create fails after Azure Local update from 2510](cluster-create-fails-after-azure-local-upgrade.md)|Active|
| AKS cluster create     | [Can't create AKS cluster with GPU-enabled default node pool](gpu-enabled-cluster-issue.md)|Active|
| AKS steady state       | [Storage provisioning issue impacting cluster and node pool creation](storage-provision-issue.md)|Active|
| AKS cluster delete     | [Deleted AKS cluster still visible on Azure portal](deleted-cluster-visible.md) | Active |
| AKS steady state       | [Disk space exhaustion on control plane VMs due to accumulation of kube-apiserver audit logs](kube-apiserver-log-overflow.md) | Fixed in 2507 release |
| AKS cluster upgrade    | [AKS cluster stuck in "Upgrading" state](cluster-upgrade-status.md) | Fixed in 2505 release |

## Next steps

- [What is AKS Hybrid and Edge?](../../aks-overview.md)
