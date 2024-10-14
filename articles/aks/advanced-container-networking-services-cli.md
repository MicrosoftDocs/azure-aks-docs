---
title: "Set up Advanced Container Networking Services (ACNS) in your Azure Kubernetes Services (AKS) Clusters"
description: Get started with Container Network Security in Advanced Container Networking Services (ACNS) for your AKS cluster using Azure managed Cilium Network Policies.
author: Khushbu-Parekh
ms.author: kparekh
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 10/10/2024
ms.custom: template-how-to-pattern, devx-track-azurecli
---

# Advanced Container Networking Services (ACNS) in your Azure Kubernetes Services (AKS) Clusters

This article shows you how to set up Advanced Container Networking Services in AKS clusters.

## Prerequisites

* An Azure account with an active subscription. If you don't have one, create a [free account](https://azure.microsoft.com/free/?WT.mc_id=A261C142F) before you begin.
[!INCLUDE [azure-CLI-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

* The minimum version of Azure CLI required for the steps in this article is 2.56.0. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).

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

The `az aks create` command with the Advanced Container Networking Services flag, `--enable-acns`, creates a new AKS cluster with all Advanced Container Networking Services (ACNS) features. These features encompasses:
* **Container Network Observability:**  Provides insights into your network traffic. To learn more visit [Container Network Observability](./advanced-network-observability-concepts.md).

* **Container Network Security:** Offers security features like FQDN filtering. To learn more visit  [Container Network Security](./advanced-network-container-services-security-concepts.md).

### [**Cilium**](#tab/cilium)

> [!NOTE]
> Clusters with the Cilium data plane support Container Network Observability starting with Kubernetes version 1.29.

```azurecli-interactive
# Set an environment variable for the AKS cluster name. Make sure to replace the placeholder with your own value.
export CLUSTER_NAME="<aks-cluster-name>"

# Create an AKS cluster
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --generate-ssh-keys \
    --location eastus \
    --max-pods 250 \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --network-dataplane cilium \
    --node-count 2 \
    --pod-cidr 192.168.0.0/16 \
    --kubernetes-version 1.29 \
    --enable-acns
```

### [**Non-Cilium**](#tab/non-cilium)

> [!NOTE]
> [Container Network Security](./advanced-network-container-services-security-concepts.md) feature is not available for Non-cilium clusters

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
    --enable-acns
```

---

## Enable Advanced Container Networking Services on an existing cluster

The [`az aks update`](/cli/azure/aks#az_aks_update) command with the Advanced Container Networking Services flag, `--enable-acns`, updates an existing AKS cluster with all Advanced Container Networking Services features which includes [Container Network Observability](./advanced-network-observability-concepts.md) and the [Container Network Security](./advanced-network-container-services-security-concepts.md) feature.


> [!NOTE]
> Only clusters with the Cilium data plane support Container Network Security features of Advanced Container Networking Services.

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns
```

---

## Disable Container Network Observability 

To disable Container Network Observability features without affecting other Advanced Container Networking Services features, use the  `--disable-acns-observability` 

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --disable-acns-observability 
```

## Disable Container Network Security 

To disable Container Network Security features without affecting other Advanced Container Networking Services features, use the  `--disable-acns-security` 

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --disable-acns-security 
```


## Re-enable Container Network Observability 

To disable Container Network Observability features without affecting other Advanced Container Networking Services features, use the  `--disable-acns-observability` 

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns-observability 
```

## Re-enable Container Network Security 

To disable Container Network Security features without affecting other Advanced Container Networking Services features, use the  `--disable-acns-security` 

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns-security 
```


## Disable Advanced Container Networking Services

The `--disable-acns` flag disables all Advanced Container Networking Services features on an existing AKS cluster which includes Container Network Security and Container Network Observability.

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

In this how-to article, you learned how to install and enable Advanced Container Networking Services for your AKS cluster.

* To create an AKS cluster with Container Network Observability and Azure managed Prometheus and Grafana, see [Setup Container Network Observability for Azure Kubernetes Service (AKS) Azure managed Prometheus and Grafana](advanced-network-observability-cli.md).

* To create an AKS cluster with Container Network Observability and BYO Prometheus and Grafana, see [Setup Container Network Observability for Azure Kubernetes Service (AKS) BYO Prometheus and Grafana](advanced-network-observability-bring-your-own-cli.md).

* To create an AKS cluster with Container Network Security, see [Setup Container Network Security for Azure Kubernetes Service (AKS)](advanced-network-container-services-security-cli.md) on AKS.