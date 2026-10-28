---
title: Use Windows node pools 
description: Learn how to enable the Windows node pool feature in AKS on Azure Local.
ms.topic: how-to
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak 
ms.lastreviewed: 09/24/2025
ms.custom: hyperconverged

---

# Enable the Windows node pool feature

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)] release 2509 or later.

Virtual hard disks (VHDs) serve as the base operating system images for the Kubernetes nodes within your AKS cluster. Starting with Azure Local version 2509, only the Azure Linux VHDs are downloaded by default on the Azure Local instance. The Azure Linux VHDs are used to create the default Linux node pool on the AKS cluster. For Windows-based workloads, AKS supports Windows Server 2019 and Windows Server 2022 images that you can use to create corresponding Windows node pools; however, these VHDs are not available by default and must be downloaded before you can create your Windows-based node pools. Having the Windows node pool feature disabled by default ensures that the Windows-based OS images are not downloaded unnecessarily, and helps to save bandwidth and storage space.

> [!IMPORTANT]
> With the Windows node pool feature disabled by default in Azure Local release 2509 and later, if you have a Windows node pool and you attempt to issue commands like `aksarc upgrade`, `aksarc update`,  `aksarc nodepool update`, or `aksarc nodepool add`, they fail with an error message stating that "The Windows node pool feature is disabled." You are then explicitly asked to enable this feature before you proceed with these operations.

## Prerequisites

Before you begin creating Windows node pools, make sure you have the following prerequisites in place:

- **Azure Local deployed**. This article applies only if you deployed Azure Local release 2509 or later. Windows VHDs are disabled by default starting in release 2509. If you are on an earlier release, you can proceed to [create a Windows node pool](howto-create-windows-node-pools.md).
- **Azure RBAC permissions to update Azure Local configuration**. Make sure you have the following roles. For more information, see [required permissions for deployment](/azure/azure-local/deploy/deployment-arc-register-server-permissions?tabs=powershell#assign-required-permissions-for-deployment):
  - Azure Local Administrator
  - Reader
- **Custom Location**. Name of the custom location. The custom location is configured during the Azure Local deployment. If you're in the Azure portal, go to the **Overview** page of the Azure Local system resource. In the **Essentials** section, you should see the custom location name for your cluster.
- **Azure resource group**. The Azure resource group in which Azure Local is deployed.
- Access to at least one node on the Azure Local instance, either directly or via remote PowerShell.

[!INCLUDE [gmsa-windows-node-pools-not-supported](../../includes/gmsa-windows-node-pools-not-supported.md)]

## Enable the Windows node pool feature on AKS clusters

To enable the Windows node pool feature on your AKS cluster, use the **Support.AksArc** PowerShell module. This module provides tools for diagnostics and remediation in AKS environments. By running its commands, you can activate the Windows node pool feature and initiate the download of the required Windows VHDs, making it possible to create Windows-based node pools.

### Step 1: Connect to an Azure Local node

Follow these steps on your client machine to connect to one of the Azure Local nodes.

1. Run PowerShell as administrator on the client that you're using to connect to your system.
1. Open a remote PowerShell session to a machine on your Azure Local instance. Run the following command and provide the credentials of your machine when prompted:

   ```powershell
   $cred = Get-Credential
   Enter-PSSession -ComputerName "<Computer IP>" -Credential $cred 
   ```

   > [!NOTE]
   > Sign in using your deployment user account credentials. This is the account you created when preparing [Active Directory](/azure/azure-local/deploy/deployment-prep-active-directory), and used to deploy Azure Local.

   <details>
   <summary>Expand this section to see an example output.</summary>

   The following is example output:

   ```output
   cmdlet Get-Credential at command pipeline position 1
   Supply values for the following parameters:
   Credential
   ```

   ```powershell
   Enter-PSSession -ComputerName "100.100.100.10" -Credential $cred
   ```
   
   ```output
   [100.100.100.10]: PS C:\Users\Administrator\Documents>
   ```

   </details>

### Step 2: Enable the Windows node pool feature on your cluster

In the remote PowerShell session, sign in to Azure, to the subscription where the Azure Local instance resides:

```azurecli
az login --use-device-code --tenant <Azure tenant ID>
az account set -s <subscription ID>
```

Install the **Support.AksArc** module using the following command:

```powershell
Install-Module -Name Support.AksArc
Import-Module Support.AksArc -Force
```

You can then run the following command to enable the Windows node pool feature and download the Windows-related VHDs:

```powershell
Invoke-SupportAksArcRemediation_EnableWindowsNodepool -Verbose
```

This enables the Windows node pool feature and begins the download of the Windows VHDs. This can take some time, depending on the network bandwidth available on your Azure Local instance.

### Step 3: Check if the Windows VHDs are ready

Run the following command to check if the Windows VHDs are downloaded and ready for use:

```azurecli
$customlocationName = <The custom location name for Azure Local>
$resourceGroup = <The Azure resource group in which Azure Local is deployed>

az aksarc get-versions --resource-group $resourceGroup --custom-location $customlocationName
```

For the Kubernetes version you intend to use, find the right Windows SKU by looking for `osType=Windows` and the `osSKU` fields and ensure that the `ready` state is **true**.

```output
...
         "1.29.4": { 
            "readiness": [ 
              { 
                "errorMessage": null, 
                "osSku": "CBLMariner", 
                "osType": "Linux", 
                "ready": true 
              }, 
              { 
                "errorMessage": null, 
                "osSku": "Windows2019", 
                "osType": "Windows", 
                "ready": true 
              }, 
              { 
                "errorMessage": null, 
                "osSku": "Windows2022", 
                "osType": "Windows", 
                "ready": true 
              } 
            ], 
            "upgrades": null 
          } 
...
```

Once the VHDs show `ready` as **true**, you can proceed to [create a Windows node pool](howto-create-windows-node-pools.md), and deploy your Windows-based workloads.

## Disable the Windows node pool feature on AKS clusters

If you no longer need to use Windows node pools on your AKS cluster, you can disable the Windows node pool feature. Disabling this feature removes the Windows VHDs from your Azure Local instance, and prevents any further operations on Windows node pools. If you have existing Windows node pools, you must delete them before you can disable this feature.

### Step 1: Delete existing Windows node pools

If you intend to disable the Windows node pool feature on your cluster, it's recommended that you delete any Windows node pool that you already have. You can delete your Windows node pools either from the Azure portal or using the CLI, as follows:

```azurecli
az aksarc nodepool delete --name "<nodepool-name>" --cluster-name "<cluster-name>" --resource-group $resourceGroup 
```

### Step 2: Disable the Windows node pool feature on your cluster

To disable the Windows node pool feature, you must access an Azure Local node. First, [Connect to the Azure Local node](#step-1-connect-to-an-azure-local-node).

In the remote PowerShell session, sign in to Azure, to the subscription where the Azure Local instance resides.

```azurecli
az login --use-device-code --tenant <Azure tenant ID>
az account set -s <subscription ID>
```

Install the **Support.AksArc** module using the following command:

```powershell
Install-Module -Name Support.AksArc
Import-Module Support.AksArc -Force
```

You can then run the following command to disable the Windows node pool feature and delete the Windows-related VHDs from your Azure Local instance.

```powershell
Invoke-SupportAksArcRemediation_DisableWindowsNodepool -Verbose
```

This command disables the Windows node pool feature and deletes the existing Windows VHDs.

### Step 3: Verify that the Windows VHDs are no longer available

Next, check if the Windows node pools were disabled by running the following command. You can see that the `errorMessage` parameter shows that the Windows node pool feature is disabled and the `ready` parameter shows as **false**, for each of the Kubernetes versions:

```azurecli
az aksarc get-versions --resource-group $resourceGroup --custom-location $customlocationName
```

```output
...
     - patchVersion: 1.29.4 
          readiness: 
          - osSku: CBLMariner 
            osType: Linux 
            ready: true 
          - errorMessage: Windows nodepool feature is disabled 
            isDisabled: true 
            osSku: Windows2019 
            osType: Windows 
            ready: false 
          - errorMessage: Windows nodepool feature is disabled 
            isDisabled: true 
            osSku: Windows2022 
            osType: Windows 
            ready: false 
....
```

You can verify if Windows VHDs were removed from the Azure Local storage paths. Deletion can take a while, so wait about 30 minutes before checking. You must check all the storage paths, because Windows VHDs are assigned to storage paths in round-robin fashion, based on available storage capacity.


## Next steps

- [Add a node pool](manage-node-pools.md#add-a-node-pool)
- [Delete a node pool](manage-node-pools.md#delete-a-node-pool)
