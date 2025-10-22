---
title: View a Multi-cluster Managed Namespace and its Associated Member Clusters
description: Learn how to find managed namespaces you have access to, view their deployment locations, and monitor resource quota usage across multiple clusters.
author: audrastump
ms.author: stumpaudra
ms.topic: how-to
ms.date: 09/22/2025
ms.service: azure-kubernetes-fleet-manager

# Customer intent: "As an application developer or team lead, I want to find the namespaces I have access to and monitor their resource usage across all clusters so I can understand deployment status and determine if quota adjustments are needed."
---
# View a managed namespace and its associated member clusters (preview)

**Applies to:** :heavy_check_mark: Fleet Manager with hub cluster

This article shows you how to view the managed namespaces you have access to and monitor resource usage across member clusters.

[!INCLUDE [preview_features_note](./includes/preview/preview-callout.md)]

## Before you begin 

> [!IMPORTANT]
> This article is intended for **developers and team members** who need to discover and monitor managed namespaces they have access to. If you're a platform administrator looking to create and configure managed namespaces, see [Use multi-cluster managed namespaces for multi-tenancy](./howto-managed-namespaces.md).

- You need an Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).
- You need an existing multi-cluster managed namespace. If you don't have one, see [Create a multi-cluster managed namespace](./howto-managed-namespaces.md).
- Read the [Overview of multi-cluster managed namespaces](./concepts-fleet-managed-namespace.md) to understand the concept of a managed namespace.
- You need Azure CLI version 2.58.0 or later installed to complete this article. To install or upgrade, see [Install Azure CLI][az-aks-install-cli].
- You need the `fleet` Azure CLI extension. You can install it and update to the latest version using the [`az extension add`](/cli/azure/extension#az-extension-add) and [`az extension update`](/cli/azure/extension#az-extension-update) commands.

    ```azurecli-interactive
    # Install the extension
    az extension add --name fleet

    # Update the extension
    az extension update --name fleet
    ```

- Confirm the fleet extension version is at least 1.7.0 using the [`az extension show`](/cli/azure/extension#az-extension-show) command.

    ```azurecli-interactive
    az extension show --name fleet
    ```

- Set the following environment variables for your subscription ID, resource group, and Fleet:

    ```bash
    export SUBSCRIPTION_ID=<subscription-id>
    export GROUP=<resource-group-name>
    export FLEET=<fleet-name>
    export FLEET_NAMESPACE_NAME=<fleet-namespace-name>
    ```

- Set the default Azure subscription using the [`az account set`][az-account-set] command.

    ```azurecli-interactive
    az account set --subscription ${SUBSCRIPTION_ID}
    ```

## View the multi-cluster managed namespaces I have access to

- View the multi-cluster managed namespaces you have access to using the [`az fleet namespace list`](/cli/azure/fleet/namespace#az-fleet-namespace-list) command.

    ```azurecli-interactive
    az fleet namespace list  
        --resource-group {GROUP} \ 
        --fleet-name ${FLEET} \ 
        -o table 
    ```

## View the member clusters the managed namespace is placed on

- View the member clusters associated with the managed namespace using the [`az fleet namespace show`](/cli/azure/fleet/namespace#az-fleet-namespace-show) command.

    ```azurecli-interactive
    az fleet namespace show \ 
        --resource-group ${GROUP} \ 
        --fleet-name ${FLEET} \ 
        --name ${FLEET_NAMESPACE_NAME}$ \ 
        -o table 
    ```

## Next steps

- Read the [Overview of multi-cluster managed namespaces](./concepts-fleet-managed-namespace.md) to understand the concept of a managed namespace.
- Learn how to [create and use a multi-cluster managed namespace](./howto-managed-namespaces.md).

<!-- INTERNAL LINKS -->
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-account-set]: /cli/azure/account#az_account_set
