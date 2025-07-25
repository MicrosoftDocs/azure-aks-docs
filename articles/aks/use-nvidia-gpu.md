---
title: Use GPUs on Azure Kubernetes Service (AKS)
description: Learn how to use GPUs for high performance compute or graphics-intensive workloads on Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.subservice: aks-developer
ms.date: 04/10/2023
author: schaffererin
ms.author: schaffererin

# Customer intent: As a cluster administrator or developer, I want to provision an Azure Kubernetes Service (AKS) cluster with GPU-enabled node pools, so that I can run high-performance, compute-intensive workloads effectively.
---

# Use GPUs for compute-intensive workloads on Azure Kubernetes Service (AKS)

Graphical processing units (GPUs) are often used for compute-intensive workloads, such as graphics and visualization workloads. AKS supports GPU-enabled Linux node pools to run compute-intensive Kubernetes workloads.

This article helps you provision nodes with schedulable GPUs on new and existing AKS clusters.

## Supported GPU-enabled VMs

To view supported GPU-enabled VMs, see [GPU-optimized VM sizes in Azure][gpu-skus]. For AKS node pools, we recommend a minimum size of *Standard_NC6s_v3*. The NVv4 series (based on AMD GPUs) aren't supported on AKS.

> [!NOTE]
> GPU-enabled VMs contain specialized hardware subject to higher pricing and region availability. For more information, see the [pricing][azure-pricing] tool and [region availability][azure-availability].

## Limitations

* If you're using an Azure Linux GPU-enabled node pool, automatic security patches aren't applied. Refer to your current AKS API version for the default behavior of node OS upgrade channel.

> [!NOTE]
> For AKS API version 2023-06-01 or later, the default channel for node OS upgrade is *NodeImage*. For previous versions, the default channel is *None*. To learn more, see [auto-upgrade](./auto-upgrade-node-image.md).

* Updating an existing node pool to add GPU VM size is not supported on AKS.

> [!NOTE]
> The AKS GPU image (preview) is retired starting on January 10, 2025. The custom header is no longer available, meaning that you can't create new GPU-enabled node pools using the AKS GPU image. We recommend migrating to or using the default GPU configuration rather than the GPU image, as the GPU image is no longer supported. For more information, see [AKS release notes](https://github.com/Azure/AKS/releases), or view this retirement announcement in our [AKS public roadmap](https://github.com/Azure/AKS/issues/4472).

## Before you begin

* This article assumes you have an existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* You need the Azure CLI version 2.72.2 or later installed to set the `--gpu-driver` field. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
* If you have the `aks-preview` Azure CLI extension installed, please update the version to 18.0.0b2 or later.

## Get the credentials for your cluster

Get the credentials for your AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command. The following example command gets the credentials for the *myAKSCluster* in the *myResourceGroup* resource group:

```azurecli-interactive
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
```

## Options for using NVIDIA GPUs

Using NVIDIA GPUs involves the installation of various NVIDIA software components such as the [NVIDIA device plugin for Kubernetes](https://github.com/NVIDIA/k8s-device-plugin?tab=readme-ov-file), GPU driver installation, and more.

> [!NOTE]
> By default, Microsoft automatically maintains the version of the NVIDIA drivers as part of the node image deployment, and AKS ***supports and manages*** it. While the NVIDIA drivers are installed by default on GPU capable nodes, you need to install the device plugin.

### NVIDIA device plugin installation

NVIDIA device plugin installation is required when using GPUs on AKS. In some cases, the installation is handled automatically, such as when using the [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html). Alternatively, you can manually install the NVIDIA device plugin.

#### Manually install the NVIDIA device plugin

You can deploy a DaemonSet for the NVIDIA device plugin, which runs a pod on each node to provide the required drivers for the GPUs. This is the recommended approach when using GPU-enabled node pools for Azure Linux.

##### [Ubuntu Linux node pool (default SKU)](#tab/add-ubuntu-gpu-node-pool)

To use the default OS SKU, you create the node pool without specifying an OS SKU. The node pool is configured for the default operating system based on the Kubernetes version of the cluster.

1. Add a node pool to your cluster using the [`az aks nodepool add`][az-aks-nodepool-add] command.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name gpunp \
        --node-count 1 \
        --node-vm-size Standard_NC6s_v3 \
        --node-taints sku=gpu:NoSchedule \
        --enable-cluster-autoscaler \
        --min-count 1 \
        --max-count 3
    ```

    This command adds a node pool named *gpunp* to *myAKSCluster* in *myResourceGroup* and uses parameters to configure the following node pool settings:

    * `--node-vm-size`: Sets the VM size for the node in the node pool to *Standard_NC6s_v3*.
    * `--node-taints`: Specifies a *sku=gpu:NoSchedule* taint on the node pool.
    * `--enable-cluster-autoscaler`: Enables the cluster autoscaler.
    * `--min-count`: Configures the cluster autoscaler to maintain a minimum of one node in the node pool.
    * `--max-count`: Configures the cluster autoscaler to maintain a maximum of three nodes in the node pool.

    > [!NOTE]
    > Taints and VM sizes can only be set for node pools during node pool creation, but you can update autoscaler settings at any time.

##### [Azure Linux node pool](#tab/add-azure-linux-gpu-node-pool)

To use Azure Linux, you specify the OS SKU by setting `os-sku` to `AzureLinux` during node pool creation. The `os-type` is set to `Linux` by default.

1. Add a node pool to your cluster using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--os-sku` flag set to `AzureLinux`.

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
    ```

    This command adds a node pool named *gpunp* to *myAKSCluster* in *myResourceGroup* and uses parameters to configure the following node pool settings:

    * `--node-vm-size`: Sets the VM size for the node in the node pool to *Standard_NC6s_v3*.
    * `--node-taints`: Specifies a *sku=gpu:NoSchedule* taint on the node pool.
    * `--enable-cluster-autoscaler`: Enables the cluster autoscaler.
    * `--min-count`: Configures the cluster autoscaler to maintain a minimum of one node in the node pool.
    * `--max-count`: Configures the cluster autoscaler to maintain a maximum of three nodes in the node pool.

    > [!NOTE]
    > Taints and VM sizes can only be set for node pools during node pool creation, but you can update autoscaler settings at any time. Certain SKUs, including A100 and H100 VM SKUs, aren't available for Azure Linux. For more information, see [GPU-optimized VM sizes in Azure][gpu-skus].

---

1. Create a namespace using the [`kubectl create namespace`][kubectl-create] command.

    ```bash
    kubectl create namespace gpu-resources
    ```

1. Create a file named *nvidia-device-plugin-ds.yaml* and paste the following YAML manifest provided as part of the [NVIDIA device plugin for Kubernetes project][nvidia-github]:

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
          labels:
            name: nvidia-device-plugin-ds
        spec:
          tolerations:
          - key: "sku"
            operator: "Equal"
            value: "gpu"
            effect: "NoSchedule"
          # Mark this pod as a critical add-on; when enabled, the critical add-on
          # scheduler reserves resources for critical add-on pods so that they can
          # be rescheduled after a failure.
          # See https://kubernetes.io/docs/tasks/administer-cluster/guaranteed-scheduling-critical-addon-pods/
          priorityClassName: "system-node-critical"
          containers:
          - image: nvcr.io/nvidia/k8s-device-plugin:v0.17.2
            name: nvidia-device-plugin-ctr
            env:
              - name: FAIL_ON_INIT_ERROR
                value: "false"
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

1. Create the DaemonSet and confirm the NVIDIA device plugin is created successfully using the [`kubectl apply`][kubectl-apply] command.

    ```bash
    kubectl apply -f nvidia-device-plugin-ds.yaml
    ```

1. Now that you successfully installed the NVIDIA device plugin, you can check that your [GPUs are schedulable](#confirm-that-gpus-are-schedulable) and [run a GPU workload](#run-a-gpu-enabled-workload).


### Skip GPU driver installation

If you want to control the installation of the NVIDIA drivers or use the [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html), you can skip the default GPU driver installation. Microsoft **doesn't support or manage** the maintenance and compatibility of the NVIDIA drivers as part of the node image deployment.

> [!NOTE]
> The `gpu-driver` API field is a suggested alternative for customers previously using the `--skip-gpu-driver-install` node pool tag. 
>- The `--skip-gpu-driver-install` node pool tag on AKS will be retired on 14 August 2025. To retain the existing behavior of skipping automatic GPU driver installation, upgrade your node pools to the latest node image version and set the `--gpu-driver` field to `none`. After 14 August 2025, you will not be able to provision AKS GPU-enabled node pools with the `--skip-gpu-driver-install` node pool tag to bypass this default behavior. For more information, see [`skip-gpu-driver` tag retirement](https://aka.ms/aks/skip-gpu-driver-tag-retirement).

1. Create a node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command and set `--gpu-driver` field to `none` to skip default GPU driver installation.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name gpunp \
        --node-count 1 \
        --gpu-driver none \
        --node-vm-size Standard_NC6s_v3 \
        --enable-cluster-autoscaler \
        --min-count 1 \
        --max-count 3
    ```

    Setting the `--gpu-driver` API field to `none` during node pool creation skips the automatic GPU driver installation. Any existing nodes aren't changed. You can scale the node pool to zero and then back up to make the change take effect.

    If you get the error `unrecognized arguments: --gpu-driver none` then [update the Azure CLI version](/cli/azure/update-azure-cli). For more information, see [Before you begin](#before-you-begin).

1. You can optionally install the NVIDIA GPU Operator following [these steps][nvidia-gpu-operator].

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

1. Confirm the GPUs are schedulable using the [`kubectl describe node`][kubectl-describe] command.

    ```console
    kubectl describe node aks-gpunp-28993262-0
    ```

    Under the *Capacity* section, the GPU should list as `nvidia.com/gpu:  1`. Your output should look similar to the following condensed example output:

    ```console
    Name:               aks-gpunp-28993262-0
    Roles:              agent
    Labels:             accelerator=nvidia

    [...]

    Capacity:
    [...]
     nvidia.com/gpu:                 1
    [...]
    ```

## Run a GPU-enabled workload

To see the GPU in action, you can schedule a GPU-enabled workload with the appropriate resource request. In this example, we'll run a [Tensorflow](https://www.tensorflow.org/) job against the [MNIST dataset](http://yann.lecun.com/exdb/mnist/).

1. Create a file named *samples-tf-mnist-demo.yaml* and paste the following YAML manifest, which includes a resource limit of `nvidia.com/gpu: 1`:

    > [!NOTE]
    > If you receive a version mismatch error when calling into drivers, such as "CUDA driver version is insufficient for CUDA runtime version", review the [NVIDIA driver matrix compatibility chart](https://docs.nvidia.com/deploy/cuda-compatibility/index.html).

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
               nvidia.com/gpu: 1
          restartPolicy: OnFailure
          tolerations:
          - key: "sku"
            operator: "Equal"
            value: "gpu"
            effect: "NoSchedule"
    ```

1. Run the job using the [`kubectl apply`][kubectl-apply] command, which parses the manifest file and creates the defined Kubernetes objects.

    ```console
    kubectl apply -f samples-tf-mnist-demo.yaml
    ```

## View the status of the GPU-enabled workload

1. Monitor the progress of the job using the [`kubectl get jobs`][kubectl-get] command with the `--watch` flag. It may take a few minutes to first pull the image and process the dataset.

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

1. Get the name of the pod using the [`kubectl get pods`][kubectl-get] command.

    ```console
    kubectl get pods --selector app=samples-tf-mnist-demo
    ```

1. View the output of the GPU-enabled workload using the [`kubectl logs`][kubectl-logs] command.

    ```console
    kubectl logs samples-tf-mnist-demo-smnr6
    ```

    The following condensed example output of the pod logs confirms that the appropriate GPU device, `Tesla K80`, has been discovered:

    ```console
    2019-05-16 16:08:31.258328: I tensorflow/core/platform/cpu_feature_guard.cc:137] Your CPU supports instructions that this TensorFlow binary was not compiled to use: SSE4.1 SSE4.2 AVX AVX2 FMA
    2019-05-16 16:08:31.396846: I tensorflow/core/common_runtime/gpu/gpu_device.cc:1030] Found device 0 with properties:
    name: Tesla K80 major: 3 minor: 7 memoryClockRate(GHz): 0.8235
    pciBusID: 2fd7:00:00.0
    totalMemory: 11.17GiB freeMemory: 11.10GiB
    2019-05-16 16:08:31.396886: I tensorflow/core/common_runtime/gpu/gpu_device.cc:1120] Creating TensorFlow device (/device:GPU:0) -> (device: 0, name: Tesla K80, pci bus id: 2fd7:00:00.0, compute capability: 3.7)
    2019-05-16 16:08:36.076962: I tensorflow/stream_executor/dso_loader.cc:139] successfully opened CUDA library libcupti.so.8.0 locally
    Successfully downloaded train-images-idx3-ubyte.gz 9912422 bytes.
    Extracting /tmp/tensorflow/input_data/train-images-idx3-ubyte.gz
    Successfully downloaded train-labels-idx1-ubyte.gz 28881 bytes.
    Extracting /tmp/tensorflow/input_data/train-labels-idx1-ubyte.gz
    Successfully downloaded t10k-images-idx3-ubyte.gz 1648877 bytes.
    Extracting /tmp/tensorflow/input_data/t10k-images-idx3-ubyte.gz
    Successfully downloaded t10k-labels-idx1-ubyte.gz 4542 bytes.
    Extracting /tmp/tensorflow/input_data/t10k-labels-idx1-ubyte.gz
    Accuracy at step 0: 0.1081
    Accuracy at step 10: 0.7457
    Accuracy at step 20: 0.8233
    Accuracy at step 30: 0.8644
    Accuracy at step 40: 0.8848
    Accuracy at step 50: 0.8889
    Accuracy at step 60: 0.8898
    Accuracy at step 70: 0.8979
    Accuracy at step 80: 0.9087
    Accuracy at step 90: 0.9099
    Adding run metadata for 99
    Accuracy at step 100: 0.9125
    Accuracy at step 110: 0.9184
    Accuracy at step 120: 0.922
    Accuracy at step 130: 0.9161
    Accuracy at step 140: 0.9219
    Accuracy at step 150: 0.9151
    Accuracy at step 160: 0.9199
    Accuracy at step 170: 0.9305
    Accuracy at step 180: 0.9251
    Accuracy at step 190: 0.9258
    Adding run metadata for 199
    [...]
    Adding run metadata for 499
    ```

## Clean up resources

Remove the associated Kubernetes objects you created in this article using the [`kubectl delete job`][kubectl delete] command.

```console
kubectl delete jobs samples-tf-mnist-demo
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
[nvidia-github]: https://github.com/NVIDIA/k8s-device-plugin/blob/4b3d6b0a6613a3672f71ea4719fd8633eaafb4f3/deployments/static/nvidia-device-plugin.yml

<!-- LINKS - internal -->
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az_aks_nodepool_update
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az_aks_nodepool_add
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
[aks-spark]: spark-job.md
[gpu-skus]: /azure/virtual-machines/sizes-gpu
[install-azure-cli]: /cli/azure/install-azure-cli
[azureml-aks]: /azure/machine-learning/how-to-attach-kubernetes-anywhere
[azureml-deploy]: /azure/machine-learning/how-to-deploy-managed-online-endpoints
[azureml-triton]: /azure/machine-learning/how-to-deploy-with-triton
[aks-container-insights]: monitor-aks.md#integrations
[nvidia-gpu-operator]: nvidia-gpu-operator.md
[advanced-scheduler-aks]: operator-best-practices-advanced-scheduler.md
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[NVadsA10]: /azure/virtual-machines/nva10v5-series
