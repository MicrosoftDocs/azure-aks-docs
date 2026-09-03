---
title: Supported Kubernetes versions for AKS Hybrid and Edge
description: Understand the Kubernetes version support policy and lifecycle of clusters for Azure Kubernetes Service Hybrid and Edge.
services: container-service
ms.topic: feature-availability
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.reviewer: srikantsarwa
ms.lastreviewed: 07/23/2026
ms.custom: overview

# Intent: As an IT Pro, I want to know how Kubernetes versions are supported, as well as the lifecycle of clusters in AKS Hybrid and Edge.
# Keyword: supported Kubernetes versions

---

# Supported Kubernetes versions in AKS

This article describes the supported Kubernetes versions for Azure Kubernetes Service Hybrid and Edge. AKS releases new Kubernetes minor versions approximately every three months.

## Kubernetes versions

Kubernetes uses the standard [Semantic Versioning](https://semver.org/) versioning scheme for each version:

```output
[major].[minor].[patch]

Example:
  1.29.2
  1.29.5
```

Each number in the version indicates general compatibility with the previous version:

* **Major versions** change when incompatible API updates or backwards compatibility might be broken.
* **Minor versions** change when functionality updates are made that are backwards compatible to the other minor releases.
* **Patch versions** change when backwards-compatible bug fixes are made.

You should install the latest patch release of the minor version you're running. For example, if your production cluster is on **`1.29.2`**. **`1.29.5`** is the latest available patch version available for the **1.29** series. You should upgrade to **1.29.5** as soon as possible to ensure your Kubernetes cluster is fully patched and supported.

> [!WARNING]
> **AKS on Azure Local – Kubernetes version compatibility**
>
> If you're running Azure Kubernetes Service (AKS) Hybrid and Edge on Azure Local, you must ensure your Kubernetes clusters are on a supported version before upgrading Azure Local.
>
> * Azure Local solution upgrades don't automatically upgrade Kubernetes versions.
> * Kubernetes follows a strict, sequential minor version upgrade policy and defines end-of-life timelines.
> * If an Azure Local upgrade moves your environment to a version that doesn't support the Kubernetes version currently running, there might be no supported upgrade path available for the cluster.
>
> **Before upgrading Azure Local:**
>
> 1. Check the current Kubernetes version of all AKS clusters.
> 2. Upgrade Kubernetes to a supported version that's compatible with the target Azure Local release.
>
> For Kubernetes upgrade sequencing and lifecycle timelines, see [Kubernetes End of Life](https://endoflife.date/kubernetes).

## AKS Kubernetes release calendar

|  K8s minor version | Supported Azure Local versions | Current status |
|--------------|-------------------|--------------|
| 1.33 | [2607, 2606, 2605, 2604, 2603, 2602](local/aks-whats-new-local.md#aks-hybrid-and-edge-releases) | Supported |
| 1.32 | [2607, 2606, 2605, 2604, 2603, 2602, 2601, 2512, 2511, 2510](local/aks-whats-new-local.md#aks-hybrid-and-edge-releases) | Supported |
| 1.31 | [2607, 2606, 2605, 2604, 2603, 2602, 2601, 2512, 2511, 2510, 2509, 2508](local/aks-whats-new-local.md#aks-hybrid-and-edge-releases) | Supported |
| 1.30 | [2601, 2512, 2511, 2510, 2509, 2508, 2507, 2503](local/aks-whats-new-local.md#aks-hybrid-and-edge-releases) | No more patch versions/CVE updates |
| 1.29 | [2509, 2508, 2507, 2503](local/aks-whats-new-local.md#aks-hybrid-and-edge-releases), [2411](local/aks-whats-new-local.md#aks-hybrid-and-edge-releases), [2408](local/aks-whats-new-local.md#release-2408) | No more patch versions/CVE updates |
| 1.28 | [2507, 2503](local/aks-whats-new-local.md#aks-hybrid-and-edge-releases), [2411](local/aks-whats-new-local.md#aks-hybrid-and-edge-releases), [2408](local/aks-whats-new-local.md#release-2408), [2405](local/aks-whats-new-local.md#release-2405) | No more patch versions/CVE updates |
| 1.27 | [2411](local/aks-whats-new-local.md#aks-hybrid-and-edge-releases), [2408](local/aks-whats-new-local.md#release-2408), [2405](local/aks-whats-new-local.md#release-2405), 2402 | No more patch versions/CVE updates |
| 1.26 | [2405](local/aks-whats-new-local.md#release-2405), 2402 and older | No more patch versions/CVE updates |

> [!NOTE]
> Kubernetes version 1.30 is no longer supported.

### AKS supported Kubernetes minor and patch versions per release

> [!NOTE]
> This table lists a release only when its supported Kubernetes versions change. Releases 2603 through 2607 include the same Kubernetes versions as 2602.

| Release             | Supported minor & patch versions                 |
|---------------------|--------------------------------------------------|
| 2602                | 1.31.12, 1.31.13, 1.32.8, 1.32.9, 1.33.4, 1.33.5 |
| 2510                | 1.30.13, 1.30.14, 1.31.9, 1.31.10, 1.32.5, 1.32.6|
| 2508                | 1.29.12, 1.29.13, 1.30.8, 1.30.9, 1.31.4, 1.31.5 |
| 2507                | 1.28.12, 1.28.14, 1.29.7, 1.29.9, 1.30.3, 1.30.4 |
| 2503                | 1.28.12, 1.28.14, 1.29.7, 1.29.9, 1.30.3, 1.30.4 |
| 2411                | 1.27.7, 1.27.9, 1.28.5, 1.28.9, 1.29.2, 1.29.4   |
| 2408                | 1.27.7, 1.27.9, 1.28.5, 1.28.9, 1.29.2, 1.29.4   |
| 2405                | 1.26.10, 1.26.12, 1.27.7, 1.27.9, 1.28.3, 1.28.5 |

> [!IMPORTANT]
> Once you upgrade your Azure Local instance to a specific release, you can only use the Kubernetes versions available in that release for Kubernetes cluster create and cluster upgrade operations. Outside of those operations, your existing Kubernetes clusters continue to run on the same version they were on before the Azure Local upgrade. For example, if you're on release 2510 and you create a cluster using Kubernetes version 1.30.13, and then you upgrade your Azure Local instance to 2602, the cluster created on 2510 will continue to run 1.30.13. If you create a new cluster after the upgrade, it will use a version available in the 2602 release (for example, 1.31.12, 1.31.13, 1.32.8, 1.32.9, 1.33.4, 1.33.5). You can also upgrade the cluster you created on 2510 to any version available in the 2602 release (for example, 1.31.12, 1.31.13, 1.32.8, 1.32.9, 1.33.4, 1.33.5).

## Kubernetes version support policy

AKS defines a generally available (GA) version as a version that's available for download when deploying or updating clusters.
AKS supports three GA minor versions:

* The latest GA version (N).
* The two previous minor versions (N-1 and N-2).

For example, if AKS introduces **1.30** today, support is provided for the following versions:

| New minor version    |    Supported Version List |
| -----------------    |    ---------------------- |
| 1.33                 |    1.33, 1.32, 1.31       |

When a new minor version is introduced, the oldest minor version and patch releases supported are deprecated and removed. For example, the current supported version list is:

* 1.32
* 1.31
* 1.30

When AKS releases 1.30.\*, all the 1.27.\* versions are removed and go out of support in 30 days.

In addition to this policy, AKS supports a maximum of two patch releases of a given minor version. Given the following supported versions:

```output
Current Supported Version List
------------------------------
1.32.8, 1.32.9, 1.31.12, 1.31.13
```

If AKS releases 1.32.10 and 1.31.14, the oldest patch versions are deprecated and removed, and the supported version list becomes:

```output
New Supported Version List
----------------------
1.32.*10*, 1.32.*9*, 1.31.*14*, 1.31.*13*
```

AKS reserves the right to deprecate patches if a critical CVE or security vulnerability is detected. For awareness on patch availability and any ad-hoc deprecation, see the version release notes.  

AKS might also support preview versions, which are explicitly labeled as previews.

> [!NOTE]
> If you're running an unsupported Kubernetes version, you're asked to upgrade when requesting support for the cluster. Clusters running unsupported Kubernetes releases aren't covered by the [AKS support policies](./windows-server/support-policies.md).

### Supported `kubectl` versions

You can use one minor version older or newer of `kubectl` relative to your **kube-apiserver** version, consistent with the [Kubernetes support policy for kubectl](https://kubernetes.io/docs/setup/release/version-skew-policy/#kubectl).

For example, if your **kube-apiserver** is at 1.17, then you can use versions 1.16 to 1.18 of `kubectl` with that **kube-apiserver**.
To install or update your version of `kubectl`, run `az aks install-cli`.

## Release and deprecation process

For new minor versions of Kubernetes:

* AKS publishes a preannouncement with the planned date of a new version release and respective old version deprecation in the [AKS release notes](https://aka.ms/aks-hci-relnotes) at least 30 days prior to removal.
* Users have 30 days from version removal to upgrade to a supported minor version release to continue receiving support.

### Supported versions policy exceptions

AKS reserves the right to add or remove new/existing versions with one or more critical production-impacting bugs or security issues without advance notice.

Specific patch releases might be skipped or rollout accelerated, depending on the severity of the bug or security issue.

## FAQ

### How does Microsoft notify me of new Kubernetes versions?

The AKS team publishes preannouncements with planned dates of new Kubernetes versions in the AKS documentation.

### How often should I expect to upgrade Kubernetes versions to stay in support?

Starting with Kubernetes 1.19, the [open source community expanded support to one year](https://kubernetes.io/blog/2020/08/31/kubernetes-1-19-feature-one-year-support/). AKS commits to enabling patches and support matching the upstream commitments. For Kubernetes clusters on 1.19 and greater, you are able to upgrade a minimum of once a year to stay on a supported version.

### What happens when a user upgrades a Kubernetes cluster with a minor version that isn't supported?

If you're on the n-3 version or older, it means you're outside of support and are asked to upgrade. When your upgrade from version n-3 to n-2 succeeds, you're back within our support policies. For example:

* If the oldest supported Kubernetes version is 1.27 and you are on 1.26 or older, you're outside of support.
* When you successfully upgrade from 1.26 to 1.27 or greater, you're back within the support window.

Downgrades aren't supported.

### What does "outside of support" mean?

"Outside of support" means that:

* The version you're running is outside of the supported versions list.
* You'll be asked to upgrade the cluster to a supported version when requesting support, unless you're within the 30-day grace period after version deprecation.

Additionally, AKS doesn't make any runtime (or other) guarantees for clusters outside of the supported versions list.

### What happens when I scale a Kubernetes cluster with a minor version that isn't supported?

For minor versions not supported by AKS, scaling in or out should continue to work. Since there is no Quality of Service guarantees, we recommend upgrading to bring your cluster back into support.

### Can I skip multiple Kubernetes versions during a cluster upgrade?

When you upgrade a supported AKS cluster, Kubernetes minor versions can't be skipped. For example, upgrades between:

* **1.12.x** -> **1.13.x**: allowed.
* **1.13.x** -> **1.14.x**: allowed.
* **1.12.x** -> **1.14.x**: not allowed.

To upgrade from **1.12.x** -> **1.14.x**:

1. Upgrade from **1.12.x** -> **1.13.x**.
1. Upgrade from **1.13.x** -> **1.14.x**.

You can only skip multiple versions when upgrading from an unsupported version back into a supported version. For example, you can upgrade from an unsupported 1.10.x to a supported 1.15.x.

### Can I create a new 1.xx.x cluster during its 30-day support window?

No. Once a version is deprecated/removed, you can't create a cluster with that version. As the change rolls out, you see the old version removed from your version list. This process can take up to two weeks from the announcement, progressively by region.

### I am on a freshly deprecated version. Can I still add new node pools, or do I have to upgrade?

No. You can't add node pools from the deprecated version to your cluster.

## Next steps

For information about how to upgrade your cluster, see [Update the Kubernetes version of AKS clusters](./local/hyperconverged/cluster-upgrade.md).
