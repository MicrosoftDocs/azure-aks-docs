---
title: Long-term support for Azure Kubernetes Service (AKS) versions
description: Learn about Azure Kubernetes Service (AKS) long-term support for Kubernetes
ms.topic: concept-article
ms.custom: devx-track-azurecli
ms.date: 01/24/2024
ms.author: juda
author: justindavies
#Customer intent: As a cluster operator or developer, I want to understand how long-term support for Kubernetes on AKS works.
---

# Long-term support for Azure Kubernetes Service (AKS) versions

The Kubernetes community releases a new minor version approximately every four months, with a support window for each version for one year. In Azure Kubernetes Service (AKS), this support window is called *community support*.

AKS supports versions of Kubernetes that are within this *community support* window to push bug fixes and security updates from community releases. While the community support release cadence provides benefits, it requires that you keep up to date with Kubernetes releases, which can be difficult depending on your application's dependencies and the pace of change in the Kubernetes ecosystem.

To help you manage your Kubernetes version upgrades, AKS provides a *long-term support* (LTS) option, which extends the support window for a Kubernetes version to give you more time to plan and test upgrades to newer Kubernetes versions.

## AKS support types

After approximately one year, a given Kubernetes minor version exits *community support*, making bug fixes and security updates unavailable for your AKS clusters.

AKS provides one year of *community support* and one year of *long-term support* to back port security fixes from the community upstream in the public AKS repository. The upstream LTS working group contributes efforts back to the community to provide customers with a longer support window. LTS intends to give you an extended period of time to plan and test for upgrades over a two-year period from the general availability (GA) of the designated Kubernetes version.

|   | Community support  |Long-term support   |
|---|---|---|
| **When to use** | When you can keep up with upstream Kubernetes releases | When you need control over when to migrate from one version to another  |
|  **Support versions** | Three-GA minor versions | Two Kubernetes version (currently *1.27 and 1.30*) for 1 extra year from community support EOL period. Refer to the [Community Support Calendar](https://learn.microsoft.com/azure/aks/supported-kubernetes-versions?tabs=azure-cli#aks-kubernetes-release-calendar) for more information. |

## Enable long-term support

**Enabling LTS requires moving your cluster to the Premium tier and explicitly selecting the LTS support plan**. While it's possible to enable LTS when the cluster is in *community support, you are charged once you enable the Premium tier.

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
    > Starting with kubernetes version 1.28, every kubernetes version is long term support compatible. Please check [supported version calendar](https://learn.microsoft.com/azure/aks/supported-kubernetes-versions?tabs=azure-cli#aks-kubernetes-release-calendar) for more details on timelines.
    > Supported Patches in LTS today : [1.27.100](https://github.com/aks-lts/kubernetes/blob/release-1.27-lts/CHANGELOG/CHANGELOG-1.27.md#v127100-akslts)
    > Currently LTS only supports the two most recent patches and prior old patches get deprecated.

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
| Keda | Unable to guarantee future version compatibility for supported LTS versions. |
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

### Community support for AKS 1.27 ends expires in July 2024. Can I create a new AKS cluster with version 1.27 after that date?

Yes, as long as LTS is enabled on the cluster, you can create a new AKS cluster with version 1.27 after the community support window ends.

### Can I enable and disable LTS on AKS 1.27 after the end of community support?

You can enable the LTS support plan on AKS 1.27 after the end of community support. However, you can't disable LTS on AKS 1.27 after the end of community support.

### I have a cluster running on version 1.27. Does it mean it's automatically in LTS?

No, you need to explicitly enable LTS on the cluster to receive LTS support. Enabling LTS also requires being on the Premium tier.

### What is the pricing model for LTS?

LTS is available on the Premium tier refer to the [Premium tier pricing](https://azure.microsoft.com/pricing/details/kubernetes-service/) for more information.

### After enabling LTS, my cluster's autoUpgradeChannel changed to patch channel

This is expected. If there was no defined autoUpgradeChannel for the AKS cluster, it will default to `patch` with LTS.

<!-- LINKS -->
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-upgrade]: /cli/azure/aks#az-aks-upgrade
[supported]:/articles/aks/supported-kubernetes-versions.md#aks-kubernetes-release-calendar
