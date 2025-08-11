---
title: "Use Azure Policy to ensure AKS clusters are enrolled with a Fleet Manager"
description: Learn how to use in-built Azure Policies to identify existing clusters that aren't managed by a Fleet Manager and to automatically add them to Fleet Manager.
ms.topic: how-to
ms.date: 08/11/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
# Customer intent: As a multi-cluster Kubernetes administrator, I want to ensure I can identify clusters not in a fleet and to automatically add new clusters to a fleet, so that I can ensure my clusters are managed in a consistent, centralized fashion.
---

# Use Azure Policy to ensure AKS clusters are enrolled with a Fleet Manager

Platform administrators can use Azure Policy to enforce consistency of fleet management for existing and new Azure Kubernetes Service clusters.

By using the built-in Azure Kubernetes Fleet Manager policies, it is possible to identify existing clusters that aren't managed by a Fleet Manager, while also ensuring that newly created clusters are automatically joined to a fleet.

## Available policies

Fleet Manager's policies are part of the [Kubernetes built-in policy][kubernetes-builtin-policies] set, with the following two policies relating to Fleet Manager.

It is recommended to use both policies to firstly identify existing clusters not managed by a Fleet Manager, and then ensure that new clusters are automatically enrolled.

* **Azure Kubernetes Service clusters should be a member of an Azure Kubernetes Fleet Manager**: Use this policy to identify any AKS clusters not managed by a Fleet Manager. It supports clusters that use either service principals or managed identities.

* **Configure AKS clusters to automatically join the specified Azure Kubernetes Fleet Manager**: Use this policy to ensure new AKS clusters automatically join a designated Fleet Manager. Only clusters using managed identities are supported.

## Prerequisites

* [!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
* You need a Kubernetes Fleet resource. If you don't have one, see [Create an Azure Kubernetes Fleet Manager resource and join member clusters by using the Azure CLI](quickstart-create-fleet-and-members.md).
* [Install or upgrade Azure CLI][azure-cli-install] to version `2.53.1` or later.
* You also need the `fleet` Azure CLI extension, which you can install by running the following command:

  ```azurecli-interactive
  az extension add --name fleet
  ```

  Run the [`az extension update`][az-extension-update] command to update to the latest version of the extension released:

  ```azurecli-interactive
  az extension update --name fleet
  ```

## Assign Autojoin Fleet Manager policy

You can apply a policy definition or initiative in the Azure portal using the following steps:

1. Navigate to the [Azure Policy](https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyMenuBlade/~/Overview) service in Azure portal.
1. In the left pane of the Azure Policy page, select **Authoring**, then **Definitions**.
1. From **Category** filter, select **Kubernetes**.
1. Select **Apply**.
1. Choose the **Configure AKS clusters to automatically join the specified Azure Kubernetes Fleet Manager fleet** Policy.
1. Select **Assign**.
1. Set the **Scope** to the Management Group, Subscription, or Resource Group where new AKS clusters are deployed.
1. Select whether **Policy enforcement** is enabled. Enabling ensures new AKS clusters join the specified Fleet Manager.
1. Select the **Parameters** page and set the Fleet Manager to use. 
1. Select **Review + create** > **Create** to submit the policy assignment.

## Validate policy is applied to new clusters

1. Follow the steps in the [Deploy an Azure Kubernetes Service (AKS) cluster using Azure CLI][aks-quickstart-cli] quickstart, selecting an Azure location covered by the previously applied policy definition.

1. Once the AKS cluster is created use the Azure CLI to verify it's a member cluster in the specified Fleet Manager by using the [`az fleet member list`][az-fleet-member-list] command. Substitute your AKS cluster name for `aks-member-1` in the `--query`.

    ```azurecli-interactive
    az fleet member list \
        --resource-group ${FLEET_GROUP} \
        --fleet-name ${FLEET_NAME} \
        --query "[?contains(Name, 'aks-member-1')]" -o table
    ```

    If successful, your output should look similar to the following example output:

    ```output
    ClusterResourceId                                                                                                                                Name          ProvisioningState    ResourceGroup
    -----------------------------------------------------------------------------------------------------------------------------------------------  ------------  -------------------  ---------------
    /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<GROUP>/providers/Microsoft.ContainerService/managedClusters/aks-member-1  aks-member-1  Succeeded            <GROUP>
    ```


## Related content

* [Azure Policy built-in definitions for Azure Kubernetes Fleet Manager][kubernetes-builtin-policies].

<!-- LINKS -->
[aks-quickstart-cli]: /azure/aks/learn/quick-kubernetes-deploy-cli
[azure-cli-install]: /cli/azure/install-azure-cli
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-fleet-member-list]: /cli/azure/fleet/member#az-fleet-member-list
[kubernetes-builtin-policies]: ../aks/policy-reference.md