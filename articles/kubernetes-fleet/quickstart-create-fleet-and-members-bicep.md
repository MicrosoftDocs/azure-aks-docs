---
title: "Quickstart: Create an Azure Kubernetes Fleet Manager resource and join member clusters using Bicep"
description: In this quickstart, you learn how to create an Azure Kubernetes Fleet Manager resource and join member clusters using Bicep.
ms.date: 04/15/2025
author: muhammadali
ms.author: alimuhammad
ms.service: azure-kubernetes-fleet-manager
ms.custom: template-quickstart, mode-other
ms.devlang: azurecli
ms.topic: quickstart
---

# Quickstart: Create Azure Kubernetes Fleet Manager using Bicep

Get started with Azure Kubernetes Fleet Manager (Fleet) by using Bicep to create a Fleet resource and later connect Azure Kubernetes Service (AKS) clusters as member clusters.

## Prerequisites

[!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

* Read the [conceptual overview of this feature](./concepts-fleet.md), which provides an explanation of fleets and member clusters referenced in this document.
* An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).
* An identity (user or service principal) with the following permissions on the Fleet and AKS resource types for completing the steps listed in this quickstart:

  * Microsoft.ContainerService/fleets/read
  * Microsoft.ContainerService/fleets/write
  * Microsoft.ContainerService/fleets/members/read
  * Microsoft.ContainerService/fleets/members/write
  * Microsoft.ContainerService/fleetMemberships/read
  * Microsoft.ContainerService/fleetMemberships/write
  * Microsoft.ContainerService/managedClusters/read
  * Microsoft.ContainerService/managedClusters/write
  * Microsoft.ContainerService/managedClusters/listClusterUserCredential/action

## Create a Fleet resource

You can create a Fleet resource to later group your AKS clusters as member clusters. When created via Azure CLI, by default, this resource enables member cluster grouping and update orchestration. If the Fleet hub is enabled, other preview features are enabled, such as Kubernetes object propagation to member clusters and L4 service load balancing across multiple member clusters. For more information, see the [conceptual overview of fleet types](./concepts-choosing-fleet.md), which provides a comparison of different fleet configurations.


> [!IMPORTANT]
> Once a Kubernetes Fleet resource has been created, it's possible to upgrade a Kubernetes Fleet resource without a hub cluster to one with a hub cluster. For Kubernetes Fleet resources with a hub cluster, once private or public has been selected it cannot be changed.


### [Kubernetes Fleet resource without hub cluster](#tab/without-hub-cluster)

If you want to use Fleet only for update orchestration, you can create a Fleet without a hub cluster with the following Bicep:

##### Review Bicep
:::code language="bicep" source="~/quickstart-templates/quickstarts/microsoft.kubernetes/aks/fleet/hubless-fleet-deploy.bicep":::

##### Deploy the Bicep file using either Azure CLI or Azure PowerShell.

1. Save the Bicep file as **main.bicep** to your local computer.


2. Deploy the Bicep file using either Azure CLI or Azure PowerShell.
   
    ### [Azure CLI](#tab/azure-cli)
   
    ```azurecli
    az deployment group create --resource-group myResourceGroup --template-file main.bicep'
    ```
   
    ### [Azure PowerShell](#tab/azure-powershell)
   
    ```azurepowershell
    New-AzResourceGroup -Name myResourceGroup -Location eastus
    New-AzResourceGroupDeployment -ResourceGroupName myResourceGroup -TemplateFile ./main.bicep"
    ```



### [Kubernetes Fleet resource with hub cluster](#tab/with-hub-cluster)
If you want to use Fleet for Kubernetes object propagation and multi-cluster load balancing in addition to update orchestration, then you need to create the Fleet resource with the hub cluster.

Kubernetes Fleet clusters with a hub cluster support both public and private modes for network access. For more information, see [Choose an Azure Kubernetes Fleet Manager option](./concepts-choosing-fleet.md#network-access-modes-for-hub-cluster).

#### Public hub cluster
To create a public Kubernetes Fleet resource with a hub cluster, use the following Bicep

##### Review Bicep

:::code language="bicep" source="~/quickstart-templates/quickstarts/microsoft.kubernetes/aks/fleet/public-hubful-fleet-deploy.bicep":::

##### Deploy the Bicep file using either Azure CLI or Azure PowerShell.

1. Save the Bicep file as **main.bicep** to your local computer.


2. Deploy the Bicep file using either Azure CLI or Azure PowerShell.
   
    ### [Azure CLI](#tab/azure-cli)
   
    ```azurecli
    az deployment group create --resource-group myResourceGroup --template-file main.bicep'
    ```
   
    ### [Azure PowerShell](#tab/azure-powershell)
   
    ```azurepowershell
    New-AzResourceGroup -Name myResourceGroup -Location eastus
    New-AzResourceGroupDeployment -ResourceGroupName myResourceGroup -TemplateFile ./main.bicep"
    ```


#### Private hub cluster
When creating a private access mode Kubernetes Fleet resource with a hub cluster, some extra considerations apply:
- Fleet requires you to provide the subnet on which the Fleet hub cluster's node VMs will be placed. This can be done by setting `subnetId` in the `agentProfile` within the Fleet's `hubProfile`.
-  The address prefix of the vnet **vnet_name** must not overlap with the AKS default service range of `10.0.0.0/16`.
- When using an AKS private cluster, you have the ability to configure fully qualified domain names (FQDNs) and FQDN subdomains. This functionality doesn't apply to the private access mode type hub cluster.
- Private access mode requires a `Network Contributor` role assignment on the agent subnet for Fleet's first party identity. This is **NOT** needed when creating private fleet using the `az fleet create` command because the CLI automatically creates the role assignment.

1. Fetch Fleet's service principal object ID:

    ```azurecli-interactive
    az ad sp show --id "609d2f62-527f-4451-bfd2-ac2c7850822c" --query id -o tsv
    ```

    ```output
    f3d1f4a8-1a2c-470a-8f8a-79bcfb2b5db1
    ```

2. Deploy the Bicep with service principal object ID from Step 1:

    ##### Review Bicep
    :::code language="bicep" source="~/quickstart-templates/quickstarts/microsoft.kubernetes/aks/fleet/private-hubful-fleet-deploy.bicep":::

    ##### Deploy the Bicep file using either Azure CLI or Azure PowerShell.
    
      1. Save the Bicep file as **main.bicep** to your local computer.
    
    
      2. Deploy the Bicep file using either Azure CLI or Azure PowerShell.
        
          ### [Azure CLI](#tab/azure-cli)
        
          ```azurecli
          az deployment group create --resource-group myResourceGroup --template-file main.bicep --parameters fleets_sp_object_id=<fleet-sp-object-id>
          ```
        
          ### [Azure PowerShell](#tab/azure-powershell)
        
          ```azurepowershell
          New-AzResourceGroup -Name myResourceGroup -Location eastus
          New-AzResourceGroupDeployment -ResourceGroupName myResourceGroup -TemplateFile ./main.bicep -fleets_sp_object_id=<fleet-sp-object-id>"
          ```
    

## Next steps

* [Access Fleet hub cluster Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md).