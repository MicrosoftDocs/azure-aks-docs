---
title: Observability for Azure Kubernetes Service (AKS) Clusters with Key Management Service (KMS) Etcd Encryption (legacy)
description: Learn how to view observability metrics and improve observability for AKS clusters with KMS etcd encryption.
ms.date: 12/22/2025
ms.subservice: aks-security
ms.topic: how-to
ms.service: azure-kubernetes-service
author: shashankbarsin
ms.author: shasb
# Customer intent: As a Kubernetes administrator, I want to view observability metrics for my clusters with KMS etcd encryption so I can improve observability.
---

# Observability for Azure Kubernetes Service (AKS) clusters with Key Management Service (KMS) etcd encryption (legacy)

This article shows you how to view observability metrics and improve observability for AKS clusters with KMS etcd encryption.

## Prerequisites

- An AKS cluster with KMS etcd encryption enabled. For more information, see [Add Key Management Service (KMS) etcd encryption to an Azure Kubernetes Service (AKS) cluster](./use-kms-etcd-encryption.md).
- You must enable [diagnostic settings for the key vault to check the encryption logs](/azure/key-vault/general/howto-logging).

## Check the KMS config

### [Azure CLI](#tab/azure-cli)

- Get the KMS config using the [`az aks show`][az-aks-show] command.

   ```azurecli-interactive
   az aks show --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query "securityProfile.azureKeyVaultKms"
   ```

    The output looks similar to the following example output:

    ```output
    ...
    "securityProfile": {
      "azureKeyVaultKms": {
        "enabled": true,
        "keyId": "https://<key-vault-name>.vault.azure.net/keys/<key-name>/<key-id>",
        "keyVaultNetworkAccess": "Public",
        "keyVaultResourceId": <key-vault-resource-id>
    ...
    ```

### [Azure portal](#tab/azure-portal)

1. In the Azure portal, navigate to your AKS cluster resource.
1. From the service menu, select **Diagnose and solve problems**.
1. In the search bar, search for **KMS** and select **Azure KeyVault KMS Integration Issues**.

    In the **Cluster is configured to use Azure KeyVault KMS Integration** section, you can see if KMS is enabled and the key ID, as shown in the following screenshot:

    :::image type="content" source="./media/kms-observability/portal-kms-config.png" alt-text="Screenshot of the KMS config information in the Azure portal.":::

    For more information about your key vault, you can navigate to the key vault resource.

---

## Diagnose and solve problems

Because the KMS plugin is a sidecar of `kube-apiserver` pod, you can't access it directly. To improve the observability of KMS, you can check the KMS status using the Azure portal.

1. In the Azure portal, navigate to your AKS cluster.
1. From the service menu, select **Diagnose and solve problems**.
1. In the search bar, search for **KMS** and select **Azure KeyVault KMS Integration Issues**.

### Example problem

Let's say you see the following issue: `KeyExpired: Operation encrypt isn't allowed on an expired key`.

Because the AKS KMS plugin currently only allows bring your own (BYO) key vault and key, it's your responsibility to manage the key lifecycle. If the key is expired, the KMS plugin fails to decrypt the existing secrets. To resolve this issue, you need to _extend the key expiration date_ to make KMS work and _rotate the key version_.

## Next steps

For more information on using KMS with AKS, see the following articles:

- [Data encryption at rest concepts for AKS](./kms-data-encryption-concepts.md)
- [Enable KMS data encryption in AKS](./kms-data-encryption.md)
- [Update the key vault mode for an Azure Kubernetes Service (AKS) cluster with KMS etcd encryption](./update-kms-key-vault.md)
- [Migrate to KMS v2 for etcd encryption in Azure Kubernetes Service (AKS)](./use-kms-v2.md)

<!-- LINKS -->
[az-aks-show]: /cli/azure/aks#az-aks-show
