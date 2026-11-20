--- 
title: Node Image Updates for Node Auto-Provisioning (NAP) in Azure Kubernetes Service (AKS)
description: Learn about node image updates for NAP in AKS, including how it works, recommended maintenance windows, and examples to get started.
ai-usage: ai-assisted
ms.topic: overview
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.date: 10/01/2026
ms.author: wilsondarko
author: wdarko1
# Customer intent: As a cluster operator or developer, I want to understand how node image updates work for my AKS clusters using node auto-provisioning, so that I can effectively manage and maintain the health and security of my cluster nodes.
---

# Node image updates for node auto-provisioning (NAP) in Azure Kubernetes Service (AKS)

This article provides an overview of node image updates for node auto-provisioning (NAP) in Azure Kubernetes Service (AKS), including how it works, recommended maintenance windows, and examples to get started.

You can control when node image updates in NAP happen and the amount of disruption by using three main components:

- Azure-based node OS maintenance windows
- Pod disruption budgets
- Karpenter node-level disruption budgets

## How do node image updates work for node auto-provisioning nodes?

By default, NAP node pool virtual machines (VMs) are automatically updated when a new image version is available. You can configure an [AKS-managed node operating system (OS) upgrade schedule maintenance window](#node-os-upgrade-maintenance-windows-for-nap) to control when new images are picked up and applied to your NAP nodes, or [use Karpenter Node Disruption Budgets and Pod Disruption Budgets](#karpenter-node-disruption-budgets-and-pod-disruption-budgets-for-nap) to control how and when disruption occurs during upgrades.

When you omit `spec.versions`, nodes use the observed AKS control-plane Kubernetes version, and the provider automatically resolves compatible node images. When the provider detects a control-plane Kubernetes version upgrade, it marks node images as not ready and resolves images for that Kubernetes version. The provider doesn't currently automatically downgrade node Kubernetes versions. 

### Pin node image and Kubernetes version

NAP supports pinning the latest node image version and supported Kubernetes versions for NAP-managed nodes via the `spec.versions` field in the `AKSNodeClass` custom resource. The latest node image version can be pinned until its Kubernetes version is no longer supported (or not in Long-Term Support). When a pinned node image's Kubernetes version is no longer supported, the node image automatically updates to the next available supported node image version. 

To pin Kubernetes or node image versions in NAP, see [Configure `AKSNodeClass` version settings](./node-auto-provisioning-aksnodeclass.md#kubernetes-and-node-image-versions).

## Node OS upgrade maintenance windows for NAP

Use the [AKS planned maintenance feature](./planned-maintenance.md) with a [node OS auto-upgrade channel](./auto-upgrade-node-os-image.md) to configure an `aksManagedNodeOSUpgradeSchedule` maintenance window. This window controls when to perform node OS security patching scheduled by your designated node OS auto-upgrade channel.

### Node OS upgrade maintenance window behavior and considerations

Keep the following information in mind when configuring a node OS upgrade maintenance window for NAP:

- The `aksManagedNodeOSUpgradeSchedule` maintenance window gates routine automatic node image roll-forward. This configuration doesn't necessarily determine when existing nodes are disrupted.
- The upgrade mechanism and decision criteria are specific to NAP/Karpenter and are evaluated by NAP's drift logic. NAP respects Karpenter Node Disruption Budgets and Pod Disruption Budgets. For more information about drift, see the [NAP Drift  documentation](./node-auto-provisioning-disruption.md#drift).
- The maintenance window doesn't defer required image initialization, image pin changes or removal, or image refreshes associated with Kubernetes version changes.
- These NAP upgrade decisions are separate from the cluster `NodeImage` and `SecurityPatch` channels.
- We recommend using a maintenance window of four hours or more for reliable operation.
- If the provider doesn't find upcoming maintenance-window data, it treats the window as open. Routine image roll-forward can therefore happen outside an explicitly configured window.
- Allow at least 30 minutes between creating or updating a maintenance configuration and the scheduled start time to ensure AKS has time to reconcile the new configuration.

### Recommended schedule pattern for NAP-managed nodes

We recommend the following schedule pattern for NAP-managed nodes:

- **Weekly cadence**: Recommended for routine node image roll outs (for example: _Every week on Sunday_).

For complete details, examples, and advanced scenarios, see [Use Planned Maintenance to schedule maintenance windows for your AKS cluster](./planned-maintenance.md).

## Karpenter Node Disruption Budgets and Pod Disruption Budgets for NAP

In addition to AKS specific maintenance window controls, use node-level and pod-level disruption budgets to control when and where updates happen. For more information on configuring Karpenter Node Disruption Budgets and Pod Disruption Budgets for NAP, see the following articles:

- [Node Auto-Provisioning disruption documentation](./node-auto-provisioning-disruption.md#disruption-budgets)
- [AKS scheduling best practice documentation](./operator-best-practices-scheduler.md#limit-disruption-impact-by-using-pod-disruption-budgets-pdbs)
- [Pod-level controls for disruption](https://karpenter.sh/docs/concepts/disruption/#pod-level-controls)

## Next steps

For more information on node auto-provisioning in AKS, see the following articles:

- [Use node auto-provisioning in a custom virtual network](./node-auto-provisioning-custom-vnet.md)
- [Configure networking for node auto-provisioning on AKS](./node-auto-provisioning-networking.md)
- [Configure node pools for node auto-provisioning on AKS](./node-auto-provisioning-node-pools.md)
- [Configure disruption policies for node auto-provisioning on AKS](./node-auto-provisioning-disruption.md)
