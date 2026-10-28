---
title: Configure Workload Identity on an AKS Edge Essentials cluster (preview)
description: Learn how to configure an AKS Edge Essentials cluster with workload identity.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.reviewer: leslielin
ms.custom: edge-essentials

---

# Configure Workload Identity on an AKS Edge Essentials cluster (preview)

Azure Kubernetes Service (AKS) Edge Essentials is an on-premises Kubernetes implementation of Azure Kubernetes Service (AKS) that automates running containerized applications at scale. This article describes how to perform the following tasks:

- Create a Kubernetes service account and bind it to the Azure Managed Identity.
- Create a federated credential on the managed identity to trust the OIDC issuer.
- Deploy your application.
- Example: Grant a pod in the cluster access to secrets in an Azure key vault.

For a conceptual overview of Workload identity federation, see [Workload identity federation in Azure Arc-enabled Kubernetes (preview)](/azure/azure-arc/kubernetes/conceptual-workload-identity).

> [!IMPORTANT]
> These preview features are available on a self-service, opt-in basis. Previews are provided "as is" and "as available," and they're excluded from the service-level agreements and limited warranty. Azure Kubernetes Service Edge Essentials previews are partially covered by customer support on a best-effort basis.

> [!NOTE]
> In this public preview, AKS Edge Essentials allows you to enable workload identity during the initial deployment of the Azure IoT Operations   quickstart script. This feature is not available for other AKS Edge Essentials scenarios.

## Prerequisites

Before using workload identity federation for an AKS Edge Essentials cluster, you must deploy the Azure IoT Operation quickstart script as described in [Create and configure an AKS Edge Essentials cluster that can run Azure IoT Operations](aks-edge-howto-deploy-azure-iot.md). The script automatically enables the workload identity federation feature on the AKS Edge Essentials cluster.

After you deploy the AKS Edge Essentials cluster, you can use the following command to check the status of the workload identity extension:

```azurecli
az connectedk8s show -n $aks_cluster_name -g $resource_group_name
```

```output
# agentState = "Succeeded" 
"agentPublicKeyCertificate": "", 
  "agentVersion": "1.21.10", 
  "arcAgentProfile": { 
    "agentAutoUpgrade": "Enabled", 
    "agentErrors": [], 
    "agentState": "Succeeded", 
    "desiredAgentVersion": "", 
    "systemComponents": null 

# oidcIssuerProfile "enabled": true and "issuerUrl" present 
"oidcIssuerProfile": { 
    "enabled": true, 
    "issuerUrl": "https://oidcdiscovery-{location}-endpoint-1111111111111111.000.azurefd.net/00000000-0000-0000-0000-000000000000/11111111-1111-1111-1111-111111111111/", 

# workloadIdentity "enabled": true 
"securityProfile": { 
    "workloadIdentity": { 
      "enabled": true
```

In the Azure portal, you can view the `wiextension` extension under the **Properties** section of your Kubernetes cluster.

### Export environment variables

To help simplify the steps to configure the required identities, the following steps define environment variables that are referenced in the examples in this article. Remember to replace the values shown with your own values:

```azurecli
$AZSubscriptionID = "00000000-0000-0000-0000-000000000000" 
$Location = "westeurope" 
$resource_group_name = "myResourceGroup" 

$aks_cluster_name = "myAKSCluster" 

$SERVICE_ACCOUNT_NAMESPACE = "default" 
$SERVICE_ACCOUNT_NAME = "workload-identity-sa" 

$FedIdCredentialName = "myFedIdentity" 
$MSIName = "myIdentity" 

# Include these variables to access key vault secrets from a pod in the cluster. 
$KVName = "KV-workload-id" 
$KVSecretName= "KV-secret"
```

### Save the OIDC issuer URL to an environment variable

To get the OIDC issuer URL and save it to an environment variable, run the following command:

```azurecli
$SERVICE_ACCOUNT_ISSUER =$(az connectedk8s show --n $aks_cluster_name --resource-group $resource_group_name --query "oidcIssuerProfile.issuerUrl" --output tsv)
```

## Step 1: Create a Kubernetes service account and bind it to the Azure Managed Identity

First, call the [az identity create](/cli/azure/identity#az-identity-create) command to create a managed identity:

```azurecli
az identity create --name $MSIName --resource-group $resource_group_name --location $Location --subscription $AZSubscriptionID
```

Next, create variables for the managed identity's client ID:

```azurecli
$MSIId=$(az identity show --resource-group $resource_group_name --name $MSIName --query 'clientId' --output tsv)  
$MSIPrincipalId=$(az identity show --resource-group $resource_group_name --name $MSIName --query 'principalId' --output tsv)
```

### Create a Kubernetes service account

Create a Kubernetes service account and annotate it with the client ID of the managed identity you created in the previous step. Copy and paste the following Azure CLI commands:

```azurecli
$yaml = @" 
apiVersion: v1 
kind: ServiceAccount 
metadata: 
  annotations: 
    azure.workload.identity/client-id: $MSIId 
  name: $SERVICE_ACCOUNT_NAME 
  namespace: $SERVICE_ACCOUNT_NAMESPACE 
"@ 

# Replace variables within the YAML content 
$yaml = $yaml -replace '\$MSIId', $MSIId ` 
              -replace '\$SERVICE_ACCOUNT_NAME', $SERVICE_ACCOUNT_NAME ` 
              -replace '\$SERVICE_ACCOUNT_NAMESPACE', $SERVICE_ACCOUNT_NAMESPACE 

# Apply the YAML content to Kubernetes 
$yaml | kubectl apply -f -
```

The following output shows the workload identity created successfully:

```output
serviceaccount/workload-identity-sa created
```

## Step 2: Create a federated credential on the managed identity to trust the OIDC issuer

To create the federated identity credential between the managed identity, the service account issuer, and the subject, call the [az identity federated-credential create](/cli/azure/identity/federated-credential#az-identity-federated-credential-create) command. For more information about federated identity credentials in Microsoft Entra, see [Overview of federated identity credentials in Microsoft Entra ID](/cli/azure/identity/federated-credential#az-identity-federated-credential-create).

```azurecli
# Create a federated credential 
az identity federated-credential create --name $FedIdCredentialName --identity-name $MSIName --resource-group $resource_group_name --issuer $SERVICE_ACCOUNT_ISSUER --subject "system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME}" 

# Show the federated credential 
az identity federated-credential show --name $FedIdCredentialName --resource-group $resource_group_name --identity-name $MSIName
```

> [!NOTE]
> After you add a federated identity credential, it takes a few seconds to propagate. Token requests made immediately afterward might fail until the cache refreshes. To prevent this issue, consider adding a brief delay after creating the federated identity credential.

## Step 3: Deploy your application

When you deploy your application pods, the manifest should reference the service account created in the **Create Kubernetes service account** step. The following manifest shows how to reference the account, specifically the `metadata\namespace` and `spec\serviceAccountName` properties. Make sure to specify an image for `image` and a container name
for `containerName`:

```azurecli
$image = "<image>"  # Replace <image> with the actual image name 
$containerName = "<containerName>"  # Replace <containerName> with the actual container name 

$yaml = @" 
apiVersion: v1 
kind: Pod 
metadata: 
  name: sample-quick-start 
  namespace: $SERVICE_ACCOUNT_NAMESPACE 
  labels: 
    azure.workload.identity/use: "true" # Required. Only pods with this label can use workload identity. 
spec: 
  serviceAccountName: $SERVICE_ACCOUNT_NAME 
  containers: 
    - image: $image 
      name: $containerName 
"@ 

# Replace variables within the YAML content 
$yaml = $yaml -replace '\$SERVICE_ACCOUNT_NAMESPACE', $SERVICE_ACCOUNT_NAMESPACE ` 
                -replace '\$SERVICE_ACCOUNT_NAME', $SERVICE_ACCOUNT_NAME 

# Apply the YAML configuration 
$yaml | kubectl apply -f - 
```

> [!IMPORTANT]
> Ensure that the application pods using workload identity include the label `azure.workload.identity/use: "true"` in the pod spec. Otherwise the pods fail after they restart.

## Example: Grant permissions to access Azure Key Vault

The instructions in this step describe how to access secrets, keys, or certificates in an Azure key vault from the pod. The examples in this section configure access to secrets in the key vault for the workload identity, but you can perform similar steps to configure access to keys or certificates.

The following example shows how to use the Azure role-based access control (Azure RBAC) permission model to grant the pod access to the key vault. For more information about the Azure RBAC permission model for Azure Key Vault, see [Grant permission to applications to access an Azure key vault using Azure RBAC](/azure/key-vault/general/rbac-guide).

1. Create a key vault with purge protection and RBAC authorization enabled. You can also use an existing key vault if it is configured for both purge protection and RBAC authorization:

   ```azurecli
   az keyvault create --name $KVName --resource-group $resource_group_name --location $Location --enable-purge-protection --enable-rbac-authorization

   # retrieve the key vault ID for role assignment
   $KVId=$(az keyvault show --resource-group $resource_group_name --name $KVName --query id --output tsv)
   ```

1. Assign the RBAC [Key Vault Secrets Officer](/azure/role-based-access-control/built-in-roles/security#key-vault-secrets-officer) role to yourself so that you can create a secret in the new key vault. New role assignments can take up to five minutes to propagate and be updated by the authorization server.

   ```azurecli
   az role assignment create --assignee-object-id $MSIPrincipalId --role "Key Vault Secrets Officer" --scope $KVId --assignee-principal-type ServicePrincipal
   ```

1. Create a secret in the key vault:

   ```azurecli
   az keyvault secret set --vault-name $KVName --name $KVSecretName --value "Hello!"
   ```

1. Assign the [Key Vault Secrets User](/azure/role-based-access-control/built-in-roles/security#key-vault-secrets-user) role to the user-assigned managed identity that you created previously. This step gives the managed identity permission to read secrets from the key vault:

   ```azurecli
   az role assignment create --assignee-object-id $MSIPrincipalId --role "Key Vault Secrets User" --scope $KVId --assignee-principal-type ServicePrincipal
   ```

1. Create an environment variable for the key vault URL:

   ```azurecli
   $KVUrl=$(az keyvault show --resource-group $resource_group_name --name $KVName --query properties.vaultUri --output tsv)
   ```

1. Deploy a pod that references the service account and key vault URL:

   ```azurecli
   $yaml = @" 
   apiVersion: v1 
   kind: Pod
   metadata:
     name: sample-quick-start
     namespace: $SERVICE_ACCOUNT_NAMESPACE
     labels:
       azure.workload.identity/use: "true"
   spec:
     serviceAccountName: $SERVICE_ACCOUNT_NAME 
     containers:
       - image: ghcr.io/azure/azure-workload-identity/msal-go 
         name: oidc 
         env: 
         - name: KEYVAULT_URL 
           value: $KVUrl 
         - name: SECRET_NAME 
           value: $KVSecretName 
     nodeSelector:
       kubernetes.io/os: linux
   "@

   # Replace variables within the YAML content 
   $yaml = $yaml -replace '\$SERVICE_ACCOUNT_NAMESPACE', $SERVICE_ACCOUNT_NAMESPACE ` 
                   -replace '\$SERVICE_ACCOUNT_NAME', $SERVICE_ACCOUNT_NAME ` 
                   -replace '\$KVUrl', $KVUrl ` 
                   -replace '\$KVSecretName', $KVSecretName 

   # Apply the YAML configuration
   $yaml | kubectl --kubeconfig $aks_cluster_name apply -f -
   ```

## Next steps

This article described how to configure a workload identity in preparation for application workloads to authenticate with that credential. Now you're ready to deploy your application and configure it to use the workload identity with the latest version of the [Azure Identity client library](/azure/active-directory/develop/reference-v2-libraries).
