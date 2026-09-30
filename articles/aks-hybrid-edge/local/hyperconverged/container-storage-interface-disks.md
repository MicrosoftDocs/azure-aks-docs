---
title: Use Container Storage Interface (CSI) disk drivers in AKS Hybrid and Edge
description: Learn how to use Container Storage Interface (CSI) drivers to manage disks in AKS Hybrid and Edge.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak
ms.custom: hyperconverged

# Intent: As an IT Pro, I want to learn how to use Container Storage Interface (CSI) drivers in AKS.
# Keyword: container storage interface drivers, CSI drivers
---

# Use Container Storage Interface (CSI) disk drivers in AKS Hybrid and Edge

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

This article describes how to use Container Storage Interface (CSI) built-in storage classes to dynamically create disk persistent volumes and create custom storage classes in AKS Hybrid and Edge.

## Overview of CSI in AKS Hybrid and Edge

[!INCLUDE [csi-in-aks-hybrid-overview](../../includes/csi-in-aks-hybrid-overview.md)]

[!INCLUDE [csi-disks](../../includes/csi-disks.md)]

1. Create a new storage path using the `stack-hci-vm storagepath` cmdlets to create, show, and list the storage paths on your Azure Local cluster. For more information about storage path creation, see [storage path](/azure/azure-local/manage/create-storage-path).

   For `$path`, create a storage path named `$storagepathname`; for example, **C:\ClusterStorage\test-storagepath**:

   ```azurecli
   az stack-hci-vm storagepath create --resource-group $resource_group --custom-location $customLocationID --name $storagepathname --path $path
   ```

   Get the storage path resource ID:

   ```azurecli
   $storagepathID = az stack-hci-vm storagepath show --name $storagepathname --resource-group $resource_group --query "id" -o tsv 
   ```

1. Create a new custom storage class using the new storage path.

   1. Create a file named **sc-aks-hci-disk-custom.yaml**, and then copy the manifest from the following YAML file. The storage class is the same as the default storage class except with the new `container`. Use the `storage path ID` created in the previous step for `container`. For `group` and `hostname`, query the default storage class by running `kubectl get storageclass default -o yaml`, and then use the values that are specified:

      ```yaml
      kind: StorageClass
      apiVersion: storage.k8s.io/v1
      metadata:
       name: aks-hci-disk-custom
      provisioner: disk.csi.akshci.com
      parameters:
       blocksize: "33554432"
       container: <storage path ID>
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

[Use the Container Storage Interface file drivers](container-storage-interface-files.md)
