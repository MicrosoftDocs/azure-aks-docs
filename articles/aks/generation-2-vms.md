---
title: Use Generation 2 (Gen 2) Virtual Machines (VMs) on Azure Kubernetes Service (AKS)
description: Learn how to check available Gen 2 VM sizes, create AKS node pools with Gen 2 VMs, migrate from Gen 1 to Gen 2 VMs on AKS, and verify VM generation.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-nodes
ms.date: 08/05/2025
ms.author: schaffererin
author: schaffererin
# Customer intent: As a cluster operator or developer, I want to learn how to use Generation 2 (Gen 2) Virtual Machines (VMs) on Azure Kubernetes Service (AKS) so that I can take advantage of the latest features and performance improvements.
---

# Use Generation 2 (Gen 2) virtual machines (VMs) on Azure Kubernetes Service (AKS)

In this article, you learn how to use Generation 2 (Gen 2) virtual machines (VMs) on Azure Kubernetes Service (AKS), including how to check available Gen 2 VM sizes, create AKS node pools with Gen 2 VMs, migrate from Gen 1 to Gen 2 VMs on AKS, and verify the VM generation of your AKS nodes.

## Before you begin

- Review the [Virtual machine (VM) sizes, generations, and features for Azure Kubernetes Service (AKS)](./aks-virtual-machine-sizes.md) article to understand VM generations and features supported on AKS.

## Check available Gen 2 VM sizes

Check available Gen 2 VM sizes using the [`az vm list-skus`][az-vm-list-skus] command.

```azurecli-interactive
# Set environment variables
export LOCATION=<your-region>
export VM_SIZE=<vm-size-to-check>

# Check if the VM size is available in the specified location
az vm list-skus --location $LOCATION --size $VM_SIZE --output table
```

For a breakdown of what VM sizes support Gen 2, see [Support for Gen 2 VMs on Azure](/azure/virtual-machines/generation-2).

## Create a node pool with a Gen 2 VM

### [Linux node pool](#tab/linux-node-pool)

By default, Linux uses the Gen 2 node image unless the VM size doesn't support Gen 2.

Create a Linux node pool with a Gen 2 VM using the default [node pool creation](./create-node-pools.md) process.

### [Windows node pool](#tab/windows-node-pool)

By default, Windows Server 2022 uses the Gen 1 node image. If you want to use a Gen 2 node image, create a Windows node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--aks-custom-headers UseWindowsGen2VM=true` custom header `--aks-custom-headers UseWindowsGen2VM=true`:

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<resource-group-name>
export CLUSTER_NAME=<cluster-name>
export NODE_POOL_NAME=<node-pool-name>
export VM_SIZE=<supported-generation-2-vm-size>

# Create a Windows node pool with a Gen 2 VM
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODE_POOL_NAME --node-vm-size $VM_SIZE --os-type Windows --os-sku Windows2022 --aks-custom-headers UseWindowsGen2VM=true
```

Windows Server 2025+ uses the Gen 2 node image by default, so you don't need to specify the custom header.

---

## Migrate an existing node pool to Gen 2

### [Linux node pool](#tab/linux-node-pool)

If you're using a VM size that only supports Gen 1, you can update your node pool to a VM size that supports Gen 2 by running the [`az aks nodepool update`][az-aks-nodepool-update] command. 

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<resource-group-name>
export CLUSTER_NAME=<cluster-name>
export NODE_POOL_NAME=<node-pool-name>
export VM_SIZE=<supported-generation-2-vm-size>

# Update a Linux node pool to use a Gen 2 VM
az aks nodepool update --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODE_POOL_NAME --node-vm-size $VM_SIZE --os-type Linux
```

> [!NOTE]
> Some VM sizes that support Gen 2 require a different disk controller. You can't resize a node pool directly from a Gen1-only size (for example, `Standard_D3_v2`) to a Gen2, NVMe-only size (for example, `Standard_D4s_v6`). Use [two-step resize][two-step-resize] or [create new node pool][resize-new-node-pool] for the migration.

### [Windows node pool](#tab/windows-node-pool)

Windows Server 2022 node pools use the Gen 1 node image by default. To move a Windows node pool to Gen 2, use one of these options:

- Upgrade the node pool to Windows Server 2025 in place. Windows Server 2025 uses the Gen 2 image on VM sizes that support Gen 2, and requires FIPS. You can also change the VM size in the same operation.

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<resource-group-name>
export CLUSTER_NAME=<cluster-name>
export NODE_POOL_NAME=<node-pool-name>
export VM_SIZE=<supported-generation-2-vm-size>

# Update a Windows node pool to use a Gen 2 VM
az aks nodepool update --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODE_POOL_NAME \
  --os-sku Windows2025 --enable-fips-image [--node-vm-size $VM_SIZE]
```

- Create a new Windows Server 2022 node pool with Gen 2, and then [migrate your workload][resize-new-node-pool]:

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<resource-group-name>
export CLUSTER_NAME=<cluster-name>
export NODE_POOL_NAME=<node-pool-name>
export VM_SIZE=<supported-generation-2-vm-size>

# Create a new Windows node pool to use a Gen 2 VM
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODE_POOL_NAME \
  --os-type Windows --os-sku Windows2022 --node-vm-size $VM_SIZE --aks-custom-headers UseWindowsGen2VM=true
```

>[!NOTE]
> Some VM sizes that support Gen 2 require a different disk controller. In-place node pool updates can't move Windows node pools to NVMe-only VM sizes (for example, v6 or v7). To use those sizes, [create new node pool][resize-new-node-pool] for the migration.

---

## Check if you're using a Gen 2 node image

Verify a successful node pool creation using the [`az aks nodepool show`][az-aks-nodepool-show] command and check that the `nodeImageVersion` contains `gen2` in the output.

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<resource-group-name>
export CLUSTER_NAME=<cluster-name>
export NODE_POOL_NAME=<node-pool-name>

# Show node pool details
az aks nodepool show --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODE_POOL_NAME --output table
```

## Next steps

- To learn more about Gen 2 VMs, see [Support for Generation 2 VMs on Azure](/azure/virtual-machines/generation-2)
- To learn more about supported Gen 2 node images, see [Node images](./node-images.md)

<!-- LINKS -->
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-nodepool-show]: /cli/azure/aks/nodepool#az-aks-nodepool-show
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[az-vm-list-skus]: /cli/azure/vm#az-vm-list-skus
[two-step-resize]: resize-node-pool.md#resize-from-a-gen1-only-size-to-an-nvme-only-size
[resize-new-node-pool]: resize-node-pool.md#option-2-resize-by-creating-a-new-node-pool