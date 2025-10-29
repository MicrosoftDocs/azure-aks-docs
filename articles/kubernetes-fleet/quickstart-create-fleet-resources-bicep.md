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

# Quickstart: Create an Azure Kubernetes Fleet Manager resource using Bicep

Get started with Azure Kubernetes Fleet Manager by using Bicep to create a Fleet Manager resource.

## Prerequisites

[!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

* Read the [conceptual overview of Fleet Manager](./concepts-fleet.md), which provides an explanation of fleets and member clusters referenced in this document.
* An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).

* [Install or upgrade Azure CLI](/cli/azure/install-azure-cli) to version `2.71.0` or later.
    - Ensure **fleet** extension is updated to version `1.5.2` or higher.

## Create a Fleet Manager resource

You can create a Fleet Manager resource to later group your AKS clusters as member clusters.  If the Fleet Manager hub is enabled, other preview features are enabled, such as Kubernetes object propagation to member clusters. For more information, see the [conceptual overview of Fleet Manager types](./concepts-choosing-fleet.md), which provides a comparison of different Fleet Manager configurations.


> [!IMPORTANT]
> Once a Fleet Manager resource has been created, it's possible to upgrade a Fleet Manager resource without a hub cluster to one with a hub cluster. For Fleet Manager resources with a hub cluster, once private or public has been selected it cannot be changed.


### [Fleet Manager resource without hub cluster](#tab/without-hub-cluster)

If you only want to use Fleet Manager for update orchestration, you can create a hubless Fleet Manager with the following Bicep:

##### Review Bicep
:::code language="bicep" source="~/quickstart-templates/quickstarts/microsoft.kubernetes/fleet-hubless/main.bicep":::

##### Deploy the Bicep file using either Azure CLI or Azure PowerShell.

1. Save the Bicep file as **main.bicep** to your local computer.


2. Deploy the Bicep file using either Azure CLI or Azure PowerShell.
   
    ### [Azure CLI](#tab/azure-cli)
   
    ```azurecli
    az group create --name myResourceGroup --location eastus
    az deployment group create --resource-group myResourceGroup --template-file main.bicep'
    ```
   
    ### [Azure PowerShell](#tab/azure-powershell)
   
    ```azurepowershell
    New-AzResourceGroup -Name myResourceGroup -Location eastus
    New-AzResourceGroupDeployment -ResourceGroupName myResourceGroup -TemplateFile ./main.bicep"
    ```



### [Fleet Manager resource with hub cluster](#tab/with-hub-cluster)
If you want to use Fleet Manager for Kubernetes object propagation in addition to update orchestration, then you need to create the Fleet Manager resource with the hub cluster.

Fleet Manager clusters with a hub cluster support both public and private modes for network access. For more information, see [Choose an Azure Kubernetes Fleet Manager option](./concepts-choosing-fleet.md#network-access-modes-for-hub-cluster).

#### Public hub cluster
To create a public Fleet Manager resource with a hub cluster, use the following Bicep

##### Review Bicep

:::code language="bicep" source="~/quickstart-templates/quickstarts/microsoft.kubernetes/fleet-hubful/main.bicep":::

##### Deploy the Bicep file using either Azure CLI or Azure PowerShell.

1. Save the Bicep file as **main.bicep** to your local computer.


2. Deploy the Bicep file using either Azure CLI or Azure PowerShell.
   
    ### [Azure CLI](#tab/azure-cli)
   
    ```azurecli
    az group create --name myResourceGroup --location eastus
    az deployment group create --resource-group myResourceGroup --template-file main.bicep'
    ```
   
    ### [Azure PowerShell](#tab/azure-powershell)
   
    ```azurepowershell
    New-AzResourceGroup -Name myResourceGroup -Location eastus
    New-AzResourceGroupDeployment -ResourceGroupName myResourceGroup -TemplateFile ./main.bicep"
    ```

#### Private hub cluster

[!INCLUDE [private-fleet-prerequisites.md](./includes/private-fleet/private-fleet-prerequisites.md)]

1. Fetch Fleet Manager's service principal object ID:

```azurecli-interactive
az ad sp list --display-name "Azure Kubernetes Service - Fleet RP" --query
```

```output
xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

2. Review Bicep
:::code language="bicep" source="~/quickstart-templates/quickstarts/microsoft.kubernetes/fleet-hubful-private/main.bicep":::

3. Deploy the Bicep file using either Azure CLI or Azure PowerShell.
Deploy the Bicep file with service principal object ID from first step:

- Save the Bicep file as **main.bicep** to your local computer.
    
- Deploy the Bicep file using either Azure CLI or Azure PowerShell.
        
    ### [Azure CLI](#tab/azure-cli)
        
    ```azurecli
    az group create --name myResourceGroup --location eastus
    az deployment group create --resource-group myResourceGroup --template-file main.bicep --parameters fleets_sp_object_id=<fleet-sp-object-id>
    ```
        
    ### [Azure PowerShell](#tab/azure-powershell)
        
    ```azurepowershell
    New-AzResourceGroup -Name myResourceGroup -Location eastus
    New-AzResourceGroupDeployment -ResourceGroupName myResourceGroup -TemplateFile ./main.bicep -fleets_sp_object_id=<fleet-sp-object-id>"
    ```
---

## Next steps

* [Access Fleet Manager hub cluster Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md).