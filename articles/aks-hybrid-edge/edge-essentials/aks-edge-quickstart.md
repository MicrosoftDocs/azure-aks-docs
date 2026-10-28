---
title: Quickstart for AKS Edge Essentials
description: Learn how to bring up an AKS Edge Essentials cluster and connect it to Azure Arc. 
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: quickstart
ms.date: 09/01/2026
ms.custom: template-how-to, edge-essentials
---

# AKS Edge Essentials quickstart guide

This quickstart guide describes how to set up an Azure Kubernetes Service (AKS) Edge Essentials single-machine K3S Linux-only cluster.

> [!NOTE]
>
> - This quickstart script eases the evaluation process. It requires higher level credentials for a one-time setup of the Azure subscription. The script isn't intended for production use.
> - By default, this quickstart script enables the Key Management Service (KMS) plugin (preview) by setting Init.KmsPlugin to **true**. For more information, see [Enable secret encryption on an AKS Edge Essentials cluster](aks-edge-howto-secret-encryption.md).

## Prerequisites

- See the [system requirements](aks-edge-system-requirements.md). For this quickstart, ensure that you have a minimum of 4.5 GB RAM free, 4 vCPUs, and 20 GB free disk space.
- OS requirements: install Windows 10/11 IoT Enterprise/Enterprise/Pro on your machine and activate Windows. Use the latest [client version 22H2 (OS build 19045)](/windows/release-health/release-information) or [Server 2022 (OS build 20348)](/windows/release-health/windows-server-release-info). You can [download a version of Windows 10 here](https://www.microsoft.com/software-download/windows10) or [Windows 11 here](https://www.microsoft.com/software-download/windows11).
- See the [Microsoft Software License Terms](aks-edge-software-license-terms.md) as they apply to your use of the software. By using the `AksEdgeQuickStart` script, you accept the Microsoft Software License Terms and the `AcceptEULA` flag is set to `true` indicating acceptance of the license terms.
- Get your Azure subscription parameters: to connect your cluster to Azure Arc, you must provide these parameters. If you skip these parameters, the Arc connection is skipped, but the cluster is still deployed:
  - Your **login credentials**: Required for interactive authentication into Azure using Azure CLI. Your account should have one of these roles `Owner`, `Contributor`, or `Administrator`.
  - Your **Subscription ID** `<subscription-id>`: In the Azure portal, select the subscription you're using and look for the subscription ID (GUID).
  - Your **Tenant ID** `<tenant-id>`: In the Azure portal, search for Microsoft Entra ID, which takes you to the **Default Directory** page. Look for the tenant ID (GUID).
  - The **Location (Azure region)** `<location>`: Where you want your resources to be created. See [Azure Arc by Region](https://azure.microsoft.com/explore/global-infrastructure/products-by-region/?products=azure-arc) for the locations supported by `Azure Arc enabled servers` and `Azure Arc enabled Kubernetes` services. Choose a region in which both are supported.

## Step 1: Download script for easy deployment

Download the `AksEdgeQuickStart.ps1` script to a working folder. Depending on the policy setup on your machine, you might need to unblock the file before running it and run `Set-ExecutionPolicy` to allow the script execution.

Open an elevated PowerShell window, and change directory to a working folder:

```powershell
$url = "https://raw.githubusercontent.com/Azure/AKS-Edge/main/tools/scripts/AksEdgeQuickStart/AksEdgeQuickStart.ps1"
Invoke-WebRequest -Uri $url -OutFile .\AksEdgeQuickStart.ps1
Unblock-File .\AksEdgeQuickStart.ps1
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

This script automates the following steps:

- In the working folder, the script downloads the GitHub archive of [Azure/AKS-Edge](https://github.com/Azure/AKS-Edge) and unzips to a folder **AKS-Edge-main** (or **AKS-Edge-\<tag\>**). By default, this step downloads the current main branch.
- Uses the [AksEdgeAzureSetup script](https://github.com/Azure/AKS-Edge/blob/main/tools/scripts/AksEdgeAzureSetup/AksEdgeAzureSetup.ps1) to prompt the user to sign in to the Azure portal with their Azure credentials and performs the following tasks:
  - Installs [Azure CLI](/cli/azure/).
  - Creates a resource group **aksedge-rp**.
  - Creates a service principal **aksedge-sp** with **Contributor** role restricted to the **aksedge-rp** resource group scope. If the service principal already exists, it resets its password. This service principal is used to connect to Azure Arc.
  - Registers the resource providers **Microsoft.HybridCompute**, **Microsoft.GuestConfiguration**, **Microsoft.HybridConnectivity**,
    **Microsoft.Kubernetes**, **Microsoft.KubernetesConfiguration**, and **Microsoft.ExtendedLocation**.
- Invokes the `Start-AideWorkflow` function that performs the following tasks:
  - Downloads and installs the AKS Edge Essentials MSI.
  - Installs required host OS features (`Install-AksEdgeHostFeatures`). The machine might reboot when Hyper-V is enabled, and you must restart the script again.
  - Deploys a single machine cluster with internal switch (Linux node only).
- Invokes the `Connect-AideArc` function if the Azure parameters are provided. This function performs the following tasks:
  - Installs the Azure Connected Machine Agent and connects the host machine to Arc for Servers.
  - Connects the deployed cluster to Arc for connected Kubernetes.

> [!TIP]
> You can modify the `$aksedgeConfig` json content in the `AksEdgeQuickStart` script for any additional options. For available options, see [Deployment JSON configuration](aks-edge-deployment-config-json.md).

## Step 2: Deploy AKS Edge Essentials

In an elevated PowerShell prompt, run the `AksEdgeQuickStart.ps1` script. This script brings up a K3s cluster:

```powershell
.\AksEdgeQuickStart.ps1 -SubscriptionId "<subscription-id>" -TenantId "<tenant-id>" -Location "<location>"
```

To install the Kubernetes version, specify the `-UseK8s` flag:

```powershell
.\AksEdgeQuickStart.ps1 -SubscriptionId "<subscription-id>" -TenantId "<tenant-id>" -Location "<location>" -UseK8s
```

The script installs AKS Edge Essentials and connects your cluster to Azure using Azure Arc.

> [!TIP]
> If Hyper-V isn't enabled on your machine, the quickstart script enables Hyper-V and restarts your machine. Run the `AksEdgeQuickStart` script again after the reboot.

## Step 3: Verify deployment

1. Confirm that the deployment was successful by running:

    ```powershell
    kubectl get nodes -o wide
    kubectl get pods -A -o wide
    ```

    The following image shows pods on a K3S cluster:

    ![Screenshot showing all pods running.](../media/aks-edge/all-pods-running.png)

1. You can view your cluster in the Azure portal if you navigate to your resource group:

   ![Screenshot showing the cluster in azure portal](../media/aks-edge/cluster-in-az-portal.png)

1. On the left panel, select the **Namespaces** under **Kubernetes resources (preview)**:

   ![Screenshot of Kubernetes resources.](../media/aks-edge/kubernetes-resources-preview.png)

1. To view your Kubernetes resources, you need a bearer token:

   ![Screenshot showing the bearer token required page.](../media/aks-edge/bearer-token-required.png)

1. Run `Get-AksEdgeManagedServiceToken` to retrieve your service token:

   ![Screenshot showing where to paste token in portal.](../media/aks-edge/bearer-token-in-portal.png)

1. Now you can view resources on your cluster. The **Workloads** shows the pods running on your cluster.

    ```powershell
    kubectl get pods --all-namespaces
    ```

    ![Screenshot showing all pods in Arc.](../media/aks-edge/all-pods-in-arc.png)

You now have an Arc-connected AKS Edge Essentials K3S cluster with a Linux node. You can explore deploying a sample Linux application on this cluster.

> [!TIP]
> If you didn't provide your Azure subscription details while running the `AksEdgeQuickStart.ps1` script, you can still connect to Azure Arc by [following the steps in this article](aks-edge-howto-connect-to-arc.md).

## Next steps

- [Understand deployment options](aks-edge-concept-clusters-nodes.md).
- [Deploy a Linux application](aks-edge-howto-deploy-app.md).
- [Add a Windows node](aks-edge-howto-single-node-deployment.md#step-4-add-a-windows-worker-node-optional).
- [Overview](aks-edge-overview.md)
- [Uninstall AKS cluster](aks-edge-howto-uninstall.md)
