---
author: davidsmatlak
ms.author: davidsmatlak
ms.service: azure-kubernetes-service-hybrid
ms.topic: include
ms.date: 09/01/2026
ms.lastreviewed: 10/18/2022

---

## Dynamically create disk persistent volumes using built-in storage class

A *storage class* is used to define how a unit of storage is dynamically created with a persistent volume. For more information about how to use storage classes, see [Kubernetes storage classes](https://kubernetes.io/docs/concepts/storage/storage-classes/).

In AKS, the default storage class uses CSI to create VHDX-backed volumes. The reclaim policy ensures that the underlying VHDX is deleted when the persistent volume that used it is deleted. The storage class also configures the persistent volumes to be expandable; you just need to edit the persistent volume claim with the new size.

To use this storage class, create a [Persistent Volume Claim (PVC)](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) and a respective pod that references and uses it. A PVC is used to automatically provision storage based on a storage class. A PVC can use one of the pre-created storage classes or a user-defined storage class to create a VHDX of the desired size. When you create a pod definition, the PVC is specified to request the desired storage.

## Create custom storage class for disks

The default storage class is suitable for most common scenarios. However, in some cases, you may want to create your own storage class that stores PVs at a particular location mapped to a specific performance tier.

If you have Linux workloads (pods), you must create a custom storage class with the parameter `fsType: ext4`. This requirement applies to Kubernetes versions 1.19 and 1.20 or later. The following example shows a custom storage class definition with `fsType` parameter defined:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: aks-hci-disk-custom
parameters:
  blocksize: "33554432"
  container: SqlStorageContainer
  dynamic: "true"
  group: clustergroup-summertime
  hostname: TESTPATCHING-91.sys-sqlsvr.local
  logicalsectorsize: "4096"
  physicalsectorsize: "4096"
  port: "55000"
  fsType: ext4
provisioner: disk.csi.akshci.com
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
```

If you create a custom storage class, you can specify the location in which you want to store PVs. If the underlying infrastructure is Azure Local, this new location could be a volume that's backed by high-performing SSDs/NVMe, or a cost-optimized volume backed by HDDs.

Creating a custom storage class is a two-step process:
