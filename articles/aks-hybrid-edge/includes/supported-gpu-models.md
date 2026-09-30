---
author: davidsmatlak
ms.author: davidsmatlak
ms.service: azure-kubernetes-service-hybrid
ms.topic: include
ms.date: 09/01/2026
ms.reviewer: rmody
ms.lastreviewed: 12/16/2025

---

## Supported GPU models

Azure Kubernetes Service (AKS) on Azure local supports the following GPU models. GPUs are only supported on Linux OS node pools. GPUs aren't supported on Windows OS node pools.

| Manufacturer | GPU model | Supported version |
|--------------|-----------|-------------------|
| NVIDIA       | A2        | 2311.2            |
| NVIDIA       | A16       | 2402.0            |
| NVIDIA       | T4        | 2408.0            |
| NVIDIA       | L4        | 2512.0            |
| NVIDIA       | L40       | 2512.0            |
| NVIDIA       | L40S      | 2512.0            |
| NVIDIA       | RTX Pro 6000      | 2603.0            |

## Supported GPU VM sizes

AKS on Azure Local supports the following VM sizes for each GPU model.

### NVIDIA T4 is supported by NK T4 SKUs

| VM size | GPUs | GPU Memory: GiB | vCPU | Memory: GiB |
|-----------------|---|----|-----|----|
| Standard_NK6    | 1 | 8  | 6   | 12 |
| Standard_NK12   | 2 | 16 | 12  | 24 |

### NVIDIA A2 is supported by NC2 A2 SKUs

| VM size | GPUs | GPU Memory: GiB | vCPU | Memory: GiB |
|-------------------|---|----|----|----|
| Standard_NC4_A2   | 1 | 16 | 4  | 8  |
| Standard_NC8_A2   | 1 | 16 | 8  | 16 |
| Standard_NC16_A2  | 2 | 32 | 16 | 64 |
| Standard_NC32_A2  | 2 | 32 | 32 | 128 |

### NVIDIA A16 is supported by NC2 A16 SKUs

| VM size | GPUs | GPU Memory: GiB | vCPU | Memory: GiB |
|--------------------|---|----|----|----|
| Standard_NC4_A16   | 1 | 16 | 4  | 8  |
| Standard_NC8_A16   | 1 | 16 | 8  | 16 |
| Standard_NC16_A16  | 2 | 32 | 16 | 64 |
| Standard_NC32_A16  | 2 | 32 | 32 | 128 |

### NVIDIA L4 is supported by NC2 L4 SKUs (Preview)

| VM size | GPUs | GPU Memory: GiB | vCPU | Memory: GiB |
|--------------------|---|----|----|----|
| Standard_NC16_L4_1   | 1 | 24 | 16  | 64  |
| Standard_NC16_L4_2   | 2 | 48 | 16  | 64  |
| Standard_NC32_L4_1   | 1 | 24 | 32  | 128  |
| Standard_NC32_L4_2   | 2 | 48 | 32  | 128  |

### NVIDIA L40 is supported by NC2 L40 SKUs (Preview)

| VM size | GPUs | GPU Memory: GiB | vCPU | Memory: GiB |
|--------------------|---|----|----|----|
| Standard_NC16_L40_1   | 1 | 48 | 16  | 64  |
| Standard_NC16_L40_2   | 2 | 96 | 16  | 64  |
| Standard_NC32_L40_1   | 1 | 48 | 32  | 128  |
| Standard_NC32_L40_2   | 2 | 96 | 32  | 128  |

### NVIDIA L40S is supported by NC2 L40S SKUs (Preview)

| VM size | GPUs | GPU Memory: GiB | vCPU | Memory: GiB |
|--------------------|---|----|----|----|
| Standard_NC16_L40S_1   | 1 | 48 | 16  | 64  |
| Standard_NC16_L40S_2   | 2 | 96 | 16  | 64  |
| Standard_NC32_L40S_1   | 1 | 48 | 32  | 128  |
| Standard_NC32_L40S_2   | 2 | 96 | 32  | 128  |


### NVIDIA RTX Pro 6000 is supported by NC2 RTX Pro 6000 SKUs (Preview)

| VM size | GPUs | GPU Memory: GiB | vCPU | Memory: GiB |
|--------------------|---|----|----|----|
| Standard_NC16_RTX6000Pro_1   | 1 | 48 | 16  | 64  |
| Standard_NC16_RTX6000Pro_2   | 2 | 96 | 16  | 64  |
| Standard_NC32_RTX6000Pro_1   | 1 | 48 | 32  | 128  |
| Standard_NC32_RTX6000Pro_2   | 2 | 96 | 32  | 128  |
