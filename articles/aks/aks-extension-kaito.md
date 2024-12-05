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

Before you begin, make sure you have the following resources:

* The Azure Kubernetes Service (AKS) extension for Visual Studio Code downloaded. For more information, see [Install the Azure Kubernetes Service (AKS) extension for Visual Studio Code][install-aks-vscode].

## Install KAITO on your cluster

You can access the screen to install KAITO via the Kubernetes view.

### [Kubernetes view](#tab/kubernetes-view)
    
1. In the Kubernetes tab, under Clouds > Azure > your subscription > Deploy a LLM with KAITO, right click on your cluster and select **Install KAITO**.
2. Click **Install KAITO**.
3. Once on the page, click **Install KAITO** and the KAITO installation process will begin. Once KAITO has been successfully installed, you will be prompted with a "Generate Workspace" button that will redirect you to the model deployment page.
---

## Create a KAITO workspace

You can access the screen to create a KAITO workspace via the Kubernetes view.

When creating a KAITO workspace, you can choose to deploy the default workspace CRD directly into your AKS cluster, or save the CRD and customize it to your liking.

### [Kubernetes view](#tab/kubernetes-view)
    
1. In the Kubernetes tab, under Clouds > Azure > your subscription >  Deploy a LLM with KAITO, right click on your cluster and select **Create KAITO workspace**.
2. Find the model you wish to deploy/create and click on it.
3. Choose to either **Deploy default workspace CRD** or **Customize workspace CRD**.
4. Click **Deploy Default workspace CRD** to deploy the model. It will track the progress of the model and notify you once the model has been successfully deployed. It will also notify you if the model was already previously unsucessfully onto your cluster. Upon successful deployment, you will be prompted with a "View Deployed Models" button that will redirect you to the deployment management page.
---

## Manage KAITO models

You can access the screen to manage your KAITO models via the Kubernetes view.

The manage KAITO models screen allows you to see all models deployed in your AKS cluster, alongside their status (ongoing, successful, or failed). 

For your selected deployment, click **Get Logs** to  access the latest logs from the KAITO workspace pods. This action will generate a new text file containing the most recent 500 lines of logs.

To delete a model, select **Delete Workspace** (or **Cancel** for ongoing deployments). For failed deployments, choose **Re-deploy Default CRD** to remove the current deployment and restart the model deployment process from scratch.

To test a model, select **Test**. This will bring you to a new screen where you can interact with the deployed model through a chat interface.

### [Kubernetes view](#tab/kubernetes-view)
    
1. In the Kubernetes tab, under Clouds > Azure > your subscription >  Deploy a LLM with KAITO, right click on your cluster and select **Manage KAITO models**.
2. Choose to either **Delete Workspace**, **Get Logs**, or **Test** your model.
---

## Test your model

After selecting **Test** model on the [Manage KAITO models](#manage-kaito-models) screen, a chat interface will pop up allowing you to interact and various parameters of the model.

### [Kubernetes view](#tab/kubernetes-view)
    
1. In the Kubernetes tab, under Clouds > Azure > your subscription >  Deploy a LLM with KAITO, right click on your cluster and select **Manage KAITO models**.
2. Select **Test**.
3. Type into the "Prompt" box.
4. Optional: tweak the parameters:

    * **Temperature**: Controls the randomness of the model's output. A low temperature is good for tasks needing precision (e.g., math problems), while a high temperature is better for creative writing
    * **Top P**: Limits the next-word choices to a dynamic subset of the vocabulary, determined by a cumulative probability threshold.
    * **Top K**: Limits the next-word selection to the top K most probable words. Smaller K values lead to more predictable outputs, while larger values increase variability.
    * **Repetition Penalty**: Penalizes the model for repeating the same phrases, words, or sequences. Useful for avoiding repetitive or looping outputs, especially in longer generations.
    * **Max Length**: Defines the maximum number of tokens (words or subwords) in the generated output.
---


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
