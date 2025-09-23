---
title: Use Azure Kubernetes Fleet Manager Managed Namespaces to manage workloads across multiple clusters. 
description: Learn how to use multi-cluster managed namespace to isolate and manage workloads across multiple fleet members.
author: audrastump
ms.author: stumpaudra
ms.topic: how-to
ms.date: 09/22/2025
ms.service: azure-kubernetes-fleet-manager
# Customer intent: "As a platform admin, I want to define a namespace and deploy it across selected fleet clusters so I can delegate application teams access to resources on any cluster where the namespace exists."
---
# Use Azure Kubernetes Fleet Manager Multi-Cluster Managed Namespaces to manage workloads across multiple clusters (preview).
Multi-cluster managed namespaces provide a centralized, Azure-native way to isolate workloads across several member clusters within a fleet. Managed namespaces allow platform admins to configure resource quotas, user access, and network policies across all clusters where the namespace is placed. Teams or developers can access resources in namespaces to which they have been delegated access.

## Prerequisites
* You need an Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).

* To understand the concept of a managed namespace, read the [conceptual overview of multi-cluster managed namespaces](./concepts-fleet-managed-namespace.md).

* You need Azure CLI version 2.58.0 or later installed to complete this article. To install or upgrade, see [Install Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest).

* You need the `fleet` Azure CLI extension. You can install it by running the following command:

  ```azurecli-interactive
  az extension add --name fleet
  ```

  Run the [`az extension update`](https://learn.microsoft.com/cli/azure/extension?view=azure-cli-latest#az-extension-update) command to update to the latest version of the extension:

  ```azurecli-interactive
  az extension update --name fleet
  ```

* You need a fleet with a hub cluster. This article includes instructions for configuring your managed namespace across member clusters. To follow this tutorial, [create and join at least one Azure Kubernetes Service (AKS) cluster to the fleet](./quickstart-create-fleet-and-members.md).

## Creating a new multi-cluster managed namespace 
#### [Azure portal](#tab/azure-portal)
#### [Azure CLI](#tab/cli)

1. Set the following environment variables for your subscription ID, resource group, Fleet, and Fleet Member:

```azurecli-interactive
export SUBSCRIPTION_ID=<subscription-id>
export GROUP=<resource-group-name>
export FLEET=<fleet-name>
export FLEET_ID=<fleet-id>
export FLEET_MEMBER_NAME=<member-cluster-name>
```

2. Set the default Azure subscription by using the [`az account set`][az-account-set] command:

```azurecli-interactive
az account set --subscription ${SUBSCRIPTION_ID}
```

3. Create the multi-cluster managed namespace:

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
---

## Updating a multi-cluster managed namespace to add a member cluster
#### [Azure portal](#tab=azure-portal-2)
#### [Azure CLI](#tab=cli-2)
```azurecli-interactive
az fleet namespace create \
    --name myManagedNamespace \
    --fleet-name $FLEET \
    --resource-group $GROUP \
    --member-cluster-names $FLEET_MEMBER_NAME
```
---

## Viewing the multi-cluster managed namespace
After creation, you can view the member clusters where the managed namespace is placed.

#### [Azure portal](#tab=azure-portal-3)
#### [Azure CLI](#tab=cli-3)

```azurecli-interactive
az fleet namespace show \
   --fleet-name $FLEET \
   --resource-group $GROUP \
   --name myManagedNamespace \
   -o table
```
---


## Delegating access to a user
You can now assign access to a user for the managed namespace across member clusters using one of the [built-in roles](./concepts-fleet-managed-namespace.md#multi-cluster-managed-namespace-built-in-roles).
#### [Azure portal](#tab=azure-portal-4)
#### [Azure CLI](#tab=cli-4)

```azurecli-interactive
az role assignment create --role "Azure Kubernetes Fleet Manager Member Cluster RBAC Writer" --assignee <USER-ENTRA-ID> --scope $FLEET_ID/managedNamespaces/myManagedNamespace
```
---


## Deleting the multi-cluster managed namespace
To clean up, delete the managed namespace resource.

#### [Azure portal](#tab=azure-portal-5)
#### [Azure CLI](#tab=cli-5)
```azurecli-interactive
az fleet namespace delete \
    --name myManagedNamespace \
    --fleet-name $FLEET \
    --resource-group $GROUP
```
---






