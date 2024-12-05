---
title: Deploy and test models with the AI toolchain operator (KAITO) in Visual Studio Code
description: Learn how to deploy and test models with the AI toolchain operator (KAITO) in Visual Studio Code.
author: qpetraroia
ms.topic: how-to
ms.date: 12/04/2024
ms.author: qpetraroia
ms.service: azure-kubernetes-service
---

# Deploy and test models with the AI toolchain operator (KAITO) in Visual Studio Code

In this article, you learn how to use the AI toolchain operator (KAITO) in the Azure Kubernetes Service (AKS) extension for Visual Studio Code. The AI toolchain operator automatically provisions the necessary GPU nodes and sets up the associated inference server as an endpoint server to your AI models allowing you to test your models with ease.

## Prerequisites


* The Azure Kubernetes Service (AKS) extension for Visual Studio Code downloaded. For more information, see [Install the Azure Kubernetes Service (AKS) extension for Visual Studio Code][install-aks-vscode].

## Install KAITO on your cluster

1. In the Kubernetes tab, under **Clouds** > **Azure** > **your subscription** > **Deploy a LLM with KAITO**, right click on your cluster and select **Install KAITO**.
2. Once on the page, select **Install KAITO** to start the KAITO installation process.
3. When the installation completes, you see a **Generate Workspace** button that redirects you to the model deployment page.

:::image type="content" source="./media/aks-extension/kaito/kaito-install.png" alt-text="Screenshot showing the KAITO install screen." lightbox="./media/aks-extension/kaito/kaito-install.png":::

## Create a KAITO workspace

When creating a KAITO workspace, you can either deploy the default workspace CRD directly into your AKS cluster or save the CRD and customize it for your needs.
    
1. In the Kubernetes tab, under **Clouds** > **Azure** > **your subscription** > **Deploy a LLM with KAITO**, right click on your cluster and select **Create KAITO workspace**.
2. Find and select the model you want to deploy.
3. Select **Deploy default workspace CRD** or **Customize workspace CRD**.
4. Select **Deploy default workspace CRD** to deploy the model. It tracks the progress of the model and notifies you once the model successfully deploys. It also notifies you if the model was already previously unsucessfully onto your cluster.
5. When the deployment completes, you see a **View Deployed Models** button that redirects you to the deployment management page.

:::image type="content" source="./media/aks-extension/kaito/kaito-select-model.png" alt-text="Screenshot showing the model select screen." lightbox="./media/aks-extension/kaito/kaito-select-model.png":::

## Manage KAITO models

The **Manage KAITO models** page allows you to see all models deployed in your AKS cluster along with their status (*ongoing*, *successful*, or *failed*). 

1. In the Kubernetes tab, under **Clouds** > **Azure** > **your subscription** > **Deploy a LLM with KAITO**, right click on your cluster and select **Manage KAITO models**.
2. From this page, you can choose to perform one of the following actions:

    * **Get logs**: Select **Get Logs** to access the latest logs from the KAITO workspace pods for your deployment. This action generates a new text file containing the most recent 500 lines of logs.
    * **Delete a model**: Select **Delete Workspace** (or **Cancel** for ongoing deployments). For failed deployments, select **Redeploy Default CRD** to remove the current deployment and restart the model deployment process from scratch.
    * **Test a model**: Select **Test**. This action brings you to a new page where you can interact with the deployed model through a chat interface.

:::image type="content" source="./media/aks-extension/kaito/kaito-manage-models.png" alt-text="Screenshot showing the manage models screen." lightbox="./media/aks-extension/kaito/kaito-manage-models.png":::

## Test your model

1. In the Kubernetes tab, under **Clouds** > **Azure** > **your subscription** > **Deploy a LLM with KAITO**, right click on your cluster and select **Manage KAITO models**.
2. Select **Test**. This action brings you to a new page where you can interact with the deployed model through the **Prompt** box chat interface.
3. You can optionally adjust the parameters:

    * **Temperature**: Controls the randomness of the model's output. A low temperature is good for tasks needing precision, like math problems, while a high temperature is better for tasks like creative writing.
    * **Top P**: Limits the next-word choices to a dynamic subset of the vocabulary, determined by a cumulative probability threshold.
    * **Top K**: Limits the next-word selection to the top `K` most probable words. Smaller `K` values lead to more predictable outputs, while larger values increase variability.
    * **Repetition Penalty**: Penalizes the model for repeating the same phrases, words, or sequences. This is useful for avoiding repetitive or looping outputs, especially in longer generations.
    * **Max Length**: Defines the maximum number of tokens (words or subwords) in the generated output.

:::image type="content" source="./media/aks-extension/kaito/kaito-test-model.png" alt-text="Screenshot showing test models screen." lightbox="./media/aks-extension/kaito/kaito-test-model.png":::

For more information, see [AKS extension for Visual Studio Code features][aks-vscode-features].

## Product support and feedback
    
If you have a question or want to offer product feedback, please open an issue on the [AKS extension GitHub repository][aks-vscode-github].
    
## Next steps
    
To learn more about other AKS add-ons and extensions, see [Add-ons, extensions, and other integrations for AKS][aks-addons].
    
<!---LINKS--->
[install-aks-vscode]: ./aks-extension-vs-code.md#installation
[aks-vscode-features]: https://code.visualstudio.com/docs/azure/aksextensions#_features
[aks-vscode-github]: https://github.com/Azure/vscode-aks-tools/issues/new/choose
[aks-addons]: ./integrations.md
