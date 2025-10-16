---
title: Enable Ultra Disk support on Azure Kubernetes Service (AKS)
description: Learn how to enable and configure Ultra Disks in an Azure Kubernetes Service (AKS) cluster
ms.topic: how-to
ms.date: 10/08/2025
author: schaffererin
ms.author: schaffererin


# Customer intent: As a Kubernetes administrator, I want to enable Azure ultra disks on an AKS cluster, so that I can improve the performance of my stateful applications with high throughput, low latency, and the ability to dynamically adjust disk performance.
---

# Use Azure ultra disks on Azure Kubernetes Service

[Azure ultra disks][ultra-disk-overview] offer high throughput, high IOPS, and consistent low latency disk storage for your stateful applications. One major benefit of ultra disks is the ability to dynamically change the performance of the SSD along with your workloads without the need to restart your agent nodes. Ultra disks are suited for data-intensive workloads.

This article describes how to configure a new or existing AKS cluster to use Azure ultra disks.

## Before you begin

This feature can only be set at cluster creation or when creating a node pool.

### Limitations

- Azure ultra disks require node pools deployed in availability zones and regions that support these disks, and are only supported by specific virtual machine (VM) series. Review the corresponding table under the  [Ultra disk limitations][ultra-disk-limitations] section for more information.
- Ultra disks can't be used with some features and functionality, such as availability sets or Azure Disk Encryption. Review the [Ultra disk limitations][ultra-disk-limitations] for the latest information.

## Create a cluster that can use ultra disks

Create a resource group for the cluster.

```azurecli-interactive
az group create --name MyResourceGroup --location westus2
```

Create an AKS cluster that's able to use Azure ultra disks with the following CLI commands. Use the `--enable-ultra-ssd` parameter to set the `EnableUltraSSD` feature.

```azurecli-interactive
az aks create \
  --resource-group MyResourceGroup \
  --name myAKSCluster \
  --location westus2 \
  --node-vm-size Standard_D2s_v3 \
  --zones 1 \
  --node-count 2 \
  --enable-ultra-ssd \
  --generate-ssh-keys
```

If you want to create a cluster without ultra disk support, you can do so by omitting the `--enable-ultra-ssd` parameter.

After a successful cluster deployment, run the following command that sets the context to your new cluster.

```azurecli-interactive
az aks get-credentials --resource-group MyResourceGroup --name myAKSCluster
```

## Enable ultra disks on an existing cluster

You can enable ultra disks on an existing cluster by adding a new node pool to your cluster that supports ultra disks. Configure a new node pool to use ultra disks by using the `--enable-ultra-ssd` parameter with the [`az aks nodepool add`][az-aks-nodepool-add] command.

If you want to create new node pools without support for ultra disks, you can do so by excluding the `--enable-ultra-ssd` parameter.

## Use ultra disks dynamically with a storage class

To use ultra disks in your deployments or stateful sets, you can use a [storage class for dynamic provisioning][azure-disk-volume].

### Create the storage class

A storage class is used to define how a unit of storage is dynamically created with a persistent volume. For more information on Kubernetes storage classes, see [Kubernetes storage classes][kubernetes-storage-classes]. In this example, you create a storage class that references ultra disks.

1. Create a file named `azure-ultra-disk-sc.yaml` and copy in the following manifest:

    ```yaml
    kind: StorageClass
    apiVersion: storage.k8s.io/v1
    metadata:
      name: ultra-disk-sc
    provisioner: disk.csi.azure.com # replace with "kubernetes.io/azure-disk" if aks version is less than 1.21
    volumeBindingMode: WaitForFirstConsumer # optional, but recommended if you want to wait until the pod that will use this disk is created
    parameters:
      skuname: UltraSSD_LRS
      kind: managed
      cachingMode: None
      diskIopsReadWrite: "2000"  # minimum value: 2 IOPS/GiB
      diskMbpsReadWrite: "320"   # minimum value: 0.032/GiB
    ```

1. Create the storage class using the [`kubectl apply`][kubectl-apply] command and specify your `azure-ultra-disk-sc.yaml` file.

    ```bash
    kubectl apply -f azure-ultra-disk-sc.yaml
    ```

    Your output should resemble the following example output:

    ```console
    storageclass.storage.k8s.io/ultra-disk-sc created
    ```

## Create a persistent volume claim

A persistent volume claim (PVC) is used to automatically provision storage based on a storage class. In this case, a PVC can use the previously created storage class to create an ultra disk.

1. Create a file named `azure-ultra-disk-pvc.yaml` and copy in the following manifest:

    ```yaml
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: ultra-disk
    spec:
      accessModes:
      - ReadWriteOnce
      storageClassName: ultra-disk-sc
      resources:
        requests:
          storage: 1000Gi
    ```

    The claim requests a disk named `ultra-disk` that is `1000 GB` in size with `ReadWriteOnce` access. The `ultra-disk-sc` storage class is specified as the storage class.

1. Create the persistent volume claim using the [`kubectl apply`][kubectl-apply] command and specify your `azure-ultra-disk-pvc.yaml` file.

    ```bash
    kubectl apply -f azure-ultra-disk-pvc.yaml
    ```

    Your output should resemble the following example output:

    ```console
    persistentvolumeclaim/ultra-disk created
    ```

## Use the persistent volume

After the persistent volume claim is created and the disk successfully provisioned, a pod can be created with access to the disk. The following manifest creates a basic NGINX pod that uses the persistent volume claim named `ultra-disk` to mount the Azure disk at the path `/mnt/azure`.

1. Create a file named `nginx-ultra.yaml` and copy in the following manifest:

    ```yaml
    kind: Pod
    apiVersion: v1
    metadata:
      name: nginx-ultra
    spec:
      containers:
      - name: nginx-ultra
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
      volumes:
        - name: volume
          persistentVolumeClaim:
            claimName: ultra-disk
    ```

1. Create the pod using [`kubectl apply`][kubectl-apply] command and specify your `nginx-ultra.yaml` file.

    ```console
    kubectl apply -f nginx-ultra.yaml
    ```

    Your output should resemble the following example output:

    ```console
    pod/nginx-ultra created
    ```

    You now have a running pod with your Azure disk mounted in the `/mnt/azure` directory.

1. See your configuration details using the `kubectl describe pod` command and specify your `nginx-ultra.yaml` file.

    ```bash
    kubectl describe pod nginx-ultra
    ```

    Your output should resemble the following example output:

    ```console
    [...]
    Volumes:
      volume:
        Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
        ClaimName:  ultra-disk
        ReadOnly:   false
      kube-api-access-sszt8:
        Type:                    Projected (a volume that contains injected data from multiple sources)
        TokenExpirationSeconds:  3607
    [...]
    Events:
      Type    Reason                  Age   From                     Message
      ----    ------                  ----  ----                     -------
      Normal  Scheduled               29s   default-scheduler        Successfully assigned default/nginx-ultra to aks-nodepool1-13380798-vmss000001
      Normal  SuccessfulAttachVolume  9s    attachdetach-controller  AttachVolume.Attach succeeded for volume "pvc-a6a6a6a6-bbbb-cccc-dddd-e7e7e7e7e7e7"
    ```

## Next steps

- For more about ultra disks, see [Using Azure ultra disks](/azure/virtual-machines/disks-enable-ultra-ssd).
- For more about storage best practices, see [Best practices for storage and backups in AKS][operator-best-practices-storage].

<!-- LINKS - external -->
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubernetes-storage-classes]: https://kubernetes.io/docs/concepts/storage/storage-classes/

<!-- LINKS - internal -->
[ultra-disk-overview]: /azure/virtual-machines/disks-types#ultra-disks
[ultra-disk-limitations]: /azure/virtual-machines/disks-types#ultra-disk-limitations
[azure-disk-volume]: azure-disk-csi.md
[operator-best-practices-storage]: operator-best-practices-storage.md
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az_aks_nodepool_add
