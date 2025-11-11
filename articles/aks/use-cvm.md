---
title: Use Confidential Virtual Machines (CVM) in Azure Kubernetes Service (AKS)
description: Learn how to create Confidential Virtual Machines (CVM) node pools with Azure Kubernetes Service (AKS)
ms.topic: how-to
ms.date: 06/26/2025
author: allyford
ms.author: allyford
# Customer intent: "As a cloud engineer, I want to add a Confidential Virtual Machines node pool to my existing Kubernetes cluster, so that I can securely handle sensitive container workloads without requiring code changes."

---

# Use Confidential Virtual Machines (CVM) in Azure Kubernetes Service (AKS) cluster

[Confidential Virtual Machines (CVM)][about-cvm] offer strong security and confidentiality for tenants. CVMs offer VM based Hardware Trusted Execution Environment (TEE) that leverage SEV-SNP security features to deny the hypervisor and other host management code access to VM memory and state, providing defense in depth protections against operator access. These features enable node pools with CVM to target the migration of highly sensitive container workloads to AKS without any code refactoring while benefiting from the features of AKS. For example, you may require CVM if you have the following:
* Workloads that handle security critical data and/or sensitive customer data
* Services that are required to meet various compliance requirements, especially for government contracts. Without a scalable solution for securing data, this could potentially lead to the loss of accreditations and contracts.

In this article, you learn how to create AKS node pools using Confidential VM sizes.

> [!CAUTION]
> In this article, there are references to a feature that is using Ubuntu OS versions that are being deprecated for AKS.
>- Starting on 17 March 2027, AKS will no longer support Ubuntu 20.04. Existing node images will be deleted and AKS will no longer provide security updates. You'll no longer be able to scale your node pools. [Upgrade your node pools](./upgrade-aks-cluster.md) to kubernetes version 1.34+ to migrate to a supported Ubuntu version.
>For more information on this retirement, see [AKS GitHub Issues](https://github.com/Azure/AKS/issues).

> [!IMPORTANT]
> Starting on **30 November 2025**, AKS will no longer support or provide security updates for Azure Linux 2.0. Starting on **31 March 2026**, node images will be removed, and you'll be unable to scale your node pools. Migrate to a supported Azure Linux version by [**upgrading your node pools**](/azure/aks/upgrade-aks-cluster) to a supported Kubernetes version or migrating to [`osSku AzureLinux3`](/azure/aks/upgrade-os-version). For more information, see [[Retirement] Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).

## AKS supported confidential VM sizes

Azure offers a choice of [Trusted Execution Environment (TEE)][TEE] options from both AMD and Intel. These TEEs allow you to create Confidential VM environments with excellent price-to-performance ratios, all without requiring any code changes.
- AMD-based Confidential VMs, use AMD SEV-SNP technology, which is introduced with third Gen AMD EPYC™ processors. 
- Intel-based Confidential VMs use Intel TDX, with fourth Gen Intel® Xeon® processors. 

Both technologies have different implementations. However both provide similar protections from the cloud infrastructure stack. For more information, see [CVM VM sizes][CVM-sizes].

## Security Features 

CVMs offer the following security enhancements as compared to other virtual machine (VM) sizes:
- Robust hardware-based isolation between virtual machines, hypervisor, and host management code.
- Customizable attestation policies to ensure the host's compliance before deployment.
- Cloud-based Confidential OS disk encryption before the first boot.
- VM encryption keys that the platform or the customer (optionally) owns and manages.
- Secure key release with cryptographic binding between the platform's successful attestation and the VM's encryption keys.
- Dedicated virtual Trusted Platform Module (TPM) instance for attestation and protection of keys and secrets in the virtual machine.
- Secure boot capability similar to Trusted launch for Azure VMs

## How does it work?

If you're running a workload that requires enhanced confidentiality and integrity, you can benefit from memory encryption and enhanced security without code changes in your application. All pods on your CVM node are part of the same trust boundary. The nodes in a node pool created with CVM use a customized [node image][node-images] specially configured for CVM. 

### Supported OS Versions
You can create CVM node pools on Linux OS types (Ubuntu and Azure Linux). However, not all OS versions support CVM node pools.

This table includes the supported OS versions:

|OS Type|OS SKU|CVM support|CVM default|
|--|--|--|--|
|Linux|`Ubuntu`|Supported|Ubuntu 20.04 is default for K8s version 1.24-1.33. Ubuntu 24.04 is default for K8s version 1.35+.|
|Linux|`Ubuntu2204`|Not Supported|AKS doesn't support CVM for Ubuntu 22.04.|
|Linux|`Ubuntu2404`|Supported| CVM is supported on `Ubuntu2404` in K8s 1.32-1.38. |
|Linux|`AzureLinux`| Supported on Azure Linux 3.0| Azure Linux 3 is default when enabling CVM for K8s version 1.28-1.36.|
|Linux| `flatcar`| Not supported| [Flatcar Container Linux for AKS][flatcar] doesn't support CVM. |
|Linux| `AzureLinuxOSGuard`| Not supported| [Azure Linux with OS Guard for AKS][os-guard] doesn't support CVM. |
|Windows|All Windows OS SKU| Not Supported|

When using `Ubuntu` or `AzureLinux` as the `osSKU`, if the default OS version doesn't support CVM, AKS defaults to the most recent CVM-supported version of the OS. For example, Ubuntu 22.04 is default for Linux node pools. Since 22.04 doesn't currently support CVM, AKS defaults to Ubuntu 20.04 for Linux CVM-enabled node pools.

### Limitations

The following limitations apply when adding a node pool with CVM to AKS:

- You can't use FIPS, ARM64, Trusted Launch, or Pod Sandboxing.
- You can't update an existing node pool to migrate to a CVM size. To migrate, you'll need to [resize your node pool][resize-your-nodepool].
- You can't use CVM with Windows node pools.
- CVM with Azure Linux is currently in preview.

## Prerequisites

Before you begin, make sure you have the following:

- An existing AKS cluster.
- CVM sizes must be available for your subscription in the region where the cluster is created. You must have sufficient quota to create a node pool with a CVM size.
- If you're using Azure Linux os, you need to install the `aks-preview` extension, update the `aks-preview` extension, and register the preview feature flag. If you're using Ubuntu, you can skip these steps.

### Install `aks-preview` extension

1. Install the `aks-preview` Azure CLI extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command.

    [!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

2. Update to the latest version of the extension using the [`az extension update`](/cli/azure/extension#az-extension-update) command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register `AzureLinuxCVMPreview` feature flag

1. Register the `AzureLinuxCVMPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AzureLinuxCVMPreview"
    ```

2. Verify the registration status using the [`az feature show`][az-feature-show] command. It takes a few minutes for the status to show *Registered*.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name AzureLinuxCVMPreview
    ```

3. When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

## Add a node pool with a CVM to your AKS cluster

- Add a node pool with a CVM to your AKS cluster using the [`az aks nodepool add`][az-aks-nodepool-add] command and set the `node-vm-size` to a supported [VM size][CVM-sizes].

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name cvmnodepool \
        --node-count 3 \
        --node-vm-size Standard_DC4as_v5 
    ```

If you don't specify the `osSKU` or `osType`, AKS defaults to `--os-type Linux` and `--os-sku Ubuntu`.

## Verify the node pool uses CVM

1. Verify a node pool uses CVM using the [`az aks nodepool show`][az-aks-nodepool-show] command and verify the `vmSize` is `Standard_DCa4_v5`.

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

2. Verify a node pool uses a CVM image using the [`az aks nodepool list`][az-aks-nodepool-list] command.

    ```azurecli-interactive
    az aks nodepool list \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name cvmnodepool \
        --query 'nodeImageVersion'
    ```

    The following example command and output shows the node pool uses an Ubuntu 20.04 CVM image:

    ```output
    az aks nodepool show \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name cvmnodepool \
        --query 'nodeImageVersion'

    "AKSUbuntu-2004cvmcontainerd-202507.02.0"
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

In this article, you learned how to add a node pool with CVM to an AKS cluster. 
* For more information about CVM, see [Confidential VM node pools support on AKS][cvm].
* To migrate an existing node pool to a CVM vm size, you can [resize your node pool][resize-your-nodepool].
* If you're only interested in enabling Trusted Launch on your node pools, see [Trusted Launch on AKS][trusted-launch].

<!-- LINKS - Internal -->
[about-cvm]: /azure/confidential-computing/confidential-vm-overview
[TEE]: /azure/confidential-computing/trusted-execution-environment
[cvm-sizes]: /azure/confidential-computing/virtual-machine-options
[cvm]: /azure/confidential-computing/confidential-node-pool-aks
[cvm-announce]: https://techcommunity.microsoft.com/t5/azure-confidential-computing/azure-confidential-vms-using-sev-snp-dcasv5-ecasv5-are-now/ba-p/3573747
[cvm-subs-dc]: /azure/virtual-machines/dcasv5-dcadsv5-series
[cvm-subs-ec]: /azure/virtual-machines/ecasv5-ecadsv5-series
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-nodepool-list]: /cli/azure/aks/nodepool#az-aks-nodepool-list
[az-aks-nodepool-show]: /cli/azure/aks/nodepool#az-aks-nodepool-show
[az-aks-nodepool-delete]: /cli/azure/aks/nodepool#az-aks-nodepool-delete
[resize-your-nodepool]: ./resize-node-pool.md
[trusted-launch]: ./use-trusted-launch.md
[flatcar]: ./flatcar-container-linux-for-aks.md
[os-guard]: ./use-azure-linux-os-guard.md
[node-images]: ./node-images.md

