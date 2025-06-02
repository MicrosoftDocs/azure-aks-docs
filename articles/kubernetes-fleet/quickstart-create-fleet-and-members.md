---
title: "Quickstart: Create an Azure Kubernetes Fleet Manager resource and join member clusters using Azure CLI"
description: In this quickstart, you learn how to create an Azure Kubernetes Fleet Manager resource and join member clusters using Azure CLI.
author: sjwaight
ms.author: simonwaight
ms.date: 05/13/2025
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
---

# Quickstart: Create an Azure Kubernetes Fleet Manager and join member clusters using Azure CLI

Get started with Azure Kubernetes Fleet Manager by using the Azure CLI to create a Fleet Manager and join Azure Kubernetes Service (AKS) clusters as member clusters.

## Prerequisites

[!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]

* Read the [conceptual overview of Fleet Manager](./concepts-fleet.md), which provides an explanation of fleets and member clusters referenced in this document.
* Read the [conceptual overview of fleet types](./concepts-choosing-fleet.md), which provides a comparison of different fleet configuration options.
* An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).
* An identity (user or service principal) which can be used to [log in to Azure CLI](/cli/azure/authenticate-azure-cli). This identity needs to have the following permissions on the Fleet and AKS resource types for completing the steps listed in this quickstart:

  * Microsoft.ContainerService/fleets/read
  * Microsoft.ContainerService/fleets/write
  * Microsoft.ContainerService/fleets/members/read
  * Microsoft.ContainerService/fleets/members/write
  * Microsoft.ContainerService/fleetMemberships/read
  * Microsoft.ContainerService/fleetMemberships/write
  * Microsoft.ContainerService/managedClusters/read
  * Microsoft.ContainerService/managedClusters/write

* Have the Azure CLI version 2.70.0 or later installed. To install or upgrade, see [Install the Azure CLI][azure-cli-install].

* You also need the `fleet` Azure CLI extension version 1.5.0 or later, which you can install by running the following command:

  ```azurecli-interactive
  az extension add --name fleet
  ```

  Run the following command to update to the latest version of the extension released:

  ```azurecli-interactive
  az extension update --name fleet
  ```

* Set the following environment variables:

    ```azurecli
    export SUBSCRIPTION_ID=<subscription_id>
    export GROUP=<your_resource_group_name>
    export FLEET=<your_fleet_name>
    export LOCATION=<azure-region-name>
    ```

* Install `kubectl` using the [`az aks install-cli`][az-aks-install-cli] command.

  ```azurecli-interactive
  az aks install-cli
  ```

* The AKS clusters you want to join as member clusters need to be running Kubernetes versions supported by AKS. Learn more about AKS version support policy [here](/azure/aks/supported-kubernetes-versions#kubernetes-version-support-policy).

## Create a resource group

An [Azure resource group](/azure/azure-resource-manager/management/overview) is a logical group in which Azure resources are deployed and managed. When you create a resource group, you're prompted to specify a location. This location is the storage location of your resource group metadata and where your resources run in Azure if you don't specify another location during resource creation.

Set the Azure subscription and create a resource group using the [`az group create`][az-group-create] command.

```azurecli-interactive
az account set -s ${SUBSCRIPTION_ID}
az group create --name ${GROUP} --location ${LOCATION}
```

The following output example resembles successful creation of the resource group:

```output
{
  "id": "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/fleet-demo",
  "location": "<LOCATION>",
  "managedBy": null,
  "name": "fleet-demo",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null,
  "type": "Microsoft.Resources/resourceGroups"
}
```

## Create a Fleet Manager resource

You can create a Fleet Manager at any time, selecting to later add your AKS clusters as member clusters. When created via the Azure CLI, by default, Fleet Manager enables member cluster grouping and update orchestration. If the Fleet Manager is created with a hub cluster, intelligent Kubernetes object placement and load balancing across multiple member clusters is possible. For more information, see the [conceptual overview of fleet types](./concepts-choosing-fleet.md), which provides a comparison of different fleet configurations.

> [!IMPORTANT]
> You can change from a Fleet Manager without a hub cluster to one with a hub cluster, but not the reverse. For Fleet Managers with a hub cluster, once private or public access is selected it can't be changed.

### [Fleet Manager without hub cluster](#tab/without-hub-cluster)

If you want to use Fleet Manager only for Kubernetes or node image update orchestration, you can create a Fleet resource without the hub cluster using the [`az fleet create`][az-fleet-create] command.

```azurecli-interactive
az fleet create \
    --resource-group ${GROUP} \
    --name ${FLEET} \
    --location ${LOCATION} \
    --enable-managed-identity
```

Your output should look similar to the following example output:

```output
{
  "etag": "...",
  "hubProfile": null,
  "id": "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/fleet-demo/providers/Microsoft.ContainerService/fleets/fleet-demo",
  "identity": {
    "principalId": <system-identity-id>,
    "tenantId": <entra-tenant-id>,
    "type": "SystemAssigned",
    "userAssignedIdentities": null
  },
  "location": "<LOCATION>",
  "name": "fleet-demo",
  "provisioningState": "Succeeded",
  "resourceGroup": "fleet-demo",
  "systemData": {
    "createdAt": "2023-11-03T17:15:19.610149+00:00",
    "createdBy": "<user>",
    "createdByType": "User",
    "lastModifiedAt": "2023-11-03T17:15:19.610149+00:00",
    "lastModifiedBy": "<user>",
    "lastModifiedByType": "User"
  },
  "tags": null,
  "type": "Microsoft.ContainerService/fleets"
}
```

### [Fleet Manager with hub cluster](#tab/with-hub-cluster)

If you want to use Fleet Manager for intelligent Kubernetes object placement and multi-cluster load balancing as well as Kubernetes and node image update orchestration, then you must create the Fleet Manager with the hub cluster enabled by specifying the `--enable-hub` parameter with the [`az fleet create`][az-fleet-create] command.

Fleet Manager hub clusters support both public and private modes for network access. For more information, see [Choose an Azure Kubernetes Fleet Manager option](./concepts-choosing-fleet.md#network-access-modes-for-hub-cluster).

> [!NOTE]
> By default, Fleet Manager hub clusters are public. Fleet Manager chooses the virtual machine (VM) SKU used for the hub node (at this time, Fleet Manager tries "Standard_D4s_v4", "Standard_D4s_v3", "Standard_D4s_v5", "Standard_Ds3_v2", "Standard_E4as_v4" in order). If none of these options are acceptable or available, you can select a VM SKU by setting `--vm-size <SKU>`.

#### Public hub cluster

To create a public Fleet Manager with a hub cluster, use the `az fleet create` command with the `--enable-hub` flag set.

```azurecli-interactive
az fleet create \
    --resource-group ${GROUP} \
    --name ${FLEET} \
    --location ${LOCATION}  \
    --enable-hub \
    --enable-managed-identity
```

Your output should look similar to the following example output:

```output
{
  "etag": "...",
  "hubProfile": {
    "agentProfile": {
      "subnetId": null,
      "vmSize": null
    },
    "apiServerAccessProfile": {
      "enablePrivateCluster": false,
      "enableVnetIntegration": false,
      "subnetId": null
    }
  },
  "id": "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/fleet-demo/providers/Microsoft.ContainerService/fleets/fleet-demo",
  "identity": {
    "principalId": <system-identity-id>,
    "tenantId": <entra-tenant-id>,
    "type": "SystemAssigned",
    "userAssignedIdentities": null
  },
  "location": "<LOCATION>",
  "name": "fleet-demo",
  "provisioningState": "Succeeded",
  "resourceGroup": "fleet-demo",
  "systemData": {
    "createdAt": "2023-11-03T17:15:19.610149+00:00",
    "createdBy": "<user>",
    "createdByType": "User",
    "lastModifiedAt": "2023-11-03T17:15:19.610149+00:00",
    "lastModifiedBy": "<user>",
    "lastModifiedByType": "User"
  },
  "tags": null,
  "type": "Microsoft.ContainerService/fleets"
}
```

#### Private hub cluster

When you create a Fleet Manager with a hub cluster with private access, some extra considerations apply:

* Fleet Manager requires you to provide the subnet on which the hub cluster node VM is placed. You can specify the subnet at creation time by setting `--agent-subnet-id <subnet>`.
* The address prefix of the virtual network (VNet) whose subnet is passed via `--vnet-subnet-id` must not overlap with the AKS default service range of `10.0.0.0/16`.
* When using an AKS private cluster, you have the ability to configure fully qualified domain names (FQDNs) and FQDN subdomains. This functionality doesn't apply to the private access mode type hub cluster.

First, create a virtual network and subnet for your hub cluster's node VMs using the `az network vnet create` and `az network vnet subnet create` commands.

```azurecli-interactive
az network vnet create --resource-group ${GROUP} --name vnet --address-prefixes 192.168.0.0/16
az network vnet subnet create --resource-group ${GROUP} --vnet-name vnet --name subnet --address-prefixes 192.168.0.0/24

SUBNET_ID=$(az network vnet subnet show --resource-group ${GROUP} --vnet-name vnet -n subnet -o tsv --query id)
```

To create a private access mode Kubernetes Fleet resource, use `az fleet create` command with the `--enable-private-cluster` flag and provide the subnet ID obtained in the previous step to the  `--agent-subnet-id <subnet>` argument.

```azurecli-interactive
az fleet create \
    --resource-group ${GROUP} \
    --name ${FLEET} \
    --location ${LOCATION} \ 
    --enable-hub \
    --enable-private-cluster \
    --enable-managed-identity \
    --agent-subnet-id "${SUBNET_ID}"
```

---

## Join member clusters

Fleet currently supports joining existing AKS clusters as member clusters.

1. Set the following environment variables for member clusters:

    ```azurecli-interactive
    export MEMBER_NAME_1=aks-member-1
    export MEMBER_CLUSTER_ID_1=/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${GROUP}/providers/Microsoft.ContainerService/managedClusters/${MEMBER_NAME_1}
    ```

2. Join your existing AKS clusters to the Fleet resource using the [`az fleet member create`][az-fleet-member-create] command.

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

3. Verify that the member clusters successfully joined the Fleet resource using the [`az fleet member list`][az-fleet-member-list] command.

    ```azurecli-interactive
    az fleet member list \
        --resource-group ${GROUP} \
        --fleet-name ${FLEET} \
        -o table
    ```

    If successful, your output should look similar to the following example output:

    ```output
    ClusterResourceId                                                                                                                                Name          ProvisioningState    ResourceGroup
    -----------------------------------------------------------------------------------------------------------------------------------------------  ------------  -------------------  ---------------
    /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<GROUP>/providers/Microsoft.ContainerService/managedClusters/aks-member-1  aks-member-1  Succeeded            <GROUP>
    /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<GROUP>/providers/Microsoft.ContainerService/managedClusters/aks-member-2  aks-member-2  Succeeded            <GROUP>
    /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<GROUP>/providers/Microsoft.ContainerService/managedClusters/aks-member-3  aks-member-3  Succeeded            <GROUP>
    ```

## Next steps

* [Access Fleet Manager hub cluster Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md).

<!-- INTERNAL LINKS -->
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[az-group-create]: /cli/azure/group#az-group-create
[az-fleet-create]: /cli/azure/fleet#az-fleet-create
[az-fleet-member-create]: /cli/azure/fleet/member#az-fleet-member-create
[az-fleet-member-list]: /cli/azure/fleet/member#az-fleet-member-list
[azure-cli-install]: /cli/azure/install-azure-cli
