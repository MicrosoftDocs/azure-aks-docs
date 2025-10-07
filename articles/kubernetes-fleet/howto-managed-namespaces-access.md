---
title: View a managed namespace and the member clusters it is placed on (preview)
description: Learn how to find managed namespaces you have access to, view their deployment locations, and monitor resource quota usage across multiple clusters.
author: audrastump
ms.author: stumpaudra
ms.topic: how-to
ms.date: 09/22/2025
ms.service: azure-kubernetes-fleet-manager
zone_pivot_groups: azure-portal-azure-cli

# Customer intent: "As an application developer or team lead, I want to find the namespaces I have access to and monitor their resource usage across all clusters so I can understand deployment status and determine if quota adjustments are needed."
---
# View a managed namespace and the member clusters it is placed on (preview)

**Applies to:** :heavy_check_mark: Fleet Manager with hub cluster

## Before you begin
* You need an Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).

* To understand the concept of a managed namespace, read the [conceptual overview of multi-cluster managed namespaces](./concepts-fleet-managed-namespace.md).

* You need Azure CLI version 2.58.0 or later installed to complete this article. To install or upgrade, see [Install Azure CLI][az-aks-install-cli].

* You need the `fleet` Azure CLI extension. You can install it by running the following command:

  ```azurecli-interactive
  az extension add --name fleet
  ```

  Run the [`az extension update`][az-extension-update] command to update to the latest version of the extension:

  ```azurecli-interactive
  az extension update --name fleet
  ```
  
  Confirm the fleet extension version is at least 1.7.0:

  ```azurecli-interactive
  az extension show --name fleet
  ```

* You need an existing multi-cluster managed namespace. See [guide](./howto-managed-namespaces.md) on how to create a multi-cluster managed namespace.

* Set the following environment variables for your subscription ID, resource group, and Fleet:

  ```azurecli-interactive
  export SUBSCRIPTION_ID=<subscription-id>
  export GROUP=<resource-group-name>
  export FLEET=<fleet-name>
  export FLEET_NAMESPACE_NAME=<fleet-namespace-name>
  ```

* Set the default Azure subscription by using the [`az account set`][az-account-set] command:

  ```azurecli-interactive
  az account set --subscription ${SUBSCRIPTION_ID}
  ```

:::zone target="docs" pivot="azure-cli"
## View the multi-cluster managed namespaces I have access to 
  ```azurecli-interactive
  az fleet namespace list  
    --resource-group {GROUP} \ 
    --fleet-name ${FLEET} \ 
    -o table 
  ```

## View the member clusters that the managed namespace is placed on
  ```azurecli-interactive
  az fleet namespace show \ 
    --resource-group ${GROUP} \ 
    --fleet-name ${FLEET} \ 
    --name ${FLEET_NAMESPACE_NAME}$ \ 
    -o table 
  ```

:::zone-end
:::zone target="docs" pivot="azure-portal"
## View the multi-cluster managed namespace I have access to 
## View the member clusters that the managed namespace is placed on
:::zone-end

<!-- INTERNAL LINKS -->
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-account-set]: /cli/azure/account#az_account_set
