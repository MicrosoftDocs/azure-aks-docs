---
title: Create an OpenID Connect (OIDC) Provider for your Azure Kubernetes Service (AKS) Cluster
description: Learn how to configure the OpenID Connect (OIDC) provider for a cluster in Azure Kubernetes Service (AKS).
author: davidsmatlak
ms.author: yuewu2
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-security
ms.custom: devx-track-azurecli
ms.date: 10/16/2025
# Customer intent: "As a Kubernetes administrator, I want to configure an OpenID Connect provider for my AKS cluster, so that I can implement secure authentication and enable single sign-on for applications running within the cluster."
---

# Create an OpenID Connect provider on Azure Kubernetes Service (AKS)

This article describes how to create and manage an OpenID Connect (OIDC) provider for your Azure Kubernetes Service (AKS) cluster. The OIDC issuer allows your AKS cluster to integrate with identity providers like Microsoft Entra ID, enabling secure authentication and single sign-on (SSO) capabilities for applications running within the cluster.

## About OpenID Connect (OIDC) on AKS

[OpenID Connect][open-id-connect-overview] (OIDC) extends the OAuth 2.0 authorization protocol for use as another authentication protocol issued by Microsoft Entra ID. You can use OIDC to enable single sign-on (SSO) between OAuth-enabled applications on your Azure Kubernetes Service (AKS) cluster using a security token called an ID token. You can enable the OIDC issuer on your AKS clusters, which allows Microsoft Entra ID (or another cloud provider's identity and access management platform) to discover the API server's public signing keys.

## Prerequisites

**Platform requirements**:

- Azure CLI version 2.42.0+ (`az --version` to check version, [install or upgrade Azure CLI][azure-cli-install] if needed)
- Minimum Kubernetes version is 1.22+

**Version-specific behavior**:

- OIDC issuer enabled by default (no `--enable-oidc-issuer` flag needed) for Kubernetes version 1.34+
- Token auto-extension disabled (`--service-account-extend-token-expiration=false`) for Kubernetes version 1.30.0+
- Manual enablement required if not previously configured for Kubernetes version earlier than 1.34

**Important considerations**:

- You can't disable OIDC issuer once enabled
- Enabling OIDC issuer on existing clusters requires API server restart (brief downtime)
- Maximum token lifetime is 24 hours (one day)
- Projected service account tokens required for Kubernetes 1.30+ clusters

## Create an AKS cluster with the OIDC issuer

- Create an AKS cluster using the [`az aks create`][az-aks-create] command with the `--enable-oidc-issuer` parameter.

    ```azurecli-interactive
    # Set environment variables
    RESOURCE_GROUP=<your-resource-group-name>
    CLUSTER_NAME=<your-aks-cluster-name>
    
    # Create the AKS cluster with OIDC issuer enabled (OIDC issuer enabled by default for Kubernetes 1.34+)
    az aks create \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --node-count 1 \
        --enable-oidc-issuer \
        --generate-ssh-keys
    ```

## Enable the OIDC issuer on an existing AKS cluster

- Enable the OIDC issuer on an existing AKS cluster using the [`az aks update`][az-aks-update] command with the `--enable-oidc-issuer` parameter.

    ```azurecli-interactive
    # Set environment variables
    RESOURCE_GROUP=<your-resource-group-name>
    CLUSTER_NAME=<your-aks-cluster-name>

    # Enable the OIDC issuer on the existing AKS cluster
    az aks update \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --enable-oidc-issuer 
    ```

## Get the OIDC issuer URL

- Get the OIDC issuer URL using the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
    # Set environment variables
    RESOURCE_GROUP=<your-resource-group-name>
    CLUSTER_NAME=<your-aks-cluster-name>

    # Get the OIDC issuer URL
    az aks show \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --query "oidcIssuerProfile.issuerUrl" \
        -o tsv
    ```

    By default, the issuer is set to use the base URL `https://{region}.oic.prod-aks.azure.com`, where the value for `{region}` matches the location the AKS cluster is deployed in.

## Rotate the OIDC key

> [!IMPORTANT]
> Keep the following considerations in mind when rotating the OIDC key:
>
> - If you want to invalidate the old key immediately after key rotation, you must rotate the OIDC key twice and restart the pods using projected service account tokens.
> - Both old and new keys remain valid for 24 hours after rotation.
> - Manual token refresh required every 24 hours (unless using [Azure Identity SDK][sdk], which rotates automatically).

- Rotate the OIDC key using the [`az aks oidc-issuer`][az-aks-oidc-issuer] command.

    ```azurecli-interactive
    # Set environment variables
    RESOURCE_GROUP=<your-resource-group-name>
    CLUSTER_NAME=<your-aks-cluster-name>

    # Rotate the OIDC signing keys
    az aks oidc-issuer rotate-signing-keys \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP
    ```

## Get the discovery document

- Navigate to your [OIDC issuer URL](#get-the-oidc-issuer-url) in your browser and append `/.well-known/openid-configuration` to the URL. For example: `https://eastus.oic.prod-aks.azure.com/.well-known/openid-configuration`.

    Your output should resemble the following example output:

    ```output
    {
      "issuer": "https://eastus.oic.prod-aks.azure.com/ffffffff-eeee-dddd-cccc-bbbbbbbbbbb0/00000000-0000-0000-0000-000000000000/",
      "jwks_uri": "https://eastus.oic.prod-aks.azure.com/00000000-0000-0000-0000-000000000000/00000000-0000-0000-0000-000000000000/openid/v1/jwks",
      "response_types_supported": [
        "id_token"
      ],
      "subject_types_supported": [
        "public"
      ],
      "id_token_signing_alg_values_supported": [
        "RS256"
      ]
    }
    ```

## Get the JWK Set document

- Navigate to the [**jwks_uri** from the discovery document](#get-the-discovery-document) in your browser. For example: `https://eastus.oic.prod-aks.azure.com/00000000-0000-0000-0000-000000000000/00000000-0000-0000-0000-000000000000/openid/v1/jwks`.

    Your output should resemble the following example output:

    ```output
    {
      "keys": [
        {
          "use": "sig",
          "kty": "RSA",
          "kid": "xxx",
          "alg": "RS256",
          "n": "xxxx",
          "e": "AQAB"
        },
        {
          "use": "sig",
          "kty": "RSA",
          "kid": "xxx",
          "alg": "RS256",
          "n": "xxxx",
          "e": "AQAB"
        }
      ]
    }
    ```

    > [!NOTE]
    > During key rotation, there's one other key present in the discovery document.

## Related content

- [Create a trust relationship between an application and an external identity provider](/azure/active-directory/develop/workload-identity-federation-create-trust)
- [Microsoft Entra Workload ID overview][azure-ad-workload-identity-overview]
- [Secure pod network traffic][secure-pod-network-traffic]

<!-- LINKS - external -->

<!-- LINKS - internal -->
[open-id-connect-overview]: /azure/active-directory/fundamentals/auth-oidc
[sdk]: workload-identity-overview.md#azure-identity-client-libraries
[azure-cli-install]: /cli/azure/install-azure-cli
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-show]: /cli/azure/aks#az-aks-show
[az-aks-oidc-issuer]: /cli/azure/aks/oidc-issuer
[azure-ad-workload-identity-overview]: workload-identity-overview.md
[secure-pod-network-traffic]: use-network-policies.md
