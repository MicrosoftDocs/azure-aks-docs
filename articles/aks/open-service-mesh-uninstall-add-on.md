---
title: Uninstall the Open Service Mesh (OSM) add-on from your Azure Kubernetes Service (AKS) cluster
description: How to uninstall the Open Service Mesh on Azure Kubernetes Service (AKS) using Azure CLI.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 09/25/2024
author: schaffererin
ms.author: schaffererin

# Customer intent: As a Kubernetes administrator, I want to uninstall the Open Service Mesh add-on from my AKS cluster, so that I can clean up unused resources and prepare for migrating to a compatible service mesh solution.
---

# Uninstall the Open Service Mesh (OSM) add-on from your Azure Kubernetes Service (AKS) cluster

This article shows you how to uninstall the OMS add-on and related resources from your AKS cluster.

> [!WARNING]
> Microsoft has announced the retirement of the [Open Service Mesh (OSM) add-on for AKS](https://azure.microsoft.com/updates?id=open-service-mesh-add-on-for-aks-will-be-retired-on-september-30-2027). The upstream OSM project has also been retired by the [Cloud Native Computing Foundation (CNCF)](https://docs.openservicemesh.io/). Identify any existing OSM configurations and migrate them to equivalent Istio configurations. For migration steps, see [Migration guidance for Open Service Mesh (OSM) configurations to Istio](open-service-mesh-istio-migration-guidance.md).

## Disable the OSM add-on from your cluster

* Disable the OSM add-on from your cluster using the [`az aks disable-addon`][az-aks-disable-addon] command and the `--addons` parameter.

    ```azurecli-interactive
    az aks disable-addons \
      --resource-group myResourceGroup \
      --name myAKSCluster \
      --addons open-service-mesh
    ```

## Remove OSM resources

* Uninstall the remaining resources on the cluster using the `osm uninstall cluster-wide-resources` command.

    ```console
    osm uninstall cluster-wide-resources
    ```

    > [!NOTE]
    > For version 1.1, the command is `osm uninstall mesh --delete-cluster-wide-resources`

    > [!IMPORTANT]
    > You must remove these additional resources after you disable the OSM add-on. Leaving these resources on your cluster may cause issues if you enable the OSM add-on again in the future.

## Next steps

Learn more about [Open Service Mesh][osm].

<!-- LINKS - Internal -->
[az-aks-disable-addon]: /cli/azure/aks#az-aks-disable-addons
[osm]: ./open-service-mesh-about.md

