---
title: Configure kube-proxy (iptables/IPVS/nftables) (Preview)
titleSuffix: Azure Kubernetes Service
description: Learn how to configure kube-proxy to utilize different load balancing configurations with Azure Kubernetes Service (AKS).
ms.subservice: aks-networking
ms.custom: devx-track-azurecli
ms.topic: how-to
ms.date: 01/28/2026
ms.author: davidsmatlak
author: davidsmatlak

# Customer intent: As a cluster operator, I want to configure kube-proxy settings in my AKS environment so that I can optimize load balancing for my Kubernetes services.
---

# Configure `kube-proxy` in Azure Kubernetes Service (AKS) (Preview)

`kube-proxy` is a component of Kubernetes that handles routing traffic for services within the cluster. There are three backends available for Layer 3/4 load balancing in upstream `kube-proxy`: `iptables`, `IPVS`, and `nftables`.

- `iptables` is the default backend used in many Kubernetes clusters. It's simple and well-supported, but not as efficient or intelligent as `IPVS`.
- `IPVS` uses the Linux Virtual Server, a Layer 3/4 load balancer built into the Linux kernel. `IPVS` provides many advantages over the default `iptables` configuration, including state awareness, connection tracking, and more intelligent load balancing. `IPVS` _doesn't support Azure Network Policy_.
- `nftables` is the successor to the `iptables` API and is designed to provide better performance and scalability than `iptables`. The `nftables` proxy mode is essentially a replacement for both the `iptables` and `IPVS` modes, with better performance than either of them, and is recommended as a replacement for `IPVS`.

For more information, see the [Kubernetes documentation on kube-proxy](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/).

> [!NOTE]
> You can disable the AKS-managed `kube-proxy` `DaemonSet` to support [bring-your-own CNI][aks-byo-cni].

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Before you begin

- If you're using the Azure CLI, you need the `aks-preview` extension. See [Install the `aks-preview` Azure CLI extension](#install-the-aks-preview-azure-cli-extension).
- If you're using Azure Resource Manager or the REST API, the AKS API version must be _2022-08-02-preview_ or later. Specifically for `nftables` mode, the version must be _2025-09-02-preview_ or later.
- You need to register the `KubeProxyConfigurationPreview` feature flag. See [Register the `KubeProxyConfigurationPreview` feature flag](#register-the-kubeproxyconfigurationpreview-feature-flag).

### Install the `aks-preview` Azure CLI extension

1. Install the `aks-preview` extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the `KubeProxyConfigurationPreview` feature flag

1. Register the `KubeProxyConfigurationPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "KubeProxyConfigurationPreview"
    ```

    It takes a few minutes for the status to show _Registered_.

1. Verify the registration status using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "KubeProxyConfigurationPreview"
    ```

1. When the status shows _Registered_, refresh the registration of the `Microsoft.ContainerService` resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

## `kube-proxy` configuration options

You can view the full `kube-proxy` configuration structure in the [AKS Cluster Schema][aks-schema-kubeproxyconfig].

- `enabled`: Determines deployment of the `kube-proxy` DaemonSet. Defaults to `true`.
- `mode`: You can set to either `IPTABLES`, `IPVS` or `NFTABLES`. Defaults to `IPTABLES`.
- `ipvsConfig`: If `mode` is `IPVS`, this object contains IPVS-specific configuration properties.
  - `scheduler`: Determines which connection scheduler to use. Supported values include:
    - `LeastConnection`: Sends connections to the backend pod with the fewest connections.
    - `RoundRobin`: Evenly distributes connections between backend pods.
  - `tcpFinTimeoutSeconds`: Sets the timeout length value after a TCP session receives a FIN.
  - `tcpTimeoutSeconds`: Sets the timeout length value for idle TCP sessions.
  - `udpTimeoutSeconds`: Sets the timeout length value for idle UDP sessions.

`IPVS` load balancing operates in each node independently and is only aware of connections that flow through the local node. This means that while `LeastConnection` results in a more even load under a higher number of connections, when a low number of connections occur (`# connects < 2 * node count`), traffic might be unbalanced.

## Use `kube-proxy` in a new or existing AKS cluster

The `kube-proxy` configuration is a cluster-wide setting. You don't need to update your services.

A change to the `kube-proxy` configuration might cause a slight interruption in cluster service traffic flow.

1. Create a configuration file with the desired `kube-proxy` configuration.

    - `IPVS`: For example, the following configuration enables `IPVS` with the `LeastConnection` scheduler and sets the TCP timeout to 900 seconds.

      ```json
      {
        "enabled": true,
        "mode": "IPVS",
        "ipvsConfig": {
          "scheduler": "LeastConnection",
          "tcpTimeoutSeconds": 900,
          "tcpFinTimeoutSeconds": 120,
          "udpTimeoutSeconds": 300
        }
      }
      ```

    - `nftables`: For example, the following configuration enables `nftables` mode.

      ```json
      {
        "enabled": true,
        "mode": "NFTABLES"
      }
      ```

1. Create a new cluster or update an existing cluster with the configuration file using the [`az aks create`][az-aks-create] or [`az aks update`][az-aks-update] commands. Use the `--kube-proxy-config` parameter to specify the configuration file.

    ```azurecli-interactive
    # Create a new cluster
    az aks create \
      --resource-group <resourceGroup> \
      --name <clusterName> \
      --kube-proxy-config kube-proxy.json \
      --generate-ssh-keys

    # Update an existing cluster
    az aks update \
      --resource-group <resourceGroup> \
      --name <clusterName> \
      --kube-proxy-config kube-proxy.json
    ```

## Next steps

This article described how to configure `kube-proxy` in Azure Kubernetes Service (AKS). To learn more about load balancing in AKS, see the following articles:

- [Use a public standard load balancer in Azure Kubernetes Service (AKS)](load-balancer-standard.md).
- [Use an internal load balancer with Azure Kubernetes Service (AKS)](internal-lb.md).

<!-- LINKS - External -->
[aks-schema-kubeproxyconfig]: /azure/templates/microsoft.containerservice/managedclusters?pivots=deployment-language-bicep#containerservicenetworkprofilekubeproxyconfig

<!-- LINKS - Internal -->
[aks-byo-cni]: use-byo-cni.md
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
