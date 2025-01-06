---
title: Operate cost optimized Azure Kubernetes Service (AKS) at scale
description: Learn how to operate cost optimized Azure Kubernetes Service (AKS) at scale.
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 01/03/2025
---

# Operate cost optimized Azure Kubernetes Service (AKS) at scale

This article provides guidance on how to operate cost optimized Azure Kubernetes Service (AKS) at scale. It covers the following topics:

- [Operate cost optimized Azure Kubernetes Service (AKS) at scale](#operate-cost-optimized-azure-kubernetes-service-aks-at-scale)
  - [Azure Kubernetes Fleet Manager](#azure-kubernetes-fleet-manager)
    - [Resource propagation](#resource-propagation)

## Azure Kubernetes Fleet Manager

[Azure Kubernetes Fleet Manager](/azure/kubernetes-fleet/overview) enables at-scale management of multiple AKS clusters.




A *fleet* is a group of AKS clusters, and you can use them to manage multiple clusters as a single entity, orchestrate updates across multiple clusters, and propagate Kubernetes resources across multiple clusters.

For more information, see the [Azure Kubernetes Fleet Manager documentation](/azure/kubernetes-fleet/).

### Resource propagation

