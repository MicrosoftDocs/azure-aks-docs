---
title: GPU observability in Azure Kubernetes Service (AKS)
description: This article provides a conceptual overview of key utilization and performance NVIDIA DCGM GPU metrics on Azure Kubernetes Service (AKS).
ms.topic: concepts
ms.service: azure-kubernetes-service
ms.date: 11/7/2025
author: sachidesai
ms.author: sachidesai
# Customer intent: "As a Kubernetes administrator, I want to learn about NVIDIA GPU metrics so that I can optimize resource utilization and ensure the performance of GPU-enabled workloads in my AKS cluster."
---

# Learn about NVIDIA GPU metrics to optimize GPU performance and utilization on Azure Kubernetes Service (AKS)

Efficient placement and optimization of GPU workloads often requires visibility into resource utilization and performance. Managed GPU metrics on AKS (preview) provide automated collection and exposure of GPU utilization, memory, and performance data across NVIDIA GPU-enabled node pools. This enables platform administrators to optimize cluster resources and developers to tune and debug workloads with limited manual instrumentation.

In this article, you learn about GPU metrics collected by the NVIDIA Data Center GPU Manager [(DCGM) exporter](https://github.com/NVIDIA/dcgm-exporter/tree/main) with [a fully managed GPU-enabled node pool (preview)](./aks-managed-gpu-nodes.md) in Azure Kubernetes Service (AKS).

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

- An AKS cluster with [a fully managed GPU-enabled node pool (preview)](./aks-managed-gpu-nodes.md) and ensure that the [GPUs are schedulable](./use-nvidia-gpu.md#confirm-that-gpus-are-schedulable).
- A [sample GPU workload](./use-nvidia-gpu.md#run-a-gpu-enabled-workload) deployed to your node pool.

## Limitations
- Managed GPU metrics is not currently supported with [Azure Managed Prometheus or Azure Managed Grafana](/azure/azure-monitor/containers/kubernetes-monitoring-enable).

## Verify that managed GPU components are installed

After creating your managed NVIDIA GPU node pool (preview) following [these instructions](./aks-managed-gpu-nodes.md), confirm that the GPU software components were installed with the [az aks nodepool show](/cli/azure/aks/nodepool#az-aks-nodepool-show) command:

```azurecli-interactive
az aks nodepool show \
    --resource-group <resource-group-name> \
    --cluster-name <cluster-name> \
    --name <node-pool-name> \
```

Your output should include the following values:

  ```output
  ...
  ...
  "gpuInstanceProfile": …
      "gpuProfile": {
        "driver": "Install"
      },
  ...
  ...
  ```

## Understanding GPU metrics

### GPU Utilization Metrics

GPU Utilization metrics show the percentage of time the GPU’s cores are actively processing work. High values indicate that the GPU is heavily used, which is generally desirable for workloads like training or data processing. Interpretation of this metric should consider the type of workload: AI training typically keeps utilization high, while inference may have intermittent utilization due to bursty traffic.

Memory Utilization: Shows the percentage of GPU memory in use. High memory usage without high GPU utilization can indicate memory-bound workloads where the GPU waits on memory transfers. Low memory usage with low utilization may suggest the workload is too small to fully leverage the GPU.

SM (Streaming Multiprocessor) Efficiency: Measures the efficiency with which the GPU’s cores are used. A low SM efficiency indicates that cores are idle or underutilized due to workload imbalance or suboptimal kernel design. High efficiency is ideal for compute-heavy applications.

### Memory Metrics

Memory Bandwidth Utilization: Reflects how much of the theoretical memory bandwidth is being consumed. High bandwidth utilization with low compute utilization can indicate a memory-bound workload. Conversely, high utilization in both compute and memory bandwidth suggests a well-balanced workload.

Memory Errors: Tracks ECC (Error-Correcting Code) errors if enabled. A high number of errors may indicate hardware degradation or thermal issues and should be monitored for reliability.

### Temperature and Power Metrics

GPU Temperature: Indicates the operating temperature of the GPU. Sustained high temperatures can trigger thermal throttling, reducing performance. Ideal interpretation of this metric involves observing temperature relative to the GPU’s thermal limits and cooling capacity.

Power Usage: Shows instantaneous power draw. Comparing power usage to TDP (Thermal Design Power) helps understand whether the GPU is being pushed to its limits. Sudden drops in power may indicate throttling or underutilization.

### Clocks and Frequency Metrics

GPU Clock: The actual operating frequency of the GPU. Combined with utilization, this helps determine if the GPU is throttling or underperforming relative to its potential.

Memory Clock: Operating frequency of GPU memory. Memory-bound workloads may benefit from higher memory clocks; a mismatch between memory and compute utilization can highlight bottlenecks.

### PCIe and NVLink Metrics

PCIe Bandwidth: Measures the throughput over the PCIe bus. Low utilization with heavy workloads may suggest CPU-GPU communication is not a bottleneck. High utilization could point to data transfer limitations impacting performance.

NVLink Bandwidth: This metric is similar to PCIe bandwidth but specific to NVLink interconnects, and relevant in multi-GPU systems for cross-GPU communication. High NVLink usage with low SM utilization may indicate synchronization or data transfer delays.

### Error and Reliability Metrics

Retired Pages and XID Errors: Track GPU memory errors and critical failures. Frequent occurrences signal potential hardware faults and require attention for long-running workloads.

### Interpretation Guidance

DCGM metrics should always be interpreted contextually with the type of your workload on AKS. A high compute-intensive workload should ideally show high GPU and SM utilization, high memory bandwidth usage, stable temperatures below throttling thresholds, and power draw near but below TDP. 

Memory-bound workloads might show high memory utilization and bandwidth but lower compute utilization. Anomalies such as low utilization with high temperature or power consumption often indicate throttling, inefficient scheduling, or system-level bottlenecks.

Monitoring trends over time rather than single snapshots is critical. Sudden drops in utilization or spikes in errors often reveal underlying issues before they impact production workloads. Comparing metrics across multiple GPUs can also help identify outliers or misbehaving devices in a cluster. Understanding these metrics in combination, rather than isolation, provides the clearest insight into GPU efficiency and workload performance.

## Common GPU metrics

The following NVIDIA DCGM metrics are commonly evaluated for performance of GPU node pools on Kubernetes:

| GPU Metric Name | Meaning	| Typical Range / Indicator	| Usage Tip |
| -- | -- | -- | -- |
| `DCGM_FI_DEV_GPU_UTIL`| GPU utilization (% time GPU cores are active)	| 0–100% (higher is better)	| Monitor per-node and per-pod; low values may indicate CPU or I/O bottlenecks |
| `DCGM_FI_DEV_SM_UTIL` | Streaming Multiprocessor efficiency (% active cores) | 0–100%	| Low values with high memory usage indicate a memory-bound workload |
| `DCGM_FI_DEV_FB_USED`	| Framebuffer memory used (bytes)	| 0 to total memory	| Use pod GPU memory limits and track per-pod memory usage |
| `DCGM_FI_DEV_FB_FREE` | Free GPU memory (bytes)	| 0 to total memory	| Useful for scheduling and to avoid OOM errors | 
| `DCGM_FI_DEV_MEMORY_UTIL` | Memory utilization (%) | 0–100%	| Combine with GPU/SM utilization to determine memory-bound workloads |
| `DCGM_FI_DEV_MEMORY_CLOCK` | Current memory clock frequency (MHz)	| 0 to max memory clock |	Low values under high memory utilization may indicate throttling |
| `DCGM_FI_DEV_POWER_USAGE` |	Instantaneous power usage (Watts)	| 0 to TDP | Drops during high utilization may indicate throttling |
| `DCGM_FI_DEV_TEMPERATURE`	| GPU temperature (°C) | ~30–85°C normal | Alert on sustained high temperatures |
| `DCGM_FI_DEV_NVLINK_RX`	| NVLink receive bandwidth utilization (%)	| 0–100% |	Multi-GPU synchronization bottleneck if high with low SM utilization |
| `DCGM_FI_DEV_XID_ERRORS` | GPU critical errors reported by driver	| Typically 0 | Immediate investigation required; can taint node in Kubernetes |
    
To learn about the full suite of GPU metrics, visit [NVIDIA DCGM](https://docs.nvidia.com/datacenter/dcgm/latest/user-guide/index.html) Upstream documentation.

## Next steps

- Track your [GPU node health](./gpu-health-monitoring.md) with Node Problem Detector (NPD)
- Create [multi-instance GPU](./gpu-multi-instance.md) node pools on AKS
- Explore the [AI toolchain operator add-on](./ai-toolchain-operator.md) for AI inferencing and fine-tuning
