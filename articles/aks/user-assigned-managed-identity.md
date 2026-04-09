---
title: Use a User-Assigned Managed Identity in Azure Kubernetes Service (AKS)
description: This article explains how to enable a user-assigned managed identity on a new or existing AKS cluster, get the principal ID of the user-assigned managed identity, and add a role assignment for the user-assigned managed identity.
author: schaffererin
ms.author: schaffererin
ms.topic: how-to
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.custom:
  - devx-track-azurecli
  - ignite-2023
ms.date: 06/07/2024
zone_pivot_groups: azure-cli-or-terraform
# Customer intent: "As a DevOps engineer, I want to enable a user-assigned managed identity on my AKS cluster so that I can securely access Azure resources without managing credentials."
---

# Use a user-assigned managed identity in Azure Kubernetes Service (AKS)

This article explains how to enable a user-assigned managed identity on a new or existing AKS cluster, get the principal ID of the user-assigned managed identity, and add a role assignment for the user-assigned managed identity.

## Prerequisites

- Read the [Overview of managed identities in Azure Kubernetes Service (AKS)](managed-identity-overview.md) to understand the different types of managed identities available in AKS and how you can use them to securely access Azure resources.
- Set your subscription as the current active subscription using the [`az account set`][az-account-set] command.

    ```azurecli-interactive
    az account set --subscription <subscription-id>
    ```

:::zone pivot="azure-cli"

- An existing Azure resource group. If you don't have one, you can create one using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create \
        --name <resource-group-name> \
        --location <location>
    ```

:::zone-end

- Azure CLI version 2.23.0 or later installed. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
- To update an existing cluster to use a [user-assigned managed identity][update-user-assigned-managed-identity-on-an-existing-cluster], you need Azure CLI version 2.49.0 or later installed.

:::zone pivot="terraform"

- Terraform installed locally. For installation instructions, see [Install Terraform](https://developer.hashicorp.com/terraform/install).

:::zone-end

## Limitations

- Once you create a cluster with a managed identity, you can't switch back to using a service principal.
- Moving or migrating a managed identity-enabled cluster to a different tenant isn't supported.
- If the cluster has Microsoft Entra pod-managed identity (`aad-pod-identity`) enabled, Node-Managed Identity (NMI) pods modify the iptables of the nodes to intercept calls to the Azure Instance Metadata (IMDS) endpoint. This configuration means any request made to the IMDS endpoint is intercepted by NMI, even if a particular pod doesn't use `aad-pod-identity`.
  - You can configure the AzurePodIdentityException custom resource definition (CRD) to specify that requests to the IMDS endpoint that originate from a pod matching labels defined in the CRD should be proxied without any processing in NMI. Exclude the system pods with the `kubernetes.azure.com/managedby: aks` label in _kube-system_ namespace in `aad-pod-identity` by configuring the AzurePodIdentityException CRD. For more information, see [Use Microsoft Entra pod-managed identities in Azure Kubernetes Service (AKS)](use-azure-ad-pod-identity.md).
  - To configure an exception, install the [mic-exception YAML](https://github.com/Azure/aad-pod-identity/blob/master/deploy/infra/mic-exception.yaml).
- The USDOD Central, USDOD East, and USGov Iowa regions in Azure US Government cloud don't support creating a cluster with a user-assigned managed identity.

## Update cluster considerations

When you update a cluster, consider the following information:

- An update only works if there's a VHD update to consume. If you're running the latest VHD, you need to wait until the next VHD is available in order to perform the update.
- The Azure CLI ensures your add-on's permission is correctly set after migrating. If you're not using the Azure CLI to perform the migrating operation, you need to handle the add-on identity's permission by yourself. For an example using an Azure Resource Manager (ARM) template, see [Assign Azure roles using ARM templates](/azure/role-based-access-control/role-assignments-template).
- If your cluster was using `--attach-acr` to pull from images from Azure Container Registry (ACR), you need to run the `az aks update --resource-group <resource-group-name> --name <aks-cluster-name> --attach-acr <acr-resource-id>` command after updating your cluster to let the newly created kubelet used for managed identity get the permission to pull from ACR. Otherwise, you won't be able to pull from ACR after the update.

:::zone pivot="azure-cli"

## Create a user-assigned managed identity

If you don't yet have a user-assigned managed identity resource, create one using the [`az identity create`][az-identity-create] command.

```azurecli-interactive
az identity create \
    --name <identity-name> \
    --resource-group <resource-group-name>
```

Your output should resemble the following example output:
  
```output
{                                  
    "clientId": "<client-id>",
    "clientSecretUrl": "<clientSecretUrl>",
    "id": "/subscriptions/<subscription-id>/resourcegroups/<resource-group-name>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<identity-name>",
    "location": "<location>",
    "name": "<identity-name>",
    "principalId": "<principal-id>",
    "resourceGroup": "<resource-group-name>",
    "tags": {},
    "tenantId": "<tenant-id>",
    "type": "Microsoft.ManagedIdentity/userAssignedIdentities"
}
```

## Get the principal ID of the user-assigned managed identity

Get the principal ID of the user-assigned managed identity using the [`az identity show`][az-identity-show] command.

```azurecli-interactive
CLIENT_ID=$(az identity show \
    --name <identity-name> \
    --resource-group <resource-group-name> \
    --query principalId \
    --output tsv)
```

## Get the resource ID of the user-assigned managed identity

Get the resource ID of the user-assigned managed identity using the [`az identity show`][az-identity-show] command.

```azurecli-interactive
RESOURCE_ID=$(az identity show \
    --name <identity-name> \
    --resource-group <resource-group-name> \
    --query id \
    --output tsv)
```

## Enable a user-assigned managed identity on a new AKS cluster

Create an AKS cluster with a  user-assigned managed identity using the [`az aks create`][az-aks-create] command and the `--assign-identity` parameter set to the [resource ID of the user-assigned managed identity](#get-the-resource-id-of-the-user-assigned-managed-identity).

```azurecli-interactive
az aks create \
    --resource-group <resource-group-name> \
    --name <cluster-name> \
    --network-plugin azure \
    --vnet-subnet-id <vnet-subnet-id> \
    --dns-service-ip 10.2.0.10 \
    --service-cidr 10.2.0.0/24 \
    --assign-identity $RESOURCE_ID \
    --generate-ssh-keys
```

## Update an existing cluster to use a user-assigned managed identity

Update an existing cluster to use a user-assigned managed identity using the [`az aks update`][az-aks-update] command and the `--assign-identity` parameter set to the [resource ID of the user-assigned managed identity](#get-the-resource-id-of-the-user-assigned-managed-identity).

```azurecli-interactive
az aks update \
    --resource-group <resource-group-name> \
    --name <cluster-name> \
    --enable-managed-identity \
    --assign-identity $RESOURCE_ID
```

The output for a successful cluster update to use a user-assigned managed identity should resemble the following example output:

```output
...
    "identity": {
    "principalId": null,
    "tenantId": null,
    "type": "UserAssigned",
    "userAssignedIdentities": {
        "/subscriptions/<subscription-id>/resourcegroups/<resource-group-name>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<identity-name>": {
        "clientId": "<client-id>",
        "principalId": "<principal-id>"
        }
    }
    },
...
```

> [!NOTE]
> Migrating a managed identity for the control plane from system-assigned to user-assigned doesn't result in any downtime for control plane and agent pools. Control plane components continue to the old system-assigned identity for up to several hours until the next token refresh.

## Assign an Azure RBAC role to the user-assigned managed identity

Add a role assignment for the user-assigned managed identity using the [`az role assignment create`][az-role-assignment-create] command. The following example assigns the **Key Vault Secrets User** role to the user-assigned managed identity to grant it permissions to access secrets in a key vault. The role assignment is scoped to the key vault resource.

```azurecli-interactive
az role assignment create \
    --assignee <client-id> \
    --role "Key Vault Secrets User" \
    --scope "<key-vault-resource-id>"
```

> [!NOTE]
> It can take up to 60 minutes for the permissions granted to your cluster's managed identity to propagate.

:::zone-end

:::zone pivot="terraform"

## Create the Terraform configuration file

Terraform configuration files define the infrastructure that Terraform creates and manages.

1. Create a file named `main.tf` and add the following code to define the Terraform version and specify the Azure provider:

    ```Terraform
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

1. Add the following code to `main.tf` to create an Azure resource group. Feel free to change the name and location of the resource group as needed.

    ```Terraform
    resource "azurerm_resource_group" "example" {
     name     = "aks-rg"
     location = "East US"
    }
    ```

## Create an AKS cluster with a user-assigned managed identity using Terraform

Add the following code to `main.tf` to create a user-assigned managed identity and an AKS cluster that uses the identity:

```Terraform
resource "azurerm_user_assigned_identity" "uai" {
 name                = "aks-user-identity"
 resource_group_name = azurerm_resource_group.example.name
 location            = azurerm_resource_group.example.location
}
resource "azurerm_kubernetes_cluster" "user_assigned" {
 name                = "aks-user"
 location            = azurerm_resource_group.example.location
 resource_group_name = azurerm_resource_group.example.name
 dns_prefix          = "aksuser"
 identity {
   type         = "UserAssigned"
   identity_ids = [azurerm_user_assigned_identity.uai.id]
 }
 default_node_pool {
   name       = "system"
   node_count = 1
   vm_size    = "Standard_DS2_v2"
 }
}
```

## Add a role assignment for a user-assigned managed identity using Terraform

Add the following code to `main.tf` to create a role assignment for the user-assigned managed identity. This example assigns the **Key Vault Secrets User** role to the user-assigned managed identity to grant it permissions to access secrets in a key vault. The role assignment is scoped to the key vault resource.

```Terraform
resource "azurerm_role_assignment" "user_assigned_key_vault_secrets_user" {
 scope                = azurerm_resource_group.example.id
 role_definition_name = "Key Vault Secrets User"
 principal_id         = azurerm_user_assigned_identity.uai.principal_id
}
```

## Initialize Terraform

Initialize Terraform in the directory containing your `main.tf` file using the [`terraform init`](https://www.terraform.io/docs/commands/init.html) command. This command downloads the Azure provider required to manage Azure resources with Terraform.

```console
terraform init
```

## Create a Terraform execution plan

Create a Terraform execution plan using the [`terraform plan`](https://www.terraform.io/docs/commands/plan.html) command. This command shows you the resources that Terraform will create or modify in your Azure subscription.

```console
terraform plan
```

## Apply the Terraform configuration

After reviewing and confirming the execution plan, apply the Terraform configuration using the [`terraform apply`](https://www.terraform.io/docs/commands/apply.html) command. This command creates or modifies the resources defined in your `main.tf` file in your Azure subscription.

```console
terraform apply
```

## Verify the Terraform deployment

After applying the Terraform configuration, you can verify the deployment using the [`az aks show`][az-aks-show] command with the `--query` parameter to filter the output and display the identity information. For example:

```azurecli-interactive
az aks show \
 --name <cluster-name> \
 --resource-group <resource-group> \
 --query identity.type \
 --output tsv
```

:::zone-end

## Related content

To learn more about managed identities in AKS, see the following articles:

- [Overview of managed identities in Azure Kubernetes Service (AKS)](managed-identity-overview.md)
- [Use a system-assigned managed identity in AKS](./system-assigned-managed-identity.md)
- [Use a pre-created kubelet managed identity in AKS](./pre-created-kubelet-managed-identity.md)
- [Use kubelogin to authenticate users in Azure Kubernetes Service (AKS)](./kubelogin-authentication.md)

<!-- LINKS - internal -->
[install-azure-cli]: /cli/azure/install-azure-cli
[az-identity-create]: /cli/azure/identity#az_identity_create
[az-identity-show]: /cli/azure/identity#az_identity_show
[update-user-assigned-managed-identity-on-an-existing-cluster]: use-managed-identity.md#update-an-existing-cluster-to-use-a-user-assigned-managed-identity
[az-account-set]: /cli/azure/account#az-account-set
[az-group-create]: /cli/azure/group#az_group_create
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-update]: /cli/azure/aks#az_aks_update
[az-role-assignment-create]: /cli/azure/role/assignment#az_role_assignment_create
