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

## Versioning and support policy

### Service mesh add-on release calendar

The Istio-based service mesh add-on release calendar indicates each revision's AKS compatibility and estimated release and deprecation dates.

New minor revisions and patches are rolled out as part of AKS releases. Announcements about the releases of new minor revisions or patches to the Istio-based service mesh add-on are published in the [AKS release notes][aks-release-notes]. To see real-time updates of regional release status and AKS release notes containing updates about Istio revision support, visit the [AKS release status webpage][aks-release-status].

To learn more about support and compatibility for service mesh add-on revisions, read the [versioning and support policy](./istio-support-policy.md#versioning-and-support-policy).

|  Service mesh revision | Upstream release  | AKS release  | End of life | Compatible AKS versions |
|--------------|-------------------|--------------|---------|-------------|-----------------------|
| asm-1-17 | Feb 2023 | Apr 2023 | Jan 2024 | 1.23, 1.24, 1.25, 1.26, 1.27, 1.28 |
| asm-1-18 | Jun 2023 | Nov 2023 | Feb 2024 | 1.24, 1.25, 1.26, 1.27, 1.28 |
| asm-1-19 | Sept 2023 | Jan 2024 | Jun 2024 | 1.25, 1.26, 1.27, 1.28 |
| asm-1-20 | Nov 2023 | Feb 2024 | Sept 2024 | 1.25, 1.26, 1.27, 1.28, 1.29 |
| asm-1-21 | Mar 2024 | Apr 2024 | Oct 2024 | 1.26, 1.27, 1.28, 1.29, 1.30 |
| asm-1-22 | May 2024 | Jul 2024 | ~Feb 2025 (expected) | 1.27, 1.28, 1.29, 1.30 |
| asm-1-23 | Aug 2024 | Sept 2024 | ~June 2025 (expected) | 1.27, 1.28, 1.29, 1.30, 1.31 |

### Supported revisions
- **Minor revision**:
    - At any given time, at least two revisions of the Istio-based service mesh add-on are supported.
    - An older revision `n-2` will continue to be supported until six weeks after the newest revision `n` starts rolling out to all regions. For example, if `asm-1-22` just started rolling out to all regions, `asm-1-20` will be deprecated after six weeks.
    - Deprecation means no new mesh installations can be done with this revision. While clusters already having this revision continue to work, for support issues and security patches, it is recommended to [upgrade to a newer supported mesh revision][istio-minor-upgrade].
    
- **Patch version**: 
    - Patches to Istio control plane (istiod) and Istio ingresses are rolled out as part of AKS releases. User is expected to follow AKS release notes on availability of newer patch versions and to then [upgrade istio-proxy sidecars by restarting their workloads][istio-patch-upgrade].
    - AKS reserves the right to deprecate patches if a critical Common Vulnerability and Exposure (CVE) or security vulnerability is detected. For awareness on patch availability and any ad-hoc deprecation, refer to [AKS release notes][aks-release-notes] and visit the [AKS release status webpage][aks-release-status].
    
    
### Default revision
If a revision isn't explicitly provided by user during installation, the `n-1` revision is installed by default. For example, if `asm-1-22` is the latest revision, the default is `asm-1-21`.

### AKS compatibility
Each revision of the add-on is compatible with a set of AKS minor versions established by the [upstream Istio support and release calendar][istio-support-calendar].

## Allowed, supported, and blocked customizations

The Istio-based service mesh add-on for AKS designates features and [configuration options][istio-meshconfig] as `allowed`, `supported`, or `blocked`.

- **Blocked**: Disallowed features and configuration options are blocked via add-on managed admission webhooks. The API server immediately publishes the error message to the user that the feature is disallowed.
- **Supported**: Supported features receive support from Azure support.
- **Allowed**: Allowed features are open and available to Istio add-on users but aren't covered by Azure support.

## Next steps

* [Deploy Istio-based service mesh add-on][istio-deploy-addon]
* [Upgrade Istio-based service mesh add-on][istio-upgrade]

<!-- LINKS - External -->
[aks-release-notes]: https://github.com/Azure/AKS/releases
[aks-release-status]: https://releases.aks.azure.com/
[istio-support-calendar]: https://istio.io/latest/docs/releases/supported-releases/#support-status-of-istio-releases

<!-- LINKS - Internal -->
[istio-deploy-addon]: ./istio-deploy-addon.md
[istio-upgrade]: ./istio-upgrade.md
[istio-minor-upgrade]: ./istio-upgrade.md#minor-revision-upgrade
[istio-patch-upgrade]: ./istio-upgrade.md#patch-version-upgrade
[istio-meshconfig]: ./istio-meshconfig.md#allowed-supported-and-blocked-meshconfig-values