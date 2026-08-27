---
title: Upgrade Node Images in Azure Kubernetes Service (AKS)
description: Learn how to upgrade node images in your Azure Kubernetes Service (AKS) cluster to leverage the latest features and ensure optimal performance and security for your containerized applications.
ms.topic: how-to
ms.custom: devx-track-azurecli, innovation-engine
ms.subservice: aks-upgrade
ms.service: azure-kubernetes-service
ms.date: 08/03/2026
author: schaffererin
ms.author: schaffererin
# Customer intent: As a Kubernetes administrator, I want to upgrade node images in my AKS cluster so that I can leverage the latest features and ensure optimal performance and security for my containerized applications.
---

# Upgrade Azure Kubernetes Service (AKS) node images

> [!div class="nextstepaction"]
> [Deploy and Explore](https://go.microsoft.com/fwlink/?linkid=2321849)

Azure Kubernetes Service (AKS) regularly provides new [node images][node-images], so upgrade your node images frequently to use the latest AKS features. Linux node images are updated weekly, and Windows node images are updated monthly. The [AKS release notes](https://github.com/Azure/AKS/releases) include image upgrade announcements. It can take up to two weeks for these updates to roll out across all regions. See the [release tracker][release-tracker] for roll out status. You can also perform node image upgrades automatically and schedule them by using planned maintenance. For more information, see [Automatically upgrade node OS images][auto-upgrade-node-os-image].

AKS recommends [node OS auto-upgrade channels][auto-upgrade-node-os-image], which automatically upgrade your node images or apply security patches during your maintenance windows without changing the Kubernetes version. If you want to manually upgrade your node images, follow the instructions in this article. This article shows you how to upgrade AKS cluster node images and how to update node pool images without upgrading the Kubernetes version. For information on upgrading the Kubernetes version for your cluster, see [Upgrade an AKS cluster][upgrade-cluster].

[!INCLUDE [azure-linux-retirement](includes/azure-linux-retirement.md)]

> [!NOTE]
> Clusters that use Node Auto-Provisioning (NAP) automatically update node images when a new image is available. You can configure a maintenance window to control when NAP picks up a new image, but the window doesn't necessarily determine when existing nodes are disrupted. NAP's drift logic, Karpenter Node Disruption Budgets, and Pod Disruption Budgets control how and when disruption occurs. For more information, see [Node image updates for NAP](node-auto-provisioning-upgrade-image.md).
>
> You can't downgrade a node image version (for example, _AKSUbuntu-2404_ to _AKSUbuntu-2204_, or _AKSUbuntu-2404-202601.27.0_ to _AKSUbuntu-2404-202601.13.0_).

## Prerequisites

- An existing AKS cluster and node pool.
- The [Azure CLI](/cli/azure/install-azure-cli) installed and signed in to your Azure account.
- Permission to retrieve cluster credentials and read and update the AKS cluster and node pools.
- A Bash shell. The commands in this article use Bash environment variable syntax.

Set environment variables for your resource group, cluster, and node pool names to use in the subsequent commands:

```bash
export AKS_RESOURCE_GROUP="<resource-group-name>"
export AKS_CLUSTER="<cluster-name>"
export AKS_NODEPOOL="<node-pool-name>"
```

## Connect to your AKS cluster

1. Connect to your AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials \
        --resource-group $AKS_RESOURCE_GROUP \
        --name $AKS_CLUSTER
    ```

## Check for available node image upgrades

1. Check for available node image upgrades using the [`az aks nodepool get-upgrades`][az-aks-nodepool-get-upgrades] command.

    ```azurecli-interactive
    az aks nodepool get-upgrades \
        --nodepool-name $AKS_NODEPOOL \
        --cluster-name $AKS_CLUSTER \
        --resource-group $AKS_RESOURCE_GROUP
    ```

1. In the output, find and make note of the `latestNodeImageVersion` value. This value is the latest node image version available for your node pool.
1. Check your current node image version to compare with the latest version using the [`az aks nodepool show`][az-aks-nodepool-show] command.

    ```azurecli-interactive
    az aks nodepool show \
        --resource-group $AKS_RESOURCE_GROUP \
        --cluster-name $AKS_CLUSTER \
        --name $AKS_NODEPOOL \
        --query nodeImageVersion
    ```

1. If the `nodeImageVersion` value is different from the `latestNodeImageVersion`, you can upgrade your node image.

## Upgrade all node images in all node pools

1. Upgrade all node images in all node pools in your cluster using the [`az aks upgrade`][az-aks-upgrade] command with the `--node-image-only` flag.

    ```azurecli-interactive
    az aks upgrade \
        --resource-group $AKS_RESOURCE_GROUP \
        --name $AKS_CLUSTER \
        --node-image-only \
        --yes
    ```

1. You can check the status of the node images using the `kubectl get nodes` command.

    > [!NOTE]
    > This command might differ slightly depending on the shell you use. For more information on Windows and PowerShell environments, see the [Kubernetes JSONPath documentation][kubernetes-json-path]. This command lists each node's name alongside the value of its `kubernetes.azure.com/node-image-version` label, which identifies the node's current image version.

    ```bash
    kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.kubernetes\.azure\.com\/node-image-version}{"\n"}{end}'
    ```

1. When the upgrade completes, use the [`az aks show`][az-aks-show] command to get the updated node pool details. The current node image is shown in the `nodeImageVersion` property.

    ```azurecli-interactive
    az aks show \
        --resource-group $AKS_RESOURCE_GROUP \
        --name $AKS_CLUSTER  \
        --query "agentPoolProfiles[].{Name:name, NodeImageVersion:nodeImageVersion}"
    ```

## Upgrade a specific node pool

1. Update the OS image of a node pool without doing a Kubernetes cluster upgrade using the [`az aks nodepool upgrade`][az-aks-nodepool-upgrade] command with the `--node-image-only` flag.

    ```azurecli-interactive
    az aks nodepool upgrade \
        --resource-group $AKS_RESOURCE_GROUP \
        --cluster-name $AKS_CLUSTER \
        --name $AKS_NODEPOOL \
        --node-image-only
    ```

1. You can check the status of the node images with the `kubectl get nodes` command.

    > [!NOTE]
    > This command might differ slightly depending on the shell you use. For more information on Windows and PowerShell environments, see the [Kubernetes JSONPath documentation][kubernetes-json-path]. This command lists each node's name alongside the value of its `kubernetes.azure.com/node-image-version` label, which identifies the node's current image version.

    ```bash
    kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.kubernetes\.azure\.com\/node-image-version}{"\n"}{end}'
    ```

1. When the upgrade completes, use the [`az aks nodepool show`][az-aks-nodepool-show] command to get the updated node pool details. The current node image is shown in the `nodeImageVersion` property.

    ```azurecli-interactive
    az aks nodepool show \
        --resource-group $AKS_RESOURCE_GROUP \
        --cluster-name $AKS_CLUSTER \
        --name $AKS_NODEPOOL \
        --query nodeImageVersion
    ```

## Upgrade node images with node surge

This procedure upgrades the node image for a specific node pool, not all node pools in the cluster. By default, AKS uses one extra node to configure upgrades. To speed up the node image upgrade process, upgrade your node images by using a customizable node surge value.

1. Configure the number of surge nodes for the node pool using the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--max-surge` flag. This setting persists for subsequent upgrades.

    > [!NOTE]
    > To learn more about the trade-offs of various `--max-surge` settings, see [Customize node surge upgrade][max-surge].

    ```azurecli-interactive
    az aks nodepool update \
        --resource-group $AKS_RESOURCE_GROUP \
        --cluster-name $AKS_CLUSTER \
        --name $AKS_NODEPOOL \
        --max-surge 33%
    ```

1. Upgrade the node image using the [`az aks nodepool upgrade`][az-aks-nodepool-upgrade] command with the `--node-image-only` flag.

    ```azurecli-interactive
    az aks nodepool upgrade \
        --resource-group $AKS_RESOURCE_GROUP \
        --cluster-name $AKS_CLUSTER \
        --name $AKS_NODEPOOL \
        --node-image-only
    ```

1. You can check the status of the node images with the `kubectl get nodes` command. This command lists each node's name alongside the value of its `kubernetes.azure.com/node-image-version` label, which identifies the node's current image version.

    ```bash
    kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.kubernetes\.azure\.com\/node-image-version}{"\n"}{end}'
    ```

1. Get the updated node pool details using the [`az aks nodepool show`][az-aks-nodepool-show] command. The current node image is shown in the `nodeImageVersion` property.

    ```azurecli-interactive
    az aks nodepool show \
        --resource-group $AKS_RESOURCE_GROUP \
        --cluster-name $AKS_CLUSTER \
        --name $AKS_NODEPOOL \
        --query nodeImageVersion
    ```

## Related content

- For information about the latest node images, see the [AKS release notes](https://github.com/Azure/AKS/releases).
- Learn how to upgrade the Kubernetes version with [Upgrade an AKS cluster][upgrade-cluster].
- [Automatically apply cluster and node pool upgrades with GitHub Actions][github-schedule].
- Learn more about multiple node pools with [Create multiple node pools][use-multiple-node-pools].
- Learn about upgrading best practices with [AKS patch and upgrade guidance][upgrade-operators-guide].

<!-- LINKS - external -->
[kubernetes-json-path]: https://kubernetes.io/docs/reference/kubectl/jsonpath/

<!-- LINKS - internal -->
[upgrade-cluster]: upgrade-aks-control-plane.md
[release-tracker]: release-tracker.md
[node-images]: node-images.md
[github-schedule]: upgrade-github-actions.md
[use-multiple-node-pools]: create-node-pools.md
[max-surge]: upgrade-aks-node-pools-rolling.md#customize-node-surge
[auto-upgrade-node-os-image]: auto-upgrade-node-os-image.md
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-aks-nodepool-get-upgrades]: /cli/azure/aks/nodepool#az-aks-nodepool-get-upgrades
[az-aks-nodepool-show]: /cli/azure/aks/nodepool#az-aks-nodepool-show
[az-aks-nodepool-upgrade]: /cli/azure/aks/nodepool#az-aks-nodepool-upgrade
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[az-aks-upgrade]: /cli/azure/aks#az-aks-upgrade
[az-aks-show]: /cli/azure/aks#az-aks-show
[upgrade-operators-guide]: /azure/architecture/operator-guides/aks/aks-upgrade-practices
