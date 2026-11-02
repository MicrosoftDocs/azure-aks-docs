---
title: Configure Azure Files for Azure Kubernetes Service
description: Learn how to configure Azure Files as persistent, shared storage for applications running on Azure Kubernetes Service (AKS).
ms.topic: concept-article
ms.custom: devx-track-azurecli
ms.subservice: aks-storage
ms.date: 10/14/2026
author: codefinite-vri
ms.author: vritikanaik

# Customer intent: As a Kubernetes developer, I want to configure Azure Files for my AKS cluster so that I can provision and manage persistent, shared storage for my applications.
---

# Configure Azure Files for Azure Kubernetes Service

Azure Files provides fully managed file shares that applications can access through the Server Message Block (SMB) or Network File System (NFS) protocol. By using the Azure Files Container Storage Interface (CSI) driver, you can mount Azure file shares as persistent volumes in Azure Kubernetes Service (AKS).

Azure Files supports the Kubernetes `ReadWriteMany` access mode, which allows multiple pods and nodes to access the same file share. Use Azure Files when your workloads require persistent shared storage, such as shared application content, configuration files, media, logs, or data-processing inputs and outputs.

This article explains the Azure Files storage options for AKS and helps you choose between dynamic and static provisioning. For step-by-step deployment instructions, see the linked articles in [Next steps](#next-steps).

## How Azure Files integrates with AKS

Kubernetes separates how storage is provided from how applications consume it:

- A **StorageClass** defines how the CSI driver dynamically provisions storage.
- A **PersistentVolume (PV)** represents storage available to the cluster.
- A **PersistentVolumeClaim (PVC)** requests storage for a workload.
- A pod mounts the PVC and accesses the Azure file share through its container file system.

AKS uses the Azure Files CSI driver, identified by the provisioner name `file.csi.azure.com`, to manage the lifecycle of Azure file shares. The driver can dynamically create a file share for a PVC or mount an existing file share through a statically defined PV.

> [!IMPORTANT]
> Starting with Kubernetes version 1.26, AKS doesn't support creating volumes with the in-tree `kubernetes.io/azure-file` driver. Use the Azure Files CSI driver, `file.csi.azure.com`, for new deployments.

## Supported protocols

Choose a protocol based on the operating system and application requirements of your workload.

| Protocol | Supported node pools | Common use cases | Key considerations |
|---|---|---|---|
| SMB 3.x | Linux and Windows | Shared application content, user directories, configuration and general-purpose file storage | Requires outbound connectivity on TCP port 445 unless you use private connectivity. Supports storage account key authentication and supported Microsoft Entra authentication scenarios. |
| NFS 4.1 | Linux | Linux workloads that require NFS semantics | Requires an Azure Files SSD file share and network-based access to the storage account. NFS uses network security rather than user-based authentication. |

For detailed protocol and account requirements, see [Azure Files protocols](/azure/storage/files/storage-files-planning#available-protocols).

## Provisioning options

You can provision Azure Files storage dynamically or statically.

### Dynamic provisioning

With dynamic provisioning, you create a PVC that references an Azure Files StorageClass. The Azure Files CSI driver creates the Azure file share and PV automatically and then binds the PV to the claim.

Use dynamic provisioning when:

- Each workload or claim should receive a new file share.
- You want Kubernetes to manage the storage lifecycle.
- You want to automate deployments by using Kubernetes manifests or Helm charts.

AKS includes built-in Azure Files StorageClasses for common SMB scenarios. You can also create a custom StorageClass to control settings such as the storage SKU, protocol, reclaim policy, mount options and volume expansion.

> [!NOTE]
> StorageClass names and defaults can vary based on the cluster configuration. Run `kubectl get storageclass` to view the StorageClasses available in your cluster.

### Static provisioning

With static provisioning, you create the storage account and file share first. You then create a Kubernetes PV that references the existing share and bind it to a PVC.

Use static provisioning when:

- You need to mount an existing Azure file share.
- The data lifecycle must remain independent of the Kubernetes resource lifecycle.
- You need direct control over the storage account, file share, networking, or identity configuration.
- Multiple clusters or non-Kubernetes clients need to use the same file share.

When you use static provisioning, ensure the PV reclaim policy reflects how you want Kubernetes to handle the volume after its claim is deleted.

## Compare dynamic and static provisioning

| Consideration | Dynamic provisioning | Static provisioning |
|---|---|---|
| File-share creation | The CSI driver creates the share automatically. | You create the storage account and file share before creating the PV. |
| Kubernetes objects | StorageClass and PVC; the PV is generated automatically. | PV and PVC; a StorageClass isn't required. |
| Best suited for | New, repeatable, application-specific storage. | Existing shares and storage managed outside Kubernetes. |
| Storage lifecycle | Controlled by the StorageClass reclaim policy. | Controlled by the PV reclaim policy and external storage-management process. |
| Custom networking and identity | Configured through the StorageClass and Azure resources. | Configured directly on the existing storage account and referenced by the PV. |

## Before you begin

Before configuring Azure Files for AKS, ensure that you have:

- An Azure subscription.
- An existing AKS cluster.
- Azure CLI version 2.42 or later. Run `az --version` to check the installed version. To install or upgrade Azure CLI, see [Install Azure CLI](/cli/azure/install-azure-cli).
- `kubectl` configured to connect to your AKS cluster.
- Permissions to create or use the required Azure storage resources and Kubernetes objects.
- Network connectivity between the AKS nodes and the storage account.

For NFS, use a Linux node pool and an Azure Files SSD file share. For SMB, use Linux or Windows nodes according to your workload requirements.

## Verify the Azure Files CSI driver

AKS clusters running Kubernetes version 1.21 or later use CSI drivers by default. Check whether the Azure Files CSI driver is enabled:

```azurecli-interactive
az aks show \
  --resource-group <resource-group> \
  --name <aks-cluster-name> \
  --query "storageProfile.fileCsiDriver.enabled" \
  --output tsv
```

If the command returns `false`, enable the driver:

```azurecli-interactive
az aks update \
  --resource-group <resource-group> \
  --name <aks-cluster-name> \
  --enable-file-driver
```

Verify the CSI driver pods:

```bash
kubectl get pods --namespace kube-system --selector app=csi-azurefile-node
```

View the available StorageClasses:

```bash
kubectl get storageclass
```

## Choose an Azure Files configuration

Consider the following factors before creating a StorageClass, PV, or PVC.

### File-share performance and billing model

Select the Azure Files media tier, billing model and redundancy option based on the workload's capacity, IOPS, throughput, latency and availability requirements. For new performance-sensitive workloads, evaluate Azure Files SSD file shares. For lower-I/O workloads, Azure Files HDD file shares might provide a more appropriate cost profile.

For current account types, billing models, limits and regional availability, see:

- [Plan for an Azure Files deployment](/azure/storage/files/storage-files-planning)
- [Understand Azure Files billing](/azure/storage/files/understanding-billing)
- [Azure Files scalability and performance targets](/azure/storage/files/storage-files-scale-targets)

> [!IMPORTANT]
> Some Azure Files capabilities require a minimum Azure Files CSI driver version. Verify feature requirements before selecting a storage account SKU or billing model.

### Access mode

Azure Files supports `ReadWriteMany`, allowing multiple pods to mount the same share. It also supports common single-pod access patterns. Select the access mode that matches your application's concurrency and scheduling requirements.

### Reclaim policy

The reclaim policy determines what happens to dynamically provisioned storage after its PVC is deleted:

- `Delete` removes the Kubernetes PV and the dynamically provisioned Azure file share.
- `Retain` preserves the PV and underlying file share for manual recovery or cleanup.

Use `Retain` when accidental deletion could cause unacceptable data loss. Use `Delete` for disposable development, test, or continuous-integration workloads.

### Volume expansion

Set `allowVolumeExpansion: true` on a custom StorageClass when workloads must increase PVC capacity without replacing the claim. Confirm that the selected Azure Files configuration and CSI driver version support the required expansion behavior.

### Networking

Keep the storage account in the same Azure region as the AKS cluster to reduce latency. Depending on your security requirements, you can use:

- A public storage endpoint with firewall restrictions.
- A service endpoint, where supported by the selected configuration.
- A private endpoint and private DNS for private connectivity.

Ensure that DNS resolution and routing are configured correctly from every AKS node subnet that needs to mount the share.

For SMB, allow TCP port 445 between the nodes and the storage endpoint. For NFS, follow the Azure Files NFS networking requirements.

### Authentication and authorization

The authentication model depends on the protocol, provisioning method and selected Azure Files feature:

- SMB configurations can use a storage account key or a supported Microsoft Entra authentication flow.
- NFS access is controlled through network security and export configuration rather than user-based authentication.
- Dynamic provisioning requires the AKS identity to have the permissions required to create and manage file shares at the selected Azure scope.

Apply least-privilege role assignments and avoid placing credentials directly in workload manifests. For available Azure Files authentication options, see [Azure Files identity-based authentication options for SMB access](/azure/storage/files/storage-files-active-directory-overview).

## Validate the storage configuration

After you create the StorageClass or PV and deploy the PVC, verify that the claim is bound:

```bash
kubectl get persistentvolumeclaim
```

Inspect the claim if it remains in the `Pending` state:

```bash
kubectl describe persistentvolumeclaim <pvc-name>
```

Verify the corresponding PV:

```bash
kubectl get persistentvolume
```

After the pod starts, verify that the volume is mounted:

```bash
kubectl describe pod <pod-name>
```

Review Azure Files CSI driver logs when provisioning or mounting fails:

```bash
kubectl logs \
  --namespace kube-system \
  --selector app=csi-azurefile-node \
  --container azurefile \
  --tail 100
```

## Troubleshoot common issues

### The PVC remains pending

Check the PVC events, StorageClass name, selected SKU, protocol, identity permissions and regional availability. For dynamic provisioning, confirm that the cluster identity can create the required storage resources.

### The pod can't mount an SMB share

Verify TCP port 445 connectivity, storage account firewall rules, private DNS resolution, authentication configuration and the share name. On Linux nodes, also review the SMB mount options and file-permission requirements of the application.

### The pod can't mount an NFS share

Confirm that the workload runs on a Linux node, the share supports NFS 4.1, the storage account has the required network configuration and the AKS node subnet can reach the storage endpoint.

### Multiple pods can't access the volume

Confirm that the PVC uses an access mode supported by the share, such as `ReadWriteMany` and that the application itself supports concurrent access to the same files.

## Next steps

- [Dynamically create and use an Azure Files volume with Azure Kubernetes Service](/azure/aks/azure-csi-files-storage-provision)
- [Manually create and use an Azure Files volume with Azure Kubernetes Service](/azure/aks/azure-files-volume)
- [Use Azure Files CSI driver in Azure Kubernetes Service](/azure/aks/azure-files-csi)
- [Azure Files guidance for Azure Kubernetes Service workloads](/azure/storage/files/azure-kubernetes-service-workloads)
- [Use Container Storage Interface drivers on Azure Kubernetes Service](csi-storage-drivers.md)
