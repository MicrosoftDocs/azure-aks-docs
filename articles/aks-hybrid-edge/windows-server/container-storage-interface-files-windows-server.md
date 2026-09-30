---
title: Use Container Storage Interface (CSI) file drivers in AKS on Windows Server
description: Learn how to use Container Storage Interface (CSI) drivers to manage files in AKS on Windows Server.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.custom: sfi-ropc-nochange, windows-server

# Intent: As an IT Pro, I want to learn how to use Container Storage Interface (CSI) drivers in AKS on Windows Server.
# Keyword: container storage interface drivers, CSI drivers

---

# Use Container Storage Interface (CSI) file drivers in AKS on Windows Server

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

This article describes how to use Container Storage Interface (CSI) drivers for files to mount a Server Message Block (SMB) or NFS shares when multiple nodes need concurrent access to the same storage volume in AKS on Windows Server.

## Overview of CSI in AKS on Windows Server

[!INCLUDE [csi-in-aks-hybrid-overview](../includes/csi-in-aks-hybrid-overview.md)]

## Use persistent volumes using ReadWriteMany CSI drivers

If multiple nodes need concurrent access to the same storage volumes in AKS, you can use CSI drivers for files to mount SMB or NFS shares as **ReadWriteMany**. You must provision the SMB or NFS shares in advance.

### Use SMB drivers

1. Make sure the SMB driver is deployed. Deploy the driver using the following [Install-AksHciCsiSmb](/azure/aks/aksarc/reference/ps/install-akshcicsismb) PowerShell command:

   ```powershell
   Install-AksHciCsiSmb -clusterName mycluster
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

1. Deploy the driver using the following [Install-AksHciCsiSmb](/azure/aks/aksarc/reference/ps/install-akshcicsismb) PowerShell command:

   ```powershell
   Install-AksHciCsiNfs -clusterName mycluster
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

Use the following PowerShell commands to uninstall either the SMB or NFS drivers:

```powershell
Uninstall-AksHciCsiSMB -clusterName <clustername>
Uninstall-AksHciCsiNFS -clusterName <clustername>
```

## Next steps

- [Use disk Container Storage Interface drivers](./container-storage-interface-disks-windows-server.md)
