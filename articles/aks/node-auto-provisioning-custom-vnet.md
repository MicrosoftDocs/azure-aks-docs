---
title: Create an Azure Kubernetes Service (AKS) cluster with node auto-provisioning (NAP) in a custom virtual network
description: Learn how to create an AKS cluster with node auto-provisioning in a custom virtual network.
ms.topic: how-to
ms.custom: devx-track-azurecli, aks-scaling
ms.date: 08/06/2026
ai-usage: ai-assisted
ms.author: schaffererin
author: schaffererin
ms.service: azure-kubernetes-service
# Customer intent: As a cluster operator or developer, I want to create an AKS cluster with node auto-provisioning enabled in a custom virtual network, so that I can manage my cluster's networking and security configurations while leveraging automatic node provisioning for optimal resource management.
---

# Create a node auto-provisioning (NAP) cluster in a custom virtual network in Azure Kubernetes Service (AKS)

This article shows you how to create an Azure Kubernetes Service (AKS) cluster with node auto-provisioning (NAP) enabled in a custom virtual network (VNet). You create a VNet and subnet, then grant a managed identity access to the VNet.

## Prerequisites

- An Azure subscription. If you don't have one, you can create a [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).
- Azure CLI version `2.76.0` or later. To find the version, run `az --version`. For more information about installing or upgrading the Azure CLI, see [Install Azure CLI][azure cli].
- A Bash environment, such as [Azure Cloud Shell](/azure/cloud-shell/overview). If you run the commands locally, sign in using the [`az login`](/cli/azure/reference-index#az-login) command.
- The Kubernetes command-line client, `kubectl`. `kubectl` is already installed in Azure Cloud Shell. To install it locally, use the [`az aks install-cli`][az-aks-install-cli] command.
- `Microsoft.Authorization/roleAssignments/write` permission, such as the [Role Based Access Control Administrator](/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) role, to assign the Network Contributor role.
- Familiarity with the concepts described in [Overview of node auto-provisioning (NAP) in AKS](./node-auto-provisioning.md) and [Overview of networking configurations for node auto-provisioning (NAP) in Azure Kubernetes Service (AKS)](./node-auto-provisioning-networking.md).

## Limitations

- When creating a NAP cluster in a custom virtual network (VNet), you must use a [Standard Load Balancer](./load-balancer-standard.md). The Basic Load Balancer isn't supported.
- To review other limitations and unsupported features for NAP, see the [Overview of node auto-provisioning (NAP) in AKS](./node-auto-provisioning.md#limitations-and-unsupported-features) article.

## Set environment variables and create a resource group

1. Set the environment variables used throughout this article. Replace the placeholder values with your own values.

    ```bash
    export SUBSCRIPTION_ID="<subscription-id>"
    export RG_NAME="<resource-group-name>"
    export LOCATION="<location>"
    export VNET_NAME="<vnet-name>"
    export SUBNET_NAME="<subnet-name>"
    export IDENTITY_NAME="<managed-identity-name>"
    export CLUSTER_NAME="<cluster-name>"
    ```

1. Select your Azure subscription using the [`az account set`][az-account-set] command.

    ```azurecli-interactive
    az account set --subscription $SUBSCRIPTION_ID
    ```

1. Create a resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create \
        --name $RG_NAME \
        --location $LOCATION
    ```

## Create a virtual network and subnet

1. Create a VNet using the [`az network vnet create`][az-network-vnet-create] command.

    ```azurecli-interactive
    az network vnet create \
        --name $VNET_NAME \
        --resource-group $RG_NAME \
        --location $LOCATION \
        --address-prefixes 172.19.0.0/16
    ```

1. Create a node subnet using the [`az network vnet subnet create`][az-network-vnet-subnet-create] command.

    ```azurecli-interactive
    az network vnet subnet create \
        --resource-group $RG_NAME \
        --vnet-name $VNET_NAME \
        --name $SUBNET_NAME \
        --address-prefixes 172.19.0.0/24
    ```

## Create a managed identity and assign VNet permissions

1. Create a managed identity using the [`az identity create`][az-identity-create] command.

    ```azurecli-interactive
    az identity create \
        --resource-group $RG_NAME \
        --name $IDENTITY_NAME \
        --location $LOCATION
    ```

1. Use the [`az identity show`][az-identity-show] command to get the managed identity's principal ID and save it in an environment variable.

    ```azurecli-interactive
    IDENTITY_PRINCIPAL_ID=$(az identity show --resource-group $RG_NAME --name $IDENTITY_NAME --query principalId -o tsv)
    ```

1. Assign the Network Contributor role to the managed identity using the [`az role assignment create`][az-role-assignment-create] command. The `--assignee-principal-type` parameter prevents failures caused by replication delays after creating the managed identity.

    > [!IMPORTANT]
    > The Network Contributor role at VNet scope grants broad permissions. Before you use this approach in production, review the [RBAC setup for custom subnet configurations](./node-auto-provisioning-networking.md#rbac-setup-for-custom-subnet-configurations) and consider assigning scoped subnet permissions.

    ```azurecli-interactive
    az role assignment create \
        --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/virtualNetworks/$VNET_NAME" \
        --role "Network Contributor" \
        --assignee-object-id $IDENTITY_PRINCIPAL_ID \
        --assignee-principal-type ServicePrincipal
    ```

## Enable NAP and connect to the cluster

Use the managed identity, VNet, and node subnet that you created in the previous sections. The cluster must use a Standard Load Balancer, as described in [Limitations](#limitations).

1. Create an AKS cluster with NAP enabled in your custom VNet using the [`az aks create`][az-aks-create] command. The following table describes the NAP and networking parameters used in the command:

    | Parameter | Value | Description |
    | --------- | ----- | ----------- |
    | `--node-provisioning-mode` | `Auto` | Enables NAP on the cluster. |
    | `--network-plugin` | `azure` | Uses Azure CNI for cluster networking. |
    | `--network-plugin-mode` | `overlay` | Uses Azure CNI Overlay for pod networking. |
    | `--network-dataplane` | `cilium` | Uses the Cilium data plane. |

    For more information, see [Overview of networking configurations for node auto-provisioning (NAP) in Azure Kubernetes Service (AKS)](./node-auto-provisioning-networking.md).

    ```azurecli-interactive
    az aks create \
        --name $CLUSTER_NAME \
        --resource-group $RG_NAME \
        --location $LOCATION \
        --assign-identity "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$IDENTITY_NAME" \
        --network-dataplane cilium \
        --network-plugin azure \
        --network-plugin-mode overlay \
        --vnet-subnet-id "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$SUBNET_NAME" \
        --node-provisioning-mode Auto \
        --generate-ssh-keys
    ```

    When cluster creation finishes, the command returns JSON-formatted information about the cluster.

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

For more information on node auto-provisioning in AKS, see the following articles:

- [Overview of networking configurations for node auto-provisioning (NAP) in Azure Kubernetes Service (AKS)](./node-auto-provisioning-networking.md)
- [Configure node pools for node auto-provisioning on AKS](./node-auto-provisioning-node-pools.md)
- [Configure disruption policies for node auto-provisioning on AKS](./node-auto-provisioning-disruption.md)

<!-- LINKS -->
[az-network-vnet-create]: /cli/azure/network/vnet#az-network-vnet-create
[az-network-vnet-subnet-create]: /cli/azure/network/vnet/subnet#az-network-vnet-subnet-create
[az-account-set]: /cli/azure/account#az-account-set
[az-group-create]: /cli/azure/group#az-group-create
[az-identity-create]: /cli/azure/identity#az-identity-create
[az-identity-show]: /cli/azure/identity#az-identity-show
[az-role-assignment-create]: /cli/azure/role/assignment#az-role-assignment-create
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[azure cli]: /cli/azure/get-started-with-azure-cli
