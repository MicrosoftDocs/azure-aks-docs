---
title: "Set up FQDN filtering feature for enhanced security in Advanced Container Networking Services (ACNS)"
description: Get started with FQDN Filtering Feature for Advanced Container Networking Services for your AKS cluster using Azure managed Cilium Network Policies.
author: sf-msft
ms.author: samfoo
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 07/30/2024
ms.custom: template-how-to-pattern, devx-track-azurecli
---

# Set up FQDN filtering feature for enhanced security in Advanced Container Networking Services (ACNS)

This article shows you how to set up Advanced Container Networking Services (ACNS) with FQDN Filtering Feature in AKS clusters.

> [!IMPORTANT]
> Advanced Container Networking Services is currently in PREVIEW.
> See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability.

## Prerequisites

* An Azure account with an active subscription. If you don't have one, create a [free account](https://azure.microsoft.com/free/?WT.mc_id=A261C142F) before you begin.
[!INCLUDE [azure-CLI-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

* The minimum version of Azure CLI required for the steps in this article is 2.56.0. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).


### Install the `aks-preview` Azure CLI extension

Install or update the Azure CLI preview extension using the [`az extension add`](/cli/azure/extension#az_extension_add) or [`az extension update`](/cli/azure/extension#az_extension_update) command.

```azurecli-interactive
# Install the aks-preview extension
az extension add --name aks-preview
# Update the extension to make sure you have the latest version installed
az extension update --name aks-preview
```

### Register the `AdvancedNetworkingPreview` feature flag

Register the `AdvancedNetworkingPreview` feature flag using the [`az feature register`](/cli/azure/feature#az_feature_register) command.

```azurecli-interactive 
az feature register --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingPreview"
```
Verify successful registration using the [`az feature show`](/cli/azure/feature#az_feature_show) command. It takes a few minutes for the registration to complete.

```azurecli-interactive
az feature show --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingPreview"
```

Once the feature shows `Registered`, refresh the registration of the `Microsoft.ContainerService` resource provider using the [`az provider register`](/cli/azure/provider#az_provider_register) command.

## Create a resource group

A resource group is a logical container into which Azure resources are deployed and managed. Create a resource group using the [`az group create`](/cli/azure/group#az_group_create) command.

```azurecli-interactive
# Set environment variables for the resource group name and location. Make sure to replace the placeholders with your own values.
export RESOURCE_GROUP="<resource-group-name>"
export LOCATION="<azure-region>"
# Create a resource group
az group create --name $RESOURCE_GROUP --location $LOCATION
```

## Create an AKS cluster with Advanced Container Networking Services

The `az aks create` command with the Advanced Container Networking Services flag, `--enable-acns`, creates a new AKS cluster with all ACNS features which includes [ACNS Observability](./advanced-network-observability-concepts.md) and the FQDN Filtering feature.

```azurecli-interactive
# Set an environment variable for the AKS cluster name. Make sure to replace the placeholder with your own value.
export CLUSTER_NAME="<aks-cluster-name>"

# Create an AKS cluster
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --generate-ssh-keys \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --pod-cidr 192.168.0.0/16 \
    --network-dataplane cilium \
    --enable-acns
```

### Create an AKS cluster with FQDN filtering feature without ACNS Observability

The `az aks create` command with the FQDN Filtering feature flag, `--enable-fqdn-policy`, creates a new AKS cluster with the FQDN Filtering feature without ACNS Observability.

```azurecli-interactive
# Set an environment variable for the AKS cluster name. Make sure to replace the placeholder with your own value.
export CLUSTER_NAME="<aks-cluster-name>"

# Create an AKS cluster
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --generate-ssh-keys \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --pod-cidr 192.168.0.0/16 \
    --network-dataplane cilium \
    --enable-fqdn-policy
```

## Enable Advanced Container Networking Services on an existing cluster

The [`az aks update`](/cli/azure/aks#az_aks_update) command with the Advanced Container Networking Services flag, `--enable-acns`, updates an existing AKS cluster with all ACNS features which includes [ACNS Observability](./advanced-network-observability-concepts.md) and the FQDN Filtering feature.

> [!NOTE]
> Only clusters with the Cilium data plane support Advanced Security and Advanced Container Networking Services.

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns
```

## Enable FQDN filtering feature without ACNS Observability

The [`az aks update`](/cli/azure/aks#az_aks_update) command with the FQDN Filtering feature flag, `--enable-fqdn-policy`, updates an existing AKS cluster with the FQDN Filtering feature without ACNS Observability.

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-fqdn-policy
```

## Disable FQDN filtering

The `--disable-fqdn-policy` flag disables the FQDN Filtering feature on an existing AKS cluster.

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --disable-fqdn-policy
```

## Disable Advanced Container Networking Services

The `--disable-acns` flag disables all ACNS features on an existing AKS cluster which includes FQDN Filtering and ACNS Observability.

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --disable-acns
```

---

## Clean up resources

If you don't plan on using this application, delete the other resources you created in this article using the [`az group delete`](/cli/azure/#az_group_delete) command.

```azurecli-interactive
  az group delete --name $RESOURCE_GROUP
```

## Next steps

In this how-to article, you learned how to install and enable security features with Advanced Container Networking Services for your AKS cluster.

* For more information about Advanced Container Networking Services for Azure Kubernetes Service (AKS), see [What is Advanced Container Networking Services for Azure Kubernetes Service (AKS)?](advanced-container-networking-services-overview.md).