---
title: Use Container Storage Interface (CSI) Drivers on Azure Kubernetes Service (AKS)
description: Learn about and deploy the Container Storage Interface (CSI) drivers for Azure Disks, Azure Files, and Azure Blob storage on your Azure Kubernetes Service (AKS) cluster to enable flexible and efficient storage solutions for your containerized applications.
ms.topic: how-to
ms.date: 03/14/2024
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-storage
zone_pivot_groups: csi-storage-drivers
# Customer intent: "As a Kubernetes administrator, I want to deploy and manage Container Storage Interface (CSI) drivers on my Azure Kubernetes Service (AKS) cluster, so that I can enable flexible and efficient storage solutions for my containerized applications."
---

# Use Container Storage Interface (CSI) drivers on Azure Kubernetes Service (AKS)

The Container Storage Interface (CSI) is a standard for exposing arbitrary block and file storage systems to containerized workloads on Kubernetes. When using CSI, Azure Kubernetes Service (AKS) can write, deploy, and iterate plug-ins to expose new or improve existing storage systems in Kubernetes without having to touch the core Kubernetes code and wait for its release cycles.

The CSI storage driver support on AKS allows you to natively use **Azure Disks**, **Azure Files**, or **Azure Blob storage** as persistent storage for your applications running on AKS.

> [!TIP]
> If you want a fully managed solution for block-level access to data, consider using [Azure Container Storage][azure-container-storage] instead of CSI drivers. Azure Container Storage integrates with Kubernetes, allowing dynamic and automatic provisioning of persistent volumes. Azure Container Storage supports Azure Disks, Ephemeral Disks, and Azure Elastic SAN (preview) as backing storage, offering flexibility and scalability for stateful applications running on Kubernetes clusters.

:::zone pivot="azure-disks,azure-files"

> [!IMPORTANT]
> Starting with Kubernetes version 1.26, in-tree persistent volume types `kubernetes.io/azure-disk` and `kubernetes.io/azure-file` are deprecated and will no longer be supported. _In-tree drivers_ refer to the storage drivers that are part of the core Kubernetes code opposed to the CSI drivers, which are plug-ins.
>
> Removing these drivers following their deprecation isn't planned, however you should migrate to the corresponding CSI drivers `disk.csi.azure.com` and `file.csi.azure.com`. To review the migration options for your storage classes and upgrade your cluster to use Azure Disks and Azure Files CSI drivers, see [Migrate from in-tree to CSI drivers][migrate-from-in-tree-csi-drivers].
>
> If you created in-tree driver storage classes, those storage classes continue to work since CSI migration is turned on after upgrading your cluster to 1.21.x. If you want to use CSI features, you need to perform the migration.

:::zone-end

:::zone pivot="azure-disks"

## About Azure Disks CSI driver

The Azure Disks CSI driver is a [CSI specification](https://github.com/container-storage-interface/spec/blob/master/spec.md)-compliant driver used by AKS to manage the lifecycle of Azure Disk resources. With the Azure Disks CSI driver, you can create a Kubernetes _DataDisk_ resource. Disks can use Azure Premium Storage, backed by high-performance SSDs, or Azure Standard Storage, backed by regular HDDs or Standard SSDs. For most production and development workloads, use Premium Storage. Azure Disks are mounted as _ReadWriteOnce_ and are only available to one node in AKS. For storage volumes that can be accessed by multiple nodes simultaneously, use Azure Files.

## Features of Azure Disks CSI driver

In addition to in-tree driver features, Azure Disk CSI driver supports the following features:

- Performance improvements during concurrent disk attach and detach operations.
  - In-tree drivers attach or detach disks in serial, while CSI drivers attach or detach disks in batch. There's significant improvement when there are multiple disks attaching to one node.
- Premium SSD v1 and v2.
  - `PremiumV2_LRS` only supports `None` caching mode.
- Zone-redundant storage (ZRS) disk support.
  - `Premium_ZRS`, `StandardSSD_ZRS` disk types are supported. ZRS disk could be scheduled on the zone or nonzone node, without the restriction that disk volume should be colocated in the same zone as a given node. For more information, including which regions are supported, see [Zone-redundant storage for managed disks](/azure/virtual-machines/disks-redundancy).
- Create [snapshots of persistent volumes](./create-volume-azure-disk.md#volume-snapshot-class-parameters-for-azure-disks).
- Create [volume clones](./create-volume-azure-disk.md#clone-volumes-with-azure-disks).
- [Resize persistent volumes without downtime](./create-volume-azure-disk.md#resize-a-persistent-volume-without-downtime-with-azure-disks).

> [!NOTE]
> Depending on the virtual machine (VM) SKU you're using, the Azure Disk CSI driver might have a per-node volume limit. For some powerful VMs (for example, 16 cores), the limit is _64 volumes per node_. To identify the limit per VM SKU, review the **Max data disks** column for each VM SKU offered. For a list of VM SKUs offered and their corresponding detailed capacity limits, see [General purpose virtual machine sizes][general-purpose-machine-sizes].

:::zone-end

:::zone pivot="azure-files"

## About Azure Files CSI driver

The Azure Files CSI driver is a [CSI specification][csi-specification]-compliant driver used by AKS to manage the lifecycle of Azure file shares. With the Azure Files CSI driver, you can mount an SMB 3.0/3.1 share backed by an Azure storage account to pods. With Azure Files, you can share data across multiple nodes and pods. Azure Files can use Azure Standard storage backed by regular HDDs or Azure Premium storage backed by high-performance SSDs.

:::zone-end

:::zone pivot="azure-blob"

## About Azure Blob storage CSI driver

The Azure Blob storage CSI driver is a [CSI specification][csi-specification]-compliant driver used by AKS to manage the lifecycle of Azure Blob storage. With the Azure Blob storage CSI driver, you can mount blob storage (or object storage) as a file system into a container or pod. Using blob storage enables your cluster to support applications that work with large unstructured datasets like log file data, images or documents, HPC, and others. Additionally, if you ingest data into [Azure Data Lake storage](/azure/storage/blobs/data-lake-storage-introduction), you can directly mount and use it in AKS without configuring another interim filesystem.

When you mount Azure Blob storage as a filesystem into a container or pod, it enables you to use blob storage with multiple applications that work massive amounts of unstructured data, such as:

- Log file data
- Images, documents, and streaming video or audio
- Disaster recovery data

Applications can access data on the object storage using BlobFuse or Network File System (NFS) 3.0 protocol. Before the introduction of the Azure Blob storage CSI driver, the only option was to manually install an unsupported driver to access blob storage from your application running on AKS.

## Features of Azure Blob storage CSI driver

- Two built-in storage classes: _azureblob-fuse-premium__ and _azureblob-nfs-premium_.
- BlobFuse and Network File System (NFS) version 3.0 protocol.

:::zone-end

## Prerequisites

- You need the Azure CLI version 2.42 or later installed and configured. Find the version using the `az --version` command. To install or upgrade, see [Install Azure CLI][install-azure-cli].
- If the open-source CSI storage driver is installed on your cluster, uninstall it before enabling the Azure storage CSI driver.

:::zone pivot="azure-blob"

- Follow the steps [here][csi-blob-storage-open-source-driver-uninstall-steps] if you previously installed the [CSI Blob storage open-source driver][csi-blob-storage-open-source-driver] to access Azure Blob storage from your cluster.

    > [!NOTE]
    > If blobfuse-proxy isn't enabled during the installation of the open-source driver, the uninstallation of the open-source driver disrupts existing blobfuse mounts. However, NFS mounts remain unaffected.

:::zone-end

- To enforce the Azure Policy for AKS [policy definition][azure-policy-aks-definition] **Kubernetes clusters should use Container Storage Interface (CSI) driver `StorageClass`**, you need to enable the Azure Policy add-on on your cluster. To enable on an existing cluster, see [Learn Azure Policy for Kubernetes][learn-azure-policy-kubernetes].

## Disk encryption supported scenarios

CSI storage drivers support the following scenarios:

- [Encrypted managed disks with customer-managed keys][encrypt-managed-disks-customer-managed-keys] using Azure key vaults stored in a different Microsoft Entra tenant.
- Encrypt your Azure Storage disks hosting AKS operating system (OS) and application data with [customer-managed keys][azure-disk-customer-managed-keys].

:::zone pivot="azure-disks"

## Enable Azure Disks CSI storage driver on an existing AKS cluster

- Enable the Azure Disks CSI driver on an existing cluster using the [`az aks update`][az-aks-update] command with the `--enable-disk-driver` parameter. The following example enables the Azure Disks CSI driver on an existing cluster named _myAKSCluster_ in the resource group _myResourceGroup_:

    > [!NOTE]
    > You can enable the [snapshot controller][snapshot-controller] at the same time as the Azure Disks CSI driver, which allows you to create snapshots of your persistent volumes. To enable the snapshot controller, include the `--enable-snapshot-controller` parameter in the command.

    ```azurecli-interactive
    az aks update --name myAKSCluster --resource-group myResourceGroup --enable-disk-driver
    ```

    It takes a few minutes to enable the Azure Disks CSI driver. After the command is completed, you can verify that the driver is enabled by checking that `blobCsiDriver` is set to `true` in the output. For example:

    ```output
    "storageProfile": {
        "blobCsiDriver": {
          "enabled": true
        },
    ```

:::zone-end

:::zone pivot="azure-files"

## Enable Azure Files CSI storage driver on an existing AKS cluster

- Enable the Azure Files CSI driver on an existing cluster using the [`az aks update`][az-aks-update] command with the `--enable-file-driver` parameter. The following example enables the Azure Files CSI driver on an existing cluster named _myAKSCluster_ in the resource group _myResourceGroup_:

    > [!NOTE]
    > You can enable the [snapshot controller][snapshot-controller] at the same time as the Azure Files CSI driver, which allows you to create snapshots of your persistent volumes. To enable the snapshot controller, include the `--enable-snapshot-controller` parameter in the command.

    ```azurecli-interactive
    az aks update --name myAKSCluster --resource-group myResourceGroup --enable-file-driver
    ```

    It takes a few minutes to enable the Azure Files CSI driver. After the command is completed, you can verify that the driver is enabled by checking that `fileCsiDriver` is set to `true` in the output. For example:

    ```output
    "storageProfile": {
        "fileCsiDriver": {
          "enabled": true
        },
    ```

:::zone-end

:::zone pivot="azure-blob"

## Enable Azure Blob storage CSI storage driver on an existing AKS cluster

- Enable the Azure Blob storage CSI driver on an existing cluster using the [`az aks update`][az-aks-update] command with the `--enable-blob-driver` parameter. The following example enables the Azure Blob storage CSI driver on an existing cluster named _myAKSCluster_ in the resource group _myResourceGroup_:

    > [!NOTE]
    > You can enable the [snapshot controller][snapshot-controller] at the same time as the Azure Blob storage CSI driver, which allows you to create snapshots of your persistent volumes. To enable the snapshot controller, include the `--enable-snapshot-controller` parameter in the command.

    ```azurecli-interactive
    az aks update --name myAKSCluster --resource-group myResourceGroup --enable-blob-driver
    ```

    It takes a few minutes to enable the Azure Blob storage CSI driver. After the command is completed, you can verify that the driver is enabled by checking that `blobCsiDriver` is set to `true` in the output. For example:

    ```output
    "storageProfile": {
        "blobCsiDriver": {
          "enabled": true
        },
    ```

:::zone-end

:::zone pivot="azure-disks"

## Disable Azure Disks CSI storage driver on an existing AKS cluster

- Disable the Azure Disks CSI driver on an existing cluster using the [`az aks update`][az-aks-update] command with the `--disable-disk-driver` parameter. The following example disables the Azure Disks CSI driver on an existing cluster named _myAKSCluster_ in the resource group _myResourceGroup_:

    > [!NOTE]
    > You can disable the [snapshot controller][snapshot-controller] by including the `--disable-snapshot-controller` parameter in the command.

    ```azurecli-interactive
    az aks update --name myAKSCluster --resource-group myResourceGroup --disable-disk-driver
    ```

:::zone-end

:::zone pivot="azure-files"

### Disable Azure Files CSI storage driver on an existing AKS cluster

- Disable the Azure Files CSI driver on an existing cluster using the [`az aks update`][az-aks-update] command with the `--disable-file-driver` parameter. The following example disables the Azure Files CSI driver on an existing cluster named _myAKSCluster_ in the resource group _myResourceGroup_:

    > [!NOTE]
    > You can disable the [snapshot controller][snapshot-controller] by including the `--disable-snapshot-controller` parameter in the command.

    ```azurecli-interactive
    az aks update --name myAKSCluster --resource-group myResourceGroup --disable-file-driver
    ```

:::zone-end

:::zone pivot="azure-blob"

## Disable Azure Blob storage CSI storage driver on an existing AKS cluster

- Disable the Azure Blob storage CSI driver on an existing cluster using the [`az aks update`][az-aks-update] command with the `--disable-blob-driver` parameter. The following example disables the Azure Blob storage CSI driver on an existing cluster named _myAKSCluster_ in the resource group _myResourceGroup_:

    > [!NOTE]
    > You can disable the [snapshot controller][snapshot-controller] by including the `--disable-snapshot-controller` parameter in the command.

    ```azurecli-interactive
    az aks update --name myAKSCluster --resource-group myResourceGroup --disable-blob-driver
    ```

:::zone-end

> [!NOTE]
> We recommend deleting the corresponding PersistentVolumeClaim object instead of the PersistentVolume object when deleting a CSI volume. The external provisioner in the CSI driver reacts to the deletion of the PersistentVolumeClaim. Based on the PVC reclamation policy, the provisioner issues the DeleteVolume call against the CSI volume driver commands to delete the volume. The PersistentVolume object is then deleted.

## Next step

:::zone pivot="azure-disks"

> [!div class="nextstepaction"]
> [Create and use a persistent volume (PV) with Azure Disks in Azure Kubernetes Service (AKS)](./create-volume-azure-disk.md)

:::zone-end

:::zone pivot="azure-files"

> [!div class="nextstepaction"]
> [Create and use a persistent volume (PV) with Azure Files in Azure Kubernetes Service (AKS)](./create-volume-azure-files.md)

:::zone-end

:::zone pivot="azure-blob"

> [!div class="nextstepaction"]
> [Create and use a persistent volume (PV) with Azure Blob storage in Azure Kubernetes Service (AKS)](./create-volume-azure-blob-storage.md)

:::zone-end

<!--- LINKS --->
[snapshot-controller]: https://kubernetes-csi.github.io/docs/snapshot-controller.html
[install-azure-cli]: /cli/azure/install-azure-cli
[migrate-from-in-tree-csi-drivers]: csi-migrate-in-tree-volumes.md
[learn-azure-policy-kubernetes]: /azure/governance/policy/concepts/policy-for-kubernetes
[azure-policy-aks-definition]: /azure/governance/policy/samples/built-in-policies#kubernetes
[encrypt-managed-disks-customer-managed-keys]: /azure/virtual-machines/disks-cross-tenant-customer-managed-keys
[azure-disk-customer-managed-keys]: azure-disk-customer-managed-keys.md
[azure-container-storage]: /azure/storage/container-storage/container-storage-introduction
[csi-specification]: https://github.com/container-storage-interface/spec/blob/master/spec.md
[csi-blob-storage-open-source-driver]: https://github.com/kubernetes-sigs/blob-csi-driver
[csi-blob-storage-open-source-driver-uninstall-steps]: https://github.com/kubernetes-sigs/blob-csi-driver/blob/master/docs/install-csi-driver-master.md#clean-up-blob-csi-driver
[general-purpose-machine-sizes]: /azure/virtual-machines/sizes-general
