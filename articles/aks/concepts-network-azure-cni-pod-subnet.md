---
title: Concepts - Azure CNI Pod Subnet networking in Azure Kubernetes Service (AKS)
description: Learn about Azure CNI Pod Subnet, dynamic IP allocation mode, and static block allocation mode in Azure Kubernetes Service (AKS).
ms.topic: concept-article
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.date: 09/10/2026
author: schaffererin
ms.author: schaffererin
ms.custom: references_regions
ai-usage: ai-assisted
# Customer intent: "As a Kubernetes administrator, I want to understand Azure CNI Pod Subnet networking options, so that I can effectively manage IP address allocation and optimize network performance in my AKS clusters."
---

# Azure Container Networking Interface (CNI) Pod Subnet

In Azure Kubernetes Service (AKS), Azure CNI Pod Subnet assigns IP addresses to pods from a separate subnet from your cluster nodes. This feature is available in two modes: Dynamic IP Allocation and Static Block Allocation.

## Prerequisites

> [!NOTE]
> When using Static Block Allocation of CIDRs, exposing an application as a Private Link Service using a Kubernetes Load Balancer Service isn't supported.

- Review the [AKS CNI networking prerequisites][aks-cni-networking-prerequisites].
- Review the configuration guidance for [Dynamic IP Allocation][configure-dynamic-ip-allocation] and [Static Block Allocation][configure-static-block-allocation].
- AKS Engine and DIY clusters aren't supported.
- Use Azure CLI version `2.75.0` or later to configure Static Block Allocation.

## Dynamic IP allocation mode

Dynamic IP allocation helps mitigate pod IP address exhaustion issues by allocating pod IPs from a subnet that's separate from the subnet hosting the AKS cluster.

The Dynamic IP Allocation mode offers the following benefits:

- **Better IP utilization**: IPs are dynamically allocated to cluster Pods from the Pod subnet. This leads to better utilization of IPs in the cluster compared to the traditional CNI solution, which does static allocation of IPs for every node.
- **Scalable and flexible**: Node and pod subnets can be scaled independently. A single pod subnet can be shared across multiple node pools of a cluster or across multiple AKS clusters deployed in the same VNet. You can also configure a separate pod subnet for a node pool.  
- **High performance**: Since pods are assigned VNet IPs, they have direct connectivity to other cluster pods and resources in the VNet.
- **Separate VNet policies for pods**: Since pods have a separate subnet, you can configure separate VNet policies for them that are different from node policies. This enables many useful scenarios, such as allowing internet connectivity only for pods and not for nodes, fixing the source IP for pod in a node pool using an Azure NAT Gateway, and using network security groups (NSGs) to filter traffic between node pools.  
- **Kubernetes network policies**: For Linux node pools, use Azure CNI Powered by Cilium. For Windows node pools, use Calico. New subscriptions can't enable Azure Network Policy Manager (NPM). Azure NPM support ends on September 30, 2026, for Windows and September 30, 2028, for Linux. For more information, see [Network policies in AKS][network-policies].

### Limitations

- The maximum supported pod subnet size is `/16`. Large clusters can also be limited to approximately 65,000 pods by the Azure address mapping limit. For larger-scale scenarios, use Static Block Allocation.
- Azure CNI Pod Subnet with Dynamic IP Allocation isn't supported with [node auto-provisioning (NAP)][nap-networking].

### Plan IP addressing

With Dynamic IP Allocation, nodes and pods scale independently, so you can plan their address spaces separately. Since pod subnets can be configured to the granularity of a node pool, you can always add a new subnet when you add a node pool. The system pods in a cluster/node pool also receive IPs from the pod subnet, so this behavior needs to be accounted for.

IPs are allocated to nodes in batches of 16. Pod subnet IP allocation should be planned with a minimum of 16 IPs per node in the cluster, as the nodes request 16 IPs on startup and request another batch of 16 anytime there are <8 IPs unallocated in their allotment.

IP address planning for Kubernetes services and Docker Bridge remain unchanged.

## Static block allocation mode

Static block allocation helps mitigate potential pod subnet sizing and Azure address mapping limitations by assigning CIDR blocks to nodes rather than individual IPs.

The Static Block Allocation mode offers the following benefits:

- **Better IP scalability**: CIDR blocks are statically allocated to the cluster nodes and are present for the lifetime of the node, as opposed to the traditional dynamic allocation of individual IPs with traditional CNI. This enables routing based on CIDR blocks and helps scale the cluster limit up to 1 million pods from the traditional 65K pods per cluster. Your Azure Virtual Network must be large enough to accommodate the scale of your cluster. 
- **Flexibility**: Node and pod subnets can be scaled independently. A single pod subnet can be shared across multiple node pools of a cluster or across multiple AKS clusters deployed in the same VNet. You can also configure a separate pod subnet for a node pool.  
- **High performance**: Since pods are assigned virtual network IPs, they have direct connectivity to other cluster pods and resources in the VNet.
- **Separate VNet policies for pods**: Since pods have a separate subnet, you can configure separate VNet policies for them that are different from node policies. This enables many useful scenarios such as allowing internet connectivity only for pods and not for nodes, fixing the source IP for pod in a node pool using an Azure NAT Gateway, and using NSGs to filter traffic between node pools.  
- **Kubernetes network policies**: For Linux node pools, use Azure CNI Powered by Cilium. For Windows node pools, use Calico. New subscriptions can't enable Azure NPM. Azure NPM support ends on September 30, 2026, for Windows and September 30, 2028, for Linux. For more information, see [Network policies in AKS][network-policies].

### Limitations

Below are some of the limitations of using Azure CNI Static Block allocation:
- Minimum Kubernetes Version required is 1.28.
- Maximum subnet size supported is x.x.x.x/12 ~ 1 million IPs.
- Windows Server 2019 nodes aren't supported in Azure CNI Pod Subnet.
- Only a single mode of operation can be used per subnet. If a subnet uses Static Block allocation mode, it cannot use Dynamic IP allocation mode in a different cluster or node pool with the same subnet and vice versa.
- In-place migration or updates of existing node pools aren't supported. To migrate an existing cluster from Dynamic IP Allocation to Static Block Allocation, [add a Static Block Allocation node pool on a new subnet and move the workloads][migrate-to-static-block].
- Across all the CIDR blocks assigned to a node in the node pool, one IP will be selected as the primary IP of the node. Thus, for network administrators selecting the `--max-pods` value try to use the calculation below to best serve your needs and have optimal usage of IPs in the subnet:

`max_pods = (N * 16) - 1` where `N` is any positive integer and `N` > 0

### Plan IP addressing

With Static Block Allocation, nodes and pods scale independently, so you can plan their address spaces separately. Since pod subnets can be configured to the granularity of a node pool, you can always add a new subnet when you add a node pool. The system pods in a cluster/node pool also receive IPs from the pod subnet, so this behavior needs to be accounted for.

CIDR blocks of /28 (16 IPs) are allocated to nodes based on your `--max-pods` configuration for your node pool, which defines the maximum number of pods per node. 1 IP is reserved on each node from all the available IPs on that node for internal purposes. 

While planning your IPs, it's important to define your `--max-pods` configuration using the following calculation: `max_pods_per_node = (16 * N) - 1`, where `N` is any positive integer greater than `0`.

Ideal values with no IP wastage would require the max pods value to conform to the above expression.

See the following example cases: 

> [!NOTE] 
> The examples assume /28 CIDR blocks (16 IPs each).

| Example case | `max_pods` | CIDR Blocks allocated per node | Total IP available for pods | IP wastage for node |
| --- | --- | --- | --- | --- |
| Low wastage (acceptable) | 30 | 2 | (16 * 2) - 1 = 32 - 1 = 31 | 31 - 30 = 1 |
| Ideal case | 31 | 2 | (16 * 2) - 1 = 32 - 1 = 31 | 31 - 31 = 0 |
| High wastage (not recommended) | 32 | 3 | (16 * 3) - 1 = 48 - 1 = 47 | 47 - 32 = 15 |

IP address planning for Kubernetes services remains unchanged.

> [!NOTE]
> Ensure your VNet has a sufficiently large and contiguous address space to support your cluster's scale.

<!-- LINKS - External -->

<!-- LINKS - Internal -->
[aks-cni-networking-prerequisites]: ./concepts-network-cni-overview.md#aks-cni-networking-prerequisites
[configure-dynamic-ip-allocation]: ./configure-azure-cni-dynamic-ip-allocation.md
[configure-static-block-allocation]: ./configure-azure-cni-static-block-allocation.md
[migrate-to-static-block]: ./configure-azure-cni-static-block-allocation.md#migrating-from-pod-subnet---dynamic-ip-allocation-to-pod-subnet---static-block-allocation
[nap-networking]: ./node-auto-provisioning-networking.md#supported-networking-configurations-for-nap
[network-policies]: ./use-network-policies.md