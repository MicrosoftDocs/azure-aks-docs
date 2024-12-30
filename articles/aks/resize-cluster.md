---
title: Resize Azure Kubernetes Service (AKS) clusters
description: In this article, you learn about the importance of right-sizing your AKS clusters and how you can right-size them to optimize costs and performance.
ms.topic: how-to
ms.date: 12/18/2024
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
# Customer intent: As a cluster operator, I want to resize my cluster so I can scale my workloads based on demand.
---

# Resize Azure Kubernetes Service (AKS) clusters

In this article, you learn how to resize an Azure Kubernetes Service (AKS) cluster. It's important to right-size your clusters to optimize costs and performance. You can manually resize a cluster by adding or removing the nodes to meet the needs of your applications. You can also autoscale your cluster to automatically adjust the number of nodes in response to changing demands.

## Cluster right-sizing

When you create an AKS cluster, you specify the number of nodes and the size of the nodes, which determines the compute capacity of the cluster. Oversized clusters can lead to unnecessary costs, while undersized clusters can lead to performance issues. You can adjust the number and size of the nodes in the cluster to right-size the cluster to meet the needs of your applications.

Consider the following factors when right-sizing your cluster:

* **Resource requirements**: Understand the resource requirements of your applications to determine the number of nodes and the size of the nodes needed to run your workloads.
* **Performance requirements**: Determine the performance requirements of your applications to ensure that the cluster can meet the demands of your workloads.
* **Cost considerations**: Optimize costs by right-sizing your cluster to avoid unnecessary costs associated with oversized clusters.
* **Application demands**: Monitor the demands of your applications to adjust the size of the cluster in response to changing demands.
* **Infrastructure constraints**: Consider the infrastructure constraints of your environment, such as capacity or reserved instance limiting to specific SKUs, to ensure that the cluster can be right-sized within the limits of your environment.

## Monitor cluster performance and cost

Closely monitor the performance and cost of your clusters to ensure they're right-sized to meet the needs of your application and make adjustments as needed. You can use the following resources for monitoring:

* [Identify high CPU usage in Azure Kubernetes Service (AKS) clusters][identify-high-cpu-usage]
* [Troubleshoot memory saturation in Azure Kubernetes Service (AKS) clusters][troubleshoot-memory-saturation]
* [Cost analysis add-on for Azure Kubernetes Service (AKS)](./cost-analysis.md)
* [Configure the Metrics Server Vertical Pod Autoscaler (VPA) in Azure Kubernetes Service (AKS)](./use-metrics-server-vertical-pod-autoscaler.md)

## When to resize a cluster

You might want to resize a cluster in scenarios such as the following:

* If you see that CPU and memory usage is consistently low, consider *downsizing* the cluster. If usage is consistently high, make sure you have [autoscaling enabled](#automatically-resize-an-aks-cluster) and increase the maximum node count if necessary.
* The [cost analysis add-on for AKS](./cost-analysis.md) shows you details about node usage and cost that indicate you might benefit from cluster resizing. For example, if you see that your nodes have a *high idle cost* with a *low usage cost*, you might consider resizing your cluster to reduce costs.
* The [Metrics Server VPA](./use-metrics-server-vertical-pod-autoscaler.md) shows you that your requests and/or limits are too high or low based on historical usage. You can use this information to adjust your cluster size to better match your workload.
* You experience performance issues such as resource starvation. This might be a result of the cluster being undersized for the demands of your applications.

## What happens when I resize a cluster?

### Increasing cluster size

You can increase the size of an AKS cluster by adding nodes to the cluster. You can [add nodes to the cluster manually][manually-scale] or [configure autoscaling to automatically adjust the number of nodes](#automatically-resize-an-aks-cluster) in response to changing demands.

When you increase the size of a cluster, the following changes occur:

* New node instances are created using the same configuration as the existing nodes in the cluster.
* New pods might be scheduled on the new nodes to distribute the workload across the cluster.
* Existing pods don't move to the new nodes unless they are rescheduled due to node failures or other reasons.

### Decreasing cluster size

You can decrease the size of an AKS cluster by removing nodes from the cluster. When you remove nodes from the cluster, the nodes are automatically drained and removed from the cluster. You can remove nodes from the cluster manually or configure autoscaling to automatically adjust the number of nodes in response to changing demands.

When you decrease the size of a cluster, the following changes occur:

* AKS gracefully terminates the nodes and drains the pods running on the nodes before removing the nodes from the cluster.
* Any pods managed by a replication controller are rescheduled on other node instances in the cluster.
* Any pods that aren't managed by a replication controller aren't restarted.

## Manually resize an AKS cluster

### [Azure CLI](#tab/azure-cli)

* Resize an AKS cluster using the [`az aks scale`][az-aks-scale] command with the `--node-count` and `--nodepool-name` parameters.

    ```azurecli-interactive
    az aks scale --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --node-count $NUM_NODES --nodepool-name $NODE_POOL_NAME
    ```

    Repeat this command for each node pool in the cluster that you want to resize. If your cluster has only one node pool, you can omit the `--nodepool-name` parameter.

### [Azure portal](#tab/azure-portal)

1. In the Azure portal, go to the AKS cluster that you want to resize.
2. Under **Settings**, select **Node pools**.
3. Select the node pool that you want to resize > **Scale node pool**.
4. On the **Scale node pool** page, enter the new **Node count** value.
5. Select **Apply** and repeat the steps for each node pool in the cluster that you want to resize.

---

## Automatically resize an AKS cluster

Use the [cluster autoscaler](./cluster-autoscaler-overview.md) to automatically resize your node pools in response to changing demands.

For more information, see the [Cluster autoscaling in Azure Kubernetes Service (AKS) overview](./cluster-autoscaler-overview.md). To configure cluster autoscaling in AKS, see [Use the cluster autoscaler in Azure Kubernetes Service (AKS)](./cluster-autoscaler.md).

## Next steps

In this article, you learned how to right-size an AKS cluster. To learn more about managing AKS clusters, see the following articles:

* [Stop and start an AKS cluster](./start-stop-cluster.md)
* [Configure a private AKS cluster](./private-clusters.md)
* [Use AKS cluster extensions](./cluster-extensions.md)

<!-- LINKS -->
[az-aks-scale]: /cli/azure/aks#az-aks-scale
[manually-scale]: ./scale-cluster.md
[identify-high-cpu-usage]: /troubleshoot/azure/azure-kubernetes/availability-performance/identify-high-cpu-consuming-containers-aks
[troubleshoot-memory-saturation]: /troubleshoot/azure/azure-kubernetes/availability-performance/identify-memory-saturation-aks
