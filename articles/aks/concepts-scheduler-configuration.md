---
title: Concepts - Configuring the Scheduler in Azure Kubernetes Service (AKS)
description: Learn about advanced scheduling concepts on Azure Kubernetes Service (AKS)
ms.topic: concept-article
ms.date: 09/30/2025
ms.author: sachidesai
author: sachidesai
# Customer intent: "As a Kubernetes cluster operator, I want to learn about advanced scheduling strategies using one or more in-tree scheduling plugins, so that I can effectively manage workload distribution and resource allocation across my AKS clusters."
---

# Scheduler configuration concepts for workload placement in Azure Kubernetes Service (AKS)

On Azure Kubernetes Service (AKS), the default mechanism of workload placement across nodes within a cluster is via the scheduler. The default scheduler is a control plane component responsible for assigning AKS deployment pods to nodes. When a pod is created without a specified node, the scheduler selects an optimal node based on several criteria, including (but not limited to):

* Available resources (CPU, memory)
* [Node affinity/anti-affinity](./operator-best-practices-advanced-scheduler.md#node-affinity)
* [Pod affinity/anti-affinity](./operator-best-practices-advanced-scheduler.md#inter-pod-affinity-and-anti-affinity)
* [Taints and tolerations](./operator-best-practices-advanced-scheduler.md#provide-dedicated-nodes-using-taints-and-tolerations)

Once the AKS scheduler selects a node, the deployment pod is bound to it, and the rest of the lifecycle continues. 

By default, the AKS scheduler comes with a set of built-in rules that work well for general-purpose workloads. However, advanced use cases may require custom scheduling strategies. For example,

* Batch jobs might prefer collocating in a few nodes (for better performance) over topology-aware spreading (for reliability).
* Cost-sensitive workloads may benefit from node binpacking to consolidate jobs and minimize idle compute node costs.

To support these use cases, AKS allows you to set one or more in-tree scheduling plugins via a Kubernetes custom resource (CRD) to configure the scheduling behavior on your AKS cluster.

## Configurable scheduler profiles (preview)

A scheduler profile is a set of one or more in-tree scheduling plugins and configurations that dictate how a pod should be scheduled. Previously, the scheduler configuration was managed by AKS and not accessible to the users. Starting from Kubernetes version `1.33`, you can now configure and set a scheduler profile (preview) used by the Kubernetes scheduler on your cluster.

Each scheduler profile has:

* A unique name.
* A set of scheduling plugins.
* Custom arguments for fine-grained behavior (applicable to certain plugins)

## Supported in-tree scheduling plugins

AKS supports configuration of the following Kubernetes scheduling plugins:

Learn more about these plugins and configuration options with the [Official Kubernetes Scheduling Plugin documentation](https://kubernetes.io/docs/reference/scheduling/config/#scheduling-plugins).

### Scheduling Constraints and Order-based Plugins

`DefaultBinder`: Responsible for binding the pod to a node after the scheduler has selected a suitable node. Once the node is chosen, the `DefaultBinder` ensures that the pod is scheduled onto that node by creating a binding object.

`DefaultPreemption`: Handles preemption, which is the process of evicting lower-priority pods to make room for higher-priority pods. If a pod cannot be scheduled because there aren’t enough resources on the node, this plugin will preempt other pods to make space.

**Arguments it may receive**:

  * `PodPriority`: Defines the priority of the pod being scheduled.
  * `PreemptionPolicy`: The policy for handling pod preemption (e.g., "PreemptLowerPriority" or "DoNotPreempt").
  * `PodPriorityClass`: The priority class associated with the pod.
  * `PodInfo`: Information about the pods that are candidates for preemption.
  * `Node`: Information about the node on which preemption is considered.
  
`SchedulingGates`: Introduces the concept of scheduling gates, which are conditions that must be satisfied before a pod is scheduled. For example, it can enforce the completion of certain tasks or operations before the scheduler attempts to schedule a pod.
  
`PrioritySort`: Sorts the list of pods according to their priority class. Pods with higher priority will be scheduled first. It helps with the preemption decision-making and determines which pods should be considered for scheduling first.
  
### Node Selection Constraints Scheduling Plugins

`InterPodAffinity`: Takes into account *affinity* rules specified by the user that influence scheduling based on the proximity of other pods. If a pod has affinity rules, it will try to schedule the pod on the same node or in the same topology as other pods that it has an affinity for. (e.g., for performance reasons or tight coupling).

**Arguments it may receive**:

  * `Affinity`: Defines the affinity rules (required or preferred) for the pod, which specifies other pods the pod should or should not be scheduled near.
  * `TopologyKey`: The key representing the failure domain to which the affinity rule applies (e.g., "kubernetes.io/hostname" for node-level affinity or "topology.kubernetes.io/zone" for zone-level).
  * `Weight`: Defines how strongly the scheduler should consider a specific affinity rule.
  * `Pod`: The pod being scheduled.
  * `OtherPods`: List of other pods to consider in relation to the affinity rules.

`NodeAffinity`: Enables scheduling based on node labels. It allows users to specify rules for which nodes a pod can be scheduled on, based on the node's labels, and provides fine-grained control over pod placement on nodes.

**Arguments it may receive**:

  * `NodeAffinity`: Defines the required or preferred node affinity rules, such as `requiredDuringSchedulingIgnoredDuringExecution` or `preferredDuringSchedulingIgnoredDuringExecution`.
  * `NodeSelectorTerms`: Defines the set of node labels and values that must match.
  * `Pod`: The pod being scheduled.
  * `Node`: A potential node for scheduling.
  * `LabelSelector`: A selector for choosing nodes based on labels.

`NodeName`: Used to force a pod to be scheduled on a specific node. When you specify the exact node name, the scheduler will place the pod on that node if possible.

`NodePorts`: Ensures that a pod with a service of type `NodePort` can be scheduled on a node that has the required ports available for binding. It checks whether the node has enough resources to support the node port allocations for the service.

`NodeUnschedulable`: Ensures that pods are not scheduled on nodes that are marked as unschedulable. If a node has been tainted with `node.kubernetes.io/unschedulable`, the scheduler will not place any new pods on that node.

`TaintToleration`: Checks if a pod has the required tolerations to be scheduled on a node that has taints. Taints on nodes prevent pods from being scheduled unless the pod has a matching toleration.

`NodeVolumeLimits`: Checks whether a node has exceeded its volume limit. Each node has a maximum number of volumes it can attach, and this plugin ensures that the pod is not scheduled on a node that has already reached that supported limit.

`VolumeBinding`: Ensures that persistent volumes (PVs) are properly bound to pods. It checks whether the volume that a pod requires can be bound to a node and ensures the volume is available on the selected node.

**Arguments it may receive**:

  * `VolumeClaims`: The persistent volume claims (PVCs) made by the pod being scheduled.
  * `Node`: The candidate node being considered for scheduling.
  * `VolumeAvailable`: Checks if the persistent volume is available on the node or within the appropriate zone.
  * `Pod`: The pod that is requesting volume binding.
  * `StorageClass`: The storage class associated with the persistent volume.
  * `VolumeBindingMode`: Defines whether the volume binding mode is `Immediate` or `WaitForFirstConsumer` (for delayed binding until a pod is scheduled).

`VolumeRestrictions`: Ensures that volume restrictions (such as limitations on the number of volumes a node can have attached) are respected when scheduling a pod. It prevents scheduling a pod on a node where the volume restrictions would be violated.

`VolumeZone`: Ensures that volumes are scheduled in the same availability zone as the pod. For example, if a pod requests a volume that must be in a specific zone, the plugin ensures that both the pod and the volume are in the same zone.

### Resource and Topology Optimization Scheduling Plugins

`NodeResourcesBalancedAllocation`: Aims to balance the resource allocation on nodes. When scheduling a pod, it considers how resources like CPU and memory are allocated across nodes to avoid over-provisioning or under-utilizing resources.

**Arguments it may receive**:

  * `ResourceRequests`: The resource requests (CPU, memory, etc.) of the pod being scheduled.
  * `Node`: A candidate node for scheduling.
  * `NodeResources`: The available resources (CPU, memory, etc.) of the node.
  * `ClusterResourceUsage`: Cluster-wide resource usage metrics to help decide the best node to balance resources.

`NodeResourcesFit`: Checks whether a node has enough available resources (CPU, memory, etc.) to run the pod. It ensures that a pod is only scheduled on a node that has sufficient resources available.

**Arguments it may receive**:

  * `ResourceRequests`: The resource requests of the pod.
  * `Node`: The candidate node being considered for scheduling.
  * `NodeCapacity`: The available capacity of resources on the node.
  * `Pod`: The pod being scheduled, with its resource requests.
 
`ImageLocality`: Helps the scheduler decide whether to schedule a pod onto a node based on the presence of a required container image. It tries to schedule pods on nodes where the required image is already present, reducing the time needed to pull the image.

`PodTopologySpread`: Ensures that pods are spread evenly across the topology (like zones or regions) to achieve high availability and fault tolerance. It tries to avoid placing multiple replicas of a pod in the same failure domain.

**Arguments it may receive**:

  * `TopologySpreadConstraints`: Defines the constraints for how pods should be spread across failure domains, including the key (e.g., `topology.kubernetes.io/zone`) and the number of pods to be placed in each domain.
  * `Pod`: The pod being scheduled.
  * `FailureDomain`: The failure domain key (e.g., zone or region).
  * `PodAffinity`: Information about pod affinity, which could also impact how the pods are distributed.
  * `Node`: Potential nodes for placement.
  * `PodSpreadScore`: Used to determine how much "spread" the pod should have across domains (higher scores indicate better spreading).


`DefaultPreemption`: Handles preemption, which is the process of evicting lower-priority pods to make room for higher-priority pods. If a pod cannot be scheduled because there aren’t enough resources on the node, this plugin will preempt other pods to make space.

**Arguments it may receive**:

  * `PodPriority`: Defines the priority of the pod being scheduled.
  * `PreemptionPolicy`: The policy for handling pod preemption (e.g., "PreemptLowerPriority" or "DoNotPreempt").
  * `PodPriorityClass`: The priority class associated with the pod.
  * `PodInfo`: Information about the pods that are candidates for preemption.
  * `Node`: Information about the node on which preemption is considered.

`ImageLocality`: Helps the scheduler decide whether to schedule a pod onto a node based on the presence of a required container image. It tries to schedule pods on nodes where the required image is already present, reducing the time needed to pull the image.

`InterPodAffinity`: Takes into account *affinity* rules specified by the user that influence scheduling based on the proximity of other pods. If a pod has affinity rules, it will try to schedule the pod on the same node or in the same topology as other pods that it has an affinity for. (e.g., for performance reasons or tight coupling).

**Arguments it may receive**:

  * `Affinity`: Defines the affinity rules (required or preferred) for the pod, which specifies other pods the pod should or should not be scheduled near.
  * `TopologyKey`: The key representing the failure domain to which the affinity rule applies (e.g., "kubernetes.io/hostname" for node-level affinity or "topology.kubernetes.io/zone" for zone-level).
  * `Weight`: Defines how strongly the scheduler should consider a specific affinity rule.
  * `Pod`: The pod being scheduled.
  * `OtherPods`: List of other pods to consider in relation to the affinity rules.

`NodeAffinity`: Enables scheduling based on node labels. It allows users to specify rules for which nodes a pod can be scheduled on, based on the node's labels, and provides fine-grained control over pod placement on nodes.

**Arguments it may receive**:

  * `NodeAffinity`: Defines the required or preferred node affinity rules, such as `requiredDuringSchedulingIgnoredDuringExecution` or `preferredDuringSchedulingIgnoredDuringExecution`.
  * `NodeSelectorTerms`: Defines the set of node labels and values that must match.
  * `Pod`: The pod being scheduled.
  * `Node`: A potential node for scheduling.
  * `LabelSelector`: A selector for choosing nodes based on labels.

`NodeName`: Used to force a pod to be scheduled on a specific node. When you specify the exact node name, the scheduler will place the pod on that node if possible.

`NodePorts`: Ensures that a pod with a service of type `NodePort` can be scheduled on a node that has the required ports available for binding. It checks whether the node has enough resources to support the node port allocations for the service.

`NodeResourcesBalancedAllocation`: Aims to balance the resource allocation on nodes. When scheduling a pod, it considers how resources like CPU and memory are allocated across nodes to avoid over-provisioning or under-utilizing resources.

**Arguments it may receive**:

  * `ResourceRequests`: The resource requests (CPU, memory, etc.) of the pod being scheduled.
  * `Node`: A candidate node for scheduling.
  * `NodeResources`: The available resources (CPU, memory, etc.) of the node.
  * `ClusterResourceUsage`: Cluster-wide resource usage metrics to help decide the best node to balance resources.

`NodeResourcesFit`: Checks whether a node has enough available resources (CPU, memory, etc.) to run the pod. It ensures that a pod is only scheduled on a node that has sufficient resources available.

**Arguments it may receive**:

  * `ResourceRequests`: The resource requests of the pod.
  * `Node`: The candidate node being considered for scheduling.
  * `NodeCapacity`: The available capacity of resources on the node.
  * `Pod`: The pod being scheduled, with its resource requests.

`NodeUnschedulable`: Ensures that pods are not scheduled on nodes that are marked as unschedulable. If a node has been tainted with `node.kubernetes.io/unschedulable`, the scheduler will not place any new pods on that node.

`NodeVolumeLimits`: Checks whether a node has exceeded its volume limit. Each node has a maximum number of volumes it can attach, and this plugin ensures that the pod is not scheduled on a node that has already reached that supported limit.

`PodTopologySpread`: Ensures that pods are spread evenly across the topology (like zones or regions) to achieve high availability and fault tolerance. It tries to avoid placing multiple replicas of a pod in the same failure domain.

**Arguments it may receive**:

  * `TopologySpreadConstraints`: Defines the constraints for how pods should be spread across failure domains, including the key (e.g., `topology.kubernetes.io/zone`) and the number of pods to be placed in each domain.
  * `Pod`: The pod being scheduled.
  * `FailureDomain`: The failure domain key (e.g., zone or region).
  * `PodAffinity`: Information about pod affinity, which could also impact how the pods are distributed.
  * `Node`: Potential nodes for placement.
  * `PodSpreadScore`: Used to determine how much "spread" the pod should have across domains (higher scores indicate better spreading).

`PrioritySort`: Sorts the list of pods according to their priority class. Pods with higher priority will be scheduled first. It helps with the preemption decision-making and determines which pods should be considered for scheduling first.

`SchedulingGates`: Introduces the concept of scheduling gates, which are conditions that must be satisfied before a pod is scheduled. For example, it can enforce the completion of certain tasks or operations before the scheduler attempts to schedule a pod.

`TaintToleration`: Checks if a pod has the required tolerations to be scheduled on a node that has taints. Taints on nodes prevent pods from being scheduled unless the pod has a matching toleration.

`VolumeBinding`: Ensures that persistent volumes (PVs) are properly bound to pods. It checks whether the volume that a pod requires can be bound to a node and ensures the volume is available on the selected node.

**Arguments it may receive**:

  * `VolumeClaims`: The persistent volume claims (PVCs) made by the pod being scheduled.
  * `Node`: The candidate node being considered for scheduling.
  * `VolumeAvailable`: Checks if the persistent volume is available on the node or within the appropriate zone.
  * `Pod`: The pod that is requesting volume binding.
  * `StorageClass`: The storage class associated with the persistent volume.
  * `VolumeBindingMode`: Defines whether the volume binding mode is `Immediate` or `WaitForFirstConsumer` (for delayed binding until a pod is scheduled).

`VolumeRestrictions`: Ensures that volume restrictions (such as limitations on the number of volumes a node can have attached) are respected when scheduling a pod. It prevents scheduling a pod on a node where the volume restrictions would be violated.

`VolumeZone`: Ensures that volumes are scheduled in the same availability zone as the pod. For example, if a pod requests a volume that must be in a specific zone, the plugin ensures that both the pod and the volume are in the same zone.

Learn more about these plugins and configuration options with the [Official Kubernetes Scheduling Plugin documentation](https://kubernetes.io/docs/reference/scheduling/config/#scheduling-plugins).

Next Step: [Configure and deploy a scheduler profile (preview) on your AKS cluster](./configure-aks-scheduler.md).