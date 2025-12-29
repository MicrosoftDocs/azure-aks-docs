---
title: View and access Managed Fleet Namespaces using Azure Kubernetes Fleet Manager
description: Learn how to find and access your Managed Fleet Namespaces.
author: sjwaight
ms.author: simonwaight
ms.topic: how-to
ms.date: 12/19/2025
ms.service: azure-kubernetes-fleet-manager
zone_pivot_groups: azure-portal-azure-cli
# Customer intent: "As an application developer or team lead, I want to find the managed namespaces I have access to and monitor their resource usage across all clusters so I can understand deployment status and determine if quota adjustments are needed."
---
# View and access Managed Fleet Namespaces (preview)

**Applies to:** :heavy_check_mark: Fleet Manager with hub cluster

This article is intended for users of a managed namespace who need to discover and access those namespaces. If you're looking to create and configure managed namespaces, see [create and configure Managed Fleet Namespaces](./howto-managed-namespaces.md).

[!INCLUDE [preview_features_note](./includes/preview/preview-callout.md)]

## Before you begin 

* You need an Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).
* You need an existing Managed Fleet Namespace. If you don't have one, see [create and configure Managed Fleet Namespaces](./howto-managed-namespaces.md).
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

* Set the following environment variables for your subscription ID, resource group, and Fleet:

    ```bash
    export SUBSCRIPTION_ID=<subscription-id>
    export GROUP=<resource-group-name>
    export FLEET=<fleet-name>
    export FLEET_NAMESPACE_NAME=<fleet-namespace-name>
    ```

* Set the default Azure subscription using the [`az account set`][az-account-set] command.

    ```azurecli-interactive
    az account set --subscription ${SUBSCRIPTION_ID}
    ```

## View the Managed Fleet Namespaces you can access

View the Managed Fleet Namespaces you can access using the [`az fleet namespace list`](/cli/azure/fleet/namespace#az-fleet-namespace-list) command.

```azurecli-interactive
az fleet namespace list  
    --resource-group ${GROUP} \ 
    --fleet-name ${FLEET} \ 
    -o table 
```

Your output should resemble the following example output:

```output
AdoptionPolicy  DeletePolicy   ETag                                    Location   Name                  ProvisioningState   ResourceGroup
--------------  ------------   -------------------------------------   --------   --------------------  -----------------   -------------
Always          Delete         "aaaaaaaa-0b0b-1c1c-2d2d-333333333333   westus2    my-managed-namespace  Succeeded           test-rg
```

## View a Managed Fleet Namespace's configuration

View a specific Managed Fleet Namespace's details by using the [`az fleet namespace show`](/cli/azure/fleet/namespace#az-fleet-namespace-show) command.

```azurecli-interactive
az fleet namespace show \ 
    --resource-group ${GROUP} \ 
    --fleet-name ${FLEET} \ 
    --name ${FLEET_NAMESPACE_NAME} \ 
    -o table 
```

Your output should resemble the following example output:
```output
AdoptionPolicy  DeletePolicy   ETag                                    Location   Name                  ProvisioningState   ResourceGroup
--------------  ------------   -------------------------------------   --------   --------------------  -----------------   -------------
Always          Delete         "aaaaaaaa-0b0b-1c1c-2d2d-333333333333   westus2    my-managed-namespace  Succeeded           test-rg
```

:::zone-end

:::zone target="docs" pivot="azure-portal"

## View Managed Fleet Namespaces you can access

You can locate Managed Fleet Namespace from within Fleet Manager, or via Kubernetes center.

Starting in Fleet Manager:

* In the Azure portal, navigate to your Azure Kubernetes Fleet Manager resource.
* From the left menu, under **Fleet Resources**, select **Namespaces**.
* Managed Fleet Namespaces you have access to are shown in the namespaces list.

:::image type="content" source="./media/managed-namespace/view-managed-fleet-namespace-fleet-manager.png" alt-text="Screenshot of the Azure portal showing the list of namespaces including the Managed Fleet Namespace." lightbox="./media/managed-namespace/view-managed-fleet-namespace-in-fleet-manager.png":::

Starting in Kubernetes center:

* Open [Kubernetes center - Managed namespaces](https://portal.azure.com/#view/Microsoft_Azure_KubernetesFleet/KubernetesHub.MenuView/~/managedNamespaces) in the Azure portal.
* Set the **Type** filter to **Managed Fleet Namespace**.
* Managed Fleet Namespaces you have access to are shown in the namespaces list.

:::image type="content" source="./media/managed-namespace/view-managed-fleet-namespace-kubernetes-center.png" alt-text="Screenshot of the Azure portal showing the list of Managed namespaces in Kubernetes center filtered to Managed Fleet Namespace." lightbox="./media/managed-namespace/view-managed-fleet-namespace-kubernetes-center.png":::

## View Managed Fleet Namespace configuration

View a Managed Fleet Namespace's configuration on its overview by selecting the namespace from the list.

:::image type="content" source="./media/managed-namespace/view-managed-fleet-namespace-overview.png" alt-text="Screenshot of the Azure portal showing the overview screen for a Managed Fleet Namespace." lightbox="./media/managed-namespace/view-managed-fleet-namespace-overview.png":::

## View Managed Fleet Namespace member clusters

From the Managed Fleet Namespace overview select **Member clusters** on the left navigation to view the member clusters the namespace is distributed to.

:::image type="content" source="./media/managed-namespace/view-managed-fleet-namespace-member-clusters.png" alt-text="Screenshot of the Azure portal showing the member clusters that host the selected Managed Fleet Namespace." lightbox="./media/managed-namespace/view-managed-fleet-namespace-member-clusters.png"::: 

:::zone-end

## Access a Managed Fleet Namespace 

You can retrieve the kubeconfig to access a Managed Fleet Namespace on either the Fleet Manager hub cluster, or on a specific member cluster. If you access the hub cluster, you can utilize Fleet Manager's [intelligent resource placement](intelligent-resource-placement.md) to replicate your resources to member clusters, avoiding the need to manually redeploy the same artifacts on each cluster.

Get credentials to access the namespace on the Fleet Manager hub cluster using the following command. 

```azurecli-interactive
az fleet namespace get-credentials \ 
    --resource-group ${GROUP} \ 
    --fleet-name ${FLEET} \ 
    --name ${FLEET_NAMESPACE_NAME}
```

Get credentials to access the namespace on member cluster by providing the `member` parameter. 

```azurecli-interactive
az fleet namespace get-credentials \ 
    --resource-group ${GROUP} \ 
    --fleet-name ${FLEET} \ 
    --name ${FLEET_NAMESPACE_NAME} \ 
    --member myMemberCluster
```

## Next steps

* Understand the concept of Managed Fleet Namespaces by [reading the overview](./concepts-fleet-managed-namespace.md).
* Learn how to [create and configure a Managed Fleet Namespace](./howto-managed-namespaces.md).

<!-- INTERNAL LINKS -->
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-account-set]: /cli/azure/account#az-account-set
