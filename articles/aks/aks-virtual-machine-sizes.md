---
title: Virtual machine (VM) sizes, generations, and features for Azure Kubernetes Service (AKS)
description: Learn about VM fundamentals on AKS, like different VM sizes, generations, and features. When provisioning, learn about how to check for available VM sizes, understand why some VM sizes might not be available, and see behind the scenes when a VM size retires.
ms.topic: overview
ms.service: azure-kubernetes-service
ms.date: 08/05/2025
ms.author: schaffererin
author: schaffererin
---

# Virtual machine (VM) sizes, generations, and features for Azure Kubernetes Service (AKS)

Azure Kubernetes Service (AKS) supports a variety of virtual machine (VM) sizes, generations, and features to accommodate different workloads and performance requirements. This article provides an overview of available VM sizes and generations for AKS, how to check for available VM sizes in your region, reasons why certain VM sizes might not be available, and what happens when a VM size retires.

## VM support on AKS

Azure supports both Generation 1 (Gen 1) and [Generation 2 (Gen 2) virtual machines (VMs)](/azure/virtual-machines/generation-2). With some [exceptions](/windows-server/virtualization/hyper-v/plan/should-i-create-a-generation-1-or-2-virtual-machine-in-hyper-v), we generally recommend [migrating to Generation 2 VMs](#use-gen-2-vms-on-aks) to take advantage of the newest features and functionalities in Azure VMs.

The VM size and operating system (OS) you select when creating an AKS node pool determines the VM generation and [node image](./node-images.md) used. Check the [list of supported sizes](/azure/virtual-machines/generation-2#generation-2-vm-sizes) to see if your SKU supports or requires Gen 2.

### Limitations

There are some limitations to take into account when choosing a VM generation and/or OS:

- Trusted Launch can only be enabled on VM sizes that support Gen 2.
- Confidential VM sizes always use Gen 2 on AKS.
- Arm64 VM sizes always use Gen 2 on AKS.
- Windows Server 2019 node pools don't support Gen 2 VM sizes.
- Windows Server 2022 node pools require use of a custom header to use Gen 2.

To use Gen 2 VMs on AKS, see [Use Gen 2 VMs](#use-gen-2-vms-on-aks).

## Available VM features

AKS supports a variety of VM features that enhance security, performance, and functionality. Some key features include:

- [**Node autoprovisioning (NAP)**](./node-autoprovision.md) uses pending pod resource requirements to decide the optimal VM configuration to run your workloads efficiently and cost-effectively.
- [**Virtual Machines node pools**](./virtual-machines-node-pools.md) provide a better experience for dynamic workloads and high availability requirements. Virtual Machines node pools enable you to set up multiple similar-family VMs in a single node pool. Your workloads are automatically scheduled on the available resources you configure.

## Supported VM sizes

For in-depth information about VM sizes available in Azure, see [Azure VM sizes](/azure/virtual-machines/sizes/overview?tabs=breakdownseries%2Cgeneralsizelist%2Ccomputesizelist%2Cmemorysizelist%2Cstoragesizelist%2Cgpusizelist%2Cfpgasizelist%2Chpcsizelist). To view supported Gen 2 VM sizes, see [Generation 2 VM sizes](/azure/virtual-machines/generation-2).

AKS also supports the following VM types and features:

- [Confidential VMs (CVMs)](./use-cvm.md)
- [Arm-based processor (Arm64) VMs](./use-arm64-vms.md)
- [GPU-optimized VMs](/azure/virtual-machines/sizes/overview?tabs=breakdownseries%2Cgeneralsizelist%2Ccomputesizelist%2Cmemorysizelist%2Cstoragesizelist%2Cgpusizelist%2Cfpgasizelist%2Chpcsizelist#gpu-accelerated)
- [Trusted Launch](./use-trusted-launch.md)
- [Federal Information Process Standard (FIPS)](./enable-fips-nodes.md)

### Default behavior for supported VM sizes

There are three scenarios when creating a node pool with a supported VM size:

1. If the VM size supports only Gen 1, the default behavior for both Linux and Windows node pools is to use the Gen 1 node image.
2. If the VM size supports only Gen 2, the default behavior for both Linux and Windows node pools is to use the Gen 2 node image. Windows Server 2022 node pools require a custom header to use a VM size that only supports Gen 2. For more information, see [Create a Windows node pool with a Gen 2 VM](#create-a-node-pool-with-a-gen-2-vm).
3. If the VM size supports both Gen 1 and Gen 2, the default behavior for both Linux and Windows (in Windows Server 2025+) nodes pools is to use the Gen 2 node image. To use the Gen 2 node image for Windows Server 2022, see [Create a Windows node pool with a Gen 2 VM](#create-a-node-pool-with-a-gen-2-vm).

## Check available VM sizes

Check available VM sizes using the [`az vm list-skus`][az-vm-list-skus] command.

```azurecli-interactive
az vm list-skus --location <your-location> --output table
```

## Why certain VM sizes might not be available

There are several reasons why certain VM sizes might not be available, including:

- **Quota limits**: All Azure services set default limits and quotas for resources and features. For more information, see the following resources:

    > [!NOTE]
    > - For ***user node pools***, VM sizes with *fewer than two vCPUs and two GBs of memory (RAM)* might not be used by default.
    > - For ***system node pools***, VM sizes with *fewer than two vCPUs and four GBs of memory (RAM)* might not be used by default. To ensure that you can reliably schedule the required `kube-system` pods and your applications, we recommend that you **do not use any [B series VMs](/azure/virtual-machines/sizes/general-purpose/bv1-series) or [Av1 series VMs](/azure/virtual-machines/sizes/retirement/av1-series-retirement)**.

  - [Quotas and regional limits for Azure Kubernetes Service (AKS)](./quotas-skus-regions.md)
  - [Check your quota usage](/azure/virtual-machines/quotas)
  - [Request a quota increase through an Azure support request](https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade/newsupportrequest) (for **Issue type**, select **Quota**)

- **VM sizes in preview**: VM sizes in preview might not be available to you if you haven't registered the preview flag for the VM size.
- **Blocked by AKS**: Some VM sizes might not be available by default in AKS. These sizes might require additional testing or validation to ensure compatibility with AKS. If you need a specific VM size that isn't available to you, you can [submit a GitHub issue request](https://github.com/Azure/AKS/issues).

Make sure you understand which features your workloads need and choose a VM size that meets those requirements. Later VM versions typically have better performance and improved features. For example[Gen 2 VMs](#use-gen-2-vms-on-aks) have increased security and performance benefits over Gen 1 VMs.

## What happens when a VM size retires?

When a VM size or series reaches its retirement date, the VM is deallocated. VM deallocation causes your AKS node pools to break. To check the retirement status of a VM size, see [Retired Azure VM size series](/azure/virtual-machines/sizes/retirement/retired-sizes-list) or perform a search in [Azure Updates](https://azure.microsoft.com/updates). To check the VM size of your node pools, use the [`az aks nodepool list`][az-aks-nodepool-list] command and query for the `vmSize` property:

```azurecli-interactive
az aks nodepool list --resource-group <your-resource-group> --cluster-name <your-cluster-name> --query "[].{Name:name, VMSize:vmSize}" --output table
```

If you're using a VM size that's retiring/retired, we recommend [migrating your node pools to a supported VM size](#migrate-node-pools-to-a-supported-vm-size) to prevent any potential disruption to your service. Currently, AKS *doesn't support* transitioning to a new VM size within the same node pool.

## Migrate node pools to a supported VM size

Once you determine the appropriate node pools to take action on, you can [resize your node pools](./resize-node-pool.md). During the resizing process, a new node pool is created and workloads are migrated to the new node pool.

For more information on migrating to a new VM size, see the following resources:

- [Migrate from Gen 1 to Gen 2 VMs](#use-gen-2-vms-on-aks)
- [General-purpose sizes migration guide](/azure/virtual-machines/migration/sizes/d-ds-dv2-dsv2-ls-series-migration-guide)
- [Storage-optimized sizes migration guide](/azure/virtual-machines/migration/sizes/d-ds-dv2-dsv2-ls-series-migration-guide)
- [GPU-accelerated sizes migration guide](/azure/virtual-machines/migration/sizes/n-series-migration)
- [Azure Dedicated Host SKU migration guide](/azure/virtual-machines/migration/dedicated-host-migration-guide)

## Use Gen 2 VMs on AKS

Gen 2 VMs are generally Azure's newer offerings and boast exclusive features over Gen 1 VMs, such as increased memory, improved CPU performance, support for NVMe disks, and support for [Trusted Launch](./use-trusted-launch.md).

While we generally recommend running Gen 2 VMs, you should make sure that the generation you choose supports your requirements. To learn more about the differences between generations, and when one might make more sense than the other, see [Should I create a Gen 1 or 2 VM in Hyper-V?](/windows-server/virtualization/hyper-v/plan/should-i-create-a-generation-1-or-2-virtual-machine-in-hyper-v)

### Check available Gen 2 VM sizes

Check available Gen 2 VM sizes using the [`az vm list-skus`][az-vm-list-skus] command.

```azurecli-interactive
az vm list-skus --location <location> --size <vm-size> --output table
```

For a breakdown of what VM sizes support Gen 2, see [Support for Gen 2 VMs on Azure](/azure/virtual-machines/generation-2).

### Create a node pool with a Gen 2 VM

#### [Linux node pool](#tab/linux-node-pool)

By default, Linux uses the Gen 2 node image unless the VM size doesn't support Gen 2.

Create a Linux node pool with a Gen 2 VM using the default [node pool creation](./create-node-pools.md) process.

#### [Windows node pool](#tab/windows-node-pool)

By default, Windows Server 2022 uses the Gen 1 node image. If you want to use a Gen 2 node image, create a Windows node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--aks-custom-headers UseWindowsGen2VM=true` custom header `--aks-custom-headers UseWindowsGen2VM=true`:

```azurecli-interactive
az aks nodepool add --resource-group <resource-group-name> --cluster-name <cluster-name> --name <node-pool-name> --node-vm-size <supported-generation-2-vm-size> --os-type Windows --os-sku Windows2022 --aks-custom-headers UseWindowsGen2VM=true
```

Windows Server 2025+ uses the Gen 2 node image by default, so you don't need to specify the custom header.

---

### Migrate an existing node pool to Gen 2

#### [Linux node pool](#tab/linux-node-pool)

If you're using a VM size that only supports Gen 1, you can update your node pool to a VM size that supports Gen 2 using the [`az aks nodepool update`][az-aks-nodepool-update] command. This update changes your node image from Gen 1 to Gen 2.

```azurecli-interactive
az aks nodepool update --resource-group <resource-group-name> --cluster-name <cluster-name> --name <node-pool-name> --node-vm-size <supported-generation-2-vm-size> --os-type Linux
```

#### [Windows node pool](#tab/windows-node-pool)

If you're Windows Server 2022 with the Gen 1 image, you can update your node pool to use Gen 2 by selecting a VM size that supports Gen 2 using the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--aks-custom-headers UseWindowsGen2VM=true` custom header:

```azurecli-interactive
az aks nodepool update --resource-group <resource-group-name> --cluster-name <cluster-name> --name <node-pool-name> --node-vm-size <supported-generation-2-vm-size> --os-type Windows --os-sku Windows2022 --aks-custom-headers UseWindowsGen2VM=true
```

---

### Check if you're using a Gen 2 node image

Verify a successful node pool creation using the [`az aks nodepool show`][az-aks-nodepool-show] command and check that the `nodeImageVersion` contains `gen2` in the output.

## Next steps

- To learn more about Gen 2 VMs, see [Support for Generation 2 VMs on Azure](/azure/virtual-machines/generation-2)
- To learn more about supported Gen 2 node images, see [Node images](./node-images.md)

<!-- LINKS -->
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az_aks_nodepool_add
[az-aks-nodepool-show]: /cli/azure/aks/nodepool#az_aks_nodepool_show
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az_aks_nodepool_update
[az-vm-list-skus]: /cli/azure/vm#az_vm_list_skus
