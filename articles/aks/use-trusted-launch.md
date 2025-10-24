---
title: Trusted Launch with Azure Kubernetes Service (AKS)
description: Learn how Trusted Launch protects the Azure Kubernetes Cluster (AKS) nodes against boot kits, rootkits, and kernel-level malware. 
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.subservice: aks-security
ms.date: 07/15/2025
author: allyford
ms.author: allyford
zone_pivot_groups: arm-azure-cli
# Customer intent: "As a Kubernetes administrator, I want to implement Trusted Launch on AKS clusters, so that I can enhance the security of my nodes against malware and ensure the integrity of the boot process."
---

# Trusted Launch for Azure Kubernetes Service (AKS)

[Trusted Launch][trusted-launch-overview] improves the security of generation 2 virtual machines (VMs) by protecting against advanced and persistent attack techniques. It enables administrators to deploy AKS nodes, which contain the underlying virtual machines, with verified and signed bootloaders, OS kernels, and drivers. By using secure and measured boot, administrators gain insights and confidence of the entire boot chain's integrity.

This article helps you understand this new feature, and how to implement it.

> [!IMPORTANT]
> Starting on **30 November 2025**, AKS will no longer support or provide security updates for Azure Linux 2.0. Starting on **31 March 2026**, node images will be removed, and you'll be unable to scale your node pools. Migrate to a supported Azure Linux version by [**upgrading your node pools**](/azure/aks/upgrade-aks-cluster) to a supported Kubernetes version or migrating to [`osSku AzureLinux3`](/azure/aks/upgrade-os-version). For more information, see [[Retirement] Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).

## Overview

Trusted Launch is composed of several, coordinated infrastructure technologies that can be enabled independently. Each technology provides another layer of defense against sophisticated threats.

- **vTPM** - Trusted Launch introduces a virtualized version of a hardware [Trusted Platform Module][trusted-platform-module-overview] (TPM), compliant with the TPM 2.0 specification. It serves as a dedicated secure vault for keys and measurements. Trusted Launch provides your VM with its own dedicated TPM instance, running in a secure environment outside the reach of any VM. The vTPM enables [attestation][attestation-overview] by measuring the entire boot chain of your VM (UEFI, OS, system, and drivers). Trusted Launch uses the vTPM to perform remote attestation by the cloud. It's used for platform health checks and for making trust-based decisions. As a health check, Trusted Launch can cryptographically certify that your VM booted correctly. If the process fails, possibly because your VM is running an unauthorized component, [Microsoft Defender for Cloud][microsoft-defender-for-cloud-overview] issues integrity alerts. The alerts include details on which components failed to pass integrity checks.

- **Secure Boot** - At the root of Trusted Launch is Secure Boot for your VM. This mode, which is implemented in platform firmware, protects against the installation of malware-based rootkits and boot kits. Secure Boot works to ensure that only signed operating systems and drivers can boot. It establishes a "root of trust" for the software stack on your VM. With Secure Boot enabled, all OS boot components (boot loader, kernel, kernel drivers) must be signed by trusted publishers. Both Windows and select Linux distributions support Secure Boot. If Secure Boot fails to authenticate an image signed by a trusted publisher, the VM isn't allowed to boot. For more information, see [Secure Boot][secure-boot-overview].

## Before you begin

:::zone target="docs" pivot="azure-cli"
- The Azure CLI version 2.66.0 or later. Run `az --version` to find the version, and run `az upgrade` to upgrade the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
:::zone-end
- Secure Boot requires signed boot loaders, OS kernels, and drivers.

## Limitations

- AKS supports Trusted Launch on kubernetes version 1.25.2 and higher.
- Trusted Launch only supports [Azure Generation 2 VMs][azure-generation-two-virtual-machines].
- Node pools with Windows Server operating system aren't supported.
- Trusted Launch can't be enabled in the same node pool as [FIPS][FIPS], [Arm64][Arm64], [Pod Sandboxing][pod-sandboxing], or [Confidential VM][CVM]. For more information, see [node images documentation][node-images].
- Trusted Launch doesn't support virtual node.
- Availability sets aren't supported, only Virtual Machine Scale Sets.
- To enable Secure Boot on GPU node pools, you need to skip installing the GPU driver. For more information, see [Skip GPU driver installation][skip-gpu-driver-install].
- Ephemeral OS disks can be created with trusted Launch and all regions are supported. However, not all virtual machines sizes are supported. For more information, see [Trusted Launch ephemeral OS sizes][tusted-launch-ephemeral-os-sizes].
- [Flatcar Container Linux for AKS][flatcar] does not support Trusted Launch on AKS.

## Create an AKS cluster with Trusted Launch enabled

When creating a cluster, enabling vTPM or Secure Boot automatically sets up your node pools to use the customized Trusted Launch image. This image is specifically configured to support the security features enabled by Trusted Launch.

:::zone target="docs" pivot="azure-cli"
1. Create an AKS cluster using the [az aks create][az-aks-create] command. Before running the command, review the following parameters:

   * **--name**: Enter a unique name for the AKS cluster, such as *myAKSCluster*.
   * **--resource-group**: Enter the name of an existing resource group to host the AKS cluster resource.
   * **--enable-secure-boot**: Enables Secure Boot to authenticate an image signed by a trusted publisher.
   * **--enable-vtpm**: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

   > [!NOTE]
   > Secure Boot requires signed boot loaders, OS kernels, and drivers. If after enabling Secure Boot your nodes don't start, you can verify which boot components are responsible for Secure Boot failures within an Azure Linux Virtual Machine. See [verify Secure Boot failures][verify-secure-boot-failures].

   The following example creates a cluster named *myAKSCluster* with one node in the *myResourceGroup*, and enables Secure Boot and vTPM:

    ```azurecli
    az aks create \
        --name myAKSCluster \
        --resource-group myResourceGroup \
        --node-count 1 \
        --enable-secure-boot \
        --enable-vtpm \
        --generate-ssh-keys
    ```

2. Run the following command to get access credentials for the Kubernetes cluster. Use the [az aks get-credentials][az-aks-get-credentials] command and replace the values for the cluster name and the resource group name.

    ```azurecli
    az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
    ```
:::zone-end
:::zone target="docs" pivot="arm"
1. Create a template with Trusted Launch parameters. Before creating the template, review the following parameters:

   * **enableSecureBoot**: Enables Secure Boot to authenticate an image signed by a trusted publisher.
   * **enableVTPM**: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    In your template, provide values for `enableVTPM` and `enableSecureBoot`. The same schema used for CLI deployment exists in the `Microsoft.ContainerService/managedClusters/agentPools` definition under `"properties"`, as shown in the following example:

    ```json
    "properties": {
        ...,
        "securityProfile": {
            "enableVTPM": "true",
            "enableSecureBoot": "true",
        }
    }
    ```

2. Deploy your template with vTPM and secure boot enabled on your cluster. See [Deploy an AKS cluster using an ARM template][quick-ARM-deploy] for detailed instructions.
:::zone-end

## Add a node pool with Trusted Launch enabled

When you create a node pool, enabling vTPM or Secure Boot automatically sets up your node pools to use the customized Trusted Launch image. This image is specifically configured to support the security features enabled by Trusted Launch.

:::zone target="docs" pivot="azure-cli"
1. Add a node pool with Trusted Launch enabled using the [`az aks nodepool add`][az-aks-nodepool-add] command. Before running the command, review the following parameters:

   * **--cluster-name**: Enter the name of the AKS cluster.
   * **--resource-group**: Enter the name of an existing resource group to host the AKS cluster resource.
   * **--name**: Enter a unique name for the node pool. The name of a node pool can only contain lowercase alphanumeric characters and must begin with a lowercase letter. For Linux node pools, the length must be between 1-11 characters.
   * **--node-count**: The number of nodes in the Kubernetes agent pool. Default is 3.
   * **--enable-secure-boot**: Enables Secure Boot to authenticate image signed by a trusted publisher.
   * **--enable-vtpm**: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    > [!NOTE]
    > Secure Boot requires signed boot loaders, OS kernels, and drivers. If after enabling Secure Boot your nodes don't start, you can verify which boot components are responsible for Secure Boot failures within an Azure Linux Virtual Machine. See [verify Secure Boot failures][verify-secure-boot-failures].

    The following example deploys a node pool with vTPM and Secure Boot enabled on a cluster named *myAKSCluster* with three nodes:

    ```azurecli-interactive
    az aks nodepool add --resource-group myResourceGroup --cluster-name myAKSCluster --name mynodepool --node-count 3 --enable-vtpm --enable-secure-boot
    ```
2. Check that your node pool is using a Trusted Launch image.

    Trusted Launch nodes have the following output:

    * Node image version containing `"TL"`, such as `"AKSUbuntu-2204-gen2TLcontainerd"`.
    * `"Security-type"` should be `"Trusted Launch"`.

    ```bash
    kubectl get nodes
    kubectl describe node {node-name} | grep -e node-image-version -e security-type
    ```

:::zone-end
:::zone target="docs" pivot="arm"
1. Create a template with Trusted Launch parameters. Before creating the template, review the following parameters:

   * **enableSecureBoot**: Enables Secure Boot to authenticate an image signed by a trusted publisher.
   * **enableVTPM**: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    In your template, provide values for `enableVTPM` and `enableSecureBoot`. The same schema used for CLI deployment exists in the `Microsoft.ContainerService/managedClusters/agentPools` definition under `"properties"`, as shown in the following example:

    ```json
    "properties": {
        ...,
        "securityProfile": {
            "enableVTPM": "true",
            "enableSecureBoot": "true",
        }
    }
    ```

2. Deploy your template with vTPM and secure boot enabled on your cluster. See [Deploy an AKS cluster using an ARM template][quick-ARM-deploy] for detailed instructions.
:::zone-end

## Enable vTPM or secure boot on an existing Trusted Launch node pool

You can update an existing Trusted Launch node pool to enable vTPM or secure boot. The following scenarios are supported:
   * When creating a node pool, you only specify `--enable-secure-boot`, you can run the update command to `--enable-vtpm`
   * When creating a node pool, you only specify `--enable-vtpm`, you can run the update command to `--enable-secure-boot`

If your node pool doesn't currently have a Trusted Launch image, you won't be able to update the node pool to enable secure boot or vTPM.

:::zone target="docs" pivot="azure-cli"
1. Check that your node pool is using a Trusted Launch image.

    Trusted Launch nodes have the following output:

    * Node image version containing `"TL"`, such as `"AKSUbuntu-2204-gen2TLcontainerd"`.
    * `"Security-type"` should be `"Trusted Launch"`.

    ```bash
    kubectl get nodes
    kubectl describe node {node-name} | grep -e node-image-version -e security-type
    ```

    If your node pool doesn't currently have a Trusted Launch image, you won't be able to update the node pool to enable secure boot or vTPM.

2. Update a node pool with Trusted Launch enabled using the [`az aks nodepool update`][az-aks-nodepool-update] command. Before running the command, review the following parameters:

    * **--resource-group**: Enter the name of an existing resource group hosting your existing AKS cluster.
    * **--cluster-name**: Enter a unique name for the AKS cluster, such as *myAKSCluster*.
    * **--name**: Enter the name of your node pool, such as *mynodepool*.
    * **--enable-secure-boot**: Enables Secure Boot to authenticate that the image was signed by a trusted publisher.
    * **--enable-vtpm**: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    > [!NOTE]
    > Secure Boot requires signed boot loaders, OS kernels, and drivers. If after enabling Secure Boot your nodes don't start, you can verify which boot components are responsible for Secure Boot failures within an Azure Linux Virtual Machine. See [verify Secure Boot failures][verify-secure-boot-failures].

    The following example updates the node pool *mynodepool* on the *myAKSCluster* in the *myResourceGroup*, and enables vTPM. In this scenario, secure boot was enabled during node pool creation:

    ```azurecli-interactive
    az aks nodepool update --cluster-name myCluster --resource-group myResourceGroup --name mynodepool --enable-vtpm 
    ```

    The following example updates the node pool *mynodepool* on the *myAKSCluster* in the *myResourceGroup*, and enables secure boot. In this scenario, vTPM was enabled during node pool creation:

    ```azurecli-interactive
    az aks nodepool update --cluster-name myCluster --resource-group myResourceGroup --name mynodepool --enable-secure-boot
    ```
    
:::zone-end
:::zone target="docs" pivot="arm"
1. Check that your node pool is using a Trusted Launch image.

    Trusted Launch nodes have the following output:
    
    * Node image version containing `"TL"`, such as `"AKSUbuntu-2204-gen2TLcontainerd"`.
    * `"Security-type"` should be `"Trusted Launch"`.

    ```bash
    kubectl get nodes
    kubectl describe node {node-name} | grep -e node-image-version -e security-type
    ```

    If your node pool doesn't currently have a Trusted Launch image, you won't be able to update the node pool to enable secure boot or vTPM.

2. Create a template with Trusted Launch parameters. Before creating the template, review the following parameters:

   * **enableSecureBoot**: Enables Secure Boot to authenticate an image signed by a trusted publisher.
   * **enableVTPM**: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    In your template, provide values for `enableVTPM` and `enableSecureBoot`. The same schema used for CLI deployment exists in the `Microsoft.ContainerService/managedClusters/agentPools` definition under `"properties"`, as shown in the following example:

    ```json
    "properties": {
        ...,
        "securityProfile": {
            "enableVTPM": "true",
            "enableSecureBoot": "true",
        }
    }
    ```

3. Deploy your template with vTPM and secure boot enabled on your cluster. See [Deploy an AKS cluster using an ARM template][quick-ARM-deploy] for detailed instructions.
:::zone-end

## Assign pods to nodes with Trusted Launch enabled

You can constrain a pod and restrict it to run on a specific node or nodes, or preference to nodes with Trusted Launch enabled. You can control this using the following node pool selector in your pod manifest.

```yml
spec:
  nodeSelector:
        kubernetes.azure.com/security-type = "TrustedLaunch"
```

## Disable vTPM or secure boot on an existing Trusted Launch node pool

You can update an existing node pool to disable vTPM or secure boot. When this occurs, you'll still remain on the Trusted Launch image. You can re-enable vTPM or secure boot at any time by updating your node pool.

:::zone target="docs" pivot="azure-cli"
Update a node pool to disable secure boot or vTPM using the [`az aks nodepool update`][az-aks-nodepool-update] command. Before running the command, review the following parameters:

   * **--resource-group**: Enter the name of an existing resource group hosting your existing AKS cluster.
   * **--cluster-name**: Enter a unique name for the AKS cluster, such as *myAKSCluster*.
   * **--name**: Enter the name of your node pool, such as *mynodepool*.
   * **--enable-secure-boot**: Enables Secure Boot to authenticate that the image was signed by a trusted publisher.
   * **--enable-vtpm**: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

To disable vTPM on an existing node pool:

```azurecli-interactive
az aks nodepool update --cluster-name myCluster --resource-group myResourceGroup --name mynodepool --disable-vtpm
```

To disable secure boot on an existing node pool:

```azurecli-interactive
az aks nodepool update --cluster-name myCluster --resource-group myResourceGroup --name mynodepool --disable-secure-boot 
```
:::zone-end
:::zone target="docs" pivot="arm"
1. Create a template with Trusted Launch parameters. Before creating the template, review the following parameters:

   * **enableSecureBoot**: Enables Secure Boot to authenticate an image signed by a trusted publisher.
   * **enableVTPM**: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    In your template, provide values for `enableVTPM` and `enableSecureBoot`. The same schema used for CLI deployment exists in the `Microsoft.ContainerService/managedClusters/agentPools` definition under `"properties"`, as shown in the following example:

    ```json
    "properties": {
        ...,
        "securityProfile": {
            "enableVTPM": "false",
            "enableSecureBoot": "false",
        }
    }
    ```

2. Deploy your template with vTPM and secure boot disabled on your cluster. See [Deploy an AKS cluster using an ARM template][quick-ARM-deploy] for detailed instructions.
:::zone-end

## Next steps

In this article, you learned how to enable Trusted Launch. Learn more about [Trusted Launch][trusted-launch-overview].

<!-- EXTERNAL LINKS -->

<!-- INTERNAL LINKS -->
[install-azure-cli]: /cli/azure/install-azure-cli
[az-feature-register]: /cli/azure/feature#az_feature_register
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[trusted-launch-overview]: /azure/virtual-machines/trusted-launch
[secure-boot-overview]: /windows-hardware/design/device-experiences/oem-secure-boot
[trusted-platform-module-overview]: /windows/security/information-protection/tpm/trusted-platform-module-overview
[attestation-overview]: /windows/security/information-protection/tpm/tpm-fundamentals#measured-boot-with-support-for-attestation
[microsoft-defender-for-cloud-overview]: /azure/defender-for-cloud/defender-for-cloud-introduction
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[azure-generation-two-virtual-machines]: /azure/virtual-machines/generation-2
[verify-secure-boot-failures]: /azure/virtual-machines/trusted-launch-faq#verify-secure-boot-failures
[tusted-launch-ephemeral-os-sizes]: /azure/virtual-machines/ephemeral-os-disks#trusted-launch-for-ephemeral-os-disks
[skip-gpu-driver-install]: gpu-cluster.md#skip-gpu-driver-installation
[FIPS]: ./enable-fips-nodes.md
[Arm64]: ./use-arm64-vms.md
[pod-sandboxing]: ./use-pod-sandboxing.md
[CVM]: ./use-cvm.md
[node-images]: ./node-images.md
[quick-ARM-deploy]: /azure/aks/learn/quick-kubernetes-deploy-rm-template
[flatcar]: ./flatcar-container-linux-for-aks.md
[os-guard]: ./azure/azure-linux/intro-azure-linux-os-guard.md
