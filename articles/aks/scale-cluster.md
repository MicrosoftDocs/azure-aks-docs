---
title: Manually Scale Nodes in an Azure Kubernetes Service (AKS) Cluster
description: Manually scale the node count in your Azure Kubernetes Service (AKS) cluster with Azure CLI or PowerShell to match demand and optimize capacity.
ms.topic: how-to
ms.custom: aks-scaling
ms.service: azure-kubernetes-service
ms.date: 09/09/2026
author: schaffererin
ms.author: schaffererin
ai-usage: ai-assisted
# Customer intent: As a Kubernetes administrator, I want to manually scale the nodes in my AKS cluster, so that I can optimize resource allocation based on my application's performance needs.
---

# Manually scale the node count in an Azure Kubernetes Service (AKS) cluster

If the resource needs of your applications change, your cluster performance may be impacted due to low capacity on CPU, memory, PID space, or disk sizes. To address these changes, you can manually scale your AKS cluster to run a different number of nodes. When you scale in, nodes are carefully [cordoned and drained][kubernetes-drain] to minimize disruption to running applications. When you scale out, AKS waits until nodes are marked **Ready** by the Kubernetes cluster before pods are scheduled on them.

This article describes how to manually increase or decrease the number of nodes in an AKS cluster.

> [!NOTE]
> This article applies to AKS Standard clusters. AKS Automatic clusters use [node autoprovisioning][aks-automatic] to manage node scaling.

## Before you begin

- Review the [AKS service quotas and limits][service-quotas] to verify your cluster can scale to your desired number of nodes.
- If the cluster autoscaler is enabled on the node pool, you can't manually change the node count. You can either [update the cluster autoscaler minimum and maximum values][cluster-autoscaler-update] or [disable the cluster autoscaler on the node pool][cluster-autoscaler-disable] before manually scaling it.
- Azure Linux 2.0 support ended on November 30, 2025. Beginning March 31, 2026, Azure Linux 2.0 node images were removed, and affected node pools can no longer scale. Migrate to [Azure Linux 3][azure-linux-3] before scaling an Azure Linux 2.0 node pool.
- Node pool names must meet the following requirements:

    | Node pool type | Name requirements |
    |--|--|
    | Linux | Between 1-12 lowercase alphanumeric characters. Must begin with a lowercase letter. |
    | Windows | Between 1-6 lowercase alphanumeric characters. Must begin with a lowercase letter. |

## Scale cluster nodes in AKS

> [!IMPORTANT]
> Removing nodes from a node pool by using the [`kubectl`][kubectl] command isn't supported. This action can create scaling problems with your AKS cluster.

### [Azure CLI](#tab/azure-cli)

1. Get the name, mode, and node count of your node pools by using the [`az aks show`][az-aks-show] command. The following example gets the node pool details for the cluster named *myAKSCluster* in the *myResourceGroup* resource group:

    ```azurecli-interactive
    az aks show --resource-group myResourceGroup --name myAKSCluster --query "agentPoolProfiles[].{Name:name,Mode:mode,Count:count}" --output table
    ```

    The following example output shows that *nodepool1* is a system node pool with three nodes:

    ```output
    Name       Mode    Count
    ---------  ------  -------
    nodepool1  System  3
    ```

1. Scale the cluster nodes by using the [`az aks scale`][az-aks-scale] command. The following example scales *nodepool1* in the cluster named *myAKSCluster* to two nodes:

    ```azurecli-interactive
    az aks scale --resource-group myResourceGroup --name myAKSCluster --node-count 2 --nodepool-name nodepool1 --query "agentPoolProfiles[?name=='nodepool1'].{Name:name,Mode:mode,Count:count}" --output table
    ```

    The following example output shows the system node pool successfully scaled to two nodes:

    ```output
    Name       Mode    Count
    ---------  ------  -------
    nodepool1  System  2
    ```

    System node pools must have at least two nodes. For production clusters, use at least three nodes in a system node pool. For more information, see [System and user node pools][system-node-pools].

### [Azure PowerShell](#tab/azure-powershell)

1. Get the name, mode, node count, and provisioning state of your node pools by using the [`Get-AzAksCluster`][get-azakscluster] command. The following example gets the node pool details for the cluster named _myAKSCluster_ in the _myResourceGroup_ resource group:

    ```azurepowershell-interactive
    Get-AzAksCluster -ResourceGroupName myResourceGroup -Name myAKSCluster |
      Select-Object -ExpandProperty AgentPoolProfiles |
      Select-Object Name, Mode, Count, ProvisioningState
    ```

    The following example output shows that _nodepool1_ is a system node pool with three nodes:

    ```output
    Name                   : nodepool1
    Mode                   : System
    Count                  : 3
    ProvisioningState      : Succeeded
    ```

1. Scale the cluster nodes by using the [Set-AzAksCluster][set-azakscluster] command. The `-NodeName` parameter accepts the node pool name. The following example scales _nodepool1_ in the cluster named _myAKSCluster_ to two nodes:

    ```azurepowershell-interactive
    Set-AzAksCluster -ResourceGroupName myResourceGroup -Name myAKSCluster -NodeCount 2 -NodeName nodepool1 |
      Select-Object -ExpandProperty AgentPoolProfiles |
      Where-Object Name -eq nodepool1 |
      Select-Object Name, Mode, Count, ProvisioningState
    ```

    The following example output shows the system node pool successfully scaled to two nodes:

    ```output
    Name                   : nodepool1
    Mode                   : System
    Count                  : 2
    ProvisioningState      : Succeeded
    ```

    System node pools must have at least two nodes. For production clusters, use at least three nodes in a system node pool. For more information, see [System and user node pools][system-node-pools].

---

## Scale user node pools to 0

Unlike system node pools that always require running nodes, user node pools can scale to 0. To learn more about the differences between system and user node pools, see [System and user node pools](use-system-pools.md).

> [!IMPORTANT]
> To scale a user node pool to 0 nodes, disable the cluster autoscaler. For more information, see [Disable the cluster autoscaler on a node pool](./cluster-autoscaler.md#disable-the-cluster-autoscaler-on-a-node-pool).

### [Azure CLI](#tab/azure-cli)

To scale a user node pool to 0, use [az aks nodepool scale][az-aks-nodepool-scale] instead of the `az aks scale` command used for general node scaling, and set `--node-count` to `0`.

```azurecli-interactive
az aks nodepool scale --name <your node pool name> --cluster-name myAKSCluster --resource-group myResourceGroup  --node-count 0
```

You can allow, but not force, autoscaling to zero nodes on autoscaled user node pools by setting the `--min-count` parameter of the [Cluster Autoscaler](cluster-autoscaler.md) to `0`.

### [Azure PowerShell](#tab/azure-powershell)

To scale a user node pool to 0, use [Update-AzAksNodePool][update-azaksnodepool] instead of the `Set-AzAksCluster` command used for general node scaling, and set `-NodeCount` to `0`.

```azurepowershell-interactive
Update-AzAksNodePool -Name <your node pool name> -ClusterName myAKSCluster -ResourceGroupName myResourceGroup -NodeCount 0
```

You can allow, but not force, autoscaling to zero nodes on autoscaled user node pools by setting the `-MinCount` parameter to `0`:

```azurepowershell-interactive
Update-AzAksNodePool -Name <your node pool name> -ClusterName myAKSCluster -ResourceGroupName myResourceGroup -EnableAutoScaling -MinCount 0 -MaxCount <maximum node count>
```

---

## Next steps

In this article, you manually scaled an AKS cluster to increase or decrease the number of nodes. You can also use the [cluster autoscaler][cluster-autoscaler] to automatically scale your cluster.

<!-- LINKS - external -->
[kubernetes-drain]: https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/
[kubectl]: https://kubernetes.io/docs/reference/kubectl/

<!-- LINKS - internal -->
[az-aks-show]: /cli/azure/aks#az-aks-show
[get-azakscluster]: /powershell/module/az.aks/get-azakscluster
[az-aks-scale]: /cli/azure/aks#az-aks-scale
[set-azakscluster]: /powershell/module/az.aks/set-azakscluster
[cluster-autoscaler]: cluster-autoscaler.md
[cluster-autoscaler-disable]: cluster-autoscaler.md#disable-the-cluster-autoscaler-on-a-node-pool
[cluster-autoscaler-update]: cluster-autoscaler.md#update-the-cluster-autoscaler-settings
[az-aks-nodepool-scale]: /cli/azure/aks/nodepool#az-aks-nodepool-scale
[update-azaksnodepool]: /powershell/module/az.aks/update-azaksnodepool
[service-quotas]: ./quotas-skus-regions.md#service-quotas-and-limits
[aks-automatic]: intro-aks-automatic.md#node-management-scaling-and-cluster-operations
[azure-linux-3]: /azure/azure-linux/how-to-enable-azure-linux-3
[system-node-pools]: use-system-pools.md#system-and-user-node-pools
