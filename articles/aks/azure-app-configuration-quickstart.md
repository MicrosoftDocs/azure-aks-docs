---
title: Configure workload with Azure App Configuration in Azure Kubernetes Service
description: Learn how to configure the workload in Azure Kubernetes Service (AKS) with Azure App Configuration.
author: RichardChen820
ms.author: junbchen
ms.topic: article
ms.custom: devx-track-azurecli
ms.subservice: aks-developer
ms.date: 10/10/2024
---

# Configure workload with Azure App Configuration in Azure Kubernetes Service

## Prerequisites

* An App Configuration store. [Create a store](/azure/azure-app-configuration/quickstart-azure-app-configuration-create#create-an-app-configuration-store).
* An Azure Kubernetes Service (AKS) cluster. [Create an AKS cluster](/azure/aks/tutorial-kubernetes-deploy-cluster#create-a-kubernetes-cluster).
* A running workload in Azure Kubernetes Service (AKS) cluster. If you don't have one, you can [create an demo application running in AKS](/azure/azure-app-configuration/quickstart-azure-kubernetes-service#create-an-application-running-in-aks).

## Configure workload with Azure App Configuration

### Create a service connection to App Configuration store

Create a service connection between your AKS cluster and your App Configuration store using Microsoft Entra Workload Identity.

1. In the [Azure portal](https://portal.azure.com), navigate to your AKS cluster resource.

1. Select **Settings** > **Service Connector (Preview)** > **Create**.

1. On the Basics tab, configure the following settings:
   
   - **Kubernetes namespace**: Specify the namespace you'd like to use.
   - **Service type**: Select App Configuration.
   - Check the checkbox **Enable App Configuration Extension on Kubernetes**
   - **Connection name**: Use the connection name provided by Service Connector or enter your own connection name.
   - **Subscription**: Select the subscription of your App Configuration store.
   - **App Configuration**: Select your App Configuration store.

    ![Screenshot showing create connection](./media/azure-app-configuration/create-connection.png)

1. Select **Next: Authentication**. On the **Authentication** tab, select Workload Identity and choose one User assigned managed identity.

1. Select **Next: Networking** > **Next: Review + create**

1. Waiting for the validation to pass, select **Create**.

1. Waiting for the service connection to be created.

### Configure workload to use App Configuration

Now that you created a connection between your AKS cluster and the App Configuration store, you need to use the connection to download the configuration data from the App Configuration store into a configMap and configure your workload with it.

1. In the [Azure portal](https://portal.azure.com), navigate to your AKS cluster resource and select **Service Connector (Preview)**.

1. Select the newly created connection, and then select **Yaml snippet**.

1. On the **AzureAppConfigurationProvider** tab，configure the following settings:
   
   - **Using configuration as**: Select how you want to use the configuration data in your workload. You can use it as a mounted file or environment variables.
   - If you select **Mounted file**, you need to provide the file type and file name
   - **Selector**: Select the configuration key-value pairs to be used from the App Configuration store.

1. An **AzureAppConfigurationProvider** YAML snippet is auto generated based on your above input. Click **Apply** to apply it to your AKS cluster. It will create a ConfigMap in your AKS cluster with the selected configuration data from the App Configuration store.

    ![Screenshot showing AzureAppConfigurationProvider](./media/azure-app-configuration/yaml-snippet-provider.png)

1. Click **Next**，on the **Workload** tab, configure the following settings:
   
   - If you select **Mounted file**, you need to provide the file mount path.
   - **Kubernetes Workload**: select an existing Kubernetes workload. The snippet includes highlighted sections showing the newly generated configMap will be used as mounted file on your selected workload. Select **Apply** to update the workload.

## Next Steps

Azure App Configuration provides many features, e.g. dynamic refresh configuration data, to help you manage your application settings and feature flags. Refer to the [Azure App Configuration Kubernetes Provider reference](/azure/azure-app-configuration/reference-kubernetes-provider) for more information.