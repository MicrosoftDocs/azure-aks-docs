---
title: Use system node pools in Azure Kubernetes Service (AKS)
description: Learn how to create and manage system node pools in Azure Kubernetes Service (AKS)
ms.topic: how-to
ms.date: 04/30/2026
author: schaffererin
ms.author: schaffererin
ms.custom: fasttrack-edit, devx-track-azurecli, devx-track-azurepowershell, biannual
ms.subservice: aks-nodes
zone_pivot_groups: cli-powershell-terraform

# Customer intent: As a Kubernetes administrator, I want to create and manage system node pools in an Azure Kubernetes Service (AKS) cluster, so that I can ensure critical system pods are properly isolated and efficiently scheduled, thereby maintaining the reliability of my applications.
---

# Manage system node pools in Azure Kubernetes Service (AKS)

In Azure Kubernetes Service (AKS), nodes of the same configuration are grouped together into _node pools_. Node pools contain the underlying virtual machines (VM) that run your applications. System node pools and user node pools are two different node pool modes for your AKS clusters. This article explains how to manage system node pools in AKS. For information about how to use multiple node pools, see [create node pools][create-node-pools].

- **System node pools**: The primary purpose is to host critical system pods like `CoreDNS` and `metrics-server`. System node pools shouldn't be used to run your application. System node pools use Ubuntu Linux or Azure Linux.
- **User node pools**: The primary purpose is to host your application pods and isolate applications from the system node pool. This isolation prevents an application from causing instability with your cluster's system node pool. User node pools can use Ubuntu Linux, Azure Linux, or Windows.

A production AKS cluster with a single system node pool must contain at least two nodes. The recommendation for a production AKS cluster with a single system node pool is to have at least three nodes for improved fault tolerance and availability zones. For example, the [az aks create][az-aks-create] command's default node count is three and creates a new cluster with a single Linux system node pool and three Linux nodes.

It's possible, but not recommended, to schedule application pods on a system node pool if you only have one node pool in your AKS cluster. A better solution is to create a user node pool for your application.

## Before you begin

:::zone pivot="azure-cli"

You need the Azure CLI version 2.3.1 or later installed and configured. To find the version, run the `az --version` command. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

:::zone-end

:::zone pivot="azure-powershell"

You need the Azure PowerShell version 7.5.0 or later installed and configured. To find the version, run the `Get-InstalledModule -Name Az` command. If you need to install or upgrade, see [Install Azure PowerShell][install-azure-powershell].

:::zone-end

:::zone pivot="terraform"

Before you begin, make sure you have the following prerequisites:

- An active Azure subscription.
- Terraform installed locally.
- Azure CLI installed and signed in.
- Permissions to create and manage AKS resources.

Set your subscription:

```bash
az account set --subscription <subscription-id>
```

:::zone-end

## Limitations

The following limitations apply when you create and manage AKS clusters that support system node pools.

- See [Quotas, VM size restrictions, and region availability in AKS][quotas-skus-regions].
- An API version of `2020-03-01` or greater must be used to set a node pool mode. Clusters created on API versions older than `2020-03-01` contain only user node pools, but can be migrated to contain system node pools by following [update pool mode steps](#update-existing-cluster-system-and-user-node-pools).
- The name of a node pool can only contain lowercase alphanumeric characters and must begin with a lowercase letter. For Linux node pools, the length must be between 1 and 12 characters. For Windows node pools, the length must be between one and six characters.
- The mode of a node pool is a required property and must be explicitly set when using ARM templates or direct API calls.

## System and user node pools

For a system node pool, AKS automatically assigns the label `kubernetes.azure.com/mode: system` to its nodes. This causes AKS to prefer scheduling system pods on node pools that contain this label. This label doesn't prevent you from scheduling application pods on system node pools. But we recommend you isolate critical system pods from your application pods to prevent misconfigured or rogue application pods from accidentally deleting system pods.

You can enforce this behavior by creating a dedicated system node pool. Use the `CriticalAddonsOnly=true:NoSchedule` taint to prevent application pods from being scheduled on system node pools.

System node pools have the following restrictions:

- System node pools must support at least 30 pods as described by the [minimum and maximum value formula for pods][maximum-pods].
- System pools `osType` must be Linux.
- User node pools `osType` can be Linux or Windows.
- System pools must contain at least two nodes but the recommendation is three nodes. User node pools can contain zero or more nodes.
- System node pools require a VM SKU of at least 4 vCPUs and 4 GB of memory.
- [B series VMs][b-series-vm] aren't supported for system node pools.
- A minimum of three nodes of 8 vCPUs or two nodes of at least 16 vCPUs is recommended (for example, Standard_DS4_v2), especially for large clusters (Multiple CoreDNS Pod replicas, 3-4+ add-ons, etc.).
- Spot node pools require user node pools.
- Adding another system node pool or changing which node pool is a system node pool doesn't automatically move system pods. System pods can continue to run on the same node pool, even if you change it to a user node pool. If you delete or scale down a node pool running system pods that were previously a system node pool, those system pods are redeployed with preferred scheduling to the new system node pool.

You can do the following operations with node pools:

- Create a dedicated system node pool (prefer scheduling of system pods to node pools of `mode:system`)
- Change a system node pool to be a user node pool, provided you have another system node pool to take its place in the AKS cluster.
- Change a user node pool to be a system node pool.
- Delete user node pools.
- You can delete system node pools, provided you have another system node pool to take its place in the AKS cluster.
- An AKS cluster can have multiple system node pools and requires at least one system node pool.
- If you want to change various immutable settings on existing node pools, you can create new node pools to replace them. One example is to add a new node pool with a new `maxPods` setting and delete the old node pool.
- Use [node affinity][node-affinity] to _require_ or _prefer_ which nodes can be scheduled based on node labels. You can set `key` to `kubernetes.azure.com`, `operator` to `In`, and `values` of either `user` or `system` to your YAML, applying this definition using `kubectl apply -f yourYAML.yaml`.

## Create a new AKS cluster with a system node pool

:::zone pivot="azure-cli"

When you create a new AKS cluster, the initial node pool defaults to a mode of type `System`. When you create new node pools with [`az aks nodepool add`][az-aks-nodepool-add], those node pools are user node pools unless you explicitly specify the mode parameter.

Create variables for the resource group, cluster name, and location for commands used in this article. This article specifies values or you can use your own values.

```bash
export RESOURCE_GROUP="myResourceGroup"
export CLUSTER_NAME="myAKSCluster"
export LOCATION="eastus"
export NEW_SYSTEM_NP="systempool"
export NEW_NODE_POOL="mynodepool"
```

The following example creates a resource group named _myResourceGroup_ in the _eastus_ region.

```azurecli-interactive
az group create --name $RESOURCE_GROUP --location $LOCATION
```

Use the [`az aks create`][az-aks-create] command to create an AKS cluster. The following example creates a cluster named _myAKSCluster_ with one dedicated system pool containing two nodes. For your production workloads, ensure you're using system node pools with at least three nodes. This operation takes several minutes to complete.

```azurecli-interactive
az aks create --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --node-count 2 --generate-ssh-keys
```

:::zone-end

:::zone pivot="azure-powershell"

When you create a new AKS cluster, the initial node pool defaults to a mode of type `system`. When you create new node pools with `New-AzAksNodePool`, those node pools are user node pools. A node pool's mode can be [updated at any time][update-node-pool-mode].

Create variables for the resource group, cluster name, and location for commands used in this article. This article specifies values or you can use your own values.

```azurepowershell-interactive
$ResourceGroup="myResourceGroup"
$ClusterName="myAKSCluster"
$Location="eastus"
$NewSystemNP="systempool"
$NewNodePool="mynodepool"
```

The following example creates a resource group named _myResourceGroup_ in the _eastus_ region.

```azurepowershell-interactive
New-AzResourceGroup -ResourceGroupName $ResourceGroup -Location $Location
```

Use the [New-AzAksCluster][new-azakscluster] cmdlet to create an AKS cluster. The following example creates a cluster named _myAKSCluster_ with one dedicated system pool containing two nodes. For your production workloads, ensure you're using system node pools with at least three nodes. The operation takes several minutes to complete.

```azurepowershell-interactive
New-AzAksCluster -ResourceGroupName $ResourceGroup -Name $ClusterName -NodeCount 2 -GenerateSshKey
```

:::zone-end

:::zone pivot="terraform"

Use the following Terraform configuration to create an AKS cluster with a system node pool.

### Create the Terraform configuration file

Create a file named `main.tf`, and add the following shared configuration:

```terraform
terraform {
 required_version = ">= 1.0"
 required_providers {
   azurerm = {
     source  = "hashicorp/azurerm"
     version = "~> 4.0"
   }
 }
}
provider "azurerm" {
 features {}
}
```

### Create a resource group

Add the following resource group configuration:
```terraform
resource "azurerm_resource_group" "rg" {
 name     = "aks-system-pool-rg"
 location = "East US"
}
```
A resource group is used to organize and manage Azure resources.

### Create a new AKS cluster

Add the following configuration to create an AKS cluster. The initial node pool is created as a system node pool and is required for cluster operation.

```terraform
resource "azurerm_kubernetes_cluster" "aks" {
 name                = "aks-system-pool-cluster"
 location            = azurerm_resource_group.rg.location
 resource_group_name = azurerm_resource_group.rg.name
 dns_prefix          = "akssystempool"
 default_node_pool {
   name                = "systemnp"
   vm_size             = "Standard_D4s_v5"
   node_count          = 2
   min_count           = 2
   max_count           = 3
   max_pods            = 30
   enable_auto_scaling = true
 }
 identity {
   type = "SystemAssigned"
 }
 network_profile {
   network_plugin    = "azure"
   load_balancer_sku = "standard"
 }
}
```

:::zone-end

## Add a dedicated system node pool to an existing AKS cluster

:::zone pivot="azure-cli"

You can add one or more system node pools to existing AKS clusters. The recommendation is to schedule your application pods on user node pools, and dedicate system node pools to only critical system pods. This separation prevents rogue application pods from accidentally deleting system pods. Enforce this behavior with the `CriticalAddonsOnly=true:NoSchedule` [taint][aks-taints] for your system node pools.

The following command adds a dedicated node pool of mode type `System` with three nodes. The [`az aks nodepool add`][az-aks-nodepool-add] command adds three nodes by default, but you use the `--node-count` parameter to specify the number of nodes you want.

```azurecli-interactive
az aks nodepool add \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name $NEW_SYSTEM_NP \
  --node-count 3 \
  --node-taints CriticalAddonsOnly=true:NoSchedule \
  --mode System
```

:::zone-end

:::zone pivot="azure-powershell"

You can add one or more system node pools to existing AKS clusters. The recommendation is to schedule your application pods on user node pools, and dedicate system node pools to only critical system pods. Adding more system node pools prevents rogue application pods from accidentally deleting system pods. Enforce the behavior with the `CriticalAddonsOnly=true:NoSchedule` [taint][aks-taints] for your system node pools.

The following command adds a dedicated node pool of mode type `System` with three nodes.

```azurepowershell-interactive
$systempoolparams = @{
  ResourceGroupName = $ResourceGroup
  ClusterName = $ClusterName
  Name = $NewSystemNP
  Count = 3
  Mode = 'System'
  NodeTaint = 'CriticalAddonsOnly=true:NoSchedule'
}

New-AzAksNodePool @systempoolparams
```

:::zone-end

:::zone pivot="terraform"

Add a second node pool configured as a system node pool to isolate critical system workloads.

```terraform
resource "azurerm_kubernetes_cluster_node_pool" "system_pool" {
 name                  = "systempool"
 kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
 vm_size               = "Standard_D4s_v5"
 node_count            = 3
 mode                  = "System"
 max_pods              = 30
 node_taints = [
   "CriticalAddonsOnly=true:NoSchedule"
 ]
}
```

This configuration applies the `CriticalAddonsOnly=true:NoSchedule` taint so that application workloads aren't scheduled on the dedicated system node pool.

### Add a user node pool

To separate application workloads from system components, add a user node pool.

```terraform
resource "azurerm_kubernetes_cluster_node_pool" "user_pool" {
 name                  = "userpool"
 kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
 vm_size               = "Standard_D4s_v5"
 node_count            = 2
 mode                  = "User"
 max_pods              = 30
 enable_auto_scaling = true
 min_count           = 2
 max_count           = 4
}
```

User node pools provide a dedicated environment for application pods.

### Final check before deployment

Your `main.tf` should include:

- Terraform and provider configuration
- Resource group
- AKS cluster with the default system node pool
- Dedicated system node pool
- Optional user node pool, if needed

A completed configuration looks similar to the following example:

```terraform
terraform {
 required_version = ">= 1.0"
 required_providers {
   azurerm = {
     source  = "hashicorp/azurerm"
     version = "~> 4.0"
   }
 }
}
provider "azurerm" {
 features {}
}
resource "azurerm_resource_group" "rg" {
 name     = "aks-system-pool-rg"
 location = "East US"
}
resource "azurerm_kubernetes_cluster" "aks" {
 name                = "aks-system-pool-cluster"
 location            = azurerm_resource_group.rg.location
 resource_group_name = azurerm_resource_group.rg.name
 dns_prefix          = "akssystempool"
 default_node_pool {
   name                = "systemnp"
   vm_size             = "Standard_D4s_v5"
   node_count          = 2
   min_count           = 2
   max_count           = 3
   max_pods            = 30
   enable_auto_scaling = true
 }
 identity {
   type = "SystemAssigned"
 }
 network_profile {
   network_plugin    = "azure"
   load_balancer_sku = "standard"
 }
}
resource "azurerm_kubernetes_cluster_node_pool" "system_pool" {
 name                  = "systempool"
 kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
 vm_size               = "Standard_D4s_v5"
 node_count            = 3
 mode                  = "System"
 max_pods              = 30
 node_taints = [
   "CriticalAddonsOnly=true:NoSchedule"
 ]
}
resource "azurerm_kubernetes_cluster_node_pool" "user_pool" {
 name                  = "userpool"
 kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
 vm_size               = "Standard_D4s_v5"
 node_count            = 2
 mode                  = "User"
 max_pods              = 30
 enable_auto_scaling = true
 min_count           = 2
 max_count           = 4
}
```

### Validate the configuration

Run the following commands to format, initialize, and validate the configuration:

```bash
terraform fmt
terraform init
terraform validate
```

### Review the execution plan

Run the following command to review the execution plan before deployment:

```bash
terraform plan
```

### Apply the configuration

Run the following command to create the AKS cluster and node pools:

```bash
terraform apply
```

### Verify the deployment

Check the dedicated system node pool configuration:

```bash
az aks nodepool show \
 --resource-group aks-system-pool-rg \
 --cluster-name aks-system-pool-cluster \
 --name systempool
```

Review the output and confirm the node pool is configured with `mode` set to `System`.
Connect to the cluster and list the nodes:

```bash
az aks get-credentials \
 --resource-group aks-system-pool-rg \
 --name aks-system-pool-cluster

kubectl get nodes
```

:::zone-end

## Show details for your node pool

:::zone pivot="azure-cli"

You can check the details of your node pool with the following command.

```azurecli-interactive
az aks nodepool show \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name $NEW_SYSTEM_NP \
  --query "{Count:count, Mode:mode, NodePool:name, NodeTaint:nodeTaints, ResourceGroup:resourceGroup}"
```

A mode of type **System** is defined for system node pools, and a mode of type **User** is defined for user node pools. For a system pool, verify the `nodeTaints` property is set to `CriticalAddonsOnly=true:NoSchedule`, which prevents application pods from being scheduled on this node pool.

```output
{
  "Count": 3,
  "Mode": "System",
  "NodePool": "systempool",
  "NodeTaint": [
    "CriticalAddonsOnly=true:NoSchedule"
  ],
  "ResourceGroup": "myResourceGroup"
}
```

:::zone-end

:::zone pivot="azure-powershell"

You can check the details of your node pool with the following command.

```azurepowershell-interactive
Get-AzAksNodePool -ResourceGroupName $ResourceGroup -ClusterName $ClusterName -Name $NewSystemNP |
  Select-Object -Property Count, Mode, Name, NodeTaints
```

A mode of type **System** is defined for system node pools, and a mode of type **User** is defined for user node pools. For a system pool, verify the taint is set to `CriticalAddonsOnly=true:NoSchedule`, which prevents application pods from being scheduled on this node pool.

```output
Count Mode   Name       NodeTaints
----- ----   ----       ----------
    3 System systempool {CriticalAddonsOnly=true:NoSchedule}
```

:::zone-end

:::zone pivot="terraform"

This step was included in the previous section's [Verify the deployment](#verify-the-deployment) step.

A mode of type **System** is defined for system node pools, and a mode of type **User** is defined for user node pools. For a system pool, verify the `nodeTaints` property is set to `CriticalAddonsOnly=true:NoSchedule`, which prevents application pods from being scheduled on this node pool.

:::zone-end

## Update existing cluster system and user node pools

:::zone pivot="azure-cli"

> [!NOTE]
> An API version of `2020-03-01` or greater must be used to set a system node pool mode. Clusters created on API versions older than `2020-03-01` contain only user node pools as a result. To receive system node pool functionality and benefits on older clusters, update the mode of existing node pools with the following commands on the latest Azure CLI version.

You can change modes for both system node pools and user node pools. You can change a system node pool to a user node pool only if another system node pool already exists on the AKS cluster.

Run this command to create a new system mode node pool.

```azurecli-interactive
az aks nodepool add \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name $NEW_NODE_POOL \
  --node-count 3 \
  --mode System
```

You can verify the mode with the following command.

```azurecli-interactive
az aks nodepool show \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name $NEW_NODE_POOL \
  --query mode --output tsv
```

```output
System
```

Run this command to change a system node pool to a user node pool.

```azurecli-interactive
az aks nodepool update \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name $NEW_NODE_POOL \
  --mode User
```

You can verify the mode changed with the following command.

```azurecli-interactive
az aks nodepool show \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name $NEW_NODE_POOL \
  --query mode --output tsv
```

```output
User
```

:::zone-end

:::zone pivot="azure-powershell"

> [!NOTE]
> An API version of `2020-03-01` or greater must be used to set a system node pool mode. Clusters created on API versions older than `2020-03-01` contain only user node pools as a result. To receive system node pool functionality and benefits on older clusters, update the mode of existing node pools with the following commands on the latest Azure PowerShell version.

You can change modes for both system node pools and user node pools. You can change a system node pool to a user node pool only if another system node pool already exists on the AKS cluster.

Run this command to create a new system mode node pool.

```azurepowershell-interactive
$newpoolparams = @{
  ResourceGroupName = $ResourceGroup
  ClusterName = $ClusterName
  Name = $NewNodePool
  Count = 3
  Mode = 'System'
}

New-AzAksNodePool @newpoolparams
```

You can verify the mode with the following command.

```azurepowershell-interactive
Get-AzAksNodePool -ResourceGroupName $ResourceGroup -ClusterName $ClusterName -Name $NewNodePool |
  Select-Object -Property Mode
```

```output
Mode
----
System
```

Run this command to change a system node pool to a user node pool.

```azurepowershell-interactive
$updateuserpoolparams = @{
  ResourceGroupName = $ResourceGroup
  ClusterName = $ClusterName
  Name = $NewNodePool
  Mode = 'User'
}

Update-AzAksNodePool @updateuserpoolparams
```

You can verify the mode with the following command.

```azurepowershell-interactive
Get-AzAksNodePool -ResourceGroupName $ResourceGroup -ClusterName $ClusterName -Name $NewNodePool |
  Select-Object -Property Mode
```

```output
Mode
----
User
```

:::zone-end

:::zone pivot="terraform"

To change the mode of an existing node pool, update the `mode` value in the Terraform configuration and reapply the deployment.

For example, the following configuration changes the `user_pool` node pool to a system node pool:

```terraform
resource "azurerm_kubernetes_cluster_node_pool" "user_pool" {
 name                  = "userpool"
 kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
 vm_size               = "Standard_D4s_v5"
 node_count            = 2
 mode                  = "System"
 max_pods              = 30
 enable_auto_scaling = true
 min_count           = 2
 max_count           = 4
}
```

After updating the configuration, run:

```bash
terraform plan
terraform apply
```

To change the dedicated system node pool to a user node pool, update the `mode` value for `system_pool` to `User` and reapply the configuration.

:::zone-end

## Delete a system node pool

:::zone pivot="azure-cli"

> [!NOTE]
> To use system node pools on AKS clusters before API version `2020-03-01`, add a new system node pool, then delete the original default node pool.

You must have at least two system node pools on your AKS cluster before you can delete one of them.

```azurecli-interactive
az aks nodepool delete \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name $NEW_NODE_POOL
```

After you delete the system node pool, you should have the original system node pool that was created with the cluster and the system node pool you created in the section [add a dedicated system node pool to an existing AKS cluster](#add-a-dedicated-system-node-pool-to-an-existing-aks-cluster).


```azurecli-interactive
az aks nodepool list \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --query "[].{Name:name, Mode:mode}" --output table
```

:::zone-end

:::zone pivot="azure-powershell"

> [!NOTE]
> To use system node pools on AKS clusters before API version `2020-03-01`, add a new system node pool, then delete the original default node pool.

You must have at least two system node pools on your AKS cluster before you can delete one of them.

The following command prompts you for confirmation to delete the node pool. Type `Y` to confirm.

```azurepowershell-interactive
Remove-AzAksNodePool $ResourceGroup -ClusterName $ClusterName -Name $NewNodePool
```

After you delete the system node pool, you should have the original system node pool that was created with the cluster and the system node pool you created in the section [add a dedicated system node pool to an existing AKS cluster](#add-a-dedicated-system-node-pool-to-an-existing-aks-cluster).

```azurepowershell-interactive
Get-AzAksNodePool -ResourceGroupName $ResourceGroup -ClusterName $ClusterName
```

:::zone-end

:::zone pivot="terraform"

A cluster must always contain at least one system node pool. If the cluster has more than one system node pool, you can remove one by deleting its resource block from the Terraform configuration and applying the change.

For example, remove the `system_pool` resource block and then run:

```bash
terraform plan
terraform apply
```

:::zone-end

## Clean up resources

When you delete the AKS cluster's resource group, all the cluster resources and the related node resource group (`MC_`) are deleted.

:::zone pivot="azure-cli"

To delete the cluster, use the [az group delete][az-group-delete] command to delete the AKS resource group:

```azurecli-interactive
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

:::zone-end

:::zone pivot="azure-powershell"

To delete the cluster, use the [Remove-AzResourceGroup][remove-azresourcegroup] command to delete the AKS resource group:

```azurepowershell-interactive
Remove-AzResourceGroup -Name $ResourceGroup -Force
```

:::zone-end

:::zone pivot="terraform"

When you're finished, remove the resources:

```bash
terraform destroy
```

:::zone-end

## Next steps

In this article, you learned how to create and manage system node pools in an AKS cluster. For information about how to start and stop AKS node pools, see [start and stop AKS node pools][start-stop-nodepools].


<!-- EXTERNAL LINKS -->
[kubernetes-drain]: https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[kubectl-taint]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#taint
[kubectl-describe]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#describe
[kubernetes-labels]: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
[kubernetes-label-syntax]: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set

<!-- INTERNAL LINKS -->
[aks-taints]: manage-node-pools.md#set-node-pool-taints
[aks-windows]: windows-container-cli.md
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-aks-create]: /cli/azure/aks#az-aks-create
[new-azakscluster]: /powershell/module/az.aks/new-azakscluster
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-nodepool-list]: /cli/azure/aks/nodepool#az-aks-nodepool-list
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[az-aks-nodepool-upgrade]: /cli/azure/aks/nodepool#az-aks-nodepool-upgrade
[az-aks-nodepool-scale]: /cli/azure/aks/nodepool#az-aks-nodepool-scale
[az-aks-nodepool-delete]: /cli/azure/aks/nodepool#az-aks-nodepool-delete
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-group-create]: /cli/azure/group#az-group-create
[az-group-delete]: /cli/azure/group#az-group-delete
[remove-azresourcegroup]: /powershell/module/az.resources/remove-azresourcegroup
[az-deployment-group-create]: /cli/azure/deployment/group#az-deployment-group-create
[gpu-cluster]: gpu-cluster.md
[install-azure-cli]: /cli/azure/install-azure-cli
[install-azure-powershell]: /powershell/azure/install-az-ps
[operator-best-practices-advanced-scheduler]: operator-best-practices-advanced-scheduler.md
[quotas-skus-regions]: quotas-skus-regions.md
[supported-versions]: supported-kubernetes-versions.md
[tag-limitation]: ../azure-resource-manager/management/tag-resources.md
[taints-tolerations]: operator-best-practices-advanced-scheduler.md#provide-dedicated-nodes-using-taints-and-tolerations
[vm-sizes]: ../virtual-machines/sizes.md
[create-node-pools]: create-node-pools.md
[maximum-pods]: concepts-network-ip-address-planning.md#maximum-pods-per-node
[b-series-vm]: /azure/virtual-machines/sizes-b-series-burstable
[update-node-pool-mode]: use-system-pools.md#update-existing-cluster-system-and-user-node-pools
[start-stop-nodepools]: ./start-stop-nodepools.md
[node-affinity]: operator-best-practices-advanced-scheduler.md#node-affinity
