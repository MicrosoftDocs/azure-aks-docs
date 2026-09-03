---
title: Create a Kubernetes DaemonSet in AKS on Windows Server
description: Learn how to create a DaemonSet in Azure Kubernetes Service (AKS) on Windows Server.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 1/14/2022
ms.reviewer: EkeleAsonye
ms.custom: windows-server

# Intent: As an IT Pro, I want to learn how to create and utilize a DaemonSet to help manage my Kubernetes configuration and improve the overall cluster performance.
# Keyword: DaemonSet how-to worker nodes

---

# Create Kubernetes DaemonSets

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

This article describes how to create and use a Kubernetes *DaemonSet* in AKS on Windows Server to ensure that a copy of a pod is always available on every worker node in a cluster. You can use a DaemonSet to improve cluster performance by ensuring that an app runs on all the worker nodes, and to deploy pods that do maintenance and provide support services for nodes.

## Overview of DaemonSets

A DaemonSet is a Kubernetes object that ensures a copy of a pod that's defined in the configuration is always available on every worker node in a cluster. When a new node is added to a cluster, the DaemonSet automatically allocates the pod on that node.

Similarly, when a node is deleted, the pod that's running on the node is also deleted and isn't rescheduled on another node (for example, as happens with **ReplicaSets**). This enables you to overcome Kubernetes scheduling limitations and make sure a specific application is deployed on all nodes within the cluster.

DaemonSets can improve the overall cluster performance. For example, you can use them to deploy pods to perform maintenance tasks and support services to every node:

- Run a log collection daemon, such as `Fluentd` and `Logstash`.
- Run a node monitoring daemon, such as `Prometheus`.
- Run a cluster storage daemon, such as `glusterd` or `ceph`.

Although DaemonSets create a pod on every node by default, you can limit the number of acceptable nodes by predefining the node selector field in the YAML file. The DaemonSet controller only creates pods on nodes that match the node selector.

Usually, one DaemonSet deploys one daemon type across all nodes, but it's possible to have multiple DaemonSets control one daemon type by using different labels. A Kubernetes label specifies deployment rules based on the characteristics of individual nodes.

For more information about how to use DaemonSets, see [Kubernetes DaemonSets](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/).

## Create a DaemonSet

You describe a DaemonSet by using a YAML file, and then create it using the `kubectl create` or `kubectl apply` commands (for example, `kubectl create –f example-daemon.yaml`).

The following example describes the features of a DaemonSet configuration file using an nginx image:

```yaml
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
    app: nginx
  name: example-daemon
spec:
  template:
    metadata: null
    labels:
      app: nginx
containers: null
name: nginx
image: nginx
```

To view the current state of the DaemonSet, use the `kubectl describe` command (for example, `kubectl describe daemonset example-daemon`).

## Limit DaemonSet to specific nodes

By default, DaemonSets create pods on all the nodes in a cluster, but with node selectors, you can configure them to create pods only in specific nodes. If you want to limit a DaemonSet to specific nodes, use the `kubectl label` command.

## Update a DaemonSet

You can update a DaemonSet using the `kubectl edit ds<NAME>` command. However, it's recommended that you edit the original configuration file, and then use the `kubectl apply` command when it was initially created. After you apply an update, you can view the update status using the `kubectl rollout status ds <daemonset-name>` command.

## Delete a DaemonSet

To remove a DaemonSet, use the `kubectl delete` command (for example, `kubectl delete –f example-daemon.yaml -n monitoring`). You should be cautious when specifying the name of the DaemonSet file, as deleting a DaemonSet cleans up all the pods it deployed.

## Next steps

- [Create pods](create-pods.md)
- [Create a deployment](create-deployments.md)
- [Create a ReplicaSet](create-replicasets.md)
