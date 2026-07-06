---
title: Use the Azure Linux Container Host on Azure Kubernetes Service (AKS)
description: Learn how Azure Linux is used on Azure Kubernetes Service (AKS), including how it fits into AKS Automatic and how to use it with AKS Standard clusters.
ms.topic: how-to
ms.custom: build-2023, linux-related-content
ms.date: 07/06/2026
author: schaffererin
ms.author: schaffererin
# Customer intent: "As a cloud developer, I want to understand how Azure Linux is used in AKS, including AKS Automatic and AKS Standard, so that I can choose the right operating system experience for reliable, secure, production-ready container workloads."
---

# Use the Azure Linux container host for Azure Kubernetes Service (AKS)

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

The Azure Linux container host for AKS is an open-source Linux distribution created by Microsoft. It's generally available as a container host on Azure Kubernetes Service (AKS). You can deploy Azure Linux node pools in a new cluster, add Azure Linux node pools to your existing Ubuntu clusters, or migrate your Ubuntu nodes to Azure Linux nodes. To learn more about Azure Linux, see the [Azure Linux documentation][azurelinux-doc].

For most production workloads, AKS Automatic is the recommended production-ready default for AKS. In AKS Automatic, Azure Linux is preconfigured as the default operating system (OS) for the system node pool. This configuration means Azure Linux is part of the managed, production-ready default experience in AKS Automatic, rather than a separate decision you need to make for cluster system components.

[!INCLUDE [azure linux 2.0 retirement](./includes/azure-linux-retirement.md)]

## Why use Azure Linux

The Azure Linux container host on AKS uses a native AKS image that provides one place to do all Linux development. Every package is built from source and validated, ensuring your services run on proven components. Azure Linux is lightweight, only including the necessary set of packages needed to run container workloads. Azure Linux provides a reduced attack surface and eliminates patching and maintenance of unnecessary packages. At the base layer, it has a Microsoft hardened kernel tuned for Azure. Learn more about the [key capabilities of Azure Linux][azurelinux-capabilities].

Azure Linux is also the default OS for the system node pool in AKS Automatic. This default supports the AKS Automatic goal of providing a production-ready cluster configuration with preconfigured platform choices for reliability, security, and reduced operational overhead.

## Azure Linux in AKS Automatic

AKS Automatic is the recommended production-ready default for most AKS workloads. In AKS Automatic:

- Azure Linux is preconfigured as the default OS for the system node pool.
- AKS manages core cluster setup and platform defaults for you.
- Azure Linux is part of the built-in production-oriented experience, alongside other preconfigured security, scaling, and operations defaults.

If you want a managed AKS experience with production-ready defaults, start with AKS Automatic. To learn more, see [What is Azure Kubernetes Service (AKS) Automatic?](./intro-aks-automatic.md)

## Deployment options for Azure Linux on AKS

How you use Azure Linux depends on whether you're using AKS Automatic or AKS Standard.

### AKS Automatic

In AKS Automatic, the system node pool uses Azure Linux by default. If you're creating a new production workload and want the recommended production-ready default experience for AKS, start with AKS Automatic.

To get started, see:

- [What is Azure Kubernetes Service (AKS) Automatic?](./intro-aks-automatic.md)
- [Create an AKS Automatic cluster](./automatic/quick-automatic-managed-network.md)

### AKS Standard

In AKS Standard, you can choose Azure Linux as the node OS option based on your cluster and workload requirements.

To get started using Azure Linux with AKS Standard, see:

- [Creating a cluster with Azure Linux][azurelinux-cluster-config]
- [How to upgrade Azure Linux clusters](/azure/azure-linux/tutorial-azure-linux-upgrade)
- [Add an Azure Linux node pool to your existing cluster][azurelinux-node-pool]
- [Ubuntu to Azure Linux migration][ubuntu-to-azurelinux]
- [Azure Linux supported GPU SKUs](/azure/azure-linux/intro-azure-linux#azure-linux-container-host-supported-gpu-skus)

## Considerations

When deciding how to use Azure Linux in AKS, keep the following points in mind:

- For new production workloads, AKS Automatic is the recommended production-ready default for most AKS scenarios.
- In AKS Automatic, the system node pool is preconfigured to use Azure Linux.
- In AKS Standard, you can explicitly choose Azure Linux for new clusters, added node pools, or migration scenarios.
- Regional availability for Azure Linux follows AKS regional availability.

## Regional availability

The Azure Linux container host is available for use in the same regions as AKS.

## Related content

To learn more about Azure Linux and AKS Automatic, see:

- [What is Azure Kubernetes Service (AKS) Automatic?](./intro-aks-automatic.md)
- [Create an AKS Automatic cluster](./automatic/quick-automatic-managed-network.md)
- [Azure Linux documentation][azurelinuxdocumentation]

<!-- LINKS - Internal -->
[azurelinux-doc]: /azure/azure-linux/intro-azure-linux
[azurelinux-capabilities]: /azure/azure-linux/intro-azure-linux#azure-linux-container-host-key-benefits
[azurelinux-cluster-config]: /azure/azure-linux/quickstart-azure-cli
[azurelinux-node-pool]: ./create-node-pools.md#create-an-aks-cluster-with-a-single-node-pool-using-the-azure-cli
[ubuntu-to-azurelinux]: /azure/azure-linux/tutorial-azure-linux-migration
[azurelinuxdocumentation]: /azure/azure-linux/intro-azure-linux
