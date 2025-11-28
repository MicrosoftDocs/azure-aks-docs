---
title: Use Key Management Service (KMS) Etcd Encryption in Azure Kubernetes Service (AKS)
description: Learn how to use Key Management Service (KMS) etcd encryption for a public or private key vault with AKS.
ms.date: 09/26/2024
ms.subservice: aks-security
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.custom:
  - devx-track-azurecli
  - build-2025
author: davidsmatlak
ms.author: davidsmatlak
zone_pivot_groups: public-or-private-kv
# Customer intent: As a Kubernetes administrator, I want to enable Key Management Service etcd encryption in my Azure Kubernetes Service cluster, so that I can ensure the security of sensitive data stored in etcd while maintaining control over key management and access policies.
---

# Add Key Management Service (KMS) etcd encryption to an Azure Kubernetes Service (AKS) cluster

This article shows you how to turn on encryption at rest for a public or private key vault using Azure Key Vault and the Key Management Service (KMS) plugin on AKS. You can use the KMS plugin to:

- Use a key in a key vault for etcd encryption.
- Bring your own keys.
- Provide encryption at rest for secrets stored in etcd.
- Rotate the keys in a key vault.

For more information on using KMS, see [Using a KMS provider for data encryption](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/).

## Prerequisites

- An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free).
- Azure CLI version 2.39.0 or later. Find your version using the `az --version` command. If you need to install or upgrade, see [Install the Azure CLI][azure-cli-install].

> [!WARNING]
>
> Starting on September 15, 2024, Konnectivity is no longer supported for private key vaults for new subscriptions or subscriptions that didn't previously use this configuration. For subscriptions currently using this configuration or used it in the past 60 days, support will continue until AKS version 1.30 reaches end of life for community support.
>
> KMS supports Konnectivity or [API Server VNet Integration][api-server-vnet-integration] for public key vaults.
>
> KMS supports [API Server VNet Integration][api-server-vnet-integration] for both private and public key vaults.
>
> You can use `kubectl get pods -n kube-system` to verify the results and show that a `konnectivity-agent` pod is running. If a pod is running, the AKS cluster is using Konnectivity. When you use API Server VNet Integration, you can run the `az aks show --resource-group <resource-group-name> --name <cluster-name>` command to verify that the `enableVnetIntegration` setting is set to `true`.

## Limitations

The following limitations apply when you integrate KMS etcd encryption with AKS:

- Deleting the key, the key vault, or the associated identity isn't supported.
- KMS etcd encryption doesn't work with system-assigned managed identity. The key vault access policy must be set before the feature is turned on. System-assigned managed identity isn't available until after the cluster is created. Consider the cycle dependency.
- Azure Key Vault with a firewall setting "allow public access from specific virtual networks and IP addresses" isn't supported because it blocks traffic from the KMS plugin to the key vault.
- The maximum number of secrets supported by a cluster with KMS turned on is _2,000_. However, it's important to note that [KMS v2][kms-v2-support] isn't limited by this restriction and can handle a higher number of secrets.
- Bring your own (BYO) Azure key vault from another tenant isn't supported.
- With KMS turned on, you can't change the associated key vault mode (public versus private). To [update a key vault mode][update-a-key-vault-mode], you must first turn off KMS, and then turn it on again.
- If a cluster has KMS turned on and has a private key vault, it must use the [API Server VNet Integration][api-server-vnet-integration] tunnel. Konnectivity isn't supported.
- Using the Virtual Machine Scale Sets API to scale the nodes in the cluster down to zero deallocates the nodes. The cluster then goes down and becomes unrecoverable.
- After you turn off KMS, you can't delete or expire the keys. Such behaviors would cause the API server to stop working.

:::zone pivot="public-kv"

## Create a key vault and key for a public key vault

The following sections describe how to turn on KMS for a public key vault. You can use a public key vault with or without Azure role-based access control (Azure RBAC).

> [!WARNING]
> Deleting the key or the key vault isn't supported and causes the secrets in the cluster to be unrecoverable.
>
> If you need to recover your key vault or your key, see [Azure Key Vault recovery management with soft delete and purge protection](/azure/key-vault/general/key-vault-recovery?tabs=azure-cli).

### [Create a key vault and key with Azure RBAC](#tab/rbac-kv)

1. Create a key vault with Azure RBAC using the [`az keyvault create`][azure-keyvault-create] command. This example command also exports the key vault resource ID to an environment variable.

    ```azurecli-interactive
    export KEY_VAULT_RESOURCE_ID=$(az keyvault create --name $KEY_VAULT --resource-group $RESOURCE_GROUP  --enable-rbac-authorization true --query id -o tsv)
    ``````

1. Assign yourself permissions to create a key using the [`az role assignment create`][azure-role-assignment-create] command. This example assigns the Key Vault Crypto Officer role to the signed-in user.

    ```azurecli-interactive
    az role assignment create --role "Key Vault Crypto Officer" --assignee-object-id $(az ad signed-in-user show --query id -o tsv) --assignee-principal-type "User" --scope $KEY_VAULT_RESOURCE_ID
    ```

1. Create a key using the [`az keyvault key create`][azure-keyvault-key-create] command.

    ```azurecli-interactive
    az keyvault key create --name $KEY_NAME --vault-name $KEY_VAULT
    ```

1. Get the key ID and save it as an environment variable using the [`az keyvault key show`][azure-keyvault-key-show] command.

    ```azurecli-interactive
    export KEY_ID=$(az keyvault key show --name $KEY_NAME --vault-name $KEY_VAULT --query 'key.kid' -o tsv)
    echo $KEY_ID
    ```

### [Create a key vault and key without Azure RBAC](#tab/non-rbac-kv)

1. Create a key vault without Azure RBAC using the [`az keyvault create`][azure-keyvault-create] command.

    ```azurecli-interactive
    az keyvault create --name $KEY_VAULT --resource-group $RESOURCE_GROUP
    ```

1. Create a key using the [`az keyvault key create`][azure-keyvault-key-create] command.

    ```azurecli-interactive
    az keyvault key create --name $KEY_NAME --vault-name $KEY_VAULT
    ```

1. Export the key ID to an environment variable using the [`az keyvault key show`][azure-keyvault-key-show] command.

    ```azurecli-interactive
    export KEY_ID=$(az keyvault key show --name $KEY_NAME --vault-name $KEY_VAULT --query 'key.kid' -o tsv)
    echo $KEY_ID
    ```

---

## Create a user-assigned managed identity for a public key vault

1. Create a user-assigned managed identity using the [`az identity create`][azure-identity-create] command.

    ```azurecli-interactive
    az identity create --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP
    ```

1. Get the identity object ID and save it as an environment variable using the [`az identity show`][azure-identity-show] command.

    ```azurecli-interactive
    export IDENTITY_OBJECT_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query 'principalId' -o tsv)
    echo $IDENTITY_OBJECT_ID
    ```

1. Get the identity resource ID and save it as an environment variable using the [`az identity show`][azure-identity-show] command.

    ```azurecli-interactive
    export IDENTITY_RESOURCE_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query 'id' -o tsv)
    echo $IDENTITY_RESOURCE_ID
    ```

## Assign permissions to decrypt and encrypt a public key vault

The following sections describe how to assign decrypt and encrypt permissions for a public key vault with or without Azure RBAC.

### [Assign permissions for a public key vault with Azure RBAC](#tab/rbac-kv)

- Assign the Key Vault Crypto User role to give decrypt and encrypt permissions using the [`az role assignment create`][azure-role-assignment-create] command.

    ```azurecli-interactive
    az role assignment create --role "Key Vault Crypto User" --assignee-object-id $IDENTITY_OBJECT_ID --assignee-principal-type "ServicePrincipal" --scope $KEY_VAULT_RESOURCE_ID
    ```

### [Assign permissions for a public key vault without Azure RBAC](#tab/non-rbac-kv)

- Create an Azure Key Vault policy to give decrypt and encrypt permissions using the [`az keyvault set-policy`][azure-keyvault-set-policy] command.

    ```azurecli-interactive
    az keyvault set-policy --name $KEY_VAULT --key-permissions decrypt encrypt --object-id $IDENTITY_OBJECT_ID
    ```

---

## Enable KMS for a public key vault on an AKS cluster

The following sections describe how to turn on KMS for a public key vault on a new or existing AKS cluster.

### Create an AKS cluster with a public key vault and KMS

- Create an AKS cluster with a public key vault and KMS using the [`az aks create`][az-aks-create] command with the `--enable-azure-keyvault-kms`, `--azure-keyvault-kms-key-vault-network-access`, and `--azure-keyvault-kms-key-id` parameters.

    ```azurecli-interactive
    az aks create \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --assign-identity $IDENTITY_RESOURCE_ID \
        --enable-azure-keyvault-kms \
        --azure-keyvault-kms-key-vault-network-access "Public" \
        --azure-keyvault-kms-key-id $KEY_ID \
        --generate-ssh-keys
    ```
  
### Enable a public key vault and KMS on an existing AKS cluster

1. Enable KMS on a public key vault on an existing cluster using the [`az aks update`][az-aks-update] command with the `--enable-azure-keyvault-kms`, `--azure-keyvault-kms-key-vault-network-access`, and `--azure-keyvault-kms-key-id` parameters.

    ```azurecli-interactive
    az aks update \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --enable-azure-keyvault-kms \
        --azure-keyvault-kms-key-vault-network-access "Public" \
        --azure-keyvault-kms-key-id $KEY_ID
    ```

1. Update all secrets using the `kubectl get secrets` command to ensure the secrets created earlier are no longer encrypted. For larger clusters, you might want to subdivide the secrets by namespace or create an update script. If the previous command to update KMS fails, still run the following command to avoid unexpected state for KMS plugin.

    ```bash
    kubectl get secrets --all-namespaces -o json | kubectl replace -f -
    ```

## Rotate existing keys in a public key vault

After you change the key ID (including changing either the key name or the key version), you can rotate the existing keys in the public key vault.

> [!WARNING]
> Remember to update all secrets after key rotation. If you don't update all secrets, the secrets are inaccessible if the keys that were created earlier don't exist or no longer work.
>
> KMS uses two keys at the same time. After the first key rotation, you need to ensure both the old and new keys are valid (not expired) until the next key rotation. After the second key rotation, the oldest key can be safely removed/expired.
>
> After rotating KMS key version with the new `keyId`, check `securityProfile.azureKeyVaultKms.keyId` in AKS resource json. Ensure the new key version is in use.

1. Rotate existing keys using the [`az aks update`][az-aks-update] command with the `--enable-azure-keyvault-kms`, `--azure-keyvault-kms-key-vault-network-access`, and `--azure-keyvault-kms-key-id` parameters.

    ```azurecli-interactive
    az aks update \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --enable-azure-keyvault-kms \
        --azure-keyvault-kms-key-vault-network-access "Public" \
        --azure-keyvault-kms-key-id $NEW_KEY_ID
    ```

1. Update all secrets using the `kubectl get secrets` command to ensure the secrets created earlier are no longer encrypted. For larger clusters, you might want to subdivide the secrets by namespace or create an update script. If the previous command to update KMS fails, still run the following command to avoid unexpected state for KMS plugin.

    ```bash
    kubectl get secrets --all-namespaces -o json | kubectl replace -f -
    ```

:::zone-end

:::zone pivot="private-kv"

## Create a key vault and key for a private key vault

If you turn on KMS for a private key vault, AKS automatically creates a private endpoint and a private link in the node resource group. The key vault has a private endpoint connection with the AKS cluster.

> [!WARNING]
> Keep the following information in mind when using a private key vault:
>
> - KMS only supports [API Server VNet Integration][api-server-vnet-integration] for private key vault.
> - Creating or updating keys in a private key vault that doesn't have a private endpoint isn't supported. To learn how to manage private key vaults, see [Integrate a key vault by using Azure Private Link](/azure/key-vault/general/private-link-service).
> - Deleting the key or the key vault isn't supported and causes the secrets in the cluster to be unrecoverable. If you need to recover your key vault or your key, see [Azure Key Vault recovery management with soft delete and purge protection](/azure/key-vault/general/key-vault-recovery?tabs=azure-cli).
>

1. Create a private key vault using the [`az keyvault create`][azure-keyvault-create] command with the `--public-network-access Disabled` parameter.

    ```azurecli-interactive
    az keyvault create --name $KEY_VAULT --resource-group $RESOURCE_GROUP --public-network-access Disabled
    ```

1. Create a key using the [`az keyvault key create`][azure-keyvault-key-create] command.

    ```azurecli-interactive
    az keyvault key create --name $KEY_NAME --vault-name $KEY_VAULT
    ```

## Create a user-assigned managed identity for a private key vault

1. Create a user-assigned managed identity using the [`az identity create`][azure-identity-create] command.

    ```azurecli-interactive
    az identity create --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP
    ```

1. Get the identity object ID and save it as an environment variable using the [`az identity show`][azure-identity-show] command.

    ```azurecli-interactive
    export IDENTITY_OBJECT_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query 'principalId' -o tsv)
    echo $IDENTITY_OBJECT_ID
    ```

1. Get the identity resource ID and save it as an environment variable using the [`az identity show`][azure-identity-show] command.

    ```azurecli-interactive
    export IDENTITY_RESOURCE_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query 'id' -o tsv)
    echo $IDENTITY_RESOURCE_ID
    ```

## Assign permissions to decrypt and encrypt a private key vault

The following sections describe how to assign decrypt and encrypt permissions for a private key vault with or without Azure RBAC.

### [Assign permissions for a private key vault with Azure RBAC](#tab/rbac-kv)

- Assign the Key Vault Crypto User role to give decrypt and encrypt permissions using the [`az role assignment create`][azure-role-assignment-create] command.

    ```azurecli-interactive
    az role assignment create --role "Key Vault Crypto User" --assignee-object-id $IDENTITY_OBJECT_ID --assignee-principal-type "ServicePrincipal" --scope $KEY_VAULT_RESOURCE_ID
    ```

### [Assign permissions for a private key vault without Azure RBAC](#tab/non-rbac-kv)

> [!NOTE]
> With a private key vault, AKS can't validate the permissions of the identity. Verify the identity has permission to access the key vault before enabling KMS.

- Create an Azure Key Vault policy to give decrypt and encrypt permissions using the [`az keyvault set-policy`][azure-keyvault-set-policy] command.

    ```azurecli-interactive
    az keyvault set-policy --name $KEY_VAULT --key-permissions decrypt encrypt --object-id $IDENTITY_OBJECT_ID
    ```

---

## Assign permissions to create a private link

For private key vaults, the Key Vault Contributor role is required to create a private link between the private key vault and the cluster.

- Assign the Key Vault Contributor role using the [`az role assignment create`][azure-role-assignment-create] command.

    ```azurecli-interactive
    az role assignment create --role "Key Vault Contributor" --assignee-object-id $IDENTITY_OBJECT_ID --assignee-principal-type "ServicePrincipal" --scope $KEY_VAULT_RESOURCE_ID
    ```

## Enable KMS for a private key vault on an AKS cluster

The following sections describe how to turn on KMS for a private key vault on a new or existing AKS cluster.

### Create an AKS cluster with a private key vault and KMS

- Create an AKS cluster with a private key vault and KMS using the [`az aks create`][az-aks-create] command with the `--enable-azure-keyvault-kms`, `--azure-keyvault-kms-key-id`, `--azure-keyvault-kms-key-vault-network-access`, and `--azure-keyvault-kms-key-vault-resource-id` parameters.

    ```azurecli-interactive
    az aks create \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --assign-identity $IDENTITY_RESOURCE_ID \
        --enable-azure-keyvault-kms \
        --azure-keyvault-kms-key-id $KEY_ID \
        --azure-keyvault-kms-key-vault-network-access "Private" \
        --azure-keyvault-kms-key-vault-resource-id $KEY_VAULT_RESOURCE_ID \
        --generate-ssh-keys
    ```

### Update an existing AKS cluster to turn on KMS etcd encryption for a private key vault

1. Enable KMS on a private key vault on an existing cluster using the [`az aks update`][az-aks-update] command with the `--enable-azure-keyvault-kms`, `--azure-keyvault-kms-key-id`, `--azure-keyvault-kms-key-vault-network-access`, and `--azure-keyvault-kms-key-vault-resource-id` parameters.

    ```azurecli-interactive
    az aks update \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --enable-azure-keyvault-kms \
        --azure-keyvault-kms-key-id $KEY_ID \
        --azure-keyvault-kms-key-vault-network-access "Private" \
        --azure-keyvault-kms-key-vault-resource-id $KEY_VAULT_RESOURCE_ID
    ```

1. Update all secrets using the `kubectl get secrets` command to ensure the secrets created earlier are no longer encrypted. For larger clusters, you might want to subdivide the secrets by namespace or create an update script. If the previous command to update KMS fails, still run the following command to avoid unexpected state for KMS plugin.

    ```bash
    kubectl get secrets --all-namespaces -o json | kubectl replace -f -
    ```

### Rotate existing keys in a private key vault

After you change the key ID (including changing either the key name or the key version), you can rotate the existing keys in the private key vault.

> [!WARNING]
> Remember to update all secrets after key rotation. If you don't update all secrets, the secrets are inaccessible if the keys that were created earlier don't exist or no longer work.
>
> After you rotate the key, the previous key (key1) is still cached and shouldn't be deleted. If you want to delete the previous key (key1) immediately, you need to rotate the key twice. Then key2 and key3 are cached, and key1 can be deleted without affecting the existing cluster.
>
> After rotating KMS key version with the new `keyId`, check `securityProfile.azureKeyVaultKms.keyId` in AKS resource json. Ensure the new key version is in use.

1. Rotate existing keys in a private key vault using the [`az aks update`][az-aks-update] command with the `--enable-azure-keyvault-kms`, `--azure-keyvault-kms-key-id`, `--azure-keyvault-kms-key-vault-network-access`, and `--azure-keyvault-kms-key-vault-resource-id` parameters.

    ```azurecli-interactive
    az aks update \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP  \
        --enable-azure-keyvault-kms \
        --azure-keyvault-kms-key-id $NEW_KEY_ID \
        --azure-keyvault-kms-key-vault-network-access "Private" \
        --azure-keyvault-kms-key-vault-resource-id $KEY_VAULT_RESOURCE_ID
    ```

1. Update all secrets using the `kubectl get secrets` command to ensure the secrets created earlier are no longer encrypted. For larger clusters, you might want to subdivide the secrets by namespace or create an update script. If the previous command to update KMS fails, still run the following command to avoid unexpected state for KMS plugin.

    ```bash
    kubectl get secrets --all-namespaces -o json | kubectl replace -f -
    ```

:::zone-end

## Disable KMS on an AKS cluster

1. Before you turn off KMS, verify that KMS is enabled on the cluster using the [`az aks list`][az-aks-list] command.

    ```azurecli-interactive
    az aks list --query "[].{Name:name, KmsEnabled:securityProfile.azureKeyVaultKms.enabled, KeyId:securityProfile.azureKeyVaultKms.keyId}" -o table
    ```

1. Once confirmed, you can disable KMS using the [`az aks update`][az-aks-update] command with the `--disable-azure-keyvault-kms` parameter.

    ```azurecli-interactive
    az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --disable-azure-keyvault-kms
    ```

1. Update all secrets using the `kubectl get secrets` command to ensure the secrets created earlier are no longer encrypted. For larger clusters, you might want to subdivide the secrets by namespace or create an update script. If the previous command to update KMS fails, still run the following command to avoid unexpected state for KMS plugin.

    ```bash
    kubectl get secrets --all-namespaces -o json | kubectl replace -f -
    ```

## Next steps

For more information on using KMS with AKS, see the following articles:

- [Update the key vault mode for an Azure Kubernetes Service (AKS) cluster with KMS etcd encryption](./update-kms-key-vault.md)
- [Use KMS v2 for etcd encryption in Azure Kubernetes Service (AKS)](./use-kms-v2.md)
- [Observability for KMS etcd encryption in Azure Kubernetes Service (AKS)](./kms-observability.md)

<!-- LINKS -->
[azure-cli-install]: /cli/azure/install-azure-cli
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[api-server-vnet-integration]: api-server-vnet-integration.md
[kms-v2-support]: ./use-kms-v2.md
[update-a-key-vault-mode]: ./update-kms-key-vault.md
