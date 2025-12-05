---
title: Azure Kubernetes Service (AKS) Managed Gateway API Installation
description: Install Managed Kubernetes Gateway API on Azure Kubernetes Service
ms.topic: how-to
ms.service: azure-kubernetes-service
author: nshankar
ms.date: 10/21/2025
ms.author: nshankar
# Customer intent: "As a Kubernetes administrator, I want to install the Kubernetes Gateway API Custom Resource Definitions (CRDs) to create Kubernetes Gateway API resources on my cluster."
---

# Install Managed Gateway API Custom Resource Definitions (CRDs) - Preview

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

The [Kubernetes Gateway API][kubernetes-gateway-api] is a specification for traffic management on Kubernetes clusters. It was designed as a successor and enhancement of the [Ingress API][kubernetes-ingress-api], which lacked a unified and provider-agnostic approach for advanced traffic routing.

The Managed Gateway API Installation for Azure Kubernetes Service (AKS) installs the Custom Resource Definitions (CRDs) for the Kubernetes Gateway API. With the Managed Gateway API installation, you can use Gateway API functionality in a fully supported mode on AKS. However, you must also use an AKS add-on or extension that implements the Gateway API, such as [the Istio add-on][istio-gateway-api].

## Requirements and limitations

* You must have at least one add-on installed, such as the [Istio add-on][istio-about], that implements the Gateway API. The add-on must be enabled before, or during enablement of the Managed Gateway Installation. 
* If you already have an existing installation of the Gateway API CRDs on your cluster, then you must only have `standard` channel CRDs installed, and the Gateway API bundle version must be compatible with your cluster's Kubernetes version. See the table for the [bundle version associated with each Kubernetes version](#gateway-api-bundle-version-and-aks-kubernetes-version-mapping).

### Gateway API bundle version and AKS Kubernetes version mapping

The following table outlines the supported Kubernetes versions for your AKS cluster for each Gateway API bundle version for the `standard` channel. `Experimental` channel CRDs are disallowed and must be uninstalled before enabling the Managed Gateway API installation.

| Gateway API Bundle Version | Supported Kubernetes Versions |
|----------------------------|-------------------------------|
| v1.2.1                     | v1.26.0 - v1.33.x             |
| v1.3.0                     | v1.34.0+                      |

> [!NOTE]
> If you upgrade your AKS cluster to a new minor version after installing the Managed Gateway API CRDs, the CRDs will automatically be upgraded to the new supported Gateway API bundle version for that Kubernetes version. For instance, if you upgrade from AKS `v1.33.0` to `v1.34.0` and previously had the Managed Gateway API installed for bundle version `v1.2.1`, the CRDs will automatically be upgraded to bundle version `v1.3.0`.

## Prerequisites

### Install supported Gateway API implementation

Ensure that you have at least one of the following implementations of the Gateway API installed on your cluster:
- [Istio add-on][istio-deploy] minor revision `asm-1-26` or higher. 

### Install the `aks-preview` Azure CLI extension

Install the `aks-preview` extension if you're using Azure CLI. You must use `aks-preview` version `19.0.0b4` or higher.

1. Install the `aks-preview` extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

2. Update to the latest version of the extension using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the Managed Gateway API preview feature

Register the `ManagedGatewayAPIPreview` feature flag by using the [`az feature register`](/cli/azure/feature#az-feature-register) command:

```azurecli-interactive
az feature register --namespace "Microsoft.ContainerService" --name "ManagedGatewayAPIPreview"
```

## Install the Managed Gateway API CRDs

Once you finish the prerequisite steps, you can run the `az aks create` command to install the Managed Gateway API CRDs on a newly created cluster. Note that you must also enable an implementation of the Gateway API to enable the managed CRD installation. See [above](#requirements-and-limitations) for a list of supported implementations.

```azurecli-interactive
 # Example: enable the managed Gateway API installation with the Istio service mesh add-on 
 az aks create -g $RESOURCE_GROUP -n $CLUSTER_NAME --enable-gateway-api --enable-azure-service-mesh
```

To install the Managed Gateway API CRDs on an existing cluster with a supported implementation enabled, you can run:

```azurecli-interactive
 az aks update -g $RESOURCE_GROUP -n $CLUSTER_NAME --enable-gateway-api
```

You should now see the CRDs installed on your cluster:

```bash
kubectl get crds | grep "gateway.networking.k8s.io"
```

```output
gatewayclasses.gateway.networking.k8s.io                           2025-08-29T17:52:36Z
gateways.gateway.networking.k8s.io                                 2025-08-29T17:52:36Z
grpcroutes.gateway.networking.k8s.io                               2025-08-29T17:52:36Z
httproutes.gateway.networking.k8s.io                               2025-08-29T17:52:37Z
referencegrants.gateway.networking.k8s.io                          2025-08-29T17:52:37Z
```

Verify that the CRDs have the expected annotations and that the bundle version matches the [expected Kubernetes version](#gateway-api-bundle-version-and-aks-kubernetes-version-mapping) for your cluster.

```bash
kubectl get crd gateways.gateway.networking.k8s.io -ojsonpath={.metadata.annotations} | jq
```

```output
{
  "api-approved.kubernetes.io": "https://github.com/kubernetes-sigs/gateway-api/pull/3328",
  "app.kubernetes.io/managed-by": "aks",
  "app.kubernetes.io/part-of": <hash>,
  "gateway.networking.k8s.io/bundle-version": "v1.2.1",
  "gateway.networking.k8s.io/channel": "standard"
}
```

## Uninstall the Managed Gateway API CRDs

To uninstall the Managed Gateway API CRDs, you can run the following command:

```azurecli-interactive
 az aks update -g $RESOURCE_GROUP -n $CLUSTER_NAME --disable-gateway-api
```

## Next Steps

* [Install the Istio add-on][istio-deploy]
* [Configure ingress for Istio service mesh add-on with the Kubernetes Gateway API][istio-gateway-api]

[istio-about]: ./istio-about.md
[istio-deploy]: ./istio-deploy-addon.md
[istio-gateway-api]: ./istio-gateway-api.md

[kubernetes-gateway-api]: https://gateway-api.sigs.k8s.io/
[kubernetes-ingress-api]: https://kubernetes.io/docs/concepts/services-networking/ingress/