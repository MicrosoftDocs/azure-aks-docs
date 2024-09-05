---
title: 'Create the infrastructure for running a MongoDB cluster on Azure Kubernetes Service (AKS)'
description: Create the infrastructure needed to run a MongoDB cluster on AKS.
ms.topic: how-to
ms.date: 09/05/2024
author: fossygirl
ms.author: carols
ms.custom: aks-related-content
---

# Create the infrastructure for running a MongoDB cluster on Azure Kubernetes Service (AKS)

In this article, we create the infrastructure resources required to run a MongoDB cluster on Azure Kubernetes Service (AKS).

## Prerequisites

* If you haven't already, review the [Overview for deploying a MongoDB cluster on Azure Kubernetes Service (AKS)](./mongodb-overview.md).
* An Azure subscription. If you don't have one, create a [free account](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).
* Azure CLI version 2.61.0. To install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
* Helm version 3 or later. To install, see [Installing Helm](https://helm.sh/docs/intro/install/).
* `kubectl`, which Azure Cloud Shell installs by default.
* Docker installed on your local machine. To install, see [Get Docker](https://docs.docker.com/get-docker/).

## Set environment variables

Set the required environment variables for use throughout this guide:

```bash
random=$(echo $RANDOM | tr '[0-9]' '[a-z]')
export MY_LOCATION=australiaeast
export MY_RESOURCE_GROUP_NAME=myResourceGroup-rg-$(echo $MY_LOCATION)
export MY_ACR_REGISTRY=mydnsrandomname$(echo $random)
export MY_IDENTITY_NAME=ua-identity-123
export MY_KEYVAULT_NAME=vault-$(echo $random)-kv
export MY_CLUSTER_NAME=cluster-aks
export SERVICE_ACCOUNT_NAME=mongodb
export SERVICE_ACCOUNT_NAMESPACE=mongodb
export AKS_MONGODB_NAMESPACE=mongodb
export AKS_MONGODB_SECRETS_NAME=cluster-aks-mongodb-secrets
export AKS_MONGODB_CLUSTER_NAME=cluster-aks-mongodb
export AKS_MONGODB_SECRETS_ENCRYPTION_KEY=cluster-aks-mongodb-secrets-mongodb-encryption-key
export AKS_AZURE_SECRETS_NAME=cluster-aks-azure-secrets
export AKS_MONGODB_BACKUP_STORAGE_ACCOUNT_NAME=mongodbsa$(echo $random)
export AKS_MONGODB_BACKUP_STORAGE_CONTAINER_NAME=backups
```

## Create a resource group

* Create a resource group using the [`az group create`](/cli/azure/group#az-group-create) command.

    ```bash
    az group create --name $MY_RESOURCE_GROUP_NAME --location $MY_LOCATION --output table
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    Location       Name
    -------------  --------------------------------
    australiaeast  myResourceGroup-rg-australiaeast   
    ```
## Create an identity to access secrets in Azure Key Vault

In this step, we create a user-assigned managed identity that the External Secrets Operator uses to access the MongoDB passwords stored in Azure Key Vault.

* Create a user-assigned managed identity using the [`az identity create`](/cli/azure/identity#az-identity-create) command.

    ```bash
    az identity create --name $MY_IDENTITY_NAME --resource-group $MY_RESOURCE_GROUP_NAME --output table
    export MY_IDENTITY_NAME_ID=$(az identity show --name $MY_IDENTITY_NAME -g $MY_RESOURCE_GROUP_NAME --query id -o tsv)
    export MY_IDENTITY_NAME_PRINCIPAL_ID=$(az identity show --name $MY_IDENTITY_NAME -g $MY_RESOURCE_GROUP_NAME --query principalId -o tsv)
    export MY_IDENTITY_NAME_CLIENT_ID=$(az identity show --name $MY_IDENTITY_NAME -g $MY_RESOURCE_GROUP_NAME --query clientId -o tsv)
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    ClientId                              Location       Name             PrincipalId                           ResourceGroup                     TenantId
    ------------------------------------  -------------  ---------------  ------------------------------------  --------------------------------  ------------------------------------
    7708017b-dc75-4e65-84a6-f35c99ef5558  australiaeast  ua-identity-123  5b213098-1e45-4ed7-9a23-7fda7597f298  myResourceGroup-rg-australiaeast  07fa200c-6006-411f-bb29-a43bdf1a2bcc
    ```

## Create an Azure Key Vault instance

* Create an Azure Key Vault instance using the [`az keyvault create`](/cli/azure/keyvault#az-keyvault-create) command.

    ```bash
    az keyvault create --name $MY_KEYVAULT_NAME --resource-group $MY_RESOURCE_GROUP_NAME --location $MY_LOCATION --enable-rbac-authorization false --output table
    export KEYVAULTID=$(az keyvault show --name $MY_KEYVAULT_NAME --query "id" --output tsv)
    export KEYVAULTURL=$(az keyvault show --name $MY_KEYVAULT_NAME --query "properties.vaultUri" --output tsv)
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    Location       Name            ResourceGroup
    -------------  --------------  --------------------------------
    australiaeast  vault-cjcfc-kv  myResourceGroup-rg-australiaeast
    ```

## Create an Azure Container Registry

* Create an Azure Container Registry to store and manage your container images using the [`az acr create`](/cli/azure/acr#az-acr-create) command.

    ```bash
    az acr create \
    --name ${MY_ACR_REGISTRY} \
    --resource-group $MY_RESOURCE_GROUP_NAME \
    --sku Premium \
    --location $MY_LOCATION \
    --admin-enabled true \
    --output table
    export MY_ACR_REGISTRY_ID=$(az acr show --name $MY_ACR_REGISTRY --resource-group $MY_RESOURCE_GROUP_NAME --query id -o tsv)
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    NAME                  RESOURCE GROUP                    LOCATION       SKU      LOGIN SERVER                     CREATION DATE         ADMIN ENABLED
    --------------------  --------------------------------  -------------  -------  -------------------------------  --------------------  ---------------
    mydnsrandomnamecjcfc  myResourceGroup-rg-australiaeast  australiaeast  Premium  mydnsrandomnamecjcfc.azurecr.io  2024-07-01T12:18:34Z  True
    ```

## Create an Azure Storage Account

* Create an Azure Storage Account to store the MongoDB backups using the [`az acr create`](/cli/azure/storage/account#az-storage-account-create) command.

    ```bash
    az storage account create --name $AKS_MONGODB_BACKUP_STORAGE_ACCOUNT_NAME --resource-group $MY_RESOURCE_GROUP_NAME --location $MY_LOCATION --sku Standard_ZRS --output table
    az storage container create --name $AKS_MONGODB_BACKUP_STORAGE_CONTAINER_NAME --account-name $AKS_MONGODB_BACKUP_STORAGE_ACCOUNT_NAME --output table
    export AKS_MONGODB_BACKUP_STORAGE_ACCOUNT_KEY=$(az storage account keys list --account-name $AKS_MONGODB_BACKUP_STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name AZURE-STORAGE-ACCOUNT-KEY --value $AKS_MONGODB_BACKUP_STORAGE_ACCOUNT_KEY
    ```
    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    AccessTier    AllowBlobPublicAccess    AllowCrossTenantReplication    CreationTime                      EnableHttpsTrafficOnly    Kind       Location       MinimumTlsVersion    Name            PrimaryLocation    ProvisioningState    ResourceGroup
    StatusOfPrimary
    ------------  -----------------------  -----------------------------  --------------------------------  ------------------------  ---------  -------------  -------------------  --------------  -----------------  -------------------  --------------------------------  -----------------
    Hot           False                    False                          2024-08-09T07:06:41.727230+00:00  True                      StorageV2  australiaeast  TLS1_0               mongodbsabdibh  australiaeast      Succeeded            myResourceGroup-rg-australiaeast  available
    Created
    ---------
    True
    Name                       Value
    -------------------------  ----------------------------------------------------------------------------------------
    AZURE-STORAGE-ACCOUNT-KEY  xxx4tE3xxxxxxxxxxxxxxxxxxxxxxxxxxxx...
    ```

## Create an AKS cluster

In this step, we create an AKS cluster with workload identity and OIDC issuer enabled. The workload identity gives the External Secrets Operator service account permission to access the MongoDB passwords stored in your key vault.

1. Create an AKS cluster using the [`az aks create`](/cli/azure/aks#az-aks-create) command.

    ```bash
    az aks create \
    --location $MY_LOCATION \
    --name $MY_CLUSTER_NAME \
    --tier standard \
    --resource-group $MY_RESOURCE_GROUP_NAME \
    --network-plugin azure  \
    --node-vm-size Standard_DS4_v2 \
    --node-count 3 \
    --auto-upgrade-channel stable \
    --node-os-upgrade-channel NodeImage \
    --attach-acr ${MY_ACR_REGISTRY} \
    --enable-oidc-issuer \
    --enable-workload-identity \
    --zones 1 2 3 \
    --generate-ssh-keys \
    --output table
    ```

    Example output:
    <!-- expected_similarity=0.5 -->
    ```output
    AzurePortalFqdn                                                                 CurrentKubernetesVersion    DisableLocalAccounts    DnsPrefix                           EnableRbac    Fqdn                                                                     KubernetesVersion    Location       MaxAgentPools    Name         NodeResourceGroup                                              ProvisioningState    ResourceGroup                     ResourceUid               SupportPlan
    ------------------------------------------------------------------------------  --------------------------  ----------------------  ----------------------------------  ------------  -----------------------------------------------------------------------  -------------------  -------------  ---------------  -----------  -------------------------------------------------------------  -------------------  --------------------------------  ------------------------  ------------------
    cluster-ak-myresourcegroup--83a15f-46qdeqrv.portal.hcp.australiaeast.azmk8s.io  1.28.9                      False                   cluster-ak-myResourceGroup--83a15f  True          cluster-ak-myresourcegroup--83a15f-46qdeqrv.hcp.australiaeast.azmk8s.io  1.28                 australiaeast  100              cluster-aks  MC_myResourceGroup-rg-australiaeast_cluster-aks_australiaeast  Succeeded            myResourceGroup-rg-australiaeast  66829edfd7793f0001b5b2fd  KubernetesOfficial
    ```

2. Get the OIDC issuer URL to use for the workload identity configuration using the [`az aks show`](/cli/azure/aks#az-aks-show) command.

    ```bash
    export OIDC_URL=$(az aks show --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --query oidcIssuerProfile.issuerUrl -o tsv)
    ```

3. Assign the `AcrPull` role to the kubelet identity using the [`az role assignment create`](/cli/azure/role/assignment#az-role-assignment-create) command.

    ```bash
    export KUBELET_IDENTITY=$(az aks show -g $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME -o tsv --query identityProfile.kubeletidentity.objectId)
    az role assignment create \
    --assignee ${KUBELET_IDENTITY} \
    --role "AcrPull" \
    --scope ${MY_ACR_REGISTRY_ID} \
    --output table
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    CreatedBy                             CreatedOn                         Name                                  PrincipalId                           PrincipalName                         PrincipalType     ResourceGroup                     RoleDefinitionId                                                                                                                            RoleDefinitionName    Scope                                                                                                                                                                      UpdatedBy                             UpdatedOn
    ------------------------------------  --------------------------------  ------------------------------------  ------------------------------------  ------------------------------------  ----------------  --------------------------------  ------------------------------------------------------------------------------------------------------------------------------------------  --------------------  -------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ------------------------------------  --------------------------------
    d3a2023b-03fe-41bb-8b6f-08fb78ac4da6  2024-07-01T12:23:20.749750+00:00  8247e9bb-bc6b-414f-98a6-4768dbb961ad  9686a88e-25bc-4b4c-b611-d1057a26acdc  0b40421c-343b-4986-b691-980d6154429e  ServicePrincipal  myResourceGroup-rg-australiaeast  /subscriptions/83a15f8c-a05a-4cf3-b4bb-f6bcd6dbbfa9/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d  AcrPull               /subscriptions/83a15f8c-a05a-4cf3-b4bb-f6bcd6dbbfa9/resourceGroups/myResourceGroup-rg-australiaeast/providers/Microsoft.ContainerRegistry/registries/mydnsrandomnamecjcfc  d3a2023b-03fe-41bb-8b6f-08fb78ac4da6  2024-07-01T12:23:20.749750+00:00
    ```
## Connect to the AKS cluster

* Configure `kubectl` to connect to your AKS cluster using the [`az aks get-credentials`](/cli/azure/aks#az-aks-get-credentials) command.

    ```bash
    az aks get-credentials --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --overwrite-existing --output table
    ```

## Upload Percona images to your Azure Container Registry

In this section, we download the Percona images from Dockerhub and upload it to Azure Container Registry. This step ensures that the image is available in your private registry and can be used in your AKS cluster. We don't recommend consuming the public image in a production environment.

* Import the Percona images from Dockerhub and upload it to your Azure Container Registry using the [`az acr import`](/cli/azure/acr#az-acr-import) command.
    ```bash
    az acr import \
        --name $MY_ACR_REGISTRY \
        --source docker.io/percona/percona-server-mongodb:7.0.8-5  \
        --image percona-server-mongodb:7.0.8-5

    az acr import \
        --name $MY_ACR_REGISTRY \
        --source docker.io/percona/pmm-client:2.41.2  \
        --image pmm-client:2.41.2

    az acr import \
        --name $MY_ACR_REGISTRY \
        --source docker.io/percona/percona-backup-mongodb:2.4.1  \
        --image percona-backup-mongodb:2.4.1

    az acr import \
        --name $MY_ACR_REGISTRY \
        --source docker.io/percona/percona-server-mongodb-operator:1.16.1  \
        --image percona-server-mongodb-operator:1.16.1
    ```

## Next steps

> [!div class="nextstepaction"]
> [Configure and deploy the MongoDB cluster on AKS](./deploy-mongodb-cluster.md)
