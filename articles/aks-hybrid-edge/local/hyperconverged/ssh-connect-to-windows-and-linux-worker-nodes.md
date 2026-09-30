---
title: Connect to Windows or Linux worker nodes with SSH
description: Learn how to use SSH to connect to Windows or Linux worker nodes in an AKS cluster.
ms.date: 09/01/2026
ms.topic: how-to
author: davidsmatlak
ms.author: davidsmatlak
ms.reviewer: leslielin
ms.lastreviewed: 07/02/2025
ms.custom: hyperconverged
---

# Connect to Windows or Linux worker nodes with SSH

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

During your AKS cluster's lifecycle, you might need to directly access cluster nodes for maintenance, log collection, or troubleshooting operations. For security purposes, you must use a Secure Shell Protocol (SSH) connection to access Windows or Linux worker nodes. You sign in using the node's IP address.

This article explains how to use SSH to connect to both Windows and Linux nodes.

## Prerequisites

### **Install the Kubernetes CLI**

You can use the Kubernetes CLI, [**kubectl**](https://kubernetes.io/docs/reference/kubectl/), to connect to your Kubernetes cluster. If you use Azure Cloud Shell, **kubectl** is already installed. If you run the commands locally, you can use the Azure CLI or Azure PowerShell to install **kubectl**.

### [Azure CLI](#tab/azure-cli)

* Install **kubectl** locally using the [`az aks install-cli`](/cli/azure/aks?view=azure-cli-latest&preserve-view=true#az-aks-install-cli) command:

  ```azurecli-interactive
  az aks install-cli
  ```

### [Azure PowerShell](#tab/azure-powershell)

* Install **kubectl** locally using the [`Install-AzAksCliTool`](/powershell/module/az.aks/install-azaksclitool?view=azps-14.2.0&preserve-view=true) cmdlet:

  ```azurepowershell-interactive
  Install-AzAksCliTool
  ```

---

## Use SSH to connect to worker nodes

1. To access the Kubernetes cluster with the specified permissions, you must retrieve the certificate-based admin **kubeconfig** file using the [az aksarc get-credentials](/cli/azure/aksarc#az-aksarc-get-credentials) command. For more information, see [Retrieve certificate-based admin kubeconfig](retrieve-admin-kubeconfig.md):

   ```azurecli
   az aksarc get-credentials --resource-group $<resource_group_name> --name $<aks_cluster_name> --admin
   ```

1. Run **kubectl get** to obtain the node's IP address and capture its IP value in order to sign in to a Windows or Linux worker node using SSH:

   ```azurecli
   kubectl --kubeconfig /path/to/aks-cluster-kubeconfig get nodes -o wide
   ```

1. Run `ssh` to connect to a worker node:

   > [!NOTE]
   > You must pass the correct location to your SSH private key. The following example uses the default location of **~/.ssh/id_rsa**, but you might need to change this location if you requested a different path. To change the location, see [Configure SSH keys](configure-ssh-keys.md) to specify the `--ssh-key-value` parameter when you create an AKS cluster.

   For a Linux worker node, run the following command:

   ```azurecli
   ssh -i $env:USERPROFILE\.ssh\id_rsa clouduser@<IP address of the node>
   ```
   
   For a Windows worker node, run the following command:
   
   ```azurecli
   ssh -i $env:USERPROFILE\.ssh\id_rsa Administrator@<IP address of the node>
   ```

If you encounter SSH login issues, verify that your IP address is included in the **--ssh-auth-ip list**. To check this list, run `az aksarc show --name "$<aks_cluster_name>" --resource-group "$<resource_group_name>"` and look for `authorizedIpRanges` under `clusterVmAccessProfile`.

## Next steps

- [Use SSH keys to get on-demand logs for troubleshooting](get-on-demand-logs.md)
- [Configure SSH keys for an AKS cluster](configure-ssh-keys.md)
- Help to protect your cluster in other ways by following the guidance in the [security book for AKS Hybrid and Edge](/azure/azure-arc/kubernetes/conceptual-security-book?toc=/azure/aks/aksarc/toc.json&bc=/azure/aks/aksarc/breadcrumb/toc.json).