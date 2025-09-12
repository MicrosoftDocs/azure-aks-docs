---
title: Support policy for Istio-based service mesh add-on for Azure Kubernetes Service
description: Support policy for Istio-based service mesh add-on for Azure Kubernetes Service
ms.topic: concept-article
ms.service: azure-kubernetes-service
ms.date: 08/02/2024
ms.author: kochhars
author: sanyakochhar
ms.custom: devx-track-azurecli
# Customer intent: As a cloud engineer managing microservices on Kubernetes, I want to understand the support and compatibility policies for the Istio-based service mesh add-on, so that I can ensure my deployments are secure and compliant with the latest updates.
---
# Support policy for Istio-based service mesh add-on for Azure Kubernetes Service

This article outlines the support policy for the Istio-based service mesh add-on for Azure Kubernetes Service (AKS).

## Versioning and support policy

### Service mesh add-on release calendar

The Istio-based service mesh add-on release calendar indicates each revision's AKS compatibility and estimated release and deprecation dates.

New minor revisions and patches are rolled out as part of AKS releases. Announcements about the releases of new minor revisions or patches to the Istio-based service mesh add-on are published in the [AKS release notes][aks-release-notes]. To see real-time updates of regional release status and AKS release notes containing updates about Istio revision support, visit the [AKS release status webpage][aks-release-status].

|  Service mesh revision | Upstream release  | AKS release  | End of life | Compatible AKS versions | Compatible AKS LTS versions |
|--------------|-------------------|--------------|---------|-------------|-----------------------|-----------------------|
| asm-1-17 | Feb 2023 | Apr 2023 | Jan 2024 | 1.23, 1.24, 1.25, 1.26, 1.27, 1.28 | |
| asm-1-18 | Jun 2023 | Nov 2023 | Feb 2024 | 1.24, 1.25, 1.26, 1.27, 1.28 | |
| asm-1-19 | Sept 2023 | Jan 2024 | Jun 2024 | 1.25, 1.26, 1.27, 1.28 | |
| asm-1-20 | Nov 2023 | Feb 2024 | Sept 2024 | 1.25, 1.26, 1.27, 1.28, 1.29 | |
| asm-1-21 | Mar 2024 | Apr 2024 | Oct 2024 | 1.26, 1.27, 1.28, 1.29, 1.30 | |
| asm-1-22 | May 2024 | Jul 2024 | March 2025 | 1.27, 1.28, 1.29, 1.30 | |
| asm-1-23 | Aug 2024 | Sept 2024 | June 2025 | 1.27, 1.28, 1.29, 1.30, 1.31, 1.32 | |
| asm-1-24 | Nov 2024 | Feb 2025 | Sep 2025 | 1.28, 1.29, 1.30, 1.31, 1.32, 1.33 | |
| asm-1-25 | Mar 2025 | May 2025 | ~Jan 2026 (expected) | 1.29, 1.30, 1.31, 1.32, 1.33 | 1.28, 1.29, 1.30, 1.31, 1.32, 1.33 |
| asm-1-26 | May 2025 | July 2025 | ~Feb 2026 (expected) | 1.29, 1.30, 1.31, 1.32, 1.33, 1.34 | 1.28, 1.29, 1.30, 1.31, 1.32, 1.33, 1.34 |
| asm-1-27 | Aug 2025 | ~Sept 2025 (expected EOM) | ~May 2026 (expected) | 1.29, 1.30, 1.31, 1.32, 1.33, 1.34 | 1.29, 1.30, 1.31, 1.32, 1.33, 1.34 |

If using an AKS [long term-support (LTS) cluster][aks-lts], a newer revision may be declared as compatible when a previous compatible Istio revision reaches end of life before the AKS LTS version's end of life. For more details, read Istio's [AKS compatibility policy](#aks-compatibility).

### Supported revisions
- **Minor revision**:
    - At any given time, at least two revisions of the Istio-based service mesh add-on are supported.
    - An older revision `n-2` will continue to be supported until six weeks after the newest revision `n` starts rolling out to all regions. For example, if `asm-1-22` just started rolling out to all regions, `asm-1-20` will be deprecated after six weeks.
    - Deprecation means no new mesh installations can be done with this revision. While clusters already having this revision continue to work, for support issues and security patches, it's recommended to [upgrade to a newer supported mesh revision][istio-minor-upgrade].
    
- **Patch version**: 
    - Patches to Istio control plane (istiod) and Istio ingresses are rolled out as part of AKS releases. User is expected to follow AKS release notes on availability of newer patch versions and to then [upgrade istio-proxy sidecars by restarting their workloads][istio-patch-upgrade].
    - AKS reserves the right to deprecate patches if a critical Common Vulnerability and Exposure (CVE) or security vulnerability is detected. For awareness on patch availability and any ad-hoc deprecation, refer to [AKS release notes][aks-release-notes] and visit the [AKS release status webpage][aks-release-status].
    
    
### Default revision
If a revision isn't explicitly provided by user during installation, the `n-1` revision is installed by default. For example, if `asm-1-22` is the latest revision, the default is `asm-1-21`.

### AKS compatibility
Each revision of the add-on is compatible with a set of AKS minor versions established by the [upstream Istio support and release calendar][istio-support-calendar].

**AKS LTS clusters may be compatible with additional revisions beyond upstream Istio's support table.** For Istio revisions `asm-1-25`+ and AKS LTS versions 1.28+, every supported AKS LTS version will have _at least one_ compatible Istio revision. 

To check the compatible AKS versions for an Istio revision, use the command [`az aks mesh get-revisions`][az-aks-mesh-get-revisions]:

```azurecli-interactive
az aks mesh get-revisions --location <location> -o table
```

This command has been updated to include separate `CompatibleWith` outputs for `KubernetesOfficial` (standard tier) and `AKSLongTermSupport`, replacing the earlier response that only included `kubernetes` (standard tier).

If using the Azure portal to enable the Istio add-on for an existing cluster, the available Istio revisions will be filtered based on the cluster's tier.

Each Istio add-on revision follows upstream lifecycle for end of life and patch availability. This means:
1. Every Istio revision will not be compatible with every AKS LTS version, but every AKS LTS version will be compatible with at least one Istio add-on revision.

1. If an Istio revision reaches end of life before the AKS LTS version it is compatible with, a newer revision will be declared compatible with that LTS version. The add-on will need to be upgraded to stay in support. 
 
    For example, if `asm-1-26` is compatible with AKS LTS 1.28, and `asm-1-26` reaches end of life, `asm-1-27` may become compatible with 1.28 LTS instead.


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
[aks-lts]: ./long-term-support.md
