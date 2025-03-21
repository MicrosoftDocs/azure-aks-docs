---
title: Upgrade Operating System (OS) version in Azure Kubernetes Service (AKS) clusters.
description: Learn about support, testing, and rollback for OS versions available available on Azure Kubernetes Service (AKS).
ms.topic: overview
ms.service: azure-kubernetes-service
ms.date: 03/21/2025
author: allyford
ms.author: allyford
---

# Operating System (OS) versions in AKS

This article describes OS versions available for Azure Kubernetes Service (AKS) nodes, as well as best practices for testing and upgrading your OS version.

> [!CAUTION]
> In this article, there are references to Ubuntu OS versions that are being deprecated for AKS.
>- Starting on 17 June 2025, AKS will no longer support Ubuntu 18.04. Existing node images will be deleted and AKS will no longer provide security updates. You'll no longer be able to scale your node pools. [Upgrade your node pools](./upgrade-aks-cluster.md) to a supported kubernetes version to migrate to a supported Ubuntu version.
>- Starting on 17 March 2027, AKS will no longer support Ubuntu 20.04. Existing node images will be deleted and AKS will no longer provide security updates. You'll no longer be able to scale your node pools. [Upgrade your node pools](./upgrade-aks-cluster.md) to kubernetes version 1.34+ to migrate to a supported Ubuntu version.
>For more information on this retirement, see [AKS GitHub Issues](https://github.com/Azure/AKS/issues)

## Supported OS versions

Each [node image][node-image] corresponds to an OS version which you can specify using OS SKU. You specify the following parameters when creating clusters and node pools:

* **--os-type**: OS type, including Linux or Windows.
* **--os-sku**: Used to specify OS version or OS variant.
* **--kubernetes-version**: Version of Kubernetes to use for creating the node pool or cluster.

> **Best practice guidance**
>
> The default OS version is the most recent validated version.
>
>   - For Ubuntu, we recommend creating clusters and node pools while specifying `--os-type Linux` and `--os-sku Ubuntu`. This will automatically update you to the latest default Ubuntu version based on your Kubernetes version.
>   - For Azure Linux, we recommend creating clusters and node pools while specifying `--os-type Linux` and `--os-sku AzureLinux`. This will automatically update you to the latest default Azure Linux version based on your Kubernetes version.
>   - For Windows, we recommend creating node pools while specifying `--os-type Windows` and `--os-sku Windows2022`. You will need to manually update node pools to the next OS version when it's released.

| OS Type | OS SKU | Supported Kubernetes versions | Default versioning |
|--|--|--|--|
| Linux | Ubuntu | This OS SKU is supported in all kubernetes versions. | OS version for this OS SKU changes based on your Kubernetes version. Ubuntu 22.04 is default for Kubernetes version 1.25 to 1.32. |
| Linux | Ubuntu2404 | This OS SKU is supported in kubernetes 1.32 to 1.38. | Ubuntu 24.04 is available in preview with k8s 1.32+ using `--os-sku Ubuntu2404`. This OS SKU is recommended if you want to test out the new os version without upgrading your kubernetes version. |
| Linux | Ubuntu2204 | This OS SKU is supported in kubernetes version 1.25 to 1.33. | Ubuntu 22.04 is currently default when using `--os-sku Ubuntu`. This OS SKU is recommended if you need to rollback to Ubuntu 22.04 after testing Ubuntu 24.04. |
| Linux | Azure Linux | This OS SKU is supported in all Kubernetes versions. | OS version for this OS SKU changes based on your Kubernetes version. Azure Linux 2.0 is default for Kubernetes version 1.27 to 1.31. Azure Linux 3.0 is default for Kubernetes version 1.32+. |
| Windows | Windows2019 | 1.14-1.32 | Default for Windows OS Type in Kubernetes version 1.14 to 1.24. |
| Windows | Windows2022 | 1.23 to 1.34 | Default for Windows OS Type in Kubernetes version 1.25 to 1.33. |

## Testing a new OS version

When a new OS version releases on AKS, it will be supported in Preview before it becomes Generall Available and default. We recommend testing your non-production workloads with the new OS version when it becomes available in preview. 

You can use the [`az aks update`][az-aks-update] command to update the `os-sku` on an existing node pool. In cases where there is a new os version available in preview, this will allow you to migrate your node pool to the new os version without needing to upgrade your kubernetes version.

Add a Windows Server 2022 node pool using the `az aks nodepool add` command:

```azurecli
az aks nodepool add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --os-type Windows \
    --os-sku Windows2022 \
    --name npwin \
    --node-count 1
```

## Rollback your OS version

## Next steps

To learn more about node images, node pool upgrades, and node configurations on AKS, see the following resources:
- To learn about nodes and node configurations, see [AKS core concepts][aks-core-concepts].
- Configure [automatic node image upgrades](./auto-upgrade-node-os-image.md) and schedule them using [planned maintenance](./planned-maintenance.md).
- Apply [custom node configurations][custom-node-configuration] to modify OS or kubelet settings.
- For information about the latest node images, see the [AKS release notes](https://github.com/Azure/AKS/releases).
- [Automatically apply cluster and node pool upgrades with GitHub Actions][github-schedule].
- Learn about upgrading best practices with [AKS patch and upgrade guidance][upgrade-operators-guide].

<!-- LINKS - internal -->
[upgrade-aks-node-images]: ./node-image-upgrade.md
[use-windows-annual]: ./windows-annual-channel.md
[aks-core-concepts]: ./core-aks-concepts.md
[custom-node-configuration]: ./custom-node-configuration.md
[use-cvm]: ./use-cvm.md
[create-node-pools]: ./create-node-pools.md
[node-images]: ./node-images.md

<!-- LINKS - external -->
[aks-release-notes]: https://github.com/Azure/AKS/releases
[aks-release-tracker]: https://releases.aks.azure.com/