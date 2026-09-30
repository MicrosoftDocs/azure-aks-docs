---
title: AKS Edge Essentials update (online)
description: Learn how to update AKS Edge Essentials clusters.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.custom: template-how-to, edge-essentials
---

# Update AKS Edge Essentials clusters (online)

As newer versions of AKS Edge Essentials become available, you can update your AKS Edge Essentials clusters to take advantage of the latest features and security improvements. This article describes how to update and upgrade your AKS Edge Essentials devices when fixes and a new version are available.

The AKS Edge Essentials cluster is comprised of two main components that need to be updated. The first is the Mariner Linux VM. This virtual machine is installed as a part of the AKS Edge Essentials MSI, and has no package manager, so you can't manually update or change any of the VM components. Instead, the virtual machine is managed with Microsoft Update to automatically keep the components up to date. Second, the Kubernetes platform can be upgraded to stay in sync with the open-source version and the AKS service.  

Microsoft Update reliably updates the AKS Edge Essentials virtual machine. The virtual machine uses the A/B update partition scheme, to make each update safe and enable a rollback to a previous version if anything goes wrong during the update process.

AKS Edge Essentials upgrades are sequential and you must upgrade to every version. To get to the latest version, you must either do a fresh installation using the latest available version, or apply all the previous servicing updates, up to the desired version.

## Step 1: configure the host machine to receive updates using Microsoft Update

To receive AKS Edge Essentials updates, configure the Windows host to receive updates for other Microsoft products. By default, Microsoft Update is enabled during AKS Edge Essentials installation. If custom configuration is needed after installation, you can turn this option on or off using the following steps:

1. Open **Settings** on the Windows host.
1. Select **Updates & Security**.
1. Select **Advanced options**.
1. Toggle the **Receive updates for other Microsoft products when you update Windows** button to **On**.

Microsoft Update in the Windows Update subsystem can now scan for an update for AKS Edge Essentials based on the Windows Update policy set on the machine. If you want to force the scan immediately, you can select **Check for updates**.

> [!IMPORTANT]
> Microsoft Update must be enabled on all machines in the cluster.

After the update is downloaded from either the cloud endpoint or a local WSUS server, it can be staged and installed on all the nodes on a machine.

## Step 2: update files on all nodes

On all nodes in your cluster, run `Start-AksEdgeUpdate` to install the MSI and other related files:

```powershell
Start-AksEdgeUpdate
```

## Step 3: update the primary control node

If you have more than one control node in your deployment, first update the primary control node using the following command:

```powershell
Start-AksEdgeControlPlaneUpdate -firstControlPlane $true
```

## Step 4: update the secondary control nodes

You can then update the other control nodes using the following command:

```powershell
Start-AksEdgeControlPlaneUpdate -firstControlPlane $false
```

## Step 5: update worker nodes

Update the worker nodes in your cluster by running the following command on each of the worker nodes:

```powershell
Start-AksEdgeWorkerNodeUpdate 
```

## Update using Windows Server Update Services (WSUS)

On-premises updates using WSUS is supported for AKS Edge Essentials updates. For more information about WSUS, see [Device Management Overview - WSUS](/windows/iot/iot-enterprise/device-management/device-management-overview#windows-server-update-services-wsus).

## Upgrade to newer versions

For a list of currently supported Kubernetes versions on both K3s and K8s, see the table in [Download AKS Edge Essentials](aks-edge-howto-setup-machine.md#download-aks-edge-essentials). As we continue to add support to newer versions, you can use over-the-air updates to the newer versions. To upgrade your clusters to newer versions, set the `Set-AksEdgeUpgrade` command to `true`:

```powershell
Set-AksEdgeUpgrade – AcceptUpgrade $true
```

You can then select **Check for Updates** to download and stage an update if applicable. Then, run the `Start-AksEdgeUpdate` to complete the update:

```powershell
Start-AksEdgeUpdate
```

This command then triggers the version upgrade.

## Next steps

- [Overview](aks-edge-overview.md)
- [Uninstall AKS cluster](aks-edge-howto-uninstall.md)
