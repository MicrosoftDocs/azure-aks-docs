---
title: Use GPUs for Windows node pools on Azure Kubernetes Service (AKS) (preview)
description: Learn how to use Windows GPUs for high performance compute or graphics-intensive workloads on Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 03/18/2024
author: schaffererin
ms.author: schaffererin
#Customer intent: As a cluster administrator or developer, I want to create an AKS cluster that can use high-performance GPU-based VMs for compute-intensive workloads using a Windows os.
---

# Use Windows GPUs for compute-intensive workloads on Azure Kubernetes Service (AKS) (preview)

Graphical processing units (GPUs) are often used for compute-intensive workloads, such as graphics and visualization workloads. AKS supports GPU-enabled Windows and [Linux](./gpu-cluster.md) node pools to run compute-intensive Kubernetes workloads.

This article helps you provision Windows nodes with schedulable GPUs on new and existing AKS clusters (preview).

## Supported GPU-enabled virtual machines (VMs)

To view supported GPU-enabled VMs, see [GPU-optimized VM sizes in Azure][gpu-skus]. For AKS node pools, we recommend a minimum size of *Standard_NC6s_v3*. The NVv4 series (based on AMD GPUs) aren't supported on AKS.

> [!NOTE]
> GPU-enabled VMs contain specialized hardware subject to higher pricing and region availability. For more information, see the [pricing][azure-pricing] tool and [region availability][azure-availability].

## Limitations

* Updating an existing Windows node pool to add GPU isn't supported.
* Not supported on Kubernetes version 1.28 and below.

## Before you begin

* This article assumes you have an existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* You need the Azure CLI version 2.72.2 or later installed and configured to use the `--gpu-driver` field with the `az aks nodepool add` command. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
* If you have the `aks-preview` Azure CLI extension installed, please update the version to 18.0.0b2 or later.

## Get the credentials for your cluster

* Get the credentials for your AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command. The following example command gets the credentials for the *myAKSCluster* in the *myResourceGroup* resource group:

    ```azurecli-interactive
    az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
    ```

## Using Windows GPU with automatic driver installation

Using NVIDIA GPUs involves the installation of various NVIDIA software components such as the [DirectX device plugin for Kubernetes](https://github.com/aarnaud/k8s-directx-device-plugin), GPU driver installation, and more. When you create a Windows node pool with a supported GPU-enabled VM, these components and the appropriate NVIDIA CUDA or GRID drivers are installed. For NC and ND series VM sizes, the CUDA driver is installed. For NV series VM sizes, the GRID driver is installed.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

### Install the `aks-preview` Azure CLI extension

* Register or update the aks-preview extension using the [`az extension add`][az-extension-add] or [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    # Register the aks-preview extension
    az extension add --name aks-preview

    # Update the aks-preview extension
    az extension update --name aks-preview
    ```

### Register the `WindowsGPUPreview` feature flag

1. Register the `WindowsGPUPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "WindowsGPUPreview"
    ```

    It takes a few minutes for the status to show *Registered*.

2. Verify the registration status using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "WindowsGPUPreview"
    ```

3. When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

### Create a Windows GPU-enabled node pool (preview)

To create a Windows GPU-enabled node pool, you need to use a supported GPU-enabled VM size and specify the `os-type` as `Windows`. The default Windows `os-sku` is `Windows2022`, but all Windows `os-sku` options are supported.

1. Create a Windows GPU-enabled node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command.

   ```azurecli-interactive
   az aks nodepool add \
      --resource-group myResourceGroup \
      --cluster-name myAKSCluster \
      --name gpunp \
      --node-count 1 \
      --os-type Windows \
      --kubernetes-version 1.29.0 \
      --node-vm-size Standard_NC6s_v3
   ```

2. Check that your [GPUs are schedulable](#confirm-that-gpus-are-schedulable).
3. Once you confirm that your GPUs are schedulable, you can run your GPU workload.

#### Specify GPU Driver Type (preview)

By default, AKS specifies a default GPU driver type for each supported GPU-enabled VM. Because workload and driver compatibility are important for functioning GPU workloads, you can specify the driver type for your Windows GPU node. This feature is not supported for Linux GPU node pools.

When creating a Windows agent pool with GPU support, you have the option to specify the type of GPU driver using the `--driver-type` flag. 

The available options are:
- GRID: For applications requiring virtualization support.
- CUDA: Optimized for computational tasks in scientific computing and data-intensive applications.

 > [!NOTE]
 > When you set the `--driver-type` flag, you assume responsibility for ensuring that the selected driver type is compatible with the specific VM size and configuration of your node pool. While AKS attempts to validate compatibility, there are scenarios where the node pool creation might fail due to incompatibilities between the specified driver type and the underlying VM or hardware.

To create a Windows GPU-enabled node pool with a specific GPU Driver type, use the [`az aks nodepool add`][az-aks-nodepool-add] command.

  ```azurecli-interactive
  az aks nodepool add \
      --resource-group myResourceGroup \
      --cluster-name myAKSCluster \
      --name gpunp \
      --node-count 1 \
      --os-type Windows \
      --kubernetes-version 1.29.0 \
      --node-vm-size Standard_NC6s_v3 \
      --driver-type GRID
  ```
For example, the above command creates a GPU-enabled node pool using the `GRID` GPU driver type. Selecting this driver type overrides the default of `CUDA` driver type for NC series VM skus.

## Using Windows GPU with manual driver installation

When creating a Windows node pool with N-series (NVIDIA GPU) VM sizes in AKS, the GPU driver and Kubernetes DirectX device plugin are installed automatically. To bypass this automatic installation, use the following steps:

1. [Skip GPU driver installation](#skip-gpu-driver-installation) by setting the configuration `--gpu-driver none` at node pool create time.
2. [Manual installation of the Kubernetes DirectX device plugin](#manually-install-the-kubernetes-directx-device-plugin).

### Skip GPU driver installation

AKS has automatic GPU driver installation enabled by default. In some cases, such as installing your own drivers, you may want to skip GPU driver installation.

1. Create a node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command and setting the API field `--gpu-driver` to `none` to skip automatic GPU driver installation.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name gpunp \
        --node-count 1 \
        --os-type windows \
        --os-sku windows2022 \
        --gpu-driver none
    ```

 > [!NOTE]
 > If the `--node-vm-size` that you're using isn't yet onboarded on AKS, you can't use GPUs and the `--gpu-driver` field doesn't work.

### Manually install the Kubernetes DirectX device plugin

You can deploy a DaemonSet for the Kubernetes DirectX device plugin, which runs a pod on each node to provide the required drivers for the GPUs.

* Add a node pool to your cluster using the [`az aks nodepool add`][az-aks-nodepool-add] command.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name gpunp \
        --node-count 1 \
        --os-type windows \
        --os-sku windows2022
    ```

## Create a namespace and deploy the Kubernetes DirectX device plugin

1. Create a namespace using the [`kubectl create namespace`][kubectl-create] command.

    ```bash
    kubectl create namespace gpu-resources
    ```

2. Create a file named *k8s-directx-device-plugin.yaml* and paste the following YAML manifest provided as part of the [NVIDIA device plugin for Kubernetes project][nvidia-github]:

    ```yaml
    apiVersion: apps/v1
    kind: DaemonSet
    metadata:
      name: nvidia-device-plugin-daemonset
      namespace: gpu-resources
    spec:
      selector:
        matchLabels:
          name: nvidia-device-plugin-ds
      updateStrategy:
        type: RollingUpdate
      template:
        metadata:
          # Mark this pod as a critical add-on; when enabled, the critical add-on scheduler
          # reserves resources for critical add-on pods so that they can be rescheduled after
          # a failure.  This annotation works in tandem with the toleration below.
          annotations:
            scheduler.alpha.kubernetes.io/critical-pod: ""
          labels:
            name: nvidia-device-plugin-ds
        spec:
          tolerations:
          # Allow this pod to be rescheduled while the node is in "critical add-ons only" mode.
          # This, along with the annotation above marks this pod as a critical add-on.
          - key: CriticalAddonsOnly
            operator: Exists
          - key: nvidia.com/gpu
            operator: Exists
            effect: NoSchedule
          - key: "sku"
            operator: "Equal"
            value: "gpu"
            effect: "NoSchedule"
          containers:
          - image: mcr.microsoft.com/aks/aks-windows-gpu-device-plugin:0.0.17
            name: nvidia-device-plugin-ctr
            securityContext:
              allowPrivilegeEscalation: false
              capabilities:
                drop: ["ALL"]
            volumeMounts:
              - name: device-plugin
                mountPath: /var/lib/kubelet/device-plugins
          volumes:
            - name: device-plugin
              hostPath:
                path: /var/lib/kubelet/device-plugins
    ```

3. Create the DaemonSet and confirm the NVIDIA device plugin is created successfully using the [`kubectl apply`][kubectl-apply] command.

    ```bash
    kubectl apply -f nvidia-device-plugin-ds.yaml
    ```

4. Now that you successfully installed the NVIDIA device plugin, you can check that your [GPUs are schedulable](#confirm-that-gpus-are-schedulable).

## Confirm that GPUs are schedulable

After creating your cluster, confirm that GPUs are schedulable in Kubernetes.

1. List the nodes in your cluster using the [`kubectl get nodes`][kubectl-get] command.

    ```console
    kubectl get nodes
    ```

    Your output should look similar to the following example output:

    ```console
    NAME                   STATUS   ROLES   AGE   VERSION
    aks-gpunp-28993262-0   Ready    agent   13m   v1.20.7
    ```

2. Confirm the GPUs are schedulable using the [`kubectl describe node`][kubectl-describe] command.

    ```console
    kubectl describe node aks-gpunp-28993262-0
    ```

    Under the *Capacity* section, the GPU should list as `microsoft.com/directx: 1`. Your output should look similar to the following condensed example output:

    ```output
    Capacity:
    [...]
     microsoft.com.directx/gpu:                 1
    [...]
    ```

## Clean up resources

* Remove the associated Kubernetes objects you created in this article using the [`kubectl delete job`][kubectl delete] command.

    ```console
    kubectl delete jobs windows-gpu-workload
    ```

## Next steps

* To run Apache Spark jobs, see [Run Apache Spark jobs on AKS][aks-spark].
* For more information on features of the Kubernetes scheduler, see [Best practices for advanced scheduler features in AKS][advanced-scheduler-aks].
* For more information on Azure Kubernetes Service and Azure Machine Learning, see:
  * [Configure a Kubernetes cluster for ML model training or deployment][azureml-aks].
  * [Deploy a model with an online endpoint][azureml-deploy].
  * [High-performance serving with Triton Inference Server][azureml-triton].
  * [Labs for Kubernetes and Kubeflow][kubeflow].

<!-- LINKS - external -->
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[kubeflow]: https://github.com/Azure/kubeflow-labs
[kubectl-describe]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#describe
[kubectl-logs]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#logs
[kubectl delete]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#delete
[kubectl-create]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#create
[azure-pricing]: https://azure.microsoft.com/pricing/
[azure-availability]: https://azure.microsoft.com/global-infrastructure/services/
[nvidia-github]: https://github.com/NVIDIA/k8s-device-plugin

<!-- LINKS - internal -->
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az_aks_nodepool_update
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az_aks_nodepool_add
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[aks-quickstart-cli]: ./learn/quick-windows-container-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-windows-container-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-windows-container-deploy-powershell.md
[aks-spark]: spark-job.md
[gpu-skus]: /azure/virtual-machines/sizes-gpu
[install-azure-cli]: /cli/azure/install-azure-cli
[azureml-aks]: /azure/machine-learning/how-to-attach-kubernetes-anywhere
[azureml-deploy]: /azure/machine-learning/how-to-deploy-managed-online-endpoints
[azureml-triton]: /azure/machine-learning/how-to-deploy-with-triton
[aks-container-insights]: monitor-aks.md#integrations
[advanced-scheduler-aks]: operator-best-practices-advanced-scheduler.md
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[NVadsA10]: /azure/virtual-machines/nva10v5-series
