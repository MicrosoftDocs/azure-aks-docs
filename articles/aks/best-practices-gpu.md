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

## Apply specific rules and limits to GPU nodes

Apply a taint, such as `[gpu-vendor].com/gpu: NoSchedule` (where `gpu-vendor` might be `nvidia`, `amd`, etc.), to your GPU nodes. This taint prevents any pod from running on the node, unless it is a GPU workload pod that has a matching toleration.

The AKS scheduler will attempt to run your pods on any node that has enough CPU and memory, if not told otherwise.

Without setting a specific rule: 

* A GPU workload might land on a non-GPU node and fail to start.
* A general-purpose workload (like a web service) might land on a GPU node unintentionally and consume expensive GPU resources.

To guarantee that your GPU-enabled workload targets a GPU node and receives access to the compute resource, you can set a resource limit such as:

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

Upgrade your GPU node pool(s) to the latest recommended node OS image released by AKS, either by setting the [autoupgrade channel](./auto-upgrade-node-os-image) or through [manual upgrade](./node-image-upgrade). You can monitor and track the latest node image releases using the [AKS release tracker](https://releases.aks.azure.com/).

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
      namespace: team-a-gpu
      labels:
        team: ml
    ```

3. Add network policies to isolate traffic, as shown in the following manifest that blocks cross-namespace traffic (except for what is explicitly allowed):

    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: deny-other-namespaces
      namespace: team-a-gpu
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

## Next steps

To learn more about GPU workload deployment and management on AKS, see the following articles:

* [Create a GPU-enabled node pool](./use-nvidia-gpu.md) on your AKS cluster.
* Monitor GPU workloads using [self-managed NVIDIA DCGM exporter](./monitor-gpu-metrics.md).
* Auto-scale your GPU workloads based on common GPU metrics with [KEDA and DCGM exporter](./autoscale-gpu-workloads-with-keda.md).