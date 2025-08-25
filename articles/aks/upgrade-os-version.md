---
title: Upgrade Operating System (OS) version in Azure Kubernetes Service (AKS) clusters
description: Learn about support, testing, and rollback for OS versions available on Azure Kubernetes Service (AKS).
ms.topic: overview
ms.service: azure-kubernetes-service
ms.date: 03/21/2025
author: allyford
ms.author: allyford
---

# Upgrade operating system (OS) versions in AKS

This article describes OS versions available for Azure Kubernetes Service (AKS) nodes, and best practices for testing and upgrading your OS version.

> [!CAUTION]
> In this article, there are references to Ubuntu OS versions that are being deprecated for AKS.
>- Starting on 17 June 2025, AKS will no longer support Ubuntu 18.04. Existing node images will be deleted and AKS will no longer provide security updates. You'll no longer be able to scale your node pools. Migrate to a supported Ubuntu version by [upgrading your node pools](./upgrade-aks-cluster.md) to a supported kubernetes version. For more information on this retirement, see [AKS GitHub Issues](https://github.com/Azure/AKS/issues/4873).
>- Starting on 17 March 2027, AKS will no longer support Ubuntu 20.04. Existing node images will be deleted and AKS will no longer provide security updates. You'll no longer be able to scale your node pools. Migrate to a supported Ubuntu version by [upgrading your node pools](./upgrade-aks-cluster.md) to kubernetes version 1.34+. For more information on this retirement, see [AKS GitHub Issues](https://github.com/Azure/AKS/issues/4874).

> [!IMPORTANT]
> Starting on **30 November 2025**, AKS will no longer support or provide security updates for Azure Linux 2.0. Starting on **31 March 2026**, existing node images will be deleted, and you'll be unable to scale your node pools. Migrate to a supported Azure Linux version by [**upgrading your node pools**](/azure/aks/upgrade-aks-cluster) to a supported Kubernetes version or migrating to [`osSku AzureLinux3`](/azure/aks/upgrade-os-version). For more information, see [[Retirement] Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).

## Supported OS versions

Each [node image][node-images] corresponds to an OS version which you can specify using OS SKU. You can specify the following parameters when creating clusters and node pools:

* **--os-type**: OS type, including Linux or Windows. Windows OS type can't be specified during cluster creation or update.
* **--os-sku**: Used to specify OS version or OS variant. Windows OS SKU can't be specified during cluster creation or update.
* **--kubernetes-version**: Version of Kubernetes to use for creating the node pool or cluster.

> **Best practice guidance**
>
> The default OS version is the most recent validated version.
>
>   - For Ubuntu, we recommend creating clusters and node pools while specifying `--os-type Linux` and `--os-sku Ubuntu`. This will automatically update you to the latest default Ubuntu version based on your Kubernetes version.
>   - For Azure Linux, we recommend creating clusters and node pools while specifying `--os-type Linux` and `--os-sku AzureLinux`. This will automatically update you to the latest default Azure Linux version based on your Kubernetes version.
>   - For Windows, we recommend creating node pools while specifying `--os-type Windows` and `--os-sku Windows2022`. You need to manually update node pools to the next OS version when it's released.

| OS type | OS SKU | Supported Kubernetes versions | Default versioning |
|--|--|--|--|
| Linux | Ubuntu | This OS SKU is supported in all kubernetes versions. | OS version for this OS SKU changes based on your Kubernetes version. Ubuntu 22.04 is default for Kubernetes version 1.25 to 1.32. |
| Linux | Ubuntu2404 | This OS SKU is supported in kubernetes 1.32 to 1.38. | Ubuntu 24.04 is available in preview with K8s 1.32+ using `--os-sku Ubuntu2404`. This OS SKU is recommended if you want to test out the new os version without upgrading your kubernetes version. |
| Linux | Ubuntu2204 | This OS SKU is supported in kubernetes version 1.25 to 1.33. | Ubuntu 22.04 is currently default when using `--os-sku Ubuntu`. This OS SKU is recommended if you need to roll back to Ubuntu 22.04 after testing Ubuntu 24.04. |
| Linux | Azure Linux | This OS SKU is supported in all Kubernetes versions. | OS version for this OS SKU changes based on your Kubernetes version. Azure Linux 2.0 is default for Kubernetes version 1.27 to 1.31. Azure Linux 3.0 is default for Kubernetes version 1.32+. |
| Windows | Windows2019 | 1.14-1.32 | Default for Windows OS Type in Kubernetes version 1.14 to 1.24. |
| Windows | Windows2022 | 1.23 to 1.34 | Default for Windows OS Type in Kubernetes version 1.25 to 1.33. |

## [Test a new OS version](#tab/testing-a-new-os-version)

When a new OS version releases on AKS, it's supported in preview before it becomes generally available and default. We recommend testing your nonproduction workloads with the new OS version when it becomes available in preview. 

### Update OS SKU on an existing node pool

You can use the [`az aks nodepool update`][az-aks-nodepool-update] command to update the `os-sku` on an existing node pool. In cases where there's a new os version available in preview, this functionality allows you to migrate your node pool to the new os version without needing to upgrade your kubernetes version.

#### Limitations

- `--os-sku Windows2019` isn't a valid `os-sku` for node pool update command. 
- `--os-sku Windows2022` isn't a valid `os-sku` for node pool update command. 

#### Update `os-sku` using the [`az aks nodepool update`][az-aks-nodepool-update] command:

```azurecli
az aks nodepool update \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --os-type Linux \
    --os-sku Ubuntu \
    --name npwin \
    --node-count 1
```

The [`az aks nodepool update`][az-aks-nodepool-update] command can be used to migrate between any supported Linux `os-sku`. The command may fail if the target OS does not have a supported node image for your kubernetes version, vm size, or FIPS enablement. 

## [Test Ubuntu 24.04 (preview)](#tab/test-ubuntu-preview)

Ubuntu 24.04 is available in preview by specifying `--os-sku Ubuntu2404`.

### Limitations

- `--os-sku Ubuntu2404` doesn't support [FIPS](./enable-fips-nodes.md) or [CVM](./use-cvm.md). 
- `--os-sku Ubuntu2404` is supported in kubernetes version 1.32 to 1.38. 
- `--os-sku Ubuntu2404` is intended for testing the new os version without upgrading your kubernetes version. You need to update your OS SKU to a supported OS option before upgrading your kubernetes version to 1.39+.

### Install `aks-preview` extension

1. Install the `aks-preview` Azure CLI extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

    [!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

2. Update to the latest version of the extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command. **Ubuntu 24.04 requires a minimum of 18.0.0b5**.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register `Ubuntu2404Preview` feature flag

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

### Update your node pool to use Ubuntu 24.04 (preview)

You can use the [`az aks nodepool update`][az-aks-nodepool-update] command to update to `--os-sku Ubuntu2404` on an existing node pool.

```azurecli
az aks nodepool update \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --os-type Linux \
    --os-sku Ubuntu2404 \
    --kubernetes-version 1.32.0
    --name npwin \
    --node-count 1
```
---

## [Roll back your OS version](#tab/roll-back-your-os-version)

In kubernetes versions where multiple OS versions are supported, you can use the [`az aks nodepool update`][az-aks-nodepool-update] command to roll back to a previous OS version. 

For example, if you encounter issues while using Ubuntu 24.04, then you can update your node pool `os-sku` to specify Ubuntu 22.04 to resolve issues while maintaining workload availability.

### Roll back your OS version on an existing node pool

You can use the [`az aks nodepool update`][az-aks-nodepool-update] command to update the `os-sku` on an existing node pool. In cases where there's a previous OS version supported in your kubernetes version, this functionality can allow you to roll back you OS version.

#### Limitations

- `--os-sku Windows2019` isn't a valid `os-sku` for node pool update command. 
- `--os-sku Windows2022` isn't a valid `os-sku` for node pool update command. 

#### Update `os-sku` using the [`az aks nodepool update`][az-aks-nodepool-update] command:

```azurecli
az aks nodepool update \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --os-type Linux \
    --os-sku Ubuntu2204 \
    --name npwin \
    --node-count 1
```

The [`az aks nodepool update`][az-aks-nodepool-update] command can be used to migrate between any supported Linux `os-sku`. The command may fail if the target OS does not have a supported node image for your kubernetes version, vm size, or FIPS enablement. 

## [Roll back to Ubuntu 22.04](#tab/test-roll-back)

Ubuntu 22.04 can be specified by using `--os-sku Ubuntu2204`.

### Limitations

- `--os-sku Ubuntu2204` doesn't support [FIPS](./enable-fips-nodes.md) or [CVM](./use-cvm.md). 
- `--os-sku Ubuntu2204` is supported in kubernetes version 1.25 to 1.33. 
- `--os-sku Ubuntu2204` is intended for roll back to Ubuntu 22.04 on your current kubernetes version. You need to update your OS SKU to a supported OS option to upgrade your kubernetes version to 1.34+.

### Update your node pool to use Ubuntu 22.04

You can use the [`az aks nodepool update`][az-aks-nodepool-update] command to update to `--os-sku Ubuntu2204` on an existing node pool.

```azurecli
az aks nodepool update \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --os-type Linux \
    --os-sku Ubuntu2204 \
    --kubernetes-version 1.32.0
    --name npwin \
    --node-count 1
```
---

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
[upgrade-aks-node-images]: ./node-image-upgrade.md
[use-windows-annual]: ./windows-annual-channel.md
[aks-core-concepts]: ./core-aks-concepts.md
[custom-node-configuration]: ./custom-node-configuration.md
[use-cvm]: ./use-cvm.md
[create-node-pools]: ./create-node-pools.md
[node-images]: ./node-images.md
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[install-azure-cli]:  /cli/azure/install-azure-cli
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-show]: /cli/azure/feature#az-feature-show

<!-- LINKS - external -->
[aks-release-notes]: https://github.com/Azure/AKS/releases
[aks-release-tracker]: https://releases.aks.azure.com/
