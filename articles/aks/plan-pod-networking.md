---
title: Plan Pod Networking for Azure Kubernetes Service (AKS) Workloads
description: This article provides an overview of the networking components you need to consider for Azure Kubernetes Service (AKS) pods.
ms.topic: overview
ms.subservice: aks-networking
ms.date: 09/09/2026
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: I want to understand the networking options available for my pods to effectively plan and optimize my Azure Kubernetes Service (AKS) workloads.
---

# Plan pod networking for Azure Kubernetes Service (AKS)

Choose a pod networking configuration based on whether pods need direct IP access from connected networks and your IP address scale requirements.

## Do you need direct pod IP access?

Pod networking controls how pods get IP addresses and defines how pods communicate with each other, cluster nodes, and destinations outside the cluster. Kubernetes implements pod networking through a _Container Network Interface (CNI)_ plugin, which manages pod IP addresses and network connectivity.

When setting up pod networking, you need to plan for **IP address management (IPAM)** and **routing and transport (data plane)**.

If your workloads require pods to be reachable by private IP from networks connected to the Azure Kubernetes Service (AKS) cluster VNet, use a Flat Networking Model. Otherwise, use Azure CNI Overlay.

## IP address management (IPAM) options

When setting up IPAM, you can choose between an **Overlay Networking Model** with **[Azure CNI Overlay](./concepts-network-azure-cni-overlay.md)** and a **Flat Networking Model** with **[Azure CNI Pod Subnet](./concepts-network-azure-cni-pod-subnet.md)** or **[Azure CNI Node Subnet](./concepts-network-legacy-cni.md#azure-cni-node-subnet)**:

The following table compares the IPAM options available for AKS pod networking, including their key features and scale limits.

| IPAM options | Diagram of networking components | Features & functionality |
|--------------|----------------------------------|--------------------------|
| Overlay Networking Model (with Azure CNI Overlay) | :::image type="content" source="./media/plan-networking/overlay-networking.png" alt-text="Screenshot of a diagram of the networking components of an Overlay Networking Model."::: | • Pod IPs come from an overlay range that's _not_ part of the VNet space. <br> • Highly scalable networking, with _up to 5,000 nodes_ and _200,000 pods per cluster_. The node, per-node pod, and aggregate pod limits are independent. <br> • Pod overlay address space can be reused across independent clusters. The pod CIDR must not overlap with directly connected networks, including peered VNets, networks connected through ExpressRoute or a VPN, and other routes that expose private address space. <br> • Dual-stack (IPv4/IPv6) support. <br> • Pods can't be accessed directly from outside the cluster. |
| Flat Networking Model (with Azure CNI Pod Subnet _or_ Node Subnet) | :::image type="content" source="./media/plan-networking/flat-networking.png" alt-text="Screenshot of a diagram of the networking components of a Flat Networking Model."::: | • Node and pod IPs come from VNet space. <br> • Pods can be accessed by their private IP addresses from connected networks. Azure CNI Pod Subnet preserves the pod source IP across connected VNets, while destinations outside the cluster VNet see the node source IP with Azure CNI Node Subnet. <br> • Azure CNI Pod Subnet options include **[Dynamic IP Allocation](./configure-azure-cni-dynamic-ip-allocation.md)** for efficiency or **[Static Block Allocation](./configure-azure-cni-static-block-allocation.md)** for scale. |

### Considerations for Flat Networking Model options

Keep the following considerations in mind when deciding between **Azure CNI Pod Subnet with Dynamic IP Allocation**, **Azure CNI Pod Subnet with Static Block Allocation**, and **Azure CNI Node Subnet**:

| Flat Networking Model option | Considerations |
|------------------------------|----------------|
| Azure CNI Pod Subnet with Dynamic IP Allocation | • Requires separate node and pod subnets that you can size and scale independently. <br> • Allocates pod IP addresses to nodes from the pod subnet in batches of 16. <br> • Subject to VNet configured private IP address limits. |
| Azure CNI Pod Subnet with Static Block Allocation | • Requires careful planning, as you need to allocate a specific range of IPs for your pods and ensure it doesn't overlap with other subnets. <br> • Can get _up to 1,000,000 IPs_. <br> • IPs might not be used as efficiently, which could lead to wastage. |
| Azure CNI Node Subnet | • Legacy option that can use an AKS-managed VNet or a customer-managed VNet and subnet. <br> • Nodes and pods share the node subnet, so you need to plan capacity in advance for nodes, pods, scaling, and upgrades. <br> • Subject to VNet configured private IP address limits. |

## Routing and transport (data plane) options

When setting up your data plane, you can choose between [**Azure CNI Powered by Cilium**](./azure-cni-powered-by-cilium.md), [**Azure iptables data plane**](./configure-azure-cni.md), and [**BYO CNI**](./use-byo-cni.md):

The following table compares the data plane options available for AKS pod networking and their key capabilities.

| Data plane options | Features & functionality |
|--------------------|--------------------------|
| Azure CNI Powered by Cilium | • Improved scale and performance for Linux node pools. Windows node pools aren't supported. <br> • Built-in Cilium network policy enforcement. <br> • FQDN filtering requires Advanced Container Networking Services and Kubernetes 1.29 or later. |
| Azure iptables | • Use _Calico_ for Windows network policy enforcement. Azure Network Policy Manager (NPM) support ends on September 30, 2026, for Windows and September 30, 2028, for Linux. New subscriptions can no longer enable Azure NPM. <br> • For Linux clusters, use Azure CNI Powered by Cilium instead of Azure NPM. <br> • Supports Kubernetes NetworkPolicy. |
| BYO CNI | • No managed CNI plugin installed - you can use any option that supports AKS. <br> • Microsoft _doesn't support_ any CNI-related issues. |

## AKS pod networking recommendations

Our **general recommendation** is to use **Azure CNI Overlay**. If you **need direct pod IP access from connected networks and have efficiency or scale requirements**, consider using **Azure CNI Pod Subnet with Dynamic IP Allocation** or **Azure CNI Pod Subnet with Static Block Allocation**. Azure CNI Node Subnet is a legacy option; in general, use it only if you need an AKS-managed VNet for your cluster.

## Related content

- [Plan control plane networking for Azure Kubernetes Service (AKS)](./plan-control-plane-networking.md)
- [Plan node networking for Azure Kubernetes Service (AKS)](./plan-node-networking.md)
- [Plan application networking for Azure Kubernetes Service (AKS)](./plan-application-networking.md)
