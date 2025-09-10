---
title: Resize Node Pools in Azure Kubernetes Service (AKS)
description: Learn how to resize node pools for a cluster in Azure Kubernetes Service (AKS) by cordoning and draining.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 08/28/2025
author: schaffererin
ms.author: schaffererin
ms.subservice: aks-nodes
# Customer intent: As a Kubernetes cluster operator, I want to resize my node pools by cordoning and draining, so that I can efficiently manage resources and support increasing workloads.
---

# Resize node pools in Azure Kubernetes Service (AKS)

You might want to change the size of your virtual machines (VMs) to accommodate an increasing number of deployments or to run a larger workload. Resizing AKS instances directly isn't supported when using [Virtual Machine Scale Sets][vmss-docs] in AKS, as outlined in the [support policies for AKS][aks-support-policies]:

> AKS agent nodes appear in the Azure portal as regular Azure IaaS resources. But these virtual machines are deployed into a custom Azure resource group (usually prefixed with MC_*). You can't make direct customizations to these nodes using the IaaS APIs or resources. Any custom changes that aren't done via the AKS API won't persist through an upgrade, scale, update, or reboot.

In this article, you learn the recommended method to resize a node pool by creating a new node pool with the desired SKU size, cordoning and draining the existing nodes, and then removing the existing node pool.

> [!IMPORTANT]
> This method is specific to [Virtual Machine Scale Sets][vmss-docs]-based AKS clusters. When using Virtual Machines-based node pools, you can easily update the VM sizes in an existing node pool using a single Azure CLI command and have multiple VM sizes in the same node pool. For more information, see the [Virtual Machines node pools documentation][vm-node-pools].

## Example scenario

To illustrate the process, we use the following example scenario throughout this article:

You want to resize an existing VMSS node pool, `nodepool1`, from SKU size `Standard_DS2_v2` to `Standard_DS3_v2`. To accomplish this, you need to create a new node pool using `Standard_DS3_v2`, move workloads from `nodepool1` to the new node pool `mynodepool`, and remove `nodepool1`.

The `kubectl get nodes` and `kubectl get pods -o wide -A` commands show the current state of the cluster, nodes, and pods before starting the resize process:

```bash
kubectl get nodes

NAME                                STATUS   ROLES   AGE   VERSION
aks-nodepool1-12345678-vmss000000   Ready    agent   10d   v1.21.9
aks-nodepool1-12345678-vmss000001   Ready    agent   10d   v1.21.9
aks-nodepool1-12345678-vmss000002   Ready    agent   10d   v1.21.9
```

```bash
kubectl get pods -o wide -A

NAMESPACE     NAME                                  READY   STATUS    RESTARTS   AGE     IP           NODE                                NOMINATED NODE   READINESS GATES
default       sampleapp2-12a3b456cd-789ef           1/1     Running   0          93m     10.244.1.6   aks-nodepool1-12345678-vmss000002   <none>           <none>
default       sampleapp2-98a7b6c54d-efghi           1/1     Running   0          94m     10.244.1.5   aks-nodepool1-12345678-vmss000002   <none>           <none>
kube-system   azure-ip-masq-agent-1a23b             1/1     Running   0          10d     10.240.0.6   aks-nodepool1-12345678-vmss000002   <none>           <none>
kube-system   azure-ip-masq-agent-4a5b6             1/1     Running   0          10d     10.240.0.4   aks-nodepool1-12345678-vmss000000   <none>           <none>
kube-system   azure-ip-masq-agent-ab7cd             1/1     Running   0          10d     10.240.0.5   aks-nodepool1-12345678-vmss000001   <none>           <none>
kube-system   coredns-987654f32-edcba               1/1     Running   0          10d     10.244.0.2   aks-nodepool1-12345678-vmss000000   <none>           <none>
kube-system   coredns-123456a78-bcdef               1/1     Running   0          10d     10.244.2.3   aks-nodepool1-12345678-vmss000001   <none>           <none>
kube-system   coredns-autoscaler-1a23bc456d-efghi   1/1     Running   0          10d     10.244.2.4   aks-nodepool1-12345678-vmss000001   <none>           <none>
kube-system   csi-azuredisk-node-1abcd              3/3     Running   0          10d     10.240.0.4   aks-nodepool1-12345678-vmss000000   <none>           <none>
kube-system   csi-azuredisk-node-abcde              3/3     Running   0          10d     10.240.0.5   aks-nodepool1-12345678-vmss000001   <none>           <none>
kube-system   csi-azuredisk-node-dcba1              3/3     Running   0          10d     10.240.0.6   aks-nodepool1-12345678-vmss000002   <none>           <none>
kube-system   csi-azurefile-node-1abc2              3/3     Running   0          3d10h   10.240.0.6   aks-nodepool1-12345678-vmss000002   <none>           <none>
kube-system   csi-azurefile-node-dc1ba              3/3     Running   0          3d10h   10.240.0.5   aks-nodepool1-12345678-vmss000001   <none>           <none>
kube-system   csi-azurefile-node-a12bc              3/3     Running   0          3d10h   10.240.0.4   aks-nodepool1-12345678-vmss000000   <none>           <none>
kube-system   konnectivity-agent-1ab23c45de-fghij   1/1     Running   0          10d     10.240.0.6   aks-nodepool1-12345678-vmss000002   <none>           <none>
kube-system   konnectivity-agent-1ab23c45de-klmno   1/1     Running   0          10d     10.240.0.4   aks-nodepool1-12345678-vmss000000   <none>           <none>
kube-system   kube-proxy-1abc2                      1/1     Running   0          10d     10.240.0.4   aks-nodepool1-12345678-vmss000000   <none>           <none>
kube-system   kube-proxy-d3efg                      1/1     Running   0          10d     10.240.0.6   aks-nodepool1-12345678-vmss000002   <none>           <none>
kube-system   kube-proxy-hij45                      1/1     Running   0          10d     10.240.0.5   aks-nodepool1-12345678-vmss000001   <none>           <none>
kube-system   metrics-server-123a45bcd6-e78fg       1/1     Running   1          3d10h   10.244.1.3   aks-nodepool1-12345678-vmss000002   <none>           <none>
```

## Create a new node pool with the desired SKU

### [Azure CLI](#tab/azure-cli)

When resizing, be sure to consider all workload requirements, such as availability zones, and configure your VMSS node pool accordingly. You might need to modify the following command to best fit your needs. For a full list of the configuration options, see the [`az aks nodepool add`][az-aks-nodepool-add] reference page.

Use the [`az aks nodepool add`][az-aks-nodepool-add] command to create a new node pool called `mynodepool` with three nodes using the `Standard_DS3_v2` VM SKU:

```azurecli-interactive
az aks nodepool add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name mynodepool \
    --node-count 3 \
    --node-vm-size Standard_DS3_v2 \
    --mode System \
    --no-wait
```

> [!NOTE]
> Every AKS cluster must contain at least one system node pool with at least one node.In this example, we are using a `--mode` of `System` to add a system node pool to replace the system node pool we want to resize. A node pool's mode can be [updated at any time][update-node-pool-mode]. You can also add a user node pool by setting `--mode` to `User`. 

After a few minutes, the new node pool is created:

:::image type="content" source="./media/resize-node-pool/node-pool-both.png" alt-text="Screenshot of the Azure portal page for the cluster, navigated to Settings > Node pools. Two node pools, named node pool 1 and my node pool are shown.":::

```bash
kubectl get nodes

NAME                                 STATUS   ROLES   AGE   VERSION
aks-mynodepool-20823458-vmss000000   Ready    agent   23m   v1.21.9
aks-mynodepool-20823458-vmss000001   Ready    agent   23m   v1.21.9
aks-mynodepool-20823458-vmss000002   Ready    agent   23m   v1.21.9
aks-nodepool1-31721111-vmss000000    Ready    agent   10d   v1.21.9
aks-nodepool1-31721111-vmss000001    Ready    agent   10d   v1.21.9
aks-nodepool1-31721111-vmss000002    Ready    agent   10d   v1.21.9
```

### [Azure PowerShell](#tab/azure-powershell)

When resizing, be sure to consider all workload requirements, such as availability zones, and configure your VMSS node pool accordingly. You might need to modify the following command to best fit your needs. For a full list of the configuration options, see the [`New-AzAksNodePool`][new-azaksnodepool] reference page.

Use the [`New-AzAksNodePool`][new-azaksnodepool] cmdlet to create a new node pool called `mynodepool` with three nodes using the `Standard_DS3_v2` VM SKU:

```azurepowershell-interactive
$params = @{
    ResourceGroupName = 'myResourceGroup'
    ClusterName       = 'myAKSCluster'
    Name              = 'mynodepool'
    Count             = 3
    VMSize            = 'Standard_DS3_v2'
}
New-AzAksNodePool @params
```

After a few minutes, the new node pool is created:

:::image type="content" source="./media/resize-node-pool/node-pool-both.png" alt-text="Screenshot of the Azure portal page for the cluster, navigated to Settings > Node pools. Two node pools, named node pool 1 and my node pool are shown.":::

```bash
kubectl get nodes

NAME                                 STATUS   ROLES   AGE   VERSION
aks-mynodepool-20823458-vmss000000   Ready    agent   23m   v1.21.9
aks-mynodepool-20823458-vmss000001   Ready    agent   23m   v1.21.9
aks-mynodepool-20823458-vmss000002   Ready    agent   23m   v1.21.9
aks-nodepool1-31721111-vmss000000    Ready    agent   10d   v1.21.9
aks-nodepool1-31721111-vmss000001    Ready    agent   10d   v1.21.9
aks-nodepool1-31721111-vmss000002    Ready    agent   10d   v1.21.9
```

> [!NOTE]
> Every AKS cluster must contain at least one system node pool with at least one node. In this example, we are using a `--mode` of `System` to add a system node pool to replace the system node pool we want to resize. A node pool's mode can be [updated at any time][update-node-pool-mode]. You can also add a user node pool by setting `--mode` to `User`. 

```azurepowershell-interactive
$myAKSCluster = Get-AzAksCluster -ResourceGroupName myResourceGroup -Name myAKSCluster
($myAKSCluster.AgentPoolProfiles | Where-Object Name -eq 'mynodepool').Mode = 'System'
$myAKSCluster | Set-AzAksCluster
```

---

## Cordon the existing nodes

Cordoning marks specified nodes as unschedulable and prevents any more pods from being added to the nodes.

Get the names of the nodes you want to cordon using the `kubectl get nodes` command. Your output should look similar to the following example:

```bash
NAME                                STATUS   ROLES   AGE     VERSION
aks-nodepool1-31721111-vmss000000   Ready    agent   7d21h   v1.21.9
aks-nodepool1-31721111-vmss000001   Ready    agent   7d21h   v1.21.9
aks-nodepool1-31721111-vmss000002   Ready    agent   7d21h   v1.21.9
```

Next, using `kubectl cordon <node-names>`, specify the desired nodes in a space-separated list:

```bash
kubectl cordon aks-nodepool1-31721111-vmss000000 aks-nodepool1-31721111-vmss000001 aks-nodepool1-31721111-vmss000002
```

```output
node/aks-nodepool1-31721111-vmss000000 cordoned
node/aks-nodepool1-31721111-vmss000001 cordoned
node/aks-nodepool1-31721111-vmss000002 cordoned
```

## Drain the existing nodes

> [!IMPORTANT]
> To successfully drain nodes and evict running pods, ensure that any PodDisruptionBudgets (PDBs) allow for at least one pod replica to be moved at a time. Otherwise, the drain/evict operation fails. To check this, you can run `kubectl get pdb -A` and verify `ALLOWED DISRUPTIONS` is at least `1` or higher.

When you drain nodes, the pods running on them are evicted and recreated on the other schedulable nodes.

To drain nodes, use `kubectl drain <node-names> --ignore-daemonsets --delete-emptydir-data`, again using a space-separated list of node names:

> [!IMPORTANT]
> Using `--delete-emptydir-data` is required to evict the AKS-created `coredns` and `metrics-server` pods. If this flag isn't used, an error is expected. For more information, see the [documentation on emptydir][empty-dir].

```bash
kubectl drain aks-nodepool1-31721111-vmss000000 aks-nodepool1-31721111-vmss000001 aks-nodepool1-31721111-vmss000002 --ignore-daemonsets --delete-emptydir-data
```

After the drain operation finishes, all pods other than the pods controlled by daemon sets are running on the new node pool:

```bash
kubectl get pods -o wide -A

NAMESPACE     NAME                                  READY   STATUS    RESTARTS   AGE     IP           NODE                                 NOMINATED NODE   READINESS GATES
default       sampleapp2-74b4b974ff-676sz           1/1     Running   0          15m     10.244.4.5   aks-mynodepool-20823458-vmss000002   <none>           <none>
default       sampleapp2-76b6c4c59b-rhmzq           1/1     Running   0          16m     10.244.4.3   aks-mynodepool-20823458-vmss000002   <none>           <none>
kube-system   azure-ip-masq-agent-4n66k             1/1     Running   0          10d     10.240.0.6   aks-nodepool1-31721111-vmss000002    <none>           <none>
kube-system   azure-ip-masq-agent-9p4c8             1/1     Running   0          10d     10.240.0.4   aks-nodepool1-31721111-vmss000000    <none>           <none>
kube-system   azure-ip-masq-agent-nb7mx             1/1     Running   0          10d     10.240.0.5   aks-nodepool1-31721111-vmss000001    <none>           <none>
kube-system   azure-ip-masq-agent-sxn96             1/1     Running   0          49m     10.240.0.9   aks-mynodepool-20823458-vmss000002   <none>           <none>
kube-system   azure-ip-masq-agent-tsq98             1/1     Running   0          49m     10.240.0.8   aks-mynodepool-20823458-vmss000001   <none>           <none>
kube-system   azure-ip-masq-agent-xzrdl             1/1     Running   0          49m     10.240.0.7   aks-mynodepool-20823458-vmss000000   <none>           <none>
kube-system   coredns-845757d86-d2pkc               1/1     Running   0          17m     10.244.3.2   aks-mynodepool-20823458-vmss000000   <none>           <none>
kube-system   coredns-845757d86-f8g9s               1/1     Running   0          17m     10.244.5.2   aks-mynodepool-20823458-vmss000001   <none>           <none>
kube-system   coredns-autoscaler-5f85dc856b-f8xh2   1/1     Running   0          17m     10.244.4.2   aks-mynodepool-20823458-vmss000002   <none>           <none>
kube-system   csi-azuredisk-node-7md2w              3/3     Running   0          49m     10.240.0.7   aks-mynodepool-20823458-vmss000000   <none>           <none>
kube-system   csi-azuredisk-node-9nfzt              3/3     Running   0          10d     10.240.0.4   aks-nodepool1-31721111-vmss000000    <none>           <none>
kube-system   csi-azuredisk-node-bblsb              3/3     Running   0          10d     10.240.0.5   aks-nodepool1-31721111-vmss000001    <none>           <none>
kube-system   csi-azuredisk-node-lcmtz              3/3     Running   0          49m     10.240.0.9   aks-mynodepool-20823458-vmss000002   <none>           <none>
kube-system   csi-azuredisk-node-mmncr              3/3     Running   0          49m     10.240.0.8   aks-mynodepool-20823458-vmss000001   <none>           <none>
kube-system   csi-azuredisk-node-tjhj4              3/3     Running   0          10d     10.240.0.6   aks-nodepool1-31721111-vmss000002    <none>           <none>
kube-system   csi-azurefile-node-29w6z              3/3     Running   0          49m     10.240.0.9   aks-mynodepool-20823458-vmss000002   <none>           <none>
kube-system   csi-azurefile-node-4nrx7              3/3     Running   0          49m     10.240.0.7   aks-mynodepool-20823458-vmss000000   <none>           <none>
kube-system   csi-azurefile-node-9pcr8              3/3     Running   0          3d11h   10.240.0.6   aks-nodepool1-31721111-vmss000002    <none>           <none>
kube-system   csi-azurefile-node-bh2pc              3/3     Running   0          3d11h   10.240.0.5   aks-nodepool1-31721111-vmss000001    <none>           <none>
kube-system   csi-azurefile-node-gqqnv              3/3     Running   0          49m     10.240.0.8   aks-mynodepool-20823458-vmss000001   <none>           <none>
kube-system   csi-azurefile-node-h75gq              3/3     Running   0          3d11h   10.240.0.4   aks-nodepool1-31721111-vmss000000    <none>           <none>
kube-system   konnectivity-agent-6cd55c69cf-2bbp5   1/1     Running   0          17m     10.240.0.7   aks-mynodepool-20823458-vmss000000   <none>           <none>
kube-system   konnectivity-agent-6cd55c69cf-7xzxj   1/1     Running   0          16m     10.240.0.8   aks-mynodepool-20823458-vmss000001   <none>           <none>
kube-system   kube-proxy-4wzx7                      1/1     Running   0          10d     10.240.0.4   aks-nodepool1-31721111-vmss000000    <none>           <none>
kube-system   kube-proxy-7h8r5                      1/1     Running   0          49m     10.240.0.7   aks-mynodepool-20823458-vmss000000   <none>           <none>
kube-system   kube-proxy-g5tvr                      1/1     Running   0          10d     10.240.0.6   aks-nodepool1-31721111-vmss000002    <none>           <none>
kube-system   kube-proxy-mrv54                      1/1     Running   0          10d     10.240.0.5   aks-nodepool1-31721111-vmss000001    <none>           <none>
kube-system   kube-proxy-nqmnj                      1/1     Running   0          49m     10.240.0.9   aks-mynodepool-20823458-vmss000002   <none>           <none>
kube-system   kube-proxy-zn77s                      1/1     Running   0          49m     10.240.0.8   aks-mynodepool-20823458-vmss000001   <none>           <none>
kube-system   metrics-server-774f99dbf4-2x6x8       1/1     Running   0          16m     10.244.4.4   aks-mynodepool-20823458-vmss000002   <none>           <none>
```

### Troubleshooting

You might see an error similar to the following:
> Error when evicting pods/[podname] -n [namespace] (will retry after 5s): Cannot evict pod as it would violate the pod's disruption budget.

By default, your cluster has AKS-managed pod disruption budgets (such as `coredns-pdb` or `konnectivity-agent`) with a `MinAvailable` of 1. For example, if there are two `coredns` pods running, only one can be disrupted at a time. While one of them is getting recreated and is unavailable, the other `coredns` pod cannot be evicted due to the pod disruption budget. This issue resolves itself after the initial `coredns` pod is scheduled and running, allowing the second pod to be properly evicted and recreated.

> [!TIP]
> Consider draining nodes one-by-one for a smoother eviction experience and to avoid throttling. For more information, see:
>
> * [Plan for availability using a pod disruption budget][pod-disruption-budget]
> * [Specifying a Disruption Budget for your Application][specify-disruption-budget]
> * [Disruptions][disruptions]

## Remove the existing node pool

### [Azure CLI](#tab/azure-cli)

To delete the existing node pool, use the Azure portal or the [`az aks nodepool delete`][az-aks-nodepool-delete] command:

```azurecli-interactive
az aks nodepool delete \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name nodepool1
```

### [Azure PowerShell](#tab/azure-powershell)

To delete the existing node pool, use the Azure portal or the [`Remove-AzAksNodePool`][remove-azaksnodepool] cmdlet:

> [!IMPORTANT]
> When you delete a node pool, AKS doesn't perform cordon and drain. To minimize the disruption of rescheduling pods currently running on the node pool you are going to delete, perform a cordon and drain on all nodes in the node pool before deleting.

```azurepowershell-interactive
$params = @{
    ResourceGroupName = 'myResourceGroup'
    ClusterName       = 'myAKSCluster'
    Name              = 'nodepool1'
    Force             = $true
}
Remove-AzAksNodePool @params
```

---

After completion, the final result is the AKS cluster having a single, new node pool with the new, desired SKU size and all the applications and pods properly running:

:::image type="content" source="./media/resize-node-pool/node-pool-ds3.png" alt-text="Screenshot of the Azure portal page for the cluster, navigated to Settings > Node pools. One node pool, named my node pool, is shown.":::

```bash
kubectl get nodes

NAME                                 STATUS   ROLES   AGE   VERSION
aks-mynodepool-20823458-vmss000000   Ready    agent   63m   v1.21.9
aks-mynodepool-20823458-vmss000001   Ready    agent   63m   v1.21.9
aks-mynodepool-20823458-vmss000002   Ready    agent   63m   v1.21.9
```

## Next steps

After resizing a node pool by cordoning and draining, learn more about [using multiple node pools][use-multiple-node-pools].

<!-- LINKS -->
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az_aks_nodepool_add
[new-azaksnodepool]: /powershell/module/az.aks/new-azaksnodepool
[az-aks-nodepool-delete]: /cli/azure/aks/nodepool#az_aks_nodepool_delete
[remove-azaksnodepool]: /powershell/module/az.aks/remove-azaksnodepool
[vmss-docs]: /azure/virtual-machine-scale-sets/overview
[vm-node-pools]: ./virtual-machines-node-pools.md
[update-vm-pool-size]: ./virtual-machines-node-pools.md#update-an-existing-manual-scale-profile
[aks-support-policies]: support-policies.md#user-customization-of-agent-nodes
[update-node-pool-mode]: use-system-pools.md#update-existing-cluster-system-and-user-node-pools
[pod-disruption-budget]: operator-best-practices-scheduler.md#plan-for-availability-using-pod-disruption-budgets
[empty-dir]: https://kubernetes.io/docs/concepts/storage/volumes/#emptydir
[specify-disruption-budget]: https://kubernetes.io/docs/tasks/run-application/configure-pdb/
[disruptions]: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/
[use-multiple-node-pools]: create-node-pools.md

