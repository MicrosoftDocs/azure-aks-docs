---
title: AKS Cluster unhealthy after Kubernetes Upgrade
description: Learn how to troubleshoot and mitigate an issue that causes AKS cluster to become unhealthy after Kubernetes upgrade
ms.topic: troubleshooting
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.lastreviewed: 1/13/2026
ms.custom: hyperconverged
---

# AKS cluster becomes unhealthy after upgrading to Kubernetes v1.31 with Azure Policy or Gatekeeper enabled

After upgrading an AKS cluster to Kubernetes v1.31 or later, the cluster might enter a degraded or unhealthy state.

## Symptoms

The degraded or unhealthy state is observed when Azure Policy or Gatekeeper is enabled.

Cluster operations like reconciliation, upgrades, or certificate rotation might fail or behave unexpectedly.

## Cause

In Kubernetes v1.31 and later, certain update and reconciliation paths interact incorrectly with Azure Policy and Gatekeeper.

This issue occurs during upgrades or certificate reconciliation:

- Kubernetes version upgrades (for example, v1.30 to v1.31).
- Automated update mechanisms like the 45-day Workload Identity Federation (WLIF) certificate rotation.

When Azure Policy or Gatekeeper is enabled, these updates can cause the control plane to enter a degraded state.

## Affected configurations

- AKS clusters with Kubernetes version v1.31 and later.
- Azure Policy and/or Gatekeeper enabled.

## Workaround

Until a permanent fix is available, use one of the following mitigations.

### Option 1: Temporarily disable Azure Policy (recommended)

Disable Azure Policy on the affected cluster before you do the following tasks:

- Kubernetes version upgrades.
- Any operation that might trigger control plane updates, like certificate rotation.

Azure Policy can be re-enabled after the Kubernetes version is updated and the cluster returns to a healthy state.

### Option 2: Update Gatekeeper policies

If Gatekeeper is enabled, update the Gatekeeper constraint templates and policies to ensure compatibility with Kubernetes v1.31 behavior.

> [!NOTE]
> This workaround might be customer-specific and might not apply in all environments.

## Resolution

This issue is currently under investigation, and a permanent fix is in progress.

Until the fix is fully validated and released, customers are advised to follow the recommended workarounds described in this article. This page is updated as more guidance becomes available.

## Next steps

- If you're planning to upgrade to Kubernetes v1.31 or later, review your cluster configuration, and apply the recommended mitigations before proceeding.
- If your cluster is already affected, apply one of the workarounds and contact Microsoft Support if assistance is required.
