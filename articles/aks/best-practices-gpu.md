---
title: GPU best practices for Azure Kubernetes Service (AKS)
description: Learn the best practices for managing your GPU-enabled node pools on Azure Kubernetes Service (AKS)
ms.topic: best-practice
ms.service: azure-kubernetes-service
ms.date: 7/31/2025
author: sachidesai
ms.author: sachidesai
# Customer intent: "As a cloud operations engineer managing GPU workloads on AKS, I want to enforce strong security practices and maintain consistent lifecycle management of GPU node pools, so I can ensure compliance, reduce risk, and keep the GPU infrastructure reliable and maintainable."
---

# GPU best practices for Azure Kubernetes Service (AKS)

Running GPU workloads on an AKS cluster requires proper setup and continuous validation to ensure that compute resources are accessible, secure, and optimally utilized. This article outlines best practices for managing GPU-enabled nodes, validating configurations, and troubleshooting common issues using vendor-specific diagnostic commands.

GPU workloads, like AI model training, real-time inference, simulations, and video processing, often depend on the following configurations:

* Correct GPU driver and runtime compatibility.
* Accurate scheduling of GPU resources.
* Access to GPU hardware devices inside containers.

Misconfigurations can lead to high costs, unexpected job failures, or GPU underutilization.


## Apply specific rules and limits to GPU nodes

Apply a taint, such as `[gpu-vendor].com/gpu: NoSchedule` (where `gpu-vendor` might be `nvidia`, `amd`, etc.), to your GPU nodes. This taint prevents any pod from running on the node unless the GPU workload pod has a matching toleration.

The scheduler will attempt to run your pods on any node that has enough CPU and memory, unless told otherwise.

Without setting a specific rule: 

* A GPU workload might land on a non-GPU node and fail to start.
* A general-purpose workload (like a web service) might land on a GPU node and consume expensive GPU resources.

To guarantee that your GPU workload deployment pod is placed on a GPU node and receives access to the GPU, you can set a resource limit such as:

```bash
resources:
  limits:
    [gpu-vendor].com/gpu: 1

## Verify readiness of GPU node pools before deploying production workloads

Before deploying production GPU workloads, always validate that your GPU node pools are:

* Equipped with compatible GPU drivers.
* Hosting a healthy Kubernetes Device Plugin DaemonSet.
* Exposing `[gpu-vendor].com/gpu` as a schedulable resource.

You can confirm the current driver version running on your GPU node pools with the system management interface (SMI) associated with the GPU vendor. The following command executes `nvidia-smi` from inside your GPU device plugin deployment pod, to verify driver installation and runtime readiness on an NVIDIA GPU-enabled node pool:

```bash
kubectl exec -it $"{GPU_DEVICE_PLUGIN_POD}" -n {GPU_NAMESPACE} -- nvidia-smi

Your output should resemble the following example output:

```output
+-----------------------------------------------------------------------------+
|NVIDIA-SMI 570.xx.xx    Driver Version: 570.xx.xx    CUDA Version: 12.x|
...
...
```

Repeat the step above for each GPU node pool to confirm the driver version installed on your nodes. 

On your AMD GPU-enabled node pools, alternatively [deploy the AMD GPU components](./use-amd-gpus.md) and execute the `amd-smi` command in the ROCm device plugin pod to confirm the driver version that is installed.

## Upgrade GPU node pools to latest node OS image

Upgrade your GPU node pools to the latest recommended node OS image released by AKS. These images are:

* Pre-configured with the latest GPU driver, to use the production branch upgraded from EOL driver branch(es).
* Tested against your current Kubernetes version.
* Patched for known vulnerabilities surfaced by the GPU vendor (e.g. NVIDIA) guidance.
* Aligned with OS and container runtime upgrades.

You can track AKS node image releases using [AKS release tracker](https://releases.aks.azure.com/).

## Separate GPU workloads when using shared clusters

If multiple teams (like ML, data science, video processing, etc.) are using a shared AKS cluster with GPU node pools, their workloads should be separated to:

* Avoid accidental access to or block the usage of each other’s resources.
* Improve security and compliance.
* Make it easier to manage and monitor which team is consuming GPU resources.

You can separate GPU workloads on a single AKS cluster using namespaces and network policies. This separation makes it easier to apply usage limits, quotas, and logging per namespace.

### Example scenario

For example, the following two teams are deploying GPU workloads that don't require cross-node communication with each other:

* Team A: ML research team running training jobs.
* Team B: Computer vision team running real-time inference.

You can use the following steps to separate the two workloads:

1. Create dedicated namespaces per team using the `kubectl create namespace` command.

    ```bash
    kubectl create namespace team-a-gpu
    kubectl create namespace team-b-gpu
    ```

2. Label GPU workload deployment pods by team, as shown in the following pod spec:

    ```yaml
    metadata:
      namespace: team-a-gpu
      labels:
        team: ml
    ```

3. Add network policies to isolate traffic, as shown in the following manifest that blocks cross-namespace traffic (except for what's explicitly allowed):

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

    * Applies to all pods in `team-a-gpu`.
    * Blocks all inbound and outbound traffic by default.

You can add exceptions (e.g. allow traffic to a shared metrics service or to an internal API) as needed.


## Optimize resource usage on GPU nodes using multi-instance GPU (MIG)

Different GPU workloads range in memory requirements, and smaller deployments (e.g. NVIDIA A100 40GB) might not need an entire GPU. However, a single workload by default monopolizes the GPU resource even when underutilized. 

AKS supports resource optimization on GPU nodes by splitting them into smaller slices using multi-instance GPU (MIG), so that teams can schedule smaller jobs more efficiently. Learn more about the supported GPU sizes and how to get started with [multi-instance GPU on AKS](./gpu-multi-instance.md).


## Next steps

For more information on GPU workloads on AKS, see the following articles:

* [Create a GPU-enabled node pool](./use-nvidia-gpu.md) on your AKS cluster.
* Monitor GPU workloads using [self-managed NVIDIA DCGM exporter](./monitor-gpu-metrics.md).
* Auto-scale your GPU workloads based on common GPU metrics with [KEDA and DCGM exporter](./autoscale-gpu-workloads-with-keda.md).
