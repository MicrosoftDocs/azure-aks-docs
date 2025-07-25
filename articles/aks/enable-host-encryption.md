---
title: Enable host-based encryption on Azure Kubernetes Service (AKS)
description: Learn how to configure a host-based encryption in an Azure Kubernetes Service (AKS) cluster.
ms.topic: how-to
ms.subservice: aks-security
ms.date: 07/17/2023 
author: nickomang
ms.author: nickoman

ms.custom: devx-track-azurecli
ms.devlang: azurecli
---

# Host-based encryption on Azure Kubernetes Service (AKS)

With host-based encryption, the data stored on the VM host of your AKS agent nodes' VMs is encrypted at rest and flows encrypted to the Storage service. This means the temp disks are encrypted at rest with platform-managed keys. The cache of OS and data disks is encrypted at rest with either platform-managed keys or customer-managed keys depending on the encryption type set on those disks.

By default, when using AKS, OS and data disks use server-side encryption with platform-managed keys. The caches for these disks are encrypted at rest with platform-managed keys. You can specify your own managed keys following [Bring your own keys (BYOK) with Azure disks in Azure Kubernetes Service](azure-disk-customer-managed-keys.md). The caches for these disks are also encrypted using the key you specify.

Host-based encryption is different than server-side encryption (SSE), which is used by Azure Storage. Azure-managed disks use Azure Storage to automatically encrypt data at rest when saving data. Host-based encryption uses the host of the VM to handle encryption before the data flows through Azure Storage.

## Before you begin

Before you begin, review the following prerequisites and limitations.

### Prerequisites

- Ensure you have the CLI extension v2.23 or higher installed.

### Limitations

- This feature can only be set at cluster or node pool creation time.
- This feature can only be enabled in [Azure regions][supported-regions] that support server-side encryption of Azure managed disks and only with specific [supported VM sizes][supported-sizes].
- This feature requires an AKS cluster and node pool based on Virtual Machine Scale Sets as *VM set type*.

## Enable Encryption at Host for your AKS cluster

Before adding a node pool with host-based encryption, ensure the EncryptionAtHost feature is enabled for your subscription:

```azurecli
# Register the EncryptionAtHost feature
az feature register --namespace Microsoft.Compute --name EncryptionAtHost

# Wait for registration to complete (this may take several minutes)
az feature show --namespace Microsoft.Compute --name EncryptionAtHost --query "properties.state"

# Refresh the provider registration
az provider register --namespace Microsoft.Compute
```

## Use host-based encryption on new clusters

- Create a new cluster and configure the cluster agent nodes to use host-based encryption using the [`az aks create`][az-aks-create] command with the `--enable-encryption-at-host` flag.

    ```shell
    az aks create \
        --name myAKSCluster \
        --resource-group myResourceGroup \
        --node-vm-size Standard_DS2_v2 \
        --location westus2 \
        --enable-encryption-at-host \
        --generate-ssh-keys
    ```

## Use host-based encryption on existing clusters

- Enable host-based encryption on an existing cluster by adding a new node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--enable-encryption-at-host` flag.

    ```azurecli
    az aks nodepool add --name hostencrypt --cluster-name $MY_AKS_CLUSTER --resource-group $MY_RESOURCE_GROUP -s Standard_DS2_v2 --enable-encryption-at-host
    ```

    Results:

    <!-- expected_similarity=0.3 -->

    ```output
    {
        "agentPoolProfile": {
            "enableEncryptionAtHost": true,
            "name": "hostencrypt",
            "nodeCount": 1,
            "osDiskSizeGB": 30,
            "vmSize": "Standard_DS2_v2"
        },
        ...
    }
    ```

## Next steps

- Review [best practices for AKS cluster security][best-practices-security].
- Read more about [host-based encryption](/azure/virtual-machines/disk-encryption#encryption-at-host---end-to-end-encryption-for-your-vm-data).
<!-- LINKS - external -->

<!-- LINKS - internal -->
[best-practices-security]: ./operator-best-practices-cluster-security.md
[supported-regions]: /azure/virtual-machines/disk-encryption#supported-regions
[supported-sizes]: /azure/virtual-machines/disk-encryption#supported-vm-sizes
[control-keys]: ../key-vault/general/best-practices.md#control-access-to-your-vault
[akv-built-in-roles]: ../key-vault/general/rbac-guide.md#azure-built-in-roles-for-key-vault-data-plane-operations
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add