---
title: Deploy an AI Model on Azure Kubernetes Service (AKS) with the AI Toolchain Operator in the Azure Portal (Preview)
description: Learn how to deploy an AI model on Azure Kubernetes Service (AKS) using the AI Toolchain Operator in the Azure Portal (Preview).
ms.topic: how-to
ms.date: 11/04/2025
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
# Customer intent: "As a data scientist, I want to deploy AI models on a Kubernetes cluster using a managed operator, so that I can streamline model management and focus on development rather than infrastructure setup."
---

# Deploy an AI model on Azure Kubernetes Service (AKS) with the AI toolchain operator in the Azure portal (preview)

In this article, you learn how to use the AI toolchain operator (KAITO) in the Azure portal to efficiently self-host large language models on Kubernetes, reducing costs and resource complexity, enhancing customization, and maintaining full control over your data.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## About the AI toolchain operator (KAITO)

Self-hosting large language models (LLMs) on Kubernetes is gaining momentum among organizations with inference workloads at scale, such as batch processing, chatbots, agents, and AI-driven applications. These organizations often have access to commercial-grade GPUs and are seeking alternatives to costly per-token API pricing models, which can quickly scale out of control. Many also require the ability to fine-tune or customize their models, a capability typically restricted by closed-source API providers. Additionally, companies handling sensitive or proprietary data - especially in regulated sectors such as finance, healthcare, or defense - prioritize self-hosting to maintain strict control over data and prevent exposure through third-party systems.

To address these needs and more, the [Kubernetes AI Toolchain Operator (KAITO)](https://github.com/kaito-project/kaito), a Cloud Native Computing Foundation (CNCF) Sandbox project, simplifies the process of deploying and managing open-source LLM workloads on Kubernetes. KAITO integrates with vLLM, a high-throughput inference engine designed to serve large language models efficiently. vLLM as an inference engine helps reduce memory and GPU requirements without significantly compromising accuracy.

Built on top of the open-source KAITO project, the AI toolchain operator managed add-on offers a modular, plug-and-play setup that allows teams to quickly deploy models and expose them via production-ready APIs. It includes built-in features like OpenAI-compatible APIs, prompt formatting, and streaming response support. When deployed on an AKS cluster, KAITO ensures data stays within your organization’s controlled environment, providing a secure, compliant alternative to cloud-hosted LLM APIs.

## Before you begin

- This article assumes a basic understanding of Kubernetes concepts. For more information, see [Kubernetes core concepts for AKS](./concepts-clusters-workloads.md).
- For **_all hosted model preset images_** and default resource configuration, see the [KAITO GitHub repository](https://github.com/kaito-project/kaito/tree/main/presets).
- The AI toolchain operator add-on currently supports KAITO **version 0.6.0**. Please make a note of this in considering your choice of model from the KAITO model repository.

## Limitations

- `AzureLinux` and `Windows` OS SKU aren't currently supported.
- AMD GPU virtual machine (VM) sizes aren't a supported `instanceType` in a KAITO workspace.
- AI toolchain operator add-on is supported in **public** Azure regions.

## Prerequisites

- If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn) before you begin.

    > [!NOTE]
    > Your Azure subscription must have GPU VM quota recommended for your model deployment in the same Azure region as your AKS resources.

- An existing AKS cluster. If you don't have one, you can create one by following the steps in [Create an AKS cluster using the Azure portal](./learn/quick-kubernetes-deploy-portal.md).

## Enable the AI toolchain operator on an AKS cluster

1. In the [Azure portal](https://portal.azure.com/), navigate to your **AKS cluster resource**.
1. From the service menu, select **Settings** > **AI/ML (preview)** > **Enable**.

    :::image type="content" source="./media/ai-toolchain-operator-azure-portal/enable-add-on-azure-portal.png" alt-text="Screenshot that shows the AI/ML (preview) page and the option to enable KAITO in the Azure portal.":::

## Connect to your AKS cluster using Azure Cloud Shell

You use the Kubernetes command-line client, [kubectl][kubectl], to manage Kubernetes clusters. `kubectl` is already installed if you use Azure Cloud Shell. If you're unfamiliar with the Cloud Shell, review [Overview of Azure Cloud Shell](/azure/cloud-shell/overview).

If you're using Cloud Shell, open it with the `>_` button on the top of the Azure portal. If you're using PowerShell locally, connect to Azure via the `Connect-AzAccount` command. If you're using Azure CLI locally, connect to Azure via the `az login` command.

### [Azure CLI](#tab/azure-cli)

1. Configure `kubectl` to connect to your Kubernetes cluster using the [`az aks get-credentials`][az-aks-get-credentials] command. This command downloads credentials and configures the Kubernetes CLI to use them.

    ```azurecli-interactive
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
    ```

1. Verify the connection to your cluster using the [`kubectl get`][kubectl-get] command, which returns a list of the cluster nodes.

    ```bash
    kubectl get nodes
    ```

    The following example output shows the single node created in the previous steps. Make sure the node status is _Ready_.

    ```output
    NAME                       STATUS   ROLES   AGE     VERSION
    aks-nodepool1-31718369-0   Ready    agent   6m44s   v1.15.10
    ```

### [Azure PowerShell](#tab/azure-powershell)

1. Configure `kubectl` to connect to your Kubernetes cluster using the [`Import-AzAksCredential`][import-azakscredential] cmdlet. This command downloads credentials and configures the Kubernetes CLI to use them.

    ```azurepowershell-interactive
    Import-AzAksCredential -ResourceGroupName $RESOURCE_GROUP -Name $CLUSTER_NAME
    ```

1. Verify the connection to your cluster using the [`kubectl get`][kubectl-get] command, which returns a list of the cluster nodes.

    ```bash
    kubectl get nodes
    ```

    The following example output shows the single node created in the previous steps. Make sure the node status is _Ready_.

    ```output
    NAME                       STATUS  ROLES   AGE     VERSION
    aks-nodepool1-31718369-0   Ready   agent   6m44s   v1.15.10
    ```

---

## Deploy a default hosted AI model

1. Navigate through the supported model registry in the **Models** tab and select **Deploy** for your chosen model.

    :::image type="content" source="./media/ai-toolchain-operator-azure-portal/add-on-azure-portal-model.png" alt-text="Screenshot that shows the supported model registry in the AI/ML (preview) blade of the AKS cluster resource in the Azure portal.":::

1. On the **1. Model** page, select a **Model family**, **Model**, and **Instance type**, and enter a **Workspace name**.

    :::image type="content" source="./media/ai-toolchain-operator-azure-portal/add-on-azure-portal-model-details.png" alt-text="Screenshot that shows the inference configuration and compute resource details for the selected model in the Azure portal.":::

1. Deploy the model.
1. Track the resource readiness and progress of the inference service deployment in the **AI Deployments** tab.

    :::image type="content" source="./media/ai-toolchain-operator-azure-portal/add-on-azure-portal-deployment-progress.png" alt-text="Screenshot that shows the AI Deployments tab in the Azure portal.":::

## Test the model inference service

- Test different inputs on your model inference service and adjust the configurable parameters to evaluate model performance.

    :::image type="content" source="media/ai-toolchain-operator-azure-portal/add-on-azure-portal-model-testing.png" alt-text="Screenshot that shows the KAITO inference test page with sliders to configure LLM parameters in the Azure portal.":::

## Next steps

Learn more about KAITO model deployment options with the following articles:

- Deploy LLMs with your application on AKS using [KAITO in Visual Studio Code][kaito-vs-code].
- [Monitor your KAITO inference workload][kaito-monitoring].
- [Fine tune a model][kaito-fine-tune] with the AI toolchain operator add-on on AKS.
- Configure and test [tool calling with KAITO inference][kaito-tool-calling].
- Integrate an [MCP server with the AI toolchain operator][kaito-mcp] add-on on AKS.

<!-- LINKS - external -->
[kubectl]: https://kubernetes.io/docs/reference/kubectl/
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get

<!-- LINKS - internal -->
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[import-azakscredential]: /powershell/module/az.aks/import-azakscredential
[kaito-fine-tune]: ./ai-toolchain-operator-fine-tune.md
[kaito-monitoring]: ./ai-toolchain-operator-monitoring.md
[kaito-tool-calling]: ./ai-toolchain-operator-tool-calling.md
[kaito-mcp]: ./ai-toolchain-operator-mcp.md
[kaito-vs-code]: ./aks-extension-kaito.md
