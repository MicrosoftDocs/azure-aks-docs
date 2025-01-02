---
title: Automatically drain Azure Kubernetes Service (AKS) nodes 
description: Learn about node auto-drain functionality and how AKS protects your workloads from scheduled VM maintenance events.
ms.topic: conceptual
ms.date: 08/12/2024
author: nickomang
ms.author: nickomang

---

# Azure Kubernetes Service (AKS) node auto-drain
[Scheduled events][scheduled-events] can occur on the underlying virtual machines (VMs) in any of your node pools. For [spot node pools][spot-node-pools], scheduled events may cause a *preempt* node event for the node. Certain node events, such as  *preempt*, cause AKS node auto-drain to attempt a cordon and drain of the affected node. This process enables rescheduling for any affected workloads on that node. For example, your spot node with the taint "kubernetes.azure.com/scalesetpriority: spot" may receive a taint with `"remediator.kubernetes.azure.com/unschedulable"` when a scheduled event occurs on that node.

The following table shows the node events for AKS node auto-drain and describes their associated actions:

| Event | Description |   Action   |
| --- | --- | --- |
| Freeze | The underlying virtual machine (VM) is scheduled to pause for a few seconds. CPU and network connectivity may be suspended, but there's no impact on memory or open files.  | No action. |
| Reboot | The VM is scheduled for reboot. The VM's non-persistent memory is lost. | No action. |
| Redeploy | The VM is scheduled to move to another node. The VM's ephemeral disks are lost. | Cordon and drain. |
| Preempt | The spot VM is being deleted. The VM's ephemeral disks are lost. | Cordon and drain |
| Terminate | The VM is scheduled for deletion.| Cordon and drain. |

## Limitations

In many cases, AKS can determine whether a node is unhealthy and then attempt to repair the node. However, there are cases where AKS either can't detect that an issue exists or can't repair the node. For example, AKS can't detect issues in the following example scenarios:

* A node's status isn't being reported due to an error in network configuration.
* A node failed to initially register as a healthy node.

Node auto-drain is a best effort service and can't be guaranteed to operate perfectly in all scenarios.
## Next steps

Use [availability zones][availability-zones] to increase high availability with your AKS cluster workloads.

<!-- LINKS - Internal -->
[availability-zones]: ./availability-zones.md
[vm-updates]: /azure/virtual-machines/updates-maintenance-overview
[scheduled-events]: /azure/virtual-machines/linux/scheduled-events
[spot-node-pools]: ./spot-node-pool.md
