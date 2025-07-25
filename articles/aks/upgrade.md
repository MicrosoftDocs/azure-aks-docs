---
title: Overview of upgrading Azure Kubernetes Service (AKS) clusters and components
description: Learn about the various upgradeable components of an Azure Kubernetes Service (AKS) cluster and how to maintain them.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: overview
ms.subservice: aks-upgrade
ms.date: 07/01/2025
# Customer intent: As a cloud operations engineer, I want to upgrade the Azure Kubernetes Service cluster and its components, so that I can ensure security, compatibility, and access to the latest features while minimizing workload impact.
---

# Upgrading Azure Kubernetes Service clusters and node pools

An Azure Kubernetes Service (AKS) cluster needs to be periodically updated to ensure security and compatibility with the latest features. There are two components of an AKS cluster that are necessary to maintain:

- *Cluster Kubernetes version*: Part of the AKS cluster lifecycle involves performing upgrades to the latest Kubernetes version. It’s important that you upgrade to apply the latest security releases and to get access to the latest Kubernetes features, as well as to stay within the [AKS support window][supported-k8s-versions].
- *Node image version*: AKS regularly provides new node images with the latest OS and runtime updates. It's beneficial to upgrade your nodes' images regularly to ensure support for the latest AKS features and to apply essential security patches and hot fixes.

For Linux nodes, node image security patches and hotfixes may be performed without your initiation as *unattended updates*. These updates are automatically applied, but AKS doesn't automatically reboot your Linux nodes to complete the update process. You're required to use a tool like [kured][node-updates-kured] or [node image upgrade][node-image-upgrade] to reboot the nodes and complete the cycle.

The following table summarizes the details of updating each component:

|Component name|Frequency of upgrade|Planned Maintenance supported|Supported operation methods|Supported operation methods (Multi-Cluster)|Documentation link|
|--|--|--|--|--|--|
|Cluster Kubernetes version upgrade (minor)|Roughly every three months|Yes|Automatic, Manual|Automatic, Manual|[Upgrade an AKS cluster][upgrade-cluster], [Multi-cluster upgrade][multi-cluster-upgrade-concept]|
|Cluster Kubernetes version upgrade (patch)|Approximately weekly. To determine the latest applicable version in your region, see the [AKS release tracker][release-tracker]|Yes|Automatic, Manual|Manual|[Upgrade an AKS cluster][upgrade-cluster], [Multi-cluster upgrade][multi-cluster-upgrade-concept]|
|Node image version upgrade|**Linux**: weekly<br>**Windows**: monthly|Yes|Automatic, Manual|Automatic, Manual|[AKS node image upgrade][node-image-upgrade], [Multi-cluster upgrade][multi-cluster-upgrade-concept]|
|Security patches and hot fixes for node images|As-necessary|||Unsupported|[AKS node security patches][node-security-patches]|

## Multi-cluster upgrade
When you have multiple clusters, an important practice that you should include as part of your upgrade process is remembering to follow commonly used deployment and testing patterns. Testing an upgrade in a development or test environment before deployment in production is an important step to ensure application functionality and compatibility with the target environment. It can help you identify and fix any errors, bugs, or issues that might affect the performance, security, or usability of the application or underlying infrastructure.

[Azure Kubernetes Fleet Manager][fleet-manager] has built-in support for [multi-cluster upgrades][multi-cluster-upgrade-concept] which implements the best practice above to minimize application disruptions caused by cluster upgrades. Besides allowing you to customize the order of upgrades of multiple clusters, it also allows you to use consistent node OS image versions across clusters in different regions.

## Automatic upgrades

Automatic upgrades can be performed through [auto upgrade channels][auto-upgrade] or via [GitHub Actions][gh-actions-upgrade].

[Automatic multi-cluster upgrades][auto-multi-cluster-upgrade] can be performed through [Azure Kubernetes Fleet Manager][fleet-manager] to adopt the best practice of testing and verifying an upgrade in a development or test environment before production.

## Planned maintenance

 [Planned maintenance][planned-maintenance] allows you to schedule weekly maintenance windows that will update your control plane and your kube-system pods, helping to minimize workload impact.

## Troubleshooting

To find details and solutions to specific issues, view the following troubleshooting guides:

- [Upgrade fails because of NSG rules][ts-nsg]

- [PodDrainFailure error][ts-pod-drain]

- [PublicIPCountLimitReached error][ts-ip-limit]

- [QuotaExceeded error][ts-quota-exceeded]

- [SubnetIsFull error][ts-subnet-full]

## Next steps

For more information what cluster operations may trigger specific upgrade events, upgrade best practices, and other considerations, see the [AKS operator's guide on patching][operator-guide-patching].

<!-- LINKS -->
[auto-upgrade]: ./auto-upgrade-cluster.md
[planned-maintenance]: ./planned-maintenance.md
[upgrade-cluster]: ./upgrade-cluster.md
[release-tracker]: ./release-tracker.md
[node-image-upgrade]: ./node-image-upgrade.md
[gh-actions-upgrade]: ./node-upgrade-github-actions.md 
[operator-guide-patching]: /azure/architecture/operator-guides/aks/aks-upgrade-practices
[supported-k8s-versions]: ./supported-kubernetes-versions.md#kubernetes-version-support-policy
[fleet-manager]: /azure/kubernetes-fleet/overview
[multi-cluster-upgrade-concept]: /azure/kubernetes-fleet/concepts-update-orchestration
[auto-multi-cluster-upgrade]: /azure/kubernetes-fleet/update-automation
[ts-nsg]: /troubleshoot/azure/azure-kubernetes/upgrade-fails-because-of-nsg-rules
[ts-pod-drain]: /troubleshoot/azure/azure-kubernetes/error-code-poddrainfailure
[ts-ip-limit]: /troubleshoot/azure/azure-kubernetes/error-code-publicipcountlimitreached
[ts-quota-exceeded]: /troubleshoot/azure/azure-kubernetes/error-code-quotaexceeded
[ts-subnet-full]: /troubleshoot/azure/azure-kubernetes/error-code-subnetisfull-upgrade
[node-security-patches]: ./concepts-vulnerability-management.md#worker-nodes
[node-updates-kured]: ./node-updates-kured.md

