---
title: Automatically drain Azure Kubernetes Service (AKS) nodes
description: Learn about node auto-drain functionality and how AKS protects your workloads from scheduled VM maintenance events.
ms.topic: concept-article
ms.date: 03/30/2026
author: davidsmatlak
ms.author: davidsmatlak
ai-usage: ai-assisted

# Customer intent: As a cloud operations engineer, I want to implement node auto-drain in AKS, so that I can protect workloads from disruptions caused by scheduled VM maintenance events.
---

# Azure Kubernetes Service (AKS) node auto-drain
Node auto-drain helps you protect your node workloads from disruptions when [scheduled events][scheduled-events] occur on the underlying virtual machines (VMs) in any of your node pools. When certain node events happen, node auto-drain attempts a cordon and drain of the affected node so the workloads can be rescheduled safely. An example of when node auto-drain might occur is when scheduled events on a [spot node pool][spot-node-pools] cause a preempt node event. The spot node with the taint `"kubernetes.azure.com/scalesetpriority: spot"` may receive a taint with `"remediator.kubernetes.azure.com/unschedulable"` when a scheduled event occurs on that node.

> [!NOTE]
> Node auto-drain is a best effort service and can't be guaranteed to operate perfectly in all scenarios.

## Scheduled event actions

The following table shows the node events for AKS node auto-drain and describes their associated actions:

| Event | Description | Action |
| --- | --- | --- |
| Freeze | The underlying virtual machine (VM) is scheduled to pause for a few seconds. CPU and network connectivity might be suspended, but there's no impact on memory or open files. | Opt in to [workload eviction on freeze events (preview)](./node-auto-drain-evict-on-freeze.md). |
| Reboot | The VM is scheduled for reboot. The VM's non-persistent memory is lost. | No action. |
| Redeploy | The VM is scheduled to move to another node. The VM's ephemeral disks are lost. | Cordon and drain. |
| Preempt | The spot VM is being deleted. The VM's ephemeral disks are lost. | Cordon and drain. |
| Terminate | The VM is scheduled for deletion. | Cordon and drain (requires [Virtual Machine Scale Set terminate notifications](../virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification.md)). |

> [!NOTE]
> Redeploy and Preempt use default behavior and don't require extra configuration.
> Freeze and Terminate require opt-in configuration:
>
> - Freeze: [Configure pod eviction for freeze events](./node-auto-drain-evict-on-freeze.md).
> - Terminate: Enable [Virtual Machine Scale Set terminate notifications](../virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification.md) as a prerequisite for AKS node auto-drain.

## Next steps

- [Configure pod eviction for freeze events (preview)](./node-auto-drain-evict-on-freeze.md)
- Use [availability zones][availability-zones] to increase high availability with your AKS cluster workloads.

<!-- LINKS - Internal -->
[availability-zones]: ./availability-zones.md
[vm-updates]: /azure/virtual-machines/updates-maintenance-overview
[scheduled-events]: /azure/virtual-machines/linux/scheduled-events
[spot-node-pools]: ./spot-node-pool.md
[events]: ./events.md
