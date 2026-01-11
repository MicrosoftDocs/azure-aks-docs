---
title: Migrate to Key Management Service (KMS) with platform-managed or customer-managed keys in Azure Kubernetes Service (AKS)
description: Learn how to migrate from KMS v2 to KMS with platform-managed keys (PMK) or customer-managed keys (CMK) for enhanced performance and security.
ms.date: 01/12/2026
ms.subservice: aks-security
ms.topic: how-to
ms.service: azure-kubernetes-service
author: zhechengli
ms.author: zhechengli
# Customer intent: As a Kubernetes administrator, I want to migrate from KMS v2 to KMS with platform-managed keys to leverage improved encryption capabilities.
---

# Migrate to Key Management Service (KMS) with platform-managed or customer-managed keys in Azure Kubernetes Service (AKS) (Preview)

> [!IMPORTANT]
> This article applies to clusters running Kubernetes version 1.33 or later that need to migrate from KMS v2 to the new KMS encryption experience. This experience offers platform-managed keys (PMK), customer-managed keys (CMK) with automatic key rotation, and a simplified configuration experience.
>
> Migration from KMS v1 to platform-managed or customer-managed keys is not supported. Please upgrade to KMS v2 first.
>
> AKS apiserver vnet integration is required for KMS v2 with private key vault, while it is not required in CMK.

In this article, you learn how to migrate from KMS v2 for clusters with version 1.33 or later. The new KMS experience provides enhanced performance and security features, including the option to use platform-managed keys that eliminate the need to manage your own Azure Key Vault.

## Prerequisites

Before starting the migration, ensure you have:

- An AKS cluster running Kubernetes version 1.33.0 or later
- Azure CLI version 2.73.0 or later
- The `aks-preview` extension version 19.0.0b13 or later
- Appropriate permissions to update AKS clusters
- For CMK migrations: User-assigned managed identity with Key Vault permissions

## Migration scenarios

The new KMS experience supports two key management options:

- **Platform-managed key (PMK)**: Azure manages the encryption key automatically. No Key Vault configuration required.
- **Customer-managed key (CMK)**: You provide your own Key Vault with either public or private network access.

## Migrate from KMS v2 with public Key Vault to PMK

This migration path is ideal if you want to simplify your encryption setup by letting AKS manage the encryption keys. After migration, customer managed key vault and key are not used by KMS.

Enable PMK on your existing KMS v2 cluster using the `az aks update` command.

```azurecli-interactive
az aks update \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --kms-infrastructure-encryption "Enabled" \
    --disable-azure-keyvault-kms
```

## Migrate from KMS v2 with private Key Vault to PMK

Enable PMK on your existing KMS v2 cluster using the `az aks update` command.

```azurecli-interactive
az aks update \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --kms-infrastructure-encryption "Enabled" \
    --disable-azure-keyvault-kms
```

## Migrate from KMS v2 with public Key Vault to CMK

This migration path allows you to continue using your existing Key Vault while gaining the benefits of the new KMS experience, including automatic key rotation support.

1. Ensure your Key Vault has the following configuration:
   - Public network access enabled
   - User-assigned managed identity has "Key Vault Crypto User" and "Key Vault Reader" roles

3. Enable CMK on your existing KMS v2 cluster using the `az aks update` command.

    ```azurecli-interactive
    az aks update \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --kms-infrastructure-encryption "Enabled"
    ```

## Migrate from KMS v2 with private Key Vault to CMK

1. Ensure your Key Vault has the following configuration:
   - Private network access enabled
   - "Allow trusted Microsoft services to bypass this firewall" enabled
   - User-assigned managed identity has "Key Vault Crypto User" and "Key Vault Reader" roles

2. Enable CMK on your existing KMS v2 cluster using the `az aks update` command for private Key Vault support.

    ```azurecli-interactive
    az aks update \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --kms-infrastructure-encryption "Enabled"
    ```

## Important considerations

- **No downgrade**: Once the new KMS encryption is enabled, you cannot disable it or downgrade to KMS v2.
- **Minimum version**: The new KMS experience requires Kubernetes version 1.33.0 or later.

## Next steps

For more information on using KMS with AKS, see the following articles:

- [Use KMS platform-managed keys or customer-managed keys](kms-data-encryption.md)

<!-- LINKS -->
[az-aks-update]: /cli/azure/aks#az-aks-update
