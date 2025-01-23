---
title: Automatically repair Azure Kubernetes Service (AKS) nodes 
description: Learn about node auto-repair functionality and how AKS fixes broken worker nodes.
ms.topic: conceptual
ms.date: 01/03/2025
author: nickomang
ms.author: nickoman

---

# Azure Kubernetes Service (AKS) node auto-repair

Azure Kubernetes Service (AKS) continuously monitors the health state of worker nodes and performs automatic node repair if they become unhealthy. The Azure virtual machine (VM) platform [performs maintenance on VMs](/azure/virtual-machines/maintenance-and-updates) experiencing issues. AKS and Azure VMs work together to minimize service disruptions for clusters.

In this article, you learn how the automatic node repair functionality behaves for Windows and Linux nodes.

## How AKS checks for NotReady nodes

AKS uses the following rules to determine if a node is unhealthy and needs repair:

* The node reports the [**NotReady**](https://kubernetes.io/docs/reference/node/node-status/#condition) status on consecutive checks within a 10-minute time frame.
* The node doesn't report any status within 10 minutes.

You can manually check the health state of your nodes with the `kubectl get nodes` command.

## How automatic repair works

> [!NOTE]
> AKS initiates repair operations with the user account **aks-remediator**.

If AKS identifies an unhealthy node that remains unhealthy for at least *five* minutes, AKS performs the following actions:

1. AKS reboots the node.
2. If the node remains unhealthy after reboot, AKS reimages the node.
3. If the node remains unhealthy after reimage and it's a Linux node, AKS redeploys the node.

AKS retries the restart, reimage, and redeploy sequence up to three times if the node remains unhealthy. The overall auto repair process can take up to an hour to complete. 

## Limitations
AKS node auto-repair is a best effort service and we don't guarantee that the node is restored back to healthy status. If your node persists in an unhealthy state, we highly encourage that you perform manual investigation of the node. Learn more about [troubleshooting node NotReady status](/troubleshoot/azure/azure-kubernetes/availability-performance/node-not-ready-basic-troubleshooting).

There are cases where AKS doesn't perform automatic repair. Failure to automatically repair the node can occur either by design or if Azure can't detect that an issue exists. Examples of when auto-repair isn't performed include:

* A node status isn't being reported due to error in network configuration.
* A node failed to initially register as a healthy node.
* If either of the following taints are present on the node: `node.cloudprovider.kubernetes.io/shutdown`, `ToBeDeletedByClusterAutoscaler`.

## Monitor node auto-repair using Kubernetes events
When AKS performs node auto-repair on your cluster, AKS emits Kubernetes events from the aks-auto-repair source for visibility. The following events appear on a node object when auto-repair happens. 

To learn more about accessing, storing, and configuring alerts on Kubernetes events, see [Use Kubernetes events for troubleshooting in Azure Kubernetes Service](./events.md).

> [!NOTE]
> We are currently monitoring the volume of the new remediation events to ensure that there are no performance degradations. As a result, your cluster may not receive these new events as they are slowly rolling out to clusters in production regions. We estimate a full rollout by March 2025.

| Reason | Event Message | Description |
| --- | --- | --- |
| NodeRebootStart | Node auto-repair is initiating a reboot action due to NotReady status persisting for more than 5 minutes. | This event is emitted to notify you when reboot is about to be performed on your node. This action is the first in the overall node auto-repair sequence. |
| NodeRebootEnd | Reboot action from node auto-repair is completed. | Emitted once reboot is complete on the node. This event doesn't indicate the health status (healthy or unhealthy) of the node after the reboot is performed. |
| NodeReimageStart | Node auto-repair is initiating a reimage action due to NotReady status persisting for more than 5 minutes. | This event is emitted to notify you when reimage is about to be performed on your node. |
| NodeReimageEnd | Reimage action from node auto-repair is completed. | Emitted once reimage is complete on the node. This event doesn't indicate the health status (healthy or unhealthy) of the node after the reimage is performed. |
| NodeRedeployStart | Node auto-repair is initiating a redeploy action due to NotReady status persisting more than 5 minutes. | This event is emitted to notify you when redeploy is about to be performed on your node. Redeploy is the last action in the node auto-repair sequence. |
| NodeRedeployEnd | Redeploy action from node auto-repair is completed. | Emitted once redeploy is complete on the node. This event doesn't indicate the health status (healthy or unhealthy) of the node after redeploy is performed. |

If any errors occur during the node auto-repair process, the following events are emitted with the verbatim error message. Learn more about [troubleshooting common node auto-repair errors](/troubleshoot/azure/azure-kubernetes/availability-performance/node-auto-repair-errors).

> [!NOTE]
> _Error code_ in the following event messages varies depending on the error reported.

| Reason | Event Message | Description |
| --- | --- | --- |
| NodeRebootError | Node auto-repair reboot action failed due to an operation failure. See error details here: _Error code_ | Emitted when there's an error with the reboot action. |
| NodeReimageError | Node auto-repair reimage action failed due to an operation failure. See error details here: _Error code_ | Emitted when there's an error with the reimage action. |
| NodeRedeployError | Node auto-repair redeploy action failed due to an operation failure. See error details here: _Error code_ | Emitted when there's an error with the redeploy action. |

## Next steps
By default, you can access Kubernetes events and logs on your AKS cluster from the past 1 hour. To store and query events and logs from the past 90 days, enable [Container Insights](/azure/azure-monitor/containers/container-insights-overview#access-container-insights) for deeper troubleshooting on your AKS cluster.
