---
title: Assign Capacity Reservation Groups to Node Pools in Azure Kubernetes Service (AKS)
description: Learn how to use capacity reservation groups with node pools in Azure Kubernetes Service (AKS) to guarantee allocated capacity for your node pools.  
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 08/17/2026
ai-usage: ai-assisted
author: schaffererin
ms.author: stgriffi
ms.subservice: aks-nodes
# Customer intent: "As a Kubernetes administrator, I want to use capacity reservation groups with node pools in AKS to guarantee allocated capacity for my node pools."
---

# Assign capacity reservation groups to Azure Kubernetes Service (AKS) node pools

As your workload demands change, you can associate existing [capacity reservation groups (CRGs)][capacity-reservation-groups] to your Azure Kubernetes Service (AKS) node pools to guarantee allocated capacity for them. Capacity reservation groups allow you to reserve compute capacity in an Azure region or availability zone for any duration of time. This feature is useful for workloads that require guaranteed capacity, such as those with predictable traffic patterns or those that need to meet specific performance requirements.

In this article, you learn how to use capacity reservation groups with node pools in AKS.

> [!NOTE]
> Deleting a node pool implicitly dissociates that node pool from any associated capacity reservation group before the node pool is deleted. Deleting a cluster implicitly dissociates all node pools in that cluster from their associated capacity reservation groups.

## Prerequisites for using capacity reservation groups with AKS node pools

- You need Azure CLI version 2.76.0 or later installed and configured. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
- You need an existing [capacity reservation group](/azure/virtual-machines/capacity-reservation-associate-virtual-machine-scale-set) with at least one capacity reservation. If not, the node pool is added to the cluster with a warning and no capacity reservation group gets associated.
- You need to [create a user-assigned managed identity with the `Contributor` role](#create-a-user-assigned-managed-identity-and-assign-it-to-an-aks-cluster) on the capacity reservation group and assign the identity to your AKS cluster. System-assigned managed identities don't work for this feature.


### Create a user-assigned managed identity and assign it to an AKS cluster

1. Create a user-assigned managed identity using the [`az identity create`][az-identity-create] command.

    ```azurecli-interactive
    az identity create --name <identity-name> --resource-group <identity-resource-group-name> --location <location>
    ```

1. Get the resource ID and principal ID of the user-assigned managed identity using the [`az identity show`][az-identity-show] command and set them to environment variables. Use the resource ID when you assign the identity to the cluster and the principal ID when you assign an Azure role to the identity.

    ```azurecli-interactive
    IDENTITY_RESOURCE_ID=$(az identity show --name <identity-name> --resource-group <identity-resource-group-name> --query id -o tsv)
    IDENTITY_PRINCIPAL_ID=$(az identity show --name <identity-name> --resource-group <identity-resource-group-name> --query principalId -o tsv)
    ```

1. Assign the `Contributor` role to the user-assigned identity, scoped to the capacity reservation group, using the [`az role assignment create`][az-role-assignment-create] command.

    ```azurecli-interactive
    az role assignment create \
        --assignee-object-id "$IDENTITY_PRINCIPAL_ID" \
        --assignee-principal-type ServicePrincipal \
        --role "Contributor" \
        --scope /subscriptions/<subscription-id>/resourceGroups/<capacity-reservation-resource-group-name>/providers/Microsoft.Compute/capacityReservationGroups/<crg-name>
    ```

    It can take up to _60 minutes_ for the role assignment to propagate.

1. Assign the user-assigned managed identity to a new or existing AKS cluster using the `--assign-identity` flag with the [`az aks create`][az-aks-create] or [`az aks update`][az-aks-update] command.

    ```azurecli-interactive
    # Create a new AKS cluster with the user-assigned managed identity
    az aks create \
        --resource-group <cluster-resource-group-name> \
        --name <cluster-name> \
        --location <location> \
        --node-vm-size <vm-size> --node-count <node-count> \
        --assign-identity "$IDENTITY_RESOURCE_ID" \
        --generate-ssh-keys

    # Update an existing AKS cluster to use the user-assigned managed identity
    az aks update \
        --resource-group <cluster-resource-group-name> \
        --name <cluster-name> \
        --enable-managed-identity \
        --assign-identity "$IDENTITY_RESOURCE_ID"
    ```

> [!IMPORTANT]
> Before you change the control plane identity of an existing cluster, grant the new identity equivalent permissions on the Azure resources that the cluster manages. Changing from a system-assigned managed identity to a user-assigned managed identity doesn't cause downtime for the control plane or agent pools. The control plane might continue to use the old identity for several hours until its token refreshes. For more information, see [Update an existing cluster to use a user-assigned managed identity](user-assigned-managed-identity.md#update-an-existing-cluster-to-use-a-user-assigned-managed-identity).

## Get the ID of an existing capacity reservation group

Get the ID of an existing capacity reservation group by using the [`az capacity reservation group show`][az-crg-show] command and set it to an environment variable.

```azurecli-interactive
CRG_ID=$(az capacity reservation group show --capacity-reservation-group <crg-name> --resource-group <capacity-reservation-resource-group-name> --query id -o tsv)
```

## Associate an existing capacity reservation group with a new node pool

Associate an existing capacity reservation group with a new node pool by using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--crg-id` flag. The following example assumes you have a CRG named "myCRG".

```azurecli-interactive
az aks nodepool add --resource-group <cluster-resource-group-name> --cluster-name <cluster-name> --name <node-pool-name> --crg-id "$CRG_ID"
```

## Associate an existing capacity reservation group with an existing node pool (Preview)

Associate an existing capacity reservation group with an existing node pool by using the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--crg-id` flag.

- Updating an existing node pool is supported only for Virtual Machine Scale Sets node pools. For [Virtual Machines node pools](virtual-machines-node-pools.md), assign the capacity reservation group when you create the node pool. You can't add or change the capacity reservation group after creation.
- For zonal node pools with running nodes, AKS updates the existing Virtual Machine Scale Set (VMSS) and performs a rolling reimage. AKS doesn't create or replace the node pool. It cordons and drains nodes in batches based on the node pool's upgrade settings before reimaging the VMSS instances.
- For non-zonal (regional) node pools during the preview, first scale the node pool to zero, then apply the capacity reservation group.

### Prerequisites

- Install the `aks-preview` Azure CLI extension version `20.0.0b7` or later before running this command.
- When `maxSurge` is greater than `0`, AKS temporarily creates extra VM instances in the same node pool and removes them after the rollout. These instances require matching allocatable compute capacity. To guarantee their allocation, reserve extra matching capacity in the capacity reservation group for the [max surge][max-surge] value. For example, a 10-node pool with `maxSurge` set to `2` can run up to 12 nodes during an upgrade.
- For a user node pool without extra capacity, set `maxSurge` to `0` and [maxUnavailable][max-unavailable] to a value greater than `0` before you associate the capacity reservation group. This configuration avoids creating extra VM instances but temporarily reduces the node pool's available capacity. Make sure your workloads and pod disruption budgets can tolerate the unavailable nodes. System node pools don't support `maxUnavailable`.

```azurecli-interactive
az aks nodepool update --resource-group <cluster-resource-group-name> --cluster-name <cluster-name> --name <node-pool-name> --crg-id "$CRG_ID"
```

> [!IMPORTANT]
> A capacity reservation with a quantity of zero doesn't reserve capacity. After you associate the node pool, increase each matching capacity reservation to the number of allocated node instances in its zone to protect the allocated capacity. For more information, see [Secure existing zonal virtual machine scale sets using a zero-size reservation](/azure/virtual-machines/capacity-reservation-associate-virtual-machine-scale-set#secure-existing-zonal-virtual-machine-scale-sets-using-zero-size-reservation).

## Associate an existing capacity reservation group with a system node pool

Associate a capacity reservation group with a system node pool during cluster creation, or follow the [existing node pool workflow](#associate-an-existing-capacity-reservation-group-with-an-existing-node-pool-preview) to update an existing system node pool. Existing system node pools with running nodes must use `maxSurge` because system node pools don't support `maxUnavailable`. Make sure matching spare or reserved capacity is available for the surge instances.

Create a new AKS cluster with the user-assigned managed identity and associate it with the capacity reservation group using the `--assign-identity` and `--crg-id` flags with the [`az aks create`][az-aks-create] command.

```azurecli-interactive
az aks create \
    --resource-group <cluster-resource-group-name> \
    --name <cluster-name> \
    --location <location> \
    --node-vm-size <vm-size> --node-count <node-count> \
    --assign-identity "$IDENTITY_RESOURCE_ID" \
    --crg-id "$CRG_ID" \
    --generate-ssh-keys
```

## Next steps: Manage node pools in AKS

To learn more about managing node pools in AKS, see [Manage node pools in Azure Kubernetes Service (AKS)](manage-node-pools.md).

<!-- LINKS -->
[capacity-reservation-groups]:/azure/virtual-machines/capacity-reservation-associate-virtual-machine-scale-set
[max-surge]: upgrade-aks-node-pools-rolling.md#customize-node-surge
[max-unavailable]: upgrade-aks-node-pools-rolling.md#customize-unavailable-nodes
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[az-identity-create]: /cli/azure/identity#az-identity-create
[az-identity-show]: /cli/azure/identity#az-identity-show
[az-role-assignment-create]: /cli/azure/role/assignment#az-role-assignment-create
[az-crg-show]: /cli/azure/capacity/reservation/group#az-capacity-reservation-group-show
[az-aks-update]: /cli/azure/aks#az-aks-update
