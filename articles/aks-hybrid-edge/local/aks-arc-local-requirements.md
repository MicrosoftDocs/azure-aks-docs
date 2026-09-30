---
title: System requirements for AKS on Azure Local
description: Learn about system storage requirements for Azure Kubernetes Service (AKS) for Azure Local.
ms.topic: concept-article
author: xelu86
ms.author: alalve
ms.date: 09/01/2026
ms.custom: local
# Intent: As a system administrator, I want to understand the storage requirements needed to run my infrastructure.
# Keyword: AKS Azure Local storage requirements
---

# System requirements for AKS on Azure Local

With Azure Kubernetes Service (AKS) Arc on Azure Local, you can deploy and manage Kubernetes clusters on your own infrastructure with integrated Azure Arc control. Cluster creation and
lifecycle management are supported via familiar Azure tools such as the portal, Azure CLI, and Resource Manager templates. These clusters are automatically onboarded to Azure Arc, enabling
centralized governance and secure access through Microsoft Entra ID.

## System requirements

Microsoft and trusted hardware partners preconfigure and validate certified Azure Local platforms to deliver dependable AKS deployments. These platforms feature the following essential infrastructure components:

- **Hardware:** Enterprise-grade servers and devices designed for high availability and performance.
- **Networking:** Integrated network fabric supporting redundancy, security, and scalable connectivity.
- **Storage:** Robust storage solutions optimized for Kubernetes workloads and data durability.
- **Operating systems:** Supported and secure OS images tailored for AKS compatibility.
- **Management tools:** Built-in monitoring, automation, and lifecycle management utilities for streamlined operations.

The platform delivers out-of-the-box Azure Arc integration, allowing administrators to focus on workload operations while underlying maintenance and optimizations are handled automatically. While the hardware provides baseline requirements, the cluster and workload sizing should be tailored to your specific environment needs.

## Storage requirements

Storage sizing requirements for AKS on Azure Local depend primarily on hardware configuration, expected AKS workloads, and overall cluster sizing. While certified Azure Local platforms provide built-in baseline hardware, it’s important to assess your storage needs according to the types and scale of applications you plan to run.

- **Single storage path:** Ensure at least one storage path is configured in your Azure Local environment. To learn more, see [Create storage path for Azure Local](/azure/azure-local/manage/create-storage-path).

- **Storage per AKS cluster:** For a standard AKS cluster with a single control plane, such as a virtual machine (VM) with one node pool and one control plane running Azure on Linux:

  - **Minimum required:** A total of 10 GB of storage per node.

  - **Maximum usage:** Up to 200 GB total, depending on the number of VMs and the workloads deployed.

- **Workload usage recommendations:**

  - Use the designated storage volume exclusively for Kubernetes workloads.

  - Avoid storing unrelated files or data on these storage paths.

  - Store backup files and related data in a different location to prevent potential storage exhaustion issues.

## See also

- [AKS on Azure Local architecture](hyperconverged/cluster-architecture.md)
- [How to deploy a Kubernetes cluster using the Azure portal](aks-create-clusters-portal.md)
- [Storage options for applications in AKS Hybrid and Edge](hyperconverged/concepts-storage.md)
