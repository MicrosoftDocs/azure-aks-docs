---
title: Use Virtual Machines node pools in Azure Kubernetes Services (AKS)
description: Learn how to add multiple Virtual Machine types of a similar family to a node pool in an AKS cluster.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 06/26/2025
ms.author: wilsondarko
author: wdarko1
#Customer intent: As a cluster operator or developer, I want to learn how to enable my cluster to create node pools with multiple Virtual Machine types. I want to minimize capacity constraints by having greater flexibility in VM size selection.
---

# Use Virtual Machines node pools in Azure Kubernetes Service (AKS)

In this article, you'll learn about the new Virtual Machines node pool type for AKS. 

With Virtual Machines node pools, AKS directly manages the provisioning and bootstrapping of every single node. For Virtual Machine Scale Sets node pools, AKS manages the model of the Virtual Machine Scale Sets and uses it to achieve consistency across all nodes in the node pool. Virtual Machines node pools enable you to orchestrate your cluster with virtual machines that best fit your individual workloads.

## Overview

### How it works

A node pool consists of a set of virtual machines, where different virtual machine sizes are designated to support different types of workloads. These virtual machine sizes, referred to as SKUs, are categorized into different families that are optimized for specific purposes. For more information, see [VM SKUs][vm-SKU].

To enable scaling of multiple virtual machine sizes, the Virtual Machines node pool type uses a `ScaleProfile` that contains configurations indicating how the node pool can scale, specifically the desired list of virtual machine size and the count of each size. A `ManualScaleProfile` is a scale profile that specifies one desired virtual machine size and the total count of that type in the nodepool. Only one virtual machine size is allowed in a `ManualScaleProfile`. You need to create a separate `ManualScaleProfile` for each virtual machine size in your node pool. When creating a new Virtual Machines node pool, you add an initial manual scale profile for a virtual machine size using the `vm-size` field and including a `node-count`, per the instructions below. You can also add additional manual scale profiles following the instructions for [adding manual scale profiles][add-a-manual-scale-profile-to-a-node-pool].
 
> [!NOTE]
> When creating a new Virtual Machines node pool, you can have multiple scale profiles, and you need at least one manual scale profile in your nodepool.

### Advantages

Advantages of the Virtual Machines node pool type include:

- **Flexibility**: Node specifications can be updated to adapt to your current workload and needs.
- **Fine-tuned control**: Single node-level controls allow specifying and mixing nodes of different specs to lift restrictions from a single model and improve consistency.
- **Efficiency**: You can reduce the node footprint for your cluster, simplifying your operational requirements.

Virtual Machines node pools provide a better experience for dynamic workloads and high availability requirements. Virtual Machines node pools enable you to set up multiple similar-family virtual machines in one node pool. Your workload will be automatically scheduled on the available resources that you configure.


### Feature comparison

The following table highlights how Virtual Machines node pools compare with standard [Scale Set][VMSS orchestrate] node pools.

| Node pool type | Capabilities |
| ----------------- | ------------- |
| Virtual Machines node pool | You can add, remove, or update nodes in a node pool. Virtual machine types can be any virtual machine of the same family type (for example, D-series, A-Series, etc.). |
| Virtual Machine Scale Set based node pool | You can add or remove nodes of the same size and type in a node pool. If you add a new virtual machine size to the cluster, you need to create a new node pool. |

### Limitations

- [Cluster autoscaler][cluster autoscaler] is currently not supported.
- [InifiniBand][InifiniBand] isn't available.
- This feature isn't available in Azure portal. [Azure CLI][azure cli] or REST APIs must be used to perform CRUD operations or manage the pool.
- [Node pool snapshot][node pool snapshot] isn't supported.
- All VM sizes selected in a node pool need to be from a similar virtual machine family. For example, you can't mix an N-Series virtual machine type with a D-Series virtual machine type in the same node pool.
- Virtual Machines node pools allow up to five different virtual machine sizes per node pool.

## Prerequisites

- An Azure subscription. If you don't have one, you can [create a free account](https://azure.microsoft.com/free).
- Azure CLI version 2.73.0 or later installed and configured. To find the version, run `az --version`. For more information about installing or upgrading the Azure CLI, see [Install Azure CLI][install azure cli]
- This feature requires kubernetes version 1.27 or greater. To upgrade your kubernetes version, see [Upgrade AKS cluster](https://learn.microsoft.com/azure/aks/upgrade-aks-cluster)

## Create an AKS cluster with Virtual Machines node pools

> [!NOTE]
> Only *one* VM size is allowed in a scale profile, and the maximum limit is *five* VM scale profiles overall for a Virtual Machines node pool.

- Create an AKS cluster with Virtual Machines node pools using the [`az aks create`][az aks create] command with the `--vm-set-type` flag set to `"VirtualMachines"`.

    The following example creates a cluster named *myAKSCluster* with a Virtual Machines node pool containing two nodes, generates SSH keys, sets the load balancer SKU to *standard*, and sets the Kubernetes version to *1.28.5*:

    ```azurecli-interactive
    az aks create \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --vm-set-type "VirtualMachines" \
        --vm-sizes "Standard_D4s_v3" 
        --node-count 2 \
        --kubernetes-version 1.28.5
    ```

## Create a cluster with Windows enabled and a Windows Virtual Machine node pool

Virtual Machine node pools are available in Windows enabled clusters. The following example creates a cluster named *myAKSCluster* with a Virtual Machines node pool. These steps create a Linux system pool at first.
1. Create a username to use as administrator credentials for the Windows Server nodes on your cluster. The following commands prompt you for a username and sets it to *WINDOWS_USERNAME* for use in a later command.

    ```bash
    echo "Please enter the username to use as administrator credentials for Windows Server nodes on your cluster: " && read WINDOWS_USERNAME
    ```

2. Create a password for the administrator username you created in the previous step. The password must be a minimum of 14 characters and meet the [Windows Server password complexity requirements][windows-server-password].

    ```bash
    echo "Please enter the password to use as administrator credentials for Windows Server nodes on your cluster: " && read WINDOWS_PASSWORD
    ```

3. Create an AKS cluster with Windows enabled and Virtual Machines type node pools using the [`az aks create`][az aks create] command with the `--vm-set-type` flag set to `"VirtualMachines"`.

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

4. Add a Virtual Machines node pool to an existing Windows enabled cluster using the [`az aks nodepool add`][az aks nodepool add] command with the `--vm-set-type` flag set to `"VirtualMachines"`. The following example adds a Virtual Machines node pool named *npwin* to the *myAKSCluster* cluster:
  
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

- Add a Virtual Machines node pool to an existing cluster using the [`az aks nodepool add`][az aks nodepool add] command with the `--vm-set-type` flag set to `"VirtualMachines"`.

    The following example adds a Virtual Machines node pool named *myvmpool* to the *myAKSCluster* cluster. The node pool creates a ManualScaleProfile with `--vm-sizes` set to *Standard_D4s_v3* and a `--node-count` of 3:

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

- Add a manual scale profile to a node pool using the [`az aks nodepool manual-scale add`][az aks nodepool manual-scale add] with the `--vm-sizes` flag set to `"Standard_D2s_v3"` and the `node-count` set to 2.

    The following example adds a manual scale profile to node pool *myvmpool* in cluster *myAKSCluster*. The node pool includes two nodes with a VM SKU of *Standard_D2s_v3*:

    ```azurecli-interactive
    az aks nodepool manual-scale add \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name myvmpool \
        --vm-sizes "Standard_D2s_v3" \
        --node-count 2
     ```

## Update an existing manual scale profile

- Update an existing manual scale profile in a node pool using the [`az aks nodepool manual-scale update`][az aks nodepool manual-scale update] command with the `--vm-sizes` flag set to `"Standard_D2s_v3"`.

    > [!NOTE]
    > Use the `--current-vm-sizes` parameter to specify the size of the existing node pool that you want to update. You can update `--vm-sizes` and/or `--node-count`. When using other tools or REST APIs, you need to pass in a full `agentPoolProfiles.virtualMachinesProfile.scale` field when updating the node pool scale profile.

    The following example updates a manual scale profile to the *myvmpool* node pool in the *myAKSCluster* cluster. The command updates the number of nodes to five and changes the VM SKU from *Standard_D4s_v3* to *Standard_D8s_v3*:

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

- Delete an existing manual scale profile using the [`az aks nodepool manual-scale delete`][az aks nodepool manual-scale delete] command.

    > [!NOTE]
    > The `--current-vm-sizes` parameter specifies the size of the existing node pool to be deleted. When using other tools or REST APIs to update the node pool scale profile, pass in a full `agentPoolProfiles.virtualMachinesProfile.scale` field.

    The following example deletes the manual scale profile for the *Standard_D8s_v3* VM SKU in the *myvmpool* node pool.

    ```azurecli-interactive
    az aks nodepool manual-scale delete \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name myvmpool \
        --current-vm-sizes "Standard_D8s_v3"
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
[node pool snapshot]: node-pool-snapshot.md
[cluster autoscaler]: cluster-autoscaler-overview.md
[InifiniBand]: /azure/virtual-machines/extensions/enable-infiniband
[vm-SKU]: /azure/virtual-machines/sizes/overview
[VMSS]: /azure/virtual-machine-scale-sets/overview
[azure cli]: /cli/azure/get-started-with-azure-cli
[az extension update]: /cli/azure/extension#az-extension-update
[az account set]: /cli/azure/account#az-account-set
[create node pools]: create-node-pools.md
[windows-server-password]: /windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements#reference
[VMSS orchestrate]: /azure/virtual-machine-scale-sets/virtual-machine-scale-sets-orchestration-modes
