---
title: Configure External Identity Providers with AKS Structured Authentication (Preview)
description: Learn how to configure external identity providers for Azure Kubernetes Service (AKS) using structured authentication and JWT authenticators.
author: shashankbarsin
ms.author: shasb
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-security
ms.custom: preview, devx-track-azurecli
ms.date: 11/04/2025
zone_pivot_groups: external-idp-authn-type
# Customer intent: As a platform engineer, I want to configure external identity providers for my AKS cluster using structured authentication, so that my users can authenticate with their existing organizational identities.
---

# Configure external identity providers with AKS structured authentication (preview)

This article shows you how to configure GitHub and Google Identity external identity providers for Azure Kubernetes Service (AKS) control plane authentication using structured authentication. You learn how to create JSON Web Token (JWT) authenticators, configure claim validation and mapping, and test the authentication flow.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

- Read the [conceptual overview][structured-auth-overview] for authentication to AKS using external identity provider.

[!INCLUDE [azure-cli-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

- This article requires version 2.77.0 or later of the Azure CLI. If you're using Azure Cloud Shell, the latest version is already installed there. To install or update the Azure CLI on your local machine, see [Install the Azure CLI](/cli/azure/install-azure-cli).
- You need to install the `aks-preview` Azure CLI extension version 18.0.0b41 or later to use structured authentication features.

  - If you don't already have the `aks-preview` extension, install it using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

  - If you already have the `aks-preview` extension, update it to make sure you have the latest version using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

  - Verify you have the required version of the `aks-preview` extension using the [`az extension show`][az-extension-show] command.

    ```azurecli-interactive
    az extension show --name aks-preview --query version
    ```

- An AKS cluster running Kubernetes version 1.30 or later. To create an AKS cluster, see [Deploy an Azure Kubernetes Service (AKS) cluster using Azure CLI][aks-quickstart-cli].
- `kubectl` command-line tool to interact with your Kubernetes cluster. `kubectl` is already installed if you use Azure Cloud Shell. You can install `kubectl` locally using the [`az aks install-cli`][az-aks-install-cli] command.

    ```azurecli-interactive
    az aks install-cli
    ```

- An external identity provider that supports OpenID Connect (OIDC).
- Network connectivity from cluster nodes to your identity provider.
- If you plan to use the `kubelogin` plugin, install it by following the instructions in the [kubelogin setup guide][kubelogin-oidc].

## Set environment variables

- Set the following environment variables for your resource group and cluster name:

    ```bash
    export RESOURCE_GROUP="<your-resource-group-name>"
    export CLUSTER_NAME="<your-cluster-name>"
    ```

## Register the `JWTAuthenticatorPreview` feature

1. Register the `JWTAuthenticatorPreview` feature using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --name JWTAuthenticatorPreview --namespace Microsoft.ContainerService
    ```

1. Check the registration status of the feature using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show --name JWTAuthenticatorPreview --namespace Microsoft.ContainerService
    ```

1. When the status shows `Registered`, refresh the resource provider registration for `Microsoft.ContainerService` using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

:::zone pivot="github"

## Set up GitHub Actions OIDC authentication

1. Ensure your GitHub Actions workflows have the necessary permissions.
1. Configure the `id-token: write` permission in your workflow files. For example:

   ```yaml
   permissions:
     id-token: write
     contents: read
   ```

1. Set up appropriate repository and organization settings for OIDC token access. Configure [repository OIDC settings](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure) and organization security policies for token usage.

:::zone-end

:::zone pivot="google-identity"

## Set up Google Identity OAuth 2.0 authentication

1. Navigate to the [Google Cloud Console][google-cloud-console].
1. [Create or select a project][google-workspace-create-project].
1. [Create OAuth 2.0 credentials][google-oauth2-protocol].
1. Note your client ID and client secret for later use.

:::zone-end

::: zone pivot="github"

## Create JWT authenticator configuration for GitHub Actions OIDC

- Create a file named `jwt-config.json` with the following configuration:

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

:::zone-end

:::zone pivot="google-identity"

## Create JWT authenticator configuration for Google Identity

- Create a file named `jwt-config.json` with the following configuration:

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

:::zone-end

## JWT authenticator configuration elements

The JWT authenticator configuration includes the following key elements: `issuer`, `claimValidationRules`, `claimMappings`, and `userValidationRules`. Each element serves a specific purpose in defining how AKS validates and processes JWT tokens from the external identity provider.

### Issuer configuration

The following table describes the key elements of the `issuer` configuration:

| Issuer configuration element | Description |
| ---------------------------- | ----------- |
| `url` | The OIDC issuer URL that must match the `iss` claim in JWTs. |
| `audiences` | List of audiences that JWTs must be issued for (checked against `aud` claim). |
| `certificateAuthority` | Optional base64-encoded root certificate bundle for Transport Layer Security (TLS) verification when connecting to the issuer URL. |

### Claim validation rules configuration

The following table describes the key elements of the `claimValidationRules` configuration:

| Claim validation rule element | Description |
| ----------------------------- | ----------- |
| `expression` | CEL expression that defines the validation logic to apply to JWT claims. The expression must evaluate to true for the token to be accepted. |
| `message` | Error message returned when the validation rule fails. |

### Claim mappings configuration

The following table describes the key elements of the `claimMappings` configuration:

| Claim mappings element | Description |
| ---------------------- | ----------- |
| `username` | CEL expression that defines how to construct the Kubernetes username from JWT claims. **Must include the `aks:jwt:` prefix to prevent conflicts with other authentication methods**. |
| `groups` | CEL expression that defines how to construct Kubernetes group memberships from JWT claims. **Must include the `aks:jwt:` prefix to prevent conflicts with other authentication methods**. |
| `uid` | Optional CEL expression that defines a unique identifier for the user. |
| `extra` | Optional map of additional user attributes defined by CEL expressions. |

### User validation rules configuration

The following table describes the key elements of the `userValidationRules` configuration:

| User validation rule element | Description |
| ---------------------------- | ----------- |
| `expression` | CEL expression that defines additional validation logic to apply to the final mapped user information. The expression must evaluate to true for the user to be accepted. |
| `message` | Error message returned when the user validation rule fails. |

## Create the JWT authenticator

- Add the JWT authenticator to your AKS cluster using the [`az aks jwtauthenticator add`][az-aks-jwtauthenticator-add] command.

    ```azurecli-interactive
    az aks jwtauthenticator add \
        --resource-group $RESOURCE_GROUP \
        --cluster-name $CLUSTER_NAME \
        --name external-auth \
        --config-file jwt-config.json
    ```

## Manage JWT authenticators

### List all JWT authenticators

- List all JWT authenticators on your cluster using the [`az aks jwtauthenticator list`][az-aks-jwtauthenticator-list] command.

    ```azurecli-interactive
    az aks jwtauthenticator list \
        --resource-group $RESOURCE_GROUP \
        --cluster-name $CLUSTER_NAME
    ```

### Get details for a specific JWT authenticator

- Get details for a specific JWT authenticator using the [`az aks jwtauthenticator show`][az-aks-jwtauthenticator-show] command.

    ```azurecli-interactive
    az aks jwtauthenticator show \
        --resource-group $RESOURCE_GROUP \
        --cluster-name $CLUSTER_NAME \
        --name external-auth
    ```

:::zone pivot="github"

## Set up GitHub Actions OIDC for authentication

1. Create environment variables for and set the following required repository secrets in your GitHub repository:

   - `AKS_SERVER_URL`: Your AKS cluster's API server URL.
   - `AKS_CA_DATA`: Base64-encoded certificate authority data for your AKS cluster.

1. Create a workflow that obtains an OIDC token and uses it to authenticate with your AKS cluster. The following example workflow gets all pods running on the cluster:

    > [!NOTE]
    > The audience value `my-api` should match the audience configured in your [JWT authenticator configuration](#create-jwt-authenticator-configuration-for-github-actions-oidc).

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

## Get cluster information for JWT authenticator configuration

1. Get the API server URL for your cluster using the [`az aks show`][az-aks-show] command.

    ```bash
    az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "fqdn" -o tsv | \
      awk '{print "https://" $0 ":443"}'
    ```

1. Get the base64-encoded certificate authority data for your cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```bash
    # Get CA data (base64 encoded)
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --file - --format exec | \
      grep certificate-authority-data | awk '{print $2}'
    ```

:::zone-end

:::zone pivot="google-identity"

## Set up Google Identity OAuth 2.0 for authentication

You can set up Google Identity authentication using either the `kubelogin` plugin or by directly using a static token.

### [Use kubelogin plugin](#tab/use-kubelogin-plugin)

- Add a new user context to your kubeconfig file. For example:

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

### [Use static token](#tab/use-static-token)

- If you have a JWT token, you can use it directly. For example:

    ```yaml
    users:
    - name: external-user
      user:
        token: eyJhbGciOiJSUzI1NiIs...
    ```

---

:::zone-end

## Test authentication

:::zone pivot="github"

1. Trigger the workflow either by **pushing to the main branch** or **manually triggering it from the Actions tab** in your repository.
1. Monitor the workflow execution in the Actions tab to verify authentication is working.

    Expected output for first-time setup before Role-Based Access Control (RBAC) configuration:

    ```output
    Error from server (Forbidden): nodes is forbidden: User "aks:jwt:github:your-sub" cannot list resource "nodes" in API group "" at the cluster scope
    ```

    This error indicates successful authentication but lack of authorization.

:::zone-end

:::zone pivot="google-identity"

- Test the authentication using the `kubectl get nodes` command with the `--user` flag to specify the user context you created for Google Identity authentication. For example:

    ```bash
    kubectl get nodes --user external-user
    ```

    Expected output for first-time setup before Role-Based Access Control (RBAC) configuration:

    ```output
    Error from server (Forbidden): nodes is forbidden: User "aks:jwt:google:your-subject" cannot list resource "nodes" in API group "" at the cluster scope
    ```

    This error indicates successful authentication but lack of authorization.

:::zone-end

## Configure Kubernetes Role-Based Access Control (RBAC)

Create appropriate RBAC bindings for your external users, and use the cluster admin credentials to apply these configurations.

:::zone pivot="github"

1. Create a file named `rbac-config.yaml` to configure RBAC bindings for external users. For example:

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
      # This matches the username expression in claim mappings for GitHub; example of GitHub subject is "repo:<organization-name>/<repository-name>:ref:refs/heads/main"
      name: aks:jwt:github:your-github-sub
      apiGroup: rbac.authorization.k8s.io
    roleRef:
      kind: ClusterRole
      name: external-user-role
      apiGroup: rbac.authorization.k8s.io
    ```

1. Apply the RBAC configuration using the `kubectl apply` command:

    ```bash
    kubectl apply -f rbac-config.yaml
    ```

:::zone-end

:::zone pivot="google-identity"

1. Create a file named `rbac-config.yaml` to configure RBAC bindings for external users. For example:

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

1. Apply the RBAC configuration using the `kubectl apply` command:

    ```bash
    kubectl apply -f rbac-config.yaml
    ```

:::zone-end

## Verify access with RBAC

- Verify the external user can now access resources according to the RBAC permissions you configured using the `kubectl get nodes` and `kubectl get pods` commands with the `--user` flag. For example:

    ```bash
    kubectl get nodes --user external-user
    kubectl get pods --user external-user
    ```

## Remove JWT authenticator

- When you no longer need the JWT authenticator, remove it from your AKS cluster using the [`az aks jwtauthenticator delete`][az-aks-jwtauthenticator-delete] command.

    ```azurecli-interactive
    az aks jwtauthenticator delete \
        --resource-group $RESOURCE_GROUP \
        --cluster-name $CLUSTER_NAME \
        --name external-auth
    ```

## Related content

- [Set up resource logs to monitor AKS API server logs][monitor-resource-logs]

<!-- LINKS - external -->
[google-cloud-console]: https://console.cloud.google.com/
[google-workspace-create-project]: https://developers.google.com/workspace/guides/create-project
[google-oauth2-protocol]: https://developers.google.com/identity/protocols/oauth2/
[kubelogin-oidc]: https://github.com/int128/kubelogin?tab=readme-ov-file#setup

<!-- LINKS - internal -->
[aks-quickstart-cli]: learn/quick-kubernetes-deploy-cli.md
[structured-auth-overview]: external-identity-provider-authentication-overview.md
[monitor-resource-logs]: monitor-aks-reference.md#resource-logs
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli