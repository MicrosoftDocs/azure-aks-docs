---
title: Use a Pre-Created Kubelet Managed Identity in Azure Kubernetes Service (AKS)
description: This article explains how to enable a pre-created kubelet managed identity on a new or existing AKS cluster, get the properties of the kubelet managed identity, and add a role assignment for the kubelet managed identity.
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
# Customer intent: "As a DevOps engineer, I want to enable a pre-created kubelet managed identity on my AKS cluster so that I can securely access Azure resources without managing credentials."
---

# Use a pre-created kubelet managed identity in Azure Kubernetes Service (AKS)

This article explains how to enable a pre-created kubelet managed identity on a new or existing AKS cluster, get the properties of the kubelet managed identity, and add a role assignment for the kubelet managed identity.

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

- Azure CLI version 2.26.0 or later installed. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

:::zone pivot="terraform"

- Terraform installed locally. For installation instructions, see [Install Terraform](https://developer.hashicorp.com/terraform/install).

:::zone-end

## Limitations

- Once you create a cluster with a managed identity, you can't switch back to using a service principal.
- Moving or migrating a managed identity-enabled cluster to a different tenant isn't supported.
- If the cluster has Microsoft Entra pod-managed identity (`aad-pod-identity`) enabled, Node-Managed Identity (NMI) pods modify the iptables of the nodes to intercept calls to the Azure Instance Metadata (IMDS) endpoint. This configuration means any request made to the IMDS endpoint is intercepted by NMI, even if a particular pod doesn't use `aad-pod-identity`.
  - You can configure the AzurePodIdentityException custom resource definition (CRD) to specify that requests to the IMDS endpoint that originate from a pod matching labels defined in the CRD should be proxied without any processing in NMI. Exclude the system pods with the `kubernetes.azure.com/managedby: aks` label in _kube-system_ namespace in `aad-pod-identity` by configuring the AzurePodIdentityException CRD. For more information, see [Use Microsoft Entra pod-managed identities in Azure Kubernetes Service (AKS)](use-azure-ad-pod-identity.md).
  - To configure an exception, install the [mic-exception YAML](https://github.com/Azure/aad-pod-identity/blob/master/deploy/infra/mic-exception.yaml).
- A pre-created kubelet managed identity must be a user-assigned managed identity.
- The China East and China North regions in Microsoft Azure operated by 21Vianet aren't supported.

[!INCLUDE [21vianet-retirement](includes/21vianet-retirement.md)]

## Update cluster considerations

When you update a cluster, consider the following information:

- An update only works if there's a VHD update to consume. If you're running the latest VHD, you need to wait until the next VHD is available in order to perform the update.
- The Azure CLI ensures your add-on's permission is correctly set after migrating. If you're not using the Azure CLI to perform the migrating operation, you need to handle the add-on identity's permission by yourself. For an example using an Azure Resource Manager (ARM) template, see [Assign Azure roles using ARM templates](/azure/role-based-access-control/role-assignments-template).
- If your cluster was using `--attach-acr` to pull from images from Azure Container Registry (ACR), you need to run the `az aks update --resource-group <resource-group-name> --name <aks-cluster-name> --attach-acr <acr-resource-id>` command after updating your cluster to let the newly created kubelet used for managed identity get the permission to pull from ACR. Otherwise, you won't be able to pull from ACR after the update.

:::zone pivot="azure-cli"

## Create a kubelet managed identity

If you don't have a kubelet managed identity, create one using the [`az identity create`][az-identity-create] command.

```azurecli-interactive
az identity create \
    --name <kubelet-identity-name> \
    --resource-group <resource-group-name>
```

Your output should resemble the following example output:

```output
{
    "clientId": "<client-id>",
    "clientSecretUrl": "<clientSecretUrl>",
    "id": "/subscriptions/<subscription-id>/resourcegroups/<resource-group-name>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<kubelet-identity-name>",
    "location": "<location>",
    "name": "<kubelet-identity-name>",
    "principalId": "<principal-id>",
    "resourceGroup": "<resource-group-name>",
    "tags": {},
    "tenantId": "<tenant-id>",
    "type": "Microsoft.ManagedIdentity/userAssignedIdentities"
}
```

## Assign an RBAC role to the kubelet managed identity

Assign the `acrpull` role on the kubelet managed identity using the [`az role assignment create`][az-role-assignment-create] command.

```azurecli-interactive
az role assignment create \
    --assignee <kubelet-client-id> \
    --role "acrpull" \
    --scope "<acr-registry-id>"
```

## Enable a kubelet managed identity on a new AKS cluster

Create an AKS cluster with your existing identities using the [`az aks create`][az-aks-create] command.

```azurecli-interactive
az aks create \
    --resource-group <resource-group-name> \
    --name <aks-cluster-name> \
    --network-plugin azure \
    --vnet-subnet-id <vnet-subnet-id> \
    --dns-service-ip 10.2.0.10 \
    --service-cidr 10.2.0.0/24 \
    --assign-identity <identity-resource-id> \
    --assign-kubelet-identity <kubelet-identity-resource-id> \
    --generate-ssh-keys
```

A successful AKS cluster creation using a kubelet managed identity should result in output similar to the following:

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
    "identityProfile": {
    "kubeletidentity": {
        "clientId": "<client-id>",
        "objectId": "<object-id>",
        "resourceId": "/subscriptions/<subscription-id>/resourcegroups/<resource-group-name>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<kubelet-identity-name>"
    }
    },
...
```

## Update an existing cluster to use a kubelet managed identity

To update an existing cluster to use the kubelet managed identity, first get the current control plane managed identity for your AKS cluster.

> [!WARNING]
> Updating the kubelet managed identity upgrades your AKS cluster's node pools, make sure you have the right availability configurations, such as Pod Disruption Budgets, configured before executing this to avoid workload disruption or execute this during a maintenance window.

1. Confirm your AKS cluster is using the user-assigned managed identity using the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
    az aks show \
        --resource-group <resource-group-name> \
        --name <aks-cluster-name> \
        --query "servicePrincipalProfile"
    ```

    If your cluster is using a managed identity, the output shows `clientId` with a value of **msi**. A cluster using a service principal shows an object ID. For example:

    ```output
    {
      "clientId": "msi"
    }
    ```

1. After confirming your cluster is using a managed identity, find the managed identity's resource ID using the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
    az aks show --resource-group <resource-group-name> \
        --name <aks-cluster-name> \
        --query "identity"
    ```

    For a user-assigned managed identity, your output should look similar to the following example output:

    ```output
    {
      "principalId": null,
      "tenantId": null,
      "type": "UserAssigned",
      "userAssignedIdentities": <identity-resource-id>
          "clientId": "<client-id>",
          "principalId": "<principal-id>"
    },
    ```

1. Update your cluster with your existing identities using the [`az aks update`][az-aks-update] command. Provide the resource ID of the user-assigned managed identity for the control plane for the `assign-identity` parameter. Provide the resource ID of the kubelet managed identity for the `assign-kubelet-identity` parameter.

    ```azurecli-interactive
    az aks update \
        --resource-group <resource-group-name> \
        --name <aks-cluster-name> \
        --enable-managed-identity \
        --assign-identity <identity-resource-id> \
        --assign-kubelet-identity <kubelet-identity-resource-id>
    ```

    Your output for a successful cluster update using your own kubelet managed identity should resemble the following example output:

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
      "identityProfile": {
        "kubeletidentity": {
          "clientId": "<client-id>",
          "objectId": "<object-id>",
          "resourceId": "/subscriptions/<subscription-id>/resourcegroups/<resource-group-name>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<kubelet-identity-name>"
        }
      },
    ...
    ```

## Get the properties of the kubelet managed identity

Get the properties of the kubelet managed identity using the [`az aks show`][az-aks-show] command and query on the `identityProfile.kubeletidentity` property.

```azurecli-interactive
az aks show \
    --name <aks-cluster-name> \
    --resource-group <resource-group-name> \
    --query "identityProfile.kubeletidentity"
```

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

## Create an AKS cluster with a pre-created kubelet managed identity using Terraform

Add the following code to `main.tf` to create a kubelet managed identity and an AKS cluster that uses the kubelet managed identity:

```Terraform
resource "azurerm_user_assigned_identity" "kubelet" {
 name                = "aks-kubelet-identity"
 resource_group_name = azurerm_resource_group.example.name
 location            = azurerm_resource_group.example.location
}
resource "azurerm_kubernetes_cluster" "kubelet_identity" {
 name                = "aks-kubelet"
 location            = azurerm_resource_group.example.location
 resource_group_name = azurerm_resource_group.example.name
 dns_prefix          = "akskubelet"
 identity {
   type         = "UserAssigned"
   identity_ids = [azurerm_user_assigned_identity.kubelet.id]
 }
 kubelet_identity {
   client_id                 = azurerm_user_assigned_identity.kubelet.client_id
   object_id                 = azurerm_user_assigned_identity.kubelet.principal_id
   user_assigned_identity_id = azurerm_user_assigned_identity.kubelet.id
 }
 default_node_pool {
   name       = "system"
   node_count = 1
   vm_size    = "Standard_DS2_v2"
 }
}
```

## Add a role assignment for the kubelet managed identity using Terraform

Add the following code to `main.tf` to create a role assignment for the kubelet managed identity. This example assigns the **AcrPull** role to the kubelet managed identity to grant it permissions to pull images from Azure Container Registry (ACR). The role assignment is scoped to the resource group.

> [!NOTE]
> In production scenarios, assign the **AcrPull** role at the Azure Container Registry scope instead of the resource group.

```Terraform
resource "azurerm_role_assignment" "kubelet_acr_pull" {
 scope                = azurerm_resource_group.example.id
 role_definition_name = "AcrPull"
 principal_id         = azurerm_user_assigned_identity.kubelet.principal_id
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
- [Use a user-assigned managed identity in AKS](./user-assigned-managed-identity.md)
- [Use kubelogin to authenticate users in Azure Kubernetes Service (AKS)](./kubelogin-authentication.md)

<!-- LINKS - internal -->
[install-azure-cli]: /cli/azure/install-azure-cli
[az-identity-create]: /cli/azure/identity#az_identity_create
[az-account-set]: /cli/azure/account#az-account-set
[az-group-create]: /cli/azure/group#az_group_create
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-update]: /cli/azure/aks#az_aks_update
[az-role-assignment-create]: /cli/azure/role/assignment#az_role_assignment_create
[az-aks-show]: /cli/azure/aks#az_aks_show
