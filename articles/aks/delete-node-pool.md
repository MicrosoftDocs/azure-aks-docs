---
title: Delete an Azure Kubernetes Service (AKS) node pool
description: Learn about deleting a node pool from your Azure Kubernetes Service (AKS) cluster.
ms.topic: how-to
ms.author: alvinli
author: alvinli
ms.date: 05/09/2024
# Customer intent: "As a cloud administrator managing an Azure Kubernetes Service cluster, I want to delete a node pool, so that I can optimize resource allocation and manage costs effectively."
---

# Delete an Azure Kubernetes Service (AKS) node pool

This article outlines node pool deletion in Azure Kubernetes Service (AKS), including what happens when you delete a node pool and how to delete a node pool.

## What happens when you delete a node pool?

When you delete a node pool, the following resources are deleted:

* The virtual machine scale set (VMSS) and virtual machines (VMs) for each node in the node pool
* Any node instances in the node pool along with any pods running on those nodes

## Delete a node pool

> [!IMPORTANT]
> Keep the following information in mind when deleting a node pool:
>
> * **You can't recover a node pool after it's deleted**. You need to create a new node pool and redeploy your applications.

### [Azure CLI](#tab/azure-cli)

Delete a node pool using the [`az aks nodepool delete`][az-aks-delete-nodepool] command.

```azurecli-interactive
az aks nodepool delete \
    --resource-group <resource-group-name> \
    --cluster-name <cluster-name> \
    --name <node-pool-name>
```

### [Azure PowerShell](#tab/azure-powershell)

Delete a node pool using the [`Remove-AzAksNodePool`][remove-azaksnodepool] cmdlet.

```azurepowershell-interactive
$params = @{
    ResourceGroupName = '<resource-group-name>'
    ClusterName       = '<cluster-name>'
    Name              = '<node-pool-name>'
}
Remove-AzAksNodePool @params
```

### [Azure portal](#tab/azure-portal)

To delete a node pool in Azure portal, navigate to the **Settings > Node pools** page for the cluster and select the name of the node pool you want to delete. On the **Node Pool | Overview** page, you can select **Delete** to delete the node pool.

---

To verify that the node pool was deleted successfully, use the `kubectl get nodes` command to confirm that the nodes in the node pool no longer exist.

## Ignore PodDisruptionBudgets (PDBs) when removing an existing node pool

If your cluster has PodDisruptionBudgets that are preventing the deletion of the node pool, you can ignore the PodDisruptionBudget requirements by setting `--ignore-pod-disruption-budget` to `true`. To learn more about PodDisruptionBudgets, see:

* [Plan for availability using a pod disruption budget][pod-disruption-budget]
* [Specifying a Disruption Budget for your Application][specify-disruption-budget]
* [Disruptions][disruptions]

1. Delete an existing node pool without following any PodDisruptionBudgets set on the cluster using the [`az aks nodepool delete`][az-aks-delete-nodepool] command with the `--ignore-pod-disruption-budget` flag set to `true`:

    ```azurecli-interactive
    az aks nodepool delete \
        --resource-group myResourceGroup \
        --cluster-name myAKSCluster \
        --name nodepool1 \
        --ignore-pod-disruption-budget true
    ```

1. To verify that the node pool was deleted successfully, use the `kubectl get nodes` command to confirm that the nodes in the node pool no longer exist.

## Remove specific VMs in an existing node pool

> [!NOTE]
> When you delete a VM with this command, AKS doesn't perform cordon and drain. To minimize the disruption of rescheduling pods currently running on the VM you plan to delete, perform a cordon and drain on the VM before deleting. You can learn more about how to cordon and drain using the example scenario provided in the resizing node pools tutorial.

1. List the existing nodes using the `kubectl get nodes` command.

    ```bash
    kubectl get nodes
    ```

    Your output should look similar to the following example output:

    ```output
    NAME                                 STATUS   ROLES   AGE   VERSION
    aks-mynodepool-20823458-vmss000000   Ready    agent   63m   v1.21.9
    aks-mynodepool-20823458-vmss000001   Ready    agent   63m   v1.21.9
    aks-mynodepool-20823458-vmss000002   Ready    agent   63m   v1.21.9
    ```

1. Delete the specified VMs using the [`az aks nodepool delete-machines`][az-aks-nodepool-delete-machines] command. Make sure to replace the placeholders with your own values.

    ```azurecli-interactive
    az aks nodepool delete-machines \
        --resource-group <resource-group-name> \
        --cluster-name <cluster-name> \
        --name <node-pool-name> \
        --machine-names <vm-name-1> <vm-name-2>
    ```

1. Verify the VMs were successfully deleted using the `kubectl get nodes` command.

    ```bash
    kubectl get nodes
    ```

    Your output should no longer include the VMs that you specified in the `az aks nodepool delete-machines` command.

## Next steps

For more information about adjusting node pool sizes in AKS, see [Resize node pools][resize-node-pool].

<!-- LINKS -->
[az-aks-delete-nodepool]: /cli/azure/aks#az_aks_nodepool_delete
[remove-azaksnodepool]: /powershell/module/az.aks/remove-azaksnodepool
[resize-node-pool]: ./resize-node-pool.md
[pod-disruption-budget]: operator-best-practices-scheduler.md#plan-for-availability-using-pod-disruption-budgets
[specify-disruption-budget]: https://kubernetes.io/docs/tasks/run-application/configure-pdb/
[disruptions]: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/
[az-aks-nodepool-delete-machines]: /cli/azure/aks/nodepool#az_aks_nodepool_delete_machines
