---
title: Use Kubernetes Fleet Manager Managed Namespaces for Multi-Tenancy across Multiple Clusters
description: Learn how to use multi-cluster managed namespaces to define resource quotas and network policies, and how to delegate user access for namespaces on multiple clusters.
author: audrastump
ms.author: stumpaudra
ms.topic: how-to
ms.date: 09/22/2025
ms.service: azure-kubernetes-fleet-manager

# Customer intent: "As a platform admin, I want to define a namespace and deploy it across selected fleet clusters so I can delegate application teams access to resources on any cluster where the namespace exists."
---
# Use Fleet Manager Managed Namespaces for multi-tenancy across multiple clusters (preview)

**Applies to:** :heavy_check_mark: Fleet Manager with hub cluster

This article shows you how to use Fleet Manager Managed Namespaces to define resource quotas and network policies, and how to delegate user access for namespaces on multiple clusters.

[!INCLUDE [preview_features_note](./includes/preview/preview-callout.md)]

## Before you begin

> [!IMPORTANT]
> This article is intended for **platform administrators** who need to create, configure, and manage multi-cluster managed namespaces across a fleet. If you're a developer or team member looking to view and access existing managed namespaces, see [View managed namespaces you have access to](./howto-managed-namespaces-access.md).

- You need an Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).
- You need a fleet with a hub cluster. If you don't have one, see [create and join at least one Azure Kubernetes Service (AKS) cluster to the fleet](./quickstart-create-fleet-and-members.md).
- Read the [Overview of multi-cluster managed namespaces](./concepts-fleet-managed-namespace.md) to understand the concept of a managed namespace.
- You need Azure CLI version 2.58.0 or later installed to complete this article. To install or upgrade, see [Install Azure CLI][az-aks-install-cli].
- You need the `fleet` Azure CLI extension. You can install it and update to the latest version using the [`az extension add`](/cli/azure/extension#az-extension-add) and [`az extension update`](/cli/azure/extension#az-extension-update) commands.
	
    ```azurecli-interactive
    # Install the extension
    az extension add --name fleet
	
    # Update the extension
    az extension update --name fleet
    ```

- Confirm the fleet extension version is at least 1.7.0 using the [`az extension show`](/cli/azure/extension#az-extension-show) command.
	
    ```azurecli-interactive
    az extension show --name fleet
    ```

- Set the following environment variables for your subscription ID, resource group, Fleet, and Fleet Member:

    ```bash
    export SUBSCRIPTION_ID=<subscription-id>
    export GROUP=<resource-group-name>
    export FLEET=<fleet-name>
    export FLEET_ID=<fleet-id>
    ```

- Set the default Azure subscription using the [`az account set`][az-account-set] command.
	
    ```azurecli-interactive
    az account set --subscription ${SUBSCRIPTION_ID}
    ```

## Create a new multi-cluster managed namespace 

> [!IMPORTANT]
> An adoption policy and delete policy are required when creating a multi-cluster managed namespace.

- Create a new multi-cluster managed namespace using the [`az fleet namespace create`](/cli/azure/fleet/namespace#az-fleet-namespace-create) command.

    ```azurecli-interactive
        az fleet namespace create \
            --resource-group $GROUP \
            --fleet-name $FLEET \
            --name my-managed-namespace \ 
            --annotations annotation1=value1 annotation2=value2 \
            --labels team=myTeam label2=value2 \
            --cpu-requests 1m \
            --cpu-limits 4m \
            --memory-requests 1Mi \
            --memory-limits 4Mi \
            --ingress-policy allowAll \
            --egress-policy allowAll \
            --delete-policy keep \
            --adoption-policy never
    ```

> [!IMPORTANT]
> When a multi-cluster managed namespace adopts a single cluster managed namespace or vice versa, it may lead to conflicting ownership. If you do so, use a delete policy of `keep` to avoid deleting Kubernetes resources that are still being actively managed by either Fleet or an AKS cluster.

## Delegate access to a user

You can now assign access to a user for the managed namespace across member clusters using one of the [built-in roles](./concepts-fleet-managed-namespace.md#multi-cluster-managed-namespace-built-in-roles).

- Create a role assignment using the [`az role assignment create`](/cli/azure/role/assignment#az-role-assignment-create) command. The following example assigns the _Azure Kubernetes Fleet Manager RBAC Writer for Member Clusters_ role:

    ```azurecli-interactive
    az role assignment create --role "Azure Kubernetes Fleet Manager RBAC Writer for Member Clusters" --assignee <USER-ENTRA-ID> --scope $FLEET_ID/managedNamespaces/my-managed-namespace
    ```

## Add member clusters to a managed namespace

You can control which member clusters to deploy the managed namespace to by specifying the desired list of member cluster names. Any unmanaged namespaces with the same name on member clusters not in the specified list remain untouched.

> [!IMPORTANT]
> Make sure the member clusters meet the following requirements:
>
> - Member clusters within a managed namespace must have a target Kubernetes version of at least 1.30.0. Clusters below this version **will not** block end users from modifying the placed resources.
> - The clusters you specify must be members of the fleet.

- Specify the full list of member clusters you want to deploy the managed namespace to using the [`az fleet namespace create`](/cli/azure/fleet/namespace#az-fleet-namespace-create) command with the `--member-cluster-names` parameter. The namespace will be propagated to all clusters in the list.

   In this example, the namespace will be deployed to `clusterA`, `clusterB`, and `clusterC`.

    ```azurecli-interactive
    az fleet namespace create \
        --resource-group $GROUP \
        --fleet-name $FLEET \
        --name my-managed-namespace \
        --member-cluster-names clusterA clusterB clusterC
    ```

## Remove member clusters from a managed namespace

You can remove member clusters from a managed namespace by specifying the list of member clusters you want the namespace to remain on, excluding any clusters you want to remove. This action removes the namespace from the clusters not included in the list.

- Specify the list of member clusters you want the managed namespace to remain on using the [`az fleet namespace create`](/cli/azure/fleet/namespace#az-fleet-namespace-create) command with the `--member-cluster-names` parameter. The namespace will be removed from any clusters excluded from the list.

   In this example, the namespace will be removed from `clusterC`.

    ```azurecli-interactive
    az fleet namespace create \
        --resource-group $GROUP \
        --fleet-name $FLEET \
        --name my-managed-namespace \
        --member-cluster-names clusterA clusterB
    ```

## View the multi-cluster managed namespace

- View the managed namespace using the [`az fleet namespace show`](/cli/azure/fleet/namespace#az-fleet-namespace-show) command.

    ```azurecli-interactive
    az fleet namespace show \
       --resource-group $GROUP \
       --fleet-name $FLEET \
       --name my-managed-namespace \
       -o table
    ```

    Your output should resemble the following example output:
    ```output
    AdoptionPolicy  DeletePolicy   ETag                                    Location   Name                  ProvisioningState   ResourceGroup
    --------------  ------------   -------------------------------------   --------   --------------------  -----------------   -------------
    Always          Delete         "aaaaaaaa-0b0b-1c1c-2d2d-333333333333   westus2    my-managed-namespace  Succeeded           test-rg
    ```

## Delete a multi-cluster managed namespace

- Delete a multi-cluster managed namespace using the [`az fleet namespace delete`](/cli/azure/fleet/namespace#az-fleet-namespace-delete) command.

    ```azurecli-interactive
    az fleet namespace delete \
        --resource-group $GROUP \
        --fleet-name $FLEET \
        --name my-managed-namespace \
    ```

> [!IMPORTANT]
> RBAC roles placed on the managed namespace will be deleted when the managed namespace is deleted, regardless of the delete policy configuration


## Next steps

- Read the [Overview of multi-cluster managed namespaces](./concepts-fleet-managed-namespace.md) to understand the concept of a managed namespace.
- Learn how to [view managed namespaces you have access to](./howto-managed-namespaces-access.md).

<!-- INTERNAL LINKS -->
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-account-set]: /cli/azure/account#az-account-set