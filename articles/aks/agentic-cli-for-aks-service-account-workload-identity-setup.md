---
title: Create a Service Account and Configure Workload Identity for the Agentic CLI for Azure Kubernetes Service (AKS) (preview)
description: Learn how to create the required service account and optionally configure workload identity for the agentic CLI for AKS to enable authentication.
ms.topic: how-to
ms.date: 01/29/2026
author: aritragho
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-monitoring
ai-usage: ai-generated
# Customer intent: As a cluster administrator or SRE, I want to set up the required service account and optionally configure workload identity for the agentic CLI for AKS so that the agent can access cluster resources securely.
---

# Create a service account and configure workload identity for the agentic CLI for Azure Kubernetes Service (AKS) (preview)

This article shows you how to create the **required** service account and **optionally** configure workload identity for the agentic CLI for Azure Kubernetes Service (AKS). The service account creation is **mandatory** for cluster mode deployment, while workload identity setup is optional but recommended for enhanced security when accessing Azure resources.

## Prerequisites

**Service account creation prerequisites**:

- Azure CLI version 2.76 or later. Check your version using the `az version` command. To install or update, see [Install Azure CLI](/cli/azure/install-azure-cli).
- Set your active Azure subscription using the [`az account set`](/cli/azure/account#az-account-set) command.

    ```azurecli-interactive
    az account set --subscription "your-subscription-id-or-name"
    ```

- You need sufficient permissions to create and manage Kubernetes service accounts, roles, and role bindings.

**Workload identity configuration prerequisites**:

- [Workload identity enabled on your AKS cluster](/azure/aks/workload-identity-overview).
- You need sufficient permissions to create and manage Azure managed identities and create federated identity credentials.

## Define variables

First, set up the required variables for your environment. Replace the placeholder values with your actual cluster and Azure details.

**Required variables for service account creation**:

```bash
# Cluster information
export RESOURCE_GROUP="<YOUR_RESOURCE_GROUP>"
export CLUSTER_NAME="<YOUR_CLUSTER_NAME>"

# Service account configuration
export SERVICE_ACCOUNT_NAME="aks-mcp"
export SERVICE_ACCOUNT_NAMESPACE="<YOUR_NAMESPACE>"  # e.g., "kube-system" or custom namespace
```

**Additional variables (only if configuring workload identity)**:

```bash
# Azure information for workload identity
export LOCATION="<YOUR_LOCATION>"
export SUBSCRIPTION="$(az account show --query id --output tsv)"

# Workload identity configuration
export USER_ASSIGNED_IDENTITY_NAME="aks-mcp-identity"
export FEDERATED_IDENTITY_CREDENTIAL_NAME="aks-mcp-fed-identity"

# Generate unique suffix for resource naming
export RANDOM_ID="$(openssl rand -hex 3)"
```

## Create a Kubernetes service account and assign permissions (required)

> [!IMPORTANT]
> The service account is **required** for the agentic CLI to authenticate with the AKS cluster in **cluster mode**.

### Create the service account

Create the service account in your target namespace using the following command:

```bash
kubectl create serviceaccount "${SERVICE_ACCOUNT_NAME}" --namespace "${SERVICE_ACCOUNT_NAMESPACE}"
```

### Create RBAC permissions

Create the necessary Role and RoleBinding for the service account with read access for aks-mcp troubleshooting. Here are two examples based on your access requirements:

#### Cluster-wide read access (recommended for cluster administrators)

1. Use this ClusterRoleBinding to grant read-only access to all Kubernetes resources except secrets across all namespaces. This option is recommended for cluster-level administrators or DevOps engineers who need to investigate and troubleshoot issues across the entire cluster.

    ```bash
    cat <<EOF | kubectl apply -f -
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: aks-mcp-view-rolebinding
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: view
    subjects:
    - kind: ServiceAccount
      name: ${SERVICE_ACCOUNT_NAME}
      namespace: ${SERVICE_ACCOUNT_NAMESPACE}
    EOF
    ```

1. Verify the resources were created successfully using the following commands:

    ```bash
    kubectl get serviceaccount "${SERVICE_ACCOUNT_NAME}" --namespace "${SERVICE_ACCOUNT_NAMESPACE}"
    kubectl get clusterrolebinding aks-mcp-view-rolebinding
    ```

#### Namespace-scoped read access (for limited access scenarios)

1. Use RoleBindings to grant read-only access to all Kubernetes resources except secrets in specific namespaces only. This option is suitable for teams or users who should have limited access to specific namespaces rather than the entire cluster. Repeat this RoleBinding for each namespace that requires access.

    ```bash
    cat <<EOF | kubectl apply -f -
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: aks-mcp-view-rolebinding
      namespace: ${SERVICE_ACCOUNT_NAMESPACE}
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: view
    subjects:
    - kind: ServiceAccount
      name: ${SERVICE_ACCOUNT_NAME}
      namespace: ${SERVICE_ACCOUNT_NAMESPACE}
    EOF
    ```

1. Verify the resources were created successfully using the following commands:

    ```bash
    kubectl get serviceaccount "${SERVICE_ACCOUNT_NAME}" --namespace "${SERVICE_ACCOUNT_NAMESPACE}"
    kubectl get rolebinding aks-mcp-view-rolebinding --namespace "${SERVICE_ACCOUNT_NAMESPACE}"
    ```

## Configure workload identity for Azure resource access (optional)

The following steps are **optional** but recommended if you want to enable the agentic CLI to access Azure resources securely using workload identity.

### Check current workload identity status

Check if workload identity is already enabled on your AKS cluster using the [`az aks show`](/cli/azure/aks#az-aks-show) command.

```azurecli-interactive
az aks show --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --query "securityProfile.workloadIdentity.enabled"
```

If the output is `true`, workload identity is enabled. If `null` or `false`, you need to enable it.

### Enable workload identity

Enable workload identity on your AKS cluster using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--enable-workload-identity` and `--enable-oidc-issuer` flags.

```azurecli-interactive
az aks update \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --enable-oidc-issuer \
    --enable-workload-identity
```

### Retrieve the OIDC issuer URL

Get the OIDC issuer URL using the [`az aks show`](/cli/azure/aks#az-aks-show) command and save it to an environment variable.

```azurecli-interactive
export AKS_OIDC_ISSUER="$(az aks show --name "${CLUSTER_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query "oidcIssuerProfile.issuerUrl" \
    --output tsv)"
```

The environment variable should contain the issuer URL, similar to the following example:

```output
https://eastus.oic.prod-aks.azure.com/00000000-0000-0000-0000-000000000000/11111111-1111-1111-1111-111111111111/
```

### Create a user-assigned managed identity

Create a user-assigned managed identity for Azure resource access using the [`az identity create`](/cli/azure/identity#az-identity-create) command.

```azurecli-interactive
az identity create \
    --name "${USER_ASSIGNED_IDENTITY_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --subscription "${SUBSCRIPTION}"
```

The following output example shows successful creation of a managed identity:

```output
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/myResourceGroupxxxxxx/providers/Microsoft.ManagedIdentity/userAssignedIdentities/myIdentityxxxxxx",
  "location": "eastus",
  "name": "myIdentityxxxxxx",
  "principalId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "resourceGroup": "myResourceGroupxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "type": "Microsoft.ManagedIdentity/userAssignedIdentities"
}
```

### Get the managed identity client ID

Get the client ID of the managed identity using the [`az identity show`](/cli/azure/identity#az-identity-show) and save it to an environment variable.

```azurecli-interactive
export USER_ASSIGNED_CLIENT_ID="$(az identity show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${USER_ASSIGNED_IDENTITY_NAME}" \
    --query 'clientId' \
    --output tsv)"
```

### Assign necessary role to managed identity

Assign the necessary roles to the managed identity using the [`az role assignment create`](/cli/azure/role/assignment#az-role-assignment-create) command. 

The following example assigns the "Reader" role at the subscription scope, which allows the agentic CLI to read Azure resource information. Adjust the role and scope as needed for your use case.

```azurecli-interactive
az role assignment create --role "Reader" \
    --assignee $USER_ASSIGNED_CLIENT_ID \
    --scope /subscriptions/${SUBSCRIPTION}
```

If you're using Azure OpenAI with Microsoft Entra ID (keyless authentication), you must also assign the "Cognitive Services User" or "Azure AI User" role on the Azure OpenAI resource:

```azurecli-interactive
# Option 1: Assign Cognitive Services User role
az role assignment create \
    --role "Cognitive Services User" \
    --assignee $USER_ASSIGNED_CLIENT_ID \
    --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.CognitiveServices/accounts/<openai-resource-name>

# Option 2: Assign Azure AI User role
az role assignment create \
    --role "Azure AI User" \
    --assignee $USER_ASSIGNED_CLIENT_ID \
    --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.CognitiveServices/accounts/<openai-resource-name>
```

Replace `<subscription-id>`, `<resource-group>`, and `<openai-resource-name>` with your actual values.

### Annotate the service account with workload identity (optional)

1. Update the service account to include the annotation for workload identity using the following command:

    ```bash
    kubectl annotate serviceaccount "${SERVICE_ACCOUNT_NAME}" \
        --namespace "${SERVICE_ACCOUNT_NAMESPACE}" \
        azure.workload.identity/client-id="${USER_ASSIGNED_CLIENT_ID}" \
        --overwrite
    ```

1. Verify the service account has the correct workload identity annotation using the following command:

    ```bash
    kubectl describe serviceaccount "${SERVICE_ACCOUNT_NAME}" --namespace "${SERVICE_ACCOUNT_NAMESPACE}"
    ```

### Create a federated identity credential (optional)

1. Create a federated identity credential between the managed identity, the service account issuer, and the subject using the [`az identity federated-credential create`](/cli/azure/identity/federated-credential#az-identity-federated-credential-create) command.

    ```azurecli-interactive
    az identity federated-credential create \
        --name "${FEDERATED_IDENTITY_CREDENTIAL_NAME}" \
        --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --issuer "${AKS_OIDC_ISSUER}" \
        --subject "system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME}" \
        --audience api://AzureADTokenExchange
    ```

    > [!NOTE]
    > It takes a few seconds for the federated identity credential to propagate after it's added. If a token request is made immediately after adding the federated identity credential, the request might fail until the cache is refreshed. To avoid this issue, you can add a slight delay after adding the federated identity credential.

1. List the federated identity credentials to confirm creation using the [`az identity federated-credential list`](/cli/azure/identity/federated-credential#az-identity-federated-credential-list) command.

    ```azurecli-interactive
    az identity federated-credential list \
        --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" \
        --resource-group "${RESOURCE_GROUP}"
    ```

## Related content

- [Install and use the agentic CLI for AKS](./agentic-cli-for-aks-install.md)
- [Deploy and configure Microsoft Entra Workload ID on an AKS cluster](/azure/aks/workload-identity-deploy-cluster)
- [Microsoft Entra Workload ID overview](/azure/aks/workload-identity-overview)
