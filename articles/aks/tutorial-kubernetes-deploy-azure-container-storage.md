---
title: Kubernetes on Azure tutorial - Use Azure Container Storage
description: In this Azure Kubernetes Service (AKS) tutorial, you learn how to deploy Azure Container Storage on an AKS cluster and create volumes.
ms.topic: tutorial
ms.date: 02/18/2026
author: khdownie
ms.author: kendownie
ms.custom: mvc, devx-track-azurecli

# Customer intent: As a developer or IT pro, I want to learn how to use Azure Container Storage with Azure Kubernetes Service (AKS) so that I can deploy container-native storage for stateful applications.

---

# Tutorial - Deploy Azure Container Storage on an AKS cluster

This tutorial introduces Azure Container Storage and demonstrates how to deploy and manage container-native storage for applications running on Azure Kubernetes Service (AKS). If you don't want to deploy Azure Container Storage now, you can skip this tutorial and proceed directly to [Deploy an application in AKS][aks-tutorial-deploy-app]. You won't need Azure Container Storage for the basic storefront application in this tutorial series.

Azure Container Storage simplifies the management of stateful applications in Kubernetes by offering container-native storage tailored to a variety of workloads, including databases, analytics platforms, and high-performance applications.

By the end of this tutorial, you will:

> [!div class="checklist"]
>
> * Understand how Azure Container Storage supports diverse workloads in Kubernetes.
> * Deploy Azure Container Storage on your AKS cluster.
> * Create a generic ephemeral volume.

## Before you begin

In previous tutorials, you created a container image, uploaded it to an ACR instance, and created an AKS cluster. Start with [Tutorial 1 - Prepare application for AKS][aks-tutorial-prepare-app] to follow along.

* Confirm that your target region is supported by reviewing the [Azure Container Storage regional availability][azure-container-storage-availability].

* Install the latest version of the [Azure CLI](/cli/azure/install-azure-cli) (2.83.0 or later), then sign in with `az login`. Don't use Azure Cloud Shell, because `az upgrade` isn't available.

* Install the Kubernetes command-line client, `kubectl`. You can install it locally by running `az aks install-cli`.

> [!IMPORTANT]
> This tutorial applies to [Azure Container Storage (version 2.x.x)][azure-container-storage], which supports local NVMe disk and Azure Elastic SAN as backing storage types. This tutorial uses local NVMe and creates a generic ephemeral volume. To use local NVMe, your VM SKU must support local NVMe data disks, such as [storage-optimized](/azure/virtual-machines/sizes/overview#storage-optimized) or [GPU-accelerated](/azure/virtual-machines/sizes/overview#gpu-accelerated) VMs.
> 
> If you'd prefer to use Azure Elastic SAN, see [Use Azure Container Storage with Azure Elastic SAN][azure-container-storage-elastic-san].

## Install the Kubernetes extension

Add or upgrade to the latest version of `k8s-extension` by running the following command.

```azurecli
az extension add --upgrade --name k8s-extension
```

## Enable Azure Container Storage on your AKS cluster

Run the following command to enable Azure Container Storage on an existing AKS cluster using local NVMe. Azure Container Storage installs the latest available version and updates itself automatically. Manual version selection isn't supported.

```azurecli
az aks update -n myAKSCluster -g myResourceGroup --enable-azure-container-storage ephemeralDisk
```

The deployment can take up to five minutes. When it completes, the AKS cluster has Azure Container Storage installed and the components for local NVMe storage type deployed. It also creates the default `local` storage class.

## Connect to the cluster and verify status

If you're not already connected to your cluster from the previous tutorial, run the following commands. If you're already connected, you can skip this section.

1. Download the cluster credentials and configure the Kubernetes CLI to use them. By default, credentials are stored in `~/.kube/config`. Provide a different path by using the `--file` argument if needed.

    ```azurecli
    az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
    ```

2. Verify the connection by listing the cluster nodes.

    ```azurecli
    kubectl get nodes
    ```

3. Make sure all nodes report a status of `Ready`.

## Verify the storage class

Run the following command to verify that the storage class is created:

```azurecli
kubectl get storageclass local
```

You should see output similar to:

```output
NAME    PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local   localdisk.csi.acstor.io    Delete          WaitForFirstConsumer   true                   10s
```

## Deploy a pod with generic ephemeral volume

Create a pod using [Fio](https://github.com/axboe/fio) (Flexible I/O Tester) for benchmarking and workload simulation that uses a generic ephemeral volume.

1. Use your favorite text editor to create a YAML manifest file such as `code fiopod.yaml`.

1. Paste in the following code and save the file.

   ```yml
   kind: Pod
   apiVersion: v1
   metadata:
     name: fiopod
   spec:
     nodeSelector:
       "kubernetes.io/os": linux
     containers:
       - name: fio
         image: mayadata/fio
         args: ["sleep", "1000000"]
         volumeMounts:
           - mountPath: "/volume"
             name: ephemeralvolume
     volumes:
       - name: ephemeralvolume
         ephemeral:
           volumeClaimTemplate:
             spec:
               volumeMode: Filesystem
               accessModes: ["ReadWriteOnce"]
               storageClassName: local
               resources:
                 requests:
                   storage: 10Gi
   ```

1. Apply the YAML manifest file to deploy the pod.
   
   ```azurecli
   kubectl apply -f fiopod.yaml
   ```

## Verify the deployment and run benchmarks

Check that the pod is running:

```azurecli
kubectl get pod fiopod
```

You should see the pod in the Running state. Once running, you can execute a Fio benchmark test:

```azurecli
kubectl exec -it fiopod -- fio --name=benchtest --size=800m --filename=/volume/test --direct=1 --rw=randrw --ioengine=libaio --bs=4k --iodepth=16 --numjobs=8 --time_based --runtime=60
```

You've now deployed a pod that's using local NVMe as its storage, and you can use it for your Kubernetes workloads.

To learn more about Azure Container Storage, see [What is Azure Container Storage?][azure-container-storage]

## Clean up resources

You won't need Azure Container Storage for the rest of this tutorial series, so we recommend deleting it now to avoid incurring unnecessary Azure charges.

1. Delete the pod.

   ```azurecli
   kubectl delete pod fiopod
   ```

1. Delete the generic ephemeral volume.

   ```azurecli
   kubectl delete pv ephemeralvolume
   ```

1. Delete the extension instance.

   ```azurecli
   az aks update -n myAKSCluster -g myResourceGroup --disable-azure-container-storage
   ```

## Next step

In this tutorial, you deployed Azure Container Storage on your AKS cluster. You learned how to:

> [!div class="checklist"]
>
> * Enable Azure Container Storage on your AKS cluster.
> * Deploy a pod with a generic ephemeral volume.

In the next tutorial, you learn how to deploy an application to your cluster.

> [!div class="nextstepaction"]
> [Deploy an application in AKS][aks-tutorial-deploy-app]

<!-- LINKS - internal -->
[aks-tutorial-deploy-app]: ./tutorial-kubernetes-deploy-application.md
[aks-tutorial-prepare-app]: ./tutorial-kubernetes-prepare-app.md
[aks-tutorial-deploy-cluster]: ./tutorial-kubernetes-deploy-cluster.md
[azure-cli-install]: /cli/azure/install-azure-cli
[azure-container-storage]: /azure/storage/container-storage/container-storage-introduction
[azure-container-storage-availability]: /azure/storage/container-storage/container-storage-introduction#regional-availability
[azure-container-storage-elastic-san]: /azure/storage/container-storage/use-container-storage-with-elastic-san