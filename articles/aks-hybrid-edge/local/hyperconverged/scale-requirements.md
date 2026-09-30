---
title: Scale requirements for AKS on Azure Local
description: Learn about scale requirements for AKS on Azure Local.
ms.topic: limits-and-quotas
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.reviewer: srikantsarwa
ms.lastreviewed: 03/26/2024
ms.custom: hyperconverged
---

# Scale requirements for AKS on Azure Local

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

This article describes the maximum and minimum supported scale count for AKS on Azure Local clusters and node pools.

## Support count for AKS on Azure Local

| Scale item   | Minimum  | Maximum |
|--------------|----------|---------|
| Number of physical nodes in an Azure Local cluster  | 1  | 16 |
| Count of control plane nodes (Allowed values are 1, 3, and 5)  | 1 | 5 |
| Number of nodes in default node pool created during cluster create  | 1 | 200 |
| Number of node pools in an AKS cluster  | 1  | 16  |
| Number of nodes in a node pool (empty node pools not supported)  | 1 | 64 |
| Total number of nodes in an AKS cluster across node pools | 1 | 200 |
| Number of AKS clusters per Azure Local cluster | 0 | 32 |

## Concurrency for AKS on Azure Local

| Scale item  | Count  |
|-------------|--------|
| Number of concurrent AKS cluster creations on an ARB  | 8 |
| Number of concurrent node pool creations on an ARB  | 8  |
| Number of concurrent operations across all different AKS clusters such as upgrade/scaling, etc., excluding creating node pools or clusters  | 32 |
| Number of long running operations that can be run simultaneously on an AKS cluster  | 1 per cluster |

## Scale requirements when using autoscaler with AKS on Azure Local

> [!NOTE]
> When the autoscaler is enabled, AKS on Azure Local currently supports a maximum of 12 clusters per Azure Local environment. If this limit is exceeded, operations such as creating additional clusters or node pools might not succeed. To manage capacity, we recommend deleting unused clusters using the [az aksarc delete](/cli/azure/aksarc#az-aksarc-delete) command.
>
> If the autoscaler is enabled in an environment that already exceeds the supported cluster count, performance might be impacted. Managing within supported limits is recommended.

| Scale item  | Count  |
|-------------|--------|
| Maximum number of AKS clusters with autoscaler enabled | 12 |
| Number of concurrent AKS cluster creations | 4 |
| Number of concurrent node pool creations | 4 |

For more information, see [autoscaling with AKS on Azure Local](/azure/aks/aksarc/auto-scale-aks-arc).

If you operate at enterprise scale and have scenarios that require higher cluster counts with the autoscaler enabled, contact your Microsoft account team or support to discuss potential options.

## Default values for virtual machine sizes

| System Role                     | VM Size                                | Memory, CPU          |
|---------------------------------|----------------------------------------|----------------------|
| AKS control plane nodes     | Standard_A4_v2                         | 8-GB memory, 4 vcpu  |
| AKS Linux worker node       | Standard_A4_v2                         | 8-GB memory, 4 vcpu  |
| AKS Windows worker node     | Standard_K8S3_v1                       | 6-GB memory, 4 vcpu  |

Starting with the Azure Local 2509 release, the default OS disk size for VMs used as AKS nodes is set to 200 GB. These are dynamically expanding virtual hard disks and you should [ensure sufficient physical disk space is available](/windows-server/virtualization/hyper-v/best-practices-analyzer/ensure-sufficient-physical-disk-space-is-available-when-virtual-machines-use-dynamically?source=recommendations) for the node pools that you create on AKS. 

## Supported values for control plane node sizes

| VM Size                     | CPU  | Memory (GB)  |
|-----------------------------|------|--------------|
| Standard_K8S3_v1            | 4    | 6            |
| Standard_A4_v2              | 4    | 8            |
| Standard_D4s_v3             | 4    | 16           |
| Standard_D8s_v3             | 8    | 32           |

## Supported values for worker node sizes

| VM Size                     | CPU  | Memory (GB)  |
|-----------------------------|------|--------------|
| Standard_A2_v2              | 2    | 4            |
| Standard_K8S3_v1            | 4    | 6            |
| Standard_A4_v2              | 4    | 8            |
| Standard_D4s_v3             | 4    | 16           |
| Standard_D8s_v3             | 8    | 32           |
| Standard_D16s_v3            | 16   | 64           |
| Standard_D32s_v3            | 32   | 128          |

For more worker node sizes with GPU support, see the next section.

[!INCLUDE [supported-gpu-models](../../includes/supported-gpu-models.md)]

## Next steps

- [Review AKS on Azure Local prerequisites](network-system-requirements.md)
- [What's new in AKS on Azure Local](../aks-whats-new-local.md)
