---
author: davidsmatlak
ms.author: davidsmatlak
ms.service: azure-kubernetes-service-hybrid
ms.topic: include
ms.date: 09/01/2026
ms.lastreviewed: 10/18/2022

# Overview of CSI file and driver functionality in AKS Hybrid and Edge

---

The Container Storage Interface (CSI) is a standard for exposing arbitrary block and file storage systems to containerized workloads on Kubernetes. By using CSI, AKS Hybrid and Edge can write, deploy, and iterate plug-ins to expose new storage systems. CSI can also improve existing ones in Kubernetes without having to touch the core Kubernetes code and then wait for its release cycles.

The disk and file CSI drivers used by AKS are [CSI specification](https://github.com/container-storage-interface/spec/blob/master/spec.md)-compliant drivers.

The CSI storage driver support on AKS allows you to use:

- AKS disks that you can use to create a Kubernetes *DataDisk* resource. These are mounted as *ReadWriteOnce*, so they're only available to a single pod at a time. For storage volumes that can be accessed by multiple pods simultaneously, use [AKS files](../local/hyperconverged/container-storage-interface-files.md).

- AKS files that you can use to mount an SMB or NFS share to pods. These are mounted as *ReadWriteMany*, so you can share data across multiple nodes and pods. They can also be mounted as *ReadWriteOnce* based on the PVC (persistent volume claim) specification.
