---
title: Use Container Storage Interface (CSI) driver for Azure Disk on Azure Kubernetes Service (AKS)
description: Learn how to use the Container Storage Interface (CSI) driver for Azure Disk in an Azure Kubernetes Service (AKS) cluster.
ms.topic: how-to
ms.custom: biannual
ms.subservice: aks-storage
ms.date: 12/18/2025
author: schaffererin
ms.author: schaffererin
zone_pivot_groups: azure-csi-driver
# Customer intent: "As a Kubernetes administrator, I want to implement the Azure Disk CSI driver in my AKS cluster so that I can efficiently manage storage provisioning and enhance performance for my containerized applications."
---

::: zone pivot="csi-blob"

# Use Azure Blob storage CSI driver

The Azure Blob storage Container Storage Interface (CSI) driver is a
[CSI specification][csi-specification]-compliant driver used by Azure Kubernetes Service (AKS) to
manage the lifecycle of Azure Blob storage. The CSI is a standard for exposing arbitrary block and
file storage systems to containerized workloads on Kubernetes.

By adopting and using CSI, AKS now can write, deploy, and iterate plug-ins to expose new or improve
existing storage systems in Kubernetes. Using CSI drivers in AKS avoids having to touch the core
Kubernetes code and wait for its release cycles.

When you mount Azure Blob storage as a file system into a container or pod, it enables you to use
blob storage with many applications that work massive amounts of unstructured data. For example:

* Log file data
* Images, documents, and streaming video or audio
* Disaster recovery data

Applications access data stored in Azure Blob storage using either BlobFuse or the Network File
System (NFS) 3.0 protocol. Before the introduction of the Azure Blob storage CSI driver, the only
option was to manually install an unsupported driver to access Blob storage from your application
running on AKS. When the Azure Blob storage CSI driver is enabled on AKS, there are two built-in
storage classes:

* azureblob-fuse-premium
* azureblob-nfs-premium

To create an AKS cluster with CSI drivers support, see [CSI drivers on AKS][csi-drivers-aks]. To
learn more about the differences in access between each of the Azure storage types using the NFS
protocol, see
[Compare access to Azure Files, Blob Storage, and Azure NetApp Files with NFS][compare-access-with-nfs].

## Azure Blob storage CSI driver features

Azure Blob storage CSI driver supports the following features:

- BlobFuse
- NFS 3.0 protocol

## Prerequisites

- You must have the Azure CLI version 2.42 or later installed and configured. To find the version,
  run `az --version`. If you need to install or upgrade, see
  [Install Azure CLI][install-azure-cli]. If you installed the Azure CLI `aks-preview` extension,
  make sure that you update the extension to the latest version by calling
  `az extension update --name aks-preview`.

- Perform the steps in this [link][csi-blob-storage-open-source-driver-uninstall-steps] if you
  previously installed the
  [CSI Blob Storage open-source driver][csi-blob-storage-open-source-driver] to access Azure Blob
  storage from your cluster.

- Your AKS cluster *Control plane* identity (your AKS cluster name) is added to the
  [Contributor](/azure/role-based-access-control/built-in-roles#contributor) role on the VNet and
  network security group.

> [!NOTE]
> If the **blobfuse-proxy** isn't enabled during the installation of the open source driver, the uninstallation of the open source driver disrupts existing blobfuse mounts. However, NFS mounts remain unaffected.

## Enable CSI driver on a new or existing AKS cluster

Using the Azure CLI, you can enable the Blob storage CSI driver on a new or existing AKS cluster
before you configure a persistent volume for use by pods in the cluster.

1. To enable the driver on a new cluster, include the `--enable-blob-driver` parameter with the
   `az aks create` command as shown in the following example:

   ```azurecli
   az aks create \
       --enable-blob-driver \
       --name myAKSCluster \
       --resource-group myResourceGroup \
       --generate-ssh-keys
   ```

1. To enable the driver on an existing cluster, include the `--enable-blob-driver` parameter with
   the `az aks update` command as shown in the following example:

   ```azurecli
   az aks update --enable-blob-driver --name myAKSCluster --resource-group myResourceGroup
   ```

You're prompted to confirm there isn't an open-source Blob CSI driver installed. After you confirm,
it might take several minutes to complete this action. Once it's complete, you should see in the
output the status of enabling the driver on your cluster. The following example resembles the
section indicating the results of the previous command:

```output
"storageProfile": {
  "blobCsiDriver": {
    "enabled": true
  },
  ...
}
```

## Disable CSI driver on an existing AKS cluster

Using the Azure CLI, you can disable the Blob storage CSI driver on an existing AKS cluster after
you remove the persistent volume from the cluster.

1. To disable the driver on an existing cluster, include the `--disable-blob-driver` parameter with
   the `az aks update` command as shown in the following example:

   ```azurecli
   az aks update --disable-blob-driver --name myAKSCluster --resource-group myResourceGroup
   ```

## Use a PV with Azure Blob storage

A [persistent volume][persistent-volume] (PV) represents a piece of storage that's provisioned for
use with Kubernetes pods. A PV is used by one or many pods and can be dynamically or statically
provisioned. If multiple pods need concurrent access to the same storage volume, you can use Azure
Blob storage to connect by using NFS or BlobFuse. This article shows you how to dynamically create
an Azure Blob storage container for use by multiple pods in an AKS cluster.

For more information on Kubernetes volumes, see
[Storage options for applications in AKS][concepts-storage].

## Create Azure Blob storage PVs by using the built-in storage classes

A storage class is used to define how an Azure Blob storage container is created. A storage account
is automatically created in the node resource group for use with the storage class to hold the Azure
Blob storage container. Choose one of the following Azure storage redundancy SKUs for skuName:

* **Standard_LRS**: Standard locally redundant storage
* **Premium_LRS**: Premium locally redundant storage
* **Standard_ZRS**: Standard zone redundant storage
* **Premium_ZRS**: Premium zone redundant storage
* **Standard_GRS**: Standard geo-redundant storage
* **Standard_RAGRS**: Standard read-access geo-redundant storage

When you use storage CSI drivers on AKS, there are two additional built-in StorageClasses that use
the Azure Blob CSI storage driver.

The reclaim policy on both storage classes ensures that the underlying Azure Blob storage is deleted
when the respective PV is deleted. The storage classes also configure the container to be expandable
by default, as the `set allowVolumeExpansion` parameter is set to **true**.

> [!NOTE]
> Shrinking persistent volumes isn't supported.

Use the [kubectl get sc][kubectl-get] command to see the storage classes. The following example
shows the `azureblob-fuse-premium` and `azureblob-nfs-premium` storage classes available within an
AKS cluster:

```output
NAME                     PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
azureblob-fuse-premium   blob.csi.azure.com   Delete          Immediate           true                   23h
azureblob-nfs-premium    blob.csi.azure.com   Delete          Immediate           true                   23h
```

To use these storage classes, create a PVC and respective pod that references and uses them. A PVC
is used to automatically allocate storage based on a storage class. You can create a PVC using one
of the built-in storage classes or a custom storage class. This PVC creates an Azure Blob storage
container with your specified SKU, size, and protocol. When you create a pod definition, the PVC is
specified to request the desired storage.

## Create a StatefulSet

To ensure your workload retains its storage volume across pod restarts or replacements, use a
StatefulSet. StatefulSets simplify the process of associating persistent storage with pods, so that
new pods created to replace failed ones can automatically access the same storage volumes. The
following examples demonstrate how to set up a StatefulSet for Blob storage using either BlobFuse or
the NFS protocol.

# [NFS](#tab/nfs)

1. Create a file named `azure-blob-nfs-ss.yaml` and copy in the following YAML.

   ```yml
   apiVersion: apps/v1
   kind: StatefulSet
   metadata:
     name: statefulset-blob-nfs
     labels:
       app: nginx
   spec:
     serviceName: statefulset-blob-nfs
     replicas: 1
     template:
       metadata:
         labels:
           app: nginx
       spec:
         nodeSelector:
           "kubernetes.io/os": linux
         containers:
           - name: statefulset-blob-nfs
             image: mcr.microsoft.com/azurelinux/base/nginx:1.25
             volumeMounts:
               - name: persistent-storage
                 mountPath: /mnt/blob
     updateStrategy:
       type: RollingUpdate
     selector:
       matchLabels:
         app: nginx
     volumeClaimTemplates:
       - metadata:
           name: persistent-storage
         spec:
           storageClassName: azureblob-nfs-premium
           accessModes: ["ReadWriteMany"]
           resources:
             requests:
               storage: 100Gi
   ```

1. Create the StatefulSet with the `kubectl create` command:

   ```bash
   kubectl create -f azure-blob-nfs-ss.yaml
   ```

# [BlobFuse](#tab/blobfuse)

1. Create a file named `azure-blobfuse-ss.yaml` and copy in the following YAML.

   ```yml
   apiVersion: apps/v1
   kind: StatefulSet
   metadata:
     name: statefulset-blob
     labels:
       app: nginx
   spec:
     serviceName: statefulset-blob
     replicas: 1
     template:
       metadata:
         labels:
           app: nginx
       spec:
         nodeSelector:
           "kubernetes.io/os": linux
         containers:
           - name: statefulset-blob
             image: mcr.microsoft.com/azurelinux/base/nginx:1.25
             volumeMounts:
               - name: persistent-storage
                 mountPath: /mnt/blob
     updateStrategy:
       type: RollingUpdate
     selector:
       matchLabels:
         app: nginx
     volumeClaimTemplates:
       - metadata:
           name: persistent-storage
         spec:
           storageClassName: azureblob-fuse-premium
           accessModes: ["ReadWriteMany"]
           resources:
             requests:
               storage: 100Gi
   ```

1. Create the StatefulSet with the `kubectl create` command:

   ```bash
   kubectl create -f azure-blobfuse-ss.yaml
   ```

## Next steps

- To learn how to set up a static or dynamic persistent volume, see
  [Create and use a volume with Azure Blob storage][azure-csi-blob-storage-provision].
- To learn how to use CSI driver for Azure Disks, see
  [Use Azure Disks with CSI driver][azure-disk-csi-driver].
- To learn how to use CSI driver for Azure Files, see
  [Use Azure Files with CSI driver][azure-files-csi-driver].
- For more about storage best practices, see
  [Best practices for storage and backups in Azure Kubernetes Service][operator-best-practices-storage].

::: zone-end

::: zone pivot="csi-disk"

# Azure Disk CSI driver in AKS

The Azure Disks Container Storage Interface (CSI) driver is a [CSI specification](https://github.com/container-storage-interface/spec/blob/master/spec.md)-compliant driver used by Azure Kubernetes Service (AKS) to manage the lifecycle of Azure Disk.

The CSI is a standard for exposing arbitrary block and file storage systems to containerized workloads on Kubernetes. By adopting and using CSI, AKS now can write, deploy, and iterate plug-ins to expose new or improve existing storage systems in Kubernetes. Using CSI drivers in AKS avoids having to touch the core Kubernetes code and wait for its release cycles. To create an AKS cluster with CSI driver support, see [Enable CSI driver on AKS](csi-storage-drivers.md).

A [persistent volume](concepts-storage.md#persistent-volumes) (PV) represents a piece of storage that's provisioned for use with Kubernetes pods. A PV is used by one or more pods and can be dynamically or statically provisioned. This article shows you how to dynamically create PVs with Azure disk for use by a single pod in an AKS cluster. For static provisioning, see [Create an Azure Disk](azure-csi-disk-storage-provision.md#statically-provision-a-volume).

For more information on Kubernetes volumes, see [Storage options for applications in AKS](concepts-storage.md).

This article describes how to use the Azure Disk CSI driver.

> [!NOTE]
> *In-tree drivers* refer to the current storage drivers that are part of the core Kubernetes code versus the new CSI drivers, which are plug-ins.

## Azure Disk CSI driver features

In addition to in-tree driver features, Azure Disk CSI driver supports the following features:

- Performance improvements during concurrent disk attach and detach

  - In-tree drivers attach or detach disks in serial, while CSI drivers attach or detach disks in batch. There's significant improvement when there are multiple disks attaching to one node.

- Premium SSD v1 and v2 are supported.

  - `PremiumV2_LRS` only supports `None` caching mode

- Zone-redundant storage (ZRS) disk support

  - `Premium_ZRS`, `StandardSSD_ZRS` disk types are supported. ZRS disk could be scheduled on the zone or non-zone node, without the restriction that disk volume should be co-located in the same zone as a given node. For more information, including which regions are supported, see [Zone-redundant storage for managed disks](/azure/virtual-machines/disks-redundancy).

- [Volume snapshot](#understand-volume-snapshots)
- [Volume clone](#clone-volumes)
- [Resize disk PV without downtime](#resize-a-persistent-volume-without-downtime)

> [!NOTE]
> Depending on the VM SKU that's being used, the Azure Disk CSI driver might have a per-node volume limit. For some powerful VMs (for example, 16 cores), the limit is 64 volumes per node. To identify the limit per VM SKU, review the **Max data disks** column for each VM SKU offered. For a list of VM SKUs offered and their corresponding detailed capacity limits, see [General purpose virtual machine sizes][general-purpose-machine-sizes].

## Prerequisites

- You must have an AKS cluster with the Azure Disk CSI driver enabled. The CSI driver is enabled by default on AKS clusters running Kubernetes version 1.21 or later.

- Azure CLI version 2.37.0 or later is installed and configured. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).

- The `kubectl` command-line tool is installed and configured to connect to your AKS cluster.

- A storage class configured to use the Azure Disk CSI driver (`disk.csi.azure.com`).

## Create a custom storage class

The default storage classes are suitable for most common scenarios. For some cases, you might want to have your own storage class customized with your own parameters. For example, you might want to change the `volumeBindingMode` class.

You can use a `volumeBindingMode: Immediate` class that guarantees it occurs immediately once the persistent volume claim (PVC) is created. When your node pools are topology constrained, for example when using availability zones, PVs would be bound or provisioned without knowledge of the pod's scheduling requirements.

To address this scenario, you can use `volumeBindingMode: WaitForFirstConsumer`, which delays the binding and provisioning of a PV until a pod that uses the PVC is created. This way, the PV conforms and is provisioned in the availability zone (or other topology) that's specified by the pod's scheduling constraints. The default storage classes use `volumeBindingMode: WaitForFirstConsumer` class.

Create a file named `sc-azuredisk-csi-waitforfirstconsumer.yaml`, and then paste the following manifest. The storage class is the same as our `managed-csi` storage class, but with a different `volumeBindingMode` class.

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: azuredisk-csi-waitforfirstconsumer
provisioner: disk.csi.azure.com
parameters:
  skuname: StandardSSD_LRS
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

Create the storage class by running the [kubectl apply][kubectl-apply] command and specify your
`sc-azuredisk-csi-waitforfirstconsumer.yaml` file:

```bash
kubectl apply -f sc-azuredisk-csi-waitforfirstconsumer.yaml
```

The output of the command resembles the following example:

```output
storageclass.storage.k8s.io/azuredisk-csi-waitforfirstconsumer created
```

## Create Azure Disk PVs using built-in storage classes

A storage class is used to define how a unit of storage is dynamically created with a persistent volume. For more information on Kubernetes storage classes, see [Kubernetes storage classes][kubernetes-storage-classes].

When you use the Azure Disk CSI driver on AKS, there are two more built-in `StorageClasses` that use the Azure Disk CSI storage driver. The other CSI storage classes are created with the cluster alongside the in-tree default storage classes.

- `managed-csi`: Creates managed disks using Azure Standard SSD with locally redundant storage (LRS). Starting with Kubernetes version 1.29, for AKS clusters deployed across multiple availability zones, this storage class uses Azure Standard SSD zone-redundant storage (ZRS) to provision managed disks.

- `managed-csi-premium`: Provisions managed disks using Azure Premium LRS. Beginning with Kubernetes version 1.29, for AKS clusters spanning multiple availability zones, this storage class automatically uses Azure Premium ZRS to create managed disks.

The reclaim policy in both storage classes ensures that the underlying Azure Disks are deleted when the respective PV is deleted. The storage classes also configure the PVs to be expandable. You just need to edit the PVC with the new size.

To use these storage classes, create a [PVC](concepts-storage.md#persistent-volume-claims) and respective pod that references and uses them. A PVC is used to automatically provision storage based on a storage class. A PVC can use one of the pre-created storage classes or a user-defined storage class to create an Azure-managed disk for the desired SKU and size. When you create a pod definition, the PVC is specified to request the desired storage.

Create an example pod and respective PVC by running the [kubectl apply][kubectl-apply] command:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/example/pvc-azuredisk-csi.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/example/nginx-pod-azuredisk.yaml
```

The output of the command resembles the following example:

```output
persistentvolumeclaim/pvc-azuredisk created
pod/nginx-azuredisk created
```

After the pod is in the running state, run the following command to create a new file called `test.txt`:

```bash
kubectl exec nginx-azuredisk -- touch /mnt/azuredisk/test.txt
```

To validate the disk is correctly mounted, run the following command and verify you see the `test.txt` file in the output:

```bash
kubectl exec nginx-azuredisk -- ls /mnt/azuredisk

lost+found
outfile
test.txt
```

## Understand volume snapshots

The Azure Disk CSI driver supports [volume snapshots](https://kubernetes-csi.github.io/docs/snapshot-restore-feature.html), enabling you to capture the state of persistent volumes at specific points in time for backup and restore operations. Volume snapshots let you create point-in-time copies of your persistent data without interrupting running applications. You can use these snapshots to create new volumes or restore existing ones to a previous state.

You can create two types of snapshots:

- **Full snapshots**: Capture the complete state of the disk.

- **Incremental snapshots**: Capture only the changes since the last snapshot, offering better storage efficiency and cost savings. [Incremental snapshots](/azure/virtual-machines/disks-incremental-snapshots) are the default behavior when the `incremental` parameter is set to `true` in your VolumeSnapshotClass.

The following table provides details for these parameters.

| Name | Meaning | Available Value | Mandatory | Default value |
|--|--|--|--|--|
|resourceGroup | Resource group for storing snapshot shots | EXISTING RESOURCE GROUP | No | If not specified, snapshots are stored in the same resource group as source Azure Disks |
|incremental | Take [full or incremental snapshot](/azure/virtual-machines/windows/incremental-snapshots) | `true`, `false` | No | `true` |
|tags | Azure Disks [tags](/azure/azure-resource-manager/management/tag-resources) | Tag format: 'key1=val1,key2=val2' | No | "" |
|userAgent | User agent used for [customer usage attribution](/azure/marketplace/azure-partner-customer-usage-attribution) | | No  | Generated Useragent formatted `driverName/driverVersion compiler/version (OS-ARCH)` |
|subscriptionID | Specify Azure subscription ID where Azure Disks are created | Azure subscription ID | No | If not empty, `resourceGroup` must be provided, `incremental` must set as `false` |

Volume snapshots support the following scenarios:

- **Backup and restore**: Create point-in-time backups of stateful application data and restore when
  needed.
- **Data cloning**: Clone existing volumes to create new persistent volumes with the same data.
- **Disaster recovery**: Quickly recover from data loss or corruption.

### Create a volume snapshot

> [!NOTE]
> Before proceeding, ensure that the application isn't writing data to the source disk.

For an example of this capability, create a [volume snapshot class](https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/deploy/example/snapshot/storageclass-azuredisk-snapshot.yaml) with the [kubectl apply][kubectl-apply] command:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/example/snapshot/storageclass-azuredisk-snapshot.yaml
```

The output of the command resembles the following example:

```output
volumesnapshotclass.snapshot.storage.k8s.io/csi-azuredisk-vsc created
```

Create a [volume snapshot](https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/deploy/example/snapshot/azuredisk-volume-snapshot.yaml) from the PVC that was created earlier in this article.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/example/snapshot/azuredisk-volume-snapshot.yaml
```

The output of the command resembles the following example:

```output
volumesnapshot.snapshot.storage.k8s.io/azuredisk-volume-snapshot created
```

To verify that the snapshot was created correctly, run the following command:

```bash
kubectl describe volumesnapshot azuredisk-volume-snapshot
```

The output of the command resembles the following example:

```output
Name:         azuredisk-volume-snapshot
Namespace:    default
Labels:       <none>
Annotations:  API Version:  snapshot.storage.k8s.io/v1
Kind:         VolumeSnapshot
Metadata:
  Creation Timestamp:  2020-08-27T05:27:58Z
  Finalizers:
    snapshot.storage.kubernetes.io/volumesnapshot-as-source-protection
    snapshot.storage.kubernetes.io/volumesnapshot-bound-protection
  Generation:        1
  Resource Version:  714582
  Self Link:         /apis/snapshot.storage.k8s.io/v1/namespaces/default/volumesnapshots/azuredisk-volume-snapshot
  UID:               dd953ab5-6c24-42d4-ad4a-f33180e0ef87
Spec:
  Source:
    Persistent Volume Claim Name:  pvc-azuredisk
  Volume Snapshot Class Name:      csi-azuredisk-vsc
Status:
  Bound Volume Snapshot Content Name:  snapcontent-dd953ab5-6c24-42d4-ad4a-f33180e0ef87
  Creation Time:                       2020-08-31T05:27:59Z
  Ready To Use:                        true
  Restore Size:                        10Gi
Events:                                <none>
```

### Create a new PVC based on a volume snapshot

You can create a new PVC based on a volume snapshot. Use the snapshot created in the previous step, and create a [new PVC](https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/deploy/example/snapshot/pvc-azuredisk-snapshot-restored.yaml) and a [new pod](https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/deploy/example/snapshot/nginx-pod-restored-snapshot.yaml) to consume it:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/example/snapshot/pvc-azuredisk-snapshot-restored.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/example/snapshot/nginx-pod-restored-snapshot.yaml
```

The output of the command resembles the following example:

```output
persistentvolumeclaim/pvc-azuredisk-snapshot-restored created
pod/nginx-restored created
```

To make sure it's the same PVC created before, check the contents by running the following command:

```bash
kubectl exec nginx-restored -- ls /mnt/azuredisk
```

The output of the command resembles the following example:

```output
lost+found
outfile
test.txt
```

We can still see our previously created `test.txt` file as expected.

## Clone volumes

A cloned volume is defined as a duplicate of an existing Kubernetes volume. For more information on cloning volumes in Kubernetes, see [volume cloning](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#volume-cloning).

Create a [cloned volume](https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/deploy/example/cloning/nginx-pod-restored-cloning.yaml)
of the [previously created](#create-azure-disk-pvs-using-built-in-storage-classes) `azuredisk-pvc` and a [new pod](https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/deploy/example/cloning/nginx-pod-restored-cloning.yaml) to consume it.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/example/cloning/pvc-azuredisk-cloning.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/example/cloning/nginx-pod-restored-cloning.yaml
```

The output of the command resembles the following example:

```output
persistentvolumeclaim/pvc-azuredisk-cloning created
pod/nginx-restored-cloning created
```

You can verify the content of the cloned volume by running the following command and confirming the file `test.txt` is created:

```bash
kubectl exec nginx-restored-cloning -- ls /mnt/azuredisk
```

The output of the command resembles the following example:

```output
lost+found
outfile
test.txt
```

## Resize a persistent volume without downtime

You can request a larger volume for a PVC. Edit the PVC object, and specify a larger size. This change triggers the expansion of the underlying volume that backs the PV.

> [!NOTE]
> A new PV is never created to satisfy the claim. Instead, an existing volume is resized.

In AKS, the built-in `managed-csi` storage class already supports expansion, so use the [previously created](#create-azure-disk-pvs-using-built-in-storage-classes) one. The PVC requested a 10-Gi persistent volume. You can confirm by running the following command:

```bash
kubectl exec -it nginx-azuredisk -- df -h /mnt/azuredisk
```

The output of the command resembles the following example:

```output
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdc        9.8G   42M  9.8G   1% /mnt/azuredisk
```

Expand the PVC by increasing the `spec.resources.requests.storage` field running the following command:

```bash
kubectl patch pvc pvc-azuredisk --type merge --patch '{"spec": {"resources": {"requests": {"storage": "15Gi"}}}}'
```

> [!NOTE]
> Shrinking persistent volumes is currently not supported. Trying to patch an existing PVC with a smaller size than the current one leads to the following error message:
>
> `The persistentVolumeClaim "pvc-azuredisk" is invalid: spec.resources.requests.storage: Forbidden: field can not be less than previous value.`

The output of the command resembles the following example:

```output
persistentvolumeclaim/pvc-azuredisk patched
```

Run the following command to confirm the volume size increased:

```bash
kubectl get pv
```

The output of the command resembles the following example:

```output
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                     STORAGECLASS   REASON   AGE
pvc-391ea1a6-0191-4022-b915-c8dc4216174a   15Gi       RWO            Delete           Bound    default/pvc-azuredisk     managed-csi             2d2h
(...)
```

And after a few minutes, run the following commands to confirm the size of the PVC:

```bash
kubectl get pvc pvc-azuredisk
```

The output of the command resembles the following example:

```output
NAME            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc-azuredisk   Bound    pvc-391ea1a6-0191-4022-b915-c8dc4216174a   15Gi       RWO            managed-csi    2d2h
```

Run the following command to confirm the size of the disk inside the pod:

```bash
kubectl exec -it nginx-azuredisk -- df -h /mnt/azuredisk
```

The output of the command resembles the following example:

```output
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdc         15G   46M   15G   1% /mnt/azuredisk
```

If your pod has *multiple containers*, you can specify which container by running the following command:

```bash
kubectl exec -it nginx-azuredisk -c <ContainerName> -- df -h /mnt/azuredisk
```

## Windows containers

The Azure Disk CSI driver supports Windows nodes and containers. If you want to use Windows
containers, follow the [Windows containers quickstart][aks-quickstart-cli] to add a Windows node
pool.

After you have a Windows node pool, you can now use the built-in storage classes like `managed-csi`.
You can deploy an example
[Windows-based stateful set](https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/deploy/example/windows/statefulset.yaml)
that saves timestamps into the file `data.txt` by running the following
[kubectl apply][kubectl-apply] command:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/example/windows/statefulset.yaml
```

The output of the command resembles the following example:

```output
statefulset.apps/busybox-azuredisk created
```

To validate the content of the volume, run the following command:

```bash
 kubectl exec -it statefulset-azuredisk-win-0 -- powershell -c "type c:/mnt/azuredisk/data.txt"
```

The output of the command resembles the following example:

```output
2020-08-27 08:13:41Z
2020-08-27 08:13:42Z
2020-08-27 08:13:44Z
(...)
```

## On-demand bursting

On-demand disk bursting model allows disk bursts whenever its needs exceed its current capacity. This model generates extra charges anytime the disk bursts. On-demand bursting is only available for premium SSDs larger than 512 GiB. For more information on premium SSDs provisioned IOPS and throughput per disk, see [Premium SSD size][az-premium-ssd]. Alternatively, credit-based bursting is where the disk will burst only if it has burst credits accumulated in its credit bucket. Credit-based bursting doesn't generate extra charges when the disk bursts. Credit-based bursting is only available for premium SSDs 512 GiB and smaller, and standard SSDs 1,024 GiB and smaller. For more information on on-demand bursting, see [On-demand bursting][az-on-demand-bursting].

> [!IMPORTANT]
> The default `managed-csi-premium` storage class has on-demand bursting disabled and uses credit-based bursting. Any premium SSD dynamically created by a persistent volume claim based on the default `managed-csi-premium` storage class also has on-demand bursting disabled.

To create a premium SSD persistent volume with [on-demand bursting][az-on-demand-bursting] enabled, you can create a new storage class with the [enableBursting][csi-driver-parameters] parameter set to `true` as shown in the following YAML template. For more information on enabling on-demand bursting, see [On-demand bursting][az-on-demand-bursting]. For more information on building your own storage class with on-demand bursting enabled, see [Create a Burstable Managed CSI Premium Storage Class][create-burstable-storage-class].

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: burstable-managed-csi-premium
provisioner: disk.csi.azure.com
parameters:
  skuname: Premium_LRS
  enableBursting: "true"
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

## Next steps

- To learn how to use CSI driver for Azure Files, see [Use Azure Files with CSI driver][azure-files-csi].
- To learn how to use CSI driver for Azure Blob storage, see [Use Azure Blob storage with CSI driver][azure-blob-csi].
- For more information about storage best practices, see [Best practices for storage and backups in Azure Kubernetes Service][operator-best-practices-storage].
- For more information about disk-based storage solutions, see [Disk-based solutions in AKS][disk-based-solutions].

::: zone-end

::: zone pivot="csi-files"

# Azure Files CSI driver in AKS

The Azure Files Container Storage Interface (CSI) driver is a
[CSI specification][csi-specification]-compliant driver used by Azure Kubernetes Service (AKS) to
manage the lifecycle of Azure file shares. The CSI is a standard for exposing arbitrary block and
file storage systems to containerized workloads on Kubernetes.

By adopting and using CSI, AKS now can write, deploy, and iterate plug-ins to expose new or improve
existing storage systems in Kubernetes. Using CSI drivers in AKS avoids having to touch the core
Kubernetes code and wait for its release cycles.

To create an AKS cluster with CSI drivers support, see
[Enable CSI drivers on AKS][csi-drivers-overview].

> [!NOTE] *In-tree drivers* refer to the current storage drivers that are part of the core
> Kubernetes code versus the new CSI drivers, which are plug-ins.

## Prerequisites

**General requirements:**

- You must have an AKS cluster with the Azure Files CSI driver enabled. The Azure Files CSI driver
  is enabled by default on AKS clusters running Kubernetes version 1.21 or later.

- Azure CLI version 2.37.0 or later is installed and configured. To check your version, run
  `az --version`. If you need to install or upgrade, see
  [Install Azure CLI](/cli/azure/install-azure-cli).

- The `kubectl` command-line tool is installed and configured to connect to your AKS cluster.

- A storage class configured to use the Azure Files CSI driver (`file.csi.azure.com`).

**Network File Share (NFS) requirements:**

- Your AKS cluster *Control plane* identity (your AKS cluster name) is added to the
  [Contributor](/azure/role-based-access-control/built-in-roles#contributor) role on the VNet and
  **NetworkSecurityGroup**.

- Your AKS cluster's service principal or managed service identity (MSI) must be added to the
  **Contributor** role to the storage account.

**Managed Identity requirements:**

- Ensure the
  [user-assigned Kubelet identity](use-managed-identity.md#create-a-kubelet-managed-identity) is
  granted the `Storage File Data SMB MI Admin` role on the storage account. If you use your own
  storage account, you need to assign `Storage File Data SMB MI Admin` role to the user-assigned
  Kubelet identity on that storage account.

- If the CSI driver creates the storage account, grant the `Storage File Data SMB MI Admin` role to
  the resource group where the storage account resides.

- If you use the default built-in user-assigned Kubelet identity, it already has the required
  `Storage File Data SMB MI Admin` role on the managed node resource group.

## Persistent volumes with Azure Files

A [persistent volume (PV)][persistent-volume] represents a piece of storage that's provisioned for
use with Kubernetes pods. A PV is used by one or more pods and can be dynamically or statically
provisioned. If multiple pods need concurrent access to the same storage volume, you can use Azure
Files to connect by using the [Server Message Block (SMB)][smb-overview] or
[Network File System (NFS)][nfs-overview]. This article shows you how to dynamically create an Azure
Files share for use by multiple pods in an AKS cluster. For static provisioning, see
[Manually create and use a volume with an Azure Files share][statically-provision-a-volume].

> [!NOTE]
> The Azure File CSI driver only permits the mounting of SMB file shares using key-based
> (NTLM v2) authentication, and therefore doesn't support the maximum security profile of Azure File
> share settings. On the other hand, mounting NFS file shares doesn't require key-based
> authentication.

With Azure Files shares, there's no limit as to how many can be mounted on a node. For more
information on Kubernetes volumes, see [Storage options for applications in AKS][concepts-storage].

### Create Azure Files PVs using built-in storage classes

A storage class is used to define how an Azure file share is created. A storage account is
automatically created in the [node resource group][node-resource-group] for use with the storage
class to hold the Azure files share. Choose one of the following
[Azure storage redundancy SKUs][storage-skus] for *skuName*:

* **Standard_LRS**: Standard locally redundant storage
* **Standard_GRS**: Standard geo-redundant storage
* **Standard_ZRS**: Standard zone-redundant storage
* **Standard_RAGRS**: Standard read-access geo-redundant storage
* **Standard_RAGZRS**: Standard read-access geo-zone-redundant storage
* **Premium_LRS**: Premium locally redundant storage
* **Premium_ZRS**: Premium zone-redundant storage

> [!NOTE] Azure Files supports Azure Premium file shares. The minimum file share capacity is 100
> GiB. We recommend using Azure Premium file shares instead of Standard file shares because Premium
> file shares offer higher performance, low-latency disk support for I/O-intensive workloads.

When you use storage CSI drivers on AKS, there are two more built-in `StorageClasses` that uses the
Azure Files CSI storage drivers. The other CSI storage classes are created with the cluster
alongside the in-tree default storage classes.

- `azurefile-csi`: Uses Azure Standard Storage to create an Azure file share.

- `azurefile-csi-premium`: Uses Azure Premium Storage to create an Azure file share.

The reclaim policy on both storage classes ensures that the underlying Azure files share is deleted
when the respective PV is deleted. Since the storage classes also configure the file shares to be
expandable, you just need to edit the [persistent volume claim][persistent-volume-claim-overview]
(PVC) with the new size.

To use these storage classes, create a PVC and respective pod that references and uses them. A PVC
is used to automatically provision storage based on a storage class. A PVC can use one of the
pre-created storage classes or a user-defined storage class to create an Azure files share for the
desired SKU and size. When you create a pod definition, the PVC is specified to request the desired
storage.

Create an
[example PVC and pod that prints the current date into an `outfile`](https://github.com/kubernetes-sigs/azurefile-csi-driver/blob/master/deploy/example/statefulset.yaml)
by running the [kubectl apply][kubectl-apply] commands:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/deploy/example/pvc-azurefile-csi.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/deploy/example/nginx-pod-azurefile.yaml
```

The output of the command resembles the following example:

```output
persistentvolumeclaim/pvc-azurefile created
pod/nginx-azurefile created
```

After the pod is in the running state, you can validate that the file share is correctly mounted by
running the following command and verifying the output contains the `outfile`:

```bash
kubectl exec nginx-azurefile -- ls -l /mnt/azurefile
```

The output of the command resembles the following example:

```output
total 29
-rwxrwxrwx 1 root root 29348 Aug 31 21:59 outfile
```

### Create a custom storage class

The default storage classes suit the most common scenarios, but not all. For some cases, you might
want to have your own storage class customized with your own parameters. For example, use the
following manifest to configure the `mountOptions` of the file share.

The default value for *fileMode* and *dirMode* is *0777* for Kubernetes mounted file shares. You can
specify the different mount options on the storage class object.

Create a file named `azure-file-sc.yaml`, and paste the following example manifest:

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: my-azurefile
provisioner: file.csi.azure.com
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
mountOptions:
  - dir_mode=0640
  - file_mode=0640
  - uid=0
  - gid=0
  - mfsymlinks
  - cache=strict # https://linux.die.net/man/8/mount.cifs
  - nosharesock
parameters:
  skuName: Standard_LRS
```

Create the storage class by running the [kubectl apply][kubectl-apply] command:

```bash
kubectl apply -f azure-file-sc.yaml
```

The output of the command resembles the following example:

```output
storageclass.storage.k8s.io/my-azurefile created
```

The Azure Files CSI driver supports creating
[snapshots of persistent volumes](https://kubernetes-csi.github.io/docs/snapshot-restore-feature.html)
and the underlying file shares.

Create a
[volume snapshot class](https://github.com/kubernetes-sigs/azurefile-csi-driver/blob/master/deploy/example/snapshot/volumesnapshotclass-azurefile.yaml)
with the [kubectl apply][kubectl-apply] command:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/deploy/example/snapshot/volumesnapshotclass-azurefile.yaml
```

The output of the command resembles the following example:

```output
volumesnapshotclass.snapshot.storage.k8s.io/csi-azurefile-vsc created
```

Create a
[volume snapshot](https://github.com/kubernetes-sigs/azurefile-csi-driver/blob/master/deploy/example/snapshot/volumesnapshot-azurefile.yaml)
from the PVC we
[dynamically created at the beginning of this article](#create-azure-files-pvs-using-built-in-storage-classes)
(`pvc-azurefile`).

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/deploy/example/snapshot/volumesnapshot-azurefile.yaml
```

The output of the command resembles the following example:

```output
volumesnapshot.snapshot.storage.k8s.io/azurefile-volume-snapshot created
```

Verify the snapshot was created correctly by running the following command:

```bash
kubectl describe volumesnapshot azurefile-volume-snapshot
```

The output of the command resembles the following example:

```bash
Name:         azurefile-volume-snapshot
Namespace:    default
Labels:       <none>
Annotations:  API Version:  snapshot.storage.k8s.io/v1beta1
Kind:         VolumeSnapshot
Metadata:
  Creation Timestamp:  2020-08-27T22:37:41Z
  Finalizers:
    snapshot.storage.kubernetes.io/volumesnapshot-as-source-protection
    snapshot.storage.kubernetes.io/volumesnapshot-bound-protection
  Generation:        1
  Resource Version:  955091
  Self Link:         /apis/snapshot.storage.k8s.io/v1beta1/namespaces/default/volumesnapshots/azurefile-volume-snapshot
  UID:               c359a38f-35c1-4fb1-9da9-2c06d35ca0f4
Spec:
  Source:
    Persistent Volume Claim Name:  pvc-azurefile
  Volume Snapshot Class Name:      csi-azurefile-vsc
Status:
  Bound Volume Snapshot Content Name:  snapcontent-c359a38f-35c1-4fb1-9da9-2c06d35ca0f4
  Ready To Use:                        false
Events:                                <none>
```

## Resize a persistent volume

You can request a larger volume for a PVC. Edit the PVC object, and specify a larger size. This
change triggers the expansion of the underlying volume that backs the PV.

> [!NOTE]
> A new PV is never created to satisfy the claim. Instead, an existing volume is resized. Shrinking persistent volumes is currently not supported.

In AKS, the built-in `azurefile-csi` storage class already supports expansion, so use the PVC [created earlier with this storage class](#create-azure-files-pvs-using-built-in-storage-classes). The PVC requested a 100 GiB file share. We can confirm that by running:

```bash
kubectl exec -it nginx-azurefile -- df -h /mnt/azurefile
```

The output of the command resembles the following example:

```output
Filesystem                                                                                Size  Used Avail Use% Mounted on
//f149b5a219bd34caeb07de9.file.core.windows.net/pvc-5e5d9980-da38-492b-8581-17e3cad01770  100G  128K  100G   1% /mnt/azurefile
```

Expand the PVC by increasing the `spec.resources.requests.storage` field:

```bash
kubectl patch pvc pvc-azurefile --type merge --patch '{"spec": {"resources": {"requests": {"storage": "200Gi"}}}}'
```

The output of the command resembles the following example:

```output
persistentvolumeclaim/pvc-azurefile patched
```

Verify that both the PVC and the file system inside the pod show the new size:

```bash
kubectl get pvc pvc-azurefile
NAME            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS    AGE
pvc-azurefile   Bound    pvc-5e5d9980-da38-492b-8581-17e3cad01770   200Gi      RWX            azurefile-csi   64m

kubectl exec -it nginx-azurefile -- df -h /mnt/azurefile
Filesystem                                                                                Size  Used Avail Use% Mounted on
//f149b5a219bd34caeb07de9.file.core.windows.net/pvc-5e5d9980-da38-492b-8581-17e3cad01770  200G  128K  200G   1% /mnt/azurefile
```

## Use a PV with private Azure Files storage (private endpoint)

If your Azure Files resources are protected with a private endpoint, you must create your own
storage class. Make sure that you've
[configured your DNS settings to resolve the private endpoint IP address to the FQDN of the connection string][azure-private-endpoint-dns].

Customize the following parameters:

* `resourceGroup`: The resource group where the storage account is deployed.

* `storageAccount`: The storage account name.

* `server`: The FQDN of the storage account's private endpoint.

Create a file named `private-azure-file-sc.yaml`, and then paste the following example manifest in
the file. Replace the values for `<resourceGroup>` and `<storageAccountName>`.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: private-azurefile-csi
provisioner: file.csi.azure.com
allowVolumeExpansion: true
parameters:
  resourceGroup: <resourceGroup>
  storageAccount: <storageAccountName>
  server: <storageAccountName>.file.core.windows.net
reclaimPolicy: Delete
volumeBindingMode: Immediate
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=0
  - gid=0
  - mfsymlinks
  - cache=strict  # https://linux.die.net/man/8/mount.cifs
  - nosharesock  # reduce probability of reconnect race
  - actimeo=30  # reduce latency for metadata-heavy workload
```

Create the storage class by using the `kubectl apply` command:

```bash
kubectl apply -f private-azure-file-sc.yaml
```

The output of the command resembles the following example:

```output
storageclass.storage.k8s.io/private-azurefile-csi created
```

Create a file named `private-pvc.yaml`, and then paste the following example manifest in the file:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: private-azurefile-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: private-azurefile-csi
  resources:
    requests:
      storage: 100Gi
```

Create the PVC by using the [kubectl apply][kubectl-apply] command:

```bash
kubectl apply -f private-pvc.yaml
```

## Use Managed Identity to access Azure Files storage (Preview)

Azure Files now supports managed identity-based authentication for SMB access. With this capability,
your applications running in AKS can securely access Azure Files shares without the need to store or
manage storage account keys or credentials. Managed identities provide a streamlined and secure
authentication mechanism, simplifying access management and reducing the risk associated with
credential exposure. You can create a dynamic volume or a static volume.

> [!NOTE]
> Managed identity support for Azure Files in AKS is available in preview starting with AKS version 1.34 on Linux nodes.

# [Dynamic volume](#tab/dynamic-volume)

To enable managed identity for dynamically provisioned volumes, follow these steps:

1. Create a storage class with managed identity enabled using a YAML file, for example,  `azurefile-csi-managed-identity.yaml` with the following sample content. Set `mountWithManagedIdentity: "true"` under `parameters`:

   ```yml
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: azurefile-csi
    provisioner: file.csi.azure.com
    parameters:
      resourceGroup: EXISTING_RESOURCE_GROUP_NAME   # optional, node resource group by default if it's not provided
      storageAccount: EXISTING_STORAGE_ACCOUNT_NAME # optional, a new account will be created if it's not provided
      mountWithManagedIdentity: "true"
      # optional, clientID of the managed identity, kubelet identity would be used by default if it's not provided
      clientID: "xxxxx-xxxx-xxx-xxx-xxxxxxx"
    reclaimPolicy: Delete
    volumeBindingMode: Immediate
    allowVolumeExpansion: true
    mountOptions:
     - dir_mode=0777  # modify this permission if you want to enhance the security
     - file_mode=0777
     - uid=0
     - gid=0
     - mfsymlinks
     - cache=strict  # https://linux.die.net/man/8/mount.cifs
     - nosharesock  # reduce probability of reconnect race
     - actimeo=30  # reduce latency for metadata-heavy workload
     - nobrl  # disable sending byte range lock requests to the server
   ```

1. Apply this storage class by running the following command:

   ```bash
   kubectl apply -f azurefile-csi-managed-identity.yaml
   ```

1. Deploy your **StatefulSet** or workload using the new storage class that references this PVC to
   ensure that the volume is provisioned using managed identity authentication. In your PVC
   manifest, set `storageClassName: azurefile-csi-managed-identity`. For example:

   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: azurefile-managed-identity-pvc
   spec:
     accessModes:
      - ReadWriteMany
     storageClassName: azurefile-csi-managed-identity
     resources:
      requests:
       storage: 100Gi
   ```

# [Static volume](#tab/static-volume)

To enable managed identity for statically provisioned volumes, follow these steps:

1. Create a PV manifest, for example, `azurefile-csi-static.yaml`. Define a PV that references your
   existing Azure Files share and enables managed identity authentication by setting
   `mountWithManagedIdentity: "true"` under `volumeAttributes`.

   Sample PV manifest:

   ```yaml
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     name: pv-azurefile
   spec:
     capacity:
       storage: 100Gi
     accessModes:
       - ReadWriteMany
     persistentVolumeReclaimPolicy: Retain
     storageClassName: azurefile-csi
     mountOptions:
       - dir_mode=0777  # modify this permission if you want to enhance the security
       - file_mode=0777
       - uid=0
       - gid=0
       - mfsymlinks
       - cache=strict  # https://linux.die.net/man/8/mount.cifs
       - nosharesock  # reduce probability of reconnect race
       - actimeo=30  # reduce latency for metadata-heavy workload
       - nobrl  # disable sending byte range lock requests to the server
     csi:
       driver: file.csi.azure.com
       # make sure volumeHandle is unique for every identical share in the cluster
       volumeHandle: "{resource-group-name}#{account-name}#{file-share-name}"
       volumeAttributes:
         resourceGroup: EXISTING_RESOURCE_GROUP_NAME   # optional, node resource group by default if it's not provided
         storageAccount: EXISTING_STORAGE_ACCOUNT_NAME # optional, a new account will be created if it's not provided
         shareName: EXISTING_FILE_SHARE_NAME
         mountWithManagedIdentity: "true"
         # optional, clientID of the managed identity, kubelet identity would be used by default if it's empty
         clientID: "xxxxx-xxxx-xxx-xxx-xxxxxxx"
   ```

1. Deploy the PV to your application pod by running the following command:

   ```bash
   kubectl apply -f azurefile-csi-static.yaml
   ```

## Understand Azure Files NFS

Azure Files supports the
[NFS v4.1 protocol](/azure/storage/files/storage-files-how-to-create-nfs-shares). NFS version 4.1
support for Azure Files provides you with a fully managed NFS system as a service built on highly
available, highly durable distributed resilient storage platform.

This option is optimized for random access workloads with in-place data updates and provides full
POSIX file system support. This section shows you how to use NFS shares with the Azure File CSI
driver on an AKS cluster.

> [!NOTE] You can use a private endpoint instead of allowing access to the selected VNet.

This section explains how to maximize performance and security when using Azure Files NFS 4.1 with
AKS. Learn how to:

* Optimize NFS read and write size settings

* Create and configure an NFS storage class

* Deploy workloads that use NFS-backed volumes

* Enable Encryption in Transit (EiT) to protect data as it moves between your AKS cluster and Azure
  Files.

# [NFS Optimization](#tab/optimize)

This section provides information about how to approach performance tuning NFS with the Azure Files
CSI driver with the `rsize` (read size) and `wsize` (write size) options. The `rsize` and `wsize`
options set the maximum transfer size of an NFS operation. If `rsize` or `wsize` aren't specified on
mount, the client and server negotiate the largest size supported by the two. Currently, both Azure
Files and modern Linux distributions support read and write sizes as large as 1,048,576 Bytes (1
MiB).

Optimal performance is based on efficient client-server communication. Increasing or decreasing the
**mount** read and write option size values can improve NFS performance. The default size of the
read/write packets transferred between client and server are 8 KB for NFS version 2, and 32 KB for
NFS version 3 and 4. These defaults might be too large or too small. Reducing the `rsize` and
`wsize` might improve NFS performance in a congested network by sending smaller packets for each
NFS-read reply and write request. However, this reduction can increase the number of packets needed
to send data across the network, increasing total network traffic and CPU utilization on the client
and server.

It's important that you perform testing to find an `rsize` and `wsize` that sustains efficient
packet transfer, where it doesn't decrease throughput and increase latency.

For example, to configure a maximum `rsize` and `wsize` of 256-KiB, configure the `mountOptions` in
the storage class as follows:

```yml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi-nfs
provisioner: file.csi.azure.com
allowVolumeExpansion: true
parameters:
  protocol: nfs
mountOptions:
  - nconnect=4
  - noresvport
  - actimeo=30
  - rsize=262144
  - wsize=262144
```

# [NFS storage class](#tab/nfs-storage)

Create a file named `nfs-sc.yaml` and copy the sample manifest. For a list of supported
`mountOptions`, see [NFS mount options][nfs-file-share-mount-options].

> [!NOTE]
> The Azure File CSI driver configures `vers`, `minorversion`, and `sec`. Specifying a value in your manifest for these properties **isn't** supported.

```yml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi-nfs
provisioner: file.csi.azure.com
allowVolumeExpansion: true
parameters:
  protocol: nfs
mountOptions:
  - nconnect=4
  - noresvport
  - actimeo=30
```

After you edit and save your YAML file, apply the storage class with the [kubectl apply][kubectl-apply] command:

```bash
kubectl apply -f nfs-sc.yaml
```

The output of the command resembles the following example:

```output
storageclass.storage.k8s.io/azurefile-csi-nfs created
```

# [NFS deployment](#tab/nfs-deployment)

You can deploy a sample **StatefulSet** that writes timestamps to a file named `data.txt` by running
the [kubectl apply][kubectl-apply] command:

```bash
kubectl apply -f

apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: statefulset-azurefile
  labels:
    app: nginx
spec:
  podManagementPolicy: Parallel  # default is OrderedReady
  serviceName: statefulset-azurefile
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
        - name: statefulset-azurefile
          image: mcr.microsoft.com/oss/nginx/nginx:1.19.5
          command:
            - "/bin/bash"
            - "-c"
            - set -euo pipefail; while true; do echo $(date) >> /mnt/azurefile/outfile; sleep 1; done
          volumeMounts:
            - name: persistent-storage
              mountPath: /mnt/azurefile
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: nginx
  volumeClaimTemplates:
    - metadata:
        name: persistent-storage
      spec:
        storageClassName: azurefile-csi-nfs
        accessModes: ["ReadWriteMany"]
        resources:
          requests:
            storage: 100Gi
```

The output of the command resembles the following example:

```output
statefulset.apps/statefulset-azurefile created
```

Validate the contents of the volume by running the following command:

```bash
kubectl exec -it statefulset-azurefile-0 -- df -h
```

The output of the command resembles the following example:

```output
Filesystem      Size  Used Avail Use% Mounted on
...
/dev/sda1                                                                                 29G   11G   19G  37% /etc/hosts
accountname.file.core.windows.net:/accountname/pvc-fa72ec43-ae64-42e4-a8a2-556606f5da38  100G     0  100G   0% /mnt/azurefile
...
```

Because the NFS is in a Premium storage account, the minimum file share size is 100 GiB. If you
create a PVC with a small storage size, you might encounter an error similar to the following
output:

```error
*failed to create file share ... size (5)...*.
```

# [NFS EiT (Preview)](#tab/nfs-eit)

With AKS version 1.33, the
[Encryption in Transit (EiT)](/azure/storage/files/encryption-in-transit-for-nfs-shares) **Preview**
feature ensures that all read and writes to the NFS file shares within the VNet are encrypted,
providing an additional layer of security.

By setting `encryptInTransit: "true"` in the storage class parameters, you can enable data
encryption in transit for NFS Azure file shares. For example:

```yml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi-nfs
provisioner: file.csi.azure.com
allowVolumeExpansion: true
parameters:
  protocol: nfs
  encryptInTransit: "true"
mountOptions:
  - nconnect=4
  - noresvport
  - actimeo=30
```

> [!NOTE]
>
> - ARM64 nodes aren't currently supported.
>
> - This feature is supported for the following [Linux distributions](/azure/storage/files/encryption-in-transit-for-nfs-shares#overview) in these [supported regions](/azure/storage/files/encryption-in-transit-for-nfs-shares#supported-regions).

## Windows containers

The Azure Files CSI driver also supports Windows nodes and containers. To use Windows containers,
follow the [Windows containers quickstart](./learn/quick-windows-container-deploy-cli.md) to add a
Windows node pool.

After you have a Windows node pool, use the built-in storage classes like `azurefile-csi` or create
a custom one. You can deploy an example
[Windows-based stateful set](https://github.com/kubernetes-sigs/azurefile-csi-driver/blob/master/deploy/example/windows/statefulset.yaml)
that saves timestamps into a file `data.txt` by running the [kubectl apply][kubectl-apply] command:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/deploy/example/windows/statefulset.yaml
```

The output of the command resembles the following example:

```output
statefulset.apps/busybox-azurefile created
```

Validate the contents of the volume by running the following [kubectl exec][kubectl-exec] command:

```bash
kubectl exec -it busybox-azurefile-0 -- cat c:\\mnt\\azurefile\\data.txt # on Linux or MacOS Bash
kubectl exec -it busybox-azurefile-0 -- cat c:\mnt\azurefile\data.txt # on Windows Powershell or CMD
```

The output of the commands resembles the following example:

```output
2020-08-27 22:11:01Z
2020-08-27 22:11:02Z
2020-08-27 22:11:04Z
(...)
```

## Next steps

- For best practices when using Azure Files, see
  [Provision Azure Files storage](azure-csi-files-storage-provision.md#best-practices).
- To learn how to use CSI driver for Azure Disks, see
  [Use Azure Disks with CSI driver][azure-disk-csi].
- To learn how to use CSI driver for Azure Blob storage, see
  [Use Azure Blob storage with CSI driver][azure-blob-csi].
- For more about storage best practices, see
  [Best practices for storage and backups in Azure Kubernetes Service][operator-best-practices-storage].

::: zone-end

<!-- LINKS - external -->
[access-modes]: https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes
[create-burstable-storage-class]: https://github.com/Azure-Samples/burstable-managed-csi-premium
[csi-blob-storage-open-source-driver]: https://github.com/kubernetes-sigs/blob-csi-driver
[csi-blob-storage-open-source-driver-uninstall-steps]: https://github.com/kubernetes-sigs/blob-csi-driver/blob/master/docs/install-csi-driver-master.md#clean-up-blob-csi-driver
[csi-driver-parameters]: https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/docs/driver-parameters.md
[csi-specification]: https://github.com/container-storage-interface/spec/blob/master/spec.md
[expand-pvc-with-downtime]: https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/docs/known-issues/sizegrow.md
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-exec]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#exec
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[kubernetes-storage-classes]: https://kubernetes.io/docs/concepts/storage/storage-classes/
[kubernetes-volumes]: https://kubernetes.io/docs/concepts/storage/persistent-volumes/
[managed-disk-pricing-performance]: https://azure.microsoft.com/pricing/details/managed-disks/
[nfs-overview]:/windows-server/storage/nfs/nfs-overview
[smb-overview]: /windows/desktop/FileIO/microsoft-smb-protocol-and-cifs-protocol-overview

<!-- LINKS - internal -->
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[az-disk-create]: /cli/azure/disk#az-disk-create
[az-disk-list]: /cli/azure/disk#az-disk-list
[az-disk-show]: /cli/azure/disk#az-disk-show
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-feature-list]: /cli/azure/feature#az-feature-list
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-on-demand-bursting]: /azure/virtual-machines/disk-bursting#on-demand-bursting
[az-premium-ssd]: /azure/virtual-machines/disks-types#premium-ssds
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-snapshot-create]: /cli/azure/snapshot#az-snapshot-create
[azure-blob-csi]: azure-blob-csi.md
[azure-csi-blob-storage-provision]: azure-csi-blob-storage-provision.md
[azure-disk-csi]: azure-disk-csi.md
[azure-disk-csi-driver]: azure-disk-csi.md
[azure-disk-volume]: azure-disk-volume.md
[azure-files-csi]: azure-files-csi.md
[azure-files-csi-driver]: azure-files-csi.md
[azure-files-pvc]: azure-files-dynamic-pv.md
[azure-netapp-files-mount-options-best-practices]: /azure/azure-netapp-files/performance-linux-mount-options#rsize-and-wsize
[azure-private-endpoint-dns]: /azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration
[compare-access-with-nfs]: /azure/storage/common/nfs-comparison
[concepts-storage]: concepts-storage.md
[csi-drivers-aks]: csi-storage-drivers.md
[csi-drivers-overview]: csi-storage-drivers.md
[disk-based-solutions]: /azure/cloud-adoption-framework/scenarios/app-platform/aks/storage#disk-based-solutions
[enable-on-demand-bursting]: ../virtual-machines/disks-enable-bursting.md?tabs=azure-cli
[expand-an-azure-managed-disk]: ../virtual-machines/linux/expand-disks.md#expand-an-azure-managed-disk
[general-purpose-machine-sizes]: /azure/virtual-machines/sizes-general
[install-azure-cli]: /cli/azure/install-azure-cli
[nfs-file-share-mount-options]: /azure/storage/files/storage-files-how-to-mount-nfs-shares#mount-options
[node-resource-group]: faq.yml
[operator-best-practices-storage]: operator-best-practices-storage.md
[operator-best-practices-storage]: operator-best-practices-storage.md
[operator-best-practices-storage]: operator-best-practices-storage.md
[persistent-volume]: concepts-storage.md#persistent-volumes
[persistent-volume-claim-overview]: concepts-storage.md#persistent-volume-claims
[premium-storage]: /azure/virtual-machines/disks-types
[private-endpoint-overview]: /azure/private-link/private-endpoint-overview
[share-snapshots-overview]: /azure/storage/files/storage-snapshots-files
[statically-provision-a-volume]: azure-csi-files-storage-provision.md#statically-provision-a-volume
[storage-class-concepts]: concepts-storage.md#storage-classes
[storage-skus]: /azure/storage/common/storage-redundancy
