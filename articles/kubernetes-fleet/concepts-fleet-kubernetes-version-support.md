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

Azure Kubernetes Fleet Manager follows the [Kubernetes version support policy][aks-version-policy] for Azure Kubernetes Service (AKS).

Similar to AKS, which allows clusters already running older Kubernetes versions to operate without support, Fleet Manager also allows clusters on older Kubernetes version to join as member clusters. While these clusters continue to function, there's no guarantee that all Fleet Manager features are available or function as expected.

To ensure you can take advantage of the latest Fleet Manager, AKS and Kubernetes features, we recommend upgrading your clusters to a supported AKS or Arc-enabled Kubernetes version, including [AKS long term support (LTS)][aks-version-policy-lts].

## Azure Arc-enabled Kubernetes

Azure Arc-enabled Kubernetes clusters are subject to the [version support policy][arc-version-policy] of Azure Arc's Kubernetes agent.

While Arc-enabled Kubernetes clusters may continue to function outside of this window, they won't be supported by Microsoft.

## Fleet Manager feature support

On Kubernetes versions outside of the supported AKS or Arc-enabled Kubernetes versions, Fleet Manager features may not be available or function as expected. In this scenario, the features may have unintended side effects on the cluster.

On clusters running a supported AKS and Arc-enabled Kubernetes version, but which don't meet the minimum Kubernetes version required for a Fleet Manager feature, that feature isn't available.  Microsoft guarantees the cluster functions as expected.

Where a Fleet Manager feature requires a minimum Kubernetes version, the minimum version is documented in the relevant Fleet Manager documentation.

## Next steps

For information on how to upgrade your cluster, see:
- [Upgrade multiple Kubernetes clusters via Azure Kubernetes Fleet Manager][fleet-multi-cluster-upgrade]

<!-- LINKS - Internal -->
[arc-version-policy]: /azure/azure-arc/kubernetes/agent-upgrade#version-support-policy
[aks-version-policy]: ../aks/supported-kubernetes-versions.md
[aks-version-policy-lts]: ../aks/supported-kubernetes-versions.md#long-term-support-lts
[fleet-multi-cluster-upgrade]: ./update-orchestration.md
