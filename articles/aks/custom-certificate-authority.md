---
title: Custom Certificate Authority (CA) in Azure Kubernetes Service (AKS)
description: Learn how to use a custom certificate authority (CA) to add certificates to your nodes in an Azure Kubernetes Service (AKS) cluster.
author: allyford
ms.author: allyford
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.date: 03/07/2025
# Customer intent: As a Kubernetes administrator, I want to install custom certificate authorities on my AKS cluster nodes so that I can ensure secure connections to private registries and maintain the trustworthiness of the node's trust store.
---

# Use custom certificate authorities (CAs) in Azure Kubernetes Service (AKS)

Custom Certificate Authority (CA) allows you to add up to 10 base64-encoded certificates to your node's trust store. This feature is often needed when certificate authorities (CAs) are required to be present on the node, like when connecting to a private registry.  

This article shows you how to create custom CAs and apply them to your AKS clusters.

> [!NOTE]
> The Custom CA feature adds your custom certificates to the trust store of the AKS node. Certificates added with this feature aren't available to containers running in pods. If you need the certificates inside containers, you need to add them separately by adding them to the image used by your pods or at runtime via scripting and a secret.

## Prerequisites

- An Azure subscription. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free).
- Azure CLI version 2.72.0 or later installed and configured. To find your CLI version, run the `az --version` command. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
- A base64 encoded certificate string or a text file with certificate.

## Limitations

- Windows node pools aren't supported.
- Installing different CAs in the same cluster isn't supported.

## Create a certificate file

- Create a text file containing up to 10 blank line separated certificates. When you pass this file to your cluster, the certificates are installed in the trust stores of the AKS node.

    Example text file:

    ```txt
        -----BEGIN CERTIFICATE-----
        cert1
        -----END CERTIFICATE-----

        -----BEGIN CERTIFICATE-----
        cert2
        -----END CERTIFICATE-----
    ```

**Before proceeding to the next step, make sure that there are no blank spaces in your text file to avoid errors**.

## Pass custom CAs to your AKS cluster

- Pass certificates to your cluster using the [`az aks create`][az-aks-create] or [`az aks update`][az-aks-update] command with `--custom-ca-trust-certificates` set to the name of your certificate file.

    ```azurecli-interactive
    # Create a new cluster
    az aks create \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --node-count 2 \
        --custom-ca-trust-certificates <path-to-certificate-file> \
        --generate-ssh-keys

    # Update an existing cluster
    az aks update \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --custom-ca-trust-certificates <path-to-certificate-file>
    ```

    > [!NOTE]
    > This operation triggers a model update to ensure all existing nodes have the same CAs installed for correct provisioning. AKS creates new nodes, drains existing nodes, deletes existing nodes, and replaces them with nodes that have the new set of CAs installed.

## Verify CAs are installed

- Verify the CAs are installed using the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
    az aks show --resource-group <resource-group-name> --name <cluster-name> | grep securityProfile -A 4
    ```

    In the output, the `securityProfile` section should include your custom CA certificates. For example:

    ```output
      "securityProfile": {
        "azureKeyVaultKms": null,
        "customCaTrustCertificates": [
            "values"
    ```

## Resolve custom CA formatting errors

Adding certificates to a cluster can result in an error if the file with the certificates isn't formatted properly. You might see an error similar to the following example:

```output
failed to decode one of SecurityProfile.CustomCATrustCertificates to PEM after base64 decoding
```

If you encounter this error, you should check that your input file has no extra new lines, white spaces, or data other than correctly formatted certificates as shown in the example file.

## Resolve custom CA X.509 Certificate Signed by Unknown Authority errors

AKS requires certificates passed to be properly formatted and base64 encoded. Make sure the CAs you passed are properly base64 encoded and that files with CAs don't have CRLF line breaks.

## Restart containerd to pick up new certificates

If containerd doesn't pick up new certificates, run the `systemctl restart containerd` command from the node's shell. Once containerd restarts, the container runtime should pick up the new certificates.

## Related content

For more information on AKS security best practices, see [Best practices for cluster security and upgrades in Azure Kubernetes Service (AKS)][aks-best-practices-security-upgrades].

<!-- LINKS INTERNAL -->
[aks-best-practices-security-upgrades]: ./operator-best-practices-cluster-security.md
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-show]: /cli/azure/aks#az-aks-show
[install-azure-cli]:  /cli/azure/install-azure-cli
