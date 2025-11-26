---
title: GPU health monitoring in Node Problem Detector (NPD) in Azure Kubernetes Service (AKS) nodes
description: Learn about how AKS uses Node Problem Detector to expose issues on GPU-enabled nodes.
ms.topic: how-to
ms.date: 08/15/2025
author: sachidesai
ms.author: sachidesai
ms.service: azure-kubernetes-service

# As a Kubernetes operator, I want to monitor GPU-specific health conditions using Node Problem Detector (NPD), so that I can detect and respond to hardware or connectivity issues affecting GPU nodes, ensuring high performance and stability for GPU workloads.
---

# GPU health monitoring in Node Problem Detector (NPD) in Azure Kubernetes Service (AKS) nodes

This article describes how Azure Kubernetes Service (AKS) uses Node Problem Detector (NPD) to monitor the health of GPU-enabled node pools. NPD is a Kubernetes component that detects and reports node-level issues, including hardware faults, driver errors, and connectivity problems that can affect the performance and availability of GPU workloads.

## About GPU health monitoring in NPD

AKS supports GPU health monitoring through [Node Problem Detector (NPD)](./node-problem-detector.md), enabling automatic detection and reporting of issues that affect GPU-enabled node pools on an AKS cluster. GPU health monitoring helps Kubernetes operators keep GPU nodes healthy and performant by surfacing hardware faults, communication failures, and system-level errors. NPD sets GPU-related node conditions and enable platform engineering teams to take action before issues impact application performance or availability.

These health signals are vital for ensuring optimal performance and reliability across a range of GPU workloads, including:

* Machine learning (ML) training and inference.
* AI model development.
* High-performance computing (HPC).
* Graphics rendering and data-intensive simulations.

## Limitations

AKS Node Problem Detector ***does not*** run GPU health checks on node pools with `--gpu-driver none`, where **self-managed** or custom GPU driver was installed on the nodes.

## Supported GPU health checks

NPD regularly monitors GPU-enabled node pools and sets conditions when anomalies are detected. The following GPU health checks are currently supported:

* **GPUMissing**: NPD verifies that the number of GPUs detected by the `nvidia-smi` utility matches the expected GPU count for the VM SKU assigned to the node.
  * A mismatch might indicate a hardware fault, driver issue, or misconfiguration. Accurate GPU enumeration is critical for ensuring scheduling accuracy and workload availability on GPU nodes.

* **GPUXIDErrors**: Checks for XID (eXecution ID) errors emitted by the GPU driver in the kernel logs. XID errors are low-level GPU faults that typically occur when:
  * The driver misprograms the GPU.
  * There's a corruption in the command stream sent to the GPU.
  * A hardware failure or instability affects GPU operation.

  For more information, see [XID errors on NVIDIA GPUs](https://docs.nvidia.com/deploy/xid-errors/index.html).

* **NVLink Status**: For NVIDIA VM SKUs that support NVLink, this condition confirms that NVLink is active and functioning.
  * NVLink is a high-speed interconnect used to facilitate data transfer between multiple GPUs.
  * If NVLink is inactive or degraded, multi-GPU workloads might experience reduced performance or communication bottlenecks.

  For more information, see [NVIDIA NVLink](https://www.nvidia.com/en-us/data-center/nvlink/).

* **InfiniBand Link Flapping**: NPD monitors for InfiniBand (IB) link flapping, or intermittent connectivity of the IB network device.
  * Link flapping shouldn't occur under normal operating conditions and might result in degraded inter-node communication for distributed workloads.
  * It can also signal physical layer issues, misconfigured firmware, or driver instability.

* **NVIDIA GRID Driver License Check**: For NVIDIA VM SKUs that support GRID driver, this condition verifies license status of the installed GRID driver on [supported NVIDIA VM SKUs](/azure/virtual-machines/sizes/gpu-accelerated/nvadsa10v5-series)
  * Invalid might indicate the installed GRID driver is not licensed.

## Frequently asked questions

### Does Node Problem Detector (NPD) automatically remediate GPU node issues?

NPD doesn't take direct action to remediate GPU-enabled node issues. NPD detects and reports problems by publishing Kubernetes node conditions and events. Any remediation (for example: draining a node, restarting workloads, or replacing faulty hardware) must be handled manually, through external automation, or alerting systems configured by the Kubernetes operator.

### On which Azure VM sizes does AKS conduct GPU health monitoring through NPD?

Currently, NPD conducts health checks on GPU nodes provisioned with the `Standard_ND96asr_v4` or `Standard_ND96isr_H100_v5` VM size on AKS. Also on [A10 SKU](/azure/virtual-machines/sizes/gpu-accelerated/nvadsa10v5-series) for GRID Driver License checks.

### Does NPD monitor the health of multi-instance GPU (MIG) node pools?

Yes, NPD health monitoring is supported on [MIG-enabled AKS node pools](./gpu-multi-instance.md).

## Next steps

* Provision GPUs on [Linux](./use-nvidia-gpu.md) or [Windows](./use-windows-gpu.md) node pools in your AKS cluster.
* Learn more about the [types of node conditions and events](./node-problem-detector.md) set by NPD on AKS.
* [Monitor general GPU metrics](./monitor-gpu-metrics.md) using a self-managed metrics exporter.
