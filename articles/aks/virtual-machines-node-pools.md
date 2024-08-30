---
title: Use Virtual Machines node pools in Azure Kubernetes Services (AKS)
description: Learn how to add multiple Virtual Machine types of a similar family to a node pool in an AKS cluster.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 07/26/2024
ms.author: wilsondarko
author: wdarko1
#Customer intent: As a cluster operator or developer, I want to learn how to enable my cluster to create node pools with multiple Virtual Machine types.
---

# Use Virtual Machines node pools (preview) in Azure Kubernetes Service (AKS)

In this article, you learn about the new Virtual Machines node pool type (preview) for AKS. 

With Virtual Machines node pools, AKS directly manages the provisioning and bootstrapping of every single node. For Virtual Machine Scale Sets node pools with Uniform orchestration, AKS manages the model of the Virtual Machine Scale Sets and uses it to achieve consistency across all nodes in the node pool. Virtual Machines node pools enable you to orchestrate your cluster with virtual machines that best fit your individual workloads.

## Overview

### How it works

A node pool consists of a set of virtual machines, where different virtual machine sizes are designated to support different types of workloads. These virtual machine sizes, referred to as SKUs, are categorized into different families that are optimized for specific purposes. For more information, see [VM SKUs][vm-SKU].

To enable scaling of multiple virtual machine sizes, the Virtual Machines node pool type uses a `ScaleProfile` that contains configurations indicating how the node pool can scale, specifically the desired list of virtual machine size and count. A `ManualScaleProfile` is a scale profile that specifies the desired virtual machine size and count. Only one virtual machine size is allowed in a `ManualScaleProfile`. You need to create a separate `ManualScaleProfile` for each virtual machine size in your node pool.
 
> [!NOTE]
> When creating a new Virtual Machines node pool, you need at least one `ManualScaleProfile` in the `ScaleProfile`. A Virtual Machines node pool can have multiple manual scale profiles.

### Advantages

Advantages of the Virtual Machines node pool type include:

- **Flexibility**: Node specifications can be updated to adapt to your current workload and needs.
- **Fine-tuned control**: Single node-level controls allow specifying and mixing nodes of different specs to lift restrictions from a single model and improve consistency.
- **Efficiency**: You can reduce the node footprint for your cluster, simplifying your operational requirements.

Virtual Machines node pools provide a better experience for dynamic workloads and high availability requirements. Virtual Machines node pools enable you to set up multiple similar-family virtual machines in one node pool. Your workload will be automatically scheduled on the available resources that you configure.


## Feature Capabilities
The following capabilities highlight how Virtual Machines node pools compare with standard [Uniform scale set][VMSS orchestrate] node pools.

**Virtual Machine based node pools**: You can add, remove, or update nodes in a node pool. Virtual machine types can be any virtual machine of the same family type (for example, D-series, A-Series, etc.)

**VMSS Uniform based node pools**: YOu can add or remove nodes in a node pool (of the same size and type). Should a new virtual machine size be added to the cluster, a new node pool must be created.

### Limitations

- [Cluster autoscaler][cluster autoscaler] is currently not supported.
- [InifiniBand][InifiniBand] isn't available.
- Windows node pools aren't supported.
- This feature isn't available in Azure portal. [Azure CLI][azure cli] or REST APIs must be used to perform CRUD operations or manage the pool.
- [Node pool snapshot][node pool snapshot] isn't supported.
- All VM sizes selected in a node pool need to be from a similar virtual machine family. For example, you can't mix an N-Series virtual machine type with a D-Series virtual machine type in the same node pool.
- Virtual Machines node pools allow up to five different virtual machine sizes per node pool.

## Prerequisites

- An Azure subscription is required to use this feature. To create a free account, click [Free Azure Account](https://azure.microsoft.com/free).
- The Virtual Machines node pool feature is in preview, and is available only in API versions 2023-10-02-preview and greater, or by installing the az cli extension 2.61.0 version or greater.
- If using the [Azure CLI][install azure cli], register the `aks-preview` extension or update the version of existing `aks-preview` to minimum version 4.0.0b4.
- The minimum minor Kubernetes release version required for this feature is release 1.26.

### Install the aks-preview Azure CLI extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

1. Install the aks-preview extension using the [`az extension add`][az extension add] command:

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

2. Update to the latest version of the aks-preview extension using the [`az extension update`][az extension update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

## Register the `VMsAgentPoolPreview` feature flag

1. Select the subscription where you want to enable the feature flag using the [`az account set`][az account set] command.

    ```azurecli-interactive
    az account set --subscription <subscription-name>
    ```

2. Register the `VMsAgentPoolPreview` feature flag using the [`az feature registration create`][az feature registration create] command.

    ```azurecli-interactive
    az feature registration create --namespace Microsoft.ContainerService --name VMsAgentPoolPreview
    ```

    It takes a few minutes for the status to show *Registered*.

3. Verify the registration status using the [`az feature show`][az feature show] command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "VMsAgentPoolPreview"
    ```

4. When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider using the [`az provider register`][az provider register] command.

    ```azurecli-interactive
    az provider register --namespace "Microsoft.ContainerService"
    ```



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
        --node-count 2 \
        --generate-ssh-keys \
        --load-balancer-sku standard \
        --kubernetes-version 1.28.5
    ```

## Add a Virtual Machines node pool to an existing cluster

- Add a Virtual Machines node pool to an existing cluster using the [`az aks nodepool add`][az aks nodepool add] command with the `--vm-set-type` flag set to `"VirtualMachines"`.

    The following example adds a Virtual Machines node pool named *myvmpool* to the *myAKSCluster* cluster. The node pool has three nodes and a maximum VM SKU of *Standard_D4s_v3*:

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

- Add a manual scale profile to a node pool using the [`az aks nodepool manual-scale add`][az aks nodepool manual-scale add] with the `--vm-sizes` flag set to `"Standard_D2s_v3"`.

    The following example adds a manual scale profile to node pool *myvmpool* in cluster *myAKSCluster*. The node pool includes two nodes with a VM SKU of *Standard_D2s_v3*:

    ```azurecli-interactive
    az aks nodepool manual-scale add \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name myvmpool1 \
        --vm-sizes "Standard_D2s_v3" \
        --node-count 2
     ```

## Update an existing manual scale profile

- Update an existing manual scale profile in a node pool using the [`az aks nodepool manual-scale update`][az aks nodepool manual-scale update] command with the `--vm-sizes` flag set to `"Standard_D2s_v3"`.

    > [!NOTE]
    > Use the `--current-vm-sizes` parameter to specify the size of the existing node pool that you want to update. You can update `--vm-sizes` and/or `--node-count`. When using other tools or REST APIs, you need to pass in a full `agentPoolProfiles.virtualMachinesProfile.scale` field when updating the node pool scale profile.

    The following example updates a manual scale profile to the *myvmpool1* node pool in the *myAKSCluster* cluster. The commmand updates the numder of nodes to five and changes the VM SKU from *Standard_D4s_v3* to *Standard_D8s_v3*:

    ```azurecli-interactive
    az aks nodepool manual-scale update \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name myvmpool1 \
        --current-vm-sizes "Standard_D4s_v3" \
        --vm-sizes "Standard_D8s_v3" \
        --node-count 5
    ```

## Delete a manual scale profile

- Delete an existing manual scale profile using the [`az aks nodepool manual-scale delete`][az aks nodepool manual-scale delete] command.

    > [!NOTE]
    > The `--current-vm-sizes` parameter specifies the size of the existing node pool to be deleted. When using other tools or REST APIs to update the node pool scale profile, pass in a full `agentPoolProfiles.virtualMachinesProfile.scale` field.

    The following example deletes the manual scale profile for the *Standard_D8s_v3* VM SKU in the *myvmpool1* node pool.

    ```azurecli-interactive
    az aks nodepool manual-scale delete \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name myvmpool1 \
        --current-vm-sizes "Standard_D8s_v3"
     ```

## Next steps

In this article, you learned how to use Virtual Machines node pools in AKS. To learn more about node pools in AKS, see [Create node pools][create node pools].

<!-- EXTERNAL LINKS -->

<!-- INTERNAL LINKS -->
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
[VMSS orchestrate]: /azure/virtual-machine-scale-sets/virtual-machine-scale-sets-orchestration-modes
