---
title: Use Service Tags for API Server Authorized IP Ranges in Azure Kubernetes Service (AKS) (preview)
description: Learn how to use service tags to specify authorized IP ranges for the API server in Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.date: 10/29/2026
ms.author: schaffererin
author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-security
ai-usage: ai-assisted
# Customer intent: As a cluster operator, I want to use service tags to specify authorized IP ranges for the API server in AKS.
---

# Use service tags for API server authorized IP ranges in Azure Kubernetes Service (AKS) (preview)

Service tags for API server authorized IP ranges is a preview feature that allows you to use service tags to specify authorized IP ranges for the API server in Azure Kubernetes Service (AKS). This feature simplifies the management of authorized IP ranges by allowing you to use predefined service tags instead of manually specifying individual IP addresses or CIDR ranges.

You can use service tags with public AKS clusters, including clusters that use [API Server VNet Integration][api-server-vnet-integration]. Authorized IP ranges restrict access to the API server's public endpoint, not its private endpoint.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

- Azure CLI version 2.85.0 or later installed and configured, as required by the current `aks-preview` extension. Check your version using the `az --version` command. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
- The latest [`aks-preview` Azure CLI extension](#install-the-aks-preview-azure-cli-extension) installed. Service-tag inputs to `az aks create` and `az aks update` require the extension, even if your cluster already uses API Server VNet Integration.
- The [`EnableServiceTagAuthorizedIPPreview` feature flag](#register-the-service-tag-authorized-ip-feature-flag) registered in your Azure subscription.

## Limitations

- You can't configure authorized IP ranges for a private cluster.
- Only one non-common service tag is allowed. Common tags, such as `AzureCloud`, don't count toward this limit. For example, `AzureCloud,AzureCloud.eastus2` is allowed, but `AzureCloud.westus2,AzureCloud.eastus2` isn't.
- You can combine service tags with IP addresses and CIDR ranges. Public clusters with API Server VNet Integration support up to 2,000 configured entries. Each service tag counts as one entry, regardless of how many IP prefixes it contains. For other cluster limits, see [API server authorized IP ranges][api-server-authorized-ip-ranges].
- You can't combine `0.0.0.0/32` with a service tag or another IP range.
- Service tag names are case-insensitive.

> [!NOTE]
> Allowed ranges are combined. Adding a regional tag alongside `AzureCloud` doesn't restrict access to that region. Use only the regional tag if you want to allow only that region's IP ranges.

## Install the `aks-preview` Azure CLI extension

1. Install the Azure CLI preview extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview --allow-preview true
    ```

1. Update the extension to make sure you have the latest version using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview --allow-preview true
    ```

## Register the service tag authorized IP feature flag

1. Register the `EnableServiceTagAuthorizedIPPreview` feature flag using the [`az feature register`][az-feature-register] command. It takes a few minutes for the registration to complete.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "EnableServiceTagAuthorizedIPPreview"
    ```

    Example output:

    ```output
    {
      "id": "/subscriptions/<subscription-id>/providers/Microsoft.ContainerService/features/EnableServiceTagAuthorizedIPPreview",
      "name": "EnableServiceTagAuthorizedIPPreview",
      "properties": {
        "state": "Registering"
      },
      "type": "Microsoft.ContainerService/features"
    }
    ```

1. Once the feature flag state changes from `Registering` to `Registered`, refresh the registration of the `Microsoft.ContainerService` resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace "Microsoft.ContainerService"
    ```

1. Verify the registration using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "EnableServiceTagAuthorizedIPPreview"
    ```

    Example output:

    ```output
    {
      "id": "/subscriptions/<subscription-id>/providers/Microsoft.ContainerService/features/EnableServiceTagAuthorizedIPPreview",
      "name": "EnableServiceTagAuthorizedIPPreview",
      "properties": {
        "state": "Registered"
      },
      "type": "Microsoft.ContainerService/features"
    }
    ```

## Create an AKS cluster with service tag authorized IP ranges

- Create a cluster with service tag authorized IP ranges using the [`az aks create`][az-aks-create] command with the `--api-server-authorized-ip-ranges` parameter. The following example creates a cluster named _myAKSCluster_ in the _myResourceGroup_ resource group and allows connections from IP addresses covered by the `AzureCloud` service tag and from an additional IP address:

    ```azurecli-interactive
    az aks create --resource-group myResourceGroup --name myAKSCluster --api-server-authorized-ip-ranges AzureCloud,20.20.20.20
    ```

    > [!NOTE]
    > A client whose public source IP address is covered by the service tag can reach the API server. Network access doesn't replace Kubernetes authentication or authorization.

### Create a public cluster with API Server VNet Integration

Include `--enable-apiserver-vnet-integration` when you create the cluster. The following example creates a public cluster with Azure CNI Overlay and allows clients whose public source IP addresses are covered by `AzureCloud.westus2`:

```azurecli-interactive
az aks create \
    --resource-group myResourceGroup \
    --name myASVICluster \
    --location westus2 \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --enable-apiserver-vnet-integration \
    --api-server-authorized-ip-ranges AzureCloud.westus2
```

Choose a tag that covers your clients' public source IP addresses. The tag's region doesn't have to match the cluster's region. For networking prerequisites and availability, see [API Server VNet Integration][api-server-vnet-integration].

## Update service tag authorized IP ranges

Use the [`az aks update`][az-aks-update] command to replace the authorized ranges on an existing public cluster, including a cluster with API Server VNet Integration. Include every service tag, IP address, and CIDR range that you want to keep; the update replaces the entire list.

The following example allows the `AzureCloud.eastus2` service tag and an additional client IP address. Replace `<your-public-ip-address>` with your client's public IPv4 address:

```azurecli-interactive
az aks update \
    --resource-group myResourceGroup \
    --name myASVICluster \
    --api-server-authorized-ip-ranges "AzureCloud.eastus2,<your-public-ip-address>/32"
```

Verify the configured ranges using the [`az aks show`][az-aks-show] command:

```azurecli-interactive
az aks show \
    --resource-group myResourceGroup \
    --name myASVICluster \
    --query apiServerAccessProfile.authorizedIpRanges \
    --output json
```

<!-- LINKS - internal -->
[api-server-authorized-ip-ranges]: api-server-authorized-ip-ranges.md
[api-server-vnet-integration]: api-server-vnet-integration.md
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-show]: /cli/azure/aks#az-aks-show
[install-azure-cli]: /cli/azure/install-azure-cli
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register
