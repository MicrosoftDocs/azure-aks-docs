---
title: Deploy and use Container Network Insights Agent on AKS
description: Learn how to deploy Container Network Insights Agent as an AKS extension to troubleshoot networking issues in Azure Kubernetes Service (AKS) clusters.
author: shaifaligargmsft
ms.author: shaifaligarg
ms.date: 02/23/2026
ms.topic: how-to
ms.service: azure-kubernetes-service
---

# Deploy and use Container Network Insights Agent on AKS

This article shows how to deploy Container Network Insights Agent on your Azure Kubernetes Service (AKS) cluster, configure authentication and identity, and use the agent to troubleshoot networking issues.

Container Network Insights Agent is an AI-powered diagnostic assistant that runs as an in-cluster web application. You describe networking problems in natural language, and the agent runs diagnostic commands (`kubectl`, `cilium`, `hubble`) against your cluster. It returns structured, evidence-backed reports with root cause analysis and remediation guidance.

Container Network Insights Agent helps you troubleshoot:

- DNS failures, including CoreDNS misconfigurations, network policies blocking DNS traffic, NodeLocal DNS issues, and Cilium FQDN egress restrictions.
- Packet drops, including NIC-level RX drops, kernel packet loss, socket buffer overflow, SoftIRQ saturation, and ring buffer exhaustion across cluster nodes.
- Kubernetes networking issues, including pod connectivity failures, service port misconfigurations, network policy conflicts, missing endpoints, and Hubble flow analysis.
- Cluster resource queries for quick answers about pods, services, deployments, nodes, and namespaces.

Container Network Insights Agent operates with read-only access to your cluster. It doesn't modify running workloads, configurations, or network policies. Remediation guidance is advisory only.

Container Network Insights Agent deploys as an AKS extension (`microsoft.containernetworkingagent`). It integrates with the Azure resource management plane, and is managed through the `az k8s-extension` CLI commands.

**Supported regions:** centralus, eastus, eastus2, uksouth, westus2.

## Prerequisites

Before you begin, ensure you have the following tools, permissions, and information.

### Tools required

| Tool | Version | Check command | Install guide |
|------|---------|---------------|---------------|
| Azure CLI | >= 2.77.0 | `az version` | [Install the Azure CLI](/cli/azure/install-azure-cli) |
| kubectl | latest | `kubectl version --client` | `az aks install-cli` |
| jq | any | `jq --version` | [Download jq](https://jqlang.github.io/jq/download/) |
| Git | any | `git --version` | [Install Git](https://git-scm.com/downloads) |
| Azure CLI `k8s-extension` extension | latest | `az extension show --name k8s-extension` | `az extension add --name k8s-extension` |

### Azure permissions required

- **Contributor** on the target resource group.
- **User Access Administrator** on the target resource group (for RBAC role assignments).
- Access to create Azure OpenAI resources in your subscription.
- Access to create Entra ID App Registrations (for production authentication).

### Information you'll need

| Parameter | Description |
|-----------|-------------|
| Azure Subscription ID | Your target subscription. |
| Resource group name | Existing or to be created during deployment. |
| Azure region | A supported region: centralus, eastus, eastus2, uksouth, westus2. |
| AKS cluster name | Create a new cluster or use an existing one. |
| `SERVICE_MANAGEMENT_REFERENCE` | Service management reference (for example, a Service Tree ID) required by some tenants for App Registration setup (Step 7). |

> [!TIP]
> To find your Service Management Reference for an existing app, run:
> `az ad app show --id <app-id> --query serviceManagementReference -o tsv`

### Cluster requirements

- An active Azure subscription. If you don't have one, create a [free account](https://azure.microsoft.com/free/) before you begin.
- An AKS cluster with [workload identity](/azure/aks/workload-identity-overview) and [OIDC issuer](/azure/aks/use-oidc-issuer) enabled, running a [supported Kubernetes version](/azure/aks/supported-kubernetes-versions). You create a new cluster in [Step 2](#step-2-create-an-aks-cluster) if needed.
- (Recommended) [Azure CNI powered by Cilium](/azure/aks/azure-cni-powered-by-cilium) with [Advanced Container Networking Services (ACNS)](/azure/aks/advanced-container-networking-services-overview) enabled, for full diagnostic capabilities including Hubble flow analysis and Cilium policy diagnostics.
- Minimum node size: `Standard_D4_v3` or equivalent (three nodes recommended).
- An [Azure OpenAI](/azure/ai-services/openai/) resource with a deployed model (for example, GPT-4o or later). You create this resource in [Step 3](#step-3-create-an-azure-openai-resource-and-deploy-a-model) if needed.
- The AKS cluster requires outbound connectivity to the Azure OpenAI endpoint over HTTPS (port 443).
- The cluster must be able to pull container images from `acnpublic.azurecr.io`.

> [!TIP]
> Container Network Insights Agent works on clusters without Cilium or ACNS, but with reduced diagnostic capabilities. On non-ACNS clusters, the agent provides DNS, packet drop, and standard Kubernetes networking diagnostics. Hubble flow analysis and Cilium policy diagnostics aren't available.

## Deploy Container Network Insights Agent

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]
Follow these steps to deploy the agent:

1. [Set environment variables and create a resource group](#step-1-set-environment-variables-and-create-a-resource-group)
1. [Create an AKS cluster](#step-2-create-an-aks-cluster)
1. [Create an Azure OpenAI resource and deploy a model](#step-3-create-an-azure-openai-resource-and-deploy-a-model)
1. [Create a managed identity](#step-4-create-a-managed-identity)
1. [Assign RBAC roles](#step-5-assign-rbac-roles)
1. [Configure federated credentials](#step-6-configure-federated-credentials)
1. [Create an App Registration for Entra ID authentication](#step-7-create-an-app-registration-for-entra-id-authentication)
1. [Install the extension](#step-8-install-the-extension)

### Step 1: Set environment variables and create a resource group

Define the core configuration variables and create an Azure resource group to organize all the resources you'll deploy in subsequent steps (AKS cluster, Azure OpenAI service, managed identity). Replace the placeholder values with your own.

```azurecli-interactive
export SUBSCRIPTION_ID="<your-subscription-id>"
export LOCATION="<your-region>"  # Supported regions: centralus, eastus, eastus2, uksouth, westus2
export RESOURCE_GROUP="<your-resource-group>"
export CLUSTER_NAME="<your-aks-cluster-name>"
export OPENAI_SERVICE_NAME="<your-openai-service-name>"
export OPENAI_DEPLOYMENT_NAME="<your-deployment-name>"        # Name to give the deployment
export OPENAI_MODEL_NAME="<your-model-name>"                  # e.g. gpt-4o or gpt-5
export OPENAI_MODEL_VERSION="<your-model-version>"            # e.g. 2024-11-20
export SKU_CAPACITY="<your-sku-capacity>"                     # e.g. 50, 100,1000. Capacity value of the Sku of Cognitive Services account/deployment.



az login
az account set --subscription $SUBSCRIPTION_ID
```

Create a resource group if one doesn't already exist using the [`az group create`](/cli/azure/group#az-group-create) command.

```azurecli-interactive
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION
```

### Step 2: Create an AKS cluster

If you don't already have an AKS cluster, create one with workload identity, OIDC issuer, Azure CNI with Cilium dataplane, and Advanced Container Networking Services (ACNS) enabled. Use the [`az aks create`](/cli/azure/aks#az-aks-create) command.

```azurecli-interactive
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --location $LOCATION \
    --node-count 3 \
    --node-vm-size Standard_D4_v3 \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --network-dataplane cilium \
    --enable-acns \
    --enable-oidc-issuer \
    --enable-workload-identity \
    --generate-ssh-keys
```

> [!NOTE]
> If you already have a cluster without workload identity and OIDC issuer, enable them using [`az aks update`](/cli/azure/aks#az-aks-update):
>
> ```azurecli-interactive
> az aks update \
>     --resource-group $RESOURCE_GROUP \
>     --name $CLUSTER_NAME \
>     --enable-oidc-issuer \
>     --enable-workload-identity
> ```

Get the cluster credentials using the [`az aks get-credentials`](/cli/azure/aks#az-aks-get-credentials) command.

```azurecli-interactive
az aks get-credentials \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --overwrite-existing
```

### Step 3: Create an Azure OpenAI resource and deploy a model

Container Network Insights Agent uses Azure OpenAI Service to power its AI reasoning. When you describe a networking issue, the agent sends your query and the collected diagnostic evidence to Azure OpenAI for analysis and response generation. In this step, you create an Azure OpenAI resource and deploy a model (for example, GPT-4o or later) that the agent uses at runtime.

> [!NOTE]
> If you already have an Azure OpenAI resource with a deployed model, skip the resource and model creation commands below. Instead, set the following environment variables to match your existing resource and continue to the next step:
>
> ```azurecli-interactive
> export OPENAI_SERVICE_NAME="<your-existing-openai-service-name>"
> export OPENAI_DEPLOYMENT_NAME="<your-existing-deployment-name>"
> export AZURE_OPENAI_ENDPOINT=$(az cognitiveservices account show \
>     --name $OPENAI_SERVICE_NAME \
>     --resource-group $RESOURCE_GROUP \
>     --query "properties.endpoint" -o tsv)
>
> echo "OpenAI Endpoint: $AZURE_OPENAI_ENDPOINT"
> echo "Deployment Name: $OPENAI_DEPLOYMENT_NAME"
> ```
>
> Then continue to [Step 4: Create a managed identity](#step-4-create-a-managed-identity).

#### [Azure CLI - Run commands individually](#tab/step3-cli)

If you don't already have an Azure OpenAI resource, create one using the [`az cognitiveservices account create`](/cli/azure/cognitiveservices/account#az-cognitiveservices-account-create) command. The following commands use `OPENAI_SERVICE_NAME`, `OPENAI_DEPLOYMENT_NAME`, `OPENAI_MODEL_NAME`, and `OPENAI_MODEL_VERSION` from [Step 1](#step-1-set-environment-variables-and-create-a-resource-group).

```azurecli-interactive
az cognitiveservices account create \
    --name $OPENAI_SERVICE_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --kind "OpenAI" \
    --sku "S0" \
    --custom-domain $OPENAI_SERVICE_NAME
```

Wait for provisioning to complete, then deploy the model using the [`az cognitiveservices account deployment create`](/cli/azure/cognitiveservices/account/deployment#az-cognitiveservices-account-deployment-create) command.

> [!TIP]
> The following loop polls the provisioning state every 10 seconds and proceeds automatically once the resource is ready. This is more reliable than a fixed `sleep` delay.

```azurecli-interactive
echo "Waiting for Azure OpenAI resource to be provisioned..."
while true; do
  STATE=$(az cognitiveservices account show \
      --name $OPENAI_SERVICE_NAME \
      --resource-group $RESOURCE_GROUP \
      --query "properties.provisioningState" -o tsv 2>/dev/null)
  if [[ "$STATE" == "Succeeded" ]]; then
    echo "Resource provisioned successfully."
    break
  fi
  echo "  Current state: ${STATE:-Creating}. Retrying in 10 seconds..."
  sleep 10
done

az cognitiveservices account deployment create \
    --name $OPENAI_SERVICE_NAME \
    --resource-group $RESOURCE_GROUP \
    --deployment-name $OPENAI_DEPLOYMENT_NAME \
    --model-name $OPENAI_MODEL_NAME \
    --model-version $OPENAI_MODEL_VERSION \
    --model-format OpenAI \
    --sku-name "GlobalStandard" \
    --sku-capacity "$SKU_CAPACITY"
```

Retrieve the endpoint URL using the [`az cognitiveservices account show`](/cli/azure/cognitiveservices/account#az-cognitiveservices-account-show) command.

```azurecli-interactive
export AZURE_OPENAI_ENDPOINT=$(az cognitiveservices account show \
    --name $OPENAI_SERVICE_NAME \
    --resource-group $RESOURCE_GROUP \
    --query "properties.endpoint" -o tsv)

echo "OpenAI Endpoint: $AZURE_OPENAI_ENDPOINT"
```


#### [Portal - Use the Azure portal UI](#tab/step3-portal)

Create an Azure OpenAI resource and deploy a model directly from the Azure portal.

Follow the step-by-step guide on Microsoft Learn:

> [Create and deploy an Azure OpenAI Service resource - Azure portal](/azure/ai-foundry/openai/how-to/create-resource?pivots=web-portal)

The guide walks you through:

1. Creating an Azure OpenAI resource in your subscription and resource group.
2. Deploying a model (for example, GPT-4.1 or later) to the resource.
3. Retrieving the endpoint URL and resource name.

> [!IMPORTANT]
> After creating the resource and deploying a model through the portal, set the following environment variables in your terminal before continuing to the next step. These values are required by subsequent deployment steps.
>
> ```azurecli-interactive
> export OPENAI_SERVICE_NAME="<your-openai-service-name>"       # The name you gave your Azure OpenAI resource
> export OPENAI_DEPLOYMENT_NAME="<your-model-deployment-name>"  # The deployment name shown in the portal
> export AZURE_OPENAI_ENDPOINT="<your-openai-endpoint>"         # For example, https://<name>.openai.azure.com/
>
> echo "OpenAI Endpoint: $AZURE_OPENAI_ENDPOINT"
> echo "Deployment Name: $OPENAI_DEPLOYMENT_NAME"
> ```

---

### Step 4: Create a managed identity

Create a user-assigned managed identity for the agent using the [`az identity create`](/cli/azure/identity#az-identity-create) command.

```azurecli-interactive
export IDENTITY_NAME="container-networking-agent-reader-identity"

az identity create \
    --name $IDENTITY_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --tags purpose=k8s-workload-identity
```

Get the identity client ID and principal ID using the [`az identity show`](/cli/azure/identity#az-identity-show) command.

```azurecli-interactive
export IDENTITY_CLIENT_ID=$(az identity show \
    --name $IDENTITY_NAME \
    --resource-group $RESOURCE_GROUP \
    --query "clientId" -o tsv)

export IDENTITY_PRINCIPAL_ID=$(az identity show \
    --name $IDENTITY_NAME \
    --resource-group $RESOURCE_GROUP \
    --query "principalId" -o tsv)

echo "Client ID: $IDENTITY_CLIENT_ID"
echo "Principal ID: $IDENTITY_PRINCIPAL_ID"
```

### Step 5: Assign RBAC roles

Assign the required roles to the managed identity using the [`az role assignment create`](/cli/azure/role/assignment#az-role-assignment-create) command. The managed identity needs the following roles:

| Role | Scope | Purpose |
|------|-------|---------|
| `Cognitive Services OpenAI User` | Azure OpenAI resource | Allows the agent to make inference calls to the deployed model. |
| `Azure Kubernetes Service Cluster User Role` | AKS cluster | Allows the agent to access AKS cluster properties. |
| `Azure Kubernetes Service Contributor Role` | AKS cluster | Allows the agent to read and write AKS cluster information for MCP AKS operations. |
| `Reader` | Resource group | Allows the agent to read resource group metadata. |

```azurecli-interactive

# 1. Grant Cognitive Services OpenAI User role on OpenAI resource
# NOTE: Use OPENAI_RESOURCE_GROUP if OpenAI is in a different resource group

export OPENAI_RESOURCE_GROUP="${OPENAI_RESOURCE_GROUP:-$RESOURCE_GROUP}"
az role assignment create \
    --assignee $IDENTITY_PRINCIPAL_ID \
    --role "Cognitive Services OpenAI User" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$OPENAI_RESOURCE_GROUP/providers/Microsoft.CognitiveServices/accounts/$OPENAI_SERVICE_NAME"


# 2. Grant AKS Cluster User Role (for kubeconfig access)
az role assignment create \
    --assignee $IDENTITY_PRINCIPAL_ID \
    --role "Azure Kubernetes Service Cluster User Role" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$CLUSTER_NAME"

# 3. Grant AKS Contributor Role (for cluster management operations)
az role assignment create \
    --assignee $IDENTITY_PRINCIPAL_ID \
    --role "Azure Kubernetes Service Contributor Role" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerService/managedClusters/$CLUSTER_NAME"

# 4. Grant Reader role on resource group (for resource discovery)
az role assignment create \
    --assignee $IDENTITY_PRINCIPAL_ID \
    --role "Reader" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
```

> [!IMPORTANT]
> Azure RBAC role assignments can take up to 10 minutes to propagate. If the agent pod shows `401` or `403` errors after installation, wait a few minutes and restart the pod.

### Step 6: Configure federated credentials

Link the managed identity to the Kubernetes service account used by the agent using the [`az identity federated-credential create`](/cli/azure/identity/federated-credential#az-identity-federated-credential-create) command.

```azurecli-interactive
export OIDC_ISSUER_URL=$(az aks show \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --query "oidcIssuerProfile.issuerUrl" -o tsv)

az identity federated-credential create \
    --name "container-networking-agent-k8s-fed-cred" \
    --identity-name $IDENTITY_NAME \
    --resource-group $RESOURCE_GROUP \
    --issuer $OIDC_ISSUER_URL \
    --subject "system:serviceaccount:kube-system:container-networking-agent-reader" \
    --audiences "api://AzureADTokenExchange"
```

Container Network Insights Agent uses [AKS workload identity](/azure/aks/workload-identity-overview) to authenticate to Azure OpenAI and other Azure services. At runtime, AKS automatically injects a federated token into the agent pod. The agent exchanges this token for a Microsoft Entra ID access token to call Azure OpenAI. This approach eliminates the need for secrets or connection strings in your cluster.

### Step 7: Create an App Registration for Entra ID authentication

Create an Entra ID App Registration so users can sign in to Container Network Insights Agent using Microsoft Entra ID (MSAL) with OAuth2/OIDC. This step is required for production deployments.

Container Network Insights Agent supports two methods for user sign-in:

| Method | Use case |
|--------|----------|
| Simple username login | Development and testing environments only. |
| Microsoft Entra ID (MSAL) | Production environments with OAuth2/OIDC through an App Registration (recommended). |

To enable Microsoft Entra ID user authentication in production, create an App Registration using the [`az ad app create`](/cli/azure/ad/app#az-ad-app-create) command.

```azurecli-interactive
export APP_DISPLAY_NAME="container-networking-agent-oauth2-user-auth-<your-alias>"
export APP_REDIRECT_URI="http://localhost:8080/auth/callback"  # For local/port-forward testing

# Optional: Required by some tenants - set your Service Tree ID if needed
# export SERVICE_MANAGEMENT_REFERENCE="<your-service-tree-id>"

# Create app registration with ID token and access token issuance
# NOTE: Ensure you have Owner or Contributor permissions on the app registration
#       you plan to use so you can add federated credentials later.
# If your tenant requires SERVICE_MANAGEMENT_REFERENCE, add: --service-management-reference $SERVICE_MANAGEMENT_REFERENCE
export APP_CLIENT_ID=$(az ad app create \
    --display-name $APP_DISPLAY_NAME \
    --web-redirect-uris $APP_REDIRECT_URI \
    --sign-in-audience AzureADMyOrg \
    --enable-id-token-issuance true \
    --enable-access-token-issuance true \
    --query "appId" -o tsv)

echo "App Registration Client ID (ENTRA_CLIENT_ID): $APP_CLIENT_ID"
```

If your tenant requires a Service Management Reference and the above command fails, use:

```azurecli-interactive
export APP_CLIENT_ID=$(az ad app create \
    --display-name $APP_DISPLAY_NAME \
    --web-redirect-uris $APP_REDIRECT_URI \
    --sign-in-audience AzureADMyOrg \
    --enable-id-token-issuance true \
    --enable-access-token-issuance true \
    --service-management-reference $SERVICE_MANAGEMENT_REFERENCE \
    --query "appId" -o tsv)
```

```azurecli-interactive
# Get tenant ID
export TENANT_ID=$(az account show --query tenantId -o tsv)
echo "Tenant ID: $TENANT_ID"
```

Add the required Microsoft Graph delegated permissions (`openid`, `profile`, `User.Read`, `offline_access`) using the [`az ad app permission add`](/cli/azure/ad/app/permission#az-ad-app-permission-add) command.

```azurecli-interactive
az ad app permission add \
    --id $APP_CLIENT_ID  \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions \
        e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope \
        14dad69e-099b-42c9-810b-d002981feec1=Scope \
        37f7f235-527c-4136-accd-4a02d197296e=Scope \
        7427e0e9-2fba-42fe-b0c0-848c9e6a8182=Scope

echo "App Registration Client ID: $APP_CLIENT_ID"
echo "Tenant ID: $TENANT_ID"
```

Create a federated credential on the App Registration to allow the agent pod to authenticate using workload identity. This is separate from the managed identity federated credential you created in Step 6. The [`az ad app federated-credential create`](/cli/azure/ad/app/federated-credential#az-ad-app-federated-credential-create) command links the app registration to the same Kubernetes service account.

> [!IMPORTANT]
> If you reuse an existing app registration across multiple AKS clusters, add a separate federated credential for each cluster because each cluster has a unique OIDC issuer URL.

```azurecli-interactive
# Ensure OIDC_ISSUER_URL is set (it was exported in Step 6; re-fetch if needed)
export OIDC_ISSUER_URL=$(az aks show \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --query "oidcIssuerProfile.issuerUrl" -o tsv)

az ad app federated-credential create \
    --id $APP_CLIENT_ID \
    --parameters "{
        \"name\": \"container-networking-agent-k8s-fed-cred\",
        \"issuer\": \"$OIDC_ISSUER_URL\",
        \"subject\": \"system:serviceaccount:kube-system:container-networking-agent-reader\",
        \"audiences\": [\"api://AzureADTokenExchange\"]
    }"

az ad app federated-credential list --id $APP_CLIENT_ID --query "[].{name:name, issuer:issuer}" -o table
```

### Step 8: Install the extension

Install the Container Network Insights Agent AKS extension using the [`az k8s-extension create`](/cli/azure/k8s-extension#az-k8s-extension-create) command. Use the command that matches your cluster configuration.

```azurecli-interactive
export TENANT_ID=$(az account show --query tenantId -o tsv)
export AZURE_OPENAI_DEPLOYMENT=$OPENAI_DEPLOYMENT_NAME
```

**For clusters with ACNS and Cilium dataplane:**

```azurecli-interactive
az k8s-extension create \
    --cluster-name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --cluster-type managedClusters \
    --name containernetworkingagent \
    --extension-type microsoft.containernetworkingagent  \
    --release-train stable \
    --auto-upgrade-minor-version false \
    --scope cluster \
    --configuration-settings config.AZURE_CLIENT_ID=$IDENTITY_CLIENT_ID \
    --configuration-settings config.AZURE_TENANT_ID=$TENANT_ID \
    --configuration-settings config.AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID \
    --configuration-settings config.AKS_CLUSTER_NAME=$CLUSTER_NAME \
    --configuration-settings config.AKS_RESOURCE_GROUP=$RESOURCE_GROUP \
    --configuration-settings config.ENTRA_TENANT_ID=$TENANT_ID \
    --configuration-settings config.ENTRA_CLIENT_ID=$APP_CLIENT_ID \
    --configuration-settings config.AZURE_OPENAI_DEPLOYMENT=$AZURE_OPENAI_DEPLOYMENT \
    --configuration-settings config.AZURE_OPENAI_API_VERSION=2025-03-01-preview \
    --configuration-settings config.AZURE_OPENAI_ENDPOINT=$AZURE_OPENAI_ENDPOINT \
    --configuration-settings config.AKS_MCP_ENABLED_COMPONENTS=kubectl \
    --configuration-settings config.DISABLE_TELEMETRY=false
```

**For clusters without ACNS (Hubble disabled):**

```azurecli-interactive
az k8s-extension create \
    --cluster-name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --cluster-type managedClusters \
    --name containernetworkingagent \
    --extension-type microsoft.containernetworkingagent \
    --scope cluster \
    --release-train stable \
    --configuration-settings config.AZURE_CLIENT_ID=$IDENTITY_CLIENT_ID \
    --configuration-settings config.AZURE_TENANT_ID=$TENANT_ID \
    --configuration-settings config.AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID \
    --configuration-settings config.AKS_CLUSTER_NAME=$CLUSTER_NAME \
    --configuration-settings config.AKS_RESOURCE_GROUP=$RESOURCE_GROUP \
    --configuration-settings config.ENTRA_TENANT_ID=$TENANT_ID \
    --configuration-settings config.ENTRA_CLIENT_ID=$APP_CLIENT_ID \
    --configuration-settings config.AZURE_OPENAI_DEPLOYMENT=$AZURE_OPENAI_DEPLOYMENT \
    --configuration-settings config.AZURE_OPENAI_API_VERSION=2025-03-01-preview \
    --configuration-settings config.AZURE_OPENAI_ENDPOINT=$AZURE_OPENAI_ENDPOINT \
    --configuration-settings hubble.enabled=false \
    --configuration-settings config.AKS_MCP_ENABLED_COMPONENTS=kubectl
```

### Verify extension state

Verify the extension state in Azure using the [`az k8s-extension show`](/cli/azure/k8s-extension#az-k8s-extension-show) command.

```azurecli-interactive
az k8s-extension show \
    --cluster-name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --cluster-type managedClusters \
    --name containernetworkingagent \
    --query "{provisioningState:provisioningState, version:version}" -o table
```

The `provisioningState` value should show `Succeeded` with a version number.

```azurecli-interactive
kubectl get serviceaccount container-networking-agent-reader -n kube-system -o yaml
```

The annotation `azure.workload.identity/client-id` should match your managed identity client ID.

## Use Container Network Insights Agent

After deployment and validation, access the agent through the web chat interface.

### Access the chat interface

1. Forward the service port:

   ```azurecli-interactive
   kubectl port-forward svc/container-networking-agent-service -n kube-system 8080:80
   ```

2. Open `http://localhost:8080` in your browser.
   - You should see the Container Network Insights Agent chat interface.
   - If you face an internal server error, check if federated credentials are correctly configured.

3. Sign in using either simple username login (development) or Microsoft Entra ID (production), depending on your configuration.

### Start a diagnostic conversation

Type a question or describe a networking problem in the chat input. The agent follows a structured diagnostic workflow:

1. **Classify**: Determines the issue category (DNS, connectivity, network policy, service routing, or packet drops).
1. **Collect evidence**: Runs the appropriate diagnostic commands against your cluster.
1. **Analyze**: Examines the collected evidence to identify anomalies and root causes.
1. **Report**: Returns a structured report with evidence tables, root cause analysis, and remediation commands.

### Sample prompts

| Scenario | Prompt |
|----------|--------|
| DNS failure | *"A pod in namespace `my-app` cannot resolve any DNS names"* |
| Packet drops | *"I see packet drops on node `aks-nodepool1-12345678-vmss000000`"* |
| Service unreachable | *"My client pod cannot connect to the backend-service in namespace `production`"* |
| Network policy blocking traffic | *"Pods in namespace `frontend` cannot communicate with the `backend` namespace"* |
| Cluster-wide DNS failure | *"All DNS is broken in the cluster"* |
| Proactive health check | *"Check network health on node `my-node`"* |

### Diagnostic workflows

- **DNS troubleshooting**: The agent checks CoreDNS pod health, service endpoints, and CoreDNS configuration (including custom ConfigMaps). It also checks NodeLocal DNS status, DNS resolution from multiple paths, and network policies that might block DNS traffic.
- **Packet drop analysis**: The agent deploys a lightweight debug DaemonSet to collect host-level network statistics. It examines NIC ring buffer utilization, kernel softnet statistics, per-CPU SoftIRQ distribution, socket buffer saturation, and network interface statistics. Delta measurements detect active drops versus historical counters.
- **Kubernetes networking diagnostics**: The agent examines pod status and scheduling, service configuration and endpoint registration, network policies (both Kubernetes and Cilium), Hubble flows, and service-to-pod port mapping.

### Diagnostic output

Each diagnostic response includes:

- A summary of the issue and its status.
- An evidence table showing each check, its result, and whether it passed or failed.
- Analysis of what's working and what's broken.
- Root cause identification with specific evidence citations.
- Exact commands to fix the issue and verify the fix.

### Session and conversation limits

| Limit | Default |
|-------|---------|
| Chat context window | ~15 exchanges |
| Messages per conversation | 100 |
| Conversations per user | 20 |
| Session idle timeout | 30 minutes |
| Session absolute timeout | 8 hours |

Start a new conversation for unrelated issues to keep context fresh.

## Cluster access and security

Container Network Insights Agent uses a dedicated service account (`container-networking-agent-reader`) with a read-only ClusterRole in the `kube-system` namespace. The RBAC configuration uses the principle of least privilege:

- **Read access** to core Kubernetes resources: Pods, Services, Nodes, Namespaces, ConfigMaps, Events, Deployments, ReplicaSets, DaemonSets, StatefulSets, Ingresses, NetworkPolicies, Endpoints, EndpointSlices, PersistentVolumes, and PersistentVolumeClaims.
- **Read access** to Cilium CRDs: CiliumNetworkPolicies, CiliumEndpoints, CiliumIdentities, CiliumLoadBalancerIPPools, CiliumL2AnnouncementPolicies, and other Cilium resources.
- **Read access** to metrics: Node and Pod metrics via metrics-server.
- **Limited exec access**: The agent uses `pods/exec` only for diagnostic commands (Cilium status and endpoint information).
- **No write access**: The agent can't create, update, or delete any cluster resource.

The agent pod makes outbound HTTPS calls to your Azure OpenAI endpoint. If you use egress restrictions (network policies, Azure Firewall, or NSGs), allow outbound traffic from the `kube-system` namespace to your Azure OpenAI endpoint on port 443.

For packet drop diagnostics, the agent deploys a lightweight debug DaemonSet (`rx-troubleshooting-debug`) in `kube-system` that requires `hostNetwork` and `NET_ADMIN` capabilities. This DaemonSet is shared across diagnostic sessions and cleaned up automatically.

The agent doesn't persist diagnostic data externally. The pod stores session data (chat history, agent assignments) in memory, and this data is lost if the pod restarts.

## Manage the extension

### Update the extension

Update the extension to a new version using the [`az k8s-extension update`](/cli/azure/k8s-extension#az-k8s-extension-update) command.

```azurecli-interactive
az k8s-extension update \
    --cluster-name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --cluster-type managedClusters \
    --name containernetworkingagent \
    --version <new-version>
```

### Uninstall the extension

Remove the extension using the [`az k8s-extension delete`](/cli/azure/k8s-extension#az-k8s-extension-delete) command.

```azurecli-interactive
az k8s-extension delete \
    --cluster-name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --cluster-type managedClusters \
    --name containernetworkingagent
```

## Troubleshoot

If you encounter issues deploying, configuring, or using Container Network Insights Agent, see [Troubleshoot Container Network Insights Agent on AKS](./troubleshoot-container-network-insights-agent.md) for detailed guidance on common problems including identity and permission errors, Azure OpenAI connectivity issues, extension installation failures, and more.

## Next steps

- [Troubleshoot Container Network Insights Agent on AKS](./troubleshoot-container-network-insights-agent.md)
- [Container Network Insights Agent overview](./container-network-insights-agent-overview.md)
- [Advanced Container Networking Services overview](/azure/aks/advanced-container-networking-services-overview)
- [Azure CNI powered by Cilium](/azure/aks/azure-cni-powered-by-cilium)
