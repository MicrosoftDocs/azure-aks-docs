---
title: "Access the Kubernetes API for a Azure Kubernetes Fleet Manager Hub Cluster"
description: Learn how to access the Kubernetes API for an Azure Kubernetes Fleet Manager hub cluster.
ms.topic: how-to
ms.date: 04/01/2024
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-fleet-manager
zone_pivot_groups: public-hub-private-hub
# Customer intent: As a Kubernetes administrator, I want to access the Kubernetes API for my Azure Kubernetes Fleet Manager hub cluster, so that I can manage resource propagation and monitor member clusters.
---

:::zone target="docs" pivot="public-hub" 
**Applies to:** :heavy_check_mark: Fleet Manager with hub cluster

# Access the Kubernetes API for a Azure Kubernetes Fleet Manager hub cluster

If your Azure Kubernetes Fleet Manager (Kubernetes Fleet) resource was created with a hub cluster, you can use it to centrally control scenarios like Kubernetes resource propagation. In this article, you learn how to access the Kubernetes API for a Kubernetes Fleet hub cluster.

## Before you begin

* [!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
* You need a Kubernetes Fleet resource with a hub cluster and member clusters. If you don't have one, see [Create an Azure Kubernetes Fleet Manager resource and join member clusters by using the Azure CLI](quickstart-create-fleet-and-members.md).
* The identity (user or service principal) that you're using needs to have Microsoft.ContainerService/fleets/listCredentials/action permissions on the Kubernetes Fleet resource.

:::zone-end


:::zone target="docs" pivot="private-hub"

# Access the Kubernetes API for a Azure Kubernetes Fleet Manager hub cluster

If your Azure Kubernetes Fleet Manager (Kubernetes Fleet) resource was created with a private hub cluster, you can use it to centrally control scenarios like Kubernetes resource propagation. In this article, you learn how to access the Kubernetes API for a private Kubernetes Fleet hub cluster securely using Azure Bastion's native client tunneling feature.

Using Azure Bastion protects your private hub cluster from exposing endpoints to the outside world, while still providing secure access. For more information, see [What is Azure Bastion?](https://docs.azure.cn/en-us/bastion/bastion-overview)


## Before you begin

* [!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
* You need a Kubernetes Fleet resource with a hub cluster and member clusters. If you don't have one, see [Create an Azure Kubernetes Fleet Manager resource and join member clusters by using the Azure CLI](quickstart-create-fleet-and-members.md).
* You need a virtual network with the Bastion host already installed.
  * Ensure that you have set up an Azure Bastion host for the virtual network in which the Fleet Manager is located. To set up an Azure Bastion host, see [Quickstart: Deploy Bastion with default settings](https://docs.azure.cn/en-us/bastion/quickstart-host-portal).
  * The Bastion must be Standard or Premium SKU and have native client support enabled under configuration settings.
* The identity (user or service principal) that you're using needs to have:
  * Microsoft.ContainerService/fleets/listCredentials/action permissions on the Kubernetes Fleet resource.
  * Microsoft.Network/bastionHosts/read	on the Bastion Resource.
  * Microsoft.Network/virtualNetworks/read on the virtual network of the private hub cluster.

:::zone-end

## Access the Kubernetes API

1. Set the following environment variables for your subscription ID, resource group, and Kubernetes Fleet resource:

    ```azurecli-interactive
    export SUBSCRIPTION_ID=<subscription-id>
    export GROUP=<resource-group-name>
    export FLEET=<fleet-name>
    ```

2. Set the default Azure subscription by using the [`az account set`][az-account-set] command:

    ```azurecli-interactive
    az account set --subscription ${SUBSCRIPTION_ID}
    ```

3. Get the kubeconfig file of the Kubernetes Fleet hub cluster by using the [`az fleet get-credentials`][az-fleet-get-credentials] command:

    ```azurecli-interactive
    az fleet get-credentials --resource-group ${GROUP} --name ${FLEET}
    ```

   Your output should look similar to the following example:

    ```output
    Merged "hub" as current context in /home/fleet/.kube/config
    ```

4. Set the following environment variable for the `FLEET_ID` value of the hub cluster's Kubernetes Fleet resource:

    ```azurecli-interactive
    export FLEET_ID=/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${GROUP}/providers/Microsoft.ContainerService/fleets/${FLEET}
    ```

5. Authorize your identity to access the Kubernetes Fleet hub cluster by using the following commands.

   For the `ROLE` environment variable, you can use one of the following four built-in role definitions as the value:

    * Azure Kubernetes Fleet Manager RBAC Reader
    * Azure Kubernetes Fleet Manager RBAC Writer
    * Azure Kubernetes Fleet Manager RBAC Admin
    * Azure Kubernetes Fleet Manager RBAC Cluster Admin

    ```azurecli-interactive
    export IDENTITY=$(az ad signed-in-user show --query "id" --output tsv)
    export ROLE="Azure Kubernetes Fleet Manager RBAC Cluster Admin"
    az role assignment create --role "${ROLE}" --assignee ${IDENTITY} --scope ${FLEET_ID}
    ```

   Your output should look similar to the following example:

    ```output
    {
      "canDelegate": null,
      "condition": null,
      "conditionVersion": null,
      "description": null,
      "id": "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<GROUP>/providers/Microsoft.ContainerService/fleets/<FLEET>/providers/Microsoft.Authorization/roleAssignments/<assignment>",
      "name": "<name>",
      "principalId": "<id>",
      "principalType": "User",
      "resourceGroup": "<GROUP>",
      "roleDefinitionId": "/subscriptions/<SUBSCRIPTION_ID>/providers/Microsoft.Authorization/roleDefinitions/18ab4d3d-a1bf-4477-8ad9-8359bc988f69",
      "scope": "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<GROUP>/providers/Microsoft.ContainerService/fleets/<FLEET>",
      "type": "Microsoft.Authorization/roleAssignments"
    }
    ```
:::zone target="docs" pivot="public-hub"
6. Verify that you can access the API server by using the `kubectl get memberclusters` command:

    ```bash
    kubectl get memberclusters
    ```

   If the command is successful, your output should look similar to the following example:

    ```output
    NAME           JOINED   AGE
    aks-member-1   True     2m
    aks-member-2   True     2m
    aks-member-3   True     2m
    ```
:::zone-end

:::zone target="docs" pivot="private-hub"

6. Open the tunnel to your Private Fleet Manager's hub cluster:
    ```bash
    export HUB_CLUSTER_ID=<hub-cluster-id-in-FL_resourceGroup>
    az network bastion tunnel --name <BastionName> --resource-group ${GROUP} --target-resource-id ${HUB_CLUSTER_ID}$ --resource-port 443 --port <LocalMachinePort>
    ```

7. In a new terminal window, connect to the hub cluster through the Bastion tunnel and verify API server access:

    ```bash
    kubectl get memberclusters --server=https://localhost:<LocalMachinePort>
    ```

   If the command is successful, your output should look similar to the following example:

    ```output
    NAME           JOINED   AGE
    aks-member-1   True     2m
    aks-member-2   True     2m
    aks-member-3   True     2m
    ```
:::zone-end

:::zone-end


## Related content

* [Propagate resources from an Azure Kubernetes Fleet Manager hub cluster to member clusters](./quickstart-resource-propagation.md)

<!-- LINKS --->
[az-fleet-get-credentials]: /cli/azure/fleet#az-fleet-get-credentials
[az-account-set]: /cli/azure/account#az-account-set
