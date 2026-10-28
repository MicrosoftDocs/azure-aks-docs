---
title: Entra authentication prompts when running kubectl with Kubernetes RBAC
description: Learn how to troubleshoot Entra authentication issues when using kubectl with Kubernetes RBAC.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: troubleshooting
ms.date: 09/01/2026
ms.reviewer: leslielin
ms.lastreviewed: 06/24/2025
ms.custom: hyperconverged

---

# Repeated Entra authentication prompts when running kubectl with Kubernetes RBAC

This article helps you diagnose and resolve issues related to repeated Entra authentication prompts when using **kubectl** with Kubernetes RBAC on AKS Hybrid and Edge.

## Symptoms

When you use **kubectl** with [Microsoft Entra authentication and Kubernetes RBAC](kubernetes-rbac-local.md) in AKS on Azure Local, Entra authentication prompts appear after each command execution.

## Possible causes

This issue is caused by [a GitHub bug](https://github.com/Azure/kubelogin/issues/654) introduced in **kubelogin** version 0.2.0 and later.

## Mitigation

To mitigate this issue, you can use one of the following two methods:

- Downgrade **kubelogin** to version 0.1.9. This stable version does not have the bug that causes repeated authentication prompts. You can [download this version from the GitHub repository](https://github.com/Azure/kubelogin/releases/tag/v0.1.9). Select the appropriate asset for your OS or architecture, extract it, and replace your existing **kubelogin** binary.
- Alternatively, if you have administrator permissions, you can use the `--admin` flag with the `az aksarc get-credentials` command. This method bypasses **kubelogin** authentication by retrieving admin credentials directly:

  ```azurecli
  az aksarc get-credentials -g $resource_group_name -n $aks_cluster_name --file <file-name> --admin
  ```

## Next steps

[Troubleshoot issues in AKS Hybrid and Edge](aks-troubleshoot.md)
