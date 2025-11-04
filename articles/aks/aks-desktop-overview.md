---
title: AKS desktop overview
description: Learn how to use AKS desktop to deploy and manage workloads on Azure Kubernetes Service (AKS) with a guided, self-service experience.
ms.subservice: aks-developer
author: qpetraroia
ms.topic: overview
ms.date: 11/04/2025
ms.author: qpetraroia
# Customer intent: As a developer, I want to use AKS desktop to deploy and manage applications on Azure Kubernetes Service without needing deep Kubernetes expertise, so that I can accelerate time to business value.
---

# AKS desktop overview

AKS desktop delivers an application-focused experience for deploying and managing workloads on Azure Kubernetes Service (AKS). It accelerates time to business value by providing a guided, self-service user experience (UX) built on supported AKS features, best practices, and open-source Headlamp. Designed to work within your existing environment and tools, it enables team collaboration through role-based access control (RBAC) while abstracting complexity without removing control.

> [!NOTE]
> AKS desktop is in early stages of public preview. During the public preview, AKS desktop might undergo design changes, add, or delete additional features. If you're interested in shaping the AKS desktop experience, engage with the engineers and product team at [aka.ms/aks/aks-desktop](https://aka.ms/aks/aks-desktop).

## Why AKS desktop?

It's common for Kubernetes users to express frustration with how hard application development can be. From deploying apps and tuning configurations to finding the right logs and setting up proper monitoring, there are plenty of small but constant pain points that add up fast. What was supposed to be an exciting path toward modernizing your stack often turns into a cycle of hiring specialized talent, spending more, and burning hours learning proprietary tools that seem to change every few months. And after all that effort, you do eventually see business value, but at an increasingly higher cost and a slower time to value.

To fix these problems, we created AKS desktop, an application centric UI experience built on top of open-source Headlamp. Our goal with AKS desktop is simple: provide faster time to business value by building on top of AKS best practices and configurations to abstract but not remove Kubernetes.

AKS desktop provides the following benefits:

- **Add existing clusters into AKS desktop** - Easily sing in or sign out of your Azure account and import existing AKS clusters into AKS desktop through a simple UI.

- **Deploy applications without needing to focus on writing detailed Kubernetes manifests**:

  - Guided deployment wizard
  - Automatically generated Kubernetes manifests aligned to AKS best practices compatible with AKS Automatic

- **View and manage applications from an app centric UI** - Easy to understand UI allowing you to focus directly on your applications, with an emphasis on:

  - General application health
  - Detailed metrics and logs for monitoring
  - Viewing and editing application scaling properties
  - Kubernetes resource troubleshooting

- **Multi-cloud capabilities** - View and access Kubernetes clusters across any cloud.

- **Collaboration: User and resource management**:

  - Teams can view the same project
  - UI that honors RBAC roles enabling persona scoped experiences

### AKS desktop limitations

AKS desktop is optimized for AKS Automatic clusters. While standard SKU clusters work in AKS desktop, you might not see the full benefits of the project view and day 2 capabilities.

## What are Projects?

In AKS desktop, a Project is linked directly by default to a [Kubernetes namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/), which is a collection of Kubernetes resources for organizing deployed applications or workloads. Projects are meant to simplify the idea around Kubernetes namespaces and Kubernetes concepts.

In upcoming releases, AKS desktop introduces support for "AKS projects" based on [AKS Managed Namespace](../aks/concepts-managed-namespaces.md). This enhancement expands to include additional Azure resources, such as Azure Container Registry, enabling you to view all resources related to your application within a unified interface.

A project can be made up of one or more applications. For this preview, we recommend you have one application per project. When you deploy an app into a project through AKS desktop, you're greeted with the project overview screen that includes all the tools you need for day 2 operations.

## What is the project overview screen (day 2 operations)?

Once you deploy an application to a project through AKS desktop, you're greeted with the Project Overview screen. The Project Overview screen is an overview of your application highlighting the most important parts that matter to application developers. With these tools at your disposal, the Project Overview screen is your centralized control hub, giving you visibility, insights, and direct actions to manage, monitor, and optimize your application. These features are:

| Feature | Description |
|--|--|
| **Kubernetes resources** | View all Kubernetes resources deployed in your project, including workloads and network configuration. |
| **Access** | Grant or remove access to your project. |
| **Map** | Visualize how Kubernetes resources in your project interact, showing data flow between deployments and services. |
| **Logs** | Access streaming logs for your application. |
| **Monitoring** | Monitor application health and status with integrated dashboards. |
| **Metrics** | View detailed metrics such as CPU, memory, and resource usage for your application. |
| **Scaling** | Configure application scaling using Horizontal Pod Autoscaler (HPA) or manual settings. |
| **Environment variables** | Manage environment variables for your application. |

## Next steps

Learn how to [Deploy an application via AKS desktop (Preview)](aks-desktop-deploy-app.md)
