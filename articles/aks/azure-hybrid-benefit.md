---
title: Use Azure Hybrid Benefit
titleSuffix: Azure Kubernetes Service
description: Learn how to save costs for Windows workloads by using existing Windows Server licenses on Azure Kubernetes Service.
ms.topic: concept-article
ms.date: 02/09/2024
ms.author: viniap
author: vrapolinario
# Customer intent: "As a cloud administrator, I want to enable Azure Hybrid Benefit for my Azure Kubernetes Service cluster, so that I can reduce costs by utilizing my existing Windows Server licenses."
---

# What is Azure Hybrid Benefit for Azure Kubernetes Service?

Azure Hybrid Benefit is a program that enables you to significantly reduce the costs of running workloads in the cloud. With Azure Hybrid Benefit for Azure Kubernetes Service (AKS), you can maximize the value of your on-premises licenses and modernize your applications at no extra cost. Azure Hybrid Benefit enables you to use your on-premises licenses that also have either active Software Assurance (SA) or a qualifying subscription to get Windows virtual machines (VMs) on Azure at a reduced cost.

For more information on qualifications for Azure Hybrid Benefit, what is included with it, how to stay compliant, and more, check out [Azure Hybrid Benefit for Windows Server](/azure/virtual-machines/windows/hybrid-use-benefit-licensing).

>[!Note]
>Azure Hybrid Benefit for Azure Kubernetes Service follows the same licensing guidance as Azure Hybrid Benefit for Windows Server VMs on Azure.

## Enable Azure Hybrid Benefit for Azure Kubernetes Service

Azure Hybrid Benefit for Azure Kubernetes Service can be enabled at cluster creation or on an existing AKS cluster. You can enable and disable Azure Hybrid Benefit using either the Azure CLI or Azure PowerShell. In the following examples, be sure to replace the variable definitions with values matching your own cluster.

To create a new AKS cluster with Azure Hybrid Benefit enabled:

### [Azure CLI](#tab/azure-cli)

```azurecli-interactive
PASSWORD='' # replace with your own password value
RG_NAME='myResourceGroup'
CLUSTER='myAKSCluster'

az aks create \
    --resource-group $RG_NAME \
    --name $CLUSTER \
    --load-balancer-sku Standard \
    --network-plugin azure \
    --windows-admin-username azure \
    --windows-admin-password $PASSWORD \
    --enable-ahub \
    --generate-ssh-keys
```

### [Azure PowerShell](#tab/azure-powershell)

```powershell
$password= ConvertTo-SecureString -AsPlainText "" -Force # replace with your own password value
$rg_name = "myResourceGroup"
$cluster = "myAKSCluster"

New-AzAksCluster -ResourceGroupName $rg_name -Name $cluster -WindowsProfileAdminUserName azureuser -WindowsProfileAdminUserPassword $cred -NetworkPlugin azure -NodeVmSetType VirtualMachineScaleSets --EnableAHUB
```

---

To enable Azure Hybrid Benefit on an existing AKS cluster:

### [Azure CLI](#tab/azure-cli)

```azurecli
RG_NAME='myResourceGroup'
CLUSTER='myAKSCluster'

az aks update --resouce-group $RG_NAME --name $CLUSTER--enable-ahub
```

### [Azure PowerShell](#tab/azure-powershell)

```powershell
$rg_name = "myResourceGroup"
$cluster = "myAKSCluster"

Get-AzAksCluster -ResourceGroupName $rg_name -Name $cluster | Set-AzAksCluster -EnableAHUB
```

---

## Disable Azure Hybrid Benefit for Azure Kubernetes Service

To disable Azure Hybrid Benefit for an AKS cluster:

### [Azure CLI](#tab/azure-cli)

```azurecli
RG_NAME='myResourceGroup'
CLUSTER='myAKSCluster'

az aks update --resource-group $RG_NAME --name $CLUSTER --disable-ahub
```

### [Azure PowerShell](#tab/azure-powershell)

It is currently not possible to disable Azure Hybrid Benefit for AKS using Azure PowerShell.

---

## Next steps

To learn more about Windows containers on AKS, see the following resources:

* [Learn how to deploy, manage, and monitor Windows containers on AKS](/training/paths/deploy-manage-monitor-wincontainers-aks).
* Open an issue or provide feedback in the [Windows containers GitHub repository](https://github.com/microsoft/Windows-Containers/issues).
* Review the [third-party partner solutions for Windows on AKS](windows-aks-partner-solutions.md).

