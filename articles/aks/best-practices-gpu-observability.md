---
title: GPU observability best practices for Azure Kubernetes Service (AKS)
description: This article provides insights into monitoring correlated GPU metrics to help improve long term GPU node utilization and performance on AKS.
ms.topic: best-practice
ms.service: azure-kubernetes-service
ms.date: 5/1/2026
author: sachidesai
ms.author: sachidesai
ai-usage: ai-assisted
# Customer intent: "As an AKS cluster admin, I want to monitor correlated GPU metrics in AKS so that I can improve long-term GPU utilization, performance, and cost efficiency."
---

# GPU observability best practices for Azure Kubernetes Service (AKS)

This article provides best practices for monitoring and interpreting GPU signals on Azure Kubernetes Service (AKS). Instead of looking at NVIDIA GPU metrics in isolation, you correlate signals across utilization, memory, and workload context to improve long-term performance and node efficiency.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Understand GPU utilization versus saturation

Don't treat the NVIDIA DCGM metric `GPU_UTIL` as a direct efficiency score. `GPU_UTIL` only indicates how often kernels are active, so it doesn't tell you whether the workload is compute-efficient. You get more accurate guidance by correlating utilization signals instead of reading them independently. Compare `GPU_UTIL` with `SM_ACTIVE`, and then compare `SM_ACTIVE` with `DRAM_ACTIVE` to identify whether your bottleneck is compute, memory, or launch and synchronization overhead.

High `GPU_UTIL` with low `SM_ACTIVE` often points to launch overhead, synchronization stalls, or memory contention. High `SM_ACTIVE` with low `DRAM_ACTIVE` is more consistent with compute-bound behavior. Higher `DRAM_ACTIVE` with lower `SM_ACTIVE` usually points to memory-bound execution.

This correlation-first approach helps you avoid scaling out when the root issue might be kernel efficiency or memory access patterns. For detailed metric semantics, see the [NVIDIA DCGM user guide](https://docs.nvidia.com/datacenter/dcgm/latest/user-guide/index.html).

## Use memory pressure as a primary scheduling signal

If memory repeatedly approaches out-of-memory thresholds, treat that pattern as an early indicator of instability. Kubernetes has no native GPU-memory pressure signal, so VRAM exhaustion typically surfaces only as container OOM kills and pod disruption, often well after DCGM telemetry shows the trend.

## Automate node lifecycle actions from GPU health signals

This practice is especially important for long-lived AKS GPU node pools where host aging can vary across nodes.

## Align observability signals with scaling decisions

For vertical scaling, create a new node pool on a different Azure GPU-enabled VM SKU and migrate workloads when power or thermal constraints cap throughput, for example when `DCGM_FI_DEV_POWER_USAGE` stays near limit while `DCGM_FI_PROF_SM_ACTIVE` remains flat despite demand.

## Separate MIG and non-MIG observability policies

When MIG is enabled, the scope of each metric shifts, so interpret the signals differently.

## Publish cost-aware GPU efficiency metrics

Optimize for cost visibility, not only performance. A high-value derived metric for AKS platform teams is GPU-seconds used versus GPU-seconds allocated. Use DCGM telemetry and Kubernetes context joins to publish this metric by namespace and workload class, then review it over time as a shared KPI for platform and finance teams. This approach defines a common source of truth for optimization decisions and helps prevent over-allocation from being hidden by aggregate utilization averages.

## Next steps

- Review [GPU best practices for AKS](./best-practices-gpu.md).
- Get started with AKS managed [GPU observability](./monitor-gpu-metrics.md).
- Optimize allocation with [multi-instance GPU (MIG) nodes](./gpu-multi-instance.md).
- Scale based on GPU signals using [KEDA and DCGM metrics](./autoscale-gpu-workloads-with-keda.md).
