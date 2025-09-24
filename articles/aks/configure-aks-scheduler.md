---
title: Configure Scheduler Profiles on Azure Kubernetes Service (AKS)
description: Learn how to set scheduling profiles to achieve advanced scheduling behaviors, such as node bin-packing and co-scheduling, on Azure Kubernetes Service (AKS)
ms.topic: how-to
ms.subservice: aks-operator
ms.date: 09/15/2025
ms.author: sachidesai
author: sachidesai
# Customer intent: "As a Kubernetes cluster operator, I want to implement advanced scheduling strategies using one or more configurable profiles, so that I can effectively manage workload distribution and resource allocation across my AKS clusters."
---

# Configure advanced scheduler profiles on Azure Kubernetes Service (AKS)

On Azure Kubernetes Service (AKS), the default mechanism of workload placement across nodes within a cluster is via the kube-scheduler. The kube-scheduler is a control plane component responsible for assigning AKS deployment pods to nodes. When a pod is created without a specified node, the scheduler selects an optimal node based on several criteria, such as:

* Available resources (CPU, memory)
* Node affinity/anti-affinity
* Pod affinity/anti-affinity
* Taints and tolerations

Once the kube-scheduler selects a node, the deployment pod is bound to it, and the rest of the lifecycle continues. 

By default, kube-scheduler comes with a set of built-in rules that work well for general-purpose workloads. However, advanced use cases may require custom scheduling strategies. For example,

* Data processing workloads with flexible start times may benefit from co-scheduling.
* Batch jobs might prioritize resource fairness over speed.
* Cost-sensitive workloads may benefit from  node bin-packing to consolidate jobs and minimize idle compute node costs.

To support these use cases, AKS allows you to set one or more in-tree scheduling plugins via a scheduler profile to configure the scheduling behavior (preview) on your cluster(s).

## Limitations
* Currently, AKS does not manage the deployment of third-party schedulers (out-of-tree scheduling plugins).

## Prerequisites
* The Azure CLI version `2.76.0` or later. Run `az --version` to find the version, and run `az upgrade` to upgrade the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
* The `aks-preview` Azure CLI extension version `18.0.0b27` or later.
* Kubernetes version 1.33 or later on your AKS cluster.
* Register the `UserDefinedSchedulerConfigurationPreview` feature in your Azure subscription.

## Configurable scheduler profiles (preview)

A scheduler profile is a set of in-tree scheduling plugins and configurations that dictate how a pod should be scheduled. Starting from Kubernetes v1.33, you can set a pre-defined scheduler profile to target AKS node(s) or an entire AKS cluster.

Each profile has:

* A unique name.
* A set of scheduling plugins.
* Custom arguments for fine-grained behavior (applicable to certain plugins)

### Supported in-tree scheduling plugins

AKS supports configuration of the following Kubernetes scheduling plugins:

`DefaultBinder`: Responsible for binding the pod to a node after the scheduler has selected a suitable node. Once the node is chosen, the `DefaultBinder` ensures that the pod is scheduled onto that node by creating a binding object.

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

### Install the aks-preview Azure CLI extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

To install the `aks-preview` extension, run the following command:

```azurecli-interactive
az extension add --name aks-preview
```

Run the following command to update to the latest version of the `aks-preview` extension:

```azurecli-interactive
az extension update --name aks-preview
```

### Register the UserDefinedSchedulerConfigurationPreview feature flag

1. Register the `UserDefinedSchedulerConfigurationPreview` feature flag by using the [az feature register][az-feature-register] command, as shown in the following example:

```azurecli-interactive
az feature register --namespace "Microsoft.ContainerService" --name "UserDefinedSchedulerConfigurationPreview"
```

1. It takes a few minutes for the status to show *Registered*. Verify the registration status by using the [az feature show][az-feature-show] command:

```azurecli-interactive
az feature show --namespace "Microsoft.ContainerService" --name "UserDefinedSchedulerConfigurationPreview"
```

1. When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider by using the [az provider register][az-provider-register] command:

```azurecli-interactive
az provider register --namespace "Microsoft.ContainerService"
```

## Deploy to a new cluster

1. Create an AKS cluster using the [az aks create][az-aks-create] command and enable Scheduler Customization (preview) on the cluster.
    
    ```azurecli-interactive
    az aks create \
    --resource-group myResourceGroup \ 
    --name myAKSCluster \
    --enable-upstream-kubescheduler-user-configuration \
    --generate-ssh-keys
    ```

1. When the cluster is ready, get the cluster credentials using the [az aks get-credentials][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
    ```

## Deploy to an existing cluster

1. Run the [az aks update][az-aks-update] command to enable Scheduler Customization (preview) on the cluster.

    ```azurecli-interactive
    az aks update \
    --name myAKSCluster \
    --enable-upstream-kubescheduler-user-configuration
    ```

## Verify installation of the scheduler controller

Once you have enabled the feature, verify that the custom resource definition (CRD) of the scheduler controller was successfully installed:

```bash
kubectl get crd schedulerconfigurations.aks.azure.com
```

> [!NOTE]
> This command will not succeed if the feature was not enabled in the previous step.

The following examples demonstrate how targeted scheduling mechanisms can be configured on your AKS cluster using one or a subset of in-tree scheduling plugins:

## Node binpacking strategy

Node binpacking is a scheduling strategy that aims to pack as many pods as possible onto a node to maximize resource utilization and reduce the number of underutilized nodes. This strategy helps improve cluster efficiency by minimizing wasted resources and lowering the operational cost of maintaining idle or underutilized nodes.

> [!NOTE]
> In environments where you want to optimize cost by using fewer nodes, this configuration helps ensure that the existing nodes are used more effectively by filling them up with workloads that match their current resource allocation.

Create the following manifest in a file called `aks-scheduler-customization.yaml` to set up node bin-packing on your AKS cluster:

```bash
apiVersion: aks.azure.com/v1alpha1
kind: SchedulerConfiguration
metadata:
  name: upstream
spec:
  profiles:
  - schedulerName: node-binpacking-scheduler
    pluginConfig:
    - name: NodeResourcesFit
      args:
        scoringStrategy:
          type: MostAllocated
          resources:
          - name: cpu
            weight: 1
```

Apply this scheduling configuration manifest:

```bash
kubectl apply -f aks-scheduler-customization.yaml
```

To target this scheduling mechanism for specific workload(s), update your pod deployment(s) with the following `schedulerName`:

```bash
...
...
    spec:
      schedulerName: node-binpacking-scheduler
      containers:
...
...
```

### What does this configuration do?

This scheduler profile uses `NodeResourcesFit` to ensure that the scheduler checks if a node has enough resources to run the pod. 

* **scoringStrategy: MostAllocated**: Tells the scheduler to prefer nodes that have already allocated the most resources for CPU. This helps achieve **better resource utilization** by placing new pods on nodes that are already "full".
4. **Resources**: The configuration specifies that **CPU** is the primary resource being considered for scoring, and it assigns a weight of `1` to it (meaning that CPU usage prioritized with a relatively equal level of importance in the scheduling decision)

### What does this profile accomplish when applied to an AKS cluster?

This example scheduler profile helps place new pods on nodes that are already being heavily used in terms of CPU resources. This avoids under-utilizing nodes that still have free resources and helps to make better use of the resources already allocated to nodes.

It also may direct the scheduler to balance out CPU usage across nodes more evenly, preventing some nodes from being too underutilized while others become overloaded.

## Pod topology spread configuration

Pod topology spread is a scheduling strategy that distributes pods evenly across failure domains (e.g., availability zones or regions) to ensure high availability and fault tolerance. This strategy helps prevent the risk of all replicas of a pod being placed in the same failure domain, and improves the resilience of applications in the event of zone or node failures.

Create the following manifest in a file called `aks-scheduler-customization.yaml` to configure pod topology spread on your AKS cluster:

```bash
apiVersion: aks.azure.com/v1alpha1
kind: SchedulerConfiguration
metadata:
  name: upstream
spec:
  rawConfig: |
    apiVersion: kubescheduler.config.k8s.io/v1
    kind: KubeSchedulerConfiguration
    profiles:
    - schedulerName: pod-distribution-scheduler
      - pluginConfig:
          - name: PodTopologySpread
            args:
              apiVersion: kubescheduler.config.k8s.io/v1
              kind: PodTopologySpreadArgs
              defaultingType: List
              defaultConstraints:
                - maxSkew: 1
                  topologyKey: topology.kubernetes.io/zone
                  whenUnsatisfiable: ScheduleAnyway
```

To target this scheduling mechanism for specific workload(s), update your pod deployment(s) with the following `schedulerName`:

```bash
...
...
    spec:
      schedulerName: pod-distribution-scheduler
      containers:
...
...
```

### What does this configuration do?

The scheduler profile includes the PodTopologySpread plugin, which helps with pod distribution across failure domains. It uses `List` type, meaning it applies the default constraints as a list of rules. The scheduler will use the rules in the order they are defined, and they apply to all pods that don’t specify custom topology spread constraints.

In this profile, the setting `maxSkew: 1` means the number of pods can differ by at most 1 between any two zones, and `topologyKey: topology.kubernetes.io/zone` indicates that the scheduler should spread pods across availability zones.

### What does this profile accomplished when applied to an AKS cluster?

The `PodTopologySpread` plugin ensures that the scheduler will try to distribute pods as evenly as possible across availability zones. This helps ensure that the pods in your application are not all concentrated in a single zone, improving resilience in case of zone failure.

By spreading pods across different zones, you increase the availability and fault tolerance of your application. If one zone goes down, the other zones still have pods running, which prevents complete application failure.

The `whenUnsatisfiable: ScheduleAnyway` setting ensures that if there are not enough resources to meet the topology constraints exactly, the pod will still be scheduled. This avoids pod scheduling failures when exact distribution is not feasible.

## Set the scheduler profile for an entire AKS cluster

In your scheduler profile configuration update the following field:

```bash
...
...
`- schedulerName: default_scheduler` 
...
...
```

Repply the manifest:

```bash
kubectl apply -f aks-scheduler-customization.yaml
```

Now, this configuration will become the **default** scheduling operation for your entire AKS cluster.

## Disable AKS scheduler configuration

```bash
kubectl delete schedulerconfiguration upstream || true # This is a workaround for a known issue in AKS's reconciliation service
```

    ```azurecli-interactive
    az aks update --subscription="${SUBSCRIPTION_ID}" \
    --resource-group="${RESOURCEGROUP_NAME}" \
    --name="${CLUSTER_NAME}" \
    --disable-upstream-kubescheduler-user-configuration
    ```


## FAQ

Do not set `aks-system` to the `schedulerName` field in your scheduler profile manifest.


## Next Steps

To learn more about the AKS scheduler, visit:

* [Azure Kubernetes Service Scheduler best practices](./operator-best-practices-scheduler.md)
* [Best practices for advanced scheduling policies](./operator-best-practices-advanced-scheduler.md)
* 


<!--- Links --->
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-update]: /cli/azure/aks#az_aks_update
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[az-feature-register]: /cli/azure/feature#az_feature_register
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-show]: /cli/azure/feature#az-feature-show
