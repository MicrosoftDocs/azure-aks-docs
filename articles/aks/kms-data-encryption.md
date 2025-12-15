---
title: Enable KMS data encryption in Azure Kubernetes Service (AKS)
description: Learn how to enable Key Management Service (KMS) data encryption with platform-managed keys or customer-managed keys in AKS.
ms.date: 12/14/2025
ms.subservice: aks-security
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.custom:
  - devx-track-azurecli
author: shashankbarsin
ms.author: shasb
zone_pivot_groups: kms-key-type
# Customer intent: As a Kubernetes administrator, I want to enable KMS data encryption in my AKS cluster so that I can encrypt Kubernetes secrets at rest with platform-managed or customer-managed keys.
---

# Enable KMS data encryption in Azure Kubernetes Service (AKS)

This article shows you how to enable Key Management Service (KMS) data encryption for Kubernetes secrets in Azure Kubernetes Service (AKS). KMS encryption encrypts Kubernetes secrets stored in etcd using Azure Key Vault keys.

AKS supports two key management options:

- **Platform-managed keys (PMK)**: AKS automatically creates and manages the encryption keys. This option provides the simplest setup with automatic key rotation.
- **Customer-managed keys (CMK)**: You create and manage your own Azure Key Vault and encryption keys. This option provides full control over key lifecycle and meets compliance requirements that mandate customer-managed keys.

For more information about encryption concepts and key options, see [Data encryption at rest concepts for AKS][kms-data-encryption-concepts].

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

[!INCLUDE [azure-cli-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

- This article requires version 2.73.0 or later of the Azure CLI. If you're using Azure Cloud Shell, the latest version is already installed there.
- You need the `aks-preview` Azure CLI extension version *19.0.0b13* or later.
    - If you don't already have the `aks-preview` extension, install it using the [`az extension add`][az-extension-add] command.
        ```azurecli-interactive
        az extension add --name aks-preview
        ```
    - If you already have the `aks-preview` extension, update it to make sure you have the latest version using the [`az extension update`][az-extension-update] command.
        ```azurecli-interactive
        az extension update --name aks-preview
        ```
- `kubectl` CLI tool installed.

### Register the feature flag

To use KMS data encryption with platform-managed keys, register the `KMSPMKPreview` feature flag in your subscription.

1. Register the feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace Microsoft.ContainerService --name KMSPMKPreview
    ```

1. Verify the registration status using the [`az feature show`][az-feature-show] command. It takes a few minutes for the status to show *Registered*.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name KMSPMKPreview
    ```

1. When the status shows *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

## Set up environment variables

Set up environment variables for your deployment. Replace the placeholder values with your own.

```azurecli-interactive
# Set environment variables
export SUBSCRIPTION_ID="<your-subscription-id>"
export RESOURCE_GROUP="<your-resource-group>"
export LOCATION="<your-location>"
export CLUSTER_NAME="<your-cluster-name>"

# Set subscription
az account set --subscription $SUBSCRIPTION_ID

# Create resource group if it doesn't exist
az group create --name $RESOURCE_GROUP --location $LOCATION
```

:::zone pivot="pmk"

## Enable platform-managed key encryption

With platform-managed keys, AKS automatically creates and manages the Azure Key Vault and encryption keys. Key rotation is handled automatically by the platform.

### Create a new AKS cluster with platform-managed keys

Create a new AKS cluster with KMS encryption using platform-managed keys.

```azurecli-interactive
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --kubernetes-version 1.33.0 \
    --kms-infrastructure-encryption Enabled \
    --generate-ssh-keys
```

### Enable platform-managed keys on an existing cluster

Enable KMS encryption with platform-managed keys on an existing AKS cluster.

> [!NOTE]
> The cluster must be running Kubernetes version 1.33 or later.

```azurecli-interactive
az aks update \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --kms-infrastructure-encryption Enabled
```

:::zone-end

:::zone pivot="cmk-public"

## Enable customer-managed key encryption with a public key vault

With customer-managed keys, you create and manage your own Azure Key Vault and encryption keys. This section shows how to configure customer-managed keys with a public key vault.

### Create a key vault and key

1. Create a key vault with Azure RBAC enabled.

    ```azurecli-interactive
    export KEY_VAULT_NAME="<your-key-vault-name>"
    
    az keyvault create \
        --name $KEY_VAULT_NAME \
        --resource-group $RESOURCE_GROUP \
        --enable-rbac-authorization true \
        --public-network-access Enabled
    
    # Get the key vault resource ID
    export KEY_VAULT_RESOURCE_ID=$(az keyvault show --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP --query id -o tsv)
    ```

1. Assign yourself the Key Vault Crypto Officer role to create a key.

    ```azurecli-interactive
    az role assignment create \
        --role "Key Vault Crypto Officer" \
        --assignee-object-id $(az ad signed-in-user show --query id -o tsv) \
        --assignee-principal-type "User" \
        --scope $KEY_VAULT_RESOURCE_ID
    ```

1. Create a key in the key vault.

    ```azurecli-interactive
    export KEY_NAME="<your-key-name>"
    
    az keyvault key create --name $KEY_NAME --vault-name $KEY_VAULT_NAME
    
    # Get the key ID (without version for automatic rotation)
    export KEY_ID=$(az keyvault key show --name $KEY_NAME --vault-name $KEY_VAULT_NAME --query 'key.kid' -o tsv)
    export KEY_ID_NO_VERSION=$(echo $KEY_ID | sed 's|/[^/]*$||')
    ```

### Create a user-assigned managed identity

1. Create a user-assigned managed identity for the cluster.

    ```azurecli-interactive
    export IDENTITY_NAME="<your-identity-name>"
    
    az identity create --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP
    
    # Get the identity details
    export IDENTITY_OBJECT_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query 'principalId' -o tsv)
    export IDENTITY_RESOURCE_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query 'id' -o tsv)
    ```

1. Assign the required roles to the managed identity.

    ```azurecli-interactive
    # Assign Key Vault Crypto User role for encrypt/decrypt operations
    az role assignment create \
        --role "Key Vault Crypto User" \
        --assignee-object-id $IDENTITY_OBJECT_ID \
        --assignee-principal-type "ServicePrincipal" \
        --scope $KEY_VAULT_RESOURCE_ID
    
    # Assign Key Vault Contributor role for key management
    az role assignment create \
        --role "Key Vault Contributor" \
        --assignee-object-id $IDENTITY_OBJECT_ID \
        --assignee-principal-type "ServicePrincipal" \
        --scope $KEY_VAULT_RESOURCE_ID
    ```

### Create a new AKS cluster with customer-managed keys

Create a new AKS cluster with KMS encryption using customer-managed keys.

```azurecli-interactive
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --kubernetes-version 1.33.0 \
    --kms-infrastructure-encryption Enabled \
    --enable-azure-keyvault-kms \
    --azure-keyvault-kms-key-id $KEY_ID_NO_VERSION \
    --azure-keyvault-kms-key-vault-resource-id $KEY_VAULT_RESOURCE_ID \
    --azure-keyvault-kms-key-vault-network-access Public \
    --assign-identity $IDENTITY_RESOURCE_ID \
    --generate-ssh-keys
```

### Enable customer-managed keys on an existing cluster

Enable KMS encryption with customer-managed keys on an existing AKS cluster.

> [!NOTE]
> The cluster must be running Kubernetes version 1.33 or later.

```azurecli-interactive
az aks update \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --kms-infrastructure-encryption Enabled \
    --enable-azure-keyvault-kms \
    --azure-keyvault-kms-key-id $KEY_ID_NO_VERSION \
    --azure-keyvault-kms-key-vault-resource-id $KEY_VAULT_RESOURCE_ID \
    --azure-keyvault-kms-key-vault-network-access Public \
    --assign-identity $IDENTITY_RESOURCE_ID
```

:::zone-end

:::zone pivot="cmk-private"

## Enable customer-managed key encryption with a private key vault

For enhanced security, you can use a private key vault that's only accessible through private endpoints. This configuration requires the AKS cluster to use [API Server VNet Integration][api-server-vnet-integration] so the API server can access the private key vault. This section shows how to configure customer-managed keys with a private key vault.

### Create a private key vault and key

1. Create a private key vault with Azure RBAC enabled.

    ```azurecli-interactive
    export KEY_VAULT_NAME="<your-key-vault-name>"
    
    az keyvault create \
        --name $KEY_VAULT_NAME \
        --resource-group $RESOURCE_GROUP \
        --enable-rbac-authorization true \
        --public-network-access Enabled
    
    # Get the key vault resource ID
    export KEY_VAULT_RESOURCE_ID=$(az keyvault show --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP --query id -o tsv)
    ```

1. Assign yourself the Key Vault Crypto Officer role to create a key.

    ```azurecli-interactive
    az role assignment create \
        --role "Key Vault Crypto Officer" \
        --assignee-object-id $(az ad signed-in-user show --query id -o tsv) \
        --assignee-principal-type "User" \
        --scope $KEY_VAULT_RESOURCE_ID
    ```

1. Create a key in the key vault.

    > [!NOTE]
    > This document illustrates creating a key vault with public network access initially, then switching to private access. In production environments, you should create and manage your key vault as private from the start using the appropriate network connectivity options. For guidance on managing private key vaults, see [Integrate Key Vault with Azure Private Link][keyvault-private-link].

    ```azurecli-interactive
    export KEY_NAME="<your-key-name>"
    
    az keyvault key create --name $KEY_NAME --vault-name $KEY_VAULT_NAME
    
    # Get the key ID (without version for automatic rotation)
    export KEY_ID=$(az keyvault key show --name $KEY_NAME --vault-name $KEY_VAULT_NAME --query 'key.kid' -o tsv)
    export KEY_ID_NO_VERSION=$(echo $KEY_ID | sed 's|/[^/]*$||')
    ```

1. Disable public network access on the key vault.

    ```azurecli-interactive
    az keyvault update \
        --name $KEY_VAULT_NAME \
        --resource-group $RESOURCE_GROUP \
        --default-action Deny \
        --public-network-access Disabled
    ```

### Create a private endpoint for the key vault

To enable the AKS API server to access the private key vault, create a private endpoint in the same virtual network where the API server is VNet integrated. For more information, see [Integrate Key Vault with Azure Private Link][keyvault-private-link].

1. Set environment variables for the virtual network, subnet, and private endpoint. Replace the placeholder values with your own.

    ```azurecli-interactive
    export VNET_NAME="<your-vnet-name>"
    export VNET_ADDRESS_PREFIX="10.0.0.0/8"
    export PE_SUBNET_NAME="pe-subnet"
    export PE_SUBNET_PREFIX="10.1.0.0/24"
    export AKS_SUBNET_NAME="aks-subnet"
    export AKS_SUBNET_PREFIX="10.2.0.0/16"
    export APISERVER_SUBNET_NAME="apiserver-subnet"
    export APISERVER_SUBNET_PREFIX="10.3.0.0/28"
    export PRIVATE_ENDPOINT_NAME="${KEY_VAULT_NAME}-pe"
    ```

1. Create a virtual network. This virtual network is used for API Server VNet Integration when creating the AKS cluster.

    ```azurecli-interactive
    az network vnet create \
        --name $VNET_NAME \
        --resource-group $RESOURCE_GROUP \
        --address-prefix $VNET_ADDRESS_PREFIX
    ```

1. Create a subnet for the private endpoint.

    ```azurecli-interactive
    az network vnet subnet create \
        --name $PE_SUBNET_NAME \
        --vnet-name $VNET_NAME \
        --resource-group $RESOURCE_GROUP \
        --address-prefix $PE_SUBNET_PREFIX
    ```

1. Disable network policies for private endpoints on the subnet.

    ```azurecli-interactive
    az network vnet subnet update \
        --name $PE_SUBNET_NAME \
        --vnet-name $VNET_NAME \
        --resource-group $RESOURCE_GROUP \
        --private-endpoint-network-policies Disabled
    ```

1. Create a private DNS zone for Azure Key Vault.

    ```azurecli-interactive
    az network private-dns zone create \
        --resource-group $RESOURCE_GROUP \
        --name "privatelink.vaultcore.azure.net"
    ```

1. Link the private DNS zone to the virtual network.

    ```azurecli-interactive
    az network private-dns link vnet create \
        --resource-group $RESOURCE_GROUP \
        --zone-name "privatelink.vaultcore.azure.net" \
        --name "${VNET_NAME}-dns-link" \
        --virtual-network $VNET_NAME \
        --registration-enabled false
    ```

1. Create a private endpoint for the key vault.

    ```azurecli-interactive
    az network private-endpoint create \
        --name $PRIVATE_ENDPOINT_NAME \
        --resource-group $RESOURCE_GROUP \
        --vnet-name $VNET_NAME \
        --subnet $PE_SUBNET_NAME \
        --private-connection-resource-id $KEY_VAULT_RESOURCE_ID \
        --group-id vault \
        --connection-name "${KEY_VAULT_NAME}-connection"
    ```

1. Create a DNS zone group for the private endpoint. This automatically creates the required DNS A record for the key vault in the private DNS zone.

    ```azurecli-interactive
    az network private-endpoint dns-zone-group create \
        --resource-group $RESOURCE_GROUP \
        --endpoint-name $PRIVATE_ENDPOINT_NAME \
        --name "default" \
        --private-dns-zone "privatelink.vaultcore.azure.net" \
        --zone-name "privatelink-vaultcore-azure-net"
    ```

1. Verify the private DNS configuration by checking that the A record was created.

    ```azurecli-interactive
    az network private-dns record-set a list \
        --resource-group $RESOURCE_GROUP \
        --zone-name "privatelink.vaultcore.azure.net"
    ```

    The output should show an A record for your key vault name pointing to the private endpoint's private IP address.

### Create a user-assigned managed identity

1. Create a user-assigned managed identity for the cluster.

    ```azurecli-interactive
    export IDENTITY_NAME="<your-identity-name>"
    
    az identity create --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP
    
    # Get the identity details
    export IDENTITY_OBJECT_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query 'principalId' -o tsv)
    export IDENTITY_RESOURCE_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query 'id' -o tsv)
    ```

1. Assign the required roles to the managed identity.

    ```azurecli-interactive
    # Assign Key Vault Crypto User role for encrypt/decrypt operations
    az role assignment create \
        --role "Key Vault Crypto User" \
        --assignee-object-id $IDENTITY_OBJECT_ID \
        --assignee-principal-type "ServicePrincipal" \
        --scope $KEY_VAULT_RESOURCE_ID
    
    # Assign Key Vault Contributor role for key management
    az role assignment create \
        --role "Key Vault Contributor" \
        --assignee-object-id $IDENTITY_OBJECT_ID \
        --assignee-principal-type "ServicePrincipal" \
        --scope $KEY_VAULT_RESOURCE_ID
    
    # Assign Network Contributor role on the AKS subnet
    az role assignment create \
        --role "Network Contributor" \
        --assignee-object-id $IDENTITY_OBJECT_ID \
        --assignee-principal-type "ServicePrincipal" \
        --scope $AKS_SUBNET_ID
    
    # Assign Network Contributor role on the API server subnet
    az role assignment create \
        --role "Network Contributor" \
        --assignee-object-id $IDENTITY_OBJECT_ID \
        --assignee-principal-type "ServicePrincipal" \
        --scope $APISERVER_SUBNET_ID
    ```

### Create a new AKS cluster with customer-managed keys (private)

Create a new AKS cluster with KMS encryption using customer-managed keys with a private key vault. The cluster must use API Server VNet Integration to access the private key vault.

1. Create a subnet for the AKS cluster nodes.

    ```azurecli-interactive
    az network vnet subnet create \
        --name $AKS_SUBNET_NAME \
        --vnet-name $VNET_NAME \
        --resource-group $RESOURCE_GROUP \
        --address-prefix $AKS_SUBNET_PREFIX
    
    # Get the AKS subnet resource ID
    export AKS_SUBNET_ID=$(az network vnet subnet show \
        --name $AKS_SUBNET_NAME \
        --vnet-name $VNET_NAME \
        --resource-group $RESOURCE_GROUP \
        --query id -o tsv)
    ```

1. Create a delegated subnet for the API server. The subnet must be delegated to `Microsoft.ContainerService/managedClusters` for API Server VNet Integration.

    ```azurecli-interactive
    az network vnet subnet create \
        --name $APISERVER_SUBNET_NAME \
        --vnet-name $VNET_NAME \
        --resource-group $RESOURCE_GROUP \
        --address-prefix $APISERVER_SUBNET_PREFIX \
        --delegations Microsoft.ContainerService/managedClusters
    
    # Get the API server subnet resource ID
    export APISERVER_SUBNET_ID=$(az network vnet subnet show \
        --name $APISERVER_SUBNET_NAME \
        --vnet-name $VNET_NAME \
        --resource-group $RESOURCE_GROUP \
        --query id -o tsv)
    ```

1. Create the AKS cluster with API Server VNet Integration and KMS encryption.

    > [!NOTE]
    > For private key vault scenarios, you must enable [API Server VNet Integration][api-server-vnet-integration] on your cluster.

    ```azurecli-interactive
    az aks create \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --kubernetes-version 1.33.0 \
        --network-plugin azure \
        --vnet-subnet-id $AKS_SUBNET_ID \
        --apiserver-subnet-id $APISERVER_SUBNET_ID \
        --enable-apiserver-vnet-integration \
        --kms-infrastructure-encryption Enabled \
        --enable-azure-keyvault-kms \
        --azure-keyvault-kms-key-id $KEY_ID_NO_VERSION \
        --azure-keyvault-kms-key-vault-resource-id $KEY_VAULT_RESOURCE_ID \
        --azure-keyvault-kms-key-vault-network-access Private \
        --assign-identity $IDENTITY_RESOURCE_ID \
        --generate-ssh-keys
    ```

### Enable customer-managed keys on an existing cluster (private)

Enable KMS encryption with customer-managed keys using a private key vault on an existing AKS cluster.

> [!NOTE]
> The cluster must be running Kubernetes version 1.33 or later and must have [API Server VNet Integration][api-server-vnet-integration] enabled.

```azurecli-interactive
az aks update \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --kms-infrastructure-encryption Enabled \
    --enable-azure-keyvault-kms \
    --azure-keyvault-kms-key-id $KEY_ID_NO_VERSION \
    --azure-keyvault-kms-key-vault-resource-id $KEY_VAULT_RESOURCE_ID \
    --azure-keyvault-kms-key-vault-network-access Private \
    --assign-identity $IDENTITY_RESOURCE_ID
```

:::zone-end

## Verify KMS configuration

After enabling KMS encryption, verify the configuration.

```azurecli-interactive
az aks show --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query 'securityProfile'
```

The output includes the KMS configuration:

```json
{
    "azureKeyVaultKms": {
        "enabled": true,
        "keyId": "https://<key-vault-name>.vault.azure.net/keys/<key-name>",
        "keyVaultNetworkAccess": "Public",
        "keyVaultResourceId": "<key-vault-resource-id>"
    },
    "kubernetesResourceObjectEncryptionProfile": {
        "infrastructureEncryption": "Enabled"
    }
}
```

## Migrate between key management options

You can migrate between platform-managed keys and customer-managed keys.

### Migrate from platform-managed keys to customer-managed keys

To migrate from platform-managed keys to customer-managed keys, first set up the key vault, key, and managed identity as described in the customer-managed keys section, then run the update command:

```azurecli-interactive
az aks update \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --kms-infrastructure-encryption Enabled \
    --enable-azure-keyvault-kms \
    --azure-keyvault-kms-key-id $KEY_ID_NO_VERSION \
    --azure-keyvault-kms-key-vault-resource-id $KEY_VAULT_RESOURCE_ID \
    --azure-keyvault-kms-key-vault-network-access Public \
    --assign-identity $IDENTITY_RESOURCE_ID
```

### Migrate from customer-managed keys to platform-managed keys

To migrate from customer-managed keys to platform-managed keys:

```azurecli-interactive
az aks update \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --kms-infrastructure-encryption Enabled \
    --disable-azure-keyvault-kms
```

## Key rotation

With KMS data encryption, key rotation is handled differently depending on your key management option:

- **Platform-managed keys**: Key rotation is automatic. No action is required.
- **Customer-managed keys**: When you rotate the key version in Azure Key Vault, the KMS controller detects the rotation periodically (every 6 hours) and uses the new key version.

> [!NOTE]
> Unlike the legacy KMS experience, with this new implementation you don't need to manually re-encrypt secrets after key rotation. The platform handles this automatically.

## Related content

- [Data encryption at rest concepts for AKS][kms-data-encryption-concepts]
- [Observability for KMS etcd encryption][kms-observability]
- [Legacy KMS etcd encryption][use-kms-etcd-encryption]
- [Azure data encryption at rest][azure-encryption-atrest]

<!-- INTERNAL LINKS -->
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register
[kms-data-encryption-concepts]: kms-data-encryption-concepts.md
[kms-observability]: kms-observability.md
[use-kms-etcd-encryption]: use-kms-etcd-encryption.md
[api-server-vnet-integration]: api-server-vnet-integration.md
[azure-encryption-atrest]: /azure/security/fundamentals/encryption-atrest
[keyvault-private-link]: /azure/key-vault/general/private-link-service
