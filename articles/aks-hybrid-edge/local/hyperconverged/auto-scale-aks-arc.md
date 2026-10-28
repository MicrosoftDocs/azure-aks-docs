---
title: Use auto-scaling in a Kubernetes cluster
description: Learn how to use Azure CLI for cluster autoscaling.
ms.topic: how-to
ms.custom: devx-track-azurecli, hyperconverged
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.reviewer: srikantsarwa
ms.lastreviewed: 06/09/2025

# Intent: As a Kubernetes user, I want to use cluster autoscaling to grow my nodes to keep up with application demand.
# Keyword: cluster autoscaling Kubernetes
---

# Use cluster autoscaler on an AKS cluster

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

To keep up with application demands in Kubernetes, you might need to adjust the number of nodes that run your workloads. The cluster autoscaler component watches for pods in your cluster that can't be scheduled because of resource constraints. When the cluster autoscaler detects issues, it scales up the number of nodes in the node pool to meet the application demands. It also regularly checks nodes for a lack of running pods and scales down the number of nodes as needed. This article shows you how to enable and manage the cluster autoscaler in AKS.

> [!NOTE]
> Before enabling autoscaling on your Azure Local cluster, review the [Scale requirements for AKS on Azure Local](/azure/aks/aksarc/scale-requirements#scale-requirements-when-using-autoscaler-with-aks-on-azure-local) to ensure your environment meets the required limits.

## Enable the cluster autoscaler on a new cluster

Create an AKS cluster using the [`az aksarc create`](/cli/azure/aksarc#az-aksarc-create) command, and enable and configure the cluster autoscaler on the node pool for the cluster using the `--enable-cluster-autoscaler` parameter and specifying `--min-count` and `--max-count` for a node. The following example command creates a cluster with a single node, enables the cluster autoscaler, and sets a minimum of one and maximum of three nodes:

```azurecli-interactive
az aksarc create \
--resource-group myResourceGroup \
--name my-aks-arc-cluster \
--custom-location $customLocationId 
--vnet-ids $vnetId
--generate-ssh-keys
--aad-admin-group-object-ids $entraIds
--node-count 1 \
--enable-cluster-autoscaler \
--min-count 1 \
--max-count 3
```

It takes a few minutes to create the cluster and configure the cluster autoscaler settings.

### Enable the cluster autoscaler on an existing cluster

Update an existing cluster using the [`az aksarc update`](/cli/azure/aksarc#az-aksarc-update) command, and enable and configure the cluster autoscaler using the `--enable-cluster-autoscaler` parameter and specifying `--min-count` and `--max-count` for a node. The following example command updates an existing AKS cluster to enable the cluster autoscaler on the cluster and sets a minimum of one and maximum of three nodes:

```azurecli-interactive
az aksarc update \
  --resource-group myResourceGroup \
  --name my-aks-arc-cluster \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 3
```

It takes a few minutes to update the cluster and configure the cluster autoscaler settings.

### Disable the cluster autoscaler on a cluster

Disable the cluster autoscaler using the [`az aksarc update`](/cli/azure/aksarc#az-aksarc-update) command and the `--disable-cluster-autoscaler` parameter:

```azurecli-interactive
az aksarc update \
  --resource-group myResourceGroup \
  --name my-aks-arc-cluster \
  --disable-cluster-autoscaler
```

Nodes aren't removed when the cluster autoscaler is disabled.

## Update the cluster autoscaler settings

As your application demands change, you might need to adjust the cluster autoscaler node count to scale efficiently. Change the node count using the [`az aksarc update`](/cli/azure/aksarc#az-aksarc-update) command and update the cluster autoscaler using the `--update-cluster-autoscaler` parameter and specifying your updated `--min-count` and `--max-count` for the node.

```azurecli-interactive
az aksarc update \
  --resource-group myResourceGroup \
  --name myAKSCluster \
  --update-cluster-autoscaler \
  --min-count 1 \
  --max-count 5
```

## Use the cluster autoscaler profile

You can configure more granular details of the cluster autoscaler by changing the default values in the cluster-wide autoscaler profile. For example, a scale down event happens after nodes are under-utilized after 10 minutes. If you have workloads that run every 15 minutes, you might want to change the autoscaler profile to scale down under-utilized nodes after 15 or 20 minutes. When you enable the cluster autoscaler, a default profile is used unless you specify different settings.

### Cluster autoscaler profile settings

The following table lists the available settings for the cluster autoscaler profile:

|Setting |Description |Default value |
|--------|------------|--------------|
| `scan-interval` | How often the cluster is reevaluated for scale up or down. | 10 seconds |
| `scale-down-delay-after-add` | How long after scale up that scale down evaluation resumes. | 10 minutes |
| `scale-down-delay-after-delete` | How long after node deletion that scale down evaluation resumes. | `scan-interval` |
| `scale-down-delay-after-failure` | How long after scale down failure that scale down evaluation resumes. | Three minutes |
| `scale-down-unneeded-time` | How long a node should be unneeded before it's eligible for scale down. | 10 minutes |
| `scale-down-unready-time` | How long an unready node should be unneeded before it's eligible for scale down. | 20 minutes |
| `scale-down-utilization-threshold` | Node utilization level, defined as sum of requested resources divided by capacity, in which a node can be considered for scale down. | 0.5 |
| `max-graceful-termination-sec` | Maximum number of seconds the cluster autoscaler waits for pod termination when trying to scale down a node. | 600 seconds |
| `balance-similar-node-groups` | Detects similar node pools and balances the number of nodes between them. | `false` |
| `expander` | Type of node pool [the expander](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#what-are-expanders) uses in scale up. Possible values include `most-pods`, `random`, `least-waste`, and `priority`. |  |
| `skip-nodes-with-local-storage` | If `true`, cluster autoscaler doesn't delete nodes with pods with local storage; for example, EmptyDir or HostPath. | `true` |
| `skip-nodes-with-system-pods` | If `true`, cluster autoscaler doesn't delete nodes with pods from kube-system (except for DaemonSet or mirror pods). | `true` |
| `max-empty-bulk-delete` | Maximum number of empty nodes that can be deleted at the same time. | 10 nodes |
| `new-pod-scale-up-delay` | For scenarios such as burst/batch scale where you don't want CA to act before the Kubernetes scheduler could schedule all the pods, you can tell CA to ignore unscheduled pods before they reach a certain age. | 0 seconds |
| `max-total-unready-percentage` | Maximum percentage of unready nodes in the cluster. After this percentage is exceeded, CA halts operations. | 45% |
| `max-node-provision-time` | Maximum time the autoscaler waits for a node to be provisioned. | 15 minutes |

### Set the cluster autoscaler profile on a new cluster

Create an AKS cluster using the [`az aksarc create`](/cli/azure/aksarc#az-aksarc-create) command and set the cluster autoscaler profile using the `cluster-autoscaler-profile` parameter:

```azurecli-interactive
az aksarc create \
  --resource-group myResourceGroup \
  --name my-aks-arc-cluster \
  --node-count 1 \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 3 \
  --cluster-autoscaler-profile scan-interval=30s
```

### Set the cluster autoscaler profile on an existing cluster

Set the cluster autoscaler on an existing cluster using the [`az aksarc update`](/cli/azure/aksarc#az-aksarc-update) command and the `cluster-autoscaler-profile` parameter. The following example configures the scan interval setting as **30s**:

```azurecli-interactive
az aksarc update \
  --resource-group myResourceGroup \
  --name my-aks-arc-cluster \
  --cluster-autoscaler-profile scan-interval=30s
```

### Reset cluster autoscaler profile to default values

Reset the cluster autoscaler profile using the [`az aksarc update`](/cli/azure/aksarc#az-aksarc-update) command:
  
```azurecli-interactive
az aksarc update \
  --resource-group myResourceGroup \
  --name my-aks-arc-cluster \
  --cluster-autoscaler-profile ""
```

## Make effective use of autoscaler

Now that the cluster and node pool are configured to automatically scale, you can optionally configure a workload to also scale in a way that makes use of the horizontal autoscaler capabilities.

> [!NOTE]
> The following guidance is not officially supported by Microsoft. It's shared as a best-effort recommendation based on open-source practices.

There are two methods available for workload scaling:

- **Kubernetes Horizontal Pod Autoscaler**: Based on load characteristics, the Horizontal Pod Autoscaler (also known as the *horizontal autoscaler*) scales the pods of an application deployment to available nodes in the Kubernetes cluster. If no more nodes are available to be scheduled, the horizontal autoscaler instantiates a new node to which to schedule the pods. If the application load subsides, the nodes are scaled back again. For the Horizontal Pod Autoscaler to work, you must manually deploy the Metrics Server component in your AKS cluster. For more information about horizontal pod autoscaler rules, see [Kubernetes horizontal pod autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/).
- **Kubernetes node anti-affinity rules**: Anti-affinity rules for a Kubernetes deployment can specify that a set of pods can't be scaled on the same node, and a different node is required to scale the workload. In combination with either load characteristics or the number of target pods for the application instances, the horizontal autoscaler instantiates new nodes in the node pool to satisfy requests. If application demand subsides, the horizontal autoscaler scales down the node pool again. For more information about Kubernetes pod affinity rules, see [Assigning Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node).

## Next steps

This article showed you how to automatically scale the number of AKS nodes. To scale node pools manually, see [manage node pools in AKS clusters](manage-node-pools.md).
