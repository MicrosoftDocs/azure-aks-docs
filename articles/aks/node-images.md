---
title: Node Images in Azure Kubernetes Service (AKS)
description: Learn about the different node images available in Azure Kubernetes Service (AKS).
ms.topic: overview
ms.service: azure-kubernetes-service
ms.date: 07/03/2025
author: schaffererin
ms.author: schaffererin
# Customer intent: "As a Kubernetes administrator, I want to understand the available node images in Azure Kubernetes Service, so that I can select the appropriate OS version and ensure my clusters remain supported and secure."
---

# Node images in Azure Kubernetes Service (AKS)

This article describes the node images available for Azure Kubernetes Service (AKS) nodes.

> [!CAUTION]
> In this article, there are references to Ubuntu OS versions that are being deprecated for AKS.
>
> - Starting on 17 March 2027, AKS no longer supports Ubuntu 20.04. Existing node images will be deleted and AKS will no longer provide security updates. You'll no longer be able to scale your node pools. Migrate to a supported Ubuntu version by [upgrading your node pools](./upgrade-aks-cluster.md) to kubernetes version 1.34+. For more information on this retirement, see [AKS GitHub Issues](https://github.com/Azure/AKS/issues/4874).
> - Starting on **30 November 2025**, AKS will no longer support or provide security updates for Azure Linux 2.0. Starting on **31 March 2026**, node images will be removed, and you'll be unable to scale your node pools. Migrate to a supported Azure Linux version by [**upgrading your node pools**](/azure/aks/upgrade-aks-cluster) to a supported Kubernetes version or migrating to [`osSku AzureLinux3`](/azure/aks/upgrade-os-version). For more information, see [Retirement of Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).

> [!IMPORTANT]
> Older node images can contain unpatched security vulnerabilities and might not work properly with recently released features. Using older images might lead to issues with scaling, node readiness, and security. Depending on the age of the image version, it could also place the cluster outside of the support scope until you perform a node image upgrade. **We recommend that you keep node images [current](https://releases.aks.azure.com/) and enable automatic upgrades**.

## Node image releases

Azure Kubernetes Service (AKS) regularly provides new node images, so it's beneficial to upgrade your node images frequently to access the latest AKS features, component updates, and security fixes. You can find detailed summaries of each node image version in the [AKS VHD notes](https://github.com/Azure/AKS/tree/master/vhd-notes). 

Linux node images are released weekly, and Windows node images are released monthly. New node images are included in the [AKS release notes](https://github.com/Azure/AKS/releases).

> **Best practice guidance**
>
> Configure [automatic node image upgrades](./auto-upgrade-node-os-image.md) and schedule them using [planned maintenance](./planned-maintenance.md). This will ensure that your node images are always up to date without requiring manual upgrades.

When new node images are released, it can take up to two weeks for the updates to be rolled out across all regions. The [AKS Release Tracker](./release-tracker.md) shows the current latest node image version, three previously available node image versions for each region, and the node image update order by region. Once the node image is available in your region, you can perform a [manual node image upgrade](./node-image-upgrade.md) or configure [automatic node image upgrades](./auto-upgrade-node-os-image.md) and schedule them using [planned maintenance](./planned-maintenance.md).

## Default node images

AKS sets a default operating system (OS) and node image during cluster and node pool creation. OS Type can be used to filter between Linux or Windows. 

| OS Type | Default OS | Default node image |
|--|--|--|
| Not Specified | Ubuntu Linux | Ubuntu with containerd and gen 2|
| Linux | Ubuntu Linux | Ubuntu with containerd and gen 2 |
| Windows | Windows Server | Windows Server Long Term Servicing Channel (LTSC) with containerd and gen 1 |

> [!NOTE]
> You can't specify the Windows OS Type during cluster creation since the system node pool in every cluster must be Linux.

### Factors that influence the default node image

The following factors influence the default image AKS chooses for your node pool:

- **OS SKU**: If `--os-sku` is specified, then your default OS changes. For example, if you specify Azure Linux as the OS SKU, then your node image is Azure Linux with containerd.
- **Virtual machine (VM) size**: 
    - [Confidential virtual machines (CVM)](./use-cvm.md)
    - [AMR64 virtual machines](./create-node-pools.md)
- **Hypervisor generation**: Each VM size supports Generation 1, [Generation 2](./generation-2-vm.md), or both.
    - If Generation 2 is supported, AKS defaults to using the Generation 2 node image in all OS versions except for Windows Server 2019 and Windows Server 2022.
    - If only Generation 1 is supported, AKS defaults to using the Generation 1 node image. Generation 1 isn't supported for Azure Linux OS Guard (preview) or Flatcar Container Linux for AKS (preview).
- **Feature enablement**: There are some features embedded into the node image. If you choose to use any of these features, your default node image changes.
  - [Federal Information Processing Standards (FIPS)](./enable-fips-nodes.md) changes the default node image for all Linux node pools.
  - [Pod Sandboxing](./use-pod-sandboxing.md) changes the default node image for Azure Linux node pools.
  - [Trusted Launch](./use-trusted-launch.md) changes the default node image for all Linux node pools.

> [!NOTE]
> Certain features can't be combined in a single node pool. Follow links to the feature documentation to review the limitations.

## Available Linux node images

### Ubuntu node images

The Ubuntu node images are fully validated by AKS and supported by Microsoft, Canonical, and the Ubuntu community. AKS won't retire an Ubuntu version before the end of Canonical's support lifecycle.

| Node image | Use case | Limitations |
|--|--|--|
| **Ubuntu with containerd and Gen 1** | This is the standard node image for Ubuntu node pools using a VM size that only supports Generation 1. | N/A |
| **Ubuntu with containerd and Gen 2** | This is the standard node image for Ubuntu node pools using a VM size that supports Generation 2. If a VM size supports both Generation 1 and Generation 2, this node image is selected. | N/A |
| **Ubuntu with containerd and FIPS** | This is a variant of the default node image for customers that enable [Federal Information Processing Standards (FIPS)](./enable-fips-nodes.md). These images support both Generation 1 and Generation 2. | Not yet supported for Ubuntu 22.04+. Can't be combined with Arm64, Trusted Launch, or CVM. |
| **Ubuntu with containerd and Arm64** | This is a variant of the default node image for customers that use a VM size that supports [Arm64](./use-arm64-vms.md). These images support Generation 2 only. | Can't be combined with FIPS, CVM, or Trusted Launch. |
| **Ubuntu with containerd and CVM** | This is a variant of the default node image for customers that use a [Confidential VM](./use-cvm.md) size. These images support Generation 2 only. | Not yet supported for Ubuntu 22.04+. Can't be combined with FIPS, Arm64, or Trusted Launch. |
| **Ubuntu with containerd and Trusted Launch** | This is a variant of the default node image for customers that enable [Trusted Launch](./use-trusted-launch.md). These images support Generation 2 only. | Can't be combined with FIPS, Arm64, or CVM. |

### Azure Linux node images

The Azure Linux node images are fully validated by AKS and built from source, using a native AKS image.

| Node image | Use case | Limitations |
|--|--|--|
| **Azure Linux with containerd and Gen 1** | This is the standard node image for Azure Linux node pools using a VM size that only supports Generation 1. | N/A |
| **Azure Linux with containerd and Gen 2** | This is the standard node image for Azure Linux node pools using a VM size that supports Generation 2. If a VM size supports both Generation 1 and Generation 2, node image is selected. | N/A |
| **Azure Linux with containerd and FIPS** | This is a variant of the default node image for customers that enable [Federal Information Processing Standards (FIPS)](./enable-fips-nodes.md). These images support both Generation 1 and Generation 2. | Can't be combined with Trusted Launch, or Pod Sandboxing. Azure Linux supports a separate image for FIPS and ARM64. |
| **Azure Linux with containerd and Arm64** | This is a variant of the default node image for customers that use a VM size that supports [Arm64](./use-arm64-vms.md). These images support Generation 2 only. | Can't be combined with Trusted Launch or Pod Sandboxing. Azure Linux supports a separate image for FIPS and ARM64. |
| **Azure Linux with containerd, FIPS, and Arm64** | This is a variant of the default node image for customers that enable [Federal Information Processing Standards (FIPS)](./enable-fips-nodes.md) and use a VM size that supports [Arm64](./use-arm64-vms.md). These images support Generation 2 only. | Can't be combined with Trusted Launch or Pod Sandboxing. |
| **Azure Linux with containerd and Trusted Launch** | This is a variant of the default node image for customers that enable [Trusted Launch](./use-trusted-launch.md). These images support Generation 2 only. | Can't be combined with FIPS, Arm64, or Pod Sandboxing. |
| **Azure Linux with containerd and Pod Sandboxing** | This is a variant of the default node image for customers that enable [Pod Sandboxing](./use-pod-sandboxing.md). These images support Generation 2 only. | Can't be combined with FIPS, Arm64, or Trusted Launch. |
### Azure Linux with OS Guard for AKS (preview) node images

The Azure Linux with OS Guard for AKS node images are fully validated by AKS and built from source, using a native AKS image. Versioning for Azure Linux with OS Guard node images follow the AKS date-based format (for example: 202509.23.0). You can check the node images in the release notes and by running the [`az aks nodepool list`][az-aks-nodepool-list] command to view the `nodeImageVersion`. For more information, see [Azure Linux with OS Guard for AKS][os-guard].

| Node image | Use case | Limitations |
|--|--|--|
| **Azure Linux with OS Guard with containerd, Gen 2, FIPS, and Trusted Launch** | This is the standard node image for Azure Linux with OS Guard for AKS node pools using a VM size. If you use a VM size that supports Gen 1 only, you won't be able to use Azure Linux with OS Guard.| N/A |

### Flatcar Container Linux for AKS (preview) node images

The Flatcar Container Linux for AKS node images are fully validated by AKS and supported by Microsoft and the Flatcar community. Versioning for Flatcar Container Linux node images follow the AKS date-based format (for example: 202506.13.0). You can check the node images in the release notes and by using the [`az aks nodepool list`][az-aks-nodepool-list] command to view the `nodeImageVersion`. You can check the Flatcar version number (for example: Flatcar 4344.0.0) in the release notes and by running the `kubectl get nodes` command. For more information, see [Flatcar Container Linux for AKS][flatcar].

| Node image | Use case | Limitations |
|--|--|--|
| **Flatcar Container Linux with containerd and Gen 2** | This is the standard node image for Flatcar Container Linux for AKS node pools using a VM size. If you use a VM size that supports Gen 1 only, you won't be able to use Flatcar OS.| N/A |
| **Flatcar Container Linux with containerd and Arm64** | This is a variant of the default node image for customers that use a VM size that supports [Arm64](./use-arm64-vms.md). These images support Generation 2 only. | N/A |

## Available Windows Server node images

The Windows Server node images are fully validated by AKS and supported by Microsoft.

### Windows Server Long Term Servicing Channel (LTSC) node images

| Node image | Use case | Limitations |
|--|--|--|
| **Windows Server with containerd and Gen 1** | This is the standard node image for Windows node pools using a VM size that supports Generation 1. If a VM size supports both Generation 1 and Generation 2, this node image is selected if using Windows Server 2019 or Windows Server 2022. | N/A |
| **Windows Server with containerd and Gen 2** | This is the standard node image for Windows node pools using a VM size that supports Generation 2. If a VM size supports both Generation 1 and Generation 2, this node image is selected if using Windows Server 2025. | N/A |

### Windows Server Annual Channel for Containers (preview) node images

| Node image | Use case | Limitations |
|--|--|--|
| **Windows Server with containerd and Gen 1** | This is the standard node image for Windows node pools using a VM size that only supports Generation 1. If a VM size supports both Generation 1 and Generation 2, this node image is selected. | N/A |
| **Windows Server with containerd and Gen 2** | This is the standard node image for Windows node pools using a VM size that supports Generation 2. | N/A |

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
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[az-aks-nodepool-list]: /cli/azure/aks/nodepool#az-aks-nodepool-list
[os-guard]: ./use-azure-linux-os-guard.md
[flatcar]: ./flatcar-container-linux-for-aks.md
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register

<!-- LINKS - external -->
[aks-release-notes]: https://github.com/Azure/AKS/releases
[aks-release-tracker]: https://releases.aks.azure.com/
