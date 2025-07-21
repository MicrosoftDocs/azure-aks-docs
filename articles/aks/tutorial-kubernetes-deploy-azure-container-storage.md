---
title: Kubernetes on Azure tutorial - Use Azure Container Storage
description: In this Azure Kubernetes Service (AKS) tutorial, you learn how to deploy Azure Container Storage on an AKS cluster and create volumes.
ms.topic: tutorial
ms.date: 03/05/2025
author: khdownie
ms.author: kendownie
ms.custom: mvc, devx-track-azurecli

#Customer intent: As a developer or IT pro, I want to learn how to use Azure Container Storage with Azure Kubernetes Service (AKS) so that I can deploy container-native storage for stateful applications.
# Customer intent: As a developer or IT professional, I want to deploy Azure Container Storage on an Azure Kubernetes Service (AKS) cluster, so that I can manage container-native storage for stateful applications and optimize performance for various workloads.
---

# Tutorial - Deploy Azure Container Storage on an AKS cluster

This tutorial introduces Azure Container Storage and demonstrates how to deploy and manage container-native storage for applications running on Azure Kubernetes Service (AKS). If you don't want to deploy Azure Container Storage now, you can skip this tutorial and proceed directly to [Deploy an application in AKS][aks-tutorial-deploy-app]. You won't need Azure Container Storage for the basic storefront application in this tutorial series.

Azure Container Storage simplifies the management of stateful applications in Kubernetes by offering container-native storage tailored to a variety of workloads, including databases, analytics platforms, and high-performance applications.

By the end of this tutorial, you will:

> [!div class="checklist"]
>
> * Understand how Azure Container Storage supports diverse workloads in Kubernetes.
> * Explore multiple storage backend options to tailor storage to your application's needs.
> * Deploy Azure Container Storage on your AKS cluster and create a generic ephemeral volume.

## Before you begin

In previous tutorials, you created a container image, uploaded it to an ACR instance, and created an AKS cluster. Start with [Tutorial 1 - Prepare application for AKS][aks-tutorial-prepare-app] to follow along.

* This tutorial requires using the Azure CLI version 2.35.0 or later. Portal and PowerShell aren't currently supported for Azure Container Storage. Check your version with `az --version`. To install or upgrade, see [Install Azure CLI][azure-cli-install]. If you're using the Bash environment in Azure Cloud Shell, the latest version is already installed. 
* You must have an existing Linux-based AKS cluster with at least 3 nodes with [Storage optimized VM SKUs](/azure/virtual-machines/sizes/overview#storage-optimized) or [GPU accelerated VM SKUs](/azure/virtual-machines/sizes/overview#gpu-accelerated). See [Tutorial 3 - Create an AKS cluster][aks-tutorial-deploy-cluster].
* You'll need the Kubernetes command-line client, `kubectl`. It's already installed if you're using Azure Cloud Shell, or you can install it locally by running the `az aks install-cli` command.

## Install the Kubernetes extension

Add or upgrade to the latest version of `k8s-extension` by running the following command.

```azurecli-interactive
az extension add --upgrade --name k8s-extension
```

## Connect to the cluster and check node status

If you're not already connected to your cluster from the previous tutorial, run the following commands. If you're already connected, you can skip this section.

1.  Run the following command to connect to the cluster.

    ```azurecli-interactive
    az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
    ```

1. Verify the connection to your cluster using the `kubectl get` command. This command returns a list of the cluster nodes.

    ```azurecli-interactive
    kubectl get nodes
    ```

1. The following output example shows the nodes in your cluster. Make sure the status for all nodes shows *Ready*:

    ```output
    NAME                                STATUS   ROLES   AGE   VERSION
    aks-nodepool1-34832848-vmss000000   Ready    agent   80m   v1.30.9
    aks-nodepool1-34832848-vmss000001   Ready    agent   80m   v1.30.9
    aks-nodepool1-34832848-vmss000002   Ready    agent   80m   v1.30.9
    ```

## Choose a backing storage option

Azure Container Storage uses storage pools to provision and manage persistent and generic volumes. It offers a variety of back-end storage options for your storage pools, each suited for specific workloads. Selecting the right storage type is critical for optimizing workload performance, durability, and cost efficiency. For this tutorial, we'll use Ephemeral Disk with local NVMe as backing storage to create a generic ephemeral volume. However, we'll also explore the other backing storage options that allow you to create persistent volumes.

### Ephemeral Disk

Ephemeral Disk utilizes local storage resources on the AKS nodes (either local NVMe or temp SSD). It offers low sub-ms latency and high IOPS, but no data persistence if the VM restarts. Ephemeral Disk is best suited for applications such as Cassandra that prioritize speed over persistence, and is ideal for workloads with their own application-level replication.

You can use Ephemeral Disk to create either generic ephemeral volumes or persistent volumes, even though the data will be lost if the VM restarts.

### Azure Disks

Ideal for databases like PostgreSQL and MongoDB, Azure Disks offer durability, scalability, and multi-tiered performance options, including Premium SSD and Ultra SSD.

Azure Disks allow for automatic provisioning of storage volumes and include built-in redundancy and high availability.

### Azure Elastic SAN (preview)

Designed for shared storage needs and general-purpose databases requiring scalability and high availability, Azure Elastic SAN is a good fit for workloads such as CI/CD pipelines or large-scale data processing.

## Enable Azure Container Storage and create a storage pool

Run the following command to install Azure Container Storage on the cluster and create a Local NVMe storage pool.

```azurecli-interactive
az aks update -n myAKSCluster -g myResourceGroup --enable-azure-container-storage ephemeralDisk --storage-pool-option NVMe
```

The deployment should take less than 15 minutes.

### Verify the storage pool status

When deployment completes, the components for your chosen storage pool type will be enabled, and you'll have a default storage pool.

To get the list of available storage pools, run the following command:

```azurecli-interactive
kubectl get sp -n acstor
```

To check the status of a storage pool, run the following command:

```azurecli-interactive
kubectl describe sp <storage-pool-name> -n acstor
```

If the `Message` doesn't say `StoragePool is ready`, then your storage pool is still creating or ran into a problem.

## Display the available storage classes

When the storage pool is ready to use, you must select a storage class to define how storage is dynamically created when creating and deploying volumes.

Run `kubectl get sc` to display the available storage classes. You should see a storage class called `acstor-<storage-pool-name>`. Use this storage class in the next section to deploy a pod.

## Deploy a pod with a generic ephemeral volume

Create a pod using [Fio](https://github.com/axboe/fio) (Flexible I/O Tester) for benchmarking and workload simulation, that uses a generic ephemeral volume.

1. Use your favorite text editor to create a YAML manifest file such as `code acstor-pod.yaml`.

1. Paste in the following code and save the file.

   ```yml
   kind: Pod
   apiVersion: v1
   metadata:
     name: fiopod
   spec:
     nodeSelector:
       acstor.azure.com/io-engine: acstor
     containers:
       - name: fio
         image: nixery.dev/shell/fio
         args:
           - sleep
           - "1000000"
         volumeMounts:
           - mountPath: "/volume"
             name: ephemeralvolume
     volumes:
       - name: ephemeralvolume
         ephemeral:
           volumeClaimTemplate:
             metadata:
               labels:
                 type: my-ephemeral-volume
             spec:
               accessModes: [ "ReadWriteOnce" ]
               storageClassName: acstor-ephemeraldisk-nvme # replace with the name of your storage class if different
               resources:
                 requests:
                   storage: 1Gi
   ```

   If you change the storage size of the volume, make sure the size is less than the available capacity of a single node's ephemeral disk. Run `kubectl get diskpool -n acstor` to check the available capacity.

1. Apply the YAML manifest file to deploy the pod.
   
   ```azurecli-interactive
   kubectl apply -f acstor-pod.yaml
   ```
   
   You should see output similar to the following:
   
   ```output
   pod/fiopod created
   ```

1. Check that the pod is running and that the ephemeral volume claim has been bound successfully to the pod:

   ```azurecli-interactive
   kubectl describe pod fiopod
   kubectl describe pvc fiopod-ephemeralvolume
   ```

You've now deployed a pod that's using local NVMe as its storage, and you can use it for your Kubernetes workloads.

Verify the available capacity of ephemeral disks before provisioning additional volumes:

```azurecli-interactive
kubectl describe node <node-name>
```

To learn more about Azure Container Storage, including how to create persistent volumes, see [What is Azure Container Storage?][azure-container-storage]

## Clean up resources

You won't need Azure Container Storage for the rest of this tutorial series, so we recommend deleting it now to avoid incurring unnecessary Azure charges.

1. Delete the pod.

   ```azurecli-interactive
   kubectl delete pod fiopod
   ```

1. Delete the storage pool.

   ```azurecli-interactive
   kubectl delete sp -n acstor <storage-pool-name>
   ```

1. Delete the extension instance.

   ```azurecli-interactive
   az aks update -n myAKSCluster -g myResourceGroup --disable-azure-container-storage all
   ```

## Next step

In this tutorial, you deployed Azure Container Storage on your AKS cluster. You learned how to:

> [!div class="checklist"]
>
> * Enable Azure Container Storage on your AKS cluster.
> * Choose a backing storage type and create a storage pool.
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
