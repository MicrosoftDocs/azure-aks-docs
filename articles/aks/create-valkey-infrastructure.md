---
title: Create the infrastructure for running a Valkey cluster on Azure Kubernetes Service (AKS)
description: In this article, you create the infrastructure for running a Valkey cluster on Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.custom: azure-kubernetes-service
ms.date: 08/15/2024
author: schaffererin
ms.author: schaffererin
---

# Create the infrastructure for running a Valkey cluster on Azure Kubernetes Service (AKS)

In this article, we create the infrastructure resources required to run a Valkey cluster on Azure Kubernetes Service (AKS).

## Prerequisites

* If you haven't already, review the [Overview for deploying a Valkey cluster on Azure Kubernetes Service (AKS)][valkey-solution-overview].
* An Azure subscription. If you don't have one, create a [free account][azure-free-account].
* Azure CLI version 2.61.0. To install or upgrade, see [Install Azure CLI][install-azure-cli].
* Helm version 3 or later. To install, see [Installing Helm][install-helm].
* `kubectl`, which the Azure Cloud Shell has installed by default.
* Docker installed on your local machine. To install, see [Get Docker][install-docker].

## Set environment variables

* Set the required environment variables for use throughout this guide:

    ```bash
    random=$(echo $RANDOM | tr '[0-9]' '[a-z]')
    export MY_RESOURCE_GROUP_NAME=myResourceGroup-rg
    export MY_LOCATION=eastus
    export MY_ACR_REGISTRY=mydnsrandomname$(echo $random)
    export MY_KEYVAULT_NAME=vault-$(echo $random)-kv
    export MY_CLUSTER_NAME=cluster-aks
    export SERVICE_ACCOUNT_NAME=valkey
    export SERVICE_ACCOUNT_NAMESPACE=valkey
    export TENANT_ID=$(az account show --query tenantId --output tsv)
    ```

## Create a resource group

* Create a resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --name $MY_RESOURCE_GROUP_NAME --location $MY_LOCATION --output table
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    Location    Name
    ----------  ------------------
    eastus      myResourceGroup-rg
    ```

## Create an Azure Key Vault instance

* Create an Azure Key Vault instance using the [`az keyvault create`][az-keyvault-create]command.

    ```azurecli-interactive
    az keyvault create --name $MY_KEYVAULT_NAME --resource-group $MY_RESOURCE_GROUP_NAME --location $MY_LOCATION --enable-rbac-authorization false --output table
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    Location    Name            ResourceGroup
    ----------  --------------  ------------------
    eastus      vault-bbbhe-kv  myResourceGroup-rg
    ```

## Create an Azure Container Registry

* Create an Azure Container Registry to store and manage your container images using the [`az acr create`][az-acr-create] command.

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
    NAME                  RESOURCE GROUP      LOCATION    SKU      LOGIN SERVER                     CREATION DATE         ADMIN ENABLED
    --------------------  ------------------  ----------  -------  -------------------------------  --------------------  ---------------
    mydnsrandomnamebbbhe  myResourceGroup-rg  eastus      Premium  mydnsrandomnamebbbhe.azurecr.io  2024-06-11T09:36:43Z  True
    ```

## Create an AKS cluster

In this step, we create an AKS cluster. We enable the Azure KeyVault Secret Provider Addon, which allows the AKS cluster to access secrets stored in Azure Key Vault. We also enable Workload Identity, which allows the AKS cluster to access other Azure resources securely.

1. Create an AKS cluster using the [`az aks create`][az-aks-create] command.

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
     --node-os-upgrade-channel  NodeImage \
     --attach-acr ${MY_ACR_REGISTRY} \
     --enable-oidc-issuer \
     --enable-workload-identity \
     --enable-addons azure-keyvault-secrets-provider \
     --zones 1 2 3 \
     --generate-ssh-keys \
     --output table
    ```

    Example output:
    <!-- expected_similarity=0.5 -->
    ```output
    Kind    KubernetesVersion    Location    MaxAgentPools    Name         NodeResourceGroup                         ProvisioningState    ResourceGroup       ResourceUid               SupportPlan
    -----------------------------------------------------------------------  --------------------------  ----------------------  ----------------------------------  ------------------------------------  -------------------------  ------------  ----------------------------------------------------------------  ------  -------------------  ----------  ---------------  -----------  ----------------------------------------  -------------------  ------------------  ------------------------  ------------------
    cluster-ak-myresourcegroup--9b70ac-hhrizake.portal.hcp.eastus.azmk8s.io  1.28.9                      False                   cluster-ak-myResourceGroup--9b70ac  efecebf9-8894-46b9-9d68-09bfdadc474a  False                      True          cluster-ak-myresourcegroup--9b70ac-hhrizake.hcp.eastus.azmk8s.io Base     1.28                 eastus      100              cluster-aks  MC_myResourceGroup-rg_cluster-aks_eastus  Succeeded            myResourceGroup-rg  66681ad812cd770001814d32  KubernetesOfficial
    ```

2. Get the Identity ID and the Object ID created by the Azure KeyVault Secret Provider Addon, using the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
    export userAssignedIdentityID=$(az aks show --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --query addonProfiles.azureKeyvaultSecretsProvider.identity.clientId --output tsv)
    export userAssignedObjectID=$(az aks show --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --query addonProfiles.azureKeyvaultSecretsProvider.identity.objectId --output tsv)

    ```

3. Assign the `AcrPull` role to the kubelet identity using the [`az role assignment create`][az-role-assignment-create] command.

    ```azurecli-interactive
    export KUBELET_IDENTITY=$(az aks show --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --output tsv --query identityProfile.kubeletidentity.objectId)
    az role assignment create \
      --assignee ${KUBELET_IDENTITY} \
      --role "AcrPull" \
      --scope ${MY_ACR_REGISTRY_ID} \
      --output table
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    CreatedBy                             CreatedOn                         Name                                  PrincipalId                           PrincipalName                         PrincipalType     ResourceGroup       RoleDefinitionId                                                                                                                            RoleDefinitionName    Scope                                                                                                                                                        UpdatedBy                             UpdatedOn
    ------------------------------------  --------------------------------  ------------------------------------  ------------------------------------  ------------------------------------  ----------------  ------------------  ------------------------------------------------------------------------------------------------------------------------------------------  --------------------  -----------------------------------------------------------------------------------------------------------------------------------------------------------  ------------------------------------  --------------------------------
    ffc55a9e-ed2a-4b60-b034-45228dfe7db5  2024-06-11T09:41:36.631310+00:00  04628c5e-371a-49b8-8462-4ecd7f90a43f  6a9a8328-7257-4db2-8c4f-169687f36556  94fa3265-4ac2-4e19-8516-f3e830642ca8  ServicePrincipal  myResourceGroup-rg  /subscriptions/9b70acd9-975f-44ba-bad6-255a2c8bda37/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d  AcrPull               /subscriptions/9b70acd9-975f-44ba-bad6-255a2c8bda37/resourceGroups/myResourceGroup-rg/providers/Microsoft.ContainerRegistry/registries/mydnsrandomnamebbbhe  ffc55a9e-ed2a-4b60-b034-45228dfe7db5  2024-06-11T09:41:36.631310+00:00
    ```

## Create a node pool for the Valkey workload

In this section, we create a node pool dedicated to running the Valkey workload. This node pool has autoscaling disabled and is created with six nodes across two availability zones, because we want to have one secondary per primary in a different zone.

* Create a new node pool using the [`az aks nodepool add`][az-aks-nodepool-add] command.

    ```azurecli-interactive
    while [ "$(az aks show --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --output tsv --query provisioningState)" != "Succeeded" ]; do echo "waiting for cluster to be ready"; sleep 10; done

    az aks nodepool add \
        --resource-group $MY_RESOURCE_GROUP_NAME \
        --cluster-name  $MY_CLUSTER_NAME \
        --name valkey \
        --node-vm-size Standard_D4s_v3 \
        --node-count 6 \
        --zones 1 2 \
        --output table
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    Count    CurrentOrchestratorVersion    ETag                                  EnableAutoScaling    EnableCustomCaTrust    EnableEncryptionAtHost    EnableFips    EnableNodePublicIp    EnableUltraSsd    KubeletDiskType    MaxPods    Mode    Name    NodeImageVersion                          OrchestratorVersion    OsDiskSizeGb    OsDiskType    OsSku    OsType    ProvisioningState    ResourceGroup       ScaleDownMode    TypePropertiesType       VmSize           WorkloadRuntime
    -------  ----------------------------  ------------------------------------  -------------------  ---------------------  ------------------------  ------------  --------------------  ----------------  -----------------  ---------  ------  ------  ----------------------------------------  ---------------------  --------------  ------------  -------  --------  -------------------  ------------------  ---------------  -----------------------  ---------------  -----------------
    6        1.28.9                        b7aa8e37-ff39-4ec7-bed0-cb37876416cc  False                False                  False                     False         False                 False             OS                 30         User    valkey  AKSUbuntu-2204gen2containerd-202405.27.0  1.28                   128             Managed       Ubuntu   Linux     Succeeded            myResourceGroup-rg  Delete           VirtualMachineScaleSets  Standard_D4s_v3  OCIContainer
    ```

## Connect to the AKS cluster

* Configure `kubectl` to connect to your AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --overwrite-existing --output table
    ```

## Upload Valkey images to your Azure Container Registry

In this section, we download the Valkey image from Dockerhub and upload it to Azure Container Registry. This step ensures that the image is available in your private registry and can be used in your AKS cluster. We don't recommend consuming the public image in a production environment.

* Import the Valkey image from Dockerhub and upload it to your Azure Container Registry using the [`az acr import`][az-acr-import] command.

    ```azurecli-interactive
    az acr import \
        --name $MY_ACR_REGISTRY \
        --source docker.io/valkey/valkey:latest  \
        --image valkey:latest \
        --output table
    ```

## Next steps

> [!div class="nextstepaction"]
> [Configure and deploy the Valkey cluster on AKS][deploy-valkey]

## Contributors

* Nelly Kiboi | Service Engineer
* Saverio Proto | Principal Customer Experience Engineer
* Don High | Principal Customer Engineer
* LaBrina Loving | Principal Service Engineer
* Ken Kilty | Principal TPM
* Russell de Pina | Principal TPM
* Colin Mixon | Product Manager
* Ketan Chawda | Senior Customer Engineer
* Naveed Kharadi | Customer Experience Engineer
* Erin Schaffer | Content Developer 2

<!-- External links -->
[install-helm]: https://helm.sh/docs/intro/install/
[install-docker]: https://docs.docker.com/get-docker/

<!-- Internal links -->
[valkey-solution-overview]: ./valkey-overview.md
[azure-free-account]: https://azure.microsoft.com/free/?WT.mc_id=A261C142F
[install-azure-cli]: /cli/azure/install-azure-cli
[az-group-create]: /cli/azure/group#az-group-create
[az-identity-create]: /cli/azure/identity#az-identity-create
[az-keyvault-create]: /cli/azure/keyvault#az-keyvault-create
[az-acr-create]: /cli/azure/acr#az-acr-create
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-show]: /cli/azure/aks#az-aks-show
[az-role-assignment-create]: /cli/azure/role/assignment#az-role-assignment-create
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-acr-import]: /cli/azure/acr#az-acr-import
[deploy-valkey]: ./deploy-valkey-cluster.md
