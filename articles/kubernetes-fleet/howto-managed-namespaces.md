---
title: Use Azure Kubernetes Fleet Manager Managed Namespaces for multi-tenancy across multiple clusters (preview).
description: Learn how to use multi-cluster managed namespaces to define resource quotas and network policies as well as delegate user access for namespaces on multiple clusters.
author: audrastump
ms.author: stumpaudra
ms.topic: how-to
ms.date: 09/22/2025
ms.service: azure-kubernetes-fleet-manager
zone_pivot_groups: azure-portal-azure-cli

# Customer intent: "As a platform admin, I want to define a namespace and deploy it across selected fleet clusters so I can delegate application teams access to resources on any cluster where the namespace exists."
---
# Use Azure Kubernetes Fleet Manager Managed Namespaces for multi-tenancy across multiple clusters (preview).
Multi-cluster managed namespaces enable multi-tenancy across multiple clusters through centralized, Azure-native namespace management. Platform administrators can:

* Define and enforce consistent resource quotas across all fleet member clusters
* Configure uniform network policies across multiple clusters
* Delegate namespace access without granting full cluster access to users

This enables teams to work within their allocated resources across any member cluster where their managed namespace exists.

**Applies to:** :heavy_check_mark: Fleet Manager with hub cluster

## Before you begin
* You need an Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).

* To understand the concept of a managed namespace, read the [conceptual overview of multi-cluster managed namespaces](./concepts-fleet-managed-namespace.md).

* You need Azure CLI version 2.58.0 or later installed to complete this article. To install or upgrade, see [Install the Azure CLI][az-aks-install-cli].

* You need the `fleet` Azure CLI extension. You can install it by running the following command:

  ```azurecli-interactive
  az extension add --name fleet
  ```

  Run the [`az extension update`][az-extension-update] command to update to the latest version of the extension:

  ```azurecli-interactive
  az extension update --name fleet
  ```
  
  Confirm the fleet extension version is 1.7.0:

  ```azurecli-interactive
  az extension show --name fleet
  ```

* You need a fleet with a hub cluster. This article includes instructions for configuring your managed namespace across member clusters. To follow this tutorial, [create and join at least one Azure Kubernetes Service (AKS) cluster to the fleet](./quickstart-create-fleet-and-members.md).

* Set the following environment variables for your subscription ID, resource group, Fleet, and Fleet Member:

  ```azurecli-interactive
  export SUBSCRIPTION_ID=<subscription-id>
  export GROUP=<resource-group-name>
  export FLEET=<fleet-name>
  export FLEET_ID=<fleet-id>
  ```

* Set the default Azure subscription by using the [`az account set`][az-account-set] command:

  ```azurecli-interactive
  az account set --subscription ${SUBSCRIPTION_ID}
  ```

:::zone target="docs" pivot="azure-cli"

## Creating a new multi-cluster managed namespace 

Create the multi-cluster managed namespace:

```azurecli-interactive
# Note: Adoption policy and delete policy are required when creating a multi-cluster managed namespace.
az fleet namespace create \ 
    --name myManagedNamespace \ 
    --fleet-name $FLEET \
    --resource-group $GROUP \
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

## Delegating access to a user
You can now assign access to a user for the managed namespace across member clusters using one of the [built-in roles](./concepts-fleet-managed-namespace.md#multi-cluster-managed-namespace-built-in-roles).

```azurecli-interactive
az role assignment create --role "Azure Kubernetes Fleet Manager Member Cluster RBAC Writer" --assignee <USER-ENTRA-ID> --scope $FLEET_ID/managedNamespaces/myManagedNamespace
```

## Manage member clusters the namespace is deployed to
Control which member clusters the managed namespace is deployed to by specifying the desired list of member cluster names. Ensure the clusters specified are already members of the fleet.

**To add member clusters:**
Specify the full list of member clusters you want the namespace deployed to, including any new clusters you wish to add. The namespace will be propagated to all clusters in the list.

**To remove member clusters:**
Specify the list of member clusters you want the namespace to remain on, excluding any clusters you wish to remove. The namespace will be removed from clusters not in the list.

In this example, the namespace will be deployed to `clusterA`, `clusterB`, and `clusterC`.

```azurecli-interactive
az fleet namespace create \
    --name myManagedNamespace \
    --fleet-name $FLEET \
    --resource-group $GROUP \
    --member-cluster-names clusterA clusterB clusterC
```

## Viewing the multi-cluster managed namespace
After creation, you can view the member clusters where the managed namespace is placed.

```azurecli-interactive
az fleet namespace show \
   --fleet-name $FLEET \
   --resource-group $GROUP \
   --name myManagedNamespace \
   -o table
```

## Deleting the multi-cluster managed namespace
To clean up, delete the managed namespace resource.

```azurecli-interactive
az fleet namespace delete \
    --name myManagedNamespace \
    --fleet-name $FLEET \
    --resource-group $GROUP
```
:::zone-end

:::zone target="docs" pivot="azure-portal"
## Creating a new multi-cluster managed namespace 
## Delegating access to a user
## Manage member clusters the namespace is deployed to
## Viewing the multi-cluster managed namespace
## Deleting the multi-cluster managed namespace
:::zone-end

<!-- INTERNAL LINKS -->
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-account-set]: /cli/azure/account#az_account_set





