---
title: Create a multi-instance GPU node pool in Azure Kubernetes Service (AKS)
description: Learn how to create a multi-instance GPU node pool in Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.date: 08/30/2023
ms.author: sachidesai
author: schaffererin
ms.subservice: aks-nodes
# Customer intent: "As a cloud engineer, I want to create a multi-instance GPU node pool in Azure Kubernetes Service, so that I can efficiently utilize GPU resources for parallel processing in my applications."
---

# Create a multi-instance GPU node pool in Azure Kubernetes Service (AKS)

Certain NVIDIA GPUs can be divided in up to seven independent instances. Each instance has its own Stream Multiprocessor (SM), which is responsible for executing instructions in parallel, and GPU memory. For more information on GPU partitioning, see [NVIDIA MIG][NVIDIA MIG].

This article walks you through how to create a multi-instance GPU node pool using a MIG-compatible VM size in an Azure Kubernetes Service (AKS) cluster.

## Prerequisites and limitations

* An Azure account with an active subscription. If you don't have one, you can [create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).
* Azure CLI version 2.2.0 or later installed and configured. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
* The Kubernetes command-line client, [kubectl](https://kubernetes.io/docs/reference/kubectl/), installed and configured. If you use Azure Cloud Shell, `kubectl` is already installed. If you want to install it locally, you can use the [`az aks install-cli`][az-aks-install-cli] command.
* Helm v3 installed and configured. For more information, see [Installing Helm](https://helm.sh/docs/intro/install/).
* Multi-instance GPU node pools are not currently supported on Azure Linux.
* Multi-instance GPU is currently supported on the `Standard_NC40ads_H100_v5` and A100 GPU VM sizes on AKS.

## GPU instance profiles

GPU instance profiles define how GPUs are partitioned. The following table shows the available GPU instance profile for the `Standard_ND96asr_v4`:

| Profile name | Fraction of SM |Fraction of memory | Number of instances created |
|--|--|--|--|
| MIG 1g.5gb | 1/7 | 1/8 | 7 |
| MIG 2g.10gb | 2/7 | 2/8 | 3 |
| MIG 3g.20gb | 3/7 | 4/8 | 2 |
| MIG 4g.20gb | 4/7 | 4/8 | 1 |
| MIG 7g.40gb | 7/7 | 8/8 | 1 |

As an example, the GPU instance profile of `MIG 1g.5gb` indicates that each GPU instance has 1g SM (streaming multiprocessors) and 5gb memory. In this case, the GPU is partitioned into seven instances.

The available GPU instance profiles available for this VM size include `MIG1g`, `MIG2g`, `MIG3g`, `MIG4g`, and `MIG7g`. 

> [!IMPORTANT]
> You can't change the applied GPU instance profile after node pool creation.

## Create an AKS cluster

1. Create an Azure resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --name myResourceGroup --location southcentralus
    ```

2. Create an AKS cluster using the [`az aks create`][az-aks-create] command.

    ```azurecli-interactive
    az aks create \
        --resource-group myResourceGroup \
        --name myAKSCluster \
        --generate-ssh-keys
    ```
3. Configure `kubectl` to connect to your AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
    ```

## Create a multi-instance GPU node pool

You can use either the Azure CLI or an HTTP request to the ARM API to create the node pool.

### [Azure CLI](#tab/azure-cli)

* Create a multi-instance GPU node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command and specify the GPU instance profile. The example below creates a node pool with the `Standard_ND96asr_v4` MIG-compatible GPU VM size.

    ```azurecli-interactive
    az aks nodepool add \
        --name aksMigNode \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --node-vm-size Standard_ND96asr_v4 \
        --node-count 1 \
        --gpu-instance-profile MIG1g
    ```

### [HTTP request](#tab/http-request)

* Create a multi-instance GPU node pool by placing the GPU instance profile in the request body.

    ```http
    {
        "properties": {
            "count": 1,
            "vmSize": "Standard_ND96asr_v4",
            "type": "VirtualMachineScaleSets",
            "gpuInstanceProfile": "MIG1g"
        }
    }
    ```

---

## Determine multi-instance GPU (MIG) strategy

Before you install the NVIDIA plugins, you need to specify which multi-instance GPU (MIG) strategy to use for GPU partitioning: *Single strategy* or *Mixed strategy*. The two strategies don't affect how you execute CPU workloads, but how GPU resources are displayed.

* **Single strategy**: The single strategy treats every GPU instance as a GPU. If you use this strategy, the GPU resources are displayed as `nvidia.com/gpu: 1`.
* **Mixed strategy**: The mixed strategy exposes the GPU instances and the GPU instance profile. If you use this strategy, the GPU resource are displayed as `nvidia.com/mig1g.5gb: 1`.

## Install the NVIDIA device plugin and GPU feature discovery (GFD) components

1. Set your MIG strategy as an environment variable. You can use either single or mixed strategy.

    ```azurecli-interactive
    # Single strategy
    export MIG_STRATEGY=single

    # Mixed strategy
    export MIG_STRATEGY=mixed
    ```

2. Add the NVIDIA device plugin helm repository using the `helm repo add` and `helm repo update` commands.

    ```azurecli-interactive
    helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
    helm repo update
    ```

4. Install the NVIDIA device plugin using the `helm install` command.

    ```azurecli-interactive
    helm install nvdp nvdp/nvidia-device-plugin \
    --version=0.17.0 \
    --set migStrategy=${MIG_STRATEGY} \
    --set gfd.enabled=true \
    --namespace nvidia-device-plugin \
    --create-namespace
    ```
    
> [!NOTE]
> Helm installation of the NVIDIA device plugin consolidates the Kubernetes device plugin and GFD repositories. Separate helm installation of the GFD software component is not recommended when using AKS-managed multi-instance GPU.

## Confirm multi-instance GPU capability

1. Verify the `kubectl` connection to your cluster using the `kubectl get` command to return a list of cluster nodes.

    ```azurecli-interactive
    kubectl get nodes -o wide
    ```

2. Confirm the node has multi-instance GPU capability using the `kubectl describe node` command. The following example command describes the node named *aksMigNode*, which uses MIG1g as the GPU instance profile.

    ```azurecli-interactive
    kubectl describe node aksMigNode
    ```

    Your output should resemble the following example output:

    ```output
    # Single strategy output
    Allocatable:
        nvidia.com/gpu: 56

    # Mixed strategy output
    Allocatable:
        nvidia.com/mig-1g.5gb: 56
    ```

## Schedule work

The following examples are based on CUDA base image **version 12.1.1** for Ubuntu **22.04**, tagged as `12.1.1-base-ubuntu22.04`.

### Single strategy

1. Create a file named `single-strategy-example.yaml` and copy in the following manifest.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: nvidia-single
    spec:
      containers:
      - name: nvidia-single
        image: nvidia/cuda:12.1.1-base-ubuntu22.04
        command: ["/bin/sh"]
        args: ["-c","sleep 1000"]
        resources:
          limits:
            "nvidia.com/gpu": 1
    ```

2. Deploy the application using the `kubectl apply` command and specify the name of your YAML manifest.

    ```azurecli-interactive
    kubectl apply -f single-strategy-example.yaml
    ```

3. Verify the allocated GPU devices using the `kubectl exec` command. This command returns a list of the cluster nodes.

    ```azurecli-interactive
    kubectl exec nvidia-single -- nvidia-smi -L
    ```

    The following example resembles output showing successfully created deployments and services:

    ```output
    GPU 0: NVIDIA A100 40GB PCIe (UUID: GPU-48aeb943-9458-4282-da24-e5f49e0db44b)
    MIG 1g.5gb     Device  0: (UUID: MIG-fb42055e-9e53-5764-9278-438605a3014c)
    MIG 1g.5gb     Device  1: (UUID: MIG-3d4db13e-c42d-5555-98f4-8b50389791bc)
    MIG 1g.5gb     Device  2: (UUID: MIG-de819d17-9382-56a2-b9ca-aec36c88014f)
    MIG 1g.5gb     Device  3: (UUID: MIG-50ab4b32-92db-5567-bf6d-fac646fe29f2)
    MIG 1g.5gb     Device  4: (UUID: MIG-7b6b1b6e-5101-58a4-b5f5-21563789e62e)
    MIG 1g.5gb     Device  5: (UUID: MIG-14549027-dd49-5cc0-bca4-55e67011bd85)
    MIG 1g.5gb     Device  6: (UUID: MIG-37e055e8-8890-567f-a646-ebf9fde3ce7a)
    ```

### Mixed strategy

1. Create a file named `mixed-strategy-example.yaml` and copy in the following manifest.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: nvidia-mixed
    spec:
      containers:
      - name: nvidia-mixed
        image: nvidia/cuda:12.1.1-base-ubuntu22.04
        command: ["/bin/sh"]
        args: ["-c","sleep 100"]
        resources:
          limits:
            "nvidia.com/mig-1g.5gb": 1
    ```

2. Deploy the application using the `kubectl apply` command and specify the name of your YAML manifest.

    ```azurecli-interactive
    kubectl apply -f mixed-strategy-example.yaml
    ```

3. Verify the allocated GPU devices using the `kubectl exec` command. This command returns a list of the cluster nodes.

    ```azurecli-interactive
    kubectl exec nvidia-mixed -- nvidia-smi -L
    ```

    The following example resembles output showing successfully created deployments and services:

    ```output
    GPU 0: NVIDIA A100 40GB PCIe (UUID: GPU-48aeb943-9458-4282-da24-e5f49e0db44b)
    MIG 1g.5gb     Device  0: (UUID: MIG-fb42055e-9e53-5764-9278-438605a3014c)
    ```

> [!IMPORTANT]
> The `latest` tag for CUDA images has been deprecated on Docker Hub. Please refer to [NVIDIA's repository](https://hub.docker.com/r/nvidia/cuda/tags) for the latest images and corresponding tags.

## Troubleshooting

If you don't see multi-instance GPU capability after creating the node pool, confirm the API version isn't older than *2021-08-01*.

## Next steps

To learn more about GPUs on Azure Kubernetes Service, see:

* [Create a Linux GPU-enabled node pool on AKS](./gpu-cluster.md).
* [Create a Windows GPU-enabled node pool on AKS](./use-windows-gpu.md)
* [Learn about use cases for GPU workloads on AKS](/azure/architecture/reference-architectures/containers/aks-gpu/gpu-aks)

<!-- LINKS - internal -->
[az-group-create]: /cli/azure/group#az_group_create
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az_aks_nodepool_add
[install-azure-cli]: /cli/azure/install-azure-cli
[az-aks-install-cli]: /cli/azure/aks#az_aks_install_cli
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials

<!-- LINKS - external-->
[NVIDIA MIG]:https://www.nvidia.com/en-us/technologies/multi-instance-gpu/
