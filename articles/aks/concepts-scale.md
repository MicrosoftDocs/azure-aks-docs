---
title: AKS Scaling Overview — HPA, VPA, Cluster Autoscaler, and KEDA
description: Understand the AKS scaling options — Horizontal Pod Autoscaler, Vertical Pod Autoscaler, Cluster Autoscaler, and KEDA — and choose the right method for your workload type.
ms.topic: overview
ms.date: 07/23/2026
author: schaffererin
ms.author: schaffererin
ms.custom: biannual, aks-scaling
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: As a cloud architect, I want to understand the scaling options in Kubernetes, so that I can efficiently manage application performance and resource allocation in Azure Kubernetes Service (AKS).
---

# Azure Kubernetes Service (AKS) scaling overview — HPA, VPA, Cluster Autoscaler, and KEDA

When you run applications in Azure Kubernetes Service (AKS), you can scale pods, pod resources, nodes, or event-driven workloads to match changes in demand. AKS supports manual scaling, Horizontal Pod Autoscaler (HPA), Vertical Pod Autoscaler (VPA), Cluster Autoscaler, Kubernetes Event-driven Autoscaling (KEDA), node autoprovisioning, and burst scaling with Azure Container Instances (ACI).

## Choose the right scaling method

| Scaling method | Best for | Key metric | Guide |
| --- | --- | --- | --- |
| [Horizontal Pod Autoscaler (HPA)](./horizontal-pod-autoscaler.md) | Stateless or partitionable workloads with variable demand | CPU utilization, RPS, queue depth | [When should I use Horizontal Pod Autoscaling (HPA) in Kubernetes?](./horizontal-pod-autoscaler.md#when-should-i-use-horizontal-pod-autoscaling-hpa-in-kubernetes) |
| [Vertical Pod Autoscaler (VPA)](./vertical-pod-autoscaler.md) | Non-parallelizable workloads; right-sizing pod resource requests | CPU/memory resource usage | [Use Vertical Pod Autoscaler in AKS](./use-vertical-pod-autoscaler.md) |
| [Cluster Autoscaler](./cluster-autoscaler-overview.md) | Node-level capacity when pods remain Pending | Pending pods | [Use Cluster Autoscaler in AKS](./cluster-autoscaler.md) |
| [KEDA](./keda-about.md) | Event-driven workloads; scale-to-zero required | Queue length, event backlog | [KEDA add-on overview](./keda-about.md) |
| [ACI burst scaling](./virtual-nodes.md) | Spike handling beyond node pool capacity | Burst demand | [Create virtual nodes with Azure Container Instances](./virtual-nodes-cli.md) |

## Manually scale pods or nodes

You can manually scale pod replicas and nodes to test how your application responds to changes in available resources or to maintain a fixed amount of capacity. To scale manually, define the required replica or node count. Kubernetes then creates or removes pods, while AKS adds or removes nodes from the applicable node pool.

When you scale down nodes, AKS calls the relevant Azure Compute API for the cluster's compute type. For clusters built on Virtual Machine Scale Sets, the Virtual Machine Scale Sets API determines which nodes to remove. For more information, see the [Virtual Machine Scale Sets FAQ](/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-faq#if-i-reduce-my-scale-set-capacity-from-20-to-15--which-vms-are-removed-).

To get started, see:

- [Manually scale nodes in an AKS cluster](./scale-cluster.md)
- [`kubectl scale`](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_scale/)

## Horizontal Pod Autoscaler

Use HPA when your workload can run multiple identical replicas and demand fluctuates. It scales on CPU/memory, application metrics (requests per second, latency), or external queue and backlog metrics — and should be combined with Cluster Autoscaler for node capacity.

:::image type="content" source="media/concepts-scale/horizontal-pod-autoscaling.png" alt-text="Screenshot of a diagram showing how the Horizontal Pod Autoscaler works with AKS." lightbox="media/concepts-scale/horizontal-pod-autoscaling.png":::

Learn more: [When should I use Horizontal Pod Autoscaling (HPA) in Kubernetes?](./horizontal-pod-autoscaler.md)

See also: [Use Vertical Pod Autoscaler in AKS](./vertical-pod-autoscaler.md) to right-size pod CPU and memory requests.

## Vertical Pod Autoscaler

Vertical Pod Autoscaler analyzes pod CPU and memory usage and recommends or applies appropriate resource requests. Use VPA to right-size workloads that can't scale efficiently by adding replicas or to improve scheduling and resource utilization.

Depending on its update mode, VPA can apply recommendations when pods are created or evict and recreate pods with updated resource requests. Review workload availability requirements before allowing VPA to apply changes automatically.

To get started, see [Use Vertical Pod Autoscaler in AKS](./use-vertical-pod-autoscaler.md).

## Cluster Autoscaler

Cluster Autoscaler adjusts the number of nodes in a node pool according to pod scheduling requirements. It adds nodes when pods can't be scheduled because of insufficient node capacity and removes underutilized nodes when their workloads can run elsewhere.

:::image type="content" source="media/concepts-scale/cluster-autoscaler.png" alt-text="Screenshot of a diagram showing how the Cluster Autoscaler works with AKS." lightbox="media/concepts-scale/cluster-autoscaler.png":::

Cluster Autoscaler is commonly used with [HPA](./horizontal-pod-autoscaler.md). HPA adjusts the number of pod replicas based on workload demand, while Cluster Autoscaler adjusts node capacity to accommodate those pods.

To get started, see [Use Cluster Autoscaler in AKS](./cluster-autoscaler.md).

### Scale-out events

If a node pool doesn't have sufficient compute resources for a pod, the pod remains Pending. When Cluster Autoscaler detects pods that can't be scheduled because of node pool resource constraints, it increases the number of nodes in the node pool. Kubernetes schedules the pending pods after the new nodes are provisioned and become ready.

Provisioning VM-based nodes can take several minutes. For workloads with sudden burst demand, consider using [virtual nodes and Azure Container Instances](#burst-to-azure-container-instances-aci).

### Scale-in events

Cluster Autoscaler monitors nodes for underutilization and determines whether their pods can run on other nodes. When a node is no longer required, Kubernetes reschedules its pods and AKS removes the node from the node pool.

Scale-in operations can disrupt workloads as pods move between nodes. Run multiple pod replicas and configure appropriate availability controls to minimize disruption.

## Kubernetes Event-driven Autoscaling

[Kubernetes Event-driven Autoscaling](https://keda.sh/docs/2.13/concepts/) (KEDA) is an open-source component that scales workloads based on events. KEDA extends Kubernetes with custom resources, including `ScaledObject`, that describe how a workload should respond to an event source or metric.

KEDA is useful for workloads that process queues, streams, messages, or other event backlogs. It can scale supported workloads to zero when no events are available and increase replicas as the backlog grows.

To get started, see the [KEDA add-on overview](./keda-about.md).

## Node autoprovisioning

[Node autoprovisioning](./node-auto-provisioning.md) (NAP) uses the open-source [Karpenter](https://karpenter.sh/) project to provision and manage nodes according to pending pod requirements. NAP selects an appropriate virtual machine SKU and node quantity to meet real-time workload demand.

NAP starts with an allowed set of VM SKUs and selects capacity for pending workloads. You can define resource limits and scheduling preferences to control how it provisions nodes and distributes workloads.

## Control plane scaling and safeguards

Kubernetes has a multidimensional scale envelope in which each resource type places different demands on the control plane. For example, watches on resources such as secrets can produce list calls to the Kubernetes API server and create more control plane load than resources without watches.

Because the control plane manages resource operations across the cluster, scaling heavily in one dimension can reduce the capacity available in others. For example, running hundreds of thousands of pods can affect the pod mutation rate that the control plane supports. For recommendations, see [Kubernetes client best practices for large-scale AKS clusters](./best-practices-performance-scale-large.md#kubernetes-client-best-practices).

AKS automatically scales control plane components based on signals such as the total number of cluster cores and CPU or memory pressure on control plane components.

To check whether the control plane has scaled up, inspect the `large-cluster-control-plane-scaling-status` ConfigMap:

```bash
kubectl describe configmap large-cluster-control-plane-scaling-status -n kube-system
```

### Control plane safeguards

If automatically scaling the API server doesn't stabilize it under high load, AKS can deploy a managed API server guard. This last-resort safeguard throttles non-system client requests to prevent the control plane from becoming unresponsive. System-critical API server calls from components such as `kubelet` continue to function.

To determine whether the managed API server guard has been applied, check for the `aks-managed-apiserver-guard` `FlowSchema` and `PriorityLevelConfiguration`:

```bash
kubectl get flowschemas
kubectl get prioritylevelconfigurations
```

If these resources are present, see the [API server and etcd troubleshooting guide](/troubleshoot/azure/azure-kubernetes/troubleshoot-apiserver-etcd#cause-4-aks-managed-api-server-guard-was-applied) for mitigation guidance.

## Burst to Azure Container Instances (ACI)

You can integrate AKS with Azure Container Instances to handle rapid increases in demand. Pod autoscaling can create more replicas than the existing node pool can support, while provisioning additional VM-based nodes can take several minutes. ACI provides compute capacity without requiring additional VM nodes.

:::image type="content" source="media/concepts-scale/burst-scaling.png" alt-text="Screenshot of a diagram showing how Azure Container Instances works with AKS." lightbox="media/concepts-scale/burst-scaling.png":::

The AKS [virtual nodes](./virtual-nodes.md) component is based on [Virtual Kubelet](https://virtual-kubelet.io/) and presents ACI as a virtual Kubernetes node. Kubernetes can schedule eligible pods through the virtual node to run as ACI container instances instead of directly on AKS VM nodes.

Virtual nodes use another subnet in the same virtual network as the AKS cluster. This configuration provides private network connectivity between AKS and ACI while allowing ACI to act as a logical extension of the cluster.

## Next steps

Use the following resources to implement the scaling method that fits your workload:

- [Manually scale pods](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_scale/) or [nodes](./scale-cluster.md)
- [When should I use Horizontal Pod Autoscaling (HPA) in Kubernetes?](./horizontal-pod-autoscaler.md)
- [Use Vertical Pod Autoscaler in AKS](./vertical-pod-autoscaler.md)
- [Use Cluster Autoscaler in AKS](./cluster-autoscaler-overview.md)
- [Use the KEDA add-on](./keda-about.md)
- [Use node autoprovisioning](./node-auto-provisioning.md)
- [Create virtual nodes with Azure Container Instances](./virtual-nodes-cli.md)

For more information about core Kubernetes and AKS concepts, see:

- [Core AKS concepts](./core-aks-concepts.md)
- [Access and identity](./concepts-identity.md)
- [Security](./concepts-security.md)
- [Virtual networks](./concepts-network.md)
- [Storage](./concepts-storage.md)
