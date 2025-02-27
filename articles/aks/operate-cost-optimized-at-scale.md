---
title: Operate cost optimized Azure Kubernetes Service (AKS) at scale
description: Learn how to operate cost optimized Azure Kubernetes Service (AKS) at scale.
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 02/27/2025
---

# Operate cost optimized Azure Kubernetes Service (AKS) at scale

This article provides guidance on how to operate cost optimized Azure Kubernetes Service (AKS) at scale. It covers the following topics:

- [Operate cost optimized Azure Kubernetes Service (AKS) at scale](#operate-cost-optimized-azure-kubernetes-service-aks-at-scale)
  - [Azure Kubernetes Fleet Manager (Kubernetes Fleet)](#azure-kubernetes-fleet-manager-kubernetes-fleet)
    - [Resource propagation](#resource-propagation)

## Azure Kubernetes Fleet Manager (Kubernetes Fleet)

[Azure Kubernetes Fleet Manager (Kubernetes Fleet)](/azure/kubernetes-fleet/overview) enables at-scale management of multiple AKS clusters. You can create a *Fleet resource* and use it to manage multiple clusters as a single entity, orchestrate updates across multiple clusters, and propagate Kubernetes resources across multiple clusters. When creating a new *Fleet resource*, you can create it with or without a *hub cluster*. A *hub cluster* is a managed AKS cluster that acts a hub to store and propagate Kubernetes resources.

:::image type="content" source="./media/operate-cost-optimized-at-scale/kubernetes-fleet-manager.png" alt-text="Screenshot of a diagram representing Azure Kubernetes Fleet Manager.":::

For more information, see the [Azure Kubernetes Fleet Manager documentation](/azure/kubernetes-fleet/).

### Resource propagation

Kubernetes Fleet provides *resource propagation* to enable at-scale management of Kubernetes resources. You can create Kubernetes resources in the *hub cluster* and propagate them to specified *member clusters* using the `MemberCluster` and `ClusterResourcePlacement` custom resources.

:::image type="content" source="./media/operate-cost-optimized-at-scale/kubernetes-resource-propagation.png" alt-text="Screenshot of a diagram representing Azure kubernetes Fleet Manager resource propagation.":::

For more information, see [Kubernetes Fleet resource placement from hub cluster to member clusters](/azure/kubernetes-fleet/concepts-resource-propagation).
