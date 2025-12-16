---
title: Upgrade Operating System (OS) Version in Azure Kubernetes Service (AKS) Clusters
description: Learn about support, testing, and rollback for OS versions available on Azure Kubernetes Service (AKS).
ms.topic: overview
ms.service: azure-kubernetes-service
ms.date: 09/23/2025
author: allyford
ms.author: allyford
---

# Upgrade operating system (OS) versions in AKS

This article describes OS versions available for Azure Kubernetes Service (AKS) nodes, and best practices for testing and upgrading your OS version.

> [!CAUTION]
> In this article, there are references to Ubuntu and Azure Linux OS versions that are being deprecated for AKS:
>
> - Starting on **June 17, 2025**, AKS will no longer support Ubuntu 18.04. Existing node images will be deleted and AKS will no longer provide security updates. You'll no longer be able to scale your node pools. Migrate to a supported Ubuntu version by [upgrading your node pools](./upgrade-aks-cluster.md) to a supported Kubernetes version. For more information on this retirement, see [Retirement: Ubuntu 18.04 node pools on AKS](https://github.com/Azure/AKS/issues/4873).
>
> - Starting on **March 17, 2027**, AKS will no longer support Ubuntu 20.04. Existing node images will be deleted and AKS will no longer provide security updates. You'll no longer be able to scale your node pools. Migrate to a supported Ubuntu version by [upgrading your node pools](./upgrade-aks-cluster.md) to Kubernetes version 1.34+. For more information on this retirement, see [Retirement: Ubuntu 20.04 node pools on AKS](https://github.com/Azure/AKS/issues/4874).
>
> - Starting on **November 30, 2025**, AKS will no longer support or provide security updates for Azure Linux 2.0. Starting on **March 31, 2026**, node images will be removed, and you'll be unable to scale your node pools. Migrate to a supported Azure Linux version by [**upgrading your node pools**](/azure/aks/upgrade-aks-cluster) to a supported Kubernetes version or migrating to [`osSku AzureLinux3`](/azure/aks/upgrade-os-version). For more information, see [Retirement: Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).

## Supported OS versions

Each [node image][node-images] corresponds to an OS version, which you can specify using OS SKU. You can specify the following parameters when creating clusters and node pools:

- **--os-type**: OS type, including Linux or Windows. *You can't specify the Windows OS type during cluster creation or update.*
- **--os-sku**: Used to specify OS version or OS variant. *You can't specify the Windows OS SKU during cluster creation or update.* For more information for supported OS SKU options, see [Azure AKS CLI][az-aks-create] or [API][agent-pools-create-or-update].
- **--kubernetes-version**: Version of Kubernetes to use for creating the node pool or cluster.

> **Best practice guidance**
>
> The default OS version is the most recent validated version.
>
> - For Ubuntu, we recommend creating clusters and node pools while specifying `--os-type Linux` and `--os-sku Ubuntu`. This will automatically update you to the latest default Ubuntu version based on your Kubernetes version.
> - For Azure Linux, we recommend creating clusters and node pools while specifying `--os-type Linux` and `--os-sku AzureLinux`. This will automatically update you to the latest default Azure Linux version based on your Kubernetes version.
> - For Windows, we recommend creating node pools while specifying `--os-type Windows` and `--os-sku Windows2022`. You need to manually update node pools to the next OS version when it's released.

| OS type | OS SKU | Supported Kubernetes versions | Default versioning |
|--|--|--|--|
| Linux | Ubuntu | This OS SKU is supported in all Kubernetes versions. | OS version for this OS SKU changes based on your Kubernetes version. Ubuntu 22.04 is default for Kubernetes version 1.25 to 1.32. |
| Linux | Ubuntu2404 | This OS SKU will only be supported in Kubernetes 1.32 to 1.38. | Ubuntu 24.04 is available in preview with Kubernetes 1.32+ using `--os-sku Ubuntu2404`. We recommend this OS SKU if you want to test out the new OS version without upgrading your Kubernetes version. |
| Linux | Ubuntu2204 | This OS SKU is supported in Kubernetes version 1.25 to 1.36. | Ubuntu 22.04 is currently default when using `--os-sku Ubuntu`. We recommend this OS SKU if you need to roll back to Ubuntu 22.04 after testing Ubuntu 24.04. |
| Linux | AzureLinux | This OS SKU is supported in all Kubernetes versions. | OS version for this OS SKU changes based on your Kubernetes version. Azure Linux 2.0 is default for Kubernetes version 1.27 to 1.31. Azure Linux 3.0 is default for Kubernetes version 1.32+. When the `AzureLinuxV3Preview` feature flag is enabled on AKS 1.31, `--os-sku AzureLinux` defaults to 3.0. |
| Linux | AzureLinux3 | This OS SKU is supported in Kubernetes 1.28 to 1.36. | We recommend this OS SKU if you want to test out the new OS version without upgrading your Kubernetes version. You can also use this OS SKU to migrate from Azure Linux 2.0 to Azure Linux 3.0. |
| Linux | AzureLinuxOSGuard | This OS SKU is supported in Kubernetes versions 1.32 and above. | Azure Linux with OS Guard versions are upgraded through node image upgrades. For more information, see [Azure Linux with OS Guard for AKS][os-guard]. |
| Linux | Flatcar | This OS SKU is supported in all Kubernetes versions. | Flatcar versions are upgraded through node image upgrades. For more information, see [Flatcar Container Linux for AKS][flatcar]. |
| Windows | Windows2019 | 1.14 to 1.32 | Default for Windows OS Type in Kubernetes version 1.14 to 1.24. |
| Windows | Windows2022 | 1.23 to 1.34 | Default for Windows OS Type in Kubernetes version 1.25 to 1.34. |

## Migrate to a new OS version

When a new OS version releases on AKS, it's supported in preview before it becomes generally available and default. We recommend testing your nonproduction workloads with the new OS version when it becomes available in preview. In order to access preview functions, make sure you have the preview extension installed. You can install the extension using the `az extension add --name aks-preview` command.

### Update OS SKU on an existing node pool

Update the `os-sku` on an existing node pool using the [`az aks nodepool update`][az-aks-nodepool-update] command. In cases where there's a new OS version available in preview, this functionality allows you to migrate your node pool to the new OS version without needing to upgrade your Kubernetes version.

> [!NOTE]
> The following values aren't supported for node pool update command:
>
> - `--os-sku Windows2019`
> - `--os-sku Windows2022`
>
> Instead, you need to add node pools to your cluster with the corresponding `--os-sku` you intend to use.

```azurecli-interactive
az aks nodepool update \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME \
    --os-sku Ubuntu \
    --name $NODE_POOL_NAME \
    --node-count 1
```

You can use the [`az aks nodepool update`][az-aks-nodepool-update] command to migrate between any supported Linux `os-sku`. The command might fail if the target OS doesn't have a supported node image for your Kubernetes version, VM size, or FIPS enablement.

### Migrate to Ubuntu 24.04 (preview)

Ubuntu 24.04 is available in preview by specifying `--os-sku Ubuntu2404`.

> [!NOTE]
> Keep the following information in mind when migrating to `--os-sku Ubuntu2404`:
>
> - [FIPS](./enable-fips-nodes.md) is not supported.
> - Ubuntu 24.04 will be supported in Kubernetes versions 1.32 to 1.38.
> - You need to update your OS SKU to a supported OS option before upgrading your Kubernetes version to 1.39+. `--os-sku Ubuntu2404` is an option and is intended for testing the new OS Linux version without requiring you to upgrade your Kubernetes version.
> - You need the preview Azure CLI version 18.0.0b5 or later installed and configured. To find your CLI version, run `az --version`. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

#### Install `aks-preview` extension

1. Install the `aks-preview` Azure CLI extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

    [!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

2. Update to the latest version of the extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command. **Ubuntu 24.04 requires a minimum of 18.0.0b5**.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

#### Register `Ubuntu2404Preview` feature flag

1. Register the `Ubuntu2404Preview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "Ubuntu2404Preview"
    ```

2. Verify the registration status using the [`az feature show`][az-feature-show] command. It takes a few minutes for the status to show *Registered*.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name Ubuntu2404Preview
    ```

3. When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

#### Update your node pool to use Ubuntu 24.04

Update to `--os-sku Ubuntu2404` on an existing node pool using the [`az aks nodepool update`][az-aks-nodepool-update] command.

```azurecli-interactive
az aks nodepool update \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME \
    --os-sku Ubuntu2404 \
    --kubernetes-version 1.32.0 \
    --name $NODE_POOL_NAME \
    --node-count 1
```

### Migrate to Azure Linux 3.0

Azure Linux 3.0 is the default for `--os-sku AzureLinux` in Kubernetes versions 1.32 to 1.36. You can also use Azure Linux 3.0 by specifying `--os-sku AzureLinux3`.

> [!NOTE]
> Keep the following information in mind when migrating to `--os-sku AzureLinux3`:
>
> - `--os-sku AzureLinux3` is supported in Kubernetes versions 1.28 to 1.36.
> - `--os-sku AzureLinux3` is intended for migrating to Azure Linux 3.0 without upgrading your Kubernetes version. You need to update your OS SKU to a supported OS option before upgrading your Kubernetes version to 1.37+.
> - You need the Azure CLI version 18.0.0b36 or later for *preview* and version 2.78.0 or later for *GA* installed and configured. To find your CLI version, run `az --version`. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

#### Update your node pool to use Azure Linux 3.0

Update to `--os-sku AzureLinux3` on an existing node pool using the [`az aks nodepool update`][az-aks-nodepool-update] command.

```azurecli-interactive
az aks nodepool update \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME \
    --os-sku AzureLinux3 \
    --kubernetes-version 1.30.0 \
    --name $NODE_POOL_NAME \
    --node-count 1
```

## Roll back your OS version

In Kubernetes versions where multiple OS versions are supported, you can use the [`az aks nodepool update`][az-aks-nodepool-update] command to roll back to a previous OS version.

You might want to roll back your OS version in the following scenarios:

- If you're testing a new OS version and you run into any issues.
- Once you upgrade to a Kubernetes version that supports the new OS version as default, you might want to roll back to the default `Ubuntu` or `AzureLinux` OS SKU. This allows you to get future OS versions as a part of your Kubernetes upgrades instead of requiring a node pool update.

### Roll back your OS version to the default OS SKU

You can use the [`az aks nodepool update`][az-aks-nodepool-update] command to update the `os-sku` on an existing node pool. In cases where there's a previous OS version supported in your Kubernetes version, this functionality can allow you to roll back your OS version.

> [!NOTE]
> The following values aren't supported for node pool update command:
>
> - `--os-sku Windows2019`
> - `--os-sku Windows2022`

| OS SKU | Default OS version |
|--|--|
| Ubuntu | When you have OS SKU `Ubuntu`, Ubuntu 22.04 is the default OS version if your Kubernetes version is 1.25 to 1.34. Ubuntu 24.04 is the default for Ubuntu in Kubernetes 1.35 to 1.37. |
| AzureLinux | When you have OS SKU `AzureLinux`, Azure Linux 2.0 is the default for AzureLinux in Kubernetes 1.26 to 1.31. Azure Linux 3.0 is the default for AzureLinux in Kubernetes 1.32 to 1.36. |

#### Update your OS SKU to Ubuntu on an existing node pool

When updating your node pool to use OS SKU `Ubuntu`, you'll get the default OS version based on your Kubernetes version. This might trigger an automatic reimage if the OS version changes during the node pool update command.

Update to `--os-sku Ubuntu`on an existing node pool using the [`az aks nodepool update`][az-aks-nodepool-update] command.

```azurecli-interactive
az aks nodepool update \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME \
    --os-sku Ubuntu \
    --name $NODE_POOL_NAME \
    --node-count 1
```

You can use the [`az aks nodepool update`][az-aks-nodepool-update] command to migrate between any supported Linux `os-sku`. The command might fail if the target OS doesn't have a supported node image for your Kubernetes version, VM size, or FIPS enablement.

#### Update your OS SKU to Azure Linux on an existing node pool

When updating your node pool to use OS SKU `AzureLinux`, you'll get the default OS version based on your Kubernetes version. This might trigger an automatic reimage if the OS version changes during the node pool update command.

Update to `--os-sku AzureLinux` on an existing node pool using the [`az aks nodepool update`][az-aks-nodepool-update] command.

```azurecli-interactive
az aks nodepool update \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME \
    --os-sku AzureLinux \
    --name $NODE_POOL_NAME \
    --node-count 1
```

#### Roll back to Ubuntu 22.04

> [!NOTE]
> Keep the following information in mind when migrating to `--os-sku Ubuntu2204`:
>
> - [FIPS](./enable-fips-nodes.md) and [CVM](./use-cvm.md) aren't supported.
> - Ubuntu 22.04 is supported in Kubernetes versions 1.25 to 1.36.
> - `--os-sku Ubuntu2204` is intended for roll back to Ubuntu 22.04 on your current Kubernetes version. You need to update your OS SKU to a supported OS option to upgrade your Kubernetes version to 1.34+.

Roll back to `--os-sku Ubuntu2204` on an existing node pool using the [`az aks nodepool update`][az-aks-nodepool-update] command.

```azurecli-interactive
az aks nodepool update \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME \
    --os-sku Ubuntu2204 \
    --kubernetes-version 1.32.0 \
    --name $NODE_POOL_NAME \
    --node-count 1
```

## Next steps

To learn more about node images, node pool upgrades, and node configurations on AKS, see the following resources:

- To learn about nodes and node configurations, see [AKS core concepts][aks-core-concepts].
- Configure [automatic node image upgrades](./auto-upgrade-node-os-image.md) and schedule them using [planned maintenance](./planned-maintenance.md).
- Apply [custom node configurations][custom-node-configuration] to modify OS or kubelet settings.
- For information about the latest node images, see the [AKS release notes](https://github.com/Azure/AKS/releases).
- [Automatically apply cluster and node pool upgrades with GitHub Actions][github-schedule].
- Learn about upgrading best practices with [AKS patch and upgrade guidance][upgrade-operators-guide].

<!-- LINKS - internal -->
[upgrade-operators-guide]: /azure/architecture/operator-guides/aks/aks-upgrade-practices
[github-schedule]: ./node-upgrade-github-actions.md
[agent-pools-create-or-update]: /rest/api/aks/agent-pools/create-or-update#ossku
[az-aks-create]: /cli/azure/aks#az-aks-create
[aks-core-concepts]: ./core-aks-concepts.md
[custom-node-configuration]: ./custom-node-configuration.md
[node-images]: ./node-images.md
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[install-azure-cli]:  /cli/azure/install-azure-cli
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[flatcar]: ./flatcar-container-linux-for-aks.md
[os-guard]: ./use-azure-linux-os-guard.md