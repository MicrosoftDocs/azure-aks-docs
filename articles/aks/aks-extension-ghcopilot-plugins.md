---
title: Use AKS plugins for GitHub Copilot for Azure
description: Learn how to use AKS plugins in GitHub Copilot for Azure to enhance your day-to-day experience in Azure Kubernetes Service
author: qpetraroia
ms.topic: how-to
ms.date: 10/28/2024
ms.author: qpetraroia
ms.service: azure-kubernetes-service
---

# Use AKS plugins in GitHub Copilot for Azure to enhance your day-to-day experience in Azure Kubernetes Service

The AKS plugins (or skills) for GitHub Copilot for Azure (@azure) extension enable users to perform various tasks related to Azure Kubernetes Service (AKS) directly from the GitHub Copilot Chat view. These skills include creating an AKS cluster, deploying a manifest to an AKS cluster, and generating Kubectl commands.

## Prerequisites

Before you begin, make sure you have the following resources:

* [GitHub Copilot] installed.
* [GitHub Copilot for Azure] installed.
* The Azure Kubernetes Service (AKS) extension for Visual Studio Code downloaded. For more information, see [Install the Azure Kubernetes Service (AKS) extension for Visual Studio Code][install-aks-vscode].

## How to start using the AKS plugins for GitHub Copilot for Azure

You can access the AKS plugins for GitHub Copilot for Azure by opening up the GitHub Copilot side-bar panel in Visual Studio Code.

### Create an AKS cluster

:::image type="content" source="./media/aks-extension/ghcopilot-for-azure-aks/aks-gh-chat-create-cluster.png" alt-text="Screenshot showing a cluster being created via GitHub Copilot for Azure." lightbox="./media/aks-extension/ghcopilot-for-azure-aks/aks-gh-chat-create-cluster.png":::

You can create an AKS cluster using the following prompts:

* [@azure] can you help me create a Kubernetes cluster
* [@azure] can you set up an AKS cluster for me?
* [@azure] I have a containerized application, can you help me create an AKS cluster to host it?
* [@azure] create AKS cluster
* [@azure] Help me create a Kubernetes cluster to host my application

### Deploy a manifest to an AKS cluster

:::image type="content" source="./media/aks-extension/ghcopilot-for-azure-aks/aks-gh-chat-deploy-manifest.png" alt-text="Screenshot showing a manifest being deployed via GitHub Copilot for Azure." lightbox="./media/aks-extension/ghcopilot-for-azure-aks/aks-gh-chat-deploy-manifest.png":::

You can deploy your application manifests to an AKS cluster directly from the GitHub Copilot Chat view. This simplifies the deployment process and ensures consistency. By using predefined prompts, the risk of errors during deployment is minimized leading to more reliable and stable deployments.

To deploy a manifest file to an AKS cluster you can use these prompts:

* [@azure] help me deploy my manifest file
* [@azure] can you deploy my manifest to my AKS c luster?
* [@azure] can you deploy my manifest to my Kubernetes cluster?
* [@azure] deploy my application manifest to an AKS cluster
* [@azure] deploy manifest for AKS cluster

### Generate Kubectl commands

:::image type="content" source="./media/aks-extension/ghcopilot-for-azure-aks/aks-gh-chat-kubectl-generation-1.png" alt-text="Screenshot showing kubectl commands via GitHub Copilot for Azure." lightbox="./media/aks-extension/ghcopilot-for-azure-aks/aks-gh-chat-kubectl-generation-1.png":::

You can generate various Kubectl commands to manage your AKS clusters without needing to remember complex command syntax. This makes cluster management more accessible, especially for those who may not be Kubernetes experts. Quickly generating the necessary commands helps you perform cluster operations more efficiently, saving time and effort.

You can generate various Kubectl commands for your AKS cluster using these prompts:

 * [@azure] list all services for my AKS cluster
 * [@azure] kubectl command to get deployments with at least 2 replicas in AKS cluster
 * [@azure] get me all services in my AKS cluster with external IPs
 * [@azure] what is the kubectl command to get pod info for my AKS cluster?
 * [@azure] Can you get kubectl command for getting all API resources


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
[GitHub Copilot]: https://github.com/features/copilot
[GitHub Copilot for Azure]: https://github.com/microsoft/GitHub-Copilot-for-Azure

