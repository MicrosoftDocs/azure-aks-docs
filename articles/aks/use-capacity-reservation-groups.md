---
title: Assign Capacity Reservation Groups to Node Pools in Azure Kubernetes Service (AKS)
description: Learn how to associate capacity reservation groups with Azure Kubernetes Service (AKS) node pools to guarantee allocated capacity for your nodes.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 11/05/2026
ai-usage: ai-generated
author: schaffererin
ms.author: stgriffi
ms.subservice: aks-nodes
# Customer intent: "As a Kubernetes administrator, I want to use capacity reservation groups with node pools in AKS to guarantee allocated capacity for my node pools."
---

# Assign capacity reservation groups to Azure Kubernetes Service (AKS) node pools

As your workload demands change, you can associate existing [capacity reservation groups (CRGs)][capacity-reservation-groups] to your Azure Kubernetes Service (AKS) node pools to guarantee allocated capacity for them. Capacity reservation groups allow you to reserve compute capacity in an Azure region or availability zone for any duration of time. This feature is useful for workloads that require guaranteed capacity, such as those with predictable traffic patterns or those that need to meet specific performance requirements.

In this article, you learn how to use capacity reservation groups with standard node pools in AKS. For nodes managed by node auto-provisioning (NAP), see [Use capacity reservation groups with node auto-provisioning](#use-capacity-reservation-groups-with-node-auto-provisioning).

> [!IMPORTANT]
> A CRG association doesn't guarantee that every associated node occupies reserved capacity. Azure can allocate VMs beyond a reservation's quantity. Those excess VMs use ordinary on-demand capacity, incur additional compute charges, and aren't covered by the capacity reservation SLA. Reserved capacity is billed whether or not a VM uses it.

> [!NOTE]
> Deleting a node pool implicitly dissociates that node pool from any associated capacity reservation group before the node pool is deleted. Deleting a cluster implicitly dissociates all node pools in that cluster from their associated capacity reservation groups.

## Prerequisites for using capacity reservation groups with standard AKS node pools

- You need the Azure CLI version 2.56 or later installed and configured. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
- You need an existing [capacity reservation group](/azure/virtual-machines/capacity-reservation-associate-virtual-machine-scale-set) with at least one capacity reservation. For node pools managed through `az aks nodepool`, an empty group results in a warning and no association. For NAP, an empty group prevents the `AKSNodeClass` from becoming ready.
- You need to [create a user-assigned managed identity with the `Contributor` role](#create-a-user-assigned-managed-identity-and-assign-it-to-an-aks-cluster) for the resource group that contains the capacity reservation group and assign the identity to your AKS cluster. System-assigned managed identities don't work for this feature.

> [!IMPORTANT]
> For node pools managed through the AKS API or Azure CLI, shared or cross-subscription capacity reservation groups require the user or service principal running the AKS command to have `Microsoft.Compute/capacityReservationGroups/write` permission on the linked capacity reservation group. The granular shared capacity reservation group consumer permissions used for virtual machines, such as `Microsoft.Compute/capacityReservationGroups/deploy/action`, aren't currently sufficient for associating an AKS node pool with a capacity reservation group. NAP doesn't support shared or cross-subscription groups.
>
> Permissions assigned to the AKS cluster's managed identity don't replace this caller authorization check. The cluster managed identity still needs the required permissions on the resource group that contains the capacity reservation group, as described in this article.


### Create a user-assigned managed identity and assign it to an AKS cluster

1. Create a user-assigned managed identity using the [`az identity create`][az-identity-create] command.

    ```azurecli-interactive
    az identity create --name <identity-name> --resource-group <resource-group-name> --location <location>
    ```

1. Get the resource ID and principal ID of the user-assigned managed identity by running the [`az identity show`][az-identity-show] command and set them to environment variables.

    ```azurecli-interactive
    IDENTITY_ID=$(az identity show --name <identity-name> --resource-group <resource-group-name> --query id --output tsv)
    IDENTITY_PRINCIPAL_ID=$(az identity show --name <identity-name> --resource-group <resource-group-name> --query principalId --output tsv)
    ```

1. Assign the `Contributor` role to the user-assigned identity using the [`az role assignment create`][az-role-assignment-create] command.

    ```azurecli-interactive
    az role assignment create \
        --assignee-object-id "$IDENTITY_PRINCIPAL_ID" \
        --assignee-principal-type ServicePrincipal \
        --role Contributor \
        --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group-name> \
        --output json
    ```

    It can take up to _60 minutes_ for the role assignment to propagate.

1. Assign the user-assigned managed identity to a new or existing AKS cluster using the `--assign-identity` flag with the [`az aks create`][az-aks-create] or [`az aks update`][az-aks-update] command.

    ```azurecli-interactive
    # Create a new AKS cluster with the user-assigned managed identity
    az aks create \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --location <location> \
        --node-vm-size <vm-size> --node-count <node-count> \
        --assign-identity $IDENTITY_ID \
        --generate-ssh-keys

    # Update an existing AKS cluster to use the user-assigned managed identity
    az aks update \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --location <location> \
        --node-vm-size <vm-size> \
        --node-count <node-count> \
        --enable-managed-identity \
        --assign-identity $IDENTITY_ID         
    ```

## Get the ID of an existing capacity reservation group

Get the ID of an existing capacity reservation group by using the [`az capacity reservation group show`][az-crg-show] command and set it to an environment variable.

```azurecli-interactive
CRG_ID=$(az capacity reservation group show --capacity-reservation-group <crg-name> --resource-group <resource-group-name> --query id -o tsv)
```

## Associate an existing capacity reservation group with a new cluster

Associate an existing capacity reservation group with the default system node pool during cluster creation by running the [`az aks create`][az-aks-create] command with the `--assign-identity` and `--crg-id` flags.

```azurecli-interactive
az aks create \
    --resource-group <resource-group-name> \
    --name <cluster-name> \
    --location <location> \
    --node-vm-size <vm-size> \
    --node-count <node-count> \
    --assign-identity $IDENTITY_ID \
    --crg-id $CRG_ID \
    --generate-ssh-keys
```

## Associate an existing capacity reservation group with a new node pool

Associate an existing capacity reservation group with a new user node pool by using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--crg-id` flag.

```azurecli-interactive
az aks nodepool add --resource-group <resource-group-name> --cluster-name <cluster-name> --name <node-pool-name> --crg-id $CRG_ID
```

To associate an existing capacity reservation group with a new system node pool, create the node pool with the `--mode System` and `--crg-id` flags. For production clusters, use a minimum of three nodes for system node pools.

```azurecli-interactive
az aks nodepool add \
    --resource-group <resource-group-name> \
    --cluster-name <cluster-name> \
    --name <system-node-pool-name> \
    --mode System \
    --node-count 3 \
    --node-taints CriticalAddonsOnly=true:NoSchedule \
    --crg-id $CRG_ID
```

## Associate an existing capacity reservation group with an existing node pool (Preview)

Associate an existing capacity reservation group with an existing node pool by using the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--crg-id` flag.

- For zonal node pools, this operation initiates a rolling update of the target node pool. The update process involves rolling cordon and drain of all nodes, followed by a reboot to apply the change.
- For non-zonal (regional) user node pools during the preview, first scale the node pool to zero, then apply the capacity reservation group.
- For non-zonal (regional) system node pools, don't scale the system node pool to zero. Instead, [create a new system node pool](#associate-an-existing-capacity-reservation-group-with-a-new-node-pool) associated with the capacity reservation group, verify the new node pool is ready, and then delete the old system node pool. AKS requires at least one system node pool at all times.

### Prerequisites

- Install the `aks-preview` Azure CLI extension version `20.0.0b7` or later before running this command.
- Ensure the capacity reservation group has enough capacity for your node pool upgrade strategy. When `maxSurge > 0`, reserve extra capacity for the [max surge][max-surge] value. For example, a 10-node pool with `maxSurge` set to `2` can run up to 12 nodes during an upgrade. This extra capacity isn't required for [maxUnavailable][max-unavailable] only rollouts or regional scaled-to-zero paths.

    ```azurecli-interactive
    az aks nodepool update --resource-group <resource-group-name> --cluster-name <cluster-name> --name <node-pool-name> --crg-id $CRG_ID
    ```

    If the command fails with `LinkedAuthorizationFailed` and references `Microsoft.Compute/capacityReservationGroups/write`, grant that permission to the signed-in user or service principal running the command on the target capacity reservation group.

## Use capacity reservation groups with node auto-provisioning

For [NAP](./node-auto-provisioning.md), set `spec.capacityReservation.groupID` on an `AKSNodeClass` and reference that class from a Kubernetes `NodePool`. The Azure CLI `--crg-id` option applies to standard node pools in AKS, not NAP-managed nodes.

NAP requires a `Targeted` group in the same subscription and region as the cluster, with at least one successfully provisioned, compatible member reservation. Unlike AKS-managed node pools, NAP doesn't support shared or cross-subscription groups. An empty or unusable group prevents the class from becoming ready; NAP doesn't fall back to launching unassociated nodes.

Use the [user-assigned cluster managed identity and `Contributor` assignment](#create-a-user-assigned-managed-identity-and-assign-it-to-an-aks-cluster) described earlier so AKS can associate VMs with the group. The identity NAP uses to discover the group also needs these read permissions:

- `Microsoft.Compute/capacityReservationGroups/read`.
- `Microsoft.Compute/capacityReservationGroups/capacityReservations/read`.

`Reader` on the group provides both read permissions. If NAP uses the cluster identity that already has `Contributor` on the containing resource group, no additional read assignment is needed. Read access alone doesn't authorize VM association.

For configuration examples, verification, and troubleshooting, see [Capacity reservation group configuration for AKSNodeClass](./node-auto-provisioning-aksnodeclass.md#capacity-reservation-group-configuration).

## Next steps: Manage node pools in AKS

To learn more about managing node pools in AKS, see [Manage node pools in Azure Kubernetes Service (AKS)](manage-node-pools.md). To learn how to add, update, or delete system node pools, see [Use system node pools in Azure Kubernetes Service (AKS)](use-system-pools.md).

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
