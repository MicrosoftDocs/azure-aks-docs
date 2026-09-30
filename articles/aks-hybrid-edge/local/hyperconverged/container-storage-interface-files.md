---
title: Use Container Storage Interface (CSI) file drivers in AKS Hybrid and Edge
description: Learn how to use Container Storage Interface (CSI) drivers to manage files in AKS.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 01/14/2022
ms.reviewer: srikantsarwa
ms.custom: sfi-ropc-nochange, hyperconverged

# Intent: As an IT Pro, I want to learn how to use Container Storage Interface (CSI) drivers in AKS.
# Keyword: container storage interface drivers, CSI drivers

---

# Use Container Storage Interface (CSI) file drivers in AKS Hybrid and Edge

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

This article describes how to use Container Storage Interface (CSI) drivers for files to mount a Server Message Block (SMB) or NFS shares when multiple nodes need concurrent access to the same storage volume in AKS Hybrid and Edge.

## Overview of CSI in AKS

[!INCLUDE [csi-in-aks-hybrid-overview](../../includes/csi-in-aks-hybrid-overview.md)]

## Use persistent volumes using ReadWriteMany CSI drivers

If multiple nodes need concurrent access to the same storage volumes in AKS, you can use CSI drivers for files to mount SMB or NFS shares as **ReadWriteMany**. You must provision the SMB or NFS shares in advance.

### Use SMB drivers

1. Make sure the SMB driver is deployed. The SMB CSI driver is installed by default when you create a Kubernetes cluster using the `az aksarc create` command. If you create the AKS cluster using the Azure portal, an Azure Resource Manager (ARM) template, or Terraform, the SMB CSI driver is not installed by default. You must enable the SMB driver on the AKS cluster.
The equivalent Azure CLI command to update an existing AKS cluster and enable SMB is:

   ```azurecli
   az aksarc update -n $aksclustername -g $resource_group --enable-smb-driver
   ```

1. Create Kubernetes secrets to store the credentials required to access SMB shares by running the following command:

   ```console
   kubectl create secret generic smbcreds --from-literal username=$username --from-literal password=$password --from-literal domain=$domain
   ```

1. Create a storage class using `kubectl` to create a new SMB storage class with the following manifest:

   ```yaml
   apiVersion: storage.k8s.io/v1
   kind: StorageClass
   metadata:
     name: smb-csi
   provisioner: smb.csi.akshci.com
   parameters:
      source: \\smb-server\share
      csi.storage.k8s.io/node-stage-secret-name: "smbcreds"
      csi.storage.k8s.io/node-stage-secret-namespace: "default"
   reclaimPolicy: Retain  # only Retain is supported
   volumeBindingMode: Immediate
   mountOptions:
     - dir_mode=0777
     - file_mode=0777
     - uid=1001
     - gid=1001
   ```  

### Use NFS drivers

1. Make sure the SMB driver is deployed. The SMB CSI driver is installed by default when you create a Kubernetes cluster using the `az aksarc create` command. If you create the AKS cluster using the Azure portal, an Azure Resource Manager (ARM) template, or Terraform, the SMB CSI driver is not installed by default. You must enable the SMB driver on the AKS cluster.
The equivalent Azure CLI command to update an existing AKS cluster and enable SMB is:

   ```azurecli
   az aksarc update -n $aksclustername -g $resource_group --enable-nfs-driver
   ```

1. Create an NFS storage class using the following manifest:

      ```yaml
      apiVersion: storage.k8s.io/v1
      kind: StorageClass
      metadata:
        name: nfs-csi
      provisioner: nfs.csi.akshci.com
      parameters:
        server: nfs-server.default.svc.cluster.local # NFS server endpoint
        share: / # NFS share path
      reclaimPolicy: Retain
      volumeBindingMode: Immediate
      mountOptions:
        - hard
        - nfsvers=4.1
      ```

### To uninstall SMB or NFS drivers

Use the following Azure CLI commands to uninstall either the SMB or NFS drivers:

```azurecli
az aksarc update -n $aksclustername -g $resource_group --disable-smb-driver
az aksarc update -n $aksclustername -g $resource_group --disable-nfs-driver
```

## Next steps

- [Use the disk Container Storage Interface drivers](./container-storage-interface-disks.md)
