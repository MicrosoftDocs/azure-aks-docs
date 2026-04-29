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

GPU utilization, measured by the NVIDIA DCGM metric `GPU_UTIL`, may be incorrectly used as a direct efficiency score. `GPU_UTIL` only indicates how often kernels are active, so it does not determine whether the workload is compute-efficient. In practice, teams can receive more accurate guidance by correlating utilization signals instead of evaluating them independently. For example, compare `GPU_UTIL` with `SM_ACTIVE`, and then compare `SM_ACTIVE` with `DRAM_ACTIVE` to identify whether your bottleneck is compute, memory, or launch/synchronization overhead. For example, high `GPU_UTIL` with low `SM_ACTIVE` often indicates launch overhead, synchronization stalls, or memory contention, while high `SM_ACTIVE` with low `DRAM_ACTIVE` is more consistent with compute-bound behavior. By contrast, higher `DRAM_ACTIVE` with lower `SM_ACTIVE` usually points to memory-bound execution. 

This correlation-first approach helps cluster administrators to avoid scaling out when the root issue may be kernel efficiency or memory access patterns. For detailed metric semantics, see the [NVIDIA DCGM user guide](https://docs.nvidia.com/datacenter/dcgm/latest/user-guide/index.html).

## Use memory pressure as a primary scheduling signal

For GPU workload placement, prioritize memory pressure over raw utilization. Kubernetes schedules GPUs as integer resources, while DCGM reveals true memory consumption, which is often the stronger long-term scheduling signal. For example, track sustained `FB_USED` / `FB_TOTAL` over time and interpret this metric as a trend rather than a snapshot. If memory stays consistently below 50% while GPUs are exclusively allocated, you likely have an opportunity to improve bin-packing efficiency by evaluating [multi-instance GPU (MIG)](./gpu-multi-instance.md) or alternative GPU node partitioning strategies. If memory repeatedly approaches out-of-memory thresholds, treat that pattern as an early indicator of instability even before Kubernetes reports pressure. In production clusters, near-out-of-memory (OOM) patterns commonly predict pod disruption and node instability earlier than standard scheduler-visible signals.

## Automate node lifecycle actions from GPU health signals

Use Node Problem Detector (NPD) GPU health telemetry as an early signal of hardware degradation, especially XID errors and ECC error growth. These indicators are most effective when you connect them to automation instead of manual response. Define thresholds that taint and cordon affected nodes and drain GPU workloads gracefully, rather than performing one-off repairs. This practice is especially important for long-lived AKS GPU pools where host aging can vary across nodes. For error interpretation and node conditions, see [GPU health monitoring with AKS NPD](./gpu-health-monitoring.md) and [NVIDIA XID Errors](https://docs.nvidia.com/deploy/xid-errors/index.html).

## Align observability signals with scaling decisions

Use GPU telemetry as an input to scaling policy, not just queue depth. For horizontal scaling, add nodes only when you observe sustained saturation across multiple nodes, such as persistently high `SM_ACTIVE` and sustained high memory usage (`FB_USED` / `FB_TOTAL`). For vertical scaling, evaluate a different Azure GPU-enabled VM SKU when power or thermal constraints cap throughput, for example when `POWER_USAGE` remains near limit while `SM_ACTIVE` remains flat despite demand. This approach avoids the common anti-pattern of over-scaling based only on pending pods or queue length.

## Separate MIG and non-MIG observability policies

Interpretation changes when MIG is enabled because metric scope changes. In MIG mode, DCGM reports per-instance telemetry, while non-MIG mode reports at the full physical GPU level. If your AKS environment mixes MIG and non-MIG node pools, maintain separate dashboards, thresholds, and alert policies, since direct comparisons are misleading unless you normalize by available SM and memory fractions.

## Publish cost-aware GPU efficiency metrics

Optimize for cost visibility, not only performance. A high-value derived metric for AKS platform teams is GPU-seconds used versus GPU-seconds allocated. Use DCGM telemetry and Kubernetes context joins to publish this metric by namespace and workload class, then review it over time as a shared KPI for platform and finance teams. This approach defines a common source of truth for optimization decisions and helps prevent over-allocation from being hidden by aggregate utilization averages.

## Next steps

- Review [GPU best practices for AKS](./best-practices-gpu.md).
- Get started with AKS managed [GPU observability](./monitor-gpu-metrics.md).
- Optimize allocation with [multi-instance GPU (MIG) nodes](./gpu-multi-instance.md).
- Scale based on GPU signals using [KEDA and DCGM metrics](./autoscale-gpu-workloads-with-keda.md).
