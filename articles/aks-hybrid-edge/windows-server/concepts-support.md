---
title: Tested resource limits, VM sizes, and regions for AKS on Windows Server
description: Resource limits, VM sizes, regions for Azure Kubernetes Service (AKS) on Windows Server.
author: davidsmatlak
ms.topic: limits-and-quotas
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.custom: references_regions, windows-server

#intent: As an IT Pro, I need to understand and also leverage how resource limits, VM sizes, and regions work together for AKS on Windows Server.
#keyword: Resource limits VM sizes

---

# Resource limits, VM sizes, and regions for AKS on Windows Server

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

This article provides information about tested configurations, resource limits, VM sizes, and regions for Azure Kubernetes Service (AKS) on Windows Server. The tests use the latest release of AKS on Windows Server.

## Maximum specifications

AKS on Windows Server deployments were validated with the following configurations, including the specified maximums. If you exceed these maximums, you might encounter unexpected behaviors and failures. This article provides guidance on how to avoid common configuration mistakes and can help you create a larger configuration. If you need assistance, contact your local Microsoft office or [submit a question to the community](https://feedback.azure.com/d365community/search/?q=Azure+Kubernetes).

| Resource                     | Maximum |
| ---------------------------- | --------|
| Physical servers per cluster | 8       |
| Total number of VMs          | 200     |

The recommended limits were tested with the default virtual machine (VM) sizes, based on the following table:

| System role | VM size|
|-------------|---------|
|AKS-Host| **Standard_A4_v2**|
|Target Cluster Control Plane node| **Default**|
|Target Cluster HAProxy load balancer (optional)| **Standard_A4_v2**|
|Target Cluster Linux worker node| **Standard_K8S3_v1**|
|Target Cluster Windows worker node| **Standard_K8S3_v1**|

The hardware configuration of each physical node in the AKS cluster is as follows:

- Chassis: Dell PowerEdge R650 Server or similar.
- RAM: RDIMM, 3200 MT/s, Dual Rank, total of 256 GB.
- CPU: Two (2) Intel Xeon Silver 4316 2.3G, 20C/40T, 10.4 GT/s, 30M Cache, Turbo, HT (150 W) DDR4-2666.
- Disk: 8x HDDs (2 TB or larger) and 2x 1.6 TB NVMe to support S2D storage configurations.
- Network: Four (4) 100-Gbit NICs (Mellanox or Intel).

Microsoft engineering tested AKS on Windows Server using this configuration, for single node, two node, four node, and eight node Windows failover clusters. If you have a requirement that exceeds the tested configuration, see [Scaling AKS](#scaling-aks).

> [!IMPORTANT]  
> When you upgrade a deployment of AKS, the process temporarily consumes extra resources.
> Each virtual machine is upgraded in a rolling update flow, starting with the control plane nodes. For each node in the Kubernetes cluster, the process creates a new node VM. It restricts the old node VM to prevent workloads from being deployed to it. The process drains all containers from the restricted VM to distribute the containers to other VMs in the system. It removes the drained VM from the cluster, shuts it down, and replaces it with the new, updated VM. This process repeats until all VMs are updated.

## Available VM sizes

The following VM sizes for control plane nodes, Linux worker nodes, and Windows worker nodes are available for AKS on Windows Server. While VM sizes such as **Standard_K8S2_v1** and **Standard_K8S_v1** are supported for testing and low resource requirement deployments, use these sizes with care and apply stringent testing as they might cause unexpected failures due to out of memory conditions.

| VM Size        | CPU | Memory (GB) | GPU type | GPU count |
| -------------- | ----| ------------| -------- | --------- |
| Default        | 4   | 4           |          |           |
| Standard_A2_v2 | 2   | 4           |          |           |
| Standard_A4_v2 | 4   | 8           |          |           |
| Standard_D2s_v3 | 2   | 8           |          |           |
| Standard_D4s_v3 | 4   | 16          |          |           |
| Standard_D8s_v3 | 8   | 32          |          |           |
| Standard_D16s_v3 | 16  | 64          |          |           |
| Standard_D32s_v3 | 32  | 128         |          |           |
| Standard_DS2_v2 | 2   | 7           |          |           |
| Standard_DS3_v2 | 2   | 14          |          |           |
| Standard_DS4_v2 | 8   | 28          |          |           |
| Standard_DS5_v2 | 16  | 56          |          |           |
| Standard_DS13_v2 | 8   | 56          |          |           |
| Standard_K8S_v1 | 4   | 2           |          |           |
| Standard_K8S2_v1 | 2   | 2           |          |           |
| Standard_K8S3_v1 | 4   | 6           |          |           |
| Standard_NK6     | 6   | 12          | Tesla T4 | 1         |
| Standard_NK12    | 12  | 24          | Tesla T4 | 2         |

## Supported Azure regions for Azure registration

AKS on Windows Server is supported in the following Azure regions:

- Australia East
- East US
- Southeast Asia
- West Europe

## Scaling AKS

Scaling an AKS deployment requires planning. You need to understand your workloads and your target cluster utilization. Also, consider the hardware resources in your underlying infrastructure, such as total CPU cores, total memory, storage, and IP addresses.

The following examples assume that you deploy only AKS-based workloads on the underlying infrastructure. If you deploy non-AKS workloads, such as standalone or clustered virtual machines or database servers, you reduce the resources available to AKS.

Before you start, consider the following points to determine your maximum scale and the number of target clusters you need to support:

- The number of IP addresses you have available for pods in a target cluster.
- The number of IP addresses available for Kubernetes services in a target cluster.
- The number of pods you need to run your workloads.

To determine the size of your Azure Kubernetes Service host VM, you need to know the number of worker nodes and target clusters. This information determines the size of the AKS host VM. For example:

- The number of target clusters in the final deployed system.
- The number of nodes, including control plane, load balancer, and worker nodes across all target clusters.

> [!NOTE]
> A single AKS host can only manage target clusters on the same platform.

To determine the size of your target cluster control plane node, you need to know the number of pods, containers, and worker nodes you plan to deploy in each target cluster.

### Default settings that you can't change in AKS

During or after deployment, you can't change some default configurations and settings. These settings can limit the scale for a given target cluster.

- The subnet `10.244.0.0/16` limits the number of IP addresses for Kubernetes pods in a target cluster. That limit means each worker node can use 255 IP addresses for pods across all Kubernetes namespaces. To see the pod CIDR assigned to each worker node in your cluster, use the following command in PowerShell:

```powershell
kubectl get nodes -o json | findstr 'hostname podCIDR'
```

```json
                    "kubernetes.io/hostname": "moc-lip6cotjt0f",
                                "f:podCIDR": {},
                                "f:podCIDRs": {
                                    "f:kubernetes.io/hostname": {},
                "podCIDR": "10.244.2.0/24",
                "podCIDRs": [
                    "kubernetes.io/hostname": "moc-lmb6zqozk4m",
                                "f:podCIDR": {},
                                "f:podCIDRs": {
                                    "f:kubernetes.io/hostname": {},
                "podCIDR": "10.244.4.0/24",
                "podCIDRs": [
                    "kubernetes.io/hostname": "moc-wgwhhijxtfv",
                                "f:podCIDR": {},
                                "f:podCIDRs": {
                                    "f:kubernetes.io/hostname": {},
                "podCIDR": "10.244.5.0/24",
                "podCIDRs": [
```

In the example, you see three nodes with three CIDRs, and each node can host 254 pods. For performance reasons, the Kubernetes scale documentation recommends that you don't exceed 110 pods per node. See [Considerations for large clusters](https://kubernetes.io/docs/setup/best-practices/cluster-large/).

Other considerations:

- The `10.96.0.0/16` address pool provides IP addresses for Kubernetes services outside the VIP pool you allocated. The system uses one of the 255 available addresses for the Kubernetes API server.
- You can only set the size of the AKS host VM during installation when you run `Set-AksHciConfig` for the first time. You can't change it later.
- You can only set the size of target cluster control plane and load balancer VMs when you create the target cluster.

### Scale example

The following scaling example is based on these general assumptions and use cases:

- You want to tolerate the loss of one physical node in the Kubernetes cluster.
- You want to support upgrading target clusters to newer versions.
- You want high availability for the target cluster control plane nodes and load balancer nodes.
- You want to reserve a part of the overall Windows Server capacity for these cases.

#### Suggestions

- For optimal performance, set aside at least 15 percent (100/8=12.5) of cluster capacity to allow all resources from one physical node to be redistributed to the other seven nodes. This configuration ensures that you have some reserve capacity to perform an upgrade or other AKS day two operations.

- If you want to grow beyond the 200-VM limit for a maximum hardware sized eight-node cluster, increase the size of the AKS host VM. Doubling the size results in roughly double the number of VMs it can manage. In an eight-node Kubernetes cluster, you can manage up to 8,192 (8x1024) VMs based on the recommended resource limits documented in the [Maximum supported hardware specifications](/azure/azure-local/concepts/system-requirements#maximum-supported-hardware-specifications). You should reserve approximately 30% of capacity, which leaves you with a theoretical limit of 5,734 VMs across all nodes.

  - **Standard_D32s_v3**, for the AKS host with 32 cores and 128 GB, can support a maximum of 1,600 nodes.

  > [!NOTE]
  > Since this configuration isn't extensively tested, it requires a careful approach and validation.

- At a scale like this, you might want to split the environment into at least eight target clusters with 200 worker nodes each.
- To run 200 worker nodes in one target cluster, you can use the default control plane and load balancer size. Depending on the number of pods per node, you can go up at least one size on the control plane and use **Standard_D8s_v3**.
- Depending on the number of Kubernetes services hosted in each target cluster, you might have to increase the size of the load balancer VM as well at target cluster creation to ensure that services can be reached with high performance and traffic is routed accordingly.

The deployment of AKS on Windows Server distributes the worker nodes for each node pool in a target cluster across the available nodes using placement logic.

> [!IMPORTANT]
> The node placement isn't preserved during platform and AKS upgrades and changes over time. A failed physical node also impacts the distribution of virtual machines across the remaining cluster nodes.

> [!NOTE]
> Don't run more than four target cluster creations at the same time if the physical cluster is already 50% full, as that condition can lead to temporary resource contention.
> When scaling up target cluster node pools by large numbers, take into account available physical resources, as AKS doesn't verify resource availability for parallel running creation and scaling processes.
> Always ensure enough reserve capacity to allow for upgrades and failover. Especially in very large environments, these operations, when run in parallel, can lead to rapid resource exhaustion.

If in doubt, contact your local Microsoft office for assistance or [post in the community forum](https://feedback.azure.com/d365community/search/?q=Azure+Kubernetes).

## Next steps

- [Storage options](../local/hyperconverged/concepts-storage.md)
