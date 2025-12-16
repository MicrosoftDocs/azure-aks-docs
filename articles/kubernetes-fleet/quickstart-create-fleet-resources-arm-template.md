---
title: "Quickstart: Create an Azure Kubernetes Fleet Manager resource and join member clusters using ARM Template"
description: In this quickstart, you learn how to create an Azure Kubernetes Fleet Manager resource and join member clusters using ARM Template.
ms.date: 04/15/2025
author: muhammadali
ms.author: alimuhammad
ms.service: azure-kubernetes-fleet-manager
ms.custom: template-quickstart, mode-other
ms.devlang: azurecli
ms.topic: quickstart
---

# Quickstart: Create an Azure Kubernetes Fleet Manager using an ARM template

**Applies to:** :heavy_check_mark: Fleet Manager :heavy_check_mark: Fleet Manager with hub cluster

Get started with Azure Kubernetes Fleet Manager by using the ARM template to create a Fleet Manager resource.

## Before you begin

[!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

* Read the [conceptual overview of Fleet Manager](./concepts-fleet.md), which provides an explanation of fleets and member clusters referenced in this document.
* An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).

* [Install or upgrade Azure CLI](/cli/azure/install-azure-cli) to version `2.71.0` or later.
    - Ensure **fleet** extension is updated to version `1.5.2` or higher.


## Create a Fleet Manager

You can create a Fleet Manager resource to later group your AKS clusters as member clusters.  If the Fleet Manager hub is enabled, other preview features are enabled, such as Kubernetes object propagation to member clusters. For more information, see the [conceptual overview of Fleet Manager types](./concepts-choosing-fleet.md), which provides a comparison of different Fleet Manager configurations.


> [!IMPORTANT]
> Once a Fleet Manager resource has been created, it's possible to upgrade a Fleet Manager resource without a hub cluster to one with a hub cluster. For Fleet Manager resources with a hub cluster, once private or public has been selected it cannot be changed.


### [Fleet Manager without hub cluster](#tab/without-hub-cluster)

If you only want to use Fleet Manager for update orchestration, you can create a hubless Fleet Manager with the following ARM template:

##### Review the template
:::code language="json" source="~/quickstart-templates/quickstarts/microsoft.kubernetes/fleet-hubless/azuredeploy.json":::

#####  Deploy the template

1. Select **Deploy to Azure** to sign in and open a template.

    :::image type="content" source="~/reusable-content/ce-skilling/azure/media/template-deployments/deploy-to-azure-button.svg" alt-text="Button to deploy the Resource Manager template to Azure." border="false" link="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.kubernetes%2Ffleet-hubless%2Fazuredeploy.json":::

2. On the **Basics** page, configure the following template parameters

    - **Subscription**: Select an Azure subscription.
    - **Resource group**: Select **Create new**. Enter a unique name for the resource group, such as *myResourceGroup*, then select **OK**.
    - **Location**: Select a location, such as **East US**.
    - **Fleet Name**: Enter a unique name for the Fleet, such as *myFleet*.

3. Select **Review + Create** > **Create**.


### [Fleet Manager with hub cluster](#tab/with-hub-cluster)

If you want to use Fleet Manager for Kubernetes object propagation in addition to update orchestration, then you need to create the Fleet Manager resource with the hub cluster.

Fleet Manager clusters with a hub cluster support both public and private modes for network access. For more information, see [Choose an Azure Kubernetes Fleet Manager option](./concepts-choosing-fleet.md#network-access-modes-for-hub-cluster).

#### Public hub cluster
To create a public Fleet Manager resource with a hub cluster, use the following ARM template

##### Review the template
:::code language="json" source="~/quickstart-templates/quickstarts/microsoft.kubernetes/fleet-hubful/azuredeploy.json":::

#####  Deploy the template

1. Select **Deploy to Azure** to sign in and open a template.

    :::image type="content" source="~/reusable-content/ce-skilling/azure/media/template-deployments/deploy-to-azure-button.svg" alt-text="Button to deploy the Resource Manager template to Azure." border="false" link="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.kubernetes%2Ffleet-hubful%2Fazuredeploy.json":::

2. On the **Basics** page, configure the following template parameters

    - **Subscription**: Select an Azure subscription.
    - **Resource group**: Select **Create new**. Enter a unique name for the resource group, such as *myResourceGroup*, then select **OK**.
    - **Location**: Select a location, such as **East US**.
    - **Fleet Name**: Enter a unique name for the Fleet, such as *myFleet*.

3. Select **Review + Create** > **Create**.

#### Private hub cluster

[!INCLUDE [private-fleet-prerequisites.md](./includes/private-fleet/private-fleet-prerequisites.md)]


1. Fetch Fleet Manager's service principal object ID:

 ```azurecli-interactive
az ad sp list --display-name "Azure Kubernetes Service - Fleet RP" --query "[].{id:id}" --output tsv
```

```output
xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

2. Review the template

:::code language="json" source="~/quickstart-templates/quickstarts/microsoft.kubernetes/fleet-hubful-private/azuredeploy.json":::
    
3.  Deploy the ARM template with service principal object ID from first step
    
    - Select **Deploy to Azure** to sign in and open a template.
    
    :::image type="content" source="~/reusable-content/ce-skilling/azure/media/template-deployments/deploy-to-azure-button.svg" alt-text="Button to deploy the Resource Manager template to Azure." border="false" link="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.kubernetes%2Ffleet-hubful-private%2Fazuredeploy.json":::
    
    - On the **Basics** page, configure the following template parameters:
        - **Subscription**: Select an Azure subscription.
        - **Resource group**: Select **Create new**. Enter a unique name for the resource group, such as *myResourceGroup*, then select **OK**.
        - **Location**: Select a location, such as **East US**.
        - **Fleet Name**: Enter a unique name for the Fleet, such as *myFleet*.
        - **Vnet Name**: Enter a unique name for the virtual network, such as *myVnet*
        - **Fleet SP Object ID**: Enter the service principal object ID from **Step 1** output.

    - Select **Review + Create** > **Create**.

---

## Next steps

* [Access Fleet Manager hub cluster Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md).
* [Deploy cluster-scoped resources across multiple clusters](./quickstart-resource-propagation.md).
* [Deploy namespace-scoped resources across multiple clusters](./quickstart-namespace-scoped-resource-propagation.md).
* [Create and configure Managed Fleet Namespaces](./howto-managed-namespaces.md).
* [How-to: Upgrade multiple clusters using Azure Kubernetes Fleet Manager update runs](./update-orchestration.md).