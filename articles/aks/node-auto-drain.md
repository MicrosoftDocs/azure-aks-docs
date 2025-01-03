---
title: Automatically drain Azure Kubernetes Service (AKS) nodes 
description: Learn about node auto-drain functionality and how AKS protects your workloads from scheduled VM maintenance events.
ms.topic: conceptual
ms.date: 08/12/2024
author: nickoman
ms.author: nickoman

---

# Azure Kubernetes Service (AKS) node auto-drain
Node auto-drain helps you protect your node workloads from disruptions when [scheduled events][scheduled-events] occur on the underlying virtual machines (VMs) in any of your node pools. When certain node events happen, node auto-drain attempts a cordon and drain of the affected node so the workloads can be rescheduled safely. An example of when node auto-drain might occur is when scheduled events on a [spot node pool][spot-node-pools] cause a preempt node event. The spot node with the taint "kubernetes.azure.com/scalesetpriority: spot" may receive a taint with `"remediator.kubernetes.azure.com/unschedulable"` when a scheduled event occurs on that node.

> [!NOTE]
> Node auto-drain is a best effort service and can't be guaranteed to operate perfectly in all scenarios.

## Monitor node auto-drain using Kubernetes events
The following table shows the node events for AKS node auto-drain and describes their associated actions:

| Event | Description |   Action   |
| --- | --- | --- |
| Freeze | The underlying virtual machine (VM) is scheduled to pause for a few seconds. CPU and network connectivity may be suspended, but there's no impact on memory or open files.  | No action. |
| Reboot | The VM is scheduled for reboot. The VM's non-persistent memory is lost. | No action. |
| Redeploy | The VM is scheduled to move to another node. The VM's ephemeral disks are lost. | Cordon and drain. |
| Preempt | The spot VM is being deleted. The VM's ephemeral disks are lost. | Cordon and drain |
| Terminate | The VM is scheduled for deletion.| Cordon and drain. |

## Next steps

Use [availability zones][availability-zones] to increase high availability with your AKS cluster workloads.

<!-- LINKS - Internal -->
[availability-zones]: ./availability-zones.md
[vm-updates]: /azure/virtual-machines/updates-maintenance-overview
[scheduled-events]: /azure/virtual-machines/linux/scheduled-events
[spot-node-pools]: ./spot-node-pool.md
