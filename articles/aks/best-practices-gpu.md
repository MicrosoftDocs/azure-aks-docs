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

## Overview

Running GPU workloads on an AKS cluster requires proper setup and continuous validation to ensure that compute resources are accessible, secure, and optimally utilized. This article outlines best practices for managing GPU-enabled nodes, validating configurations, and troubleshooting common issues using vendor-specific diagnostic commands.

GPU workloads like AI model training, real-time inference, simulations, and video processing often depend on:

* Correct GPU driver and runtime compatibility
* Accurate scheduling of GPU resources
* Access to GPU hardware devices inside containers

Misconfigurations can lead to high costs, unexpected job failures, or GPU underutilization.

## Best Practices

1. Ensure that a taint such as `[gpu-vendor].com/gpu: NoSchedule` is applied to your GPU nodes, where `gpu-vendor` may be `nvidia`, `amd`, etc. This taint prevents any pod from running on the node unless the GPU workload pod has a matching toleration.

The scheduler will attempt to run your pods on any node that has enough CPU and memory, unless told otherwise.

Without setting a specific rule: 

* A GPU workload may land on a non-GPU node and fail to start.
* A general-purpose workload (like a web service) might land on a GPU node and consume expensive GPU resources.

Setting a resource limit like:

```bash
resources:
  limits:
    [gpu-vendor].com/gpu: 1
```

Together with a toleration such as:

```bash
tolerations:
- key: "[gpu-vendor].com/gpu"
  operator: "Exists"
  effect: "NoSchedule"
```

Guarantees that your GPU workload deployment pod is placed on a GPU node and receives access to the GPU.

2. Before deploying production GPU workloads, always validate that your GPU node pools are:

* Equipped with compatible GPU drivers
* Hosting a healthy Kubernetes Device Plugin DaemonSet
* Exposing `[gpu-vendor].com/gpu` as a schedulable resource

You can confirm the current driver version running on your GPU node pools by deploying a simple diagnostic pod that uses a system management interface associated with the GPU vendor. The following example manifest runs the `nvidia-smi` command once to verify driver installation and runtime readiness on an NVIDIA GPU-enabled node pool:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nvidia-smi-test
spec:
  restartPolicy: Never
  containers:
  - name: nvidia-smi
    image: nvidia/cuda:12.2.0-base
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
```

Apply the manifest above using the `kubectl apply` command:

```bash
kubectl apply -f nvidia-smi-test.yaml
kubectl get pods
kubectl logs nvidia-smi-test
```

The expected output should look like:

```bash
+-----------------------------------------------------------------------------+
|NVIDIA-SMI 570.xx.xx    Driver Version: 570.xx.xx    CUDA Version: 12.x|
...
...
```

3. Upgrade your GPU node pools to the latest recommended node OS image released by AKS. These images are:

* Pre-configured with up-to-date GPU drivers, upgraded from EOL driver branches
* Tested against the your current Kubernetes version
* Patched for known vulnerabilities surfaced by the GPU vendor (e.g., NVIDIA) guidance
* Aligned with OS and container runtime updates

You can track AKS node image releases using [AKS release tracker](https://releases.aks.azure.com/).

4. If multiple teams (like ML, data science, video processing, etc.) are using a shared AKS cluster with GPU node pools, their workloads should be separated to:

* Avoid accidental access to or block the usage of each other’s resources
* Improve security and compliance
* Make it easier to manage and monitor which team is consuming GPU resources

GPU workloads on a single AKS cluster should be separated using namespaces and network policies. This makes it easier to apply usage limits, quotas, and logging per namespace.

For example, the following two teams are deploying GPU workloads which do not require cross-node communication with each other:

* Team A (ML researchers) running training jobs
* Team B (Computer vision team) running real-time inference

Start by creating dedicated namespaces per team:

```bash
kubectl create namespace team-a-gpu
kubectl create namespace team-b-gpu
```

Label GPU workload deployment pods by team, where an example pod spec may look like:

```yaml
metadata:
  namespace: team-a-gpu
  labels:
    team: ml
```

Add network policies to isolate traffic. The following manifest blocks cross-namespace traffic, except what is explicitly allowed:

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

* Applies to all pods in `team-a-gpu`
* Blocks all inbound and outbound traffic by default

Exceptions can be added as needed (e.g., allow traffic to a shared metrics service or to an internal API)

5. Different GPU workloads range in memory requirements, and smaller deployments may not need an entire GPU (e.g., NVIDIA A100 40GB). However, a single workload by default monopolizes the GPU resource even when underutilized. Azure Kubernetes Service supports resource optimization on GPU nodes by splitting them into smaller slices using multi-instance GPU (MIG), so that teams can schedule smaller jobs more efficiently. Learn more about the supported GPU sizes and how to get started with [multi-instance GPU on AKS](./gpu-multi-instance.md).


## Next Steps

* [Create a GPU-enabled node pool](./use-nvidia-gpu.md) on your AKS cluster.
* Monitor GPU workloads using [self-managed NVIDIA DCGM exporter](./monitor-gpu-metrics.md).
* Auto-scale your GPU workloads based on common GPU metrics with [KEDA and DCGM exporter](./autoscale-gpu-workloads-with-keda.md).