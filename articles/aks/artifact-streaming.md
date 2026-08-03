---
title: Reduce Time to Deployment with Artifact Streaming on Azure Kubernetes Service (AKS)
description: Learn how to enable Artifact Streaming on Azure Kubernetes Service (AKS) to reduce time to deployment and idle compute time.
author: allyford
ms.author: allyford
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.topic: how-to
ms.date: 05/05/2026
ms.subservice: aks-nodes
---

# Reduce time to deployment with Artifact Streaming on Azure Kubernetes Service (AKS) with Azure Container Registry (ACR)

Large container images can increase image pull time and delay workload deployment. [Artifact Streaming](./artifact-streaming-overview.md) allows you to stream container images from Azure Container Registry (ACR) to Azure Kubernetes Service (AKS). AKS only pulls the necessary layers for initial pod startup, reducing the time it takes to deploy your workloads.

This article describes how to enable and disable the Artifact Streaming feature on your AKS node pools to stream artifacts from ACR.

## Prerequisites

- An Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).
- [Enable Artifact Streaming on ACR](#enable-artifact-streaming-on-acr).
- Azure CLI version 2.87.0 or later. Run `az --version` to find your version. If you need to install or upgrade, see [Install Azure CLI][azure-cli-install].
- This feature requires Kubernetes version 1.25 or later. To check your AKS cluster version, see [Check for available AKS cluster upgrades][aks-upgrade].
- An existing AKS cluster with ACR integration. If you don't have one, you can create one using [Authenticate with ACR from AKS][acr-auth-aks].
- The [Azure Kubernetes Service Contributor Role][aks-contributor-role] is required to modify node pool configurations.

## Limitations

- Only images with Linux AMD64 architecture are supported.
- Windows-based container images and ARM64 images aren't supported.
- Only the AMD64 architecture is supported for multi-architecture images.
- Ubuntu based node pools in AKS must use Ubuntu version 20.04 or higher.
- Only Premium SKU ACR registries are supported.
- CMK (Customer-Managed Keys) registries aren't supported.
- Kubernetes `regcred`, such as `imagePullSecrets`, isn't supported. Image pulls from ACR using [non-Entra scope-mapped token credentials](/azure/container-registry/container-registry-token-based-repository-permissions) or [ACR admin user credentials](/azure/container-registry/container-registry-authentication?tabs=azure-cli#admin-account) default to non-Artifact Streaming pulls, even if the node pool and image are enabled for streaming.
- Artifact Streaming only supports image pulls by tag. Artifact Streaming works by resolving image pulls by tag to a streaming variant of the image. If image pulls are done by digest, you can't use Artifact Streaming.

## Enable Artifact Streaming on ACR

1. Create an Azure resource group to hold your ACR instance using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --name myStreamingTest --location westus
    ```

1. Create a new Premium SKU ACR using the [`az acr create`][az-acr-create] command with the `--sku Premium` flag.

    ```azurecli-interactive
    az acr create --resource-group myStreamingTest --name mystreamingtest --sku Premium
    ```

1. Configure the default ACR instance for your subscription using the [`az configure`][az-configure] command.

    ```azurecli-interactive
    az configure --defaults acr="mystreamingtest"
    ```

1. Push or import an image to the registry using the [`az acr import`][az-acr-import] command.

    ```azurecli-interactive
    az acr import --source docker.io/jupyter/all-spark-notebook --repository jupyter/all-spark-notebook
    ```

1. Create a streaming artifact from the image using the [`az acr artifact-streaming create`][az-acr-artifact-streaming-create] command.

    ```azurecli-interactive
    az acr artifact-streaming create --image jupyter/all-spark-notebook:latest
    ```

1. Verify the generated Artifact Streaming using the [`az acr manifest list-referrers`][az-acr-manifest-list-referrers] command.

    ```azurecli-interactive
    az acr manifest list-referrers --name jupyter/all-spark-notebook:latest
    ```

## Enable Artifact Streaming on AKS

You can enable Artifact Streaming on new or existing node pools in your AKS cluster with ACR integration.

> [!NOTE]
> If you don't have a Premium tier ACR integrated with your AKS cluster, you can't use Artifact Streaming on AKS.

### Enable Artifact Streaming on a new node pool

Create a new AKS node pool with Artifact Streaming enabled using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--enable-artifact-streaming` flag.

```azurecli-interactive
az aks nodepool add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myNodePool \
    --enable-artifact-streaming
```

### Enable Artifact Streaming on an existing node pool

Enable Artifact Streaming on an existing AKS node pool using the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--enable-artifact-streaming` flag.

```azurecli-interactive
az aks nodepool update \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myNodePool \
    --enable-artifact-streaming
```

## Disable Artifact Streaming on an existing node pool

Disable Artifact Streaming on an existing AKS node pool using the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--disable-artifact-streaming` flag.

```azurecli-interactive
az aks nodepool update \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myNodePool \
    --disable-artifact-streaming
```

## Check Artifact Streaming enablement status

Check if Artifact Streaming is enabled on an AKS node pool using the [`az aks nodepool show`][az-aks-nodepool-show] command with the `--query` flag set to `artifactStreamingProfile`.

```azurecli-interactive
az aks nodepool show \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myNodePool \
    --query artifactStreamingProfile
```

In the output, check the `Enabled` field. `true` means Artifact Streaming is enabled, and `false` means Artifact Streaming is disabled.

## Related content

This article describes how to enable and disable Artifact Streaming on your AKS node pools to stream artifacts from ACR and reduce deployment times. To learn more about working with container images in AKS, see [Best practices for container image management and security in AKS][aks-image-management].

<!-- LINKS -->
[acr-auth-aks]: ./cluster-container-registry-integration.md
[aks-upgrade]: ./upgrade-cluster.md
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[aks-image-management]: ./operator-best-practices-container-image-management.md
[az-group-create]: /cli/azure/group#az-group-create
[az-acr-create]: /cli/azure/acr#az-acr-create
[az-configure]: /cli/azure#az-configure
[az-acr-import]: /cli/azure/acr#az-acr-import
[az-acr-artifact-streaming-create]: /cli/azure/acr/artifact-streaming#az-acr-artifact-streaming-create
[az-acr-manifest-list-referrers]: /cli/azure/acr/manifest#az-acr-manifest-list-referrers
[az-aks-nodepool-show]: /cli/azure/aks/nodepool#az-aks-nodepool-show
[aks-contributor-role]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-contributor-role
[azure-cli-install]: /cli/azure/install-azure-cli
