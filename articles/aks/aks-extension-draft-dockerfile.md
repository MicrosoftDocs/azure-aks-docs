---
title: Create a Dockerfile using Automated Deployments in the Azure Kubernetes Service (AKS) extension for Visual Studio Code
description: Learn how to create a Dockerfile using Automated Deployments in the Azure Kubernetes Service (AKS) extension for Visual Studio Code.
author: qpetraroia
ms.topic: how-to
ms.date: 07/15/2024
ms.author: qpetraroia
ms.service: azure-kubernetes-service
# Customer intent: As a developer using Visual Studio Code, I want to create a Dockerfile using Automated Deployments in the AKS extension, so that I can easily define the configuration for my application's Docker image for consistent deployment in Kubernetes environments.
---

# Create a Dockerfile using Automated Deployments in the Azure Kubernetes Service (AKS) extension for Visual Studio Code

In this article, you learn how to create a Dockerfile using Automated Deployments in the Azure Kubernetes Service (AKS) extension for Visual Studio Code. A Dockerfile is essential for Kubernetes because it defines the blueprint for creating Docker images. These images encapsulate your application along with its dependencies and environment settings, ensuring consistent deployment across various environments.

## Prerequisites

Before you begin, make sure you have the following resources:

* An active folder with code open in Visual Studio Code.
* The Azure Kubernetes Service (AKS) extension for Visual Studio Code downloaded. For more information, see [Install the Azure Kubernetes Service (AKS) extension for Visual Studio Code][install-aks-vscode].

## Create a Dockerfile using the Azure Kubernetes Service (AKS) extension

You can access the screen to create a Dockerfile using the command palette or the explorer view.

### [Command palette](#tab/command-palette)

1. On your keyboard, press `Ctrl+Shift+P` to open the command palette.
2. In the search bar, search for and select **Automated Deployments: Create a Dockerfile**.
3. Enter the following information:

    * **Location**: Select a location where you want to save your Dockerfile.
    * **Programming language**: Select the programming language your app is written in.
    * **Programming language version**: Select the programming language version.
    * **Application Port**: Select the port.
    * **Cluster**: Select the port in which your application listens to for incoming network connections.

4. Select **Create**.

### [Explorer view](#tab/explorer-view)

1. Right click on the explorer pane where your active folder is open and select **Create a Dockerfile**.
2. Enter the following information:

    * **Location**: Select a location where you want to save your Dockerfile.
    * **Programming language**: Select the programming language your app is written in.
    * **Programming language version**: Select the programming language version.
    * **Application Port**: Select the port.
    * **Cluster**: Select the port in which your application listens to for incoming network connections.

3. Select **Create**.

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

