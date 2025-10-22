---
title: Create an AKS-managed GPU node pool on Azure Kubernetes Service (AKS)
description: Learn how to provision a fully-managed GPU node pool on your new or existing cluster on Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.subservice: aks-developer
ms.date: 10/30/2025
author: sachidesai
ms.author: sachidesai

# Customer intent: As a cluster administrator or developer, I want to provision an Azure Kubernetes Service (AKS) cluster with GPU-enabled node pools, without deploying or managing the fundamental GPU software and observability components myself.
---

# Create a fully-managed GPU node pool on Azure Kubernetes Service (AKS) (preview)

Running GPU workloads in Azure Kubernetes Service (AKS) requires several software components to be installed and maintained: the GPU driver, the Kubernetes device plugin, and GPU metrics exporter for telemetry. These components are essential for enabling GPU scheduling, container-level GPU access, observability of resource usage and without them, AKS GPU node pools cannot function correctly. Previously, cluster operators had to either install these components manually or use open-source alternatives like the [NVIDIA GPU Operator](./nvidia-gpu-operator.md), which may introduce complexity and operational overhead.

AKS now supports fully-managed GPU nodes (preview) and installs the NVIDIA GPU driver, device plugin, and Data Center GPU Manager [(DCGM) metrics exporter](https://github.com/NVIDIA/dcgm-exporter/tree/main) by default. Enabling 1-step GPU node pool creation, this feature streamlines the operational experience for operators and empowers developers and ML engineers by making GPU resources available in AKS as simple as general purpose CPU nodes. Now, organizations can deploy GPU workloads faster, more reliably, and with less infrastructure burden.

In this article, you learn how to provision an AKS-managed GPU nodes in your cluster, including default installation of the NVIDIA GPU driver, device plugin, and metrics exporter.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Before you begin

* This article assumes you have an existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* You need the Azure CLI version 2.72.2 or later installed. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
* This feature requires Kubernetes version 1.34 or later. To check your AKS cluster version, see [Check for available AKS cluster upgrades][aks-upgrade].
* If you have the `aks-preview` Azure CLI extension installed, please update the version to [] or later.

## Limitations

* This feature currently supports NVIDIA GPU-enabled virtual machine (VM) sizes only.
* Updating a general purpose CPU-based node pool to add a GPU VM size is not supported on AKS.
* Windows node pools are not yet supported with this feature.
* Migrating your existing [multi-instance GPU](./gpu-multi-instance.md) node pools to use this feature is not yet supported.
* In-place upgrade to use this feature on existing GPU-enabled nodes is not supported.

> [!NOTE]
> GPU-enabled VMs contain specialized hardware subject to higher pricing and region availability. For more information, see the [pricing][azure-pricing] tool and [region availability][azure-availability].

## Install the `aks-preview` CLI extension

1. Install the `aks-preview` CLI extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

2. Update the extension to ensure you have the latest version installed using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

## Register the `ManagedGPUExperiencePreview` feature flag in your subscription

* Register the `ManagedGPUExperiencePreview` feature flag in your subscription using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace Microsoft.ContainerService --name ManagedGPUExperiencePreview
    ```

## Get the credentials for your cluster

Get the credentials for your AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command. The following example command gets the credentials for the *myAKSCluster* in the *myResourceGroup* resource group:

```azurecli-interactive
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
```

## Create an AKS-managed GPU node pool (preview)

### [Ubuntu Linux node pool (default SKU)](#tab/add-ubuntu-gpu-node-pool)

To use the default OS SKU, you create the node pool without specifying an OS SKU. The node pool is configured for the default operating system based on the Kubernetes version of the cluster.

1. Add a node pool to your cluster using the [`az aks nodepool add`][az-aks-nodepool-add] command and set the `--enable-managed-gpu-experience` flag:

    ```azurecli-interactive
    az aks nodepool add \
        --resource‐group MyResourceGroup \
        --cluster‐name MyAKSCluster \
        --name gpunp \
        --node‐count 1 \
        --node‐vm‐size Standard_NC6s_v3 \
        --node‐taints sku=gpu:NoSchedule \
        --enable‐cluster‐autoscaler \
        --min‐count 1 \
        --max‐count 3 \
        --enable-managed-gpu-experience
    ```

### [Azure Linux node pool](#tab/add-azure-linux-gpu-node-pool)

To use Azure Linux, you specify the OS SKU by setting `os-sku` to `AzureLinux` during node pool creation. The `os-type` is set to `Linux` by default.

1. Add a node pool to your cluster using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--os-sku` flag set to `AzureLinux` and set the `--enable-managed-gpu-experience` flag.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name gpunp \
        --node-count 1 \
        --os-sku AzureLinux \
        --node-vm-size Standard_NC6s_v3 \
        --node-taints sku=gpu:NoSchedule \
        --enable-cluster-autoscaler \
        --min-count 1 \
        --max-count 3
        --enable-managed-gpu-experience
    ```

### Migrate existing GPU workloads to an AKS-managed GPU node pool

In-place upgrade from standard NVIDIA GPU node pool to AKS-managed NVIDIA GPU node pool (preview) is not supported. AKS recommends spinning down your GPU workloads, removing your existing GPU node pool and re-deploying them to a new GPU-enabled node pool with this feature enabled.

## Bring your own (BYO) GPU driver

If you want to control the installation of the NVIDIA drivers or use the [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html), you can bypass the GPU driver installation during node pool creation. In this case, Microsoft **doesn't support or manage** the maintenance and compatibility of the NVIDIA drivers as part of the node image deployment. See [Skip GPU driver installation](./use-nvidia-gpu.md#skip-gpu-driver-installation) for NVIDIA GPU-enabled nodes on AKS to learn more.

## Next steps

* [Confirm that the GPUs are schedulable](./use-nvidia-gpu.md#confirm-that-gpus-are-schedulable) in your AKS-managed GPU node pool.
* Deploy a [sample GPU workload](./use-nvidia-gpu.md#run-a-gpu-enabled-workload) on your AKS-managed GPU-enabled nodes.
* Monitor [GPU utilization and performance metrics](./monitor-gpu-metrics.md) from managed DCGM exporter on your GPU nodes.

## Related articles

* Learn about [GPU health monitoring](./gpu-health-monitoring.md) with Node Problem Detector (NPD) on AKS
* [Autoscale your GPU workloads](./autoscale-gpu-workloads-with-keda.md) with DCGM metrics and Kubernetes Event-Driven Autoscaling (KEDA)
* Run [distributed inference on multiple AKS GPU nodes](https://blog.aks.azure.com/2025/07/08/kaito-inference-with-acstor)

<!-- LINKS - external -->
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[kubectl-describe]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#describe
[kubectl-logs]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#logs
[kubectl delete]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#delete
[kubectl-create]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#create
[azure-pricing]: https://azure.microsoft.com/pricing/
[azure-availability]: https://azure.microsoft.com/global-infrastructure/services/

<!-- LINKS - internal -->
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az_aks_nodepool_update
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az_aks_nodepool_add
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
[gpu-skus]: /azure/virtual-machines/sizes-gpu
[install-azure-cli]: /cli/azure/install-azure-cli
[nvidia-gpu-operator]: nvidia-gpu-operator.md
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
