---
title: Deploy an Azure Kubernetes Service host with pre-staged cluster service objects and DNS records using PowerShell
description: Learn how to set up an AKS host if you pre-staged cluster service objects and DNS records.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak
ms.lastreviewed: 1/14/2022
ms.reviewer: srikantsarwa
ms.custom: windows-server

# Intent: As an IT Pro, I want step-by-step instructions on how to use PowerShell to use pre-staged cluster objects to deploy my AKS host.
# Keyword: DNS records

---

# Deploy an Azure Kubernetes Service host with pre-staged cluster service objects and DNS records using PowerShell

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

This how-to guide describes how to use PowerShell to configure your AKS host deployment if you pre-staged cluster service objects and DNS records in AKS on Windows Server.

## Before you begin

- Make sure you satisfy all the prerequisites in [system requirements](system-requirements.md).
- Download and install the [AksHci PowerShell module](./kubernetes-walkthrough-powershell.md#install-the-akshci-powershell-module).

## Step 1: Prepare your Active Directory and DNS server for deployment

If you can't enable dynamic DNS updates in your DNS environment to allow AKS on Windows Server to register the cloud agent generic cluster name in Active Directory and the DNS system for discovery, you must pre-create the respective records in Active Directory and DNS.

Create a generic cluster service in Active Directory with the name `ca-cloudagent` (or a name of your choice that doesn't exceed 32 characters). Also, create an associated DNS record that points to the FQDN of the generic cluster service with the provided `cloudservicecidr` address. For more information about the steps in this process, see the [failover clustering documentation](/windows-server/failover-clustering/prestage-cluster-adds).

The AKS deployment attempts to locate the specified `clusterRoleName` in Active Directory before proceeding with the deployment.

> [!NOTE]
> Once AKS is deployed, this information cannot be changed.

## Step 2: Prepare your machines for deployment

Run checks on every physical node to see if all the requirements are satisfied to install AKS. Open PowerShell as an administrator and run the following [Initialize-AksHciNode](/azure/aks/aksarc/reference/ps/initialize-akshcinode) command:

```powershell
Initialize-AksHciNode
```

## Step 3: Create a virtual network

To create a virtual network for the nodes in your deployment to use, create an environment variable with the `New-AksHciNetworkSetting` PowerShell command. This variable is used later to configure a deployment that uses static IP. If you want to configure your AKS deployment with DHCP, see [New-AksHciNetworkSetting](/azure/aks/aksarc/reference/ps/new-akshcinetworksetting) for examples. You can also review some [networking node concepts](./concepts-node-networking.md).

```powershell
# static IP
$vnet = New-AksHciNetworkSetting -name mgmt-vnet -vSwitchName "extSwitch" -k8sNodeIpPoolStart "172.16.10.1" -k8sNodeIpPoolEnd "172.16.10.255" -vipPoolStart "172.16.255.0" -vipPoolEnd "172.16.255.254" -ipAddressPrefix "172.16.0.0/16" -gateway "172.16.0.1" -dnsServers "172.16.0.1"
```

> [!NOTE]
> You must customize the values shown in this example command for your environment.

## Step 4: Configure your deployment with the pre-staged cluster service objects and DNS records

Set the configuration settings for the AKS host using the [Set-AksHciConfig](/azure/aks/aksarc/reference/ps/set-akshciconfig) command. You must specify the `workingDir`, `cloudServiceCidr`, `cloudConfigLocation`, and `clusterRoleName` parameters. If you want to reset your configuration details, run the command again with new parameters.

Configure your deployment with the following command:

```powershell
Set-AksHciConfig -workingDir c:\ClusterStorage\Volume1\workingDir -cloudConfigLocation c:\clusterstorage\volume1\Config -vnet $vnet -cloudservicecidr "172.16.10.10/16" -clusterRoleName "ca-cloudagent"
```

> [!NOTE]
> Customize the values shown in this example command for your environment.

## Step 5: Sign in to Azure and configure registration settings

Run the following [Set-AksHciRegistration](/azure/aks/aksarc/reference/ps/set-akshciregistration) PowerShell command with your subscription and resource group name to sign into Azure. You must have an Azure subscription, and an existing Azure resource group in the East US, Southeast Asia, or West Europe Azure regions to proceed:

```powershell
Set-AksHciRegistration -subscriptionId "<subscriptionId>" -resourceGroupName "<resourceGroupName>"
```

## Step 6: Start a new deployment

After you configure your deployment, you must start it. Starting the deployment installs the AKS agents/services and the AKS host. To begin the deployment, run the following command:

```powershell
Install-AksHci
```

> [!WARNING]
> During installation of your AKS host, a **Kubernetes - Azure Arc** resource type is created in the resource group that's set during registration. Do not delete this resource, as it represents your Azure Kubernetes Service host. You can identify the resource by checking its distribution field for the `aks_management` value. Deleting this resource results in an out-of-policy deployment.

## Next steps

- [Create an AKS workload cluster](/azure/aks/aksarc/reference/ps/new-akshcicluster)
- [Prepare an application](/azure/aks/aksarc/tutorial-kubernetes-prepare-application)
- [Deploy a Windows application on your Kubernetes cluster](./deploy-windows-application.md)
