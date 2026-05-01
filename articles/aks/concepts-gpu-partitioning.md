---
title: GPU Node Partitioning Strategies in Azure Kubernetes Service (AKS)
description: Learn about scaling in Azure Kubernetes Service (AKS), including AKS managed multi-instance GPU (MIG) or time-slicing and multi-processing service (MPS) with self-managed NVIDIA GPU Operator
ms.topic: concept-article
ms.date: 05/01/2026
author: sachidesai
ms.author: sachidesai
ms.reviewer: schaffererin
ms.service: azure-kubernetes-service
# Customer intent: As an AKS cluster admin, I want to understand the different NVIDIA GPU node partitioning strategies available in AKS so that I can select the most cost effective and optimized method for isolating and sharing NVIDIA GPU resources in my production and experimental workloads.
---

# GPU node partitioning strategies in Azure Kubernetes Service (AKS)

Azure Kubernetes Service (AKS) supports NVIDIA GPU-enabled node pools to run compute-intensive workloads, including AI/ML training, real-time inferencing, and large-scale data analytics. Traditionally, GPUs are allocated in a one-to-one model, where a single Kubernetes pod consumes an entire GPU device within an Azure virtual machine (VM). While this model provides simplicity and strong isolation, it can lead to underutilization in scenarios where workloads do not fully consume available GPU resources in the cluster.

To improve utilization and support concurrent workloads, AKS supports several GPU partitioning strategies. These approaches enable multiple workloads to share a single physical GPU by dividing it into smaller logical units or by expanding access at the software or GPU driver level.

In this article, you learn about the three primary node partitioning strategies for NVIDIA GPUs in AKS: **Multi-Instance GPU (MIG)**, **time-slicing**, and **Multi-Process Service (MPS)**.

## Overview of GPU node partitioning strategies in AKS

The three primary strategies available in AKS environments are Multi-Instance GPU (MIG), time-slicing, and Multi-Process Service (MPS). Each approach differs in terms of isolation, performance predictability, operational complexity, and level of AKS platform management.

| Strategy | Managed or allowed on AKS | GPU sharing type | Recommended for |
| -------- | ---------------- | ---------------- | --------------- |
| Multi-Instance GPU (MIG)  | Managed | Hardware partitioning  | Production workloads   |
| Time-slicing (via NVIDIA GPU Operator) | User-managed, AKS allowed | Software scheduling  | Experimentation with variable GPU loads |
| Multi-Process Service (MPS, NVIDIA GPU Operator) | User-managed, AKS allowed | CUDA-level process multiplexing | Low-latency, high-throughput workloads  |

## Multi-Instance GPU (MIG) on AKS

Multi-Instance GPU (MIG) is a hardware-based partitioning capability available on select NVIDIA GPU architectures, such as A100 and H100 series. MIG enables a single physical GPU to be divided into multiple isolated instances, each with dedicated compute cores, memory, and cache. This ensures strong workload isolation and predictable performance characteristics, making MIG suitable for production environments.

In AKS, MIG is a managed capability. When a [MIG-enabled node pool](./gpu-multi-instance.md) is provisioned, Azure configures the GPU hardware, installs and maintains the required driver stack, and integrates MIG instances with Kubernetes through the NVIDIA device plugin. Each MIG slice is exposed to the Kubernetes scheduler as a discrete allocatable resource, allowing pods to request GPU capacity in a granular and deterministic manner.

This approach offers several advantages for enterprise deployments. It provides production-grade isolation through hardware-level partitioning and reduces operational overhead by delegating lifecycle management, including driver updates and configuration, to AKS. Additionally, MIG instances behave as independent GPU devices from the scheduler’s perspective, enabling predictable placement and resource allocation.

However, MIG also introduces certain constraints: partitioning configurations are static at the node pool level, meaning that changes require node reprovisioning. Flexibility is limited to predefined MIG profiles supported by the underlying GPU hardware.

## Time-slicing with NVIDIA GPU Operator (User-managed)

[Time-slicing](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/25.3.3/gpu-sharing.html) is a software-based GPU sharing mechanism that allows multiple Kubernetes pods to share a single GPU by interleaving execution over time. This approach is implemented through the NVIDIA GPU Operator, which manages GPU drivers, the Kubernetes device plugin, and container runtime configuration.

In AKS, time-slicing is supported but not managed. Cluster operators are responsible for deploying and configuring the NVIDIA GPU Operator, typically via Helm, and enabling time-slicing through device plugin settings. Once configured, multiple pods can request access to the same GPU resource, and their workloads are scheduled in a time-shared manner.

Time-slicing offers flexibility and broad compatibility, as it doesn't depend on specific GPU hardware features and can be used with most NVIDIA GPUs supported by CUDA. It's useful for development, testing, or workloads with bursty or variable GPU utilization patterns.

Despite its flexibility, time-slicing doesn't provide hardware-level isolation. All workloads share the same GPU memory and compute resources, which can result in contention and unpredictable performance. Because configuration and lifecycle management are user-driven, operators must also handle driver updates, compatibility, and tuning. Therefore, time-slicing generally isn't recommended for production workloads that require strict service-level agreements (SLAs).

## Multi-Process Service (MPS) with NVIDIA GPU Operator (User-managed)

[NVIDIA Multi-Process Service (MPS)](https://docs.nvidia.com/deploy/mps/introduction.html) is a driver-level capability that enables multiple CUDA applications to execute concurrently on a single GPU. Unlike time-slicing, which alternates execution between workloads, MPS allows kernels from different processes to run simultaneously, improving overall GPU utilization and reducing latency for compatible workloads.

Within AKS, MPS is supported through user-managed deployments of the NVIDIA GPU Operator. Operators must configure the GPU driver environment to enable MPS and manage the lifecycle of the MPS control daemon. Workloads that connect to the same MPS server can share the GPU and benefit from concurrent kernel execution.

MPS is useful for high-throughput and low-latency scenarios, such as batch jobs or tightly coupled parallel workloads. It provides fine-grained control over GPU sharing and can significantly improve utilization when workloads are designed to take advantage of concurrent execution.

However, MPS introduces additional operational complexity. Configuration is manual, and troubleshooting can be more involved compared to other approaches. Similar to time-slicing, MPS doesn't provide strong isolation, as all processes share GPU memory and compute resources.

## How to choose a GPU partitioning strategy

Choosing the appropriate GPU partitioning strategy in AKS depends on workload requirements, operational preferences, and performance expectations. MIG is the recommended approach for production environments that require strong isolation and predictable performance. As an AKS node pool feature, MIG simplifies operations and reduces administrative overhead.

Time-slicing is useful for non-production environments or workloads with fluctuating GPU demand, where maximizing utilization is more important than consistency. It provides a hardware-agnostic solution but requires careful management and does not guarantee performance isolation.

MPS is ideal for specialized workloads that benefit from concurrent GPU execution and low latency. It offers the highest potential utilization efficiency but comes with increased complexity and minimal isolation, making it most appropriate for advanced users with CUDA-aware applications.

In practice, organizations can adopt different strategies across environments, using MIG for production clusters while leveraging time-slicing or MPS in development or experimental scenarios. Careful evaluation of GPU workload characteristics and operational constraints is essential to selecting the most effective long-term partitioning approach.

## Related content

- Get started with [multi-instance GPU node pools](./gpu-multi-instance.md) on AKS.
- Learn about best practices for [GPU-enabled node lifecycle management](./best-practices-gpu.md).
- Optimize GPU node utilization and performance by configuring [node binpacking](./configure-node-binpack-scheduler.md) in your cluster.