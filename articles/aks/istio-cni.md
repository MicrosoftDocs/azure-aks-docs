---
title: Enable Istio CNI for Istio-based service mesh add-on for Azure Kubernetes Service
description: Enable Istio CNI for enhanced security in Istio-based service mesh add-on for Azure Kubernetes Service
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.service: azure-kubernetes-service
ms.date: 05/06/2026
ms.author: gerobayopaz
author: german1608
# Customer intent: As a Kubernetes administrator, I want to enable Istio CNI for my Azure Kubernetes Service cluster with Istio service mesh add-on, so that I can improve security by removing privileged network capabilities from application workloads.
---

# Enable Istio CNI for Istio-based service mesh add-on for Azure Kubernetes Service

This article shows you how to enable Istio CNI for the Istio-based service mesh add-on on Azure Kubernetes Service (AKS). Istio CNI improves security by eliminating the need for privileged network capabilities in application workloads within the service mesh.

## Overview

Istio redirects application traffic to the Envoy sidecar proxy using one of two mechanisms:

- **Istio CNI** (`CNIChaining`): A cluster-level CNI plugin configures traffic redirection, so application pods don't need privileged network capabilities. The `istio-validation` init container is added during sidecar injection to verify that traffic redirection is configured correctly.
- **Init containers** (`InitContainers`): Each application pod uses a privileged `istio-init` init container that requires `NET_ADMIN` and `NET_RAW` capabilities to configure traffic redirection. These capabilities often raise security concerns in enterprise environments.

Starting with revision `asm-1-30`, Istio CNI is the default redirection mechanism for new mesh installations. For revisions `asm-1-25` through `asm-1-29`, init containers remain the default and you must explicitly enable Istio CNI. Earlier revisions don't support Istio CNI.

Istio CNI provides the following benefits over init containers:

- **Improves security**: Removes the need for privileged network capabilities (`NET_ADMIN`, `NET_RAW`) from application workloads
- **Simplifies pod security policies**: Application pods only require minimal capabilities
- **Maintains functionality**: Provides the same traffic management capabilities as the traditional init container approach

> [!NOTE]
> Istio CNI is **not** a replacement for [Azure CNI](concepts-network-cni-overview.md) and will not interfere with your normal AKS networking. It is a separate plugin designed to handle Istio’s traffic redirection setup at the node level, improving security by removing the need for privileged init containers in application pods.

## Before you begin

* Install the Azure CLI version 2.86.0 or later. You can run `az --version` to verify the version. To install or upgrade, see [Install Azure CLI][azure-cli-install].
* You need an AKS cluster with the Istio-based service mesh add-on enabled. If you don't have this setup, see [Deploy Istio-based service mesh add-on for Azure Kubernetes Service][istio-deploy-addon].
* Ensure your Istio service mesh is using revision `asm-1-25` or later. You can check the current revision with:

    ```azurecli-interactive
    az aks show --resource-group <resource-group-name> --name <cluster-name> --query 'serviceMeshProfile.istio.revisions'
    ```

### Set environment variables

```bash
export CLUSTER=<cluster-name>
export RESOURCE_GROUP=<resource-group-name>
```

## Enable Istio CNI

### Enable Istio CNI on a new mesh installation

For revisions `asm-1-30` and later, `CNIChaining` is the default proxy redirection mechanism for new installations of the service mesh add-on. You don't need to specify any extra parameters. For revisions `asm-1-25` through `asm-1-29`, enable Istio CNI explicitly by specifying the `--proxy-redirection-mechanism` parameter:

```azurecli-interactive
az aks mesh enable --resource-group ${RESOURCE_GROUP} --name ${CLUSTER} --proxy-redirection-mechanism CNIChaining
```

### Enable Istio CNI on an existing mesh installation

If you already have the Istio service mesh add-on enabled, you can switch to Istio CNI using the following command:

```azurecli-interactive
az aks mesh proxy-redirection-mechanism --resource-group ${RESOURCE_GROUP} --name ${CLUSTER} --mechanism CNIChaining
```

The `asm-1-30` default applies only to new installations, so upgrading an existing mesh doesn't change its redirection mechanism.

> [!NOTE]
> Existing pods won't automatically switch to the `istio-validation` init container. Restart your deployments after enabling Istio CNI so that pods pick up the change (for example, `kubectl rollout restart deployment/<name>`).

## Verify Istio CNI is enabled

Use `az aks get-credentials` to get the credentials for your AKS cluster:

```azurecli-interactive
az aks get-credentials --resource-group ${RESOURCE_GROUP} --name ${CLUSTER}
```

After enabling Istio CNI, verify the installation by checking that the CNI DaemonSet is running:

```bash
kubectl get daemonset -n aks-istio-system
```

You should see the Istio CNI DaemonSet running:

```output
NAME                                      DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
azure-service-mesh-istio-cni-addon-node   3         3         3       3            3           kubernetes.io/os=linux   94s
```

## Deploy workloads and verify behavior

To verify the security improvement, you can deploy the bookinfo sample application and check that workloads use the secure `istio-validation` init container instead of the privileged `istio-init` container.

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
details-v1-799dc5d847-7x9gl     istio-validation        {"drop":["ALL"]}
productpage-v1-99d6d698f-89gpj  istio-validation        {"drop":["ALL"]}
ratings-v1-7545c4bb6c-m7t42     istio-validation        {"drop":["ALL"]}
reviews-v1-8679d76d6c-jz4vg     istio-validation        {"drop":["ALL"]}
reviews-v2-5b9c77895c-b2b7m     istio-validation        {"drop":["ALL"]}
reviews-v3-5b57874f5f-kk9rt     istio-validation        {"drop":["ALL"]}
```

You can also check the YAML for a specific pod to verify the security context:

```bash
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 20 -B 25 "name: istio-validation"
```

The output should show that the `istio-validation` init container has no privileged capabilities:

```output
initContainers:
  - args:
    …
    name: istio-validation
    …
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      privileged: false
      readOnlyRootFilesystem: true
      runAsGroup: 1337
      runAsNonRoot: true
      runAsUser: 1337
```

## Disable Istio CNI

To disable Istio CNI and return to using traditional init containers, use the following command:

```azurecli-interactive
az aks mesh proxy-redirection-mechanism --resource-group ${RESOURCE_GROUP} --name ${CLUSTER} --mechanism InitContainers
```

After disabling Istio CNI:

1. The CNI DaemonSet will be removed:

    ```bash
    kubectl get daemonset azure-service-mesh-istio-cni-addon-node -n aks-istio-system
    ```

    Expected output (no CNI DaemonSet):

    ```output
    Error from server (NotFound): daemonsets.apps "azure-service-mesh-istio-cni-addon-node" not found
    ```

1. New workloads will use the traditional `istio-init` init container with network capabilities. Restart all existing deployments to pick up the change:

    ```bash
    kubectl rollout restart deployment/details-v1
    kubectl rollout restart deployment/productpage-v1
    kubectl rollout restart deployment/ratings-v1
    kubectl rollout restart deployment/reviews-v1
    kubectl rollout restart deployment/reviews-v2
    kubectl rollout restart deployment/reviews-v3
    ```

1. Verify init container name and capabilities:

    ```bash
    kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.initContainers[0].name}{"\t"}{.spec.initContainers[0].securityContext.capabilities}{"\n"}{end}'
    ```

    Expected output should show `istio-init` with network capabilities:

    ```output
    details-v1-57bc58c559-722v8     istio-init        {"add":["NET_ADMIN","NET_RAW"],"drop":["ALL"]}
    productpage-v1-7bb64f657c-jw6gs istio-init        {"add":["NET_ADMIN","NET_RAW"],"drop":["ALL"]}
    ratings-v1-57d5594c75-4zd49     istio-init        {"add":["NET_ADMIN","NET_RAW"],"drop":["ALL"]}
    reviews-v1-7fd8f9cd59-mdcf9     istio-init        {"add":["NET_ADMIN","NET_RAW"],"drop":["ALL"]}
    reviews-v2-7b8bdc9cdf-k9qgb     istio-init        {"add":["NET_ADMIN","NET_RAW"],"drop":["ALL"]}
    reviews-v3-588854d9d7-s2f7j     istio-init        {"add":["NET_ADMIN","NET_RAW"],"drop":["ALL"]}
    ```


## Next steps


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
