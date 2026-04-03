---
title: Azure Kubernetes Application Network Supported Versions (Preview)
description: Learn about the supported versions of Azure Kubernetes Application Network, their compatible AKS versions, and how to check available versions in your region.
author: kochhars
ms.author: kochhars
ms.service: azure-kubernetes-app-net
ms.topic: concept-article
ms.date: 03/05/2026
---

# Azure Kubernetes Application Network supported versions (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Azure Kubernetes Application Network releases minor versions roughly once a quarter. Minor version releases include new features, improvements and component updates. Each minor version has a specific Istio minor version built in, though consecutive Application Network versions might share the same Istio version. Patch releases include fixes for bugs and security vulnerabilities.

This article lists available Application Network versions along with their compatible AKS versions.

## Supported Application Network versions and compatible AKS versions

The following table outlines available Azure Kubernetes Application Network versions, their corresponding Istio versions, end-of-life dates, and compatible AKS versions:

| Application Network version | Istio version | End of life          | Compatible AKS versions                   |
|-----------------------------|---------------|----------------------|-------------------------------------------|
| 1.1                         | 1.26          | March 2026           | 1.29, 1.30, 1.31, 1.32, 1.33, 1.34        |
| 1.2                         | 1.27          | ~May 2026 (expected) | 1.29, 1.30, 1.31, 1.32, 1.33, 1.34, 1.35  |
| 1.3                         | 1.28          | ~Aug 2026 (expected) | 1.30, 1.31, 1.32, 1.33, 1.34, 1.35        |
| 1.4                         | 1.29          | ~Sep 2026 (expected) | 1.31, 1.32, 1.33, 1.34, 1.35              |

## List available versions in your region

- List the available versions in your region using the [`az appnet list-versions`][az-appnet-list-versions] command.

    ```azurecli-interactive
    az appnet list-versions --location $LOCATION -o table
    ```

    You can also use the [`az appnet list-versions`][az-appnet-list-versions] command to check which version each release channel corresponds to for Azure Kubernetes Application Network members enrolled in [`FullyManaged` upgrade mode](./upgrades.md#fully-managed-mode).

## Related content

For more information about Application Network version selection or keeping your member automatically up-to-date, see [Configure upgrades for Azure Kubernetes Application Network members](./upgrades.md).

<!--- LINKS --->
[az-appnet-list-versions]: /cli/azure/appnet#az-appnet-list-versions
