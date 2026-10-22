---
title: Overview of Upgrading Azure Kubernetes Service (AKS) Clusters and Components
description: Learn about the various upgradeable components of an Azure Kubernetes Service (AKS) cluster and how to maintain them.
author: schaffererin
ms.author: schaffererin
ms.topic: overview
ms.subservice: aks-upgrade
ms.service: azure-kubernetes-service
ms.date: 07/07/2026
# Customer intent: As a cloud operations engineer, I want to upgrade the Azure Kubernetes Service cluster and its components, so that I can ensure security, compatibility, and access to the latest features while minimizing workload impact.
---

# Upgrading Azure Kubernetes Service (AKS) clusters and node pools

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

An Azure Kubernetes Service (AKS) cluster needs to be periodically updated to ensure security and compatibility with the latest features. There are two components of an AKS cluster that are necessary to maintain:

- **Cluster Kubernetes version**: As part of the AKS cluster lifecycle, perform upgrades to the latest Kubernetes version. Upgrade to apply the latest security releases and to get access to the latest Kubernetes features. Stay within the [AKS support window][supported-k8s-versions].
- **Node image version**: AKS regularly provides new node images with the latest operating system (OS) and runtime updates. Regularly upgrade your node images to ensure support for the latest AKS features and to apply essential security patches and hotfixes.

For Linux nodes, you can apply node image security patches and hotfixes without your initiation as _unattended updates_. These updates are automatically applied, but AKS doesn't automatically reboot your Linux nodes to complete the update process. You need to use a tool like [kured][node-updates-kured] or [node image upgrade][node-image-upgrade] to reboot the nodes and complete the cycle.

## AKS Automatic: Production-ready upgrades by default

[AKS Automatic][aks-automatic] clusters simplify cluster management by including automatic cluster and node upgrades by default. If you're using AKS Automatic, your cluster is already configured with:

- **Automatic Kubernetes version upgrades** by using the stable channel (N-1 minor version).
- **Automatic node OS image upgrades** with security patches and bug fixes.
- **Built-in API breaking change detection** that stops upgrades if deprecated Kubernetes APIs are detected.
- **Automatic node repair** and cluster component patching.
- **Managed reliability defaults** for upgrade cadence, node maintenance, and control plane operations.

No action is required on your part. AKS Automatic handles upgrades automatically during [planned maintenance windows][planned-maintenance]. This article covers advanced upgrade strategies for scenarios beyond the Automatic defaults.

> [!TIP]
> **Using AKS Automatic?** Your cluster is preconfigured for production-ready upgrades. Continue reading only if you need advanced customization, multi-cluster orchestration, or manual upgrade control for non-Automatic clusters.

## Component upgrade overview

The following table summarizes the upgrade frequency, methods, and support for each component. The _AKS Automatic?_ column shows how AKS Automatic handles each component:

| Component name | Frequency | AKS Automatic? | Planned maintenance | Supported methods (Standard) | Multi-cluster support | Learn more |
| -------------- | --------- | -------------- | ------------------- | ---------------------------- | --------------------- | ---------- |
| Cluster Kubernetes version (minor) | Roughly every three months | **Yes** - Automatic (stable channel N-1) | Yes | Automatic, Manual | Automatic, Manual |[Upgrade an AKS cluster][upgrade-cluster], [Multi-cluster upgrade][multi-cluster-upgrade-concept] |
| Cluster Kubernetes version (patch) | Approximately weekly | **Yes** - Automatic | Yes | Automatic, Manual | Manual | [Upgrade an AKS cluster][upgrade-cluster], [AKS release tracker][release-tracker] |
| Node OS image (Linux) | Weekly | **Yes** - Automatic | Yes | Automatic, Manual | Automatic, Manual | [AKS node image upgrade][node-image-upgrade] |
| Node OS image (Windows) | Monthly | N/A | Yes | Automatic, Manual | Automatic, Manual | [AKS node image upgrade][node-image-upgrade] |
| Security patches and hotfixes | As needed | **Yes** - Automatic | N/A | N/A | Unsupported | [AKS node security patches][node-security-patches] |

## Advanced upgrade strategies

For advanced upgrade scenarios beyond AKS Automatic defaults, explore specialized upgrade patterns:

- **[Minimal downtime upgrades][production-upgrade-strategies]** using blue-green deployments for less than two minutes of downtime.
- **[Staged multi-region upgrades][production-upgrade-strategies]** using Azure Kubernetes Fleet Manager with validation gates.
- **[Safe version intake][production-upgrade-strategies]** using canary deployments with API deprecation scanning.
- **[Automated security patch rollouts][production-upgrade-strategies]** with less than four hours completion time for critical security patches.
- **[Application resilience patterns][production-upgrade-strategies]** for zero-impact upgrades via graceful degradation.

See [AKS production upgrade strategies][production-upgrade-strategies] for detailed implementation guidance on these patterns.

## Multi-cluster upgrade orchestration

When managing multiple AKS clusters, following consistent deployment and testing patterns is critical for minimizing disruptions:

- **Test first, deploy second**: Always test upgrades in a development or test environment before production to identify compatibility issues, bugs, or performance impacts.
- **Consistent versioning across regions**: Maintain consistent Kubernetes and node OS image versions across clusters in different regions to simplify operations and troubleshooting.

[Azure Kubernetes Fleet Manager][fleet-manager] provides built-in orchestration for multi-cluster upgrades with:

- Customizable upgrade ordering across clusters
- Validation gates between upgrade stages
- Automatic or scheduled update coordination
- Consistent node OS image versions across regions

For **AKS Automatic clusters**, Fleet Manager's automatic upgrade orchestration implements these best practices by default, safely progressing upgrades through your fleet with integrated testing and validation.

For **AKS Standard clusters**, see [Multi-cluster upgrade orchestration][multi-cluster-upgrade-concept] for step-by-step guidance.

## Automatic upgrades

You can configure automatic upgrades through multiple methods:

- **[Auto upgrade channels][auto-upgrade]**: AKS Automatic uses the stable channel by default. AKS Standard clusters can choose from release channels (patch, stable, rapid) or rapid N-1 for earlier access to new versions.
- **[GitHub Actions][gh-actions-upgrade]**: Automate node upgrades through CI/CD pipelines.
- **[Azure Kubernetes Fleet Manager][fleet-manager]**: Automatic multi-cluster upgrades with coordinated deployment across your fleet and testing and validation gates.

## Planned maintenance

For both AKS Automatic and AKS Standard clusters, use [planned maintenance][planned-maintenance] to schedule maintenance windows that update your control plane and your kube-system pods, helping to minimize workload impact. You can define maintenance schedules inline on each cluster or use a [shared maintenance window](/azure/aks/planned-maintenance?pivots=azure-cli#use-a-shared-maintenance-window-preview) to reuse a schedule across multiple clusters.

### Planned maintenance for AKS Automatic

For AKS Automatic clusters, planned maintenance is **optional**:

- **Default behavior**: Automatic upgrades are scheduled during planned maintenance windows automatically, minimizing disruption.
- **Customization**: You can configure a custom planned maintenance schedule to control when upgrades occur and ensure minimal impact on your applications. If multiple clusters should use the same schedule, link their maintenance configurations to a shared maintenance window.
- **No action required**: If you don't configure a custom schedule, AKS Automatic upgrades proceed during default maintenance windows with built-in safeguards.

### Planned maintenance for AKS Standard

For AKS Standard clusters, planned maintenance windows help align upgrades with your operational schedule and reduce unexpected disruptions.

## Reliability and service-level details

For more information, see [Service-level agreements for online services](https://www.microsoft.com/licensing/docs/view/Service-Level-Agreements-SLA-for-Online-Services).

## Troubleshooting upgrade issues

Most AKS upgrades finish without problems, especially when you use AKS Automatic's built-in safeguards and API breaking change detection. If you encounter errors during manual upgrades or on AKS Standard clusters, review the following troubleshooting guides:

- [Upgrade fails because of NSG rules][ts-nsg]
- [PodDrainFailure error][ts-pod-drain]
- [PublicIPCountLimitReached error][ts-ip-limit]
- [QuotaExceeded error][ts-quota-exceeded]
- [SubnetIsFull error][ts-subnet-full]

## Related content

- **New to AKS?** [Create an AKS Automatic cluster][quickstart-aks-automatic] for production-ready upgrades by default.
- **Exploring upgrade strategies?** Review [AKS production upgrade strategies][production-upgrade-strategies] for advanced patterns including blue-green, staged, and canary deployments.
- **Managing multiple clusters?** Learn about [multi-cluster upgrade orchestration][multi-cluster-upgrade-concept] with Azure Kubernetes Fleet Manager.
- **Want upgrade best practices?** See the [AKS operator's guide on patching and upgrades][operator-guide-patching].

<!-- LINKS -->
[aks-automatic]: ./intro-aks-automatic.md
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
[production-upgrade-strategies]: ./aks-production-upgrade-strategies.md
[quickstart-aks-automatic]: ./automatic/quick-automatic-managed-network.md
[ts-nsg]: /troubleshoot/azure/azure-kubernetes/upgrade-fails-because-of-nsg-rules
[ts-pod-drain]: /troubleshoot/azure/azure-kubernetes/error-code-poddrainfailure
[ts-ip-limit]: /troubleshoot/azure/azure-kubernetes/error-code-publicipcountlimitreached
[ts-quota-exceeded]: /troubleshoot/azure/azure-kubernetes/error-code-quotaexceeded
[ts-subnet-full]: /troubleshoot/azure/azure-kubernetes/error-code-subnetisfull-upgrade
[node-security-patches]: ./concepts-vulnerability-management.md#worker-nodes
[node-updates-kured]: ./node-updates-kured.md
