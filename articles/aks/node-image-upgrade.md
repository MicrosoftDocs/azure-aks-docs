---
title: Upgrade Azure Kubernetes Service (AKS) node images
description: Learn how to upgrade the images on AKS cluster nodes and node pools.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.subservice: aks-upgrade
ms.service: azure-kubernetes-service
ms.date: 09/20/2024
author: schaffererin
ms.author: schaffererin
---

# Upgrade Azure Kubernetes Service (AKS) node images

Azure Kubernetes Service (AKS) regularly provides new node images, so it's beneficial to upgrade your node images frequently to use the latest AKS features. Linux node images are updated weekly, and Windows node images are updated monthly. Image upgrade announcements are included in the [AKS release notes](https://github.com/Azure/AKS/releases), and it can take up to a week for these updates to be rolled out across all regions. You can also perform node image upgrades automatically and schedule them using planned maintenance. For more information, see [Automatically upgrade node images][auto-upgrade-node-image].

This article shows you how to upgrade AKS cluster node images and how to update node pool images without upgrading the Kubernetes version. For information on upgrading the Kubernetes version for your cluster, see [Upgrade an AKS cluster][upgrade-cluster].

> [!NOTE]
> The AKS cluster must use virtual machine scale sets for the nodes.
>
> It's not possible to downgrade a node image version (for example *AKSUbuntu-2204 to AKSUbuntu-1804*, or *AKSUbuntu-2204-202308.01.0 to AKSUbuntu-2204-202307.27.0*).

## Check for available node image upgrades

1. Check for available node image upgrades using the [`az aks nodepool get-upgrades`][az-aks-nodepool-get-upgrades] command.

    ```azurecli-interactive
    az aks nodepool get-upgrades \
        --nodepool-name <node-pool-name> \
        --cluster-name <cluster-name> \
        --resource-group <resource-group>
    ```

1. In the output, find and make note of the `latestNodeImageVersion` value. This value is the latest node image version available for your node pool.
1. Check your current node image version to compare with the latest version using the [`az aks nodepool show`][az-aks-nodepool-show] command.

    ```azurecli-interactive
    az aks nodepool show \
        --resource-group <resource-group> \
        --cluster-name <cluster-name> \
        --name <node-pool-name> \
        --query nodeImageVersion
    ```

1. If the `nodeImageVersion` value is different from the `latestNodeImageVersion`, you can upgrade your node image.

## Upgrade all node images in all node pools

1. Upgrade all node images in all node pools in your cluster using the [`az aks upgrade`][az-aks-upgrade] command with the `--node-image-only` flag.

    ```azurecli-interactive
    az aks upgrade \
        --resource-group <resource-group> \
        --name <cluster-name> \
        --node-image-only
    ```

1. You can check the status of the node images using the `kubectl get nodes` command.

    > [!NOTE]
    > This command might differ slightly depending on the shell you use. For more information on Windows and PowerShell environments, see the [Kubernetes JSONPath documentation][kubernetes-json-path].

    ```bash
    kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.kubernetes\.azure\.com\/node-image-version}{"\n"}{end}'
    ```

1. When the upgrade completes, use the [`az aks show`][az-aks-show] command to get the updated node pool details. The current node image is shown in the `nodeImageVersion` property.

    ```azurecli-interactive
    az aks show \
        --resource-group <resource-group> \
        --name <cluster-name>
    ```

## Upgrade a specific node pool

1. Update the OS image of a node pool without doing a Kubernetes cluster upgrade using the [`az aks nodepool upgrade`][az-aks-nodepool-upgrade] command with the `--node-image-only` flag.

    ```azurecli-interactive
    az aks nodepool upgrade \
        --resource-group <resource-group> \
        --cluster-name <cluster-name> \
        --name <node-pool-name> \
        --node-image-only
    ```

1. You can check the status of the node images with the `kubectl get nodes` command.

    > [!NOTE]
    > This command may differ slightly depending on the shell you use. For more information on Windows and PowerShell environments, see the [Kubernetes JSONPath documentation][kubernetes-json-path].

    ```bash
    kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.kubernetes\.azure\.com\/node-image-version}{"\n"}{end}'
    ```

1. When the upgrade completes, use the [`az aks nodepool show`][az-aks-nodepool-show] command to get the updated node pool details. The current node image is shown in the `nodeImageVersion` property.

    ```azurecli-interactive
    az aks nodepool show \
        --resource-group <resource-group> \
        --cluster-name <cluster-name> \
        --name <node-pool-name>
    ```

## Upgrade node images with node surge

To speed up the node image upgrade process, you can upgrade your node images using a customizable node surge value. By default, AKS uses one extra node to configure upgrades.

1. Upgrade node images with node surge using the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--max-surge` flag to configure the number of nodes used for upgrades.

    > [!NOTE]
    > To learn more about the trade-offs of various `--max-surge` settings, see [Customize node surge upgrade][max-surge].

    ```azurecli-interactive
    az aks nodepool update \
        --resource-group <resource-group> \
        --cluster-name <cluster-name> \
        --name <node-pool-name> \
        --max-surge 33% \
        --no-wait
    ```

1. You can check the status of the node images with the `kubectl get nodes` command.

    ```bash
    kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.kubernetes\.azure\.com\/node-image-version}{"\n"}{end}'
    ```

1. Get the updated node pool details using the [`az aks nodepool show`][az-aks-nodepool-show] to get the updated node pool details. The current node image is shown in the `nodeImageVersion` property.

    ```azurecli-interactive
    az aks nodepool show \
        --resource-group <resource-group> \
        --cluster-name <cluster-name> \
        --name <node-pool-name>
    ```

## Next steps

- For information about the latest node images, see the [AKS release notes](https://github.com/Azure/AKS/releases).
- Learn how to upgrade the Kubernetes version with [Upgrade an AKS cluster][upgrade-cluster].
- [Automatically apply cluster and node pool upgrades with GitHub Actions][github-schedule].
- Learn more about multiple node pools with [Create multiple node pools][use-multiple-node-pools].
- Learn about upgrading best practices with [AKS patch and upgrade guidance][upgrade-operators-guide].

<!-- LINKS - external -->
[kubernetes-json-path]: https://kubernetes.io/docs/reference/kubectl/jsonpath/

<!-- LINKS - internal -->
[upgrade-cluster]: upgrade-aks-cluster.md
[github-schedule]: node-upgrade-github-actions.md
[use-multiple-node-pools]: create-node-pools.md
[max-surge]: upgrade-aks-cluster.md#customize-node-surge-upgrade
[auto-upgrade-node-image]: auto-upgrade-node-image.md
[az-aks-nodepool-get-upgrades]: /cli/azure/aks/nodepool#az_aks_nodepool_get_upgrades
[az-aks-nodepool-show]: /cli/azure/aks/nodepool#az_aks_nodepool_show
[az-aks-nodepool-upgrade]: /cli/azure/aks/nodepool#az_aks_nodepool_upgrade
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az_aks_nodepool_update
[az-aks-upgrade]: /cli/azure/aks#az_aks_upgrade
[az-aks-show]: /cli/azure/aks#az_aks_show
[upgrade-operators-guide]: /azure/architecture/operator-guides/aks/aks-upgrade-practices
