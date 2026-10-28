---
title: Restart, remove, or reinstall Azure Kubernetes Service 
description: Learn how to restart, remove, or reinstall AKS on Windows Server.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.custom: windows-server

# Intent: As an IT Pro, I want to learn how to restart, remove, and/or reinstall my AKS deployment when necessary.
# Keyword: AKS restart AKS removal

---

# Restart, remove, or reinstall Azure Kubernetes Service

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

After you deploy AKS, you can restart, remove, or reinstall your deployment if necessary.

## Restart AKS

Restarting AKS removes all of your Kubernetes clusters (if any) and the Azure Kubernetes Service host. The restart process also uninstalls the AKS agents and services from the nodes. Then, it repeats the original install process steps until the host is recreated. The AKS configuration that you configured via [Set-AksHciConfig](/azure/aks/aksarc/reference/ps/set-akshciconfig) and the downloaded VHDX images are preserved. The `Set-AksHciConfig` command removes the current VMs and creates new ones.

To restart AKS with the same configuration settings, run the following command:

```powershell
Restart-AksHci
```

## Remove AKS

To remove AKS, run the following [Uninstall-AksHci](/azure/aks/aksarc/reference/ps/uninstall-akshci) command. This command removes the old configuration, and you must run [Set-AksHciConfig](/azure/aks/aksarc/reference/ps/set-akshciconfig) again when you reinstall.

If your clusters are Arc-enabled, delete any Azure resources before proceeding. To delete any associated Arc resources for your on-premises cluster, follow the guidance for [cleaning up Azure Arc resources](/azure/azure-arc/kubernetes/quickstart-connect-cluster#clean-up-resources).

```powershell
Uninstall-AksHci
```

If you want to retain the old configuration, run the following command:

```powershell
Uninstall-AksHci -SkipConfigCleanup
```

## Reinstall configuration settings and AKS

To reinstall AKS after uninstalling it, follow these instructions.

If you ran the `Uninstall-AksHci` command with the `-SkipConfigCleanup` parameters, your old configuration settings were retained. To reinstall, run the following command:

```powershell
Install-AksHci
```

If you didn't use the `-SkipConfigCleanup` parameter when uninstalling, then you must reset your configuration settings with the following commands. This example command creates a virtual network with a static IP address. If you want to configure your AKS deployment with DHCP, see [new-akshcinetworksetting](/azure/aks/aksarc/reference/ps/new-akshcinetworksetting) for examples of how to configure DHCP:

```powershell
# static IP
$vnet = New-AksHciNetworkSetting -name myvnet -vswitchName "extSwitch" -k8sNodeIpPoolStart "172.16.10.0" -k8sNodeIpPoolEnd "172.16.10.255" -vipPoolStart "172.16.255.0" -vipPoolEnd
"172.16.255.254" -ipAddressPrefix "172.16.0.0/16" -gateway "172.16.0.1" -dnsServers "172.16.0.1"

Set-AksHciConfig -imageDir c:\clusterstorage\volume1\Images -workingDir c:\ClusterStorage\Volume1\ImageStore -cloudConfigLocation c:\clusterstorage\volume1\Config -vnet $vnet -cloudservicecidr "172.16.10.10/16"

Install-AksHci
```

## Next steps

In this article, you learned how to restart, remove, or reinstall Azure Kubernetes Service in AKS. Next, you can:

- [Deploy a Linux application on a Kubernetes cluster](./deploy-linux-application.md)
- [Deploy a Windows Server application on a Kubernetes cluster](./deploy-windows-application.md)
