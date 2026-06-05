---
title: Use the Azure Key Vault Provider for Secrets Store CSI Driver for Azure Kubernetes Service (AKS) Secrets
description: Learn how to use the Azure Key Vault provider for Secrets Store CSI Driver to integrate secrets stores with Azure Kubernetes Service (AKS).
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.date: 05/05/2026
ms.custom: template-how-to, devx-track-azurecli, biannual
zone_pivot_groups: cli-terraform-csi-driver
# Customer intent: As a Kubernetes administrator, I want to integrate Azure Key Vault with my AKS cluster using the Secrets Store CSI Driver, so that I can securely manage and access secrets, keys, and certificates within my applications.
---

# Use the Azure Key Vault provider for Secrets Store CSI Driver in an Azure Kubernetes Service (AKS) cluster

The Azure Key Vault provider for Secrets Store Container Storage Interface (CSI) Driver allows for the integration of an Azure Key Vault as a secret store with an Azure Kubernetes Service (AKS) cluster via a [CSI volume][kube-csi].

## Features

- Mounts secrets, keys, and certificates to a pod using a CSI volume.
- Supports CSI inline volumes.
- Supports mounting multiple secrets store objects as a single volume.
- Supports pod portability with the `SecretProviderClass` Custom Resource Definition (CRD).
- Supports Windows containers.
- Syncs with Kubernetes secrets.
- Supports autorotation of mounted contents and synced Kubernetes secrets.

## Limitations

- A container using a `ConfigMap` or `Secret` as a `subPath` volume mount doesn't receive automated updates when the secret is rotated, which is a Kubernetes limitation. To have the changes take effect, the application needs to reload the changed file by either watching for changes in the file system or by restarting the pod. For more information, see [Secrets Store CSI Driver known limitations](https://secrets-store-csi-driver.sigs.k8s.io/known-limitations.html#secrets-not-rotated-when-using-subpath-volume-mount).
- The add-on creates a managed identity named `azurekeyvaultsecretsprovider-xxxxx` in the node resource group (`MC_`) and assigns it to the Virtual Machine Scale Set automatically. You can use this managed identity or your own managed identity to access the key vault. It's not supported to prevent creation of the identity.

## Prerequisites

:::zone pivot="azure-cli-create, azure-cli-update"

- If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn) before you begin.
- Check that your version of the Azure CLI is 2.30.0 or later. If it's an earlier version, [install the latest version](/cli/azure/install-azure-cli).

:::zone-end


:::zone pivot="terraform-create, terraform-update"

- If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn) before you begin.
- Terraform that's version 1.6 or later.
- Azure CLI installed and logged in. [install the latest version](/cli/azure/install-azure-cli).
- Permissions to create AKS and Key Vault resources.
- Set your Azure subscription in the Azure CLI with the following command. Replace `<subscriptionId>` with your subscription ID.

  ```azurecli-interactive
  az account set --subscription <subscriptionId>
  ```

:::zone-end

### Network

- If using network isolated clusters, the recommendation is to [set up private endpoint to access Azure Key Vault][private-endpoint-keyvault].
- If the cluster has outbound type `userDefinedRouting` and uses a firewall device that can control outbound traffic based on domain names, such as Azure Firewall, ensure the [required outbound network rules and FQDNs are allowed][fqdns-for-keyvault].
- If you're restricting Ingress to the cluster, make sure ports **9808** and **8095** are open.

### Roles

- This article uses the [Key Vault Secrets Officer][key-vault-secrets-officer] role to give your account permission to create a secret in the key vault.
- In the article to [provide Azure Key Vault access](csi-secrets-store-identity-access.md), the identity used with the `SecretProviderClass` needs [Key Vault Certificate User][key-vault-certificate-user] to access `key` or `certificate` [object types][keyvault-object-types] and [Key Vault Secrets User][key-vault-secrets-user] to access `secret` [object type][keyvault-object-types].


:::zone pivot="azure-cli-create"

## Create an AKS cluster

Create an AKS cluster with Azure Key Vault provider for Secrets Store CSI Driver support.

1. Create variables that are used in the commands to create an AKS cluster and Key Vault.

    ```azurecli-interactive
    export RANDOM_STRING=$(printf '%05d%05d' "$RANDOM" "$RANDOM")
    export KEYVAULT_NAME=myKeyVault${RANDOM_STRING}
    export RESOURCE_GROUP=myResourceGroup
    export CLUSTER_NAME=myAKSCluster
    export LOCATION=eastus2
    ```

   Azure Key Vault names must be globally unique, alphanumeric including hyphens, and 3-24 characters. The key vault name concatenates the `KEYVAULT_NAME` variable's `myKeyVault` value with the `RANDOM_STRING` variable's 10 character string.

1. Create an Azure resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --name $RESOURCE_GROUP --location $LOCATION
    ```

1. Create an AKS cluster with Azure Key Vault provider for Secrets Store CSI Driver capability using the [`az aks create`][az-aks-create] command with the `--enable-addons azure-keyvault-secrets-provider` parameter.

   The `--enable-addons` parameter creates a user-assigned managed identity named `azurekeyvaultsecretsprovider-xxxx` that you can use to authenticate to your key vault. The managed identity is stored in the node resource group (`MC_`) and is automatically assigned to the Virtual Machine Scale Set. You can use this managed identity or your own managed identity to access the key vault. It's not supported to prevent creation of the identity.

    ```azurecli-interactive
    az aks create \
      --name $CLUSTER_NAME \
      --resource-group $RESOURCE_GROUP \
      --enable-addons azure-keyvault-secrets-provider \
      --generate-ssh-keys
    ```

    > [!TIP]
    > If you want to use Microsoft Entra Workload ID, the `az aks create` command must include the `--enable-oidc-issuer` and `--enable-workload-identity` parameters.

:::zone-end


:::zone pivot="terraform-create"

## Create an AKS cluster

Create a _main.tf_ file with the following configuration to create an AKS cluster with Azure Key Vault provider for Secrets Store CSI Driver support.

1. Create the Terraform configuration.

    ```terraform
    terraform {
     required_version = ">= 1.6.0"
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
    data "azurerm_client_config" "current" {}
    resource "azurerm_resource_group" "rg" {
     name     = "aks-rg"
     location = "East US"
    }
    ```

1. Create the AKS cluster.

    ```terraform
    resource "azurerm_kubernetes_cluster" "aks" {
     name                = "aks-cluster"
     location            = azurerm_resource_group.rg.location
     resource_group_name = azurerm_resource_group.rg.name
     dns_prefix          = "akscsi"
     default_node_pool {
       name       = "system"
       node_count = 1
       vm_size    = "Standard_DS2_v2"
     }
     identity {
       type = "SystemAssigned"
     }
     key_vault_secrets_provider {
       secret_rotation_enabled = false
     }
    }
    ```

1. Deploy the configuration. Form a Bash session, run the following commands to deploy the resources:

    ```bash
    terraform init
    terraform validate
    terraform plan
    terraform apply
    ```

:::zone-end

:::zone pivot="azure-cli-update"

## Update an existing AKS cluster

Update an existing AKS cluster with Azure Key Vault provider for Secrets Store CSI Driver support.

1. Create variables that are used in the commands. Replace the values as needed to update your existing AKS cluster or Key Vault.

    For example, If you're using an existing key vault, replace the `KEYVAULT_NAME` variable's value without using the `RANDOM_STRING` variable.

    If you don't have a key vault, Azure Key Vault names must be globally unique, alphanumeric including hyphens, and 3-24 characters. The key vault name concatenates the `KEYVAULT_NAME` variable's `myKeyVault` value with the `RANDOM_STRING` variable's 10 character string. You can create the key vault later in this article.

    ```azurecli-interactive
    export RANDOM_STRING=$(printf '%05d%05d' "$RANDOM" "$RANDOM")
    export KEYVAULT_NAME=myKeyVault${RANDOM_STRING}
    export RESOURCE_GROUP=myResourceGroup
    export CLUSTER_NAME=myAKSCluster
    export LOCATION=eastus2
    ```

1. Update an existing AKS cluster with Azure Key Vault provider for Secrets Store CSI Driver capability using the [`az aks enable-addons`][az-aks-enable-addons] command and enable the `azure-keyvault-secrets-provider` add-on. The add-on creates a user-assigned managed identity you can use to authenticate to your key vault.

    ```azurecli-interactive
    az aks enable-addons \
      --addons azure-keyvault-secrets-provider \
      --name $CLUSTER_NAME \
      --resource-group $RESOURCE_GROUP
    ```

    After you enable the Azure Key Vault secret provider, AKS creates a managed identity named  `azurekeyvaultsecretsprovider-xxxx` that you can use to authenticate to your key vault. The managed identity is stored in the node resource group (`MC_`) and is automatically assigned to the Virtual Machine Scale Set. You can use this managed identity or your own managed identity to access the key vault. It's not supported to prevent creation of the identity.

:::zone-end


:::zone pivot="terraform-update"

## Update an existing AKS cluster

Create a _main.tf_ file with the following configuration to update an existing AKS cluster with Azure Key Vault provider for Secrets Store CSI Driver support.

1. Update and existing AKS cluster.

    ```terraform
    resource "azurerm_kubernetes_cluster" "aks" {
     name                = "<existing-cluster>"
     resource_group_name = "<resource-group>"
     key_vault_secrets_provider {
       secret_rotation_enabled = false
     }
    }
    ```

1. Deploy the configuration. Form a Bash session, run the following commands to deploy the configuration:

    ```bash
    Run the following commands to apply the updates:

    terraform init
    terraform validate
    terraform plan
    terraform apply
    ```

:::zone-end


:::zone pivot="azure-cli-create, azure-cli-update, terraform-create, terraform-update"

### Verify the managed identity and key vault provider installation

If you used Terraform to create a new cluster or update an existing cluster, you need to replace the variables like `$CLUSTER_NAME` in the following commands with the values you used in your Terraform configuration.

#### Verify the managed identity

Use the following steps to verify the managed identity was created and assigned to the cluster's Virtual Machine Scale Set.

1. Verify the managed identity was created and assigned to the cluster using the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
    az aks show \
      --name $CLUSTER_NAME \
      --resource-group $RESOURCE_GROUP \
      --query addonProfiles
    ```

    ```output
    {
      "azureKeyvaultSecretsProvider": {
        "config": {
          "enableSecretRotation": "false",
          "rotationPollInterval": "2m"
        },
        "enabled": true,
        "identity": {
          "clientId": "00001111-aaaa-2222-bbbb-3333cccc4444",
          "objectId": "aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb",
          "resourceId": "/subscriptions/<subscriptionID>/resourcegroups/MC_myResourceGroup_myAKSCluster_eastus2/providers/Microsoft.ManagedIdentity/userAssignedIdentities/azurekeyvaultsecretsprovider-myakscluster"
        }
      }
    }
    ```

    The `resourceId` property shows the resource group and the identity's name `azurekeyvaultsecretsprovider-myakscluster`.

1. Verify the managed identity is assigned to node resource group's Virtual Machine Scale Set.

    ```azurecli-interactive
    NODE_RG=$(az aks show \
      --name $CLUSTER_NAME \
      --resource-group $RESOURCE_GROUP \
      --query nodeResourceGroup --output tsv)

    VMSS_NAME=$(az vmss list \
      --resource-group $NODE_RG \
      --query [].name --output tsv)

    az vmss show --name $VMSS_NAME --resource-group $NODE_RG --query '[id, identity]'
    ```

    The output shows the Virtual Machines Scale sets `Microsoft.Compute/virtualMachineScaleSets` resource ID and the `userAssignedIdentities` property with a resource ID for `azurekeyvaultsecretsprovider-myakscluster` that confirms the identity is assigned to the Virtual Machine Scale Set.


#### Verify the Azure Key Vault provider for Secrets Store CSI Driver installation

1. Get the AKS cluster credentials using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials \
      --name $CLUSTER_NAME \
      --resource-group $RESOURCE_GROUP
    ```

1. Verify the installation is finished using the `kubectl get pods` command, which lists all pods with the `secrets-store-csi-driver` and `secrets-store-provider-azure` labels in the `kube-system` namespace.

    ```bash
    kubectl get pods -n kube-system -l 'app in (secrets-store-csi-driver,secrets-store-provider-azure)' -o wide
    ```

    The `-o wide` flag includes the node that each pod is running on in the output.

    Your output should look similar to the following example output:

    ```output
    NAME                                     READY   STATUS    RESTARTS   AGE    NODE
    aks-secrets-store-csi-driver-4vpkj       3/3     Running   2          4m25s  aks-nodepool1-12345678-vmss000002
    aks-secrets-store-csi-driver-ctjq6       3/3     Running   2          4m21s  aks-nodepool1-12345678-vmss000001
    aks-secrets-store-csi-driver-tlvlq       3/3     Running   2          4m24s  aks-nodepool1-12345678-vmss000000
    aks-secrets-store-provider-azure-5p4nb   1/1     Running   0          4m21s  aks-nodepool1-12345678-vmss000000
    aks-secrets-store-provider-azure-6pqmv   1/1     Running   0          4m24s  aks-nodepool1-12345678-vmss000001
    aks-secrets-store-provider-azure-f5qlm   1/1     Running   0          4m25s  aks-nodepool1-12345678-vmss000002
    ```

:::zone-end

:::zone pivot="azure-cli-create"

## Create new key vault

Run the [`az keyvault create`][az-keyvault-create] command to create a new key vault with Azure RBAC enabled.

```azurecli-interactive
az keyvault create \
  --name $KEYVAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --enable-rbac-authorization
```

Azure RBAC is enabled by default when you create a new key vault even if you don't include the `--enable-rbac-authorization` parameter.

For more information about key vault permission models and Azure RBAC, see [Provide access to Key Vault keys, certificates, and secrets with an Azure role-based access control](/azure/key-vault/general/rbac-guide).

:::zone-end


:::zone pivot="azure-cli-update"

## Update existing key vault

Run the [`az keyvault update`][az-keyvault-update] command to update an existing key vault with Azure role-based access control (Azure RBAC). The `--enable-rbac-authorization` parameter is needed to enable Azure RBAC when you update an existing key vault that has Azure RBAC disabled.

```azurecli-interactive
az keyvault update \
  --name $KEYVAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --enable-rbac-authorization
```

For more information about key vault permission models and Azure RBAC, see [Provide access to Key Vault keys, certificates, and secrets with an Azure role-based access control](/azure/key-vault/general/rbac-guide)

:::zone-end


:::zone pivot="azure-cli-create, azure-cli-update"

### Add role assignment and secret to key vault

1. Run the [`az keyvault show`][az-keyvault-show] command to verify the key vault has Azure RBAC enabled.

    ```azurecli-interactive
    az keyvault show \
      --name $KEYVAULT_NAME \
      --resource-group $RESOURCE_GROUP \
      --query properties.enableRbacAuthorization
    ```

    The output should be `true`.

1. Add a role assignment for your user account to the key vault scope using the [`az role assignment create`][az-role-assignment-create] command so that you can add a key vault secret in the next step.

    The [Key Vault Secrets Officer][key-vault-secrets-officer] role with unique identifier `b86a8fe4-44ce-4948-aee5-eccb2c155cd7` is added and you can use the name or unique identifier. Using the role's unique identifier is a best practice to prevent issues if the roles name changes.

    ```azurecli-interactive
    KEYVAULT_ID=$(az keyvault show \
      --name $KEYVAULT_NAME \
      --resource-group $RESOURCE_GROUP \
      --query id -o tsv)

    MYID=$(az ad signed-in-user show --query id --output tsv)

    az role assignment create \
      --assignee-object-id $MYID \
      --role "b86a8fe4-44ce-4948-aee5-eccb2c155cd7" \
      --scope $KEYVAULT_ID \
      --assignee-principal-type User
    ```

    It can take several minutes for the role assignment to take effect. You can verify the role assignment was created with the following command:

    ```azurecli-interactive
    az role assignment list \
      --assignee-object-id $MYID \
      --scope $KEYVAULT_ID \
      --query '[].{Role:roleDefinitionName, Scope:scope}' \
      --output table
    ```

1. Create a plain-text secret named `ExampleSecret` in the key vault using the [`az keyvault secret set`][az-keyvault-secret-set] command.


    Your key vault can store keys, secrets, and certificates. The `value` parameter uses the `RANDOM_STRING` variable to create a unique value for the secret.

    ```azurecli-interactive
    az keyvault secret set \
      --vault-name $KEYVAULT_NAME \
      --name ExampleSecret \
      --value MyAKSExampleSecret${RANDOM_STRING}
    ```

1. Verify the secret was added to the key vault using the [`az keyvault secret show`][az-keyvault-secret-show] command.

    ```azurecli-interactive
    az keyvault secret show --vault-name $KEYVAULT_NAME --name ExampleSecret
    ```

:::zone-end

:::zone pivot="terraform-create"

## Create new key vault

Update your _main.tf_ file to create a new key vault with Azure role-based access control (Azure RBAC) enabled.

1. Create a new key vault with Azure RBAC enabled.

    ```terraform
    data "azurerm_client_config" "current" {}
    resource "random_string" "suffix" {
     length  = 5
     special = false
     upper   = false
    }
    resource "azurerm_key_vault" "kv" {
     name                = "akskv${random_string.suffix.result}"
     location            = azurerm_resource_group.rg.location
     resource_group_name = azurerm_resource_group.rg.name
     tenant_id           = data.azurerm_client_config.current.tenant_id
     sku_name            = "standard"
     enable_rbac_authorization = true
    }
    ```

1. Assign Key Vault Secrets Officer role.

    ```terraform
    resource "azurerm_role_assignment" "kv_role" {
     scope                = azurerm_key_vault.kv.id
     role_definition_name = "Key Vault Secrets Officer"
     principal_id         = data.azurerm_client_config.current.object_id
    }
    ```

1. Create ExampleSecret in the key vault.

    ```terraform
    resource "azurerm_key_vault_secret" "example" {
     name         = "ExampleSecret"
     value        = "MyAKSExampleSecret"
     key_vault_id = azurerm_key_vault.kv.id
    }
    ```

1. Deploy the configuration. Form a Bash session, run the following commands to deploy the updated configuration:

    ```bash
    terraform plan
    terraform apply
    ```

1. Verify ExampleSecret was added to the key vault using the [`az keyvault secret show`][az-keyvault-secret-show] command. Replace `<keyvault-name>` with the name of the key vault you created in your Terraform configuration.

    ```azurecli-interactive
    az keyvault secret show \
     --vault-name <keyvault-name> \
     --name ExampleSecret
    ```

:::zone-end


:::zone pivot="terraform-update"

## Update existing key vault

Update your _main.tf_ file to update an existing key vault with Azure role-based access control (Azure RBAC) enabled.

1. Update existing key vault to enable Azure RBAC.

    ```terraform
    resource "azurerm_key_vault" "kv" {
     name                = "<existing-kv>"
     resource_group_name = "<resource-group>"
     enable_rbac_authorization = true
    }
    ```

1. Assign role and add secret.

    ```terraform
    resource "azurerm_role_assignment" "kv_role" {
     scope                = azurerm_key_vault.kv.id
     role_definition_name = "Key Vault Secrets Officer"
     principal_id         = data.azurerm_client_config.current.object_id
    }
    resource "azurerm_key_vault_secret" "example" {
     name         = "ExampleSecret"
     value        = "MyAKSExampleSecret"
     key_vault_id = azurerm_key_vault.kv.id
    }
    ```

1. Deploy the configuration. Form a Bash session, run the following commands to deploy the updated configuration:

    ```bash
    terraform plan
    terraform apply
    ```

:::zone-end

## Clean up resources

If you're going to the next article and need these resources, ignore the following steps. Otherwise, if you're finished and don't plan to continue to the next article, you should delete the resources created in this article to avoid unnecessary costs.

:::zone pivot="azure-cli-create, azure-cli-update"

1.  Remove your cluster's credentials from your local _.kube/config_ file.

    ```bash
    KUBE_CONTEXT=$(kubectl config current-context)
    kubectl config delete-context $KUBE_CONTEXT
    ```

1. Delete the resource group and all resources within it, including resources in the node resource group (`MC_`) using the [`az group delete`][az-group-delete] command.

    ```azurecli-interactive
    az group delete --name $RESOURCE_GROUP --yes --no-wait
    ```
:::zone-end


:::zone pivot="terraform-create, terraform-update"

The `terraform destroy` command removes all resources defined in the current Terraform configuration and state file. Only run this command from the working directory used for this article.

> [!WARNING]
> If you're working with existing or production resources, review the execution plan carefully before you run:
>
> `terraform plan -destroy`
>
> Avoid running `terraform destroy` against shared or imported infrastructure unless you're certain it's safe to remove. For more information, see the Terraform documentation for the [terraform destroy][terraform destroy] command.

1.  Remove your cluster's credentials from your local _.kube/config_ file.

    ```bash
    KUBE_CONTEXT=$(kubectl config current-context)
    kubectl config delete-context $KUBE_CONTEXT
    ```

1. Run the following command to remove the resources created in this article:

    ```bash
    terraform destroy
    ```

:::zone-end

## Next steps

In this article, you learned how to use the Azure Key Vault provider for Secrets Store CSI Driver in an AKS cluster. You now need to provide an identity to access the Azure Key Vault. To learn how, continue to the next article.

> [!div class="nextstepaction"]
> [Provide an identity to access the Azure Key Vault provider for Secrets Store CSI Driver in AKS](./csi-secrets-store-identity-access.md)

<!-- LINKS INTERNAL -->
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-aks-enable-addons]: /cli/azure/aks#az-aks-enable-addons
[az-aks-show]: /cli/azure/aks#az-aks-show
[az-keyvault-create]: /cli/azure/keyvault#az-keyvault-create
[az-keyvault-update]: /cli/azure/keyvault#az-keyvault-update
[az-keyvault-secret-set]: /cli/azure/keyvault#az-keyvault-secret-set
[az-keyvault-show]: /cli/azure/keyvault#az-keyvault-show
[az-group-create]: /cli/azure/group#az-group-create
[az-group-delete]: /cli/azure/group#az-group-delete
[az-role-assignment-create]: /cli/azure/role/assignment#az-role-assignment-create
[key-vault-certificate-user]: /azure/role-based-access-control/built-in-roles/security#key-vault-certificate-user
[key-vault-secrets-officer]: /azure/role-based-access-control/built-in-roles/security#key-vault-secrets-officer
[key-vault-secrets-user]: /azure/role-based-access-control/built-in-roles/security#key-vault-secrets-user
[private-endpoint-keyvault]: /azure/key-vault/general/private-link-service
[fqdns-for-keyvault]: outbound-rules-control-egress.md#azure-key-vault-provider-for-secrets-store-csi-driver
[keyvault-object-types]: /azure/key-vault/general/about-keys-secrets-certificates#object-types

<!-- LINKS EXTERNAL -->
[kube-csi]: https://kubernetes-csi.github.io/docs/
[terraform destroy]: https://developer.hashicorp.com/terraform/cli/commands/destroy
