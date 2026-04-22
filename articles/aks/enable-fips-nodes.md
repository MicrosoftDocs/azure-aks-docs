---
title: Enable Federal Information Processing Standard (FIPS) for Azure Kubernetes Service (AKS) Node Pools
description: Learn how to enable Federal Information Processing Standard (FIPS) for Azure Kubernetes Service (AKS) node pools.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to 
ms.date: 04/10/2026
ms.custom: template-how-to, linux-related-content
ai-usage: ai-assisted
zone_pivot_groups: azure-cli-arm-bicep-terraform-portal
# Customer intent: "As a cloud administrator, I want to enable FIPS compliance for AKS node pools, so that I can ensure the security of cryptographic modules and meet regulatory requirements while deploying applications."
---

# Enable Federal Information Processing Standard (FIPS) for Azure Kubernetes Service (AKS) node pools

The Federal Information Processing Standard (FIPS) 140-2 is a US government standard that defines minimum security requirements for cryptographic modules in information technology products and systems. Azure Kubernetes Service (AKS) allows you to create Linux and Windows node pools with FIPS 140-2 enabled. Deployments running on FIPS-enabled node pools can use those cryptographic modules to provide increased security and help meet security controls as part of FedRAMP compliance. For more information on FIPS 140-2, see [Federal Information Processing Standard (FIPS) 140][fips].

[!INCLUDE [ubuntu 20.04 retirement](./includes/ubuntu-20-04-retirement.md)]

[!INCLUDE [azure linux 2.0 retirement](./includes/azure-linux-retirement.md)]

## Prerequisites

- An active Azure subscription. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/) before you begin.
- Set your subscription context using the [`az account set`][az-account-set] command. For example:

  ```azurecli-interactive
  az account set --subscription "00000000-0000-0000-0000-000000000000"
  ```

- [kubectl](https://kubernetes.io/releases/download/) installed. You can install it locally using the [`az aks install-cli`][az-aks-install-cli] command.

:::zone pivot="terraform"

- Terraform installed locally. For installation instructions, see [Install Terraform](https://developer.hashicorp.com/terraform/install).

:::zone-end

### Version compatibility

:::zone pivot="azure-cli"

- Azure CLI version 2.32.0 or later installed and configured. To find the version, run `az --version`. For more information about installing or upgrading the Azure CLI, see [Install Azure CLI][install-azure-cli].

:::zone-end

:::zone pivot="arm"

- ARM template examples in this article use API version `2023-03-01` for `Microsoft.ContainerService/managedClusters` and `Microsoft.ContainerService/managedClusters/agentPools`.

:::zone-end

:::zone pivot="bicep"

- Bicep examples in this article use API version `2023-03-01` for `Microsoft.ContainerService/managedClusters` and `Microsoft.ContainerService/managedClusters/agentPools`.

:::zone-end

:::zone pivot="terraform"

- Terraform examples in this article use the AzureRM provider 3.x.
- For Terraform FIPS settings, use `enable_fips_image` on `azurerm_kubernetes_cluster.default_node_pool` and `fips_enabled` on `azurerm_kubernetes_cluster_node_pool`.

:::zone-end

## Limitations

FIPS-enabled node pools have the following limitations:

- FIPS-enabled node pools require Kubernetes version 1.19 and greater.
- To update the underlying packages or modules used for FIPS, you must use [Node image upgrade][node-image-upgrade].
- Container images on the FIPS nodes aren't assessed for FIPS compliance.
- Mounting of a CIFS share fails because FIPS disables some authentication modules. To work around this issue, see [Errors when mounting a file share on a FIPS-enabled node pool][errors-mount-file-share-fips].
- FIPS-enabled node pools with [Arm64 VMs](./use-arm64-vms.md) are only supported with Azure Linux 3.0+.
- The AKS monitoring add-on supports FIPS-enabled node pools with Ubuntu, Azure Linux, and Windows starting with Agent version 3.1.17 (Linux) and Win-3.1.17 (Windows).

> [!IMPORTANT]
> The FIPS-enabled Linux image is a different image than the default Linux image used for Linux-based node pools.
>
> FIPS-enabled node images can have different version numbers, such as kernel version, than images that aren't FIPS-enabled. The update cycle for FIPS-enabled node pools and node images can differ from node pools and images that aren't FIPS-enabled.

## Supported OS versions

You can create FIPS-enabled node pools on all supported OS types (Linux and Windows). However, not all OS versions support FIPS-enabled node pools. After a new OS version is released, there's typically a waiting period before it's FIPS compliant.

The following table includes the supported OS versions for FIPS-enabled node pools:

| OS type | OS SKU | FIPS compliance | Default |
| ------- | ------ | --------------- | ------- |
| Linux | Ubuntu | Supported | Disabled by default |
| Linux | Azure Linux | Supported | Disabled by default |
| Windows | Windows Server 2022 | Supported | Enabled by default |
| Windows | Windows Server 2025 | Supported | Enabled by default and can't be disabled |

When requesting FIPS-enabled Ubuntu, if the default Ubuntu version doesn't support FIPS, AKS defaults to the most recent FIPS-supported version of Ubuntu. For example, Ubuntu 22.04 is default for Linux node pools. Since 22.04 doesn't currently support FIPS, AKS defaults to Ubuntu 20.04 for Linux FIPS-enabled node pools.

> [!NOTE]
> Previously, you could use the `GetOSOptions` API to determine whether a given OS supported FIPS. The `GetOSOptions` API is now deprecated and is no longer included in new AKS API versions starting with 2024-05-01.

:::zone pivot="terraform"

## Create the Terraform configuration file

Terraform configuration files define the infrastructure that Terraform creates and manages.

1. Create a file named `main.tf` and add the following code to define the Terraform version and specify the Azure provider:

    ```Terraform
    terraform {
      required_version = ">= 1.0"
    
      required_providers {
        azurerm = {
          source  = "hashicorp/azurerm"
          version = "~> 3.0"
        }
      }
    }
    
    provider "azurerm" {
      features {}
    }
    ```

1. Add the following code to `main.tf` to create an Azure resource group. Feel free to change the name and location of the resource group as needed.

    ```Terraform
    resource "azurerm_resource_group" "example" {
      name     = "example-fips-rg"
      location = "East US"
    }
    ```

:::zone-end

## Create an AKS cluster with a FIPS-enabled default node pool

You can enable FIPS on the default node pool when creating a new AKS cluster.

:::zone pivot="azure-cli"

When creating more node pools on a cluster that already has a FIPS-enabled default node pool, you must also enable FIPS on the new node pools using the `--enable-fips-image` parameter.

1. Create an AKS cluster with FIPS enabled on the default node pool using the [`az aks create`][az-aks-create] command with the `--enable-fips-image` parameter.

    ```azurecli-interactive
    az aks create \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --node-count 3 \
        --enable-fips-image
    ```

1. Verify your node pool is FIPS-enabled using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

    The following example output shows the default node pool is FIPS-enabled:

    ```output
    Name       enableFips
    ---------  ------------
    nodepool1  True
    ```

:::zone-end

:::zone pivot="azure-portal"

Enabling FIPS during AKS cluster creation currently **isn't supported in the Azure portal**. To create a cluster with a FIPS-enabled default node pool, use the Azure CLI, ARM template, Bicep, or Terraform instructions in this article.

:::zone-end

:::zone pivot="arm"

When creating more node pools on a cluster that already has a FIPS-enabled default node pool, you must also enable FIPS on the new node pools by setting `enableFips` to `true`.

1. Create an AKS cluster with FIPS enabled on the default node pool using an ARM template by setting the `enableFips` property to `true` in the agent pool profile. For example:

    ```json
    {
      "type": "Microsoft.ContainerService/managedClusters",
      "location": "[parameters('location')]",
      "name": "[parameters('clusterName')]",
      "properties": {
        "kubernetesVersion": "1.27",
        "enableRBAC": true,
        "dnsPrefix": "[parameters('dnsPrefix')]",
        "agentPoolProfiles": [
          {
            "name": "nodepool1",
            "count": 3,
            "vmSize": "Standard_D2s_v3",
            "osType": "Linux",
            "osSKU": "Ubuntu",
            "type": "VirtualMachineScaleSets",
            "mode": "System",
            "enableFips": true
          }
        ]
      },
      "identity": {
        "type": "SystemAssigned"
      }
    }
    ```

1. Deploy the ARM template using the [Azure portal][azure-portal], Azure CLI, or Azure PowerShell. For more information on deploying ARM templates, see [Deploy resources with ARM templates][arm-templates-deploy].
1. Verify your node pool is FIPS-enabled using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

    The following example output shows the default node pool is FIPS-enabled:

    ```output
    Name       enableFips
    ---------  ------------
    nodepool1  True
    ```

:::zone-end

:::zone pivot="bicep"

When creating more node pools on a cluster that already has a FIPS-enabled default node pool, you must also enable FIPS on the new node pools by setting `enableFIPS` to `true`.

1. Create an AKS cluster with FIPS enabled on the default node pool using Bicep by setting `enableFIPS` to `true` in the agent pool profile. For example:

    ```bicep
    param location string
    param clusterName string
    param dnsPrefix string
    
    resource aks 'Microsoft.ContainerService/managedClusters@2023-03-01' = {
      name: clusterName
      location: location
      identity: {
        type: 'SystemAssigned'
      }
      properties: {
        kubernetesVersion: '1.27'
        enableRBAC: true
        dnsPrefix: dnsPrefix
        agentPoolProfiles: [
          {
            name: 'nodepool1'
            count: 3
            vmSize: 'Standard_D2s_v3'
            osType: 'Linux'
            osSKU: 'Ubuntu'
            type: 'VirtualMachineScaleSets'
            mode: 'System'
            enableFIPS: true
          }
        ]
      }
    }
    ```

1. Deploy the Bicep file using the Azure CLI, Azure PowerShell, or the [Azure portal][azure-portal]. For more information on deploying Bicep files, see [Create Bicep files using Visual Studio Code](/azure/azure-resource-manager/bicep/quickstart-create-bicep-use-visual-studio-code).
1. Verify your node pool is FIPS-enabled using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

    The following example output shows the default node pool is FIPS-enabled:

    ```output
    Name       enableFips
    ---------  ------------
    nodepool1  True
    ```

:::zone-end

:::zone pivot="terraform"

When creating more node pools on a cluster that already has a FIPS-enabled default node pool, you must also enable FIPS on the new node pools by setting `fips_enabled` to `true` on `azurerm_kubernetes_cluster_node_pool`.

1. Add the following code to `main.tf` to create an AKS cluster with FIPS enabled on the default node pool:

    ```Terraform
    resource "azurerm_kubernetes_cluster" "example" {
      name                = "example-aks-cluster"
      location            = azurerm_resource_group.example.location
      resource_group_name = azurerm_resource_group.example.name
      dns_prefix          = "example-aks"
    
      default_node_pool {
        name              = "nodepool1"
        node_count        = 3
        vm_size           = "Standard_D2s_v3"
        os_sku            = "Ubuntu"
        enable_fips_image = true
      }
    
      identity {
        type = "SystemAssigned"
      }
    }
    ```

1. Initialize Terraform in the directory containing your `main.tf` file using the [`terraform init`][terraform-init] command.

    ```console
    terraform init
    ```

1. Create a Terraform execution plan using the [`terraform plan`][terraform-plan] command.

    ```console
    terraform plan
    ```

1. Apply the configuration using the [`terraform apply`][terraform-apply] command to deploy the cluster with a FIPS-enabled default node pool.

    ```console
    terraform apply
    ```

1. Connect to the AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials \
        --resource-group myResourceGroup \
        --name myAKSCluster
    ```

1. Verify your node pool is FIPS-enabled using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

    The following example output shows the default node pool is FIPS-enabled:

    ```output
    Name       enableFips
    ---------  ------------
    nodepool1  True
    ```

For more information on the `azurerm_kubernetes_cluster` resource, see the [Terraform Azure provider documentation][terraform-aks-cluster].

:::zone-end

## Add a FIPS-enabled Linux node pool to an existing AKS cluster

:::zone pivot="azure-cli"

1. Add a FIPS-enabled Linux node pool to an existing cluster using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--enable-fips-image` parameter.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name fipsnp \
        --enable-fips-image
    ```

1. Verify your node pool configuration using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

    The following example output shows the _fipsnp_ node pool is FIPS-enabled:

    ```output
    Name       enableFips
    ---------  ------------
    fipsnp     True
    nodepool1  False  
    ```

1. List the nodes using the `kubectl get nodes` command.

    ```bash
    kubectl get nodes
    ```

    The following example output shows a list of the nodes in the cluster. The nodes starting with `aks-fipsnp` are part of the FIPS-enabled node pool.

    ```output
    NAME                                STATUS   ROLES   AGE     VERSION
    aks-fipsnp-12345678-vmss000000      Ready    agent   6m4s    v1.19.9
    aks-fipsnp-12345678-vmss000001      Ready    agent   5m21s   v1.19.9
    aks-fipsnp-12345678-vmss000002      Ready    agent   6m8s    v1.19.9
    aks-nodepool1-12345678-vmss000000   Ready    agent   34m     v1.19.9
    ```

1. Run a deployment with an interactive session on one of the nodes in the FIPS-enabled node pool using the `kubectl debug` command.

    ```bash
    kubectl debug node/aks-fipsnp-12345678-vmss000000 -it --image=mcr.microsoft.com/dotnet/runtime-deps:6.0
    ```

1. From the interactive session output, verify the FIPS cryptographic libraries are enabled. Your output should look similar to the following example output:

    ```output
    root@aks-fipsnp-12345678-vmss000000:/# cat /proc/sys/crypto/fips_enabled
    1
    ```

   FIPS-enabled node pools also have a _kubernetes.azure.com/fips_enabled=true_ label, which deployments can use to target those node pools.

:::zone-end

:::zone pivot="azure-portal"

Enabling FIPS when adding a Linux node pool currently **isn't supported in the Azure portal**. To add a FIPS-enabled Linux node pool, use the Azure CLI, ARM template, Bicep, or Terraform instructions in this article.

:::zone-end

:::zone pivot="arm"

1. Create a FIPS-enabled Linux node pool using an ARM template by deploying an agent pool resource with the `enableFips` property set to `true`. For example:

    ```json
    {
      "type": "Microsoft.ContainerService/managedClusters/agentPools",
      "apiVersion": "2023-03-01",
      "name": "[concat(parameters('clusterName'), '/fipsnp')]",
      "properties": {
        "count": 3,
        "vmSize": "Standard_D2s_v3",
        "osType": "Linux",
        "osSKU": "Ubuntu",
        "mode": "User",
        "enableFips": true
      }
    }
    ```

1. Deploy the ARM template using the [Azure portal][azure-portal], Azure CLI, or Azure PowerShell. For more information on deploying ARM templates, see [Deploy resources with ARM templates][arm-templates-deploy].
1. Verify your node pool configuration using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

    The following example output shows the _fipsnp_ node pool is FIPS-enabled:

    ```output
    Name       enableFips
    ---------  ------------
    fipsnp     True
    nodepool1  False  
    ```

1. List the nodes using the `kubectl get nodes` command.

    ```bash
    kubectl get nodes
    ```

    The following example output shows a list of the nodes in the cluster. The nodes starting with `aks-fipsnp` are part of the FIPS-enabled node pool.

    ```output
    NAME                                STATUS   ROLES   AGE     VERSION
    aks-fipsnp-12345678-vmss000000      Ready    agent   6m4s    v1.19.9
    aks-fipsnp-12345678-vmss000001      Ready    agent   5m21s   v1.19.9
    aks-fipsnp-12345678-vmss000002      Ready    agent   6m8s    v1.19.9
    aks-nodepool1-12345678-vmss000000   Ready    agent   34m     v1.19.9
    ```

1. Run a deployment with an interactive session on one of the nodes in the FIPS-enabled node pool using the `kubectl debug` command.

    ```bash
    kubectl debug node/aks-fipsnp-12345678-vmss000000 -it --image=mcr.microsoft.com/dotnet/runtime-deps:6.0
    ```

1. From the interactive session output, verify the FIPS cryptographic libraries are enabled. Your output should look similar to the following example output:

    ```output
    root@aks-fipsnp-12345678-vmss000000:/# cat /proc/sys/crypto/fips_enabled
    1
    ```

   FIPS-enabled node pools also have a _kubernetes.azure.com/fips_enabled=true_ label, which deployments can use to target those node pools.

:::zone-end

:::zone pivot="bicep"

1. Create a FIPS-enabled Linux node pool using Bicep by deploying an agent pool resource with `enableFIPS` set to `true`. For example:

    ```bicep
    param clusterName string
    param nodePoolName string = 'fipsnp'
    
    resource nodePool 'Microsoft.ContainerService/managedClusters/agentPools@2023-03-01' = {
      name: '${clusterName}/${nodePoolName}'
      properties: {
        count: 3
        vmSize: 'Standard_D2s_v3'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        mode: 'User'
        enableFIPS: true
      }
    }
    ```

1. Deploy the Bicep file using the Azure CLI, Azure PowerShell, or the [Azure portal][azure-portal]. For more information on deploying Bicep files, see [Create Bicep files using Visual Studio Code](/azure/azure-resource-manager/bicep/quickstart-create-bicep-use-visual-studio-code).
1. Verify your node pool configuration using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

    The following example output shows the _fipsnp_ node pool is FIPS-enabled:

    ```output
    Name       enableFips
    ---------  ------------
    fipsnp     True
    nodepool1  False  
    ```

1. List the nodes using the `kubectl get nodes` command.

    ```bash
    kubectl get nodes
    ```

    The following example output shows a list of the nodes in the cluster. The nodes starting with `aks-fipsnp` are part of the FIPS-enabled node pool.

    ```output
    NAME                                STATUS   ROLES   AGE     VERSION
    aks-fipsnp-12345678-vmss000000      Ready    agent   6m4s    v1.19.9
    aks-fipsnp-12345678-vmss000001      Ready    agent   5m21s   v1.19.9
    aks-fipsnp-12345678-vmss000002      Ready    agent   6m8s    v1.19.9
    aks-nodepool1-12345678-vmss000000   Ready    agent   34m     v1.19.9
    ```

1. Run a deployment with an interactive session on one of the nodes in the FIPS-enabled node pool using the `kubectl debug` command.

    ```bash
    kubectl debug node/aks-fipsnp-12345678-vmss000000 -it --image=mcr.microsoft.com/dotnet/runtime-deps:6.0
    ```

1. From the interactive session output, verify the FIPS cryptographic libraries are enabled. Your output should look similar to the following example output:

    ```output
    root@aks-fipsnp-12345678-vmss000000:/# cat /proc/sys/crypto/fips_enabled
    1
    ```

   FIPS-enabled node pools also have a _kubernetes.azure.com/fips_enabled=true_ label, which deployments can use to target those node pools.

:::zone-end

:::zone pivot="terraform"

1. Add the following code to `main.tf` to add a FIPS-enabled Linux node pool in your AKS cluster:

    ```Terraform
    resource "azurerm_kubernetes_cluster_node_pool" "fips_linux" {
      name                   = "fipsnp"
      kubernetes_cluster_id  = azurerm_kubernetes_cluster.example.id
      vm_size                = "Standard_D2s_v3"
      os_type                = "Linux"
      os_sku                 = "Ubuntu"
      node_count             = 3
      fips_enabled           = true
    
      node_taints = []
    }
    ```

1. Apply the updated Terraform configuration using the `terraform plan` and `terraform apply` commands.

    ```console
    terraform plan
    terraform apply
    ```

1. Connect to the AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials \
        --resource-group myResourceGroup \
        --name myAKSCluster
    ```

1. Verify your node pool configuration using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

    The following example output shows the _fipsnp_ node pool is FIPS-enabled:

    ```output
    Name       enableFips
    ---------  ------------
    fipsnp     True
    nodepool1  False  
    ```

1. List the nodes using the `kubectl get nodes` command.

    ```bash
    kubectl get nodes
    ```

    The following example output shows a list of the nodes in the cluster. The nodes starting with `aks-fipsnp` are part of the FIPS-enabled node pool.

    ```output
    NAME                                STATUS   ROLES   AGE     VERSION
    aks-fipsnp-12345678-vmss000000      Ready    agent   6m4s    v1.19.9
    aks-fipsnp-12345678-vmss000001      Ready    agent   5m21s   v1.19.9
    aks-fipsnp-12345678-vmss000002      Ready    agent   6m8s    v1.19.9
    aks-nodepool1-12345678-vmss000000   Ready    agent   34m     v1.19.9
    ```

1. Run a deployment with an interactive session on one of the nodes in the FIPS-enabled node pool using the `kubectl debug` command.

    ```bash
    kubectl debug node/aks-fipsnp-12345678-vmss000000 -it --image=mcr.microsoft.com/dotnet/runtime-deps:6.0
    ```

1. From the interactive session output, verify the FIPS cryptographic libraries are enabled. Your output should look similar to the following example output:

    ```output
    root@aks-fipsnp-12345678-vmss000000:/# cat /proc/sys/crypto/fips_enabled
    1
    ```

   FIPS-enabled node pools also have a _kubernetes.azure.com/fips_enabled=true_ label, which deployments can use to target those node pools.

For more information on the `azurerm_kubernetes_cluster_node_pool` resource, see the [Terraform Azure provider documentation][terraform-aks-node-pool].

:::zone-end

## Add a FIPS-enabled Windows node pool

In this section, we add a Windows node pool to an existing AKS cluster. **Windows Server 2022 and later node pools enable FIPS by default even if `enableFips` doesn't show `True`**. **Windows Server 2025 and later node pools don't support disabling FIPS**.

:::zone pivot="azure-cli"

1. Create a Windows node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command. Unlike Linux-based node pools, Windows node pools share the same image set.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name fipsnp \
        --enable-fips-image \
        --os-type Windows
    ```

1. Verify your node pool configuration using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

1. Verify Windows node pools have access to FIPS cryptographic libraries by [creating an RDP connection to a Windows node][aks-rdp] in a node pool and checking the registry. From the **Run** application, enter `regedit`.
1. Look for `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa\FIPSAlgorithmPolicy` in the registry.
1. If `Enabled` is set to _1_, then FIPS is enabled.

   :::image type="content" source="./media/enable-fips-nodes/enable-fips-nodes-windows.png" alt-text="Screenshot shows a picture of the registry editor to the FIPS Algorithm Policy, and it being enabled.":::

   FIPS-enabled node pools also have a _kubernetes.azure.com/fips_enabled=true_ label, which deployments can use to target those node pools.

:::zone-end

:::zone pivot="azure-portal"

There isn't an Azure portal experience to enable or disable FIPS settings for Windows node pools. Any Windows node pools created using Azure portal has FIPS enabled. Windows Server 2022 and later node pools enable FIPS by default, and Windows Server 2025 and later node pools don't support disabling FIPS.

:::zone-end

:::zone pivot="arm"

1. Create a Windows node pool using an ARM template by deploying an agent pool resource with `osType` set to `Windows`. For example:

    ```json
    {
      "type": "Microsoft.ContainerService/managedClusters/agentPools",
      "apiVersion": "2023-03-01",
      "name": "[concat(parameters('clusterName'), '/fipsnp')]",
      "properties": {
        "count": 3,
        "vmSize": "Standard_D2s_v3",
        "osType": "Windows",
        "osSKU": "Windows2022",
        "mode": "User"
      }
    }
    ```

1. Deploy the ARM template using the [Azure portal][azure-portal], Azure CLI, or Azure PowerShell. For more information on deploying ARM templates, see [Deploy resources with ARM templates][arm-templates-deploy].
1. Verify your node pool configuration using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

1. Verify Windows node pools have access to FIPS cryptographic libraries by [creating an RDP connection to a Windows node][aks-rdp] in a node pool and checking the registry. From the **Run** application, enter `regedit`.
1. Look for `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa\FIPSAlgorithmPolicy` in the registry.
1. If `Enabled` is set to _1_, then FIPS is enabled.

   :::image type="content" source="./media/enable-fips-nodes/enable-fips-nodes-windows.png" alt-text="Screenshot shows a picture of the registry editor to the FIPS Algorithm Policy, and it being enabled.":::

   FIPS-enabled node pools also have a _kubernetes.azure.com/fips_enabled=true_ label, which deployments can use to target those node pools.

:::zone-end

:::zone pivot="bicep"

1. Create a Windows node pool using Bicep by deploying an agent pool resource with `osType` set to `Windows`. For example:

    ```bicep
    param clusterName string
    param nodePoolName string = 'fipsnp'
    
    resource nodePool 'Microsoft.ContainerService/managedClusters/agentPools@2023-03-01' = {
      name: '${clusterName}/${nodePoolName}'
      properties: {
        count: 3
        vmSize: 'Standard_D2s_v3'
        osType: 'Windows'
        osSKU: 'Windows2022'
        mode: 'User'
        enableFIPS: true
      }
    }
    ```

1. Deploy the Bicep file using the Azure CLI, Azure PowerShell, or the [Azure portal][azure-portal]. For more information on deploying Bicep files, see [Create Bicep files using Visual Studio Code](/azure/azure-resource-manager/bicep/quickstart-create-bicep-use-visual-studio-code).
1. Verify your node pool configuration using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

1. Verify Windows node pools have access to FIPS cryptographic libraries by [creating an RDP connection to a Windows node][aks-rdp] in a node pool and checking the registry. From the **Run** application, enter `regedit`.
1. Look for `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa\FIPSAlgorithmPolicy` in the registry.
1. If `Enabled` is set to _1_, then FIPS is enabled.

   :::image type="content" source="./media/enable-fips-nodes/enable-fips-nodes-windows.png" alt-text="Screenshot shows a picture of the registry editor to the FIPS Algorithm Policy, and it being enabled.":::

   FIPS-enabled node pools also have a _kubernetes.azure.com/fips_enabled=true_ label, which deployments can use to target those node pools.

:::zone-end

:::zone pivot="terraform"

1. Add the following code to `main.tf` to create a Windows node pool in your AKS cluster:

    ```Terraform
    resource "azurerm_kubernetes_cluster_node_pool" "fips_windows" {
      name                   = "fipsnp"
      kubernetes_cluster_id  = azurerm_kubernetes_cluster.example.id
      vm_size                = "Standard_D2s_v3"
      os_type                = "Windows"
      os_sku                 = "Windows2022"
      node_count             = 3
      fips_enabled           = true
    
      node_taints = []
    }
    ```

1. Apply the updated Terraform configuration using the `terraform plan` and `terraform apply` commands.

    ```console
    terraform plan
    terraform apply
    ```

1. Connect to the AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials \
        --resource-group myResourceGroup \
        --name myAKSCluster
    ```

1. Verify your node pool configuration using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

1. Verify Windows node pools have access to FIPS cryptographic libraries by [creating an RDP connection to a Windows node][aks-rdp] in a node pool and checking the registry. From the **Run** application, enter `regedit`.
1. Look for `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa\FIPSAlgorithmPolicy` in the registry.
1. If `Enabled` is set to _1_, then FIPS is enabled.

   :::image type="content" source="./media/enable-fips-nodes/enable-fips-nodes-windows.png" alt-text="Screenshot shows a picture of the registry editor to the FIPS Algorithm Policy, and it being enabled.":::

   FIPS-enabled node pools also have a _kubernetes.azure.com/fips_enabled=true_ label, which deployments can use to target those node pools.

:::zone-end

## Update an existing node pool to enable or disable FIPS

Existing Linux node pools can be updated to enable or disable FIPS. If you're planning to migrate your node pools from non-FIPS to FIPS, first validate that your application is working properly in a test environment before migrating it to a production environment. Validating your application in a test environment should prevent issues caused by the FIPS kernel blocking some weak cipher or encryption algorithm, such as an MD4 algorithm that isn't FIPS compliant.

> [!NOTE]
> When updating an existing Linux node pool to enable or disable FIPS, the node pool update moves between the fips and nonfips image. This node pool update triggers a reimage to complete the update. This can cause the node pool update to take a few minutes to complete.

:::zone pivot="azure-cli"

### Prerequisites for updating an existing node pool

Azure CLI version 2.64.0 or later. To find the version, run `az --version`. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

:::zone-end

### Enable FIPS on an existing node pool

You can update existing Linux node pools to enable FIPS. When you update an existing node pool, the node image changes from the current image to the recommended FIPS image of the same OS SKU.

:::zone pivot="azure-cli"

1. Update a node pool using the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--enable-fips-image` parameter.

    ```azurecli-interactive
    az aks nodepool update \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name np \
        --enable-fips-image
    ```

   This command triggers a reimage of the node pool immediately to deploy the FIPS-compliant OS. This reimage occurs during the node pool update. No extra steps are required.

1. Verify your node pool is FIPS-enabled using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

    The following example output shows that the _np_ node pool is FIPS-enabled:

    ```output
    Name       enableFips
    ---------  ------------
    np         True
    nodepool1  False  
    ```

:::zone-end

:::zone pivot="azure-portal"

Enabling FIPS on an existing node pool currently **isn't supported in the Azure portal**. To enable FIPS on an existing node pool, use the Azure CLI, ARM template, Bicep, or Terraform instructions in this article.

:::zone-end

:::zone pivot="arm"

1. Enable FIPS on an existing node pool using an ARM template by updating the agent pool profile to set the `enableFips` property to `true`. For example:

    ```json
    {
      "type": "Microsoft.ContainerService/managedClusters/agentPools",
      "name": "[concat(parameters('clusterName'), '/np')]",
      "apiVersion": "2023-03-01",
      "properties": {
        "enableFips": true
      }
    }
    ```

1. Deploy the updated template using the [Azure portal][azure-portal], Azure CLI, or Azure PowerShell. For more information on deploying ARM templates, see [Deploy resources with ARM templates][arm-templates-deploy].
1. Verify your node pool is FIPS-enabled using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

    The following example output shows that the _np_ node pool is FIPS-enabled:

    ```output
    Name       enableFips
    ---------  ------------
    np         True
    nodepool1  False  
    ```

:::zone-end

:::zone pivot="bicep"

1. Enable FIPS on an existing node pool using Bicep by updating the agent pool resource to set `enableFIPS` to `true`. For example:

    ```bicep
    param clusterName string
    param nodePoolName string = 'np'
    
    resource nodePool 'Microsoft.ContainerService/managedClusters/agentPools@2023-03-01' = {
      name: '${clusterName}/${nodePoolName}'
      properties: {
        enableFIPS: true
      }
    }
    ```

1. Deploy the updated Bicep file using the Azure CLI, Azure PowerShell, or the [Azure portal][azure-portal]. For more information on deploying Bicep files, see [Create Bicep files using Visual Studio Code](/azure/azure-resource-manager/bicep/quickstart-create-bicep-use-visual-studio-code).
1. Verify that your node pool is FIPS-enabled using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

    The following example output shows that the _np_ node pool is FIPS-enabled:

    ```output
    Name       enableFips
    ---------  ------------
    np         True
    nodepool1  False  
    ```

:::zone-end

:::zone pivot="terraform"

1. Update the `azurerm_kubernetes_cluster_node_pool` resource in `main.tf` by setting `fips_enabled` to `true`:

    ```Terraform
    resource "azurerm_kubernetes_cluster_node_pool" "example" {
      name                   = "np"
      kubernetes_cluster_id  = azurerm_kubernetes_cluster.example.id
      vm_size                = "Standard_D2s_v3"
      os_type                = "Linux"
      os_sku                 = "Ubuntu"
      node_count             = 3
      fips_enabled           = true
    }
    ```

1. Apply the updated Terraform configuration using the `terraform plan` and `terraform apply` commands. Terraform detects the change to `fips_enabled` and triggers the necessary reimage operation.

    ```console
    terraform plan
    terraform apply
    ```

1. Connect to the AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials \
        --resource-group myResourceGroup \
        --name myAKSCluster
    ```

1. Verify your node pool is FIPS-enabled using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

    The following example output shows that the _np_ node pool is FIPS-enabled:

    ```output
    Name       enableFips
    ---------  ------------
    np         True
    nodepool1  False  
    ```

:::zone-end

### Disable FIPS on an existing node pool

You can update existing Linux node pools to disable FIPS. When updating an existing node pool, the node image changes from the current FIPS image to the recommended non-FIPS image of the same OS SKU. The node image change occurs after a reimage.

:::zone pivot="azure-cli"

1. Update a Linux node pool using the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--disable-fips-image` parameter.

    ```azurecli-interactive
    az aks nodepool update \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name np \
        --disable-fips-image
    ```

   This command triggers a reimage of the node pool immediately to deploy the FIPS-compliant OS. This reimage occurs during the node pool update. No extra steps are required.

1. Verify your node pool isn't FIPS-enabled using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
        -o table
    ```

    The following example output shows that the _np_ node pool isn't FIPS-enabled:

    ```output
    Name       enableFips
    ---------  ------------
    np         False
    nodepool1  False  
    ```

:::zone-end

:::zone pivot="azure-portal"

Disabling FIPS on an existing node pool currently **isn't supported in the Azure portal**. To disable FIPS on an existing node pool, use the Azure CLI, ARM template, Bicep, or Terraform instructions in this article.

:::zone-end

:::zone pivot="arm"

1. Disable FIPS on an existing node pool using an ARM template by updating the agent pool profile to set the `enableFips` property to `false`. For example:

    ```json
    {
      "type": "Microsoft.ContainerService/managedClusters/agentPools",
      "name": "[concat(parameters('clusterName'), '/np')]",
      "apiVersion": "2023-03-01",
      "properties": {
        "enableFips": false
      }
    }
    ```

1. Deploy the updated template using the [Azure portal][azure-portal], Azure CLI, or Azure PowerShell. For more information on deploying ARM templates, see [Deploy resources with ARM templates][arm-templates-deploy].
1. Verify your node pool isn't FIPS-enabled using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
      --resource-group myResourceGroup \
      --name myAKSCluster \
      --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
      -o table
    ```

    The following example output shows that the _np_ node pool isn't FIPS-enabled:

    ```output
    Name       enableFips
    ---------  ------------
    np         False
    nodepool1  False  
    ```

:::zone-end

:::zone pivot="bicep"

1. Disable FIPS on an existing node pool using Bicep by updating the agent pool resource to set `enableFIPS` to `false`. For example:

    ```bicep
    param clusterName string
    param nodePoolName string = 'np'
    
    resource nodePool 'Microsoft.ContainerService/managedClusters/agentPools@2023-03-01' = {
      name: '${clusterName}/${nodePoolName}'
      properties: {
        enableFIPS: false
      }
    }
    ```

1. Deploy the updated Bicep file using the Azure CLI, Azure PowerShell, or the [Azure portal][azure-portal]. For more information on deploying Bicep files, see [Create Bicep files using Visual Studio Code](/azure/azure-resource-manager/bicep/quickstart-create-bicep-use-visual-studio-code).
1. Verify your node pool isn't FIPS-enabled using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
      --resource-group myResourceGroup \
      --name myAKSCluster \
      --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
      -o table
    ```

    The following example output shows that the _np_ node pool isn't FIPS-enabled:

    ```output
    Name       enableFips
    ---------  ------------
    np         False
    nodepool1  False  
    ```

:::zone-end

:::zone pivot="terraform"

1. Update the `azurerm_kubernetes_cluster_node_pool` resource in `main.tf` by setting `fips_enabled` to `false`:

    ```Terraform
    resource "azurerm_kubernetes_cluster_node_pool" "example" {
      name                   = "np"
      kubernetes_cluster_id  = azurerm_kubernetes_cluster.example.id
      vm_size                = "Standard_D2s_v3"
      os_type                = "Linux"
      os_sku                 = "Ubuntu"
      node_count             = 3
      fips_enabled           = false
    }
    ```

1. Apply the updated Terraform configuration using the `terraform plan` and `terraform apply` commands. Terraform detects the change to `fips_enabled` and triggers the necessary reimage operation.

    ```console
    terraform plan
    terraform apply
    ```

1. Verify your node pool isn't FIPS-enabled using the [`az aks show`][az-aks-show] command and query for the _enableFIPS_ value in _agentPoolProfiles_.

    ```azurecli-interactive
    az aks show \
      --resource-group myResourceGroup \
      --name myAKSCluster \
      --query="agentPoolProfiles[].{Name:name enableFips:enableFips}" \
      -o table
    ```

    The following example output shows that the _np_ node pool isn't FIPS-enabled:

    ```output
    Name       enableFips
    ---------  ------------
    np         False
    nodepool1  False  
    ```

:::zone-end

:::zone pivot="azure-cli"

## Message of the day

You can replace the _Message of the Day_ (MOTD) on Linux nodes using the `--message-of-the-day` flag when creating a cluster or adding a node pool.

Create a cluster and replace the message of the day using the [`az aks create`][az-aks-create] command with the `--message-of-the-day` flag set to the path of the new MOTD file.

```azurecli-interactive
az aks create --cluster-name myAKSCluster --resource-group myResourceGroup --message-of-the-day ./newMOTD.txt
```

Add a node pool and replace the message of the day using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--message-of-the-day` flag set to the path of the new MOTD file.

```azurecli-interactive
az aks nodepool add --name mynodepool1 --cluster-name myAKSCluster --resource-group myResourceGroup --message-of-the-day ./newMOTD.txt
```

:::zone-end

## Related content

To learn more about AKS security, see [Best practices for cluster security and upgrades in Azure Kubernetes Service (AKS)][aks-best-practices-security].

<!-- LINKS - Internal -->
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[az-aks-show]: /cli/azure/aks#az-aks-show
[az-aks-create]: /cli/azure/aks#az-aks-create
[aks-best-practices-security]: operator-best-practices-cluster-security.md
[aks-rdp]: rdp.md
[fips]: /azure/compliance/offerings/offering-fips-140-2
[install-azure-cli]: /cli/azure/install-azure-cli
[node-image-upgrade]: node-image-upgrade.md
[errors-mount-file-share-fips]: /troubleshoot/azure/azure-kubernetes/fail-to-mount-azure-file-share#fipsnodepool
[azure-portal]: https://portal.azure.com
[arm-templates-deploy]: /azure/azure-resource-manager/templates/deploy-to-azure-button
[terraform-aks-node-pool]: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_node_pool
[terraform-aks-cluster]: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster
[terraform-init]: https://developer.hashicorp.com/terraform/cli/commands/init
[terraform-plan]: https://developer.hashicorp.com/terraform/cli/commands/plan
[terraform-apply]: https://developer.hashicorp.com/terraform/cli/commands/apply
[az-account-set]: /cli/azure/account#az-account-set
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
