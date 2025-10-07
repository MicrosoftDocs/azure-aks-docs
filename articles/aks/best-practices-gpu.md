---
title: GPU best practices for Azure Kubernetes Service (AKS)
description: Learn the best practices for managing your GPU-enabled node pools on Azure Kubernetes Service (AKS)
ms.topic: best-practice
ms.service: azure-kubernetes-service
ms.date: 8/26/2025
author: sachidesai
ms.author: sachidesai
# Customer intent: "As a cloud operations engineer managing GPU workloads on AKS, I want to enforce strong security practices and maintain consistent lifecycle management of GPU node pools, so I can ensure compliance, reduce risk, and keep the GPU infrastructure reliable and maintainable."
---

# GPU best practices for Azure Kubernetes Service (AKS)

Running GPU workloads on an AKS cluster requires proper setup and continuous validation to ensure that compute resources are accessible, secure, and optimally utilized. This article outlines best practices for managing GPU-enabled nodes, validating configurations, and reducing workload interruptions using vendor-specific diagnostic commands.

GPU workloads, like AI model training, real-time inference, simulations, and video processing, often depend on the following configurations:

* Correct GPU driver and runtime compatibility.
* Accurate scheduling of GPU resources.
* Access to GPU hardware devices inside containers.

Misconfigurations can lead to high costs, unexpected job failures, or GPU underutilization.

## Enforce GPU workload placement

By default, the AKS scheduler places pods on any available node with sufficient CPU and memory. Without guidance, this can lead to two key issues: 

1. GPU workloads may be scheduled on nodes without GPUs and fail to start, or
2. General-purpose workloads may occupy GPU nodes, wasting costly resources.

To enforce correct placement:

* Taint your GPU nodes using a key like `[gpu-vendor].com/gpu: NoSchedule` (e.g., nvidia.com/gpu: NoSchedule). This blocks non-GPU workloads from being scheduled there.
* Add a matching toleration in your GPU workload pod spec so it can be scheduled on the tainted GPU nodes.
* Define GPU resource requests and limits in your pod, to ensure the scheduler reserves GPU capacity, such as:

```bash
resources:
  limits:
    [gpu-vendor].com/gpu: 1
```

* Use validation policies or admission controllers to enforce that GPU workloads include the required tolerations and resource limits.

This approach guarantees that only GPU-ready workloads land on GPU nodes and have access to the specialized compute resources they require.

Before deploying production GPU workloads, always validate that your GPU node pools are:

* Equipped with compatible GPU drivers.
* Hosting a healthy Kubernetes Device Plugin DaemonSet.
* Exposing `[gpu-vendor].com/gpu` as a schedulable resource.

You can confirm the current driver version running on your GPU node pools with the system management interface (SMI) associated with the GPU vendor. 

The following command executes `nvidia-smi` from inside your GPU device plugin deployment pod, to verify driver installation and runtime readiness on an NVIDIA GPU-enabled node pool:

```bash
kubectl exec -it $"{GPU_DEVICE_PLUGIN_POD}" -n {GPU_NAMESPACE} -- nvidia-smi
```

Your output should resemble the following example output:

```output
+-----------------------------------------------------------------------------+
|NVIDIA-SMI 570.xx.xx    Driver Version: 570.xx.xx    CUDA Version: 12.x|
...
...
```

Repeat the step above for each GPU node pool to confirm the driver version installed on your nodes. 

On your AMD GPU-enabled node pools, alternatively [deploy the AMD GPU components](./use-amd-gpus.md) and execute the `amd-smi` command in the ROCm device plugin pod to confirm the driver version that is installed.

## Keep GPU-enabled nodes updated to the latest node OS image

To ensure the performance, security, and compatibility of your GPU workloads on AKS, it's essential to keep your GPU node pools up to date with the latest recommended node OS images. These updates are critical because they:

* Include the latest production-grade GPU drivers, replacing any deprecated or end-of-life (EOL) versions.
* Are fully tested for compatibility with your current Kubernetes version.
* Address known vulnerabilities identified by GPU vendors.
* Incorporate the latest OS and container runtime improvements for enhanced stability and efficiency.

Upgrade your GPU node pool(s) to the latest recommended node OS image released by AKS, either by setting the [autoupgrade channel](./auto-upgrade-node-os-image.md) or through [manual upgrade](./node-image-upgrade.md). You can monitor and track the latest node image releases using the [AKS release tracker](https://releases.aks.azure.com/).

## Separate GPU workloads when using shared clusters

If a single AKS cluster with GPU node pools is running multiple types of GPU workloads, such as model training, real-time inference, or batch processing, it's important to separate these workloads to:

* Avoid accidental interference or resource contention between different workload types.
* Improve security and maintain compliance boundaries.
* Simplify management and monitoring of GPU resource usage per workload category.

You can isolate GPU workloads within a single AKS cluster by using namespaces and network policies. This enables clearer governance through workload-specific quotas, limits, and logging configurations.

### Example scenario

Consider an AKS cluster hosting two different GPU workload types that don’t need to communicate with each other:

* Training Workloads: Resource-intensive AI model training jobs.
* Inference Workloads: Latency-sensitive real-time inference services.

You can use the following steps to separate the two workloads:

1. Create dedicated namespaces per workload type using the `kubectl create namespace` command.

    ```bash
    kubectl create namespace gpu-training
    kubectl create namespace gpu-inference
    ```

2. Label GPU workload pods by type, as shown in the following example:

    ```yaml
    metadata:
      namespace: gpu-training
      labels:
        workload: training
    ```

3. Apply network policies to isolate traffic between workload types. The following manifest blocks all ingress and egress for the `gpu-training` namespace (unless explicitly allowed):

    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: deny-cross-namespace
      namespace: gpu-training
    spec:
      podSelector: {}
      policyTypes:
      - Ingress
      - Egress
      ingress: []
      egress: []
    ```

This policy:
* Applies to all pods in the `gpu-training` namespace.
* Denies all incoming and outgoing traffic by default, supporting strong isolation.

This model enhances clarity, control, and safety in shared GPU environments, especially when workload types have different runtime profiles, risk levels, or operational requirements.

## Optimize resource usage on GPU nodes using multi-instance GPU (MIG)

Different GPU workloads range in memory requirements, and smaller deployments (e.g. NVIDIA A100 40GB) might not need an entire GPU. However, a single workload by default monopolizes the GPU resource even when underutilized. 

AKS supports resource optimization on GPU nodes by splitting them into smaller slices using multi-instance GPU (MIG), so that teams can schedule smaller jobs more efficiently. Learn more about the supported GPU sizes and how to get started with [multi-instance GPUs on AKS](./gpu-multi-instance.md).

## Use Ephemeral NVMe data disks as high-performance cache

For AI workloads running on GPU VMs in AKS, fast and reliable access to temporary storage is critical for maximizing training and inference performance. Ephemeral NVMe data disks provide high-throughput, low-latency storage directly attached to the VM host, making them ideal for scenarios such as caching datasets, storing intermediate checkpoints and model weights, or providing scratch space for data preprocessing and analytics.

When deploying GPU-enabled node pools for AI workloads, configure ephemeral NVMe data disks to serve as high-performance cache or scratch space. This approach helps eliminate I/O bottlenecks, accelerates data-intensive operations, and ensures that your GPU resources are not idling while waiting for data.

Ephemeral NVMe data disks are supported across a wide range of Azure GPU VM families. Depending on the GPU VM size, it has up to 8 ephemeral NVMe data disks with a combined capacity of up to 28 TiB. For detailed configurations on VM sizes, refer to the [ND H100 v5-series documentation](/azure/virtual-machines/sizes/gpu-accelerated/ndh100v5-series) or the VM size documentation for your chosen GPU family.


To simplify provisioning and management, use [Azure Container Storage](/azure/storage/container-storage/container-storage-introduction), which can automatically detect and orchestrate ephemeral NVMe disks for your Kubernetes workloads.

**Recommended scenarios include:**

- Caching large datasets and model checkpoints for AI training and inference.

- Caching model weights for AI inference. For example, [KAITO hosting model as OCI artifacts on local NVMe](https://kaito-project.github.io/kaito/docs/next/model-as-oci-artifacts/).
- Providing fast scratch space for batch jobs and data pipelines

> [!IMPORTANT]
> Data on ephemeral NVMe disks is temporary and will be lost if the VM is deallocated or redeployed. Use these disks only for non-critical, transient data, and store important information on persistent Azure storage solutions.

For detailed guidance, see [Use Azure Container Storage with AKS](/azure/storage/container-storage/use-container-storage-with-local-disk).

## Next steps

To learn more about GPU workload deployment and management on AKS, see the following articles:

* [Create a GPU-enabled node pool](./use-nvidia-gpu.md) on your AKS cluster.
* Monitor GPU workloads using [self-managed NVIDIA DCGM exporter](./monitor-gpu-metrics.md).

* Auto-scale your GPU workloads based on common GPU metrics with [KEDA and DCGM exporter](./autoscale-gpu-workloads-with-keda.md).
