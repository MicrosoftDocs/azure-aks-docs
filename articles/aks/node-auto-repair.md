---
title: Automatically Repair Azure Kubernetes Service (AKS) Nodes 
description: Learn how AKS node auto-repair works, including health detection, repair actions, limitations, and monitoring guidance for production workloads.
ms.topic: concept-article
ms.service: azure-kubernetes-service
ms.subservice: aks-nodes
ms.date: 07/01/2026
author: davidsmatlak
ms.author: davidsmatlak
# Customer intent: As a DevOps engineer, I want to understand how automatic node repair works in Azure Kubernetes Service so that I can ensure high availability and minimize downtime for my applications.
---

# Azure Kubernetes Service (AKS) node auto-repair

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

Azure Kubernetes Service (AKS) continuously monitors the health state of worker nodes and performs automatic node repair if they become unhealthy. The Azure virtual machine (VM) platform [performs maintenance on VMs](/azure/virtual-machines/maintenance-and-updates) experiencing issues. AKS and Azure VMs work together to minimize service disruptions for clusters.

For most production workloads, AKS Automatic is the recommended production-ready default experience for AKS. Both AKS Automatic and AKS Standard clusters come preconfigured with node auto-repair.

In this article, you learn how node auto-repair works, when repair actions trigger, what limitations apply, and how to monitor repair events.

## Node auto-repair behavior by cluster mode

Both AKS cluster modes come preconfigured with node auto-repair:

- **AKS Automatic**: Preconfigured as part of AKS Automatic production-ready defaults.
- **AKS Standard**: Preconfigured on AKS Standard clusters without extra setup.

Both modes use the same node health checks and the same repair sequence described in this article.

For more information about AKS Automatic platform defaults, see [What is Azure Kubernetes Service (AKS) Automatic?](./intro-aks-automatic.md)

## How AKS checks for NotReady nodes

AKS uses the following rules to determine if a node is unhealthy and needs repair:

- The node reports the [**NotReady**](https://kubernetes.io/docs/reference/node/node-status/#condition) status on consecutive checks within a 10-minute time frame.
- The node doesn't report any status within 10 minutes.

You can manually check the health state of your nodes with the `kubectl get nodes` command.

## How automatic repair works

> [!NOTE]
> AKS initiates repair operations with the user account **aks-remediator**.

If AKS identifies an unhealthy node that stays unhealthy for at least five minutes, AKS performs the following actions:

1. AKS reboots the node.
1. If the node stays unhealthy after reboot, AKS reimages the node.
1. If the node stays unhealthy after reimage and it's a Linux node, AKS redeploys the node.

AKS retries the restart, reimage, and redeploy sequence up to three times if the node stays unhealthy. The overall auto-repair process can take up to one hour to complete.

## Production considerations

Node auto-repair is a core resilience mechanism, but combine it with workload-level resiliency practices:

- Run critical workloads with multiple replicas.
- Use PodDisruptionBudgets and readiness probes to reduce user-visible impact.
- Monitor repair activity and error events to detect repeated node problems.
- Incorporate auto-repair timing into SLO/SLA and incident-response planning.

## Limitations

AKS node auto-repair is a best-effort service. AKS doesn't guarantee a node is restored to healthy status in every scenario. If a node remains unhealthy, perform manual investigation. For more information, see [Troubleshoot node NotReady status](/troubleshoot/azure/azure-kubernetes/availability-performance/node-not-ready-basic-troubleshooting).

AKS might not perform automatic repair in the following scenarios:

- A network configuration error prevents reporting of a node status.
- A node fails to register as a healthy node.
- A node has either of the following taints:
  - `node.cloudprovider.kubernetes.io/shutdown`
  - `ToBeDeletedByClusterAutoscaler`
- A node is being upgraded and has the following annotations:
  - `"cluster-autoscaler.kubernetes.io/scale-down-disabled": "true"`
  - `"kubernetes.azure.com/azure-cluster-autoscaler-scale-down-disabled-reason": "upgrade"`

## Monitor node auto-repair using Kubernetes events

When AKS performs node auto-repair, it emits Kubernetes events from the `aks-auto-repair` source. The following events appear on a node object when auto-repair occurs.

To learn more about accessing, storing, and alerting on Kubernetes events, see [Use Kubernetes events for troubleshooting in AKS](./events.md).

| Reason | Event message | Description |
| ------ | ------------- | ----------- |
| NodeRebootStart | Node auto-repair is initiating a reboot action due to NotReady status persisting for more than five minutes. | This event notifies you when reboot is about to be performed on your node. This action is the first in the overall node auto-repair sequence. |
| NodeRebootEnd | Reboot action from node auto-repair is completed. | Emitted once reboot is complete on the node. This event doesn't indicate the health status (healthy or unhealthy) of the node after the reboot is performed. |
| NodeReimageStart | Node auto-repair is initiating a reimage action due to NotReady status persisting for more than five minutes. | This event notifies you when reimage is about to be performed on your node. |
| NodeReimageEnd | Reimage action from node auto-repair is completed. | Emitted once reimage is complete on the node. This event doesn't indicate the health status (healthy or unhealthy) of the node after the reimage is performed. |
| NodeRedeployStart | Node auto-repair is initiating a redeploy action due to NotReady status persisting more than five minutes. | This event notifies you when redeploy is about to be performed on your node. Redeploy is the last action in the node auto-repair sequence. |
| NodeRedeployEnd | Redeploy action from node auto-repair is completed. | Emitted once redeploy is complete on the node. This event doesn't indicate the health status (healthy or unhealthy) of the node after redeploy is performed. |

If errors occur during node auto-repair, AKS emits the following events with the verbatim error message. For more information, see [Troubleshooting common node auto-repair errors](/troubleshoot/azure/azure-kubernetes/availability-performance/node-auto-repair-errors).

> [!NOTE]
> _Error code_ in the following event messages varies based on the reported error.

| Reason | Event message | Description |
| ------ | ------------- | ----------- |
| NodeRebootError | Node auto-repair reboot action failed due to an operation failure. See error details here: _Error code_ | Emitted when there's an error with the reboot action. |
| NodeReimageError | Node auto-repair reimage action failed due to an operation failure. See error details here: _Error code_ | Emitted when there's an error with the reimage action. |
| NodeRedeployError | Node auto-repair redeploy action failed due to an operation failure. See error details here: _Error code_ | Emitted when there's an error with the redeploy action. |

## Related content

- [What is Azure Kubernetes Service (AKS) Automatic?](./intro-aks-automatic.md)
- [Create an AKS Automatic cluster](./automatic/quick-automatic-managed-network.md)
- [Use Kubernetes events for troubleshooting in AKS](./events.md)
- [Troubleshoot node NotReady status in AKS](/troubleshoot/azure/azure-kubernetes/availability-performance/node-not-ready-basic-troubleshooting)
- [Troubleshoot common node auto-repair errors in AKS](/troubleshoot/azure/azure-kubernetes/availability-performance/node-auto-repair-errors)
- [Container insights overview](/azure/azure-monitor/containers/container-insights-overview)
