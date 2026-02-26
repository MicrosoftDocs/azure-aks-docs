---
title: Create and Manage Persistent Volumes with Azure Blob Storage in Azure Kubernetes Service (AKS)
description: Learn how to create and manage persistent volumes using Azure Blob storage with the Container Storage Interface (CSI) driver in Azure Kubernetes Service (AKS) to provide scalable and reliable storage for your containerized applications.
ms.topic: how-to
ms.subservice: aks-storage
ms.service: azure-kubernetes-service
ms.date: 01/08/2025
author: schaffererin
ms.author: schaffererin
# Customer intent: "As a Kubernetes administrator, I want to learn how to create and manage persistent volumes using Azure Storage CSI drivers in Azure Kubernetes Service (AKS) so that I can provide scalable and reliable storage solutions for my containerized applications."
---

# Create and manage persistent volumes (PVs) with Azure Blob storage in Azure Kubernetes Service (AKS)

If multiple pods need concurrent access to the same storage volume, you can use Azure Blob storage to connect using [blobfuse][blobfuse-overview] or [Network File System (NFS)][nfs-overview].

This article shows you how to dynamically and statically create Azure Blob storage containers for use by multiple pods in an Azure Kubernetes Service (AKS) cluster.

## Prerequisites

- The [Azure Blob storage CSI driver](./csi-storage-drivers.md) enabled on your AKS cluster.
- To support an [Azure DataLake Gen2 storage account][azure-datalake-storage-account] when using blobfuse mount, you need to do the following:

  - To create an ADLS account using the driver in dynamic provisioning, specify `isHnsEnabled: "true"` in the storage class parameters.
  - To enable blobfuse access to an ADLS account in static provisioning, specify the mount option `--use-adls=true` in the persistent volume.
  - If you're going to enable a storage account with Hierarchical Namespace, existing persistent volumes should be remounted with `--use-adls=true` mount option.

- By default, the blobfuse cache is located in the `/mnt` directory. If the VM SKU provides a temporary disk, the `/mnt` directory is mounted on the temporary disk. However, if the VM SKU doesn't provide a temporary disk, the `/mnt` directory is mounted on the OS disk, you can set `--tmp-path=` mount option to specify a different cache directory.

## Use built-in storage classes to create dynamic PVs with Azure Blob storage

A storage class is used to define how an Azure Blob storage container is created. A storage account is automatically created in the node resource group for use with the storage class to hold the Azure Blob storage container. When you use storage CSI drivers on AKS, there are two extra built-in `StorageClasses` that use the Azure Blob storage CSI driver.

The reclaim policy on both storage classes ensures that the underlying Azure Blob storage is deleted when the respective PV is deleted. The storage classes also configure the container to be expandable by default, as the `set allowVolumeExpansion` parameter is set to **true**.

> [!NOTE]
> Shrinking persistent volumes isn't supported.

You can select one of the following [Azure storage redundancy SKUs][storage-skus] for the `skuname` parameter in the storage class definition:

- **Standard_LRS**: Standard locally redundant storage
- **Premium_LRS**: Premium locally redundant storage
- **Standard_ZRS**: Standard zone redundant storage
- **Premium_ZRS**: Premium zone redundant storage
- **Standard_GRS**: Standard geo-redundant storage
- **Standard_RAGRS**: Standard read-access geo-redundant storage

## Create custom storage classes for dynamic PVs with Azure Blob storage

The default storage classes are suitable for most scenarios. In some cases, you might want to have your own storage class customized with your own parameters. In this section, we provide two examples: one using [NFS protocol](#custom-storage-class-example-using-nfs-protocol) and one using [blobfuse](#custom-storage-class-example-using-blobfuse).

### Custom storage class example using NFS protocol

The manifest in this example mounts a blob storage container using the NFS protocol. You can use it to add the `tags`  parameter.

1. Create a file named `blob-nfs-sc.yaml` and paste in the following example manifest:

    ```yaml
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

1. Create the storage class using the [`kubectl apply`][kubectl-apply] command:

    ```bash
    kubectl apply -f blob-nfs-sc.yaml
    ```

    Your output should resemble the following example output:

    ```output
    storageclass.storage.k8s.io/blob-nfs-premium created
    ```

### Custom storage class example using blobfuse

The manifest in this example uses blobfuse and mounts a Blob storage container. You can use it to update the `skuName` parameter.

1. Create a file named `blobfuse-sc.yaml` and paste in the following example manifest:

    ```yaml
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

1. Create the storage class using the [`kubectl apply`][kubectl-apply] command:

    ```bash
    kubectl apply -f blobfuse-sc.yaml
    ```

    Your output should resemble the following example output:

    ```output
    storageclass.storage.k8s.io/blob-fuse-premium created
    ```

## Storage class parameters for dynamic PVs with Azure Blob storage

The following table includes parameters you can use to define a custom storage class for your persistent volume claims (PVCs) with Azure Blob storage:

| Name | Meaning | Available values | Required | Default value |
| ---- | ------- | ---------------- | -------- | ------------- |
| `skuName` | Specify an Azure storage account type (alias: `storageAccountType`). | `Standard_LRS`, `Premium_LRS`, `Standard_GRS`, `Standard_RAGRS` | No | `Standard_LRS` |
| `location` | Specify an Azure location. | `eastus` | No | If empty, driver uses the same location name as current cluster. |
| `resourceGroup` | Specify an Azure resource group name. | myResourceGroup | No | If empty, driver uses the same resource group name as current cluster. |
| `storageAccount` | Specify an Azure storage account name.| storageAccountName | No | When a specific storage account name isn't provided, the driver looks for a suitable storage account that matches the account settings within the same resource group. If it fails to find a matching storage account, it creates a new one. However, if a storage account name is specified, the storage account must already exist. |
| `networkEndpointType` | Specify network endpoint type for the storage account created by driver. If privateEndpoint is specified, a [private endpoint][storage-account-private-endpoint] is created for the storage account. For other cases, a service endpoint will be created for NFS protocol. | `privateEndpoint` | No | For an AKS cluster, add the AKS cluster name to the Contributor role in the resource group hosting the VNet. |
| `protocol` | Specify blobfuse mount or NFSv3 mount. | `fuse`, `nfs` | No | `fuse` |
| `containerName` | Specify the existing container (directory) name. | container | No | If empty, driver creates a new container name, starting with `pvc-fuse` for blobfuse or `pvc-nfs` for NFS v3. |
| `containerNamePrefix` | Specify Azure storage directory prefix created by driver. | my |Can only contain lowercase letters, numbers, hyphens, and length should be fewer than 21 characters. | No |
| `server` | Specify Azure storage account domain name. | Existing storage account DNS domain name, for example `<storage-account>.blob.core.windows.net`. | No | If empty, driver uses default `<storage-account>.blob.core.windows.net` or other sovereign cloud storage account DNS domain name. |
| `allowBlobPublicAccess` | Allow or disallow public access to all blobs or containers for storage account created by driver. | `true`,`false` | No | `false` |
| `storageEndpointSuffix` | Specify Azure storage endpoint suffix. | `core.windows.net` | No | If empty, driver uses default storage endpoint suffix according to cloud environment. |
| `tags` | [Tags][az-tags] would be created in new storage account. | Tag format: 'foo=aaa,bar=bbb' | No | "" |
| `matchTags` | Match tags when driver tries to find a suitable storage account. | `true`,`false` | No | `false` |
| --- | **The following parameters are only for blobfuse** | --- | --- | --- |
| `subscriptionID` | Specify Azure subscription ID where blob storage directory will be created. | Azure subscription ID | No | If not empty, `resourceGroup` must be provided. |
| `storeAccountKey` | Specify store account key to Kubernetes secret. <br><br> Note: <br> `false` means driver uses kubelet identity to get account key. | `true`,`false` | No | `true` |
| `secretName` | Specify secret name to store account key. | | No | |
| `secretNamespace` | Specify the namespace of secret to store account key. | `default`,`kube-system`, etc. | No | PVC namespace |
| `isHnsEnabled` | Enable `Hierarchical namespace` for Azure Data Lake storage account. | `true`,`false` | No | `false` |
| --- | **The following parameters are only for NFS protocol** | --- | --- | --- |
| `mountPermissions` | Specify mounted folder permissions. | The default is `0777`. If set to `0`, driver won't perform `chmod` after mount. | No | `0777` |

> [!NOTE]
> If the storage account is created by the driver, then you only need to specify `networkEndpointType: privateEndpoint` parameter in storage class. The CSI driver creates the private endpoint and private DNS zone (named `privatelink.blob.core.windows.net`) together with the account. If you bring your own storage account, then you need to [create the private endpoint][storage-account-private-endpoint] for the storage account. If you're using Azure Blob storage in a network isolated cluster, you must create a custom storage class with "networkEndpointType: privateEndpoint". You can use the following example manifest as a reference:
>
> ```yaml
> apiVersion: storage.k8s.io/v1
> kind: StorageClass
> metadata:
>   name: blob-fuse
> provisioner: blob.csi.azure.com
> parameters:
>   skuName: Premium_LRS  # available values: Standard_LRS, Premium_LRS, Standard_GRS, Standard_RAGRS, Standard_ZRS, Premium_ZRS
>   protocol: fuse2
>   networkEndpointType: privateEndpoint
> reclaimPolicy: Delete
> volumeBindingMode: Immediate
> allowVolumeExpansion: true
> mountOptions:
>   - -o allow_other
>   - --file-cache-timeout-in-seconds=120
>   - --use-attr-cache=true
>   - --cancel-list-on-mount-seconds=10  # prevent billing charges on mounting
>   - -o attr_timeout=120
>   - -o entry_timeout=120
>   - -o negative_timeout=120
>   - --log-level=LOG_WARNING  # LOG_WARNING, LOG_INFO, LOG_DEBUG
>   - --cache-size-mb=1000  # Default will be 80% of available memory, eviction will happen beyond that.
> ```

## Create a PVC with Azure Blob storage

A PVC uses the storage class object to dynamically provision an Azure Blob storage. You can use the example YAML manifest in this section to create a PVC that's _5 GB_ in size with _ReadWriteMany_ access. For more information on access modes, see [Kubernetes PV access modes][access-modes].

1. Create a file named `blob-nfs-pvc.yaml` and paste in the following YAML manifest:

    ```yaml
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

1. Create the PVC using the [`kubectl create`][kubectl-create] command:

    ```bash
    kubectl create -f blob-nfs-pvc.yaml
    ```

1. View the status of the PVC with the [`kubectl get pvc`][kubectl-get-pvc] command:

    ```bash
    kubectl get pvc azure-blob-storage
    ```

    Your output should resemble the following example output, which shows that the PVC is in a `Bound` state:

    ```bash
    NAME                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                AGE
    azure-blob-storage   Bound    pvc-aaaaaaaa-0000-1111-2222-bbbbbbbbbbbb   5Gi        RWX            azureblob-nfs-premium       92m
    ```

## Use a PVC in a pod to mount Azure Blob storage

The following YAML creates a pod that uses the persistent volume claim **azure-blob-storage** to mount the Azure Blob storage at the `/mnt/blob' path.

1. Create a file named `blob-nfs-pv` and paste in the following YAML manifest. Make sure the `claimName` matches the PVC created in the previous step.

    ```yaml
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

1. Create the pod using the [`kubectl apply`][kubectl-apply] command:

   ```bash
   kubectl apply -f blob-nfs-pv.yaml
   ```

1. Once the pod is successfully running, create a new file named `test.txt` using the following command:

    ```bash
    kubectl exec mypod -- touch /mnt/blob/test.txt
    ```

1. Validate the disk is correctly mounted using the following command to list the files in the mounted directory:

    ```bash
    kubectl exec mypod -- ls /mnt/blob
    ```

    Your output should resemble the following example output, which shows the `test.txt` file you created in the mounted Azure Blob storage:

    ```output
    test.txt
    ```

## Use a StatefulSet to manage the lifecycle of a volume with Azure Blob storage

To have a storage volume persist for your workload, you can use a StatefulSet. This makes it easier to match existing volumes to new pods that replace any that have failed. The following examples demonstrate how to set up a StatefulSet for Blob storage using the NFS protocol or Blobfuse.

### [NFS protocol](#tab/NFS)

> [!NOTE]
> IF you're using NFS protocol, your AKS cluster _control plane_ identity (that is, your AKS cluster name) needs to be added to the [Contributor](/azure/role-based-access-control/built-in-roles#contributor) role on the VNet and network security group.

1. Create a file named `azure-blob-nfs-ss.yaml` and paste in the following YAML manifest:

    ```yaml
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

1. Create the StatefulSet using the [`kubectl create`][kubectl-create] command:

    ```bash
    kubectl create -f azure-blob-nfs-ss.yaml
    ```

### [Blobfuse](#tab/Blobfuse)

1. Create a file named `azure-blobfuse-ss.yaml` and paste in the following YAML manifest:

    ```yaml
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

1. Create the StatefulSet using the [`kubectl create`][kubectl-create] command:

    ```bash
    kubectl create -f azure-blobfuse-ss.yaml
    ```

---

## Create a static PV with Azure Blob storage

The following sections provide instructions for creating a static PV with Azure Blob storage. A static PV is a persistent volume that an administrator creates manually. This PV is available for use by pods in the cluster. To use a static PV, you create a PVC that references the PV, and then create a pod that references the PVC.

### Storage class parameters for static PVs with Azure Blob storage

The following table includes parameters you can use to define a custom storage class for your static PVCs with Azure Blob storage:

| Name | Meaning | Available values | Required | Default value |
| ---- | ------- | ---------------- | -------- | ------------- |
| `volumeHandle` | Specify a value the driver can use to uniquely identify the storage blob container in the cluster. | A recommended way to produce a unique value is to combine the globally unique storage account name and container name: `{account-name}_{container-name}`.<br> Note: The `#`, `/` characters are reserved for internal use and can't be used in a volume handle. | Yes | |
| `volumeAttributes.resourceGroup` | Specify Azure resource group name. | myResourceGroup | No | If empty, driver uses the same resource group name as current cluster. |
| `volumeAttributes.storageAccount` | Specify an existing Azure storage account name. | storageAccountName | Yes | |
| `volumeAttributes.containerName` | Specify existing container name. | container | Yes | |
| `volumeAttributes.protocol` | Specify blobfuse mount or NFS v3 mount. | `fuse`, `nfs` | No | `fuse` |
| --- | **The following parameters are only for blobfuse** | --- | --- | --- |
| `volumeAttributes.secretName` | Secret name that stores storage account name and key (only applies for SMB). | | No | |
| `volumeAttributes.secretNamespace` | Specify namespace of secret to store account key. | `default` | No | PVC namespace |
| `nodeStageSecretRef.name` | Specify secret name that stores one of the following:<br> `azurestorageaccountkey`<br>`azurestorageaccountsastoken`<br>`msisecret`<br>`azurestoragespnclientsecret`. | | No | Existing Kubernetes secret name |
| `nodeStageSecretRef.namespace` | Specify the namespace of secret. | Kubernetes namespace | Yes | |
| --- | **The following parameters are only for NFS protocol** | --- | --- | --- |
| `volumeAttributes.mountPermissions` | Specify mounted folder permissions. | `0777` | No | |
| --- | **The following parameters are only for NFS VNet setting** | --- | --- | --- |
| `vnetResourceGroup` | Specify VNet resource group hosting virtual network. | myResourceGroup | No | If empty, driver uses the `vnetResourceGroup` value specified in the Azure cloud config file. |
| `vnetName` | Specify the virtual network name. | aksVNet | No | If empty, driver uses the `vnetName` value specified in the Azure cloud config file. |
| `subnetName` | Specify the existing subnet name of the agent node. | aksSubnet | No | if empty, driver will update all the subnets under the cluster virtual network. |
| --- | **The following parameters are only for feature: blobfuse<br> [Managed Identity and Service Principal Name authentication](https://github.com/Azure/azure-storage-fuse#environment-variables)** | --- | --- | --- |
| `volumeAttributes.AzureStorageAuthType` | Specify the authentication type. | `Key`, `SAS`, `MSI`, `SPN` | No | `Key` |
| `volumeAttributes.AzureStorageIdentityClientID` | Specify the Identity Client ID. | | No | |
| `volumeAttributes.AzureStorageIdentityResourceID` | Specify the Identity Resource ID. | | No | |
| `volumeAttributes.MSIEndpoint` | Specify the MSI endpoint. | | No | |
| `volumeAttributes.AzureStorageSPNClientID` | Specify the Azure Service Principal Name (SPN) Client ID. | | No | |
| `volumeAttributes.AzureStorageSPNTenantID` | Specify the Azure SPN Tenant ID. | | No | |
| `volumeAttributes.AzureStorageAADEndpoint` | Specify the Microsoft Entra endpoint. | | No | |
| --- | **The following parameters are only for feature: blobfuse read account key or SAS token from key vault** | --- | --- | --- |
| `volumeAttributes.keyVaultURL` | Specify Azure Key Vault DNS name. | {vault-name}.vault.azure.net | No | |
| `volumeAttributes.keyVaultSecretName` | Specify Azure Key Vault secret name. | Existing Azure Key Vault secret name. | No | |
| `volumeAttributes.keyVaultSecretVersion` | Azure Key Vault secret version. | Existing version | No | If empty, driver uses current version. |

### Create a Blob storage container

When you create an Azure Blob storage resource for use with AKS, you can create the resource in the node resource group. This approach allows the AKS cluster to access and manage the blob storage resource.

1. Get the node resource group name of your AKS cluster using the [`az aks show`][az-aks-show] command with the `--query nodeResourceGroup` parameter.

    ```azurecli-interactive
    az aks show --resource-group myResourceGroup --name myAKSCluster --query nodeResourceGroup -o tsv
    ```

    The output of the command resembles the following example:

    ```azurecli-interactive
    MC_myResourceGroup_myAKSCluster_eastus
    ```

1. Create a container for storing blobs following the steps in the [Manage blob storage][manage-blob-storage] to authorize access and then create the container.

### Mount volume

In this section, you mount the persistent volume using the NFS protocol or Blobfuse.

#### [NFS protocol](#tab/nfs)

Mounting Blob storage using the NFS v3 protocol doesn't authenticate using an account key. Your AKS cluster needs to reside in the same or peered virtual network as the agent node. The only way to secure the data in your storage account is by using a virtual network and other network security settings. For more information on how to set up NFS access to your storage account, see [Mount Blob Storage by using the Network File System (NFS) 3.0 protocol](/azure/storage/blobs/network-file-system-protocol-support-how-to).

The following example demonstrates how to mount a Blob storage container as a persistent volume using the NFS protocol.

1. Create a file named `pv-blob-nfs.yaml` and paste in the following YAML. Under `storageClass`, update `resourceGroup`, `storageAccount`, and `containerName`.

   > [!NOTE]
   > `volumeHandle` value should be a unique volumeID for every identical storage blob container in the cluster.
   > The character `#` and `/` are reserved for internal use and can't be used.

    ```yaml
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
   > While the [Kubernetes API](https://github.com/kubernetes/kubernetes/blob/release-1.26/pkg/apis/core/types.go#L303-L306) **capacity** attribute is mandatory, this value isn't used by the Azure Blob storage CSI driver because you can flexibly write data until you reach your storage account's capacity limit. The value of the `capacity` attribute is used only for size matching between PVs and PVCs. We recommend using a fictitious high value. The pod sees a mounted volume with a fictitious size of 5 Petabytes.

1. Create the PV using the [`kubectl create`][kubectl-create] command:

    ```bash
    kubectl create -f pv-blob-nfs.yaml
    ```

1. Create a file named `pvc-blob-nfs.yaml` and paste in the following YAML. Under `volumeName`, update the value to match the name of the PV created in the previous step.

    ```yaml
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

1. Create the PVC using the [`kubectl create`][kubectl-create] command:

    ```bash
    kubectl create -f pvc-blob-nfs.yaml
    ```

#### [Blobfuse](#tab/blobfuse)

Kubernetes needs credentials to access the Blob storage container created earlier, which is either an Azure access key or SAS tokens. These credentials are stored in a Kubernetes secret, which is referenced when you create a Kubernetes pod.

1. Use the `kubectl create secret command` to create the secret. You can authenticate using a Kubernetes secret or shared access signature (SAS) tokens.

    ```bash
    # Create a Secret object named azure-secret and populate the azurestorageaccountname and azurestorageaccountkey. You need to provide the account name and key from an existing Azure storage account.
    kubectl create secret generic azure-secret --from-literal azurestorageaccountname=NAME --from-literal azurestorageaccountkey="KEY" --type=Opaque

    # Create a Secret object named azure-sas-token and populate the azurestorageaccountname and azurestorageaccountsastoken. You need to provide the account name and shared access signature from an existing Azure storage account.
    kubectl create secret generic azure-sas-token --from-literal azurestorageaccountname=NAME --from-literal azurestorageaccountsastoken
    ="sastoken" --type=Opaque
    ```

1. Create a file named `pv-blobfuse.yaml` and paste in the following YAML manifest. Under `volumeAttributes`, update `containerName`. Under `nodeStateSecretRef`, update `name` with the name of the Secret object created earlier. For example:

   > [!NOTE]
   > `volumeHandle` value should be a unique volumeID for every identical storage blob container in the cluster.
   > The character `#` and `/` are reserved for internal use and can't be used.

    ```yaml
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

1. Create the PV using the [`kubectl create`][kubectl-create] command:

    ```bash
    kubectl create -f pv-blobfuse.yaml
    ```

1. Create a file named `pvc-blobfuse.yaml` and paste in the following YAML manifest. Under `volumeName`, update the value to match the name of the PV created in the previous step.

    ```yaml
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

1. Create the PVC using the [`kubectl create`][kubectl-create] command:

    ```bash
    kubectl create -f pvc-blobfuse.yaml
    ```

---

### Use the persistent volume

The following YAML creates a pod that uses the PV or PVC named **pvc-blob** created earlier to mount the Azure Blob storage at the `/mnt/blob` path.

1. Create a file named `nginx-pod-blob.yaml` and paste in the following YAML manifest. Make sure the `claimName` matches the PVC created in the previous step when creating a PV for NFS or Blobfuse.

    ```yaml
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

1. Create the pod and mount the PVC using the [`kubectl create`][kubectl-create] command:

    ```bash
    kubectl create -f nginx-pod-blob.yaml
    ```

1. Create an interactive shell session with the pod to verify the Blob storage is mounted correctly using the following `kubectl exec` command:

    ```bash
    kubectl exec -it nginx-blob -- df -h
    ```

    Your output should resemble the following example output, which shows the Blob storage is mounted at the `/mnt/blob` path:

    ```output
    Filesystem      Size  Used Avail Use% Mounted on
    ...
    blobfuse         14G   41M   13G   1% /mnt/blob
    ...
    ```

## Related content

- [Use Azure tags in Azure Kubernetes Service (AKS)][use-tags]

<!-- LINKS -->
[blobfuse-overview]: https://github.com/Azure/azure-storage-fuse
[nfs-overview]: https://en.wikipedia.org/wiki/Network_File_System
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-create]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#create
[az-aks-show]: /cli/azure/aks#az-aks-show
[az-tags]: /azure/azure-resource-manager/management/tag-resources
[azure-datalake-storage-account]: /azure/storage/blobs/upgrade-to-data-lake-storage-gen2-how-to
[storage-account-private-endpoint]: /azure/storage/common/storage-private-endpoints
[manage-blob-storage]: /azure/storage/blobs/blob-containers-cli
[access-modes]: https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes
[use-tags]: use-tags.md
[storage-skus]: /azure/storage/common/storage-redundancy
