---
title: Assign Capacity Reservation Groups to Node Pools in Azure Kubernetes Service (AKS)
description: Learn how to use capacity reservation groups with node pools in Azure Kubernetes Service (AKS) to guarantee allocated capacity for your node pools.  
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 07/19/2023
author: schaffererin
ms.author: schaffererin
ms.subservice: aks-nodes
# Customer intent: "As a Kubernetes administrator, I want to use capacity reservation groups with node pools in AKS to guarantee allocated capacity for my node pools."
---

# Assign capacity reservation groups to Azure Kubernetes Service (AKS) node pools

As your workload demands change, you can associate existing [capacity reservation groups (CRGs)][capacity-reservation-groups] to your Azure Kubernetes Service (AKS) node pools to guarantee allocated capacity for them. Capacity reservation groups allow you to reserve compute capacity in an Azure region or availability zone for any duration of time. This feature is useful for workloads that require guaranteed capacity, such as those with predictable traffic patterns or those that need to meet specific performance requirements.

In this article, you learn how to use capacity reservation groups with node pools in AKS.

> [!NOTE]
> Deleting a node pool implicitly dissociates that node pool from any associated capacity reservation group before the node pool is deleted. Deleting a cluster implicitly dissociates all node pools in that cluster from their associated capacity reservation groups.

## Prerequisites for using capacity reservation groups with AKS node pools

- You need the Azure CLI version 2.56 or later installed and configured. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
- You need an existing [capacity reservation group](/azure/virtual-machines/capacity-reservation-associate-virtual-machine-scale-set) with at least one capacity reservation. If not, the node pool is added to the cluster with a warning and no capacity reservation group gets associated.
- You need to [create a user-assigned managed identity with the `Contributor` role](#create-a-user-assigned-managed-identity-and-assign-it-to-an-aks-cluster) for the resource group that contains the capacity reservation group and assign the identity to your AKS cluster. System-assigned managed identities don't work for this feature.

### Create a user-assigned managed identity and assign it to an AKS cluster

1. Create a user-assigned managed identity using the [`az identity create`][az-identity-create] command.

    ```azurecli-interactive
    az identity create --name <identity-name> --resource-group <resource-group-name> --location <location>
    ```

1. Get the ID of the user-assigned managed identity using the [`az identity show`][az-identity-show] command and set it to an environment variable.

    ```azurecli-interactive
    IDENTITY_ID=$(az identity show --name <identity-name> --resource-group <resource-group-name> --query identity.id -o tsv)
    ```

1. Assign the `Contributor` role to the user-assigned identity using the [`az role assignment create`][az-role-assignment-create] command.

    ```azurecli-interactive
    az role assignment create --assignee $IDENTITY_ID --role "Contributor" --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group-name>
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

## Limitations for using capacity reservation groups with AKS node pools

You can't update an existing node pool with a capacity reservation group. Instead, you need to create a new node pool with the `--crg-id` flag to associate it with the capacity reservation group. You can also associate an existing capacity reservation group with a system node pool during cluster creation.

## Get the ID of an existing capacity reservation group

- Get the ID of an existing capacity reservation group using the [`az capacity reservation group show`][az-crg-show] command and set it to an environment variable.

    ```azurecli-interactive
    CRG_ID=$(az capacity reservation group show --capacity-reservation-group <crg-name> --resource-group <resource-group-name> --query id -o tsv)
    ```

## Associate an existing capacity reservation group with a node pool

- Associate an existing capacity reservation group with a node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--crg-id` flag. The following example assumes you have a CRG named "myCRG".

    ```azurecli-interactive
    az aks nodepool add --resource-group <resource-group-name> --cluster-name <cluster-name> --name <node-pool-name> --crg-id $CRG_ID
    ```

## Associate an existing capacity reservation group with a system node pool

To associate an existing capacity reservation group with a system node pool, you need to assign the user-assigned managed identity with the `Contributor` role to the cluster during cluster creation. You can then use the `--crg-id` flag to associate the capacity reservation group with the system node pool.

- Create a new AKS cluster with the user-assigned managed identity and associate it with the capacity reservation group using the `--assign-identity` and `--crg-id` flags with the [`az aks create`][az-aks-create] command.

    ```azurecli-interactive
    az aks create \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --location <location> \
        --node-vm-size <vm-size> --node-count <node-count> \
        --assign-identity $IDENTITY_ID \
        --crg-id $CRG_ID \
        --generate-ssh-keys
    ```

## Next steps: Manage node pools in AKS

To learn more about managing node pools in AKS, see [Manage node pools in Azure Kubernetes Service (AKS)](manage-node-pools.md).

<!-- LINKS -->
[capacity-reservation-groups]:/azure/virtual-machines/capacity-reservation-associate-virtual-machine-scale-set
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-identity-create]: /cli/azure/identity#az-identity-create
[az-identity-show]: /cli/azure/identity#az-identity-show
[az-role-assignment-create]: /cli/azure/role/assignment#az-role-assignment-create
[az-crg-show]: /cli/azure/capacity/reservation/group#az-capacity-reservation-group-show
[az-aks-update]: /cli/azure/aks#az-aks-update
