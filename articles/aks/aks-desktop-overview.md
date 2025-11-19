---
title: AKS desktop overview (Preview)
description: Learn how to use AKS desktop to deploy and manage workloads on Azure Kubernetes Service (AKS) with a guided, self-service experience.
ms.subservice: aks-developer
author: qpetraroia
ms.topic: overview
ms.date: 11/18/2025
ms.author: alalve
# Customer intent: As a developer, I want to use AKS desktop to deploy and manage applications on Azure Kubernetes Service without needing deep Kubernetes expertise, so that I can accelerate time to business value.
---

# AKS desktop overview (Preview)

AKS desktop delivers an application-focused experience for deploying and managing workloads on Azure Kubernetes Service (AKS). It accelerates time to business value by providing a guided, self-service user experience (UX) built on supported AKS features, best practices, and open-source [Headlamp][Headlamp]. Designed to work within your existing environment and tools, it enables team collaboration through role-based access control (RBAC) while abstracting complexity without removing control.

You can install [AKS desktop][install AKS desktop] by visiting the official AKS desktop repository. AKS desktop supports the following operating systems:

  - Windows

  - Linux

  - Mac

> [!NOTE]
> AKS desktop is in early stages of public preview. During the public preview, AKS desktop might undergo design changes, add or delete additional features, and more. If you're interested in shaping the AKS desktop experience, need help, or have any questions, engage with the engineers and product team at the official [AKS desktop GitHub repository][AKS desktop GitHub repository].

## Why AKS desktop?

It's common for Kubernetes users to express frustration with how hard application development can be. From deploying apps and tuning configurations to finding the right logs and setting up proper monitoring, there are plenty of small but constant pain points that add up fast. What was supposed to be an exciting path toward modernizing your stack often turns into a cycle of hiring specialized talent, spending more, and burning hours learning proprietary tools that seem to change every few months. And after all that effort, you do eventually see business value, but at an increasingly higher cost and a slower time to value.

To fix these problems, we created AKS desktop, an application centric UI experience built on top of open-source Headlamp. Our goal with AKS desktop is simple: provide faster time to business value by building on top of AKS best practices and configurations to abstract but not remove Kubernetes.

AKS desktop provides the following benefits:

- **Deploy applications without needing to focus on writing detailed Kubernetes manifests**:

  - Guided deployment wizard.

  - Automatically generated Kubernetes manifests aligned to AKS best practices compatible with AKS Automatic.

- **View and manage applications from an app centric UI** - Easy to understand UI allowing you to focus directly on your applications, with an emphasis on:

  - General application health.

  - Detailed metrics and logs for monitoring.

  - Viewing and editing application scaling properties.

  - Kubernetes resource troubleshooting.

- **Multi-cloud capabilities** - View and access Kubernetes clusters across any cloud.

- **Kubeconfig management** - Easily sign into your Azure account and merge your cluster credentials.

- **User and resource management collaboration**:

  - Teams can view the same project.

  - UI that honors RBAC roles enabling persona scoped experiences.

- **Add existing clusters into AKS desktop** - Easily sing in or sign out of your Azure account and import existing AKS clusters into AKS desktop through a simple UI.

## AKS desktop limitations

**AKS desktop is optimized for [AKS Automatic clusters][what-is-aks-automatic]**. While standard SKU clusters work in AKS desktop, you might not see the full benefits of the project view. AKS Automatic includes built-in metrics, observability, and other tools that enable AKS desktop to surface important insights for users.

## What are Projects?

Per Headlamp's documentation:

> "Projects make Kubernetes easier to manage by grouping related resources into a single, application-centric view that is designed with developers in mind. Instead of navigating cluster-wide lists or searching for labels, Projects let you organize workloads across one or more namespaces and even multiple clusters into a logical group. This approach gives developers clarity on their application as a whole, making collaboration, troubleshooting, and onboarding much simpler."

In AKS desktop, an AKS managed project is linked directly by default to an [AKS managed namespace](/articles/aks/concepts-managed-namespaces.md), which is a way to logically isolate workloads and teams within a cluster. This feature enables administrators to enforce resource quotas, apply network policies, and manage access control at the namespace level. A project can be made up of one or more applications. For this preview, we recommend you have one application per Project. If you wish to learn more about the Project concept, visit [Headlamp's open-source documentation][Headlamp docs].

## What is the Project Overview screen?

Once you deploy an application to a project through AKS desktop, you're greeted with the Project Overview screen. The Project Overview screen is an overview of your application highlighting the most important parts that matter to application developers. With these tools at your disposal, the Project Overview screen is your centralized control hub, giving you visibility, insights, and direct actions to manage, monitor, and optimize your application. These features are:

| Feature | Description |
|--|--|
| **Kubernetes resources** | View all Kubernetes resources deployed in your project, including workloads and network configuration. |
| **Access** | Grant or remove access to your project. |
| **Map** | Visualize how Kubernetes resources in your project interact, showing data flow between deployments and services. |
| **Logs** | Access streaming logs for your application. |
| **Metrics** | View detailed metrics such as CPU, memory, and resource usage for your application. |
| **Scaling** | Configure application scaling using Horizontal Pod Autoscaler (HPA) or manual settings. |
| **Environment variables** | Manage environment variables for your application. |

## Join the community and provide feedback for AKS desktop (Preview)

During the preview, formal support for AKS desktop is limited or not available. The best way to get help, report issues, or provide feedback is to engage directly with the engineering team on the [official AKS desktop GitHub repository][AKS desktop GitHub repository].

Whether you have questions, concerns, bug reports, or feature requests, we encourage you to connect with us on GitHub. To provide feedback or report an issue, follow these steps:

1. Visit the [AKS desktop GitHub repository][AKS desktop GitHub repository].
1. Select the **Issues** tab.
1. Select **New Issue**, and select the appropriate issue template.
1. Fill out the required fields for the issue. Then select **Submit new issue** to share your feedback with the team.

## Next steps

- Learn how to [Deploy an application via AKS desktop (Preview)](aks-desktop-app.md)
- Learn about [Managed namespaces (preview)](concepts-managed-namespaces.md)
- [Use the cluster autoscaler in AKS](cluster-autoscaler.md)

<!-- LINKS - external -->
[Headlamp]: https://headlamp.dev/
[Headlamp docs]: https://headlamp.dev/docs/latest/learn/projects
[AKS desktop GitHub repository]: https://github.com/Azure/aks-desktop
[Azure account]: https://azure.microsoft.com/free
[install AKS desktop]: https://github.com/Azure/aks-desktop/releases

<!-- LINKS - internal -->
[what-is-aks-automatic]: ../intro-aks-automatic.md