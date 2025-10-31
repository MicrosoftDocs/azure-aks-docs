---
title: Deploy an application via AKS desktop
description: Learn how to deploy and manage applications on Azure Kubernetes Service (AKS) using the AKS desktop guided deployment wizard.
ms.subservice: aks-devx
ms.custom: devx
author: qpetraroia
ms.topic: how-to
ms.date: 10/30/2025
ms.author: qpetraroia
# Customer intent: As a developer, I want to deploy an application to Azure Kubernetes Service using AKS desktop, so that I can quickly deploy and manage my containerized applications without writing detailed Kubernetes manifests.
---

# Deploy an application to AKS desktop

In this article, you learn how to deploy an application via AKS desktop and benefit from the application centric view.

## Prerequisites

* An Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).
* AKS desktop downloaded. You can download AKS desktop via:
  * Brew _________
  * AKS desktop GitHub
    * Windows
    * Linux
    * Mac
* An Azure Container Registry with your application image that you want to deploy
* [AKS Automatic clusters][AKS Automatic clusters]

## Deploy and manage an application

### Open AKS desktop

The first time you open up AKS desktop, you need to log into your Azure account. To log in, click the **Azure Account** tab bar button on the left hand side of the application.

Once logged in, you have the ability to add clusters that you have access to into AKS desktop.

After you have merged the cluster that you want to deploy your app into, open up the projects tab and either use an existing project or create a new project.

### Create a new project

> [!NOTE]
> We recommend that you always create a new project when deploying a new application.

If you wish to deploy your app into a new project, select **Create project** and then **New project**. Fill out the project name, the cluster, and the namespace that you wish to assign the project to. When you create a project on a cluster, it's visible to all other users who have access to the namespace. This is because the project is based on a namespace, and that namespace has a specific label.

### Deploy an application into the project

1. Click into the project you created and select **Deploy Application** in the top right corner.

### Deploy app: Source

1. There are two sources you can pick from: **Container image** or **K8s YAML** directly. Select **Container Image**, scroll down, and press **Next**.

### Deploy app: Configure container image

1. Paste in your container image into the **Container Image** textbox. It must be in the format `<YOUR ACR>.azurecr.io/<YOUR IMAGE NAME>:<YOUR IMAGE TAG>`.

> [!NOTE]
> Images cannot use the 'latest' tag as this will result in best practice violation on AKS Automatic.

### Deploy app: Configure your app

Here you can select your app properties. This page has the following configuration options: 

* **Deployment Name**: The name of your deployment.
* **Resource Limits**: The resource/request limits of your application.
* **Service Type**: The option to choose between Cluster IP, Loadbalancer or Nodeport.
* **Target Port**: The port your application listens on.
* **Environment Variables**: The option to add environment variables to your deployment.
* **Horizontal Pod Autoscaler**: The option to enable Horizontal Pod Autoscaler (HPA) on your application.


### Deploy app: Health checks and advanced configuration

These are default settings needed to deploy to AKS Automatic. We reccomend not changing these settings as your deployment may be blocked by AKS Automatic's deployment safeguards.

### Deploy app: Preview and deploy

1. You can check the YAML and also click **Deploy**. This will do a `kubectl apply` to the cluster directly.
2. Click **Deploy to AKS**. The app should now deploy.
3. Click **Close** on the next screen.

## Manage the app

The key benefit to AKS desktop is to see your application resources, health status, and resource quota in one screen. The tabs on the screen give you more detail of each individual tile.

### Manage the app: Resources

View all associated application workload resources. In this section you will also see other resources such as Network, Configuration, and Discovery. These are added in by the Namespace and the AKS desktop generated Kubernetes YAML template.

### Manage the app: Map

The map screen shows the resource dependencies, useful for quick understanding and troubleshooting.

### Manage the app: Info

View and update the project networking policies and compute quota.

### Manage the app: Logs

View live application logs for workload deployments.

### Manage the app: Metrics

View live metrics per workload deployment.

### Manage the app: Scaling

View scaling and CPU metrics for your application. This can be configured to switch between manual scaling and Horizontal Pod Autoscaler (HPA).

## Next steps

* Learn more about [AKS desktop overview](aks-desktop.md)
* Explore [AKS Automatic clusters](auto-upgrade-cluster.md)
