---
title: Automatically drain Azure Kubernetes Service (AKS) nodes 
description: Learn about node auto-drain functionality and how AKS protects your workloads from scheduled VM maintanence events.
ms.topic: conceptual
ms.date: 08/12/2024
author: julia-yin
ms.author: julia-yin

---

# Azure Kubernetes Service (AKS) node auto-drain
[Scheduled events][scheduled-events] can occur on the underlying VMs in any of your node pools. For [spot node pools][spot-node-pools], scheduled events may cause a *preempt* node event for the node. Certain node events, such as  *preempt*, cause AKS node auto-drain to attempt a cordon and drain of the affected node. This process enables rescheduling for any affected workloads on that node. You might notice the node receives a taint with `"remediator.kubernetes.azure.com/unschedulable"`, because of `"kubernetes.azure.com/scalesetpriority: spot"`.

The following table shows the node events and actions they cause for AKS node auto-drain:

| Event | Description |   Action   |
| --- | --- | --- |
| Freeze | The VM is scheduled to pause for a few seconds. CPU and network connectivity may be suspended, but there's no impact on memory or open files.  | No action. |
| Reboot | The VM is scheduled for reboot. The VM's non-persistent memory is lost. | No action. |
| Redeploy | The VM is scheduled to move to another node. The VM's ephemeral disks are lost. | Cordon and drain. |
| Preempt | The spot VM is being deleted. The VM's ephemeral disks are lost. | Cordon and drain |
| Terminate | The VM is scheduled for deletion.| Cordon and drain. |

## Limitations

In many cases, AKS can determine if a node is unhealthy and attempt to repair the issue. However, there are cases where AKS either can't repair the issue or detect that an issue exists. For example, AKS can't detect issues in the following example scenarios:

* A node status isn't being reported due to error in network configuration.
* A node failed to initially register as a healthy node.

Node Autodrain is a best effort service and cannot be guaranteed to operate perfectly in all scenarios
## Next steps

Use [availability zones][availability-zones] to increase high availability with your AKS cluster workloads.

<!-- LINKS - Internal -->
[availability-zones]: ./availability-zones.md
[vm-updates]: ../virtual-machines/maintenance-and-updates.md
[scheduled-events]: ../virtual-machines/linux/scheduled-events.md
[spot-node-pools]: spot-node-pool.md
