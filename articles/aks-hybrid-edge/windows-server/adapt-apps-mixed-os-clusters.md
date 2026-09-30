---
title: Adapt applications for use in mixed-OS Kubernetes clusters
description: Learn how to use node selectors or taints and tolerations on Azure Kubernetes Service to ensure applications in mixed OS Kubernetes clusters running on AKS on Windows Server are scheduled on the correct worker node operating system.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak
ms.lastreviewed: 1/14/2022
ms.reviewer: srikantsarwa
ms.custom: windows-server

# Intent: As an IT Pro, I want to learn how use node selectors, taints, and tolerations so I can adapt apps for use on mixed-OS Kubernetes clusters.
# Keyword: Node Selector mixed-OS clusters taints tolerations

---
# Adapt applications for use in mixed-OS Kubernetes clusters

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

AKS on Windows Server enables you to run Kubernetes clusters with both Linux and Windows nodes, but you must make small edits to your apps for use in these mixed-OS clusters. This how-to guide describes how to ensure your application gets scheduled on the right host OS using either node selectors or taints and tolerations.

This article assumes a basic understanding of Kubernetes concepts. For more information, see [Kubernetes core concepts for AKS on Windows Server](kubernetes-concepts.md).

## Node selectors

A *node selector* is a simple field in the pod specification YAML that constrains pods to only be scheduled onto healthy nodes matching the operating system. In your pod specification YAML, specify a `nodeSelector` value of Windows or Linux, as shown in the following examples:

```yaml
kubernetes.io/os = Windows
```

or,

```yaml
kubernetes.io/os = Linux
```

For more information about node selectors, see [node selectors](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/).

## Taints and tolerations

**Taints** and **tolerations** work together to ensure that pods aren't unintentionally scheduled on nodes. A node can be "tainted" to reject pods that don't explicitly tolerate its taint through a "toleration" in the pod specification YAML.

Windows OS nodes in AKS can be tainted when created with the [New-AksHciNodePool](/azure/aks/aksarc/reference/ps/new-akshcinodepool) or the [New-AksHciCluster](/azure/aks/aksarc/reference/ps/new-akshcicluster) commands. You can also use these commands to taint Linux OS nodes. The following example taints Windows nodes.

### Apply taint to new cluster

If you also create a new cluster, run the following command to create a Windows node pool with a taint. If you have an existing cluster to which you want to add a node pool with a taint, see the next example, which uses the `New-AksHciNodePool` command.

```powershell
New-AksHciCluster -name mycluster -nodePoolName taintnp -nodeCount 1 -osType Windows -osSku Windows2022 -taints sku=Windows:NoSchedule
```

### Add tainted node pool to existing cluster

To add a tainted node pool to an existing cluster, run the following command:

```powershell
New-AksHciNodePool -clusterName <cluster-name> -nodePoolNAme taintnp -count 1 -osType Windows -osSku Windows2022 -taints sku=Windows:NoSchedule
```

To check that the node pool was successfully deployed with the taint, run the following command:

```powershell
Get-AksHciNodePool -clusterName <cluster-name> -name taintnp
```

Example output:

```output
Status       : {Phase, Details}
ClusterName  : mycluster
NodePoolName : taintnp
Version      : v1.20.7-kvapkg.1
OsType       : Windows
NodeCount    : 0
VmSize       : Standard_K8S3_v1
Phase        : Deployed
Taints       : {sku=Windows:NoSchedule}
```

### Specify toleration for pod

You can specify a toleration for a pod in the pod specification YAML. The following toleration "matches" the taint created by the `kubectl` taint line shown in the previous example. The result is that a pod with the toleration can schedule onto the tainted nodes.

```yaml
tolerations:
- key: node.kubernetes.io/os
  operator: Equal
  value: Windows
  effect: NoSchedule
```

The steps in this section work well if you're in control of the pod spec that you're deploying. However, in some cases, users have a pre-existing large number of deployments for Linux containers, as well as an ecosystem of common configurations, such as community [Helm charts](https://helm.sh/docs/intro/using_helm/#helm-search-finding-charts). You won't have access to the pod spec unless you want to download and edit the chart.

If you deploy these Helm charts to a mixed cluster environment with both Linux and Windows worker nodes, your application pods fail with the error "ImagePullBackOff". For example:

```powershell
kubectl get pods
```

```output
NAMESPACE              NAME                                                    READY   STATUS              RESTARTS   AGE
default                nginx-deployment-558fc78868-795dp                       0/1     ImagePullBackOff    0          6m24s
default                nginx-deployment-6b474476c4-gpb77                       0/1     ImagePullBackOff    0          11m
```

In this instance, you can use [taints](https://cloud.google.com/kubernetes-engine/docs/how-to/node-taints) to help with this. Windows Server nodes can be tainted with the key-value pair `node.kubernetes.io/os=windows:NoSchedule`.

For more information about taints and tolerations, see [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/).

## Next steps

In this how-to guide, you learned how to add node selectors or taints and tolerations to your Kubernetes clusters using kubectl. Next, you can:

- [Deploy a Linux application on a Kubernetes cluster](deploy-linux-application.md)
- [Deploy a Windows Server application on a Kubernetes cluster](deploy-windows-application.md)
