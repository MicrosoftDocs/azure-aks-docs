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

# Quickstart: Create Azure Kubernetes Fleet Manager using an ARM template

Get started with Azure Kubernetes Fleet Manager (Fleet) by using the ARM template to create a Fleet resource and later connect Azure Kubernetes Service (AKS) clusters as member clusters.

## Prerequisites

[!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

* Read the [conceptual overview of this feature](./concepts-fleet.md), which provides an explanation of fleets and member clusters referenced in this document.
* An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).

* [Install or upgrade Azure CLI](/cli/azure/install-azure-cli) to version `2.71.0` or later.
    - Ensure **fleet** extension is updated to version `1.5.2` or higher.


## Create a Fleet resource

You can create a Fleet resource to later group your AKS clusters as member clusters. When created via Azure CLI, by default, this resource enables member cluster grouping and update orchestration. If the Fleet hub is enabled, other preview features are enabled, such as Kubernetes object propagation to member clusters and L4 service load balancing across multiple member clusters. For more information, see the [conceptual overview of fleet types](./concepts-choosing-fleet.md), which provides a comparison of different fleet configurations.


> [!IMPORTANT]
> Once a Kubernetes Fleet resource has been created, it's possible to upgrade a Kubernetes Fleet resource without a hub cluster to one with a hub cluster. For Kubernetes Fleet resources with a hub cluster, once private or public has been selected it cannot be changed.


### [Kubernetes Fleet resource without hub cluster](#tab/without-hub-cluster)

If you want to use Fleet only for update orchestration, you can create a hubless Fleet with the following ARM template:

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


### [Kubernetes Fleet resource with hub cluster](#tab/with-hub-cluster)
If you want to use Fleet for Kubernetes object propagation and multi-cluster load balancing in addition to update orchestration, then you need to create the Fleet resource with the hub cluster.

Kubernetes Fleet clusters with a hub cluster support both public and private modes for network access. For more information, see [Choose an Azure Kubernetes Fleet Manager option](./concepts-choosing-fleet.md#network-access-modes-for-hub-cluster).

#### Public hub cluster
To create a public Kubernetes Fleet resource with a hub cluster, use the following ARM template

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
When creating a private access mode Kubernetes Fleet resource with a hub cluster, some extra considerations apply:
- Fleet requires you to provide the subnet on which the Fleet hub cluster's node VMs will be placed. This can be done by setting `subnetId` in the `agentProfile` within the Fleet's `hubProfile`.
-  The address prefix of the vnet **vnet_name** must not overlap with the AKS default service range of `10.0.0.0/16`.
- When using an AKS private cluster, you have the ability to configure fully qualified domain names (FQDNs) and FQDN subdomains. This functionality doesn't apply to the private access mode type hub cluster.
- Private access mode requires a `Network Contributor` role assignment on the agent subnet for Fleet's first party service principal. This is **NOT** needed when creating private fleet using the `az fleet create` command because the CLI automatically creates the role assignment.

##### Fetch Fleet's service principal object ID:

 ```azurecli-interactive
az ad sp list --display-name "Azure Kubernetes Service - Fleet RP" --query "[].{id:id}" --output tsv
```

```output
xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

##### Review the template

:::code language="json" source="~/quickstart-templates/quickstarts/microsoft.kubernetes/fleet-hubful-private/azuredeploy.json":::
    
#####  Deploy the template
Deploy the ARM template with service principal object ID from first step:

    
1. Select **Deploy to Azure** to sign in and open a template.
:::image type="content" source="~/reusable-content/ce-skilling/azure/media/template-deployments/deploy-to-azure-button.svg" alt-text="Button to deploy the Resource Manager template to Azure." border="false" link="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.kubernetes%2Ffleet-hubful-private%2Fazuredeploy.json":::
    
2. On the **Basics** page, configure the following template parameters:
    - **Subscription**: Select an Azure subscription.
    - **Resource group**: Select **Create new**. Enter a unique name for the resource group, such as *myResourceGroup*, then select **OK**.
    - **Location**: Select a location, such as **East US**.
    - **Fleet Name**: Enter a unique name for the Fleet, such as *myFleet*.
    - **Vnet Name**: Enter a unique name for the virtual network, such as *myVnet*
    - **Fleet SP Object ID**: Enter the service principal object ID from **Step 1** output.

3. Select **Review + Create** > **Create**.

---

## Next steps

* [Access Fleet hub cluster Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md).