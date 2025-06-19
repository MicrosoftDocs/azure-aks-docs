---
title: Virtual machine (VM) sizes, generations, and features for Azure Kubernetes Service (AKS)
description: Learn about the different VM sizes, generations, and features available for Azure Kubernetes Service (AKS) and learn how to check for available VM sizes, why certain VM sizes might not be available, and what happens when a VM size retires.
ms.topic: overview
ms.service: azure-kubernetes-service
ms.date: 06/19/2025
ms.author: schaffererin
author: schaffererin
---

# Virtual machine (VM) sizes, generations, and features for Azure Kubernetes Service (AKS)

Azure Kubernetes Service (AKS) supports a variety of virtual machine (VM) sizes, generations, and features to accommodate different workloads and performance requirements. This article provides an overview of available VM sizes and generations for AKS, how to check for available VM sizes in your region, reasons why certain VM sizes might not be available, and what happens when a VM size retires.

## VM generation support on AKS

Azure supports both Generation 1 (Gen 1) and [Generation 2 (Gen 2) virtual machines (VMs)](/azure/virtual-machines/generation-2). Gen 2 VMs offer exclusive features over Gen 1 VMs, such as increased memory, improved CPU performance, support for NVMe disks, and support for [Trusted Launch](./use-trusted-launch.md). With some [exceptions](/windows-server/virtualization/hyper-v/plan/should-i-create-a-generation-1-or-2-virtual-machine-in-hyper-v), we generally recommend migrating to Generation 2 VMs to take advantage of the newest features and functionalities in Azure VMs.

The VM size and operating system (OS) system you select when creating an AKS node pool determines the VM generation used. Check the [list of supported sizes](/azure/virtual-machines/generation-2#generation-2-vm-sizes) to see if your SKU supports or requires Gen 2. Additionally, not all [VM images](./node-images.md) support Gen 2 VMs. On AKS, Gen 2 VMs use the AKS Ubuntu 22.04 or the AKS Windows Server 2022 image. These images support all Gen 2 SKUs and sizes.

To migrate from Gen 1 to Gen 2 VMs, see [Use generation 2 virtual machines in Azure Kubernetes Service (AKS)](./generation-2-vm.md).

## Supported VM sizes

For in-depth information about VM sizes available in Azure, see [Azure VM sizes](/azure/virtual-machines/sizes/overview?tabs=breakdownseries%2Cgeneralsizelist%2Ccomputesizelist%2Cmemorysizelist%2Cstoragesizelist%2Cgpusizelist%2Cfpgasizelist%2Chpcsizelist). To view supported Gen 2 VM sizes, see [Generation 2 VM sizes](/azure/virtual-machines/generation-2).

AKS also supports the following VM types and features:

* [Confidential VMs (CVMs)](./use-cvm.md)
* [Arm-based processor (Arm64) VMs](./use-arm64-vms.md)
* [GPU-optimized VMs](/azure/virtual-machines/sizes/overview?tabs=breakdownseries%2Cgeneralsizelist%2Ccomputesizelist%2Cmemorysizelist%2Cstoragesizelist%2Cgpusizelist%2Cfpgasizelist%2Chpcsizelist#gpu-accelerated)
* [Trusted launch](./use-trusted-launch.md)

### Default behavior for supported VM sizes

There are three scenarios when creating a node pool with a supported VM size:

1. If the VM size supports only Gen 1, the default behavior for both Linux and Windows node pools is to use the Gen 1 node image.
2. If the VM size supports only Gen 2, the default behavior for both Linux and Windows node pools is to use the Gen 2 node image. Windows node pools require a custom header to use a VM size that only supports Gen 2. For more information, see [Create a Windows node pool with a Generation 2 VM](add-link).
3. If the VM size supports both Gen 1 and Gen 2, the default behavior for Linux and Windows differs. Linux uses the Gen 2 node image, and Windows uses Gen 1 image. To use the Gen 2 node image for Windows, see [Create a Windows node pool with a Generation 2 VM](add-link).

## Check available VM sizes

Check available VM sizes using the [`az vm list-skus`][az-vm-list-skus] command.

```azurecli-interactive
az vm list-skus --location <your-location> --output table
```

## Why certain VM sizes might not be available

* Quota
* Preview
* Blocked by AKS

## What happens when a VM size retires?

When a VM size or series reaches its retirement date, the VM is deallocated. VM deallocation causes your AKS node pools to experience breakage. To check the retirement status of a VM size, see [Retired Azure VM size series](/azure/virtual-machines/sizes/retirement/retired-sizes-list) or perform a search in [Azure Updates](https://azure.microsoft.com/updates). To check the VM size of your node pools, use the [`az aks nodepool list`][az-aks-nodepool-list] command and query for the `vmSize` property:

```azurecli-interactive
az aks nodepool list --resource-group <your-resource-group> --cluster-name <your-cluster-name> --query "[].{Name:name, VMSize:vmSize}" --output table
```

If you're using a VM size that's retiring/retired, we recommend [migrating your node pools to a supported VM size](#migrate-node-pools-to-a-supported-vm-size) to prevent any potential disruption to your service. Currently, AKS *doesn't support* transitioning to a new VM size within the same node pool.

## Migrate node pools to a supported VM size

Once you determine the appropriate node pools to take action on, you can [resize your node pools](./resize-node-pool.md). During the resizing process, a new node pool will be created and workloads will be migrated to the new node pool.

For more guidance on migrating from a retiring VM size, see the following migration guides:

* [General-purpose sizes migration guide](/azure/virtual-machines/migration/sizes/d-ds-dv2-dsv2-ls-series-migration-guide)
* [Storage-optimized sizes migration guide](/azure/virtual-machines/migration/sizes/d-ds-dv2-dsv2-ls-series-migration-guide)
* [GPU-accelerated sizes migration guide](/azure/virtual-machines/migration/sizes/n-series-migration)
* [Azure Dedicated Host SKU migration guide](/azure/virtual-machines/migration/dedicated-host-migration-guide)

## Next steps


