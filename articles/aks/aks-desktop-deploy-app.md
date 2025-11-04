---
title: Deploy an application via AKS desktop (Preview)
description: Learn how to deploy and manage applications on Azure Kubernetes Service (AKS) using the AKS desktop guided deployment wizard.
ms.subservice: aks-developer
author: qpetraroia
ms.topic: how-to
ms.date: 11/04/2025
ms.author: qpetraroia
# Customer intent: As a developer, I want to deploy an application to Azure Kubernetes Service using AKS desktop, so that I can quickly deploy and manage my containerized applications without writing detailed Kubernetes manifests.
---

# Deploy an application to AKS desktop (Preview)

This article guides you through deploying an application using AKS desktop, enabling you to manage your containerized workloads with an intuitive, application-centric interface.

> [!NOTE]
> AKS desktop is in early stages of public preview. During the public preview, AKS desktop may undergo design changes, add/delete additional features, and more. If you're interested in shaping the AKS desktop experience, engage with the engineers and product team at [aka.ms/aks/aks-desktop][aka.ms/aks/aks-desktop].

## Prerequisites

- You'll need an Azure subscription. If you don't have an Azure subscription, you can create a free [Azure account](https://azure.microsoft.com/free).

- An Azure subscription. If you don't have an Azure subscription, you can create a [free account][free azure account].

- An Azure Container Registry with your application image that you want to deploy.

- Download and install AKS desktop for your specific operating system (OS):

  - Windows

  - Linux

  - Mac

- Brew _________

## Deploy and manage an application

### Open AKS desktop

The first time you open up AKS desktop, you need to sign into your Azure account. To sign in, select the **Azure Account** tab bar button on the left hand side of the application. Once logged in, you have the ability to add clusters that you have access to into AKS desktop.

After merging the cluster you want to deploy your app to, open the **Projects** tab. You can choose an existing project or create a new one for your deployment.

### Create a new Project

> [!NOTE]
> We recommend that you always create a new Project when deploying a new application.

If you wish to deploy your app into a new Project, select **Create Project** and then **AKS managed Project**. Fill out the following information you wish to assign the project to:

- **Project name**

- **Subscription**

- **Cluster**

When you create a project on a cluster, it's visible to all other users who have access to the namespace. This is because the project is based on a namespace, and that namespace has a specific label.

> [!NOTE]
> When creating a new **AKS managed Project**, you'll only be allowed to deploy to AKS Automatic cluster or clusters that are Microsoft Entra Authenticated.

#### New Project: Networking Policies

In the **Networking Policies** tab you can set the networking communications for the managed namespace. If you wish for traffic to flow out of the namespace, set **Ingress**  to **Allow All Traffic**, you can also change this setting later.

#### New Project: Compute Quota

The **Compute Quota** tab allows you to set Quota for the managed namespace. Anytime an application is deployed within the namespace, it isn't able to exceed the limits. You can also change this setting later once the application is deployed.

#### New Project: Access

The **Access** tab allows you to add other developers, operators, and eta to the Project, either as a reader or a contributor.

### Deploy an application into the Project

1. Select the Project you created and then select **Deploy Application** in the top right corner.

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

- Learn more about [AKS desktop overview](aks-desktop-overview.md)
- Explore [AKS Automatic clusters](auto-upgrade-cluster.md)
