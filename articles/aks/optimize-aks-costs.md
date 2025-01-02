---
title: Optimize Azure Kubernetes Service (AKS) usage and costs
description: Learn different ways to optimize your Azure Kubernetes Service (AKS) usage and costs.
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 01/02/2025
---

# Optimize Azure Kubernetes Service (AKS) usage and costs

This article provides guidance on how to optimize your Azure Kubernetes Service (AKS) usage and costs. It covers the following topics:

* [Automatic scaling](#automatic-scaling)
* [GPU optimizations](#gpu-optimizations)
* [Cluster rightsizing](#cluster-rightsizing)
* [Multitenancy](#multitenancy)
* [Azure discounts](#azure-discounts)

## About cost optimization

## Automatic scaling

### Horizontal pod autoscaling

The Horizontal Pod Autoscaler (HPA) monitors resource demand and automatically updates a workload resource to automatically scale the number of pods to match demand. The response to increased load is to deploy more pods. If the load decreases and the number of pods is above the configured minimum, the autoscaler tells the workload resource to scale down.

The Metrics API gets data from the kubelet every 60 seconds, and the HPA checks the Metrics API every 15 seconds for any needed changes by default. This means that the HPA updates every 60 seconds. When you configure the HPA for a deployment, you define the minimum and maximum number of replicas that can run and the metrics that the HPA uses to determine when to scale.

For more information, see [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) and [Autoscale pods in AKS](./tutorial-kubernetes-scale.md#autoscale-pods).

### Kubernetes event-driven autoscaling

The [Kubernetes Event-driven Autoscaler (KEDA)](https://keda.sh/) applies event-driven autoscaling to your workloads. KEDA works with the HPA and can extend functionality without overwriting or duplication.

You can use the KEDA add-on for AKS to scale your applications and leverage a [rich catalog of Azure KEDA scalers](https://keda.sh/docs/2.16/scalers/). For more information, see [Application autoscaling with the KEDA add-on](./keda-about.md) and [Install the KEDA add-on for AKS](./keda-deploy-add-on-cli.md).

### Vertical pod autoscaling

The Vertical Pod Autoscaler (VPA) automatically sets resource requests and limits on containers per workload based on past usage. The VPA frees up CPU and Memory for pods to ensure effective utilization of your AKS clusters. Over time, the VPA provides recommendations for resource usage.

For more information, see [Vertical pod autoscaling in Azure Kubernetes Service (AKS)](./vertical-pod-autoscaler.md) and [Use the Vertical Pod Autoscaler (VPA) in Azure Kubernetes Service (AKS)](./use-vertical-pod-autoscaler.md).

## GPU optimizations

### Collect GPU metrics

### GPU partitioning and sharing

GPU partitioning helps combat underutilization by splitting up or sharing GPUs across multiple workloads. The following sections cover different ways to partition and share GPUs in AKS.

#### Time-slicing

The [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/overview.html) enables the **time-slicing** of GPUs in Kubernetes clusters. With time-slicing, a system administrator can define a set of *replicas* for a GPU, each of which can be handed out independently to a pod to run workloads on. You can apply cluster-wide default time-slicing configurations and node-specific configurations.

:::image type="content" source="./media/optimize-aks-costs/time-slicing-gpu.png" alt-text="Screenshot of a visual chart example showing GPU time-slicing.":::

For more information, see [Time-slicing GPUs in Kubernetes](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html).

#### Multi-processing service (MPS)

A single process might not utilize all the memory and compute bandwidth capacity available on a GPU. The Multi-Process Service (MPS) enables logical partitioning of memory and compute resources between workloads and allows kernel and memcopy operations from different processes to overlap on the GPU. MPS helps you achieve higher GPU utilization and shorter running times.

:::image type="content" source="./media/optimize-aks-costs/mps-gpu.png" alt-text="Screenshot of a visual chart example showing GPU multi-process service (MPS).":::

For more information, see [Multi-Process Service (MPS)](https://docs.nvidia.com/deploy/mps/index.html#mps).

#### Multi-instance GPUs (MIGs)

Multi-instance GPUs (MIGs) enable you to partition GPUs based on the NVIDIA Ampere and later architectures into separate and secure GPU instances for CUDA applications.

:::image type="content" source="./media/optimize-aks-costs/migs-gpu.png" alt-text="Screenshot of a visual chart example showing GPU multi-instance GPUs (MIGs).":::

For more information, see [GPU Operator with MIG](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-operator-mig.html).

## Cluster rightsizing

### Rightsize your cluster

### Cluster autoscaling

### Node autoprovisioning (preview)



## Multitenancy

### Dedicated cluster

### Dedicated node pool

### Dedicated namespace

## Azure discounts

* Azure Savings Plans
* Reserved Instances
* Azure Hybrid Benefits

## Next steps

XYZ.
