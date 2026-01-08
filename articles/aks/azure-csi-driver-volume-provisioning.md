---
title: Manage the CSI driver in AKS for volume provisioning
description: Learn how to use the Container Storage Interface (CSI) driver to provision volumes in an Azure Kubernetes Service (AKS) cluster.
ms.topic: how-to
ms.custom: biannual
ms.subservice: aks-storage
ms.date: 01/08/2025
author: schaffererin
ms.author: schaffererin
zone_pivot_groups: azure-csi-driver
# Customer intent: "As a Kubernetes administrator, I want to implement the Azure CSI driver in my AKS cluster so that I can efficiently manage storage provisioning and enhance performance for my containerized applications."
---

# Azure storage CSI driver and volume provisioning

::: zone pivot="csi-blob"

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

::: zone-end
::: zone pivot="csi-disk"

The Azure Disks Container Storage Interface (CSI) driver is a
[CSI specification](https://github.com/container-storage-interface/spec/blob/master/spec.md)-compliant
driver used by Azure Kubernetes Service (AKS) to manage the lifecycle of Azure Disk.

The CSI is a standard for exposing arbitrary block and file storage systems to containerized
workloads on Kubernetes. By adopting and using CSI, AKS now can write, deploy, and iterate plug-ins
to expose new or improve existing storage systems in Kubernetes. Using CSI drivers in AKS avoids
having to touch the core Kubernetes code and wait for its release cycles. To create an AKS cluster
with CSI driver support, see [Enable CSI driver on AKS](csi-storage-drivers.md).

For more information on Kubernetes volumes, see [Storage options for applications in AKS](concepts-storage.md).

> [!NOTE]
> *In-tree drivers* refer to the current storage drivers that are part of the core Kubernetes code versus the new CSI drivers, which are plug-ins.

::: zone-end
::: zone pivot="csi-files"

The Azure Files Container Storage Interface (CSI) driver is a
[CSI specification][csi-specification]-compliant driver used by Azure Kubernetes Service (AKS) to
manage the lifecycle of Azure file shares. The CSI is a standard for exposing arbitrary block and
file storage systems to containerized workloads on Kubernetes.

By adopting and using CSI, AKS now can write, deploy, and iterate plug-ins to expose new or improve
existing storage systems in Kubernetes. Using CSI drivers in AKS avoids having to touch the core
Kubernetes code and wait for its release cycles.

To create an AKS cluster with CSI drivers support, see [Enable CSI drivers on AKS][csi-drivers-overview].

> [!NOTE]
> *In-tree drivers* refer to the current storage drivers that are part of the core Kubernetes code versus the new CSI drivers, which are plug-ins.

::: zone-end
::: zone pivot="csi-blob"

## Azure CSI driver features

Azure Blob storage CSI driver supports the following features:

* BlobFuse
* NFS 3.0 protocol

::: zone-end
::: zone pivot="csi-disk"

In addition to in-tree driver features, Azure Disk CSI driver supports the following features:

* Performance improvements during concurrent disk attach and detach

  * In-tree drivers attach or detach disks in serial, while CSI drivers attach or detach disks in
    batch. There's significant improvement when there are multiple disks attaching to one node.

* Premium SSD v1 and v2 are supported.

  * `PremiumV2_LRS` only supports `None` caching mode

* Zone-redundant storage (ZRS) disk support

  * `Premium_ZRS`, `StandardSSD_ZRS` disk types are supported. ZRS disk could be scheduled on the
    zone or non-zone node, without the restriction that disk volume should be colocated in the same
    zone as a given node. For more information, including which regions are supported, see
    [Zone-redundant storage for managed disks](/azure/virtual-machines/disks-redundancy).

* [Volume snapshot](#learn-about-volume-snapshots)
* [Volume clone](#clone-volumes)
* [Resize disk persistent volume without downtime](#resize-an-azure-disk-pv-without-downtime)

> [!NOTE]
> Depending on the VM SKU that's being used, the Azure Disk CSI driver might have a per-node volume limit. For some powerful VMs (for example, 16 cores), the limit is 64 volumes per node. To identify the limit per VM SKU, review the **Max data disks** column for each VM SKU offered. For a list of VM SKUs offered and their corresponding detailed capacity limits, see [General purpose virtual machine sizes][general-purpose-machine-sizes].

::: zone-end

## Prerequisites

::: zone pivot="csi-blob"

* You must have the Azure CLI version 2.42 or later installed and configured. To find the version,
  run `az --version`. If you need to install or upgrade, see
  [Install Azure CLI][install-azure-cli]. If you installed the Azure CLI `aks-preview` extension,
  make sure that you update the extension to the latest version by calling
  `az extension update --name aks-preview`.

* Perform the following steps to [clean up the open source driver][csi-blob-storage-open-source-driver-uninstall-steps] if you
  previously installed the [CSI Blob Storage open-source driver][csi-blob-storage-open-source-driver] to access Azure Blob
  storage from your cluster.

* Your AKS cluster *Control plane* identity (your AKS cluster name) is added to the
  [Contributor](/azure/role-based-access-control/built-in-roles#contributor) role on the VNet and
  network security group.

* To support an [Azure Data Lake Storage Gen2 account][azure-datalake-storage-account] (ADLS) when
  using BlobFuse mount, perform the following actions:

   * To create an ADLS account using the driver in dynamic provisioning, specify `isHnsEnabled: "true"` in the storage class parameters.
   * To enable BlobFuse access to an ADLS account in static provisioning, specify the mount option `--use-adls=true` in the persistent volume.
   * If you're going to enable a storage account with Hierarchical Namespace, existing persistent volumes (PVs) should be remounted with `--use-adls=true` mount option.

* By default, the BlobFuse cache is located in the `/mnt` directory. If the virtual machine (VM) SKU
  provides a temporary disk, the `/mnt` directory is mounted on the temporary disk. However, if the
  VM SKU doesn't provide a temporary disk, the `/mnt` directory is mounted on the OS disk, you could
  set `--tmp-path=` mount option to specify a different cache directory.

> [!NOTE]
> If the **blobfuse-proxy** isn't enabled during the installation of the open source driver, the uninstallation of the open source driver disrupts existing blobfuse mounts. However, NFS mounts remain unaffected.

::: zone-end
::: zone pivot="csi-disk"

* You must have an AKS cluster with the Azure Disk CSI driver enabled. The CSI driver is enabled by
  default on AKS clusters running Kubernetes version 1.21 or later.

* Azure CLI version 2.37.0 or later is installed and configured. Run `az --version` to find the
  version. If you need to install or upgrade, see
  [Install Azure CLI](/cli/azure/install-azure-cli).

* The `kubectl` command-line tool is installed and configured to connect to your AKS cluster.

* A storage class configured to use the Azure Disk CSI driver (`disk.csi.azure.com`).

* The Azure Disk CSI driver has a per-node volume limit. The volume count changes based on the size
  of the node/node pool. Run the [kubectl get][kubectl-get] command to determine the number of
  volumes that can be allocated per node:

  ```bash
  kubectl get CSINode <nodename> -o yaml
  ```

  If the per-node volume limit is an issue for your workload, consider using
  [Azure Container Storage][azure-container-storage] for persistent volumes instead of CSI drivers.

::: zone-end
::: zone pivot="csi-files"

**General requirements:**

* You must have an AKS cluster with the Azure Files CSI driver enabled. The Azure Files CSI driver
  is enabled by default on AKS clusters running Kubernetes version 1.21 or later.

* Azure CLI version 2.37.0 or later is installed and configured. To check your version, run
  `az --version`. If you need to install or upgrade, see
  [Install Azure CLI](/cli/azure/install-azure-cli).

* The `kubectl` command-line tool is installed and configured to connect to your AKS cluster.

* A storage class configured to use the Azure Files CSI driver (`file.csi.azure.com`).

* When choosing between standard and premium file shares, it's important you understand the provisioning model and requirements of the expected usage pattern you plan to run on Azure Files. For more information, see [Choosing an Azure Files performance tier based on usage patterns][azure-files-usage].

**Network File Share (NFS) requirements:**

* Your AKS cluster *Control plane* identity (your AKS cluster name) is added to the
  [Contributor](/azure/role-based-access-control/built-in-roles#contributor) role on the VNet and
  **NetworkSecurityGroup**.

* Your AKS cluster's service principal or managed service identity (MSI) must be added to the
  **Contributor** role to the storage account.

**Managed Identity requirements:**

* Ensure the
  [user-assigned Kubelet identity](use-managed-identity.md#create-a-kubelet-managed-identity) is
  granted the `Storage File Data SMB MI Admin` role on the storage account. If you use your own
  storage account, you need to assign `Storage File Data SMB MI Admin` role to the user-assigned
  Kubelet identity on that storage account.

* If the CSI driver creates the storage account, grant the `Storage File Data SMB MI Admin` role to
  the resource group where the storage account resides.

* If you use the default built-in user-assigned Kubelet identity, it already has the required
  `Storage File Data SMB MI Admin` role on the managed node resource group.

> [!NOTE]
> The Azure File CSI driver only permits the mounting of SMB file shares using key-based (NTLM v2) authentication, and therefore doesn't support the maximum security profile of Azure File share settings. On the other hand, mounting NFS file shares doesn't require key-based authentication.

::: zone-end

::: zone pivot="csi-blob"

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

::: zone-end

## Use a persistent volume for storage

Kubernetes assigns a [persistent volume][persistent-volume] (PV) as a storage resource to one or more pods. You can provision PVs dynamically through Kubernetes or statically as an administrator.

::: zone pivot="csi-blob"

If multiple pods need concurrent access to the same storage volume, you can use Azure
Blob storage to connect by using NFS or BlobFuse. This article shows you how to dynamically create
an Azure Blob storage container for use by multiple pods in an AKS cluster.

For more information on Kubernetes volumes, see [Storage options for applications in AKS][concepts-storage].

::: zone-end
::: zone pivot="csi-disk"

This article shows you how to dynamically create a PV with Azure disk for use by a single pod in an
AKS cluster.

::: zone-end
::: zone pivot="csi-files"

If multiple pods need concurrent access to the same storage volume, you can use Azure Files to
connect by using the [Server Message Block (SMB)][smb-overview] or
[Network File System (NFS)][nfs-overview]. This article shows you how to dynamically create an Azure
Files share for use by multiple pods in an AKS cluster.

::: zone-end

**Dynamically provisioned volume:** Use this approach when you want Kubernetes to automatically
create and manage storage resources. It's ideal for scenarios where you need on-demand scaling,
prefer infrastructure-as-code, and want to minimize manual configuration steps.

**Statically provisioned volume:** Choose this method if you already have an Azure Blob storage
account or container that you want to use. It provides more control over storage setup, access, and
lifecycle, and is suitable when you need to connect to existing resources or reuse storage across
multiple clusters or workloads.

::: zone pivot="csi-blob"

# [Dynamic volume](#tab/dynamic-volume-blob)

This section provides guidance for cluster administrators who want to provision one or more
persistent volumes that include details of Blob storage for use by a workload. A persistent volume
claim (PVC) uses the storage class object to dynamically provision an Azure Blob storage container.

To provision a persistent volume using Azure Blob storage with the provided storage class, follow
these steps:

1. Create the `StorageClass` manifest by saving the following YAML to a file named
   `blob-fuse-sc.yaml`:

   ```yaml
   apiVersion: storage.k8s.io/v1
   kind: StorageClass
   metadata:
     name: blob-fuse
   provisioner: blob.csi.azure.com
   parameters:
     skuName: Premium_LRS  # available values: Standard_LRS, Premium_LRS, Standard_GRS, Standard_RAGRS, Standard_ZRS, Premium_ZRS
     protocol: fuse2
     networkEndpointType: privateEndpoint
   reclaimPolicy: Delete
   volumeBindingMode: Immediate
   allowVolumeExpansion: true
   mountOptions:
     - -o allow_other
     - --file-cache-timeout-in-seconds=120
     - --use-attr-cache=true
     - --cancel-list-on-mount-seconds=10  # prevent billing charges on mounting
     - -o attr_timeout=120
     - -o entry_timeout=120
     - -o negative_timeout=120
     - --log-level=LOG_WARNING  # LOG_WARNING, LOG_INFO, LOG_DEBUG
     - --cache-size-mb=1000  # Default will be 80% of available memory, eviction will happen beyond specified value.
   ```

1. To create the storage class in your cluster, apply the `StorageClass` by running the following
   command:

   ```bash
   kubectl apply -f blob-fuse-sc.yaml
   ```

## Create a PVC using built-in storage class

A storage class is used to define how an Azure Blob storage container is created. A storage account
is automatically created in the node resource group for use with the storage class to hold the Azure
Blob storage container. Choose one of the following Azure storage redundancy SKUs for skuName:

* **Standard_LRS**: Standard locally redundant storage
* **Premium_LRS**: Premium locally redundant storage
* **Standard_ZRS**: Standard zone redundant storage
* **Premium_ZRS**: Premium zone redundant storage
* **Standard_GRS**: Standard geo-redundant storage
* **Standard_RAGRS**: Standard read-access geo-redundant storage

When you use storage CSI drivers on AKS, there are two other built-in `StorageClasses` that use the Azure Blob CSI storage driver.

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

A PVC uses the storage class object to dynamically provision an Azure Blob storage container. The following YAML can be used to create a 5 GB PVC with *ReadWriteMany* access, using the built-in storage class. For more information on access modes, see the [Kubernetes persistent volume][kubernetes-volumes] documentation.

1. Create a file named `blob-nfs-pvc.yaml` and copy the following YAML:

   ```yml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: azure-blob-storage
   spec:
     accessModes:
     - ReadWriteMany
     storageClassName: azureblob-nfs-premium
     resources:
       requests:
         storage: 5Gi
   ```

1. Create the PVC with the [kubectl create][kubectl-create] command:

   ```bash
   kubectl create -f blob-nfs-pvc.yaml
   ```

Once complete, the Blob storage container is created. You can use the [kubectl get][kubectl-get]
command to view the status of the PVC:

```bash
kubectl get pvc azure-blob-storage
```

The output of the command resembles the following example:

```bash
NAME                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                AGE
azure-blob-storage   Bound    pvc-b88e36c5-c518-4d38-a5ee-337a7dda0a68   5Gi        RWX            azureblob-nfs-premium       92m
```

## Mount the PVC

The following YAML creates a pod that uses the PVC **azure-blob-storage** to mount the Azure Blob storage at the `/mnt/blob` path.

1. Create a file named `blob-nfs-pv`, and copy the following YAML. Make sure that the **claimName** matches the PVC created in the previous step.

   ```yml
   kind: Pod
   apiVersion: v1
   metadata:
     name: mypod
   spec:
     containers:
     - name: mypod
       image: mcr.microsoft.com/oss/nginx/nginx:1.17.3-alpine
       resources:
         requests:
           cpu: 100m
           memory: 128Mi
         limits:
           cpu: 250m
           memory: 256Mi
       volumeMounts:
       - mountPath: "/mnt/blob"
         name: volume
         readOnly: false
     volumes:
       - name: volume
         persistentVolumeClaim:
           claimName: azure-blob-storage
   ```

1. Create the pod with the [kubectl apply][kubectl-apply] command:

   ```bash
   kubectl apply -f blob-nfs-pv.yaml
   ```

1. After the pod is in the running state, run the following command to create a new file called `test.txt`.

   ```bash
   kubectl exec mypod -- touch /mnt/blob/test.txt
   ```

1. To validate the disk is correctly mounted, run the following command, and verify you see the `test.txt` file in the output:

   ```bash
   kubectl exec mypod -- ls /mnt/blob
   ```

   The output of the command resembles the following example:

   ```output
   test.txt
   ```

# [Static volume](#tab/static-volume-blob)

This section provides guidance for cluster administrators who want to create one or more PVs that include details of Blob storage for use by a workload.

## Create a Blob storage container

When you create an Azure Blob storage resource for use with AKS, you can create the resource in the
node resource group. This approach allows the AKS cluster to access and manage the blob storage
resource.

For this article, create the container in the node resource group. First, get the resource group
name with the [`az aks show`][az-aks-show] command and add the `--query nodeResourceGroup` query
parameter. The following example gets the node resource group for the AKS cluster named
**myAKSCluster** in the resource group named **myResourceGroup**:

```azurecli-interactive
az aks show --resource-group myResourceGroup --name myAKSCluster --query nodeResourceGroup -o tsv
```

The output of the command resembles the following example:

```azurecli-interactive
MC_myResourceGroup_myAKSCluster_eastus
```

Next, create a container for storing blobs following the steps in the
[Manage blob storage][manage-blob-storage] to authorize access and then create the container.

---

## Create an Azure Blob custom storage class

The default storage classes suit the most common scenarios, but not all. In some cases, you might
want to have your own storage class customized with your own parameters. In this section, we provide
two examples with the first one using the NFS protocol, and the second one using BlobFuse.

# [NFS](#tab/nfs)

In this example, the following manifest configures mounting a Blob storage container using the NFS
protocol. Use it to add the `tags` parameter.

1. Create a file named `blob-nfs-sc.yaml`, and paste the following example manifest:

    ```yml
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: azureblob-nfs-premium
    provisioner: blob.csi.azure.com
    parameters:
      protocol: nfs
      tags: environment=Development
    volumeBindingMode: Immediate
    allowVolumeExpansion: true
    mountOptions:
      - nconnect=4
    ```

1. Create the storage class with the [kubectl apply][kubectl-apply] command:

    ```bash
    kubectl apply -f blob-nfs-sc.yaml
    ```

    The output of the command resembles the following example:

    ```output
    storageclass.storage.k8s.io/blob-nfs-premium created
    ```

# [BlobFuse](#tab/blobfuse)

In this example, the following manifest configures using BlobFuse and mounts a Blob storage
container. Use it to update the *skuName* parameter.

1. Create a file named `blobfuse-sc.yaml` and paste the following example manifest:

   ```yml
   apiVersion: storage.k8s.io/v1
   kind: StorageClass
   metadata:
     name: azureblob-fuse-premium
   provisioner: blob.csi.azure.com
   parameters:
     skuName: Standard_GRS  # available values: Standard_LRS, Premium_LRS, Standard_GRS, Standard_RAGRS
    reclaimPolicy: Delete
    volumeBindingMode: Immediate
    allowVolumeExpansion: true
    mountOptions:
     - -o allow_other
     - --file-cache-timeout-in-seconds=120
     - --use-attr-cache=true
     - --cancel-list-on-mount-seconds=10  # prevent billing charges on mounting
     - -o attr_timeout=120
     - -o entry_timeout=120
     - -o negative_timeout=120
     - --log-level=LOG_WARNING  # LOG_WARNING, LOG_INFO, LOG_DEBUG
     - --cache-size-mb=1000  # Default will be 80% of available memory, eviction will happen beyond that.
   ```

1. Create the storage class with the [kubectl apply][kubectl-apply] command:

   ```bash
   kubectl apply -f blobfuse-sc.yaml
   ```

   The output of the command resembles the following example:

   ```output
   storageclass.storage.k8s.io/blob-fuse-premium created
   ```

---

## Mount an NFS or BlobFuse PV

In this section, you mount the PV using the NFS protocol or BlobFuse.

# [NFS](#tab/nfs)

Mounting Blob storage using the NFS v3 protocol doesn't authenticate using an account key. Your AKS
cluster needs to reside in the same or peered virtual network as the agent node. The only way to
secure the data in your storage account is by using a virtual network and other network security
settings. For more information on how to set up NFS access to your storage account, see
[Mount Blob Storage by using the Network File System (NFS) 3.0 protocol](/azure/storage/blobs/network-file-system-protocol-support-how-to).

The following example demonstrates how to mount a Blob storage container as a persistent volume
using the NFS protocol.

1. Create a file named `pv-blob-nfs.yaml` and copy in the following YAML. Under `storageClass`,
   update `resourceGroup`, `storageAccount`, and `containerName`.

   > [!NOTE]
   > The `volumeHandle` value within your YAML should be a unique volumeID for every identical storage blob container in the cluster.
   >
   > The characters `#` and `/` are reserved for internal use and can't be used.

   ```yml
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     annotations:
       pv.kubernetes.io/provisioned-by: blob.csi.azure.com
     name: pv-blob
   spec:
     capacity:
       storage: 1Pi
     accessModes:
       - ReadWriteMany
     persistentVolumeReclaimPolicy: Retain  # If set as "Delete" container would be removed after pvc deletion
     storageClassName: azureblob-nfs-premium
     mountOptions:
       - nconnect=4
     csi:
       driver: blob.csi.azure.com
       # make sure volumeid is unique for every identical storage blob container in the cluster
       # character `#` and `/` are reserved for internal use and cannot be used in volumehandle
       volumeHandle: account-name_container-name
       volumeAttributes:
         resourceGroup: resourceGroupName
         storageAccount: storageAccountName
         containerName: containerName
         protocol: nfs
   ```

   > [!NOTE]
   > While the [Kubernetes API](https://github.com/kubernetes/kubernetes/blob/release-1.26/pkg/apis/core/types.go#L303-L306) **capacity** attribute is mandatory, this value isn't used by the Azure Blob storage CSI driver because you can flexibly write data until you reach your storage account's capacity limit. The value of the `capacity` attribute is used only for size matching between *PVs* and *PVCs*. We recommend using a fictitious high value. The pod sees a mounted volume with a fictitious size of 5 Petabytes.

1. Run the following command to create the persistent volume using the [kubectl create][kubectl-create] command referencing the YAML file created earlier:

   ```bash
   kubectl create -f pv-blob-nfs.yaml
   ```

1. Create a `pvc-blob-nfs.yaml` file with a *PersistentVolumeClaim*. For example:

   ```yml
   kind: PersistentVolumeClaim
   apiVersion: v1
   metadata:
     name: pvc-blob
   spec:
     accessModes:
       - ReadWriteMany
     resources:
       requests:
         storage: 10Gi
     volumeName: pv-blob
     storageClassName: azureblob-nfs-premium
   ```

1. Run the following command to create the persistent volume claim using the [kubectl create][kubectl-create] command referencing the YAML file created earlier:

   ```bash
   kubectl create -f pvc-blob-nfs.yaml
   ```

# [BlobFuse](#tab/blobfuse)

Kubernetes needs credentials to access the Blob storage container created earlier, which is either
an Azure access key or SAS tokens. These credentials are stored in a Kubernetes secret, which is
referenced when you create a Kubernetes pod.

1. Use the `kubectl create secret command` to create the secret. You can authenticate using a
   [Kubernetes secret][kubernetes-secret] or [shared access signature][sas-tokens] (SAS) tokens. You
   must also provide the account name and key from an existing Azure storage account.

   # [Kubernetes secret](#tab/kubernetes-secret)

   The following example creates a [Secret object][kubernetes-secret] named `azure-secret` and
   populates the **azurestorageaccountname** and **azurestorageaccountkey** parameters.

   ```bash
   kubectl create secret generic azure-secret --from-literal azurestorageaccountname=NAME --from-literal azurestorageaccountkey="KEY" --type=Opaque
   ```

   # [SAS tokens](#tab/sas-tokens)

   The following example creates a [Secret object][kubernetes-secret] named `azure-sas-token` and
   populates the **azurestorageaccountname** and **azurestorageaccountsastoken** parameters.

   ```bash
   kubectl create secret generic azure-sas-token --from-literal azurestorageaccountname=NAME --from-literal azurestorageaccountsastoken
   ="sastoken" --type=Opaque
   ```

1. Create a `pv-blobfuse.yaml` file. Under `volumeAttributes`, update `containerName`. Under
   `nodeStateSecretRef`, update `name` with the name of the Secret object created earlier. For
   example:

   > [!NOTE]
   > The `volumeHandle` value within your YAML should be a unique volumeID for every identical storage blob container in the cluster.
   >
   > The characters `#` and `/` are reserved for internal use and can't be used.

   ```yml
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     annotations:
       pv.kubernetes.io/provisioned-by: blob.csi.azure.com
     name: pv-blob
   spec:
     capacity:
       storage: 10Gi
     accessModes:
       - ReadWriteMany
     persistentVolumeReclaimPolicy: Retain  # If set as "Delete" container would be removed after pvc deletion
     storageClassName: azureblob-fuse-premium
     mountOptions:
       - -o allow_other
       - --file-cache-timeout-in-seconds=120
     csi:
       driver: blob.csi.azure.com
       # volumeid has to be unique for every identical storage blob container in the cluster
       # character `#`and `/` are reserved for internal use and cannot be used in volumehandle
       volumeHandle: account-name_container-name
       volumeAttributes:
         containerName: containerName
       nodeStageSecretRef:
         name: azure-secret
         namespace: default
   ```

1. Run the following command to create the PV using the [kubectl create][kubectl-create] command
   referencing the YAML file created earlier:

   ```bash
   kubectl create -f pv-blobfuse.yaml
   ```

1. Create a `pvc-blobfuse.yaml` file with a PV. For example:

   ```yml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: pvc-blob
   spec:
     accessModes:
       - ReadWriteMany
     resources:
       requests:
         storage: 10Gi
     volumeName: pv-blob
     storageClassName: azureblob-fuse-premium
   ```

1. Run the following command to create the PVC using the [kubectl create][kubectl-create] command
   referencing the YAML file created earlier:

   ```bash
   kubectl create -f pvc-blobfuse.yaml
   ```

---

## Create a pod

The following YAML creates a pod that uses the PV or PVC named **pvc-blob** created earlier, to mount the Azure Blob storage at the `/mnt/blob` path.

1. Create a file named `nginx-pod-blob.yaml`, and copy in the following YAML. Make sure that the **claimName** matches the PVC created in the previous step when creating a PV for NFS or BlobFuse.

   ```yml
   kind: Pod
   apiVersion: v1
   metadata:
     name: nginx-blob
   spec:
     nodeSelector:
       "kubernetes.io/os": linux
     containers:
       - image: mcr.microsoft.com/oss/nginx/nginx:1.17.3-alpine
         name: nginx-blob
         volumeMounts:
           - name: blob01
             mountPath: "/mnt/blob"
             readOnly: false
     volumes:
       - name: blob01
         persistentVolumeClaim:
           claimName: pvc-blob
   ```

1. Run the following command to create the pod and mount the PVC using the [kubectl create][kubectl-create] command:

   ```bash
   kubectl create -f nginx-pod-blob.yaml
   ```

1. Run the following command to create an interactive shell session with the pod to verify if the Blob storage is mounted:

   ```bash
   kubectl exec -it nginx-blob -- df -h
   ```

   The output from the command resembles the following example:

   ```output
   Filesystem      Size  Used Avail Use% Mounted on
   ...
   blobfuse         14G   41M   13G   1% /mnt/blob
   ...
   ```

## Create a StatefulSet

To ensure your workload retains its storage volume across pod restarts or replacements, use a
StatefulSet. StatefulSets simplify the process of associating persistent storage with pods, so that
new pods created to replace failed ones can automatically access the same storage volumes. The
following examples demonstrate how to set up a StatefulSet for Blob storage using either BlobFuse or
the NFS protocol.

# [NFS](#tab/nfs-3)

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

# [BlobFuse](#tab/blobfuse-3)

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

::: zone-end
::: zone pivot="csi-disk"

### Dynamic PVC storage class parameters

The following table includes parameters you can use to define a custom storage class for your dynamic PVC.

# [General](#tab/general)

|Name | Description | Example | Mandatory | Default value|
|--- | --- | --- | --- | --- |
|skuName | Specify an Azure storage account type (alias: `storageAccountType`). | `Standard_LRS`, `Premium_LRS`, `Standard_GRS`, `Standard_RAGRS` | No | `Standard_LRS`|
|location | Specify an Azure location. | `eastus` | No | If empty, the driver uses the same location name as current cluster.|
|resourceGroup | Specify an Azure resource group name. | myResourceGroup | No | If empty, the driver uses the same resource group name as current cluster.|
|storageAccount | Specify an Azure storage account name.| storageAccountName | No | When a specific storage account name isn't provided, the driver looks for a suitable storage account that matches the account settings within the same resource group. If it fails to find a matching storage account, it creates a new one. However, if a storage account name is specified, the storage account must already exist. |
|networkEndpointType <sup>1</sup>| Specify network endpoint type for the storage account created by driver. If privateEndpoint is specified, a [private endpoint][storage-account-private-endpoint] is created for the storage account. For other cases, a service endpoint is created for the NFS protocol. | `privateEndpoint` | No | For an AKS cluster, add the AKS cluster name to the Contributor role in the resource group hosting the VNet.|
|protocol | Specify BlobFuse mount or NFSv3 mount. | `fuse`, `nfs` | No | `fuse`|
|containerName | Specify the existing container (directory) name. | container | No | If empty, driver creates a new container name, starting with `pvc-fuse` for BlobFuse or `pvc-nfs` for NFS v3. |
|containerNamePrefix | Specify Azure storage directory prefix created by driver. | my | No | Can only contain lowercase letters, numbers, hyphens, and length should be fewer than 21 characters. |
|server | Specify Azure storage account domain name. | Existing storage account DNS domain name, for example `<storage-account>.blob.core.windows.net`. | No | If empty, driver uses default `<storage-account>.blob.core.windows.net` or other sovereign cloud storage account DNS domain name.|
|allowBlobPublicAccess | Allow or disallow public access to all blobs or containers for storage account created by driver. | `true`,`false` | No | `false`|
|storageEndpointSuffix | Specify Azure storage endpoint suffix. | `core.windows.net` | No | If empty, the driver uses default storage endpoint suffix according to cloud environment.|
|tags | [Tags][az-tags] would be created in new storage account. | Tag format: 'foo=aaa,bar=bbb' | No | ""|
|matchTags | Match tags when driver tries to find a suitable storage account. | `true`,`false` | No | `false`|

<sup>1</sup> If the storage account is created by the driver, then you only need to specify `networkEndpointType: privateEndpoint` parameter in storage class. The CSI driver creates the private endpoint and private DNS zone (named `privatelink.blob.core.windows.net`) together with the account. If you bring your own storage account, then you need to [create the private endpoint][storage-account-private-endpoint] for the storage account. If you're using Azure Blob storage in a network isolated cluster, you must create a custom storage class with `networkEndpointType: privateEndpoint`.

# [BlobFuse](#tab/blobfuse3)

|Name | Description | Example | Mandatory | Default value|
|--- | --- | --- | --- | --- |
|subscriptionID | Specify Azure subscription ID where blob storage directory is created. | Azure subscription ID | No | If not empty, `resourceGroup` must be provided.|
|storeAccountKey | Specify store account key to Kubernetes secret. <br><br> `false` means driver uses kubelet identity to get account key. | `true`,`false` | No | `true`|
|secretName | Specify secret name to store account key. | | No | |
|secretNamespace | Specify the namespace of secret to store account key. | `default`,`kube-system`, etc. | No | PVC namespace |
|isHnsEnabled | Enable `Hierarchical namespace` for Azure Data Lake storage account. | `true`,`false` | No | `false`|

# [NFS](#tab/nfs3)

|Name | Description | Example | Mandatory | Default value|
|--- | --- | --- | --- | --- |
|mountPermissions | Specify mounted folder permissions. |The default is `0777`. If set to `0`, the driver won't perform `chmod` after mount. | `0777` | No |

---

### Static PV provisioning parameters

The following table includes parameters you can use to define your static PV.

# [General](#tab/general2)

|Name | Description | Example | Mandatory | Default value|
|--- | --- | --- | --- | ---|
|volumeHandle | Specify a value the driver can use to uniquely identify the storage blob container in the cluster. | A recommended way to produce a unique value is to combine the globally unique storage account name and container name: `{account-name}_{container-name}`. <br><br> The `#` and `/` characters are reserved for internal use and can't be used in a volume handle. | Yes ||
|volumeAttributes.resourceGroup | Specify Azure resource group name. | myResourceGroup | No | If empty, driver uses the same resource group name as current cluster.|
|volumeAttributes.storageAccount | Specify an existing Azure storage account name. | storageAccountName | Yes ||
|volumeAttributes.containerName | Specify existing container name. | container | Yes ||
|volumeAttributes.protocol | Specify BlobFuse mount or NFS v3 mount. | `fuse`, `nfs` | No | `fuse`|

# [BlobFuse](#tab/blobfuse4)

|Name | Description | Example | Mandatory | Default value|
|--- | --- | --- | --- | ---|
|volumeAttributes.secretName | Secret name that stores storage account name and key (only applies for SMB).| | No ||
|volumeAttributes.secretNamespace | Specify namespace of secret to store account key. | `default` | No | PVC namespace|
|nodeStageSecretRef.name | Specify secret name that stores one of the following parameters:<br><br> `azurestorageaccountkey`<br>`azurestorageaccountsastoken`<br>`msisecret`<br>`azurestoragespnclientsecret` | |  No  |Existing Kubernetes secret name |
|nodeStageSecretRef.namespace | Specify the namespace of secret. | Kubernetes namespace | Yes ||

# [BlobFuse SPN](#tab/blobfuse-spn)

You can use managed identity or service principal name (SPN) authentication with BlobFuse. For more
information, see
[Managed Identity and Service Principal Name authentication](https://github.com/Azure/azure-storage-fuse#environment-variables).

|Name | Description | Example | Mandatory | Default value|
|--- | --- | --- | --- | ---|
|volumeAttributes.AzureStorageAuthType | Specify the authentication type. | `Key`, `SAS`, `MSI`, `SPN` | No | `Key`|
|volumeAttributes.AzureStorageIdentityClientID | Specify the Identity Client ID. |  | No ||
|volumeAttributes.AzureStorageIdentityResourceID | Specify the Identity Resource ID. |  | No ||
|volumeAttributes.MSIEndpoint | Specify the MSI endpoint. |  | No ||
|volumeAttributes.AzureStorageSPNClientID | Specify the Azure Service Principal Name (SPN) Client ID. |  | No ||
|volumeAttributes.AzureStorageSPNTenantID | Specify the Azure SPN Tenant ID. |  | No ||
|volumeAttributes.AzureStorageAADEndpoint | Specify the Microsoft Entra endpoint. |  | No ||

# [BlobFuse Key](#tab/blobfuse-key)

You can use the following parameters to enable BlobFuse to read the account key or SAS token
directly from Azure Key Vault.

|Name | Description | Example | Mandatory | Default value|
|--- | --- | --- | --- | ---|
|volumeAttributes.keyVaultURL | Specify Azure Key Vault DNS name. | {vault-name}.vault.azure.net | No ||
|volumeAttributes.keyVaultSecretName | Specify Azure Key Vault secret name. | Existing Azure Key Vault secret name. | No ||
|volumeAttributes.keyVaultSecretVersion | Azure Key Vault secret version. | Existing version | No |If empty, driver uses current version.|

# [NFS](#tab/nfs4)

|Name | Description | Example | Mandatory | Default value|
|--- | --- | --- | --- | ---|
|volumeAttributes.mountPermissions | Specify mounted folder permissions. | `0777` | No ||

# [NFS VNet](#tab/nfs-vnet)

|Name | Description | Example | Mandatory | Default value|
|--- | --- | --- | --- | ---|
|vnetResourceGroup | Specify VNet resource group hosting virtual network. | myResourceGroup | No | If empty, driver uses the `vnetResourceGroup` value specified in the Azure cloud config file.|
|vnetName | Specify the virtual network name. | aksVNet | No | If empty, driver uses the `vnetName` value specified in the Azure cloud config file.|
|subnetName | Specify the existing subnet name of the agent node. | aksSubnet | No | If empty, the driver updates all the subnets under the cluster virtual network. |

---

::: zone-end
::: zone pivot="csi-disk"

## Create Azure Disk PVs using built-in storage classes

A storage class is used to define how a unit of storage is dynamically created with a PV. For more information on Kubernetes storage classes, see [Kubernetes storage classes][kubernetes-storage-classes].

When you use the Azure Disk CSI driver on AKS, there are two more built-in `StorageClasses` that use the Azure Disk CSI storage driver. The other CSI storage classes are created with the cluster alongside the in-tree default storage classes.

* `managed-csi`: Creates managed disks using Azure Standard SSD with locally redundant storage (LRS). With Kubernetes version 1.29 for AKS clusters deployed across multiple availability zones, this storage class uses Azure Standard SSD zone-redundant storage (ZRS) to provision managed disks.

* `managed-csi-premium`: Provisions managed disks using Azure Premium LRS. Beginning with Kubernetes version 1.29, for AKS clusters spanning multiple availability zones, this storage class automatically uses Azure Premium ZRS to create managed disks.

Effective starting with Kubernetes version 1.29, when you deploy Azure Kubernetes Service (AKS)
clusters across multiple availability zones, AKS now utilizes zone-redundant storage (ZRS) to create
managed disks within built-in storage classes.

* ZRS ensures synchronous replication of your Azure managed disks across multiple Azure availability zones in your chosen region. This redundancy strategy enhances the resilience of your applications and safeguards your data against datacenter failures.

* However, it's important to note that zone-redundant storage (ZRS) comes at a higher cost compared to locally redundant storage (LRS). If cost optimization is a priority, you can create a new storage class with the LRS SKU name parameter and use it in your persistent volume claim.

Reducing the size of a PVC isn't supported due to the risk of data loss. You can edit an existing storage class using the `kubectl edit sc` command, or you can create your own custom storage class. For example, if you want to use a disk of size 4 TiB, you must create a storage class that defines `cachingmode: None` because [disk caching isn't supported for disks 4 TiB and larger][disk-host-cache-setting]. For more information about storage classes and creating your own storage class, see [Storage options for applications in AKS][storage-class-concepts].

The reclaim policy in both storage classes ensures that the underlying Azure Disks are deleted when the respective PV is deleted. The storage classes also configure the PVs to be expandable. You just need to edit the PVC with the new size.

To use these storage classes, create a [PVC](concepts-storage.md#persistent-volume-claims) and respective pod that references and uses them. A PVC is used to automatically provision storage based on a storage class. A PVC can use one of the precreated storage classes or a user-defined storage class to create an Azure-managed disk for the desired SKU and size. When you create a pod definition, the PVC is specified to request the desired storage.

> [!NOTE]
> Persistent volume claims are specified in GiB but Azure managed disks are billed based on the SKU for a specific size. These SKUs range from 32GiB for S4 or P4 disks to 32TiB for S80 or P80 disks (in preview). The throughput and IOPS performance of a Premium managed disk depends on both the SKU and the instance size of the nodes in the AKS cluster. For more information, see [Pricing and performance of managed disks][managed-disk-pricing-performance].

You can see the precreated storage classes using the [`kubectl get sc`][kubectl-get] command. The following example shows the precreated storage classes available within an AKS cluster:

```bash
kubectl get sc
```

The output of the command resembles the following example:

```output
NAME                PROVISIONER                AGE
default (default)   disk.csi.azure.com         1h
managed-csi         disk.csi.azure.com         1h
```

# [Dynamic volume](#tab/dynamic-volume-disk)

A PVC automatically provisions storage based on a storage class. In this case, a PVC can use one of the precreated storage classes to create a standard or premium Azure managed disk.

1. Create a file named `azure-pvc.yaml` and copy in the following manifest. The claim requests a disk named `azure-managed-disk` that's `5 GB` in size with `ReadWriteOnce` access. The *managed-csi* storage class is specified as the storage class.

   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
       name: azure-managed-disk
   spec:
     accessModes:
     - ReadWriteOnce
     storageClassName: managed-csi
     resources:
       requests:
         storage: 5Gi
   ```

   > [!TIP]
   > To create a disk that uses premium storage, use `storageClassName: managed-csi-premium` rather than *managed-csi*.

1. Create the persistent volume claim using the [`kubectl apply`][kubectl-apply] command and specify your *azure-pvc.yaml* file.

   ```bash
   kubectl apply -f azure-pvc.yaml
   ```

   The output of the command resembles the following example:

   ```output
   persistentvolumeclaim/azure-managed-disk created
   ```

## Apply a PVC to a pod

After you create the persistent volume claim, you must verify it has a status of `Pending`. The `Pending` status indicates it's ready to be used by a pod.

1. Verify the status of the PVC using the `kubectl describe pvc` command.

   ```bash
   kubectl describe pvc azure-managed-disk
   ```

   The output of the command resembles the following condensed example:

   ```output
   Name:            azure-managed-disk
   Namespace:       default
   StorageClass:    managed-csi
   Status:          Pending
   [...]
   ```

1. Create a file named `azure-pvc-disk.yaml` and copy in the following manifest. This manifest creates a basic NGINX pod that uses the persistent volume claim named `azure-managed-disk` to mount the Azure Disk at the path `/mnt/azure`. For Windows Server containers, specify a `mountPath` using the Windows path convention, such as *'D:'*.

   ```yaml
   kind: Pod
   apiVersion: v1
   metadata:
     name: mypod
   spec:
     containers:
       - name: mypod
         image: mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine
         resources:
           requests:
             cpu: 100m
             memory: 128Mi
           limits:
             cpu: 250m
             memory: 256Mi
         volumeMounts:
           - mountPath: "/mnt/azure"
             name: volume
             readOnly: false
     volumes:
       - name: volume
         persistentVolumeClaim:
           claimName: azure-managed-disk
   ```

1. Create the pod using the [`kubectl apply`][kubectl-apply] command.

   ```bash
   kubectl apply -f azure-pvc-disk.yaml
   ```

   The output of the command resembles the following example:

   ```output
   pod/mypod created
   ```

1. You now have a running pod with your Azure Disk mounted in the `/mnt/azure` directory. Check the pod configuration using the [`kubectl describe`][kubectl-describe] command.

   ```bash
   kubectl describe pod mypod
   ```

   The output of the command resembles the following example:

   ```output
   [...]
   Volumes:
     volume:
       Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
       ClaimName:  azure-managed-disk
       ReadOnly:   false
      default-token-smm2n:
       Type:        Secret (a volume populated by a Secret)
       SecretName:  default-token-smm2n
       Optional:    false
   [...]
    Events:
     Type    Reason                 Age   From                               Message
     ----    ------                 ----  ----                               -------
     Normal  Scheduled              2m    default-scheduler                  Successfully assigned mypod to aks-nodepool1-79590246-0
     Normal  SuccessfulMountVolume  2m    kubelet, aks-nodepool1-79590246-0  MountVolume.SetUp succeeded for volume "default-token-smm2n"
     Normal  SuccessfulMountVolume  1m    kubelet, aks-nodepool1-79590246-0  MountVolume.SetUp succeeded for volume "pvc-faf0f176-8b8d-11e8-923b-deb28c58d242"
   [...]
   ```

# [Static volume](#tab/static-volume-disk)

When you create an Azure disk for use with AKS, you can create the disk resource in the **node** resource group. This approach allows the AKS cluster to access and manage the disk resource. If you instead create the disk in a separate resource group, you must grant the Azure Kubernetes Service (AKS) managed identity for your cluster the `Contributor` role to the disk's resource group.

1. Identify the resource group name using the [`az aks show`][az-aks-show] command and add the `--query nodeResourceGroup` parameter.

   ```azurecli-interactive
   az aks show --resource-group myResourceGroup --name myAKSCluster --query nodeResourceGroup -o tsv
   ```

   The output of the command resembles the following example:

   ```output
   MC_myResourceGroup_myAKSCluster_eastus
   ```

1. Create a disk using the [`az disk create`][az-disk-create] command. Specify the node resource group name and a name for the disk resource, such as *myAKSDisk*. The following example creates a *20 GiB* disk, and outputs the ID of the disk after creation. If you need to create a disk for use with Windows Server containers, add the `--os-type windows` parameter to correctly format the disk.

   ```azurecli-interactive
   az disk create \
     --resource-group MC_myResourceGroup_myAKSCluster_eastus \
     --name myAKSDisk \
     --size-gb 20 \
     --query id --output tsv
   ```

   > [!NOTE]
   > Azure Disks are billed base on the SKU for a specific size. These SKUs range from 32GiB for S4 or P4 disks to 32TiB for S80 or P80 disks (in preview). The throughput and IOPS performance of a Premium managed disk depends on both the SKU and the instance size of the nodes in the AKS cluster. See [Pricing and Performance of Managed Disks][managed-disk-pricing-performance].

   The disk resource ID is displayed once the command completes successfully, as shown in the following example output. You use the disk ID to mount the disk in the next section.

   ```output
   /subscriptions/<subscriptionID>/resourceGroups/MC_myAKSCluster_myAKSCluster_eastus/providers/Microsoft.Compute/disks/myAKSDisk
   ```

### Mount the disk as a volume

> [!NOTE]
> An Azure disk can only be mounted with *Access mode* type `ReadWriteOnce`, which makes it available to one node in AKS. This access mode still allows multiple pods to access the volume when the pods run on the same node. For more information, see [Kubernetes PersistentVolume access modes][access-modes].

1. Create a *pv-azuredisk.yaml* file with a PV. Update `volumeHandle` with disk resource ID from the previous step. For Windows Server containers, specify *NTFS* for the parameter `fsType`.

   ```yaml
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     annotations:
       pv.kubernetes.io/provisioned-by: disk.csi.azure.com
     name: pv-azuredisk
   spec:
     capacity:
       storage: 20Gi
     accessModes:
       - ReadWriteOnce
     persistentVolumeReclaimPolicy: Retain
     storageClassName: managed-csi
     csi:
       driver: disk.csi.azure.com
       volumeHandle: /subscriptions/<subscriptionID>/resourceGroups/MC_myAKSCluster_myAKSCluster_eastus/providers/Microsoft.Compute/disks/myAKSDisk
       volumeAttributes:
         fsType: ext4
   ```

If the disk for the `volumeHandle` was created in a separate resource group, you need to grant the AKS cluster's managed identity the `Contributor` role to the disk's resource group.

1. Create a *pvc-azuredisk.yaml* file with a PVC that uses the PV.

   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: pvc-azuredisk
   spec:
     accessModes:
       - ReadWriteOnce
     resources:
       requests:
         storage: 20Gi
     volumeName: pv-azuredisk
     storageClassName: managed-csi
   ```

1. Create the PV and PVC using the [`kubectl apply`][kubectl-apply] command and reference the two YAML files you created:

   ```bash
   kubectl apply -f pv-azuredisk.yaml
   kubectl apply -f pvc-azuredisk.yaml
   ```

1. Verify your PVC is created and bound to the PV using the `kubectl get pvc` command:

   ```bash
   kubectl get pvc pvc-azuredisk
   ```

   The output of the command resembles the following example:

   ```output
   NAME            STATUS   VOLUME         CAPACITY    ACCESS MODES   STORAGECLASS   AGE
   pvc-azuredisk   Bound    pv-azuredisk   20Gi        RWO                           5s
   ```

1. Create an *azure-disk-pod.yaml* file to reference your *PersistentVolumeClaim*. For Windows Server containers, specify a `mountPath` using the Windows path convention, such as *"D:"*.

   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: mypod
   spec:
     nodeSelector:
       kubernetes.io/os: linux
     containers:
     - image: mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine
       name: mypod
       resources:
         requests:
           cpu: 100m
           memory: 128Mi
         limits:
           cpu: 250m
           memory: 256Mi
       volumeMounts:
         - name: azure
           mountPath: /mnt/azure
     volumes:
       - name: azure
         persistentVolumeClaim:
           claimName: pvc-azuredisk
   ```

1. Apply the configuration and mount the volume using the [`kubectl apply`][kubectl-apply] command.

   ```bash
   kubectl apply -f azure-disk-pod.yaml
   ```

---

## Dynamic storage class parameters for PVCs

The following table includes parameters you can use to define a custom storage class for your PVCs.

# [General](#tab/general-disk)

|Name | Meaning | Available Value | Mandatory | Default value |
|--- | --- | --- | :---: | --- |
|skuName | Azure Disks storage account type (alias: `storageAccountType`)| `Standard_LRS`, `Premium_LRS`, `StandardSSD_LRS`, `PremiumV2_LRS`, `UltraSSD_LRS`, `Premium_ZRS`, `StandardSSD_ZRS` | No | `StandardSSD_LRS`|
|fsType | File System Type | `ext4`, `ext3`, `ext2`, `xfs`, `btrfs` for Linux, `ntfs` for Windows | No | `ext4` for Linux, `ntfs` for Windows|
|cachingMode | [Azure Data Disk Host Cache Setting][disk-host-cache-setting](PremiumV2_LRS and UltraSSD_LRS only support `None` caching mode) | `None`, `ReadOnly`, `ReadWrite` | No | `ReadOnly`|
|resourceGroup | Specify the resource group for the Azure Disks | Existing resource group name | No | If empty, driver uses the same resource group name as current AKS cluster|
|DiskIOPSReadWrite | [UltraSSD disk][ultra-ssd-disks] or [Premium SSD v2][premiumv2_lrs_disks] IOPS Capability (minimum: 2 IOPS/GiB) | 100~160000 | No | `500`|
|DiskMBpsReadWrite | [UltraSSD disk][ultra-ssd-disks] or [Premium SSD v2][premiumv2_lrs_disks] Throughput Capability(minimum: 0.032/GiB) | 1~2000 | No | `100`|
|LogicalSectorSize | Logical sector size in bytes for ultra disk. Supported values are 512 ad 4096. 4096 is the default. | `512`, `4096` | No | `4096`|
|tags | Azure Disk [tags][azure-tags] | Tag format: `key1=val1,key2=val2` | No | ""|
|diskEncryptionSetID | ResourceId of the disk encryption set to use for [enabling encryption at rest][disk-encryption] | format: `/subscriptions/{subs-id}/resourceGroups/{rg-name}/providers/Microsoft.Compute/diskEncryptionSets/{diskEncryptionSet-name}` | No | ""|
|diskEncryptionType | Encryption type of the disk encryption set. | `EncryptionAtRestWithCustomerKey` (by default), `EncryptionAtRestWithPlatformAndCustomerKeys` | No | ""|
|writeAcceleratorEnabled | [Write Accelerator on Azure Disks][azure-disk-write-accelerator] | `true`, `false` | No | ""|
|networkAccessPolicy | NetworkAccessPolicy property to prevent generation of the SAS URI for a disk or a snapshot | `AllowAll`, `DenyAll`, `AllowPrivate` | No | `AllowAll`|
|diskAccessID | Azure Resource ID of the DiskAccess resource to use private endpoints on disks | | No | ``|
|enableBursting | [Enable on-demand bursting][on-demand-bursting] beyond the provisioned performance target of the disk. On-demand bursting should only be applied to Premium disk and when the disk size > 512 GB. Ultra and shared disk isn't supported. Bursting is disabled by default. | `true`, `false` | No | `false`|
|userAgent | The user agent is used for [customer usage attribution][customer-usage-attribution] | | No | The generated user agent is formatted as `driverName/driverVersion compiler/version (OS-ARCH)`|
|subscriptionID | Specify Azure subscription ID where the Azure Disks is created. | Azure subscription ID | No | If not empty, `resourceGroup` must be provided.|

# [General v2](#tab/general-disk-v2)

The following parameters are only for **v2**.

|Name | Meaning | Available Value | Mandatory | Default value |
|--- | --- | --- | :---: | --- |
| maxShares | The total number of shared disk mounts allowed for the disk. Setting the value to 2 or more enables attachment replicas. | Supported values depend on the disk size. See [Share an Azure managed disk][share-azure-managed-disk] for supported values. | No | 1 |
| maxMountReplicaCount | The number of replicas attachments to maintain. | This value must be in the range `[0..(maxShares - 1)]` | No | If `accessMode` is `ReadWriteMany`, the default is `0`. Otherwise, the default is `maxShares - 1` |

---

## Static provisioning parameters for a PV

The following table includes parameters you can use to define a PV.

|Name | Meaning | Available Value | Mandatory | Default value|
|--- | --- | --- | --- | ---|
|volumeHandle| Azure disk URI | `/subscriptions/{sub-id}/resourcegroups/{group-name}/providers/microsoft.compute/disks/{disk-id}` | Yes | N/A|
|volumeAttributes.fsType | File system type | `ext4`, `ext3`, `ext2`, `xfs`, `btrfs` for Linux, `ntfs` for Windows | No | `ext4` for Linux, `ntfs` for Windows |
|volumeAttributes.partition | Partition number of the existing disk (only supported on Linux) | `1`, `2`, `3` | No | Empty (no partition) </br>- Make sure partition format is like `-part1` |
|volumeAttributes.cachingMode | [Disk host cache setting][disk-host-cache-setting] | `None`, `ReadOnly`, `ReadWrite` | No  | `ReadOnly`|

## Create an Azure Disk custom storage class

The default storage classes are suitable for most common scenarios. For some cases, you might want
to have your own storage class customized with your own parameters. For example, you might want to
change the `volumeBindingMode` class.

You can use a `volumeBindingMode: Immediate` class that guarantees it occurs immediately once the
persistent volume claim (PVC) is created. When your node pools are topology constrained, for example
when using availability zones, PVs would be bound or provisioned without knowledge of the pod's
scheduling requirements.

To address this scenario, you can use `volumeBindingMode: WaitForFirstConsumer`, which delays the binding and provisioning of a PV until a pod that uses the PVC is created. This approach ensures that the persistent volume (PV) is provisioned in the same availability zone or topology as required per the pod's scheduling constraints. The default storage classes use `volumeBindingMode: WaitForFirstConsumer` class.

1. Create a file named `sc-azuredisk-csi-waitforfirstconsumer.yaml`, and then paste the following
manifest. The storage class is the same as our `managed-csi` storage class, but with a different
`volumeBindingMode` class. For example:

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

1. Create the storage class by running the [kubectl apply][kubectl-apply] command and specify your
`sc-azuredisk-csi-waitforfirstconsumer.yaml` file:

   ```bash
   kubectl apply -f sc-azuredisk-csi-waitforfirstconsumer.yaml
   ```

   The output of the command resembles the following example:

   ```output
   storageclass.storage.k8s.io/azuredisk-csi-waitforfirstconsumer created
   ```

## Learn about volume snapshots

The Azure Disk CSI driver supports [volume snapshots](https://kubernetes-csi.github.io/docs/snapshot-restore-feature.html), enabling you to capture the state of persistent volumes at specific points in time for backup and restore operations. Volume snapshots let you create point-in-time copies of your persistent data without interrupting running applications. You can use these snapshots to create new volumes or restore existing ones to a previous state.

You can create two types of snapshots:

* **Full snapshots**: Capture the complete state of the disk.

* **Incremental snapshots**: Capture only the changes since the last snapshot, offering better storage efficiency and cost savings. [Incremental snapshots](/azure/virtual-machines/disks-incremental-snapshots) are the default behavior when the `incremental` parameter is set to `true` in your VolumeSnapshotClass.

The following table provides details for these parameters.

| Name | Meaning | Available Value | Mandatory | Default value |
|--|--|--|--|--|
|resourceGroup | Resource group for storing snapshot shots | EXISTING RESOURCE GROUP | No | If not specified, snapshots are stored in the same resource group as source Azure Disks |
|incremental | Take [full or incremental snapshot](/azure/virtual-machines/windows/incremental-snapshots) | `true`, `false` | No | `true` |
|tags | Azure Disks [tags](/azure/azure-resource-manager/management/tag-resources) | Tag format: 'key1=val1,key2=val2' | No | "" |
|userAgent | User agent used for [customer usage attribution](/azure/marketplace/azure-partner-customer-usage-attribution) | | No  | Generated Useragent formatted `driverName/driverVersion compiler/version (OS-ARCH)` |
|subscriptionID | Specify Azure subscription ID where Azure Disks are created | Azure subscription ID | No | If not empty, `resourceGroup` must be provided, `incremental` must set as `false` |

Volume snapshots support the following scenarios:

* **Backup and restore**: Create point-in-time backups of stateful application data and restore when
  needed.
* **Data cloning**: Clone existing volumes to create new persistent volumes with the same data.
* **Disaster recovery**: Quickly recover from data loss or corruption.

### Create a volume snapshot

> [!NOTE]
> Before proceeding, ensure that the application isn't writing data to the source disk.

1. For an example of this capability, create a [volume snapshot class](https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/deploy/example/snapshot/storageclass-azuredisk-snapshot.yaml) with the [kubectl apply][kubectl-apply] command:

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/example/snapshot/storageclass-azuredisk-snapshot.yaml
   ```

   The output of the command resembles the following example:

   ```output
   volumesnapshotclass.snapshot.storage.k8s.io/csi-azuredisk-vsc created
   ```

1. Create a [volume snapshot](https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/deploy/example/snapshot/azuredisk-volume-snapshot.yaml) from the PVC that was created earlier in this article.

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/example/snapshot/azuredisk-volume-snapshot.yaml
   ```

   The output of the command resembles the following example:

   ```output
   volumesnapshot.snapshot.storage.k8s.io/azuredisk-volume-snapshot created
   ```

1. To verify that the snapshot was created correctly, run the following command:

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

You can create a new PVC based on a volume snapshot.

1. Use the snapshot created in the previous step, and create a [new PVC](https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/deploy/example/snapshot/pvc-azuredisk-snapshot-restored.yaml) and a [new pod](https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/deploy/example/snapshot/nginx-pod-restored-snapshot.yaml) to consume it:

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/example/snapshot/pvc-azuredisk-snapshot-restored.yaml
   kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/example/snapshot/nginx-pod-restored-snapshot.yaml
   ```

   The output of the command resembles the following example:

   ```output
   persistentvolumeclaim/pvc-azuredisk-snapshot-restored created
   pod/nginx-restored created
   ```

1. To make sure it's the same PVC created before, check the contents by running the following command:

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

1. Create a [cloned volume](https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/deploy/example/cloning/nginx-pod-restored-cloning.yaml)
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

1. You can verify the content of the cloned volume by running the following command and confirming the file `test.txt` is created:

   ```bash
   kubectl exec nginx-restored-cloning -- ls /mnt/azuredisk
   ```

   The output of the command resembles the following example:

   ```output
   lost+found
   outfile
   test.txt
   ```

## Resize an Azure Disk PV without downtime

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

1. Expand the PVC by increasing the `spec.resources.requests.storage` field running the following command:

   ```bash
   kubectl patch pvc pvc-azuredisk --type merge --patch '{"spec": {"resources": {"requests": {"storage": "15Gi"}}}}'
   ```

   > [!NOTE]
   > Shrinking PVs is currently not supported. Trying to patch an existing PVC with a smaller size than the current one leads to the following error message:
   >
   > `The persistentVolumeClaim "pvc-azuredisk" is invalid: spec.resources.requests.storage: Forbidden: field can not be less than previous value.`

   The output of the command resembles the following example:

   ```output
   persistentvolumeclaim/pvc-azuredisk patched
   ```

1. Run the following command to confirm the volume size increased:

   ```bash
   kubectl get pv
   ```

   The output of the command resembles the following example:

   ```output
   NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                     STORAGECLASS   REASON   AGE
   pvc-391ea1a6-0191-4022-b915-c8dc4216174a   15Gi       RWO            Delete           Bound    default/pvc-azuredisk     managed-csi             2d2h
   (...)
   ```

1. And after a few minutes, run the following commands to confirm the size of the PVC:

   ```bash
   kubectl get pvc pvc-azuredisk
   ```

   The output of the command resembles the following example:

   ```output
   NAME            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
   pvc-azuredisk   Bound    pvc-391ea1a6-0191-4022-b915-c8dc4216174a   15Gi       RWO            managed-csi    2d2h
   ```

1. Run the following command to confirm the size of the disk inside the pod:

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

The Azure Disk CSI driver supports Windows nodes and containers. If you want to use Windows containers, follow the [Windows containers quickstart][aks-quickstart-cli] to add a Windows node pool.

1. After you have a Windows node pool, you can now use the built-in storage classes like `managed-csi`. You can deploy an example [Windows-based stateful set](https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/deploy/example/windows/statefulset.yaml) that saves timestamps into the file `data.txt` by running the following
[kubectl apply][kubectl-apply] command:

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/example/windows/statefulset.yaml
   ```

   The output of the command resembles the following example:

   ```output
   statefulset.apps/busybox-azuredisk created
   ```

1. To validate the content of the volume, run the following command:

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

## Clean up resources

When you're done with the resources created in this article, you can remove them using the
`kubectl delete` command.

```bash
# Remove the pod
kubectl delete -f azure-pvc-disk.yaml

# Remove the persistent volume claim
kubectl delete -f azure-pvc.yaml
```

::: zone-end
::: zone pivot="csi-files"

## Provision Azure Files PVs

Azure Files supports Azure Premium file shares. The minimum file share capacity is 100 GiB. We recommend using Azure Premium file shares instead of Standard file shares because Premium file shares offer higher performance, low-latency disk support for I/O-intensive workloads. With Azure Files shares, there's no limit as to how many can be mounted on a node. For more information on Kubernetes volumes, see [Storage options for applications in AKS][concepts-storage].

When you use storage CSI drivers on AKS, there are two more built-in `StorageClasses` that uses the Azure Files CSI storage drivers. The other CSI storage classes are created with the cluster alongside the in-tree default storage classes.

* `azurefile-csi`: Uses Azure Standard Storage to create an Azure file share.

* `azurefile-csi-premium`: Uses Azure Premium Storage to create an Azure file share.

The reclaim policy on both storage classes ensures that the underlying Azure files share is deleted when the respective PV is deleted. Since the storage classes also configure the file shares to be expandable, you just need to edit the [PVC][persistent-volume-claim-overview] with the new size.

> [!NOTE]
> To have the best experience with Azure Files, follow these best practices. The location to configure mount options (`mountOptions`) depends on whether you're provisioning dynamic or static persistent volumes.
>
  > * If you're dynamically provisioning a volume with a storage class, specify the mount options on the storage class object (kind: `StorageClass`).
  > * If you're statically provisioning a volume, specify the mount options on the  PersistentVolume object (kind: `PersistentVolume`).
  > * If you're mounting the file share as an inline volume, specify the mount options on the Pod object (kind: `Pod`).
>
> We recommend FIO when running benchmarking tests. For more information, see [benchmarking tools and tests](/azure/storage/files/nfs-performance#benchmarking-tools-and-tests).

# [Dynamic volume](#tab/dynamic-volume-files)

A storage class is used to define how an Azure file share is created. A storage account is automatically created in the [node resource group][node-resource-group] for use with the storage class to hold the Azure files share. Choose one of the following [Azure storage redundancy SKUs][storage-skus] for *skuName*:

* **Standard_LRS**: Standard locally redundant storage
* **Standard_GRS**: Standard geo-redundant storage
* **Standard_ZRS**: Standard zone-redundant storage
* **Standard_RAGRS**: Standard read-access geo-redundant storage
* **Standard_RAGZRS**: Standard read-access geo-zone-redundant storage
* **Premium_LRS**: Premium locally redundant storage
* **Premium_ZRS**: Premium zone-redundant storage

For more information on Kubernetes storage classes for Azure Files, see [Kubernetes Storage Classes][kubernetes-storage-classes-azure-files].

1. Create a file named `azure-file-sc.yaml` and copy in the following example manifest. For more information on `mountOptions`, see the [Mount options][mount-options] section.

   ```yaml
   kind: StorageClass
   apiVersion: storage.k8s.io/v1
   metadata:
     name: my-azurefile
   provisioner: file.csi.azure.com # replace with "kubernetes.io/azure-file" if aks version is less than 1.21
   allowVolumeExpansion: true
   mountOptions:
    - dir_mode=0777
    - file_mode=0777
    - uid=0
    - gid=0
    - mfsymlinks
    - cache=strict
    - actimeo=30
    - nobrl  # disable sending byte range lock requests to the server and for applications which have challenges with posix locks
   parameters:
     skuName: Premium_LRS
   ```

1. Create the storage class using the [`kubectl apply`][kubectl-apply] command.

   ```bash
   kubectl apply -f azure-file-sc.yaml
   ```

### Create a PVC

A PVC uses the storage class object to dynamically provision an Azure file share. You can use the following YAML to create a PVC that's *100 GB* in size with *ReadWriteMany* access. For more information on access modes, see [Kubernetes persistent volume][access-modes].

1. Create a file named `azure-file-pvc.yaml` and copy in the following YAML. Make sure the `storageClassName` matches the storage class you created in the previous step.

   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: my-azurefile
   spec:
     accessModes:
       - ReadWriteMany
     storageClassName: my-azurefile
     resources:
       requests:
         storage: 100Gi
   ```

   > [!NOTE]
   > If using the `Premium_LRS` SKU for your storage class, the minimum value for `storage` must be `100Gi`.

1. Create the PVC using the [`kubectl apply`][kubectl-apply] command.

   ```bash
   kubectl apply -f azure-file-pvc.yaml
   ```

   Once completed, the file share is created. A Kubernetes secret is also created that includes connection information and credentials. You can use the [`kubectl get`][kubectl-get] command to view the status of the PVC:

   ```bash
   kubectl get pvc my-azurefile
   ```

   The output of the command resembles the following example:

   ```output
   NAME           STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
   my-azurefile   Bound     pvc-8436e62e-a0d9-11e5-8521-5a8664dc0477   100Gi       RWX           my-azurefile      5m
   ```

### Mount the PVC

The following YAML creates a pod that uses the PVC *my-azurefile* to mount the Azure Files file share at the */mnt/azure* path. For Windows Server containers, specify a `mountPath` using the Windows path convention, such as *"D:"*.

1. Create a file named `azure-pvc-files.yaml`, and copy in the following YAML. Make sure the `claimName` matches the PVC you created in the previous step.

   ```yaml
   kind: Pod
   apiVersion: v1
   metadata:
     name: mypod
   spec:
     containers:
       - name: mypod
         image: mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine
         resources:
           requests:
             cpu: 100m
             memory: 128Mi
           limits:
             cpu: 250m
             memory: 256Mi
         volumeMounts:
           - mountPath: /mnt/azure
             name: volume
             readOnly: false
     volumes:
      - name: volume
        persistentVolumeClaim:
          claimName: my-azurefile
   ```

1. Create the pod using the [`kubectl apply`][kubectl-apply] command.

   ```bash
   kubectl apply -f azure-pvc-files.yaml
   ```

   You now have a running pod with your Azure Files file share mounted in the */mnt/azure* directory. This configuration can be seen when inspecting your pod using the [`kubectl describe`][kubectl-describe] command. The following condensed example output shows the volume mounted in the container.

   ```output
   Containers:
     mypod:
       Container ID:   docker://053bc9c0df72232d755aa040bfba8b533fa696b123876108dec400e364d2523e
       Image:          mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine
       Image ID:       docker-pullable://nginx@sha256:d85914d547a6c92faa39ce7058bd7529baacab7e0cd4255442b04577c4d1f424
       State:          Running
         Started:      Fri, 01 Mar 2019 23:56:16 +0000
       Ready:          True
       Mounts:
         /mnt/azure from volume (rw)
         /var/run/secrets/kubernetes.io/serviceaccount from default-token-8rv4z (ro)
   [...]
   Volumes:
     volume:
       Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
       ClaimName:  my-azurefile
       ReadOnly:   false
   [...]
   ```

### Mount options

For Kubernetes versions 1.13.0 and later, the default values for `fileMode` and `dirMode` are `0777`. When dynamically provisioning PVs using a storage class, you can define mount options directly in the storage class manifest. For details, see [Mount options](https://kubernetes.io/docs/concepts/storage/storage-classes/#mount-options). The following example demonstrates setting these permissions to `0777`:

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: my-azurefile
provisioner: file.csi.azure.com # replace with "kubernetes.io/azure-file" if aks version is less than 1.21
allowVolumeExpansion: true
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=0
  - gid=0
  - mfsymlinks
  - cache=strict
  - actimeo=30
  - nobrl  # disable sending byte range lock requests to the server and for applications which have challenges with posix locks
parameters:
  skuName: Premium_LRS
```

# [Static volume](#tab/static-volume-files)

This section provides guidance for cluster administrators who want to create one or more PVs that include details of an existing Azure Files share to use with a workload.

### Create an Azure Files share

Before you can use an Azure Files file share as a Kubernetes volume, you must create an Azure Storage account and the file share.

1. Get the resource group name using the [`az aks show`][az-aks-show] command with the `--query nodeResourceGroup` parameter.

   ```azurecli-interactive
   az aks show --resource-group myResourceGroup --name myAKSCluster --query nodeResourceGroup -o tsv
   ```

   The output of the command resembles the following example:

   ```azurecli-interactive
   MC_myResourceGroup_myAKSCluster_eastus
   ```

1. Create a storage account using the [`az storage account create`][az-storage-account-create] command with the `--sku` parameter. The following command creates a storage account using the `Standard_LRS` SKU. Make sure to replace the following placeholders:

   * `myAKSStorageAccount` with the name of the storage account
   * `nodeResourceGroupName` with the name of the resource group that the AKS cluster nodes are hosted in
   * `location` with the name of the region to create the resource in. It should be the same region as the AKS cluster nodes.

   ```azurecli-interactive
   az storage account create -n myAKSStorageAccount -g nodeResourceGroupName -l location --sku Standard_LRS
   ```

1. Export the connection string as an environment variable using the following command, which you use to create the file share.

   ```azurecli-interactive
   export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n storageAccountName -g resourceGroupName -o tsv)
   ```

   Connection strings must be protected using key rotation or storage in an Azure Key Vault. For more information about connection strings, see [Configure Azure Storage connection strings](/azure/storage/common/storage-configure-connection-string) and [Manage storage account access keys](/azure/storage/common/storage-account-keys-manage).

   For production environments, Microsoft recommends using Microsoft Entra ID authentication. For more information, see [Authorize access to data in Azure Storage](/azure/storage/blobs/authorize-access-azure-active-directory).

1. Create the file share using the [`az storage share create`][az-storage-share-create] command. Make sure to replace `shareName` with your share name.

   ```azurecli-interactive
   az storage share create -n shareName --connection-string $AZURE_STORAGE_CONNECTION_STRING
   ```

1. Export the storage account key as an environment variable using the following command.

   ```azurecli-interactive
   STORAGE_KEY=$(az storage account keys list --resource-group nodeResourceGroupName --account-name myAKSStorageAccount --query "[0].value" -o tsv)
   ```

1. Echo the storage account name and key using the following command. Copy this information, as you need these values when creating the Kubernetes volume.

   ```azurecli-interactive
   echo Storage account key: $STORAGE_KEY
   ```

### Create a Kubernetes secret

Kubernetes needs credentials to access the file share created in the previous step. These credentials are stored in a [Kubernetes secret][kubernetes-secret], which is referenced when you create a Kubernetes pod.

1. Create the secret using the `kubectl create secret` command. The following example creates a secret named `azure-secret` and populates the **azurestorageaccountname** and **azurestorageaccountkey** parameters from the previous step. To use an existing Azure storage account, provide the account name and key.

   ```bash
   kubectl create secret generic azure-secret --from-literal=azurestorageaccountname=myAKSStorageAccount --from-literal=azurestorageaccountkey=$STORAGE_KEY
   ```

### Mount a file share as a PV

1. Create a new file named `azurefiles-pv.yaml` and copy in the following contents. Under `csi`, update `resourceGroup`, `volumeHandle`, and `shareName`. For mount options, the default value for `fileMode` and `dirMode` is `0777`.

   ```yaml
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     annotations:
       pv.kubernetes.io/provisioned-by: file.csi.azure.com
     name: azurefile
   spec:
     capacity:
       storage: 5Gi
     accessModes:
       - ReadWriteMany
     persistentVolumeReclaimPolicy: Retain
     storageClassName: azurefile-csi
     csi:
       driver: file.csi.azure.com
       volumeHandle: "{resource-group-name}#{account-name}#{file-share-name}"  # make sure this volumeid is unique for every identical share in the cluster
       volumeAttributes:
         shareName: aksshare
       nodeStageSecretRef:
         name: azure-secret
         namespace: default
     mountOptions:
       - dir_mode=0777
       - file_mode=0777
       - uid=0
       - gid=0
       - mfsymlinks
       - cache=strict
       - nosharesock
       - nobrl  # disable sending byte range lock requests to the server and for applications which have challenges with posix locks
   ```

1. Create the PV using the [`kubectl create`][kubectl-create] command.

   ```bash
   kubectl create -f azurefiles-pv.yaml
   ```

1. Create a new file named *azurefiles-mount-options-pvc.yaml* and copy the following contents.

   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: azurefile
   spec:
     accessModes:
       - ReadWriteMany
     storageClassName: azurefile-csi
     volumeName: azurefile
     resources:
       requests:
         storage: 5Gi
   ```

1. Create the PVC using the [`kubectl apply`][kubectl-apply] command.

   ```bash
   kubectl apply -f azurefiles-mount-options-pvc.yaml
   ```

1. Verify your PVC is created and bound to the PV using the [`kubectl get`][kubectl-get] command.

   ```bash
   kubectl get pvc azurefile
   ```

   The output from the command resembles the following example:

   ```console
   NAME        STATUS   VOLUME      CAPACITY   ACCESS MODES   STORAGECLASS   AGE
   azurefile   Bound    azurefile   5Gi        RWX            azurefile      5s
   ```

1. Update your container spec to reference your PVC and your pod in the YAML file. For example:

   ```yaml
   ...
     volumes:
     - name: azure
       persistentVolumeClaim:
         claimName: azurefile
   ```

1. A pod spec can't be updated in place, so delete the pod using the [`kubectl delete`][kubectl-delete] command and recreate it using the [`kubectl apply`][kubectl-apply] command.

   ```bash
   kubectl delete pod mypod

   kubectl apply -f azure-files-pod.yaml
   ```

### Mount the file share as an inline volume

> [!NOTE]
> To avoid performance issue, we recommend you use a PV instead of an inline volume when numerous pods are accessing the same file share. Inline volume can only access secrets in the same namespace as the pod. To specify a different secret namespace, use a [persistent volume][persistent-volume].

To mount the Azure Files file share into your pod, you configure the volume in the container spec.

1. Create a new file named `azure-files-pod.yaml` and copy in the following contents. If you changed the name of the file share or secret name, update the `shareName` and `secretName`. You can also update the `mountPath`, which is the path where the Files share is mounted in the pod. For Windows Server containers, specify a `mountPath` using the Windows path convention, such as *D:/*.

   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: mypod
   spec:
     nodeSelector:
       kubernetes.io/os: linux
     containers:
       - image: 'mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine'
         name: mypod
         resources:
           requests:
             cpu: 100m
             memory: 128Mi
           limits:
             cpu: 250m
             memory: 256Mi
         volumeMounts:
           - name: azure
             mountPath: /mnt/azure
             readOnly: false
     volumes:
       - name: azure
         csi:
           driver: file.csi.azure.com
           volumeAttributes:
             secretName: azure-secret  # required
             shareName: aksshare  # required
             mountOptions: 'dir_mode=0777,file_mode=0777,cache=strict,actimeo=30,nosharesock,nobrl'  # optional
   ```

1. Create the pod using the [`kubectl apply`][kubectl-apply] command.

   ```bash
   kubectl apply -f azure-files-pod.yaml
   ```

   You now have a running pod with an Azure Files file share mounted at */mnt/azure*. You can verify the share is mounted successfully using the [`kubectl describe`][kubectl-describe] command.

   ```bash
   kubectl describe pod mypod
   ```

---

## Storage class parameters for dynamic volumes

# [General](#tab/general-files)

The following table includes parameters you can use to define a custom storage class for your PVC.

|Name | Meaning | Available Value | Mandatory | Default value |
|--|--|--|--|--|
|accountAccessTier | [Access tier for storage account][access-tiers-overview] | Standard account can choose `Hot` or `Cool`, and Premium account can only choose `Premium`. | No | Empty. Use default setting for different storage account types. |
|accountQuota | Limits the quota for an account. You can specify a maximum quota in GB (102,400 GB by default). If the account exceeds the specified quota, the driver skips selecting the account. | |No |`102400` |
|allowBlobPublicAccess | Allow or disallow public access to all blobs or containers for storage account created by driver. | `true` or `false` | No | `false` |
|disableDeleteRetentionPolicy | Specify whether disable DeleteRetentionPolicy for storage account created by driver. | `true` or `false` | No | `false` |
|folderName | Specify folder name in Azure file share. | Existing folder name in Azure file share. | No | If folder name doesn't exist in file share, the mount fails. |
|getLatestAccount |Determines whether to get the latest account key based on the creation time. This driver gets the first key by default. |`true` or `false` |No |`false` |
|location | Specify the Azure region of the Azure storage account.| For example, `eastus`. | No | If empty, driver uses the same location name as current AKS cluster.|
|matchTags | Match tags when driver tries to find a suitable storage account. | `true` or `false` | No | `false` |
|networkEndpointType <sup>1</sup>| Specify network endpoint type for the storage account created by driver. If `privateEndpoint` is specified, a private endpoint is created for the storage account. For other cases, a service endpoint is created by default. | "",`privateEndpoint`| No | "" |
|protocol | Specify file share protocol. | `smb`, `nfs` | No | `smb` |
|requireInfraEncryption | Specify whether or not the service applies a secondary layer of encryption with platform managed keys for data at rest for storage account created by driver. | `true` or `false` | No | `false` |
|resourceGroup | Specify the resource group for the Azure Disks.| Existing resource group name | No | If empty, driver uses the same resource group name as current AKS cluster.|
|selectRandomMatchingAccount | Determines whether to randomly select a matching account. By default, the driver always selects the first matching account in alphabetical order (Note: This driver uses account search cache, which results in uneven distribution of file creation across multiple accounts). | `true` or `false` |No | `false` |
|server | Specify Azure storage account server address. | Existing server address, for example `accountname.privatelink.file.core.windows.net`. | No | If empty, driver uses default `accountname.file.core.windows.net` or other sovereign cloud account address. |
|shareAccessTier | [Access tier for file share][storage-tiers] | General purpose v2 account can choose between `TransactionOptimized` (default), `Hot`, and `Cool`. Premium storage account type for file shares only. | No | Empty. Use default setting for different storage account types.|
|shareName | Specify Azure file share name. | Existing or new Azure file share name. | No | If empty, driver generates an Azure file share name. |
|shareNamePrefix | Specify Azure file share name prefix created by driver. | Share name can only contain lowercase letters, numbers, hyphens, and length should be fewer than 21 characters. | No | |
|skuName | Azure Files storage account type (alias: `storageAccountType`)| `Standard_LRS`, `Standard_ZRS`, `Standard_GRS`, `Standard_RAGRS`, `Standard_RAGZRS`,`Premium_LRS`, `Premium_ZRS`, `StandardV2_LRS`, `StandardV2_ZRS`, `StandardV2_GRS`, `StandardV2_GZRS`, `PremiumV2_LRS`, `PremiumV2_ZRS` | No | `Standard_LRS`<br> Minimum file share size for Premium account type is 100 GB.<br> ZRS account type is supported in limited regions.<br> NFS file share only supports Premium account type. <br> Standard V2 SKU names are for [Azure Files provisioned v2 model](/azure/storage/files/understanding-billing#provisioned-v2-model). |
|storageAccount | Specify an Azure storage account name.| storageAccountName | - No | When a specific storage account name isn't provided, the driver looks for a suitable storage account that matches the account settings within the same resource group. If it fails to find a matching storage account, it creates a new one. However, if a storage account name is specified, the storage account must already exist. |
|storageEndpointSuffix | Specify Azure storage endpoint suffix. | `core.windows.net`, `core.chinacloudapi.cn`, etc. | No | If empty, driver uses default storage endpoint suffix according to cloud environment. For example, `core.windows.net`. |
|tags | [Tags][tag-resources] are created in new storage account. | Tag format: 'foo=aaa,bar=bbb' | No | "" |

<sup>1</sup> If the storage account is created by the driver, then you only need to specify
`networkEndpointType: privateEndpoint` parameter in storage class. The CSI driver creates the
private endpoint and private DNS zone (named `privatelink.file.core.windows.net`) together with the
account. If you bring your own storage account, then you need to
[create the private endpoint][storage-account-private-endpoint] for the storage account. If you're
using Azure Files storage in a network isolated cluster, you must create a custom storage class with
"networkEndpointType: privateEndpoint". You can follow this sample for reference:

```bash
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi
provisioner: file.csi.azure.com
allowVolumeExpansion: true
parameters:
  skuName: Premium_LRS  # available values: Premium_LRS, Premium_ZRS, Standard_LRS, Standard_GRS, Standard_ZRS, Standard_RAGRS, Standard_RAGZRS
  networkEndpointType: privateEndpoint
reclaimPolicy: Delete
volumeBindingMode: Immediate
mountOptions:
  - dir_mode=0777  # modify this permission if you want to enhance the security
  - file_mode=0777
  - mfsymlinks
  - cache=strict  # https://linux.die.net/man/8/mount.cifs
  - nosharesock  # reduce probability of reconnect race
  - actimeo=30  # reduce latency for metadata-heavy workload
  - nobrl  # disable sending byte range lock requests to the server and for applications which have challenges with posix locks
```

# [SMB](#tab/smb-files)

The following parameters are only for the SMB protocol.

|Name | Meaning | Available Value | Mandatory | Default value |
|--|--|--|--|--|
|subscriptionID | Specify Azure subscription ID where Azure file share is created. | Azure subscription ID | No | If not empty, `resourceGroup` must be provided. |
|storeAccountKey | Specify whether to store account key to Kubernetes secret. | `true` or `false`<br>`false` means driver uses kubelet identity to get account key. | No | `true` |
|secretName | Specify secret name to store account key. | | No | |
|secretNamespace | Specify the namespace of secret to store account key. <br><br> If `secretNamespace` isn't specified, the secret is created in the same namespace as the pod. | `default`,`kube-system`, etc. | No | PVC namespace, for example `csi.storage.k8s.io/pvc/namespace` |
|useDataPlaneAPI | Specify whether to use [data plane API][data-plane-api] for file share create/delete/resize, which could solve the SRP API throttling issue because the data plane API has almost no limit, while it would fail when there's firewall or Vnet settings on storage account. | `true` or `false` | No | `false` |

# [NFS](#tab/nfs-files)

The following parameters are only for the NFS protocol.

|Name | Meaning | Available Value | Mandatory | Default value |
|--|--|--|--|--|
|mountPermissions | Mounted folder permissions. The default is `0777`. If set to `0`, driver doesn't perform `chmod` after mount | `0777` | No | |
|rootSquashType | Specify root squashing behavior on the share. The default is `NoRootSquash` | `AllSquash`, `NoRootSquash`, `RootSquash` | No | |

# [VNet](#tab/vnet-files)

The following parameters are only for the VNet setting, such as NFS and private end point.

|Name | Meaning | Available Value | Mandatory | Default value |
|--|--|--|--|--|
|fsGroupChangePolicy | Indicates how the driver changes volume's ownership. Pod `securityContext.fsGroupChangePolicy` is ignored. | `OnRootMismatch` (default), `Always`, `None` | No | `OnRootMismatch`|
|subnetName | Subnet name | Existing subnet name of the agent node. | No | If empty, driver uses the `subnetName` value in Azure cloud config file. |
|vnetName | Virtual network name | Existing virtual network name. | No | if empty, driver updates all the subnets under the cluster virtual network. |
|vnetResourceGroup | Specify VNet resource group where virtual network is defined. | Existing resource group name. | No | If empty, driver uses the `vnetResourceGroup` value in Azure cloud config file. |

---

## Static provisioning parameters for PVs

# [General](#tab/general-files2)

The following table includes parameters you can use to define a PV.

|Name | Meaning | Available Value | Mandatory | Default value |
|--- | --- | --- | --- | --- |
|volumeAttributes.resourceGroup | Specify an Azure resource group name. | myResourceGroup | No | If empty, driver uses the same resource group name as current cluster. |
|volumeAttributes.storageAccount | Specify an existing Azure storage account name. | storageAccountName | Yes ||
|volumeAttributes.shareName | Specify an Azure file share name. | fileShareName | Yes ||
|volumeAttributes.folderName | Specify a folder name in Azure file share. | folderName | No | If folder name doesn't exist in file share, mount would fail. |
|volumeAttributes.protocol | Specify file share protocol. | `smb`, `nfs` | No | `smb` |
|volumeAttributes.server | Specify Azure storage account server address | Existing server address, for example `accountname.privatelink.file.core.windows.net`. | No | If empty, driver uses default `accountname.file.core.windows.net` or other sovereign cloud account address. |

# [SMB](#tab/smb-files2)

The following parameters are only for SMB protocol.

|Name | Meaning | Available Value | Mandatory | Default value |
|--- | --- | --- | --- | --- |
|volumeAttributes.secretName | Specify a secret name that stores storage account name and key. | | No ||
|volumeAttributes.secretNamespace | Specify a secret namespace. | `default`,`kube-system`, etc. | No | PVC namespace (`csi.storage.k8s.io/pvc/namespace`) |
|nodeStageSecretRef.name | Specify a secret name that stores storage account name and key. | Existing secret name. |  No  |If empty, driver uses kubelet identity to get account key.|
|nodeStageSecretRef.namespace | Specify a secret namespace. | Kubernetes namespace  |  No  ||

# [NFS](#tab/nfs-files2)

The following parameters are only for the NFS protocol.

|Name | Meaning | Available Value | Mandatory | Default value |
|--- | --- | --- | --- | --- |
|volumeAttributes.fsGroupChangePolicy | Indicates how the driver changes a volume's ownership. Pod `securityContext.fsGroupChangePolicy` is ignored.  | `OnRootMismatch` (default), `Always`, `None` | No | `OnRootMismatch` |
|volumeAttributes.mountPermissions | Specify mounted folder permissions. The default is `0777` | | No ||

---

## Create a PV snapshot class

The Azure Files CSI driver supports creating [snapshots of persistent volumes](https://kubernetes-csi.github.io/docs/snapshot-restore-feature.html) and the underlying file shares.

1. Create a [volume snapshot class](https://github.com/kubernetes-sigs/azurefile-csi-driver/blob/master/deploy/example/snapshot/volumesnapshotclass-azurefile.yaml) with the [kubectl apply][kubectl-apply] command:

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/deploy/example/snapshot/volumesnapshotclass-azurefile.yaml
   ```

   The output of the command resembles the following example:

   ```output
   volumesnapshotclass.snapshot.storage.k8s.io/csi-azurefile-vsc created
   ```

1. Create a [volume snapshot](https://github.com/kubernetes-sigs/azurefile-csi-driver/blob/master/deploy/example/snapshot/volumesnapshot-azurefile.yaml) from the PVC created earlier (`pvc-azurefile`).

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/deploy/example/snapshot/volumesnapshot-azurefile.yaml
   ```

   The output of the command resembles the following example:

   ```output
   volumesnapshot.snapshot.storage.k8s.io/azurefile-volume-snapshot created
   ```

1. Verify the snapshot was created correctly by running the following command:

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

## Resize an Azure Files PV

You can request a larger volume for a PVC. Edit the PVC object, and specify a larger size. This change triggers the expansion of the underlying volume that backs the PV.

> [!NOTE]
> A new PV is never created to satisfy the claim. Instead, an existing volume is resized. Shrinking persistent volumes is currently not supported.

In AKS, the built-in `azurefile-csi` storage class already supports expansion, so use the PVC we created earlier with this storage class. The PVC requested a 100 GiB file share. We can confirm that by running:

```bash
kubectl exec -it nginx-azurefile -- df -h /mnt/azurefile
```

The output of the command resembles the following example:

```output
Filesystem                                                                                Size  Used Avail Use% Mounted on
//f149b5a219bd34caeb07de9.file.core.windows.net/pvc-5e5d9980-da38-492b-8581-17e3cad01770  100G  128K  100G   1% /mnt/azurefile
```

1. Expand the PVC by increasing the `spec.resources.requests.storage` field:

   ```bash
   kubectl patch pvc pvc-azurefile --type merge --patch '{"spec": {"resources": {"requests": {"storage": "200Gi"}}}}'
   ```

   The output of the command resembles the following example:

   ```output
   persistentvolumeclaim/pvc-azurefile patched
   ```

1. Verify that both the PVC and the file system inside the pod show the new size:

   ```bash
   kubectl get pvc pvc-azurefile
   NAME            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS    AGE
   pvc-azurefile   Bound    pvc-5e5d9980-da38-492b-8581-17e3cad01770   200Gi      RWX            azurefile-csi   64m

   kubectl exec -it nginx-azurefile -- df -h /mnt/azurefile
   Filesystem                                                                                Size  Used Avail Use% Mounted on
   //f149b5a219bd34caeb07de9.file.core.windows.net/pvc-5e5d9980-da38-492b-8581-17e3cad01770  200G  128K  200G   1% /mnt/azurefile
   ```

## Use a PV with private Azure Files storage (private endpoint)

If your Azure Files resources are protected with a private endpoint, you must create your own storage class. Make sure to configure your [DNS settings to resolve the private endpoint IP address to the FQDN of the connection string][azure-private-endpoint-dns].

Customize the following parameters:

* `resourceGroup`: The resource group where the storage account is deployed.

* `storageAccount`: The storage account name.

* `server`: The FQDN of the storage account's private endpoint.

1. Create a file named `private-azure-file-sc.yaml`, and then paste the following example manifest in
the file. Replace the values for `<resourceGroup>` and `<storageAccountName>`. For example:

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

1. Create the storage class by using the `kubectl apply` command:

   ```bash
   kubectl apply -f private-azure-file-sc.yaml
   ```

   The output of the command resembles the following example:

   ```output
   storageclass.storage.k8s.io/private-azurefile-csi created
   ```

1. Create a file named `private-pvc.yaml`, and then paste the following example manifest in the file:

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

1. Create the PVC by using the [kubectl apply][kubectl-apply] command:

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

# [Dynamic volume](#tab/dynamic-volume-files-mid)

To enable managed identity for dynamically provisioned volumes, follow these steps:

1. Create a storage class with managed identity enabled using a YAML file, for example, `azurefile-csi-managed-identity.yaml` with the following sample content. Set `mountWithManagedIdentity: "true"` under `parameters`:

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

# [Static volume](#tab/static-volume-files-mid)

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

---

## Learn about Azure Files NFS

Azure Files supports the
[NFS v4.1 protocol](/azure/storage/files/storage-files-how-to-create-nfs-shares). NFS version 4.1
support for Azure Files provides you with a fully managed NFS system as a service built on highly
available, highly durable distributed resilient storage platform.

This option is optimized for random access workloads with in-place data updates and provides full
POSIX file system support. This section shows you how to use NFS shares with the Azure File CSI
driver on an AKS cluster.

> [!NOTE]
> You can use a private endpoint instead of allowing access to the selected VNet.

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
Files and modern Linux distributions support read and write sizes as large as 1,048,576 bytes (1
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

1. Create a file named `nfs-sc.yaml` and copy the sample manifest. For a list of supported `mountOptions`, see [NFS mount options][nfs-file-share-mount-options].

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

1. After you edit and save your YAML file, apply the storage class with the [kubectl apply][kubectl-apply] command:

   ```bash
   kubectl apply -f nfs-sc.yaml
   ```

   The output of the command resembles the following example:

   ```output
   storageclass.storage.k8s.io/azurefile-csi-nfs created
   ```

# [NFS deployment](#tab/nfs-deployment)

1. You can deploy a sample **StatefulSet** using the following manifest that writes timestamps to a file named `data.txt` by running the [kubectl apply][kubectl-apply] command:

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

1. Validate the contents of the volume by running the following command:

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
providing another layer of security.

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

---

## Other storage class examples

# [SMB share](#tab/smb-share)

The recommended mount options for SMB shares are provided in the following storage class example:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi
provisioner: file.csi.azure.com
allowVolumeExpansion: true
parameters:
  skuName: Premium_LRS  # available values: Premium_LRS, Premium_ZRS, Standard_LRS, Standard_GRS, Standard_ZRS, Standard_RAGRS, Standard_RAGZRS
reclaimPolicy: Delete
volumeBindingMode: Immediate
mountOptions:
  - dir_mode=0777  # modify this permission if you want to enhance the security
  - file_mode=0777 # modify this permission if you want to enhance the security
  - mfsymlinks    # support symbolic links
  - cache=strict  # https://linux.die.net/man/8/mount.cifs
  - nosharesock  # reduces probability of reconnect race
  - actimeo=30  # reduces latency for metadata-heavy workload
  - nobrl  # disable sending byte range lock requests to the server and for applications which have challenges with posix locks
```

If using premium (SSD) file shares and your workload is metadata heavy, enroll to use the [metadata caching](/azure/storage/files/smb-performance?tabs=portal#metadata-caching-for-ssd-file-shares) feature to improve performance.

For more information, see [Improve performance for SMB Azure file shares](/azure/storage/files/smb-performance).

# [NFS share](#tab/nfs-share)

The recommended mount options for NFS shares are provided in the following storage class example:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi-nfs
provisioner: file.csi.azure.com
parameters:
  protocol: nfs
  skuName: Premium_LRS     # available values: Premium_LRS, Premium_ZRS
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
mountOptions:
  - nconnect=4  # improves performance by enabling multiple connections to share
  - noresvport  # improves availability
  - actimeo=30  # reduces latency for metadata-heavy workloads
```

You can enhance read throughput by [increasing the read-ahead size](/azure/storage/files/nfs-performance#increase-read-ahead-size-to-improve-read-throughput).

While Azure Files supports setting `nconnect` up to the maximum setting of 16, we recommend configuring the mount options with the optimal setting of `nconnect=4`. Currently, there are no gains beyond four channels for the Azure Files implementation of `nconnect`.

For more information, see [Improve performance for NFS Azure file shares](/azure/storage/files/nfs-performance).

---

## Windows containers

The Azure Files CSI driver also supports Windows nodes and containers. To use Windows containers, follow the [Windows containers quickstart](./learn/quick-windows-container-deploy-cli.md) to add a Windows node pool.

1. After you have a Windows node pool, use the built-in storage classes like `azurefile-csi` or create a custom one. You can deploy an example [Windows-based stateful set](https://github.com/kubernetes-sigs/azurefile-csi-driver/blob/master/deploy/example/windows/statefulset.yaml) that saves timestamps into a file `data.txt` by running the [kubectl apply][kubectl-apply] command:

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/deploy/example/windows/statefulset.yaml
   ```

   The output of the command resembles the following example:

   ```output
   statefulset.apps/busybox-azurefile created
   ```

1. Validate the contents of the volume by running the following [kubectl exec][kubectl-exec] command:

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

::: zone-end

## Next steps

* For Azure Files CSI driver parameters, see [CSI driver parameters][CSI driver parameters].
* For more information about disk-based storage solutions, see [Disk-based solutions in AKS][disk-based-solutions].
* For more information about storage best practices, see [Best practices for storage and backups in Azure Kubernetes Service][operator-best-practices-storage].
* For more information about Azure ultra disk, see [Use ultra disks on Azure Kubernetes Service (AKS)][use-ultra-disks].
* For more information about Azure tags, see [Use Azure tags in Azure Kubernetes Service (AKS)][use-tags].

<!-- LINKS - external -->
[access-modes]: https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes
[create-burstable-storage-class]: https://github.com/Azure-Samples/burstable-managed-csi-premium
[CSI driver parameters]: https://github.com/kubernetes-sigs/azurefile-csi-driver/blob/master/docs/driver-parameters.md#static-provisionbring-your-own-file-share
[csi-blob-storage-open-source-driver]: https://github.com/kubernetes-sigs/blob-csi-driver
[csi-blob-storage-open-source-driver-uninstall-steps]: https://github.com/kubernetes-sigs/blob-csi-driver/blob/master/docs/install-csi-driver-master.md#clean-up-blob-csi-driver
[csi-driver-parameters]: https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/docs/driver-parameters.md
[csi-specification]: https://github.com/container-storage-interface/spec/blob/master/spec.md
[data-plane-api]: https://pkg.go.dev/github.com/Azure/azure-sdk-for-go/sdk/storage/azblob
[expand-pvc-with-downtime]: https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/docs/known-issues/sizegrow.md
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-create]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#create
[kubectl-delete]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#delete
[kubectl-describe]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#describe
[kubectl-exec]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#exec
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[kubernetes-secret]: https://kubernetes.io/docs/concepts/configuration/secret/
[kubernetes-storage-classes]: https://kubernetes.io/docs/concepts/storage/storage-classes/
[kubernetes-storage-classes-azure-files]: https://kubernetes.io/docs/concepts/storage/storage-classes/#azure-file
[kubernetes-volumes]: https://kubernetes.io/docs/concepts/storage/persistent-volumes/
[managed-disk-pricing-performance]: https://azure.microsoft.com/pricing/details/managed-disks/
[nfs-overview]:/windows-server/storage/nfs/nfs-overview
[smb-overview]: /windows/desktop/FileIO/microsoft-smb-protocol-and-cifs-protocol-overview

<!-- LINKS - internal -->
[access-tiers-overview]: /azure/storage/blobs/access-tiers-overview
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[az-aks-show]: /cli/azure/aks#az-aks-show
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
[az-storage-account-create]: /cli/azure/storage/account#az-storage-account-create
[az-storage-share-create]: /cli/azure/storage/share#az-storage-share-create
[azure-container-storage]: /azure/storage/container-storage/container-storage-introduction
[azure-disk-volume]: azure-disk-volume.md
[azure-files-pvc]: azure-files-dynamic-pv.md
[azure-files-usage]: /azure/storage/files/understand-performance#choosing-a-performance-tier-based-on-usage-patterns
[azure-netapp-files-mount-options-best-practices]: /azure/azure-netapp-files/performance-linux-mount-options#rsize-and-wsize
[azure-private-endpoint-dns]: /azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration
[azure-storage-account]: /azure/storage/common/storage-introduction
[compare-access-with-nfs]: /azure/storage/common/nfs-comparison
[concepts-storage]: concepts-storage.md
[csi-drivers-aks]: csi-storage-drivers.md
[csi-drivers-overview]: csi-storage-drivers.md
[disk-based-solutions]: /azure/cloud-adoption-framework/scenarios/app-platform/aks/storage#disk-based-solutions
[enable-on-demand-bursting]: ../virtual-machines/disks-enable-bursting.md?tabs=azure-cli
[expand-an-azure-managed-disk]: ../virtual-machines/linux/expand-disks.md#expand-an-azure-managed-disk
[general-purpose-machine-sizes]: /azure/virtual-machines/sizes-general
[install-azure-cli]: /cli/azure/install-azure-cli
[manage-blob-storage]: /azure/storage/blobs/blob-containers-cli
[mount-options]: #mount-options
[nfs-file-share-mount-options]: /azure/storage/files/storage-files-how-to-mount-nfs-shares#mount-options
[node-resource-group]: faq.yml
[operator-best-practices-storage]: operator-best-practices-storage.md
[persistent-volume]: concepts-storage.md#persistent-volumes
[persistent-volume-claim-overview]: concepts-storage.md#persistent-volume-claims
[premium-storage]: /azure/virtual-machines/disks-types
[private-endpoint-overview]: /azure/private-link/private-endpoint-overview
[share-snapshots-overview]: /azure/storage/files/storage-snapshots-files
[statically-provision-a-volume]: azure-csi-files-storage-provision.md#statically-provision-a-volume
[storage-account-private-endpoint]: /azure/storage/common/storage-private-endpoints
[storage-class-concepts]: concepts-storage.md#storage-classes
[storage-skus]: /azure/storage/common/storage-redundancy
[storage-tiers]: /azure/storage/files/storage-files-planning#storage-tiers
[tag-resources]: /azure/azure-resource-manager/management/tag-resources
[use-tags]: use-tags.md
