---
title: Enable Istio CNI for Istio-based service mesh add-on for Azure Kubernetes Service
description: Enable Istio CNI for enhanced security in Istio-based service mesh add-on for Azure Kubernetes Service
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.service: azure-kubernetes-service
ms.date: 08/21/2025
ms.author: gerobayopaz
author: gerobayopaz
# Customer intent: As a Kubernetes administrator, I want to enable Istio CNI for my Azure Kubernetes Service cluster with Istio service mesh add-on, so that I can improve security by removing privileged network capabilities from application workloads.
---

# Enable Istio CNI for Istio-based service mesh add-on for Azure Kubernetes Service (Preview)

This article shows you how to enable Istio CNI for the Istio-based service mesh add-on on Azure Kubernetes Service (AKS). Istio CNI improves security by eliminating the need for privileged network capabilities in application workloads within the service mesh.

> [!IMPORTANT]
> This feature is currently in preview. For more information about previews, see [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/).

## Overview

By default, Istio service mesh uses privileged init containers (`istio-init`) in each application pod to configure network traffic redirection to the Envoy sidecar proxy. These init containers require `NET_ADMIN` and `NET_RAW` capabilities, which are often flagged as security concerns in enterprise environments.

Istio CNI addresses this security concern by moving the network configuration responsibilities from individual pod init containers to a cluster-level CNI plugin. This approach:

- **Improves security**: Removes the need for privileged network capabilities (`NET_ADMIN`, `NET_RAW`) from application workloads
- **Simplifies pod security policies**: Application pods only require minimal capabilities
- **Maintains functionality**: Provides the same traffic management capabilities as the traditional init container approach

When Istio CNI is enabled, application pods use a minimal `istio-validation` init container that drops all capabilities instead of the privileged `istio-init` container.

## Prerequisites

* You need an AKS cluster with the Istio-based service mesh add-on enabled. If you don't have this setup, see [Deploy Istio-based service mesh add-on for Azure Kubernetes Service][istio-deploy-addon].
* Install the Azure CLI version 2.61.0 or later (TODO UPDATE THIS VERSION ONCE ITS SHIPPED). You can run `az --version` to verify the version. To install or upgrade, see [Install Azure CLI][azure-cli-install].
* Install the `aks-preview` Azure CLI extension:

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

    If you already have the `aks-preview` extension, update it to the latest version:

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

* Register the `IstioCNIPreview` feature flag on your Azure subscription:

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "IstioCNIPreview"
    ```

    Use the following command to check the registration status:

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "IstioCNIPreview"
    ```

    It takes a few minutes for the feature to register. Verify the registration state shows `Registered`:

    ```json
    {
      "id": "/subscriptions/xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/providers/Microsoft.Features/providers/Microsoft.ContainerService/features/IstioCNIPreview",
      "name": "Microsoft.ContainerService/IstioCNIPreview",
      "properties": {
        "state": "Registered"
      },
      "type": "Microsoft.Features/providers/features"
    }
    ```

    When the feature shows as registered, refresh the registration of the `Microsoft.ContainerService` resource provider:

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

* Ensure your Istio service mesh is using revision `asm-1-25` or later. You can check the current revision with:

    ```azurecli-interactive
    az aks show --resource-group <resource-group-name> --name <cluster-name> --query 'serviceMeshProfile.istio.revisions'
    ```

> [!NOTE]
> Istio CNI is not compatible with Ubuntu 20.04 node pools. Ensure your cluster uses Ubuntu 22.04 or Azure Linux node pools.

### Set environment variables

```bash
export CLUSTER=<cluster-name>
export RESOURCE_GROUP=<resource-group-name>
```

## Enable Istio CNI

Use the following command to enable Istio CNI on your AKS cluster:

```azurecli-interactive
az aks mesh enable-istio-cni --resource-group ${RESOURCE_GROUP} --name ${CLUSTER}
```

## Verify Istio CNI is enabled

After enabling Istio CNI, verify the installation by checking that the CNI DaemonSet is running:

```bash
kubectl get daemonset -n aks-istio-system
```

You should see the Istio CNI DaemonSet running:

```output
NAME                     DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
TODO-istio-cni-node      3         3         3       3            3           <none>          2m
```

## Deploy and verify workload behavior

To demonstrate the security improvement, deploy the bookinfo sample application and verify that workloads use the secure `istio-validation` init container instead of the privileged `istio-init` container.

### Deploy sample application

First, enable sidecar injection for the default namespace:

```bash
# Get the current Istio revision
REVISION=$(az aks show --resource-group ${RESOURCE_GROUP} --name ${CLUSTER} --query 'serviceMeshProfile.istio.revisions[0]' -o tsv)

# Label the namespace for sidecar injection
kubectl label namespace default istio.io/rev=${REVISION}
```

Deploy the bookinfo sample application:

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.25/samples/bookinfo/platform/kube/bookinfo.yaml
```

### Verify secure init container usage

Check that the deployed pods use the secure `istio-validation` init container instead of `istio-init`:

```bash
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.initContainers[0].name}{"\t"}{.spec.initContainers[0].securityContext.capabilities}{"\n"}{end}'
```

Expected output should show `istio-validation` as the init container with dropped capabilities:

```output
details-v1-xxxxxx        istio-validation    {"drop":["ALL"]}
productpage-v1-xxxxxx    istio-validation    {"drop":["ALL"]}
ratings-v1-xxxxxx        istio-validation    {"drop":["ALL"]}
reviews-v1-xxxxxx        istio-validation    {"drop":["ALL"]}
reviews-v2-xxxxxx        istio-validation    {"drop":["ALL"]}
reviews-v3-xxxxxx        istio-validation    {"drop":["ALL"]}
```

You can also describe a specific pod to verify the security context:

```bash
kubectl describe pod <pod-name> | grep -A 10 -B 5 "istio-validation"
```

The output should show that the `istio-validation` init container has no privileged capabilities:

```output
Init Containers:
  istio-validation:
    Container ID:  containerd://...
    Image:         mcr.microsoft.com/oss/istio/proxyv2:...
    ...
    Security Context:
      capabilities:
        drop:
        - ALL
      runAsGroup:     1337
      runAsNonRoot:   true
      runAsUser:      1337
```

## Disable Istio CNI

To disable Istio CNI and return to using traditional init containers, use the following command:

```azurecli-interactive
az aks mesh disable-istio-cni --resource-group ${RESOURCE_GROUP} --name ${CLUSTER}
```

After disabling Istio CNI:

1. The CNI DaemonSet will be removed:

    ```bash
    kubectl get daemonset -n aks-istio-system
    ```

    Expected output (no CNI DaemonSet):

    ```output
    No resources found in aks-istio-system namespace.
    ```

2. New workloads will use the traditional `istio-init` init container with network capabilities:

    ```bash
    # Restart deployments to pick up the change
    kubectl rollout restart deployment/details-v1
    kubectl rollout restart deployment/productpage-v1
    kubectl rollout restart deployment/ratings-v1
    kubectl rollout restart deployment/reviews-v1
    kubectl rollout restart deployment/reviews-v2
    kubectl rollout restart deployment/reviews-v3

    # Verify init container name and capabilities
    kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.initContainers[0].name}{"\t"}{.spec.initContainers[0].securityContext.capabilities}{"\n"}{end}'
    ```

    Expected output should show `istio-init` with network capabilities:

    ```output
    details-v1-xxxxxx        istio-init    {"add":["NET_ADMIN","NET_RAW"]}
    productpage-v1-xxxxxx    istio-init    {"add":["NET_ADMIN","NET_RAW"]}
    ratings-v1-xxxxxx        istio-init    {"add":["NET_ADMIN","NET_RAW"]}
    reviews-v1-xxxxxx        istio-init    {"add":["NET_ADMIN","NET_RAW"]}
    reviews-v2-xxxxxx        istio-init    {"add":["NET_ADMIN","NET_RAW"]}
    reviews-v3-xxxxxx        istio-init    {"add":["NET_ADMIN","NET_RAW"]}
    ```


## Next steps

<!-- TODO: Add troubleshooting content -->

* [Deploy external or internal ingresses for Istio service mesh add-on][istio-deploy-ingress]
* [Configure Istio-based service mesh add-on for Azure Kubernetes Service][istio-meshconfig]
* [About Istio-based service mesh add-on for Azure Kubernetes Service][istio-about]

<!-- External Links -->

<!-- Internal Links -->
[istio-deploy-addon]: istio-deploy-addon.md
[istio-deploy-ingress]: istio-deploy-ingress.md
[istio-meshconfig]: istio-meshconfig.md
[istio-about]: istio-about.md
[azure-cli-install]: /cli/azure/install-azure-cli
