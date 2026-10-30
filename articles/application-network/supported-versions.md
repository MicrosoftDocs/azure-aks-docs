---
title: Azure Kubernetes Application Network Supported Versions (Preview)
description: Learn about the supported versions of Azure Kubernetes Application Network, their compatible AKS versions, and how to check available versions in your region.
author: kochhars
ms.author: kochhars
ms.service: azure-kubernetes-app-net
ms.topic: concept-article
ms.date: 10/30/2026
ai-usage: ai-assisted
---

# Azure Kubernetes Application Network supported versions (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Azure Kubernetes Application Network releases minor versions roughly once a quarter. Minor version releases include new features, improvements, and component updates. Each minor version has a specific Istio minor version built in, though consecutive Application Network versions might share the same Istio version. Patch releases include fixes for bugs and security vulnerabilities.

This article lists Application Network versions, their support lifecycle, and their compatible Azure Kubernetes Service (AKS) versions.

## Supported Application Network versions and compatible AKS versions

The following table lists Azure Kubernetes Application Network versions, their corresponding Istio versions, end-of-life information, compatible AKS versions, and fully managed release channels. Recently retired versions remain in the table for reference and are no longer supported. Version availability and release-channel mappings vary by region and AKS version. Check [available versions in your region](#list-available-versions-in-your-region) before onboarding or planning an upgrade.

| Application Network version | Istio version | End of life          | Compatible AKS versions            | Fully managed release channel |
|-----------------------------|---------------|----------------------|------------------------------------|-------------------------------|
| 1.1 (retired)               | 1.26          | April 2026           | 1.30, 1.31, 1.32, 1.33, 1.34       | None                          |
| 1.2 (retired)               | 1.27          | May 2026             | 1.30, 1.31, 1.32, 1.33, 1.34, 1.35 | None                          |
| 1.3 (retired)               | 1.28          | Sept 2026            | 1.30, 1.31, 1.32, 1.33, 1.34, 1.35 | None                          |
| 1.4                         | 1.29          | Not confirmed        | 1.31, 1.32, 1.33, 1.34, 1.35, 1.36 | None                          |
| 1.5                         | 1.30          | ~Dec 2026 (expected) | 1.32, 1.33, 1.34, 1.35, 1.36, 1.37 | `Stable`                      |
| 1.6                         | 1.31          | Not confirmed        | 1.32, 1.33, 1.34, 1.35, 1.36, 1.37 | `Rapid`                       |

End-of-life dates marked *expected* are estimates of *earliest possible* retirement, not confirmed dates.

`SelfManaged` mode offers two or three supported Application Network versions at a time. An individual member might have fewer compatible versions available, depending on its AKS version and region.

`FullyManaged` mode uses the `Rapid` and `Stable` release channels instead of selecting a version directly. The channels offer two supported versions when they target different versions, or one when they target the same version. A channel is available to a member only if its target version is compatible with the member's AKS version.

> [!IMPORTANT]
> Application Network doesn't manage upgrades of your AKS cluster. To remain in support, select a compatible version during onboarding and upgrade it regularly to maintain compatibility with Application Network. Compatibility with Application Network doesn't extend the AKS version's support lifecycle. Refer to the [AKS Kubernetes release calendar][aks-release-calendar] for AKS version end-of-life dates.

## List available versions in your region

- List the available versions in your region using the [`az appnet list-versions`][az-appnet-list-versions] command.

    ```azurecli-interactive
    az appnet list-versions --location $LOCATION -o table
    ```

    You can also use the [`az appnet list-versions`][az-appnet-list-versions] command to check which version each release channel corresponds to for Azure Kubernetes Application Network members enrolled in [`FullyManaged` upgrade mode](./upgrades.md#fully-managed-mode).

## Related content

For more information about Application Network version selection or keeping your member automatically up-to-date, see [Configure upgrades for Azure Kubernetes Application Network members](./upgrades.md).

For release and retirement announcements, see the [Application Network release notes][appnet-release-notes].

<!--- LINKS --->
[az-appnet-list-versions]: /cli/azure/appnet#az-appnet-list-versions
[aks-release-calendar]: ../aks/supported-kubernetes-versions.md#aks-kubernetes-release-calendar-and-upcoming-versions
[appnet-release-notes]: https://github.com/Azure/AKS/releases?q=AppNet&expanded=true
