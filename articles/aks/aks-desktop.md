---
title: AKS desktop - overview
description: Learn how to use AKS desktop to deploy and manage workloads on Azure Kubernetes Service (AKS) with a guided, self-service experience.
ms.subservice: aks-devx
ms.custom: devx
author: qpetraroia
ms.topic: overview
ms.date: 10/30/2025
ms.author: qpetraroia
# Customer intent: As a developer, I want to use AKS desktop to deploy and manage applications on Azure Kubernetes Service without needing deep Kubernetes expertise, so that I can accelerate time to business value.
---

# AKS desktop - overview

AKS desktop delivers an application focused experience for deploying and managing workloads on Azure Kubernetes Service. It accelerates time to business value by providing a guided, self-service UX built on supported AKS features, best practices, and open-source HeadLamp. Designed to work within your existing environment and tools, it enables team collaboration through RBAC while abstracting complexity without removing control.

This article shows you how to set up AKS desktop and enable it for feature development.

> [!NOTE]
> AKS desktop is in early stages of public preview. During the public preview, AKS desktop may undergo design changes, add/delete additional features, and more. If you're interested in shaping the AKS desktop experience, engage with the engineers and product team at [aka.ms/aks/aks-desktop](https://aka.ms/aks/aks-desktop).

## Why AKS desktop?

It's common for Kubernetes users to express frustration with how hard application development can be. From deploying apps and tuning configurations to finding the right logs and setting up proper monitoring, there are plenty of small but constant pain points that add up fast. What was supposed to be an exciting path toward modernizing your stack often turns into a cycle of hiring specialized talent, spending more, and burning hours learning proprietary tools that seem to change every few months. And after all that effort, you do eventually see business value, but at an increasingly higher cost and a slower time to value.

To fix these problems, we created AKS desktop, an application centric UI experience built on top of open-source Headlamp. Our goal with AKS desktop is simple: provide faster time to business value by building on top of AKS best practices and configurations to abstract but not remove Kubernetes.

AKS desktop provides the following benefits:

* **Add existing clusters into AKS desktop**: Easily login/logout of your Azure account and import existing AKS clusters into AKS desktop through a simple UI.
* **Deploy applications without needing to focus on writing detailed Kubernetes manifests**:
  * Guided deployment wizard
  * Automatically generated Kubernetes manifests aligned to AKS best practices compatible with AKS Automatic
* **View and manage applications from an app centric UI**: Easy to understand UI allowing you to focus directly on your applications, with an emphasis on:
  * General application health
  * Detailed metrics and logs for monitoring
  * View/edit application scaling properties
  * Kubernetes resource troubleshooting
* **Multi-cloud capabilities**: View and access Kubernetes clusters across any cloud.
* **Collaboration: User and resource management**:
  * Teams can view the same project
  * UI that honors RBAC roles enabling persona scoped experiences

## Prerequisites

* An Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).
* Download AKS desktop via:
  * Brew _________
  * AKS desktop GitHub
    * Windows
    * Linux
    * Mac
  * Coming soon! Windows Store, Apple App Store
* An Azure Container Registry with your application images
* AKS Automatic cluster

## Limitations

* AKS desktop is optimized for AKS Automatic clusters. While standard SKU clusters will work in AKS desktop, you may not see the full benefits of the project view and day 2 capabilities.

## What are projects?

> [!NOTE]
> Have questions? Talk to the team at [aka.ms/aks/aks-desktop](https://aka.ms/aks/aks-desktop).

In AKS desktop a Project is linked directly by default to a [Kubernetes namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/), which is a collection of Kubernetes resources for organizing deployed applications or workloads. Projects are meant to simplify the idea around Kubernetes namespaces and Kubernetes concepts.

In the future, AKS desktop will release "AKS projects" built on top of [AKS Managed Namespace](https://learn.microsoft.com/azure/aks/concepts-managed-namespaces), with plans to extend it to include more Azure resources such as an Azure Container Registry, so you can see all the resources applicable to your application in a single UI.

A project can be made up of one or more applications. For the preview we recommend you have one application per project. When you deploy an app into a project through AKS desktop you are greeted with the project overview screen, a screen that includes all the tools you need for day 2 operations.

## What is the project overview screen (day 2 operations)?

Once you deploy an application to a project through AKS desktop, you will be greeted to the project overview screen. The project overview screen is an overview of your application highlighting the most important parts that matter to application developers. These are:

* **Kubernetes resources**: All the Kubernetes resources deployed into your project. These are the workloads, the network configuration, etc.
* **Access**: Grant and remove access to your project.
* **Map**: A map of your Kubernetes resources in your project, showing how data flows between deployments, services, etc.
* **Logs**: View streaming logs of your application.
* **Metrics**: View live metrics per workload deployment.
* **Scaling**: Set your application to scale via HPA or manually.
* **Environment variables**: Add environment variables to your application.

With the above tools at your disposal the Project Overview screen is your centralized control hub, giving you visibility, insights, and direct actions to manage, monitor, and optimize your application.

## Next steps

Once AKS desktop is installed, learn how to deploy an app, set up a multi-cloud environment, and security best practices on AKS desktop.
