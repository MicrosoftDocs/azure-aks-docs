---
title: Optimize Azure Kubernetes Service (AKS) usage and costs
description: Learn different ways to optimize your Azure Kubernetes Service (AKS) usage and costs.
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 12/30/2024
---

# Optimize Azure Kubernetes Service (AKS) usage and costs

This article provides guidance on how to optimize your Azure Kubernetes Service (AKS) usage and costs. It covers the following topics:

* [Automatic scaling](#automatic-scaling)
* [GPU partitioning](#gpu-partitioning)
* [Cluster rightsizing](#cluster-rightsizing)
* [Multitenancy](#multitenancy)
* [Azure discounts](#azure-discounts)

## About cost optimization


## Automatic scaling

### Horizontal pod autoscaling

The Horizontal Pod Autoscaler (HPA) monitors resource demand and automatically updates a workload resource to automatically scale the number of pods to match demand. The response to increased load is to deploy more pods. If the load decreases and the number of pods is above the configured minimum, the autoscaler tells the workload resource to scale down.

The Metrics API gets data from the kubelet every 60 seconds, and the HPA checks the Metrics API every 15 seconds for any needed changes by default. This means that the HPA updates every 60 seconds. When you configure the HPA for a deployment, you define the minimum and maximum number of replicas that can run and the metrics that the HPA uses to determine when to scale.

For more information, see [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) and [Autoscale pods in AKS](./tutorial-kubernetes-scale.md#autoscale-pods).

### Kubernetes event-driven autoscaling

The [Kubernetes Event-driven Autoscaler (KEDA)](https://keda.sh/) applies event-driven autoscaling to your workloads. KEDA works with the HPA and can extend functionality without overwriting or duplication.

You can use the KEDA add-on for AKS to scale your applications and leverage a [rich catalog of Azure KEDA scalers](https://keda.sh/docs/2.16/scalers/). For more information, see [Application autoscaling with the KEDA add-on](./keda-about.md) and [Install the KEDA add-on for AKS](./keda-deploy-add-on-cli.md).

### Vertical pod autoscaling

The Vertical Pod Autoscaler (VPA) automatically sets resource requests and limits on containers per workload based on past usage. The VPA frees up CPU and Memory for pods to ensure effective utilization of your AKS clusters. Over time, the VPA provides recommendations for resource usage.

For more information, see [Vertical pod autoscaling in Azure Kubernetes Service (AKS)](./vertical-pod-autoscaler.md) and [Use the Vertical Pod Autoscaler (VPA) in Azure Kubernetes Service (AKS)](./use-vertical-pod-autoscaler.md).

## GPU partitioning


### Collect metrics



### GPU partitioning strategies



#### Time-slicing


#### Multi-processing service (MPS)


#### Multi-instance GPUs (MIGs)


## Cluster rightsizing


### Rightsize your cluster



### Cluster autoscaling



### Node autoprovisioning (preview)



## Multitenancy

### Dedicated cluster



### Dedicated node pool



### Dedicated namespace



## Azure discounts

* Azure Savings Plans
* Reserved Instances
* Azure Hybrid Benefits


## Next steps

XYZ.
