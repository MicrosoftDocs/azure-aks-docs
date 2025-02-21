---
title: Node images in Azure Kubernetes Service (AKS)
description: Learn about the different node images available in Azure Kubernetes Service (AKS).
ms.topic: overview
ms.service: azure-kubernetes-service
ms.date: 08/26/2024
author: schaffererin
ms.author: schaffererin
---

# Node images in Azure Kubernetes Service (AKS)

This article describes the node images available for Azure Kubernetes Service (AKS) nodes.

## Node image releases

Azure Kubernetes Service (AKS) regularly provides new node images, so it's beneficial to upgrade your node images frequently to use the latest AKS features. Linux node images are updated weekly, and Windows node images are updated monthly. 

New node images are included in the [AKS release notes](https://github.com/Azure/AKS/releases). Detailed summaries of each node image version can be found in the [AKS vhd notes](https://github.com/Azure/AKS/tree/2025-01-06/vhd-notes).

When new node images are released, it can take up to a week for these updates to be rolled out across all regions. The [AKS Release Tracker](https://learn.microsoft.com/azure/aks/release-tracker) shows the current latest node image version and three previously available node image versions for each region. It also shows the node image update order by region. Once the node image has rolled out to your region, you can perform a [node image upgrade manually](https://learn.microsoft.com/azure/aks/node-image-upgrade). Alternatively, you can [perform node image upgrades automatically](https://learn.microsoft.com/azure/aks/auto-upgrade-node-os-image?tabs=azure-cli) and schedule them using planned maintenance.

## Default node images

When creating a new cluster or node pool, AKS will set a default Operating System (OS) and node image. OS Type can be used to filter between Linux or Windows. 

| OS Type | Default OS | Default node image |
|--|--|--|
| Not Specified | Ubuntu Linux | Ubuntu with containerd|
| Linux | Ubuntu Linux | Ubuntu with containerd |
| Windows | Windows Server | Windows Server Long Term Servicing Channel (LTSC) with containerd |

> [!NOTE]
> Windows OS Type cannot be specified during cluster creation since the first node pool in every cluster must be Linux.

### Supported OS versions

Each node image corresponds to an OS version which can be specified by using OS SKU.

> **Best practice guidance**
>
> The default OS version is the most recent validated version. 
>   - For Ubuntu, we recommend creating cluster and node pools while specifying: --os-type Linux and --os-sku Ubuntu. This will automatically update you to the latest default Ubuntu version based on your Kubernetes version.
>   - For Azure Linux, we recommend creating cluster and node pools while specifying: --os-type Linux and --os-sku AzureLinux. This will automatically update you to the latest default Azure Linux version based on your Kubernetes version.
>   - For Windows, we recommend creating node pools while specifying --os-type Windows and --os-sku Windows2022. You will need to manually update node pools to the next os version when it is released.

Review the following parameters which are reflected in the table:

   * **--os-type**: Operating System (OS) type including Linux or Windows.
   * **--os-sku**: Used to specify OS version or OS variant.
   * **--kubernetes-version**: Version of kubernetes to use for creating the node pool or cluster.

| OS Type | OS SKU | Supported Kubernetes versions | Default versioning |
|--|--|--|--|
| Linux | Ubuntu | This OS SKU is supported in all kubernetes versions. | OS version for this OS SKU changes based on your kubernetes version. Ubuntu 22.04 is default for k8s version X to 1.25+. |
| Linux | Azure Linux | This OS SKU is supported in all kubernetes versions. | OS version for this OS SKU changes based on your kubernetes version. Azure Linux 2.0 is default for k8s version 1.X to 1.31. Azure Linux 3.0 is default for k8s version 1.32+. |
| Windows | Windows2019 | X-1.32 | Default for Windows OS Type in k8s version 1.X to 1.24.
| Windows | Windows2022 | 1.23 to 1.34 | Default for Windows OS Type in k8s version 1.25 to 1.33. |

### Factors that may impact default node images

Factors that may impact your default node image:
- OS SKU: If --os-sku is specified, then your default OS will change. For example, if you specify Azure Linux as the OS SKU, then your node image will be the Azure Linux with containerd.
- Virtual machine (VM) size: 
    - Confidential virtual machines (CVM)
    - AMR64 virtual machines
- Hypervisor Generation: Each virtual machine size supports either Generation 1, Generation 2, or both.
    - If a Generation 2 is supported, AKS will default to using the Generation 2 node image.
    - If only Generation 1 is supported, AKS will default to using the Generation 1 node image.
- Feature enablement: There are some features that are embedded into the node image. If you choose to use any of these features, your default node image will change.
    - Federal Information Processing Standards (FIPS) enablement will change the default node image for all Linux node pools.
    - Pod Sandboxing will change the default node image for Azure Linux node pools.
    - Trusted Launch will change the default node image for all Linux node pools.

> [!NOTE]
> Many of the above features can't be combined in a single node pool. Follow links to feature documentation to see limitations. 

## Available Linux node images

### Ubuntu node images

The Ubuntu node images are fully validated by AKS and supported by Microsoft, Canonical, and the Ubuntu community. AKS won't retire an Ubuntu version before the end of Canonical's support lifecycle.

| Node image | Use case | Limitations |
|--|--|--|
| **Ubuntu with containerd and Gen 1** | This is the standard node image for Ubuntu node pools using a vm size that only supports Generation 1. | N/A |
| **Ubuntu with containerd and Gen 2** | This is the standard node image for Ubuntu node pools using a vm size that supports Generation 2. If a vm size supports both Generation 1 and Generation 2, this will be the selected node image. | N/A |
| **Ubuntu with containerd and FIPS** | This is a variant of the default node image for customers that enable Federal Information Processing Standards (FIPS). These images support both Generation 1 and Generation 2. | Not yet supported for Ubuntu 22.04+. Can't be combined with ARM64, Trusted Launch, or CVM. |
| **Ubuntu with containerd and ARM64** | This is a variant of the default node image for customers that use a vm size that supports ARM64. These images support Generation 2 only. |  Can't be combined with FIPS, CVM, or Trusted Launch.|
| **Ubuntu with containerd and CVM** | This is a variant of the default node image for customers that use a Confidential VM size. These images support Generation 2 only. | Not yet supported for Ubuntu 22.04+. Cannot be combined with FIPS, ARM64, or Trusted Launch. |
| **Ubuntu with containerd and Trusted Launch** | This is a variant of the default node image for customers that enable Trusted Launch. These images support Generation 2 only. | Can't be combined with FIPS, ARM64, or CVM. |

### Azure Linux node images

The Azure Linux node images are fully validated by AKS and built from source, using a native AKS image.

| Node image | Use case | Limitations |
|--|--|--|
| **Azure Linux with containerd and Gen 1** | This is the standard node image for Azure Linux node pools using a vm size that only supports Generation 1. | N/A |
| **Azure Linux with containerd and Gen 2** | This is the standard node image for Azure Linux node pools using a vm size that supports Generation 2. If a vm size supports both Generation 1 and Generation 2, this will be the selected node image. | N/A |
| **Azure Linux with containerd and FIPS** | This is a variant of the default node image for customers that enable Federal Information Processing Standards (FIPS). These images support both Generation 1 and Generation 2. | Can't be combined with ARM64, Trusted Launch, or Pod Sandboxing. |
| **Azure Linux with containerd and ARM64** | This is a variant of the default node image for customers that use a vm size that supports ARM64. These images support Generation 2 only. |  Can't be combined with FIPS, Trusted Launch, or Pod Sandboxing.|
| **Azure Linux with containerd and Trusted Launch** | This is a variant of the default node image for customers that enable Trusted Launch. These images support Generation 2 only. | Can't be combined with FIPS, ARM64, or Pod Sandboxing. |
| **Azure Linux with containerd and Pod Sandboxing** | This is a variant of the default node image for customers that enable Pod Sandboxing. These images support Generation 2 only. | Can't be combined with FIPS, ARM64, or Trusted Launch. |

## Available Windows Server node images

The Windows Server node images are fully validated by AKS and supported by Microsoft.

### Windows Server Long Term Servicing Channel (LTSC) node images

| Node image | Use case | Limitations |
|--|--|--|
| **Windows Server with containerd and Gen 1** | This is the standard node image for Azure Linux node pools using a vm size that only supports Generation 1. | N/A |
| **Windows Server with containerd and Gen 2** | This is the standard node image for Azure Linux node pools using a vm size that supports Generation 2. If a vm size supports both Generation 1 and Generation 2, this will be the selected node image. | N/A |

### Windows Server Annual Channel for Containers (preview) node images

| Node image | Use case | Limitations |
|--|--|--|
| **Windows Server with containerd and Gen 1** | This is the standard node image for Azure Linux node pools using a vm size that only supports Generation 1. | N/A |
| **Windows Server with containerd and Gen 2** | This is the standard node image for Azure Linux node pools using a vm size that supports Generation 2. If a vm size supports both Generation 1 and Generation 2, this will be the selected node image. | N/A |

## Next steps

To learn more about Windows containers on AKS, see the following resources:

<!-- LINKS - internal -->
[upgrade-aks-node-images]: ./node-image-upgrade.md
[use-windows-annual]: ./windows-annual-channel.md

<!-- LINKS - external -->
[aks-release-notes]: https://github.com/Azure/AKS/releases
[aks-release-tracker]: https://releases.aks.azure.com/