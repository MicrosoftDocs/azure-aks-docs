---
title: Scale requirements for Azure Kubernetes Service (AKS) on Azure Local, Rack Scale
description: Learn about scale requirements for AKS on Azure Local, Rack Scale deployments, including cluster, node pool, and node limits.
ms.topic: limits-and-quotas
ms.date: 09/01/2026
ms.author: sanjanamohan
ms.custom: multi-rack
author: sanjanamsft
---

# Scale requirements and supported node sizes

This article describes the supported node sizes and scale requirements for AKS on Azure Local for multi-rack deployments.

## Support count for AKS on Azure Local

The table below shares minimum count supported. While there are no enforced maximums for clusters per deployment, the effective maximum number of nodes and clusters are constrained by the available physical compute, memory, and logical network IP capacity in your deployment. Plan your logical network IP pools to have enough addresses for all cluster nodes, control plane nodes, plus two more IPs per cluster for internal services.

| Scale item   | Minimum  |
|--------------|----------|
| Count of control plane nodes (odd numbers)  | 1 |
| Number of node pools in an AKS cluster  | 1  |
| Number of nodes in a node pool (empty node pools not supported)  | 1 |

> [!NOTE]
> The control plane node count must be an odd number (>=1) to maintain etcd quorum.

## Autoscaler

Cluster autoscaler isn't currently supported on Azure Local for multi-rack deployments. You can manually scale node pools by updating the node count.

## Default values for virtual machine sizes

| System Role                     | VM Size                                | Memory, CPU          |
|---------------------------------|----------------------------------------|----------------------|
| AKS Arc control plane nodes     | Standard_D4s_v3                         | 16-GiB memory, 4 vCPU  |
| AKS Arc Linux worker node       | Standard_A4_v2                         | 8-GiB memory, 4 vCPU  |

## Supported values for control plane node sizes

| VM Size                     | CPU  | Memory (GiB)  |
|-----------------------------|------|--------------|
| Standard_D4s_v3             | 4    | 16           |
| Standard_D8s_v3             | 8    | 32           |

## Supported values for worker node sizes

| VM Size                     | CPU  | Memory (GiB)  |
|-----------------------------|------|--------------|
| Standard_A2_v2              | 2    | 4            |
| Standard_K8S3_v1            | 4    | 6            |
| Standard_A4_v2              | 4    | 8            |
| Standard_D4s_v3             | 4    | 16           |
| Standard_D8s_v3             | 8    | 32           |
| Standard_D16s_v3            | 16   | 64           |
| Standard_D32s_v3            | 32   | 128          |

## GPU requirements

Currently, the only supported GPU model is the NVIDIA RTX Pro 6000 Blackwell (96 GiB). For supported GPU-enabled VM sizes and deployment steps, see [Use GPUs for compute-intensive workloads](deploy-gpu-node-pool.md).

## Next steps

- [Review AKS on Azure Local prerequisites](/azure/aks/aksarc/aks-hci-network-system-requirements)
- [Create AKS on Azure Local](resource-manager-quickstart.md)
