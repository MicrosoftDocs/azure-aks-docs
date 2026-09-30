---
title: Deploy and configure Workload Identity on an AKS Hybrid and Edge cluster (preview)
description: Learn how to deploy and configure an AKS cluster with workload identity.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.reviewer: leslielin
ms.custom: hyperconverged

---

# Deploy and configure Workload Identity on an AKS Hybrid and Edge cluster (preview)

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

Workload identity federation allows you to configure a user-assigned managed identity or app registration in Microsoft Entra ID to trust tokens from an external identity provider (IdP), such as Kubernetes, enabling access to resources protected by Microsoft Entra, like Azure Key Vault or Azure Blob storage.

Azure Kubernetes Service (AKS) Hybrid and Edge is a managed Kubernetes service that lets you easily deploy workload identity enabled Kubernetes clusters. This article describes how to perform the following tasks:

- Create an AKS cluster with workload identity enabled (preview).
- Create a Kubernetes service account and bind it to the Azure Managed Identity.
- Create a federated credential on the managed identity to trust the OIDC issuer.
- Deploy your application.
- Example: Grant a pod in the cluster access to secrets in an Azure key vault.

For a conceptual overview of Workload identity federation, see [Workload identity federation in Azure Arc-enabled Kubernetes (preview)](/azure/azure-arc/kubernetes/conceptual-workload-identity).

> [!IMPORTANT]
> These preview features are available on a self-service, opt-in basis. Previews are provided "as is" and "as available," and they're excluded from the service-level agreements and limited warranty. Azure Kubernetes Service, Hybrid and Edge previews are partially covered by customer support on a best-effort basis.

> [!NOTE]
> In preview, AKS on Azure Local supports enabling workload identity during AKS cluster creation. However, enabling workload identity after cluster creation or disabling it afterward isn't currently supported.

## Prerequisites

Before you deploy a Kubernetes cluster with Azure Arc enabled, you must have the following prerequisites:

- If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn) before you begin.
- Version 1.4.23 or later of the Azure CLI. If you're using Azure Cloud Shell, the latest version is already installed.

### Export environment variables

To simplify the steps to configure the required identities, run the following commands to define environment variables. The examples in this article reference these variables. Replace the following values with your own values:

```azurecli
$AZSubscriptionID = "00000000-0000-0000-0000-000000000000" 
$Location = "westeurope" 
$resource_group_name = "myResourceGroup" 

$aks_cluster_name = "myAKSCluster" 

$SERVICE_ACCOUNT_NAMESPACE = "default" 
$SERVICE_ACCOUNT_NAME = "workload-identity-sa" 

$FedIdCredentialName = "myFedIdentity" 
$MSIName = "myIdentity" 

# To access key vault secrets from a pod in the cluster, include these variables:
$KVName = "KV-workload-id" 
$KVSecretName= "KV-secret"
```

### Set the active subscription

First, set your subscription as the current active subscription. Run the [az account set](/cli/azure/account#az-account-set) command with your subscription ID:

```azurecli
az login  
az account set -s $AZSubscriptionID
```

### Create a resource group

An [Azure resource group](/azure/azure-resource-manager/management/overview) is a logical group in which Azure resources are deployed and managed. When you create a resource group, you're prompted to specify a location. This location is the storage location of your resource group metadata and where your resources run in Azure if you don't specify another region during resource creation.

To create a resource group, run the [az group create](/cli/azure/group#az-group-create) command:

```azurecli
az group create --name $resource_group_name --location $Location
```

The following example output shows the successful creation of a resource group:

```json
{ 
  "id": "/subscriptions/<guid>/resourceGroups/myResourceGroup", 
  "location": "westeurope", 
  "managedBy": null, 
  "name": "$resource_group_name", 
  "properties": { 
    "provisioningState": "Succeeded" 
  }, 
  "tags": null 
}
```

## Step 1: Create an AKS cluster with workload identity enabled

To create an AKS cluster, you need both the `$customlocation_ID` and `$logicnet_Id` values.

- `$customlocation_ID`: The Azure Resource Manager ID of the custom location. The custom location is configured during the Azure Local cluster deployment. Your infrastructure admin should give you the Resource Manager ID of the custom location. You can also get the Resource Manager ID by running `$customlocation_ID = $(az customlocation show --name "<your-custom-location-name>" --resource-group $resource_group_name --query "id" -o tsv)`, if the infrastructure admin provides a custom location name and resource group name.
- `$logicnet_Id`: The Azure Resource Manager ID of the Azure Local logical network created [following these steps](/azure/aks/hybrid/aks-networks?tabs=azurecli). Your infrastructure admin should give you the Resource Manager ID of the logical network. You can also get the Resource Manager ID by running `$logicnet_Id = $(az stack-hci-vm network lnet show --name "<your-lnet-name>" --resource-group $resource_group_name --query "id" -o tsv)`, if the infrastructure admin provides a logical network name and resource group name.

Run the [az aksarc create](/cli/azure/aksarc#az-aksarc-create) command with the `--enable-oidc-issuer --enable-workload-identity` parameter. Provide your **entra-admin-group-object-ids** and ensure you're a member of the Microsoft Entra ID admin group for proxy mode access:

```azurecli
az aksarc create  
-n $aks_cluster_name -g $resource_group_name  
--custom-location $customlocation_ID --vnet-ids $logicnet_Id  
--aad-admin-group-object-ids <entra-admin-group-object-ids> 
--generate-ssh-keys  
--enable-oidc-issuer --enable-workload-identity
```

After a few minutes, the command completes and returns JSON-formatted information about the cluster.

It might take some time for the workload identity extension to be deployed after successfully creating a provisioned cluster. Use the following command to check the workload identity extension status:

```azurecli
az connectedk8s show -n $aks_cluster_name -g $resource_group_name
```

```json
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
    "issuerUrl": "https://oidcdiscovery-{location}-endpoint-1111111111111111.000.azurefd.net/00000000-0000-0000-0000-000000000000/11111111-1111-1111-1111-111111111111/"}
```

In the Azure portal, you can view the **wiextension** extension under the **Properties** section of your Kubernetes cluster.

> [!IMPORTANT]
> As part of the security enhancement for AKS clusters, workload identity enablement triggers two changes. First, the Kubernetes service account signing key automatically rotates every 45 days. Second, the `--service-account-extend-token-expiration` flag is disabled, reducing token validity from one year to a maximum of 24 hours.

### Save the OIDC issuer URL to an environment variable

After the AKS cluster is created successfully, you can get the OIDC issuer URL and save it to an environment variable. Run the following command:

```azurecli
$SERVICE_ACCOUNT_ISSUER =$(az connectedk8s show --n $aks_cluster_name --resource-group $resource_group_name --query "oidcIssuerProfile.issuerUrl" --output tsv)
```

## Step 2: Create a Kubernetes service account and bind it to the Azure Managed Identity

First, create a managed identity. Run the [az identity create](/cli/azure/identity#az-identity-create) command:

```azurecli
az identity create --name $MSIName --resource-group $resource_group_name --location $Location --subscription $AZSubscriptionID
```

Next, create variables for the managed identity's client ID:

```azurecli
$MSIId=$(az identity show --resource-group $resource_group_name --name $MSIName --query 'clientId' --output tsv)
$MSIPrincipalId=$(az identity show --resource-group $resource_group_name --name $MSIName --query 'principalId' --output tsv)
```

### Create a Kubernetes service account

In this step, you create a Kubernetes service account and annotate it with the client ID of the managed identity you created in the previous step.

Use cluster connect to access your cluster from a client device. For more information, see [Access your cluster from a client device](/azure/azure-arc/kubernetes/cluster-connect?tabs=azure-cli%2Cagent-version#access-your-cluster-from-a-client-device):

```azurecli
az connectedk8s proxy -n $aks_cluster_name -g $resource_group_name
```

Open a new CLI command window. Copy and paste the following commands:

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

$yaml = $yaml -replace '\$MSIId', $MSIId `
               -replace '\$SERVICE_ACCOUNT_NAME', $SERVICE_ACCOUNT_NAME `
               -replace '\$SERVICE_ACCOUNT_NAMESPACE', $SERVICE_ACCOUNT_NAMESPACE

$yaml | kubectl apply -f -
```

The following output shows successful creation of the service account:

```output
serviceaccount/workload-identity-sa created
```

## Step 3: Create a federated credential on the managed identity to trust the OIDC issuer

First, create a federated identity credential. Use the [az identity federated-credential create](/cli/azure/identity/federated-credential#az-identity-federated-credential-create) command
to create the federated identity credential between the managed identity, the service account issuer, and the subject. For more information about federated identity credentials in Microsoft Entra,
see [Overview of federated identity credentials in Microsoft Entra ID](/graph/api/resources/federatedidentitycredentials-overview).

```azurecli
# Create a federated credential 

az identity federated-credential create --name $FedIdCredentialName --identity-name $MSIName --resource-group $resource_group_name --issuer $SERVICE_ACCOUNT_ISSUER --subject "system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME}" 

# Show the federated credential 

az identity federated-credential show --name $FedIdCredentialName --resource-group $resource_group_name --identity-name $MSIName
```

> [!NOTE]
> After you add a federated identity credential, it takes a few seconds to propagate. Token requests made immediately afterward might fail until the cache refreshes. To prevent this issue, consider adding a brief delay after creating the federated identity credential.

## Step 4: Deploy your application

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

1. Create a key vault with purge protection and RBAC authorization enabled. You can also use an existing key vault if it's configured for both purge protection and RBAC authorization:

   ```azurecli
   az keyvault create --name $KVName --resource-group $resource_group_name --location $Location --enable-purge-protection --enable-rbac-authorization

   # retrieve the key vault ID for role assignment
   $KVId=$(az keyvault show --resource-group $resource_group_name --name $KVName --query id --output tsv)
   ```

1. Assign the RBAC [Key Vault Secrets Officer](/azure/role-based-access-control/built-in-roles/security#key-vault-secrets-officer) role to yourself so that you can create a secret in the new key vault. New role assignments can take up to five minutes to propagate and be updated by the authorization server.

   ```azurecli
   $CALLER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

   az role assignment create --assignee-object-id $CALLER_OBJECT_ID --role "Key Vault Secrets Officer" --scope $KVId --assignee-principal-type ServicePrincipal
   ```

1. Create a secret in the key vault:

   ```azurecli
   az keyvault secret set --vault-name $KVName --name $KVSecretName --value "Hello!"
   ```

1. Assign the [Key Vault Secrets User](/azure/role-based-access-control/built-in-roles/security#key-vault-secrets-user) role to the user-assigned managed identity that you created previously. This step gives the managed identity permission to read secrets from the key vault:

   ```azurecli
   $IDENTITY_PRINCIPAL_ID=$(az identity show --name "$USER_ASSIGNED_IDENTITY_NAME" --resource-group "$resource_group_name" --query principalId --output tsv)

   az role assignment create --assignee-object-id $IDENTITY_PRINCIPAL_ID --role "Key Vault Secrets User" --scope $KVId --assignee-principal-type ServicePrincipal
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
   $yaml | kubectl --kubeconfig <path-to-aks-cluster-kubeconfig> apply -f -
   ```

## Delete AKS cluster

To delete the AKS cluster, use the [az aksarc delete](/cli/azure/aksarc#az-aksarc-delete) command:

```azurecli
az aksarc delete -n $aks_cluster_name -g $resource_group_name
```

## Next steps

In this article, you deployed a Kubernetes cluster and configured it to use a workload identity in preparation for application workloads to
authenticate with that credential. Now you're ready to deploy your application and configure it to use the workload identity with the latest version of the [Azure Identity client library](/azure/active-directory/develop/reference-v2-libraries).

You can also help to protect your cluster in other ways by following the guidance in the [security book for AKS Hybrid and Edge](/azure/azure-arc/kubernetes/conceptual-security-book?toc=/azure/aks/aksarc/toc.json&bc=/azure/aks/aksarc/breadcrumb/toc.json).
