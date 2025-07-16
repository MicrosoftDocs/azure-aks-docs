---
title: Deploy an AI model on Azure Kubernetes Service (AKS) with the AI toolchain operator add-on
description: Learn how to enable the AI toolchain operator add-on on Azure Kubernetes Service (AKS) to simplify OSS AI model management and deployment.
ms.topic: how-to
ms.custom: azure-kubernetes-service, devx-track-azurecli
ms.date: 04/30/2025
author: schaffererin
ms.author: schaffererin

---

# Deploy an AI model on Azure Kubernetes Service (AKS) with the AI toolchain operator add-on

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://go.microsoft.com/fwlink/?linkid=2303212)

In this article, you learn how to use the AI toolchain operator add-on to efficiently self-host large language models on Kubernetes, reducing costs and resource complexity, enhancing customization, and maintaining full control over your data.

## About KAITO

Self-hosting large language models (LLMs) on Kubernetes is gaining momentum among organizations with inference workloads at scale, such as batch processing, chatbots, agents, and AI-driven applications. These organizations often have access to commercial-grade GPUs and are seeking alternatives to costly per-token API pricing models, which can quickly scale out of control. Many also require the ability to fine-tune or customize their models, a capability typically restricted by closed-source API providers. Additionally, companies handling sensitive or proprietary data - especially in regulated sectors such as finance, healthcare, or defense - prioritize self-hosting to maintain strict control over data and prevent exposure through third-party systems.

To address these needs and more, the [Kubernetes AI Toolchain Operator (KAITO)](https://github.com/kaito-project/kaito), a Cloud Native Computing Foundation (CNCF) Sandbox project, simplifies the process of deploying and managing open-source LLM workloads on Kubernetes. KAITO integrates with vLLM, a high-throughput inference engine designed to serve large language models efficiently. vLLM as an inference engine helps reduce memory and GPU requirements without significantly compromising accuracy. 

Built on top of the open-source KAITO project, the AI toolchain operator managed add-on offers a modular, plug-and-play setup that allows teams to quickly deploy models and expose them via production-ready APIs. It includes built-in features like OpenAI-compatible APIs, prompt formatting, and streaming response support. When deployed on an AKS cluster, KAITO ensures data stays within your organization’s controlled environment, providing a secure, compliant alternative to cloud-hosted LLM APIs.

## Before you begin

* This article assumes a basic understanding of Kubernetes concepts. For more information, see [Kubernetes core concepts for AKS](./concepts-clusters-workloads.md).
* For ***all hosted model preset images*** and default resource configuration, see the [KAITO GitHub repository](https://github.com/kaito-project/kaito/tree/main/presets).
* The AI toolchain operator add-on currently supports KAITO **version 0.4.6**, please make a note of this in considering your choice of model from the KAITO model repository.

## Limitations

* `AzureLinux` and `Windows` OS SKU are not currently supported.
* AMD GPU VM sizes are not supported `instanceType` in a KAITO workspace.

## Prerequisites

* If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/?WT.mc_id=A261C142F) before you begin.
  * If you have multiple Azure subscriptions, make sure you select the correct subscription in which the resources will be created and charged using the [az account set][az-account-set] command.

    > [!NOTE]
    > Your Azure subscription must have GPU VM quota recommended for your model deployment in the same Azure region as your AKS resources.

* Azure CLI version 2.76.0 or later installed and configured. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
* The Kubernetes command-line client, kubectl, installed and configured. For more information, see [Install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/).

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

2. Create an AKS cluster with the AI toolchain operator add-on enabled using the [az aks create][az-aks-create] command with the `--enable-ai-toolchain-operator` flag.

    ```azurecli-interactive
    az aks create --location $AZURE_LOCATION \
        --resource-group $AZURE_RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --enable-ai-toolchain-operator \
        --generate-ssh-keys
    ```

3. On an existing AKS cluster, you can enable the AI toolchain operator add-on using the [az aks update][az-aks-update] command.

    ```azurecli-interactive
    az aks update --name $CLUSTER_NAME \
            --resource-group $AZURE_RESOURCE_GROUP \
            --enable-ai-toolchain-operator
    ```

## Connect to your cluster

1. Configure `kubectl` to connect to your cluster using the [az aks get-credentials][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group $AZURE_RESOURCE_GROUP --name $CLUSTER_NAME
    ```

2. Verify the connection to your cluster using the `kubectl get` command.

    ```azurecli-interactive
    kubectl get nodes
    ```

## Deploy a default hosted AI model

KAITO offers a range of small to large language models hosted as public container images, which can be deployed in one step using a KAITO workspace. You can browse the preset LLM images available in the [KAITO model registry](https://github.com/kaito-project/kaito/tree/main/presets). In this section, we'll use the high-performant multimodal [Microsoft Phi-4-mini](https://techcommunity.microsoft.com/blog/educatordeveloperblog/welcome-to-the-new-phi-4-models---microsoft-phi-4-mini--phi-4-multimodal/4386037) language model as an example:

1. Deploy the [Phi-4-mini instruct](https://huggingface.co/microsoft/Phi-4-mini-instruct) model preset for inference from the KAITO model repository using the `kubectl apply` command.

    ```azurecli-interactive
    kubectl apply -f https://raw.githubusercontent.com/kaito-project/kaito/refs/heads/main/examples/inference/kaito_workspace_phi_4_mini.yaml
    ```

2. Track the live resource changes in your workspace using the `kubectl get` command.

    ```azurecli-interactive
    kubectl get workspace workspace-phi-4-mini -w
    ```

    > [!NOTE]
    > As you track the KAITO workspace deployment, note that machine readiness can take up to 10 minutes, and workspace readiness up to 20 minutes depending on the size of your model.

3. Check your inference service and get the service IP address using the `kubectl get svc` command.

    ```azurecli-interactive
    export SERVICE_IP=$(kubectl get svc workspace-phi-4-mini -o jsonpath='{.spec.clusterIP}')
    ```

4. Test the Phi-4-mini instruct inference service with a sample input of your choice using the [OpenAI chat completions API format](https://platform.openai.com/docs/api-reference/chat):

    ```azurecli-interactive
    kubectl run -it --rm --restart=Never curl --image=curlimages/curl -- curl -X POST http://$SERVICE_IP/v1/completions -H "Content-Type: application/json" \
      -d '{
            "model": "Phi-4-mini-instruct",
            "prompt": "How should I dress for the weather today?",
            "max_tokens": 10
           }'
    ```

## Deploy a custom or domain-specific LLM

Open-source LLMs are often trained in different contexts and domains, and the hosted model presets may not always fit the requirements of your application or data. In this case, KAITO also supports inference deployment of newer or domain-specific language models from [HuggingFace](https://huggingface.co/). Try out a custom model inference deployment with KAITO by following [this article](./kaito-custom-inference-model.md).

## Clean up resources

If you no longer need these resources, you can delete them to avoid incurring extra Azure compute charges.

1. Delete the KAITO workspace using the `kubectl delete workspace` command.

    ```azurecli-interactive
    kubectl delete workspace workspace-phi-4-mini
    ```

2. You need to manually delete the GPU node pools provisioned by the KAITO deployment. Use the node label created by [Phi-4-mini instruct workspace](https://raw.githubusercontent.com/kaito-project/kaito/refs/heads/main/examples/inference/kaito_workspace_phi_4_mini.yaml) to get the node pool name using the [`az aks nodepool list`](/cli/azure/aks#az-aks-nodepool-list) command. In this example, the node label is "kaito.sh/workspace": "workspace-phi-4-mini".

    ```azurecli-interactive     
    az aks nodepool list --resource-group $AZURE_RESOURCE_GROUP --cluster-name $CLUSTER_NAME
    ```

3. [Delete the node pool][delete-node-pool] with this name from your AKS cluster and repeat the steps in this section for each KAITO workspace that will be removed.

## Common troubleshooting scenarios

After applying the KAITO model inference workspace, your resource readiness and workspace conditions might not update to `True` for the following reasons:

* Your Azure subscription doesn't have quota for the minimum GPU instance type specified in your KAITO workspace. You'll need to [request a quota increase](/azure/quotas/quickstart-increase-quota-portal) for the GPU VM family in your Azure subscription.
* The GPU instance type isn't available in your AKS region. Confirm the [GPU instance availability in your specific region](https://azure.microsoft.com/explore/global-infrastructure/products-by-region/?regions=&products=virtual-machines) and switch the Azure region if your GPU VM family isn't available.

## Next steps

Learn more about KAITO model deployment options below:

* Deploy LLMs with your application on AKS using [KAITO in Visual Studio Code][kaito-vs-code].
* [Monitor your KAITO inference workload][kaito-monitoring].
* [Fine tune a model][kaito-fine-tune] with the AI toolchain operator add-on on AKS.
* Learn about [MLOps best practices][mlops-best-practices] for your AI pipelines on AKS.

<!-- LINKS -->

[az-group-create]: /cli/azure/group#az_group_create
[az-group-delete]: /cli/azure/group#az_group_delete
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-update]: /cli/azure/aks#az_aks_update
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
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
[kaito-monitoring]: ./ai-toolchain-operator-monitoring.md
[kaito-vs-code]: ./aks-extension-kaito.md