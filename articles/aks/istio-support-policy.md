---
title: Support policy for Istio-based service mesh add-on for Azure Kubernetes Service
description: Support policy for Istio-based service mesh add-on for Azure Kubernetes Service
ms.topic: article
ms.service: azure-kubernetes-service
ms.date: 08/02/2024
ms.author: kochhars
author: sanyakochhar
ms.custom: devx-track-azurecli
---
# Support policy for Istio-based service mesh add-on for Azure Kubernetes Service

This article outlines the support policy for the Istio-based service mesh add-on for Azure Kubernetes Service (AKS).

Announcements about the releases of new minor revisions or patches to the Istio-based service mesh add-on are published in the [AKS release notes][aks-release-notes].

## Service mesh add-on release calendar

The Istio-based service mesh add-on release calendar indicates each revision's AKS compatibility, and estimated dates of upcoming releases and revision deprecation.

Releases are rolled out as part of AKS releases. To see real-time updates of region release status and AKS release notes containing updates about Istio revision support, visit the [AKS release status webpage][aks-release].

To learn more about support and compatibility for service mesh add-on versions, read the [versioning and support policy](./istio-support-policy.md#versioning-and-support-policy).

|  Service mesh revision | Upstream release  | AKS release  | End of life | Compatible AKS versions |
|--------------|-------------------|--------------|---------|-------------|-----------------------|
| asm-1-17 | Feb 2023 | Apr 2023 | Jan 2024 | 1.23, 1.24, 1.25, 1.26, 1.27, 1.28 |
| asm-1-18 | Jun 2023 | Nov 2023 | Feb 2024 | 1.24, 1.25, 1.26, 1.27, 1.28 |
| asm-1-19 | Sept 2023 | Jan 2024 | Jun 2024 | 1.25, 1.26, 1.27, 1.28 |
| asm-1-20 | Nov 2023 | Feb 2024 | TBD | 1.25, 1.26, 1.27, 1.28, 1.29 |
| asm-1-21 | Mar 2024 | Apr 2024 | TBD | 1.26, 1.27, 1.28, 1.29, 1.30 |
| asm-1-22 | May 2024 | Jul 2024 | TBD | 1.27, 1.28, 1.29, 1.30 |


## Versioning and support policy

### Supported revisions
At any given time, at least two revisions of the Istio-based service mesh add-on are supported. An older revision `n-2` will continue to be supported until six weeks after the newest revision `n` has started rolling out to all regions. 
    
For example, if `asm-1-22` just started rolling out to all regions, `asm-1-20` will be deprecated after six weeks.

### Default revision
If a revision isn't provided during installation, the `n-1`'st revision is installed by default. For example, if `asm-1-22` is the latest revision, the default is `asm-1-21`.

### AKS compatibility
Each revision of the add-on is compatible with a set of AKS minor versions established by the [upstream Istio support and release calendar][istio-support-calendar]. For certain revisions, additional AKS minor versions may be supported as well.

## Next steps

* [Deploy Istio-based service mesh add-on][istio-deploy-addon]
* [Upgrade Istio-based service mesh add-on][istio-upgrade]

<!-- LINKS - External -->
[aks-release-notes]: https://github.com/Azure/AKS/releases
[aks-release]: https://releases.aks.azure.com/
[istio-support-calendar]: https://istio.io/latest/docs/releases/supported-releases/#support-status-of-istio-releases

<!-- LINKS - Internal -->
[istio-deploy-addon]: ./istio-deploy-addon.md
[istio-upgrade]: ./istio-upgrade.md