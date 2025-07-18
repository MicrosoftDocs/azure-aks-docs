---
title: Operate cost optimized Azure Kubernetes Service (AKS) at scale
description: Learn how to operate cost optimized Azure Kubernetes Service (AKS) at scale.
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 03/18/2025
# Customer intent: "As a cloud operations manager, I want to implement cost-optimized Kubernetes management practices, so that I can efficiently operate multiple AKS clusters at scale while minimizing operational costs."
---

# Operate cost-optimized Azure Kubernetes Service (AKS) at scale

This article provides guidance on how to operate cost optimized Azure Kubernetes Service (AKS) at scale.

## Azure Kubernetes Fleet Manager (Kubernetes Fleet)

[Azure Kubernetes Fleet Manager (Kubernetes Fleet)](/azure/kubernetes-fleet/overview) enables at-scale management of multiple AKS clusters. You can create a *Fleet resource* and use it to manage multiple clusters as a single entity, orchestrate updates across multiple clusters, and propagate Kubernetes resources across multiple clusters. When creating a new *Fleet resource*, you can create it with or without a *hub cluster*. A *hub cluster* is a managed AKS cluster that acts a hub to store and propagate Kubernetes resources.

:::image type="content" source="./media/operate-cost-optimized-at-scale/kubernetes-fleet-manager.png" alt-text="Screenshot of a diagram representing Azure Kubernetes Fleet Manager.":::

Kubernetes Fleet can help you reduce the management overhead cost of operating multiple clusters by providing a single entry point for managing multiple clusters. For more information, see the [Azure Kubernetes Fleet Manager documentation](/azure/kubernetes-fleet/).

### Resource propagation

Kubernetes Fleet provides *resource propagation* to enable at-scale management of Kubernetes resources. You can create Kubernetes resources in the *hub cluster* and propagate them to specified *member clusters* using the `MemberCluster` and `ClusterResourcePlacement` custom resources.

:::image type="content" source="./media/operate-cost-optimized-at-scale/kubernetes-resource-propagation.png" alt-text="Screenshot of a diagram representing Azure kubernetes Fleet Manager resource propagation.":::

For more information, see [Kubernetes Fleet resource placement from hub cluster to member clusters](/azure/kubernetes-fleet/concepts-resource-propagation).

### Intelligent resource placement

Kubernetes Fleet provides *intelligent resource placement*, which can make scheduling decisions based on node count, cost of compute/memory in target member clusters, and resource availability in target member clusters. This allows you to place workloads in the most cost-effective member cluster based on your workload requirements.

:::image type="content" source="./media/operate-cost-optimized-at-scale/intelligent-resource-placement.png" alt-text="Screenshot of a diagram showing how intelligent resource placement works.":::

For more information, see [Intelligent cross-cluster Kubernetes resource placement using Azure Kubernetes Fleet Manager](/azure/kubernetes-fleet/intelligent-resource-placement).

## AKS Automatic

[AKS Automatic (preview)](./intro-aks-automatic.md) offers an experience that makes the most common tasks on Kubernetes fast and frictionless, while preserving the flexibility, extensibility, and consistency of Kubernetes. Azure takes care of cluster setup, including node management, scaling, and security, and preconfigures settings that follow AKS well-architected recommendations.

AKS Automatic clusters are designed to help reduce management overhead costs of creating cluster templates, managing the cluster lifecycle, guardrails, and updates. Scaling is seamless and dynamic. Nodes are created based on workload requests using [node autoprovisioning (NAP)](./node-autoprovision.md) and workloads are automatically scaled with features like Horizontal Pod Autoscaler (HPA), [Kubernetes Event Driven Autoscaling (KEDA)](./keda-about.md), and [Vertical Pod Autoscaler (VPA)](./vertical-pod-autoscaler.md).

## Azure Advisor cost recommendations

AKS cost recommendations in Azure Advisor provide recommendations to help you achieve cost-efficiency without sacrificing reliability. Advisor analyzes your resource configurations and recommends optimization solutions. For more information, see [Get Azure Kubernetes Service (AKS) cost recommendations in Azure Advisor](./cost-advisors.md).

## Next steps

To learn more about cost optimization in Azure Kubernetes Service (AKS), see the following articles:

- [Best practices for cost optimization in Azure Kubernetes Service (AKS)](./best-practices-cost.md)
- [Understand Azure Kubernetes Service (AKS) usage and costs](./understand-aks-costs.md)
- [Optimize Azure Kubernetes Service (AKS) usage and costs](./optimize-aks-costs.md)
- [Azure Kubernetes Service (AKS) cost analysis](./cost-analysis.md)
