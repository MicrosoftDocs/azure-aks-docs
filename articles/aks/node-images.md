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

## Available node images

AKS supports the following node images per OS for your clusters:

| OS | Node images |
|---------|------------|
| [Ubuntu Linux](#ubuntu-linux) | [Ubuntu with containerd](#ubuntu-node-images) |
| [Azure Linux](#azure-linux) | [Azure Linux with containerd](#azure-linux-node-images) |
| [Windows](#windows-server) | • [Windows Server Long Term Servicing Channel (LTSC) with containerd](#windows-server-node-images) <br> • [Windows Server Annual Channel for Containers (preview) with containerd](#windows-server-node-images) |

> [!NOTE]
> containerd is the default and only supported container runtime for AKS node pools.

## Ubuntu Linux

The Ubuntu node images are fully validated by AKS and supported by Microsoft, Canonical, and the Ubuntu community. AKS won't retire an Ubuntu version before the end of Canonical's support lifecycle.

### Ubuntu node images

| Node image | Use case | Limitations |
|--|--|--|


* **Ubuntu with containerd**: Ubuntu 22.04 is currently supported and is the default version for new Linux clusters on AKS.

## Azure Linux

The Azure Linux node images are fully validated by AKS and built from source, using a native AKS image.

### Azure Linux node images

* **Azure Linux with containerd**: Azure Linux 2.0 is currently supported for Linux clusters on AKS.

## Windows Server

The Windows Server node images are fully validated by AKS and supported by Microsoft.

### Windows Server node images

* **Windows Server Long Term Servicing Channel (LTSC) with containerd**: Windows Server 2022 and Windows Server 2019 are the currently supported versions for Windows clusters on AKS. Windows Server 2022 is the default version for new Windows clusters.
* **Windows Server Annual Channel for Containers (preview) with containerd**: Windows Server 2022 is the currently supported version for Windows clusters on AKS.

## Node image options

* ARM64
* FIPS-enabled
* Generation 1 and Generation 2
* Trusted Launch