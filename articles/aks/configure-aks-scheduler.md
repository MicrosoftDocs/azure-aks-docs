---
title: Configure Scheduler Profiles on Azure Kubernetes Service (AKS) (preview)
description: Learn how to set scheduler profiles to achieve advanced scheduling behaviors on Azure Kubernetes Service (AKS)
ms.topic: how-to
ms.date: 09/30/2025
ms.author: sachidesai
author: sachidesai
# Customer intent: "As a Kubernetes cluster operator, I want to implement advanced scheduling strategies using one or more configurable profiles, so that I can effectively manage workload distribution and resource allocation across my AKS clusters."
---

# Configure advanced scheduler profiles on Azure Kubernetes Service (AKS) (preview)

This article shows you how to set one or more in-tree scheduling plugins via a scheduler profile to configure the scheduling behavior on your Azure Kubernetes Service (AKS) clusters.

## About workload placement in AKS

The default mechanism of workload placement across nodes within an AKS cluster is via the scheduler. The default scheduler is a control plane component responsible for assigning AKS deployment pods to nodes. When a pod is created without a specified node, the scheduler selects an optimal node based on several criteria, including:

* Available resources (CPU, memory)
* [Node affinity/anti-affinity](./operator-best-practices-advanced-scheduler.md#node-affinity)
* [Pod affinity/anti-affinity](./operator-best-practices-advanced-scheduler.md#inter-pod-affinity-and-anti-affinity)
* [Taints and tolerations](./operator-best-practices-advanced-scheduler.md#provide-dedicated-nodes-using-taints-and-tolerations)

Once the AKS scheduler selects a node, the deployment pod is bound to it, and the rest of the lifecycle continues. 

By default, the AKS scheduler comes with a set of built-in rules that work well for general-purpose workloads. However, advanced use cases might require custom scheduling strategies. For example:

* Batch jobs might prioritize resource fairness over speed.
* Cost-sensitive workloads might benefit from node bin-packing to consolidate jobs and minimize idle compute node costs.

## What are configurable scheduler profiles?

A scheduler profile is a set of one or more in-tree scheduling plugins and configurations that dictate how a pod should be scheduled. Starting from Kubernetes version `1.33`, you can configure and set a scheduler profile (preview) to target AKS node pools or entire clusters.

Each scheduler profile has:

* A unique name.
* A set of scheduling plugins.
* Custom arguments for fine-grained behavior (applicable to certain plugins).

## Supported in-tree scheduling plugins

The following sections outline the supported Kubernetes scheduling plugins you can configure on AKS.

For more information about these plugins and configuration options, see the [Official Kubernetes scheduling plugin documentation](https://kubernetes.io/docs/reference/scheduling/config/#scheduling-plugins).

### `DefaultBinder`

`DefaultBinder` is responsible for binding the pod to a node after the scheduler has selected a suitable node. Once the node is chosen, the `DefaultBinder` ensures that the pod is scheduled onto that node by creating a binding object.

### `DefaultPreemption`

`DefaultPreemption` handles preemption, which is the process of evicting lower-priority pods to make room for higher-priority pods. If a pod can't be scheduled because there aren’t enough resources on the node, this plugin preempts other pods to make space.

`DefaultPreemption` might receive any of the following arguments:

- **`PodPriority`**: Defines the priority of the pod being scheduled.
- **`PreemptionPolicy`**: The policy for handling pod preemption (e.g., "PreemptLowerPriority" or "DoNotPreempt").
- **`PodPriorityClass`**: The priority class associated with the pod.
- **`PodInfo`**: Information about the pods that are candidates for preemption.
- **`Node`**: Information about the node on which preemption is considered.

### `ImageLocality`

`ImageLocality` helps the scheduler decide whether to schedule a pod onto a node based on the presence of a required container image. It tries to schedule pods on nodes where the required image is already present, reducing the time needed to pull the image.

### `InterPodAffinity`

`InterPodAffinity` takes into account *affinity* rules specified by the user that influence scheduling based on the proximity of other pods. If a pod has affinity rules, it tries to schedule the pod on the same node or in the same topology as other pods that it has an affinity for. (e.g., for performance reasons or tight coupling).

`InterPodAffinity` might receive any of the following arguments:

- **`Affinity`**: Defines the affinity rules (required or preferred) for the pod, which specifies other pods the pod should or shouldn't be scheduled close to.
- **`TopologyKey`**: The key representing the failure domain to which the affinity rule applies (e.g., "kubernetes.io/hostname" for node-level affinity or "topology.kubernetes.io/zone" for zone-level).
- **`Weight`**: Defines how strongly the scheduler should consider a specific affinity rule.
- **`Pod`**: The pod being scheduled.
- **`OtherPods`**: List of other pods to consider in relation to the affinity rules.

### `NodeAffinity`

`NodeAffinity` enables scheduling based on node labels. It allows users to specify rules for which nodes a pod can be scheduled on based on the node's labels and provides fine-grained control over pod placement on nodes.

`NodeAffinity` might receive any of the following arguments:

- **`NodeAffinity`**: Defines the required or preferred node affinity rules, such as `requiredDuringSchedulingIgnoredDuringExecution` or `preferredDuringSchedulingIgnoredDuringExecution`.
- **`NodeSelectorTerms`**: Defines the set of node labels and values that must match.
- **`Pod`**: The pod being scheduled.
- **`Node`**: A potential node for scheduling.
- **`LabelSelector`**: A selector for choosing nodes based on labels.

### `NodeName`

`NodeName` forces a pod to be scheduled on a specific node. When you specify the exact node name, the scheduler will place the pod on that node if possible.

### `NodePorts`

`NodePorts` ensures that a pod with a service of type `NodePort` can be scheduled on a node that has the required ports available for binding. It checks whether the node has enough resources to support the node port allocations for the service.

### `NodeResourcesBalancedAllocation`

`NodeResourcesBalancedAllocation` helps balance the resource allocation on nodes. When scheduling a pod, it considers how resources like CPU and memory are allocated across nodes to avoid over-provisioning or under-utilizing resources.

`NodeResourcesBalancedAllocation` might receive any of the following arguments:

 - **`ResourceRequests`**: The resource requests (CPU, memory, etc.) of the pod being scheduled.
 - **`Node`**: A candidate node for scheduling.
 - **`NodeResources`**: The available resources (CPU, memory, etc.) of the node.
 - **`ClusterResourceUsage`**: Cluster-wide resource usage metrics to help decide the best node to balance resources.

### `NodeResourcesFit`

`NodeResourcesFit` checks whether a node has enough available resources (CPU, memory, etc.) to run the pod. It ensures that a pod is only scheduled on a node that has sufficient resources available.

`NodeResourcesFit` might receive any of the following arguments:

 - **`ResourceRequests`**: The resource requests of the pod.
 - **`Node`**: The candidate node being considered for scheduling.
 - **`NodeCapacity`**: The available capacity of resources on the node.
 - **`Pod`**: The pod being scheduled, with its resource requests.
 
 ### `NodeUnschedulable`

`NodeUnschedulable` ensures that pods aren't scheduled on nodes marked as unschedulable. If a node is tainted with `node.kubernetes.io/unschedulable`, the scheduler won't place any new pods on that node.

### `NodeVolumeLimits`

`NodeVolumeLimits` checks whether a node has exceeded its volume limit. Each node has a maximum number of volumes it can attach, and this plugin ensures that the pod isn't scheduled on a node that has already reached that supported limit.

### `PodTopologySpread`

`PodTopologySpread` ensures that pods are spread evenly across the topology (like zones or regions) to achieve high availability and fault tolerance. It tries to avoid placing multiple replicas of a pod in the same failure domain.

`PodTopologySpread` might receive any of the following arguments:

 - **`TopologySpreadConstraints`**: Defines the constraints for how pods should be spread across failure domains, including the key (e.g., `topology.kubernetes.io/zone`) and the number of pods to be placed in each domain.
 - **`Pod`**: The pod being scheduled.
 - **`FailureDomain`**: The failure domain key (e.g., zone or region).
 - **`PodAffinity`**: Information about pod affinity, which could also impact how the pods are distributed.
 - **`Node`**: Potential nodes for placement.
 - **`PodSpreadScore`**: Used to determine how much "spread" the pod should have across domains (higher scores indicate better spreading).

### `PrioritySort`

`PrioritySort` sorts the list of pods according to their priority class. Pods with higher priority are scheduled first. It helps with the preemption decision-making and determines which pods should be considered for scheduling first.

### `SchedulingGates`

`SchedulingGates` introduces the concept of scheduling gates, which are conditions that must be satisfied before a pod is scheduled. For example, it can enforce the completion of certain tasks or operations before the scheduler attempts to schedule a pod.

### `TaintToleration`

`TaintToleration` checks if a pod has the required tolerations to be scheduled on a node that has taints. Taints on nodes prevent pods from being scheduled unless the pod has a matching toleration.

### `VolumeBinding`

`VolumeBinding` ensures that persistent volumes (PVs) are properly bound to pods. It checks whether the volume that a pod requires can be bound to a node and ensures the volume is available on the selected node.

`VolumeBinding` might receive any of the following arguments:

 - **`VolumeClaims`**: The persistent volume claims (PVCs) made by the pod being scheduled.
 - **`Node`**: The candidate node being considered for scheduling.
 - **`VolumeAvailable`**: Checks if the persistent volume is available on the node or within the appropriate zone.
 - **`Pod`**: The pod that is requesting volume binding.
 - **`StorageClass`**: The storage class associated with the persistent volume.
 - **`VolumeBindingMode`**: Defines whether the volume binding mode is `Immediate` or `WaitForFirstConsumer` (for delayed binding until a pod is scheduled).
 
 ### `VolumeRestrictions`

`VolumeRestrictions` ensures that volume restrictions (such as limitations on the number of volumes a node can have attached) are respected when scheduling a pod. It prevents scheduling a pod on a node where the volume restrictions would be violated.

### `VolumeZone`

`VolumeZone` ensures that volumes are scheduled in the same availability zone as the pod. For example, if a pod requests a volume that must be in a specific zone, the plugin ensures that both the pod and the volume are in the same zone.

## Deploy a sample scheduler profile (preview)

The following examples demonstrate how you can configure targeted scheduling mechanisms on your AKS cluster using one or a subset of in-tree scheduling plugins.

## Limitations

- AKS currently doesn't manage the deployment of third-party schedulers (out-of-tree scheduling plugins).
- AKS doesn't support in-tree scheduling plugins targeting the `aks-system` scheduler. This restriction is in place to help prevent unexpected changes to AKS add-ons enabled on your cluster.

## Prerequisites

- The Azure CLI version `2.76.0` or later. Run `az --version` to find the version, and run `az upgrade` to upgrade the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
- Kubernetes version `1.33` or later running on your AKS cluster.
- The [`aks-preview` Azure CLI extension](#install-the-aks-preview-azure-cli-extension) version `18.0.0b27` or later.
- [Register the `UserDefinedSchedulerConfigurationPreview` feature flag](#register-the-user-defined-scheduler-configuration-preview-feature-flag) in your Azure subscription.

### Install the `aks-preview` Azure CLI extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

- Install the `aks-preview` extension using the [`az extension add`](/cli/azure/extension#az_extension_add) command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

- Update to the latest version of the `aks-preview` extension using the [`az extension update`](/cli/azure/extension#az_extension_update) command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the user defined scheduler configuration preview feature flag

1. Register the `UserDefinedSchedulerConfigurationPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "UserDefinedSchedulerConfigurationPreview"
    ```

    It takes a few minutes for the status to show *Registered*.

1. Verify the registration status using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "UserDefinedSchedulerConfigurationPreview"
`    ``

1. When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace "Microsoft.ContainerService"
    ```

## Enable scheduler profile configuration on an AKS cluster

### [Enable on a new cluster](#tab/new-cluster)

1. Create an AKS cluster with scheduler profile configuration enabled using the [`az aks create`][az-aks-create] command with the `--enable-upstream-kubescheduler-user-configuration` flag.
    
    ```azurecli-interactive
    az aks create \
    --resource-group myResourceGroup \ 
    --name myAKSCluster \
    --enable-upstream-kubescheduler-user-configuration \
    --generate-ssh-keys
    ```

1. Once the creation process completes, connect to the cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
    ```

### [Enable on an existing cluster](#tab/existing-cluster)

- Enable scheduler profile configuration on an existing cluster using the [`az aks update`][az-aks-update] command.

    ```azurecli-interactive
    az aks update --subscription="${SUBSCRIPTION_ID}" \
    --resource-group="${RESOURCEGROUP_NAME}" \
    --name="${CLUSTER_NAME}" \
    --enable-upstream-kubescheduler-user-configuration
    ```

---


## Verify installation of the scheduler controller

- After enabling the feature on your AKS cluster, verify the custom resource definition (CRD) of the scheduler controller was successfully installed using the `kubectl get` command.

    ```bash
    kubectl get crd schedulerconfigurations.aks.azure.com
    ```

    > [!NOTE]
    > This command won't succeed if the feature wasn't successfully enabled in the [previous section](#enable-scheduler-profile-configuration-on-an-aks-cluster).

## Use the node bin-packing scheduling strategy

Node bin-packing is a scheduling strategy that aims to pack as many pods as possible onto a node to maximize resource utilization and reduce the number of underutilized nodes. This strategy helps improve cluster efficiency by minimizing wasted resources and lowering the operational cost of maintaining idle or underutilized nodes.

> [!NOTE]
> In environments where you want to optimize cost by using fewer nodes, this configuration helps ensure that the existing nodes are used more effectively by filling them up with workloads that match their current resource allocation.

1. Create a file named `aks-scheduler-customization.yaml` and paste in the following manifest:

    ```yaml
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

    This example scheduler profile helps place new pods on nodes that are already being heavily used in terms of CPU resources. This avoids underutilizing nodes that still have free resources and helps to make better use of the resources already allocated to nodes.

    The profile uses `NodeResourcesFit` to ensure that the scheduler checks if a node has enough resources to run the pod. 

    - `scoringStrategy: MostAllocated`: Tells the scheduler to prefer nodes that have already allocated the most resources for CPU. This helps achieve **better resource utilization** by placing new pods on nodes that are already "full".
    - `Resources`: The configuration specifies that `CPU` is the primary resource being considered for scoring, and it assigns a weight of `1` to it (meaning that CPU usage prioritized with a relatively equal level of importance in the scheduling decision).

    It also might direct the scheduler to balance out CPU usage across nodes more evenly, preventing some nodes from being too underutilized while others become overloaded.

1. Apply the scheduling configuration manifest using the `kubectl apply` command.

    ```bash
    kubectl apply -f aks-scheduler-customization.yaml
    ```

1. To target this scheduling mechanism for specific workload(s), update your pod deployment(s) with the following `schedulerName`:

    ```yaml
    ...
    ...
        spec:
          schedulerName: node-binpacking-scheduler
    ...
    ...
    ```


## Use the pod topology spread scheduling strategy

Pod topology spread is a scheduling strategy that distributes pods evenly across failure domains (e.g., availability zones or regions) to ensure high availability and fault tolerance. This strategy helps prevent the risk of all replicas of a pod being placed in the same failure domain and improves the resilience of applications in the event of zone or node failures.

1. Create a file named `aks-scheduler-customization.yaml` and paste in the following manifest:

    ```yaml
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

    The `PodTopologySpread` plugin ensures that the scheduler will try to distribute pods as evenly as possible across availability zones. This helps ensure that the pods in your application aren't all concentrated in a single zone, improving resilience in case of zone failure.

    By spreading pods across different zones, you increase the availability and fault tolerance of your application. If one zone goes down, the other zones still have pods running, which prevents complete application failure.

    The `whenUnsatisfiable: ScheduleAnyway` setting ensures that if there aren't enough resources to meet the topology constraints exactly, the pod will still be scheduled. This avoids pod scheduling failures when exact distribution isn't feasible.

    The `List` type applies the default constraints as a list of rules. The scheduler uses the rules in the order they're defined, and they apply to all pods that don’t specify custom topology spread constraints.

    In this profile, the setting `maxSkew: 1` means the number of pods can differ by at most _1_ between any two zones, and `topologyKey: topology.kubernetes.io/zone` indicates that the scheduler should spread pods across availability zones.

1. Apply the scheduling configuration manifest using the `kubectl apply` command.

    ```bash
    kubectl apply -f aks-scheduler-customization.yaml
    ```

1. To target this scheduling mechanism for specific workload(s), update your pod deployment(s) with the following `schedulerName`:

    ```yaml
    ...
    ...
        spec:
          schedulerName: pod-distribution-scheduler
    ...
    ...
    ```


## Configure a scheduler profile for an entire AKS cluster

1. In your scheduler profile configuration, update the `schedulerName` field as follows:

    ```yaml
    ...
    ...
    `- schedulerName: default_scheduler` 
    ...
    ...
    ```

1. Reapply the manifest using the `kubectl apply` command.

    ```bash
    kubectl apply -f aks-scheduler-customization.yaml
    ```

    Now, this configuration will become the **default** scheduling operation for your entire AKS cluster.

## Disable an AKS scheduler profile configuration

1. To disable the AKS scheduler profile configuration and revert to AKS scheduler default configuration on the cluster, first delete the `schedulerconfiguration` resource using the `kubectl delete` command.

    ```bash
    kubectl delete schedulerconfiguration upstream || true
    ```

1. Disable the feature using the [`az aks update`](/cli/azure/aks#az_aks_update) command with the `--disable-upstream-kubescheduler-user-configuration` flag.

    ```azurecli-interactive
    az aks update --subscription="${SUBSCRIPTION_ID}" \
    --resource-group="${RESOURCEGROUP_NAME}" \
    --name="${CLUSTER_NAME}" \
    --disable-upstream-kubescheduler-user-configuration
    ```

1. Verify the feature is disabled using the [`az aks show`](/cli/azure/aks#az_aks_show) command.

    ```azurecli-interactive
    az aks show --resource-group="${RESOURCEGROUP_NAME}" \
    --name="${CLUSTER_NAME}" \
    --query='properties.schedulerProfile'
    ```

    Your output should indicate that the feature is no longer enabled on your AKS cluster.

## FAQ

### What happens if a misconfigured scheduler profile is applied to my AKS cluster?

Once you apply a scheduler profile, AKS checks if it contains a valid configuration of plugins and arguments. If the configuration targets a disallowed scheduler or sets the in-tree scheduling plugins improperly, AKS rejects the configuration and reverts to the last known "accepted" scheduler configuration. This check aims to limit impact on new and existing AKS clusters due to scheduler misconfiguration.

### How can I monitor and validate that my configuration was honored by the scheduler?

There are _three_ recommended methods for observing the results of your applied scheduler profile:

- View the AKS `kube-scheduler` control plane logs to ensure that the scheduler has received the configuration from the CRD.
- Run the `kubectl get schedulerconfiguration` command. The output displays the status of the `configuration: pending` during the rollout and `Succeeded` or `Failed` after the configuration is accepted or rejected by the scheduler.
- Run the `kubectl describe schedulerconfiguration` command. The output displays a more detailed state of the scheduler, including any error during the reconciliation, and the current scheduler configuration in effect. 

## Next steps

To learn more about the AKS scheduler and best practices, see the following resources:

- [Azure Kubernetes Service (AKS) scheduler best practices](./operator-best-practices-scheduler.md)
- [Best practices for advanced scheduling policies](./operator-best-practices-advanced-scheduler.md)
- [Monitor your AKS resource metrics and logs](./monitor-aks.md)

<!-- LINKS - internal -->
[az-aks-create]: /cli/azure/aks#az_aks_create
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az_aks_nodepool_update
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az_aks_nodepool_add
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[aks-quickstart-cli]: ./learn/quick-windows-container-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-windows-container-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-windows-container-deploy-powershell.md
[install-azure-cli]: /cli/azure/install-azure-cli
[azureml-aks]: /azure/machine-learning/how-to-attach-kubernetes-anywhere
[azureml-deploy]: /azure/machine-learning/how-to-deploy-managed-online-endpoints
[azureml-triton]: /azure/machine-learning/how-to-deploy-with-triton
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update