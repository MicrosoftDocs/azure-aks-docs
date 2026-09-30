---
title: Use the autoscaler profile to configure cluster autoscaling in AKS on Windows Server
description: Learn how to use the autoscaler profile to configure Cluster autoscaler in Azure Kubernetes Service (AKS) on Windows Server.
ms.topic: how-to
author: davidsmatlak
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 06/27/2024
ms.custom: windows-server

# Intent: As a Kubernetes user, I want to use cluster autoscaler to grow my nodes to keep up with application demand.
# Keyword: configure cluster autoscaling

---

# Use autoscaler profile to configure cluster autoscaling in AKS on Windows Server

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

You can use the parameters in the autoscaler profile object to define scale events in AKS on Windows Server. The cluster autoscaler profile affects all node pools that use the cluster autoscaler; you can't set an autoscaler profile per node pool. This article explains how the autoscaler works, describes default autoscaler profile values, and describes how to configure and use a profile definition.

## Using profiles

Cluster autoscaler profiles have the following attributes:

- Autoscaler profiles apply to all node pools in a cluster.
- Profiles are global deployment-level objects.
- Multiple profiles are available in AKS.
- Only one profile is assigned to a given cluster. The profile is used for all node pools in the cluster.
- Changes to the profile are applied to all node pools that have the autoscaler function enabled.

## Profile settings

The default profile uses the following default values. You can update the following settings.

| Setting | Description | Default value |
| --- | --- | --- |
| `min-node-count` | The minimum node count that the node pool to which this profile is assigned can scale down to. | 0 |
| `max-node-count` | The maximum node count that the node pool to which this profile is assigned can scale up to. | 1 |
| `scan-interval` | How often cluster is reevaluated for scale up or down. | 10 seconds |
| `scale-down-delay-after-add` | How long after scale up that scale down evaluation resumes. | 10 minutes |
| `scale-down-delay-after-delete` | How long after node deletion that scale down evaluation resumes. | `scan-interval` |
| `scale-down-delay-after-failure` | How long after a scale down failure that scale down evaluation resumes. | 3 minutes |
| `scale-down-unneeded-time` | How long a node should be unneeded before it's eligible for scale down. | 10 minutes |
| `scale-down-unready-time` | How long an unready node should be unneeded before it's eligible for scale down. | 20 minutes |
| `scale-down-utilization-threshold` | Node utilization level, defined as the sum of requested resources divided by capacity, below which a node can be considered for scale down. | 0.5 |
| `max-graceful-termination-sec` | Maximum number of seconds the cluster autoscaler waits for pod termination when trying to scale down a node. | 600 seconds |
| `balance-similar-node-groups` | Detects similar node pools and balances the number of nodes between them. | false |
| `expander` | Type of node pool [expander](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#what-are-expanders) to use in scale up. Possible values: `most-pods`, `random`, `least-waste`, `priority`. | `random` |
| `skip-nodes-with-local-storage` | If **true**, cluster autoscaler never deletes nodes with pods with local storage, for example, **EmptyDir** or **HostPath**. | **true** |
| `skip-nodes-with-system-pods` | If **true**, cluster autoscaler never deletes nodes with pods from `kube-system` (except for DaemonSet or mirror pods). | **true** |
| `max-empty-bulk-delete` | Maximum number of empty nodes that can be deleted at the same time. | 10 |
| `new-pod-scale-up-delay` | For scenarios such as burst or batch scale where you don't want the CA to act before the Kubernetes scheduler can schedule all the pods, you can tell the CA to ignore unscheduled pods before they're a certain age. | 0 seconds |
| `max-total-unready-percentage` | Maximum percentage of unready nodes in the cluster. After this percentage is exceeded, CA halts operations. | 45% |
| `max-node-provision-time` | Maximum time the autoscaler waits for a node to be provisioned. | 15 minutes |

## Notes on autoscaler configuration

You can change settings in the cluster autoscaler profile by using the [Set-AksHciAutoScalerConfig](work-with-horizontal-autoscaler.md#change-an-existing-akshciautoscalerconfig-profile-object) PowerShell cmdlet.

The cluster autoscaler makes scaling decisions based on the minimum and maximum counts set on each node pool, but it doesn't enforce them after updating the min or max counts. For example, setting a minimum count of 5 when the current node count is 3 doesn't immediately scale the pool up to 5.

If the minimum count on the node pool is higher than the current number of nodes, the new minimum or maximum settings take effect when there are enough unschedulable pods that require two new additional nodes and trigger an autoscaler event. After the scale event, the new count limits are respected.

You can also configure more granular details of the cluster autoscaler by changing the default values in the cluster-wide autoscaler profile. For example, a scale down event happens after nodes are under-utilized for 10 minutes. If you have workloads that run every 15 minutes, you might want to change the autoscaler profile to scale down under-utilized nodes after 15 or 20 minutes. When you enable the cluster autoscaler, a default profile is used unless you specify different settings.

## Save and load the autoscaler profile

You can save and store your autoscaler profile in a profile definition as a YAML file. You can manually edit the YAML file from a text editor, and you can load saved definitions.

### Save your profile definition

You save a copy of the profile as a YAML file by using `kvactl`. After you define your profile, run the following commands:

```powershell
kvactl.exe autoscalerprofile get --name default --kubeconfig (Get-AksHciConfig).Kva.kubeconfig --outputformat=yaml > def.yaml
```

### Edit your profile definition

You can edit the profile definition in the YAML file. For example, you can open **def.yaml** in Notepad, Visual Studio Code, or other text editors.

### Load your profile definition

You can load the profile definition by using `kvactl` from the saved YAML file. Run the following command:

```powershell
kvactl.exe autoscalerprofile create --profileconfig .\def-new.yaml --kubeconfig (Get-AksHciConfig).Kva.kubeconfig
```

## Next steps

- [Use PowerShell for cluster autoscaling](work-with-horizontal-autoscaler.md)
- [Learn about cluster autoscaling](concepts-cluster-autoscaling.md)
