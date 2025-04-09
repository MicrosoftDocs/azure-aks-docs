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
* Custom Certificate Authority is available as GA in the [2025-01-01 GA API](https://learn.microsoft.com/rest/api/aks/managed-clusters/create-or-update?view=rest-aks-2025-01-01&tabs=HTTP#create-managed-cluster-with-custom-ca-trust-certificates:~:text=%2215m%22%0A%20%20%20%20%7D%0A%20%20%7D%0A%7D-,Create%20Managed%20Cluster%20with%20Custom%20CA%20Trust%20Certificates,-Sample%20request). It is not yet available in the CLI until May 2025. To use the GA feature in CLI before release, you can use the [az rest command](https://learn.microsoft.com/cli/azure/reference-index?view=azure-cli-latest#az-rest) to add custom certificates during cluster creation.
* A base64 encoded certificate string or a text file with certificate.

## Limitations

* Windows node pools aren't supported.
* Installing different CAs on different node pools isn't supported.

## Install CAs on your node's trust store

1. Create a file containing CAs.

Create a text file containing up to 10 blank line separated certificates. When this file is passed to your cluster, these certificates are installed in your node's trust stores.

Example text file:

```txt
    -----BEGIN CERTIFICATE-----
    cert1
    -----END CERTIFICATE-----

    -----BEGIN CERTIFICATE-----
    cert2
    -----END CERTIFICATE-----
 ```

Before proceeding to the next step, make sure that there are no additional blank spaces in your text file. These will result in an error in the next step if not removed.

2. Pass certificates to your cluster.

 > [!NOTE]
 > Custom Certificate Authority is available as GA in the [2025-01-01 GA API](https://learn.microsoft.com/rest/api/aks/managed-clusters/create-or-update?view=rest-aks-2025-01-01&tabs=HTTP#create-managed-cluster-with-custom-ca-trust-certificates:~:text=%2215m%22%0A%20%20%20%20%7D%0A%20%20%7D%0A%7D-,Create%20Managed%20Cluster%20with%20Custom%20CA%20Trust%20Certificates,-Sample%20request). It is not yet available in the CLI until May 2025. To use the GA feature in CLI before release, you can use the [`az rest`][az-rest] to add custom certificates during cluster creation.

 1. [Create an AKS cluster][quick-kubernetes-deply-cli] using the [`az aks create`][az-aks-create] command.
 2. Save the configuration of your cluster in a JSON file:
 ```azurecli-interactive
 az rest --method get \
  --url "/subscriptions/<subscription-id>/resourceGroups/<resource-grou-name>/providers/Microsoft.ContainerService/managedClusters/<cluster-name>?api-version=2025-01-01" > body.json
```
  3. Modify the json file to add customCATrustCertificates to the security profile of that cluster
```
  "securityProfile": {
    "azureKeyVaultKms": null,
    "customCaTrustCertificates": [
        "values"
```
  4. Pass the updated JSON file to add the certificates to the node's trust store
```azurecli-interactive
  az rest --method put \
  --url "/subscriptions/<subscription-id>/resourceGroups/<resource-grou-name>/providers/Microsoft.ContainerService/managedClusters/<cluster-name>?api-version=2025-01-01" --body @body.json
```

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

### Formatting error

Adding certificates to a cluster may result in an error if the JSON file with the certificates is not formatted properly.

```
failed to decode one of SecurityProfile.CustomCATrustCertificates to PEM after base64 decoding
```
If you encounter this error, you should check that your input file has no extra new lines, white spaces, or data other than correctly formatted certificates as shown in the example file.

### Feature is enabled and secret with CAs is added, but operations are failing with X.509 Certificate Signed by Unknown Authority error

#### Incorrectly formatted certs passed in the secret
AKS requires certs passed in the user-created secret to be properly formatted and base64 encoded. Make sure the CAs you passed are properly base64 encoded and that files with CAs don't have CRLF line breaks.

Certificates passed to ```--custom-ca-trust-certificates``` shouldn't be base64 encoded.

#### containerd hasn't picked up new certs
From the node's shell, run ```systemctl restart containerd```. Once containerd is restarts, the new certs are properly picked up by the container runtime.

## Next steps

For more information on AKS security best practices, see [Best practices for cluster security and upgrades in Azure Kubernetes Service (AKS)][aks-best-practices-security-upgrades].

<!-- LINKS INTERNAL -->
[aks-best-practices-security-upgrades]: ./operator-best-practices-cluster-security.md
[quick-kubernetes-deply-cli]: ./quick-kubernetes-deploy-cli.md
[azure-cli-install]: /cli/azure/install-azure-cli
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-nodepool-add]: /cli/azure/aks#az-aks-nodepool-add
[az-aks-nodepool-update]: /cli/azure/aks#az-aks-update
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-aks-show]: /cli/azure/aks#az-aks-show
[az-rest]: /cli/azure/reference-index?view=azure-cli-latest#az-rest
[install-azure-cli]:  /cli/azure/install-azure-cli
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-provider-register]: /cli/azure/provider#az-provider-register
[kubernetes-secrets]: https://kubernetes.io/docs/concepts/configuration/secret/
