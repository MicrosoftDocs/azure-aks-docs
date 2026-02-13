---
title: Azure Kubernetes Service (AKS) Managed Gateway API Installation (preview)
description: Learn how to install the Kubernetes Gateway API Custom Resource Definitions (CRDs) on your Azure Kubernetes Service (AKS) cluster using the Managed Gateway API installation.
ms.topic: how-to
ms.service: azure-kubernetes-service
author: nshankar
ms.author: nshankar
ms.reviewer: schaffererin
ms.date: 01/26/2026
# Customer intent: "As a Kubernetes administrator, I want to install the Kubernetes Gateway API Custom Resource Definitions (CRDs) to create Kubernetes Gateway API resources on my cluster."
---

# Install Managed Gateway API CRDs on Azure Kubernetes Service (AKS) (preview)

The [Kubernetes Gateway API][kubernetes-gateway-api] is a specification for traffic management on Kubernetes clusters. The specification enhances [Ingress API][kubernetes-ingress-api], which lacks a unified and provider-agnostic approach for advanced traffic routing.

The Managed Gateway API Installation for Azure Kubernetes Service (AKS) installs the Custom Resource Definitions (CRDs) for the Kubernetes Gateway API. With the Managed Gateway API installation, you can use Gateway API functionality in a fully supported mode on AKS.

## Prerequisites

- You must use an AKS add-on or extension that implements the Gateway API, such as the [Istio add-on][istio-gateway-api]. If using the Istio add-on, you must be on minor revision `asm-1-26` or later to ensure compatibility with the Managed Gateway API installation. To deploy this add-on, see [Deploy Istio-based service mesh add-on for Azure Kubernetes Service (AKS)][istio-deploy].

  - If you already have an existing installation of the Gateway API CRDs on your cluster, you must meet the following requirements:

    - Only `standard` channel CRDs can be installed on your cluster. `Experimental` channel CRDs are disallowed, and you must uninstall them before enabling the Managed Gateway API.
    - The Gateway API bundle version must be compatible with your cluster's Kubernetes version. For more information, see the [Supported Kubernetes versions for Gateway API bundle versions](#supported-kubernetes-versions-for-gateway-api-bundle-versions) section.

- The [`aks-preview` extension installed and updated to version `19.0.0b4` or later](#install-or-update-the-aks-preview-extension).
- The [`ManagedGatewayAPIPreview` feature flag registered to your subscription](#register-the-managed-gateway-api-preview-feature-flag).

### Install or update the `aks-preview` extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

- Install the `aks-preview` extension or update to the latest version of the extension using the [`az extension add`][az-extension-add] and [`az extension update`][az-extension-update] commands. if you're using Azure CLI. You must use `aks-preview` version `19.0.0b4` and later.

    ```azurecli-interactive
    # Install the aks-preview extension
    az extension add --name aks-preview
    
    # Update the aks-preview extension to the latest version
    az extension update --name aks-preview
    ```

### Register the Managed Gateway API preview feature flag

- Register the `ManagedGatewayAPIPreview` feature flag using the [`az feature register`](/cli/azure/feature#az-feature-register) command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "ManagedGatewayAPIPreview"
    ```

## Supported Kubernetes versions for Gateway API bundle versions

The following table outlines the supported Kubernetes versions for your AKS cluster for each Gateway API bundle version for the `standard` channel:

| Gateway API bundle version | Supported Kubernetes versions |
|----------------------------|-------------------------------|
| v1.2.1                     | v1.26.0 - v1.33.x             |
| v1.3.0                     | v1.34.0+                      |

> [!NOTE]
> If you upgrade your AKS cluster to a new minor version after installing the Managed Gateway API CRDs, the CRDs automatically upgrade to the new supported Gateway API bundle version for that Kubernetes version. For instance, if you upgrade from AKS `v1.33.0` to `v1.34.0` and previously had the Managed Gateway API installed for bundle version `v1.2.1`, the CRDs automatically upgrade to bundle version `v1.3.0`.

## Create a new AKS cluster with Managed Gateway API CRDs installed

- Create a new AKS cluster with Managed Gateway API CRDs installed using the [`az aks create`][az-aks-create] command with the `--enable-gateway-api` flag. You can also enable a supported add-on, such as the Istio service mesh add-on, in the same command. The following example command creates a new AKS cluster with the Managed Gateway API installation and the Istio service mesh add-on enabled:

    ```azurecli-interactive
    az aks create --resource-group myResourceGroup --name myAKSCluster --enable-gateway-api --enable-azure-service-mesh
    ```

## Install Managed Gateway API CRDs on an existing AKS cluster

- Install Managed Gateway API CRDs on an existing cluster with a supported implementation enabled using the [`az aks update`][az-aks-update] command with the `--enable-gateway-api` flag.

    ```azurecli-interactive
    az aks update --resource-group myResourceGroup --name myAKSCluster --enable-gateway-api
    ```

## Verify Managed Gateway API CRD installation

1. View the CRDs installed on your cluster using the following `kubectl get crds` command:

   ```bash
   kubectl get crds | grep "gateway.networking.k8s.io"
   ```

    The output should show the installed CRDs, which are part of the Kubernetes Gateway API specification. For example:

    ```output
    gatewayclasses.gateway.networking.k8s.io                           2025-08-29T17:52:36Z
    gateways.gateway.networking.k8s.io                                 2025-08-29T17:52:36Z
    grpcroutes.gateway.networking.k8s.io                               2025-08-29T17:52:36Z
    httproutes.gateway.networking.k8s.io                               2025-08-29T17:52:37Z
    referencegrants.gateway.networking.k8s.io                          2025-08-29T17:52:37Z
    ```

1. Verify the CRDs have the expected annotations and the bundle version matches the [expected Kubernetes version](#supported-kubernetes-versions-for-gateway-api-bundle-versions) for your cluster using the following `kubectl get crds` command:

    ```bash
    kubectl get crd gateways.gateway.networking.k8s.io -ojsonpath={.metadata.annotations} | jq
    ```

    The output should show the expected annotations, including the `gateway.networking.k8s.io/bundle-version` annotation with the expected bundle version for your cluster's Kubernetes version. For example, if your cluster is running Kubernetes `v1.33.0`, the expected bundle version is `v1.2.1`, and the output should be similar to the following:

    ```output
    {
    "api-approved.kubernetes.io": "https://github.com/kubernetes-sigs/gateway-api/pull/3328",
    "app.kubernetes.io/managed-by": "aks",
    "app.kubernetes.io/part-of": <hash>,
    "gateway.networking.k8s.io/bundle-version": "v1.2.1",
    "gateway.networking.k8s.io/channel": "standard"
    }
    ```

## Uninstall Managed Gateway API CRDs on an AKS cluster

- Uninstall Managed Gateway API CRDs on an existing cluster using the [`az aks update`][az-aks-update] command with the `--disable-gateway-api` flag.

    ```azurecli-interactive
    az aks update --resource-group myResourceGroup --name myAKSCluster --disable-gateway-api
    ```

## Related content

- [Configure ingress for Istio service mesh add-on with the Kubernetes Gateway API][istio-gateway-api]

<!-- LINKS -->
[istio-deploy]: ./istio-deploy-addon.md
[istio-gateway-api]: ./istio-gateway-api.md
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[kubernetes-gateway-api]: https://gateway-api.sigs.k8s.io/
[kubernetes-ingress-api]: https://kubernetes.io/docs/concepts/services-networking/ingress/
