---
title: Supported Azure VM sizes for AKS-managed GPU node pools
description: Review supported Azure VM families and exclusions before choosing a node VM size for an AKS-managed GPU node pool
author: sdesai345
ms.author: sachidesai
ms.date: 11/11/2026
ms.topic: concept-article
ms.service: azure-kubernetes-service
ms.subservice: aks-nodes
---

# Supported Azure virtual machine (VM) sizes for AKS-managed GPU node pools

## Overview

Azure Kubernetes Service (AKS) can install and maintain GPU software for supported NVIDIA GPU-enabled nodes. Use this article to choose a virtual machine (VM) family, then follow [Create an AKS-managed GPU node pool](./aks-managed-gpu-nodes.md) to configure the feature and verify your GPU workload deployment.

## Supported GPU-enabled VM sizes

AKS-managed GPU node pools currently support GPU-enabled VM sizes in the NC, ND, and NV families, subject to the exclusions in the following table. The GPU model varies by VM series. Check [regional availability][azure-availability] before you choose a size.

| Azure VM family | Supported GPU series | Exclusions and retired series |
| --- | --- | --- |
| [NC family](/azure/virtual-machines/sizes/gpu-accelerated/nc-family) | NVIDIA GPU series, including NCasT4, NC A100, and NC H100. | Non-NVIDIA GPU series aren't supported. |
| [ND family](/azure/virtual-machines/sizes/gpu-accelerated/nd-family) | Include [ND A100 v4](/azure/virtual-machines/sizes/gpu-accelerated/ndasra100v4-series), [NDm A100 v4](/azure/virtual-machines/sizes/gpu-accelerated/ndma100v4-series), and [ND H100 v5](/azure/virtual-machines/sizes/gpu-accelerated/ndh100v5-series). [ND GB200 v6](/azure/virtual-machines/sizes/gpu-accelerated/nd-gb200-v6-series) and [ND GB300 v6](/azure/virtual-machines/sizes/gpu-accelerated/nd-gb300-v6-series) are supported in public preview (see [NVIDIA Grace-Blackwell GPU concepts on AKS](./grace-blackwell-series-gpu-concepts.md) to learn more). | ND MI300X v5 isn't currently supported because it uses AMD GPUs. |
| [NV family](/azure/virtual-machines/sizes/gpu-accelerated/nv-family) | [NVads A10 v5](/azure/virtual-machines/sizes/gpu-accelerated/nvadsa10v5-series). | [NVads V710 v5](/azure/virtual-machines/sizes/gpu-accelerated/nvadsv710-v5-series) isn't currently supported because it uses AMD GPUs. NVv3 and NVv4 retired on September 30, 2026. |
| [NG family](/azure/virtual-machines/sizes/gpu-accelerated/ng-family) | None. | The NG family isn't currently supported. NGads V620 uses AMD GPUs. |
| [NP family](/azure/virtual-machines/sizes/fpga-accelerated/np-family) | None. | The NP family isn't supported. NP-series uses field-programmable gate arrays (FPGAs), not GPUs. |

## Node pool considerations

- Use an AKS node pool with `--os-type Linux`. For Windows GPU workloads, see [Use Windows GPUs on AKS](./use-windows-gpu.md).
- Confirm that your subscription has sufficient quota for the selected VM family in the target region. Regional availability doesn't guarantee deployment capacity.

> [!NOTE]
> GPU-enabled VMs contain specialized hardware subject to higher pricing and regional availability. For more information, see the [pricing][azure-pricing] tool and [regional availability][azure-availability].

## Match VM resources to workload requests and limits

- Check the specifications of the exact GPU VM size you plan to use, because GPU models, GPU counts, GPU memory, CPUs, storage, and network performance can differ within the same VM family.
- Choose a VM size with enough GPU memory for the peak memory usage of your GPU workload. Host `memory` limits don't control GPU memory. In the [NVads A10 v5 series](/azure/virtual-machines/sizes/gpu-accelerated/nvadsa10v5-series), `Standard_NV6ads_A10_v5`, `Standard_NV12ads_A10_v5`, and `Standard_NV18ads_A10_v5` provide 1/6, 1/3, and 1/2 of a physical NVIDIA A10 GPU, respectively. On these sizes, requesting `nvidia.com/gpu: 1` doesn't provide a full physical GPU. Check the selected size's GPU memory allocation rather than inferring it from the Kubernetes resource count.
- Check the network bandwidth and connections between GPUs that your distributed workload requires. GPU requests don't reserve network bandwidth or enable remote direct memory access (RDMA), so configure any required network software separately.
- Multi-Instance GPU (MIG) is supported on select NVIDIA GPU VM sizes in AKS. For supported hardware and compatible GPU instance profiles, see [Create a multi-instance GPU node pool in AKS](./gpu-multi-instance.md). To configure MIG with AKS-managed GPU software, see [Create a managed MIG node pool](./aks-managed-gpu-nodes.md#create-a-managed-multi-instance-gpu-mig-node-pool).
- Test your application with representative model sizes, batch sizes, and numbers of concurrent requests, then adjust resource requests and limits based on observed usage.

## Next steps

[Create an AKS-managed GPU node pool](./aks-managed-gpu-nodes.md) and run a sample GPU application in your AKS cluster.

<!-- LINKS - external -->

[azure-pricing]: https://azure.microsoft.com/pricing/
[azure-availability]: https://azure.microsoft.com/global-infrastructure/services/