---
title: Deploy an AI model on Azure Kubernetes Service (AKS) with the AI toolchain operator (preview)
description: Learn how to enable the AI toolchain operator add-on on Azure Kubernetes Service (AKS) to simplify OSS AI model management and deployment.
ms.topic: how-to
ms.custom: azure-kubernetes-service, devx-track-azurecli
ms.date: 02/28/2024
author: schaffererin
ms.author: schaffererin

---

# Deploy an AI model on Azure Kubernetes Service (AKS) with the AI toolchain operator (preview)

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://go.microsoft.com/fwlink/?linkid=2303212)

The AI toolchain operator (KAITO) is a managed add-on that simplifies the experience of running open-source and private AI models on your AKS cluster. KAITO reduces the time to onboard models and provision resources, enabling faster AI model prototyping and development rather than infrastructure management.

This article shows you how to enable the AI toolchain operator add-on and deploy an AI model for inferencing on AKS.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Before you begin

* This article assumes a basic understanding of Kubernetes concepts. For more information, see [Kubernetes core concepts for AKS](./concepts-clusters-workloads.md).
* For ***all hosted model preset images*** and default resource configuration, see the [KAITO GitHub repository](https://github.com/kaito-project/kaito/tree/main/presets).
* The AI toolchain operator add-on currently supports KAITO **version 0.4.4**, please make a note of this in considering your choice of model from the KAITO model repository.

## Prerequisites

* If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/?WT.mc_id=A261C142F) before you begin.
  * If you have multiple Azure subscriptions, make sure you select the correct subscription in which the resources will be created and charged using the [az account set][az-account-set] command.

    > [!NOTE]
    > Your Azure subscription must have GPU VM quota recommended for your model deployment in the same Azure region as your AKS resources.

* Azure CLI version 2.47.0 or later installed and configured. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
* The Kubernetes command-line client, kubectl, installed and configured. For more information, see [Install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/).
* [Install the Azure CLI AKS preview extension](#install-the-azure-cli-preview-extension).
* [Register the AI toolchain operator add-on feature flag](#register-the-ai-toolchain-operator-add-on-feature-flag).

### Install the Azure CLI preview extension

1. Install the Azure CLI preview extension using the [az extension add][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

2. Update the extension to make sure you have the latest version using the [az extension update][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the AI toolchain operator add-on feature flag

1. Register the AIToolchainOperatorPreview feature flag using the [az feature register][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AIToolchainOperatorPreview"
    ```

    It takes a few minutes for the registration to complete.

2. Verify the registration using the [az feature show][az-feature-show] command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "AIToolchainOperatorPreview"
    ```

### Export environment variables

* To simplify the configuration steps in this article, you can define environment variables using the following commands. Make sure to replace the placeholder values with your own.

    ```azurecli-interactive
    export AZURE_SUBSCRIPTION_ID="mySubscriptionID"
    export AZURE_RESOURCE_GROUP="myResourceGroup"
    export AZURE_LOCATION="myLocation"
    export CLUSTER_NAME="myClusterName"
    ```

## Enable the AI toolchain operator add-on on an AKS cluster

The following sections describe how to create an AKS cluster with the AI toolchain operator add-on enabled and deploy a default hosted AI model.

### Create an AKS cluster with the AI toolchain operator add-on enabled

1. Create an Azure resource group using the [az group create][az-group-create] command.

    ```azurecli-interactive
    az group create --name $AZURE_RESOURCE_GROUP --location $AZURE_LOCATION
    ```

2. Create an AKS cluster with the AI toolchain operator add-on enabled using the [az aks create][az-aks-create] command with the `--enable-ai-toolchain-operator` and `--enable-oidc-issuer` flags.

    ```azurecli-interactive
    az aks create --location $AZURE_LOCATION \
        --resource-group $AZURE_RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --enable-oidc-issuer \
        --enable-ai-toolchain-operator \
        --generate-ssh-keys
    ```

    > [!NOTE]
    > AKS creates a managed identity once you enable the AI toolchain operator add-on. The managed identity is used to create GPU node pools in the managed AKS cluster. Proper permissions need to be set for it manually following the steps introduced in the following sections.
    >

3. On an existing AKS cluster, you can enable the AI toolchain operator add-on using the [az aks update][az-aks-update] command.

    ```azurecli-interactive
    az aks update --name $CLUSTER_NAME \
            --resource-group $AZURE_RESOURCE_GROUP \
            --enable-oidc-issuer \
            --enable-ai-toolchain-operator
    ```

## Connect to your cluster

1. Configure `kubectl` to connect to your cluster using the [az aks get-credentials][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group $AZURE_RESOURCE_GROUP --cluster-name $CLUSTER_NAME
    ```

2. Verify the connection to your cluster using the `kubectl get` command.

    ```azurecli-interactive
    kubectl get nodes
    ```

## Export environment variables

* Export environment variables for the MC resource group, principal ID identity, and KAITO identity using the following commands:

    ```azurecli-interactive
    export MC_RESOURCE_GROUP=$(az aks show --resource-group $AZURE_RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --query nodeResourceGroup \
        -o tsv)
    export PRINCIPAL_ID=$(az identity show --name "ai-toolchain-operator-${CLUSTER_NAME}" \
        --resource-group $MC_RESOURCE_GROUP \
        --query 'principalId' \
        -o tsv)
    export KAITO_IDENTITY_NAME="ai-toolchain-operator-${CLUSTER_NAME}"
    ```

## Get the AKS OpenID Connect (OIDC) Issuer

* Get the AKS OIDC Issuer URL and export it as an environment variable:

    ```azurecli-interactive
    export AKS_OIDC_ISSUER=$(az aks show --resource-group $AZURE_RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --query "oidcIssuerProfile.issuerUrl" \
        -o tsv)
    ```

## Create role assignment for the service principal

* Create a new role assignment for the service principal using the [az role assignment create][az-role-assignment-create] command.

    ```azurecli-interactive
    az role assignment create --role "Contributor" \
        --assignee $PRINCIPAL_ID \
        --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourcegroups/$AZURE_RESOURCE_GROUP"
    ```

## Establish a federated identity credential

* Create the federated identity credential between the managed identity, AKS OIDC issuer, and subject using the [az identity federated-credential create][az-identity-federated-credential-create] command.

    ```azurecli-interactive
    az identity federated-credential create --name "kaito-federated-identity" \
        --identity-name $KAITO_IDENTITY_NAME \
        -g $MC_RESOURCE_GROUP \
        --issuer $AKS_OIDC_ISSUER \
        --subject system:serviceaccount:"kube-system:kaito-gpu-provisioner" \
        --audience api://AzureADTokenExchange
    ```

    > [!NOTE]
    > Before this step is complete, the `gpu-provisioner` controller pod will remain in a crash loop status. Once the federated credential is created, the `gpu-provisioner` controller pod will reach a running state and you will be able to verify that the deployment is running in the following steps.

## Verify that your deployment is running

1. Restart the KAITO GPU provisioner deployment on your pods using the `kubectl rollout restart` command:

    ```azurecli-interactive
    kubectl rollout restart deployment/kaito-gpu-provisioner -n kube-system
    ```

2. Verify that the GPU provisioner deployment is running using the `kubectl get` command:

    ```azurecli-interactive
    kubectl get deployment -n kube-system | grep kaito
    ```

## Deploy a default hosted AI model

1. Deploy the Falcon 7B-instruct model preset from the KAITO model repository using the `kubectl apply` command.

    ```azurecli-interactive
    kubectl apply -f https://raw.githubusercontent.com/Azure/kaito/main/examples/inference/kaito_workspace_falcon_7b-instruct.yaml
    ```

2. Track the live resource changes in your workspace using the `kubectl get` command.

    ```azurecli-interactive
    kubectl get workspace workspace-falcon-7b-instruct -w
    ```

    > [!NOTE]
    > As you track the KAITO workspace deployment, note that machine readiness can take up to 10 minutes, and workspace readiness up to 20 minutes depending on the size of your model.

3. Check your inference service and get the service IP address using the `kubectl get svc` command.

    ```azurecli-interactive
    export SERVICE_IP=$(kubectl get svc workspace-falcon-7b-instruct -o jsonpath='{.spec.clusterIP}')
    ```

4. Test the Falcon 7B-instruct inference service with a sample input of your choice using the [OpenAI chat completions API format](https://platform.openai.com/docs/api-reference/chat):

    ```azurecli-interactive
    kubectl run -it --rm --restart=Never curl --image=curlimages/curl -- curl -X POST http://$SERVICE_IP/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "falcon-7b-instruct",
    "prompt": "What is Kubernetes?",
    "max_tokens": 10
  }'
    ```

## Clean up resources

If you no longer need these resources, you can delete them to avoid incurring extra Azure compute charges.

* Delete the KAITO workspace using the `kubectl delete workspace` command.

    ```azurecli-interactive
    kubectl delete workspace workspace-falcon-7b-instruct
    ```

* The GPU node pools provisioned by the KAITO deployment will need to be deleted manually. 
Use the node label created by [Falcon-7b instruct workspace](https://github.com/kaito-project/kaito/blob/main/examples/inference/kaito_workspace_falcon_7b-instruct.yaml) to get the node pool name. In this example the node label is "kaito.sh/workspace": "workspace-falcon-7b-instruct".

    ```azurecli-interactive     
    az aks nodepool list --resource-group $AZURE_RESOURCE_GROUP --cluster-name $CLUSTER_NAME
    ```

* [Delete the node pool][delete-node-pool] with this name from your AKS cluster, and repeat the steps in this section for each KAITO workspace that will be removed.

## Common troubleshooting scenarios

After applying the KAITO model inference workspace, your resource readiness and workspace conditions may not update to `True` for the following reasons:

- You may not have sufficient permissions to operate on the AKS cluster. Ensure that the `ai-toolchain-operator-$CLUSTER_NAME` identity has been assigned `Contributor` role to your Azure resource group. Run the following command and confirm that the result is non-empty:

    ```azurecli-interactive   
    az role assignment list --scope /subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP
    ```

- Your Azure subscription does not have quota for the minimum GPU instance type specified in your KAITO workspace. You will need to [request a quota increase](/azure/quotas/quickstart-increase-quota-portal) for the GPU VM family in your Azure subscription.

- The GPU instance type is not available in your AKS region. Confirm the [GPU instance availability in your specific region](https://azure.microsoft.com/explore/global-infrastructure/products-by-region/?regions=&products=virtual-machines), and switch the Azure region if your GPU VM family is not available.

## Next steps

Learn more about [KAITO model deployment options](https://github.com/Azure/kaito) below:

* [Fine tune a model][kaito-fine-tune] with the AI toolchain operator add-on on AKS.
* [Monitor KAITO inference metrics](./ai-toolchain-operator-monitoring.md) with Azure Managed Prometheus and Grafana on AKS
* Onboard a [custom model for KAITO inference](https://github.com/kaito-project/kaito/blob/main/docs/custom-model-integration/custom-model-integration-guide.md) on AKS.

<!-- LINKS -->

[az-group-create]: /cli/azure/group#az_group_create
[az-group-delete]: /cli/azure/group#az_group_delete
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-update]: /cli/azure/aks#az_aks_update
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[az-role-assignment-create]: /cli/azure/role/assignment#az_role_assignment_create
[az-identity-federated-credential-create]: /cli/azure/identity/federated-credential#az_identity_federated_credential_create
[az-account-set]: /cli/azure/account#az_account_set
[az-extension-add]: /cli/azure/extension#az_extension_add
[az-extension-update]: /cli/azure/extension#az_extension_update
[az-feature-register]: /cli/azure/feature#az_feature_register
[az-feature-show]: /cli/azure/feature#az_feature_show
[az-provider-register]: /cli/azure/provider#az_provider_register
[mlops-concepts]: ../aks/concepts-machine-learning-ops.md
[mlops-best-practices]: ../aks/best-practices-ml-ops.md
[delete-node-pool]: ../aks/delete-node-pool.md
[kaito-fine-tune]: ./ai-toolchain-operator-fine-tune.md