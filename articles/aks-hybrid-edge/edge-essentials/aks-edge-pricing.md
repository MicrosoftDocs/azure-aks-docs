---
title: About AKS Edge Essentials pricing
description: Learn about AKS Edge Essentials pricing details.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: overview
ms.date: 09/01/2026
ms.custom: template-overview, edge-essentials
---

# AKS Edge Essentials pricing

AKS Edge Essentials can be licensed via one of the following options:

- Azure subscription-based model
- Volume licensing model (available from April 2023)

You can [review the details of each of the approaches](aks-edge-licensing.md). This article focuses on the Azure subscription-based approach. You can run the AKS Edge Essentials subscription-based Kubernetes offering on Windows Pro, Windows Enterprise, Windows IoT Enterprise, or Windows Server-based devices. You can download and install AKS Edge Essentials on your existing or new hardware that will be deployed on the edge. The pricing is based on usage and requires an Azure subscription, which you can obtain for free.

The billing unit model is based on a device, which can be a physical or virtual device on which AKS Edge Essentials is installed. After you install AKS Edge Essentials on your device and connect your cluster to Azure Arc, a per-device per-month rate is applied. The snapshot of usage is reported during the following month on a date that's one day prior to the date the Azure Arc-enabled Kubernetes cluster was created. For example, if the Azure Arc-enabled Kubernetes cluster was created on March 6 with AKS Edge Essentials, the number of devices included in this cluster is captured and submitted for billing on April 5. If you have one device in your cluster when the usage is posted on April 5, you'll be billed for one device usage for this Azure Arc-enabled Kubernetes cluster resource by AKS Edge Essentials.

## Pricing details

AKS Edge Essentials pricing is based on the US currency list pricing with no discounts applied.

For detailed pricing information, see the [AKS Edge Essentials pricing details page](https://aka.ms/AKSEdgeEssentialsPricing). The list price for AKS Edge Essentials includes the following components:

- A Microsoft-managed, lightweight, CNCF-conformant K8S and K3S distribution.
- License to use one Microsoft-managed Linux (CBL-Mariner) VM container host for use with Linux containers on AKS Edge Essentials.
- Azure Arc-enabled Kubernetes at no extra charge and the following items:
  - Inventory, grouping, and tagging in Azure.
  - Deployment of apps and configuration with GitOps: included at no extra charge (normally, the initial six vCPUs are free, and then afterwards, the charge is per vCPU per month).

When you run the Azure Arc-enabled Kubernetes clusters on the following products, the Kubernetes configuration capability (deployment of apps and configurations with GitOps) is included at no extra charge:

- Windows 11 Enterprise
- Windows 11 Enterprise N
- Windows 11 IoT Enterprise
- Windows 11 Pro
- Windows 10 Enterprise
- Windows 10 Enterprise N
- Windows 10 Enterprise LTSC
- Windows 10 Enterprise N LTSC
- Windows 10 IoT Enterprise
- Windows 10 IoT Enterprise LTSC
- Windows 10 Pro
- Windows Server 2022
- Windows Server 2022 Datacenter
- Windows Server 2022 Standard
- Windows Server 2019
- Windows Server 2019 Datacenter
- Windows Server 2019 Standard

## Next steps

- Read about [licensing options](./aks-edge-licensing.md)
- [Contact the AKS Edge Essentials product team](mailto:aksee-inquire@microsoft.com)
