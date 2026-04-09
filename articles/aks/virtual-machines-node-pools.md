---
title: Use Virtual Machines Node Pools in Azure Kubernetes Services (AKS)
description: Learn how to add multiple Virtual Machine types of a similar family to a Virtual Machines node pool in an AKS cluster.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 03/18/2026
ms.author: wilsondarko
author: wdarko1

# Customer intent: As a cluster operator or developer, I want to learn how to enable my cluster to create node pools with multiple Virtual Machine types. I want to minimize capacity constraints by having greater flexibility in VM size selection.
---

# Use Virtual Machines node pools in Azure Kubernetes Service (AKS)

In this article, you'll learn about the new Virtual Machines node pool type for AKS.

With Virtual Machines node pools, AKS directly manages the provisioning and bootstrapping of every single node. For Virtual Machine Scale Sets node pools, AKS manages the model of the Virtual Machine Scale Sets and uses it to achieve consistency across all nodes in the node pool. Virtual Machines node pools enable you to orchestrate your cluster with virtual machines that best fit your individual workloads. 

## Overview

### How it works

A node pool consists of a set of virtual machines (VM), where different virtual machine sizes are designated to support different types of workloads. These virtual machine sizes, referred to as SKUs, are categorized into different families that are optimized for specific purposes. For more information, see [VM SKUs][vm-SKU]. With Virtual Machine node pools, you can perform multi-SKU manual scaling, or single SKU autoscaling. 

To enable scaling of multiple virtual machine sizes, the Virtual Machines node pool type uses a `ScaleProfile` that contains configurations indicating how the node pool can scale, specifically the desired list of virtual machine size and the count of each size. A `ManualScaleProfile` is a scale profile that specifies one desired virtual machine size and the total count of that type in the node pool. Only one virtual machine size is allowed in a `ManualScaleProfile`. You need to create a separate `ManualScaleProfile` for each virtual machine size in your node pool. When creating a new Virtual Machines node pool, you add an initial manual scale profile for a virtual machine size using the `vm-size` field and including a `node-count`. You can also add more manual scale profiles following the instructions for [adding manual scale profiles][add-a-manual-scale-profile-to-a-node-pool].

Virtual Machine node pools also allows `Auto` mode, which means the node pool can use [cluster autoscaler][cluster-autoscaler]. Any Virtual Machine node pools in `Auto` mode can only use one Virtual Machine size at a time. 

> [!NOTE]
> When creating a new Virtual Machines node pool, you can have multiple scale profiles, and you need at least one manual scale profile in your node pool. When enabling cluster autoscaler with Virtual Machine node pools, you must remove all but one scale profile that the node pool uses for scaling action. 

### Advantages

Advantages of the Virtual Machines node pool type include:

- **Flexibility**: Node specifications can be updated to adapt to your current workload and needs.
- **Fine-tuned control**: Single node-level controls allow specifying and mixing nodes of different specs to lift restrictions from a single model and improve consistency.
- **Efficiency**: You can reduce the node footprint for your cluster, simplifying your operational requirements.

Virtual Machines node pools provide a better experience for dynamic workloads and high availability requirements. Virtual Machines node pools enable you to set up multiple similar-family virtual machines in one node pool. Your workload is automatically scheduled on the available resources that you configure.

### Feature comparison

The following table highlights how Virtual Machines node pools compare with standard [Scale Set][VMSS orchestrate] node pools.

| Node pool type | Capabilities |
| ----------------- | ------------- |
| Virtual Machines node pool | You can add, remove, or update nodes in a node pool. Virtual machine types can be any virtual machine of the same family type (for example, D-series, A-Series, etc.). Virtual Machine node pools also allow for multi-SKU manual scaling. |
| Virtual Machine Scale Set based node pool | You can add or remove nodes of the same size and type in a node pool. If you add a new virtual machine size to the cluster, you need to create a new node pool. |

#### Which compute scaling experience should I choose on AKS? 
Depending on your workload needs, there are multiple compute scaling experiences to consider. See the use cases for each:
- [Node auto provisioning](node-autoprovision.md): best for multi SKU autoscaling
= Virtual Machine node pools: best for multi-SKU manual scaling, and supports single SKU autoscaling. 
- [Virtual Machine scale sets][VMSS orchestrate]: supports single SKU manual scaling and single SKU autoscaling. 



### Limitations
- VM Sizes specified in the pool must be of the same type. For example, GPU and non-GPU or x86 and ARM64 virtual machines cannot be in the same node pool.
- [InifiniBand][InifiniBand] isn't available.
- [Node pool snapshot][node pool snapshot] isn't supported.
- All VM sizes selected in a node pool need to be from a similar virtual machine family. For example, you can't mix an N-Series virtual machine type with a D-Series virtual machine type in the same node pool.
- Virtual Machines node pools allow up to five different virtual machine sizes per node pool.
- When using [cluster autoscaler][cluster-autoscaler], only one scale profile is allowed. To enable cluster autoscaler in a virtual machine node pool with multiple scale profiles, remove all but one scale profile. 

## Prerequisites

- An Azure subscription. If you don't have one, you can [create a free account](https://azure.microsoft.com/free).
- Azure CLI version 2.73.0 or later installed and configured. To find the version, run `az --version`. For more information about installing or upgrading the Azure CLI, see [Install Azure CLI][install azure cli]
- This feature requires kubernetes version 1.27 or greater. To upgrade your kubernetes version, see [Upgrade AKS cluster][upgrade-aks-cluster]

> [!IMPORTANT]
> **Custom virtual network requirement**: If you deploy a Virtual Machines node pool into a custom virtual network, the cluster must use a [user-assigned managed identity][use-managed-identity] with at least [Network Contributor][network-contributor] permissions on the target subnet. Unlike Virtual Machine Scale Set node pools, Virtual Machines node pools rely solely on the cluster identity for subnet join operations and don't use first-party tokens. Clusters that use a system-assigned managed identity fail preflight validation when creating or updating a Virtual Machines node pool on a custom virtual network, returning an `InvalidParameter` error. For more information on configuring a user-assigned managed identity for your cluster, see [Use a managed identity in AKS][use-managed-identity].

## Create an AKS cluster with Virtual Machines node pools

> [!NOTE]
> Only _one_ VM size is allowed in a scale profile, and the maximum limit is _five_ VM scale profiles overall for a Virtual Machines node pool.

Create an AKS cluster with Virtual Machines node pools using the [`az aks create`][az aks create] command with the `--vm-set-type` flag set to `"VirtualMachines"`.

The following example creates a cluster named _myAKSCluster_ with a Virtual Machines node pool containing two nodes, generates SSH keys, sets the load balancer SKU to _standard_, and sets the Kubernetes version to _1.31.0_:

```azurecli-interactive
az aks create \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --vm-set-type "VirtualMachines" \
    --vm-sizes "Standard_D4s_v3"
    --node-count 2 \
    --kubernetes-version 1.31.0
```

## Create an AKS cluster with Virtual Machines node pools in a custom virtual network

When you deploy Virtual Machines node pools into a custom virtual network, before you create the cluster, you must create a user-assigned managed identity and grant it Network Contributor permissions on the virtual network.

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

1. Assign the Network Contributor role to the managed identity on the virtual network.

    ```azurecli-interactive
    VNET_ID=$(az network vnet show \
        --resource-group myResourceGroup \
        --name myVnet \
        --query id \
        --output tsv)

    az role assignment create \
        --assignee $IDENTITY_PRINCIPAL_ID \
        --role "Network Contributor" \
        --scope $VNET_ID
    ```

    It can take up to 60 minutes to propagate the permissions granted to your cluster's managed identity. Use the following command to check the status.

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

## Create a cluster with Windows enabled and a Windows Virtual Machine node pool

Virtual Machine node pools are available in Windows enabled clusters. The following example creates a cluster named _myAKSCluster_ with a Virtual Machines node pool. These steps create a Linux system pool at first.

1. Create a username to use as administrator credentials for the Windows Server nodes on your cluster. The following commands prompt you for a username and sets it to `WINDOWS_USERNAME` for use in a later command.

    ```bash
    echo "Please enter the username to use as administrator credentials for Windows Server nodes on your cluster: " && read WINDOWS_USERNAME
    ```

1. Create a password for the administrator username you created in the previous step. The password must be a minimum of 14 characters and meet the [Windows Server password complexity requirements][windows-server-password].

    ```bash
    echo "Please enter the password to use as administrator credentials for Windows Server nodes on your cluster: " && read WINDOWS_PASSWORD
    ```

1. Create an AKS cluster with Windows enabled and Virtual Machines type node pools using the [`az aks create`][az aks create] command with the `--vm-set-type` flag set to `"VirtualMachines"`.

    ```azurecli-interactive
    az aks create \
       --resource-group myResourceGroup \
       --name myAKSCluster \
       --node-count 2 \
       --enable-addons monitoring \
       --generate-ssh-keys \
       --windows-admin-username $WINDOWS_USERNAME \
       --windows-admin-password $WINDOWS_PASSWORD \
       --vm-set-type "VirtualMachines" \
       --network-plugin azure
    ```

1. Add a Virtual Machines node pool to an existing Windows enabled cluster using the [`az aks nodepool add`][az aks nodepool add] command with the `--vm-set-type` flag set to `"VirtualMachines"`. The following example adds a Virtual Machines node pool named _npwin_ to the _myAKSCluster_ cluster:

    ```azurecli-interactive
    az aks nodepool add
       --resource-group myResourceGroup \
       --cluster-name myAKSCluster \
       --os-type Windows \
       --name npwin \
       --vm-sizes "Standard_D2s_V3" \
       --node-count 1
       --vm-set-type "VirtualMachines"
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

## Cluster autoscaler with Virtual Machines Node Pools (preview)
Virtual Machines node pools support [cluster autoscaler][cluster-autoscaler]. This can be enabled using the flag `--enable-cluster-autoscaler` during cluster creation, while adding a new node pool, or in updating an existing manual node pool.

When using cluster autoscaler with Virtual Machine node pools, 
- Scale up: autoscaler responds to pending pod pressure, and scale up the node count of a node pool with the same type of single SKU in that node pool. 
- Scale down: a specific node is chosen by autoscaler based on the utilization of node. you can configure `scale-down-utilization-threshold`to adjust when cluster autoscaling triggers a scaling action. See [cluster autoscaler documentation][cluster-autoscaler] for more information on configuring autoscaling. 

### Limitations
- This feature is only available in public cloud.
- GPU Nodes are not currently supported.

### Requirements
- To enable cluster autoscaler with Virtual Machine node pools, the node pool must only use one VM size. All other manual scale profiles must be deleted before enabling cluster autoscaler.

### Install the aks-preview extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

- Install or update the `aks-preview` Azure CLI extension by using the [`az extension add`](/cli/azure/extension#az-extension-add) or [`az extension update`](/cli/azure/extension#az-extension-update) command:

```azurecli-interactive
    # Install the aks-preview extension
    az extension add --name aks-preview
    
    # Update the aks-preview extension
    az extension update --name aks-preview
```

### Register feature flag
Register the preview feature flag `VMsAgentAutoscalePreview` using the `az feature register` command:

```azurecli-interactive
    az feature register --namespace Microsoft.ContainerService --name VMsAgentPoolAutoscalePreview
```

### Create an AKS cluster with Virtual Machines node pools and cluster-autoscaler enabled
- Create an AKS cluster with Virtual Machines node pools using the [`az aks create`][az aks create] command with the `--vm-set-type` flag set to `"VirtualMachines"` and with the flag `--enable-cluster-autoscaler`.

The following example creates a cluster named *myAKSCluster* with a Virtual Machines node pool with a node pool size of "Standard_D4s_v3" minimum node count of 2, maximum node count of 5, and sets the Kubernetes version to *1.32.5*:

```azurecli-interactive
az aks create \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --vm-set-type "VirtualMachines" \
    --node-vm-size "Standard_D4s_v3" 
    --min-count 2 \
    --max-count 5 \
    --kubernetes-version 1.32.5
```

### Add a Virtual Machines node pool with cluster autoscaler enabled to an existing cluster
- Create a Virtual Machines node pool using the [`az aks nodepool add`][az aks nodepool add] command with the `--vm-set-type` flag set to `"VirtualMachines"` and with the flag `--enable-cluster-autoscaler`.

The following example adds Virtual Machines node pool *myvmpool* with cluster autoscaler enabled to a cluster named *myAKSCluster* using virtual machine size of "Standard_D4s_v3", and a minimum node count of 2 and max count of 5:

```azurecli-interactive
az aks nodepool add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myvmpool \
    --vm-set-type "VirtualMachines" \
    --node-vm-size "Standard_D4s_v3" \
    --enable-cluster-autoscaler
    --min-count 2 \
    --max-count 5 \
```

### Update cluster autoscaler settings for a Virtual Machines node pool with cluster autoscaler enabled

- Update the [cluster autoscaler][cluster-autoscaler] node count settings for a Virtual Machines node pool using the [`az aks nodepool update`][az aks nodepool update] command with the `--vm-set-type` flag set to `"VirtualMachines"` and with the flag `--update-cluster-autoscaler`.

The following example updates settings for Virtual Machines node pool *myvmpool* in cluster named *myAKSCluster* using virtual machine size of "Standard_D4s_v3":

```azurecli-interactive
az aks nodepool update \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myvmpool \
    --update-cluster-autoscaler \
    --node-vm-size "Standard_D4s_v3" \
    --min-count 2 \
    --max-count 5
```

### Update a Virtual Machines node pool from manual mode to cluster autoscaler enabled

>[!Note]
> Updating a manual mode Virtual Machines node pool to auto is only allowed when the node pool only has one manual scale profile.

If your Virtual Machine node pool has multiple manual scale profiles, you must remove all manual scale profiles except for the selected size you want for autoscaling purposes. See the following example that deletes the manual scale profile in node pool "myvmpool" for VM size `Standard_D8s_v3`:

```azurecli-interactive
az aks nodepool manual-scale delete \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myvmpool \
    --current-vm-sizes "Standard_D8s_v3"
```

The following example updates Virtual Machines node pool *myvmpool* in the cluster named *myAKSCluster* from `Manual` mode to `Auto` mode:

```azurecli-interactive
az aks nodepool update \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myvmpool \
    --enable-cluster-autoscaler \
    --min-count 2 \
    --max-count 5
```

 ### Disable cluster autoscaler in Virtual Machines node pool

You can disable [cluster autoscaler][cluster-autoscaler], or change the cluster from `Auto` mode to `Manual` mode.

The following example updates VIrtual Machines node pool *myvmpool* in the cluster named *myAKSCluster* from `Manual` mode to `Auto` mode:

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
[az extension add]: /cli/azure/extension#az-extention-add
[az feature registration create]: /cli/azure/feature/registration#az-feature-registration-create
[az aks get credentials]: /cli/azure/aks#az-aks-get-credentials
[az aks create]: /cli/azure/aks#az-aks-create
[az aks nodepool add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az aks nodepool manual-scale add]: /cli/azure/aks/nodepool/manual-scale#az-aks-nodepool-manual-scale-add
[az aks nodepool manual-scale update]: /cli/azure/aks/nodepool/manual-scale#az-aks-nodepool-manual-scale-update
[az aks nodepool manual-scale delete]: /cli/azure/aks/nodepool/manual-scale#az-aks-nodepool-manual-scale-delete
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
[upgrade-aks-cluster]: upgrade-aks-cluster.md
[windows-server-password]: /windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements#reference
[VMSS orchestrate]: /azure/virtual-machine-scale-sets/virtual-machine-scale-sets-orchestration-modes
[use-managed-identity]: use-managed-identity.md
[network-contributor]: /azure/role-based-access-control/built-in-roles#network-contributor
