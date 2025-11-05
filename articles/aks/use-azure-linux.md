---

title: Use the Azure Linux container host on Azure Kubernetes Service (AKS)
description: Learn how to use the Azure Linux container host on Azure Kubernetes Service (AKS)
ms.topic: how-to
ms.custom: build-2023, linux-related-content
ms.date: 02/27/2024
author: schaffererin
ms.author: schaffererin

# Customer intent: "As a cloud developer, I want to deploy and manage Azure Linux container hosts on AKS, so that I can ensure reliable and efficient container workloads with reduced maintenance and enhanced security."
---

# Use the Azure Linux container host for Azure Kubernetes Service (AKS)

The Azure Linux container host for AKS is an open-source Linux distribution created by Microsoft, and it’s generally available as a container host on Azure Kubernetes Service (AKS). The Azure Linux container host provides reliability and consistency from cloud to edge across the AKS, AKS-HCI, and Arc products. You can deploy Azure Linux node pools in a new cluster, add Azure Linux node pools to your existing Ubuntu clusters, or migrate your Ubuntu nodes to Azure Linux nodes. To learn more about Azure Linux, see the [Azure Linux documentation][azurelinux-doc].

> [!IMPORTANT]
> Starting on **30 November 2025**, AKS will no longer support or provide security updates for Azure Linux 2.0. Starting on **31 March 2026**, node images will be removed, and you'll be unable to scale your node pools. Migrate to a supported Azure Linux version by [**upgrading your node pools**](/azure/aks/upgrade-aks-cluster) to a supported Kubernetes version or migrating to [`osSku AzureLinux3`](/azure/aks/upgrade-os-version). For more information, see [[Retirement] Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).

## Why use Azure Linux

The Azure Linux container host on AKS uses a native AKS image that provides one place to do all Linux development. Every package is built from source and validated, ensuring your services run on proven components. Azure Linux is lightweight, only including the necessary set of packages needed to run container workloads. It provides a reduced attack surface and eliminates patching and maintenance of unnecessary packages. At the base layer, it has a Microsoft hardened kernel tuned for Azure. Learn more about the [key capabilities of Azure Linux][azurelinux-capabilities].

## How to use Azure Linux on AKS

To get started using the Azure Linux container host for AKS, see:

* [Creating a cluster with Azure Linux][azurelinux-cluster-config]
* [How to upgrade Azure Linux clusters](/azure/azure-linux/tutorial-azure-linux-upgrade)
* [Add an Azure Linux node pool to your existing cluster][azurelinux-node-pool]
* [Ubuntu to Azure Linux migration][ubuntu-to-azurelinux]
* [Azure Linux supported GPU SKUs](/azure/azure-linux/intro-azure-linux#azure-linux-container-host-supported-gpu-skus)

## Regional availability

The Azure Linux container host is available for use in the same regions as AKS.

## Next steps

To learn more about Azure Linux, see the [Azure Linux documentation][azurelinuxdocumentation].

<!-- LINKS - Internal -->
[azurelinux-doc]: /azure/azure-linux/intro-azure-linux
[azurelinux-capabilities]: /azure/azure-linux/intro-azure-linux#azure-linux-container-host-key-benefits
[azurelinux-cluster-config]: /azure/azure-linux/quickstart-azure-cli
[azurelinux-node-pool]: ./create-node-pools.md#create-an-aks-cluster-with-a-single-node-pool-using-the-azure-cli
[ubuntu-to-azurelinux]: /azure/azure-linux/tutorial-azure-linux-migration
[auto-upgrade-aks]: auto-upgrade-cluster.md
[kured]: node-updates-kured.md
[azurelinuxdocumentation]: /azure/azure-linux/intro-azure-linux

