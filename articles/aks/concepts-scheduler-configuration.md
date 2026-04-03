---
title: Concepts - Scheduler Configuration in Azure Kubernetes Service (AKS)
description: Learn about scheduler configuration and advanced scheduling concepts for Azure Kubernetes Service (AKS).
ms.service: azure-kubernetes-service
ms.topic: concept-article
ms.date: 09/30/2025
ms.author: sachidesai
author: sachidesai
# Customer intent: "As a Kubernetes cluster operator, I want to learn about advanced scheduling strategies using one or more in-tree scheduling plugins, so that I can effectively manage workload distribution and resource allocation across my AKS clusters."
---

# Scheduler configuration concepts for workload placement in Azure Kubernetes Service (AKS)

This article covers scheduler configuration and advanced scheduling concepts for workload placement in Azure Kubernetes Service (AKS), including configurable scheduler profiles, scheduling plugins, and scheduling constraints. 

## About the AKS scheduler

In AKS, the default mechanism of workload placement across nodes within a cluster is through the scheduler. The default scheduler is a control plane component responsible for assigning AKS deployment pods to nodes. Once the AKS scheduler selects a node, the deployment pod is bound to it, and the rest of the lifecycle continues. 

When a pod is created without a specified node, the scheduler selects an optimal node based on several criteria, including (but not limited to):

- Available resources (CPU, memory)
- [Node affinity/anti-affinity](./operator-best-practices-advanced-scheduler.md#node-affinity)
- [Pod affinity/anti-affinity](./operator-best-practices-advanced-scheduler.md#inter-pod-affinity-and-anti-affinity)
- [Taints and tolerations](./operator-best-practices-advanced-scheduler.md#provide-dedicated-nodes-using-taints-and-tolerations)

### AKS scheduler configuration and scheduling strategies

By default, the AKS scheduler comes with a set of built-in rules that work well for general-purpose workloads. However, advanced use cases might require custom scheduling strategies. For example:

- Batch jobs might prefer collocating in a few nodes (for better performance) over topology-aware spreading (for reliability).
- Cost-sensitive workloads might benefit from node binpacking to consolidate jobs and minimize idle compute node costs.

To support these use cases, AKS allows you to set one or more in-tree scheduling plugins through a Kubernetes custom resource (CRD) to configure the scheduling behavior on your AKS cluster.


## Configurable scheduler profiles

A scheduler profile is a set of one or more in-tree scheduling plugins and configurations that dictate how to schedule a pod. Previously, AKS managed the scheduler configuration, and it wasn't accessible to users. Starting from Kubernetes version `1.33`, you can now configure and set a scheduler profile (preview) for the Kubernetes scheduler on your cluster.

Each scheduler profile has the following components:

- A unique name.
- A set of [scheduling plugins](#supported-in-tree-scheduling-plugins).
- Custom arguments for fine-grained behavior (applicable to certain plugins).


## Supported in-tree scheduling plugins

AKS supports configuration of 18 in-tree Kubernetes scheduling plugins that allow pods to be placed on specific nodes, ensure pods are matched with specific storage resources, optimize for nodes with container images, and more.

The following sections walk you through these plugins, which are grouped into the following categories: 

- [Scheduling constraints and order-based plugins](#scheduling-constraints-and-order-based-plugins)
- [Node selection constraints scheduling plugins](#node-selection-constraints-scheduling-plugins)
- [Resource and topology optimization scheduling plugins](#resource-and-topology-optimization-scheduling-plugins)

To learn more about these plugins and configuration options, see the [Kubernetes Scheduling Plugin documentation](https://kubernetes.io/docs/reference/scheduling/config/#scheduling-plugins).


### Scheduling constraints and order-based plugins

- `DefaultBinder`: Responsible for binding the pod to a node after the scheduler selects a suitable node. Once the node is selected, the `DefaultBinder` creates a binding object to ensure the pod is scheduled onto that node.

- `DefaultPreemption`: Handles preemption, which is the process of evicting lower-priority pods to make room for higher-priority pods. If a pod can't be scheduled because there aren’t enough resources on the node, this plugin preempts other pods to make space. This plugin can receive the following arguments:

    - `PodPriority`: Defines the priority of the pod being scheduled.
    - `PreemptionPolicy`: The policy for handling pod preemption (for example: `"PreemptLowerPriority"` or `"DoNotPreempt"`).
    - `PodPriorityClass`: The priority class associated with the pod.
    - `PodInfo`: Information about the pods that are candidates for preemption.
    - `Node`: Information about the node on which preemption is considered.
  
- `SchedulingGates`: Introduces the concept of scheduling gates, which are conditions that must be satisfied before a pod is scheduled. For example, it can enforce the completion of certain tasks or operations before the scheduler attempts to schedule a pod.
- `PrioritySort`: Sorts the list of pods according to their priority class. Pods with higher priority are scheduled first. It helps with the preemption decision-making and determines which pods to consider for priority scheduling.

  
### Node selection constraints scheduling plugins

- `InterPodAffinity`: Takes into account _affinity_ rules specified by the user that influences scheduling based on the proximity of other pods. If a pod has affinity rules, it tries to schedule the pod on the same node or in the same topology as other pods that it has an affinity for (for example: for performance reasons or tight coupling). This plugin can receive the following arguments:

     - `Affinity`: Defines required or preferred affinity rules for the pod, which specifies other pods that the pod should or shouldn't be scheduled nearby.
     - `TopologyKey`: The key representing the failure domain to which the affinity rule applies (for example: `"kubernetes.io/hostname"` for node-level affinity or `"topology.kubernetes.io/zone"` for zone-level).
     - `Weight`: Defines how strongly the scheduler should consider a specific affinity rule.
     - `Pod`: The pod being scheduled.
     - `OtherPods`: List of other pods to consider in relation to the affinity rules.

- `NodeAffinity`: Enables scheduling based on node labels. It allows users to specify rules for which nodes a pod can be scheduled on based on the node's labels and provides fine-grained control over pod placement on nodes. This plugin can receive the following arguments:

    - `NodeAffinity`: Defines the required or preferred node affinity rules, such as `requiredDuringSchedulingIgnoredDuringExecution` or `preferredDuringSchedulingIgnoredDuringExecution`.
    - `NodeSelectorTerms`: Defines the set of node labels and values that must match.
    - `Pod`: The pod being scheduled.
    - `Node`: A potential node for scheduling.
    - `LabelSelector`: A selector for choosing nodes based on labels.

- `NodeName`: Forces pods to be scheduled on a specific node. When you specify the exact node name, the scheduler places the pod on that node if possible.
- `NodePorts`: Ensures that a pod with a service of type `NodePort` can be scheduled on a node that has the required ports available for binding. It checks whether the node has enough resources to support the node port allocations for the service.
- `NodeUnschedulable`: Ensures that pods aren't scheduled on nodes marked as _unschedulable_. If a node is tainted with `node.kubernetes.io/unschedulable`, the scheduler doesn't place any new pods on that node.
- `TaintToleration`: Checks if a pod has the required tolerations to be scheduled on a node that has taints. Taints on nodes prevent pods from being scheduled unless the pod has a matching toleration.
- `NodeVolumeLimits`: Checks whether a node has exceeded its volume limit. Each node has a maximum number of volumes it can attach, and this plugin ensures that the pod isn't scheduled on a node that has already reached that supported limit.
- `VolumeBinding`: Ensures that persistent volumes (PVs) are properly bound to pods. It checks whether the volume that a pod requires can be bound to a node and ensures the volume is available on the selected node. This plugin can receive the following arguments:

     - `VolumeClaims`: The persistent volume claims (PVCs) made by the pod being scheduled.
     - `Node`: The candidate node being considered for scheduling.
     - `VolumeAvailable`: Checks if the persistent volume is available on the node or within the appropriate zone.
     - `Pod`: The pod that is requesting volume binding.
     - `StorageClass`: The storage class associated with the persistent volume.
     - `VolumeBindingMode`: Defines whether the volume binding mode is `Immediate` or `WaitForFirstConsumer` (for delayed binding until a pod is scheduled).

- `VolumeRestrictions`: Ensures that volume restrictions (such as limitations on the number of volumes a node can have attached) are respected when scheduling a pod. It prevents scheduling a pod on a node where the volume restrictions would be violated.
- `VolumeZone`: Ensures that volumes are scheduled in the same availability zone as the pod. For example, if a pod requests a volume that must be in a specific zone, the plugin ensures that both the pod and the volume are in the same zone.


### Resource and topology optimization scheduling plugins

- `NodeResourcesBalancedAllocation`: Aims to balance the resource allocation on nodes. When scheduling a pod, it considers how resources like CPU and memory are allocated across nodes to avoid overprovisioning or underutilizing resources. This plugin can receive the following arguments:

     - `ResourceRequests`: The resource requests (CPU, memory, etc.) of the pod being scheduled.
     - `Node`: A candidate node for scheduling.
     - `NodeResources`: The available resources (CPU, memory, etc.) of the node.
     - `ClusterResourceUsage`: Cluster-wide resource usage metrics to help decide the best node to balance resources.

- `NodeResourcesFit`: Checks whether a node has enough available resources (CPU, memory, etc.) to run the pod. It ensures that a pod is only scheduled on a node that has sufficient resources available. This plugin can receive the following arguments:

    - `ResourceRequests`: The resource requests of the pod.
    - `Node`: The candidate node being considered for scheduling.
    - `NodeCapacity`: The available capacity of resources on the node.
    - `Pod`: The pod being scheduled, with its resource requests.
 
- `ImageLocality`: Helps the scheduler decide whether to schedule a pod onto a node based on the presence of a required container image. It tries to schedule pods on nodes where the required image is already present, reducing the time needed to pull the image.
- `PodTopologySpread`: Ensures that pods are spread evenly across the topology (like zones or regions) to achieve high availability and fault tolerance. It tries to avoid placing multiple replicas of a pod in the same failure domain. This plugin can receive the following arguments:

    - `TopologySpreadConstraints`: Defines the constraints for how pods should be spread across failure domains, including the key (for example: `topology.kubernetes.io/zone`) and the number of pods to be placed in each domain. 
    - `Pod`: The pod being scheduled.
    - `FailureDomain`: The failure domain key (for example: zone or region).
    - `PodAffinity`: Information about pod affinity, which could also impact how the pods are distributed.
    - `Node`: Potential nodes for placement.
    - `PodSpreadScore`: Used to determine how much "spread" the pod should have across domains (higher scores indicate better spreading).

## Next step

> [!div class="nextstepaction"]

> [Configure and deploy a scheduler profile (preview) on your AKS cluster](./configure-aks-scheduler.md).
