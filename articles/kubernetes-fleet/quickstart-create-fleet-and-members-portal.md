---
title: "Quickstart: Create an Azure Kubernetes Fleet Manager resource and join member clusters using Azure portal"
description: In this quickstart, you learn how to create an Azure Kubernetes Fleet Manager resource and join member clusters using Azure portal.
ms.date: 03/20/2024
author: shashankbarsin
ms.author: shasb
ms.service: azure-kubernetes-fleet-manager
ms.custom: template-quickstart, mode-other
ms.devlang: azurecli
ms.topic: quickstart
# Customer intent: As a cloud architect, I want to create an Azure Kubernetes Fleet Manager resource and join member clusters, so that I can manage and orchestrate multiple Kubernetes clusters for improved scalability and application deployment.
---

# Quickstart: Create an Azure Kubernetes Fleet Manager resource and join member clusters using Azure portal

Get started with Azure Kubernetes Fleet Manager by using the Azure portal to create a Fleet Manager and join [supported Kubernetes clusters](./concepts-member-cluster-types.md) as members.

## Prerequisites

[!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

* Read the [conceptual overview of this feature](./concepts-fleet.md), which provides an explanation of fleets and member clusters referenced in this document.
* An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).
* An identity (user or service principal) with the following permissions for Fleet resources, and if applicable, member cluster resources:

* **Fleet permissions:**
  * Microsoft.ContainerService/fleets/read
  * Microsoft.ContainerService/fleets/write
  * Microsoft.ContainerService/fleets/members/read
  * Microsoft.ContainerService/fleets/members/write
  * Microsoft.ContainerService/fleetMemberships/read
  * Microsoft.ContainerService/fleetMemberships/write
* **If joining AKS member clusters:**
  * Microsoft.ContainerService/managedClusters/read
  * Microsoft.ContainerService/managedClusters/write
  * Microsoft.ContainerService/managedClusters/listClusterUserCredential/action
* **If joining Arc-enabled Kubernetes member clusters:**
  * Microsoft.Kubernetes/connectedClusters/read,
  * Microsoft.KubernetesConfiguration/extensions/read,
  * Microsoft.KubernetesConfiguration/extensions/write,
  * Microsoft.KubernetesConfiguration/extensions/delete,

* Clusters you wish to join as members to Fleet must use supported versions of their respective platforms: see [AKS cluster version support policy](/azure/aks/supported-kubernetes-versions#kubernetes-version-support-policy) and [Azure Arc-enabled Kubernetes validation](/azure/azure-arc/kubernetes/validation-program).

## Create a Fleet Manager resource

1. Sign in to the [Azure portal](https://portal.azure.com/).
2. On the Azure portal home page, select **Create a resource**.
3. In the search box, enter **Kubernetes Fleet Manager** and select **Create > Kubernetes Fleet Manager** from the search results.
4. On the **Basics** tab, configure the following options:

    * Under **Project details**:
      * **Subscription**: Select the Azure subscription that you want to use.
      * **Resource group**: Select an existing resource group or select **Create new** to create a new resource group.
    * Under **Fleet details**:
      * **Name**: Enter a unique name for the Fleet resource.
      * **Region**: Select the region where you want to create the Fleet resource.
      * **Hub cluster mode**: Leave the default selection of **With hub cluster** if you want to use Fleet Manager for Kubernetes object propagation and multi-cluster load balancing along with update orchestration. Select **Without hub cluster** if you want to use Fleet Manager only for update orchestration.

        :::image type="content" source="./media/quickstart-create-fleet-and-members-portal/create-fleet-and-members-portal-basics.png" alt-text="Screenshot of the Create Fleet resource basics tab in the Azure portal." lightbox="./media/quickstart-create-fleet-and-members-portal/create-fleet-and-members-portal-basics.png":::

5. Select **Next: Member clusters**.
6. On the **Member clusters** tab, select **Add** to add an existing cluster as a member cluster to the Fleet Manager. You can add multiple member clusters to the Fleet Manager.
7. Select **Review + create** > **Create** to create the Fleet resource.

    It takes a few minutes to create the Fleet resource. When your deployment is complete, you can navigate to your resource by selecting **Go to resource**.

## Next steps

* [Access Fleet hub cluster Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md).
