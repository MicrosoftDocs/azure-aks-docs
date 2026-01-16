---
title: Enable KMS data encryption in Azure Kubernetes Service (AKS) clusters (Preview)
description: Learn how to enable Key Management Service (KMS) data encryption with platform-managed keys or customer-managed keys in AKS.
ms.date: 12/19/2025
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

# Enable KMS data encryption in Azure Kubernetes Service (AKS) clusters (Preview)

This article shows you how to enable Key Management Service (KMS) data encryption for Kubernetes secrets in Azure Kubernetes Service (AKS). KMS encryption encrypts Kubernetes secrets stored in etcd using Azure Key Vault keys.

AKS supports two key management options:

- **Platform-managed keys (PMK)**: AKS automatically creates and manages the encryption keys. This option provides the simplest setup with automatic key rotation. All traffic between AKS components and the internal Key Vault is secured using Microsoft’s standard infrastructure for sensitive data.
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

### Verify KMS configuration

After enabling KMS encryption, verify the configuration.

```azurecli-interactive
az aks show --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query 'securityProfile'
```

The output includes the KMS configuration:

```json
{
    "kubernetesResourceObjectEncryptionProfile": {
        "infrastructureEncryption": "Enabled"
    }
}
```

:::zone-end

:::zone pivot="cmk-private"

## Enable customer-managed key encryption with a private key vault

For enhanced security, you can use a private key vault that has public network access disabled. AKS accesses the private key vault through the [trusted services firewall exception][keyvault-trusted-services]. This section shows how to configure customer-managed keys with a private key vault.

### Create a key vault and key with trusted services access

> [!NOTE]
> This section illustrates creating a key vault with public network access initially, then enabling the firewall with trusted services bypass. This approach is for illustrative purposes only. In production environments, you should create and manage your key vault as private from the start. For guidance on managing private key vaults, see [Azure Key Vault network security][keyvault-network-security].

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

1. Enable the key vault firewall with trusted services bypass.

    ```azurecli-interactive
    az keyvault update \
        --name $KEY_VAULT_NAME \
        --resource-group $RESOURCE_GROUP \
        --default-action Deny \
        --bypass AzureServices
    ```

    The `--default-action Deny` parameter blocks public network access, and the `--bypass AzureServices` parameter allows trusted Azure services (including AKS) to access the key vault.

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

### Create a new AKS cluster with customer-managed keys (private)

Create a new AKS cluster with KMS encryption using customer-managed keys with a private key vault.

```azurecli-interactive
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --kubernetes-version 1.33.0 \
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
> The cluster must be running Kubernetes version 1.33 or later.

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

### Verify KMS configuration

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
        "keyVaultNetworkAccess": "Private",
        "keyVaultResourceId": "<key-vault-resource-id>"
    },
    "kubernetesResourceObjectEncryptionProfile": {
        "infrastructureEncryption": "Enabled"
    }
}
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

### Verify KMS configuration

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

:::zone-end

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
[azure-encryption-atrest]: /azure/security/fundamentals/encryption-atrest
[keyvault-trusted-services]: /azure/key-vault/general/network-security#key-vault-firewall-enabled-trusted-services-only
[keyvault-network-security]: /azure/key-vault/general/network-security
