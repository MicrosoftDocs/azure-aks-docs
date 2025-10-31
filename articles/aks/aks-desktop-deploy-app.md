---
title: Deploy an application via AKS desktop
description: Learn how to deploy and manage applications on Azure Kubernetes Service (AKS) using the AKS desktop guided deployment wizard.
ms.subservice: aks-developer
author: qpetraroia
ms.topic: how-to
ms.date: 10/31/2025
ms.author: qpetraroia
# Customer intent: As a developer, I want to deploy an application to Azure Kubernetes Service using AKS desktop, so that I can quickly deploy and manage my containerized applications without writing detailed Kubernetes manifests.
---

# Deploy an application to AKS desktop

This article guides you through deploying an application using AKS desktop, enabling you to manage your containerized workloads with an intuitive, application-centric interface.

> [!NOTE]
> AKS desktop is in early stages of public preview. During the public preview, AKS desktop may undergo design changes, add/delete additional features, and more. If you're interested in shaping the AKS desktop experience, engage with the engineers and product team at [aka.ms/aks/aks-desktop](https://aka.ms/aks/aks-desktop).

## Prerequisites

- An Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).

- AKS desktop downloaded. You can download AKS desktop via:

  - Brew _________

  - AKS desktop GitHub

    - Windows

    - Linux

    - Mac

- An Azure Container Registry with your application image that you want to deploy

- [AKS Automatic clusters][AKS Automatic clusters]

## Deploy and manage an application

### Open AKS desktop

The first time you open up AKS desktop, you need to sign into your Azure account. To sign in, select the **Azure Account** tab bar button on the left hand side of the application. Once logged in, you have the ability to add clusters that you have access to into AKS desktop.

After merging the cluster you want to deploy your app to, open the **Projects** tab. You can choose an existing project or create a new one for your deployment.

### Create a new project

> [!NOTE]
> We recommend that you always create a new project when deploying a new application.

If you wish to deploy your app into a new project, select **Create project** and then **New project**. Fill out the following information you wish to assign the project to:

- **Project name**

- **Cluster**

- **Namespace**

When you create a project on a cluster, it's visible to all other users who have access to the namespace. This is because the project is based on a namespace, and that namespace has a specific label.

### Deploy an application into the project

1. Select the project you created and then select **Deploy Application** in the top right corner.

1. There are two sources you can select from:

   - **Container Image**

   - **K8s YAML**

   Select **Container Image**, scroll down, and then select **Next**.

1. Paste in your container image into the **Container Image** textbox. It must be in the format `<YOUR ACR>.azurecr.io/<YOUR IMAGE NAME>:<YOUR IMAGE TAG>`.

   > [!NOTE]
   > Images can't use the "latest" tag as this results in best practice violation on AKS Automatic.

You can then select your app properties. This table provides the following configuration options:

| Option | Description |
|--|--|
| **Deployment Name** | The name of your deployment. |
| **Resource Limits** | The resource or request limits of your application. |
| **Service Type** | Choose between: <br><br><li> Cluster IP <li> Load balancer <li> Node port </li> |
| **Target Port** | The port your application listens on. |
| **Environment Variables** | Add environment variables to your deployment. |
| **Horizontal Pod Autoscaler** | Enable Horizontal Pod Autoscaler (HPA) on your application. |

### Deploy app: Health checks and advanced configuration

These are **default** settings needed to deploy to AKS Automatic. AKS Automatic deployment safeguards might block your deployment if you change these settings.

### Deploy app: Preview and deploy

1. You can check the YAML and also select **Deploy**. This performs the `kubectl apply` action to the cluster directly.

1. Select **Deploy to AKS**. The app should deploy.

1. On the next screen, select **Close**.

## View tile details

The key benefit to AKS desktop is to see your application resources, health status, and resource quota in one screen. The tabs on the screen provide more detail of each individual tile:

| Tile | Description |
|--|--|
| **Resources** | View all associated application workload resources, including **Network**, **Configuration**, and **Discovery** added by Namespace and YAML. |
| **Map** | Visualize resource dependencies for quick understanding and troubleshooting. |
| **Info** | View and update project networking policies and compute quota. |
| **Logs** | View live application logs for workload deployments. |
| **Metrics** | View live metrics per workload deployment. |
| **Scaling** | View scaling and CPU metrics. Configure manual scaling or Horizontal Pod Autoscaler (HPA). |

## Next steps

- Learn more about [AKS desktop overview](aks-desktop.md)
- Explore [AKS Automatic clusters](auto-upgrade-cluster.md)
