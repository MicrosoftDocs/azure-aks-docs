---
title: Migrate to Key Management Service (KMS) v2 in Azure Kubernetes Service (AKS)
description: Learn how to migrate to KMS v2 for clusters with versions older than 1.27.
ms.date: 12/14/2025
ms.subservice: aks-security
ms.topic: how-to
ms.service: azure-kubernetes-service
author: shashankbarsin
ms.author: shasb
# Customer intent: As a Kubernetes administrator, I want to migrate to KMS v2 so I don't face as many limitations with my encryption setup.
---

# Migrate to Key Management Service (KMS) v2 in Azure Kubernetes Service (AKS)

> [!IMPORTANT]
> This article applies to clusters using the legacy KMS experience that need to migrate from KMS v1 to KMS v2. For clusters running Kubernetes version 1.33 or later, we recommend using the new [KMS data encryption](kms-data-encryption.md) experience, which offers platform-managed keys, customer-managed keys with automatic key rotation, and a simplified configuration experience.

In this article, you learn how to migrate to KMS v2 for clusters with versions older than 1.27. Beginning in AKS version 1.27, turning on the KMS feature configures KMS v2. With KMS v2, you aren't limited to the 2,000 secrets that earlier versions support. For more information, see [KMS v2 improvements](https://kubernetes.io/blog/2023/05/16/kms-v2-moves-to-beta/).

> [!IMPORTANT]
> If your cluster version is older than 1.27 and you already turned on KMS, the upgrade to cluster version 1.27 or later is blocked.

## Turn off KMS

1. Disable KMS on an existing cluster using the [`az aks update`][az-aks-update] command with the `--disable-azure-keyvault-kms` parameter.

    ```azurecli-interactive
    az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --disable-azure-keyvault-kms
    ```

1. Update all secrets using the `kubectl get secrets` command to ensure the secrets created earlier are no longer encrypted. For larger clusters, you might want to subdivide the secrets by namespace or create an update script. If the previous command to update KMS fails, still run the following command to avoid unexpected state for KMS plugin.

    ```bash
    kubectl get secrets --all-namespaces -o json | kubectl replace -f -
    ```

## Upgrade your AKS cluster and turn on KMS

1. Upgrade your AKS cluster to version 1.27 or later using the [`az aks upgrade`][az-aks-upgrade] command with the `--kubernetes-version` parameter set to your desired version. The following example upgrades to version `1.27.1`:

    ```azurecli-interactive
    az aks upgrade --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --kubernetes-version 1.27.1
    ```

1. Once the upgrade completes, you can turn on KMS for a public or private key vault using one of the following resources:

    - [Enable a public key vault and KMS on an existing AKS cluster](./use-kms-etcd-encryption.md#enable-a-public-key-vault-and-kms-on-an-existing-aks-cluster)
    - [Update an existing AKS cluster to turn on KMS etcd encryption for a private key vault](./use-kms-etcd-encryption.md#update-an-existing-aks-cluster-to-turn-on-kms-etcd-encryption-for-a-private-key-vault)

1. Update all secrets using the `kubectl get secrets` command to ensure the secrets created earlier are no longer encrypted. For larger clusters, you might want to subdivide the secrets by namespace or create an update script. If the previous command to update KMS fails, still run the following command to avoid unexpected state for KMS plugin.

    ```bash
    kubectl get secrets --all-namespaces -o json | kubectl replace -f -
    ```

## Next steps

For more information on using KMS with AKS, see the following articles:

- [Update the key vault mode for an Azure Kubernetes Service (AKS) cluster with KMS etcd encryption](./update-kms-key-vault.md)
- [Observability for KMS etcd encryption in Azure Kubernetes Service (AKS)](./kms-observability.md)

<!-- LINKS -->
[az-aks-upgrade]: /cli/azure/aks#az-aks-upgrade
[az-aks-update]: /cli/azure/aks#az-aks-update
