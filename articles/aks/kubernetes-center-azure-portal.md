---
title: Create and Manage Kubernetes resources in the Azure portal with Kubernetes Center (preview)
description: Learn how to create and manage your Kubernetes resources directly in the Azure portal using Kubernetes Center (preview), which centralizes creation, management, and monitoring of your Kubernetes clusters.
author: Harshaa
ms.author: schaffererin
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 11/04/2025
# Customer intent: "As a DevOps engineer, I want to manage my Kubernetes resources more efficiently in the Azure portal, so that I can streamline my workflows and improve productivity."
---

# Create and manage Azure Kubernetes Service (AKS) resources in the Azure portal with Kubernetes Center (preview)

Kubernetes Center (preview) in the Azure portal centralizes and simplifies AKS resource creation and management. This feature provides a unified experience across all your AKS resources and delivers intelligent insights and streamlined workflows, allowing platform teams to maintain control while enabling developers to move quickly and confidently.

This article shows you how to get started with Kubernetes Center (preview) in the Azure portal, including how to access it, explore its features, and leverage its capabilities to enhance your Kubernetes management experience.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Key benefits of Kubernetes Center (preview)

Kubernetes Center (preview) offers several key benefits, including:

- **Actionable insights**: Identify security vulnerabilities, cluster alerts, and compliance gaps in one place.
- **Streamlined management**: Use a unified interface that integrates [AKS](./what-is-aks.md), [AKS Automatic](./intro-aks-automatic.md), [Azure Kubernetes Fleet Manager](/azure/kubernetes-fleet/overview), and [managed namespaces](./managed-namespaces.md).
- **Centralized learning and support**: Access relevant documentation, quickstarts, and in-context help.

## Prerequisites

To use Kubernetes Center (preview), ensure you have the following prerequisites:

- An active Azure subscription. If you don't have one, you can [create a free account](https://azure.microsoft.com/free/).

## Access quickstarts and documentation

1. From the [Azure portal](https://portal.azure.com/) home page, search for and select **Kubernetes center**.
1. On the **Overview** page, select **Browse quickstarts**.

    :::image type="content" source="./media/kubernetes-center-azure-portal/kubernetes-center-browse-quickstarts.png" alt-text="Screenshot showing the Browse quickstarts option on the Overview page of the Kubernetes center in the Azure portal." lightbox="./media/kubernetes-center-azure-portal/kubernetes-center-browse-quickstarts.png":::

1. On the **Kubernetes center | Quickstarts** page, browse the available quickstarts and select one to view detailed instructions and documentation.

    :::image type="content" source="./media/kubernetes-center-azure-portal/kubernetes-center-quickstarts-page.png" alt-text="Screenshot showing the Quickstarts page in the Kubernetes center of the Azure portal." lightbox="./media/kubernetes-center-azure-portal/kubernetes-center-quickstarts-page.png":::

## Create resources

1. From the [Azure portal](https://portal.azure.com/) home page, search for and select **Kubernetes center**.
1. On the **Overview** page, select **Create**.

    :::image type="content" source="./media/kubernetes-center-azure-portal/kubernetes-center-create.png" alt-text="Screenshot showing the Create option on the Overview page of the Kubernetes center in the Azure portal." lightbox="./media/kubernetes-center-azure-portal/kubernetes-center-create.png":::

1. Select the type of resource you want to create from the available options:

    - AKS Cluster
    - AKS Automatic Cluster
    - Managed Kubernetes Namespace
    - Kubernetes Fleet Manager
    - Deploy your application

    :::image type="content" source="./media/kubernetes-center-azure-portal/kubernetes-center-resources.png" alt-text="Screenshot showing the available resource options in the Kubernetes center of the Azure portal." lightbox="./media/kubernetes-center-azure-portal/kubernetes-center-resources.png":::

1. Follow the prompts to configure your resource.
1. Select **Review + create** to proceed with the creation.

## Manage clusters and workloads

The **Overview** page provides cluster health and workload performance details, along with security alerts and upgrade recommendations.

:::image type="content" source="./media/kubernetes-center-azure-portal/kubernetes-center-overview-page.png" alt-text="Screenshot showing the Overview page of the Kubernetes center in the Azure portal." lightbox="./media/kubernetes-center-azure-portal/kubernetes-center-overview-page.png":::

## Next steps

For more information about monitoring and managing your AKS clusters, see the following articles:

- [Monitor Azure Kubernetes Service (AKS)](./monitor-aks.md)
- [Monitor Azure Kubernetes Service (AKS) control plane metrics](./control-plane-metrics-monitor.md)
- [Add-ons, extensions, and other integrations with Azure Kubernetes Service (AKS)](./integrations.md)
