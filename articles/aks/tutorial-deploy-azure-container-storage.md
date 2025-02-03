---
title: Kubernetes on Azure tutorial - Use Azure Container Storage
description: In this Azure Kubernetes Service (AKS) tutorial, you learn how to deploy Azure Container Storage on an AKS cluster for persistent volumes.
ms.topic: tutorial
ms.date: 02/03/2025
author: khdownie
ms.author: kendownie

ms.custom: mvc, devx-track-azurecli, devx-track-azurepowershell, devx-track-extended-azdevcli

#Customer intent: As a developer or IT pro, I want to learn how to use Azure Container Storage with Azure Kubernetes Service (AKS) so that I can deploy persistent storage for stateful applications.
---

# Tutorial - Create an Azure Kubernetes Service (AKS) cluster

This tutorial introduces Azure Container Storage and demonstrates how to deploy and manage persistent storage for applications running on Azure Kubernetes Service (AKS). 

Azure Container Storage simplifies the management of stateful applications in Kubernetes by offering robust, scalable, and secure storage solutions tailored to a variety of workloads, including databases, analytics platforms, and high-performance applications. 

By the end of this tutorial, you will: 

> [!div class="checklist"]
>
> * Understand how Azure Container Storage supports diverse workloads in Kubernetes.
> * Explore multiple storage backend options to tailor storage to your application's needs.
> * Deploy Azure Container Storage on your AKS cluster.
> * Integrate storage with a sample application (maybe not yet? this comes in a later tutorial?)

## Before you begin

In previous tutorials, you created a container image, uploaded it to an ACR instance, and created an AKS cluster. Start with [Tutorial 1 - Prepare application for AKS][aks-tutorial-prepare-app] to follow along.

* This tutorial requires that you're running the Azure CLI version 2.35.0 or later. Portal and PowerShell aren't currently supported for Azure Container Storage. Check your version with `az --version`. To install or upgrade, see [Install Azure CLI][azure-cli-install].
* You must have `kubectl` installed and have an existing Linux-based AKS cluster with at least 4 nodes. See [Tutorial 3 - Create an AKS cluster][aks-tutorial-deploy-cluster].

## Install the Kubernetes extension

Add or upgrade to the latest version of `k8s-extension` by running the following command.

```azurecli-interactive
az extension add --upgrade --name k8s-extension
```

## Set your Azure subscription context

If you haven't already done so, set your Azure subscription context using the `az account set` command. You can view the subscription IDs for all the subscriptions you have access to by running the `az account list --output table` command. Remember to replace `<subscription-id>` with your subscription ID.

```azurecli-interactive
az account set --subscription <subscription-id>
```

## Connect to the cluster (they already connected in the last tutorial)

To connect to the cluster, run the following commands.

1. Configure `kubectl` to connect to your cluster.

    ```azurecli-interactive
    az aks get-credentials --resource-group <resource-group> --name <cluster-name>
    ```

2. Verify the connection to your cluster using the `kubectl get` command. This command returns a list of the cluster nodes.

    ```azurecli-interactive
    kubectl get nodes
    ```

3. The following output example shows the nodes in your cluster. Make sure the status for all nodes shows *Ready*:

    ```output
    NAME                                STATUS   ROLES   AGE   VERSION
    aks-nodepool1-34832848-vmss000000   Ready    agent   80m   v1.25.6
    aks-nodepool1-34832848-vmss000001   Ready    agent   80m   v1.25.6
    aks-nodepool1-34832848-vmss000002   Ready    agent   80m   v1.25.6
    ```
    
    Take note of the name of your node pool. In this example, it would be **nodepool1**.

## Choose a backing storage option

Azure Container Storage offers various backend storage options for your storage pools, each suited for specific workloads. Selecting the right storage type for your workload is critical for optimizing performance, durability, and cost efficiency. For this tutorial, we'll use Ephemeral Disk (local NVMe). However, we'll also explore the other options in this section.

### Azure Disks

Ideal for databases like PostgreSQL and MongoDB, Azure Disks offer durability, scalability, and multi-tiered performance options, including Premium SSD and Ultra SSD.

Azure Disks allow for  automatic provisioning of storage volumes and include built-in redundancy and high availability. 

### Ephemeral Disk

Ephemeral Disk utilizes local storage resources on AKS nodes (either local NVMe or temp SSD). Offering low sub-ms latency and high IOPS but no data persistence if the VM restarts, it's best for applications such as Cassandra that prioritize speed over persistence. Ephemeral disk is ideal for workloads with application-level replication.

### Azure Elastic SAN (preview)

Designed for shared storage needs and general-purpose databases requiring scalability and high availability, Elastic SAN is a good fit for workloads such as CI/CD pipelines or large-scale data processing.

## Enable Azure Container Storage and create a storage pool

Azure Container Storage uses storage pools to provision and manage persistent volumes. Run the following command to install Azure Container Storage on the cluster and create a storage pool. 


## Next steps

In this tutorial, you deployed Azure Container Storage on your AKS cluster. You learned how to:

> [!div class="checklist"]
>
> * Enable Azure Container Storage and create a storage pool.
> * Blah
> * Blah

In the next tutorial, you learn how to deploy an application to your cluster.

> [!div class="nextstepaction"]
> [Deploy an application in AKS][aks-tutorial-deploy-app]

<!-- LINKS - external -->
[kubectl]: https://kubernetes.io/docs/reference/kubectl/
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[k8s-rbac]: https://kubernetes.io/docs/reference/access-authn-authz/rbac/

<!-- LINKS - internal -->
[aks-tutorial-deploy-app]: ./tutorial-kubernetes-deploy-application.md
[aks-tutorial-prepare-app]: ./tutorial-kubernetes-prepare-app.md
[aks-tutorial-deploy-cluster]: ./tutorial-kubernetes-deploy-cluster.md
[azure-cli-install]: /cli/azure/install-azure-cli
