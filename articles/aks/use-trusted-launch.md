---
title: Trusted Launch with Azure Kubernetes Service (AKS)
description: Learn how Trusted Launch protects the Azure Kubernetes Cluster (AKS) nodes against boot kits, rootkits, and kernel-level malware. 
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.subservice: aks-security
ms.date: 11/17/2026
ai-usage: ai-assisted
author: allyford
ms.author: allyford
zone_pivot_groups: azure-cli-arm-bicep-terraform-portal
# Customer intent: "As a Kubernetes administrator, I want to implement Trusted Launch on AKS clusters, so that I can enhance the security of my nodes against malware and ensure the integrity of the boot process."
---

# Trusted Launch for Azure Kubernetes Service (AKS)

[Trusted Launch][trusted-launch-overview] improves the security of generation 2 virtual machines (VMs) by protecting against advanced and persistent attack techniques. It enables administrators to deploy AKS nodes, which contain the underlying virtual machines, with verified and signed bootloaders, OS kernels, and drivers. By using secure and measured boot, administrators gain insights and confidence of the entire boot chain's integrity.

This article helps you understand this new feature, and how to implement it.

> [!NOTE]
> Trusted Launch is supported with Node Auto Provisioning (NAP). For more information, see [Enable trusted launch in NAP clusters](./node-auto-provisioning-aksnodeclass.md#enable-trusted-launch-in-nap-clusters).

[!INCLUDE [azure linux 2.0 retirement](./includes/azure-linux-retirement.md)]

## Overview

Trusted Launch is composed of several, coordinated infrastructure technologies that can be enabled independently. Each technology provides another layer of defense against sophisticated threats.

- **vTPM** - Trusted Launch introduces a virtualized version of a hardware [Trusted Platform Module][trusted-platform-module-overview] (TPM), compliant with the TPM 2.0 specification. It serves as a dedicated secure vault for keys and measurements. Trusted Launch provides your VM with its own dedicated TPM instance, running in a secure environment outside the reach of any VM. The vTPM enables [attestation][attestation-overview] by measuring the entire boot chain of your VM (UEFI, OS, system, and drivers). Trusted Launch uses the vTPM to perform remote attestation by the cloud. It's used for platform health checks and for making trust-based decisions. As a health check, Trusted Launch can cryptographically certify that your VM booted correctly. If the process fails, possibly because your VM is running an unauthorized component, [Microsoft Defender for Cloud][microsoft-defender-for-cloud-overview] issues integrity alerts. The alerts include details on which components failed to pass integrity checks.

- **Secure Boot** - At the root of Trusted Launch is Secure Boot for your VM. This mode, which is implemented in platform firmware, protects against the installation of malware-based rootkits and boot kits. Secure Boot works to ensure that only signed operating systems and drivers can boot. It establishes a "root of trust" for the software stack on your VM. With Secure Boot enabled, all OS boot components (boot loader, kernel, kernel drivers) must be signed by trusted publishers. Both Windows and select Linux distributions support Secure Boot. If Secure Boot fails to authenticate an image signed by a trusted publisher, the VM isn't allowed to boot. For more information, see [Secure Boot][secure-boot-overview].

## Before you begin

:::zone target="docs" pivot="azure-cli"
- The Azure CLI version 2.66.0 or later. Run `az --version` to find the version, and run `az upgrade` to upgrade the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
- To use Trusted Launch with Azure Container Linux (ACL), install Azure CLI version 2.86.0 or later.
:::zone-end

:::zone target="docs" pivot="bicep"
- Bicep CLI version 0.42.1 or later for the Windows node pool example. Run `az bicep version` to check your version. For installation instructions, see [Install Bicep tools](/azure/azure-resource-manager/bicep/install).
:::zone-end

- Secure Boot requires signed boot loaders, OS kernels, and drivers.

## Limitations

- AKS supports Trusted Launch on Kubernetes version 1.25.2 and higher.
- ACL node pools with Trusted Launch require AKS version 1.34 or later.
- Trusted Launch only supports [Azure Generation 2 VMs][azure-generation-two-virtual-machines].
- Windows Trusted Launch is in preview and requires the `WindowsTrustedLaunchPreview` feature flag, Kubernetes version 1.32 or later, `osType: Windows`, `osSKU: Windows2025`, Virtual Machine Scale Sets, an x64 VM size that supports generation 2 and Trusted Launch, and FIPS enablement when creating the node pool.
- For Ubuntu and Azure Linux node pools, you can't enable Trusted Launch in the same node pool as [Arm64][Arm64], [Pod Sandboxing][pod-sandboxing], or [Confidential VM][CVM]. Azure Container Linux (ACL) supports Trusted Launch on supported AMD64 VM sizes and supported Arm64 VM sizes. For more information, see [node images documentation][node-images].
- You can enable Trusted Launch in the same node pool as [FIPS][FIPS] with Ubuntu 22.04, ACL, or Windows Server 2025. Windows Server 2025 enables FIPS by default.
- Trusted Launch doesn't support virtual node.
- Availability sets aren't supported, only Virtual Machine Scale Sets.
- To enable Secure Boot on GPU node pools using the Ubuntu operating system, you need to skip installing the GPU driver (`--gpu-driver None`). For more information, see [Skip GPU driver installation][skip-gpu-driver-install] and [Use NVIDIA GPUs on Azure Kubernetes Service (AKS)][use-nvidia-gpu]. This limitation doesn't apply for running GPU workloads with Azure Linux or Azure Container Linux operating systems.
- Ephemeral OS disks can be created with Trusted Launch and all regions are supported. However, not all virtual machines sizes are supported. For more information, see [Trusted Launch ephemeral OS sizes][tusted-launch-ephemeral-os-sizes].
- [Flatcar Container Linux for AKS][flatcar] doesn't support Trusted Launch on AKS.
- Trusted Launch with Terraform requires AzureRM (`azurerm`) provider version 5.14.0 or later.

## Supported OS versions

The following table includes the supported OS versions for Trusted Launch-enabled node pools:

| OS type | OS SKU | Trusted Launch support | Default | Constraints |
| ------- | ------ | ---------------------- | ------- | ----------- |
| Linux | Ubuntu | Supported | Disabled by default | Requires [Azure Generation 2 VMs][azure-generation-two-virtual-machines]. You can't combine Trusted Launch with [Arm64][Arm64], [Pod Sandboxing][pod-sandboxing], or [Confidential VM][CVM] in the same node pool. Trusted Launch and [FIPS][FIPS] together are supported only with Ubuntu 22.04. |
| Linux | Azure Linux | Supported | Disabled by default | Requires [Azure Generation 2 VMs][azure-generation-two-virtual-machines]. You can't combine Trusted Launch with [Arm64][Arm64], [Pod Sandboxing][pod-sandboxing], or [Confidential VM][CVM] in the same node pool. |
| Linux | Azure Container Linux | Supported | Required | ACL requires Trusted Launch with Secure Boot and vTPM and always uses [Azure Generation 2 VMs][azure-generation-two-virtual-machines]. |
| Windows | Windows Server 2025 | Supported (preview) | Opt-in preview | Requires [Azure Generation 2 VMs][azure-generation-two-virtual-machines], Kubernetes version 1.32 or later, and registration of the `WindowsTrustedLaunchPreview` feature flag. |

## Create an AKS cluster with Trusted Launch enabled

When creating a cluster, enabling vTPM or Secure Boot automatically sets up your node pools to use the customized Trusted Launch image. This image is specifically configured to support the security features enabled by Trusted Launch.

:::zone target="docs" pivot="azure-cli"
1. Create an AKS cluster using the [az aks create][az-aks-create] command. Before running the command, review the following parameters:

   * `--name`: Enter a unique name for the AKS cluster, such as *myAKSCluster*.
   * `--resource-group`: Enter the name of an existing resource group to host the AKS cluster resource.
   * `--enable-secure-boot`: Enables Secure Boot to authenticate an image signed by a trusted publisher.
   * `--enable-vtpm`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

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

1. Run the following command to get access credentials for the Kubernetes cluster. Use the [az aks get-credentials][az-aks-get-credentials] command and replace the values for the cluster name and the resource group name.

    ```azurecli
    az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
    ```
:::zone-end
:::zone target="docs" pivot="arm"
1. Create a template with Trusted Launch parameters. Before creating the template, review the following parameters:

   * `enableSecureBoot`: Enables secure boot to authenticate an image signed by a trusted publisher.
   * `enableVTPM`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    In your template, provide values for `enableVTPM` and `enableSecureBoot`. The same schema used for CLI deployment exists in the `Microsoft.ContainerService/managedClusters/agentPools` definition under `"properties"`, as shown in the following example:

    ```json
    "properties": {
        ...,
        "securityProfile": {
            "enableVTPM": true,
            "enableSecureBoot": true,
        }
    }
    ```

1. Deploy your template with vTPM and secure boot enabled on your cluster. See [Deploy an AKS cluster using an ARM template][quick-ARM-deploy] for detailed instructions.
:::zone-end
:::zone target="docs" pivot="bicep"
1. Create a Bicep file with Trusted Launch parameters. Before creating the file, review the following parameters:

   * `enableSecureBoot`: Enables secure boot to authenticate an image signed by a trusted publisher.
   * `enableVTPM`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    In your Bicep file, provide values for `enableVTPM` and `enableSecureBoot`. The same schema used for CLI deployment exists in the `Microsoft.ContainerService/managedClusters/agentPools` definition under `properties`, as shown in the following example:

    ```bicep
    properties: {
      // ...
      securityProfile: {
        enableVTPM: true
        enableSecureBoot: true
      }
    }
    ```

1. Deploy your Bicep file with vTPM and secure boot enabled on your cluster. See [Deploy an AKS cluster using a Bicep file][quick-bicep-deploy] for detailed instructions.
:::zone-end
:::zone target="docs" pivot="terraform"

1. Create a Terraform configuration with Trusted Launch settings by using the [`azurerm_kubernetes_cluster`][terraform-azurerm-kubernetes-cluster] resource. Before creating the configuration, review the following parameters in the `default_node_pool.security` block:

   * `secure_boot_enabled`: Enables Secure Boot to authenticate an image signed by a trusted publisher.
   * `vtpm_enabled`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    The following example creates a cluster named *myAKSCluster* with one node in *myResourceGroup*, and enables Secure Boot and vTPM on the default node pool:

    ```terraform
    resource "azurerm_kubernetes_cluster" "example" {
      name                = "myAKSCluster"
      location            = azurerm_resource_group.example.location
      resource_group_name = azurerm_resource_group.example.name
      dns_prefix          = "myakscluster"

      default_node_pool {
        name       = "nodepool1"
        node_count = 1
        vm_size    = "Standard_D2s_v3"

        security {
          secure_boot_enabled = true
          vtpm_enabled        = true
        }
      }

      node_provisioning_profile {
        mode = "Manual"
      }

      identity {
        type = "SystemAssigned"
      }
    }
    ```

1. Apply your Terraform configuration by using the `terraform init`, `terraform plan`, and `terraform apply` commands. For detailed instructions, see [Deploy an AKS cluster using Terraform][quick-terraform-deploy].

:::zone-end
:::zone target="docs" pivot="azure-portal"

The Azure portal **doesn't support** creating an AKS cluster with Trusted Launch enabled. To create an AKS cluster with Trusted Launch enabled, use the Azure CLI, ARM template, Bicep, or Terraform instructions in this article.

:::zone-end

## Add a Linux node pool with Trusted Launch enabled

When you create a node pool, enabling vTPM or Secure Boot automatically sets up your node pools to use the customized Trusted Launch image. This image is specifically configured to support the security features enabled by Trusted Launch.

:::zone target="docs" pivot="azure-cli"
1. Add a Linux node pool with Trusted Launch enabled by using the [`az aks nodepool add`][az-aks-nodepool-add] command. Before running the command, review the following parameters:

   * `--cluster-name`: Enter the name of the AKS cluster.
   * `--resource-group`: Enter the name of an existing resource group to host the AKS cluster resource.
   * `--name`: Enter a unique name for the node pool. The name of a node pool can only contain lowercase alphanumeric characters and must begin with a lowercase letter. For Linux node pools, the length must be between 1 and 11 characters.
   * `--node-count`: The number of nodes in the Kubernetes agent pool. Default is 3.
   * `--enable-secure-boot`: Enables Secure Boot to authenticate image signed by a trusted publisher.
   * `--enable-vtpm`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    > [!NOTE]
    > Secure Boot requires signed boot loaders, OS kernels, and drivers. If after enabling Secure Boot your nodes don't start, you can verify which boot components are responsible for Secure Boot failures within an Azure Linux Virtual Machine. See [verify Secure Boot failures][verify-secure-boot-failures].

    The following example deploys a node pool with vTPM and Secure Boot enabled on a cluster named *myAKSCluster* with three nodes:

    ```azurecli-interactive
    az aks nodepool add --resource-group myResourceGroup --cluster-name myAKSCluster --name mynodepool --node-count 3 --enable-vtpm --enable-secure-boot
    ```

1. Check that your node pool is using a Trusted Launch image.

    Trusted Launch nodes have the following output:

    * Node image version containing `"TL"`, such as `"AKSUbuntu-2204-gen2TLcontainerd"`.
    * The `kubernetes.azure.com/security-type` label is `TrustedLaunch`.

    ```bash
    kubectl get nodes
    kubectl describe node {node-name} | grep -e node-image-version -e security-type
    ```

:::zone-end
:::zone target="docs" pivot="arm"
1. Create a template with Trusted Launch parameters. Before creating the template, review the following parameters:

   * `enableSecureBoot`: Enables secure boot to authenticate an image signed by a trusted publisher.
   * `enableVTPM`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    In your template, provide values for `enableVTPM` and `enableSecureBoot`. The same schema used for CLI deployment exists in the `Microsoft.ContainerService/managedClusters/agentPools` definition under `"properties"`, as shown in the following example:

    ```json
    "properties": {
        ...,
        "securityProfile": {
            "enableVTPM": true,
            "enableSecureBoot": true,
        }
    }
    ```

1. Deploy your template with vTPM and secure boot enabled on your cluster. See [Deploy an AKS cluster using an ARM template][quick-ARM-deploy] for detailed instructions.
:::zone-end
:::zone target="docs" pivot="bicep"
1. Create a Bicep file with Trusted Launch parameters. Before creating the file, review the following parameters:

   * `enableSecureBoot`: Enables secure boot to authenticate an image signed by a trusted publisher.
   * `enableVTPM`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    In your Bicep file, provide values for `enableVTPM` and `enableSecureBoot`. The same schema used for CLI deployment exists in the `Microsoft.ContainerService/managedClusters/agentPools` definition under `properties`, as shown in the following example:

    ```bicep
    properties: {
      // ...
      securityProfile: {
        enableVTPM: true
        enableSecureBoot: true
      }
    }
    ```

1. Deploy your Bicep file with vTPM and secure boot enabled on your cluster. See [Deploy an AKS cluster using a Bicep file][quick-bicep-deploy] for detailed instructions.
:::zone-end
:::zone target="docs" pivot="terraform"

1. Create a Terraform configuration with Trusted Launch settings by using the [`azurerm_kubernetes_cluster_node_pool`][terraform-azurerm-kubernetes-cluster-node-pool] resource. Before creating the configuration, review the following parameters in the `security` block:

   * `secure_boot_enabled`: Enables Secure Boot to authenticate an image signed by a trusted publisher.
   * `vtpm_enabled`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    The following example adds a node pool named *mynodepool* with three nodes, and enables vTPM and Secure Boot:

    ```terraform
    resource "azurerm_kubernetes_cluster_node_pool" "example" {
      name                  = "mynodepool"
      kubernetes_cluster_id = azurerm_kubernetes_cluster.example.id
      vm_size               = "Standard_D2s_v3"
      node_count            = 3

      security {
        secure_boot_enabled = true
        vtpm_enabled        = true
      }
    }
    ```

1. Apply your Terraform configuration by using the `terraform plan` and `terraform apply` commands.

1. Check that your node pool uses a Trusted Launch image.

    Trusted Launch nodes have the following output:

    * Node image version containing `"TL"`, such as `"AKSUbuntu-2204-gen2TLcontainerd"`.
    * `"Security-type"` is `"Trusted Launch"`.

    ```bash
    kubectl get nodes
    kubectl describe node {node-name} | grep -e node-image-version -e security-type
    ```

:::zone-end
:::zone target="docs" pivot="azure-portal"

The Azure portal **doesn't support** adding a Linux node pool with Trusted Launch enabled. To add a Linux node pool with Trusted Launch enabled, use the Azure CLI, ARM template, Bicep, or Terraform instructions in this article.
:::zone-end

## Add a Windows Server node pool with Trusted Launch and FIPS enabled

Windows Server node pools with Trusted Launch enabled are currently in preview.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Use an existing cluster configured for Windows node pools, including a Windows profile and Azure CNI networking. For the Windows profile requirement, see [Node pool limitations](./create-node-pools.md#limitations).

Before you add a Windows node pool with Trusted Launch enabled, register the `WindowsTrustedLaunchPreview` feature flag on your subscription.

1. Register the `WindowsTrustedLaunchPreview` feature flag by using the [`az feature register`][az-feature-register] command. Registration can take several minutes.

    ```azurecli-interactive
    az feature register \
        --namespace "Microsoft.ContainerService" \
        --name "WindowsTrustedLaunchPreview"
    ```

1. Verify the registration status by using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show \
        --namespace "Microsoft.ContainerService" \
        --name "WindowsTrustedLaunchPreview" \
        --query "properties.state"
    ```

1. When the status is `Registered`, refresh the registration of the `Microsoft.ContainerService` resource provider by using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace "Microsoft.ContainerService"
    ```

:::zone target="docs" pivot="azure-cli"

Use Azure CLI version 2.87.0 or later for this Windows Server 2025 procedure. Run `az --version` to check your version and `az upgrade` to upgrade.

1. Add a Windows Server 2025 node pool with Trusted Launch enabled using the [`az aks nodepool add`][az-aks-nodepool-add] command. Before running the command, review the following parameters:

   * `--cluster-name`: Enter the name of the AKS cluster.
   * `--resource-group`: Enter the name of an existing resource group to host the AKS cluster resource.
   * `--name`: Enter a unique name for the node pool. For Windows node pools, the length must be between 1 and 6 characters.
   * `--node-count`: The number of nodes in the Kubernetes agent pool. Default is 3.
   * `--os-type`: Set to `Windows`.
   * `--os-sku`: Set to `Windows2025`.
   * `--enable-secure-boot`: Enables Secure Boot to authenticate image signed by a trusted publisher.
   * `--enable-vtpm`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.
   * `--enable-fips-image`: Required for Windows Server 2025 node pools.

    The following example deploys a Windows Server 2025 node pool named *npwin* with vTPM, Secure Boot, and FIPS enabled on a cluster named *myAKSCluster*:

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name npwin \
        --node-count 3 \
        --os-type Windows \
        --os-sku Windows2025 \
        --enable-fips-image \
        --enable-vtpm \
        --enable-secure-boot
    ```

1. Check that your node pool is using a Trusted Launch image.

    Trusted Launch Windows nodes have the following output:

    * Node image version containing `"tl"`, such as `"AKSWindows-2025-gen2-tl-26100.<build>.<YYMMDD>"`.
    * The `kubernetes.azure.com/security-type` label is `TrustedLaunch`.

    ```bash
    kubectl get nodes
    kubectl describe node {node-name} | grep -e node-image-version -e security-type
    ```

:::zone-end

:::zone target="docs" pivot="arm"
1. Create a template with Trusted Launch and FIPS parameters. Before creating the template, review the following parameters:

   * `osType`: Set to `Windows`.
   * `osSKU`: Set to `Windows2025`.
   * `enableFIPS`: Enables the FIPS-compliant node image. Required for Windows Server 2025.
   * `enableSecureBoot`: Enables secure boot to authenticate an image signed by a trusted publisher.
   * `enableVTPM`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    In your template, configure the `properties` of the `Microsoft.ContainerService/managedClusters/agentPools` resource as shown in the following example. Use a generation 2 VM size that supports Trusted Launch:

    ```json
    {
        "properties": {
            "count": 3,
            "mode": "User",
            "osType": "Windows",
            "osSKU": "Windows2025",
            "vmSize": "Standard_D4s_v5",
            "type": "VirtualMachineScaleSets",
            "enableFIPS": true,
            "securityProfile": {
                "enableVTPM": true,
                "enableSecureBoot": true
            }
        }
    }
    ```

1. Deploy your template to add the Windows node pool to your cluster. See [Deploy an AKS cluster using an ARM template][quick-ARM-deploy] for detailed deployment instructions.
:::zone-end

:::zone target="docs" pivot="bicep"

Use an existing cluster configured for Windows node pools, including a Windows profile and Azure CNI networking. For the Windows profile requirement, see [Node pool limitations](./create-node-pools.md#limitations).

1. Create a file named `windows-trusted-launch.bicep` with the following content. The example uses API version `2026-08-01` and adds a Windows Server 2025 user node pool to an existing cluster:

    ```bicep
    param clusterName string
    param nodePoolName string = 'npwin'
    param vmSize string = 'Standard_D4s_v5'

    resource aksCluster 'Microsoft.ContainerService/managedClusters@2026-08-01' existing = {
      name: clusterName
    }

    resource windowsNodePool 'Microsoft.ContainerService/managedClusters/agentPools@2026-08-01' = {
      parent: aksCluster
      name: nodePoolName
      properties: {
        count: 3
        mode: 'User'
        osType: 'Windows'
        osSKU: 'Windows2025'
        vmSize: vmSize
        type: 'VirtualMachineScaleSets'
        enableFIPS: true
        securityProfile: {
          enableVTPM: true
          enableSecureBoot: true
        }
      }
    }
    ```

    During preview, Bicep might report warning `BCP081` if its type catalog doesn't include API version `2026-08-01`. This warning means Bicep can't validate the resource properties against its type catalog; it doesn't prevent compiling or deploying the template.

    Use a generation 2 VM size that supports Trusted Launch and is available in your subscription and region. To use a different size, pass `vmSize=<vm-size>` to the deployment command.

1. Deploy the Bicep file to the resource group that contains your cluster. Replace `myResourceGroup` and `myAKSCluster` with your resource group and cluster names.

    ```azurecli-interactive
    az deployment group create \
        --resource-group myResourceGroup \
        --template-file windows-trusted-launch.bicep \
        --parameters clusterName=myAKSCluster
    ```

1. Verify that FIPS, Secure Boot, and vTPM are enabled on the node pool. Confirm that all three values are `true`. If you changed the `nodePoolName` parameter, replace `npwin` with that name.

    ```azurecli-interactive
    az aks nodepool show \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name npwin \
        --query "{fips:enableFips,secureBoot:securityProfile.enableSecureBoot,vtpm:securityProfile.enableVtpm}" \
        --output table
    ```

:::zone-end

:::zone target="docs" pivot="terraform"

This article doesn't include Terraform instructions for Windows Server node pools with Trusted Launch (preview). To add a Windows node pool with Trusted Launch enabled, use the Azure CLI, ARM template, or Bicep instructions in this article.

:::zone-end

:::zone target="docs" pivot="azure-portal"

The Azure portal **doesn't support** adding a Windows node pool with Trusted Launch enabled. To add a Windows node pool with Trusted Launch enabled, use the Azure CLI, ARM template, or Bicep instructions in this article.

:::zone-end

## Add a Linux node pool with Trusted Launch and FIPS enabled

For Linux node pools, you can enable Trusted Launch and FIPS together for Ubuntu 22.04 and Azure Container Linux (ACL) node pools on Generation 2 VM sizes.

For Windows Server 2025 node pools, FIPS is enabled by default. To add a Windows Server 2025 node pool with Trusted Launch enabled, see [Add a Windows Server node pool with Trusted Launch and FIPS enabled](#add-a-windows-server-node-pool-with-trusted-launch-and-fips-enabled).

For FIPS-specific operations, such as disabling FIPS on an existing node pool, see [Enable Federal Information Processing Standard (FIPS) for Azure Kubernetes Service (AKS) node pools][FIPS].

:::zone target="docs" pivot="azure-cli"
1. Add a Linux node pool with Trusted Launch and FIPS enabled by using the [`az aks nodepool add`][az-aks-nodepool-add] command. Before running the command, review the following parameters:

   * `--cluster-name`: Enter the name of the AKS cluster.
   * `--resource-group`: Enter the name of an existing resource group to host the AKS cluster resource.
   * `--name`: Enter a unique name for the node pool. The name of a node pool can only contain lowercase alphanumeric characters and must begin with a lowercase letter. For Linux node pools, the length must be between 1 and 11 characters.
   * `--node-count`: The number of nodes in the Kubernetes agent pool. Default is 3.
   * `--enable-secure-boot`: Enables Secure Boot to authenticate image signed by a trusted publisher.
   * `--enable-vtpm`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.
   * `--enable-fips-image`: Enables the FIPS-compliant node image for the node pool.
   * `--os-sku`: Optional. Set to `AzureContainerLinux` to create an ACL node pool with Trusted Launch and FIPS enabled.

    > [!NOTE]
    > Secure Boot requires signed boot loaders, OS kernels, and drivers. If after enabling Secure Boot your nodes don't start, you can verify which boot components are responsible for Secure Boot failures within an Azure Linux Virtual Machine. See [verify Secure Boot failures][verify-secure-boot-failures].

    The following example deploys a node pool with vTPM, Secure Boot, and FIPS enabled on a cluster named *myAKSCluster* with three nodes:

    ```azurecli-interactive
    az aks nodepool add --resource-group myResourceGroup --cluster-name myAKSCluster --name mynodepool --node-count 3 --enable-vtpm --enable-secure-boot --enable-fips-image
    ```

    To create the node pool with ACL, add `--os-sku AzureContainerLinux`.
1. Check that your node pool uses a Trusted Launch image.

    Trusted Launch nodes have the following output:

    * Node image version containing both `"TL"` and `"FIPS"`.
    * The `kubernetes.azure.com/security-type` label is `TrustedLaunch`.

    ```bash
    kubectl get nodes
    kubectl describe node {node-name} | grep -e node-image-version -e security-type
    ```

:::zone-end
:::zone target="docs" pivot="arm"
1. Create a template with Trusted Launch and FIPS parameters. Before creating the template, review the following parameters:

   * `enableSecureBoot`: Enables secure boot to authenticate an image signed by a trusted publisher.
   * `enableVTPM`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.
   * `enableFips`: Enables the FIPS-compliant node image for the node pool.
   * `osSKU`: Optional. Set to `AzureContainerLinux` to create an ACL node pool with Trusted Launch and FIPS enabled.

    In your template, provide values for `enableVTPM`, `enableSecureBoot`, and `enableFips`. The same schema used for CLI deployment exists in the `Microsoft.ContainerService/managedClusters/agentPools` definition under `"properties"`, as shown in the following example:

    ```json
    "properties": {
        ...,
        "osSKU": "Ubuntu",
        "enableFips": true,
        "securityProfile": {
            "enableVTPM": true,
            "enableSecureBoot": true,
        }
    }
    ```

1. Deploy your template with vTPM, secure boot, and FIPS enabled on your cluster. To create the node pool with ACL, set `"osSKU": "AzureContainerLinux"`. See [Deploy an AKS cluster using an ARM template][quick-ARM-deploy] for detailed instructions.
:::zone-end
:::zone target="docs" pivot="bicep"
1. Create a Bicep file with Trusted Launch and FIPS parameters. Before creating the file, review the following parameters:

   * `enableSecureBoot`: Enables secure boot to authenticate an image signed by a trusted publisher.
   * `enableVTPM`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.
   * `enableFips`: Enables the FIPS-compliant node image for the node pool.
   * `osSKU`: Optional. Set to `AzureContainerLinux` to create an ACL node pool with Trusted Launch and FIPS enabled.

    In your Bicep file, provide values for `enableVTPM`, `enableSecureBoot`, and `enableFips`. The same schema used for CLI deployment exists in the `Microsoft.ContainerService/managedClusters/agentPools` definition under `properties`, as shown in the following example:

    ```bicep
    properties: {
      // ...
      osSKU: 'Ubuntu'
      enableFips: true
      securityProfile: {
        enableVTPM: true
        enableSecureBoot: true
      }
    }
    ```

1. Deploy your Bicep file with vTPM, secure boot, and FIPS enabled on your cluster. To create the node pool with ACL, set `osSKU: 'AzureContainerLinux'`. See [Deploy an AKS cluster using a Bicep file][quick-bicep-deploy] for detailed instructions.
:::zone-end
:::zone target="docs" pivot="terraform"

1. Create a Terraform configuration with Trusted Launch and FIPS settings by using the [`azurerm_kubernetes_cluster_node_pool`][terraform-azurerm-kubernetes-cluster-node-pool] resource. Before creating the configuration, review the following parameters:

   * `secure_boot_enabled`: Enables Secure Boot to authenticate an image signed by a trusted publisher.
   * `vtpm_enabled`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.
   * `fips_enabled`: Enables the FIPS-compliant node image for the node pool.
   * `os_sku`: Set to `Ubuntu2204` to create an Ubuntu 22.04 node pool.

    The following example adds a node pool named *mynodepool* with three nodes, and enables vTPM, Secure Boot, and FIPS:

    ```terraform
    resource "azurerm_kubernetes_cluster_node_pool" "example" {
      name                  = "mynodepool"
      kubernetes_cluster_id = azurerm_kubernetes_cluster.example.id
      vm_size               = "Standard_D2s_v3"
      node_count            = 3
      os_sku                = "Ubuntu2204"
      fips_enabled          = true

      security {
        secure_boot_enabled = true
        vtpm_enabled        = true
      }
    }
    ```

    > [!NOTE]
    > The AzureRM Terraform provider doesn't support the `AzureContainerLinux` OS SKU. To add an ACL node pool with Trusted Launch and FIPS enabled, use the Azure CLI, ARM template, or Bicep instructions in this article.

1. Apply your Terraform configuration by using the `terraform plan` and `terraform apply` commands.

1. Check that your node pool uses a Trusted Launch image.

    Trusted Launch nodes have the following output:

    * Node image version containing both `"TL"` and `"FIPS"`.
    * `"Security-type"` is `"Trusted Launch"`.

    ```bash
    kubectl get nodes
    kubectl describe node {node-name} | grep -e node-image-version -e security-type
    ```

:::zone-end
:::zone target="docs" pivot="azure-portal"

The Azure portal **doesn't support** adding a node pool with Trusted Launch and FIPS enabled. To add a node pool with Trusted Launch and FIPS enabled, use the Azure CLI, ARM template, Bicep, or Terraform instructions in this article.

:::zone-end

## Enable vTPM or secure boot on an existing Linux node pool

You can enable vTPM, secure boot, or both on an existing standard Linux node pool that uses a Trusted Launch-capable Ubuntu or Azure Linux image. The node pool doesn't need to already use a Trusted Launch image, but it must meet the existing Trusted Launch requirements and limitations.

AKS reimages the node pool to a Trusted Launch image, which recreates the nodes and disrupts workloads. Perform the update during a maintenance window, and make sure your workloads tolerate node reimaging.

:::zone target="docs" pivot="azure-cli"
1. Update a node pool to enable vTPM or secure boot using the [`az aks nodepool update`][az-aks-nodepool-update] command. Before running the command, review the following parameters:

    * `--resource-group`: Enter the name of an existing resource group hosting your existing AKS cluster.
    * `--cluster-name`: Enter a unique name for the AKS cluster, such as *myAKSCluster*.
    * `--name`: Enter the name of your node pool, such as *mynodepool*.
    * `--enable-secure-boot`: Enables secure boot to authenticate that the image was signed by a trusted publisher.
    * `--enable-vtpm`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    > [!NOTE]
    > Secure Boot requires signed boot loaders, OS kernels, and drivers. If after enabling secure boot your nodes don't start, you can verify which boot components are responsible for Secure Boot failures within an Azure Linux Virtual Machine. See [verify Secure Boot failures][verify-secure-boot-failures].

    The following example updates the node pool *mynodepool* on *myAKSCluster* in *myResourceGroup* and enables vTPM:

    ```azurecli-interactive
    az aks nodepool update --cluster-name myAKSCluster --resource-group myResourceGroup --name mynodepool --enable-vtpm
    ```

    The following example updates the node pool *mynodepool* on *myAKSCluster* in *myResourceGroup* and enables secure boot:

    ```azurecli-interactive
    az aks nodepool update --cluster-name myAKSCluster --resource-group myResourceGroup --name mynodepool --enable-secure-boot
    ```

    The following example updates the node pool *mynodepool* on *myAKSCluster* in *myResourceGroup* and enables both vTPM and secure boot:

    ```azurecli-interactive
    az aks nodepool update \
        --cluster-name myAKSCluster \
        --resource-group myResourceGroup \
        --name mynodepool \
        --enable-vtpm \
        --enable-secure-boot
    ```

1. After the update completes, verify that your node pool uses a Trusted Launch image.

    Trusted Launch nodes have the following output:

    * Node image version containing `"TL"`, such as `"AKSUbuntu-2204-gen2TLcontainerd"`.
    * The `kubernetes.azure.com/security-type` label is `TrustedLaunch`.

    ```bash
    kubectl get nodes
    kubectl describe node {node-name} | grep -e node-image-version -e security-type
    ```

:::zone-end
:::zone target="docs" pivot="arm"
1. Update your ARM template with Trusted Launch parameters. Before updating the template, review the following parameters:

   * `enableSecureBoot`: Enables secure boot to authenticate an image signed by a trusted publisher.
   * `enableVTPM`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    In your template, set `enableVTPM`, `enableSecureBoot`, or both in the node pool `securityProfile`. The following example enables both vTPM and secure boot:

    ```json
    "properties": {
        ...,
        "securityProfile": {
            "enableVTPM": true,
            "enableSecureBoot": true,
        }
    }
    ```

1. Deploy your updated template with vTPM and secure boot enabled on your node pool. For detailed instructions, see [Deploy an AKS cluster using an ARM template][quick-ARM-deploy].

1. After the deployment completes, verify that your node pool uses a Trusted Launch image.

    Trusted Launch nodes have the following output:

    * Node image version containing `"TL"`, such as `"AKSUbuntu-2204-gen2TLcontainerd"`.
    * The `kubernetes.azure.com/security-type` label is `TrustedLaunch`.

    ```bash
    kubectl get nodes
    kubectl describe node {node-name} | grep -e node-image-version -e security-type
    ```

:::zone-end
:::zone target="docs" pivot="bicep"
1. Update your Bicep file with Trusted Launch parameters. Before updating the file, review the following parameters:

   * `enableSecureBoot`: Enables secure boot to authenticate an image signed by a trusted publisher.
   * `enableVTPM`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    In your Bicep file, set `enableVTPM`, `enableSecureBoot`, or both in the node pool `securityProfile`. The following example enables both vTPM and secure boot:

    ```bicep
    properties: {
      // ...
      securityProfile: {
        enableVTPM: true
        enableSecureBoot: true
      }
    }
    ```

1. Deploy your updated Bicep file with vTPM and secure boot enabled on your node pool. For detailed instructions, see [Deploy an AKS cluster using a Bicep file][quick-bicep-deploy].

1. After the deployment completes, verify that your node pool uses a Trusted Launch image.

    Trusted Launch nodes have the following output:

    * Node image version containing `"TL"`, such as `"AKSUbuntu-2204-gen2TLcontainerd"`.
    * The `kubernetes.azure.com/security-type` label is `TrustedLaunch`.

    ```bash
    kubectl get nodes
    kubectl describe node {node-name} | grep -e node-image-version -e security-type
    ```

:::zone-end
:::zone target="docs" pivot="terraform"

1. Update your Terraform configuration with Trusted Launch settings. Before updating the configuration, review the following parameters in the `security` block of your `azurerm_kubernetes_cluster_node_pool` resource, or the `default_node_pool.security` block of your `azurerm_kubernetes_cluster` resource:

   * `secure_boot_enabled`: Enables Secure Boot to authenticate an image signed by a trusted publisher.
   * `vtpm_enabled`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    Set `vtpm_enabled`, `secure_boot_enabled`, or both. The following example enables both vTPM and Secure Boot on an existing node pool:

    ```terraform
    resource "azurerm_kubernetes_cluster_node_pool" "example" {
      # ...

      security {
        secure_boot_enabled = true
        vtpm_enabled        = true
      }
    }
    ```

1. Apply your updated Terraform configuration by using the `terraform plan` and `terraform apply` commands. Terraform updates the node pool in place, and AKS reimages the nodes.

1. After the update completes, verify that your node pool uses a Trusted Launch image.

    Trusted Launch nodes have the following output:

    * Node image version containing `"TL"`, such as `"AKSUbuntu-2204-gen2TLcontainerd"`.
    * `"Security-type"` is `"Trusted Launch"`.

    ```bash
    kubectl get nodes
    kubectl describe node {node-name} | grep -e node-image-version -e security-type
    ```

:::zone-end
:::zone target="docs" pivot="azure-portal"

The Azure portal **doesn't support** enabling vTPM or secure boot on an existing node pool. To enable vTPM or secure boot on an existing node pool, use the Azure CLI, ARM template, Bicep, or Terraform instructions in this article.

:::zone-end

## Assign pods to nodes with Trusted Launch enabled

You can constrain a pod and restrict it to run on a specific node or nodes, or preference to nodes with Trusted Launch enabled. You can control this using the following node pool selector in your pod manifest.

```yml
spec:
  nodeSelector:
    kubernetes.azure.com/security-type: TrustedLaunch
```

## Disable vTPM or secure boot on an existing Linux node pool

You can disable vTPM, secure boot, or both on an existing Linux node pool. If either feature remains enabled, the node pool keeps using the Trusted Launch image path. If you disable both features on a regular Ubuntu or Azure Linux node pool, AKS reimages the node pool to the corresponding non-Trusted Launch image and changes the underlying Virtual Machine Scale Set security type back to Standard.

:::zone target="docs" pivot="azure-cli"
1. Update a node pool to disable secure boot or vTPM by using the [`az aks nodepool update`][az-aks-nodepool-update] command. Before running the command, review the following parameters:

   * `--resource-group`: Enter the name of an existing resource group hosting your existing AKS cluster.
   * `--cluster-name`: Enter a unique name for the AKS cluster, such as *myAKSCluster*.
   * `--name`: Enter the name of your node pool, such as *mynodepool*.
   * `--disable-secure-boot`: Disables secure boot.
   * `--disable-vtpm`: Disables vTPM.

    The following example updates the node pool *mynodepool* on *myAKSCluster* in *myResourceGroup* and disables vTPM:

    ```azurecli-interactive
    az aks nodepool update --cluster-name myAKSCluster --resource-group myResourceGroup --name mynodepool --disable-vtpm
    ```

    The following example updates the node pool *mynodepool* on *myAKSCluster* in *myResourceGroup* and disables secure boot:

    ```azurecli-interactive
    az aks nodepool update --cluster-name myAKSCluster --resource-group myResourceGroup --name mynodepool --disable-secure-boot
    ```

    The following example updates the node pool *mynodepool* on *myAKSCluster* in *myResourceGroup* and disables both vTPM and secure boot:

    ```azurecli-interactive
    az aks nodepool update \
        --cluster-name myAKSCluster \
        --resource-group myResourceGroup \
        --name mynodepool \
        --disable-vtpm \
        --disable-secure-boot
    ```

1. After the update completes, verify that your node pool uses the expected image.

    If either vTPM or secure boot remains enabled, Trusted Launch nodes have the following output:

    * Node image version containing `"TL"`, such as `"AKSUbuntu-2204-gen2TLcontainerd"`.
    * The `kubernetes.azure.com/security-type` label is `TrustedLaunch`.

    If you disable both vTPM and secure boot, the node image version shouldn't contain `"TL"`, and the `kubernetes.azure.com/security-type` label shouldn't be `TrustedLaunch`.

    ```bash
    kubectl get nodes
    kubectl describe node {node-name} | grep -e node-image-version -e security-type
    ```
:::zone-end
:::zone target="docs" pivot="arm"
1. Update your ARM template with Trusted Launch parameters. Before updating the template, review the following parameters:

   * `enableSecureBoot`: Enables secure boot to authenticate an image signed by a trusted publisher.
   * `enableVTPM`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    In your template, set `enableVTPM`, `enableSecureBoot`, or both in the node pool `securityProfile`. The following example disables both vTPM and secure boot:

    ```json
    "properties": {
        ...,
        "securityProfile": {
            "enableVTPM": false,
            "enableSecureBoot": false,
        }
    }
    ```

1. Deploy your updated template with vTPM and secure boot disabled on your node pool. For detailed instructions, see [Deploy an AKS cluster using an ARM template][quick-ARM-deploy].

1. After the deployment completes, verify that your node pool uses the expected image.

    If either vTPM or secure boot remains enabled, Trusted Launch nodes have the following output:

    * Node image version containing `"TL"`, such as `"AKSUbuntu-2204-gen2TLcontainerd"`.
    * The `kubernetes.azure.com/security-type` label is `TrustedLaunch`.

    If you disable both vTPM and secure boot, the node image version shouldn't contain `"TL"`, and the `kubernetes.azure.com/security-type` label shouldn't be `TrustedLaunch`.

    ```bash
    kubectl get nodes
    kubectl describe node {node-name} | grep -e node-image-version -e security-type
    ```
:::zone-end
:::zone target="docs" pivot="bicep"
1. Update your Bicep file with Trusted Launch parameters. Before updating the file, review the following parameters:

   * `enableSecureBoot`: Enables secure boot to authenticate an image signed by a trusted publisher.
   * `enableVTPM`: Enables vTPM and performs attestation by measuring the entire boot chain of your VM.

    In your Bicep file, set `enableVTPM`, `enableSecureBoot`, or both in the node pool `securityProfile`. The following example disables both vTPM and secure boot:

    ```bicep
    properties: {
      // ...
      securityProfile: {
        enableVTPM: false
        enableSecureBoot: false
      }
    }
    ```

1. Deploy your updated Bicep file with vTPM and secure boot disabled on your node pool. For detailed instructions, see [Deploy an AKS cluster using a Bicep file][quick-bicep-deploy].

1. After the deployment completes, verify that your node pool uses the expected image.

    If either vTPM or secure boot remains enabled, Trusted Launch nodes have the following output:

    * Node image version containing `"TL"`, such as `"AKSUbuntu-2204-gen2TLcontainerd"`.
    * The `kubernetes.azure.com/security-type` label is `TrustedLaunch`.

    If you disable both vTPM and secure boot, the node image version shouldn't contain `"TL"`, and the `kubernetes.azure.com/security-type` label shouldn't be `TrustedLaunch`.

    ```bash
    kubectl get nodes
    kubectl describe node {node-name} | grep -e node-image-version -e security-type
    ```
:::zone-end
:::zone target="docs" pivot="terraform"

1. Update your Terraform configuration with Trusted Launch settings. Before updating the configuration, review the following parameters in the `security` block of your `azurerm_kubernetes_cluster_node_pool` resource, or the `default_node_pool.security` block of your `azurerm_kubernetes_cluster` resource:

   * `secure_boot_enabled`: Set to `false` to disable Secure Boot.
   * `vtpm_enabled`: Set to `false` to disable vTPM.

    The following example disables both vTPM and Secure Boot. Removing the `security` block also disables both features.

    ```terraform
    resource "azurerm_kubernetes_cluster_node_pool" "example" {
      # ...

      security {
        secure_boot_enabled = false
        vtpm_enabled        = false
      }
    }
    ```

1. Apply your updated Terraform configuration by using the `terraform plan` and `terraform apply` commands.

1. After the update completes, verify that your node pool uses the expected image.

    If either vTPM or secure boot remains enabled, Trusted Launch nodes have the following output:

    * Node image version containing `"TL"`, such as `"AKSUbuntu-2204-gen2TLcontainerd"`.
    * `"Security-type"` is `"Trusted Launch"`.

    If you disable both vTPM and secure boot, the node image version shouldn't contain `"TL"`, and `"Security-type"` shouldn't be `"Trusted Launch"`.

    ```bash
    kubectl get nodes
    kubectl describe node {node-name} | grep -e node-image-version -e security-type
    ```

:::zone-end
:::zone target="docs" pivot="azure-portal"

The Azure portal **doesn't support** disabling vTPM or secure boot on an existing node pool. To disable vTPM or secure boot on an existing node pool, use the Azure CLI, ARM template, Bicep, or Terraform instructions in this article.

:::zone-end

## Clean up resources

Remove test workloads before deleting their node pool. If you added a test node pool to an existing cluster, delete only that test node pool by using the [`az aks nodepool delete`][az-aks-nodepool-delete] command. Replace `<node-pool-name>` with the name of the test node pool you created, such as `npwin` or `mynodepool`. Don't delete node pools that host workloads you need to keep.

```azurecli-interactive
az aks nodepool delete \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name <node-pool-name>
```

If you created a cluster and resource group solely for this article, delete the test resource group by using the [`az group delete`][az-group-delete] command. **This command deletes every resource in the resource group. Don't run it against a shared or pre-existing resource group.**

```azurecli-interactive
az group delete --name myResourceGroup --yes --no-wait
```

## Next steps

In this article, you learned how to enable Trusted Launch. Learn more about [Trusted Launch][trusted-launch-overview].

<!-- EXTERNAL LINKS -->

<!-- INTERNAL LINKS -->
[install-azure-cli]: /cli/azure/install-azure-cli
[az-feature-register]: /cli/azure/feature#az-feature-register
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
[az-aks-nodepool-delete]: /cli/azure/aks/nodepool#az-aks-nodepool-delete
[az-group-delete]: /cli/azure/group#az-group-delete
[azure-generation-two-virtual-machines]: /azure/virtual-machines/generation-2
[verify-secure-boot-failures]: /azure/virtual-machines/trusted-launch-faq#verify-secure-boot-failures
[tusted-launch-ephemeral-os-sizes]: /azure/virtual-machines/ephemeral-os-disks#trusted-launch-for-ephemeral-os-disks
[skip-gpu-driver-install]: gpu-cluster.md#skip-gpu-driver-installation
[use-nvidia-gpu]: ./use-nvidia-gpu.md
[FIPS]: ./enable-fips-nodes.md
[Arm64]: ./use-arm64-vms.md
[pod-sandboxing]: ./use-pod-sandboxing.md
[CVM]: ./use-cvm.md
[node-images]: ./node-images.md
[quick-ARM-deploy]: /azure/aks/learn/quick-kubernetes-deploy-rm-template
[quick-bicep-deploy]: /azure/aks/learn/quick-kubernetes-deploy-bicep
[flatcar]: ./flatcar-container-linux-for-aks.md
