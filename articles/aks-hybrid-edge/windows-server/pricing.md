---

title: Azure Kubernetes Service (AKS) on Windows Server pricing details
description: Learn about detailed pricing information for AKS on Windows Server.
ms.topic: concept-article
author: davidsmatlak
ms.author: davidsmatlak 
ms.date: 09/01/2026
ms.lastreviewed: 05/31/2023
ms.custom: windows-server

# Intent: As a subscription owner, I want to understand how the AKS service is priced and what I am paying for.
# Keyword: pricing

---


# AKS on Windows Server pricing details

[!INCLUDE [aks-hybrid-applies-to-azure-stack-hci-windows-server-sku](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

Azure Kubernetes Service (AKS) on Windows Server is a subscription-based Kubernetes offering that you can run on Windows Server Hyper-V clusters. You can download and install AKS on your existing hardware either in your own on-premises data center or on the edge. The pricing is based on usage and requires an Azure subscription, which you can get for free. The billing unit is a virtual core or vCPU. All initial AKS deployments include a free 60-day evaluation period. After the evaluation period, a pay-as-you-go rate per vCPU (of running worker nodes) per day applies.

> [!IMPORTANT]
> Starting in June 2023, the 60-day evaluation period is a one-time benefit per subscription. After the evaluation period, a pay-as-you-go rate per vCPU applies. The evaluation period no longer resets when you reinstall AKS on Windows Server. This change aligns with our existing pricing guidelines and helps us continue providing high-quality services.

## Pricing details

Azure pricing for running workloads on AKS on Windows Server is based on US currency list pricing with:

- Pay-as-you-go pricing
- D-series general purpose VM sizes (D2s v4, D4s V4, and D8s V4)
- Standard HDD
- No uptime SLA (included in the support level)

In addition, AKS pricing is based on the US currency list pricing with no discounts applied. The monthly price estimates are based on 730 hours of usage.

For detailed pricing information, see the [AKS pricing details](https://azure.microsoft.com/pricing/details/azure-stack/aks-hci/#overview) page. The list price for AKS includes the following features:

- Kubernetes control plane and load balancer nodes:
  - No charge for Arc-enabled AKS management cluster usage.
  - No charge for workload cluster control plane and load balancer nodes.

- Linux (CBL-Mariner) container hosts:
  - Pricing doesn't include Windows container hosts as they are licensed separately through regular licensing channels.
  - Windows Server Standard: Unlimited Windows containers and two Hyper-V containers.
  - Windows Server Datacenter: Unlimited Windows and Hyper-V containers.

- Azure Arc-enabled Kubernetes at no extra charge and the following items:
  - **Inventory, grouping, and tagging** in Azure.
  - **Deployment of apps and configurations with GitOps**: Included at no extra charge (normally, the initial six vCPUs are free, and then afterwards, the charged per vCPU per month).
  - **Azure Policy for Kubernetes**: Included at no extra charge (normally, the charge per vCPU per cluster for each month).

- If you enable hyper-threading on the physical computer, this feature reduces the measured vCPU count by 50 percent.

> [!NOTE]
> Running Windows Server containers on AKS requires a Windows Server license. You can acquire the license separately through regular licensing channels, or you can add it to the cost of running a Windows virtual machine on Azure. For users with Windows Server Software Assurance, [Azure Hybrid Benefits](azure-hybrid-benefit-22h2.md) might apply, thus reducing or eliminating the Windows Server license fees.

## Impact of hyper-threading on pricing for AKS

If you enable hyper-threading on your physical computer, AKS also enables hyper-threading on the worker nodes. When you enable hyper-threading, it effectively halves the number of virtual cores needed in each worker node.

:::image type="content" source="../media/pricing/hyper-thread-hyperv-manager.png" alt-text="Screenshot showing how pricing for AKS is affected by hyper-threading." lightbox="../media/pricing/hyper-thread-hyperv-manager.png":::

## Next steps

[AKS on Windows Server pricing details](https://azure.microsoft.com/pricing/details/azure-stack/aks-hci)
