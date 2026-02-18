---
title: Configure pod eviction for freeze events in Azure Kubernetes Service (AKS) (preview)
description: Learn how to configure AKS node auto-drain to evict specific pods before freeze events occur on underlying virtual machines.
ms.topic: how-to
ms.date: 02/18/2026
author: varora24
ms.author: vaibhavarora
ai-usage: ai-assisted

# Customer intent: As a cluster operator, I want to evict sensitive pods before freeze events so that I can protect workloads that can't tolerate brief node disruptions.
---

# Configure pod eviction for freeze events in AKS (preview)

[Node auto-drain](./node-auto-drain.md) helps protect your workloads from disruptions when [scheduled events][scheduled-events] occur on the underlying virtual machines (VMs) in your node pools. By default, freeze events don't trigger a cordon and drain action because they're typically brief pauses. However, some workloads are highly sensitive to any node disruption. With Evict On Freeze, you can configure AKS to automatically cordon and drain nodes before a freeze event takes place.

Evict On Freeze has two levels of configuration:

- **Cluster-level configuration**: A `ConfigMap` enables AKS to respond to freeze events by cordoning and draining the affected node. This step alone doesn't evict any specific pods.
- **Pod-level configuration**: A label on individual pods marks them as safe to evict during the drain phase. Only pods with this label are evicted. Unlabeled pods remain on the node and aren't disrupted.

When these configurations are in place, any node that has a `VMEventScheduled` condition with a `Freeze` message is cordoned, and labeled pods are evicted. Eviction respects [Pod Disruption Budgets (PDBs)][pdb-docs], so pods can only be evicted if the PDB allows it.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

- An existing AKS cluster. If you don't have one, [create an AKS cluster](/azure/aks/learn/quick-kubernetes-deploy-cli).
- The `kubectl` command-line tool configured to connect to your cluster.
- Properly configured [Pod Disruption Budgets][pdb-docs] for the workloads you want to evict.

## Enable cordon and drain for freeze events

Enable Evict On Freeze at the cluster level by publishing a `ConfigMap` in the `kube-system` namespace. This `ConfigMap` instructs AKS to watch for freeze events and cordon and drain affected nodes. This step alone doesn't evict specific pods — you must also [label pods for eviction](#step-2-label-pods-for-eviction-during-freeze-events).

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

After you enable the cluster-level configuration, mark individual pods for eviction by applying the `remediator.kubernetes.azure.com/OnFreeze` label. During the drain phase, only pods with this label are evicted.

You can add the label directly to a pod's deployment manifest or apply it to running pods.

### Add the label in a deployment manifest

Include the label in the `metadata.labels` section of your pod spec:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: some-pod-safe-to-evict
  labels:
    remediator.kubernetes.azure.com/OnFreeze: ""
spec:
  containers:
    - name: my-container
      image: mcr.microsoft.com/oss/nginx/nginx:1.25
```

### Apply the label to an existing pod

Use `kubectl label` to add the label to a running pod:

```bash
kubectl label pod <pod-name> remediator.kubernetes.azure.com/OnFreeze=""
```

When configured, AKS cordons the node and begins evicting labeled pods approximately five minutes before the scheduled freeze event time.

> [!IMPORTANT]
> Ensure your [Pod Disruption Budgets][pdb-docs] are properly configured. If the PDB doesn't allow disruption at the time of the scheduled event, the eviction fails.

## Troubleshoot Evict On Freeze

If you notice freeze events but no cordon or drain events follow, or pods aren't being evicted as expected, use the following steps to investigate.

### Check Kubernetes events

You can use the Kubernetes event log or [Container Insights][container-insights] to monitor the progression of cordon, drain, and eviction for freeze events. For more information, see [Use Kubernetes events for troubleshooting](./events.md).

The following events appear during the Evict On Freeze process:

| Event | Description |
| --- | --- |
| `FreezeScheduled` | Indicates a freeze event is scheduled, including the scheduled time. |
| `NodeCordonStart` | The node cordon begins, approximately five minutes before the scheduled event. |
| `NodeCordonEnd` | The node cordon completes. |
| `NodeDrainStart` | The drain begins and labeled pods start being evicted. |
| `NodeDrainEnd` | The drain completes and labeled pods have been evicted. |
| `NodeUncordonStart` | After the freeze event finishes, the node uncordon begins. |
| `NodeUncordonEnd` | The node uncordon completes and the node is schedulable again. |

If failures occur at any step, a separate error event is logged. For example, a `NodeDrainError` event appears with details in the event message.

If you see `FreezeScheduled` events but no `NodeCordonStart` events, the cluster-level configuration might not be applied correctly. If you see cordon events but pods aren't being evicted, verify the pod-level labels.

### Verify the ConfigMap

Confirm that the cluster-level `ConfigMap` is correctly applied by running the following command:

```bash
kubectl describe configmap remediator-config -n kube-system
```

Compare the output with the configuration described in the [Enable cordon and drain for freeze events](#enable-cordon-and-drain-for-freeze-events) section.

### Verify pod labels

Confirm that the pods you want evicted have the correct label by running the following command:

```bash
kubectl get pods --show-labels -o wide
```

Verify that the `remediator.kubernetes.azure.com/OnFreeze` label appears on the expected pods and that the pods are running on the target nodes. Pods without this label aren't evicted during the drain phase.

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
