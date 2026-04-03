---
title: AKS desktop for Azure Kubernetes Service (AKS) (preview)
description: Learn about AKS desktop, an application-focused experience for deploying and managing workloads on Azure Kubernetes Service (AKS) that accelerates time to business value.
ms.subservice: aks-developer
ms.service: azure-kubernetes-service
ms.editor: schaffererin
author: qpetraroia
ms.topic: overview
ms.date: 11/19/2025
ms.author: alalve
# Customer intent: As a developer, I want to use AKS desktop to deploy and manage applications on Azure Kubernetes Service (AKS) without needing deep Kubernetes expertise, so that I can accelerate time to business value.
---

# AKS desktop for Azure Kubernetes Service (AKS) (preview)

**Applies to**: :heavy_check_mark: [AKS Automatic clusters](intro-aks-automatic.md)

AKS desktop delivers an application-focused experience for deploying and managing workloads on Azure Kubernetes Service (AKS). It accelerates time to business value by providing a guided, self-service user experience (UX) built on supported AKS features, best practices, and open-source [Headlamp](https://headlamp.dev/). AKS desktop works within your existing environment and tools, enabling team collaboration through role-based access control (RBAC) while simplifying Kubernetes management.

To install the preview build of AKS desktop, see the [AKS desktop GitHub repository](https://github.com/Azure/aks-desktop/releases).

## Benefits of AKS desktop

AKS desktop provides the following benefits:

- **Simplified application deployment**: Guided deployment wizard and automatically generated Kubernetes manifests aligned to AKS best practices compatible with AKS Automatic.
- **Application-centric management**: Focus on managing your applications rather than individual Kubernetes resources. View insights into general application health, detailed metrics and logs for monitoring, application scaling properties, and Kubernetes resource troubleshooting.
- **Multi-cloud capabilities**: View and access Kubernetes clusters across any cloud.
- **kubeconfig management**: Sign in to your Azure account and seamlessly merge cluster credentials into your local kubeconfig file, making it accessible for use with the CLI.
- **User and resource management collaboration**: Use RBAC to manage user access to [Projects](#about-projects-in-aks-desktop) and clusters.
- **Add existing clusters into AKS desktop**: Sign in and out of your Azure account and import existing AKS clusters into AKS desktop.

## AKS desktop cluster support

AKS desktop is optimized for [AKS Automatic clusters](intro-aks-automatic.md). While AKS Standard SKU clusters work in AKS desktop, you might not see the full benefits.

## About Projects in AKS desktop

The **Projects** feature simplifies Kubernetes management by grouping related resources, such as workloads, services, and configurations, into logical units. This approach streamlines navigation, improves visibility, and supports teamwork by providing an application-focused view across namespaces and clusters.

In AKS desktop, AKS managed Projects are directly linked by default to an [AKS managed namespace](concepts-managed-namespaces.md), which is a way to logically isolate workloads and teams within a cluster. This feature enables administrators to enforce resource quotas, apply network policies, and manage access control at the namespace level. A Project can consist of one or more applications.

For more information, see [Headlamp's open-source documentation](https://headlamp.dev/docs/latest/learn/projects).

## About the Project Overview screen in AKS desktop

Once you deploy an application to a Project through AKS desktop, you gain access to the **Project Overview** screen. The Project Overview screen is your centralized control hub, giving you visibility, insights, and direct actions to manage, monitor, and optimize your application.

:::image type="content" source="./media/aks-desktop-app/aks-desktop-app-project-overview.png" alt-text="Screenshot of the Project Overview screen in AKS desktop." lightbox="./media/aks-desktop-app/aks-desktop-app-project-overview.png":::

The following table describes the key features available in the Project Overview screen:

| Feature | Description |
| ------- | ----------- |
| **Kubernetes resources** | View all Kubernetes resources deployed in your Project, including workloads and network configuration. |
| **Access** | Grant or remove access to your Project. |
| **Map** | Visualize how Kubernetes resources in your Project interact, showing data flow between deployments and services. |
| **Logs** | Access streaming logs for your application. |
| **Metrics** | View detailed metrics such as CPU, memory, and resource usage for your application. |
| **Scaling** | Configure application scaling using Horizontal Pod Autoscaler (HPA) or manual settings. |
| **Environment variables** | Manage environment variables for your application. |

## Related content

- [Set up permissions for AKS desktop (preview)](aks-desktop-permissions.md)
- Learn how to [Deploy an application with AKS desktop (preview)](aks-desktop-app.md)
- [Use the cluster autoscaler in AKS](cluster-autoscaler.md)
