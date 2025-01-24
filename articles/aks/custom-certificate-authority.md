---
title: Custom certificate authority (CA) in Azure Kubernetes Service (AKS)
description: Learn how to use a custom certificate authority (CA) in an Azure Kubernetes Service (AKS) cluster.
author: schaffererin
ms.author: schaffererin
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.date: 04/25/2023
---

# Custom certificate authority (CA) in Azure Kubernetes Service (AKS)

This article shows you how to create custom CAs and apply them to your AKS clusters.

## Prerequisites

* An Azure subscription. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free).
* The Azure CLI version 2.43.0 or later. Run `az --version` to find the version, and run `az upgrade` to upgrade the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
* A base64 encoded certificate string or a text file with certificate.

## Limitations

* This feature currently isn't supported for Windows node pools.
* Installing different CAs on different node pools is not supported.

## Custom CA installation on AKS node pools

### Install CAs on AKS node pools

* If your environment requires your custom CAs to be added to node trust store for correct provisioning, you need to pass a text file containing up to 10 blank line separated certificates during [`az aks create`][az-aks-create] or [`az aks update`][az-aks-update] operations. Example text file:

    ```txt
    -----BEGIN CERTIFICATE-----
    cert1
    -----END CERTIFICATE-----

    -----BEGIN CERTIFICATE-----
    cert2
    -----END CERTIFICATE-----
    ```

#### Install CAs during cluster creation

* Install CAs during cluster creation using the [`az aks create`][az-aks-create] command and specifying your text file for the `--custom-ca-trust-certificates` parameter.

    ```azurecli-interactive
    az aks create \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --node-count 2 \
        --custom-ca-trust-certificates pathToFileWithCAs \
        --generate-ssh-keys
    ```

#### CA rotation for availability during node pool boot up

* Update CAs passed to your cluster during boot up using the [`az aks update`][az-aks-update] command and specifying your text file for the `--custom-ca-trust-certificates` parameter.

    ```azurecli-interactive
    az aks update \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --custom-ca-trust-certificates pathToFileWithCAs
    ```

    > [!NOTE]
    > This operation triggers a model update, ensuring new nodes have the newest CAs required for correct provisioning. AKS creates additional nodes, drains existing ones, deletes them, and replaces them with nodes that have the new set of CAs installed.

## Configure a new AKS cluster to use a custom CA

* Configure a new AKS cluster to use a custom CA using the [`az aks create`][az-aks-create] command with the `--enable-custom-ca-trust` parameter.

    ```azurecli-interactive
    az aks create \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --node-count 2 \
        --enable-custom-ca-trust \
        --generate-ssh-keys
    ```

## Configure a new AKS cluster to use a custom CA with CAs installed before node boots up

* Configure a new AKS cluster to use custom CA with CAs installed before the node boots up using the [`az aks create`][az-aks-create] command with the `--enable-custom-ca-trust` and `--custom-ca-trust-certificates` parameters.

    ```azurecli-interactive
    az aks create \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --node-count 2 \
        --enable-custom-ca-trust \
        --custom-ca-trust-certificates pathToFileWithCAs \
        --generate-ssh-keys
    ```

## Configure an existing AKS cluster to have custom CAs installed before node boots up

* Configure an existing AKS cluster to have your custom CAs added to node's trust store before it boots up using the [`az aks update`][az-aks-update] command with the `--custom-ca-trust-certificates` parameter.

    ```azurecli-interactive
    az aks update \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --custom-ca-trust-certificates pathToFileWithCAs
    ```

## Configure a new node pool to use a custom CA

* Configure a new node pool to use a custom CA using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--enable-custom-ca-trust` parameter.

    ```azurecli-interactive
    az aks nodepool add \
        --cluster-name <cluster-name> \
        --resource-group <resource-group-name> \
        --name <node-pool-name> \
        --enable-custom-ca-trust \
        --os-type Linux
    ```

    If no other node pools with the feature enabled exist, the cluster has to reconcile its settings for the changes to take effect. This operation happens automatically as a part of AKS's reconcile loop. Before the operation, the daemon set and pods don't appear on the cluster. You can trigger an immediate reconcile operation using the [`az aks update`][az-aks-update] command. The daemon set and pods appear after the update completes.

## Configure an existing node pool to use a custom CA

* Configure an existing node pool to use a custom CA using the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--enable-custom-ca-trust` parameter.

    ```azurecli-interactive
    az aks nodepool update \
        --resource-group <resource-group-name> \
        --cluster-name <cluster-name> \
        --name <node-pool-name> \
        --enable-custom-ca-trust
    ```

    If no other node pools with the feature enabled exist, the cluster has to reconcile its settings for the changes to take effect. This operation happens automatically as a part of AKS's reconcile loop. Before the operation, the daemon set and pods don't appear on the cluster. You can trigger an immediate reconcile operation using the [`az aks update`][az-aks-update] command. The daemon set and pods appear after the update completes.

## Disable custom CA on a node pool

* Disable the custom CA feature on an existing node pool using the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--disable-custom-ca-trust` parameter.

    ```azurecli-interactive
    az aks nodepool update \
        --resource-group <resource-group-name> \
        --cluster-name <cluster-name> \
        --name <node-pool-name> \
        --disable-custom-ca-trust
    ```

## Troubleshooting

Troubleshooting can be found here:

## Next steps

For more information on AKS security best practices, see [Best practices for cluster security and upgrades in Azure Kubernetes Service (AKS)][aks-best-practices-security-upgrades].

<!-- LINKS INTERNAL -->
[aks-best-practices-security-upgrades]: operator-best-practices-cluster-security.md
[azure-cli-install]: /cli/azure/install-azure-cli
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-nodepool-add]: /cli/azure/aks#az-aks-nodepool-add
[az-aks-nodepool-update]: /cli/azure/aks#az-aks-update
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-provider-register]: /cli/azure/provider#az-provider-register
[kubernetes-secrets]: https://kubernetes.io/docs/concepts/configuration/secret/
