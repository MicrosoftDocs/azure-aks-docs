---
title: Uninstall AKS Edge Essentials
description: Learn how to uninstall AKS Edge Essentials. 
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.custom: edge-essentials
  - template-how-to
  - devx-track-azurecli
---

# Uninstall an AKS Edge Essentials cluster

This article describes how to uninstall AKS Edge Essentials.

## Disconnect from Azure Arc

If you used `Connect-AideArcKubernetes` to connect to Azure Arc, run `Disconnect-AideArcKubernetes` to disconnect your cluster from Azure Arc. For a complete cleanup, delete the service principal and resource group you created for this example:

```powershell
Disconnect-AideArcKubernetes
```

Run `Disconnect-AksEdgeArc` to disconnect your cluster from Azure Arc:

```powershell
Disconnect-AksEdgeArc -JsonConfigFilePath .\aksedge-config.json
```

You can also manually remove the cluster from Arc using the Azure portal and delete the Arc pods in the cluster.

## Remove your application from cluster

Delete the applications that you deployed using the following command:

```powershell
kubectl delete -f ./path-to-your-YAML-file/app.yaml
```

For example, if you deployed the sample Linux application, you can delete it using:

```powershell
kubectl delete -f linux-sample.yaml
```

## Remove nodes on a single-machine cluster

To remove the Windows node only, issue the following command:

```powershell
Remove-AksEdgeNode -nodeType Windows
```

To remove your single machine cluster with a `Linux` or `LinuxandWindows` workload, run:

```powershell
Remove-AksEdgeDeployment

# or run
Remove-AksEdgeDeployment -Force #to force removal of all clusters.
```

You can't remove the Linux node alone in this configuration; you must remove the deployment if you need to remove the Linux node.

> [!NOTE]
> If your single-machine cluster doesn't clean up properly, run `hnsdiag list networks`, then delete any existing AKS Edge Essentials network objects using `hnsdiag delete networks <ID>`.

> [!NOTE]
> There is a known issue in which repeatedly creating a new deployment and removing the node might result in an "error during ConnectToVirtualMachine." If this occurs, reboot your system to resolve the error.

## Remove nodes on a multi-machine cluster

Be careful when removing control plane nodes. Make sure you have another working control plane node before doing so.

To remove a Windows-only node:

```powershell
Remove-AksEdgeNode -NodeType Windows
```

To remove a Linux-only node:

```powershell
Remove-AksEdgeNode -NodeType Linux
```

During the removal of a control plane node from a cluster, it's important for the cluster administrator to verify that the cluster has completed reconciliation and that the removed node no longer serves as the leader.

You can verify this by running `kubectl get leases -A` and checking until the removed node is no longer a lease holder in the output. This is vital for maintaining cluster stability.

To remove both nodes:

```powershell
Remove-AksEdgeDeployment
```

> [!NOTE]
> There is a known issue in which repeatedly creating a new deployment and removing the node can result in an error. If this occurs, reboot your system to resolve the error.

## Uninstall AKS Edge Essentials

On your machine, go to **Settings > Apps > Apps & Features**. Alternatively, you can go to **Control Panel > Uninstall a Program**. From there, look for **Azure Kubernetes Service Edge Essentials (Public Preview)**. Select **Uninstall**.

> [!NOTE]
> You might want to reboot your machine right after the uninstall so that all resources are cleaned up, and your machine is ready for a new installation.

If you encounter any issues uninstalling AKS Edge Essentials, try downloading [this troubleshooting tool](https://support.microsoft.com/topic/fix-problems-that-block-programs-from-being-installed-or-removed-cca7d1b6-65a9-3d98-426b-e9f927e1eb4d) to uninstall.

## Uninstall Azure CLI

See [Uninstall Azure CLI](/cli/azure/install-azure-cli-windows#uninstall).

## Uninstall Az PowerShell

See [How to uninstall Azure PowerShell modules](/powershell/azure/uninstall-az-ps).

## Next steps

[Overview](aks-edge-overview.md)
