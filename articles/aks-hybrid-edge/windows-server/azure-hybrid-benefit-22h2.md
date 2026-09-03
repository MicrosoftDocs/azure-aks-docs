---
title: Azure Hybrid Benefit for AKS on Windows Server
description: Activate Azure Hybrid Benefit for AKS on Windows Server.
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.topic: how-to
ms.reviewer: rbaziwane
ms.lastreviewed: 01/30/2024
ms.custom: windows-server
  - devx-track-azurepowershell

# Intent: As an IT Pro, I want to learn about Azure Hybrid Benefit for AKS.   
# Keyword: Azure Hybrid Benefit for AKS
---

# Azure Hybrid Benefit for AKS on Windows Server

[!INCLUDE [aks-hybrid-applies-to-azure-stack-hci-windows-server-sku](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

Azure Hybrid Benefit is a program that enables you to significantly reduce the costs of running workloads in the cloud. With Azure Hybrid Benefit for AKS on Windows Server, you can maximize the value of your on-premises licenses and modernize your applications at no extra cost.

## What is Azure Hybrid Benefit for AKS?

Azure Hybrid Benefit for AKS on Windows Server is a new benefit that can help you significantly reduce the cost of running Kubernetes on-premises or at the edge. It works by letting you apply your on-premises Windows Server Datacenter or Standard licenses with Software Assurance (SA) to pay for AKS. Each Windows Server core license entitles use on 1 virtual core of AKS. There are a few important details to note regarding activation of the benefit for AKS:

- Azure Hybrid Benefit for AKS is enabled at the management cluster (or AKS host) level. You don't need to enable the benefit for workload clusters.
- If you have multiple AKS on Windows Server deployments, you must enable Azure Hybrid Benefit individually for each deployment.
- If you enable Azure Hybrid Benefit on an AKS deployment during the trial period, it doesn't nullify your trial period. The benefit is activated immediately, and is applied at the end of the trial period.
- Reinstalling AKS doesn't automatically reinstate the benefit. You must reactivate this benefit for the new deployment.

For more information about Software Assurance and with which agreements it's available, see [Benefits of Software Assurance](https://www.microsoft.com/licensing/licensing-programs/software-assurance-by-benefits).

The rest of this article describes how to activate this benefit for AKS on Windows Server.

## Activate Azure Hybrid Benefit for AKS

### Prerequisites

Make sure you have an AKS cluster deployed on a Windows Server host.

# [Azure PowerShell](#tab/powershell)

To use Azure PowerShell, you can upgrade Azure PowerShell to the latest version (make sure to start PowerShell with administrator privileges).

1. Install or update the `Az.Accounts` and `Az.ConnectedKubernetes` modules:

   ```PowerShell
   Update-Module Az.Accounts 
   Update-Module Az.ConnectedKubernetes 
   ```

1. (Optional) If the `Az.*` modules installation is not successful and does not work, you must grant additional PowerShell permissions to execute external scripts:

   ```PowerShell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process 
   ```

# [Azure CLI](#tab/azurecli)

Make sure you have the latest version of [Azure CLI installed](/cli/azure/install-azure-cli) on your local machine. You can also choose to upgrade your Azure CLI version using `az upgrade`.

---

> [!NOTE]
> You must have the **Microsoft.Kubernetes/connectedClusters/write** permission to the Azure Arc-enabled Kubernetes cluster resource of the management cluster (`microsoft.kubernetes/connectedclusters`) to activate the Azure Hybrid Benefit.

### Retrieve your management cluster name

You can verify the AKS host management cluster by running the following command on any one node in your physical cluster to retrieve the `kvaName` name:

```PowerShell
(Get-AksHciConfig).Kva.kvaName
```

#### Sample output

```json
"<manangement cluster name>"
```

### Verify that Azure Hybrid Benefit for AKS is not already enabled

Check that the benefit was not already enabled on your management cluster. If the benefit is enabled, you should see the property `AzureHybridBenefit` set to `true`.

```PowerShell
Connect-AzAccount -Tenant <TenantId> -Subscription <SubscriptionId> -UseDeviceAuthentication
Set-AzContext -Subscription <Subscription>
Get-AzConnectedKubernetes -ClusterName <management cluster name> -ResourceGroupName <resource group name> | fl
```

#### Sample output

```json
{
  "agentVersion": "1.8.14",
  "azureHybridBenefit": "NotApplicable",
  "connectivityStatus": "Connected",
  "distribution": "AKS_Management",
  "distributionVersion": null,
  "id": "/subscriptions/<subscription>/resourceGroups/<resource group>/providers/Microsoft.Kubernetes/connectedClusters/<cluster name>",
  "identity": {

  },
  "infrastructure": "azure_stack_hci",
  "kubernetesVersion": "1.23.12",
  "lastConnectivityTime": "2022-11-04T14:59:59.050000+00:00",
  "location": "eastus",
  "miscellaneousProperties": null,
  "name": "<management cluster name>",
  "offering": "AzureStackHCI_AKS_Management",
  "provisioningState": "Succeeded",
  "resourceGroup": "<resource group>",
  "systemData": {},
  "tags": {},
  "totalCoreCount": 4,
  "totalNodeCount": 1,
  "type": "microsoft.kubernetes/connectedclusters"
}
```

> [!WARNING]
> If you have an empty value for the JSON property `distribution`, [follow this link to patch your cluster](https://github.com/Azure/aks-hybrid/issues/270) before proceeding with activating Azure Hybrid Benefit for AKS.

### Activate Azure Hybrid Benefit

To activate the benefit for an AKS cluster, run the following command in PowerShell and set the `AzureHybridBenefit` or `azure-hybrid-benefit` property to `true`. You are prompted to confirm compliance with Azure Hybrid Benefit terms before proceeding.

# [Azure PowerShell](#tab/powershell)

```PowerShell
Update-AzConnectedKubernetes -ClusterName <management cluster name> -ResourceGroupName <resource group name> -AzureHybridBenefit True
```

# [Azure CLI](#tab/azurecli)

```azurecli
az connectedk8s update -n <name> -g <resource group name> --azure-hybrid-benefit true 
```

---

#### Sample output

```shell
I confirm I have an eligible Windows Server license with Azure Hybrid Benefit to apply this benefit to AKS on Windows Server. Visit https://aka.ms/ahb-aks for details (y/n)
```

> [!NOTE]
> You can also do the Azure Hybrid Benefit for AKS activation operation from an [Azure Cloud Shell](https://shell.azure.com) instance.

### Verify that the benefit is enabled

Run the following command and check that the JSON property `AzureHybridBenefit` is set to  `True`.

# [Azure PowerShell](#tab/powershell)

```PowerShell
Get-AzConnectedKubernetes -ClusterName <management cluster name> -ResourceGroupName <resource group name> | fl
```

# [Azure CLI](#tab/azurecli)

```azurecli
az connectedk8s show -n <management cluster name> -g <resource group> 
```

---

## Maintain compliance for Azure Hybrid Benefit

After activating Azure Hybrid Benefit for AKS, you must regularly check and maintain compliance for Azure Hybrid Benefit. You can perform an inventory of how many units you're running, and check this list against the Software Assurance licenses you have. To determine how many clusters with Azure Hybrid Benefit for AKS you're running, you can look at your Microsoft Azure bill.

To qualify for the Azure Hybrid Benefit for AKS, you must be running AKS on first-party Microsoft infrastructure such as Windows Server 2019/2022 and have the appropriate license to cover the underlying infrastructure. You can only use Azure Hybrid Benefit for AKS during the Software Assurance term. When the Software Assurance term is nearing expiry, you must either renew your agreement with Software Assurance, or deactivate the Azure Hybrid Benefit functionality.

### Verify that Azure Hybrid Benefit for AKS is applied to my Microsoft Azure Bill

See **Cost Management and Billing** in the Azure portal to verify that the Azure Hybrid Benefit for AKS was applied to your Microsoft Azure bill. Billing does not apply in real time; there's a delay of several hours from the time you activate Azure Hybrid Benefit before it shows on your bill.

### Deactivate Azure Hybrid Benefit for AKS

Run the following command to deactivate the benefit:

# [Azure PowerShell](#tab/powershell)

```powershell
Update-AzConnectedKubernetes -ClusterName <management cluster name> -ResourceGroupName <resource group name> -AzureHybridBenefit False
```

# [Azure CLI](#tab/azurecli)

```azurecli
az connectedk8s update -n <name> -g <group> --azure-hybrid-benefit false 
```

---

## Next steps

- [Pricing](pricing.md)
