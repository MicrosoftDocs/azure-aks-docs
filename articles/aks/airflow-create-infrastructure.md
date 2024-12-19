---
title: Create the infrastructure for deploying Apache Airflow on Azure Kubernetes Service (AKS)
description: In this article, you create the infrastructure needed to deploy Apache Airflow on Azure Kubernetes Service (AKS) using Helm.
ms.topic: how-to
ms.custom: azure-kubernetes-service
ms.date: 12/19/2024
author: schaffererin
ms.author: schaffererin
---

# Create the infrastructure for running Apache Airflow on Azure Kubernetes Service (AKS)

In this article, you create the infrastructure required to run Apache Airflow on Azure Kubernetes Service (AKS).

## Prerequisites

* If you haven't already, review the [Overview for deploying an Apache Airflow cluster on Azure Kubernetes Service (AKS)](./airflow-overview.md).
* An Azure subscription. If you don't have one, create a [free account](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).
* Azure CLI version 2.61.0. To install or upgrade, see [Install Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli).
* Helm version 3 or later. To install, see [Installing Helm](https://helm.sh/docs/intro/install/).
* `kubectl`, which is installed in Azure Cloud Shell by default.
* GitHub Repo to store Airflow Dags.
* Docker installed on your local machine. To install, see [Get Docker](https://docs.docker.com/get-docker/).

## Set environment variables

* Set the required environment variables for use throughout this guide:

    ```bash
    random=$(echo $RANDOM | tr '[0-9]' '[a-z]')
    export MY_LOCATION=canadacentral
    export MY_RESOURCE_GROUP_NAME=apache-airflow-rg
    export MY_IDENTITY_NAME=airflow-identity-123
    export MY_ACR_REGISTRY=mydnsrandomname$(echo $random)
    export MY_KEYVAULT_NAME=airflow-vault-$(echo $random)-kv
    export MY_CLUSTER_NAME=apache-airflow-aks
    export SERVICE_ACCOUNT_NAME=airflow
    export SERVICE_ACCOUNT_NAMESPACE=airflow
    export AKS_AIRFLOW_NAMESPACE=airflow
    export AKS_AIRFLOW_CLUSTER_NAME=cluster-aks-airflow
    export AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_NAME=airflowsasa$(echo $random)
    export AKS_AIRFLOW_LOGS_STORAGE_CONTAINER_NAME=airflow-logs
    export AKS_AIRFLOW_LOGS_STORAGE_SECRET_NAME=storage-account-credentials
    ```

## Create a resource group

* Create a resource group using the [`az group create`](/cli/azure/group#az-group-create) command.

    ```azurecli-interactive
    az group create --name $MY_RESOURCE_GROUP_NAME --location $MY_LOCATION --output table
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    Location       Name
    -------------  -----------------
    $MY_LOCATION   $MY_RESOURCE_GROUP_NAME
    ```

## Create an identity to access secrets in Azure Key Vault

In this step, we create a user-assigned managed identity that the External Secrets Operator uses to access the Airflow passwords stored in Azure Key Vault.

* Create a user-assigned managed identity using the [`az identity create`](/cli/azure/identity#az-identity-create) command.

    ```azurecli-interactive
    az identity create --name $MY_IDENTITY_NAME --resource-group $MY_RESOURCE_GROUP_NAME --output table
    export MY_IDENTITY_NAME_ID=$(az identity show --name $MY_IDENTITY_NAME --resource-group $MY_RESOURCE_GROUP_NAME --query id --output tsv)
    export MY_IDENTITY_NAME_PRINCIPAL_ID=$(az identity show --name $MY_IDENTITY_NAME --resource-group $MY_RESOURCE_GROUP_NAME --query principalId --output tsv)
    export MY_IDENTITY_NAME_CLIENT_ID=$(az identity show --name $MY_IDENTITY_NAME --resource-group $MY_RESOURCE_GROUP_NAME --query clientId --output tsv)
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    ClientId                              Location       Name                  PrincipalId                           ResourceGroup            TenantId
    ------------------------------------  -------------  --------------------  ------------------------------------  -----------------------  ------------------------------------  
    00001111-aaaa-2222-bbbb-3333cccc4444  $MY_LOCATION   $MY_IDENTITY_NAME     aaaaaaaa-bbbb-cccc-1111-222222222222  $MY_RESOURCE_GROUP_NAME  aaaabbbb-0000-cccc-1111-dddd2222eeee 
    ```

## Create an Azure Key Vault instance

* Create an Azure Key Vault instance using the [`az keyvault create`](/cli/azure/keyvault#az-keyvault-create) command.

    ```azurecli-interactive
    az keyvault create --name $MY_KEYVAULT_NAME --resource-group $MY_RESOURCE_GROUP_NAME --location $MY_LOCATION --enable-rbac-authorization false --output table
    export KEYVAULTID=$(az keyvault show --name $MY_KEYVAULT_NAME --query "id" --output tsv)
    export KEYVAULTURL=$(az keyvault show --name $MY_KEYVAULT_NAME --query "properties.vaultUri" --output tsv)
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    Location       Name                  ResourceGroup
    -------------  --------------------  ----------------------
    $MY_LOCATION   $MY_KEYVAULT_NAME     $MY_RESOURCE_GROUP_NAME
    ```

## Create an Azure Container Registry

* Create an Azure Container Registry to store and manage your container images using the [`az acr create`](/cli/azure/acr#az-acr-create) command.

    ```azurecli-interactive
    az acr create \
    --name ${MY_ACR_REGISTRY} \
    --resource-group $MY_RESOURCE_GROUP_NAME \
    --sku Premium \
    --location $MY_LOCATION \
    --admin-enabled true \
    --output table
    export MY_ACR_REGISTRY_ID=$(az acr show --name $MY_ACR_REGISTRY --resource-group $MY_RESOURCE_GROUP_NAME --query id --output tsv)
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    NAME                  RESOURCE GROUP           LOCATION       SKU      LOGIN SERVER                     CREATION DATE         ADMIN ENABLED
    --------------------  ----------------------   -------------  -------  -------------------------------  --------------------  ---------------
    mydnsrandomnamebfbje  $MY_RESOURCE_GROUP_NAME  $MY_LOCATION   Premium  mydnsrandomnamebfbje.azurecr.io  2024-11-07T00:32:48Z  True
    ```

## Create an Azure storage account

* Create an Azure Storage Account to store the Airflow logs using the [`az acr create`](/cli/azure/storage/account#az-storage-account-create) command.

    ```azurecli-interactive
    az storage account create --name $AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_NAME --resource-group $MY_RESOURCE_GROUP_NAME --location $MY_LOCATION --sku Standard_ZRS --output table
    export AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_KEY=$(az storage account keys list --account-name $AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)
    az storage container create --name $AKS_AIRFLOW_LOGS_STORAGE_CONTAINER_NAME --account-name $AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_NAME --output table --account-key $AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_KEY
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name AKS-AIRFLOW-LOGS-STORAGE-ACCOUNT-NAME --value $AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_NAME
    az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name AKS-AIRFLOW-LOGS-STORAGE-ACCOUNT-KEY --value $AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_KEY
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    AccessTier    AllowBlobPublicAccess    AllowCrossTenantReplication    CreationTime                      EnableHttpsTrafficOnly    Kind       Location       MinimumTlsVersion    Name              PrimaryLocation    ProvisioningState    ResourceGroup      StatusOfPrimary
    ------------  -----------------------  -----------------------------  --------------------------------  ------------------------  ---------  -------------  -------------------  ----------------  -----------------  -------------------  -----------------  -----------------
    Hot           False                    False                          2024-11-07T00:22:13.323104+00:00  True                      StorageV2  $MY_LOCATION   TLS1_0               airflowsasabfbje  $MY_LOCATION       Succeeded            $MY_RESOURCE_GROUP_NAME  available
    Created
    ---------
    True
    ```

## Create an AKS cluster

In this step, we create an AKS cluster with workload identity and OIDC issuer enabled. The workload identity gives the External Secrets Operator service account permission to access the Airflow passwords stored in your key vault.

1. Create an AKS cluster using the [`az aks create`](/cli/azure/aks#az-aks-create) command.

    ```azurecli-interactive
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
    --enable-blob-driver \
    --enable-workload-identity \
    --zones 1 2 3 \
    --generate-ssh-keys \
    --output table
    ```

    Example output:
    <!-- expected_similarity=0.5 -->
    ```output
    AzurePortalFqdn                                                                 CurrentKubernetesVersion    DisableLocalAccounts    DnsPrefix                           EnableRbac    Fqdn                                                                     KubernetesVersion    Location       MaxAgentPools    Name                NodeResourceGroup                                      ProvisioningState    ResourceGroup            ResourceUid                           SupportPlan
    ------------------------------------------------------------------------------  --------------------------  ----------------------  ----------------------------------  ------------  -----------------------------------------------------------------------  -------------------  -------------  ---------------  ------------------  -----------------------------------------------------  -------------------  -----------------------  ------------------------------------  ------------------
    apache-air-apache-airflow-r-363a0a-rhf6saad.portal.hcp.$MY_LOCATION.azmk8s.io   1.29.9                      False                   apache-air-apache-airflow-r-363a0a  True          apache-air-apache-airflow-r-363a0a-rhf6saad.hcp.$MY_LOCATION.azmk8s.io   1.29                 $MY_LOCATION   100              $MY_CLUSTER_NAME    MC_apache-airflow-rg_apache-airflow-aks_$MY_LOCATION   Succeeded            $MY_RESOURCE_GROUP_NAME  b1b1b1b1-cccc-dddd-eeee-f2f2f2f2f2f2  KubernetesOfficial
    ```

2. Get the OIDC issuer URL to use for the workload identity configuration using the [`az aks show`](/cli/azure/aks#az-aks-show) command.

    ```azurecli-interactive
    export OIDC_URL=$(az aks show --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --query oidcIssuerProfile.issuerUrl --output tsv)
    ```

3. Assign the `AcrPull` role to the kubelet identity using the [`az role assignment create`](/cli/azure/role/assignment#az-role-assignment-create) command.

    ```azurecli-interactive
    export KUBELET_IDENTITY=$(az aks show -g $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --output tsv --query identityProfile.kubeletidentity.objectId)
    az role assignment create \
    --assignee ${KUBELET_IDENTITY} \
    --role "AcrPull" \
    --scope ${MY_ACR_REGISTRY_ID} \
    --output table
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    CreatedBy                             CreatedOn                         Name                                  PrincipalId                           PrincipalName                         PrincipalType     ResourceGroup            RoleDefinitionId                                                                                                                            RoleDefinitionName    Scope                                                                                                                                                             UpdatedBy                             UpdatedOn
    ------------------------------------  --------------------------------  ------------------------------------  ------------------------------------  ------------------------------------  ----------------  -----------------------  ------------------------------------------------------------------------------------------------------------------------------------------  --------------------  ----------------------------------------------------------------------------------------------------------------------------------------------------------        ------------------------------------  --------------------------------
    ccccdddd-2222-eeee-3333-ffff4444aaaa  2024-11-07T00:43:26.905445+00:00  b1b1b1b1-cccc-dddd-eeee-f2f2f2f2f2f2  bbbbbbbb-cccc-dddd-2222-333333333333  cccccccc-dddd-eeee-3333-444444444444  ServicePrincipal  $MY_RESOURCE_GROUP_NAME  /subscriptions/363a0ad2-8957-48ed-a901-eca3908b32b8/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d  AcrPull               /subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e/resourceGroups/$MY_RESOURCE_GROUP_NAME/providers/Microsoft.ContainerRegistry/registries/mydnsrandomnamebfbje  ccccdddd-2222-eeee-3333-ffff4444aaaa  2024-11-07T00:43:26.905445+00:00
    ```

## Connect to the AKS cluster

* Configure `kubectl` to connect to your AKS cluster using the [`az aks get-credentials`](/cli/azure/aks#az-aks-get-credentials) command.

    ```azurecli-interactive
    az aks get-credentials --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --overwrite-existing --output table
    ```

## Upload Apache Airflow images to your container registry

In this section, we download the Apache Airflow images from Docker Hub and upload them to Azure Container Registry. This step ensures that the images are available in your private registry and can be used in your AKS cluster. We don't recommend consuming the public image in a production environment.

* Import the Airflow images from Docker Hub and upload them to your container registry using the [`az acr import`](/cli/azure/acr#az-acr-import) command.

    ```azurecli-interactive
    az acr import --name $MY_ACR_REGISTRY --source docker.io/apache/airflow:airflow-pgbouncer-2024.01.19-1.21.0 --image airflow:airflow-pgbouncer-2024.01.19-1.21.0
    az acr import --name $MY_ACR_REGISTRY --source docker.io/apache/airflow:airflow-pgbouncer-exporter-2024.06.18-0.17.0 --image airflow:airflow-pgbouncer-exporter-2024.06.18-0.17.0
    az acr import --name $MY_ACR_REGISTRY --source docker.io/bitnami/postgresql:16.1.0-debian-11-r15 --image postgresql:16.1.0-debian-11-r15
    az acr import --name $MY_ACR_REGISTRY --source quay.io/prometheus/statsd-exporter:v0.26.1 --image statsd-exporter:v0.26.1 
    az acr import --name $MY_ACR_REGISTRY --source docker.io/apache/airflow:2.9.3 --image airflow:2.9.3 
    az acr import --name $MY_ACR_REGISTRY --source registry.k8s.io/git-sync/git-sync:v4.1.0 --image git-sync:v4.1.0
    ```

## Next step

> [!div class="nextstepaction"]
> [Deploy Apache Airflow on Azure Kubernetes Service (AKS)](./airflow-deploy.md)

## Contributors

*Microsoft maintains this article. The following contributors originally wrote it:*

* Don High | Principal Customer Engineer
* Satya Chandragiri | Senior Digital Cloud Solution Architect
* Erin Schaffer | Content Developer 2
