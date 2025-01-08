---
title: Monitor Azure Kubernetes Service (AKS) idle costs
description: Learn how to monitor and optimize idle costs in the Azure Kubernetes Service (AKS) cost analysis add-on.
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-monitoring
ms.topic: how-to
ms.date: 01/08/2025
---

# Understand Azure Kubernetes Service (AKS) idle costs

If you have the [Azure Kubernetes Service (AKS) cost analysis add-on enabled](./cost-analysis.md#enable-cost-analysis-on-your-aks-cluster) and see high idle costs, then you have an opportunity to optimize your cluster and improve cost efficiency. This article explains what idle costs are, how to monitor them, and how to reduce them.

## What are idle costs?

*Idle costs* are due to idle resources, which come from overprovisioning, low utilization, and resource wastage scenarios. Customers often overprovision resources for various reasons, including:

* Concern about performance issues in the event of running out of memory resources.
* Unpredictable workloads, such as a batch workload that requires a lot of resources at once and then drops for a period of time before spiking again.
* Wanting to ensure that resources are available for buffer or unexpected periods of high resource demand.

If more nodes are provisioned than needed, or if resource requests are much greater than what's actually used, it can lead to idle costs.

## Monitor cluster metrics and cost data

To understand where your cluster idle costs come from, you can monitor the following metrics in [Azure Monitor](/azure/azure-monitor/essentials/monitor-azure-resource), [Managed Prometheus](/azure/azure-monitor/essentials/prometheus-metrics-overview#azure-monitor-managed-service-for-prometheus), or [self-hosted Prometheus](/azure/azure-monitor/essentials/prometheus-metrics-overview#azure-hosted-self-managed-prometheus):

* **Total memory request on the cluster** indicates the total amount of memory requested by all pods in the cluster and ensures the cluster has enough memory to meet the workload demands.
* **Total CPU request on the cluster** indicates total CPU requested by all pods in the cluster and ensures the cluster can handle the computational needs of the workloads.
* **Max memory usage** indicates the peak memory usage in the cluster and helps identify any memory spikes that could lead to performance issues or resource constraints. This is important for preventing OOMkill or pod crashes.
* **Max CPU usage** indicates the peak CPU usage observed in the cluster, helps detect CPU-intensive workloads, and ensures the cluster can handle peak loads or spikes in workload demand.
* **Average memory usage** is useful for identifying trends and determining if the cluster is overprovisioned or underutilized. If usage is consistently below the total memory capacity, it means the cluster has more memory resources than needed.
* **Average CPU usage** is useful for understanding the overall CPU demand. If usage is consistently below the total CPU capacity and CPU request, it means the cluster has more CPU resources than needed.
* **Node count** indicates the number of nodes in the cluster and helps identify if there's an excess number of nodes with low utilization.

To improve utilization, it's important to monitor these metrics and [adjust your cluster size and resources](#optimize-your-cluster-size-and-resources) accordingly.

## Optimize your cluster size and resources

| Recommended action | Description |
|--------------------|-------------|
| [Manual resizing](./resize-cluster.md) | Adjust the number of nodes in your cluster based on resource requirements. |
| [Enable the cluster autoscaler](./cluster-autoscaler.md) | Automatically adjust the number of nodes in your cluster based on the resource requests of your pods. This helps ensure you only pay for the resources you need. |
| Use an [alternative VM SKU type](./best-practices-cost.md#evaluate-sku-family) | Use a compute-optimized or memory-optimized SKU based on underutilized CPU nad memory resources. |
| Consider using [Spot VMs](/azure/virtual-machines/spot-vms) | For noncritical workloads, Spot VMs can be a cost-effective option. |
| [Enable the Vertical Pod Autoscaler (VPA)](./use-vertical-pod-autoscaler.md) | Automatically adjust the resource requests and limits of your pods based on their actual usage. This helps ensure that your pods are using the right amount of resources and can help reduce idle costs. |

## Frequently asked questions (FAQs)

### If a node has no pods running and is pending cluster autoscaler scale down, will the node cost be considered idle?

If there are no pods running but the node is ready, most of the node cost will be considered idle. Small amounts will be considered system cost.

### What percentage of the cost is due to pods not fully utilizing resources where the requests of the pods match the available requests?

If pods request 100% of the node resources but don’t utilize them, you can expect no idle charge because it takes the maximum usage and request for usage.

## Next steps

For more cost optimization tips, see [Best practices for cost optimization in Azure Kubernetes Service (AKS)](./best-practices-cost.md).
