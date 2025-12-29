---
title: Create and configure Managed Fleet Namespaces with Azure Kubernetes Fleet Manager
description: Learn how to create Managed Fleet Namespaces to define resource quotas, network policies, and to delegate user access to namespaces on multiple clusters.
author: sjwaight
ms.author: simonwaight
ms.topic: how-to
ms.date: 12/19/2025
ms.service: azure-kubernetes-fleet-manager
zone_pivot_groups: azure-portal-azure-cli
# Customer intent: "As a platform admin, I want to define a namespace and deploy it across selected fleet clusters so I can delegate application teams access to resources on any cluster where the namespace exists."
---
# Create and configure Managed Fleet Namespaces (preview)

**Applies to:** :heavy_check_mark: Fleet Manager with hub cluster

This article shows you how to use Fleet Manager to create and configure a Managed Fleet Namespace that defines resource quotas, network policies, and delegated user access for the namespaces on multiple clusters.

If you're looking to view or access existing Managed Fleet Namespaces you have access to, see [view and access Managed Fleet Namespaces](./howto-managed-namespaces-access.md).

[!INCLUDE [preview_features_note](./includes/preview/preview-callout.md)]

## Known limitations

* When a Managed Fleet Namespace adopts a single cluster [Managed Kubernetes Namespace](../aks/concepts-managed-namespaces.md) or vice versa, it may lead to conflicting ownership. To avoid, use a delete policy of `keep` for both the Managed Fleet and Kubernetes Namespaces.
* Clusters you specify must be members of the fleet managed by the same Fleet Manager hosting the Managed Fleet Namespace.
* Clusters must have a Kubernetes version of at least 1.30.0. Clusters below this version **will not** block users on the cluster from modifying the placed Kubernetes resources.
* RBAC roles assigned to a Managed Fleet Namespace scope will grant equivalent access to any unmanaged Kubernetes namespaces on member clusters with the same name.

## Before you begin

* You need an Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).
* You need a Fleet Manager with a hub cluster. If you don't have one, see [create and join at least one Azure Kubernetes Service (AKS) cluster to the fleet](./quickstart-create-fleet-and-members.md).
* Ensure user performing steps has the [Role Based Access Control Administrator][rbac-admin] role assigned for the Fleet Manager.
* Understand the Managed Fleet Namespace concept by [reading the overview](./concepts-fleet-managed-namespace.md).

:::zone target="docs" pivot="azure-cli"

* You need Azure CLI version 2.78.0 or later installed to complete this article. To install or upgrade, see [Install Azure CLI][az-aks-install-cli].
* You need the `fleet` Azure CLI extension version 1.8.0 or later. You can install it and update to the latest version using the [`az extension add`][az-extension-add] and [`az extension update`][az-extension-update] commands.
	
    ```azurecli-interactive
    # Install the extension
    az extension add --name fleet
	
    # Update the extension
    az extension update --name fleet
    ```

* Confirm the fleet extension version is at least 1.8.0 using the [`az extension show`](/cli/azure/extension#az-extension-show) command.
	
    ```azurecli-interactive
    az extension show --name fleet
    ```

* Set the following environment variables for your subscription ID, resource group, Fleet, and Fleet Member:

    ```bash
    export SUBSCRIPTION_ID=<subscription-id>
    export GROUP=<resource-group-name>
    export FLEET=<fleet-name>
    export FLEET_ID=<fleet-id>
    ```

* Set the default Azure subscription using the [`az account set`][az-account-set] command.
	
    ```azurecli-interactive
    az account set --subscription ${SUBSCRIPTION_ID}
    ```

## Create a new Managed Fleet Namespace 

Create a new multi-cluster managed namespace using the [`az fleet namespace create`](/cli/azure/fleet/namespace#az-fleet-namespace-create) command.

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

> [!NOTE]
> These settings are optional: networking policies, compute quota, deletion and adoption policy, labels and annotations. 
>
> When using networking policies, users with a `Microsoft.ContainerService/managedClusters/networking.k8s.io/networkpolicies/write` action, such as `Azure Kubernetes Service RBAC Writer`, on the Microsoft Entra ID role they're assigned can add more network policies through the Kubernetes API.
>
> For example, if an admin applies a `Deny All` policy for ingress/egress, and a user applies an `Allow` policy for a namespace via the Kubernetes API, the `Allow` policy takes priority over the `Deny All` policy, and traffic is allowed to flow for the namespace. This additive behavior is standard for networking policies.

## Assign user or group access

You can now grant access to a user for the Managed Fleet Namespace across member clusters using one of the [Azure RBAC built-in roles](./concepts-fleet-managed-namespace.md#managed-fleet-namespace-built-in-roles).

Create a role assignment using the [`az role assignment create`](/cli/azure/role/assignment#az-role-assignment-create) command. 

The following example assigns a user the _Azure Kubernetes Fleet Manager RBAC Writer for Member Clusters_ role on any cluster that receives the `my-managed-namespace` Managed Fleet Namespace:

```azurecli-interactive
az role assignment create \
    --role "Azure Kubernetes Fleet Manager RBAC Writer for Member Clusters" \
    --assignee <USER-ENTRA-ID> \
    --scope "$FLEET_ID/managedNamespaces/my-managed-namespace"
```

## Add member clusters

You can control which member clusters to deploy the managed namespace to by specifying the desired list of member cluster names. Any unmanaged namespaces with the same name on member clusters not in the specified list remain untouched.

Specify the full list of member clusters you want to deploy the managed namespace to using the [`az fleet namespace create`](/cli/azure/fleet/namespace#az-fleet-namespace-create) command with the `--member-cluster-names` parameter. The managed namespace is propagated to all clusters in the list.

In this example, the managed namespace is deployed to `clusterA`, `clusterB`, and `clusterC`.

```azurecli-interactive
az fleet namespace create \
    --resource-group $GROUP \
    --fleet-name $FLEET \
    --name my-managed-namespace \
    --member-cluster-names clusterA clusterB clusterC
```

## Remove member clusters

You can remove member clusters from a Managed Fleet Namespace by excluding them from the list of member clusters you want the namespace on.

Specify the list of member clusters you want the managed namespace to remain on using the [`az fleet namespace create`](/cli/azure/fleet/namespace#az-fleet-namespace-create) command with the `--member-cluster-names` parameter. The managed namespace is removed from any clusters excluded from the list.

In this example, the managed namespace is removed from `clusterC`.

```azurecli-interactive
az fleet namespace create \
    --resource-group $GROUP \
    --fleet-name $FLEET \
    --name my-managed-namespace \
    --member-cluster-names clusterA clusterB
```

## View a Managed Fleet Namespace's configuration

View a specific multi-cluster managed namespace's details by using the [`az fleet namespace show`](/cli/azure/fleet/namespace#az-fleet-namespace-show) command.

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

## Delete a Managed Fleet Namespace

Delete a multi-cluster managed namespace using the [`az fleet namespace delete`](/cli/azure/fleet/namespace#az-fleet-namespace-delete) command.

```azurecli-interactive
az fleet namespace delete \
    --resource-group $GROUP \
    --fleet-name $FLEET \
    --name my-managed-namespace 
```

> [!IMPORTANT]
> RBAC roles placed on the managed namespace are deleted when the managed namespace is deleted, regardless of the delete policy configuration.

:::zone-end

:::zone target="docs" pivot="azure-portal"

## Create a new Managed Fleet Namespace 

You can create a new Managed Fleet Namespace from within Fleet Manager, or via Kubernetes center.

Starting in Fleet Manager:

* In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
* From the left menu, under **Fleet Resources**, select **Namespaces**.
* From the menu select **+ Create**, then **Managed Fleet Namespace**.

:::image type="content" source="./media/managed-namespace/create-managed-fleet-namespace-01.png" alt-text="Screenshot of the Azure portal menu for creating a Managed Fleet Namespace in Azure Kubernetes Fleet Manager." lightbox="./media/managed-namespace/create-managed-fleet-namespace-01.png":::

Starting in Kubernetes center:

* Open [Kubernetes center - Managed namespaces](https://portal.azure.com/#view/Microsoft_Azure_KubernetesFleet/KubernetesHub.MenuView/~/managedNamespaces) in the Azure portal.
* From the menu select **+ Create**, then **Managed Fleet Namespace**.
* Select a **Subscription** and **Fleet Manager** instance.

:::image type="content" source="./media/managed-namespace/create-managed-fleet-namespace-kubernetes-center-01.png" alt-text="Screenshot of the Azure portal Kubernetes Center menu for creating a Managed Fleet Namespace." lightbox="./media/managed-namespace/create-managed-fleet-namespace-kubernetes-center-01.png":::

* Select one of the following options for **Scope**:
    * **New** - create a new Kubernetes namespace that doesn't exist on the Fleet Manager hub cluster. Enter a **Name** for the new namespace.
    * **Convert to Managed** - use an existing Kubernetes namespace on the Fleet Manager hub cluster. Select the **Namespace** from the list of namespaces on the Fleet Manager hub cluster.

:::image type="content" source="./media/managed-namespace/create-managed-fleet-namespace-02.png" alt-text="Screenshot of the Azure portal showing the Basics tab with Project details completed for a new Managed Fleet Namespace." lightbox="./media/managed-namespace/create-managed-fleet-namespace-02.png":::

## Assign user or group access

Select the Microsoft Entra users and groups that will access the Managed Fleet Namespace on clusters it is distributed to.

:::image type="content" source="./media/managed-namespace/create-managed-fleet-namespace-03.png" alt-text="Screenshot of the Azure portal showing completed Access details for a new Managed Fleet Namespace." lightbox="./media/managed-namespace/create-managed-fleet-namespace-03.png":::

> [!NOTE]
> This step is optional. You can create and distribute a Managed Fleet Namespace without assigning users or groups. This allows you to distribute the namespace without granting access immediately.

## Add network policies and compute quota

Set policies and quota.

:::image type="content" source="./media/managed-namespace/create-managed-fleet-namespace-04.png" alt-text="Screenshot of the Azure portal showing completed Networking policies and Compute quota for a new Managed Fleet Namespace." lightbox="./media/managed-namespace/create-managed-fleet-namespace-04.png":::

> [!NOTE]
> These settings are optional. This allows you to create and distribute a Managed Fleet Namespace without networking policies or quota controls applied immediately.
>
> Users with a `Microsoft.ContainerService/managedClusters/networking.k8s.io/networkpolicies/write` action, such as `Azure Kubernetes Service RBAC Writer`, on the Microsoft Entra ID role they're assigned can add more network policies through the Kubernetes API.
>
> For example, if an admin applies a `Deny All` policy for ingress/egress, and a user applies an `Allow` policy for a namespace via the Kubernetes API, the `Allow` policy takes priority over the `Deny All` policy, and traffic is allowed to flow for the namespace. This additive behavior is standard for networking policies.

## Select member clusters

You can control which member clusters to distribute the managed namespace to by adding them as follows. Any unmanaged namespaces with the same name on member clusters not in the specified list remain untouched.

* From the menu select **+ Add**.
* In the **Select member clusters** dialog search for the member clusters, selecting them by checking the box.
* Finally, choose **Select** to add the member clusters.

:::image type="content" source="./media/managed-namespace/create-managed-fleet-namespace-05.png" alt-text="Screenshot of the Azure portal showing two member clusters selected to host a new Managed Fleet Namespace." lightbox="./media/managed-namespace/create-managed-fleet-namespace-05.png":::

## Set labels, annotations and tags

Define optional Kubernetes labels and annotations, and Azure Resource Manager (ARM) tags which provide metadata that can be used for automation and resource management.

:::image type="content" source="./media/managed-namespace/create-managed-fleet-namespace-06.png" alt-text="Screenshot of the Azure portal showing settings for labels and annotations for a new Managed Fleet Namespace." lightbox="./media/managed-namespace/create-managed-fleet-namespace-06.png":::

## Create and distribute

Once you have configured all properties for the new Managed Fleet Namespace you can confirm the details before creating the namespace by selecting **Create**.

An Azure Resource Manager deployment is immediately started, which initiates a Fleet Manager workload placement to distribute the namespace to the selected clusters.

Once the deployment is completed, you can find the Managed Fleet Namespace in the list of namespaces for the Fleet Manager. 

:::image type="content" source="./media/managed-namespace/create-managed-fleet-namespace-view.png" alt-text="Screenshot of the Azure portal showing the new Managed Fleet Namespace listed with the namespaces on the Fleet Manager hub cluster." lightbox="./media/managed-namespace/create-managed-fleet-namespace-view.png":::

To review the rollout of the Kubernetes namespace across clusters, use [Resource placements](./quickstart-resource-propagation.md#use-clusterresourceplacement-to-place-resources-onto-member-clusters), looking for the resource placement named the same as the Managed Fleet Namespace.

:::image type="content" source="./media/managed-namespace/create-managed-fleet-namespace-crp-status.png" alt-text="Screenshot of the Azure portal showing the resource placement status of the new Managed Fleet Namespace." lightbox="./media/managed-namespace/create-managed-fleet-namespace-crp-status.png":::

## Remove member clusters from a Managed Fleet Namespace

You can remove member clusters from a Managed Fleet Namespace by excluding them from the list of member clusters you want the namespace on.

## View a Managed Fleet Namespace's configuration

View a specific multi-cluster managed namespace's details by using the [`az fleet namespace show`](/cli/azure/fleet/namespace#az-fleet-namespace-show) command.

## Delete a Managed Fleet Namespace

Delete a multi-cluster managed namespace using the [`az fleet namespace delete`](/cli/azure/fleet/namespace#az-fleet-namespace-delete) command.

:::zone-end

## Next steps

- Understand the concept of Managed Fleet Namespaces by [reading the overview](./concepts-fleet-managed-namespace.md).
- Learn how to [view and access Managed Fleet namespaces you have access to](./howto-managed-namespaces-access.md).

<!-- INTERNAL LINKS -->
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-account-set]: /cli/azure/account#az-account-set
[az-extension-add]: /cli/azure/extension#az-extension-add
[rbac-admin]: /azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator
[entra-role-portal]: /entra/fundamentals/how-to-assign-roles-to-users