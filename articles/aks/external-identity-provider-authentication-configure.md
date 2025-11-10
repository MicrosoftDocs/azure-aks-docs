---
title: Configure external identity providers with AKS structured authentication (preview)
description: Learn how to configure external identity providers for Azure Kubernetes Service (AKS) using structured authentication and JWT authenticators.
author: shashankbarsin
ms.author: shasb
ms.topic: how-to
ms.subservice: aks-security
ms.custom: preview, devx-track-azurecli
ms.date: 11/04/2025
zone_pivot_groups: external-idp-authn-type
# Customer intent: As a platform engineer, I want to configure external identity providers for my AKS cluster using structured authentication, so that my users can authenticate with their existing organizational identities.
---

# Configure external identity providers with AKS structured authentication (preview)

This article shows you how to configure external identity providers for Azure Kubernetes Service (AKS) control plane authentication using structured authentication. You learn how to create JSON Web Token (JWT) authenticators, configure claim validation and mapping, and test the authentication flow.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

- Read [conceptual overview][structured-auth-overview] for authentication to AKS using external identity provider.
[!INCLUDE [azure-cli-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]
- This article requires version 2.77.0 or later of the Azure CLI. If you're using Azure Cloud Shell, the latest version is already installed there.
- You need to install the `aks-preview` Azure CLI extension version 18.0.0b41 or later to use structured authentication features.
  - If you don't already have the `aks-preview` extension, install it using the [`az extension add`][az-extension-add] command:
    ```azurecli-interactive
    az extension add --name aks-preview
    ```
  - If you already have the `aks-preview` extension, update it to make sure you have the latest version using the [`az extension update`][az-extension-update] command:
    ```azurecli-interactive
    az extension update --name aks-preview
    ```
  - Verify you have the required version:
    ```azurecli-interactive
    az extension show --name aks-preview --query version
    ```
- An AKS cluster running Kubernetes version 1.30 or later. To create an AKS cluster, see [Quickstart: Deploy an Azure Kubernetes Service (AKS) cluster using Azure CLI][aks-quickstart-cli].
- `kubectl` command-line tool to interact with your Kubernetes cluster. `kubectl` is already installed if you use Azure Cloud Shell. To install `kubectl` locally, use the [az aks install-cli][az-aks-install-cli] command.
    ```azurecli-interactive
    az aks install-cli
    ```
- An external identity provider that supports OpenID Connect (OIDC).
- Network connectivity from cluster nodes to your identity provider.
- If you plan to use the `kubelogin` plugin, install it using these [setup instructions][kubelogin-oidc]

### Set environment variables

Set the following environment variables for your resource group and cluster name:

```bash
export RESOURCE_GROUP="<your-resource-group-name>"
export CLUSTER_NAME="<your-cluster-name>"
```

### Register the preview feature

If you're using a subscription without the feature registered, register the `JWTAuthenticatorPreview` feature:

```azurecli-interactive
az feature register --name JWTAuthenticatorPreview --namespace Microsoft.ContainerService
```

Check the registration status:

```azurecli-interactive
az feature show --name JWTAuthenticatorPreview --namespace Microsoft.ContainerService
```

When the status shows `Registered`, refresh the resource provider registration:

```azurecli-interactive
az provider register --namespace Microsoft.ContainerService
```

## Set up your identity provider

Configure your external identity provider to support OIDC authentication. Select your identity provider for specific setup instructions:

::: zone pivot="github"

### GitHub Actions OIDC Setup

1. Ensure your GitHub Actions workflows have the necessary permissions.
2. Configure the `id-token: write` permission in your workflow files:
   ```yaml
   permissions:
     id-token: write
     contents: read
   ```
3. Set up appropriate repository and organization settings for OIDC token access. Configure [repository OIDC settings](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure) and [organization security policies](https://docs.github.com/en/organizations/managing-organization-settings/restricting-access-to-machine-identities) for token usage.

::: zone-end

::: zone pivot="google-identity"

### Google OAuth 2.0 Setup

1. Go to the [Google Cloud Console][google-cloud-console].
2. [Create or select a project][google-workspace-create-project].
3. [Create OAuth 2.0 credentials][google-oauth2-protocol].
4. Note your client ID and client secret for later use.

::: zone-end

## Create JWT authenticator configuration

Create a JSON configuration file that defines how to validate and process tokens from your identity provider. Select your identity provider for specific configuration examples:

::: zone pivot="github"

### GitHub Configuration

For GitHub Actions OIDC, create a file named `jwt-config.json` with the following configuration:

```json
{
  "issuer": {
      "url": "https://token.actions.githubusercontent.com",
      "audiences": [
          "my-api"
      ]
  },
  "claimValidationRules": [
      {
          "expression": "has(claims.sub)",
          "message": "must have sub claim"
      }
  ],
  "claimMappings": {
      "username": {
          "expression": "'aks:jwt:github:' + claims.sub"
      }
  },
  "userValidationRules": [
      {
          "expression": "has(user.username)",
          "message": "must have username"
      },
      {
          "expression": "!user.username.startsWith('aks:jwt:github:system')",
          "message": "username must not start with 'aks:jwt:github:system'"
      }
  ]
}
```

::: zone-end

::: zone pivot="google-identity"

### Google OAuth 2.0 Configuration

Create a file named `jwt-config.json` with the following configuration:

```json
{
    "issuer": {
        "url": "https://accounts.google.com",
        "audiences": [
            "your-client-id.apps.googleusercontent.com"
        ]
    },
    "claimValidationRules": [
        {
            "expression": "has(claims.sub)",
            "message": "must have sub claim"
        }
    ],
    "claimMappings": {
        "username": {
            "expression": "'aks:jwt:google:' + claims.sub"
        },
        "groups": {
            "expression": "has(claims.groups) ? claims.groups.split(',').map(g, 'aks:jwt:' + g) : []"
        }
    },
    "userValidationRules": [
        {
            "expression": "has(user.username)",
            "message": "must have username"
        },
        {
            "expression": "!user.username.startsWith('aks:jwt:google:system')",
            "message": "username must not start with 'aks:jwt:google:system'"
        }
    ]
}
```

::: zone-end

### Configuration elements

- **issuer**: The OIDC issuer configuration.
    - **url**: The OIDC issuer URL that must match the `iss` claim in JWTs.
    - **audiences**: List of audiences that JWTs must be issued for (checked against `aud` claim).
    - **certificateAuthority**: Optional base64-encoded root certificate bundle for Transport Layer Security (TLS) verification.
- **claimValidationRules**: Array of validation rules using CEL expressions to validate JWT claims.
    - **expression**: CEL expression that must evaluate to true.
    - **message**: Error message displayed when validation fails.
- **claimMappings**: Defines how JWT claims map to Kubernetes user information.
    - **username**: CEL expression defining how to construct the username from claims.
    - **groups**: CEL expression defining how to construct group memberships from claims.
    - **uid**: Optional CEL expression for user identifier.
    - **extra**: Optional map of more user attributes.
- **userValidationRules**: Array of validation rules applied to the final user information.
    - **expression**: CEL expression that must evaluate to true for the mapped user.
    - **message**: Error message displayed when user validation fails.

> [!IMPORTANT]
> All username and group mappings must include the `aks:jwt:` prefix to prevent conflicts with other authentication methods.

## Create the JWT authenticator

Add the JWT authenticator to your AKS cluster:

```azurecli-interactive
az aks jwtauthenticator add \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME \
    --name external-auth \
    --config-file jwt-config.json
```

### Verify the authenticator

List all JWT authenticators on your cluster:

```azurecli-interactive
az aks jwtauthenticator list \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME
```

Get details of a specific authenticator:

```azurecli-interactive
az aks jwtauthenticator show \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME \
    --name external-auth
```

## Set up client for authentication

Configure your client to authenticate with your external identity provider. Select your identity provider for specific configuration:

::: zone pivot="github"

### GitHub Actions Workflow Authentication

For GitHub Actions OIDC, create a workflow that obtains an OIDC token and uses it to authenticate with your AKS cluster. Here's an example workflow that gets all pods running on the cluster:

```yaml
name: AKS Access with GitHub OIDC
on:
  workflow_dispatch:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  aks-access:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install kubectl
        uses: azure/setup-kubectl@v3
        with:
          version: 'latest'

      - name: Get GitHub OIDC token
        id: get_token
        run: |
          TOKEN=$(curl -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
            "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=my-api" | \
            jq -r '.value')
          echo "::add-mask::$TOKEN"
          echo "oidc_token=$TOKEN" >> $GITHUB_OUTPUT

      - name: Create kubeconfig with OIDC token
        run: |
          cat <<EOF > kubeconfig
          apiVersion: v1
          kind: Config
          clusters:
          - cluster:
              certificate-authority-data: ${{ secrets.AKS_CA_DATA }}
              server: ${{ secrets.AKS_SERVER_URL }}
            name: aks-cluster
          contexts:
          - context:
              cluster: aks-cluster
              user: github-oidc-user
            name: aks-context
          current-context: aks-context
          users:
          - name: github-oidc-user
            user:
              token: ${{ steps.get_token.outputs.oidc_token }}
          EOF

      - name: List all pods in the cluster
        run: |
          export KUBECONFIG=./kubeconfig
          kubectl get pods --all-namespaces
```

#### Required repository secrets and variables

Set up these secrets in your GitHub repository:

**Secrets:**
- `AKS_CA_DATA`: Base64-encoded certificate authority data for your AKS cluster.
- `AKS_SERVER_URL`: Your AKS cluster's API server URL.

> [!NOTE]
> The audience value `my-api` should match the audience configured in your JWT authenticator configuration.

#### Getting AKS cluster information

To get the required cluster information, run:

```bash
# Get cluster info
az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "fqdn" -o tsv

# Get CA data (base64 encoded)
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --file - --format exec | \
  grep certificate-authority-data | awk '{print $2}'
```

::: zone-end

::: zone pivot="google-identity"

### Method 1: Using kubelogin plugin (Google)

Add a new user context to your kubeconfig file:

```yaml
users:
- name: external-user
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: kubectl
      args:
      - oidc-login
      - get-token
      - --oidc-issuer-url=https://accounts.google.com
      - --oidc-client-id=your-client-id.apps.googleusercontent.com
      - --oidc-client-secret=your-client-secret
```

::: zone-end

### Method 2: Using static token

If you have a JWT token, you can use it directly:

```yaml
users:
- name: external-user
  user:
    token: eyJhbGciOiJSUzI1NiIs...
```

### Test authentication

Test the authentication by running a kubectl command:

```bash
kubectl get nodes --user external-user
```

::: zone pivot="github"

Expected output for first-time setup before Role-Based Access Control (RBAC) configuration:
```
Error from server (Forbidden): nodes is forbidden: User "aks:jwt:github:your-sub" cannot list resource "nodes" in API group "" at the cluster scope
```

::: zone-end

::: zone pivot="google-identity"

Expected output for first-time setup before Role-Based Access Control (RBAC) configuration:
```
Error from server (Forbidden): nodes is forbidden: User "aks:jwt:google:your-subject" cannot list resource "nodes" in API group "" at the cluster scope
```

::: zone-end

This error indicates successful authentication but lack of authorization.

## Configure Kubernetes Role-Based Access Control (RBAC)

Create appropriate RBAC bindings for your external users. Use the cluster admin credentials to apply these configurations. Select your identity provider for provider-specific examples:

### Create a sample role and binding

::: zone pivot="github"

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: external-user-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "nodes"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: external-user-binding
subjects:
- kind: User
  # This matches the username expression in claim mappings for GitHub
  name: aks:jwt:github:your-github-sub
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: external-user-role
  apiGroup: rbac.authorization.k8s.io
```

::: zone-end

::: zone pivot="google-identity"

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: external-user-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "nodes"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: external-user-binding
subjects:
- kind: User
  # This matches the username expression in claim mappings for Google
  name: aks:jwt:google:your-subject-claim
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: external-user-role
  apiGroup: rbac.authorization.k8s.io
```

::: zone-end

Apply the RBAC configuration:

```bash
kubectl apply -f rbac-config.yaml
```

### Verify access

Test that the external user can now access resources:

```bash
kubectl get nodes --user external-user
kubectl get pods --user external-user
```

### Remove JWT authenticator

Delete an authenticator when no longer needed:

```azurecli-interactive
az aks jwtauthenticator delete \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME \
    --name external-auth
```

## Next steps

- [Set up resource logs to monitor AKS API server logs][monitor-resource-logs]

<!-- LINKS - external -->
[google-cloud-console]: https://console.cloud.google.com/
[google-workspace-create-project]: https://developers.google.com/workspace/guides/create-project
[google-oauth2-protocol]: https://developers.google.com/identity/protocols/oauth2/
[jwt-ms]: https://jwt.ms
[kubelogin-oidc]: https://github.com/int128/kubelogin?tab=readme-ov-file#setup

<!-- LINKS - internal -->
[aks-quickstart-cli]: learn/quick-kubernetes-deploy-cli.md
[structured-auth-overview]: external-identity-provider-authentication-overview.md
[workload-identity-cross-tenant]: workload-identity-cross-tenant.md
[manage-azure-rbac]: manage-azure-rbac.md
[monitor-resource-logs]: monitor-aks-reference.md#resource-logs
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli