---
title: Create an Azure Kubernetes Service (AKS) cluster with node auto-provisioning (NAP) in a custom virtual network
description: Learn how to create an AKS cluster with node auto-provisioning in a custom virtual network.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 06/13/2024
ms.author: bsoghigian
author: bsoghigian
ms.service: azure-kubernetes-service
# Customer intent: As a cluster operator or developer, I want to create an AKS cluster with node auto-provisioning enabled in a custom virtual network, so that I can manage my cluster's networking and security configurations while leveraging automatic node provisioning for optimal resource management.
---

# Create a node auto-provisioning (NAP) cluster in a custom virtual network in Azure Kubernetes Service (AKS)

This article shows you how to create a virtual network (VNet) and subnet, create a managed identity with permissions to access the VNet, and create an Azure Kubernetes Service (AKS) cluster in your custom VNet with node auto-provisioning (NAP) enabled.

## Before you begin

Before you begin, review the following articles:

- [Overview of node auto-provisioning (NAP) in AKS](./node-autoprovision.md) article, which details [how NAP works](./node-autoprovision.md#how-does-node-auto-provisioning-work), [prerequisites](./node-autoprovision.md#prerequisites) and [limitations](./node-autoprovision.md#limitations-and-unsupported-features).
- [Overview of networking configurations for node auto-provisioning (NAP) in Azure Kubernetes Service (AKS)](./node-autoprovision-networking.md), which details X, Y, and Z.

## Create a virtual network and subnet

> [!IMPORTANT]
> When using a custom VNet with NAP keep the following information in mind:
>
> - You must create and delegate an API server subnet to `Microsoft.ContainerService/managedClusters`, which grants the AKS service permissions to inject the API server pods and internal load balancer into that subnet. You can't use the subnet for any other workloads, but you can use it for multiple AKS clusters located in the same VNet. The minimum supported API server subnet size is _/28_.
> - All traffic within the VNet is allowed by default. However, if you added network security group (NSG) rules to restrict traffic between different subnets, you need to ensure you configure the proper permissions. For more information, see the [Network security group documentation][network-security-group].

1. Create a VNet using the [`az network vnet create`][az-network-vnet-create] command.

    ```azurecli-interactive
    az network vnet create \
        --name $VNET_NAME \
        --resource-group $RG_NAME \
        --location $LOCATION \
        --address-prefixes 172.19.0.0/16
    ```

1. Create a subnet using the [`az network vnet subnet create`][az-network-vnet-subnet-create] command and delegate it to `Microsoft.ContainerService/managedClusters`.

    ```azurecli-interactive
    az network vnet subnet create \
        --resource-group $RG_NAME \
        --vnet-name $VNET_NAME \
        --name $SUBNET_NAME \
        --delegations Microsoft.ContainerService/managedClusters \
        --address-prefixes 172.19.0.0/28
    ```

## Create a managed identity and give it permissions to access the VNet

1. Create a managed identity using the [`az identity create`][az-identity-create] command.

    ```azurecli-interactive
    az identity create \
        --resource-group $RG_NAME \
        --name $IDENTITY_NAME \
        --location $LOCATION
    ```

1. Get the principal ID of the managed identity and set it to an environment variable using the [`az identity show`][az-identity-show] command.

    ```azurecli-interactive
    IDENTITY_PRINCIPAL_ID=$(az identity show --resource-group $RG_NAME --name $IDENTITY_NAME --query principalId -o tsv)
    ```

1. Assign the _Network Contributor_ role to the managed identity using the [`az role assignment create`][az-role-assignment-create] command.

    ```azurecli-interactive
    az role assignment create \
        --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/virtualNetworks/$VNET_NAME" \
        --role "Network Contributor" \
        --assignee $IDENTITY_PRINCIPAL_ID
    ```

## Create an AKS cluster with node auto-provisioning (NAP) in a custom VNet

1. Create an AKS cluster with NAP enabled in your custom VNet using the [`az aks create`][az-aks-create] command. Make sure to set the `--node-provisioning-mode` flag to `Auto` to enable NAP.

    The following command also sets the `--network-plugin` to `azure`, `--network-plugin-mode` to `overlay`, and `--network-dataplane` to `cilium`. For more information on networking configurations supported with NAP, see [Configure networking for node auto-provisioning on AKS](./node-autoprovision-networking.md).

    ```azurecli-interactive
    az aks create \
        --name $CLUSTER_NAME \
        --resource-group $RG_NAME \
        --location $LOCATION \
        --assign-identity "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RG_NAME/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$IDENTITY_NAME" \ 
        --network-dataplane cilium \
        --network-plugin azure \
        --network-plugin-mode overlay \
        --vnet-subnet-id "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/virtualNetworks/$CUSTOM_VNET_NAME/subnets/$SUBNET_NAME" \
        --node-provisioning-mode Auto
    ```

    After a few minutes, the command completes and returns JSON-formatted information about the cluster.

1. Configure `kubectl` to connect to your Kubernetes cluster using the [`az aks get-credentials`][az-aks-get-credentials] command. This command downloads credentials and configures the Kubernetes CLI to use them.

    ```azurecli-interactive
    az aks get-credentials \
        --resource-group $RG_NAME \
        --name $CLUSTER_NAME
    ```

1. Verify the connection to your cluster using the [`kubectl get`][kubectl-get] command. This command returns a list of the cluster nodes.

    ```bash
    kubectl get nodes
    ```

## Next steps

TBD.

<!-- LINKS -->
[az-network-vnet-create]: /cli/azure/network/vnet#az-network-vnet-create
[az-network-vnet-subnet-create]: /cli/azure/network/vnet/subnet#az-network-vnet-subnet-create
[az-identity-create]: /cli/azure/identity#az-identity-create
[az-role-assignment-create]: /cli/azure/role/assignment#az-role-assignment-create
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[network-security-group]: /azure/virtual-network/network-security-groups-overview
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get