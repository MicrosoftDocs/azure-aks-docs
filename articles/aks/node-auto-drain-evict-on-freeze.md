---
title: Configure pod eviction for freeze events in Azure Kubernetes Service (AKS) (preview)
description: Learn how to configure AKS node auto-drain to evict specific pods before freeze events occur on underlying virtual machines.
ms.topic: how-to
ms.date: 03/30/2026
author: varora24
ms.author: vaibhavarora
ai-usage: ai-assisted

# Customer intent: As a cluster operator, I want to evict sensitive pods before freeze events so that I can protect workloads that can't tolerate brief node disruptions.
---

# Configure pod eviction for freeze events in Azure Kubernetes Service (AKS) (preview)

> [!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

[Node auto-drain](./node-auto-drain.md) helps protect your workloads from disruptions when [scheduled events][scheduled-events] occur on the underlying virtual machines (VMs) in your node pools. By default, freeze events don't trigger cordon and drain because they usually pause a node only briefly. If you have workloads that can't tolerate short disruptions, you can opt in to evict labeled pods before the freeze begins.

Evict on freeze has two levels of configuration:

- **Cluster-level configuration**: A `ConfigMap` tells AKS to cordon the affected node when a freeze event is scheduled. Cordoning prevents new pods from being scheduled on the node but doesn't evict any existing pods by itself.
- **Pod-level configuration**: A label on individual pods opts them in for eviction. When the node is cordoned, AKS evicts only the pods that carry this label. Unlabeled pods remain on the node and aren't disrupted.

The `ConfigMap` alone only cordons the node, and the label alone has no effect without the `ConfigMap`. When both are in place, any node that receives a `VMEventScheduled` condition with a `Freeze` message is cordoned and labeled pods are evicted. Eviction respects [Pod Disruption Budgets (PDBs)][pdb-docs], so pods can only be evicted if the PDB allows it.

## Prerequisites

- An existing AKS cluster. If you don't have one, [create an AKS cluster](/azure/aks/learn/quick-kubernetes-deploy-cli).
- The `kubectl` command-line tool configured to connect to your cluster.
- Properly configured [Pod Disruption Budgets][pdb-docs] for the workloads you want to evict.

## Enable node cordoning for freeze events

Publish a `ConfigMap` in the `kube-system` namespace to tell AKS to cordon nodes when freeze events are scheduled. Cordoning marks the node as unschedulable so no new pods land on it, but doesn't remove any existing pods. To evict specific pods during the freeze, you must also [label them for eviction](#label-pods-for-eviction-during-freeze-events).

1. Create a file named `remediator-config.yaml` with the following contents:

    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: remediator-config
      namespace: kube-system
    data:
      appConfig: |
        {
          "Cluster": {
            "OnFreeze": {
              "Enabled": true
            }
          }
        }
    ```

1. Apply the `ConfigMap` to your cluster using `kubectl apply`:

    ```bash
    kubectl apply -f remediator-config.yaml
    ```

> [!NOTE]
> The configuration is read every 30 minutes, so changes might not be immediately applied to the cluster.

## Label pods for eviction during freeze events

After you enable the cluster-level configuration, mark individual pods for eviction by applying the `remediator.kubernetes.azure.com/onFreeze` label. During the drain phase, only pods with this label are evicted.

You can add the label to your workload manifest or apply it to running pods.

### Add the label in a deployment manifest

For persistent workloads, add the label to the pod template in your deployment manifest so Kubernetes keeps the setting when it recreates the pods:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: some-pod-safe-to-evict
  labels:
    remediator.kubernetes.azure.com/onFreeze: ""
spec:
  containers:
    - name: my-container
      image: mcr.microsoft.com/mcr/hello-world:latest
```

### Apply the label to an existing pod

Use `kubectl label` to add the label to a running pod:

```bash
kubectl label pod <pod-name> remediator.kubernetes.azure.com/onFreeze=""
```

This method is useful for quick validation, but the label is removed if Kubernetes recreates the pod.

When both the `ConfigMap` and pod labels are configured, AKS cordons the node and evicts only the labeled pods about five minutes before the scheduled freeze event time. Unlabeled pods continue running on the cordoned node.

> [!IMPORTANT]
> Ensure your [Pod Disruption Budgets][pdb-docs] are properly configured. If the PDB doesn't allow disruption at the time of the scheduled event, the eviction fails.

## Troubleshoot eviction for freeze events

If you notice freeze events but no cordon or drain events follow, or pods aren't being evicted as expected, use the following steps to investigate.

### Check Kubernetes events

You can use the Kubernetes event log or [Container Insights][container-insights] to monitor the progression of cordon, drain, and eviction for freeze events. For more information, see [Use Kubernetes events for troubleshooting](./events.md).

The following events appear during the drain and eviction process:

| Event | Description |
| --- | --- |
| `VMEventScheduled` | Marks the start of the scheduled VM event lifecycle for the node. |
| `FreezeScheduled` | Indicates a freeze event is scheduled, including the scheduled time. |
| `NodeCordonStart` | The node cordon begins, approximately five minutes before the scheduled event. |
| `NodeCordonEnd` | The node cordon completes. |
| `NodeDrainStart` | The drain begins and labeled pods start being evicted. |
| `Evicted` | A pod event that shows the specific pod that was evicted. |
| `FailedToEvict` | A pod event that indicates a pod failed to evict for any reason. |
| `NodeDrainEnd` | The drain completes when labeled pods are evicted. |
| `NoVMEventScheduled` | When no scheduled events are found for the node. |
| `NodeUncordonStart` | After the freeze event finishes, the node uncordon begins. |
| `NodeUncordonEnd` | The node uncordon completes and the node is schedulable again. |

If failures occur at any step, a separate error event is logged. For example, a `NodeDrainError` event appears with details in the event message.

If you see `FreezeScheduled` events but no `NodeCordonStart` events, the cluster-level `ConfigMap` might not be applied correctly. If you see cordon events but labeled pods aren't being evicted, verify that the pods carry the `remediator.kubernetes.azure.com/onFreeze` label and that the PDB allowed eviction at the time of the event.

### Verify the ConfigMap

Confirm that the cluster-level `ConfigMap` is correctly applied by running the following command:

```bash
kubectl describe configmap remediator-config -n kube-system
```

Compare the output with the configuration described in [Enable node cordoning for freeze events](#enable-node-cordoning-for-freeze-events).

### Verify pod labels

Confirm that the pods you want evicted have the correct label by running the following command:

```bash
kubectl get pods --show-labels -o wide
```

Verify that the `remediator.kubernetes.azure.com/onFreeze` label appears on the expected pods and that the pods are running on the target nodes. Pods without this label aren't evicted during the drain phase.

### Verify Pod Disruption Budgets

Confirm that your PDBs allow eviction at the time of the scheduled event:

```bash
kubectl get pdb
```

If the PDB doesn't allow disruption, the eviction fails even if the pod is correctly labeled.

## Limitations

- You can't trigger or simulate freeze events directly. However, freeze events are common in canary environments. To evaluate this feature, create clusters in the `eastus2euap` or `centraluseuap` regions.
- The `ConfigMap` is read every 30 minutes, so configuration changes might not be applied immediately.
- Eviction depends on [Pod Disruption Budgets][pdb-docs]. If a PDB doesn't allow disruption, eviction fails.

## Related content

- [Node auto-drain overview](./node-auto-drain.md)
- [Node auto-repair](./node-auto-repair.md)
- [Use Kubernetes events for troubleshooting](./events.md)
- [Scheduled events for Linux VMs in Azure](/azure/virtual-machines/linux/scheduled-events)

<!-- LINKS -->
[scheduled-events]: /azure/virtual-machines/linux/scheduled-events
[pdb-docs]: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/#pod-disruption-budgets
[container-insights]: /azure/azure-monitor/containers/container-insights-overview
