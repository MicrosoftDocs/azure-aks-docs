---
title: Optimize Azure Kubernetes Service (AKS) usage and costs
description: Learn different ways to optimize your Azure Kubernetes Service (AKS) usage and costs.
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 02/27/2025
---

# Optimize Azure Kubernetes Service (AKS) usage and costs

This article provides guidance on how to optimize your Azure Kubernetes Service (AKS) usage and costs. It covers guidance on the following topics:

* [Automatic scaling](#automatic-scaling)
* [Cluster right-sizing](#cluster-right-sizing)
* [GPU optimizations](#gpu-optimizations)
* [Multitenancy](#multitenancy)
* [Azure discounts](#azure-discounts)

## Automatic scaling

### Horizontal pod autoscaling

The ***Horizontal Pod Autoscaler (HPA)*** monitors resource demand and automatically updates a workload resource to automatically scale the number of pods to match demand. The response to increased load is to deploy more pods. If the load decreases and the number of pods is above the configured minimum, the autoscaler tells the workload resource to scale down.

The Metrics API gets data from the kubelet every 60 seconds, and the HPA checks the Metrics API every 15 seconds for any needed changes by default. This means that the HPA updates every 60 seconds. When you configure the HPA for a deployment, you define the minimum and maximum number of replicas that can run and the metrics that the HPA uses to determine when to scale.

For more information, see [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) and [Autoscale pods in AKS](./tutorial-kubernetes-scale.md#autoscale-pods).

### Kubernetes event-driven autoscaling

The [***Kubernetes Event-driven Autoscaler (KEDA)***](https://keda.sh/) applies event-driven autoscaling to your workloads. KEDA works with the HPA and can extend functionality without overwriting or duplication.

You can use the KEDA add-on for AKS to scale your applications and leverage a [rich catalog of Azure KEDA scalers](https://keda.sh/docs/2.16/scalers/). For more information, see [Application autoscaling with the KEDA add-on](./keda-about.md) and [Install the KEDA add-on for AKS](./keda-deploy-add-on-cli.md).

### Vertical pod autoscaling

The ***Vertical Pod Autoscaler (VPA)*** automatically sets resource requests and limits on containers per workload based on past usage. The VPA frees up CPU and Memory for pods to ensure effective utilization of your AKS clusters. Over time, the VPA provides recommendations for resource usage.

For more information, see [Vertical pod autoscaling in Azure Kubernetes Service (AKS)](./vertical-pod-autoscaler.md) and [Use the Vertical Pod Autoscaler (VPA) in Azure Kubernetes Service (AKS)](./use-vertical-pod-autoscaler.md).

## Cluster right-sizing

### Right-size your cluster

It's important to ***right-size your clusters*** to optimize costs and performance. You can manually resize a cluster by adding or removing the nodes to meet the needs of your applications. You can also autoscale your cluster to automatically adjust the number of nodes in response to changing demands.

For more information, see [Resize Azure Kubernetes Service (AKS) clusters](./resize-cluster.md).

### Cluster autoscaling

With the ***cluster autoscaler***, you can automatically scale node pools based on resource usage and constraints, such as scaling up to schedule pending pods or scaling down to reduce costs for unused nodes. The [cluster autoscaler profile](./cluster-autoscaler-overview.md#cluster-autoscaler-profile) is a set of parameters that you can fine-tune to control the behavior of the cluster autoscaler.

For more information, see [Cluster autoscaling in Azure Kubernetes Service (AKS) overview](./cluster-autoscaler-overview.md) and [Use the cluster autoscaler in Azure Kubernetes Service (AKS)](./cluster-autoscaler.md).

### Node autoprovisioning (preview)

***Node autoprovisioning (NAP)*** (preview), based on the open-source [Karpenter](https://karpenter.sh/) project, helps you provision the right infrastructure based on the pending pod resource requirements of your workloads. With efficient bin-packing, you can consolidate your workloads onto the right-sized infrastructure to reduce operating costs.

For more information, see [Node autoprovisioning (preview) in Azure Kubernetes Service (AKS)](./node-autoprovision.md).

## GPU optimizations

### GPU partitioning and sharing

GPU partitioning helps combat underutilization by splitting up or sharing GPUs across multiple workloads. The following sections cover different ways to partition and share GPUs in AKS.

#### Time-slicing

The [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/overview.html) enables the ***time-slicing*** of GPUs in Kubernetes clusters. With time-slicing, a system administrator can define a set of *replicas* for a GPU, each of which can be handed out independently to a pod to run workloads on. You can apply cluster-wide default time-slicing configurations and node-specific configurations.

:::image type="content" source="./media/optimize-aks-costs/gpu-time-slicing.png" alt-text="Screenshot of a visual chart example showing GPU time-slicing.":::

For more information, see [Time-slicing GPUs in Kubernetes](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html).

#### Multi-processing service (MPS)

A single process might not utilize all the memory and compute bandwidth capacity available on a GPU. The ***Multi-Process Service (MPS)*** enables logical partitioning of memory and compute resources between workloads and allows kernel and memcopy operations from different processes to overlap on the GPU. MPS helps you achieve higher GPU utilization and shorter running times.

:::image type="content" source="./media/optimize-aks-costs/gpu-mps.png" alt-text="Screenshot of a visual chart example showing GPU multi-process service (MPS).":::

For more information, see [Multi-Process Service (MPS)](https://docs.nvidia.com/deploy/mps/index.html#mps).

#### Multi-instance GPUs (MIGs)

***Multi-instance GPUs (MIGs)*** enable you to partition GPUs based on the NVIDIA Ampere and later architectures into separate and secure GPU instances for CUDA applications.

:::image type="content" source="./media/optimize-aks-costs/gpu-migs.png" alt-text="Screenshot of a visual chart example showing multi-instance GPUs (MIGs).":::

For more information, see [GPU Operator with MIG](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-operator-mig.html) and [Create a multi-instance GPU node pool in Azure Kubernetes Service (AKS)](./gpu-multi-instance.md).

## Multitenancy

Multitenancy refers to the sharing of infrastructure across tenants, teams, and business units. The following table outlines different ways to implement multitenancy in AKS:

| Multitenancy type | Multitenancy level | Cluster pod density | Cost allocation | Ideal use case | Potential risks |
|-------------------|-------|---------------------|-----------------|----------------|-----------------|
| [**Dedicated cluster**](#dedicated-cluster) | Hard multitenancy | Lower | Easiest | Complete security isolation boundaries and straightforward cost allocation | • Cluster sprawl at scale adds to management overhead costs <br> • Lower pod density and more overprovisioned resources |
| [**Dedicated node pool**](#dedicated-node-pool) | Soft multitenancy | Medium | Medium | Medium pod density | • Requires trust between tenants <br> • Requires extra cluster configurations, like network policies, quota management, role-based access control (RBAC), etc. |
| [**Dedicated namespace**](#dedicated-namespace) | Soft multitenancy | Higher | Harder | Sharing infrastructure to maximize resource utilization | • Unsafe for hostile environments by default <br> • Requires extra cluster configurations, like network policies, quota management, role-based access control (RBAC), etc. |

### Dedicated cluster

With ***dedicated cluster multitenancy***, clusters are dedicated to a single workload or team.

:::image type="content" source="./media/optimize-aks-costs/dedicated-cluster.png" alt-text="Screenshot of a visual chart example showing dedicated cluster multitenancy.":::

The following table outlines pros and cons of using a dedicated cluster:

| Pros | Cons |
|------|------|
| • Easier isolation method <br> • Straightforward cost allocation and chargeback <br> • Great for cases where tenants don't trust each other (often from security and resource sharing perspectives) | • High management and financial overhead <br> • Generally low pod density and overprovisioned resources |

### Dedicated node pool

With ***dedicated node pool multitenancy***, clusters are shared by many tenants.

:::image type="content" source="./media/optimize-aks-costs/dedicated-node-pool.png" alt-text="Screenshot of a visual chart example showing dedicated node pool multitenancy.":::

The following table outlines pros and cons of using a dedicated node pool:

| Pros | Cons |
|------|------|
| • Medium pod density <br> • Some shared infrastructure <br> • Apply Azure tags to node pools dedicated to a single tenant (tags propagate to nodes and persist through upgrades) | • Requires trust between the tenants <br> • Requires extra cluster configurations, like network policies, quota management, role-based access control (RBAC), etc. |

### Dedicated namespace

With ***dedicated namespace multitenancy***, clusters are shared by many tenants, with namespaces serving as the isolation boundary.

:::image type="content" source="./media/optimize-aks-costs/dedicated-namespace.png" alt-text="Screenshot of a visual chart example showing dedicated namespace multitenancy.":::

The following table outlines pros and cons of using a dedicated namespace:

| Pros | Cons |
|------|------|
| • Higher pod density <br> • Best binpacking <br> • Sharing infrastructure to maximize resource utilization | • Unsafe for hostile environments by default <br> • Requires extra security measures in place if all tenants can't be trusted |

## Azure discounts

To take savings one step further, take advantage of Azure discounts such as Azure Savings Plans, Reserved Instances, and Azure Hybrid Benefits.

| Azure discount type | Details |
|---------------------|---------|
| [**Azure Savings Plans**](/azure/cost-management-billing/savings-plan/savings-plan-compute-overview) | • 1-3 year upfront commitment <br> • Save up to 65% compared to pay-as-you-go <br> • Flexible, with no SKU family or region restrictions <br> • Best for workloads with consistent costs with resources in various SKUs and regions |
| [**Reserved Instances**](/azure/cost-management-billing/reservations/save-compute-costs-reservations) | • 1-3 year upfront commitment <br> • Save up to 72% compared to pay-as-you-go <br> • Restricted to specific SKU families and regions <br> • Best for stable workloads running continuously (with no unexpected SKU or region changes) |
| [**Azure Hybrid Benefits**](./azure-hybrid-benefit.md) | • Bring your own on-premises Windows Server and SQL Server licenses to Azure <br> • Use any qualifying on-premises licenses that have an active Software Assurance (SA) or qualifying subscription |

## Next steps

To learn more about cost in AKS, see the following articles:

* [Understand Azure Kubernetes Service (AKS) usage and costs](./understand-aks-costs.md)
* [Best practices for cost optimization in Azure Kubernetes Service (AKS)](./best-practices-cost.md)
* [Get Azure Kubernetes Service (AKS) cost recommendations in Azure Advisor](./cost-advisors.md)
