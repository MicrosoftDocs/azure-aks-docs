---
title: Use Container Storage Interface (CSI) disk drivers in AKS on Windows Server
description: Learn how to use Container Storage Interface (CSI) drivers to manage disks in AKS Hybrid and Edge on Windows Server.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak
ms.custom: windows-server

---

# Use Container Storage Interface (CSI) disk drivers in AKS on Windows Server

[!INCLUDE [aks-hybrid-applies-to-azure-stack-hci-windows-server-sku](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

This article describes how to use Container Storage Interface (CSI) built-in storage classes to dynamically create disk persistent volumes and create custom storage classes in AKS Hybrid and Edge.

## Overview of CSI in AKS on Windows Server

[!INCLUDE [csi-in-aks-hybrid-overview](../includes/csi-in-aks-hybrid-overview.md)]

[!INCLUDE [csi-disks](../includes/csi-disks.md)]

1. Create a new storage container using the following [New-AksHciStorageContainer](/azure/aks/aksarc/reference/ps/new-akshcistoragecontainer) PowerShell command:

   ```powershell
   New-AksHciStorageContainer -Name <e.g. customStorageContainer> -Path <shared storage path>
   ```

   Check whether the new storage container is created by running the following [Get-AksHciStorageContainer](/azure/aks/aksarc/reference/ps/get-akshcistoragecontainer) PowerShell command:

   ```powershell
   Get-AksHciStorageContainer -Name "customStorageContainer"
   ```

1. Create a new custom storage class using the new storage path.

   1. Create a file named **sc-aks-hci-disk-custom.yaml**, and then copy the manifest from the following YAML file. The storage class is the same as the default storage class except with the new `container`. Use the `storage container name` created in the previous step for `container`. For `group` and `hostname`, query the default storage class by running `kubectl get storageclass default -o yaml`, and then use the values that are specified:

      ```yaml
      kind: StorageClass
      apiVersion: storage.k8s.io/v1
      metadata:
       name: aks-hci-disk-custom
      provisioner: disk.csi.akshci.com
      parameters:
       blocksize: "33554432"
       container: <storage container name>
       dynamic: "true"
       group: <e.g clustergroup-akshci> # same as the default storageclass
       hostname: <e.g. ca-a858c18c.ntprod.contoso.com> # same as the default storageclass
       logicalsectorsize: "4096"
       physicalsectorsize: "4096"
       port: "55000"
       fsType: ext4 # refer to the note above to determine when to include this parameter
      allowVolumeExpansion: true
      reclaimPolicy: Delete
      volumeBindingMode: Immediate
      ```

   1. Create the storage class with the [kubectl apply](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply/) command and specify your **sc-aks-hci-disk-custom.yaml** file:

      ```azurecli
      $ kubectl apply -f sc-aks-hci-disk-custom.yaml
      storageclass.storage.k8s.io/aks-hci-disk-custom created
      ```

## Next steps

[Use Container Storage Interface file drivers](container-storage-interface-files-windows-server.md)