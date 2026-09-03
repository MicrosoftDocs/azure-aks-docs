---
title: Restrict SSH access to virtual machines in AKS on Windows Server
description: Learn how to restrict SSH access in AKS on Windows Server.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 04/27/2023
ms.reviewer: oadeniji
ms.custom: windows-server


# Intent: As an IT Pro, I want to restrict access to some IP addresses and CIDRs in AKS on Windows Server.

---

# Restrict SSH access to virtual machines in AKS on Windows Server

[!INCLUDE [aks-hybrid-applies-to-azure-stack-hci-windows-server-sku](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

This article describes a new security feature in AKS that restricts Secure Shell Protocol (SSH) access to underlying virtual machines (VMs). The feature limits access to only certain IP addresses, and restricts the set of commands that you can run over SSH.

## Overview

Currently, anyone with administrator access to AKS on Windows Server has access to VMs through SSH on any machine. In some scenarios, you might want to limit that access, because unlimited access makes it difficult to pass compliance.

> [!NOTE]
> Currently, this capability is available only for a new installation of AKS, and not for upgrades. Only a new installation of AKS can pass the restricted IPs and restrict the commands that run over SSH.

## Enable SSH restrictions

To enable SSH restrictions, perform the following steps:

1. Create an SSH configuration using the [New-AksHciSSHConfiguration](/azure/aks/aksarc/reference/ps/new-akshcisshconfiguration) cmdlet, with the allowed source IP addresses or CIDR you want to permit access to the VMs:

   ```powershell
   $ssh = New-AksHciSSHConfiguration -name sshConfig -cidr 172.16.0.0/24
   ```

   or

   ```powershell
   $ssh = New-AksHciSSHConfiguration -name sshConfig -ipAddresses 4.4.4.4,8.8.8.8
   ```

   or, to restrict SSH access:

   ```powershell
   $ssh = New-AksHciSSHConfiguration -name sshConfig –restrictSSHCommands 
   ```

   > [!NOTE]
   > If the SSH keys aren't passed, the management cluster SSH keys are reused.

1. Add the SSH configuration by running the [Set-AksHciConfig](/azure/aks/aksarc/reference/ps/set-akshciconfig) cmdlet, passing in the SSH configuration you created in the previous step:

   ```powershell
   Set-AksHciConfig -ssh $ssh
   ```

### Validation: target cluster

Once you create the cluster, you can manually validate that the SSH restriction was added by trying to SSH into one of the VMs. For example:

```powershell
ssh -i (get-MocConfig).sshPrivateKey clouduser@<vm-ipaddress>
```

You can perform this step within the list of IP addresses/CIDRs specified, or outside the list of IP addresses. The SSH from within the range of IP addresses/CIDRs has access. SSH attempts from outside the list do not have access.

You can also run commands directly from SSH. This command returns the date. `Sudo` commands don't work:

```powershell
ssh -i (get-mocconfig).sshPrivateKey clouduser@<ip> date 
```

### Validation: log collection

This command returns the VM logs such as `cloudinit`, `lb` logs, etc.

```powershell
Get-AksHciLogs –virtualMachineLogs
```

### Considerations

- Individual SSH configuration for workload clusters is now available. The configuration for workload clusters uses the [New-AksHciSSHConfiguration](/azure/aks/aksarc/reference/ps/new-akshcisshconfiguration) PowerShell cmdlet.
- The restriction is only for Linux. Windows nodes don't have this restriction; you should be able to SSH successfully.
- You can only set the configuration during the installation phase of AKS.
- You must perform a reinstall if you incorrectly configure any SSH settings.
- There is no support for upgrades.
- You can add CIDRs or IP addresses to which the SSH access can be restricted.
- The SSH setting you provide is reused for all target clusters. Individual SSH configuration for workload clusters isn't available.

## Next steps

- [Restrict SSH access in AKS on Azure Local](../local/hyperconverged/restrict-ssh-access.md)
- [AKS on Windows Server overview](../aks-overview.md)
