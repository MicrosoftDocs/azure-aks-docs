---
title: Enable Advanced Container Networking Services on Azure Kubernetes Service (AKS) Clusters
description: Learn how to set up Advanced Container Networking Services on your Azure Kubernetes Service (AKS) clusters to enhance network observability and security for your containerized applications.
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 05/28/2024
# Customer intent: "As a cloud engineer, I want to implement Advanced Container Networking Services in my AKS clusters, so that I can enhance network observability and security for my containerized applications, ensuring they are secure, compliant, and perform optimally."
---

# Use Advanced Container Networking Services on your Azure Kubernetes Service (AKS) cluster

This article describes how to enable and disable Advanced Container Networking Services, including [Container Network Observability](./advanced-container-networking-services-overview.md#container-network-observability) and [Container Network Security](./advanced-container-networking-services-overview.md#container-network-security), on your AKS clusters.

## Prerequisites

- An Azure account with an active subscription. If you don't have one, create a [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn) before you begin.

[!INCLUDE [azure-CLI-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

- Azure CLI version 2.71.0 or higher. Find your version using the `az --version` command. To install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
- [Install the `aks-preview` Azure CLI extension](#install-the-aks-preview-azure-cli-extension). You need version `14.0.0b6` or higher.
- [Register the `AdvancedNetworkingL7PolicyPreview` feature flag](#register-the-advancednetworkingl7policypreview-feature-flag) in your subscription.

## Considerations

Keep the following information in mind when creating or updating a Cilium-based cluster:

- Clusters that have the Cilium data plane support _Container Network Observability_ and _Container Network Security_ in Kubernetes version 1.29 and later.
- When the `--acns-advanced-networkpolicies` parameter is set to `L7`, both L7 and FQDN filtering policies are enabled. If you want to enable only FQDN filtering, set the parameter to `FQDN`.
- To disable both features, complete the steps in [Disable Container Network Security](./advanced-container-networking-services-overview.md?tabs=cilium#disable-container-network-security).

## Install the `aks-preview` Azure CLI extension

- Install or update the Azure CLI preview extension using the [`az extension add`](/cli/azure/extension#az-extension-add) or [`az extension update`](/cli/azure/extension#az-extension-update) command.

    ```azurecli-interactive
    # Install the aks-preview extension
    az extension add --name aks-preview
    
    # Update the extension to make sure you have the latest version installed
    az extension update --name aks-preview
    ```

## Register the `AdvancedNetworkingL7PolicyPreview` feature flag

1. Register the `AdvancedNetworkingL7PolicyPreview` feature flag using the [`az feature register`](/cli/azure/feature#az-feature-register) command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingL7PolicyPreview"
    ```

    Registration takes a few minutes to complete.

1. Verify successful registration using the [`az feature show`](/cli/azure/feature#az-feature-show) command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingL7PolicyPreview"
    ```

## Create a resource group

- Create a resource group using the [`az group create`](/cli/azure/group#az-group-create) command.

    ```azurecli-interactive
    # Set environment variables for the resource group name and location. Make sure you replace the placeholders with your own values.
    export RESOURCE_GROUP="<resource-group-name>"
    export LOCATION="<location>"

    # Create the resource group
    az group create --name $RESOURCE_GROUP --location $LOCATION
    ```

## Create a new AKS cluster with Advanced Container Networking Services (Cilium)

- Create an AKS cluster with Advanced Container Networking Services and Cilium using the [`az aks create`](/cli/azure/aks#az-aks-create) command with the `--enable-acns` and `--network-dataplane cilium` flags.

    ```azurecli-interactive
    # Set an environment variable for the AKS cluster name. Make sure you replace the placeholder with your own value.
    export CLUSTER_NAME="<aks-cluster-name>"
    
    # Create an AKS cluster
    az aks create \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --network-plugin azure \
        --network-plugin-mode overlay \
        --network-dataplane cilium \
        --kubernetes-version 1.29 \
        --enable-acns \
        --acns-advanced-networkpolicies <L7/FQDN>
    ```

## Create a new AKS cluster with Advanced Container Networking Services (non-Cilium)

> [!IMPORTANT]
> The [Container Network Security](./advanced-container-networking-services-overview.md#container-network-security) feature isn't available for non-Cilium clusters.

- Create an AKS cluster with Advanced Container Networking Services using the [`az aks create`](/cli/azure/aks#az-aks-create) command with the `--enable-acns` flag.

    ```azurecli-interactive
    # Set an environment variable for the AKS cluster name. Make sure you replace the placeholder with your own value.
    export CLUSTER_NAME="<aks-cluster-name>"
    
    # Create an AKS cluster
    az aks create \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --network-plugin azure \
        --network-plugin-mode overlay \
        --enable-acns
    ```

## Enable Advanced Container Networking Services on an existing cluster (Cilium)

- Enable Advanced Container Networking Services on an existing AKS cluster with Cilium using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--enable-acns` flag.

    ```azurecli-interactive
    az aks update \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --enable-acns \
        --acns-advanced-networkpolicies <L7/FQDN>
    ```

## Enable Advanced Container Networking Services on an existing cluster (non-Cilium)

- Enable Advanced Container Networking Services on an existing AKS cluster using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--enable-acns` flag.

    ```azurecli-interactive
    az aks update \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --enable-acns
    ```

## Disable Advanced Container Networking Services on an AKS cluster (Cilium and non-Cilium)

- Disable Advanced Container Networking Services on an existing AKS cluster using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--disable-acns` flag.

    ```azurecli-interactive
    az aks update \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --disable-acns
    ```

## Disable Container Network Observability on an AKS cluster (Cilium)

- Disable the Container Network Observability feature without affecting other Advanced Container Networking Services features using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--disable-acns-observability` flag.

    ```azurecli-interactive
    az aks update \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --enable-acns \
        --disable-acns-observability 
    ```

## Disable Container Network Observability on an AKS cluster (non-Cilium)

- Disable Advanced Container Networking Services on an existing AKS cluster using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--disable-acns` flag.

    ```azurecli-interactive
    az aks update \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --disable-acns 
    ```

## Disable Container Network Security on an AKS cluster (Cilium)

- Disable the Container Network Security feature without affecting other Advanced Container Networking Services features using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--disable-acns-security` flag.

    ```azurecli-interactive
    az aks update \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --enable-acns \
        --disable-acns-security
    ```

## Related content

- [Advanced Container Networking Services pricing](https://azure.microsoft.com/pricing/details/azure-container-networking-services/)
- [Advanced Container Networking Services for Azure Kubernetes Service (AKS) overview](./advanced-container-networking-services-overview.md)
