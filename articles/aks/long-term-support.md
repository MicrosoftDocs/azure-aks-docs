---
title: Long-term support for Azure Kubernetes Service (AKS) versions
description: Learn about Azure Kubernetes Service (AKS) long-term support for Kubernetes
author: kaarthis
ms.author: kaarthis
ms.date: 06/10/2025
ms.topic: concept-article
ms.custom:
  - devx-track-azurecli
  - build-2025
# Customer intent: As a cluster operator or developer, I want to understand how long-term support for Kubernetes on AKS works.
---

# Long-term support for Azure Kubernetes Service (AKS) versions

The Kubernetes community releases a new minor version approximately every four months, with a support window for each version for one year. In Azure Kubernetes Service (AKS), this support window is called *community support*.

AKS supports versions of Kubernetes that are within this *community support* window to push bug fixes and security updates from community releases. While the community support release cadence provides benefits, it requires that you keep up to date with Kubernetes releases, which can be difficult depending on your application's dependencies and the pace of change in the Kubernetes ecosystem.

To help you manage your Kubernetes version upgrades, AKS provides a *long-term support* (LTS) option, which extends the support window for a Kubernetes version to give you more time to plan and test upgrades to newer Kubernetes versions.

## AKS support types

After approximately one year, a given Kubernetes minor version exits *community support*, making bug fixes and security updates unavailable for your AKS clusters.

AKS offers one year of *community support* and one year of *long-term support* to backport security fixes from the upstream community. The upstream LTS working group contributes to the community, extending the support window. LTS provides more time to plan and test upgrades over two years from the Kubernetes version's general availability (GA).

|   | Community support  |Long-term support   |
|---|---|---|
| **When to use** | When you can keep up with upstream Kubernetes releases | When you need control over when to migrate from one version to another  |
| **Supported versions** | Three most recent GA minor versions | All supported Kubernetes versions from 1.27 onward are eligible for Long-Term Support (LTS). |

## LTS Patch process

LTS supports only the two most recent patch versions. This differs from Community support, where all patch versions are supported. However, AKS reserves the right to deprecate any patch version in response to critical security vulnerabilities (CVEs). For more details on community support policy, see [Kubernetes version support policy](supported-kubernetes-versions.md#kubernetes-version-support-policy).

To identify the latest supported patch versions, refer to the [AKS release tracker](https://releases.aks.azure.com/webpage/index.html).

We recommend enabling the [auto-upgrade patch channel](auto-upgrade-cluster.md) to ensure your clusters remain up-to-date with the latest patches.

## Enable long-term support

**Enabling LTS requires moving your cluster to the Premium tier and explicitly selecting the LTS support plan**. While it's possible to enable LTS when the cluster is in *community support, you're  charged once you enable the Premium tier.

### Enable LTS on a new cluster

* Create a new cluster with LTS enabled using the [`az aks create`][az-aks-create] command.

    The following command creates a new AKS cluster with LTS enabled using Kubernetes version 1.27 as an example. To review available Kubernetes releases, see the [AKS release tracker](release-tracker.md).

    ```azurecli-interactive
    az aks create \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --tier premium \
        --k8s-support-plan AKSLongTermSupport \
        --kubernetes-version 1.27 \
        --generate-ssh-keys
    ```

### Enable LTS on an existing cluster

* Enable LTS on an existing cluster using the [`az aks update`][az-aks-update] command.

    ```azurecli-interactive
    az aks update --resource-group <resource-group-name> --name <cluster-name> --tier premium --k8s-support-plan AKSLongTermSupport
    ```

## Migrate to the latest LTS version

The upstream Kubernetes community supports a two-minor-version upgrade path. The process migrates the objects in your Kubernetes cluster as part of the upgrade process, and provides a tested and accredited migration path.

If you want to carry out an in-place migration, the AKS service migrates your control plane from the previous LTS version to the latest, and then migrate your data plane. To carry out an in-place upgrade to the latest LTS version, you need to specify an LTS enabled Kubernetes version as the upgrade target.

* Migrate to the latest LTS version using the [`az aks upgrade`][az-aks-upgrade] command.
  
    The following command uses Kubernetes version 1.32.2 as an example version. To review available Kubernetes releases, see the [AKS release tracker](release-tracker.md).

    ```azurecli-interactive
    az aks upgrade --resource-group <resource-group-name> --name <cluster-name> --kubernetes-version 1.32.2
    ```

    > [!NOTE]
    > Moving forward, all AKS Kubernetes versions will be LTS-compatible. For the latest LTS calendar, visit the [AKS Kubernetes Release Calendar](./supported-kubernetes-versions.md#aks-kubernetes-release-calendar). To view available LTS releases and their patches by region, see the [AKS release tracker](release-tracker.md).


## Disable long-term support on an existing cluster

**Disabling LTS on an existing cluster requires moving your cluster to the free or standard tier and explicitly selecting the KubernetesOfficial support plan**.

There are approximately two years between one LTS version and the next. In lieu of upstream support for migrating more than two minor versions, there's a high likelihood your application depends on Kubernetes APIs that are deprecated. We recommend you thoroughly test your application on the target LTS Kubernetes version and carry out a blue/green deployment from one version to another.

1. Disable LTS on an existing cluster using the [`az aks update`][az-aks-update] command.

    ```azurecli-interactive
    az aks update --resource-group <resource-group-name> --name <cluster-name> --tier [free|standard] --k8s-support-plan KubernetesOfficial
    ```

2. Upgrade the cluster to a later supported version using the [`az aks upgrade`][az-aks-upgrade] command.

    The following command uses Kubernetes version 1.28.3 as an example version. To review available Kubernetes releases, see the [AKS release tracker](release-tracker.md).

    ```azurecli-interactive
    az aks upgrade --resource-group <resource-group-name> --name <cluster-name> --kubernetes-version 1.28.3
    ```

## Unsupported add-ons and features

The AKS team currently tracks add-on versions where Kubernetes community support exists. Once a version leaves community support, we rely on open-source projects for managed add-ons to continue that support. Due to various external factors, some add-ons and features might not support Kubernetes versions outside these upstream community support windows.

The following table provides a list of add-ons and features that aren't supported and the reasons they're unsupported:

|  Add-on / Feature | Reason it's unsupported |
|---|---|
| Istio |  The Istio support cycle is short (six months), and there are no maintenance releases for supported LTS versions. |
| Calico  |  Requires Calico Enterprise agreement past community support. |
| Key Management Service (KMS) | KMSv2 replaces KMS during this LTS cycle. |
| Dapr | AKS extensions aren't supported. |
| Application Gateway Ingress Controller | Migration to App Gateway for Containers happens during LTS period. |
| Open Service Mesh | OSM is deprecated.|
| AAD Pod Identity  | Deprecated in place of Workload Identity. |

> [!NOTE]
> You can't move your cluster to long-term support if any of these add-ons or features are enabled.
>
> While these AKS managed add-ons aren't supported by Microsoft, you can install their open-source versions on your cluster if you want to use them past community support.

## How we decide the next LTS version

Versions of Kubernetes LTS are available for two years from GA, and we mark a higher version of Kubernetes as LTS based on the following criteria:

* That sufficient time elapsed for customers to migrate from the prior LTS version to the current LTS version.
* The previous version completed a two year support window.

Read the [AKS release notes](https://github.com/Azure/AKS/releases) to stay informed of when you're able to plan your migration.

## Frequently asked questions

### Can I create a new AKS cluster with an LTS version after community support ends?

Yes, you can create a new AKS cluster using an LTS version even after its community support period has ended, provided you have opted into LTS. However, this is only valid until the end of the LTS version's lifecycle. After that, you must upgrade to the next supported LTS version. For more details, see the [AKS Kubernetes Release Calendar](./supported-kubernetes-versions.md#aks-kubernetes-release-calendar).

### Can I enable and disable LTS on an AKS-supported version after community support ends?

Yes, you can enable the LTS support plan on any AKS-supported version even after its community support period has ended. However, once the community support period has ended, you can't disable LTS for that version.


### Does a community-supported AKS cluster automatically become LTS eligible after End of Life?

No, you must explicitly enable LTS on the cluster to receive support. This also requires upgrading to the Premium tier. Refer to the [Premium tier pricing](https://azure.microsoft.com/pricing/details/kubernetes-service/) for more information.

### Will every AKS version support Long-Term Support (LTS)?

Yes, AKS ensures that all supported Kubernetes versions are eligible for Long-Term Support (LTS). You can opt into LTS for any supported version available today.

### What is the pricing model for LTS?

LTS is available on the Premium tier refer to the [Premium tier pricing](https://azure.microsoft.com/pricing/details/kubernetes-service/) for more information.

### After enabling LTS, my cluster's autoUpgradeChannel changed to patch channel

This is expected. If there was no defined autoUpgradeChannel for the AKS cluster, it defaults to `patch` with LTS.

<!-- LINKS -->
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-upgrade]: /cli/azure/aks#az-aks-upgrade
[supported]: ./supported-kubernetes-versions.md#aks-kubernetes-release-calendar
