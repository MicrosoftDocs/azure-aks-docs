---
title: Azure Kubernetes Service (AKS) Managed Gateway API Installation
description: Install Managed Kubernetes Gateway API onAzure Kubernetes Service
ms.topic: how-to
ms.service: azure-kubernetes-service
author: nshankar
ms.date: 08/25/2025
ms.author: nshankar
# Customer intent: "As a Kubernetes administrator, I want to install the Kubernetes Gateway API Custom Resource Definitions (CRDs) to create Kubernetes Gateway API resources on my cluster."
---

# Install Managed Gateway API Custom Resource Definitions (CRDs)

The [Kubernetes Gateway API][kubernetes-gateway-api] is a specification for traffic management on Kubernetes clusters. It was designed as a successor and enhancement of the [Ingress API][kubernetes-ingress-api], which lacked a unified and provider-agnostic approach for advanced traffic routing.

The Managed Gateway API Installation for Azure Kubernetes Service (AKS) installs the Custom Resource Definitions (CRDs) for the Kubernetes Gateway API to allow users to leverage Gateway API functionality in a fully-supported mode on AKS. When using the Managed Gateway Installation on AKS, users are required to also have installed an add-on that implements the Gateway API, such as [the Istio add-on][istio-gateway-api].

## Requirements and limitations

* You must have at least one add-on installed, such as the [Istio add-on][istio-about], that implements the Gateway API. The add-on must be enabled prior to, or during enablement of the Managed Gateway Installation. 
* If you already have an existing installation of the Gateway API CRDs on your cluster, then you must only have `standard` channel CRDs installed, your cluster must be on the minimum required Kubernetes version for that specific bundle version. See the [Gateway API bundle version and AKS Kubernetes version mapping](#gateway-api-bundle-version-and-aks-kubernetes-version-mapping) to see the minimum required Kubernetes version for each `standard` channel Gateway API bundle version.

### Gateway API bundle version and AKS Kubernetes version mapping

The following table summarizes the minimum required Kubernetes version for your AKS cluster for each Gateway API bundle version for the `standard` channel. `Experimental` channel CRDs are disallowed and must be uninstalled prior to enabling the Managed Gateway API installation.

| Gateway API Bundle Version | Minimum Kubernetes Version |
|----------------------------|----------------------------|
| v1.2.1                     | v1.26.0                    |
| v1.3.0                     | v1.34.0                    |

> [!NOTE]
> If you upgrade your AKS cluster to a new minor version after installing the Managed Gateway API CRDs, the CRDs will automatically be upgraded to the new minimum Gateway API bundle version. For instance, if you upgrade from AKS `v1.33.0` to `v1.34.0` and previously had the Managed Gateway API installed for bundle version v1.2.1, the CRDs will automatically be upgraded to bundle version `v1.3.0`. 

## Prerequisites

### Install supported Gateway API implementation

Ensure that you have at least one of the following implementations of the Gateway API installed on your cluster:
- [Istio add-on][istio-deploy] minor revision `asm-1-26` or higher. 

### Install the `aks-preview` Azure CLI extension

Install the `aks-preview` extension if you're using Azure CLI. You must use `aks-preview` version `` or higher.

1. Install the `aks-preview` extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

2. Update to the latest version of the extension using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the Managed Gateway API preview feature

Register the `ManagedGatewayAPIPreview` feature flag by using the [`az feature register`](/cli/azure/feature#az_feature_register) command:

```azurecli-interactive
az feature register --namespace "Microsoft.ContainerService" --name "ManagedGatewayAPIPreview"
```

## Install the Managed Gateway API CRDs

Once you've fulfilled the prerequisite steps, you can run the `az aks ` command to install the Managed Gateway API CRDs on your cluster:

```azurecli-interactive

```



## Next Steps

* [Install the Istio add-on][istio-deploy]
* [Configure ingress for Istio service mesh add-on with the Kubernetes Gateway API][istio-gateway-api]

[istio-about]: ./istio-about.md
[istio-deploy]: ./istio-deploy-addon.md
[istio-gateway-api]: ./istio-gateway-api.md

[kubernetes-gateway-api]: https://gateway-api.sigs.k8s.io/
[kubernetes-ingress-api]: https://kubernetes.io/docs/concepts/services-networking/ingress/