---
title: "Introducing Azure Kubernetes Fleet Manager intelligent resource placement"
description: This article describes the concepts of Azure Kubernetes Fleet Manager intelligent resource placement
ms.date: 07/28/2026
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: As a platform admin, I want to propagate Kubernetes resources from a hub cluster to multiple member clusters, so that I can manage workloads and access control across diverse environments.
zone_pivot_groups: cluster-namespace-scope
---

# Introducing Azure Kubernetes Fleet Manager intelligent resource placement

**Applies to** :heavy_check_mark: Fleet Manager with hub cluster

Managing Kubernetes resources across multiple clusters presents significant challenges for both platform administrators and application developers. As organizations scale their Kubernetes infrastructure beyond a single cluster, they often encounter complexities related to resource distribution, consistency, and manual management overhead. The traditional approach of managing each cluster independently creates operational silos that become increasingly difficult to maintain as the fleet size grows.

Platform administrators often need to deploy Kubernetes resources onto multiple clusters for various reasons, including:

* Managing access control using roles and role bindings across multiple clusters.
* Running infrastructure applications, such as Prometheus or Flux, that need to be on all clusters.

Application developers often need to deploy Kubernetes resources onto multiple clusters for various reasons, for example:

* Deploying a video serving application into multiple clusters in different regions for a low latency watching experience.
* Deploying a shopping cart application into two paired regions for customers to continue to shop during a single region outage.
* Deploying a batch compute application into clusters with inexpensive spot node pools available.

It's tedious and potentially error-prone to create, update, and track Kubernetes resources across multiple clusters manually. 

In this article we explore how you can use Fleet Manager's intelligent resource placement capability to manage the distribution of cluster and namespace-scoped Kubernetes resources across member clusters in a fleet.

Fleet Manager's resource placement capability is based on the [KubeFleet CNCF project](https://kubefleet.dev/).

## Resource placement process overview

To use Fleet Manager's intelligent resource placement, follow these steps:

1. **Stage resources on hub cluster**: use Continuous Deployment, GitOps, or a similar method to apply the manifests for resource distributions on the Fleet Manager hub cluster.
1. **Create a resource placement**: create a placement manifest that selects the resource and defines a policy for choosing which member clusters receive the resource.
1. **Apply resource placement on hub cluster**: apply the placement manifest to the hub cluster to start distributing the resource.
1. **Fleet Manager schedules resources**: Fleet Manager observes the resource placement and the selected scope, and it performs the distribution of the resources.
1. **Observe distribution via resource placement**: query the resource placement on the hub cluster to check the status of the resource as it rolls out.

Fleet Manager has an Azure portal experience for resource placement that provides a more visual representation of the rollout.

:::zone target="docs" pivot="cluster-scope"

## Introducing cluster-scoped resource placement

Use a ClusterResourcePlacement (CRP) to distribute a given set of cluster-scoped resources or entire namespaces from the Fleet Manager hub cluster onto one or more member clusters.

**Key characteristics:**

- **Cluster-scoped**: selects cluster-scoped resources or namespaces.
- **Declarative**: uses the same placement policies as `ResourcePlacement` for consistent behavior.

By using CRP, you can:

* Select which Kubernetes resources to distribute. These resources can be cluster-scoped Kubernetes resources defined using [Kubernetes Group Version Kind (GVK)](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.33/#api-groups) references, or a namespace, which distributes the namespace and all its resources.
* Specify placement policies to select member clusters. These policies can explicitly select clusters by names, or dynamically select clusters based on cluster labels and properties. 
* Specify rollout strategies to safely roll out any updates of the selected Kubernetes resources to multiple target clusters.
* View the rollout progress for each target cluster.

For scenarios requiring fine-grained control over individual namespace-scoped resources within a namespace, see [namespace-scoped resource placement](./concepts-namespace-scoped-resource-propagation.md?pivots=namespace-scope#overview-of-namespace-scoped-resource-placement), which enables distribution of specific resources rather than entire namespaces.

:::zone-end

:::zone target="docs" pivot="namespace-scope"

## Introducing namespace-scoped resource placement

Use a ResourcePlacement (RP) to distribute a given set of resources within a specific namespace from the Fleet Manager hub cluster onto one or more member clusters. ResourcePlacement provides fine-grained control over how specific resources within a namespace are distributed across member clusters.

**Key characteristics:**

- **Namespace-scoped**: Both `ResourcePlacement` and the resources it selects exist within the same namespace.
- **Selective**: Selects specific resources within the namespace by type, name, or labels rather than entire namespaces.
- **Declarative**: Uses the same placement policies as `ClusterResourcePlacement` for consistent behavior.

### When to use ResourcePlacement

`ResourcePlacement` is ideal for scenarios that require granular control over namespace-scoped resources:

- **Selective resource distribution**: Deploy specific ConfigMaps, Secrets, or Services without affecting the entire namespace.
- **Multitenant environments**: Allow different teams to manage their resources independently within shared namespaces.
- **Configuration management**: Distribute environment-specific configurations across different cluster environments.
- **Compliance and governance**: Apply different policies to different resource types within the same namespace.
- **Progressive rollouts**: Safely deploy resource updates across clusters by using zero-downtime strategies.

In multicluster environments, workloads often consist of both cluster-scoped and namespace-scoped resources that you need to distribute across different clusters. While `ClusterResourcePlacement` (CRP) handles cluster-scoped resources effectively, it also manages entire namespaces and their contents. However, some scenarios require more granular control over namespace-scoped resources within existing namespaces.

`ResourcePlacement` (RP) addresses this gap by providing:

- **Namespace-scoped resource management**: Target specific resources within a namespace without affecting the entire namespace.
- **Operational flexibility**: Allow teams to manage different resources within the same namespace independently.
- **Complementary functionality**: Work alongside CRP to provide a complete multicluster resource management solution.

> [!NOTE]
> You can use `ResourcePlacement` together with `ClusterResourcePlacement` in namespace-only mode. For example, use CRP to deploy the namespace, and use RP for fine-grained management of specific resources like environment-specific ConfigMaps or Secrets within that namespace.

:::zone-end

## Resource placement components

A resource placement, regardless of scope (cluster or namespace), consists of the following components:

- **[Resource selectors](#resource-selectors)**: select the resources to include through `resourceSelectors`.
- **[Placement policy](#placement-policy)**: define how to pick clusters through `placementType` using one of the `PickAll`, `PickFixed`, or `PickN` types.
- **[Rollout strategy](#configuring-rollout-strategy)**: control how resources roll out across selected clusters by including an optional `strategy`.

:::zone target="docs" pivot="cluster-scope"

This sample ClusterResourcePlacement (CRP) places the namespace `my-app` onto all clusters in the fleet. As you didn't define an explicit strategy, the process uses a `RollingUpdate`.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: namespace-only-crp
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: my-app
      version: v1
  policy:
    placementType: PickAll   
```

:::zone-end

:::zone target="docs" pivot="namespace-scope"

This sample ResourcePlacement (RP) places the ConfigMap labeled `app=my-application` in the namespace `my-app` into the matching namespace on the two named clusters. As you didn't define an explicit strategy, the process uses a `RollingUpdate`.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ResourcePlacement
metadata:
  name: app-configs-rp
  namespace: my-app
spec:
  resourceSelectors:
    - group: ""
      kind: ConfigMap
      version: v1
      labelSelector:
        matchLabels:
          app: my-application
  policy:
    placementType: PickFixed
    clusterNames:
    - cluster1
    - cluster2
```

:::zone-end

### Resource selectors

Select resources by using one or more `resourceSelectors` in a placement. Each resource selector can specify:

* **Group, Version, Kind (GVK)**: The type of Kubernetes resource to select.
* **Name**: The name of a specific resource.
* **Label selectors**: Labels to match multiple resources.

:::zone target="docs" pivot="cluster-scope"

#### Namespace selection scope

When you use cluster-scoped placement to select an entire namespace, use the `selectionScope` field to control whether to include all the child resources in the namespace, or just place an empty namespace.

* **Default behavior** (when `selectionScope` isn't specified): distributes the namespace and all resources within it.
* **`NamespaceOnly`**: distributes only the namespace resource, without any resources within the namespace. This option is useful when you want to establish namespaces across clusters while managing individual resources separately by using [`ResourcePlacement`](./concepts-namespace-scoped-resource-propagation.md).

This example shows how to distribute only the namespace without its contents.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: namespace-only-crp
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: my-app
      version: v1
      selectionScope: NamespaceOnly
  policy:
    placementType: PickAll
```

This approach enables a workflow where platform administrators use ClusterResourcePlacement to establish namespaces, while application teams use ResourcePlacement for fine-grained control over specific resources within those namespaces.

:::zone-end

### Placement policy

Fleet Manager resource placement supports the following placement policy types for controlling how it selects clusters:

* **[PickFixed](#pickfixed-placement-type)** places resources onto member clusters by using their cluster names.
* **[PickAll](#pickall-placement-type)** places resources onto all member clusters, or all member clusters that meet a criteria. This policy is useful for placing infrastructure workloads, such as cluster monitoring or reporting applications.
* **[PickN](#pickn-placement-type)** is the most flexible placement option. It allows you to select clusters based on affinity or topology spread constraints. Use this policy when spreading workloads across multiple similar clusters to ensure availability is maintained.

#### PickFixed placement type

Use `PickFixed` to select the clusters by name. Supply names in the `clusterNames` array.

:::zone target="docs" pivot="cluster-scope"

This example shows how to distribute the `test-deployment` namespace onto member clusters `cluster1` and `cluster2`.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: crp-fixed
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: test-deployment
      version: v1
  policy:
    placementType: PickFixed
    clusterNames:
    - cluster1
    - cluster2
```

:::zone-end

:::zone target="docs" pivot="namespace-scope"

This sample ResourcePlacement (RP) places the ConfigMap labeled `app: my-application` in the namespace `my-app` into the matching namespace on the two named clusters.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ResourcePlacement
metadata:
  name: app-configs-rp
  namespace: my-app
spec:
  resourceSelectors:
    - group: ""
      kind: ConfigMap
      version: v1
      labelSelector:
        matchLabels:
          app: my-application
  policy:
    placementType: PickFixed
    clusterNames:
    - cluster1
    - cluster2
```

:::zone-end

#### PickAll placement type

Use `PickAll` to distribute resources across all member clusters, or all clusters that match a criteria you specify.

When you create this type of placement, specify the following cluster affinity types:

- **requiredDuringSchedulingIgnoredDuringExecution**: as this policy is required during scheduling, it **filters** the clusters based on the specified criteria.

:::zone target="docs" pivot="cluster-scope"

This example shows how to distribute the `prod-deployment` namespace and all its child resources  across all member clusters labeled with `environment: production`.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: crp-pickall
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: prod-deployment
      version: v1
  policy:
    placementType: PickAll
    affinity:
        clusterAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
                clusterSelectorTerms:
                - labelSelector:
                    matchLabels:
                        environment: production
```

:::zone-end

:::zone target="docs" pivot="namespace-scope"

This sample ResourcePlacement (RP) places the ConfigMap labeled `app: my-application` in the namespace `my-app` into the matching namespace on all clusters labeled with `environment: production`:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ResourcePlacement
metadata:
  name: app-configs-rp-pickall
  namespace: my-app
spec:
  resourceSelectors:
    - group: ""
      kind: ConfigMap
      version: v1
      labelSelector:
        matchLabels:
          app: my-application
  policy:
    placementType: PickAll
    affinity:
        clusterAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
                clusterSelectorTerms:
                - labelSelector:
                    matchLabels:
                        environment: production
```

:::zone-end

#### PickN placement type

Use `PickN` to distribute resources onto a configurable number of clusters based on both affinities and topology spread constraints.

When you create this type of placement, specify the following cluster affinity types:

* **requiredDuringSchedulingIgnoredDuringExecution**: as this policy is required during scheduling, it **filters** the clusters based on the specified criteria.
* **preferredDuringSchedulingIgnoredDuringExecution**: as this policy is preferred, but not required during scheduling, it **ranks** clusters based on specified criteria.

You can set both required and preferred affinities. Required affinities prevent placement to clusters that don't match. Preferred affinities provide ordering of matched clusters.

##### PickN with affinities

Using affinities with a `PickN` placement policy works like using affinities with pod scheduling on a single Kubernetes cluster. 

The following example shows how to deploy a resource onto three clusters. Only clusters with the `critical-allowed: "true"` label are valid placement targets, and preference is given to clusters with the label `critical-level: 1`:

:::zone target="docs" pivot="cluster-scope"

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: crp-pickn-critical-preferences
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: prod-deployment
      version: v1
  policy:
    placementType: PickN
    numberOfClusters: 3
    affinity:
        clusterAffinity:
            preferredDuringSchedulingIgnoredDuringExecution:
              weight: 20
              preference:
              - labelSelector:
                  matchLabels:
                    critical-level: 1
            requiredDuringSchedulingIgnoredDuringExecution:
                clusterSelectorTerms:
                - labelSelector:
                    matchLabels:
                      critical-allowed: "true"
```

:::zone-end

:::zone target="docs" pivot="namespace-scope"

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ResourcePlacement
metadata:
  name: app-configs-rp-pickn-critical-preferences
  namespace: my-app
spec:
  resourceSelectors:
    - group: ""
      kind: ConfigMap
      version: v1
      labelSelector:
        matchLabels:
          app: my-application
  policy:
    placementType: PickN
    numberOfClusters: 3
    affinity:
        clusterAffinity:
            preferredDuringSchedulingIgnoredDuringExecution:
              weight: 20
              preference:
              - labelSelector:
                  matchLabels:
                    critical-level: 1
            requiredDuringSchedulingIgnoredDuringExecution:
                clusterSelectorTerms:
                - labelSelector:
                    matchLabels:
                      critical-allowed: "true"
```

:::zone-end

##### PickN with topology spread constraints

Use topology spread constraints to force placements across topology boundaries to satisfy availability requirements.

You can configure the behavior of topology spread constraints by using the `whenUnsatisfiable` property:

* **DoNotSchedule:** if the constraint can't be met, fail the placement request.
* **ScheduleAnyway:** if the constraint can't be met, place resources anyway.

The following example shows how to spread resources across multiple Azure regions and attempts to schedule across member clusters with different update days by using a custom label `updateDay`.

When the Azure region spread can't be met, placement fails. If the `updateDay` constraint isn't met, the placement still happens. 

:::zone target="docs" pivot="cluster-scope"

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: crp-pickn-locations-updates
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: prod-deployment
      version: v1
  policy:
    placementType: PickN
    topologySpreadConstraints:
    - maxSkew: 2
      topologyKey: fleet.azure.com/location
      whenUnsatisfiable: DoNotSchedule
    - maxSkew: 2
      topologyKey: updateDay
      whenUnsatisfiable: ScheduleAnyway
```

:::zone-end

:::zone target="docs" pivot="namespace-scope"

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ResourcePlacement
metadata:
  name: app-configs-rp-pickn-locations-updates
  namespace: my-app
spec:
  resourceSelectors:
    - group: ""
      kind: ConfigMap
      version: v1
      labelSelector:
        matchLabels:
          app: my-application
  policy:
    placementType: PickN
    topologySpreadConstraints:
    - maxSkew: 2
      topologyKey: fleet.azure.com/location
      whenUnsatisfiable: DoNotSchedule
    - maxSkew: 2
      topologyKey: updateDay
      whenUnsatisfiable: ScheduleAnyway
```

:::zone-end

For more information, see the [KubeFleet documentation on topology spread constraints][crp-topo].

## Select clusters by using labels and properties

Fleet Manager intelligent resource placement provides a set of powerful criteria you can use when determining how to select clusters when using the `PickN` and `PickAll` placement types. In this section, you learn how to use these options to build policies that suit your needs. 

### Placement policy options

The following table shows the available scheduling policy fields for each placement type.

|       Policy Field          | PickFixed | PickAll | PickN |
|-----------------------------|-----------|---------|-------|
| `placementType`             |    ✅     |   ✅    |  ✅   |
| `affinity`                  |    ❌     |   ✅    |  ✅   |
| `clusterNames`              |    ✅     |   ❌    |  ❌   |
| `numberOfClusters`          |    ❌     |   ❌    |  ✅   |
| `topologySpreadConstraints` |    ❌     |   ❌    |  ✅   |    

### Member cluster labels

You can label the `MemberCluster` resource on the hub cluster like any Kubernetes resource. 

Additionally, Fleet Manager automatically adds the following read-only labels to all member clusters. 

| Label                           | Description                                                                     |
|---------------------------------|---------------------------------------------------------------------------------|
| fleet.azure.com/location        | Azure Region of the cluster (`westus`)                                          |
| fleet.azure.com/resource-group  | Azure Resource Group of the cluster (`rg_prodapps_01`)                          |
| fleet.azure.com/subscription-id | Azure Subscription Identifier the cluster resides in. Formatted as UUID/GUID.   |
| fleet.azure.com/cluster-name    | The name of the cluster associated with the Fleet member cluster resource.      |
| fleet.azure.com/member-name     | The name of the Fleet Manager member cluster name corresponding to the cluster. |

### Cluster properties

Use the following properties as part of placement policies. 

| Property Name                                        | Description                                   |
|------------------------------------------------------|-----------------------------------------------|
| kubernetes-fleet.io/node-count                       | Available nodes on the member cluster.        |
| resources.kubernetes-fleet.io/total-cpu              | Total CPU resource units of cluster.          | 
| resources.kubernetes-fleet.io/allocatable-cpu        | Allocatable CPU resource units of cluster.    |
| resources.kubernetes-fleet.io/available-cpu          | Available CPU resource units of cluster.      |
| resources.kubernetes-fleet.io/total-memory           | Total memory resource unit of cluster.        |
| resources.kubernetes-fleet.io/allocatable-memory     | Allocatable memory resource units of cluster. |
| resources.kubernetes-fleet.io/available-memory       | Available memory resource units of cluster.   |
| kubernetes.azure.com/per-cpu-core-cost               | The per-CPU core cost of the cluster.         |
| kubernetes.azure.com/per-gb-memory-cost              | The per-GiB memory cost of the cluster.       | 
| kubernetes.azure.com/vm-sizes/{vm-sku-name}/count    | The available number of **existing nodes** of type [vm-sku-name][vm-sku-name] in the cluster*.<br/>Example VM SKU name: NV16as_v4.<br/>* In preview via v1beta1 API. |
| kubernetes.azure.com/vm-sizes/{vm-sku-name}/capacity | The number of **potential new nodes** of type [vm-sku-name][vm-sku-name] in the cluster's Azure region*.<br/>Example VM SKU name: NV16as_v4.<br/>* In preview via v1beta1 API. |


* Kubernetes resource units represent CPU and memory properties. For more information, see [Resource units in Kubernetes](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#resource-units-in-kubernetes).

* Cost properties are decimals that represent a per-hour cost in US dollars for the Azure compute that nodes within the cluster use. Cost is based on Azure public pricing.

### Selection matching criteria

When you use cluster properties in a policy criteria, specify:

* **Name**: Name of the property, which is one of the properties [listed in properties](#cluster-properties) in this article. 

* **Operator**: An operator that expresses the condition between the constraint or desired value and the observed value on the cluster. The following operators are currently supported:

    * `Gt` (Greater than): a cluster's observed value of the given property must be greater than the value in the condition before it can be picked for resource placement.
    * `Ge` (Greater than or equal to): a cluster's observed value of the given property must be greater than or equal to the value in the condition before it can be picked for resource placement.
    * `Lt` (Less than): a cluster's observed value of the given property must be less than the value in the condition before it can be picked for resource placement.
    * `Le` (Less than or equal to): a cluster's observed value of the given property must be less than or equal to the value in the condition before it can be picked for resource placement.
    * `Eq` (Equal to): a cluster's observed value of the given property must be equal to the value in the condition before it can be picked for resource placement.
    * `Ne` (Not equal to): a cluster's observed value of the given property must not be equal to the value in the condition before it can be picked for resource placement.

    If you use the operator `Gt`, `Ge`, `Lt`, `Le`, `Eq`, or `Ne`, the list of values in the condition should have exactly one value.

* **Values:** A list of values, which are possible values of the property.

Fleet evaluates each cluster based on the properties you specify in the condition. If a cluster doesn't satisfy the conditions listed under `requiredDuringSchedulingIgnoredDuringExecution`, Fleet excludes the cluster from resource placement.

> [!NOTE]
> If a member cluster doesn't possess the property expressed in the condition, it automatically fails the condition.

Here's an example placement policy to select only clusters with five or more nodes.

:::zone target="docs" pivot="cluster-scope"

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: crp-pickall-five-nodes
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: prod-deployment
      version: v1
  policy:
    placementType: PickAll
    affinity:
        clusterAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
                clusterSelectorTerms:
                - propertySelector:
                    matchExpressions:
                    - name: "kubernetes-fleet.io/node-count"
                      operator: Ge
                      values:
                      - "5"
```

:::zone-end

:::zone target="docs" pivot="namespace-scope"

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ResourcePlacement
metadata:
  name: app-configs-rp-pickall-five-nodes
  namespace: my-app
spec:
  resourceSelectors:
    - group: ""
      kind: ConfigMap
      version: v1
      labelSelector:
        matchLabels:
          app: my-application
  policy:
    placementType: PickAll
    affinity:
        clusterAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
                clusterSelectorTerms:
                - propertySelector:
                    matchExpressions:
                    - name: "kubernetes-fleet.io/node-count"
                      operator: Ge
                      values:
                      - "5"
```

:::zone-end

#### How property ranking works

When you use `preferredDuringSchedulingIgnoredDuringExecution`, a property sorter ranks all the clusters in the fleet based on their values in an ascending or descending order. The weights used for ordering are calculated based on the value you specify.

A property sorter consists of:

* **Name**: Name of the cluster property.
* **Sort order**: Sort order can be either `Ascending` or `Descending`. When you use `Ascending` order, member clusters with lower observed values are preferred. When you use `Descending` order, member clusters with higher observed value are preferred.

For more information, see the [KubeFleet documentation on property-based scheduling][kubefleet-props].

## Configuring rollout strategy

Fleet Manager resource placement uses a default `RollingUpdate` strategy to control how resources are distributed to member clusters.

In the following example, the placement rolls out to each member cluster sequentially, waiting at least `unavailablePeriodSeconds` between clusters. 

:::zone target="docs" pivot="cluster-scope"

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: crp-pick-all-rolling
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: prod-deployment
      version: v1
  policy:
    placementType: PickAll
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
      unavailablePeriodSeconds: 60
```

:::zone-end

:::zone target="docs" pivot="namespace-scope"

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ResourcePlacement
metadata:
  name: app-configs-rp-pickall-rolling
  namespace: my-app
spec:
  resourceSelectors:
    - group: ""
      kind: ConfigMap
      version: v1
      labelSelector:
        matchLabels:
          app: my-application
  policy:
    placementType: PickAll
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
      unavailablePeriodSeconds: 60
```

:::zone-end

Rollout status is considered successful if all resources are correctly applied to the cluster. This status doesn't cascade child resource status, so it doesn't confirm that pods created on a member cluster by a deployment become ready.

For more information, see the [documentation on rollout strategies][fleet-rollout].

## Using tolerations

You can taint member clusters just like you taint nodes in a cluster. 

Resource placements support the use of tolerations where each toleration consists of the following fields:

* `key`: The key of the toleration.
* `value`: The value of the toleration.
* `effect`: The effect of the toleration, such as `NoSchedule`.
* `operator`: The operator of the toleration, such as `Exists` or `Equal`.

Each toleration is used to tolerate one or more specific taints applied on a `MemberCluster`. Once all taints are tolerated, Fleet Manager can distribute resources to the member cluster.

:::zone target="docs" pivot="cluster-scope"

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterResourcePlacement
metadata:
  name: test-ns
spec:
  policy:
    placementType: PickAll
    tolerations:
      - key: app-team-a
        operator: Exists
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: test-ns
      version: v1
  revisionHistoryLimit: 10
  strategy:
    type: RollingUpdate
```
:::zone-end

:::zone target="docs" pivot="namespace-scope"

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ResourcePlacement
metadata:
  name: app-configs-rp-pickall-rolling
  namespace: my-app
spec:
  resourceSelectors:
    - group: ""
      kind: ConfigMap
      version: v1
      labelSelector:
        matchLabels:
          app: my-application
  policy:
    placementType: PickAll
    tolerations:
      - key: app-team-a
        operator: Exists
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
      unavailablePeriodSeconds: 60
```

:::zone-end

For more information, see the [documentation on tolerations][fleet-tolerations].

## Using envelope resources

The Fleet Manager hub cluster is also a Kubernetes cluster. You first apply any resource you want to distribute to the hub cluster. This approach can lead to:

1. **Unintended side effects**: ValidatingWebhookConfigurations, MutatingWebhookConfigurations, or Admission Controllers become active on the hub cluster, potentially intercepting and affecting hub cluster operations.

1. **Security risks**: RBAC resources (Roles, ClusterRoles, RoleBindings, ClusterRoleBindings) intended for member clusters could grant or restrict permissions on the hub cluster.

1. **Resource limitations**: ResourceQuotas, FlowSchema, or LimitRanges defined for member clusters take effect on the hub cluster.

To avoid unnecessary side effects, Fleet Manager provides custom envelope resources (ClusterResourceEnvelope and ResourceEnvelope) to wrap objects and avoid these potential problems. 

You apply the envelope resource to the hub cluster, but the resources it contains are extracted and applied when they reach member clusters. 

For more information, see the documentation on [envelope objects][envelope-object].

## Determine placement status

Fleet Manager resource placement provides two ways to view status depending on your hub cluster access level and requirements:

:::zone target="docs" pivot="cluster-scope"

* **ClusterResourcePlacement status**: View placement status directly on the cluster-scoped `ClusterResourcePlacement` resource. Use when you have cluster-level permissions and need to view status for any placement across the fleet.

:::zone-end

:::zone target="docs" pivot="namespace-scope"

* **ResourcePlacement status**: View placement status directly on the namespace-scoped `ResourcePlacement` resource. Use when you have namespace-level permissions and need to view status for a namespace-scoped placement across the fleet.

### Viewing ClusterResourcePlacement status

You can view this information by using the `kubectl describe resourceplacement <rp-name>` command.

```bash
kubectl describe resourceplacement place-cmap-1
```

:::zone-end

:::zone target="docs" pivot="cluster-scope"

* **ClusterResourcePlacementStatus (preview)**: View placement status through a namespace-scoped `ClusterResourcePlacementStatus` resource. Use this resource when namespace-scoped users need to view placement status without granting cluster-level permissions. For more information, see the [ClusterResourcePlacementStatus section](#use-clusterresourceplacementstatus-resource-preview).

Both approaches provide the following information:

* The conditions that currently apply to the placement, which include if the placement was successfully completed.
* A placement status section for each member cluster, which shows the status of deployment to that cluster.

### Use ClusterResourcePlacement status

The following example shows viewing status directly from a `ClusterResourcePlacement` that deployed the `test` namespace and the `test-1` ConfigMap into two member clusters by using `PickN`. The placement was successfully completed and the resources were placed into the `aks-member-1` and `aks-member-2` clusters.

You can view this information by using the `kubectl describe clusterresourceplacement <crp-name>` command.

```bash
kubectl describe clusterresourceplacement crp-1
```

```output
Name:         crp-1
Namespace:
Labels:       <none>
Annotations:  <none>
API Version:  placement.kubernetes-fleet.io/v1
Kind:         ClusterResourcePlacement
Metadata:
  ...
Spec:
  Policy:
    Number Of Clusters:  2
    Placement Type:      PickN
  Resource Selectors:
    Group:
    Kind:                  Namespace
    Name:                  test
    Version:               v1
  Revision History Limit:  10
Status:
  Conditions:
    Last Transition Time:  2023-11-10T08:14:52Z
    Message:               found all the clusters needed as specified by the scheduling policy
    Observed Generation:   5
    Reason:                SchedulingPolicyFulfilled
    Status:                True
    Type:                  ClusterResourcePlacementScheduled
    Last Transition Time:  2023-11-10T08:23:43Z
    Message:               All 2 cluster(s) are synchronized to the latest resources on the hub cluster
    Observed Generation:   5
    Reason:                SynchronizeSucceeded
    Status:                True
    Type:                  ClusterResourcePlacementSynchronized
    Last Transition Time:  2023-11-10T08:23:43Z
    Message:               Successfully applied resources to 2 member clusters
    Observed Generation:   5
    Reason:                ApplySucceeded
    Status:                True
    Type:                  ClusterResourcePlacementApplied
  Placement Statuses:
    Cluster Name:  aks-member-1
    Conditions:
      Last Transition Time:  2023-11-10T08:14:52Z
      Message:               Successfully scheduled resources for placement in aks-member-1 (affinity score: 0, topology spread score: 0): picked by scheduling policy
      Observed Generation:   5
      Reason:                ScheduleSucceeded
      Status:                True
      Type:                  ResourceScheduled
      Last Transition Time:  2023-11-10T08:23:43Z
      Message:               Successfully Synchronized work(s) for placement
      Observed Generation:   5
      Reason:                WorkSynchronizeSucceeded
      Status:                True
      Type:                  WorkSynchronized
      Last Transition Time:  2023-11-10T08:23:43Z
      Message:               Successfully applied resources
      Observed Generation:   5
      Reason:                ApplySucceeded
      Status:                True
      Type:                  ResourceApplied
    Cluster Name:            aks-member-2
    Conditions:
      Last Transition Time:  2023-11-10T08:14:52Z
      Message:               Successfully scheduled resources for placement in aks-member-2 (affinity score: 0, topology spread score: 0): picked by scheduling policy
      Observed Generation:   5
      Reason:                ScheduleSucceeded
      Status:                True
      Type:                  ResourceScheduled
      Last Transition Time:  2023-11-10T08:23:43Z
      Message:               Successfully Synchronized work(s) for placement
      Observed Generation:   5
      Reason:                WorkSynchronizeSucceeded
      Status:                True
      Type:                  WorkSynchronized
      Last Transition Time:  2023-11-10T08:23:43Z
      Message:               Successfully applied resources
      Observed Generation:   5
      Reason:                ApplySucceeded
      Status:                True
      Type:                  ResourceApplied
  Selected Resources:
    Kind:       Namespace
    Name:       test
    Version:    v1
    Kind:       ConfigMap
    Name:       test-1
    Namespace:  test
    Version:    v1
Events:
  Type    Reason                     Age                    From                                   Message
  ----    ------                     ----                   ----                                   -------
  Normal  PlacementScheduleSuccess   12m (x5 over 3d22h)    cluster-resource-placement-controller  Successfully scheduled the placement
  Normal  PlacementSyncSuccess       3m28s (x7 over 3d22h)  cluster-resource-placement-controller  Successfully synchronized the placement
  Normal  PlacementRolloutCompleted  3m28s (x7 over 3d22h)  cluster-resource-placement-controller  Resources have been applied to the selected clusters
```

### Use ClusterResourcePlacementStatus resource (preview)

The `ClusterResourcePlacementStatus` resource is namespace-scoped and provides the placement status for a corresponding cluster-scoped `ClusterResourcePlacement` object. This resource enables namespace users without cluster-level rights to read the status.

> [!IMPORTANT]
> The `ClusterResourcePlacementStatus` resource and `StatusReportingScope` field are available in the `placement.kubernetes-fleet.io/v1beta1` API version as a preview feature. They're not available in the `placement.kubernetes-fleet.io/v1` API.

To use this approach, configure the `ClusterResourcePlacement` with `statusReportingScope: NamespaceAccessible` by using the `v1beta1` API.

When you set `statusReportingScope` to `NamespaceAccessible`, you can only specify one namespace resource selector, and you can't change it after creation.

#### Configuring ClusterResourcePlacementStatus

To use this feature, specify the v1beta1 API version in your `ClusterResourcePlacement`:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterResourcePlacement
metadata:
  name: crp-with-status-reporting
spec:
  statusReportingScope: NamespaceAccessible
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: my-app
      version: v1
  policy:
    placementType: PickAll
```

#### Viewing ClusterResourcePlacementStatus

You can view the status by using the `kubectl describe` command:

```bash
kubectl describe clusterresourceplacementstatuses.v1beta1.placement.kubernetes-fleet.io crp-with-status-reporting -n my-app
```

The output contains the same status information as the `ClusterResourcePlacement` but is accessible to users with only namespace-level permissions.

For more information, see the [documentation on how to understand the placement result][fleet-status].

:::zone-end

## Placement change triggers

The Fleet Manager scheduler prioritizes stability of existing resource placements. This priority limits the number of changes that remove and reschedule a resource.

The following scenarios can trigger placement changes:

* Placement policy changes in the resource placement (`ClusterResourcePlacement` or `ResourcePlacement`) can trigger removal and rescheduling of a resource.
    * Scale out operations (increasing `numberOfClusters` with no other changes) place workloads only on new clusters and don't affect existing placements.
* Member cluster changes, including:
    * A new member cluster becoming eligible and meeting the placement policy, for example, a `PickAll` policy.
    * Removal of a member cluster from the fleet. Depending on the policy, the scheduler attempts to place all affected resources on remaining clusters without affecting existing placements.

Updating the selected resources (for example, modifying a `Deployment`) or updating the `resourceSelector` in a resource placement causes Fleet Manager to gradually roll out existing placements but **doesn't** trigger rescheduling (that is, changing picked clusters) of the resource.

## Working with ResourcePlacement and ClusterResourcePlacement together

While `ClusterResourcePlacement` assumes that namespaces represent application boundaries, real-world usage patterns are often more complex. Organizations frequently use namespaces as team boundaries rather than application boundaries, leading to several challenges that `ResourcePlacement` directly addresses:

**Multi-application namespaces**: In many organizations, a single namespace contains multiple independent applications owned by the same team. These applications might have:

- Different lifecycle requirements (one application might need frequent updates while another remains stable).
- Different cluster placement needs (development vs. production applications).
- Independent scaling and resource requirements.
- Separate compliance or governance requirements.

**Individual scheduling decisions**: Many workloads, particularly AI/ML jobs, require individual scheduling decisions:

- **AI Jobs**: Machine learning workloads often consist of short-lived, resource-intensive jobs that need to be scheduled based on cluster resource availability, GPU availability, or data locality.
- **Batch Workloads**: Different batch jobs within the same namespace might target different cluster types based on computational requirements.

**Complete application team control**: `ResourcePlacement` provides application teams with direct control over their resource placement without requiring platform team intervention:

- **Self-service operations**: Teams can manage their own resource distribution strategies.
- **Independent deployment cycles**: Different applications within a namespace can have independent rollout schedules.
- **Granular override capabilities**: Teams can customize resource configurations per cluster without affecting other applications in the namespace.

This granular approach ensures that `ResourcePlacement` can adapt to diverse organizational structures and workload patterns while maintaining the simplicity and power of the Fleet scheduling framework.

### Key differences between ResourcePlacement and ClusterResourcePlacement

The following table highlights the key differences between `ResourcePlacement` and `ClusterResourcePlacement`:

| Aspect | ResourcePlacement (RP) | ClusterResourcePlacement (CRP) |
|--------|------------------------|--------------------------------|
| **Scope** | Namespace-scoped resources only | Cluster-scoped resources (especially namespaces and their contents) |
| **Resource** | Namespace-scoped API object | Cluster-scoped API object |
| **Selection Boundary** | Limited to resources within the same namespace as the RP | Can select any cluster-scoped resource |
| **Typical Use Cases** | AI/ML jobs, individual workloads, specific ConfigMaps/Secrets that need independent placement decisions | Application bundles, entire namespaces, cluster-wide policies |
| **Team Ownership** | Namespace owners and developers | Platform operators |

Both `ResourcePlacement` and `ClusterResourcePlacement` share the same core capabilities for all other aspects not listed in the differences table.

### Example scenario using ResourcePlacement and ClusterResourcePlacement

`ResourcePlacement` works with `ClusterResourcePlacement` (CRP) to provide a complete multicluster resource management solution. Understanding this relationship is crucial for effective fleet management.

> [!IMPORTANT]
> `ResourcePlacement` can only place namespace-scoped resources to clusters that already have the target namespace. Use `ClusterResourcePlacement` for namespace establishment.

**Typical workflow**:

1. **Platform admins**: Use `ClusterResourcePlacement` to deploy namespaces across the fleet.
1. **Application teams**: Use `ResourcePlacement` to manage specific resources within those established namespaces.

The following examples show how to coordinate CRP and RP.

**Platform admin**: Create the namespace by using `ClusterResourcePlacement`:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: app-namespace-crp
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: my-app
      version: v1
      selectionScope: NamespaceOnly # only namespace itself is placed, no resources within the namespace
  policy:
    placementType: PickAll # If placement type is not PickAll, the application teams needs to know what are the clusters they can place their applications.
```

**Application team**: Manage specific resources within the namespace by using `ResourcePlacement`:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ResourcePlacement
metadata:
  name: app-configs-rp
  namespace: my-app
spec:
  resourceSelectors:
    - group: ""
      kind: ConfigMap
      version: v1
      labelSelector:
        matchLabels:
          app: my-application
  policy:
    placementType: PickFixed
    clusterNames:
    - cluster1
    - cluster2
```

### Best practices for ResourcePlacement and ClusterResourcePlacement

When you use `ResourcePlacement` with `ClusterResourcePlacement`, follow these best practices:

- **Establish namespaces first**: Always deploy namespaces through CRP before creating `ResourcePlacement` objects.
- **Monitor dependencies**: Use Fleet monitoring to ensure namespace-level CRPs are healthy before deploying dependent RPs.
- **Coordinate policies**: Align CRP and RP placement policies to avoid conflicts. For example, if CRP places the namespace on clusters A, B, and C, RP can target any subset of those clusters.
- **Team boundaries**: Use CRP for platform-managed resources (namespaces, RBAC) and RP for application-managed resources (app configs, secrets).

This coordinated approach ensures that `ResourcePlacement` provides the flexibility teams need while maintaining the foundational infrastructure managed by platform operators.

### Resource selection, placement, and rollout

`ResourcePlacement` uses the same placement patterns as `ClusterResourcePlacement`:

- **[Placement policy](#placement-policy)**: `PickAll`, `PickFixed`, and `PickN` policies work identically for both APIs.
- **[Rollout strategy](#configuring-rollout-strategy)**: Control how updates propagate across clusters with the same rolling update mechanisms.
- **[Status and observability](./howto-understand-placement.md)**: Monitor deployment progress by using `kubectl describe resourceplacement <name> -n <namespace>`.
- **[Advanced features](./concepts-resource-placement.md)**: Use tolerations, resource overrides, topology spread constraints, and affinity rules.

The key difference is in **resource selection** scope. While `ClusterResourcePlacement` typically selects entire namespaces and their contents, `ResourcePlacement` provides fine-grained control over individual namespace-scoped resources.

:::zone-end

## Next steps

* [Use Fleet Manager resource placement to deploy workloads across multiple clusters](./quickstart-resource-propagation.md).
* [Using ResourcePlacement to deploy namespace-scoped resources](./concepts-namespace-scoped-resource-propagation.md).
* [Intelligent cross-cluster Kubernetes resource placement based on member clusters properties](./intelligent-resource-placement.md).
* [Controlling eviction and disruption for resource placement](./concepts-eviction-disruption.md).
* [Defining a rollout strategy for a resource placement](./concepts-rollout-strategy.md).
* [Fleet Manager resource placement FAQs](./faq.md#cluster-resource-placement-faqs).

<!-- LINKS - internal -->
[envelope-object]: ./quickstart-envelope-reserved-resources.md
[fleet-rollout]: ./concepts-rollout-strategy.md
[fleet-tolerations]: ./use-taints-tolerations.md
[fleet-status]: ./howto-understand-placement.md

<!-- LINKS - external -->
[kubefleet-props]: https://kubefleet.dev/docs/how-tos/property-based-scheduling/
[crp-topo]: https://kubefleet.dev/docs/how-tos/topology-spread-constraints/
[vm-sku-name]: /azure/virtual-machines/vm-naming-conventions
