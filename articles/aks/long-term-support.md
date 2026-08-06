---
title: Long-Term Support for Azure Kubernetes Service (AKS) Versions
description: Learn about Azure Kubernetes Service (AKS) long-term support for Kubernetes
author: schaffererin
ms.author: schaffererin
ms.date: 08/05/2026
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.custom:
  - devx-track-azurecli
  - build-2025
# Customer intent: As a cluster operator or developer, I want to understand long-term support for Kubernetes versions in AKS, so that I can effectively manage upgrade timelines and maintain application stability.
---

# Long-term support for Azure Kubernetes Service (AKS) versions

The Kubernetes community releases a new minor version approximately every four months, and each version has a support window of one year. In Azure Kubernetes Service (AKS), this support window is called _community support_.

For Kubernetes versions in _community support_, AKS provides bug fixes and security updates from community releases. It can be difficult to stay current with the Kubernetes release cadence when your applications have complex dependencies.

Long-term support (LTS) extends the support window so you have more time to plan and test upgrades to newer Kubernetes versions.

## AKS support types

After approximately one year, a given Kubernetes minor version exits _community support_, and bug fixes and security updates aren't available for your AKS clusters.

AKS provides one year of _community support_, followed by one additional year of _long-term support_. Together, the community support and LTS periods provide approximately 24 months of total support from the Kubernetes version's general availability (GA). During the LTS year, AKS backports security fixes from the upstream community. The upstream LTS working group contributes to the community, extending the support window.

|   | Community support  | Long-term support   |
|---|---|---|
| **When to use** | When you can keep up with upstream Kubernetes releases | When you need control over when to migrate from one version to another  |
| **Supported versions** | Three most recent GA minor versions | All supported Kubernetes versions are eligible for LTS. See the [AKS LTS release calendar](./supported-kubernetes-versions.md#lts-versions). |

## Long-term support patch process

LTS supports only the two most recent patch versions. Community support can include any number of currently offered patches. However, AKS reserves the right to deprecate any patch version in response to critical security vulnerabilities (CVEs). For more information about community support policy, see [Kubernetes version support policy](supported-kubernetes-versions.md#kubernetes-version-support-policy).

To identify the latest supported patch versions, see the [AKS release tracker](https://releases.aks.azure.com/webpage/index.html).

## Enable long-term support

**Enabling LTS requires moving your cluster to the Premium tier and explicitly selecting the LTS support plan**. You can opt in at any time, including while your cluster is still in _community support_.

LTS is available on the Premium tier. For current rates, see [AKS pricing](https://azure.microsoft.com/pricing/details/kubernetes-service/).

> [!NOTE]
> Enable the [patch auto-upgrade channel](auto-upgrade-cluster.md) to keep your cluster on the latest supported patches. LTS supports only the two most recent patch versions for each minor version. Clusters that don't run one of those patch versions might lose support.

## Enable LTS on a new cluster

Create a new cluster with LTS enabled using the [`az aks create`][az-aks-create] command. AKS uses the default supported Kubernetes version and latest patch available in the region.

```azurecli-interactive
az aks create \
    --resource-group <resource-group-name> \
    --name <cluster-name> \
    --tier premium \
    --k8s-support-plan AKSLongTermSupport \
    --auto-upgrade-channel patch \
    --generate-ssh-keys
```

The command uses the following LTS-specific parameter values:

- `--tier premium` sets the cluster management tier to Premium, which is required for LTS.
- `--k8s-support-plan AKSLongTermSupport` enrolls the cluster in LTS and provides one additional year of security fixes.
- `--auto-upgrade-channel patch` automatically upgrades the cluster to supported patch versions while keeping the same minor version.

## Enable LTS on an existing cluster

Enable LTS on an existing cluster using the [`az aks update`][az-aks-update] command.

```azurecli-interactive
az aks update --resource-group <resource-group-name> --name <cluster-name> --tier premium --k8s-support-plan AKSLongTermSupport --auto-upgrade-channel patch
```

The command uses the following LTS-specific parameter values:

- `--tier premium` moves the cluster to the Premium cluster management tier, which is required for LTS.
- `--k8s-support-plan AKSLongTermSupport` enrolls the cluster in LTS and provides one additional year of security fixes.
- `--auto-upgrade-channel patch` automatically upgrades the cluster to supported patch versions while keeping the same minor version.

> [!TIP]
> To see which Kubernetes versions you can upgrade to, use the [AKS release tracker](https://releases.aks.azure.com/webpage/index.html) or run `az aks get-upgrades --resource-group <resource-group-name> --name <cluster-name>`.

## Migrate to the latest LTS version

To perform an in-place upgrade to the latest LTS version, specify a higher LTS version offered by AKS as the upgrade target. An LTS cluster can skip minor versions when the upgrade satisfies version-skew requirements and validation checks. For more information, see [Kubernetes version upgrade rules](upgrade-aks-control-plane.md#kubernetes-version-upgrade-rules).

During a full in-place upgrade, AKS upgrades the control plane first and then upgrades each node pool sequentially. Test your workloads against deprecated APIs and other breaking changes between the current and target versions before upgrading.

1. List the versions that AKS offers as upgrade targets for your cluster using the `az aks get-upgrades` command.

    ```azurecli-interactive
    az aks get-upgrades --resource-group <resource-group-name> --name <cluster-name> --output table
    ```

1. Upgrade to an offered LTS version using the [`az aks upgrade`][az-aks-upgrade] command.

    ```azurecli-interactive
    az aks upgrade --resource-group <resource-group-name> --name <cluster-name> --kubernetes-version <lts-kubernetes-version>
    ```

    > [!NOTE]
    > All supported AKS Kubernetes versions are LTS-compatible. For the latest LTS calendar, see the [AKS Kubernetes release calendar](./supported-kubernetes-versions.md#aks-kubernetes-release-calendar-and-upcoming-versions). To view available LTS releases and their patches by region, see the [AKS release tracker](release-tracker.md).

## Disable long-term support on an existing cluster

**To disable LTS on an existing cluster, move your cluster to the Free or Standard tier and explicitly select the `KubernetesOfficial` support plan**.

You can disable LTS while the cluster's Kubernetes version is still in community support. After that version exits community support, upgrade the cluster to a community-supported version before you disable LTS. Check the [AKS Kubernetes release calendar](./supported-kubernetes-versions.md#aks-kubernetes-release-calendar-and-upcoming-versions) to determine the support status of your version.

1. If your current version is outside community support, list the available upgrade targets using the `az aks get-upgrades` command.

    ```azurecli-interactive
    az aks get-upgrades --resource-group <resource-group-name> --name <cluster-name> --output table
    ```

1. If necessary, upgrade the cluster to an offered version that is in community support using the [`az aks upgrade`][az-aks-upgrade] command.

    ```azurecli-interactive
    az aks upgrade --resource-group <resource-group-name> --name <cluster-name> --kubernetes-version <community-supported-kubernetes-version>
    ```

1. Disable LTS using the [`az aks update`][az-aks-update] command. The following example moves the cluster to the Free tier and selects the `KubernetesOfficial` support plan.

    ```azurecli-interactive
    az aks update --resource-group <resource-group-name> --name <cluster-name> --tier free --k8s-support-plan KubernetesOfficial
    ```

    The `--tier free` value moves the cluster to the Free cluster management tier, and `--k8s-support-plan KubernetesOfficial` switches the cluster from LTS to the standard AKS Kubernetes support plan.

## Add-on and feature lifecycle considerations

LTS extends support for the Kubernetes version, but add-ons and features can have separate support lifecycles. Before moving a cluster to LTS, review the lifecycle and Kubernetes-version compatibility of each add-on and feature that the cluster uses.

The following table summarizes current lifecycle considerations:

| Add-on or feature | Lifecycle consideration |
|---|---|
| Calico | Confirm that your Calico version supports the target Kubernetes version and review Tigera support terms for use beyond Kubernetes community support. |
| Key Management Service (KMS) | The existing KMS experience is now designated as legacy. For Kubernetes 1.33 and later, review the new [KMS data encryption](kms-data-encryption.md) experience and the applicable [migration guidance](migrate-key-management-service-platform-managed-key-customer-managed-key.md). Both the new experience and its migration workflow are in preview. |
| Dapr | The managed [Dapr extension](dapr-overview.md) uses a rolling support window that includes the current and previous Dapr versions. Keep the extension within its supported version window. |
| Application Gateway Ingress Controller (AGIC) | AGIC remains available. Begin [transitioning to Application Gateway for Containers](/azure/application-gateway/for-containers/migrate-from-agic-to-agc). |
| Open Service Mesh (OSM) | AKS support for the managed OSM add-on ends on September 30, 2027. Migrate to the [Istio add-on](open-service-mesh-istio-migration-guidance.md) before that date. |
| Microsoft Entra pod-managed identity | Support for the managed add-on ended in September 2025. Migrate to [Microsoft Entra Workload ID](workload-identity-overview.md). |
| Azure Confidential Compute SGX (ACC SGX) | Confirm that ACC SGX supports the target Kubernetes version before moving the cluster beyond community support. |

## Plan the next LTS upgrade

AKS makes consecutive Kubernetes versions eligible for LTS and publishes a separate LTS end-of-life date for each version. Use the [AKS LTS release calendar](./supported-kubernetes-versions.md#lts-versions) and [AKS release tracker](release-tracker.md) to choose an offered target version and plan your migration before the current version reaches its LTS end-of-life date.

## Frequently asked questions

### Can I create a new AKS cluster with an LTS version after community support ends?

Yes, you can create a new AKS cluster using an LTS version after its community support period ends if you enable LTS. LTS support continues only until the end of that version's lifecycle. You must then upgrade to the next supported LTS version. For more information, see the [AKS Kubernetes release calendar](./supported-kubernetes-versions.md#aks-kubernetes-release-calendar-and-upcoming-versions).

### Can I enable and disable LTS on an AKS-supported version after community support ends?

Yes, you can enable the LTS support plan on any AKS-supported version even after its community support period has ended. However, once the community support period has ended, you can't disable LTS for that version.

### Does a community-supported AKS cluster automatically become eligible for LTS after end of life?

No. You must explicitly enable LTS and move the cluster to the Premium tier.

### Is every AKS version eligible for long-term support?

Yes. All supported Kubernetes versions are eligible for LTS.

### What is the pricing model for LTS?

LTS is offered on the Premium tier. For current rates, see [Premium tier pricing](https://azure.microsoft.com/pricing/details/kubernetes-service/).

### Does enabling LTS disrupt workloads?

No. It's a configuration-only change; it doesn't reimage nodes or disrupt workloads, so no downtime is expected.

<!-- LINKS -->
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-upgrade]: /cli/azure/aks#az-aks-upgrade
[supported]: ./supported-kubernetes-versions.md#aks-kubernetes-release-calendar
