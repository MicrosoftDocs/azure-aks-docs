---
title: Troubleshoot issues in AKS Hybrid and Edge
description: Learn how to troubleshoot various Kubernetes issues in AKS Hybrid and Edge.
ms.topic: how-to
author: davidsmatlak
ms.date: 09/01/2026
ms.author: davidsmatlak
ms.lastreviewed: 07/29/2025
ms.reviewer: srikantsarwa
ms.custom: hyperconverged
---

# Troubleshoot issues in AKS Hybrid and Edge

This section describes how to find solutions for Kubernetes issues you might encounter when using AKS Hybrid and Edge.

## Open a support request

To open a support request, see the [Get support](help-support.md) article for information about how to use the Azure portal to get support or open a support request for AKS.

## Guides to diagnose and troubleshoot Kubernetes CRUD failures

| AKS operation | Issue |
|------------------------|-------|
| General network validation errors | [Troubleshoot network validation errors](network-validation-errors.md) |
| Create validation      | [Control plane configuration validation errors](control-plane-validation-errors.md) |
| Create validation      | [K8sVersionValidation error](cluster-k8s-version.md) |
| Create validation      | [KubeAPIServer unreachable error](kube-api-server-unreachable.md) |
| Network configuration issues | [Use diagnostic checker](aks-arc-diagnostic-checker.md) |
| Kubernetes steady state   | [Resolve issues due to out-of-band deletion of storage volumes](delete-storage-volume.md) |
| Kubernetes steady state   | [Repeated Entra authentication prompts when running kubectl with Kubernetes RBAC](entra-prompts.md) |
| Network validation | [Network validation error due to .local domain](network-validation-error-local.md) |
| Network validation | [Troubleshoot BGP with FRR in AKS environments](connectivity-troubleshoot.md) |
| Disable Windows node pools | [Disable Windows node pools](disable-windows-nodepool.md) | 

## Next steps

[What is AKS Hybrid and Edge?](../../aks-overview.md)
