---
title: Plan Application Networking for Azure Kubernetes Service (AKS) Workloads
description: This article provides an overview of the networking components you need to consider for Azure Kubernetes Service (AKS) applications.
ms.topic: overview
ms.subservice: aks-networking
ms.date: 11/07/2026
author: schaffererin
ms.author: schaffererin
ai-usage: ai-assisted
# Customer intent: I want to understand the networking options available for my applications to effectively plan and optimize my Azure Kubernetes Service (AKS) workloads.
---

# Plan application networking for Azure Kubernetes Service (AKS)

In this article, you learn application networking options for Azure Kubernetes Service (AKS). We first pose a question to help guide your planning, and then provide options, recommendations, and best practices.

## How do you want to access your applications?

Application networking controls how clients access applications running in your Kubernetes pods and how services communicate within and across clusters.

## Application networking options

Choose application networking options based on whether you need to expose applications to clients outside the cluster or manage service-to-service communication:

| Application networking option | Features & functionality |
|-------------------|--------------------------|
| [Load Balancer Service](./concepts-network-services.md#loadbalancer) | • Uses a Kubernetes `LoadBalancer` Service to directly expose an application on a public or private IP. <br> • Supports multiple ports and any TCP or UDP traffic. <br> • Requires _at least one_ unique IP:port pair per application. |
| Ingress controllers | • Exposes an application behind a layer-7 reverse proxy. <br> • Usable only for HTTP-like traffic (HTTP, HTTPS, gRPC). <br> • Can share a single public IP and ports for all ingress definitions on the same ingress controller. <br> • Managed ingress options include: Managed ingress-nginx through the [application routing add-on](./app-routing.md), [Azure Application Gateway for Containers (recommended)](/azure/application-gateway/for-containers/overview), and [Istio ingress gateway](./istio-about.md). |
| [Azure Kubernetes Application Network (preview)](./application-network-overview.md) | • Provides managed, sidecar-free service-to-service communication within and across AKS member clusters. <br> • Provides mTLS and workload identity for enrolled services, with optional layer-7 routing and authorization. <br> • Manages the service-network control plane and data plane. <br> • Doesn't replace application ingress or create underlying cross-cluster network connectivity. |

## Recommendations

For clients accessing applications from outside the cluster, use **Load Balancer Service with layer-4 load balancing** for **non-HTTP traffic**. This approach provides direct access to your applications and supports a wide range of protocols. For **HTTP-like traffic**, use **Ingress controllers with layer-7 load balancing**. This approach allows you to take advantage of advanced routing features and share a single public IP for multiple applications.

For **service-to-service communication**, consider [Azure Kubernetes Application Network (preview)](./application-network-overview.md) when you need managed workload identity, mTLS, and traffic policies without sidecars. Review its [preview status and current limitations](../application-network/overview.md) before adoption, and plan ingress and underlying network connectivity separately.

## Related content

- [Azure Kubernetes Application Network for service-to-service communication (preview)](./application-network-overview.md)
- [Plan control plane networking for Azure Kubernetes Service (AKS)](./plan-control-plane-networking.md)
- [Plan node networking for Azure Kubernetes Service (AKS)](./plan-node-networking.md)
- [Plan pod networking for Azure Kubernetes Service (AKS)](./plan-pod-networking.md)
