---
author: davidsmatlak
ms.author: davidsmatlak
ms.service: azure-kubernetes-service-hybrid
ms.topic: include
ms.date: 09/01/2026
ms.lastreviewed: 05/02/2022

---

Follow these steps on all nodes in your Windows Server cluster:

> [!NOTE]
> If you are using remote PowerShell, you must use CredSSP.

1. Close all open PowerShell windows, open a new PowerShell session as administrator, and run the following command on all nodes in your Windows Server cluster:

   ```powershell
   Install-PackageProvider -Name NuGet -Force
   Install-Module -Name PowershellGet -Force -Confirm:$false
   ```

   You must close all existing PowerShell windows again to ensure that loaded modules are refreshed. Don't continue to the next step until you close all open PowerShell windows.

1. Install the **AksHci** PowerShell module by running the following command on all nodes in your Windows Server cluster:

   ```powershell
   Install-Module -Name AksHci -Repository PSGallery -Force -AcceptLicense
   ```

   You must close all existing PowerShell windows again to ensure that loaded modules are refreshed. Don't continue to the next step until you close all open PowerShell windows.

You can use a [helper script to delete old AKS-HCI PowerShell modules](https://github.com/Azure/aksArc/issues/130), to avoid any PowerShell version-related issues in your AKS deployment.

### Validate your installation

```powershell
Get-Command -Module AksHci
```

For the complete list of **AksHci** PowerShell commands, see [AksHci PowerShell](/azure/aks/aksarc/reference/ps/index).
