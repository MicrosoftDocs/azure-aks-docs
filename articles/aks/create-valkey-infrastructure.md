---
title: Create the infrastructure for running a Valkey cluster on Azure Kubernetes Service (AKS)
description: In this article, you create the infrastructure for running a Valkey cluster on Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.custom: azure-kubernetes-service
ms.date: 08/15/2024
author: schaffererin
ms.author: schaffererin
zone_pivot_groups: azure-cli-or-terraform

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

:::zone pivot="azure-cli"

## Set environment variables

* Set the required environment variables for use throughout this guide:

    ```bash
    random=$(echo $RANDOM | tr '[0-9]' '[a-z]')
    export MY_RESOURCE_GROUP_NAME=myResourceGroup-rg
    export MY_LOCATION=eastus
    export MY_ACR_REGISTRY=mydnsrandomname$(echo $random)
    export MY_KEYVAULT_NAME=vault-$(echo $random)-kv
    export MY_CLUSTER_NAME=cluster-aks
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
    bbbb1b1b-cc2c-dd3d-ee4e-ffffff5f5f5f  2024-06-11T09:41:36.631310+00:00  04628c5e-371a-49b8-8462-4ecd7f90a43f  6a9a8328-7257-4db2-8c4f-169687f36556  94fa3265-4ac2-4e19-8516-f3e830642ca8  ServicePrincipal  myResourceGroup-rg  /subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d  AcrPull               /subscriptions/aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e/resourceGroups/myResourceGroup-rg/providers/Microsoft.ContainerRegistry/registries/mydnsrandomnamebbbhe  bbbb1b1b-cc2c-dd3d-ee4e-ffffff5f5f5f  2024-06-11T09:41:36.631310+00:00
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
        --zones 1 2 3 \
        --output table
    ```

    Example output:
    <!-- expected_similarity=0.8 -->
    ```output
    Count    CurrentOrchestratorVersion    ETag                                  EnableAutoScaling    EnableCustomCaTrust    EnableEncryptionAtHost    EnableFips    EnableNodePublicIp    EnableUltraSsd    KubeletDiskType    MaxPods    Mode    Name    NodeImageVersion                          OrchestratorVersion    OsDiskSizeGb    OsDiskType    OsSku    OsType    ProvisioningState    ResourceGroup       ScaleDownMode    TypePropertiesType       VmSize           WorkloadRuntime
    -------  ----------------------------  ------------------------------------  -------------------  ---------------------  ------------------------  ------------  --------------------  ----------------  -----------------  ---------  ------  ------  ----------------------------------------  ---------------------  --------------  ------------  -------  --------  -------------------  ------------------  ---------------  -----------------------  ---------------  -----------------
    6        1.28.9                        b7aa8e37-ff39-4ec7-bed0-cb37876416cc  False                False                  False                     False         False                 False             OS                 30         User    valkey  AKSUbuntu-2204gen2containerd-202405.27.0  1.28                   128             Managed       Ubuntu   Linux     Succeeded            myResourceGroup-rg  Delete           VirtualMachineScaleSets  Standard_D4s_v3  OCIContainer
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

:::zone-end

:::zone pivot="terraform"

## Deploy the infrastructure with Terraform

To deploy the infrastructure using terraform we are going to use the [Azure Verified Module](https://azure.github.io/Azure-Verified-Modules/)[for AKS](https://github.com/Azure/terraform-azurerm-avm-res-containerservice-managedcluster.git).

> [!NOTE]
> If you're planning to run this in production, we recommend looking at [AKS production pattern module for Azure Verified Modules](https://github.com/Azure/terraform-azurerm-avm-ptn-aks-production). This comes coupled with best practice recommendations.

1. Clone the git repository with the terraform module.

    ```bash
    git clone https://github.com/Azure/terraform-azurerm-avm-res-containerservice-managedcluster.git
    cd terraform-azurerm-avm-res-containerservice-managedcluster/tree/stateful-workloads/examples/stateful-workloads-valkey
    ```

2. Run the Terraform commands to deploy the infrastructure. You can also provide your specific [variables](https://developer.hashicorp.com/terraform/language/values/variables) at this step. In this step, we have set the secrets that will be used when deploying Valkey in the next step.

    ```bash
    terraform init
    SECRET=$(openssl rand -base64 32)
    export TF_VAR_valkey_password=${SECRET}
    terraform apply 
    ```

> [!NOTE]
> In some cases, the container registry tasks that import Valkey images to the container registry might fail. This is a well-known issue. Please refer to [container-registry-task] for more information. In most cases, retrying resolves the problem.

:::zone-end

## Next steps

> [!div class="nextstepaction"]
> [Configure and deploy the Valkey cluster on AKS][deploy-valkey]

## Contributors

*Microsoft maintains this article. The following contributors originally wrote it:*

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
[github-azure]: https://github.com/Azure/

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
[az-acr-import]: /cli/azure/acr#az-acr-import
[deploy-valkey]: ./deploy-valkey-cluster.md
[container-registry-task]:./container-registry/container-registry-faq#run-error-message-troubleshooting
