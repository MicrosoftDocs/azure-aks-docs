---
title: "Supported Kubernetes versions inAzure Kubernetes Fleet Manager"
description: Learn the Kubernetes version support policy and lifecycle of clusters in Azure Kubernetes Fleet Manager.
ms.date: 09/02/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: "As a Kubernetes administrator, I want to understand the supported Kubernetes version lifecycle in Azure Kubernetes Fleet Manager, so that I can ensure my clusters remain compliant, up-to-date and can use new features."
---

# Supported Kubernetes versions in Azure Kubernetes Fleet Manager

**Applies to:** :heavy_check_mark: Fleet Manager :heavy_check_mark: Fleet Manager with hub cluster

This article describes the Kubernetes version support policy for member clusters in Azure Kubernetes Fleet Manager, along with how Kubernetes versions affect access to some Fleet Manager features.

## Azure Kubernetes Service (AKS) member clusters

Azure Kubernetes Fleet Manager follows the [Kubernetes version support policy][aks-version-policy] for Azure Kubernetes Service (AKS).

To ensure you can take advantage of the latest Fleet Manager, AKS, and Kubernetes features, we recommend upgrading your clusters to a supported AKS Kubernetes version, including [AKS long term support (LTS)][aks-version-policy-lts].

## Azure Arc-enabled Kubernetes member clusters

Azure Arc-enabled Kubernetes clusters are subject to the [version support policy][arc-version-policy] of Azure Arc's Kubernetes agent.

## Fleet Manager feature support

Some Fleet Manager features require a minimum Kubernetes version in order to function. Those features indicate the minimum version on their documentation page.

Member clusters running supported AKS and Arc-enabled Kubernetes versions, but that don't meet the minimum Kubernetes version required for a Fleet Manager feature, don't have access to that feature.

## Next steps

For information on how to upgrade your cluster, see:
- [Upgrade multiple Kubernetes clusters via Azure Kubernetes Fleet Manager][fleet-multi-cluster-upgrade]

<!-- LINKS - Internal -->
[arc-version-policy]: /azure/azure-arc/kubernetes/agent-upgrade#version-support-policy
[aks-version-policy]: ../aks/supported-kubernetes-versions.md
[aks-version-policy-lts]: ../aks/supported-kubernetes-versions.md#long-term-support-lts
[fleet-multi-cluster-upgrade]: ./update-orchestration.md
