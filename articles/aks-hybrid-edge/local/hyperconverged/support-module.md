---
title: Support.AksArc diagnostic and remediation tool
description: Learn how to run commands in the Support.AksArc PowerShell module to diagnose and remediate issues in AKS environments.
ms.topic: troubleshooting
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.reviewer: sumsmith
ms.lastreviewed: 07/22/2025
ms.custom: hyperconverged

---

# Use the Support Tool to troubleshoot and fix AKS related issues

The [**Support Tool**](https://www.powershellgallery.com/packages/Support.AksArc) is a PowerShell module that provides diagnostic and remediation capabilities for AKS environments. Before you open a support request, you can run the specified commands in this module to help diagnose and potentially resolve issues. 

## Benefits

The Support Tool uses simple commands to identify issues without expert product knowledge. The tool provides:

- **Fixes for installation and upgrade issues**: Identifies and attempts to remediate common issues that occur during the installation and upgrade process.
- **Diagnostic checks**: Provides diagnostic health checks based on common issues, incidents, and telemetry data.
- **Enables Windows node pool feature**: Allows users to enable Windows node pools and download the required VHDs before creating Windows node pools.
- **Regular updates**: Updates with new checks and useful commands to manage, troubleshoot, and diagnose issues in AKS.

## Common issues where the Support tool might help

You should run the commands if you experience any of the following symptoms:

- Solution upgrade fails in MOC binaries state.
- Solution upgrade fails in Arc Resource Bridge stage.
- MOC service doesn't stay online.
- Arc Resource Bridge is offline.

## Prerequisites

Before you begin, make sure that:

- You have access to an Azure Local system that runs 2311 or higher. The system should be registered with Azure.
- You have access to a client that can connect to your Azure Local.

## Connect to your Azure Local instance

Follow these steps on your client to connect to one of the machines in your Azure Local.

1. Run PowerShell as an administrator on the client that you use to connect to your system.
1. Open a remote PowerShell session to a machine on your Azure Local instance. Run the following command and provide the credentials for your machine when prompted:

   ```powershell
   $cred = Get-Credential
   Enter-PSSession -ComputerName "<Azure Local node IP>" -Credential $cred 
   ```

   > [!NOTE]
   > Sign in using your deployment user account credentials. This is the account you created when preparing [Active Directory](/azure/azure-local/deploy/deployment-prep-active-directory) and used to deploy Azure Local.


   <details>
   <summary>Expand this section to see an example output.</summary>


   Here's an example output:

   ```Console
   PS C:\Users\Administrator> $cred = Get-Credential
     
   cmdlet Get-Credential at command pipeline position 1
   Supply values for the following parameters:
   Credential
   PS C:\Users\Administrator> Enter-PSSession -ComputerName "100.100.100.10" -Credential $cred 
   [100.100.100.10]: PS C:\Users\Administrator\Documents>
   ```

   </details>

## Installation

To install the Support Tool module, run the following commands:

```powershell
Install-Module -Name Support.AksArc
Import-Module Support.AksArc -force
```

If you already have the module installed, you can update it using the following cmdlet:

```powershell
Update-Module -Name Support.AksArc
```

>[!NOTE]
>When you import the module, it attempts to automatically update it from the PowerShell gallery. You can also update manually using the following methods.

Ensure that you have the latest module loaded into the current instance by removing and importing the module:

```powershell
Remove-Module -Name Support.AksArc
Import-Module -Name Support.AksArc
```

## Use the AKS Support Tool

This section provides examples of the different cmdlets available in the Support Tool.

> [!NOTE]
> Make sure to run these PowerShell commands locally, not in a PowerShell remote session.

### View available cmdlets

To see a list of available cmdlets in the PowerShell module, run the following cmdlet:

```powershell
Get-Command -Module Support.AksArc
```

### Perform diagnostic checks

You can perform a diagnostic health check against the system to help detect common issues:

```powershell
Test-SupportAksArcKnownIssues
```

The following example output from the `Test-SupportAksArcKnownIssues` command shows the results of a failed test:

```output
Test Name                                                  Status Message
---------                                                  --------------
Validate Failover Cluster Service Responsiveness           Passed Failover Cluster service is responsive.
Validate Missing MOC Cloud Agents                          Passed No missing MOC cloud agents found.
Validate MOC Cloud Agent Running                           Passed MOC Cloud Agent is running
Validate Missing MOC Node Agents                           Passed All MOC nodes have the Node Agent service installed and healthy.
Validate Missing MOC Host Agents                           Passed All nodes have MOC host agents installed and healthy
Validate MOC is on Latest Patch Version                    Failed MOC is not on the latest patch version. Current: 1.15.5.10626, Latest: 1.15.7.10719
Validate Expired Certificates                              Passed No expired certificates found
Validate MOC Nodes Not Active                              Passed All MOC nodes are in the 'Active' state
Validate Multiple MOC Cloud Agent Instances                Passed No multiple instances of MOC Cloud Agent found
Validate Windows Event Log Running                         Passed Windows Event Log is running
Validate Gallery Image Stuck In Deleting                   Passed No gallery images are stuck in deleting state
Validate Virtual Machine Stuck In Pending                  Passed No virtual machines are stuck in pending state
Validate Virtual Machine Management Service Responsiveness Passed Virtual Machine Management service is responsive
```

The following example output shows a successful result for all tests:

```output
Test Name                                                  Status Message
---------                                                  --------------
Validate Failover Cluster Service Responsiveness           Passed  Failover Cluster service is responsive.
Validate Missing MOC Cloud Agents                          Passed  No missing MOC cloud agents found.
Validate MOC Cloud Agent Running                           Passed  MOC Cloud Agent is running
Validate Missing MOC Node Agents                           Passed  All MOC nodes have the Node Agent service installed and healthy.
Validate Missing MOC Host Agents                           Passed  All nodes have MOC host agents installed and healthy.
Validate MOC is on Latest Patch Version                    Passed  MOC is on the latest patch version.
Validate Expired Certificates                              Passed  No expired certificates found.
Validate MOC Nodes Not Active                              Passed  All NMC nodes are in the 'Active' state.
Validate NMC Nodes Sync with Cluster Nodes                 Passed  All NMC nodes are in sync with cluster nodes.
Validate Multiple NMC Cloud Agent Instances                Passed  No multiple instances of NMC Cloud Agent found.
Validate NMC Powershell Not Stuck in Updating              Passed  NMC Powershell is not stuck in updating state.
Validate Windows Event Log Running                         Passed  Windows Event Log is running
Validate Gallery Image Stuck In Deleting                   Passed  No gallery images are stuck in deleting state.
Validate Virtual Machine Stuck In Pending                  Passed  No virtual machines are stuck in pending state.
Validate Virtual Machine Management Service Responsiveness Passed  Virtual Machine Management service is responsive.
```

### Remediate common issues

This command tests and fixes known issues with a given solution version:

```powershell
Invoke-SupportAksArcRemediation
```

### Enable Windows node pool feature

This command enables the Windows node pool feature on your AKS cluster:

```powershell
Invoke-SupportAksArcRemediation_EnableWindowsNodepool -Verbose
```

### Disable Windows node pool feature

This command disables the Windows node pool feature on your AKS cluster. Before running this command, ensure that you have no Windows node pools running on your cluster:

```powershell
Invoke-SupportAksArcRemediation_DisableWindowsNodepool -Verbose
```

## Next steps

[Use the diagnostic checker tool to identify common environment issues](aks-arc-diagnostic-checker.md)

