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

# Quickstart: Create an Azure Kubernetes Fleet Manager using Terraform

**Applies to:** :heavy_check_mark: Fleet Manager :heavy_check_mark: Fleet Manager with hub cluster

Learn how to create an Azure Kubernetes Fleet Manager using Terraform.

## Before you begin

[!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

* Read the [conceptual overview of Fleet Manager](./concepts-fleet.md), which provides an explanation of fleets and member clusters referenced in this document.
* An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).
* [Install and configure Terraform](/azure/developer/terraform/quickstart-configure).

> [!IMPORTANT]
> If you're using the 4.x AzureRM Terraform provider, you must [explicitly specify the Azure subscription ID](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/4.0-upgrade-guide#specifying-subscription-id-is-now-mandatory) to authenticate to Azure before running commands.
>
> One way to specify the Azure subscription ID without putting it in the `providers` block is to specify the subscription ID in an environment variable named `ARM_SUBSCRIPTION_ID`.
>
> For more information, see the [Azure provider reference documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#argument-reference).

## Create a Fleet Manager

You can create a Fleet Manager and later add your AKS and Arc-enabled clusters as member clusters.  If the Fleet Manager has a hub cluster, additional features are enabled, such as [Kubernetes object propagation](./concepts-resource-propagation.md) and [Managed Fleet Namespaces](./concepts-fleet-managed-namespace.md). For more information, see the [conceptual overview of Fleet Manager types](./concepts-choosing-fleet.md), which provides a comparison of different Fleet Manager configurations.

> [!NOTE]
> Once a Fleet Manager is created, it's possible to switch from a Fleet Manager resource without a hub cluster to one with a hub cluster. For Fleet Manager resources with a hub cluster, once private or public has been selected it cannot be changed.

### [Fleet Manager without hub cluster](#tab/without-hub-cluster)

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

### [Fleet Manager with hub cluster](#tab/with-hub-cluster)

If you want to use Fleet Manager for Kubernetes object propagation or Managed Fleet Namespaces as well as cluster upgrades, then you need to create the Fleet Manager with a hub cluster.

Fleet Manager hub clusters support both public and private modes for network access. For more information, see [Choose an Azure Kubernetes Fleet Manager option](./concepts-choosing-fleet.md#network-access-modes-for-hub-cluster).

1. Create a directory you can use to test the sample Terraform code and make it your current directory.

1. Create a file named `providers.tf` and insert the following code:

    ```terraform
    terraform {
     required_providers {
        azapi = {
          source  = "azure/azapi"
          version = "~> 2.0"
        }
        azurerm = {
          source  = "hashicorp/azurerm"
          version = "~> 4.0"
        }
        random = {
          source  = "hashicorp/random"
          version = "~> 3.1"
        }
      }
    }
    provider "azurerm" {
      features {}
    }
    provider "azapi" {
    }
```

1. Create a file named `main.tf` and insert the following code:

    ```terraform
    # Generate random suffix for unique resource names
    resource "random_string" "suffix" {
      length  = 4
      special = false
      upper   = false
    }
    
    # Local values for resource naming
    locals {
      resource_group_name = coalesce(var.resource_group_name, "rg-fleet-example-${random_string.suffix.result}")
      fleet_name = coalesce(var.fleet_name, "fleet-example-${random_string.suffix.result}")
    }
    
    # Resource Group
    resource "azurerm_resource_group" "fleet_rg" {
      name     = local.resource_group_name
      location = var.location
    }
    ```

#### Public hub cluster

1. Create a file named `fleet.tf` and insert the following code:

    ```terraform
    resource "azapi_resource" "fleet-public" {
      type      = "Microsoft.ContainerService/fleets@2025-03-01"
      name      = "${local.fleet_name}-pub"
      location  = azurerm_resource_group.fleet_rg.location
      parent_id = azurerm_resource_group.fleet_rg.id
    
      body = {
        properties = {
          hubProfile = {
            agentProfile = {
              vmSize = var.hub_cluster_vm_size
            }
            apiServerAccessProfile = {
              enablePrivateCluster = false
              enableVnetIntegration = false
            }
            dnsPrefix = "${local.fleet_name}-pub"
          }
        }
      }
    
      identity {
        type = "SystemAssigned"
      }
    
      depends_on = [
        azurerm_resource_group.fleet_rg
      ]
    }
    ```

#### Private hub cluster

[!INCLUDE [private-fleet-prerequisites.md](./includes/private-fleet/private-fleet-prerequisites.md)]

1. Fetch Fleet Manager's service principal object ID:

    ```azurecli-interactive
    az ad sp list \
        --display-name "Azure Kubernetes Service - Fleet RP" \
        --query "[].{id:id}" \
        --output tsv
    ```
    
    ```output
    xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    ```

1. Create a file named `identity.tf` and insert the following code, updating the placeholder `principal_id` to match the output from the earlier service principal query:

    ```terraform
    ##
    # REQUIRED: Assign Network Contributor Role to "Azure Kubernetes Service - Fleet RP" to enable hub cluster updates
    ##
    resource "azurerm_role_assignment" "fleet_identity_01_network_contributor" {
      scope                = azurerm_subnet.hub-cluster-subnet.id
      role_definition_name = "Network Contributor"
      principal_id         = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      principal_type       = "ServicePrincipal"
    
      depends_on = [azurerm_subnet.hub-cluster-subnet]
    }
    
    ##
    # REQUIRED: Create User Assigned Managed Identity for Fleet Manager
    ##
    resource "azurerm_user_assigned_identity" "fleet_user_assigned_identity" {
      location            = azurerm_resource_group.fleet_rg.location
      name                = "${local.fleet_name}-uai"
      resource_group_name = azurerm_resource_group.fleet_rg.name
    }
    
    # REQUIRED: Assign Managed Identity the Network Contributor Role scoped to Hub Cluster API Server Subnet
    resource "azurerm_role_assignment" "fleet_user_assign_id_api_subnet_network_contributor" {
      scope                = azurerm_subnet.fleet-hub-apiserver-subnet.id
      role_definition_name = "Network Contributor"
      principal_id         = azurerm_user_assigned_identity.fleet_user_assigned_identity.principal_id
      principal_type       = "ServicePrincipal"
    
      depends_on = [azurerm_subnet.fleet-hub-apiserver-subnet, azurerm_user_assigned_identity.fleet_user_assigned_identity]
    }
    
    # REQUIRED: Assign Managed Identity the Network Contributor Role scoped to Hub Cluster Subnet
    resource "azurerm_role_assignment" "fleet_user_assign_id_hub_subnet_network_contributor" {
      scope                = azurerm_subnet.hub-cluster-subnet.id
      role_definition_name = "Network Contributor"
      principal_id         = azurerm_user_assigned_identity.fleet_user_assigned_identity.principal_id
      principal_type       = "ServicePrincipal"
    
      depends_on = [azurerm_subnet.hub-cluster-subnet, azurerm_user_assigned_identity.fleet_user_assigned_identity]
    }
    ```

1. Create a file named `vnet.tf` and insert the following code. If you want to use an existing virtual network you can replace the contents of `vnet.tf` file with resource references only, ensuring you have the correct subnets and delegations in place.
    
    ```terraform
    resource "azurerm_virtual_network" "hub-vnet" {
      name                = "${local.fleet_name}-vnet"
      location            = azurerm_resource_group.fleet_rg.location
      resource_group_name = azurerm_resource_group.fleet_rg.name
      address_space       = ["10.224.0.0/12"]
    }
    
    resource "azurerm_subnet" "hub-cluster-subnet" {
      name                 = "fleet-hub-cluster-subnet"
      resource_group_name  = azurerm_resource_group.fleet_rg.name
      virtual_network_name = azurerm_virtual_network.hub-vnet.name
      address_prefixes     = ["10.224.0.0/15"]
      private_endpoint_network_policies = "Disabled"
      private_link_service_network_policies_enabled = true
    }
    
    resource "azurerm_subnet" "fleet-hub-apiserver-subnet" {
      name                 = "fleet-hub-apiserver-subnet"
      resource_group_name  = azurerm_resource_group.fleet_rg.name
      virtual_network_name = azurerm_virtual_network.hub-vnet.name
      address_prefixes     = ["10.226.0.0/15"]
      delegation {
        name = "aksApiServerSubnetDelegation"
        service_delegation {
          name    = "Microsoft.ContainerService/managedClusters"
        }
      }
    }
    ```

1. Create a file named `fleet.tf` and insert the following code:

    ```terraform
    locals {
      fleet_name = coalesce(var.fleet_name, "fleet-example-${random_string.suffix.result}")
    }
    
    # Fleet Resource
    resource "azapi_resource" "fleet" {
      type      = "Microsoft.ContainerService/fleets@2025-03-01"
      name      = local.fleet_name
      location  = azurerm_resource_group.fleet_rg.location
      parent_id = azurerm_resource_group.fleet_rg.id
    
      body = {
        properties = {
          hubProfile = {
            agentProfile = {
              subnetId = azurerm_subnet.hub-cluster-subnet.id
              vmSize = var.hub_cluster_vm_size
            }
            apiServerAccessProfile = {
              enablePrivateCluster = true
              enableVnetIntegration = true
              subnetId = azurerm_subnet.fleet-hub-apiserver-subnet.id
            }
            dnsPrefix = local.fleet_name
          }
        }
      }
    
      identity {
        type = "UserAssigned"
        identity_ids = [azurerm_user_assigned_identity.fleet_user_assigned_identity.id]
      }
    
      depends_on = [
        azurerm_resource_group.fleet_rg,
        azurerm_role_assignment.fleet_identity_01_network_contributor, 
        azurerm_user_assigned_identity.fleet_user_assigned_identity, 
        azurerm_role_assignment.fleet_user_assign_id_api_subnet_network_contributor,
        azurerm_role_assignment.fleet_user_assign_id_hub_subnet_network_contributor
      ]
    }
    ```

---

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

## Next steps

* [Access Fleet Manager hub cluster Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md).
* [Deploy cluster-scoped resources across multiple clusters](./quickstart-resource-propagation.md).
* [Deploy namespace-scoped resources across multiple clusters](./quickstart-namespace-scoped-resource-propagation.md).
* [Create and configure Managed Fleet Namespaces](./howto-managed-namespaces.md).
* [How-to: Upgrade multiple clusters using Azure Kubernetes Fleet Manager update runs](./update-orchestration.md).