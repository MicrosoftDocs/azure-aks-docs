---
title: Plan Node Networking for Azure Kubernetes Service (AKS) Workloads
description: This article provides an overview of the networking components you need to consider for Azure Kubernetes Service (AKS) nodes.
ms.topic: overview
ms.date: 03/24/2025
author: schaffererin
ms.author: schaffererin
# Customer intent: I want to understand the networking options available for my nodes to effectively plan and optimize my Azure Kubernetes Service (AKS) workloads.
---

# Plan node networking for Azure Kubernetes Service (AKS)

In this article, you learn node networking options for Azure Kubernetes Service (AKS). We first pose a question to help guide your planning, and then provide options, recommendations, and best practices.

## How do you want your cluster to access the internet?

You need to configure networking for AKS nodes (Azure virtual machines (VMs)) to access each other, the API server, and the internet. When selecting a VNet, you can choose between a managed VNet or a bring-your-own (BYO) VNet. There are also different cluster outbound types available depending on your networking needs.

## Node networking options

When setting up node networking, you can choose between **Load Balancer**, **NAT Gateway**, and **User Defined Routing (UDR)** :

| Node networking option | Diagram of networking components | Features & functionality |
|------------------------|----------------------------------|--------------------------|
| Load Balancer | :::image type="content" source="./media/plan-networking/load-balancer.png" alt-text="Screenshot of a diagram of the networking components of a Load Balancer."::: | • Default configuration. <br>  • Managed entirely by AKS. <br> • Follows [Azure Standard Load Balancer](/azure/load-balancer/load-balancer-overview) rules. <br> • Provides fixed SNAT ports assigned per node upon node creation. |
| NAT Gateway | :::image type="content" source="./media/plan-networking/nat-gateway.png" alt-text="Screenshot of a diagram of the networking components of a NAT Gateway."::: | • Can select a managed or user-assigned (BYO) option. <br> • Provides improved SNAT port handling over Load Balancer. <br> • Requires extra configuration for zone redundancy. |
| User Defined Routing (UDR) | :::image type="content" source="./media/plan-networking/user-defined-routing.png" alt-text="Screenshot of a diagram of the networking components of a User Defined Routing (UDR)."::: | • Used for explicit network control with BYO VNet. <br> • Managed by you, providing a more customizable experience. <br> • Must have a default route to an Azure Firewall, vWAN, or third-party network virtual appliance (NVA). <br> • Typically doesn't support external Load Balancer services directly. |

## Recommendations

Our **general recommendation** is to use a **Load Balancer**. If you have a **high volume of outbound connections**, consider using a **NAT Gateway** for better SNAT port management. If you have any **custom egress needs (Azure Firewall, NVA, etc.)**, you might want to explore **User Defined Routing (UDR)**.

## Related content

- [Plan control plane networking for Azure Kubernetes Service (AKS)](./plan-control-plane-networking.md)
- [Plan pod networking for Azure Kubernetes Service (AKS)](./plan-pod-networking.md)
- [Plan application networking for Azure Kubernetes Service (AKS)](./plan-application-networking.md)
