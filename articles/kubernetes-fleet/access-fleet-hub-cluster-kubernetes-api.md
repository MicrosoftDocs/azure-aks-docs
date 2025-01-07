---
title: "Access the Kubernetes API for an Azure Kubernetes Fleet Manager Hub Cluster"
description: Learn how to access the Kubernetes API for an Azure Kubernetes Fleet Manager hub cluster.
ms.topic: how-to
ms.date: 04/01/2024
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-fleet-manager
---

# Access the Kubernetes API for an Azure Kubernetes Fleet Manager hub cluster

If your Azure Kubernetes Fleet Manager (Kubernetes Fleet) resource was created with a hub cluster, you can use it to centrally control scenarios like Kubernetes resource propagation. In this article, you learn how to access the Kubernetes API for a Kubernetes Fleet hub cluster.

## Prerequisites

* [!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
* You need a Kubernetes Fleet resource with a hub cluster and member clusters. If you don't have one, see [Create an Azure Kubernetes Fleet Manager resource and join member clusters by using the Azure CLI](quickstart-create-fleet-and-members.md).
* The identity (user or service principal) that you're using needs to have Microsoft.ContainerService/fleets/listCredentials/action permissions on the Kubernetes Fleet resource.

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

## Related content

* [Propagate resources from an Azure Kubernetes Fleet Manager hub cluster to member clusters](./quickstart-resource-propagation.md)

<!-- LINKS --->
[az-fleet-get-credentials]: /cli/azure/fleet#az-fleet-get-credentials
[az-account-set]: /cli/azure/account#az-account-set
