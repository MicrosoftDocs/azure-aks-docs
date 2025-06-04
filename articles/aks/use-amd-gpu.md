---
title: Use AMD GPUs Azure Kubernetes Service (AKS)
description: Learn how to use AMD GPUs for high performance compute or AI workloads on Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.subservice: aks-developer
ms.date: 06/04/2025
author: sachidesai

#Customer intent: As a cluster administrator or AI app developer, I want to create an AKS cluster that can use high-performance AMD GPU-based VMs for compute-intensive graphics or AI workloads.
---

# Use AMD GPUs for compute-intensive workloads on Azure Kubernetes Service (AKS)

AMD GPU VM sizes on Azure can provide flexibility in performance and cost, offering high compute capacity while allowing you to choose the right configuration for your workload requirements. AKS supports AMD GPU-enabled Linux node pools to run compute-intensive Kubernetes workloads.

This article helps you provision nodes with schedulable AMD GPUs on new and existing AKS clusters.

## Limitations
* AKS currently supports the `Standard_ND96isr_MI300X_v5` Azure VM size powered by the [MI300 series AMD GPU](https://www.amd.com/en/products/accelerators/instinct/mi300.html).
* Updating an existing node pool to add an AMD GPU VM size is not supported on AKS.
* Updating a non-AMD GPU-enabled node pool with an AMD GPU VM size is not supported.
* AMD GPU is not yet supported on AKS node pools with `AzureLinux` or `Windows` ossku.

## Before you begin

* This article assumes you have an existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* You need the Azure CLI version 2.72.2 or later installed to set the `--gpu-driver` field. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
* If you have the `aks-preview` Azure CLI extension installed, please update the version to 18.0.0b2 or later.

> [!NOTE]
> GPU-enabled VMs contain specialized hardware subject to higher pricing and region availability. For more information, see the [pricing][azure-pricing] tool and [region availability][azure-availability].

## Get the credentials for your cluster

Get the credentials for your AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command. The following example command gets the credentials for the cluster `myAKSCluster` in the `myResourceGroup` resource group:

```azurecli-interactive
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
```

## Options for using AMD GPUs

Using AMD GPUs involves the installation of various AMD GPU software components such as the [AMD device plugin for Kubernetes](https://github.com/ROCm/k8s-device-plugin), GPU drivers, and more.

    > [!NOTE]
    > Today, AKS does not automate the installation of GPU drivers nor the AMD GPU device plugin on AMD GPU-enabled node pools.

### Register the AKSInfinibandSupport feature

1. If your AMD GPU VM size is RDMA-enabled with the `r` naming convention (e.g. `Standard_ND96isr_MI300X_v5`), you will need to ensure that the machines in the nodepool land on the same physical Infiniband network. To achieve this, register the `AKSInfinibandSupport` feature flag using the [`az feature register`](/cli/azure/feature#az-feature-register) command:

    ```azurecli-interactive
    az feature register --name AKSInfinibandSupport --namespace Microsoft.ContainerService
    ```

1. Verify the registration status using the [`az feature show`](/cli/azure/feature#az-feature-show) command:

    ```azurecli-interactive
    az feature show \
    --namespace "Microsoft.ContainerService" \
    --name AKSInfinibandSupport
    ```

1. Create an AMD GPU-enabled node pool using the [`az aks nodepool add`](/cli/azure/aks#az_aks_nodepool_add) command and skip default driver installation by setting the API field `--gpu-driver` to the value `none`:

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name gpunp \
        --node-count 1 \
        --node-vm-size Standard_ND96isr_MI300X_v5 \
        --gpu-driver none
    ```

    > [!NOTE]
    > AKS currently enforces the use of the `gpu-driver` field to skip automatic driver installation at AMD GPU node pool creation time.

### Deploy the AMD GPU Operator on AKS

The AMD GPU Operator automates the management and deployment of all AMD software components needed to provision GPU including driver installation, the [AMD device plugin for Kubernetes](), the AMD container runtime, and more. Since the AMD GPU Operator handles these components, it's not necessary to separately install the AMD device plugin on your AKS cluster. This also means that the automatic GPU driver installation should be skipped in order to use the AMD GPU Operator on AKS.

1. Follow the AMD documentation to [Install the GPU Operator](https://instinct.docs.amd.com/projects/gpu-operator/en/latest/usage.html).

1. Check the status of the AMD GPUs in your nodepool using the `kubectl get nodes` command:

    ```bash
    kubectl get nodes -o custom-columns=NAME:.metadata.name,GPUs:.status.capacity.'amd\.com/gpu'
    ```

## Confirm that the AMD GPUs are schedulable

After creating your nodepool, confirm that GPUs are schedulable in your AKS cluster.

1. List the nodes in your cluster using the [`kubectl get nodes`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get) command.

    ```console
    kubectl get nodes
    ```

1. Confirm the GPUs are schedulable using the [`kubectl describe node`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#describe) command.

    ```console
    kubectl describe node aks-gpunp-00000000
    ```

    Under the *Capacity* section, the GPU should list as `amd.com/gpu:  1`. Your output should look similar to the following condensed example output:

    ```console
    Name:               aks-gpunp-00000000
    Roles:              agent
    Labels:             accelerator=amd

    [...]

    Capacity:
    [...]
     amd.com/gpu:                 1
    [...]
    ```

## Run an AMD GPU-enabled workload

To see the AMD GPU in action, you can schedule a GPU-enabled workload with the appropriate resource request. In this example, we'll run a [Tensorflow](https://www.tensorflow.org/) job against the [MNIST dataset](http://yann.lecun.com/exdb/mnist/).

1. Create a file named *samples-tf-mnist-demo.yaml* and paste the following YAML manifest, which includes a resource limit of `amd.com/gpu: 1`:

    ```yaml
    apiVersion: batch/v1
    kind: Job
    metadata:
      labels:
        app: samples-tf-mnist-demo
      name: samples-tf-mnist-demo
    spec:
      template:
        metadata:
          labels:
            app: samples-tf-mnist-demo
        spec:
          containers:
          - name: samples-tf-mnist-demo
            image: mcr.microsoft.com/azuredocs/samples-tf-mnist-demo:gpu
            args: ["--max_steps", "500"]
            imagePullPolicy: IfNotPresent
            resources:
              limits:
               amd.com/gpu: 1
          restartPolicy: OnFailure
          tolerations:
          - key: "sku"
            operator: "Equal"
            value: "gpu"
            effect: "NoSchedule"
    ```

1. Run the job using the [`kubectl apply`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply) command, which parses the manifest file and creates the defined Kubernetes objects.

    ```console
    kubectl apply -f samples-tf-mnist-demo.yaml
    ```

## View the status of the GPU-enabled workload

1. Monitor the progress of the job using the [`kubectl get jobs`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get) command with the `--watch` flag. It may take a few minutes to first pull the image and process the dataset.

    ```console
    kubectl get jobs samples-tf-mnist-demo --watch
    ```

    When the *COMPLETIONS* column shows *1/1*, the job has successfully finished, as shown in the following example output:

    ```console
    NAME                    COMPLETIONS   DURATION   AGE

    samples-tf-mnist-demo   0/1           3m29s      3m29s
    samples-tf-mnist-demo   1/1   3m10s   3m36s
    ```

1. Exit the `kubectl --watch` process with *Ctrl-C*.

1. Get the name of the pod using the [`kubectl get pods`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get) command.

    ```console
    kubectl get pods --selector app=samples-tf-mnist-demo
    ```

1. To confirm that the appropriate AMD GPU device has been discovered, display the output of the GPU-enabled workload using the [`kubectl logs`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#logs) command.

    ```console
    kubectl logs samples-tf-mnist-demo-smnr6
    ```

## Clean up resources

Remove the associated Kubernetes objects you created in this article using the [`kubectl delete job`](https://kubernetes.io/docs/reference/generated/kubectl/) command.

    ```console
    kubectl delete jobs samples-tf-mnist-demo
    ```

## Next steps

- Explore the [different storage options](/cli/azure/aks/concepts-storage) for your GPU-based application on AKS.
- Learn more about [Ray clusters on AKS](ray-overview.md).


<!-- LINKS -->
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md