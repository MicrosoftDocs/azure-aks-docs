---
title: Use Virtual Machines Node Pools in Azure Kubernetes Service (AKS)
description: Learn how to add multiple Virtual Machine types of a similar family to a Virtual Machines node pool in an AKS cluster.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 07/28/2026
ms.author: wilsondarko
author: wdarko1

# Customer intent: As a cluster operator or developer, I want to learn how to enable my cluster to create node pools with multiple Virtual Machine types. I want to minimize capacity constraints by having greater flexibility in VM size selection.
---

# Use Virtual Machines node pools in Azure Kubernetes Service (AKS)

In this article, you'll learn about the new Virtual Machines node pool type for AKS.

With Virtual Machines node pools, AKS directly manages the provisioning and bootstrapping of every single node. For Virtual Machine Scale Sets node pools, AKS manages the model of the Virtual Machine Scale Sets and uses it to achieve consistency across all nodes in the node pool. Virtual Machines node pools enable you to orchestrate your cluster with virtual machines that best fit your individual workloads. 

By using virtual machines node pools, AKS directly manages the provisioning and bootstrapping of every single node. For virtual machine scale sets node pools, AKS manages the model of the virtual machine scale sets and uses it to achieve consistency across all nodes in the node pool. Virtual machines node pools enable you to orchestrate your cluster with virtual machines that best fit your individual workloads.

## Virtual machines node pool overview

### How it works

A node pool consists of a set of virtual machines (VMs), where different virtual machine sizes support different types of workloads. These virtual machine sizes, referred to as SKUs, are categorized into different families that are optimized for specific purposes. For more information, see [VM SKUs documentation][vm-SKU]. By using virtual machines node pools, you can perform multi-SKU manual scaling and multi-SKU autoscaling.

To enable scaling of multiple virtual machine sizes, the Virtual Machines node pool type uses a `ScaleProfile` that contains configurations indicating how the node pool can scale, specifically the desired list of virtual machine size and the count of each size. A `ManualScaleProfile` is a scale profile that specifies one desired virtual machine size and the total count of that type in the node pool. Only one virtual machine size is allowed in a `ManualScaleProfile`. You need to create a separate `ManualScaleProfile` for each virtual machine size in your node pool. When creating a new Virtual Machines node pool, you add an initial manual scale profile for a virtual machine size using the `vm-size` field and including a `node-count`. You can also add more manual scale profiles following the instructions for [adding manual scale profiles][add-a-manual-scale-profile-to-a-node-pool].

To enable scaling of multiple virtual machine sizes, the virtual machines node pool type uses a `ScaleProfile` that contains configurations indicating how the node pool can scale, specifically the desired list of virtual machine size and the count of each size. A `ManualScaleProfile` is a scale profile that specifies one desired virtual machine size and the total count of that type in the node pool. A `ManualScaleProfile` supports only one virtual machine size. You need to create a separate `ManualScaleProfile` for each virtual machine size in your node pool. When creating a new virtual machines node pool, add an initial manual scale profile for a virtual machine size by using the `vm-size` field and including a `node-count`. You can also add more manual scale profiles by following the instructions for [adding manual scale profiles][add-a-manual-scale-profile-to-a-node-pool].

Virtual machines node pools also support `Auto` mode, which means the node pool can use [cluster autoscaler][cluster-autoscaler]. A virtual machines node pool supports up to five scale profiles total across manual and autoscale modes. Each profile specifies one same-family VM SKU. Each `AutoScaleProfile` can have its own minimum and maximum node count in the node pool.

> [!NOTE]
> When creating a new Virtual Machines node pool, you can have multiple scale profiles, and you need at least one manual or auto scale profile in your node pool.

## Advantages of virtual machines node pools

Advantages of the Virtual Machines node pool type include:

- **Flexibility**: Node specifications can be updated to adapt to your current workload and needs.
- **Fine-tuned control**: Single node-level controls allow specifying and mixing nodes of different specs to lift restrictions from a single model and improve consistency.
- **Efficiency**: You can reduce the node footprint for your cluster, simplifying your operational requirements.

Virtual machines node pools support up to five scale profiles per node pool, so workloads can use multiple same-family VM SKUs without requiring a separate node pool for each SKU.

## Compare AKS compute scaling experiences

The following table highlights how Virtual Machines node pools compare with standard [Scale Set][VMSS orchestrate] node pools.

| Node pool type | Scaling and node management capabilities |
| ----------------- | ------------- |
| Virtual Machines node pool | You can add, remove, or update nodes in a node pool. Virtual machine types can be any virtual machine of the same family type (for example, D-series, A-Series, and so on). Virtual Machines node pools also allow for multiversion manual and auto scaling. |
| Virtual Machine Scale Set based node pool | You can add or remove nodes of the same size and type in a node pool. If you add a new virtual machine size to the cluster, you need to create a new node pool. |

### Which compute scaling experience should I choose on AKS?
Depending on your workload needs, there are multiple compute scaling experiences to consider. See the use cases for each:
- [Node auto provisioning](node-auto-provisioning.md): best for multiversion autoscaling, and more intelligent, flexible VM version selection (including multiple version families).
- Virtual Machines node pools: best for multiversion manual scaling and supports multiversion autoscaling. Requires specific version selection of up to five sizes per node pool.
- [Virtual Machine Scale Sets][VMSS orchestrate]: supports single-version manual scaling and single-version autoscaling. Requires specific version selection of one size per node pool.

## Virtual Machines node pool limitations
- VM Sizes specified in the pool must be of the same type. For example, GPU and non-GPU or x86 and ARM64 virtual machines cannot be in the same node pool.
- [InifiniBand][InifiniBand] isn't available.
- [Node pool snapshot][node pool snapshot] isn't supported.
- All VM sizes selected in a node pool need to be from a similar virtual machine family. For example, you can't mix an N-Series virtual machine type with a D-Series virtual machine type in the same node pool.
- You need to select all VM sizes in a node pool that support the same ephemeral OS disk placement when you use ephemeral OS disks. Because `DiffDiskPlacement` is a single pool-level value, AKS can't express different placements per VM size in one node pool.
- Virtual Machines node pools allow up to five scale profiles total per node pool. Each manual or autoscale profile specifies one VM size from the same VM family.
- Windows node pools aren't supported.
- Availability zones aren't supported. If your workload requires zone resiliency, use [Virtual Machine Scale Sets][VMSS orchestrate] node pools.

### Ephemeral OS disk placement compatibility

When you add a scale profile that mixes VM sizes with different ephemeral OS disk placements, the create or update operation fails with an `InvalidParameter` error and the subcode `EphemeralOSMixedPlacementNotSupported`.

Use one of the following remediation options:

- Use VM sizes that share the same ephemeral OS disk placement.
- Split VM sizes into separate node pools so each pool has one placement.
- Use managed OS disks instead of ephemeral OS disks.

#### Determine placement before you add a scale profile

Before you add a VM size to a Virtual Machines node pool, check SKU capabilities in the target region and verify ephemeral OS disk placement compatibility.

1. List candidate VM sizes and inspect key capabilities:

    ```azurecli-interactive
    az vm list-skus \
        --location <region> \
        --size Standard_D \
        --resource-type virtualMachines \
        --query "[].{name:name, capabilities:capabilities[?name=='EphemeralOSDiskSupported' || name=='MaxResourceVolumeMB' || name=='NvmeDiskSizeInMiB']}" \
        --output json
    ```

1. Confirm each selected VM size supports ephemeral OS disks (`EphemeralOSDiskSupported`) and identify where local disk is available (`MaxResourceVolumeMB` for temp/resource disk and `NvmeDiskSizeInMiB` for NVMe).
1. Group VM sizes so each Virtual Machines node pool uses a single compatible placement.

For example, if one profile uses `Standard_D4ds_v5` (temp/resource disk placement) and another profile uses `Standard_D4ads_v6` (NVMe placement), keep them in separate node pools or use managed OS disks.

> [!IMPORTANT]
> **Preflight and what-if behavior**
> No dedicated preflight API currently validates mixed ephemeral OS disk placement across scale profiles before deployment. `az deployment group what-if` (ARM what-if) doesn't guarantee detection of this node-pool compatibility conflict. The authoritative check occurs when AKS processes the create or update request and returns `EphemeralOSMixedPlacementNotSupported` if placements are incompatible.

## Prerequisites

- An Azure subscription. If you don't have one, you can [create a free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).
- Azure CLI version 2.85.0 or later installed and configured. To find the version, run `az --version`. For more information about installing or upgrading the Azure CLI, see [Install Azure CLI][install azure cli].
- This feature requires Kubernetes version 1.27 or greater. To upgrade your Kubernetes version, see [Upgrade AKS cluster][upgrade-aks-cluster].

> [!IMPORTANT]
> **Custom virtual network requirement**: If you deploy a Virtual Machines node pool into a custom virtual network, the cluster must use a [user-assigned managed identity][use-managed-identity] with at least [Network Contributor][network-contributor] permissions on the target subnet. Unlike Virtual Machine Scale Set node pools, Virtual Machines node pools rely solely on the cluster identity for subnet join operations and don't use first-party tokens. Clusters that use a system-assigned managed identity fail preflight validation when creating or updating a Virtual Machines node pool on a custom virtual network, returning an `InvalidParameter` error. For more information on configuring a user-assigned managed identity for your cluster, see [Use a managed identity in AKS][use-managed-identity].

## Create an AKS cluster with Virtual Machines node pools

> [!NOTE]
> Only _one_ VM size is allowed in a scale profile, and the maximum limit is _five_ VM scale profiles overall for a Virtual Machines node pool.

Create an AKS cluster with Virtual Machines node pools using the [`az aks create`][az aks create] command with the `--vm-set-type` flag set to `"VirtualMachines"`.

The following example creates a cluster named _myAKSCluster_ with a Virtual Machines node pool containing two nodes:

```azurecli-interactive
az aks create \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --vm-set-type "VirtualMachines" \
    --vm-sizes "Standard_D4s_v3" \
    --node-count 2
```

## Create an AKS cluster with Virtual Machines node pools in a custom virtual network

When you deploy Virtual Machines node pools into a custom virtual network, you must create a user-assigned managed identity and grant it Network Contributor permissions on the target subnet before you create the cluster.

1. Create a virtual network and subnet.

    ```azurecli-interactive
    az network vnet create \
        --resource-group myResourceGroup \
        --name myVnet \
        --address-prefixes 10.1.0.0/16 \
        --subnet-name mySubnet \
        --subnet-prefix 10.1.0.0/24
    ```

1. Get the subnet resource ID.

    ```azurecli-interactive
    SUBNET_ID=$(az network vnet subnet show \
        --resource-group myResourceGroup \
        --vnet-name myVnet \
        --name mySubnet \
        --query id \
        --output tsv)
    ```

1. Create a user-assigned managed identity.

    ```azurecli-interactive
    az identity create \
        --name myAKSIdentity \
        --resource-group myResourceGroup
    ```

1. Get the principal ID and resource ID of the managed identity.

    ```azurecli-interactive
    IDENTITY_PRINCIPAL_ID=$(az identity show \
        --name myAKSIdentity \
        --resource-group myResourceGroup \
        --query principalId \
        --output tsv)

    IDENTITY_RESOURCE_ID=$(az identity show \
        --name myAKSIdentity \
        --resource-group myResourceGroup \
        --query id \
        --output tsv)
    ```

1. Assign the Network Contributor role to the managed identity on the target subnet.

    ```azurecli-interactive
    az role assignment create \
        --assignee $IDENTITY_PRINCIPAL_ID \
        --role "Network Contributor" \
        --scope $SUBNET_ID
    ```

    It can take up to 60 minutes to propagate the permissions granted to your cluster's managed identity.

1. Verify that the role assignment exists on the target subnet before you create the cluster.

    ```azurecli-interactive
    az role assignment list \
        --assignee $IDENTITY_PRINCIPAL_ID \
        --role "Network Contributor" \
        --scope $SUBNET_ID \
        --query "[].{Role:roleDefinitionName, Scope:scope}" \
        --output table
    ```

    Continue when the output shows the Network Contributor role at the target subnet scope.

1. Create the AKS cluster with Virtual Machines node pools in your custom virtual network.

    ```azurecli-interactive
    az aks create \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --vm-set-type "VirtualMachines" \
        --vm-sizes "Standard_D4s_v3" \
        --node-count 2 \
        --vnet-subnet-id $SUBNET_ID \
        --assign-identity $IDENTITY_RESOURCE_ID
    ```

## Add a Virtual Machines node pool to an existing cluster

Add a Virtual Machines node pool to an existing cluster using the [`az aks nodepool add`][az aks nodepool add] command with the `--vm-set-type` flag set to `"VirtualMachines"`.

The following example adds a Virtual Machines node pool named _myvmpool_ to the _myAKSCluster_ cluster. The node pool creates a ManualScaleProfile with `--vm-sizes` set to `Standard_D4s_v3` and a `--node-count` of 3:

```azurecli-interactive
az aks nodepool add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myvmpool \
    --vm-set-type "VirtualMachines" \
    --vm-sizes "Standard_D4s_v3" \
    --node-count 3
```

## Add a manual scale profile to a node pool

Add a manual scale profile to a node pool using the [`az aks nodepool manual-scale add`][az aks nodepool manual-scale add] with the `--vm-sizes` flag set to `"Standard_D2s_v3"` and the `node-count` set to 2.

The following example adds a manual scale profile to node pool _myvmpool_ in cluster _myAKSCluster_. The node pool includes two nodes with a VM SKU of `Standard_D2s_v3`:

```azurecli-interactive
az aks nodepool manual-scale add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myvmpool \
    --vm-sizes "Standard_D2s_v3" \
    --node-count 2
```

## Update an existing manual scale profile

Update an existing manual scale profile in a node pool using the [`az aks nodepool manual-scale update`][az aks nodepool manual-scale update] command with the `--vm-sizes` flag set to `"Standard_D2s_v3"`.

> [!NOTE]
> Use the `--current-vm-sizes` parameter to specify the size of the existing node pool that you want to update. You can update `--vm-sizes` and/or `--node-count`. When using other tools or REST APIs, you need to pass in a full `agentPoolProfiles.virtualMachinesProfile.scale` field when updating the node pool scale profile.

The following example updates a manual scale profile to the _myvmpool_ node pool in the _myAKSCluster_ cluster. The command updates the number of nodes to five and changes the VM SKU from `Standard_D4s_v3` to `Standard_D8s_v3`:

```azurecli-interactive
az aks nodepool manual-scale update \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myvmpool \
    --current-vm-sizes "Standard_D4s_v3" \
    --vm-sizes "Standard_D8s_v3" \
    --node-count 5
```

## Delete a manual scale profile

Delete an existing manual scale profile using the [`az aks nodepool manual-scale delete`][az aks nodepool manual-scale delete] command.

> [!NOTE]
> The `--current-vm-sizes` parameter specifies the size of the existing node pool to be deleted. When using other tools or REST APIs to update the node pool scale profile, pass in a full `agentPoolProfiles.virtualMachinesProfile.scale` field.

The following example deletes the manual scale profile for the `Standard_D8s_v3` VM SKU in the _myvmpool_ node pool.

```azurecli-interactive
az aks nodepool manual-scale delete \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myvmpool \
    --current-vm-sizes "Standard_D8s_v3"
```

## Cluster autoscaler with Virtual Machines Node Pools
Virtual Machines node pools support [cluster autoscaler][cluster-autoscaler]. This support allows autoscaling for both same VM size node pools and multiple VM size node pools. You can enable this feature by using the flag `--enable-cluster-autoscaler` during cluster creation, while adding a new node pool, or when updating an existing manual node pool. 

When using cluster autoscaler with Virtual Machine node pools, the behavior is as follows:
- Scale up: autoscaler responds to pending pod pressure, and can scale up the node count of a node pool with multiple VM sizes in that node pool. 
- Scale down: autoscaler chooses a specific node based on the utilization of the node. You can configure `scale-down-utilization-threshold` to adjust when cluster autoscaling triggers a scaling action. See [cluster autoscaler documentation][cluster-autoscaler] for more information on configuring autoscaling.

### Limitations
- This feature is only available in public cloud.
- GPU nodes aren't currently supported.

## Create an AKS cluster with Virtual Machines node pools and cluster autoscaler enabled
- Create an AKS cluster with Virtual Machines node pools using the [`az aks create`][az aks create] command with the `--vm-set-type` flag set to `"VirtualMachines"` and with the flag `--enable-cluster-autoscaler`.

The following example creates a cluster named *myAKSCluster* with a Virtual Machines node pool that uses the node size `Standard_D4s_v3`, a minimum node count of 2, and a maximum node count of 5:

```azurecli-interactive
az aks create \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --vm-set-type "VirtualMachines" \
    --node-vm-size "Standard_D4s_v3" \
    --enable-cluster-autoscaler \
    --min-count 2 \
    --max-count 5
```

## Add a Virtual Machines node pool with cluster autoscaler enabled to an existing cluster
- Create a Virtual Machines node pool using the [`az aks nodepool add`][az aks nodepool add] command with the `--vm-set-type` flag set to `"VirtualMachines"` and with the flag `--enable-cluster-autoscaler`.

The following example adds Virtual Machines node pool *myvmpool* with cluster autoscaler enabled to a cluster named *myAKSCluster* using virtual machine size of "Standard_D4s_v3", and a minimum node count of 2 and max count of 5:

```azurecli-interactive
az aks nodepool add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myvmpool \
    --vm-set-type "VirtualMachines" \
    --node-vm-size "Standard_D4s_v3" \
    --enable-cluster-autoscaler \
    --min-count 2 \
    --max-count 5
```

## Update cluster autoscaler settings for a Virtual Machines node pool

- Update the [cluster autoscaler][cluster-autoscaler] node count settings for a Virtual Machines node pool using the [`az aks nodepool auto-scale update`][az aks nodepool auto-scale update] command.

The following example updates settings for Virtual Machines node pool *myvmpool* in cluster named *myAKSCluster* using virtual machine size of "Standard_D4s_v3":

```azurecli-interactive
az aks nodepool auto-scale update \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myvmpool \
    --current-node-vm-size "Standard_D4s_v3" \
    --min-count 3 \
    --max-count 7
```

## Switch Virtual Machines node pool scale profiles from manual to autoscale mode

The following example updates Virtual Machines node pool *myvmpool* in the cluster named *myAKSCluster*, converting all manual scale profiles to autoscale profiles with the same minimum and maximum node count:

```azurecli-interactive
az aks nodepool update \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myvmpool \
    --enable-cluster-autoscaler \
    --min-count 2 \
    --max-count 5
```

## Disable cluster autoscaler in a Virtual Machines node pool

You can disable [cluster autoscaler][cluster-autoscaler], or switch all the scale profiles in a virtual machine node pool from `Auto` mode to `Manual` mode.

The following example disables the cluster autoscaler for the Virtual Machines node pool *myvmpool* in the cluster named *myAKSCluster*. It switches all scale profiles from `Auto` mode to `Manual` mode:

```azurecli-interactive
az aks nodepool update \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myvmpool \
    --disable-cluster-autoscaler
```

## Next steps

In this article, you learned how to use Virtual Machines node pools in AKS. To learn more about node pools in AKS, see [Create node pools][create node pools].

<!-- EXTERNAL LINKS -->

<!-- INTERNAL LINKS -->
[add-a-manual-scale-profile-to-a-node-pool]: /azure/aks/virtual-machines-node-pools#add-a-manual-scale-profile-to-a-node-pool
[install azure cli]: /cli/azure/install-azure-cli#install-azure-cli
[az provider register]: /cli/azure/provider#az-provider-register
[az feature show]: /cli/azure/feature#az-feature-show
[az feature registration create]: /cli/azure/feature/registration#az-feature-registration-create
[az aks get credentials]: /cli/azure/aks#az-aks-get-credentials
[az aks create]: /cli/azure/aks#az-aks-create
[az aks nodepool add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az aks nodepool manual-scale add]: /cli/azure/aks/nodepool/manual-scale#az-aks-nodepool-manual-scale-add
[az aks nodepool manual-scale update]: /cli/azure/aks/nodepool/manual-scale#az-aks-nodepool-manual-scale-update
[az aks nodepool manual-scale delete]: /cli/azure/aks/nodepool/manual-scale#az-aks-nodepool-manual-scale-delete
[az aks nodepool auto-scale update]: /cli/azure/aks/nodepool/auto-scale#az-aks-nodepool-auto-scale-update
[az aks nodepool update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[node pool snapshot]: node-pool-snapshot.md
[cluster-autoscaler]: cluster-autoscaler-overview.md
[InifiniBand]: /azure/virtual-machines/extensions/enable-infiniband
[vm-SKU]: /azure/virtual-machines/sizes/overview
[VMSS]: /azure/virtual-machine-scale-sets/overview
[azure cli]: /cli/azure/get-started-with-azure-cli
[az extension update]: /cli/azure/extension#az-extension-update
[az account set]: /cli/azure/account#az-account-set
[create node pools]: create-node-pools.md
[upgrade-aks-cluster]: tutorial-kubernetes-upgrade-cluster.md
[VMSS orchestrate]: /azure/virtual-machine-scale-sets/virtual-machine-scale-sets-orchestration-modes
[use-managed-identity]: managed-identity-overview.md
[network-contributor]: /azure/role-based-access-control/built-in-roles#network-contributor
