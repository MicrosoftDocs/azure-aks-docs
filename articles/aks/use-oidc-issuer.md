---
title: Use the OpenID Connect (OIDC) Issuer in Azure Kubernetes Service (AKS)
description: Learn how to use the OpenID Connect (OIDC) issuer in Azure Kubernetes Service (AKS), including AKS Automatic where OIDC issuer is preconfigured and AKS Standard where you can enable it based on cluster version and configuration.
author: davidsmatlak
ms.author: yuewu2
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-security
ms.custom: devx-track-azurecli
ms.date: 10/16/2025
# Customer intent: "As a Kubernetes administrator, I want to configure an OpenID Connect issuer for my AKS cluster, so that I can implement secure authentication and enable single sign-on for applications running within the cluster."
---

# Create an OpenID Connect issuer on Azure Kubernetes Service (AKS)

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

This article describes how to create and manage an OpenID Connect (OIDC) issuer for your Azure Kubernetes Service (AKS) cluster. The OIDC issuer enables your AKS cluster to integrate with identity providers like Microsoft Entra ID, so you can securely authenticate and provide single sign-on (SSO) capabilities for applications running within the cluster.

For most production workloads, AKS Automatic is the recommended default AKS experience. AKS Automatic is production ready by default and includes OIDC issuer as a preconfigured security capability. In AKS Standard, OIDC issuer behavior depends on Kubernetes version and cluster state, and you can enable it manually when required.

To learn more about AKS Automatic, see [What is Azure Kubernetes Service (AKS) Automatic?](./intro-aks-automatic.md)

## OIDC issuer in AKS Automatic and AKS Standard

Both AKS cluster modes support OIDC issuer, but setup differs:

- **AKS Automatic**: OIDC issuer is preconfigured.
- **AKS Standard**: You might need to explicitly enable OIDC issuer, depending on version and whether it's already configured.

For most production scenarios, start with AKS Automatic to use production-ready defaults and reduce operational overhead.

## About OpenID Connect (OIDC) on AKS

[OpenID Connect][open-id-connect-overview] (OIDC) extends the OAuth 2.0 authorization protocol for use as another authentication protocol issued by Microsoft Entra ID. You can use OIDC to enable single sign-on (SSO) between OAuth-enabled applications on your Azure Kubernetes Service (AKS) cluster using a security token called an ID token. You can enable the OIDC issuer on your AKS clusters, which allows Microsoft Entra ID (or another cloud provider's identity and access management platform) to discover the API server's public signing keys.

## Prerequisites

Platform requirements:

- Azure CLI version 2.42.0 or later (`az --version` to check version, [install or upgrade Azure CLI][azure-cli-install] if needed).
- Kubernetes version 1.22 or later.

Version-specific behavior (AKS Standard):

- OIDC issuer is enabled by default (no `--enable-oidc-issuer` flag needed) for newly created AKS clusters on Kubernetes version 1.34 or later.
- For existing clusters, OIDC isn't enabled by default regardless of Kubernetes version and requires manual enablement.
- Token auto-extension disabled (`--service-account-extend-token-expiration=false`) for Kubernetes version 1.30.0 or later.
- If OIDC issuer wasn't previously configured, manual enablement is required for Kubernetes versions earlier than 1.34.
- Projected service account tokens are required for Kubernetes version 1.30 or later clusters.

Important considerations:

- You can't disable OIDC issuer once enabled.
- Enabling OIDC issuer on existing clusters requires API server restart (brief downtime).
- Maximum token lifetime is 24 hours (one day).

## Create an AKS cluster with the OIDC issuer

### AKS Automatic (recommended default for production)

In AKS Automatic, the OIDC issuer is preconfigured. You don't need a separate OIDC issuer enablement step.

Create an AKS Automatic cluster by following the quickstart:

- [Create an Azure Kubernetes Service (AKS) Automatic cluster](./automatic/quick-automatic-managed-network.md)

### AKS Standard

Create an AKS Standard cluster using the [`az aks create`][az-aks-create] command with the `--enable-oidc-issuer` parameter.

```azurecli-interactive
# Set environment variables
RESOURCE_GROUP=<your-resource-group-name>
CLUSTER_NAME=<your-aks-cluster-name>
    
# Create the AKS Standard cluster with OIDC issuer enabled
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --node-count 1 \
    --enable-oidc-issuer \
    --generate-ssh-keys
```

> [!NOTE]
> On AKS Standard clusters created with Kubernetes version 1.34 or later, the OIDC issuer is enabled by default for new clusters.

## Enable OIDC issuer on an existing AKS Standard cluster

Enable the OIDC issuer on an existing AKS Standard cluster using the [`az aks update`][az-aks-update] command with the `--enable-oidc-issuer` parameter.

```azurecli-interactive
# Set environment variables
RESOURCE_GROUP=<your-resource-group-name>
CLUSTER_NAME=<your-aks-cluster-name>

# Enable the OIDC issuer on the existing AKS Standard cluster
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-oidc-issuer 
```

## Get the OIDC issuer URL

Get the OIDC issuer URL using the [`az aks show`][az-aks-show] command.

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

By default, the issuer uses the base URL `https://{region}.oic.prod-aks.azure.com`, where the value for `{region}` matches the location where you deployed the AKS cluster.

## Rotate the OIDC signing key

> [!IMPORTANT]
> Keep the following considerations in mind when rotating OIDC signing keys:
>
> - If you want to invalidate the old key immediately after key rotation, you must rotate the OIDC key twice and restart the pods using projected service account tokens.
> - Both old and new keys remain valid for 24 hours after rotation.
> - You need to refresh the token manually every 24 hours (unless you're using [Azure Identity client libraries][sdk], which refresh automatically).

Rotate the OIDC key using the [`az aks oidc-issuer`][az-aks-oidc-issuer] command.

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

Go to your [OIDC issuer URL](#get-the-oidc-issuer-url) in your browser and add `/.well-known/openid-configuration` to the URL.

Example: `https://eastus.oic.prod-aks.azure.com/.well-known/openid-configuration`

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

In your browser, go to the [**jwks_uri** from the discovery document](#get-the-discovery-document).

For example: `https://eastus.oic.prod-aks.azure.com/00000000-0000-0000-0000-000000000000/00000000-0000-0000-0000-000000000000/openid/v1/jwks`

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
> During key rotation, the discovery document includes one extra key.

## Related content

- [Create an AKS Automatic cluster](./automatic/quick-automatic-managed-network.md)
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
