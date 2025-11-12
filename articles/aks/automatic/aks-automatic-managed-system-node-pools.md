---
title: Create an Azure Kubernetes Service (AKS) Automatic Cluster with Managed System Node Pools (Preview)
description: Learn how to create an Azure Kubernetes Service (AKS) Automatic cluster with managed system node pools using the Azure CLI.
ms.topic: quickstart
ms.custom: ignite-2025
ms.date: 10/10/2025
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
# Customer intent: As a cluster developer, I want to create an AKS Automatic cluster with managed system node pools so that I can offload system components to a managed service.
---

# Quickstart: Create an Azure Kubernetes Service (AKS) Automatic cluster with managed system node pools (preview)

In this quickstart, you learn how to create an Azure Kubernetes Service (AKS) Automatic cluster with managed system node pools (preview) using the Azure CLI.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

- Before you begin, read the [Overview of AKS Automatic clusters with managed system node pools](./aks-automatic-managed-system-node-pools-about.md) to learn about the feature and its restrictions.
- The Azure CLI version 2.77.0 or later. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/get-started-with-azure-cli).
- [Install the `aks-preview` Azure CLI extension](#install-or-update-the-aks-preview-extension). The minimum required version is **19.0.0b15**.
- [Register the `AKS-AutomaticHostedSystemProfilePreview` feature flag in your Azure subscription](#register-the-aks-automatichostedsystemprofilepreview-feature-flag).
- An Azure resource group. You can create one using the [`az group create`](/cli/azure/group#az-group-create) command.

### Install or update the `aks-preview` extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

- Install the `aks-preview` extension using the [`az extension add`](/cli/azure/extension#az-extension-add) command if you don't have it installed already.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

- Update the `aks-preview` extension to the latest version using the [`az extension update`](/cli/azure/extension#az-extension-update) command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the `AKS-AutomaticHostedSystemProfilePreview` feature flag

- Register the `AKS-AutomaticHostedSystemProfilePreview` feature flag using the [`az feature register`](/cli/azure/feature#az-feature-register) command.

    ```azurecli-interactive
    az feature register --name AKS-AutomaticHostedSystemProfilePreview --namespace Microsoft.ContainerService
    ```

## Limitations

- Windows nodes aren't supported.
- The [Istio-based service mesh add-on for AKS](../istio-deploy-ingress.md) isn't supported.
- Migrations between AKS Automatic clusters and AKS Automatic clusters with managed system node pools aren't supported.
- AKS Automatic clusters in a custom virtual network (VNet) with managed system node pools aren't supported.

## Region availability

AKS Automatic clusters with managed system node pools are currently available in the following regions:

| Geography | Available regions |
|-----------|-------------------|
| Africa | South Africa North <br> South Africa West |
| Asia Pacific | Asia East <br> Asia Southeast |
| Australia | Australia Central <br> Australia East <br> Australia Central 2 <br> Australia Southeast |
| Brazil | Brazil South <br> Brazil Southeast |
| Canada | Canada Central <br> Canada East |
| Chile | Chile Central |
| Europe | Europe North <br> Europe West |
| France | France Central <br> France South |
| Germany | Germany North <br> Germany West Central |
| India | India Central <br> India South <br> India West <br> Jio India Central <br> Jio India West |
| Israel | Israel Central |
| Italy | Italy North |
| Japan | Japan East <br> Japan West |
| Korea | Korea Central <br> Korea South |
| Malaysia | Malaysia South |
| Mexico | Mexico Central |
| New Zealand | New Zealand North |
| Norway | Norway East <br> Norway West |
| Poland | Poland Central |
| Qatar | Qatar Central |
| Spain | Spain Central |
| Sweden | Sweden Central <br> Sweden South |
| Switzerland | Switzerland North <br> Switzerland West |
| Taiwan | Taiwan North <br> Taiwan Northwest |
| UAE | UAE North <br> UAE Central |
| UK | UK South <br> UK South 2 <br> UK West |
| US | East US <br> East US 2 <br> Central US <br> North Central US <br> South Central US <br> West Central US <br> West US <br> West US 2 <br> West US 3 <br> US East 2 EUAP <br> US Central EUAP |

## Create an AKS Automatic cluster with managed system node pools

- Create an AKS Automatic cluster with managed system node pools using the [`az aks create`](/cli/azure/aks#az-aks-create) command with the `--sku` parameter set to `automatic` and the `--enable-hosted-system` flag.

    ```azurecli-interactive
    az aks create \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --sku automatic \
        --enable-hosted-system \
        --location $LOCATION
    ```

    Your output should resemble the following condensed example output, showing that the managed system node pools feature is enabled:

    ```output
    ...
    "hostedSystemProfile": {
        "enabled": true
      },
    ...
    ```
