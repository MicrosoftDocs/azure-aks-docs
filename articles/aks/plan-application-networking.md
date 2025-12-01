---
title: Plan Application Networking for Azure Kubernetes Service (AKS) Workloads
description: This article provides an overview of the networking components you need to consider for Azure Kubernetes Service (AKS) applications.
ms.topic: overview
ms.date: 03/24/2025
author: schaffererin
ms.author: schaffererin
# Customer intent: I want to understand the networking options available for my applications to effectively plan and optimize my Azure Kubernetes Service (AKS) workloads.
---

# Plan application networking for Azure Kubernetes Service (AKS)

In this article, you learn application networking options for Azure Kubernetes Service (AKS). We first pose a question to help guide your planning, and then provide options, recommendations, and best practices.

## How do you want to access your applications?

Application networking controls how the applications running in your Kubernetes pods are exposed to clients from outside the cluster.

## Application networking options

When setting up application networking, you can choose between a **Load Balancer Service with layer-4 load balancing** or **Ingress controllers with layer-7 load balancing**:

| | Load Balancer Service | Ingress controllers |
|---|---|---|
| Features & functionality | • Uses a Kubernetes `LoadBalancer` Service to directly expose an application on a public or private IP. <br> • Supports multiple ports and any TCP or UDP traffic. <br> • Requires *at least one* unique IP:port pair per application. | • Exposes an application behind a layer-7 reverse proxy. <br> • Usable only for HTTP-like traffic (HTTP, HTTPS, gRPC). <br> • Can share a single public IP and ports for all ingress definitions on the same ingress controller. <br> • Managed ingress options include: Managed ingress-nginx through the [application routing add-on](./app-routing.md), [Azure Application Gateway for Containers (recommended)](/azure/application-gateway/for-containers/overview), and [Istio ingress gateway](./istio-about.md). |

## Recommendations

For **non-HTTP traffic**, we recommend using **Load Balancer Service with layer-4 load balancing**. This approach provides direct access to your applications and supports a wide range of protocols. For **HTTP-like traffic**, we recommend using **Ingress controllers with layer-7 load balancing**. This approach allows you to take advantage of advanced routing features and share a single public IP for multiple applications.

## Related content

To learn more about networking in AKS, see the following articles:

- [IP address planning for your Azure Kubernetes Service (AKS) clusters](./concepts-network-ip-address-planning.md)
- [Best practices for network connectivity and security in Azure Kubernetes Service (AKS)](./operator-best-practices-network.md)
- [Outbound network and FQDN rules for Azure Kubernetes Service (AKS) clusters](./outbound-rules-control-egress.md)
