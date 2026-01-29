---
title: Service account creation and workload identity setup for the Agentic CLI for Azure Kubernetes Service (AKS) (Preview)
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

# Service account creation and workload identity setup for the Agentic CLI for Azure Kubernetes Service (AKS) (preview)

This article shows you how to create the **required** service account and **optionally** configure workload identity for the agentic CLI for Azure Kubernetes Service (AKS). The service account creation is **mandatory** for cluster mode deployment, while workload identity setup is optional but recommended for enhanced security when accessing Azure resources.

For the main installation guide, see [Install and use the agentic CLI for Azure Kubernetes Service (AKS)](./cli-agent-for-aks-install.md).

## Prerequisites

**For service account creation (mandatory):**
- Use the Azure CLI version 2.76 or later. To verify your Azure CLI version, use the [`az version`](/cli/azure/reference-index#az-version) command.
- Ensure that you're signed in to the proper subscription by using the [`az account set`](/cli/azure/account#az-account-set) command.
- You need sufficient permissions to create and manage Kubernetes service accounts, roles, and role bindings

**For workload identity setup (optional):**
- Your AKS cluster must have workload identity enabled. If not enabled, follow the steps in [Enable workload identity](#verify-and-enable-workload-identity).
- You need sufficient permissions to:
  - Create and manage Azure managed identities
  - Create federated identity credentials

## Define variables

First, set up the required variables for your environment. Replace the placeholder values with your actual cluster and Azure details:

**Required variables (for service account creation):**

```bash
# Cluster information
export RESOURCE_GROUP="<YOUR_RESOURCE_GROUP>"
export CLUSTER_NAME="<YOUR_CLUSTER_NAME>"

# Service account configuration
export SERVICE_ACCOUNT_NAME="aks-mcp"
export SERVICE_ACCOUNT_NAMESPACE="<YOUR_NAMESPACE>"  # e.g., "kube-system" or custom namespace
```

**Additional variables (only if configuring workload identity):**

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

## Step 1: Create the Kubernetes service account (Mandatory)

This step is **required** for cluster mode deployment.

### Create or verify the namespace

If you're using a custom namespace (not `kube-system`), create it first:

```bash
kubectl create namespace "${SERVICE_ACCOUNT_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
```

### Create the service account

Create the service account in your target namespace:

```bash
kubectl create serviceaccount "${SERVICE_ACCOUNT_NAME}" -n "${SERVICE_ACCOUNT_NAMESPACE}"
```

### Create RBAC permissions

Create the necessary Role and RoleBinding for the service account with read access for aks-mcp troubleshooting:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
  name: aks-mcp-role
rules:
# Read access to all resources in the namespace for aks-mcp troubleshooting
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: aks-mcp-rolebinding
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
subjects:
- kind: ServiceAccount
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
roleRef:
  kind: Role
  name: aks-mcp-role
  apiGroup: rbac.authorization.k8s.io
EOF
```

### Verify the service account resources

Verify that the resources were created successfully:

```bash
kubectl get serviceaccount "${SERVICE_ACCOUNT_NAME}" -n "${SERVICE_ACCOUNT_NAMESPACE}"
kubectl get role aks-mcp-role -n "${SERVICE_ACCOUNT_NAMESPACE}"
kubectl get rolebinding aks-mcp-rolebinding -n "${SERVICE_ACCOUNT_NAMESPACE}"
```

## Workload identity setup (Optional)

The following steps are **optional** but recommended if you want to enable the agentic CLI to access Azure resources securely using workload identity.

### Verify and enable workload identity

#### Check current workload identity status

Verify if workload identity is enabled on your cluster:

```azurecli-interactive
az aks show --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --query "securityProfile.workloadIdentity.enabled"
```

If the output is `true`, workload identity is enabled. If `null` or `false`, you need to enable it.

#### Enable workload identity (if required)

If workload identity is not enabled, update your cluster to enable OIDC issuer and workload identity:

```azurecli-interactive
az aks update \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --enable-oidc-issuer \
    --enable-workload-identity
```

#### Retrieve the OIDC issuer URL

Get the OIDC issuer URL and save it to an environment variable:

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

> [!NOTE]
> This step is **optional** and only required if you want to configure workload identity for Azure resource access.

Create a user-assigned managed identity for Azure resource access:

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

Get the client ID of the managed identity and save it to an environment variable:

```azurecli-interactive
export USER_ASSIGNED_CLIENT_ID="$(az identity show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${USER_ASSIGNED_IDENTITY_NAME}" \
    --query 'clientId' \
    --output tsv)"
```

## Step 3: Annotate the service account with workload identity (Optional)

> [!NOTE]
> This step is **optional** and only required if you created a managed identity in Step 2.

Update the service account to include the annotation for workload identity:

```bash
kubectl annotate serviceaccount "${SERVICE_ACCOUNT_NAME}" \
    -n "${SERVICE_ACCOUNT_NAMESPACE}" \
    azure.workload.identity/client-id="${USER_ASSIGNED_CLIENT_ID}" \
    --overwrite
```

## Step 4: Create the federated identity credential (Optional)

> [!NOTE]
> This step is **optional** and only required if you want to complete the workload identity setup.

Create a federated identity credential between the managed identity, the service account issuer, and the subject:

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

## Verify the setup

### Check the service account annotation

Verify that the service account has the correct workload identity annotation:

```bash
kubectl describe serviceaccount "${SERVICE_ACCOUNT_NAME}" -n "${SERVICE_ACCOUNT_NAMESPACE}"
```

You should see the annotation:

```output
Annotations:
  azure.workload.identity/client-id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### Verify the federated identity credential

List the federated identity credentials to confirm creation:

```azurecli-interactive
az identity federated-credential list \
    --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" \
    --resource-group "${RESOURCE_GROUP}"
```

## Next steps

Now that you have completed the mandatory service account setup, you can proceed with the cluster mode installation:

1. Return to the [Install and use the agentic CLI for Azure Kubernetes Service (AKS)](./cli-agent-for-aks-install.md) article
2. Continue with the [Installation section](./cli-agent-for-aks-install.md#installation), cluster mode tab
3. When prompted during initialization, use the values you configured:
   - **Service account name**: `${SERVICE_ACCOUNT_NAME}` (aks-mcp)
   - **Namespace**: `${SERVICE_ACCOUNT_NAMESPACE}`
   - **Managed identity client ID**: Only provide if you completed the optional workload identity setup (`${USER_ASSIGNED_CLIENT_ID}`)

## Troubleshooting

### Common issues and solutions

- **Workload identity not enabled**: Ensure workload identity is enabled on your cluster using the verification commands above
- **Permission denied errors**: Verify you have sufficient permissions to create managed identities and federated credentials
- **Service account not found**: Ensure the service account was created in the correct namespace
- **Annotation missing**: Re-run the annotation command if the workload identity client ID annotation is missing

### Federated credential propagation delay

If you encounter authentication issues immediately after setup, wait 1-2 minutes for the federated identity credential to propagate across Azure services.

## Related content

- [Install and use the agentic CLI for Azure Kubernetes Service (AKS)](./cli-agent-for-aks-install.md)
- [Deploy and configure Microsoft Entra Workload ID on an Azure Kubernetes Service (AKS) cluster](/azure/aks/workload-identity-deploy-cluster)
- [Microsoft Entra Workload ID overview](/azure/aks/workload-identity-overview)