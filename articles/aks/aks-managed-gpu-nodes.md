---
title: Create an AKS-managed GPU node pool on Azure Kubernetes Service (AKS)
description: Learn how to provision a fully managed GPU node pool on your new or existing cluster on Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.subservice: aks-developer
ms.date: 4/27/2026
author: sachidesai
ms.author: sachidesai
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: As a cluster administrator or developer, I want to provision an Azure Kubernetes Service (AKS) cluster with GPU-enabled node pools, without deploying or managing the fundamental GPU software and observability components myself.
---

# Create a fully managed GPU node pool on Azure Kubernetes Service (AKS) (preview)

Running NVIDIA GPU workloads on Azure Kubernetes Service (AKS) traditionally requires you to install and maintain the NVIDIA GPU driver, Kubernetes device plugin, and a GPU metrics exporter on each GPU node. These components enable GPU scheduling, container-level GPU access, and telemetry, but installing them manually or through the [NVIDIA GPU Operator](./nvidia-gpu-operator.md) adds operational overhead.

With fully managed GPU nodes (preview), AKS installs and maintains the NVIDIA GPU driver, device plugin, and Data Center GPU Manager [(DCGM) metrics exporter](https://github.com/NVIDIA/dcgm-exporter/tree/main) for you. GPU node pool creation becomes a single step, and GPU capacity behaves like any other AKS node pool.

You configure a managed GPU node pool through two fields under `gpuProfile.nvidia`:

- `managementMode` (`Managed` or `Unmanaged`) controls whether AKS installs the full managed GPU stack (driver, device plugin, and DCGM metrics exporter) or the driver only. The default is `Unmanaged`.
- `migStrategy` (`None`, `Single`, or `Mixed`) sets the Multi-Instance GPU (MIG) strategy for supported GPU SKUs such as A100 and H100. The default is `None`.

In this article, you provision a managed GPU node pool, optionally enable MIG, verify the stack, and run a sample GPU workload.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Before you begin

- This article assumes you have an existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
- You need the Azure CLI version 2.85.0 or later installed. To find the version, run `az --version`. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
- You need to [install and upgrade to latest version of the `aks-preview` extension](#install-the-aks-preview-cli-extension).
- Get the credentials for your AKS cluster with [`az aks get-credentials`][az-aks-get-credentials] before running the `kubectl` examples in this article.

## Managed GPU components

A managed GPU node pool can include the following components on every node:

| Component | What it does | What AKS manages |
| --- | --- | --- |
| **NVIDIA GPU driver** | Kernel modules and user-space libraries that let the OS and containers talk to the GPU hardware. | Driver version selection, installation at node provisioning, and reinstallation after node image upgrades. |
| **NVIDIA Kubernetes device plugin** | DaemonSet-equivalent that advertises GPU resources (`nvidia.com/gpu`, `nvidia.com/mig-*`) to the kubelet so pods can request them. | Deployment, configuration (including MIG strategy), and lifecycle on each GPU node. |
| **NVIDIA DCGM and DCGM metrics exporter** | [Data Center GPU Manager](https://github.com/NVIDIA/dcgm-exporter/tree/main) collects GPU health and utilization data and exposes Prometheus metrics (for example, `DCGM_FI_DEV_GPU_UTIL`, `DCGM_FI_DEV_GPU_TEMP`) on port `19400`. | Installation, service enablement, and the `kubernetes.azure.com/dcgm-exporter=enabled` node label used to scrape metrics. |
| **GPU health signals** | NPD signals that surface GPU-specific node conditions such as `UnhealthyNvidiaDevicePlugin` and `UnhealthyNvidiaDCGMServices`. | NPD monitoring and condition reporting on GPU nodes. |

### Install profiles

Two `gpuProfile` fields decide which of those components AKS installs:

- `gpuProfile.driver` (`Install` or `None`): whether AKS installs the NVIDIA GPU driver.
- `gpuProfile.nvidia.managementMode` (`Managed` or `Unmanaged`): whether AKS also installs the Kubernetes-facing GPU stack on top of the driver.

Together, they produce three install profiles:

| Install profile | CLI flags | What AKS installs and manages |
| --- | --- | --- |
| **Full managed stack** | `--enable-managed-gpu=true` (or neither flag) | All four components above: driver, device plugin, DCGM metrics exporter, and GPU health monitoring in NPD. |
| **Driver only** (default) | `--enable-managed-gpu=false` | NVIDIA GPU driver only. You install and manage the device plugin, metrics exporter, and health monitoring yourself (for example, with the [NVIDIA GPU Operator](./nvidia-gpu-operator.md)). |
| **None (BYO)** | `--enable-managed-gpu=false --gpu-driver None` | Nothing. AKS doesn't install any of the four components. You own the full stack. See [Bring your own GPU driver](#alternative-install-profiles). |

### Defaults and overrides

- **Defaults**: If you don't pass `--enable-managed-gpu` or `--gpu-driver`, AKS applies the **Driver only** profile on the node pool created with an **NVIDIA** GPU-enabled VM size.
- **Override**: `managementMode: Managed` requires the driver, so `--gpu-driver None` is ignored when `--enable-managed-gpu=true` and the driver is still installed. To skip the driver, set both `--enable-managed-gpu=false` and `--gpu-driver None`.
- **Immutability**: `managementMode`, `migStrategy`, and `driver` are all fixed at creation time. To change profile, create a new node pool.

### Install the `aks-preview` CLI extension

1. Install the `aks-preview` CLI extension using the [`az extension add`][az-extension-add] command. Version 19.0.0b29 or later is required.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update the extension to ensure you have the latest version installed using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the `ManagedGPUExperiencePreview` feature flag

Register the `ManagedGPUExperiencePreview` feature flag in your subscription using the [`az feature register`][az-feature-register] command.

```azurecli-interactive
az feature register --namespace Microsoft.ContainerService --name ManagedGPUExperiencePreview
```

## Limitations

- This feature currently supports [NVIDIA GPU-enabled virtual machine (VM) sizes](/azure/virtual-machines/sizes-gpu) only.
- Updating a general-purpose node pool to add a GPU VM size isn't supported on AKS.
- Windows node pools aren't supported with this feature, because GPU metrics aren't supported. When you create Windows GPU node pools, AKS automatically installs and manages the drivers and DirectX device plugin. For more information, see the [AKS Windows GPU documentation](./use-windows-gpu.md).
- Migrating your existing [multi-instance GPU](./gpu-multi-instance.md) node pools to use this feature isn't supported.
- In-place upgrades from an existing NVIDIA GPU node pool to a managed GPU node pool aren't supported. To migrate, cordon and drain your existing GPU nodes, then redeploy your workloads to a new GPU node pool created with `--enable-managed-gpu=true`. For more information, see [Resize node pools on AKS](./resize-node-pool.md).
- The `managementMode`, `migStrategy`, and `driver` fields under `gpuProfile` are immutable after node pool creation. To change these values, create a new node pool.
- Cluster autoscaler isn't supported on managed GPU node pools during preview. Scale these pools manually.

> [!NOTE]
> GPU-enabled VMs contain specialized hardware subject to higher pricing and region availability. For more information, see the [pricing][azure-pricing] tool and [region availability][azure-availability].

## Create an AKS-managed GPU node pool (preview)

Add a managed GPU node pool to an existing AKS cluster by passing `--enable-managed-gpu=true` to [`az aks nodepool add`][az-aks-nodepool-add]. AKS sets `gpuProfile.nvidia.managementMode` to `Managed` and installs the GPU driver, device plugin, and DCGM metrics exporter automatically.

### [Ubuntu Linux node pool (default SKU)](#tab/add-ubuntu-gpu-node-pool)

To use the default Ubuntu operating system (OS) SKU, you create the node pool without specifying an OS SKU. The node pool is configured for the default operating system based on the Kubernetes version of the cluster.

1. Add a node pool to your cluster using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--enable-managed-gpu=true` flag.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name gpunp \
        --node-count 1 \
        --node-vm-size Standard_NC6s_v3 \
        --node-taints sku=gpu:NoSchedule \
        --enable-managed-gpu=true
    ```

1. Confirm that the managed NVIDIA GPU software components are installed successfully:

    ```azurecli-interactive
    az aks nodepool show \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name gpunp
    ```

    Your output should include the following values:

    ```output
    ...
    "gpuProfile": {
        "driver": "Install",
        "driverType": "",
        "nvidia": {
            "managementMode": "Managed",
            "migStrategy": null
        }
    },
    ...
    ```

### [Azure Linux node pool](#tab/add-azure-linux-gpu-node-pool)

To use Azure Linux, you specify the OS SKU by setting `--os-sku` to `AzureLinux` during node pool creation. The `os-type` is set to `Linux` by default.


1. Add a node pool to your cluster using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--os-sku` flag set to `AzureLinux` and `--enable-managed-gpu=true`.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name gpunp \
        --node-count 1 \
        --os-sku AzureLinux \
        --node-vm-size Standard_NC6s_v3 \
        --node-taints sku=gpu:NoSchedule \
        --enable-managed-gpu=true
    ```

1. Confirm that the managed NVIDIA GPU software components are installed successfully:

    ```azurecli-interactive
    az aks nodepool show \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name gpunp
    ```

    Your output should include the following values:

    ```output
    ...
    "gpuProfile": {
        "driver": "Install",
        "driverType": "",
        "nvidia": {
            "managementMode": "Managed",
            "migStrategy": null
        }
    },
    ...
    ```

---

## Create a managed Multi-Instance GPU (MIG) node pool (preview)

For GPU SKUs that support Multi-Instance GPU (such as A100 and H100), configure a MIG strategy at node pool creation with the `--gpu-mig-strategy` flag. The strategy controls how MIG partitions are exposed to Kubernetes:

- `Single`: All MIG instances are aggregated under the standard `nvidia.com/gpu` resource.
- `Mixed`: Each MIG profile is exposed as a separate resource, such as `nvidia.com/mig-1g.10gb`.
- `None` (default): MIG isn't configured.

The `migStrategy` field is immutable after the node pool is created.

For background on MIG partitioning, supported VM sizes, and GPU instance profiles, see [Create a multi-instance GPU node pool in AKS](./gpu-multi-instance.md) and [NVIDIA Multi-Instance GPU](https://docs.nvidia.com/datacenter/tesla/mig-user-guide/).

### [Single strategy](#tab/mig-single)

```azurecli-interactive
az aks nodepool add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name mignp \
    --node-count 1 \
    --node-vm-size Standard_NC24ads_A100_v4 \
    --node-taints sku=gpu:NoSchedule \
    --enable-managed-gpu=true \
    --gpu-instance-profile MIG1g \
    --gpu-mig-strategy Single
```

With this configuration, pods request GPU resources using the standard `nvidia.com/gpu` resource name.

### [Mixed strategy](#tab/mig-mixed)

```azurecli-interactive
az aks nodepool add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name mignp \
    --node-count 1 \
    --node-vm-size Standard_NC24ads_A100_v4 \
    --node-taints sku=gpu:NoSchedule \
    --enable-managed-gpu=true \
    --gpu-instance-profile MIG1g \
    --gpu-mig-strategy Mixed
```

With this configuration, pods request specific MIG partitions, for example `nvidia.com/mig-1g.10gb: 1`.

---

## Verify the managed GPU node pool (preview)

After the node pool is ready, run the following checks to confirm that the full managed stack is installed and healthy.

1. Verify GPU-specific node conditions from Node Problem Detector (NPD):

    ```bash
    GPU_NODE=$(kubectl get nodes -l agentpool=gpunp -o jsonpath='{.items[0].metadata.name}')
    kubectl describe node $GPU_NODE
    ```

    On a managed GPU node, the following conditions should both report `False`:

    | Condition | Status | Reason |
    | --- | --- | --- |
    | `UnhealthyNvidiaDevicePlugin` | `False` | `HealthyNvidiaDevicePlugin` |
    | `UnhealthyNvidiaDCGMServices` | `False` | `HealthyNvidiaDCGMServices` |

1. Verify that the managed GPU label is present on the node:

    ```bash
    kubectl get node $GPU_NODE -o jsonpath='{.metadata.labels.kubernetes\.azure\.com/dcgm-exporter}'
    ```

    Expected output: `enabled`.

1. Verify that GPU resources are advertised in the node's allocatable resources:

    ```bash
    kubectl get node $GPU_NODE -o jsonpath='{.status.allocatable}'
    ```

    For a non-MIG node pool, the output includes `"nvidia.com/gpu": "1"` (or more, depending on the SKU). For a MIG `Mixed` node pool, the output includes MIG-specific resources such as `"nvidia.com/mig-1g.10gb": "7"`.

1. Run a sample workload to confirm GPU access from within a container:

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: managed-gpu-test
    spec:
      restartPolicy: Never
      tolerations:
        - key: "sku"
          operator: "Equal"
          value: "gpu"
          effect: "NoSchedule"
      containers:
      - name: gpu-test
        image: mcr.microsoft.com/azuredocs/samples-tf-mnist-demo:gpu
        command: ["nvidia-smi"]
        resources:
          limits:
            nvidia.com/gpu: 1
    ```

    View the pod logs to see `nvidia-smi` output showing the GPU device, driver version, and CUDA version:

    ```bash
    kubectl logs managed-gpu-test
    ```

## Scale a managed GPU node pool (preview)

Scale a managed GPU node pool manually with [`az aks nodepool scale`][az-aks-nodepool-scale]. New nodes install the full managed GPU stack.

```azurecli-interactive
az aks nodepool scale \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name gpunp \
    --node-count 2
```

> [!IMPORTANT]
> During preview, managed GPU node pools don't support the cluster autoscaler. Scale these pools manually.

## Alternative install profiles

If the **Full managed stack** profile isn't the right fit, AKS supports two alternative profiles on GPU node pools.

### [Driver only (preview)](#tab/driver-only)

Use this profile when you want AKS to install and maintain the NVIDIA GPU driver, but you plan to deploy the device plugin and metrics exporter yourself (for example, with the [NVIDIA GPU Operator](./nvidia-gpu-operator.md)). Set `--enable-managed-gpu=false`:

```azurecli-interactive
az aks nodepool add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name gpunp \
    --node-count 1 \
    --node-vm-size Standard_NC6s_v3 \
    --node-taints sku=gpu:NoSchedule \
    --enable-managed-gpu=false
```

With this configuration:

- AKS installs and manages the NVIDIA GPU driver (`gpuProfile.driver` is `Install`).
- AKS doesn't install a device plugin, DCGM metrics exporter, or GPU health rules. `gpuProfile.nvidia` is `null`.
- No `nvidia.com/gpu` resource is advertised until you deploy a device plugin.

### [Bring your own GPU driver](#tab/byo-driver)

Use this profile when you want to install the NVIDIA driver yourself (for example, to run the [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html)). Create the node pool with `--enable-managed-gpu=false --gpu-driver None`:

```azurecli-interactive
az aks nodepool add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name gpunp \
    --node-count 1 \
    --node-vm-size Standard_NC6s_v3 \
    --node-taints sku=gpu:NoSchedule \
    --enable-managed-gpu=false \
    --gpu-driver None
```

In this configuration, AKS installs no GPU software components: no driver, no device plugin, and no metrics exporter. Microsoft **doesn't support or manage** NVIDIA drivers or any other GPU components on these nodes. For more information, see [Skip GPU driver installation](./use-nvidia-gpu.md#skip-gpu-driver-installation).

---

## Next steps

- Deploy a [sample GPU workload](./use-nvidia-gpu.md#run-a-gpu-enabled-workload) on your AKS-managed GPU-enabled nodes.
- Learn about [GPU utilization and performance metrics](./monitor-gpu-metrics.md) from managed NVIDIA DCGM exporter on your GPU node pool.

## Related articles

- [Use NVIDIA GPUs on AKS](./use-nvidia-gpu.md) for the standard (non-managed) GPU experience.
- [Create a multi-instance GPU (MIG) node pool](./gpu-multi-instance.md) for background on MIG partitioning and supported VM sizes.
- [NVIDIA GPU Operator](./nvidia-gpu-operator.md) for managing GPU drivers and the device plugin yourself.
- [Monitor GPU metrics](./monitor-gpu-metrics.md) from the managed NVIDIA DCGM exporter.
- [GPU health monitoring](./gpu-health-monitoring.md) with Node Problem Detector (NPD) on AKS.
- [Use Windows GPUs on AKS](./use-windows-gpu.md) for Windows GPU node pools.
- [Azure GPU VM sizes](/azure/virtual-machines/sizes-gpu) for the full list of NVIDIA GPU-enabled VMs.
- Run [distributed inference on multiple AKS GPU nodes](https://blog.aks.azure.com/2025/07/08/kaito-inference-with-acstor).

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
[az-aks-nodepool-scale]: /cli/azure/aks/nodepool#az_aks_nodepool_scale
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
