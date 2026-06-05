---
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 02/09/2026
author: allyford
ms.author: allyford
---

> [!IMPORTANT]
> Starting on **June 30, 2027**, Azure Kubernetes Service (AKS) no longer supports or provides security updates for Ubuntu 22.04. To avoid disruptions, [transition](../upgrade-aks-cluster.md) to Ubuntu 24.04 or later by that date. Between now and June 30, 2027, you can continue to use Ubuntu 22.04 on AKS without disruption. If you don't migrate by June 30, 2027, you won't be able to create new node pools, AKS won't produce new node images, and you'll no longer receive security patches for existing node pools. If you want to enable long-term support (LTS) with Kubernetes version 1.33 or later, first update your node pools to Ubuntu 24.04.
> On **April 30, 2028**, AKS will remove Ubuntu 22.04 node images and existing code, causing scaling and remediation operations to fail.
> To avoid service disruptions such as security vulnerabilities, failed node image upgrades, and scaling failures, [migrate](../upgrade-aks-cluster.md) to Ubuntu 24.04 or later by June 30, 2027. Your migration options include:
>
> - **Default Operating System SKU (OSSku)**: If you're using `Ubuntu`, you'll automatically migrate to Ubuntu 24.04 when you upgrade your Kubernetes version to 1.35 or later.
> - **Versioned OSSku**: If you're using `Ubuntu2204`, update your OSSku to `Ubuntu` for Kubernetes 1.35 or later or `Ubuntu2404` for Kubernetes 1.32 or later.
>
> For more information on this retirement, see the [Retirement GitHub issue](https://aka.ms/aks/ubuntu2204-retirement-github) and [Azure Updates post](https://azure.microsoft.com/updates/?id=557928). To stay informed on announcements and updates, follow the [AKS release notes](https://github.com/Azure/AKS/releases).