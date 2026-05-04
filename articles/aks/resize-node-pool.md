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

## Resize a VMSS node pool in place (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

You can now resize the VM size (SKU) of an existing VMSS-based node pool in a single command using `az aks nodepool update --node-vm-size <new-size>`. When you trigger this update, the AKS resource provider performs a rolling upgrade by:

1. Surging new nodes with the target VM size.
2. Cordoning and draining the old nodes.
3. Deleting the old nodes.

This avoids the manual create/cordon/drain/delete workflow described in the rest of this article.

### How the resize rollout works

The resize rollout uses the same rolling upgrade engine as a [node image upgrade][upgrade-node-image] and a [Kubernetes version upgrade][upgrade-aks-node-pools-rolling], so it honors the following upgrade-related settings already configured on the node pool. In particular, the resize respects:

* [**Max surge** (`--max-surge`)][max-surge]: Controls how many extra nodes with the target VM size are added during the rollout. A higher value resizes the pool faster but consumes more compute and IP quota; a lower value is slower but less disruptive. The AKS default is `1`, and `33%` is recommended for production node pools.
* [**Node drain timeout** (`--drain-timeout`)][drain-timeout]: How long AKS waits for pod eviction on each old node before forcefully deleting it. The default is 30 minutes. Combine this with appropriate [PodDisruptionBudgets][pod-disruption-budget] so workloads can drain safely.
* [**Node soak duration** (`--node-soak-duration`)][node-soak-duration]: How long AKS waits after a new node becomes Ready before moving on to the next batch. Useful for letting workloads stabilize on the new VM size before continuing the rollout.

Because resize reuses the upgrade pipeline, the same prerequisites apply: ensure your subscription has enough target VM size replacement capacity and available subnet IPs for surge nodes, and that your PodDisruptionBudgets allow at least one replica to be evicted at a time, otherwise resize can be blocked during drain. For end-to-end recommendations, see [Best practices for AKS node pool upgrades][aks-production-upgrade-strategies].

### Prerequisites

* AKS API version `2026-01-02-preview` or later.
* The latest version of the [aks-preview Azure CLI extension][aks-preview-extension].

### Resize the node pool

Use the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--node-vm-size` parameter to change the VM size of an existing VMSS-based node pool:

```azurecli-interactive
az aks nodepool update \
    --resource-group MyResourceGroup \
    --cluster-name MyManagedCluster \
    --name nodepool1 \
    --node-vm-size Standard_D4s_v3
```

### Validation and unsupported combinations

The AKS resource provider validates the resize request and blocks incompatible VM size changes. The following changes are **not supported** as part of an in-place VMSS resize:

* Changing the **disk controller type** (for example, SCSI to NVMe).
* Changing the **CPU architecture** (for example, x64 to ARM64).
* Changing **confidential computing** support (for example, enabling or disabling SNP).
* Changing the **hypervisor generation** (for example, V1 to V2).
* Combining the resize with a **Kubernetes version upgrade** or a **node count change** in the same operation.

If your target VM size requires any of the changes above, use the manual cordon-and-drain workflow described in the following sections instead.

> [!NOTE]
> In-place resize requires surge capacity to provision new nodes with the target VM size before draining the old ones. If the node pool is configured with `--max-surge 0` (that is, `--max-unavailable` is in effect), the resize request is rejected with a `400 Bad Request`. To proceed, set `--max-surge` to at least `1` using
>```azurecli-interactive
> az aks nodepool update \
>     --resource-group MyResourceGroup \
>     --cluster-name MyManagedCluster \
>     --name nodepool1 \
>     --node-vm-size Standard_D4s_v3 \
>     --max-surge 33%
>```
> and optionally restore your original `--max-surge` and `--max-unavailable` values after the resize completes.

## Create a new node pool with the desired SKU

> [!NOTE]
> Every AKS cluster must contain at least one system node pool with at least one node. In this example, we use a `--mode` of `System` to add a system node pool to replace the system node pool we want to resize. You can [update the mode of a node pool][update-node-pool-mode] at any time. You can also add a user node pool by setting `--mode` to `User`.

### [Azure CLI](#tab/azure-cli)

When resizing, make sure you consider all workload requirements, such as availability zones, and configure your VMSS node pool accordingly. You might need to modify the following command to best fit your needs. For a full list of the configuration options, see the [`az aks nodepool add`][az-aks-nodepool-add] reference page.

1. Create a new node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command. In this example, we create a new node pool, `mynodepool`, with three nodes and the `Standard_DS3_v2` VM SKU to replace an existing node pool, `nodepool1`, that has the `Standard_DS2_v2` VM SKU.

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

    It takes a few minutes for the new node pool to be created.

2. Get the status of the new node pool using the `kubectl get nodes` command.

    ```bash
    kubectl get nodes
    ```

    Your output should resemble the following example output, showing both the new node pool `mynodepool` and the existing node pool `nodepool1`:

    ```output
    NAME                                 STATUS   ROLES   AGE   VERSION
    aks-mynodepool-98765432-vmss000000   Ready    agent   23m   v1.21.9
    aks-mynodepool-98765432-vmss000001   Ready    agent   23m   v1.21.9
    aks-mynodepool-98765432-vmss000002   Ready    agent   23m   v1.21.9
    aks-nodepool1-12345678-vmss000000    Ready    agent   10d   v1.21.9
    aks-nodepool1-12345678-vmss000001    Ready    agent   10d   v1.21.9
    aks-nodepool1-12345678-vmss000002    Ready    agent   10d   v1.21.9
    ```

### [Azure PowerShell](#tab/azure-powershell)

When resizing, make sure you consider all workload requirements, such as availability zones, and configure your VMSS node pool accordingly. You might need to modify the following command to best fit your needs. For a full list of the configuration options, see the [`New-AzAksNodePool`][new-azaksnodepool] reference page.

1. Create a new node pool using the [`New-AzAksNodePool`][new-azaksnodepool] cmdlet. In this example, we create a new node pool, `mynodepool`, with three nodes and the `Standard_DS3_v2` VM SKU to replace an existing node pool, `nodepool1`, that has the `Standard_DS2_v2` VM SKU.

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

    It takes a few minutes for the new node pool to be created.

2. Get the status of the new node pool using the `kubectl get nodes` command.

    ```bash
    kubectl get nodes
    ```

    Your output should resemble the following example output, showing both the new node pool `mynodepool` and the existing node pool `nodepool1`:

    ```output
    NAME                                 STATUS   ROLES   AGE   VERSION
    aks-mynodepool-98765432-vmss000000   Ready    agent   23m   v1.21.9
    aks-mynodepool-98765432-vmss000001   Ready    agent   23m   v1.21.9
    aks-mynodepool-98765432-vmss000002   Ready    agent   23m   v1.21.9
    aks-nodepool1-12345678-vmss000000    Ready    agent   10d   v1.21.9
    aks-nodepool1-12345678-vmss000001    Ready    agent   10d   v1.21.9
    aks-nodepool1-12345678-vmss000002    Ready    agent   10d   v1.21.9
    ```

---

## Cordon the existing nodes

Cordoning marks specified nodes as unschedulable and prevents any more pods from being added to the nodes.

1. Get the names of the nodes you want to cordon using the `kubectl get nodes` command.

    ```bash
    kubectl get nodes
    ```

    Your output should resemble the following example output, showing the nodes in the existing node pool `nodepool1` that you want to cordon:

    ```output
    NAME                                STATUS   ROLES   AGE     VERSION
    aks-nodepool1-12345678-vmss000000   Ready    agent   7d21h   v1.21.9
    aks-nodepool1-12345678-vmss000001   Ready    agent   7d21h   v1.21.9
    aks-nodepool1-12345678-vmss000002   Ready    agent   7d21h   v1.21.9
    ```

2. Cordon the existing nodes using the `kubectl cordon` command, specifying the desired nodes in a space-separated list. For example:

    ```bash
    kubectl cordon aks-nodepool1-12345678-vmss000000 aks-nodepool1-12345678-vmss000001 aks-nodepool1-12345678-vmss000002
    ```

    Your output should resemble the following example output, showing that the nodes are cordoned:

    ```output
    node/aks-nodepool1-12345678-vmss000000 cordoned
    node/aks-nodepool1-12345678-vmss000001 cordoned
    node/aks-nodepool1-12345678-vmss000002 cordoned
    ```

## Drain the existing nodes

> [!IMPORTANT]
> To successfully drain nodes and evict running pods, ensure that any PodDisruptionBudgets (PDBs) allow for at least one pod replica to be moved at a time. Otherwise, the drain/evict operation fails. To check this, you can run `kubectl get pdb -A` and verify `ALLOWED DISRUPTIONS` is at least `1` or higher.

When you drain nodes, the pods running on them are evicted and recreated on the other schedulable nodes.

1. Drain the existing nodes using the `kubectl drain` command with the `--ignore-daemonsets` and `--delete-emptydir-data` flags, specifying the desired nodes in a space-separated list. For example:

    > [!IMPORTANT]
    > Using `--delete-emptydir-data` is required to evict the AKS-created `coredns` and `metrics-server` pods. If you don't use this flag, you get an error. For more information, see the [documentation on emptydir][empty-dir].

    ```bash
    kubectl drain aks-nodepool1-12345678-vmss000000 aks-nodepool1-12345678-vmss000001 aks-nodepool1-12345678-vmss000002 --ignore-daemonsets --delete-emptydir-data
    ```

2. After the drain operation finishes, all pods (excluding the pods controlled by daemon sets) should be running on the new node pool. You can verify this using the `kubectl get pods` command.

    ```bash
    kubectl get pods -o wide -A
    ```

### Troubleshoot pod eviction issues

You might encounter the following error when draining nodes:

> `Error when evicting pods/[podname] -n [namespace] (will retry after 5s): Cannot evict pod as it would violate the pod's disruption budget.`

By default, your cluster has AKS-managed pod disruption budgets (such as `coredns-pdb` or `konnectivity-agent`) with a `MinAvailable` of `1`. For example, if there are two `coredns` pods running, only one can be disrupted at a time. While one of them is getting recreated and is unavailable, the other `coredns` pod can't be evicted due to the pod disruption budget. This issue resolves itself after the initial `coredns` pod is scheduled and running, allowing the second pod to be properly evicted and recreated.

> [!TIP]
> Consider draining nodes one by one for a smoother eviction experience and to avoid throttling. For more information, see:
>
> * [Plan for availability using a pod disruption budget][pod-disruption-budget]
> * [Specify a disruption budget for your application][specify-disruption-budget]
> * [Disruptions][disruptions]

## Remove the existing node pool

> [!IMPORTANT]
> When you delete a node pool, AKS doesn't perform cordon and drain. To minimize the disruption of rescheduling pods currently running on the node pool you plan to delete, perform a cordon and drain on all nodes in the node pool before deleting.

### [Azure CLI](#tab/azure-cli)

1. Delete the original node pool using the [`az aks nodepool delete`][az-aks-nodepool-delete] command.

    ```azurecli-interactive
    az aks nodepool delete \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name nodepool1
    ```

2. Verify that your AKS cluster has only the new node pool with the applications and pods properly running using the `kubectl get nodes` command.

    ```bash
    kubectl get nodes
    ```

    Your output should resemble the following example output, showing only the new node pool `mynodepool`:

    ```output
    NAME                                 STATUS   ROLES   AGE   VERSION
    aks-mynodepool-98765432-vmss000000   Ready    agent   63m   v1.21.9
    aks-mynodepool-98765432-vmss000001   Ready    agent   63m   v1.21.9
    aks-mynodepool-98765432-vmss000002   Ready    agent   63m   v1.21.9
    ```

### [Azure PowerShell](#tab/azure-powershell)

1. Delete the original node pool using the [`Remove-AzAksNodePool`][remove-azaksnodepool] cmdlet.

    ```azurepowershell-interactive
    $params = @{
        ResourceGroupName = 'myResourceGroup'
        ClusterName       = 'myAKSCluster'
        Name              = 'nodepool1'
        Force             = $true
    }
    Remove-AzAksNodePool @params
    ```

2. Verify that your AKS cluster has only the new node pool with the applications and pods properly running using the `kubectl get nodes` command.

    ```bash
    kubectl get nodes
    ```

    Your output should resemble the following example output, showing only the new node pool `mynodepool`:

    ```output
    NAME                                 STATUS   ROLES   AGE   VERSION
    aks-mynodepool-98765432-vmss000000   Ready    agent   63m   v1.21.9
    aks-mynodepool-98765432-vmss000001   Ready    agent   63m   v1.21.9
    aks-mynodepool-98765432-vmss000002   Ready    agent   63m   v1.21.9
    ```

---

## Next steps

After resizing a node pool by cordoning and draining, learn more about [using multiple node pools][use-multiple-node-pools].

<!-- LINKS -->
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[aks-preview-extension]: /cli/azure/azure-cli-extensions-list
[upgrade-node-image]: upgrade-node-image.md
[upgrade-aks-node-pools-rolling]: upgrade-aks-node-pools-rolling.md
[max-surge]: upgrade-aks-node-pools-rolling.md#customize-node-surge
[max-unavailable]: upgrade-aks-node-pools-rolling.md#customize-unavailable-nodes
[drain-timeout]: upgrade-aks-node-pools-rolling.md#customize-node-drain-timeout
[node-soak-duration]: upgrade-aks-node-pools-rolling.md#customize-node-soak-time
[aks-production-upgrade-strategies]: aks-production-upgrade-strategies.md
[new-azaksnodepool]: /powershell/module/az.aks/new-azaksnodepool
[az-aks-nodepool-delete]: /cli/azure/aks/nodepool#az-aks-nodepool-delete
[remove-azaksnodepool]: /powershell/module/az.aks/remove-azaksnodepool
[vmss-docs]: /azure/virtual-machine-scale-sets/overview
[vm-node-pools]: ./virtual-machines-node-pools.md
[aks-support-policies]: support-policies.md#user-customization-of-agent-nodes
[update-node-pool-mode]: use-system-pools.md#update-existing-cluster-system-and-user-node-pools
[pod-disruption-budget]: operator-best-practices-scheduler.md#plan-for-availability-using-pod-disruption-budgets
[empty-dir]: https://kubernetes.io/docs/concepts/storage/volumes/#emptydir
[specify-disruption-budget]: https://kubernetes.io/docs/tasks/run-application/configure-pdb/
[disruptions]: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/
[use-multiple-node-pools]: create-node-pools.md
