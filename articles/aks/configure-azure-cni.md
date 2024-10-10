---
title: Configure Azure CNI networking in Azure Kubernetes Service (AKS)
titleSuffix: Azure Kubernetes Service
description: Learn how to configure Azure CNI (advanced) networking in Azure Kubernetes Service (AKS).
author: asudbring
ms.author: allensu
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 09/13/2023
ms.custom: references_regions, devx-track-azurecli
---

# Configure Azure CNI networking in Azure Kubernetes Service (AKS)

This article shows you how to use Azure CNI networking to create and use a virtual network subnet for an AKS cluster. For more information on network options and considerations, see [Network concepts for Kubernetes and AKS](/azure/aks/concepts-network).

## Prerequisites

### [Azure portal](#tab/configure-networking-portal)

- An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).

### [Azure PowerShell](#tab/configure-networking-powershell)

- An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).

- Azure Cloud Shell or Azure PowerShell.

  The steps in this quickstart run the Azure PowerShell cmdlets interactively in [Azure Cloud Shell](/azure/cloud-shell/overview). To run the commands in the Cloud Shell, select **Open Cloudshell** at the upper-right corner of a code block. Select **Copy** to copy the code and then paste it into Cloud Shell to run it. You can also run the Cloud Shell from within the Azure portal.

  You can also [install Azure PowerShell locally](/powershell/azure/install-azure-powershell) to run the cmdlets. The steps in this article require Azure PowerShell module version 5.4.1 or later. Run `Get-Module -ListAvailable Az` to find your installed version. If you need to upgrade for specific OS, see [macOS][macOSUpgrade], [Windows][windowsUpgrade] or [Linux][linuxUpgrade].

  If you run PowerShell locally, run `Connect-AzAccount` to connect to Azure.

### [Azure CLI](#tab/configure-networking-cli)

- An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).

[!INCLUDE [azure-cli-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

---

## Configure networking

For information on planning IP addressing for your AKS cluster, see [Plan IP addressing for your cluster](concepts-network-ip-address-planning.md).

### [Azure portal](#tab/configure-networking-portal)

1. Sign in to the [Azure portal](https://portal.azure.com/).
1. On the Azure portal home page, select **Create a resource**.
1. Under **Categories**, select **Containers** > **Azure Kubernetes Service (AKS)**.
1. On the **Basics** tab, configure the following settings:
   - Under **Project details**:
     - **Subscription**: Select your Azure subscription.
     - **Resource group**: Select **Create new**, enter a resource group name, such as *test-rg*, and then select **Ok**.
   - Under **Cluster details**:
     - **Kubernetes cluster name**: Enter a cluster name, such as *aks-cluster*.
     - **Region**: Select **East US 2**.
1. Select **Next** > **Next** to get to the **Networking** tab.
1. For **Container networking**, select **Azure CNI Node Subnet**.
1. Select **Review + create** > **Create**.

### [Azure PowerShell](#tab/configure-networking-powershell)

When you create an AKS cluster with Azure PowerShell, you can also configure Azure CNI networking.

Use [New-AzAksCluster](/powershell/module/az.aks/new-azakscluster) to create an AKS cluster with default settings and Azure CNI networking:

```azurepowershell-interactive
## Create a resource group for the AKS cluster. ##
$rg = @{
    Name = "test-rg"
    Location = "eastus2"
}
New-AzResourceGroup @rg

$net = @{
      NetworkPlugin = "azure"
      ResourceGroupName = "test-rg"
      Name = "aks-cluster"
}
New-AzAksCluster @net
```

### [Azure CLI](#tab/configure-networking-cli)

When you create an AKS cluster with the Azure CLI, you can also configure Azure CNI networking. 

Use [`az aks create`][az-aks-create] with the `--network-plugin azure` argument to create a cluster with advanced networking:

```azurecli-interactive
az group create \
    --name test-rg \
    --location eastus2

az aks create \
    --resource-group test-rg \
    --name aks-cluster \
    --network-plugin azure \
    --generate-ssh-keys
```

---

## Next steps

To configure Azure CNI networking with dynamic IP allocation and enhanced subnet support, see [Configure Azure CNI networking for dynamic allocation of IPs and enhanced subnet support in AKS](configure-azure-cni-dynamic-ip-allocation.md).

<!-- LINKS - Internal -->
[az-aks-create]: /cli/azure/aks#az_aks_create
[macOSUpgrade]: /powershell/azure/install-azps-macos#update-the-azure-powershell-module
[windowsUpgrade]: /powershell/azure/install-azps-windows#update-the-az-powershell-module
[linuxUpgrade]: /powershell/azure/install-azps-linux#update-the-az-powershell-module
