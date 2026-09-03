---
title: Manage node taints for an AKS cluster
description: Learn how to manage node taints in AKS on Azure Local
ms.topic: how-to
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak 
ms.reviewer: srikantsarwa
ms.lastreviewed: 01/30/2024
ms.custom: hyperconverged
---

# Use node taints in an AKS Hybrid and Edge cluster

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

This article describes how to use node taints in an AKS cluster.

## Overview

The AKS scheduling mechanism is responsible for placing pods onto nodes and is based on the upstream Kubernetes scheduler, [kube-scheduler](https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/). You can constrain a pod to run on particular nodes by instructing the node to reject a set of pods using [node taints](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/), which interact with the AKS scheduler.

Node taints work by marking a node so that the scheduler avoids placing certain pods on the marked nodes. You can place [tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) on a pod to allow the scheduler to schedule that pod on a node with a matching taint. Taints and tolerations work together to help you control how the scheduler places pods onto nodes. For more information, see [example use cases of taints and tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/#example-use-cases:~:text=not%20be%20evicted.-,Example%20Use%20Cases,-Taints%20and%20tolerations).

Taints are key-value pairs with an [effect](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/). There are three values for the effect field when using node taints: `NoExecute`, `NoSchedule`, and `PreferNoSchedule`.

- `NoExecute`: Pods already running on the node are immediately evicted if they don't have a matching toleration. If a pod has a matching toleration, it might be evicted if `tolerationSeconds` are specified.
- `NoSchedule`: Only pods with a matching toleration are placed on this node. Existing pods aren't evicted.
- `PreferNoSchedule`: The scheduler avoids placing any pods that don't have a matching toleration.

### Before you begin

- This article assumes you have an existing AKS cluster. If you need an AKS cluster, you can create one using [Azure CLI](../aks-create-clusters-cli.md), Azure PowerShell, or the [Azure portal](../aks-create-clusters-portal.md).
- When you create a node pool, you can add taints to it. When you add a taint, all nodes within that node pool also get that taint.

> [!IMPORTANT]
> You should add taints or labels to nodes for the entire node pool using `az aksarc nodepool`. We don't recommend using `kubectl` to apply taints or labels to individual nodes in a node pool.

### Set node pool taints

Create a node pool with a taint using the [`az aksarc nodepool add`](/cli/azure/aksarc/nodepool#az-aksarc-nodepool-add) command. Specify the name `taintnp` and use the `--node-taints` parameter to specify `sku=gpu:NoSchedule` for the taint:

```azurecli
az aksarc nodepool add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name taintnp \
    --node-count 1 \
    --node-taints sku=gpu:NoSchedule \
    --no-wait
```

Check the status of the node pool using the [`az aksarc nodepool list`](/cli/azure/aksarc/nodepool#az-aksarc-nodepool-list) command:

```azurecli
az aksarc nodepool list -g myResourceGroup --cluster-name myAKSCluster
```

The following example output shows that the `taintnp` node pool creates nodes with the specified `nodeTaints`:

```output
[
  {
    ...
    "count": 1,
    ...
    "name": "taintnp",
    ...
    "provisioningState": "Succeeded",
    ...
    "nodeTaints":  [
      "sku=gpu:NoSchedule"
    ],
    ...
  },
 ...
]
```

The taint information is visible in Kubernetes for handling scheduling rules for nodes. The Kubernetes scheduler can use taints and tolerations to restrict which workloads can run on nodes.

- A *taint* is applied to a node that indicates only specific pods can be scheduled on them.
- A *toleration* is then applied to a pod that allows them to "tolerate" a node's taint.

### Set node pool tolerations

In the previous step, you applied the `sku=gpu:NoSchedule` taint when you created the node pool. The following example YAML manifest uses a toleration to allow the Kubernetes scheduler to run an NGINX pod on a node in that node pool:

Create a file named **nginx-toleration.yaml** and copy/paste the following example YAML:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mypod
spec:
  containers:
  - image: mcr.microsoft.com/oss/nginx/nginx:1.15.9-alpine
    name: mypod
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 1
        memory: 2G
  tolerations:
  - key: "sku"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"
```

Schedule the pod using the `kubectl apply` command:

```azurecli
kubectl apply -f nginx-toleration.yaml
```

It takes a few seconds to schedule the pod and pull the NGINX image.

Check the status using the [`kubectl describe pod`](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_describe/) command:

```azurecli
kubectl describe pod mypod
```

The following condensed example output shows that the `sku=gpu:NoSchedule` toleration is applied. In the **Events** section, the scheduler assigned the pod to the `moc-lbeof1gn6x3` node:

```output
[...]
Tolerations:     node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                 node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
                 sku=gpu:NoSchedule
Events:
  Type    Reason     Age    From                Message
  ----    ------     ----   ----                -------
  Normal  Scheduled  54s  default-scheduler   Successfully assigned default/mypod to moc-lbeof1gn6x3
  Normal  Pulling    53s  kubelet             Pulling image "mcr.microsoft.com/oss/nginx/nginx:1.15.9-alpine"
  Normal  Pulled     48s  kubelet             Successfully pulled image "mcr.microsoft.com/oss/nginx/nginx:1.15.9-alpine" in 3.025148695s (3.025157609s including waiting)
  Normal  Created    48s  kubelet             Created container
  Normal  Started    48s  kubelet             Started container
```

Only pods that have this toleration applied can be scheduled on nodes in `taintnp`. Any other pods are scheduled in the **nodepool1** node pool. If you create more node pools, you can use taints and tolerations to limit what pods can be scheduled on those node resources.

### Update a cluster node pool to add a node taint

Update a cluster to add a node taint using the [`az aksarc update`](/cli/azure/aksarc/nodepool#az-aksarc-nodepool-update) command and the `--node-taints` parameter to specify `sku=gpu:NoSchedule` for the taint. All existing taints are replaced with the new values. The old taints are deleted:

```azurecli
az aksarc update -g myResourceGroup --cluster-name myAKSCluster --name taintnp --node-taints "sku=gpu:NoSchedule"   
```

## Next steps

- [Use labels in an Azure Arc-enabled AKS cluster](cluster-labels.md).
