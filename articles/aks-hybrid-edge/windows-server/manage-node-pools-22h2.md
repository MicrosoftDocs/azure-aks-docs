---
title: Manage node pools for a cluster in AKS on Windows Server
description: Learn how to manage multiple node pools in AKS on Windows Server.
ms.topic: how-to
ms.custom: windows-server
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak 
ms.reviewer: rbaziwane
ms.lastreviewed: 01/30/2024
---

# Manage node pools for a cluster in AKS on Windows Server

[!INCLUDE [aks-hybrid-applies-to-azure-stack-hci-windows-server-sku](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

> [!NOTE]
> For information about managing node pools in AKS on Azure Local, see [Manage node pools](../local/hyperconverged/manage-node-pools.md).

In AKS on Windows Server, nodes of the same configuration are grouped together into *node pools*. These node pools contain the underlying VMs that run your applications. This article shows you how to create and manage node pools for a cluster in AKS.

> [!NOTE]
> This feature enables greater control over how to create and manage multiple node pools. As a result, separate commands are required for create, update, and delete operations. Previously, cluster operations through [New-AksHciCluster](/azure/aks/aksarc/reference/ps/new-akshcicluster) or [Set-AksHciCluster](/azure/aks/aksarc/reference/ps/set-akshcicluster) were the only option to create or scale a cluster with one Windows node pool and one Linux node pool. This feature exposes a separate operation set for node pools that require the use of the node pool commands [New-AksHciNodePool](/azure/aks/aksarc/reference/ps/new-akshcinodepool), [Set-AksHciNodePool](/azure/aks/aksarc/reference/ps/set-akshcinodepool), [Get-AksHciNodePool](/azure/aks/aksarc/reference/ps/get-akshcinodepool), and [Remove-AksHciNodePool](/azure/aks/aksarc/reference/ps/remove-akshcinodepool) to execute operations on an individual node pool. 

## Before you begin

We recommend that you install version 1.1.6. If you already have the PowerShell module installed, run the following command to find the version:

```powershell
Get-Command -Module AksHci
```

If you need to update PowerShell, following the instructions in [Upgrade the AKS host](update-akshci-host-powershell.md).

## Create an AKS cluster

To get started, create an AKS cluster with a single node pool. The following example uses the [New-AksHciCluster](/azure/aks/aksarc/reference/ps/new-akshcicluster) command to create a new Kubernetes cluster with one Linux node pool named *linuxnodepool*, which has 1 node. **If you already have a cluster deployed with an older version of AKS, and you wish to continue using your old deployment, you can skip this step. You can still use the new set of node pool commands to add more node pool to your existing cluster.**

```powershell
New-AksHciCluster -name mycluster -nodePoolName linuxnodepool -nodeCount 1 -osType linux
```

> [!NOTE]
> The old parameter set for `New-AksHciCluster` is still supported.

## Add a node pool

The cluster named `mycluster`*`, created in the previous step, has a single node pool. You can add a second node pool to the existing cluster using the [New-AksHciNodePool](/azure/aks/aksarc/reference/ps/new-akshcinodepool) command. The following example creates a Windows node pool named **windowsnodepool** with one node. Make sure that the name of the node pool is not the same name as any existing node pool.

```powershell
New-AksHciNodePool -clusterName mycluster -name windowsnodepool -count 1 -osType Windows -osSku Windows2022
```

## Get configuration information of a node pool

To see the configuration information of your node pools, use the [Get-AksHciNodePool](/azure/aks/aksarc/reference/ps/get-akshcinodepool) command.

```powershell
Get-AksHciNodePool -clusterName mycluster
```

Example output:

```output
ClusterName  : mycluster
NodePoolName : linuxnodepool
Version      : v1.20.7
OsType       : Linux
NodeCount    : 1
VmSize       : Standard_K8S3_v1
Phase        : Deployed

ClusterName  : mycluster
NodePoolName : windowsnodepool
Version      : v1.20.7
OsType       : Windows
NodeCount    : 1
VmSize       : Standard_K8S3_v1
Phase        : Deployed
```

To see the configuration information of one specific node pool, use the `-name` parameter in [Get-AksHciNodePool](/azure/aks/aksarc/reference/ps/get-akshcinodepool).

```powershell
Get-AksHciNodePool -clusterName mycluster -name linuxnodepool
```

Example output:

```output
ClusterName  : mycluster
NodePoolName : linuxnodepool
Version      : v1.20.7
OsType       : Linux
NodeCount    : 1
VmSize       : Standard_K8S3_v1
Phase        : Deployed
```

```powershell
Get-AksHciNodePool -clusterName mycluster -name windowsnodepool
```

Example output:

```output
ClusterName  : mycluster
NodePoolName : windowsnodepool
Version      : v1.20.7
OsType       : Windows
NodeCount    : 1
VmSize       : Standard_K8S3_v1
Phase        : Deployed
```

> [!NOTE]
> If you use the new parameter sets in `New-AksHciCluster` to deploy a cluster and then run `Get-AksHciCluster` to get the cluster information, the fields `WindowsNodeCount` and `LinuxNodeCount` in the output will return `0`. To get the accurate number of nodes in each node pool, use the command `Get-AksHciNodePool` with the specified cluster name.

## Scale a node pool

You can scale the number of nodes up or down in a node pool.

To scale the number of nodes in a node pool, use the [Set-AksHciNodePool](/azure/aks/aksarc/reference/ps/set-akshcinodepool) command. The following example scales the number of nodes to 3 in a node pool named `linuxnodepool` in the `mycluster` cluster.

```powershell
Set-AksHciNodePool -clusterName mycluster -name linuxnodepool -count 3
```

## Scale control plane nodes

Management of control plane nodes hasn't changed. The way in which they are created, scaled, and removed remains the same. You will still deploy control plane nodes with the [New-AksHciCluster](/azure/aks/aksarc/reference/ps/new-akshcicluster) command with the parameters `controlPlaneNodeCount` and `controlPlaneVmSize` with the default values of 1 and Standard_A4_V2, respectively, if you don't provide any values.

You may need to scale the control plane nodes as the workload demand of your applications change. To scale the control plane nodes, use the [Set-AksHciCluster](/azure/aks/aksarc/reference/ps/set-akshcicluster) command. The following example scales the control plane nodes to 3 in `mycluster` cluster, which was created in the previous steps.

```powershell
Set-AksHciCluster -name mycluster -controlPlaneNodeCount 3
```

## Delete a node pool

If you need to delete a node pool, use the [Remove-AksHciNodePool](/azure/aks/aksarc/reference/ps/remove-akshcinodepool) command. The following example removes the node pool named `windowsnodepool` from the `mycluster` cluster.

```powershell
Remove-AksHciNodePool -clusterName mycluster -name windowsnodepool
```

## Specify a taint for a node pool

When creating a node pool, you can add taints to that node pool. When you add a taint, all nodes within that node pool also get that taint. For more information about taints and tolerations, see [Kubernetes Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/).

### Setting node pool taints

To create a node pool with a taint, use [New-AksHciNodePool](/azure/aks/aksarc/reference/ps/new-akshcinodepool). Specify the name `taintnp`, and use the `-taints` parameter to specify `sku=gpu:noSchedule` for the taint.

```powershell
New-AksHciNodePool -clusterName mycluster -name taintnp -count 1 -osType linux -taints sku=gpu:NoSchedule
```

> [!NOTE]
> A taint can only be set for node pools during node pool creation.

Run the following command to make sure the node pool was successfully deployed with the specified taint.

```powershell
Get-AksHciNodePool -clusterName mycluster -name taintnp
```

```output
Status       : {Phase, Details}
ClusterName  : mycluster
NodePoolName : taintnp
Version      : v1.20.7-kvapkg.1
OsType       : Linux
NodeCount    : 1
VmSize       : Standard_K8S3_v1
Phase        : Deployed
Taints       : {sku=gpu:NoSchedule}
```

In the previous step, you applied the *sku=gpu:NoSchedule* taint when you created your node pool. The following basic example YAML manifest uses a toleration to allow the Kubernetes scheduler to run an NGINX pod on a node in that node pool.

Create a file named `nginx-toleration.yaml`, and copy the information in the following text.

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

Then, schedule the pod using the following command.

```powershell
kubectl apply -f nginx-toleration.yaml
```

To verify that the pod was deployed, run the following command:

```powershell
kubectl describe pod mypod
```

```Output
[...]
Tolerations:     node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                 node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
                 sku=gpu:NoSchedule
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  32s   default-scheduler  Successfully assigned default/mypod to moc-lk4iodl7h2y
  Normal  Pulling    30s   kubelet            Pulling image "mcr.microsoft.com/oss/nginx/nginx:1.15.9-alpine"
  Normal  Pulled     26s   kubelet            Successfully pulled image "mcr.microsoft.com/oss/nginx/nginx:1.15.9-alpine" in 4.529046457s
  Normal  Created    26s   kubelet            Created container mypod
  ```

## Next steps

- [Manage nodepools (AKS on Azure Local)](../local/hyperconverged/manage-node-pools.md)
