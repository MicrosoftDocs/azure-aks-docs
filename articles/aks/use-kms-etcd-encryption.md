---
title: Use Key Management Service etcd encryption in Azure Kubernetes Service
description: Learn how to use Key Management Service (KMS) etcd encryption with Azure Kubernetes Service (AKS).
ms.date: 09/26/2024
ms.subservice: aks-security
ms.topic: how-to
ms.custom:
  - devx-track-azurecli
  - build-2025
author: davidsmatlak
ms.author: davidsmatlak
# Customer intent: As a Kubernetes administrator, I want to enable Key Management Service etcd encryption in my Azure Kubernetes Service cluster, so that I can ensure the security of sensitive data stored in etcd while maintaining control over key management and access policies.
---

# Add Key Management Service etcd encryption to an Azure Kubernetes Service cluster

This article shows you how to turn on encryption at rest for your Azure Kubernetes Service (AKS) secrets in an etcd key-value store by using Azure Key Vault and the Key Management Service (KMS) plugin. You can use the KMS plugin to:

* Use a key in a key vault for etcd encryption.
* Bring your own keys.
* Provide encryption at rest for secrets that are stored in etcd.
* Rotate the keys in a key vault.

For more information on using KMS, see [Using a KMS provider for data encryption](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/).

## Prerequisites

* An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free).
* Azure CLI version 2.39.0 or later. Run `az --version` to find your version. If you need to install or upgrade, see [Install the Azure CLI][azure-cli-install].

> [!WARNING]
>
> Starting on September 15, 2024, Konnectivity is no longer supported for private key vaults for new subscriptions or subscriptions that haven't previously used this configuration. For subscriptions that are currently using this configuration or have used it in the past 60 days, support will continue until AKS version 1.30 reaches end of life for community support.
>
> KMS supports Konnectivity or [API Server VNet Integration (preview)][api-server-vnet-integration] for public key vaults.
>
> KMS supports [API Server VNet Integration (preview)][api-server-vnet-integration] for both private and public key vaults.
>
> You can use `kubectl get po -n kube-system` to verify the results and show that a konnectivity-agent pod is running. If a pod is running, the AKS cluster is using Konnectivity. When you use API Server VNet Integration, you can run the `az aks show -g -n` command to verify that the `enableVnetIntegration` setting is set to `true`.

## Limitations

The following limitations apply when you integrate KMS etcd encryption with AKS:

* Deleting the key, the key vault, or the associated identity isn't supported.
* KMS etcd encryption doesn't work with system-assigned managed identity. The key vault access policy must be set before the feature is turned on. System-assigned managed identity isn't available until after the cluster is created. Consider the cycle dependency.
* Azure Key Vault with a firewall setting "allow public access from specific virtual networks and IP addresses" or "disable public access" isn't supported because it blocks traffic from the KMS plugin to the key vault.
* The maximum number of secrets that are supported by a cluster that has KMS turned on is 2,000. However, it's important to note that [KMS v2][kms-v2-support] isn't limited by this restriction and can handle a higher number of secrets.
* Bring your own (BYO) Azure key vault from another tenant isn't supported.
* With KMS turned on, you can't change the associated key vault mode (public versus private). To [update a key vault mode][update-a-key-vault-mode], you must first turn off KMS, and then turn it on again.
* If a cluster has KMS turned on and has a private key vault, it must use the [API Server VNet Integration (preview)][api-server-vnet-integration] tunnel. Konnectivity isn't supported.
* Using the Virtual Machine Scale Sets API to scale the nodes in the cluster down to zero deallocates the nodes. The cluster then goes down and becomes unrecoverable.
* After you turn off KMS, you can't delete or expire the keys. Such behaviors would cause the API server to stop working.

KMS supports a [public key vault][turn-on-kms-for-a-public-key-vault] or a [private key vault][turn-on-kms-for-a-private-key-vault].

## Turn on KMS for a public key vault

The following sections describe how to turn on KMS for a public key vault.

### Create a public key vault and key

> [!WARNING]
> Deleting the key or the key vault isn't supported and causes the secrets in the cluster to be unrecoverable.
>
> If you need to recover your key vault or your key, see [Azure Key Vault recovery management with soft delete and purge protection](/azure/key-vault/general/key-vault-recovery?tabs=azure-cli).

#### Create a key vault and key for a non-RBAC public key vault

Use `az keyvault create` to create a key vault without using Azure role-based access control (Azure RBAC):

```azurecli
az keyvault create --name MyKeyVault --resource-group MyResourceGroup
```

Use `az keyvault key create` to create a key:

```azurecli
az keyvault key create --name MyKeyName --vault-name MyKeyVault
```

Use `az keyvault key show` to export the key ID:

```azurecli
export KEY_ID=$(az keyvault key show --name MyKeyName --vault-name MyKeyVault --query 'key.kid' -o tsv)
echo $KEY_ID
```

This example stores the key ID in `KEY_ID`.

#### Create a key vault and key for an RBAC public key vault

Use `az keyvault create` to create a key vault by using Azure RBAC:

```azurecli
export KEYVAULT_RESOURCE_ID=$(az keyvault create --name MyKeyVault --resource-group MyResourceGroup  --enable-rbac-authorization true --query id -o tsv)
```

Assign yourself permissions to create a key:

```azurecli-interactive
az role assignment create --role "Key Vault Crypto Officer" --assignee-object-id $(az ad signed-in-user show --query id -o tsv) --assignee-principal-type "User" --scope $KEYVAULT_RESOURCE_ID
```

Use `az keyvault key create` to create a key:

```azurecli
az keyvault key create --name MyKeyName --vault-name MyKeyVault
```

Use `az keyvault key show` to export the key ID:

```azurecli
export KEY_ID=$(az keyvault key show --name MyKeyName --vault-name MyKeyVault --query 'key.kid' -o tsv)
echo $KEY_ID
```

This example stores the key ID in `KEY_ID`.

### Create a user-assigned managed identity for a public key vault

Use `az identity create` to create a user-assigned managed identity:

```azurecli
az identity create --name MyIdentity --resource-group MyResourceGroup
```

Use `az identity show` to get the identity object ID:

```azurecli
IDENTITY_OBJECT_ID=$(az identity show --name MyIdentity --resource-group MyResourceGroup --query 'principalId' -o tsv)
echo $IDENTITY_OBJECT_ID
```

The preceding example stores the value of the identity object ID in `IDENTITY_OBJECT_ID`.

Use `az identity show` to get the identity resource ID:

```azurecli
IDENTITY_RESOURCE_ID=$(az identity show --name MyIdentity --resource-group MyResourceGroup --query 'id' -o tsv)
echo $IDENTITY_RESOURCE_ID
```

This example stores the value of the identity resource ID in `IDENTITY_RESOURCE_ID`.

### Assign permissions to decrypt and encrypt a public key vault

The following sections describe how to assign decrypt and encrypt permissions for a private key vault.

#### Assign permissions for a non-RBAC public key vault

If your key vault isn't set with  `--enable-rbac-authorization`, you can use `az keyvault set-policy` to create an Azure key vault policy.

```azurecli-interactive
az keyvault set-policy --name MyKeyVault --key-permissions decrypt encrypt --object-id $IDENTITY_OBJECT_ID
```

#### Assign permissions for an RBAC public key vault

If your key vault is set with `--enable-rbac-authorization`, assign the Key Vault Crypto User role to give decrypt and encrypt permissions.

```azurecli-interactive
az role assignment create --role "Key Vault Crypto User" --assignee-object-id $IDENTITY_OBJECT_ID --assignee-principal-type "ServicePrincipal" --scope $KEYVAULT_RESOURCE_ID
```

### Create an AKS cluster that has a public key vault and turn on KMS etcd encryption

To turn on KMS etcd encryption, create an AKS cluster by using the [az aks create][az-aks-create] command. You can use the `--enable-azure-keyvault-kms`, `--azure-keyvault-kms-key-vault-network-access`, and `--azure-keyvault-kms-key-id` parameters with `az aks create`.

```azurecli-interactive
az aks create \
    --name myAKSCluster \
    --resource-group MyResourceGroup \
    --assign-identity $IDENTITY_RESOURCE_ID \
    --enable-azure-keyvault-kms \
    --azure-keyvault-kms-key-vault-network-access "Public" \
    --azure-keyvault-kms-key-id $KEY_ID \
    --generate-ssh-keys
```

### Update an existing AKS cluster to turn on KMS etcd encryption for a public key vault

To turn on KMS etcd encryption for an existing cluster, use the [az aks update][az-aks-update] command. You can use the `--enable-azure-keyvault-kms`, `--azure-keyvault-kms-key-vault-network-access`, and `--azure-keyvault-kms-key-id` parameters with `az-aks-update`.

```azurecli-interactive
az aks update --name myAKSCluster --resource-group MyResourceGroup --enable-azure-keyvault-kms --azure-keyvault-kms-key-vault-network-access "Public" --azure-keyvault-kms-key-id $KEY_ID
```

Use the following command to update all secrets. If you don't run this command, secrets that were created earlier are no longer encrypted. For larger clusters, you might want to subdivide the secrets by namespace or create an update script. If the above command to update KMS fails, please still run the below command to avoid unexpected state for KMS plugin.

```azurecli-interactive
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

### Rotate existing keys in a public key vault

After you change the key ID (including changing either the key name or the key version), you can use the [az aks update][az-aks-update] command. You can use the `--enable-azure-keyvault-kms`, `--azure-keyvault-kms-key-vault-network-access`, and `--azure-keyvault-kms-key-id` parameters with `az-aks-update` to rotate existing keys in KMS.

> [!WARNING]
> Remember to update all secrets after key rotation. If you don't update all secrets, the secrets are inaccessible if the keys that were created earlier don't exist or no longer work.
>
> KMS uses two keys at the same time. After the first key rotation, you need to ensure both the old and new keys are valid (not expired) until the next key rotation. After the second key rotation, the oldest key can be safely removed/expired
>
> After rotating KMS key version with the new `keyId`, please check `securityProfile.azureKeyVaultKms.keyId` in AKS resource json. Ensure the new key version is in use.

```azurecli-interactive
az aks update --name myAKSCluster --resource-group MyResourceGroup  --enable-azure-keyvault-kms --azure-keyvault-kms-key-vault-network-access "Public" --azure-keyvault-kms-key-id $NEW_KEY_ID 
```

Use the following command to update all secrets. If you don't run this command, secrets that were created earlier are still encrypted with the previous key. For larger clusters, you might want to subdivide the secrets by namespace or create an update script. If the above command to update KMS fails, please still run the below command to avoid unexpected state for KMS plugin.

```azurecli-interactive
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

## Turn on KMS for a private key vault

If you turn on KMS for a private key vault, AKS automatically creates a private endpoint and a private link in the node resource group. The key vault is added a private endpoint connection with the AKS cluster.

> [!WARNING]
> KMS only supports [API Server VNet Integration (preview)][api-server-vnet-integration] for private key vault.

### Create a private key vault and key

> [!WARNING]
> Deleting the key or the key vault isn't supported and causes the secrets in the cluster to be unrecoverable.
>
> If you need to recover your key vault or your key, see [Azure Key Vault recovery management with soft delete and purge protection](/azure/key-vault/general/key-vault-recovery?tabs=azure-cli).

Use `az keyvault create` to create a private key vault:

```azurecli
az keyvault create --name MyKeyVault --resource-group MyResourceGroup --public-network-access Disabled
```

Use `az keyvault key create` to create a key:

```azurecli
az keyvault key create --name MyKeyName --vault-name MyKeyVault
```

Creating or updating keys in a private key vault that doesn't have a private endpoint isn't supported. To learn how to manage private key vaults, see [Integrate a key vault by using Azure Private Link](/azure/key-vault/general/private-link-service).

### Create a user-assigned managed identity for a private key vault

Use `az identity create` to create a user-assigned managed identity:

```azurecli
az identity create --name MyIdentity --resource-group MyResourceGroup
```

Use `az identity show` to get the identity object ID:

```azurecli
IDENTITY_OBJECT_ID=$(az identity show --name MyIdentity --resource-group MyResourceGroup --query 'principalId' -o tsv)
echo $IDENTITY_OBJECT_ID
```

The preceding example stores the value of the identity object ID in `IDENTITY_OBJECT_ID`.

Use `az identity show` to get the identity resource ID:

```azurecli
IDENTITY_RESOURCE_ID=$(az identity show --name MyIdentity --resource-group MyResourceGroup --query 'id' -o tsv)
echo $IDENTITY_RESOURCE_ID
```

This example stores the value of the identity resource ID in `IDENTITY_RESOURCE_ID`.

### Assign permissions to decrypt and encrypt a private key vault

The following sections describe how to assign decrypt and encrypt permissions for a private key vault.

#### Assign permissions for a non-RBAC private key vault

> [!NOTE]
> When using a private key vault, AKS can't validate the permissions of the identity. Verify the identity has been granted permission to access the key vault before enabling KMS.

If your key vault isn't set with  `--enable-rbac-authorization`, you can use `az keyvault set-policy` to create a key vault policy in Azure:

```azurecli-interactive
az keyvault set-policy --name MyKeyVault --key-permissions decrypt encrypt --object-id $IDENTITY_OBJECT_ID
```

#### Assign permissions for an RBAC private key vault

If your key vault is set with `--enable-rbac-authorization`, assign an Azure RBAC role that includes decrypt and encrypt permissions:

```azurecli-interactive
az role assignment create --role "Key Vault Crypto User" --assignee-object-id $IDENTITY_OBJECT_ID --assignee-principal-type "ServicePrincipal" --scope $KEYVAULT_RESOURCE_ID
```

### Assign permissions to create a private link

For private key vaults, the Key Vault Contributor role is required to create a private link between the private key vault and the cluster.

```azurecli-interactive
az role assignment create --role "Key Vault Contributor" --assignee-object-id $IDENTITY_OBJECT_ID --assignee-principal-type "ServicePrincipal" --scope $KEYVAULT_RESOURCE_ID
```

### Create an AKS cluster that has a private key vault and turn on KMS etcd encryption

To turn on KMS etcd encryption for a private key vault, create an AKS cluster by using the [az aks create][az-aks-create] command. You can use the `--enable-azure-keyvault-kms`, `--azure-keyvault-kms-key-id`, `--azure-keyvault-kms-key-vault-network-access`, and `--azure-keyvault-kms-key-vault-resource-id` parameters with `az-aks-create`.

```azurecli-interactive
az aks create \
    --name myAKSCluster \
    --resource-group MyResourceGroup \
    --assign-identity $IDENTITY_RESOURCE_ID \
    --enable-azure-keyvault-kms \
    --azure-keyvault-kms-key-id $KEY_ID \
    --azure-keyvault-kms-key-vault-network-access "Private" \
    --azure-keyvault-kms-key-vault-resource-id $KEYVAULT_RESOURCE_ID \
    --generate-ssh-keys
```

### Update an existing AKS cluster to turn on KMS etcd encryption for a private key vault

To turn on KMS etcd encryption on an existing cluster that has a private key vault, use the [az aks update][az-aks-update] command. You can use the `--enable-azure-keyvault-kms`, `--azure-keyvault-kms-key-id`, `--azure-keyvault-kms-key-vault-network-access`, and `--azure-keyvault-kms-key-vault-resource-id` parameters with `az-aks-update`.

```azurecli-interactive
az aks update --name myAKSCluster --resource-group MyResourceGroup --enable-azure-keyvault-kms --azure-keyvault-kms-key-id $KEY_ID --azure-keyvault-kms-key-vault-network-access "Private" --azure-keyvault-kms-key-vault-resource-id $KEYVAULT_RESOURCE_ID
```

Use the following command to update all secrets. If you don't run this command, secrets that were created earlier aren't encrypted. For larger clusters, you might want to subdivide the secrets by namespace or create an update script. If the above command to update KMS fails, please still run the below command to avoid unexpected state for KMS plugin.

```azurecli-interactive
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

### Rotate existing keys in a private key vault

After you change the key ID (including the key name and the key version), you can use the [az aks update][az-aks-update] command. You can use the `--enable-azure-keyvault-kms`, `--azure-keyvault-kms-key-id`, `--azure-keyvault-kms-key-vault-network-access`, and `--azure-keyvault-kms-key-vault-resource-id` parameters with `az-aks-update` to rotate the existing keys of KMS.

> [!WARNING]
> Remember to update all secrets after key rotation. If you don't update all secrets, the secrets are inaccessible if the keys that were created earlier don't exist or no longer work.
>
> After you rotate the key, the previous key (key1) is still cached and shouldn't be deleted. If you want to delete the previous key (key1) immediately, you need to rotate the key twice. Then key2 and key3 are cached, and key1 can be deleted without affecting the existing cluster.
>
> After rotating KMS key version with the new `keyId`, please check `securityProfile.azureKeyVaultKms.keyId` in AKS resource json. Ensure the new key version is in use.

```azurecli-interactive
az aks update --name myAKSCluster --resource-group MyResourceGroup  --enable-azure-keyvault-kms --azure-keyvault-kms-key-id $NewKEY_ID --azure-keyvault-kms-key-vault-network-access "Private" --azure-keyvault-kms-key-vault-resource-id $KEYVAULT_RESOURCE_ID
```

Use the following command to update all secrets. If you don't update all secrets, secrets that were created earlier are encrypted with the previous key. For larger clusters, you might want to subdivide the secrets by namespace or create an update script. If the above command to update KMS fails, please still run the below command to avoid unexpected state for KMS plugin.

```azurecli-interactive
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

## Update a key vault mode

> [!NOTE]
> To change a different key vault with a different mode (whether public or private), you can run `az aks update` directly. To change the mode of an attached key vault, you must first turn off KMS, and then turn it on again by using the new key vault IDs.

The following sections describe how to migrate an attached public key vault to private mode.  These steps can also be used for migrating from private to public.

### Turn off KMS on the cluster

Turn off KMS on an existing cluster and release the key vault:

```azurecli-interactive
az aks update --name myAKSCluster --resource-group MyResourceGroup --disable-azure-keyvault-kms
```

Use the following command to update all secrets. If you don't run this command, secrets that were created earlier are still encrypted with the previous key. For larger clusters, you might want to subdivide the secrets by namespace or create an update script. If the above command to update KMS fails, please still run the below command to avoid unexpected state for KMS plugin.

```azurecli-interactive
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

> [!WARNING]
> After turning off KMS, the encryption key vault key is still needed. You can't delete or expire it.

### Change the key vault mode

Update the key vault from public to private:

```azurecli-interactive
az keyvault update --name MyKeyVault --resource-group MyResourceGroup --public-network-access Disabled
```

To migrate from private to public set `--public-network-access` to `Enabled` in the command above.

### Turn on KMS for the cluster by using the updated key vault

Turn on KMS by using the updated private key vault:

```azurecli-interactive
az aks update --name myAKSCluster --resource-group MyResourceGroup  --enable-azure-keyvault-kms --azure-keyvault-kms-key-id $NewKEY_ID --azure-keyvault-kms-key-vault-network-access "Private" --azure-keyvault-kms-key-vault-resource-id $KEYVAULT_RESOURCE_ID
```

After you set up KMS, you can turn on [diagnostic settings for the key vault to check the encryption logs](/azure/key-vault/general/howto-logging).

## Turn off KMS

Before you turn off KMS, you can use the following Azure CLI command to check whether KMS is turned on:

```azurecli-interactive
az aks list --query "[].{Name:name, KmsEnabled:securityProfile.azureKeyVaultKms.enabled, KeyId:securityProfile.azureKeyVaultKms.keyId}" -o table
```

If the results confirm KMS that is on, run the following command to turn off KMS on the cluster:

```azurecli-interactive
az aks update --name myAKSCluster --resource-group MyResourceGroup --disable-azure-keyvault-kms
```

Use the following command to update all secrets. If you don't run this command, secrets that were created earlier are still encrypted with the previous key, and the encrypt and decrypt permissions on the key vault are still required. For larger clusters, you might want to subdivide the secrets by namespace or create an update script. If the above command to update KMS fails, please still run the below command to avoid unexpected state for KMS plugin.

```azurecli-interactive
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

## KMS v2 support

Beginning in AKS version 1.27, turning on the KMS feature configures KMS v2. With KMS v2, you aren't limited to the 2,000 secrets that earlier versions support. For more information, see [KMS V2 Improvements](https://kubernetes.io/blog/2023/05/16/kms-v2-moves-to-beta/).

### Migrate to KMS v2

If your cluster version is older than 1.27 and you already turned on KMS, the upgrade to cluster version 1.27 or later is blocked. Use the following steps to migrate to KMS v2:

1. Turn off KMS on the cluster.
1. Perform the storage migration.
1. Upgrade the cluster to version 1.27 or later.
1. Turn on KMS on the cluster.
1. Perform the storage migration.

#### Turn off KMS to migrate storage

To turn off KMS on an existing cluster, use the `az aks update` command with the `--disable-azure-keyvault-kms` argument:

```azurecli-interactive
az aks update --name myAKSCluster --resource-group MyResourceGroup --disable-azure-keyvault-kms
```

#### Migrate storage

To update all secrets, use the `kubectl get secrets` command with the `--all-namespaces` argument. If the above command to update KMS fails, please still run the below command to avoid unexpected state for KMS plugin:

```azurecli-interactive
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

#### Upgrade the AKS cluster

To upgrade an AKS cluster, use the `az aks upgrade` command. Set the version to `1.27.x` or later by using the `--kubernetes-version` argument.

```azurecli-interactive
az aks upgrade --resource-group myResourceGroup --name myAKSCluster --kubernetes-version <AKS version>
```

Here's an example:

```azurecli-interactive
az aks upgrade --resource-group myResourceGroup --name myAKSCluster --kubernetes-version 1.27.1
```

#### Turn on KMS after storage migration

You can turn on the KMS feature on the cluster again to encrypt the secrets. Afterward, the AKS cluster uses KMS v2. If you don't want to migrate to KMS v2, you can create a new cluster that is version 1.27 or later with KMS turned on.

#### Migrate storage for KMS v2

To re-encrypt all secrets in KMS v2, use the `kubectl get secrets` command with the `--all-namespaces` argument:

```azurecli-interactive
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

## KMS observability

### AKS resource json

You can check the KMS config in AKS resource json by:

1. Using the `az aks show` command
2. Through Azure portal

The `securityProfile.azureKeyVaultKms` section shows the KMS config, including Key vault, key, current key version.

### Diagnose and solve problems

Because KMS plugin is a side car of kube-apiserver Pod, you can't access it directly. To improve the observability of KMS, you can check the KMS status by:

1. Open Azure portal page of your AKS cluster
2. Go to `Diagnose and solve problems` and search for `KMS`
3. In `KMS` detector, you can see the status of KMS and if it is in some known failing scenarios

Take `KeyExpired: Operation encrypt isn't allowed on an expired key` as an example:

Because AKS KMS plugin currently only allows BYO key vault and key, it is your responsibility to manage the key lifecycle. If the key is expired, the KMS plugin will fail to decrypt the existing secrets. You need to

1. Extend the key expiration date to make KMS work
2. Rotate the key version

<!-- LINKS - Internal -->
[azure-cli-install]: /cli/azure/install-azure-cli
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az_aks_update
[turn-on-kms-for-a-public-key-vault]: #turn-on-kms-for-a-public-key-vault
[azure-keyvault-firewall]:../key-vault/general/how-to-azure-key-vault-network-security.md
[turn-on-kms-for-a-private-key-vault]: #turn-on-kms-for-a-private-key-vault
[update-a-key-vault-mode]: #update-a-key-vault-mode
[api-server-vnet-integration]: api-server-vnet-integration.md
[kms-v2-support]: use-kms-etcd-encryption.md#kms-v2-support
