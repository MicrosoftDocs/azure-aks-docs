---
title: Use Shared Health Probes for externalTrafficPolicy Cluster Services in Azure Kubernetes Service (AKS) (preview)
description: Learn how to use shared health probes for Services with externalTrafficPolicy set to Cluster in Azure Kubernetes Service (AKS) to improve load balancer efficiency and reduce configuration complexity.
ms.subservice: aks-networking
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.topic: how-to
ms.date: 01/23/2024
ms.author: davidsmatlak
author: davidsmatlak
# Customer intent: As a network administrator or DevOps engineer using AKS, I want to implement shared health probes for Services with externalTrafficPolicy set to Cluster, so that I can improve load balancer efficiency and reduce configuration complexity.
---

# Use shared health probes for `externalTrafficPolicy: Cluster` Services (preview) in Azure Kubernetes Service (AKS)

This article describes how to enable **shared health probe mode** (preview) for Services with `externalTrafficPolicy: Cluster` in Azure Kubernetes Service (AKS). Shared probe mode improves load balancer efficiency, reduces configuration complexity, and provides more accurate node health monitoring.

## About shared health probe mode

In clusters that use `externalTrafficPolicy: Cluster`, Azure Standard Load Balancer (SLB) currently creates a _separate probe per Service_ and targets each Service's `nodePort`.

This design means SLB infers node health from whichever **application pod** answers the probe. As clusters grow, this approach leads to several issues, including:

- **Configuration drift and blind spots**: SLB can't detect a failed or misconfigured `kube‑proxy` if iptables rules are still present.
- **Duplicate health logic**: Readiness must be defined twice. Once in each pod's `readinessProbe`, and again through SLB annotations.
- **Operational overhead**: Each Service on each node is probed every _five seconds_, consuming connections, SNAT ports, and SLB rule space.
- **Feature friction**: Customers can't set `allocateLoadBalancerNodePorts=false`, and workloads like Istio or ingress‑nginx require extra annotations to keep probes working.
- **Troubleshooting confusion**: An unhealthy app, Network Policy rule, or scale‑to‑zero event can make an _entire node_ appear down.

**Shared probe mode** solves these problems by moving to a _single HTTP probe_ for all `externalTrafficPolicy: Cluster` Services. In shared probe mode:

- SLB probes `http://<node‑ip>:10356/healthz`, the standard `kube‑proxy` health endpoint.
- A lightweight sidecar runs next to `kube‑proxy` to relay the probe and handle PROXY protocol when Private Link Service is enabled.

## Benefits of shared probe mode

The following table outlines **key benefits** of using shared probe mode:

| Benefit                | Why it matters                                                            |
|------------------------|---------------------------------------------------------------------------|
| Accurate node health   | SLB now measures `kube‑proxy` directly, not an arbitrary backend pod.     |
| Simpler configuration  | No per‑Service probe annotations; readiness lives solely in the pod spec. |
| Lower traffic overhead | One probe per node instead of _Services × (nodes – 1)_ probes.            |

> [!NOTE]
> Keep the following information in mind when using shared probe mode:
>
> - Services that use `externalTrafficPolicy: Local` are **unchanged**.
> - This feature does **not** address container‑native load balancing.

## Before you begin

- [Install or update the `aks-preview` Azure CLI extension](#install-or-update-the-aks-preview-azure-cli-extension).
- [Register the `EnableSLBSharedHealthProbePreview` feature flag in your Azure subscription](#register-the-enableslbsharedhealthprobepreview-feature-flag).

### Install or update the `aks-preview` Azure CLI extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

- Install the `aks-preview` extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

- Update to the latest version of the `aks-preview` extension using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the `EnableSLBSharedHealthProbePreview` feature flag

1. Register the `EnableSLBSharedHealthProbePreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "EnableSLBSharedHealthProbePreview"
    ```

    It takes a few minutes for the status to show _Registered_.

1. Verify the registration status using the [`az feature show`][az-feature-show] command:

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "EnableSLBSharedHealthProbePreview"
    ```

1. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

## Enable shared probe mode on an AKS cluster

### [Create a new cluster with shared probe mode](#tab/new-cluster-shared-probe-mode)

- Create a new cluster with shared probe mode using the [`az aks create`](/cli/azure/aks#az-aks-create) command with the `--cluster-service-load-balancer-health-probe-mode` parameter set to `shared`.

    ```azurecli-interactive
    az aks create \
      --resource-group $RESOURCE_GROUP \
      --name $CLUSTER_NAME \
      --cluster-service-load-balancer-health-probe-mode shared
    ```

### [Update an existing cluster to use shared probe mode](#tab/existing-cluster-shared-probe-mode)

- Update an existing cluster to use shared probe mode using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--cluster-service-load-balancer-health-probe-mode` parameter set to `shared`.

    ```azurecli-interactive
    az aks update \
      --resource-group $RESOURCE_GROUP \
      --name $CLUSTER_NAME \
      --cluster-service-load-balancer-health-probe-mode shared
    ```

## Next steps

To learn more about AKS Standard Load Balancer configuration options, see [Configure your public standard load balancer in AKS](configure-load-balancer-standard.md).

<!--- LINKS --->
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register
