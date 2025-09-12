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

It is important for fleet administrators to understand the Kubernetes version support policy for clusters as older Kubernetes versions can expose your workloads to security vulnerabilities and bugs, while at the same time being unsupported by Microsoft.

Azure Kubernetes Fleet Manager follows the [Kubernetes version support policy][aks-version-policy] for Azure Kubernetes Service (AKS).

Similar to AKS, which currently allows clusters already running with older Kubernetes versions to operate without support, Fleet Manager also allows clusters on older Kubernetes version to join as member clusters.

In order to ensure you can take advantage of the latest features and security updates, we recommend you upgrade your clusters to a supported AKS Kubernetes version, including [AKS LTS][aks-version-policy-lts].

## Azure Arc Kubernetes version support

Azure Arc-enabled Kubernetes clusters are subject to the [version support policy][arc-version-policy] of Azure Arc's Kubernetes agent.

While Arc clusters may continue to function outside of this window, they will not be supported by Microsoft, as per the policy.

## Fleet Manager feature support

While AKS and Arc clusters on older Kubernetes versions can join a fleet, certain Fleet Manager features which require a higher Kubernetes version won't be guaranteed to function or be available for those clusters. In some cases, these features may cause unexpected behavior in the cluster.

Where a Fleet Manager feature requires a minimum Kubernetes version, the minimum version will be documented in the relevant Fleet Manager documentation.

## Next steps

For information on how to upgrade your cluster, see:
- [Upgrade multiple Kubernetes clusters via Azure Kubernetes Fleet Manager][fleet-multi-cluster-upgrade]

<!-- LINKS - Internal -->
[arc-version-policy]: /azure/azure-arc/kubernetes/agent-upgrade#version-support-policy
[aks-version-policy]: ../aks/supported-kubernetes-versions.md
[aks-version-policy-lts]: ../aks/supported-kubernetes-versions.md#long-term-support-lts
[fleet-multi-cluster-upgrade]: ./update-orchestration.md
