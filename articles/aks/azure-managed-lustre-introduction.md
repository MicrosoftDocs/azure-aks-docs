---
title: What is Azure Managed Lustre on AKS?
description: Learn how Azure Managed Lustre provides high-performance shared storage for AI and HPC workloads on Azure Kubernetes Service, including scale targets and MLPerf Storage results.
ms.topic: overview
ms.subservice: aks-storage
ms.date: 10/30/2026
author: wolfgang-desalvador
ms.author: wdesalvador

# Customer intent: As a platform engineer, I want to understand the performance scale and use cases of Azure Managed Lustre before using it with AKS.
---

# What is Azure Managed Lustre on AKS?

[Azure Managed Lustre](/azure/azure-managed-lustre/amlfs-overview) is a managed parallel file system for high-performance computing (HPC) and artificial intelligence (AI) workloads. It provides shared file storage while Azure manages the underlying file system infrastructure.

On Azure Kubernetes Service (AKS), the Azure Managed Lustre Container Storage Interface (CSI) driver makes this storage available to Linux workloads through persistent volumes and persistent volume claims. Multiple pods can access a shared file system using `ReadWriteMany` volumes.

## When to use Azure Managed Lustre

Consider Azure Managed Lustre when your containerized workloads need high aggregate file-system bandwidth across many workers:

- **AI training data access**: Read shared datasets concurrently to supply distributed training jobs.
- **Checkpointing and recovery**: Write model state and read checkpoints when restarting a job.
- **HPC and data processing**: Share input datasets and output files across parallel compute tasks.

You can also integrate the file system with Azure Blob Storage to import datasets and export results. For details, see [Azure Blob Storage integration](/azure/azure-managed-lustre/blob-integration).

## Performance and scale

Azure Managed Lustre supports petabyte-scale file systems, and published benchmark configurations demonstrate aggregate throughput of hundreds of gigabytes per second. Size the file system for both data capacity and workload bandwidth; the throughput tier and provisioned capacity determine its nominal bandwidth.

For example, the documented maximum for the 20 MBps tier without Blob integration is 25,632 TiB, approximately 25 PiB. Limits differ by tier and Blob integration configuration, and exceeding a subscription's default maximum requires a support request. Use the [Azure Managed Lustre scale targets](/azure/azure-managed-lustre/create-file-system-portal#throughput-configurations) for the current limits and capacity increments rather than treating a benchmark configuration as a deployment limit.

### MLPerf Storage results

The published [Azure Managed Lustre MLPerf Storage v3.0 results](/azure/azure-managed-lustre/mlperf-storage-v3-results) include these examples:

| Workload | Tested configuration | Measured aggregate bandwidth |
| --- | --- | --- |
| Training reads | AMLFS 125, 4,096 TiB, 70 simulated B200 accelerators | 379.1 GiB/s, or 407.1 GB/s. |
| Checkpoint writes and recovery reads | AMLFS 125, 4,096 TiB, 1250B-parameter checkpoint workload | 642.2 GiB/s writes and 489.6 GiB/s recovery reads, or 689.6 GB/s and 525.7 GB/s, respectively. |

[MLPerf Storage](https://mlcommons.org/benchmarks/storage/) exercises the storage data path with simulated accelerators. These figures are storage-system results, not per-pod throughput or measurements of AKS CSI-driver overhead, GPU computation, or end-to-end training time. GiB/s uses binary units; GB/s uses decimal units.

Benchmark results describe the tested configurations, not a performance guarantee. Validate your application with its intended data layout, concurrency, AKS node networking, and file system size. See the [complete results and sizing guidance](/azure/azure-managed-lustre/mlperf-storage-v3-results#how-to-use-the-data-as-a-sizing-reference) and [performance optimization guidance](/azure/azure-managed-lustre/optimize-performance).

## Use Azure Managed Lustre with AKS

Install the CSI driver with Helm or a script. Your workloads use Kubernetes storage classes and claims to access the file system:

- [Static provisioning](azure-managed-lustre-static-provisioning.md) connects an existing Azure Managed Lustre file system.
- [Dynamic provisioning](azure-managed-lustre-dynamic-provisioning.md) creates a file system for a persistent volume claim.

An alternative [AKS CLI installation option (preview)](azure-managed-lustre-install-cli-preview.md#install-with-aks-cli-options-preview) installs the driver as a managed extension. Neither installation method changes the service's capacity or performance limits.

## Next steps

- [Install Azure Managed Lustre on AKS](azure-managed-lustre-install.md).
- [Plan network connectivity](azure-managed-lustre-network-planning.md).
- [Review CSI driver compatibility requirements](azure-managed-lustre-overview.md#supported-kubernetes-and-aks-versions).
