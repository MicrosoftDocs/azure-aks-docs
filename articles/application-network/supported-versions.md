---
title: Azure Kubernetes Application Network Supported Versions (Preview)
description: Learn about the supported versions of Azure Kubernetes Application Network, their compatible AKS versions, and how to check available versions in your region.
author: kochhars
ms.author: kochhars
ms.service: azure-kubernetes-app-net
ms.topic: concept-article
ms.date: 10/27/2026
ai-usage: ai-assisted
---

# Azure Kubernetes Application Network supported versions (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Azure Kubernetes Application Network releases minor versions roughly once a quarter. Minor version releases include new features, improvements, and component updates. Each minor version has a specific Istio minor version built in, though consecutive Application Network versions might share the same Istio version. Patch releases include fixes for bugs and security vulnerabilities.

This article lists supported Application Network versions along with their compatible Azure Kubernetes Service (AKS) versions.

## Supported Application Network versions and compatible AKS versions

The following table lists supported Azure Kubernetes Application Network versions, their corresponding Istio versions, compatible AKS versions, and fully managed release channels as of October 27, 2026. Version availability and release-channel mappings vary by region and AKS version. Check [available versions in your region](#list-available-versions-in-your-region) before onboarding or planning an upgrade.

| Application Network version | Istio version | Compatible AKS versions            | Fully managed release channel |
|-----------------------------|---------------|------------------------------------|-------------------------------|
| 1.4                         | 1.29          | 1.31, 1.32, 1.33, 1.34, 1.35, 1.36 | None                          |
| 1.5                         | 1.30          | 1.32, 1.33, 1.34, 1.35, 1.36       | `Stable`                      |
| 1.6                         | 1.31          | 1.32, 1.33, 1.34, 1.35, 1.36       | `Rapid`                       |

For AKS 1.31, only Application Network 1.4 in `SelfManaged` mode is available. No fully managed release channel is available for that AKS version.

> [!IMPORTANT]
> Application Network doesn't manage upgrades of your AKS cluster. To remain in support, select a compatible version during onboarding and upgrade it regularly to maintain compatibility with Application Network. Compatibility with Application Network doesn't extend the AKS version's support lifecycle. Refer to the [AKS Kubernetes release calendar][aks-release-calendar] for AKS version end-of-life dates.

## Retired Application Network versions

Application Network versions 1.0, 1.1, 1.2, and 1.3 are no longer supported. If your member uses one of these versions, see [Configure upgrades for Application Network members](./upgrades.md) to plan an upgrade to a supported version.

For release and retirement announcements, see the [Application Network release notes][appnet-release-notes].

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
[aks-release-calendar]: ../aks/supported-kubernetes-versions.md#aks-kubernetes-release-calendar-and-upcoming-versions
[appnet-release-notes]: https://github.com/Azure/AKS/releases?q=AppNet&expanded=true
