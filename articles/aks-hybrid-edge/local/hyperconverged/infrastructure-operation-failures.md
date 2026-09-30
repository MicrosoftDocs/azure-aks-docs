---
title: Troubleshoot MOC unreachable errors during AKS on Azure Local cluster or node pool operations
description: Learn how to troubleshoot and recover from infrastructure errors when MOC is unreachable during AKS on Azure Local cluster or node pool creation or deletion.
ms.topic: troubleshooting
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.reviewer: srikantsarwa
ms.custom: hyperconverged

# Customer intent: As an Azure Kubernetes user, I want to troubleshoot the MOC is unreachable error code so that I can successfully create or delete an Azure Kubernetes Service cluster or node pool and avoid infrastructure operation failures.
---

# Troubleshoot the MOC is unreachable error during cluster or node pool operations

This article describes how to identify and resolve a Microsoft On-premises Cloud (MOC) error. The "MOC is unreachable" error can occur when you try to create or delete a Microsoft Azure Kubernetes Service (AKS) cluster or node pool on Azure Local.

## Symptoms

When you try to create or delete an AKS cluster or node pool, you receive one of the following error messages:

```output
AksArc creation failed because MOC is unreachable. Read aka.ms/aksarc-moc-unreachable for more information. Detailed message: <detailed message>

AksArc cluster infrastructure deletion failed because MOC is unreachable. Read aka.ms/aksarc-moc-unreachable for more information. Detailed message: <detailed message>

AksArc nodepool infrastructure deletion failed because MOC is unreachable. Read aka.ms/aksarc-moc-unreachable for more information. Detailed message: <detailed message>

MOC deletion failed because it is unreachable. Read aka.ms/aksarc-moc-unreachable for more information. Detailed message: <detailed message>
```

## Cause

The Microsoft On-premises Cloud (MOC) service that manages the on-premises virtual machines and infrastructure for your AKS cluster is offline or unreachable. Because the operation can't reach MOC, the underlying infrastructure (virtual machines, networks, and disks) can't be created or cleaned up.

> [!IMPORTANT]
> Don't force-delete the Azure resource to work around this error. Force-deleting removes only the Azure Resource Manager (ARM) resource and leaves the on-premises virtual machines and infrastructure orphaned. You must restore MOC and retry the operation so the infrastructure is managed correctly.

## Possible causes and follow-ups

- The MOC cloud agent (`wssdcloudagent`) service isn't running, or multiple instances are running on the cluster.
- The MOC node agents (`wssdagent`) aren't installed or running on one or more nodes.
- MOC certificates or identity tokens are expired or corrupted.
- The MOC PowerShell configuration is corrupted or stuck in an **Updating** state.
- Azure Local nodes aren't in an **Active** state, or the node list is out of sync with the cluster.

## Use the `Support.AksArc` module to diagnose and remediate

The `Support.AksArc` module is a PowerShell-based tool that diagnoses and remediates common AKS on Azure Local issues, including MOC service failures. Run the module to detect why MOC is unreachable and apply the recommended remediation, then retry the operation.

For installation and usage steps, see [Support.AksArc diagnostic and remediation tool](support-module.md).

## Contact Microsoft Support

If the problem persists after restoring MOC, collect the [AKS cluster logs](get-on-demand-logs.md) before you [create a support request](aks-troubleshoot.md#open-a-support-request).

## Next steps

- [Use the Support.AksArc diagnostic and remediation tool](support-module.md)
- [Review AKS on Azure Local architecture](cluster-architecture.md)
- [Review networking prerequisites for AKS on Azure Local](network-system-requirements.md)
