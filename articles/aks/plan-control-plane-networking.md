---
title: Plan Control Plane Networking for Azure Kubernetes Service (AKS) Workloads
description: This article provides an overview of the networking components you need to consider when planning your Azure Kubernetes Service (AKS) control plane workloads.
ms.topic: overview
ms.date: 03/24/2025
author: schaffererin
ms.author: schaffererin
# Customer intent: I want to understand the networking options available for my control plane to effectively plan and optimize my Azure Kubernetes Service (AKS) workloads.
---

# Plan control plane networking for Azure Kubernetes Service (AKS)

In this article, you learn control plane networking options for Azure Kubernetes Service (AKS). We first pose a question to help guide your planning, and then provide options, recommendations, and best practices.

## How do you want to access your API server?

The Azure-managed AKS control plane consists of several components that help manage the cluster, including the API server. You need to configure networking so that nodes and end users can access the API server for things like updates and cluster management.

## Control plane networking options

When setting up control plane networking, you can choose a **public cluster** or a **private cluster**:

| Control plane networking option | Diagram of networking components | Features & functionality |
|---------------------------------|----------------------------------|--------------------------|
| Public cluster | :::image type="content" source="./media/plan-networking/public-cluster.png" alt-text="Screenshot of a diagram of the networking components of a public AKS cluster."::: | • API server accessible via a _public IP address_, allowing users and nodes to connect without any extra configuration. <br> • You can restrict access to certain source IP ranges. <br> • Uses konnectivity tunnel for node and pod access. <br> • Supports [API Server VNet Integration](#api-server-vnet-integration-preview). |
| Private cluster | :::image type="content" source="./media/plan-networking/private-cluster.png" alt-text="Screenshot of a diagram of the networking components of a private AKS cluster"::: | • API server accessible via internal IP address, with [Azure Private DNS](/azure/dns/private-dns-overview) used for API server hostname. <br> • Uses [Azure Private Link](/azure/private-link/private-link-overview) to securely connect to the API server. <br> • Uses konnectivity tunnel for node and pod access. <br> • Supports [API Server VNet Integration](#api-server-vnet-integration-preview). |

### API Server VNet Integration (preview)

[API Server VNet Integration](./api-server-vnet-integration.md) is supported for public or private clusters. API Server VNet Integration enables network communication between the API server and the cluster nodes without requiring a private link or tunnel. The API server is available behind an internal load balancer VIP in the delegated subnet, which the nodes are configured to utilize.

With API Server VNet Integration:

- API server provisions into a delegated subnet within your virtual network (VNet).
- Can use a konnectivity tunnel for pod access in [Overlay](./concepts-network-azure-cni-overlay.md) or [BYO CNI](./use-byo-cni.md) clusters.
- Can add or remove API server public access at any time without cluster disruption.

## Recommendations

Our **general recommendation** is to use a **public cluster**, as it simplifies the networking setup and allows for easier access to the API server. However, if you have **specific security or compliance requirements**, a **private cluster** might be more appropriate.

Once generally available (GA), we recommend enabling [API Server VNet Integration](#api-server-vnet-integration-preview) for both public and private clusters to enhance security and simplify network management.

## Related content

- [Plan node networking for Azure Kubernetes Service (AKS)](./plan-node-networking.md)
- [Plan pod networking for Azure Kubernetes Service (AKS)](./plan-pod-networking.md)
- [Plan application networking for Azure Kubernetes Service (AKS)](./plan-application-networking.md)