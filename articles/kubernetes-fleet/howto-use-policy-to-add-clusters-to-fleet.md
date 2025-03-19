---
title: "Use Azure Policy to ensure AKS clusters are manged by Azure Kubernetes Fleet Manager"
description: Learn how to use in-bulit Azure Policies to enable Fleet auto-join for new AKS clusters.
ms.topic: how-to
ms.date: 03/19/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
---

# Use Azure Policy to ensure AKS clusters are manged by Azure Kubernetes Fleet Manager (preview)

Fleet administrators can use Azure Policy to ensure that new Azure Kubernetes Service clusters are automatically added to an existing Azure Kubernetes Fleet Manager instance.

Auto-join of AKS clusters to a fleet ensures that new a cluster lifecycle and workload placement configuration is managed exactly the same as existing clusters. 

Fleet Manager's Azure Policies are bundled with those for AKS as the policies are applied to clusters and not to Fleet Manager.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

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

## Assign Fleet Manager's built-in policy definition or initiative

You can apply a policy definition or initiative in the Azure portal using the following steps:

1. Navigate to the [Azure Policy](https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyMenuBlade/~/Overview) service in Azure portal.
1. In the left pane of the Azure Policy page, select **Authoring**, then **Definitions**.
1. From **Category** filter, select `Kubernetes`.
1. Select **Apply**.
1. Choose the **Configure AKS clusters to automatically join the specified Azure Kubernetes Fleet Manager fleet** Policy.
1. Select **Assign**.
1. Set the **Scope** to the Management Group, Subscription or Resource Group where new AKS clusters will be deployed.
1. Select whether **Policy enforcement** is enabled. Enabling will ensure new AKS clusters join the specified fleet.
1. Select the **Parameters** page and set the Fleet Manager instance to use. 
1. Select **Review + create** > **Create** to submit the policy assignment.

## Validate application of policy

1. Follow the steps in the [Deploy an Azure Kubernetes Service (AKS) cluster using Azure CLI][aks-quickstart-cli] quickstart, selecting an Azure location covered by the previously applied policy definition.

1. Once the AKS cluster has been created use the Azure CLI verify the cluster is joined to the specified Fleet Manager fleet as a member cluster by using the [`az fleet member list`][az-fleet-member-list] command. Substitute your AKS cluster name for `aks-member-1` in the `--query`.

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

* [Azure Policy built-in definitions for Azure Kubernetes Fleet Manager](./policy-reference.md).

<!-- LINKS -->
[aks-quickstart-cli]: /azure/aks/learn/quick-kubernetes-deploy-cli
[azure-cli-install]: /cli/azure/install-azure-cli
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-fleet-member-list]: /cli/azure/fleet/member#az-fleet-member-list