---
title: Update the Key Vault Mode for an Azure Kubernetes Service (AKS) Cluster with KMS Etcd Encryption
description: Learn how to update the key vault mode from public to private or private to public for an AKS cluster with Key Management Service (KMS) etcd encryption.
ms.date: 09/26/2024
ms.subservice: aks-security
ms.topic: how-to
ms.service: azure-kubernetes-service
author: davidsmatlak
ms.author: davidsmatlak
# Customer intent: As a Kubernetes administrator, I want to update the key vault mode for my AKS cluster with KMS etcd encryption, so that I can change the key vault from public to private or private to public as needed.
---

# Update the key vault mode for an Azure Kubernetes Service (AKS) cluster with Key Management Service (KMS) etcd encryption

This article shows you how to update the key vault mode from public to private or private to public for an Azure Kubernetes Service (AKS) cluster with Key Management Service (KMS) etcd encryption.

## Prerequisites

- An AKS cluster with KMS etcd encryption enabled. For more information, see [Add Key Management Service (KMS) etcd encryption to an Azure Kubernetes Service (AKS) cluster](./use-kms-etcd-encryption.md).
- Azure CLI version 2.39.0 or later. Find your version using the `az --version` command. If you need to install or upgrade, see [Install the Azure CLI][azure-cli-install].

## Update a key vault mode

> [!NOTE]
> To change a different key vault with a different mode (whether public or private), you can run [`az aks update`][az-aks-update] directly. To change the mode of an attached key vault, you must first turn off KMS, then turn it on again using the new key vault IDs.

### [Update from a public to a private key vault](#tab/public-to-private)

1. Turn off KMS on the existing cluster and release the key vault using the [`az aks update`][az-aks-update] command with the `--disable-azure-keyvault-kms` parameter.

   ```azurecli-interactive
   az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --disable-azure-keyvault-kms
   ```

    > [!WARNING]
    > After you turn off KMS, the encryption key vault key is still needed. You can't delete or expire it.

1. Update all secrets using the `kubectl get secrets` command to ensure the secrets created earlier are no longer encrypted. For larger clusters, you might want to subdivide the secrets by namespace or create an update script. If the previous command to update KMS fails, still run the following command to avoid unexpected state for KMS plugin.

    ```bash
    kubectl get secrets --all-namespaces -o json | kubectl replace -f -
    ```

1. Update the key vault from public to private using the [`az keyvault update`][azure-keyvault-update] command with the `--public-network-access` parameter set to `Disabled`.

   ```azurecli-interactive
   az keyvault update --name $KEY_VAULT --resource-group $RESOURCE_GROUP --public-network-access Disabled
   ```

1. Turn on KMS with the updated private key vault using the [`az aks update`][az-aks-update] command with the `--azure-keyvault-kms-key-vault-network-access` parameter set to `Private`.

   ```azurecli-interactive
   az aks update \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP  \
        --enable-azure-keyvault-kms \
        --azure-keyvault-kms-key-id $KEY_ID \
        --azure-keyvault-kms-key-vault-network-access "Private" \
        --azure-keyvault-kms-key-vault-resource-id $KEY_VAULT_RESOURCE_ID
   ```

### [Update from a private to a public key vault](#tab/private-to-public)

1. Turn off KMS on the existing cluster to release the key vault using the [`az aks update`][az-aks-update] command.

   ```azurecli-interactive
   az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --disable-azure-keyvault-kms
   ```

    > [!WARNING]
    > After you turn off KMS, the encryption key vault key is still needed. You can't delete or expire it.

1. Update all secrets using the `kubectl get secrets` command to ensure the secrets created earlier are no longer encrypted. For larger clusters, you might want to subdivide the secrets by namespace or create an update script. If the previous command to update KMS fails, still run the following command to avoid unexpected state for KMS plugin.

    ```bash
    kubectl get secrets --all-namespaces -o json | kubectl replace -f -
    ```

1. Update the key vault from public to private using the [`az keyvault update`][azure-keyvault-update] command with the `--public-network-access` parameter set to `Enabled`.

   ```azurecli-interactive
   az keyvault update --name $KEY_VAULT --resource-group $RESOURCE_GROUP --public-network-access Enabled
   ```

1. Turn on KMS with the updated private key vault using the [`az aks update`][az-aks-update] command with the `--azure-keyvault-kms-key-vault-network-access` parameter set to `Public`.

   ```azurecli-interactive
   az aks update \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP  \
        --enable-azure-keyvault-kms \
        --azure-keyvault-kms-key-id $KEY_ID \
        --azure-keyvault-kms-key-vault-network-access "Public" \
        --azure-keyvault-kms-key-vault-resource-id $KEY_VAULT_RESOURCE_ID
   ```

--

## Next steps

For more information on using KMS with AKS, see the following articles:

- [Use KMS v2 for etcd encryption in Azure Kubernetes Service (AKS)](./use-kms-v2.md)
- [Observability for KMS etcd encryption in Azure Kubernetes Service (AKS)](./kms-observability.md)

<!-- LINKS -->

[azure-cli-install]: /cli/azure/install-azure-cli
[az-aks-update]: /cli/azure/aks#az-aks-update
[azure-keyvault-update]: /cli/azure/keyvault#az-keyvault-update
