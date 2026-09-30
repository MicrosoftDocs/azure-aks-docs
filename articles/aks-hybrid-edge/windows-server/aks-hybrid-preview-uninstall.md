---
title: Before you begin - uninstall the AKS cluster provisioning preview
description: Learn how to uninstall the AKS cluster provisioning from Azure preview.
ms.topic: overview
ms.custom: devx-track-azurecli, windows-server
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak 
ms.reviewer: guanghu
ms.lastreviewed: 01/30/2024
---

# Before you begin: uninstall the AKS cluster provisioning preview

[!INCLUDE [aks-hybrid-applies-to-azure-stack-hci-windows-server-sku](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

This step is only required if you installed the AKS cluster provisioning from Azure preview. The preview ended with the release of [AKS on Azure Local](../aks-overview.md). This article describes the steps to uninstall the preview bits before upgrading to AKS.

## Step 1: delete all preview AKS clusters and Azure vnets created using Az CLI

```azurecli
az akshybrid delete --resource-group <resource group name> --name <kubernetes cluster name>
az akshybrid vnet delete --resource-group <resource group name> --name <vnet name>
```

## Step 2: delete the custom location

```azurecli
az customlocation delete --name <custom location name> --resource-group <resource group name>
```

## Step 3: delete the cluster extension

```azurecli
az k8s-extension delete --resource-group <resource group name> --cluster-name <arc appliance name> --cluster-type appliances --name <aks extension name>
```

## Step 4: delete the Arc Resource Bridge

```azurecli
az arcappliance delete hci --config-file "<path to working directory>\hci-appliance.yaml"
```

## Step 5: delete the ArcHCI config files

```powershell
Remove-ArcHciAksConfigFiles -workDirectory <path to working directory>
```

## Next steps

[AKS overview](../aks-overview.md)
