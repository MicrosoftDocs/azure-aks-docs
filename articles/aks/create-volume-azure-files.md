---
title: Create and Manage Persistent Volumes with Azure Files in Azure Kubernetes Service (AKS)
description: Learn how to create and manage persistent volumes using Azure Files with the Container Storage Interface (CSI) driver in Azure Kubernetes Service (AKS) to provide scalable and reliable storage for your containerized applications.
ms.topic: how-to
ms.subservice: aks-storage
ms.service: azure-kubernetes-service
ms.date: 03/31/2026
author: schaffererin
ms.author: schaffererin
# Customer intent: "As a Kubernetes administrator, I want to learn how to create and manage persistent volumes using Azure Files CSI drivers in Azure Kubernetes Service (AKS) so that I can provide scalable and reliable storage solutions for my containerized applications."
---

# Create and manage persistent volumes (PVs) with Azure Files in Azure Kubernetes Service (AKS)

If multiple pods need concurrent access to the same storage volume, you can use Azure Files to connect using the [Server Message Block (SMB)][smb-overview] or [NFS protocol][nfs-overview]. This article shows you how to dynamically and statically create an Azure file share for use by multiple pods in an Azure Kubernetes Service (AKS) cluster.

> [!NOTE]
> The Azure File CSI driver only permits the mounting of SMB file shares using key-based (NTLM v2) authentication, and therefore doesn't support the maximum security profile of Azure File share settings. Mounting NFS file shares doesn't require key-based authentication.

> [!NOTE]
> We recommend FIO when running benchmarking tests. For more information, see [benchmarking tools and tests](/azure/storage/files/nfs-performance#benchmarking-tools-and-tests).

## Prerequisites

- Azure CLI version 2.0.59 or later installed and configured. Find the version using the `az --version` command. To install or upgrade, see [Install Azure CLI][install-azure-cli].
- The [Azure Files CSI driver](./csi-storage-drivers.md) enabled on your AKS cluster.
- An Azure [storage account][azure-storage-account].
- When choosing between SSD (Premium) and HDD (Standard) file shares, it's important you understand the provisioning model and requirements of the expected usage pattern you plan to run on Azure Files. Azure Files has three billing models: [provisioned v2](/azure/storage/files/understanding-billing#provisioned-v2-model) (recommended), [pay-as-you-go](/azure/storage/files/understanding-billing#pay-as-you-go-model), and the legacy [provisioned v1](/azure/storage/files/understanding-billing#provisioned-v1-model). For more information, see [Choosing an Azure Files performance tier based on usage patterns][azure-files-usage].

## Use built-in storage classes to create dynamic PVs with Azure Files

Storage classes define how a unit of storage is dynamically created with a persistent volume. A storage account is automatically created in the [node resource group][node-resource-group] for use with the storage class to hold the Azure Files file share. When you use CSI drivers on AKS, there are two extra built-in `StorageClasses` that use the Azure Files CSI storage drivers (the other CSI storage classes are created with the cluster alongside the in-tree default storage classes):

- `azurefile-csi`: Creates an Azure file share on HDD storage.
- `azurefile-csi-premium`: Creates an Azure file share on SSD storage.

The reclaim policy on both storage classes ensures that the underlying Azure file share is deleted when the respective PV is deleted. The storage classes also configure the file shares to be expandable, you just need to edit the [persistent volume claim][persistent-volume-claim-overview] (PVC) with the new size.

You can select one of the following [Azure storage redundancy SKUs][storage-skus] for the `skuname` parameter in the storage class definition:

- **PremiumV2_LRS** (recommended): SSD provisioned v2, locally redundant storage
- **PremiumV2_ZRS** (recommended): SSD provisioned v2, zone-redundant storage
- **Premium_LRS**: SSD provisioned v1 (legacy), locally redundant storage
- **Premium_ZRS**: SSD provisioned v1 (legacy), zone-redundant storage
- **StandardV2_LRS**: HDD provisioned v2, locally redundant storage
- **StandardV2_ZRS**: HDD provisioned v2, zone-redundant storage
- **StandardV2_GRS**: HDD provisioned v2, geo-redundant storage
- **StandardV2_GZRS**: HDD provisioned v2, geo-zone-redundant storage
- **Standard_LRS**: HDD pay-as-you-go, locally redundant storage
- **Standard_GRS**: HDD pay-as-you-go, geo-redundant storage
- **Standard_ZRS**: HDD pay-as-you-go, zone-redundant storage

> [!IMPORTANT]
> To use the provisioned v2 billing model for Azure Files, you must use the Azure Files CSI driver [version 1.35.0](https://github.com/kubernetes-sigs/azurefile-csi-driver/releases/tag/v1.35.0) or later.

> [!NOTE]
> For new deployments, we recommend SSD provisioned v2 (`PremiumV2_LRS` or `PremiumV2_ZRS`) for most workloads. SSD file shares offer higher performance and low-latency disk support for I/O-intensive workloads. The minimum file share capacity for Premium accounts is 100 GiB.

## Create custom storage classes for dynamic PVs with Azure Files

The default storage classes are suitable for most scenarios. In some cases, you might want to have your own storage class customized with your own parameters. For example, you might want to configure the `mountOptions` of the file share.

1. Create a file named `azure-file-sc.yaml` and paste in the following example manifest:

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
      # Canonical permissions: 0755/uid=1000/gid=1000 for least privilege.
      # Use 0777/uid=0/gid=0 only if app requires root or broad write access.
      - dir_mode=0755
      - file_mode=0755
      - uid=1000
      - gid=1000
      - mfsymlinks
      - cache=strict
      - actimeo=30
      - nosharesock
    parameters:
      skuName: PremiumV2_LRS  # SSD provisioned v2 (recommended). Alternatives: Premium_LRS (SSD v1), StandardV2_LRS (HDD v2), Standard_LRS (HDD pay-as-you-go)
    ```

1. Create the storage class using the [`kubectl apply`][kubectl-apply] command:

    ```bash
    kubectl apply -f azure-file-sc.yaml
    ```

    Your output should resemble the following example output:

    ```output
    storageclass.storage.k8s.io/my-azurefile created
    ```

## Storage class parameters for dynamic PVs with Azure Files

The following table includes parameters you can use to define a custom storage class for your persistent volume claims (PVCs) with Azure Files:

| Name | Meaning | Available values | Required | Default value |
| ---- | ------- | ---------------- | -------- | ------------- |
| `accountAccessTier` | [Access tier for storage account][access-tiers-overview] | Standard account can choose `Hot` or `Cool`, and Premium account can only choose `Premium`. | No | Empty. Use default setting for different storage account types. |
| `accountQuota` | Limits the quota for an account. You can specify a maximum quota in GB (102400 GB by default). If the account exceeds the specified quota, the driver skips selecting the account. | | No | `102400` |
| `allowBlobPublicAccess` | Allow or disallow public access to all blobs or containers for storage account created by driver. | `true` or `false` | No | `false` |
| `disableDeleteRetentionPolicy` | Specify whether disable DeleteRetentionPolicy for storage account created by driver. | `true` or `false` | No | `false` |
| `folderName` | Specify folder name in Azure file share. | Existing folder name in Azure file share. | No | If folder name doesn't exist in file share, the mount fails. |
| `getLatestAccount` | Determines whether to get the latest account key based on the creation time. This driver gets the first key by default. | `true` or `false` | No | `false` |
| `location` | Specify the Azure region of the Azure storage account. | For example, `eastus`. | No | If empty, driver uses the same location name as current AKS cluster. |
| `matchTags` | Match tags when driver tries to find a suitable storage account. | `true` or `false` | No | `false` |
| `networkEndpointType` | Specify network endpoint type for the storage account created by driver. If `privateEndpoint` is specified, a private endpoint is created for the storage account. For other cases, a service endpoint is created by default. | "",`privateEndpoint` | No | "" |
| `protocol` | Specify file share protocol. | `smb`, `nfs` | No | `smb` |
| `requireInfraEncryption` | Specify whether or not the service applies a secondary layer of encryption with platform managed keys for data at rest for storage account created by driver. | `true` or `false` | No | `false` |
| `resourceGroup` | Specify the resource group for the Azure Disks. | Existing resource group name | No | If empty, driver uses the same resource group name as current AKS cluster. |
| `selectRandomMatchingAccount` | Determines whether to randomly select a matching account. By default, the driver always selects the first matching account in alphabetical order (Note: This driver uses account search cache, which results in uneven distribution of file creation across multiple accounts). | `true` or `false` | No | `false` |
| `server` | Specify Azure storage account server address. | Existing server address, for example `accountname.privatelink.file.core.windows.net`. | No | If empty, driver uses default `accountname.file.core.windows.net` or other sovereign cloud account address. |
| `shareAccessTier` | [Access tier for file share][storage-tiers] | General purpose v2 account can choose between `TransactionOptimized` (default), `Hot`, and `Cool`. Premium storage account type for file shares only. | No | Empty. Use default setting for different storage account types. |
| `shareName` | Specify Azure file share name. | Existing or new Azure file share name. | No | If empty, driver generates an Azure file share name. |
| `shareNamePrefix` | Specify Azure file share name prefix created by driver. | Share name can only contain lowercase letters, numbers, hyphens, and length should be fewer than 21 characters. | No | |
| `skuName` | Azure Files storage account type (alias: `storageAccountType`) | `Standard_LRS`, `Standard_ZRS`, `Standard_GRS`, `Standard_RAGRS`, `Standard_RAGZRS`,`Premium_LRS`, `Premium_ZRS`, `StandardV2_LRS`, `StandardV2_ZRS`, `StandardV2_GRS`, `StandardV2_GZRS`, `PremiumV2_LRS`, `PremiumV2_ZRS` | No | `Standard_LRS` <br> Minimum file share size for Premium account type is 100 GB. <br> ZRS account type is supported in limited regions. <br> NFS file share only supports Premium account type. <br> Standard V2 SKU names are for [Azure Files provisioned v2 model](/azure/storage/files/understanding-billing#provisioned-v2-model). |
| `storageAccount` | Specify an Azure storage account name. | storageAccountName | No | When a specific storage account name is not provided, the driver will look for a suitable storage account that matches the account settings within the same resource group. If it fails to find a matching storage account, it will create a new one. However, if a storage account name is specified, the storage account must already exist. |
| `storageEndpointSuffix` | Specify Azure storage endpoint suffix. | `core.windows.net`, `core.chinacloudapi.cn`, etc. | No | If empty, driver uses default storage endpoint suffix according to cloud environment. For example, `core.windows.net`. |
| `subscriptionID` | Specify Azure subscription ID where Azure file share is created. | Azure subscription ID | No | If not empty, `resourceGroup` must be provided. |
| `tags` | [Tags][tag-resources] are created in new storage account. | Tag format: 'foo=aaa,bar=bbb' | No | "" |
| --- | **The following parameters are only for SMB protocol** | --- | --- | --- |
| `storeAccountKey` | Specify whether to store account key to Kubernetes secret. | `true` or `false` <br> `false` means driver uses kubelet identity to get account key. | No | `true` |
| `secretName` | Specify secret name to store account key. | | No | |
| `secretNamespace` | Specify the namespace of secret to store account key. <br><br> **Note**: <br> If `secretNamespace` isn't specified, the secret is created in the same namespace as the pod. | `default`,`kube-system`, etc. | No | PVC namespace, for example `csi.storage.k8s.io/pvc/namespace` |
| `useDataPlaneAPI` | Specify whether to use [data plane API][data-plane-api] for file share create/delete/resize, which could solve the SRP API throttling issue because the data plane API has almost no limit, while it would fail when there's firewall or Vnet settings on storage account. | `true` or `false` | No | `false` |
| --- | **The following parameters are only for NFS protocol** | --- | --- | --- |
| `mountPermissions` | Mounted folder permissions. The default is `0777`. If set to `0`, driver doesn't perform `chmod` after mount | `0777` | No | |
| `rootSquashType` | Specify root squashing behavior on the share. The default is `NoRootSquash` | `AllSquash`, `NoRootSquash`, `RootSquash` | No | |
| --- | **The following parameters are only for virtual network setting (for example: NFS, private endpoint)** | --- | --- | --- |
| `fsGroupChangePolicy` | Indicates how the driver changes volume's ownership. Pod `securityContext.fsGroupChangePolicy` is ignored. | `OnRootMismatch` (default), `Always`, `None` | No | `OnRootMismatch` |
| `subnetName` | Subnet name | Existing subnet name of the agent node. | No | If empty, driver uses the `subnetName` value in Azure cloud config file. |
| `vnetName` | Virtual network name | Existing virtual network name. | No | If empty, driver will update all the subnets under the cluster virtual network. |
| `vnetResourceGroup` | Specify virtual network resource group where virtual network is defined. | Existing resource group name. | No | If empty, driver uses the `vnetResourceGroup` value in Azure cloud config file. |

> [!IMPORTANT]
> The `tags` storage class parameter is applied to the storage account when the Azure Files CSI driver provisions the volume. After the persistent volume is created, the `PersistentVolume` spec is immutable, so editing or patching the PV to change tags or other volume attributes fails. Updating the storage class later affects only newly provisioned volumes.
>
> To update tags on an existing volume, change them on the underlying storage account in Azure. If your storage class uses an existing storage account, update tags on that account. This operation doesn't interrupt existing mounts, pods, or data access, and updated Azure tags aren't synchronized back to the Kubernetes PV YAML or metadata. For example:
>
> ```azurecli-interactive
> az storage account update \
>     --name mystorageaccount \
>     --resource-group MC_myResourceGroup_myAKSCluster_eastus \
>     --set tags.abc=ABC123
> ```

> [!NOTE]
> If the storage account is created by the driver, then you only need to specify `networkEndpointType: privateEndpoint` parameter in storage class. The CSI driver creates the private endpoint and private DNS zone (named `privatelink.file.core.windows.net`) together with the account. If you bring your own storage account, then you need to [create the private endpoint][storage-account-private-endpoint] for the storage account. If you're using Azure Files storage in a network isolated cluster, you must create a custom storage class with "networkEndpointType: privateEndpoint". You can use the following example manifest as a reference:
>
> ```yaml
> apiVersion: storage.k8s.io/v1
> kind: StorageClass
> metadata:
>   name: azurefile-csi-private-custom
> provisioner: file.csi.azure.com
> allowVolumeExpansion: true
> parameters:
>   skuName: PremiumV2_LRS  # SSD provisioned v2 (recommended). Alternatives: Premium_LRS, Premium_ZRS, StandardV2_LRS, Standard_LRS
>   networkEndpointType: privateEndpoint
> reclaimPolicy: Delete
> volumeBindingMode: Immediate
> mountOptions:
>   # Canonical permissions: 0755/uid=1000/gid=1000 for least privilege.
>   # Use 0777/uid=0/gid=0 only if app requires root or broad write access.
>   - dir_mode=0755
>   - file_mode=0755
>   - uid=1000
>   - gid=1000
>   - mfsymlinks
>   - cache=strict  # https://linux.die.net/man/8/mount.cifs
>   - nosharesock  # reduce probability of reconnect race
>   - actimeo=30  # reduce latency for metadata-heavy workload
>   - nobrl  # disable sending byte range lock requests to the server and for applications which have challenges with posix locks
> ```

## Create a PVC with Azure Files

A PVC uses the storage class object to dynamically provision an Azure file share. You can use the example YAML manifest in this section to create a PVC that's _100 GB_ in size with _ReadWriteMany_ access. For more information on access modes, see [Kubernetes PV access modes][access-modes].

1. Create a file named `azure-file-pvc.yaml` and paste in the following YAML. Make sure the `storageClassName` matches the name of your existing storage class.

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

1. View the status of the PVC using the [`kubectl get`][kubectl-get] command:

    ```bash
    kubectl get pvc my-azurefile
    ```

    Your output should resemble the following example output, which shows that the PVC is in a `Bound` state, and a PV was dynamically created to satisfy the claim:

    ```output
    NAME           STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
    my-azurefile   Bound     pvc-aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb   100Gi       RWX            my-azurefile      5m
    ```

## Use a PVC with Azure Files in a pod

The example YAML manifest in this section creates a pod that uses the PVC _my-azurefile_ to mount the Azure Files file share at the _/mnt/azure_ path. For Windows Server containers, specify a `mountPath` using the Windows path convention, such as _'D:'_.

1. Create a file named `azure-pvc-files.yaml`, and paste in the following YAML. Make sure the `claimName` matches the name of your existing PVC.

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

1. View the status of the pod using the [`kubectl describe`][kubectl-describe] command:

    ```bash
    kubectl describe pod mypod
    ```

    Your output should resemble the following example output, which shows that the pod is running and the volume is mounted at the correct path:

    ```output
    Containers:
      mypod:
        Container ID:   docker://BB22CC33DD44EE55FF66AA77BB88CC99DD00EE11
        Image:          mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine
        Image ID:       docker-pullable://nginx@sha256:AA11BB22CC33DD44EE55FF66AA77BB88CC99DD00
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

## Mount options for Azure Files

The location to configure mount options (`mountOptions`) depends on whether you're provisioning dynamic or static persistent volumes:

- If you're dynamically provisioning a volume with a storage class, specify the mount options on the storage class object (kind: StorageClass).
- If you're statically provisioning a volume, specify the mount options on the PV object (kind: PersistentVolume).
- If you're [mounting the file share as an inline volume](#mount-file-share-as-an-inline-volume), specify the mount options on the Pod object (kind: Pod).

For more information, see [Mount options](https://kubernetes.io/docs/concepts/storage/storage-classes/#mount-options).

The default value for `fileMode` and `dirMode` is _0777_ for Kubernetes versions 1.13.0 and above. The following example sets _0777_:

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: my-azurefile
provisioner: file.csi.azure.com
allowVolumeExpansion: true
mountOptions:
  # Canonical permissions: 0755/uid=1000/gid=1000 for least privilege.
  # Use 0777/uid=0/gid=0 only if app requires root or broad write access.
  - dir_mode=0755
  - file_mode=0755
  - uid=1000
  - gid=1000
  - mfsymlinks
  - cache=strict
  - actimeo=30
  - nobrl  # disable sending byte range lock requests to the server and for applications which have challenges with posix locks
parameters:
  skuName: PremiumV2_LRS  # SSD provisioned v2 (recommended). Alternatives: Premium_LRS (SSD v1), StandardV2_LRS (HDD v2), Standard_LRS (HDD pay-as-you-go)
```

### Recommended mount options for SMB shares

Recommended mount options for SMB shares are provided in the following storage class example:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
    name: azurefile-csi-premiumv2-custom
provisioner: file.csi.azure.com
allowVolumeExpansion: true
parameters:
    skuName: PremiumV2_LRS  # SSD provisioned v2 (recommended). Alternatives: Premium_LRS, Premium_ZRS, StandardV2_LRS, Standard_LRS, Standard_ZRS
reclaimPolicy: Delete
volumeBindingMode: Immediate
mountOptions:
    # Canonical permissions: 0755/uid=1000/gid=1000 for least privilege.
    # Use 0777/uid=0/gid=0 only if app requires root or broad write access.
    - dir_mode=0755
    - file_mode=0755
    - uid=1000
    - gid=1000
    - mfsymlinks    # support symbolic links
    - cache=strict  # https://linux.die.net/man/8/mount.cifs
    - nosharesock  # reduces probability of reconnect race
    - actimeo=30  # reduces latency for metadata-heavy workload
    - nobrl  # disable sending byte range lock requests to the server and for applications which have challenges with posix locks
```

If you're using premium (SSD) file shares with the SMB protocol and your workload is metadata heavy, enroll to use the [metadata caching](/azure/storage/files/smb-performance?tabs=portal#metadata-caching-for-ssd-file-shares) feature to improve performance.

For more information, see [Improve performance for SMB Azure file shares](/azure/storage/files/smb-performance).

### Recommended mount options for NFS shares

Recommended mount options for NFS shares are provided in the following storage class example:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
    name: azurefile-csi-premiumv2-custom
provisioner: file.csi.azure.com
parameters:
    protocol: nfs
    skuName: PremiumV2_LRS     # SSD provisioned v2 (recommended). Alternatives: Premium_LRS, Premium_ZRS, PremiumV2_ZRS
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
mountOptions:
    - nconnect=4  # improves performance by enabling multiple connections to share
    - noresvport  # improves availability
    - actimeo=30  # reduces latency for metadata-heavy workloads
```

Increase [read-ahead size](/azure/storage/files/nfs-performance#increase-read-ahead-size-to-improve-read-throughput) to improve read throughput.

While Azure Files supports setting nconnect up to the maximum setting of 16, we recommend configuring the mount options with the optimal setting of nconnect=4. Currently, there are no gains beyond four channels for the Azure Files implementation of nconnect.

## Create a volume snapshot from a PVC with Azure Files

The Azure Files CSI driver supports creating [snapshots of persistent volumes](https://kubernetes-csi.github.io/docs/snapshot-restore-feature.html) and the underlying file shares.

1. Create a [volume snapshot class](https://github.com/kubernetes-sigs/azurefile-csi-driver/blob/master/deploy/example/snapshot/volumesnapshotclass-azurefile.yaml) using the [`kubectl apply`][kubectl-apply] command:

    ```bash
    kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/deploy/example/snapshot/volumesnapshotclass-azurefile.yaml
    ```

    Your output should resemble the following example output:

    ```output
    volumesnapshotclass.snapshot.storage.k8s.io/csi-azurefile-vsc created
    ```

1. Create a [volume snapshot](https://github.com/kubernetes-sigs/azurefile-csi-driver/blob/master/deploy/example/snapshot/volumesnapshot-azurefile.yaml) from the dynamic PVC you created earlier in this tutorial using the [`kubectl apply`][kubectl-apply] command:

    ```bash
    kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/deploy/example/snapshot/volumesnapshot-azurefile.yaml
    ```

    Your output should resemble the following example output:

    ```output
    volumesnapshot.snapshot.storage.k8s.io/azurefile-volume-snapshot created
    ```

1. View the status of the volume snapshot using the [`kubectl describe`][kubectl-describe] command:

    ```bash
    kubectl describe volumesnapshot azurefile-volume-snapshot
    ```

    Your output should resemble the following example output, which shows that the volume snapshot isn't ready to use because the driver is still creating the snapshot of the underlying Azure file share:

    ```output
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
      UID:               00aa00aa-bb11-cc22-dd33-44ee44ee44ee
    Spec:
      Source:
        Persistent Volume Claim Name:  pvc-azurefile
      Volume Snapshot Class Name:      csi-azurefile-vsc
    Status:
      Bound Volume Snapshot Content Name:  snapcontent-00aa00aa-bb11-cc22-dd33-44ee44ee44ee
      Ready To Use:                        false
    Events:                                <none>
    ```

## Resize a persistent volume with Azure Files

> [!NOTE]
> Shrinking persistent volumes isn't currently supported. Trying to patch an existing PVC with a smaller size than the current one leads to the following error message:
>
> `The persistentVolumeClaim "pvc-azurefile" is invalid: spec.resources.requests.storage: Forbidden: field can not be less than previous value.`

You can request a larger volume for a PVC by editing the PVC object to specify a larger size. This change triggers the expansion of the underlying volume that backs the PV. A new PV is never created to satisfy the claim. Instead, an existing volume is resized.

In AKS, the built-in `managed-csi` storage class already supports expansion, so you can use the dynamic PVC you created earlier in this tutorial. The PVC requested a 100 GiB file share.

1. Verify the current size of the PVC and the filesystem inside the pod using the `kubectl exec` command to run the `df -h` command inside the pod:

    ```bash
    kubectl exec -it nginx-azurefile -- df -h /mnt/azurefile
    ```

    Your output should resemble the following example output, which shows that the filesystem is 100 GB in size:

    ```output
    Filesystem                                                                                      Size  Used Avail Use% Mounted on
    //a123b4c567de89fghi01jk2.file.core.windows.net/pvc-00aa00aa-bb11-cc22-dd33-44ee44ee44ee  100G  128K  100G   1% /mnt/azurefile
    ```

1. Expand the PVC by increasing the `spec.resources.requests.storage` field using the `kubectl patch` command. In this example, we increase the file share to 200 GiB:

    ```bash
    kubectl patch pvc pvc-azurefile --type merge --patch '{"spec": {"resources": {"requests": {"storage": "200Gi"}}}}'
    ```

    Your output should resemble the following example output, which shows that the PVC was patched successfully:

    ```output
    persistentvolumeclaim/pvc-azurefile patched
    ```

1. Verify the PVC was successfully resized and the new size is reflected in the pod by using the `kubectl get pvc` command and the `df -h` command inside the pod:

    ```bash
    kubectl get pvc pvc-azurefile
    ```

    Your output should resemble the following example output, which shows that the PVC is still in a `Bound` state, and the capacity was updated to 200 GiB:

    ```output
    NAME            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS    AGE
    pvc-azurefile   Bound    pvc-00aa00aa-bb11-cc22-dd33-44ee44ee44ee   200Gi      RWX            azurefile-csi   64m
    ```

1. Verify the new size of the filesystem inside the pod using the `kubectl exec` command to run the `df -h` command inside the pod:

    ```bash
    kubectl exec -it nginx-azurefile -- df -h /mnt/azurefile
    ```

    Your output should resemble the following example output, which shows that the filesystem is now 200 GB in size:

    ```output
    Filesystem                                                                                Size  Used Avail Use% Mounted on
    //a123b4c567de89fghi01jk2.file.core.windows.net/pvc-bbbbbbbb-1111-2222-3333-cccccccccccc  200G  128K  200G   1% /mnt/azurefile
    ```

## Use a persistent volume with private Azure Files storage (private endpoint)

If your Azure Files resources are protected with a private endpoint, you must create your own storage class. Make sure that you've [configured your DNS settings to resolve the private endpoint IP address to the FQDN of the connection string][azure-private-endpoint-dns]. When you create the storage class using the Azure Files CSI driver, you need to specify the `networkEndpointType` parameter with the value `privateEndpoint`, and provide the following parameters:

- `resourceGroup`: The resource group where the storage account is deployed.
- `storageAccount`: The storage account name.
- `server`: The FQDN of the storage account's private endpoint.

1. Create a file named `private-azure-file-sc.yaml` and then paste in the following manifest. Make sure you replace the placeholders for `<resourceGroup>` and `<storageAccountName>`.

    ```yaml
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: azurefile-csi-private-custom
    provisioner: file.csi.azure.com
    allowVolumeExpansion: true
    parameters:
      skuName: PremiumV2_LRS  # SSD provisioned v2 (recommended). Alternatives: Premium_LRS, StandardV2_LRS
      resourceGroup: <resourceGroup>
      storageAccount: <storageAccountName>
      server: <storageAccountName>.file.core.windows.net
      networkEndpointType: privateEndpoint
    reclaimPolicy: Delete
    volumeBindingMode: Immediate
    mountOptions:
      # Canonical permissions: 0755/uid=1000/gid=1000 for least privilege.
      # Use 0777/uid=0/gid=0 only if app requires root or broad write access.
      - dir_mode=0755
      - file_mode=0755
      - uid=1000
      - gid=1000
      - mfsymlinks
      - cache=strict  # https://linux.die.net/man/8/mount.cifs
      - nosharesock  # reduce probability of reconnect race
      - actimeo=30  # reduce latency for metadata-heavy workload
      - nobrl
    ```

1. Create the storage class using the `kubectl apply` command:

    ```bash
    kubectl apply -f private-azure-file-sc.yaml
    ```

    Your output should resemble the following example output:

    ```output
    storageclass.storage.k8s.io/private-azurefile-csi created
    ```

1. Create a file named `private-pvc.yaml` and paste in the following manifest. Make sure the `storageClassName` matches the name of your existing storage class.

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

1. Create the PVC using the [`kubectl apply`][kubectl-apply] command.

    ```bash
    kubectl apply -f private-pvc.yaml
    ```

## Use Azure Files with Windows containers

The Azure Files CSI driver also supports Windows nodes and containers. To use Windows containers, follow the [Windows containers quickstart](./learn/quick-windows-container-deploy-cli.md) to add a Windows node pool. After you have a Windows node pool, you can use the built-in storage classes like `azurefile-csi` or create a custom one.  The example [Windows-based stateful set](https://github.com/kubernetes-sigs/azurefile-csi-driver/blob/master/deploy/example/windows/statefulset.yaml) in this section saves timestamps into a file `data.txt` every second, which is mounted to an Azure file share using the Azure Files CSI driver.

1. Create the stateful set using the [`kubectl apply`][kubectl-apply] command:

    ```bash
    kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/deploy/example/windows/statefulset.yaml
    ```

    Your output should resemble the following example output:

    ```output
    statefulset.apps/busybox-azurefile created
    ```

1. Validate the timestamps are being written to the file share using the following `kubectl exec` commands to run the `cat` command inside the pod:

    ```bash
    kubectl exec -it busybox-azurefile-0 -- cat c:\\mnt\\azurefile\\data.txt # on Linux/MacOS Bash
    kubectl exec -it busybox-azurefile-0 -- cat c:\mnt\azurefile\data.txt # on Windows Powershell/CMD
    ```

    Your output should resemble the following example output, which shows that timestamps are being written to the file share every second:

    ```output
    2020-08-27 22:11:01Z
    2020-08-27 22:11:02Z
    2020-08-27 22:11:04Z
    (...)
    ```

## Use NFS protocol with Azure Files

[Azure Files supports the NFS v4.1 protocol](/azure/storage/files/storage-files-how-to-create-nfs-shares). NFS version 4.1 support for Azure Files provides you with a fully managed NFS file system as a service built on a highly available and highly durable distributed resilient storage platform.

This option is optimized for random access workloads with in-place data updates and provides full POSIX file system support. This section shows you how to use NFS shares with the Azure File CSI driver on an AKS cluster.

### Prerequisites for using NFS shares with Azure Files

- NFS requires SSD file shares (such as `PremiumV2_LRS`, `PremiumV2_ZRS`, `Premium_LRS`, or `Premium_ZRS`) and a virtual network-enabled storage account.
- Your AKS cluster _control plane_ identity (that is, your AKS cluster name) is added to the [Contributor](/azure/role-based-access-control/built-in-roles#contributor) role on the VNet and NetworkSecurityGroup.
- Your AKS cluster's service principal or managed service identity (MSI) must be added to the Contributor role to the storage account.

> [!NOTE]
> You can use a private endpoint instead of allowing access to the selected VNet.

### Optimize read and write size options

This section provides information about how to approach performance tuning NFS with the Azure Files CSI driver with the `rsize` and `wsize` options. The `rsize` and `wsize` options set the maximum transfer size of an NFS operation. If `rsize` or `wsize` aren't specified on mount, the client and server negotiate the largest size supported by the two. Currently, both Azure Files and modern Linux distributions support read and write sizes as large as 1,048,576 Bytes (1 MiB).

Optimal performance is based on efficient client-server communication. Increasing or decreasing the **mount** read and write option size values can improve NFS performance. The default size of the read/write packets transferred between client and server are 8 KB for NFS version 2, and 32 KB for NFS version 3 and 4. These defaults might be too large or too small. Reducing the `rsize` and `wsize` might improve NFS performance in a congested network by sending smaller packets for each NFS-read reply and write request. However, this can increase the number of packets needed to send data across the network, increasing total network traffic and CPU utilization on the client and server.

It's important that you perform testing to find an `rsize` and `wsize` that sustain efficient packet transfer and don't decrease throughput and increase latency.

The following example manifest configures the `mountOptions` section in a storage class to a maximum `rsize` and `wsize` of 256-KiB:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi-premiumv2-custom
provisioner: file.csi.azure.com
allowVolumeExpansion: true
parameters:
  protocol: nfs
  skuName: PremiumV2_LRS  # SSD provisioned v2 (recommended). Alternatives: Premium_LRS, Premium_ZRS, PremiumV2_ZRS
mountOptions:
  - nconnect=4
  - noresvport
  - actimeo=30
  - rsize=262144
  - wsize=262144
```

For a list of supported `mountOptions`, see [NFS mount options][nfs-file-share-mount-options].

### Create NFS file share storage class

> [!NOTE]
> `vers`, `minorversion`, `sec` are configured by the Azure File CSI driver. Specifying a value in your manifest for these properties isn't supported.

1. Create a file named `nfs-sc.yaml` and paste in the following manifest. Make sure to specify `protocol: nfs` in the parameters section, and adjust the `mountOptions` as needed for your workload.

    ```yaml
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: azurefile-csi-premiumv2-custom
    provisioner: file.csi.azure.com
    allowVolumeExpansion: true
    parameters:
      protocol: nfs
      skuName: PremiumV2_LRS  # SSD provisioned v2 (recommended). Alternatives: Premium_LRS, Premium_ZRS, PremiumV2_ZRS
    mountOptions:
      - nconnect=4
      - noresvport
      - actimeo=30
    ```

1. After editing and saving the file, create the storage class using the [`kubectl apply`][kubectl-apply] command.

    ```bash
    kubectl apply -f nfs-sc.yaml
    ```

    Your output should resemble the following example output:

    ```output
    storageclass.storage.k8s.io/azurefile-csi-nfs created
    ```

### Create a stateful set with an NFS-backed file share

1. Create a file named `nfs-ss.yaml` and paste in the following manifest. This configuration saves timestamps into a file `data.txt`.

    ```yaml
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
            storageClassName: azurefile-csi-premiumv2-custom
            accessModes: ["ReadWriteMany"]
            resources:
              requests:
                storage: 100Gi
    ```

1. Create the stateful set using the [`kubectl apply`][kubectl-apply] command.

    ```bash
    kubectl apply -f nfs-ss.yaml
    ```

    Your output should resemble the following example output:

    ```output
    statefulset.apps/statefulset-azurefile created
    ```

1. Validate the contents of the volume using the following `kubectl exec` command to run the `df -h` command inside the pod:

    ```bash
    kubectl exec -it statefulset-azurefile-0 -- df -h
    ```

    Your output should resemble the following example output, which shows that the NFS file share is mounted at the correct path with the correct size:

    ```output
    Filesystem      Size  Used Avail Use% Mounted on
    ...
    /dev/sda1                                                                                 29G   11G   19G  37% /etc/hosts
    accountname.file.core.windows.net:/accountname/pvc-cccccccc-2222-3333-4444-dddddddddddd  100G     0  100G   0% /mnt/azurefile
    ...
    ```

    Because the NFS file share is in a Premium storage account, the minimum file share size is 100 GiB. If you create a PVC with a small storage size, you might encounter an error similar to the following: _failed to create file share ... size (5)..._.

### Encryption in Transit (EiT) for NFS file shares (preview)

> [!NOTE]
> The EiT feature is now available in preview starting with AKS version 1.33. Ubuntu 20.04, Azure Linux, arm64 and Windows nodes aren't currently supported.
>
> The feature is supported in all Azure regions that [support SSD Azure file shares](/azure/storage/files/redundancy-premium-file-shares).

[Encryption in Transit (EiT)](/azure/storage/files/encryption-in-transit-for-nfs-shares) ensures that all read and writes to the NFS file shares within the virtual network are encrypted, providing an extra layer of security.

By setting `encryptInTransit: "true"` in the storage class parameters, you can enable data encryption in transit for NFS Azure file shares. For example:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi-premiumv2-custom
provisioner: file.csi.azure.com
allowVolumeExpansion: true
parameters:
  protocol: nfs
  skuName: PremiumV2_LRS  # SSD provisioned v2 (recommended). Alternatives: Premium_LRS, Premium_ZRS, PremiumV2_ZRS
  encryptInTransit: "true"
mountOptions:
  - nconnect=4
  - noresvport
  - actimeo=30
```

## Use managed identity to access Azure Files storage (preview)

Azure Files now supports managed identity based authentication for SMB access. This enables your applications to securely access Azure Files without storing or managing credentials.

> [!NOTE]
> Managed identity support for Azure Files in AKS is available in preview starting with AKS version 1.34 on Linux nodes.

### Prerequisites for using managed identity to access Azure Files storage

- Ensure the [user-assigned Kubelet identity](use-managed-identity.md#create-a-kubelet-managed-identity) has the `Storage File Data SMB MI Admin` role on the storage account.
  - If you use your own storage account, you need to assign `Storage File Data SMB MI Admin` role to the user-assigned Kubelet identity on that storage account.
  - If the storage account is created by the CSI driver, grant `Storage File Data SMB MI Admin` role to the resource group where the storage account resides.


### Enable managed identity for dynamic PVs with Azure Files

To enable managed identity for dynamically provisioned volumes, you need to create a new storage class with `mountWithManagedIdentity`: `"true"` and deploy your stateful set using this storage class.

The following example manifest configures a storage class to use managed identity to access Azure Files:

 ```yaml
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
    # Canonical permissions: 0755/uid=1000/gid=1000 for least privilege.
    # Use 0777/uid=0/gid=0 only if app requires root or broad write access.
    - dir_mode=0755
    - file_mode=0755
    - uid=1000
    - gid=1000
    - mfsymlinks
    - cache=strict  # https://linux.die.net/man/8/mount.cifs
    - nosharesock  # reduce probability of reconnect race
    - actimeo=30  # reduce latency for metadata-heavy workload
    - nobrl  # disable sending byte range lock requests to the server
```

### Enable managed identity for static PVs with Azure Files

To use managed identity with statically provisioned Azure Files persistent volumes, ensure the following configuration:

1. Enable the SMBOauth on the storage account by running:
   ```bash
   az storage account update --name <account-name> --resource-group <resource-group-name> --enable-smb-oauth true
   ```
1. Create a PV with `mountWithManagedIdentity`: `"true"` and mount the PV to your application pod.

The following example manifest configures a PV to use managed identity to access Azure Files:

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
    # Canonical permissions: 0755/uid=1000/gid=1000 for least privilege.
    # Use 0777/uid=0/gid=0 only if app requires root or broad write access.
    - dir_mode=0755
    - file_mode=0755
    - uid=1000
    - gid=1000
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

## Use workload identity to access Azure Files storage (preview)

Azure Files now supports workload identity-based authentication for SMB access. Workload identity enables pod-level, least-privilege access to Azure Files without tying application identity to the node lifecycle.

> [!NOTE]
> Workload identity support for Azure Files in AKS is available in preview starting with AKS version 1.35.0 on Linux nodes.

### Prerequisites for using workload identity to access Azure Files storage
Before using workload identity to access Azure Files from AKS, complete the following prerequisites.

#### 1. Create a cluster with oidc-issuer enabled and get the AKS cluster credential
Create a new AKS cluster with the OIDC issuer enabled, or verify that it's already enabled. Follow the official [documentation](use-oidc-issuer.md#create-an-aks-cluster-with-the-oidc-issuer) for creating a new AKS cluster with the `--enable-oidc-issuer` parameter and retrieve the cluster credentials. And set the following environment variables:
```bash
export RESOURCE_GROUP=<your resource group name>
export CLUSTER_NAME=<your cluster name>
export REGION=<your region>
```

#### 2. Prepare the storage account
Create a new storage account and file share, or use an existing one. Refer to the Azure Files [documentation](/azure/storage/files/storage-how-to-use-files-portal) for detailed instructions. Set the following environment variables:
```bash
export STORAGE_RESOURCE_GROUP=<your storage account resource group>
export ACCOUNT=<your storage account name>
export SHARE=<your fileshare name> # optional
```

#### 3. Create or reuse a managed identity and grant required permissions

Create a user‑assigned managed identity, or reuse an existing one (for example, a [managed identity](managed-identity-overview.md) associated with the AKS node resource group). And retrieve the required identity and resource details:
```bash
export UAMI=<your managed identity name>
az identity create --name $UAMI --resource-group $RESOURCE_GROUP

export USER_ASSIGNED_CLIENT_ID="$(az identity show -g $RESOURCE_GROUP --name $UAMI --query 'clientId' -o tsv)"
export IDENTITY_TENANT=$(az aks show --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query identity.tenantId -o tsv)
export ACCOUNT_SCOPE=$(az storage account show --name $ACCOUNT --query id -o tsv)
```

Grant the `Storage File Data SMB MI Admin` role to the managed identity. This role enables Azure Files mounting using workload identity tokens only, without relying on storage account keys.
```bash
az role assignment create --role "Storage File Data SMB MI Admin" --assignee $USER_ASSIGNED_CLIENT_ID --scope $ACCOUNT_SCOPE
```

#### 4. Create a Kubernetes ServiceAccount
Create a Kubernetes ServiceAccount that your workload will use.
```bash
export SERVICE_ACCOUNT_NAME=<your sa name>
export SERVICE_ACCOUNT_NAMESPACE=<your sa namespace>

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
EOF
```

#### 5. Create the federated identity credential
Create the federated identity credential between the managed identity, service account issuer, and subject using the `az identity federated-credential create` command.
```bash
export FEDERATED_IDENTITY_NAME=<your federated identity name>
export AKS_OIDC_ISSUER="$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "oidcIssuerProfile.issuerUrl" -o tsv)"

az identity federated-credential create --name $FEDERATED_IDENTITY_NAME \
--identity-name $UAMI \
--resource-group $RESOURCE_GROUP \
--issuer $AKS_OIDC_ISSUER \
--subject system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME}
```

After completing these steps, workloads running with the specified ServiceAccount can authenticate to Azure Files using Microsoft Entra workload identity, without using storage account keys or node‑level managed identities.

### Enable workload identity for dynamic PVs with Azure Files
To use workload identity with dynamically provisioned Azure Files persistent volumes, ensure the following configuration:
1. Grant permissions to the CSI driver control plane identity
   - Assign the `Storage Account Contributor` role to the identity used by the CSI driver control plane for the target storage account.
   - If the storage account is created dynamically by the CSI driver, grant `Storage Account Contributor` role to the node resource group.
   - By default, AKS cluster control plane identity is already assigned the `Storage Account Contributor` role on the node resource group for the storage account creation.

1. Create a new storage class with `mountWithWorkloadIdentityToken`: `"true"` and deploy your stateful set using this storage class.

The following example manifest configures a storage class to use workload identity to access Azure Files:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi-wi
provisioner: file.csi.azure.com
parameters:
  resourceGroup: EXISTING_RESOURCE_GROUP_NAME   # optional, node resource group by default if it's not provided
  storageAccount: EXISTING_STORAGE_ACCOUNT_NAME # optional, a new account will be created if it's not provided
  mountWithWorkloadIdentityToken: "true"
    # optional, clientID of the managed identity, kubelet identity would be used by default if it's not provided
  clientID: "xxxxx-xxxx-xxx-xxx-xxxxxxx"
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
mountOptions:
  - dir_mode=0777  # modify this permission if you want to enhance the security
  - file_mode=0777
  - mfsymlinks
  - cache=strict  # https://linux.die.net/man/8/mount.cifs
  - nosharesock  # reduce probability of reconnect race
  - actimeo=30  # reduce latency for metadata-heavy workload
  - nobrl  # disable sending byte range lock requests to the server
```

### Enable workload identity for static PVs with Azure Files
To use workload identity with statically provisioned Azure Files persistent volumes, ensure the following configuration:

1. Enable the SMBOauth on the storage account by running:
   ```bash
   az storage account update --name <account-name> --resource-group <resource-group-name> --enable-smb-oauth true
   ```
1. Create a PV with `mountWithWorkloadIdentityToken`: `"true"` specified and mount the PV to your application pod.

The following example manifest configures a PV to use workload identity to access Azure Files:

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
    mountWithWorkloadIdentityToken: "true"
    # optional, clientID of the managed identity, kubelet identity would be used by default if it's empty
    clientID: "xxxxx-xxxx-xxx-xxx-xxxxxxx"
```

## Create a static PV with Azure Files

The following sections provide instructions for creating a static PV with Azure Files. A static PV is a persistent volume that an administrator creates manually. This PV is available for use by pods in the cluster. To use a static PV, you create a PVC that references the PV, and then create a pod that references the PVC.

### Storage class parameters for static PVs with Azure Files

The following table includes parameters you can use to define a custom storage class for your static PVCs with Azure Files:

| Name | Meaning | Available values | Required | Default value |
| ---- | ------- | ---------------- | -------- | ------------- |
| `volumeAttributes.resourceGroup` | Specify an Azure resource group name. | myResourceGroup | No | If empty, driver uses the same resource group name as current cluster. |
| `volumeAttributes.storageAccount` | Specify an existing Azure storage account name. | storageAccountName | Yes | |
| `volumeAttributes.shareName` | Specify an Azure file share name. | fileShareName | Yes | |
| `volumeAttributes.folderName` | Specify a folder name in Azure file share. | folderName | No | If folder name doesn't exist in file share, mount would fail. |
| `volumeAttributes.protocol` | Specify file share protocol. | `smb`, `nfs` | No | `smb` |
| `volumeAttributes.server` | Specify Azure storage account server address | Existing server address, for example `accountname.privatelink.file.core.windows.net`. | No | If empty, driver uses default `accountname.file.core.windows.net` or other sovereign cloud account address. |
| --- | **The following parameters are only for SMB protocol** | --- | --- | --- |
| `volumeAttributes.secretName` | Specify a secret name that stores storage account name and key. | | No | |
| `volumeAttributes.secretNamespace` | Specify a secret namespace. | `default`,`kube-system`, etc. | No | PVC namespace (`csi.storage.k8s.io/pvc/namespace`) |
| `nodeStageSecretRef.name` | Specify a secret name that stores storage account name and key. | Existing secret name. | No | If empty, driver uses kubelet identity to get account key. |
| `nodeStageSecretRef.namespace` | Specify a secret namespace. | Kubernetes namespace | No | |
| --- | **The following parameters are only for NFS protocol** | --- | --- | --- |
| `volumeAttributes.fsGroupChangePolicy` | Indicates how the driver changes a volume's ownership. Pod `securityContext.fsGroupChangePolicy` is ignored. | `OnRootMismatch` (default), `Always`, `None` | No | `OnRootMismatch` |
| `volumeAttributes.mountPermissions` | Specify mounted folder permissions. The default is `0777` | | No | |

### Create an Azure file share

Before you can use an Azure Files file share as a Kubernetes volume, you must create an Azure Storage account and the file share.

1. Get the node resource group name of your AKS cluster using the [`az aks show`][az-aks-show] command with the `--query nodeResourceGroup` parameter.

    ```azurecli-interactive
    az aks show --resource-group myResourceGroup --name myAKSCluster --query nodeResourceGroup -o tsv
    ```

    The output of the command resembles the following example:

    ```azurecli-interactive
    MC_myResourceGroup_myAKSCluster_eastus
    ```

1. Create a storage account using the [`az storage account create`][az-storage-account-create] command with the `--sku` parameter. The following command creates a storage account using the `Standard_LRS` SKU. Make sure to replace the following placeholders:

   - `myAKSStorageAccount` with the name of the storage account
   - `nodeResourceGroupName` with the name of the resource group that the AKS cluster nodes are hosted in
   - `location` with the name of the region to create the resource in. It should be the same region as the AKS cluster nodes.

    ```azurecli-interactive
    az storage account create --name myAKSStorageAccount --resource-group nodeResourceGroupName --location location --sku Standard_LRS
    ```

1. Export the connection string as an environment variable, which you use to create the file share, using the [`az storage account show-connection-string`][az-storage-account-show-connection-string] command. Make sure to replace `storageAccountName` and `resourceGroupName` with your storage account name and resource group name.

    ```azurecli-interactive
    export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name storageAccountName --resource-group resourceGroupName -o tsv)
    ```

    > [!NOTE]
    > Connection strings must be protected using key rotation or storage in an Azure Key Vault. For more information about connection strings, see [Configure Azure Storage connection strings](/azure/storage/common/storage-configure-connection-string) and [Manage storage account access keys](/azure/storage/common/storage-account-keys-manage). For production environments, Microsoft recommends using Microsoft Entra ID authentication. For more information, see [Authorize access to data in Azure Storage](/azure/storage/blobs/authorize-access-azure-active-directory).

1. Create the file share using the [`az storage share create`][az-storage-share-create] command. Make sure to replace `shareName` with your share name.

    ```azurecli-interactive
    az storage share create --name shareName --connection-string $AZURE_STORAGE_CONNECTION_STRING
    ```

1. Export the storage account key as an environment variable using the [`az storage account keys list`][az-storage-account-keys-list] command. Make sure to replace `storageAccountName` and `resourceGroupName` with your storage account name and resource group name.

    ```azurecli-interactive
    STORAGE_KEY=$(az storage account keys list --resource-group nodeResourceGroupName --account-name myAKSStorageAccount --query "[0].value" -o tsv)
    ```

1. Echo the storage account name and key using the following command. Make note of the storage account key, which you use to create a Kubernetes secret in the next step.

    ```bash
    echo Storage account key: $STORAGE_KEY
    ```

### Create a Kubernetes secret

Kubernetes needs credentials to access the file share created in the previous step. These credentials are stored in a [Kubernetes secret][kubernetes-secret], which is referenced when you create a Kubernetes pod.

- Create the secret using the `kubectl create secret` command. The following example creates a secret named _azure-secret_ and populates the _azurestorageaccountname_ and _azurestorageaccountkey_ from the previous step. To use an existing Azure storage account, provide the account name and key.

    ```bash
    kubectl create secret generic azure-secret --from-literal=azurestorageaccountname=myAKSStorageAccount --from-literal=azurestorageaccountkey=$STORAGE_KEY
    ```

### Mount file share as a persistent volume

1. Create a new file named `azurefiles-pv.yaml` and copy in the following contents. Under `csi`, update `resourceGroup`, `volumeHandle`, and `shareName`. For mount options, the default value for `fileMode` and `dirMode` is _0777_.

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
        # Canonical permissions: 0755/uid=1000/gid=1000 for least privilege.
        # Use 0777/uid=0/gid=0 only if app requires root or broad write access.
        - dir_mode=0755
        - file_mode=0755
        - uid=1000
        - gid=1000
        - mfsymlinks
        - cache=strict
        - nosharesock
        - actimeo=30
        - nobrl  # disable sending byte range lock requests to the server and for applications which have challenges with posix locks
    ```

1. Create the PV using the [`kubectl create`][kubectl-create] command.

    ```bash
    kubectl create -f azurefiles-pv.yaml
    ```

1. Create a new file named _azurefiles-mount-options-pvc.yaml_ and paste in the following contents. Make sure the `storageClassName` matches the name of your existing storage class, and the `volumeName` matches the name of the PV you created in the previous step.

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

    Your output should resemble the following example output, which shows that the PVC is in a `Bound` state, and it's bound to the PV named _azurefile_:

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

### Mount file share as an inline volume

> [!NOTE]
> To avoid performance issue, we recommend you use a persistent volume instead of an inline volume when numerous pods are accessing the same file share. Inline volume can only access secrets in the same namespace as the pod. To specify a different secret namespace, use a [persistent volume][persistent-volume].

To mount the Azure Files file share into your pod, you configure the volume in the container spec.

1. Create a new file named `azure-files-pod.yaml` and copy in the following contents. If you changed the name of the file share or secret name, update the `shareName` and `secretName`. You can also update the `mountPath`, which is the path where the Files share is mounted in the pod. For Windows Server containers, specify a `mountPath` using the Windows path convention, such as _'D:'_.

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
              mountOptions: 'dir_mode=0755,file_mode=0755,uid=1000,gid=1000,cache=strict,actimeo=30,nosharesock,nobrl'  # optional
    ```

1. Create the pod using the [`kubectl apply`][kubectl-apply] command.

    ```bash
    kubectl apply -f azure-files-pod.yaml
    ```

1. View the status of the pod using the [`kubectl describe`][kubectl-describe] command:

    ```bash
    kubectl describe pod mypod
    ```

## Related content

- [Use Azure tags in Azure Kubernetes Service (AKS)][use-tags]

<!-- LINKS -->
[kubernetes-secret]: https://kubernetes.io/docs/concepts/configuration/secret/
[smb-overview]: /windows/desktop/FileIO/microsoft-smb-protocol-and-cifs-protocol-overview
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[kubectl-create]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#create
[data-plane-api]: https://pkg.go.dev/github.com/Azure/azure-sdk-for-go/sdk/storage/azblob
[kubectl-describe]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#describe
[kubectl-delete]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#delete
[access-modes]: https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes
[azure-storage-account]: /azure/storage/common/storage-introduction
[install-azure-cli]: /cli/azure/install-azure-cli
[persistent-volume]: #mount-file-share-as-a-persistent-volume
[use-tags]: use-tags.md
[node-resource-group]: faq.yml
[storage-skus]: /azure/storage/common/storage-redundancy
[az-aks-show]: /cli/azure/aks#az-aks-show
[az-storage-share-create]: /cli/azure/storage/share#az-storage-share-create
[storage-tiers]: /azure/storage/files/storage-files-planning#storage-tiers
[access-tiers-overview]: /azure/storage/blobs/access-tiers-overview
[tag-resources]: /azure/azure-resource-manager/management/tag-resources
[azure-files-usage]: /azure/storage/files/understand-performance#choosing-a-performance-tier-based-on-usage-patterns
[az-storage-account-create]: /cli/azure/storage/account#az-storage-account-create
[storage-account-private-endpoint]: /azure/storage/common/storage-private-endpoints
[nfs-overview]:/windows-server/storage/nfs/nfs-overview
[persistent-volume-claim-overview]: concepts-storage.md#persistent-volume-claims
[azure-private-endpoint-dns]: /azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration
[nfs-file-share-mount-options]: /azure/storage/files/storage-files-how-to-mount-nfs-shares#mount-options
