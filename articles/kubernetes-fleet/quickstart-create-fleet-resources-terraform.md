---
title: "Quickstart: Create an Azure Kubernetes Fleet Manager resource and join member clusters using Terraform"
description: In this quickstart, you learn how to create an Azure Kubernetes Fleet Manager resource and join member clusters using Terraform.
ms.date: 04/15/2025
author: muhammadali
ms.author: alimuhammad
ms.service: azure-kubernetes-fleet-manager
ms.custom: template-quickstart, mode-other
ms.devlang: azurecli
ms.topic: quickstart
---

# Quickstart: Create an Azure Kubernetes Fleet Manager resource using Terraform

Get started with Azure Kubernetes Fleet Manager by using Terraform to create a Fleet resource.

## Prerequisites

[!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

* Read the [conceptual overview of Fleet Manager](./concepts-fleet.md), which provides an explanation of fleets and member clusters referenced in this document.
* An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).
* [Install and configure Terraform](/azure/developer/terraform/quickstart-configure).

## Create a Fleet Manager resource

You can create a Fleet Manager resource to later group your AKS clusters as member clusters.  If the Fleet Manager hub is enabled, other preview features are enabled, such as Kubernetes object propagation to member clusters. For more information, see the [conceptual overview of Fleet Manager types](./concepts-choosing-fleet.md), which provides a comparison of different Fleet Manager configurations.


> [!IMPORTANT]
> Once a Fleet Manager resource has been created, it's possible to upgrade a Fleet Manager resource without a hub cluster to one with a hub cluster. For Fleet Manager resources with a hub cluster, once private or public has been selected it cannot be changed.


### [Fleet Manager resource without hub cluster](#tab/without-hub-cluster)

To create a Fleet Manager resource without a hub cluster, implement the following Terraform code

#### Implement the Terraform code
- Create a directory you can use to test the sample Terraform code and make it your current directory.

- Create a file named `providers.tf` and insert the following code:
    [!code-terraform[master](~/terraform_samples/quickstart/101-aks-fleet-hubless/providers.tf)]

- Create a file named `main.tf` and insert the following code:
    [!code-terraform[master](~/terraform_samples/quickstart/101-aks-fleet-hubless/main.tf)]

- Create a file named `variables.tf` and insert the following code:
    [!code-terraform[master](~/terraform_samples/quickstart/101-aks-fleet-hubless/variables.tf)]

- Create a file named `outputs.tf` and insert the following code:
    [!code-terraform[master](~/terraform_samples/quickstart/101-aks-fleet-hubless/outputs.tf)]

> [!IMPORTANT]
> If you're using the 4.x azurerm provider, you must [explicitly specify the Azure subscription ID](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/4.0-upgrade-guide#specifying-subscription-id-is-now-mandatory) to authenticate to Azure before running the Terraform commands.
>
> One way to specify the Azure subscription ID without putting it in the `providers` block is to specify the subscription ID in an environment variable named `ARM_SUBSCRIPTION_ID`.
>
> For more information, see the [Azure provider reference documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#argument-reference).

#### Initialize Terraform

[!INCLUDE [terraform-init.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-init.md)]

#### Create a Terraform execution plan

[!INCLUDE [terraform-plan.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-plan.md)]

#### Apply a Terraform execution plan

[!INCLUDE [terraform-apply-plan.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-apply-plan.md)]

#### Verify the results

1. Verify results using either Azure CLI or Azure PowerShell.
    ### [Azure CLI](#tab/azure-cli)
    
    1. Get the Azure resource group name.
    
        ```console
        resource_group_name=$(terraform output -raw resource_group_name)
        ```
    
    1. Get the Fleet Manager name.
    
        ```console
        batch_name=$(terraform output -raw fleet_name)
        ```
    
    1. Run [az fleet show](/cli/azure/fleet#az-fleet-show) to view the Azure Kubernetes Fleet Manager.
    
        ```azurecli
        az fleet show --resource-group $resource_group_name --name $fleet_name
        ```
    
    ### [Azure PowerShell](#tab/azure-powershell)
    
    1. Get the Azure resource group name.
    
        ```powershell
        $resource_group_name=$(terraform output -raw resource_group_name)
        ```
    
    1. Get the Fleet Manager name.
    
        ```powershell
        $batch_name=$(terraform output -raw fleet_name)
        ```
    
    1. Run [Get-AzFleet](/powershell/module/az.fleet/get-azfleet) to view the Azure Kubernetes Fleet Manager.
    
        ```azurepowershell
        Get-AzFleet -ResourceGroupName $resource_group_name -Name $fleet_name
        ```
    
#### Clean up resources

[!INCLUDE [terraform-plan-destroy.md](~/azure-dev-docs-pr/articles/terraform/includes/terraform-plan-destroy.md)]

### [Fleet Manager resource with hub cluster](#tab/with-hub-cluster)

Public and Private hub cluster Fleet Manager resource cannot be created using Terraform yet.

---

## Next steps

* [Access Fleet Manager hub cluster Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md).