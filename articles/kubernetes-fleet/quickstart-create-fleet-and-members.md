---
title: "Quickstart: Create an Azure Kubernetes Fleet Manager and join member clusters using Azure CLI"
description: In this quickstart, you learn how to create an Azure Kubernetes Fleet Manager and join member clusters using Azure CLI.
author: sjwaight
ms.author: simonwaight
ms.date: 02/23/2026
ms.service: azure-kubernetes-fleet-manager
ms.topic: quickstart
ms.custom:
  - template-quickstart
  - mode-other
  - devx-track-azurecli
  - ignite-2023
  - build-2024
  - build-2025
ms.devlang: azurecli
zone_pivot_groups: none-public-private-hub
# Customer intent: As a cloud architect, I want to create an Azure Kubernetes Fleet Manager and join member clusters using the Azure CLI, so that I can manage and orchestrate multiple Kubernetes clusters for improved scalability and application deployment.
---

# Quickstart: Create an Azure Kubernetes Fleet Manager and join member clusters using Azure CLI

**Applies to:** :heavy_check_mark: Fleet Manager :heavy_check_mark: Fleet Manager with hub cluster

Get started with Azure Kubernetes Fleet Manager by using the Azure CLI to create a Fleet Manager and join [supported Kubernetes clusters](./concepts-member-cluster-types.md) as members. 

Fleet Manager supports an optional hub cluster that is used for intelligent Kubernetes resource placement and is required to use [Managed Fleet Namespaces](./concepts-fleet-managed-namespace.md). 

For more information on Fleet Manager configurations, see the [conceptual overview of fleet types](./concepts-choosing-fleet.md).

## Before you begin

[!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

* Read the [conceptual overview of Fleet Manager](./concepts-fleet.md), which provides an explanation of fleets and member clusters referenced in this document.
* Read the [conceptual overview of fleet types](./concepts-choosing-fleet.md), which provides a comparison of different fleet configuration options.
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

* Have the Azure CLI version 2.82.0 or later installed. To install or upgrade, see [Install the Azure CLI][azure-cli-install].

* You also need the `fleet` Azure CLI extension version 1.8.3 or later, which you can install by running the following command:

  ```azurecli-interactive
  az extension add --name fleet
  ```

  Run the following command to update to the latest version of the extension released:

  ```azurecli-interactive
  az extension update --name fleet
  ```

* Set the following environment variables:

    ```bash
    export SUBSCRIPTION_ID=<subscription_id>
    export GROUP=<resource_group_name>
    export FLEET=<fleet_name>
    export LOCATION=<azure_region_name>
    ```

* Install `kubectl` using the [`az aks install-cli`][az-aks-install-cli] command.

  ```azurecli-interactive
  az aks install-cli
  ```

* Member clusters must run supported versions: see [AKS cluster version support policy](/azure/aks/supported-kubernetes-versions#kubernetes-version-support-policy) and [Azure Arc-enabled Kubernetes validation](/azure//azure-arc/kubernetes/validation-program).

## Create a resource group

Set the Azure subscription and create a resource group using the [`az group create`][az-group-create] command.

```azurecli-interactive
az account set -s ${SUBSCRIPTION_ID}
az group create --name ${GROUP} --location ${LOCATION}
```
:::zone target="docs" pivot="no-hub" 

## Fleet Manager with no hub cluster

If you want to use Fleet Manager only for safe multi-cluster Kubernetes or node image updates, you can create a Fleet Manager without a hub cluster using the [`az fleet create`][az-fleet-create] command.

> [!IMPORTANT]
> You can change from a Fleet Manager without a hub cluster to one with a hub cluster, but not the reverse.

```azurecli-interactive
az fleet create \
    --resource-group ${GROUP} \
    --name ${FLEET} \
    --location ${LOCATION} \
    --enable-managed-identity
```

:::zone-end

:::zone target="docs" pivot="public-hub"

## Fleet Manager with public hub cluster

If you want to use Fleet Manager for intelligent Kubernetes object placement and multi-cluster load balancing as well as Kubernetes and node image update orchestration, then you must create the Fleet Manager with the hub cluster enabled by specifying the `--enable-hub` parameter with the [`az fleet create`][az-fleet-create] command.

Fleet Manager hub clusters support both public and private modes for network access. For more information, see [Choose an Azure Kubernetes Fleet Manager option](./concepts-choosing-fleet.md#network-access-modes-for-hub-cluster).

> [!NOTE]
> By default, Fleet Manager hub clusters are public. Fleet Manager chooses the virtual machine (VM) SKU used for the hub node (at this time, Fleet Manager tries "Standard_D4s_v4", "Standard_D4s_v3", "Standard_D4s_v5", "Standard_Ds3_v2", "Standard_E4as_v4" in order). If none of these options are acceptable or available, you can select a VM SKU by setting `--vm-size <SKU>`.

To create a public Fleet Manager with a hub cluster, use the `az fleet create` command with the `--enable-hub` flag set.


> [!IMPORTANT]
> You can't change a hub cluster's type (public or private) once it's configured.

```azurecli-interactive
az fleet create \
    --resource-group ${GROUP} \
    --name ${FLEET} \
    --location ${LOCATION}  \
    --enable-hub \
    --enable-managed-identity
```

Your output should look similar to the following example output:

:::zone-end

:::zone target="docs" pivot="private-hub"

## Fleet Manager with private hub cluster

When you create a Fleet Manager with a private hub cluster the preferred virtual network integration method for the hub cluster is [API server VNet integration](../aks/api-server-vnet-integration.md). 

1. Set the following environment variables.

  ```bash
  export SUBSCRIPTION_ID=<subscription_id>
  export GROUP=<resource_group_name>
  export FLEET=<fleet_name>
  export LOCATION=<azure_region_name>
  export UAMI-NAME=<user_managed_identity>
  export VNET-NAME=<virtual_network_name>
  export VNET-CLUSTER-SUBNET-NAME=<vnet_cluster_subnet_name>
  export VNET-API-SUBNET-NAME=<vnet_api_subnet_name>
  ```

2. Create a user-assigned managed identity to be used to enable private virtual network integration.

```azurecli-interactive
az identity create \
    --resource-group ${GROUP} \
    --name ${UAMI-NAME}
```

Retrieve the resource identifier for the user assigned managed identity to use later.

```bash
UAMI_ID=$(az identity show --resource-group ${GROUP} --name ${UAMI-NAME} --query id --output tsv)
```

3. If one doesn't already exist, create a virtual network. 

```azurecli-interactive
az network vnet create \
    --resource-group ${GROUP} \
    --name ${FLEET} \
    --address-prefixes 192.168.0.0/16
```

4. Add a subnet for the hub cluster integration.

```azurecli-interactive
az network vnet subnet create \
    --resource-group ${GROUP} \
    --vnet-name ${FLEET} \
    --name ${VNET-CLUSTER-SUBNET-NAME} \
    --address-prefixes 192.168.0.0/23
```

Retrieve the resource identifier for the cluster subnet to use later.

```bash
CLUSTER_SUBNET_ID=$(az network vnet subnet show --resource-group ${GROUP} --vnet-name ${FLEET} -n ${VNET-CLUSTER-SUBNET-NAME} -o tsv --query id)
```

5. Add a subnet for the hub cluster's API server VNet integration. This subnet requires delegation to `Microsoft.ContainerService/managedClusters`.

```azurecli-interactive
az network vnet subnet create \
    --resource-group ${GROUP} \
    --vnet-name ${FLEET} \
    --name ${VNET-API-SUBNET-NAME} \
    --delegations "Microsoft.ContainerService/managedClusters" \
    --address-prefixes 192.168.2.0/23
```

Retrieve the resource identifier for the API subnet to use later.

```bash
API_SUBNET_ID=$(az network vnet subnet show --resource-group ${GROUP} --vnet-name ${FLEET} -n ${VNET-API-SUBNET-NAME} -o tsv --query id)
```

6. Finally, create the new hub cluster, providing the necessary arguments to enable API VNet integration  

```azurecli-interactive
 az fleet create \
    --resource-group ${GROUP} \
    --name ${FLEET} \
    --location ${LOCATION}  \
    --enable-hub \
    --enable-managed-identity \
    --agent-subnet-id ${CLUSTER_SUBNET_ID} \
    --apiserver-subnet-id ${API_SUBNET_ID} \
    --assign-identity ${UAMI_ID}
```

:::zone-end

## Join member clusters

Fleet Manager supports joining existing AKS clusters or Arc-enabled Kubernetes clusters (Preview) as member clusters.

1. Set the following environment variables for member clusters:

    ```azurecli-interactive
    export MEMBER_NAME_1=flt-member-cluster-1

   # For an AKS cluster
    export MEMBER_CLUSTER_ID_1=/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${GROUP}/providers/Microsoft.ContainerService/managedClusters/${MEMBER_NAME_1}

    # For an Arc-enabled cluster
    export MEMBER_CLUSTER_ID_1=/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${GROUP}/providers/Microsoft.Kubernetes/connectedClusters/${MEMBER_NAME_1}
    ```

2. Join the existing clusters to the Fleet Manager using the [`az fleet member create`][az-fleet-member-create] command.

    ```azurecli-interactive
    az fleet member create \
        --resource-group ${GROUP} \
        --fleet-name ${FLEET} \
        --name ${MEMBER_NAME_1} \
        --member-cluster-id ${MEMBER_CLUSTER_ID_1}
    ```

    Your output should look similar to the following example output:

    ```output
    {
      "clusterResourceId": "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<GROUP>/providers/Microsoft.ContainerService/managedClusters/aks-member-x",
      "etag": "...",
      "id": "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<GROUP>/providers/Microsoft.ContainerService/fleets/<FLEET>/members/aks-member-x",
      "name": "aks-member-1",
      "provisioningState": "Succeeded",
      "resourceGroup": "<GROUP>",
      "systemData": {
        "createdAt": "2022-10-04T19:04:56.455813+00:00",
        "createdBy": "<user>",
        "createdByType": "User",
        "lastModifiedAt": "2022-10-04T19:04:56.455813+00:00",
        "lastModifiedBy": "<user>",
        "lastModifiedByType": "User"
      },
      "type": "Microsoft.ContainerService/fleets/members"
    }
    ```

3. Verify that the member clusters successfully joined the Fleet Manager using the [`az fleet member list`][az-fleet-member-list] command.

    ```azurecli-interactive
    az fleet member list \
        --resource-group ${GROUP} \
        --fleet-name ${FLEET} \
        -o table
    ```

    If successful, your output should look similar to the following example output:

    ```output
    ClusterResourceId                                                                                                          Name          ProvisioningState    ResourceGroup
    -------------------------------------------------------------------------------------------------------------------------- ------------  -------------------  ---------------
    /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<GROUP>/providers/Microsoft.ContainerService/managedClusters/aks-member-1  aks-member-1  Succeeded            <GROUP>
    /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<GROUP>/providers/Microsoft.ContainerService/managedClusters/aks-member-2  aks-member-2  Succeeded            <GROUP>
    /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<GROUP>/providers/Microsoft.ContainerService/managedClusters/aks-member-3  aks-member-3  Succeeded            <GROUP>
    ```

## Next steps

* [Access Fleet Manager hub cluster Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md).
* [Deploy cluster-scoped resources across multiple clusters](./quickstart-resource-propagation.md).
* [Deploy namespace-scoped resources across multiple clusters](./quickstart-namespace-scoped-resource-propagation.md).
* [Create and configure Managed Fleet Namespaces](./howto-managed-namespaces.md).
* [How-to: Upgrade multiple clusters using Azure Kubernetes Fleet Manager update runs](./update-orchestration.md).

<!-- INTERNAL LINKS -->
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[az-group-create]: /cli/azure/group#az-group-create
[az-fleet-create]: /cli/azure/fleet#az-fleet-create
[az-fleet-member-create]: /cli/azure/fleet/member#az-fleet-member-create
[az-fleet-member-list]: /cli/azure/fleet/member#az-fleet-member-list
[azure-cli-install]: /cli/azure/install-azure-cli
