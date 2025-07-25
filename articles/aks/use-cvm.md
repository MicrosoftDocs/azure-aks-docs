---
title: Use Confidential Virtual Machines (CVM) in Azure Kubernetes Service (AKS)
description: Learn how to create Confidential Virtual Machines (CVM) node pools with Azure Kubernetes Service (AKS)
ms.topic: how-to
ms.date: 08/14/2023
author: schaffererin
ms.author: schaffererin

# Customer intent: "As a cloud engineer, I want to add a Confidential Virtual Machines node pool to my existing Kubernetes cluster, so that I can securely handle sensitive container workloads without requiring code changes."
---

# Use Confidential Virtual Machines (CVM) in Azure Kubernetes Service (AKS) cluster

You can use [confidential virtual machine (VM) sizes (DCav5/ECav5)][cvm-announce] to add a node pool to your AKS cluster with CVM. Confidential VMs with AMD SEV-SNP support bring a new set of security features to protect data-in-use with full VM memory encryption. These features enable node pools with CVM to target the migration of highly sensitive container workloads to AKS without any code refactoring while benefiting from the features of AKS. The nodes in a node pool created with CVM use a customized Ubuntu 20.04 image specially configured for CVM. For more  on CVM, see [Confidential VM node pools support on AKS with AMD SEV-SNP confidential VMs][cvm].

> [!CAUTION]
> In this article, there are references to a feature that may be using Ubuntu OS versions that are being deprecated for AKS
>- Starting on 17 March 2027, AKS will no longer support Ubuntu 20.04. Existing node images will be deleted and AKS will no longer provide security updates. You'll no longer be able to scale your node pools. [Upgrade your node pools](./upgrade-aks-cluster.md) to kubernetes version 1.34+ to migrate to a supported Ubuntu version.
>For more information on this retirement, see [AKS GitHub Issues](https://github.com/Azure/AKS/issues)

## Before you begin

Before you begin, make sure you have the following:

- An existing AKS cluster.
- The [DCasv5 and DCadsv5-series][cvm-subs-dc] or [ECasv5 and ECadsv5-series][cvm-subs-ec] SKUs available for your subscription.

## Limitations

The following limitations apply when adding a node pool with CVM to AKS:

- You can't use `--enable-fips-image`, ARM64, or Azure Linux.
- You can't upgrade an existing node pool to use CVM.
- The [DCasv5 and DCadsv5-series][cvm-subs-dc] or [ECasv5 and ECadsv5-series][cvm-subs-ec] SKUs must be available for your subscription in the region where the cluster is created.

## Add a node pool with the CVM to AKS

- Add a node pool with CVM to AKS using the [`az aks nodepool add`][az-aks-nodepool-add] command and set the `node-vm-size` to `Standard_DCa4_v5`.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name cvmnodepool \
        --node-count 3 \
        --node-vm-size Standard_DC4as_v5 
    ```

## Verify the node pool uses CVM

- Verify a node pool uses CVM using the [`az aks nodepool show`][az-aks-nodepool-show] command and verify the `vmSize` is `Standard_DCa4_v5`.

    ```azurecli-interactive
    az aks nodepool show \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name cvmnodepool \
        --query 'vmSize'
    ```

    The following example command and output shows the node pool uses CVM:

    ```output
    az aks nodepool show \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name cvmnodepool \
        --query 'vmSize'

    "Standard_DC4as_v5"
    ```

## Remove a node pool with CVM from an AKS cluster

- Remove a node pool with CVM from an AKS cluster using the [`az aks nodepool delete`][az-aks-nodepool-delete] command.

    ```azurecli-interactive
    az aks nodepool delete \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name cvmnodepool
    ```

## Next steps

In this article, you learned how to add a node pool with CVM to an AKS cluster. For more information about CVM, see [Confidential VM node pools support on AKS with AMD SEV-SNP confidential VMs][cvm].

<!-- LINKS - Internal -->
[cvm]: /azure/confidential-computing/confidential-node-pool-aks
[cvm-announce]: https://techcommunity.microsoft.com/t5/azure-confidential-computing/azure-confidential-vms-using-sev-snp-dcasv5-ecasv5-are-now/ba-p/3573747
[cvm-subs-dc]: /azure/virtual-machines/dcasv5-dcadsv5-series
[cvm-subs-ec]: /azure/virtual-machines/ecasv5-ecadsv5-series
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az_aks_nodepool_add
[az-aks-nodepool-show]: /cli/azure/aks/nodepool#az_aks_nodepool_show
[az-aks-nodepool-delete]: /cli/azure/aks/nodepool#az_aks_nodepool_delete

