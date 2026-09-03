---
title: Create an AKS on bare metal cluster using the Azure portal (preview)
description: Learn how to deploy an Azure Kubernetes Service (AKS) cluster on bare metal using the Azure portal.
ms.topic: how-to
ms.date: 09/01/2026
author: SummerSmith
ms.author: sumsmith
ms.custom: bare-metal
---

# Create an AKS on bare metal cluster using the Azure portal (preview)

> [!IMPORTANT]
> Azure Kubernetes Service on bare metal is currently in preview. See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability. Azure Kubernetes Service on bare metal previews are partially covered by customer support on a best-effort basis.

This article shows you how to create an Azure Kubernetes Service (AKS) cluster on bare metal using the Azure portal.

## Prerequisites

Complete all [system requirements and prerequisites](aks-bare-metal-system-requirements.md) before you begin.

## Step 1: Navigate to AKS on bare metal

1. Sign in to the [Azure portal](https://portal.azure.com).
1. In the search bar, enter **Azure Arc** and select it from the results.
1. In the left menu, expand **Operations** and select **Machine provisioning (preview)**.
1. Under **3. Deploy cluster**, select **Deploy** > **AKS for Azure Local on Linux**.

   :::image type="content" source="../media/aks-bare-metal-create-cluster-portal/create-cluster.png" alt-text="Screenshot of Azure Arc Machine provisioning to deploy a cluster for AKS for Azure Local on Linux." lightbox="../media/aks-bare-metal-create-cluster-portal/create-cluster.png":::

## Step 2: Configure basics

On the **Basics** tab, configure the following settings:

| Setting | Value |
|---------|-------|
| Site | Select your site. This selection automatically populates your subscription. |
| Resource group | Select or create a resource group in **East US**. |
| Cluster name | Enter a name for your cluster. Name must be 1-27 characters long, start and end with a letter or number, and can only contain letters, numbers, hyphens, or underscores. |
| Kubernetes version | Select **1.34.2** or **1.34.3**. |
| Edge machine | Select **Add machines** to view available machines within your selected site, and then select the machine to deploy on. |

## Step 3: Configure access

On the **Access** tab, configure the following settings:

| Setting | Value |
|---------|-------|
| Admin group object IDs | Enter your Microsoft Entra ID group object ID for cluster admin access. |

## Step 4: Configure networking

On the **Networking** tab, configure the following settings:

| Setting | Value |
|---------|-------|
| Control plane IP | (Optional) If you leave this field blank, the control plane IP defaults to the host machine's IP address. Only specify a custom IP if you need the control plane to be reachable on a different address than the host machine. If provided, it must be in the same subnet as your edge machine. |

> [!WARNING]
> If you specify a custom control plane IP and your machine uses DHCP, you must reserve the control plane IP address so it remains permanently assigned to this machine. If the control plane IP changes, the Kubernetes cluster becomes unreachable and must be redeployed.

## Step 5: Configure integrations (optional)

On the **Integrations** tab, you can enable Azure Monitor and other integrations for your cluster. This step is optional.

## Step 6: Configure tags (optional)

On the **Tags** tab, you can add name/value tags to organize your resources for billing and management. This step is optional.

## Step 7: Review and create

1. Select **Review + create**.
1. Review your configuration settings.
1. Select **Create**.

Deployment typically takes **20 minutes**. You can monitor progress on the deployment page.

## Step 8: Verify deployment

After the deployment completes:

1. Navigate to your resource group.
1. Select the AKS cluster resource.
1. Verify that the status shows **Succeeded**.

## Next steps

- [Connect to your cluster](aks-bare-metal-connect-to-cluster.md)
- [Deploy an application](aks-bare-metal-deploy-application.md)
