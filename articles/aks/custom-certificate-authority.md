---
title: Custom certificate authority (CA) in Azure Kubernetes Service (AKS)
description: Learn how to use a custom certificate authority (CA) to add certificates to your nodes in an Azure Kubernetes Service (AKS) cluster.
author: allyford
ms.author: allyford
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.date: 03/07/2025
---

# Custom certificate authority (CA) in Azure Kubernetes Service (AKS)

Custom Certificate Authority (CA) allows you to add up to 10 base64-encoded certificates to your node's trust store. This feature is often needed when CAs are required to be present on the node, for example when connecting to a private registry.  

This article shows you how to create custom CAs and apply them to your AKS clusters. 

## Prerequisites

* An Azure subscription. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free).
* The Azure CLI version 2.43.0 or later. Run `az --version` to find the version, and run `az upgrade` to upgrade the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
* A base64 encoded certificate string or a text file with certificate.

## Limitations

* Windows node pools aren't supported.
* Installing different CAs on different node pools isn't supported.

## Install CAs on your node's trust store

1. Create a file containing CAs.

Create a text file containing up to 10 blank line separated certificates. When this file is passed to your cluster, these certificates are installed in your node's trust stores.

Example text file: "FileWithCAs"

```txt
    -----BEGIN CERTIFICATE-----
    cert1
    -----END CERTIFICATE-----

    -----BEGIN CERTIFICATE-----
    cert2
    -----END CERTIFICATE-----
 ```

2. Pass certificates to your cluster.

You can use the [`az aks create`][az-aks-create] or [`az aks update`][az-aks-update] to pass certificates to your cluster. Once the operation completes, the certificates are installed in your node's trust stores.

* Install CAs during cluster creation using the [`az aks create`][az-aks-create] command and specifying your text file for the `--custom-ca-trust-certificates` parameter.

    ```azurecli-interactive
    az aks create \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --node-count 2 \
        --custom-ca-trust-certificates FileWithCAs \
        --generate-ssh-keys
    ```

* Install CAs during cluster update using the [`az aks update`][az-aks-update] command and specifying your text file for the `--custom-ca-trust-certificates` parameter.

    ```azurecli-interactive
    az aks update \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --custom-ca-trust-certificates <path-to-ca-file>
    ```
 > [!NOTE]
 > This operation triggers a model update to ensure all existing nodes have the same CAs installed for correct provisioning. AKS creates new nodes, drains existing nodes, deletes existing nodes, and replaces them with nodes that have the new set of CAs installed.

3. Check that CAs have been installed.
 Use the [`az aks show`][az-aks-show] command to check that CAs have been installed. 

```azurecli-interactive
az aks show -g <resource-group-name> -n <cluster-name> | grep securityProfile -A 4
```
The securityProfile output should include your Custom CA Trust Certificates.


```output
  "securityProfile": {
    "azureKeyVaultKms": null,
    "customCaTrustCertificates": [
        "values"
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
[az-aks-show]: /cli/azure/aks#az-aks-show
[install-azure-cli]:  /cli/azure/install-azure-cli
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-provider-register]: /cli/azure/provider#az-provider-register
[kubernetes-secrets]: https://kubernetes.io/docs/concepts/configuration/secret/
