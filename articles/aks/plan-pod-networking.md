---
title: Plan Pod Networking for Azure Kubernetes Service (AKS) Workloads
description: This article provides an overview of the networking components you need to consider for Azure Kubernetes Service (AKS) pods.
ms.topic: overview
ms.date: 03/24/2025
author: schaffererin
ms.author: schaffererin
# Customer intent: I want to understand the networking options available for my pods to effectively plan and optimize my Azure Kubernetes Service (AKS) workloads.
---

# Plan pod networking for Azure Kubernetes Service (AKS)

In this article, you learn pod networking options for Azure Kubernetes Service (AKS). We first pose a question to help guide your planning, and then provide options, recommendations, and best practices.

## Do you need direct pod IP access?

Pod networking controls how pods have IP addresses assigned and defined how pods communicate with each other, cluster nodes, and destinations outside the cluster. Kubernetes provides pod networking through a _Container Network Interface (CNI)_ plugin, which is responsible for managing pod IP addresses and network connectivity.

When setting up pod networking, you need to plan for **IP address management (IPAM)** and **routing and transport (data plane)**.

## IP address management (IPAM) options

When setting up IPAM, you can choose between an **Overlay Networking Model** with **[Azure CNI Overlay](./concepts-network-azure-cni-overlay.md)** and a **Flat Networking Model** with **[Azure CNI Pod Subnet](./concepts-network-azure-cni-pod-subnet.md)** or **[Azure CNI Node Subnet](./concepts-network-legacy-cni.md#azure-cni-node-subnet)**:

| | Overlay Networking Model (with Azure CNI Overlay) | Flat Networking Model (with Azure CNI Pod Subnet _or_ Node Subnet) |
|---|---|---|
| Diagram of networking components | :::image type="content" source="./media/plan-networking/overlay-networking.png" alt-text="Screenshot of a diagram of the networking components of an Overlay Networking Model."::: | :::image type="content" source="./media/plan-networking/flat-networking.png" alt-text="Screenshot of a diagram of the networking components of a Flat Networking Model."::: |
| Features & functionality | • Pod IPs come from an overlay range that's _not_ part of the VNet space. <br> • Highly scalable networking, with _up to 5,000 nodes_ and _250,000 pods_. <br> • Reuse pod overlay space across all clusters without conflict. _Things like VNet peering or ExpressRoute direct connections might cause conflicts with private IP space_. <br> • Dual-stack (IPV4/IPV6) support. <br> • Pods can't be accessed directly from outside the cluster. | • Node and pod IPs come from VNet space. <br> • Pods can be accessed directly from outside the cluster. <br> • Azure CNI Pod Subnet options include **[Dynamic IP Allocation](./configure-azure-cni-dynamic-ip-allocation.md)** for efficiency or **[Static Block Allocation](./configure-azure-cni-static-block-allocation.md)** for scale. <br> |

Keep the following considerations in mind when deciding between **Azure CNI Pod Subnet with Dynamic IP Allocation**, **Azure CNI Pod Subnet with Static Block Allocation**, and **Azure CNI Node Subnet**:

| | Azure CNI Pod Subnet with Dynamic IP Allocation | Azure CNI Pod Subnet with Static Block Allocation | Azure CNI Node Subnet |
|---|---|---|---|
| Considerations | • Involves some complexity and management. You need to delegate a subnet for your nodes and pods, and ensure you properly scope it to handle the scale you need. <br> • Limitation of _64,000 IPs_. | • Requires careful planning, as you need to allocate a specific range of IPs for your pods and ensure it doesn't overlap with other subnets. <br> • Can get _up to 1,000,000 IPs_. <br> • IPs might not be used as efficiently, which could lead to wastage. | • AKS manages the subnet for you, simplifying the setup. <br> • Limitation of _64,000 IPs_. |

## Routing and transport (data plane) options

When setting up your data plane, you can choose between [**Azure CNI Powered by Cilium eBPF data plane**](./azure-cni-powered-by-cilium.md), [**Azure IPTables data plane**](./configure-azure-cni.md), and [**BYO CNI**](./use-byo-cni.md):

| | Azure CNI Powered by Cilium | Azure IPTables | BYO CNI |
|---|---|---|---|
| Features & functionality | • Improved scale and performance. <br> • Built-in Network Policy Manager (NPM). <br> • Enhanced network policies, such as FQDN filtering with Advanced Container Network Services. | • Install _Calico_ or _Azure NPM (not recommended)_ for your Network Policy Manager. <br> • Supports all Kubernetes spec Network Policies. | • No managed CNI plugin installed - you can use any option that supports AKS. <br> • Microsoft _doesn't support_ any CNI-related issues. |

## Recommendations

Our **general recommendation** is to use **Azure CNI Overlay**. If you **need direct IP access and have efficiency or scale requirements**, consider using **Azure CNI Pod Subnet with Dynamic IP Allocation** or **Azure CNI Pod Subnet with Static Block Allocation**. If you **need direct pod IP access and want simplified management**, consider using **Azure CNI Node Subnet**.

## Next step

To continue planning your AKS networking, see the following article:

> [!div class="nextstepaction"]
> [Plan application networking for Azure Kubernetes Service (AKS)](./plan-application-networking.md)
