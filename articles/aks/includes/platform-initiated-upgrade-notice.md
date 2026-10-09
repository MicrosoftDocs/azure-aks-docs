---
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 09/17/2026
author: kaarthis
ms.author: kaarthis
---

> [!IMPORTANT]
> **AKS platform-initiated upgrades.** Starting on **June 1, 2027**, AKS automatically upgrades any cluster that stays on an unsupported Kubernetes version after its 60-day [platform support grace period](../platform-initiated-upgrades.md#platform-support-grace-period) ends. A platform-initiated upgrade **doesn't follow your maintenance window**, **doesn't stop for deprecated API usage**, and **can override a Pod Disruption Budget** that blocks a node drain, so workloads might be disrupted. Before the upgrade month, replace APIs removed from the target Kubernetes version and update incompatible self-managed add-ons. Keep your clusters on a supported Kubernetes version to avoid a platform-initiated upgrade. For more information, see [Prepare for platform-initiated upgrades in AKS](../platform-initiated-upgrades.md#prepare-before-aks-starts-the-upgrade).
