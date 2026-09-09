---
title: Use kubelogin to authenticate in Azure Kubernetes Service (AKS)
description: Learn how to use the kubelogin plugin for all Microsoft Entra authentication methods in Azure Kubernetes Service (AKS).
author: shashankbarsin
ms.author: shasb
ms.topic: how-to
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.date: 09/09/2026
zone_pivot_groups: kubelogin-auth-methods
ai-usage: ai-assisted
# Customer intent: "As a Kubernetes administrator, I want to configure the kubelogin plugin for Microsoft Entra authentication in AKS, so that I can streamline user access and improve security for cluster management."
---

# Use kubelogin to authenticate users in Azure Kubernetes Service (AKS)

The kubelogin plugin in Azure is a client-go credential [plugin][client-go-cred-plugin] that implements Microsoft Entra authentication. The kubelogin plugin offers features that aren't available in the kubectl command-line tool. For more information, see the [kubelogin introduction](https://azure.github.io/kubelogin/index.html) and the [kubectl introduction](https://kubernetes.io/docs/reference/kubectl/introduction/).

This article provides an overview and examples of how to use kubelogin for supported Microsoft Entra authentication methods recommended for AKS.

## Kubelogin authentication in AKS limitations

- Groups that are created in Microsoft Entra are included only by their **ObjectID** value, and not by their display name. The `sAMAccountName` command is available only for groups that are synchronized from on-premises Windows Server Active Directory.

:::zone pivot="service-principal"

- The service principal authentication method works only with managed Microsoft Entra ID integration, not legacy Microsoft Entra ID integration.
- The service principal can be a member of a maximum of 200 [Microsoft Entra groups][microsoft-entra-group-membership]. If you have more than 200 groups, consider using [application roles][entra-id-application-roles].

:::zone-end

:::zone pivot="device-code"

- The device code authentication method doesn't work when a Microsoft Entra Conditional Access policy is set on a Microsoft Entra tenant. In that scenario, use web browser interactive authentication instead.

:::zone-end

:::zone pivot="azure-cli"

- The Azure CLI authentication method works only with Microsoft Entra.

:::zone-end

## How kubelogin authentication works in AKS

AKS clusters running Kubernetes version 1.24 or later automatically use the kubelogin exec plugin format. Clusters running Kubernetes versions earlier than 1.24 require manual conversion to this format.

For most interactions with kubelogin, you use the [`convert-kubeconfig`](https://azure.github.io/kubelogin/cli/convert-kubeconfig.html) subcommand. The subcommand uses the kubeconfig file that's specified in `--kubeconfig` or in the `KUBECONFIG` environment variable to convert the final kubeconfig file to exec format based on the specified authentication method.

The authentication methods that kubelogin implements are Microsoft Entra OAuth 2.0 token grant flows. Cache behavior depends on the authentication method. Device code, web browser interactive, and resource owner password credential (ROPC) authentication cache authentication records in the kubelogin cache directory. Methods such as Azure CLI and Azure Developer CLI use the cache managed by their respective command-line tool instead of the kubelogin cache.

:::zone pivot="device-code"

## Device code authentication

Device code is the default authentication method for the `convert-kubeconfig` subcommand. This authentication method prompts the device code for the user to sign in from a browser session.

> [!NOTE]
> Before the kubelogin and exec plugins were introduced, the Azure authentication method in kubectl supported only the device code flow. It used an earlier version of a library that produces a token that has the `audience` claim with an `spn:` prefix. It isn't compatible with [Microsoft Entra][aks-managed-microsoft-entra-id], which uses an [on-behalf-of (OBO)][oauth-on-behalf-of] flow. When you run the `convert-kubeconfig` subcommand, kubelogin removes the `spn:` prefix from the audience claim.

### Parameters for device code authentication

The following table outlines parameters that you can use with device code authentication:

| Parameter | Description |
|-----------|-------------|
| `-l devicecode` (optional) | Specifies the kubelogin authentication method. This parameter is optional because device code is the default method. |
| `--legacy` | Uses legacy behavior for clusters configured with legacy Microsoft Entra ID integration. If the kubeconfig file is for such a cluster, kubelogin automatically adds the `--legacy` flag. |
| `--cache-dir` | Overrides the default path of the token cache directory, which is _${HOME}/.kube/cache/kubelogin_. |

:::zone-end

:::zone pivot="azure-cli"

## Azure CLI authentication

The Azure CLI (command: `-l azurecli`) authentication method uses the signed-in context that the Azure CLI establishes to get the access token. The token is issued in the same Microsoft Entra tenant as [`az login`](/cli/azure/authenticate-azure-cli-interactively#interactive-login). kubelogin doesn't write tokens to the token cache file because the Azure CLI already manages them.

### Parameters for Azure CLI authentication

The following table outlines parameters that you can use with Azure CLI authentication:

| Parameter | Description |
|-----------|-------------|
| `-l azurecli` | Specifies the kubelogin authentication method. |
| `--azure-config-dir` | Specifies the Azure CLI configuration directory. The default directory is _${HOME}/.azure_. |

## Sign in to Azure

Sign in to Azure using the `az login` command.

```azurecli-interactive
az login
```

:::zone-end

:::zone pivot="web-browser-interactive"

## Web browser interactive authentication

The web browser interactive (command: `-l interactive`) method of authentication automatically opens a web browser to sign in the user. After the user is authenticated, the browser redirects to the local web server using the verified credentials. This authentication method complies with Conditional Access policy.

You can use either a bearer token or a Proof-of-Possession (PoP) token with this authentication method.

### Parameters for bearer token authentication

The following table outlines parameters that you can use with bearer token authentication:

| Parameter | Description |
|-----------|-------------|
| `-l interactive` | Specifies the kubelogin authentication method. |
| `--cache-dir` | Overrides the default path of the token cache directory, which is _${HOME}/.kube/cache/kubelogin_. |

### Parameters for PoP token authentication

The following table outlines parameters that you can use with PoP token authentication:

| Parameter | Description |
|-----------|-------------|
| `-l interactive` | Specifies the kubelogin authentication method. |
| `--pop-enabled` | Enables PoP token authentication. |
| `--pop-claims` | Specifies the PoP token claims in a key-value pair format. For example, `u=/ARM/ID/OF/CLUSTER`. |

:::zone-end

:::zone pivot="service-principal"

## Service principal authentication

The service principal (command: `-l spn`) authentication method uses a service principal to sign in the user. You can provide the credential by setting an environment variable or by using the credential in a command-line argument. The supported credentials that you can use are a password or a Personal Information Exchange (PFX) client certificate.

### Parameters for service principal authentication

The following table outlines parameters that you can use with service principal authentication:

| Parameter | Description |
|-----------|-------------|
| `-l spn` | Specifies the kubelogin authentication method. |
| `--client-id` | The application ID (client-id) of the service principal. |
| `--client-secret` | The client secret of the service principal. |

:::zone-end

:::zone pivot="managed-identity"

## Managed identity authentication

Use the [managed identity][managed-identity-overview] (command: `-l msi`) authentication method for applications that connect to resources that support Microsoft Entra authentication. Examples include accessing Azure resources like an Azure virtual machine (VM), Virtual Machine Scale Sets, or Azure Cloud Shell.

You can use the default managed identity that's assigned to the resource or a specific user-assigned managed identity.

### Parameters for managed identity authentication

The following table outlines parameters that you can use with managed identity authentication:

| Parameter | Description |
|-----------|-------------|
| `-l msi` | Specifies the kubelogin authentication method. |
| `--client-id` | The application ID (client-id) of the user-assigned managed identity. If you don't specify this parameter, the default managed identity is used. |

:::zone-end

:::zone pivot="workload-identity"

## Workload identity authentication

The workload identity (command: `-l workloadidentity`) authentication method uses identity credentials that are federated with Microsoft Entra to authenticate access to AKS clusters. The method uses Microsoft Entra integrated authentication. It works by setting the following environment variables:

| Variable | Description |
|----------|-------------|
| `AZURE_CLIENT_ID` | The Microsoft Entra application ID that is federated with the workload identity. |
| `AZURE_TENANT_ID` | The Microsoft Entra tenant ID. |
| `AZURE_FEDERATED_TOKEN_FILE` | The file that contains a signed assertion of the workload identity, like a Kubernetes projected service account (JWT) token. |
| `AZURE_AUTHORITY_HOST` | The base URL of a Microsoft Entra authority. For example, `https://login.microsoftonline.com/`. |

You can use a [workload identity][workload-identity] to access Kubernetes clusters from CI/CD systems like GitHub or Argo CD without storing service principal credentials in the external systems. To configure OpenID Connect (OIDC) federation from GitHub, see the [OIDC federation example][oidc-federation-github].

### Parameters for workload identity authentication

The following table outlines parameters that you can use with workload identity authentication:

| Parameter | Description |
|-----------|-------------|
| `-l workloadidentity` | Specifies the kubelogin authentication method. |

:::zone-end

## Azure Developer CLI authentication

The Azure Developer CLI (command: `-l azd`) authentication method uses the signed-in context that the Azure Developer CLI establishes to get the access token. The token is issued in the same Microsoft Entra tenant as [`azd auth login`](/azure/developer/azure-developer-cli/reference#azd-auth-login). kubelogin doesn't write tokens to its token cache because the Azure Developer CLI manages them.

This authentication method works only with managed Microsoft Entra in AKS. For more information, see the [Azure Developer CLI overview](/azure/developer/azure-developer-cli/overview).

## Azure Pipelines authentication

The Azure Pipelines (command: `-l azurepipelines`) authentication method uses an Azure Resource Manager service connection and the pipeline's system access token to authenticate. This method works only in Azure Pipelines. The pipeline must have an Azure Resource Manager service connection and allow scripts to access the OAuth token.

When you use an [`AzureCLI@2`](/azure/devops/pipelines/tasks/reference/azure-cli-v2) task with an Azure Resource Manager service connection, kubelogin can use the tenant ID, client ID, and service connection ID that Azure Pipelines provides as environment variables. For more information, see [Azure Pipelines service connections](/azure/devops/pipelines/library/service-endpoints).

> [!WARNING]
> kubelogin also supports the resource owner password credential (ROPC) authentication method. Microsoft recommends that you don't use ROPC because it's incompatible with multifactor authentication and some hybrid identity scenarios. For more information, see the [Microsoft identity platform ROPC guidance](/entra/identity-platform/v2-oauth-ropc).

## Export the kubeconfig file path

Before you run the `convert-kubeconfig` subcommand, export the kubeconfig file path to the `KUBECONFIG` environment variable. For example:

```bash
export KUBECONFIG=/path/to/kubeconfig
```

:::zone pivot="device-code, azure-cli, web-browser-interactive, managed-identity, workload-identity"

## Convert the kubeconfig file

Run the `convert-kubeconfig` subcommand to convert the kubeconfig file to use the exec plugin for your chosen authentication method.

:::zone-end

:::zone pivot="device-code"

```bash
kubelogin convert-kubeconfig
```

:::zone-end

:::zone pivot="azure-cli"

```bash
kubelogin convert-kubeconfig -l azurecli
```

:::zone-end

:::zone pivot="web-browser-interactive"

```bash
# Bearer token authentication
kubelogin convert-kubeconfig -l interactive

# Proof-of-Possession (PoP) token authentication
kubelogin convert-kubeconfig -l interactive --pop-enabled --pop-claims "u=/ARM/ID/OF/CLUSTER"
```

:::zone-end

:::zone pivot="service-principal"

## [Use environment variables](#tab/environment-variables)

1. Run the `convert-kubeconfig` subcommand to convert the kubeconfig file to use the exec plugin.

    ```bash
    kubelogin convert-kubeconfig -l spn
    ```

1. Set the environment variables for the client ID and client secret or client certificate. For example:

    ```bash
    export AZURE_CLIENT_ID=<service-principal-client-id>
    export AZURE_CLIENT_SECRET=<service-principal-client-secret>
    ```

## [Use command-line arguments](#tab/command-line-arguments)

> [!NOTE]
> The command-line argument method stores the secret in the kubeconfig file.

Run the `convert-kubeconfig` subcommand with the client ID and client secret or client certificate parameters.

```bash
kubelogin convert-kubeconfig -l spn --client-id <service-principal-client-id> --client-secret <service-principal-client-secret>
```

## [Use a client certificate](#tab/client-certificate)

1. Run the `convert-kubeconfig` subcommand to convert the kubeconfig file to use the exec plugin.

    ```bash
    kubelogin convert-kubeconfig -l spn
    ```

1. Set the environment variables for the client ID, client certificate path, and client certificate password. For example:

    ```bash
    export AZURE_CLIENT_ID=<service-principal-client-id>
    export AZURE_CLIENT_CERTIFICATE_PATH=/path/to/cert.pfx
    export AZURE_CLIENT_CERTIFICATE_PASSWORD=<pfx-password>
    ```

## [Use a PoP token with environment variables](#tab/pop-token-environment-variables)

1. Run the `convert-kubeconfig` subcommand to convert the kubeconfig file to use the exec plugin.

    ```bash
    kubelogin convert-kubeconfig -l spn --pop-enabled --pop-claims "u=/ARM/ID/OF/CLUSTER"
    ```

1. Set the environment variables for the client ID and client secret or client certificate. For example:

    ```bash
    export AZURE_CLIENT_ID=<service-principal-client-id>
    export AZURE_CLIENT_SECRET=<service-principal-client-secret>
    ```

:::zone-end

:::zone pivot="managed-identity"

```bash
# Default managed identity authentication
kubelogin convert-kubeconfig -l msi

# Specific managed identity authentication
kubelogin convert-kubeconfig -l msi --client-id <managed-identity-client-id>
```

:::zone-end

:::zone pivot="workload-identity"

```bash
kubelogin convert-kubeconfig -l workloadidentity
```

:::zone-end

## Convert the kubeconfig file using the Azure Developer CLI

1. Sign in using the Azure Developer CLI.

    ```azurecli
    azd auth login
    ```

1. Convert the kubeconfig file to use the Azure Developer CLI authentication method.

    ```bash
    kubelogin convert-kubeconfig -l azd
    ```

## Convert the kubeconfig file in Azure Pipelines

In an `AzureCLI@2` task that uses an Azure Resource Manager service connection, convert the kubeconfig file to use Azure Pipelines authentication.

```bash
kubelogin convert-kubeconfig -l azurepipelines
```

:::zone pivot="device-code"

## Remove cached tokens

Remove cached tokens using the [`kubelogin remove-cache-dir`](https://azure.github.io/kubelogin/cli/remove-cache-dir.html) command.

```bash
kubelogin remove-cache-dir
```

:::zone-end

## Get node information

Get node information using the [`kubectl get`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get) command.

```bash
kubectl get nodes
```

## How to use kubelogin application IDs with AKS

AKS uses a pair of first-party Microsoft Entra applications. These application IDs are the same in all environments.

| Application | Application ID (GUID) | Used in |
|-------------|-----------------------|---------|
| AKS server application (`--server-id`) | `6dae42f8-4368-4678-94ff-3960e28e3630` | The token audience for all supported kubelogin authentication methods when accessing AKS. |
| AKS public client application (`--client-id`) | `80faf920-1908-4b52-b5ef-a8e7bedfc67a` | Device code, web browser interactive, and ROPC authentication. |

When you call `kubelogin get-token` directly for AKS, specify the AKS server application ID with `--server-id`. For mode-specific parameters, see the [kubelogin `get-token` reference](https://azure.github.io/kubelogin/cli/get-token.html).

> [!NOTE]
> The AKS public client application ID in this section is the `--client-id` value for device code, web browser interactive, and ROPC authentication. For service principal and managed identity authentication, `--client-id` identifies the service principal or user-assigned managed identity instead.

For example, get a token by using device code authentication and the AKS application IDs:

```bash
kubelogin get-token \
    --login devicecode \
    --server-id 6dae42f8-4368-4678-94ff-3960e28e3630 \
    --client-id 80faf920-1908-4b52-b5ef-a8e7bedfc67a \
    --tenant-id <microsoft-entra-tenant-id>
```

## Related content

- Learn how to integrate AKS with Microsoft Entra in the [Microsoft Entra integration][aks-managed-microsoft-entra-integration-guide] how-to article.
- To get started with managed identities in AKS, see [Use a managed identity in AKS][use-a-managed-identity-in-aks].
- To get started with workload identities in AKS, see [Use a workload identity in AKS][use-a-workload-identity-in-aks].

<!-- LINKS - internal -->
[aks-managed-microsoft-entra-id]: managed-azure-ad.md
[oauth-on-behalf-of]: /azure/active-directory/develop/v2-oauth2-on-behalf-of-flow
[microsoft-entra-group-membership]: /entra/identity/hybrid/connect/how-to-connect-fed-group-claims
[managed-identity-overview]: /entra/identity/managed-identities-azure-resources/overview
[workload-identity]: /entra/workload-id/workload-identities-overview
[entra-id-application-roles]: /entra/external-id/customers/how-to-use-app-roles-customers
[aks-managed-microsoft-entra-integration-guide]: managed-azure-ad.md
[use-a-managed-identity-in-aks]: use-managed-identity.md
[use-a-workload-identity-in-aks]: workload-identity-overview.md

<!-- LINKS - external -->
[client-go-cred-plugin]: https://kubernetes.io/docs/reference/access-authn-authz/authentication/#client-go-credential-plugins
[oidc-federation-github]: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure
