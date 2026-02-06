---
title: "Quickstart: Create an Azure Kubernetes Fleet Manager and join member clusters using the Azure portal"
description: In this quickstart, you learn how to create an Azure Kubernetes Fleet Manager and join member clusters using the Azure portal.
ms.date: 02/06/2026
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.custom: template-quickstart, mode-other
ms.devlang: azurecli
ms.topic: quickstart
# Customer intent: As a cloud architect, I want to create an Azure Kubernetes Fleet Manager and join member clusters using the Azure portal, so that I can manage and orchestrate multiple Kubernetes clusters for improved scalability and application deployment.
---

# Quickstart: Create an Azure Kubernetes Fleet Manager and join member clusters using the Azure portal

**Applies to:** :heavy_check_mark: Fleet Manager :heavy_check_mark: Fleet Manager with hub cluster

Get started with Azure Kubernetes Fleet Manager by using the Azure portal to create a Fleet Manager and join [supported Kubernetes clusters](./concepts-member-cluster-types.md) as members.

## Before you begin

[!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

* Read the [conceptual overview of Fleet Manager](./concepts-fleet.md), which provides an explanation of fleets and member clusters referenced in this document.
* An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).
* An identity (user or service principal) with the following permissions:
    * **Fleet Manager:**
      * Microsoft.ContainerService/fleets/read
      * Microsoft.ContainerService/fleets/write
      * Microsoft.ContainerService/fleets/members/read
      * Microsoft.ContainerService/fleets/members/write
      * Microsoft.ContainerService/fleetMemberships/read
      * Microsoft.ContainerService/fleetMemberships/write
    * **AKS member clusters:**
      * Microsoft.ContainerService/managedClusters/read
      * Microsoft.ContainerService/managedClusters/write
      * Microsoft.ContainerService/managedClusters/listClusterUserCredential/action
    * **Arc-enabled Kubernetes member clusters:**
      * Microsoft.Kubernetes/connectedClusters/read
      * Microsoft.KubernetesConfiguration/extensions/read
      * Microsoft.KubernetesConfiguration/extensions/write
      * Microsoft.KubernetesConfiguration/extensions/delete

* Clusters you wish to join as members to Fleet must use supported versions of their respective platforms: see [AKS cluster version support policy](/azure/aks/supported-kubernetes-versions#kubernetes-version-support-policy) and [Azure Arc-enabled Kubernetes validation](/azure/azure-arc/kubernetes/validation-program).

## Create a Fleet Manager resource

1. Sign in to the [Azure portal](https://portal.azure.com/).
1. On the Azure portal home page, select **Create a resource**.
1. In the search box, enter **Kubernetes Fleet Manager** and select **Create > Kubernetes Fleet Manager** from the search results.
1. On the **Basics** tab, configure the following options:

    * Under **Project details**:
      * **Subscription**: Select the Azure subscription that you want to use.
      * **Resource group**: Select an existing resource group or select **Create new** to create a new resource group.
    * Under **Fleet details**:
      * **Name**: Enter a name for the Fleet Manager.
      * **Region**: Select the region where you want to create the Fleet Manager.
      * **Hub cluster mode**: Select one of the following options based on features you require:
        * **With hub cluster** multi-cluster Kubernetes resource placement, Managed Fleet Namespaces, DNS load balancing, and cluster upgrades. 
        * **Without hub cluster** safe multi-cluster Kubernetes and node image cluster upgrades, cluster observability.

      :::image type="content" source="./media/quickstart-create-fleet-and-members-portal/create-fleet-and-members-portal-basics.png" alt-text="Screenshot of the Create Fleet Manager basics tab in the Azure portal." lightbox="./media/quickstart-create-fleet-and-members-portal/create-fleet-and-members-portal-basics.png":::

1. Select **Next: Member clusters**.
1. Select **+ Add** to add existing clusters, filtering the cluster list by using the search box.

    :::image type="content" source="./media/quickstart-create-fleet-and-members-portal/create-fleet-and-members-portal-add-members-search.png" alt-text="Screenshot of the Create Fleet Manager add member cluster dialog in the Azure portal." lightbox="./media/quickstart-create-fleet-and-members-portal/create-fleet-and-members-portal-add-members-search.png":::

1. Select **Add** to add the selected clusters and close the list.
1. In them member list:
    * A **Name** is generated for the member cluster to uniquely identify it within Fleet Manager. Modify the generated name if as required.
    * Enter an **update group** for the member cluster so the cluster can be included in safe cluster updates when the group is included in an [update strategy](./update-create-update-strategy.md).

     :::image type="content" source="./media/quickstart-create-fleet-and-members-portal/create-fleet-and-members-portal-add-members-add-update-group-name.png" alt-text="Screenshot of the Create Fleet Manager add member cluster name and update group options in the Azure portal." lightbox="./media/quickstart-create-fleet-and-members-portal/create-fleet-and-members-portal-add-members-add-update-group-name.png":::

1. Select **Next: Advanced**.
1. On the **Advanced** tab, configure the following options:
    * Select **Private hub access** to provision a private hub cluster with [API server VNet integration](../aks/api-server-vnet-integration.md):
        * **Virtual network**: Select an existing Azure virtual network or select **Create new** to create a new virtual network.
        * **Cluster subnet**: Select a virtual network subnet for the hub cluster node.
        * **API server subnet**: Select a virtual network subnet for the hub cluster's API server integration. 
    * Select an existing [user-assigned managed identity](/entra/identity/managed-identities-azure-resources/overview#managed-identity-types) or select **Create new** to create a new user-assigned managed identity to be used by Fleet Manager.
    * Optionally, create one or more [Managed Fleet Namespaces](./concepts-fleet-managed-namespace.md) to provision with the Fleet Manager.

    :::image type="content" source="./media/quickstart-create-fleet-and-members-portal/create-fleet-and-members-portal-advanced.png" alt-text="Screenshot of the Create Fleet Manager advanced tab in the Azure portal." lightbox="./media/quickstart-create-fleet-and-members-portal/create-fleet-and-members-portal-advanced.png":::

1. Select **Next: Tags** and define any Azure resource tags to apply to the new Fleet Manager.
1. Select **Review + create** > **Create** to create the Fleet Manager.

It takes a few minutes to create the Fleet resource. When your deployment is complete, you can navigate to your resource by selecting **Go to resource**.

## Next steps

* [Access Fleet Manager hub cluster Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md).
* [Deploy cluster-scoped resources across multiple clusters](./quickstart-resource-propagation.md).
* [Deploy namespace-scoped resources across multiple clusters](./quickstart-namespace-scoped-resource-propagation.md).
* [Create and configure Managed Fleet Namespaces](./howto-managed-namespaces.md).
* [How-to: Upgrade multiple clusters using Azure Kubernetes Fleet Manager update runs](./update-orchestration.md).