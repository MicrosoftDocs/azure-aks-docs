---
title: Create Node Pools in Azure Kubernetes Service (AKS)
description: Learn how to create multiple node pools for a cluster in Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.custom: devx-track-azurecli, build-2023, linux-related-content, annual
ms.date: 09/26/2025
author: schaffererin
ms.author: schaffererin
ms.subservice: aks-nodes
ms.service: azure-kubernetes-service
zone_pivot_groups: azure-cli-or-arm
# Customer intent: "As a cloud engineer, I want to create and manage multiple node pools in Azure Kubernetes Service, so that I can optimize resource allocation based on varying application workloads and performance requirements."
---

# Create node pools for a cluster in Azure Kubernetes Service (AKS)

This article shows you how to create one or more node pools in an AKS cluster.

> [!NOTE]
> This feature enables more control over creating and managing multiple node pools and requires separate commands for _create/update/delete_ (CRUD) operations. Previously, cluster operations through [`az aks create`][az-aks-create] or [`az aks update`][az-aks-update] used the managedCluster API and were the only options to change your control plane and a single node pool. This feature exposes a separate operation set for agent pools through the agentPool API and requires use of the [`az aks nodepool`][az-aks-nodepool] command set to execute operations on an individual node pool.

> [!IMPORTANT]
> Starting on **30 November 2025**, AKS will no longer support or provide security updates for Azure Linux 2.0. Starting on **31 March 2026**, node images will be removed, and you'll be unable to scale your node pools. Migrate to a supported Azure Linux version by [**upgrading your node pools**](/azure/aks/upgrade-aks-cluster) to a supported Kubernetes version or migrating to [`osSku AzureLinux3`](/azure/aks/upgrade-os-version). For more information, see [Retirement: Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).

## Prerequisites

:::zone pivot="azure-cli"

- You need Azure CLI version 2.2.0 or later installed and configured. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

:::zone-end

:::zone pivot="arm"

- To deploy an ARM template, you need write access on the resources you're deploying and access to all operations on the `Microsoft.Resources/deployments` resource type. For example, to deploy a virtual machine (VM), you need `Microsoft.Compute/virtualMachines/write` and `Microsoft.Resources/deployments/*` permissions. For a list of roles and permissions, see [Azure built-in roles](/azure/role-based-access-control/built-in-roles).
- Review the following requirements for each parameter:

  - `osTYPE`: The operating system type. The default is Linux.
  - `osSKU`: Specifies the OS SKU used by the agent pool.
  - `count`: Number of agents (VMs) to host docker containers. Allowed values must be in the range of 0 to 1000 (inclusive) for user pools and in the range of 1 to 1000 (inclusive) for system pools. The default value is 1.

- After you deploy the cluster using an ARM template, you can use Azure CLI or Azure PowerShell to connect to the cluster and deploy the sample application.

:::zone-end

## Limitations

The following limitations apply when you create AKS clusters that support multiple node pools:

- You can delete the system node pool if you have another system node pool to take its place in the AKS cluster. Otherwise, you can't delete the system node pool.
- System pools must contain at least one node. User node pools can contain zero or more nodes.
- **If you create a cluster with a single node pool, the OS type must be `Linux`**. The OS SKU can be any Linux variation such as `Ubuntu` or `AzureLinux`. You can't create a cluster with a single Windows node pool. If you want to run Windows containers, you must [add a Windows node pool](#add-a-windows-server-node-pool) to the cluster after creating it with a Linux system node pool.
- The AKS cluster must use the Standard SKU load balancer to use multiple node pools. This feature isn't supported with Basic SKU load balancers.
- The AKS cluster must use Virtual Machine Scale Sets for the nodes.
- The name of a node pool can only contain lowercase alphanumeric characters and must begin with a lowercase letter.

  - For Linux node pools, the length must be between 1-12 characters.
  - For Windows node pools, the length must be between 1-6 characters.

- All node pools must reside in the same virtual network.
- When you create multiple node pools at cluster creation time, the Kubernetes versions for the node pools must match the version set for the control plane.

## Create specialized node pools

To learn how to create specialized node pools, see the following articles:

- [Add an Azure Spot node pool to an AKS cluster](./spot-node-pool.md)
- [Add a Virtual Machines node pool to an AKS cluster](./virtual-machines-node-pools.md)
- [Add a dedicated system node pool to an AKS cluster](./use-system-pools.md#add-a-dedicated-system-node-pool-to-an-existing-aks-cluster)
- [Enabled Federal Information Processing Standards (FIPS) on an AKS node pool](./enable-fips-nodes.md)
- [Add a node pool with a Confidential Virtual Machine (CVM) on an AKS cluster](./use-cvm.md)
- [Create node pools with unique subnets in AKS](./node-pool-unique-subnet.md)
- [Add a generation 2 VM node pool to an AKS cluster](./generation-2-vms.md)
- [Add a node pool with Artifact Streaming to an AKS cluster](./artifact-streaming.md)
- [Add Windows Server node pools with `containerd` to an AKS cluster](./windows-containerd.md)

:::zone pivot="azure-cli"

## Set environment variables

- Set the following environment variables in your shell to simplify the commands in this article. You can change the values to your preferred names.

    ```bash
    export RESOURCE_GROUP_NAME="my-aks-rg"
    export LOCATION="eastus"
    export CLUSTER_NAME="my-aks-cluster"
    export NODE_POOL_NAME="mynodepool"
    ```

## Create a resource group

- Create an Azure resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --name $RESOURCE_GROUP_NAME --location $LOCATION
    ```

## Create an AKS cluster with a single node pool using the Azure CLI

If you want only one node pool in your AKS cluster, you can schedule application pods on system node pools. If you run a single system node pool for your AKS cluster in a production environment, we recommend you use at least three nodes for the node pool. If one node goes down, the redundancy is compromised. You can mitigate this risk by having more system node pool nodes.

### [Create an AKS cluster with a single Ubuntu node pool](#tab/ubuntu)

1. Create a cluster with a single Ubuntu node pool using the [`az aks create`][az-aks-create] command. This step specifies two nodes in the single node pool.

    ```azurecli-interactive
    az aks create \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $CLUSTER_NAME \
        --vm-set-type VirtualMachineScaleSets \
        --node-count 2 \
        --os-sku Ubuntu \
        --location $LOCATION \
        --load-balancer-sku standard \
        --generate-ssh-keys
    ```

    It takes a few minutes to create the cluster.

1. When the cluster is ready, get the cluster credentials using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME
    ```

### [Create an AKS cluster with a single Azure Linux node pool](#tab/azure-linux)

1. Create a cluster with a single Azure Linux node pool using the [`az aks create`][az-aks-create] command. This step specifies two nodes in the single node pool.

    For more information about Azure Linux, see [Azure Linux on AKS][azure-linux].

    ```azurecli-interactive
    az aks create \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $CLUSTER_NAME \
        --vm-set-type VirtualMachineScaleSets \
        --node-count 2 \
        --os-sku AzureLinux \
        --location $LOCATION \
        --load-balancer-sku standard \
        --generate-ssh-keys
    ```

    It takes a few minutes to create the cluster.

1. When the cluster is ready, get the cluster credentials using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME
    ```

### [Create an AKS cluster with a single Azure Linux with OS Guard for AKS (preview) node pool](#tab/os-guard)

#### Install the `aks-preview` extension

1. Install the `aks-preview` Azure CLI extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

    [!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

#### Register the `AzureLinuxOSGuardPreview` feature flag

1. Register the `AzureLinuxOSGuardPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AzureLinuxOSGuardPreview"
    ```

1. Verify the registration status using the [`az feature show`][az-feature-show] command. It takes a few minutes for the status to show _Registered_.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name AzureLinuxOSGuardPreview
    ```

1. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

#### Create the Azure Linux with OS Guard for AKS cluster

1. Create a cluster with a single Azure Linux with OS Guard for AKS (preview) node pool using the [`az aks create`][az-aks-create] command. This step specifies two nodes in the single node pool.

    ```azurecli-interactive
    az aks create \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $CLUSTER_NAME \
        --vm-set-type VirtualMachineScaleSets \
        --node-count 2 \
        --os-sku AzureLinuxOSGuard \
        --node-osdisk-type Managed \
        --enable-fips-image \
        --enable-secure-boot \
        --enable-vtpm
        --location $LOCATION \
        --load-balancer-sku standard \
        --generate-ssh-keys
    ```

    It takes a few minutes to create the cluster.

1. When the cluster is ready, get the cluster credentials using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME
    ```

### [Create an AKS cluster with a single Flatcar Container Linux for AKS (preview) node pool](#tab/flatcar)

#### Install the `aks-preview` extension

1. Install the `aks-preview` Azure CLI extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

    [!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command. **Flatcar Container Linux requires a minimum of 18.0.0b42**.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

#### Register the `AKSFlatcarPreview` feature flag

1. Register the `AKSFlatcarPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AKSFlatcarPreview"
    ```

1. Verify the registration status using the [`az feature show`][az-feature-show] command. It takes a few minutes for the status to show _Registered_.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name AKSFlatcarPreview
    ```

1. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

#### Create the Flatcar Container Linux for AKS cluster

1. Create a cluster with a single Flatcar Container Linux for AKS (preview) node pool using the [`az aks create`][az-aks-create] command. This step specifies two nodes in the single node pool.

    ```azurecli-interactive
    az aks create \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $CLUSTER_NAME \
        --vm-set-type VirtualMachineScaleSets \
        --node-count 2 \
        --os-sku flatcar \
        --location $LOCATION \
        --load-balancer-sku standard \
        --generate-ssh-keys
    ```

    It takes a few minutes to create the cluster.

1. When the cluster is ready, get the cluster credentials using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME
    ```

---

## Add a second node pool using the Azure CLI

The cluster created in the [previous section](#create-an-aks-cluster-with-a-single-node-pool-using-the-azure-cli) has a single node pool. In this section, we add a second node pool to the cluster. This second node pool can have an OS type of `Linux` with an OS SKU of `Ubuntu` or `AzureLinux`, or an OS type of `Windows`.

> [!NOTE]
> If you want to add a node pool that uses **Ephemeral OS disks** to your AKS cluster, you can set the `--node-osdisk-type` flag to `Ephemeral` when running the `az aks nodepool add` command.
>
> With Ephemeral OS, you can deploy VMs and instance images up to the size of the VM cache. The default node OS disk configuration in AKS uses 128 GB, which means that you need a VM size that has a cache larger than 128 GB. The default `Standard_DS2_v2` has a cache size of 86 GB, which isn't large enough. The `Standard_DS3_v2` VM SKU has a cache size of 172 GB, which is large enough. You can also reduce the default size of the OS disk using `--node-osdisk-size`, but keep in mind the minimum size for AKS images is 30 GB.
>
> If you want to create node pools with **network-attached OS disks**, you can set the `--node-osdisk-type` flag to `Managed` when running the `az aks nodepool add` command.

### Add a Linux node pool

#### [Add an Ubuntu node pool](#tab/ubuntu)

- Create a new node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command. The following example creates a `Linux` node pool with the `Ubuntu` OS SKU that runs _three_ nodes. If you don't specify an OS SKU, AKS defaults to `Ubuntu`.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group $RESOURCE_GROUP_NAME \
        --cluster-name $CLUSTER_NAME \
        --name $NODE_POOL_NAME \
        --node-vm-size Standard_DS2_v2 \
        --os-type Linux \
        --os-sku Ubuntu \
        --node-count 3
    ```

    It takes a few minutes to create the node pool.

#### [Add an Azure Linux node pool](#tab/azure-linux)

- Create a new node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command. The following example creates a `Linux` node pool with the `Azure Linux` OS SKU that runs _three_ nodes. If you don't specify an OS SKU, AKS defaults to `Ubuntu`.

    For more information about Azure Linux, see [Azure Linux on AKS][azure-linux].

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group $RESOURCE_GROUP_NAME \
        --cluster-name $CLUSTER_NAME \
        --name $NODE_POOL_NAME \
        --node-vm-size Standard_DS2_v2 \
        --os-type Linux \
        --os-sku AzureLinux \
        --node-count 3
    ```

    It takes a few minutes to create the node pool.

#### [Add an Azure Linux with OS Guard for AKS (preview) node pool](#tab/os-guard)

##### Install the `aks-preview` extension

1. Install the `aks-preview` Azure CLI extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

    [!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

##### Register the `AzureLinuxOSGuardPreview` feature flag

1. Register the `AzureLinuxOSGuardPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AzureLinuxOSGuardPreview"
    ```

1. Verify the registration status using the [`az feature show`][az-feature-show] command. It takes a few minutes for the status to show _Registered_.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name AzureLinuxOSGuardPreview
    ```

1. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

##### Create the Azure Linux with OS Guard for AKS node pool

- Create a new node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command. The following example creates a `Linux` node pool with the `Azure Linux with OS Guard` OS SKU that runs _three_ nodes. If you don't specify an OS SKU, AKS defaults to `Ubuntu`.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group $RESOURCE_GROUP_NAME \
        --cluster-name $CLUSTER_NAME \
        --name $NODE_POOL_NAME \
        --node-vm-size Standard_DS2_v2 \
        --os-type Linux \
       --os-sku AzureLinuxOSGuard \
       --node-osdisk-type Managed \
       --enable-fips-image \
       --enable-secure-boot \
       --enable-vtpm \
       --node-count 3
    ```

    It takes a few minutes to create the node pool.

    For more information, see [Azure Linux with OS Guard for AKS][os-guard].

#### [Add a Flatcar Container Linux for AKS (preview) node pool](#tab/flatcar)

##### Install the `aks-preview` extension

1. Install the `aks-preview` Azure CLI extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

    [!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command. **Flatcar Container Linux requires a minimum of 18.0.0b42**.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

##### Register the `AKSFlatcarPreview` feature flag

1. Register the `AKSFlatcarPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AKSFlatcarPreview"
    ```

1. Verify the registration status using the [`az feature show`][az-feature-show] command. It takes a few minutes for the status to show _Registered_.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name AKSFlatcarPreview
    ```

1. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

##### Create the Flatcar Container Linux for AKS node pool

- Create a new node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command. The following example creates a `Linux` node pool with the `flatcar` OS SKU that runs _three_ nodes. If you don't specify an OS SKU, AKS defaults to `Ubuntu`.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group $RESOURCE_GROUP_NAME \
        --cluster-name $CLUSTER_NAME \
        --name $NODE_POOL_NAME \
        --node-vm-size Standard_DS2_v2 \
        --os-type Linux \
        --os-sku flatcar \
        --node-count 3
    ```

    It takes a few minutes to create the node pool.

    For more information, see [Flatcar Container Linux for AKS][flatcar].

---

### Add a Windows Server node pool

#### [Add a Windows Server 2025 (preview) node pool](#tab/ws2025)

##### Install the `aks-preview` extension

1. Install the `aks-preview` Azure CLI extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

    [!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command. **Windows Server 2025 requires a minimum of 18.0.0b5**.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

##### Register the `AksWindows2025Preview` feature flag

1. Register the `AksWindows2025Preview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AksWindows2025Preview"
    ```

1. Verify the registration status using the [`az feature show`][az-feature-show] command. It takes a few minutes for the status to show _Registered_.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name AksWindows2025Preview
    ```

1. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

##### Create the Windows Server 2025 node pool

- Create a new node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command. The following example creates a `Windows` node pool with the `Windows2025` OS SKU that runs _three_ nodes.

    For more information about Windows OS, see [Windows best practices][windows].

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group $RESOURCE_GROUP_NAME \
        --cluster-name $CLUSTER_NAME \
        --name $NODE_POOL_NAME \
        --node-vm-size Standard_DS2_v2 \
        --os-type Windows \
        --os-sku Windows2025 \
        --node-count 3
    ```

#### [Add a Windows Server 2022 node pool](#tab/ws2022)

- Create a new node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command. The following example creates a `Windows` node pool with the `Windows2022` OS SKU that runs _three_ nodes.

    For more information about Windows OS, see [Windows best practices][windows].

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group $RESOURCE_GROUP_NAME \
        --cluster-name $CLUSTER_NAME \
        --name $NODE_POOL_NAME \
        --node-vm-size Standard_DS2_v2 \
        --os-type Windows \
        --os-sku Windows2022 \
        --node-count 3
    ```

---

### Check the status of your node pools

- Check the status of your node pools using the [`az aks nodepool list`][az-aks-nodepool-list] command and specify your resource group and cluster name.

    ```azurecli-interactive
    az aks nodepool list --resource-group $RESOURCE_GROUP_NAME --cluster-name $CLUSTER_NAME
    ```

## Delete a node pool

If you no longer need a node pool, you can delete it and remove the underlying VM nodes.

> [!CAUTION]
> When you delete a node pool, AKS doesn't perform cordon and drain, and there are no recovery options for data loss that may occur when you delete a node pool. If pods can't be scheduled on other node pools, those applications become unavailable. Make sure you don't delete a node pool when in-use applications don't have data backups or the ability to run on other node pools in your cluster. To minimize the disruption of rescheduling pods currently running on the node pool you want to delete, perform a cordon and drain on all nodes in the node pool before deleting.

- Delete a node pool using the [`az aks nodepool delete`][az-aks-nodepool-delete] command and specify the node pool name.

    ```azurecli-interactive
    az aks nodepool delete --resource-group $RESOURCE_GROUP_NAME --cluster-name $CLUSTER_NAME --name $NODE_POOL_NAME --no-wait
    ```

    It takes a few minutes to delete the nodes and the node pool.

:::zone-end

:::zone pivot="arm"

## Create an AKS cluster with a single node pool using an ARM template

If you want only one node pool in your AKS cluster, you can schedule application pods on system node pools. If you run a single system node pool for your AKS cluster in a production environment, we recommend you use at least three nodes for the node pool. If one node goes down, the redundancy is compromised. You can mitigate this risk by having more system node pool nodes.

### Create a `Microsoft.ContainerService/managedClusters` resource

- Create a `Microsoft.ContainerService/managedClusters` resource by adding [this JSON][managedclusters] to your template.

### [Modify JSON to create a single Ubuntu node pool](#tab/ubuntu-arm)

- Create a single Ubuntu node pool in your AKS cluster by making the following modifications to your ARM template:

    ```json
      "properties": {
        "agentPoolProfiles": [
        {
            "count": "1",
            "osSKU": "ubuntu",
            "osType": "linux"
         } 
         ],
    }
    ```

### [Modify JSON to create a single Azure Linux node pool](#tab/azure-linux-arm)

- Create a single Azure Linux node pool in your AKS cluster by making the following modifications to your ARM template:

    ```json
      "properties": {
        "agentPoolProfiles": [
        {
            "count": "1",
            "osSKU": "AzureLinux",
            "osType": "linux"
         } 
         ],
    }
    ```

    For more information about Azure Linux, see [Azure Linux on AKS][azure-linux].

### [Modify JSON to create a single Azure Linux with OS Guard for AKS (preview) node pool](#tab/os-guard-arm)

#### Install the `aks-preview` extension

1. Install the `aks-preview` Azure CLI extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

    [!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

#### Register the `AzureLinuxOSGuardPreview` feature flag

1. Register the `AzureLinuxOSGuardPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AzureLinuxOSGuardPreview"
    ```

1. Verify the registration status using the [`az feature show`][az-feature-show] command. It takes a few minutes for the status to show _Registered_.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name AzureLinuxOSGuardPreview
    ```

1. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

#### Create the Azure Linux with OS Guard for AKS node pool

- Create a single Azure Linux with OS Guard for AKS node pool in your AKS cluster by making the following modifications to your ARM template:

    ```json
      "properties": {
        "agentPoolProfiles": [
        {
            "count": "1",
            "osSKU": "AzureLinuxOSGuard",
            "osType": "linux",
            "osDiskType": "Managed",
                        "enableFIPS": true,
                        "securityProfile": {
                            "enableSecureBoot": true,
                            "enableVTPM": true
                        },
         } 
         ],
    }
    ```

    For more information, see [Azure Linux with OS Guard for AKS][os-guard].

### [Modify JSON to create a single Flatcar Container Linux for AKS (preview) node pool](#tab/flatcar-arm)

#### Install the `aks-preview` extension

1. Install the `aks-preview` Azure CLI extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

    [!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command. **Flatcar Container Linux requires a minimum of 18.0.0b42**.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

#### Register the `AKSFlatcarPreview` feature flag

1. Register the `AKSFlatcarPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AKSFlatcarPreview"
    ```

1. Verify the registration status using the [`az feature show`][az-feature-show] command. It takes a few minutes for the status to show _Registered_.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name AKSFlatcarPreview
    ```

1. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

#### Create the Flatcar Container Linux for AKS node pool

- Create a single Flatcar Container Linux for AKS node pool in your AKS cluster by making the following modifications to your ARM template:

    ```json
      "properties": {
        "agentPoolProfiles": [
        {
            "count": "1",
            "osSKU": "flatcar",
            "osType": "linux"
         } 
         ],
    }
    ```

    For more information, see [Flatcar Container Linux for AKS][flatcar].

---

## Add a second node pool using an ARM template

The cluster created in the [previous section](#create-an-aks-cluster-with-a-single-node-pool-using-an-arm-template) has a single node pool. In this section, we add a second node pool to the cluster. This second node pool can have an OS type of `Linux` with an OS SKU of `Ubuntu` or `AzureLinux`, or an OS type of `Windows`.

### Add Linux node pools

#### [Modify JSON to create multiple Ubuntu node pools](#tab/ubuntu-arm)

- Create multiple Ubuntu node pools in your AKS cluster by making the following modifications to your ARM template:

    ```json
      "properties": {
        "agentPoolProfiles": [
        {
            "count": "3",
            "osSKU": "ubuntu",
            "osType": "linux"
         } 
         ],
    }
    ```

#### [Modify JSON to create multiple Azure Linux node pools](#tab/azure-linux-arm)

- Create multiple Azure Linux node pools in your AKS cluster by making the following modifications to your ARM template:

    ```json
      "properties": {
        "agentPoolProfiles": [
        {
            "count": "3",
            "osSKU": "AzureLinux",
            "osType": "linux"
         } 
         ],
    }
    ```

    For more information about Azure Linux, see [Azure Linux on AKS][azure-linux].

#### [Modify JSON to create multiple Azure Linux with OS Guard for AKS (preview) node pools](#tab/os-guard-arm)

##### Install the `aks-preview` extension

1. Install the `aks-preview` Azure CLI extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

    [!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

##### Register the `AzureLinuxOSGuardPreview` feature flag

1. Register the `AzureLinuxOSGuardPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AzureLinuxOSGuardPreview"
    ```

1. Verify the registration status using the [`az feature show`][az-feature-show] command. It takes a few minutes for the status to show _Registered_.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name AzureLinuxOSGuardPreview
    ```

1. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

##### Create the Azure Linux with OS Guard for AKS node pools

- Create multiple Azure Linux with OS Guard for AKS (preview) node pools in your AKS cluster by making the following modifications to your ARM template:

    ```json
      "properties": {
        "agentPoolProfiles": [
        {
            "count": "3",
            "osSKU": "AzureLinuxOSGuard",
            "osType": "linux",
            "osDiskType": "Managed",
            "enableFIPS": true,
            "securityProfile": {
                   "enableSecureBoot": true,
                   "enableVTPM": true
             },
         } 
         ],
    }
    ```

For more information, see Azure Linux with OS Guard for AKS][os-guard].

#### [Modify JSON to create multiple Flatcar Container Linux for AKS (preview) node pools](#tab/flatcar-arm)

##### Install the `aks-preview` extension

1. Install the `aks-preview` Azure CLI extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

    [!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command. **Flatcar Container Linux requires a minimum of 18.0.0b42**.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

##### Register the `AKSFlatcarPreview` feature flag

1. Register the `AKSFlatcarPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AKSFlatcarPreview"
    ```

1. Verify the registration status using the [`az feature show`][az-feature-show] command. It takes a few minutes for the status to show _Registered_.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name AKSFlatcarPreview
    ```

1. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

##### Create the Flatcar Container Linux for AKS node pools

- Create multiple Flatcar Container Linux for AKS (preview) node pools in your AKS cluster by making the following modifications to your ARM template:

    ```json
      "properties": {
        "agentPoolProfiles": [
        {
            "count": "3",
            "osSKU": "flatcar",
            "osType": "linux"
         } 
         ],
    }
    ```

For more information, see [Flatcar Container Linux for AKS][flatcar].

---

### Add Windows Server node pools

#### [Modify JSON to create multiple Windows Server 2025 (preview) node pools](#tab/ws2025-arm)

##### Install the `aks-preview` extension

1. Install the `aks-preview` Azure CLI extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

    [!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command. **Windows Server 2025 requires a minimum of 18.0.0b5**.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

##### Register the `AksWindows2025Preview` feature flag

1. Register the `AksWindows2025Preview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AksWindows2025Preview"
    ```

1. Verify the registration status using the [`az feature show`][az-feature-show] command. It takes a few minutes for the status to show _Registered_.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name AksWindows2025Preview
    ```

1. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

##### Create the Windows Server 2025 node pools

- Create multiple Windows node pools in your AKS cluster by making the following modifications to your ARM template:

    ```json
      "properties": {
        "agentPoolProfiles": [
        {
            "count": "3",
            "osSKU": "windows2025",
            "osType": "windows"
         } 
         ],
    }
    ```

#### [Modify JSON to create multiple Windows Server 2022 node pools](#tab/ws2022-arm)

- Create multiple Windows node pools in your AKS cluster by making the following modifications to your ARM template:

    ```json
      "properties": {
        "agentPoolProfiles": [
        {
            "count": "3",
            "osSKU": "windows2022",
            "osType": "windows"
         } 
         ],
    }
    ```

---

## Deploy your ARM template

- Deploy your ARM template by following the guidance in [Deploy an Azure Kubernetes Service (AKS) cluster using an ARM template][quick-arm].

:::zone-end

## Next steps

In this article, you learned how to create node pools in an AKS cluster using the Azure CLI.

To learn how to manage multiple node pools, see [Manage multiple node pools for AKS clusters](./manage-node-pools.md).

<!-- LINKS -->
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-nodepool]: /cli/azure/aks/nodepool
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-nodepool-list]: /cli/azure/aks/nodepool#az-aks-nodepool-list
[az-aks-nodepool-delete]: /cli/azure/aks/nodepool#az-aks-nodepool-delete
[az-group-create]: /cli/azure/group#az-group-create
[install-azure-cli]: /cli/azure/install-azure-cli
[azure-linux]: ./use-azure-linux.md
[windows]: ./windows-best-practices.md
[managedclusters]: /azure/templates/microsoft.containerservice/managedclusters?pivots=deployment-language-arm-template
[quick-arm]: ./learn/quick-kubernetes-deploy-rm-template.md
[flatcar]: ./flatcar-container-linux-for-aks.md
[os-guard]: ./use-azure-linux-os-guard.md
[az-feature-register]: /cli/azure/feature#az-feature-register
