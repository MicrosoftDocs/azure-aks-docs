---
title: "Introducing Azure Kubernetes Fleet Manager intelligent resource placement"
description: This article describes the concepts of Azure Kubernetes Fleet Manager intelligent resource placement
ms.date: 04/23/2026
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

Using Fleet Manager's intelligent resource placement involves these steps:

1. **Stage resources on hub cluster**: use Continuous Deployment, GitOps or similar to apply the manifests for resource for distributions on the Fleet Manager hub cluster.
1. **Create a resource placement**: create a placement manifest that selects the resource and defines a policy that is used to select which member clusters will receive the resource.
1. **Apply resource placement on hub cluster**: take the placement manifest and apply to the hub cluster to initiate distribution of the resource.
1. **Fleet Manager schedules resources**: Fleet Manager observes the resource placement and the selected scope and performs the distribution of the resources.
1. **Observe distribution via resource placement**: query the resource placement on the hub cluster to observe the status of the resource as it rolls out.

Fleet Manager has an Azure portal experience for resource placement that provides a more visual representation of the rollout.

:::zone target="docs" pivot="cluster-scope"

## Introducing cluster-scoped resource placement

Use a ClusterResourcePlacement (CRP) to distribute a given set of cluster-scoped resource or entire namespaces from the Fleet Manager hub cluster onto one or more member cluster.

**Key characteristics:**

- **Cluster-scoped**: selects cluster-scoped resources or namespaces.
- **Declarative**: Uses the same placement policies as `ResourcePlacement` for consistent behavior.

With CRP, you can:

* Select which Kubernetes resources to distribute. These can be cluster-scoped Kubernetes resources defined using [Kubernetes Group Version Kind (GVK)](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.33/#api-groups) references, or a namespace, which distributes the namespace and all its resources.
* Specify placement policies to select member clusters. These policies can explicitly select clusters by names, or dynamically select clusters based on cluster labels and properties. 
* Specify rollout strategies to safely roll out any updates of the selected Kubernetes resources to multiple target clusters.
* View the rollout progress for each target cluster.

For scenarios requiring fine-grained control over individual namespace-scoped resources within a namespace, see [namespace-scoped resource placement](./concepts-namespace-scoped-resource-propagation.md?pivots=namespace-scope#overview-of-namespace-scoped-resource-placement), which enables distribution of specific resources rather than entire namespaces.

:::zone-end

:::zone target="docs" pivot="namespace-scope"

## Introducing namespace-scoped resource placement

Use a ResourcePlacement (RP) to distribute a given set of resources within a specific namespace from the Fleet Manager hub cluster onto one or more member cluster. ResourcePlacement provides fine-grained control over how specific resources within a namespace are distributed across member clusters.

> [!IMPORTANT]
> `ResourcePlacement` uses the `placement.kubernetes-fleet.io/v1beta1` API version and is currently in preview. Some features demonstrated in this article, such as `selectionScope` in `ClusterResourcePlacement`, are also part of the v1beta1 API and aren't available in the v1 API.

**Key characteristics:**

- **Namespace-scoped**: Both `ResourcePlacement` and the resources it selects exist within the same namespace.
- **Selective**: selects specific resources within the namespace by type, name, or labels rather than entire namespaces.
- **Declarative**: Uses the same placement policies as `ClusterResourcePlacement` for consistent behavior.

### When to use ResourcePlacement

`ResourcePlacement` is ideal for scenarios requiring granular control over namespace-scoped resources:

- **Selective resource distribution**: Deploy specific ConfigMaps, Secrets, or Services without affecting the entire namespace.
- **Multi-tenant environments**: Allow different teams to manage their resources independently within shared namespaces.
- **Configuration management**: Distribute environment-specific configurations across different cluster environments.
- **Compliance and governance**: Apply different policies to different resource types within the same namespace.
- **Progressive rollouts**: Safely deploy resource updates across clusters with zero-downtime strategies.

In multi-cluster environments, workloads often consist of both cluster-scoped and namespace-scoped resources that need to be distributed across different clusters. While `ClusterResourcePlacement` (CRP) handles cluster-scoped resources effectively, entire namespaces and their contents, there are scenarios where you need more granular control over namespace-scoped resources within existing namespaces.

`ResourcePlacement` (RP) was designed to address this gap by providing:

- **Namespace-scoped resource management**: Target specific resources within a namespace without affecting the entire namespace.
- **Operational flexibility**: Allow teams to manage different resources within the same namespace independently.
- **Complementary functionality**: Work alongside CRP to provide a complete multi-cluster resource management solution.

> [!NOTE]
> `ResourcePlacement` can be used together with `ClusterResourcePlacement` in namespace-only mode. For example, you can use CRP to deploy the namespace, while using RP for fine-grained management of specific resources like environment-specific ConfigMaps or Secrets within that namespace.

:::zone-end

## Resource placement components

A resource placement, regardless of scope (cluster or namespace) consists of the following components:

- **[Resource selectors](#resource-selectors)**: select the resources to include via `resourceSelectors`.
- **[Placement policy](#placement-policy)**: define how to pick clusters via `placementType` using one of `PickAll`, `PickFixed`, or `PickN` types.
- **[Rollout strategy](#configuring-rollout-strategy)**: control how resources rollout across selected clusters by including an optional `strategy`.

:::zone target="docs" pivot="cluster-scope"

This sample ClusterResourcePlacement (CRP) places the namespace `my-app` onto all clusters in the fleet. As no explicit strategy is defined, a `RollingUpdate` is used.

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

This sample ResourcePlacement (RP) places the ConfigMap labeled `app=my-application` in the namespace `my-app` into the matching namespace on the two named clusters.  As no explicit strategy is defined, a `RollingUpdate` is used.

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

Select resources using one or more `resourceSelectors` in a placement. Each resource selector can specify:

* **Group, Version, Kind (GVK)**: The type of Kubernetes resource to select.
* **Name**: The name of a specific resource.
* **Label selectors**: Labels to match multiple resources.

:::zone target="docs" pivot="cluster-scope"

#### Namespace selection scope (preview)

When using cluster-scoped placement to select an entire namespace, you can use the `selectionScope` field to control whether to include all the child resources in the namespace, or just place an empty namespace.

* **Default behavior** (when `selectionScope` is not specified): distributes the namespace and all resources within it.
* **`NamespaceOnly`**: distributes only the namespace resource, without any resources within the namespace. This is useful when you want to establish namespaces across clusters while managing individual resources separately using [`ResourcePlacement`](./concepts-namespace-scoped-resource-propagation.md).

> [!IMPORTANT]
> The `selectionScope` field is available in the `placement.kubernetes-fleet.io/v1beta1` API version as a preview feature. It is not available in the `placement.kubernetes-fleet.io/v1` API.

This example shows how to distribute only the namespace without its contents.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
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

The following placement policy types are available for controlling how the clusters are selected by Fleet Manager resource placement:

* **[PickFixed](#pickfixed-placement-type)** places resources onto member clusters using their cluster name.
* **[PickAll](#pickall-placement-type)** places resources onto all member clusters, or all member clusters that meet a criteria. This policy is useful for placing infrastructure workloads, like cluster monitoring or reporting applications.
* **[PickN](#pickn-placement-type)** is the most flexible placement option and allows for selection of clusters based on affinity or topology spread constraints and is useful when spreading workloads across multiple similar clusters to ensure availability is maintained.

#### PickFixed placement type

Use `PickFixed` to select the clusters by name, supplying names in the `clusterNames` array.

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

Use `PickAll` to distribute resources across all member clusters, or all clusters matching a criteria you specify.

When creating this type of placement the following cluster affinity types can be specified:

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

When creating this type of placement the following cluster affinity types can be specified:

* **requiredDuringSchedulingIgnoredDuringExecution**: as this policy is required during scheduling, it **filters** the clusters based on the specified criteria.
* **preferredDuringSchedulingIgnoredDuringExecution**: as this policy is preferred, but not required during scheduling, it **ranks** clusters based on specified criteria.

You can set both required and preferred affinities. Required affinities prevent placement to clusters that don't match. Preferred affinities provide ordering of matched clusters.

##### PickN with affinities

Using affinities with a `PickN` placement policy functions similarly to using affinities with pod scheduling on a single Kubernetes cluster. 

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

Use topology spread constraints to force placements across topology boundaries in order to satisfy availability requirements.

You can configure the behavior of topology spread constraints by using the `whenUnsatisfiable` property:

* **DoNotSchedule:** if the constraint can't be met, fail the placement request.
* **ScheduleAnyway:** if the constraint can't be met, place resources any way.

The following example shows how to spread resources across multiple Azure regions and attempts to schedule across member clusters with different update days using a custom label `updateDay`.

When the Azure region spread can't be met, placement will fail. If the `updateDay` constraint isn't met, the placement will still happen. 

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

## Select clusters using labels and properties

Fleet Manager intelligent resource placement provides a set of powerful criteria you can use when determining how clusters are selected when using the `PickN` and `PickAll` placement types. In this section we'll take a look at how you can use these options to build policies to suit your needs. 

### Placement policy options

Available scheduling policy fields for each placement type are shown in the table.

|       Policy Field          | PickFixed | PickAll | PickN |
|-----------------------------|-----------|---------|-------|
| `placementType`             |    ✅     |   ✅    |  ✅   |
| `affinity`                  |    ❌     |   ✅    |  ✅   |
| `clusterNames`              |    ✅     |   ❌    |  ❌   |
| `numberOfClusters`          |    ❌     |   ❌    |  ✅   |
| `topologySpreadConstraints` |    ❌     |   ❌    |  ✅   |    

### Member cluster labels

The `MemberCluster` resource on the hub cluster can be labeled like any Kubernetes resource. 

Additionally, Fleet Manager automatically adds the following read only labels to all member clusters. 

| Label                           | Description                                                                     |
|---------------------------------|---------------------------------------------------------------------------------|
| fleet.azure.com/location        | Azure Region of the cluster (`westus`)                                          |
| fleet.azure.com/resource-group  | Azure Resource Group of the cluster (`rg_prodapps_01`)                          |
| fleet.azure.com/subscription-id | Azure Subscription Identifier the cluster resides in. Formatted as UUID/GUID.   |
| fleet.azure.com/cluster-name    | The name of the cluster associated with the Fleet member cluster resource.      |
| fleet.azure.com/member-name     | The name of the Fleet Manager member cluster name corresponding to the cluster. |

### Cluster properties

The following properties are available for use as part of placement policies. 

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


* CPU and memory properties are represented as [Kubernetes resource units](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#resource-units-in-kubernetes).

* Cost properties are decimals, which represent a per-hour cost in US Dollars for the Azure compute utilized for nodes within the cluster. Cost is based on Azure public pricing.

### Selection matching criteria

When using cluster properties in a policy criteria, you specify:

* **Name**: Name of the property, which is one the properties [listed in properties](#cluster-properties) in this article. 

* **Operator**: An operator used to express the condition between the constraint/desired value and the observed value on the cluster. The following operators are currently supported:

    * `Gt` (Greater than): a cluster's observed value of the given property must be greater than the value in the condition before it can be picked for resource placement.
    * `Ge` (Greater than or equal to): a cluster's observed value of the given property must be greater than or equal to the value in the condition before it can be picked for resource placement.
    * `Lt` (Less than): a cluster's observed value of the given property must be less than the value in the condition before it can be picked for resource placement.
    * `Le` (Less than or equal to): a cluster's observed value of the given property must be less than or equal to the value in the condition before it can be picked for resource placement.
    * `Eq` (Equal to): a cluster's observed value of the given property must be equal to the value in the condition before it can be picked for resource placement.
    * `Ne` (Not equal to): a cluster's observed value of the given property must be not equal to the value in the condition before it can be picked for resource placement.

    If you use the operator `Gt`, `Ge`, `Lt`, `Le`, `Eq`, or `Ne`, the list of values in the condition should have exactly one value.

* **Values:** A list of values, which are possible values of the property.

Fleet evaluates each cluster based on the properties specified in the condition. Failure to satisfy conditions listed under `requiredDuringSchedulingIgnoredDuringExecution` excludes a member cluster from resource placement.

> [!NOTE]
> If a member cluster doesn't possess the property expressed in the condition, it will automatically fail the condition.

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

When `preferredDuringSchedulingIgnoredDuringExecution` is used, a property sorter ranks all the clusters in the fleet based on their values in an ascending or descending order. The weights used for ordering are calculated based on the value specified.

A property sorter consists of:

* **Name**: Name of the cluster property.
* **Sort order**: Sort order can be either `Ascending` or `Descending`. When `Ascending` order is used, member clusters with lower observed values are preferred. When `Descending` order is used, member clusters with higher observed value are preferred.

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

Rollout status is considered successful if all resources were correctly applied to the cluster. This status doesn't cascade child resource status, so for example, it doesn't confirm that pods created on a member cluster by a deployment become ready.

For more information, see the [documentation on rollout strategies][fleet-rollout].

## Using tolerations

Member clusters can be tainted in the same way that nodes in a cluster can be tainted. 

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

It's important to understand that the Fleet Manager hub cluster is also a Kubernetes cluster. Any resource you want to distribute is first applied to the hub cluster, which can lead to:

1. **Unintended side effects**: ValidatingWebhookConfigurations, MutatingWebhookConfigurations, or Admission Controllers become active on the hub cluster, potentially intercepting and affecting hub cluster operations.

2. **Security Risks**: RBAC resources (Roles, ClusterRoles, RoleBindings, ClusterRoleBindings) intended for member clusters could grant or restrict permissions on the hub cluster.

3. **Resource Limitations**: ResourceQuotas, FlowSchema, or LimitRanges defined for member clusters take effect on the hub cluster.

To avoid unnecessary side effects, Fleet Manager provides custom envelope resources (ClusterResourceEnvelope and ResourceEnvelope) to wrap objects to avoid these potential problems. 

The envelope resource is applied to the hub cluster, but the resources it contains are extracted and applied when they reach member clusters. 

For more information, see the documentation on [envelope objects][envelope-object].

## Determine placement status

Fleet Manager resource placement provides two ways to view status depending on your hub cluster access level and requirements:

:::zone target="docs" pivot="cluster-scope"

* **ClusterResourcePlacement status**: View placement status directly on the cluster-scoped `ClusterResourcePlacement` resource. Use when you have cluster-level permissions and need to view status for any placement across the fleet.

:::zone-end

:::zone target="docs" pivot="namespace-scope"

* **ResourcePlacement status**: View placement status directly on the namespace-scoped `ResourcePlacement` resource. Use when you have namespace-level permissions and need to view status for a namespace-scoped placement across the fleet.

### Viewing ClusterResourcePlacement status

You can view this information using the `kubectl describe resourceplacement <rp-name>` command.

```bash
kubectl describe resourceplacement place-cmap-1
```

:::zone-end

:::zone target="docs" pivot="cluster-scope"

* **ClusterResourcePlacementStatus (preview)**: View placement status through a namespace-scoped `ClusterResourcePlacementStatus` resource. Use when namespace-scoped users need to view placement status without granting cluster-level permissions. For more information, see the [ClusterResourcePlacementStatus section](#use-clusterresourceplacementstatus-resource-preview).

Both approaches provide the following information:

* The conditions that currently apply to the placement, which include if the placement was successfully completed.
* A placement status section for each member cluster, which shows the status of deployment to that cluster.

### Use ClusterResourcePlacement status

The following example shows viewing status directly from a `ClusterResourcePlacement` that deployed the `test` namespace and the `test-1` ConfigMap into two member clusters using `PickN`. The placement was successfully completed and the resources were placed into the `aks-member-1` and `aks-member-2` clusters.

You can view this information using the `kubectl describe clusterresourceplacement <crp-name>` command.

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

The `ClusterResourcePlacementStatus` is a namespace-scoped resource that provides the placement status of a corresponding cluster-scoped `ClusterResourcePlacement` object, allowing namespace users who don't have cluster-level rights to read the status.

> [!IMPORTANT]
> The `ClusterResourcePlacementStatus` resource and `StatusReportingScope` field are available in the `placement.kubernetes-fleet.io/v1beta1` API version as a preview feature. They aren't available in the `placement.kubernetes-fleet.io/v1` API.

To use this approach the `ClusterResourcePlacement` must be configured with `statusReportingScope: NamespaceAccessible` using the `v1beta1` API.

When `statusReportingScope` is set to `NamespaceAccessible`, only one namespace resource selector is allowed, and can't be changed after creation.

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

You can view the status using the `kubectl describe` command:

```bash
kubectl describe clusterresourceplacementstatuses.v1beta1.placement.kubernetes-fleet.io crp-with-status-reporting -n my-app
```

The output contains the same status information as the `ClusterResourcePlacement` but is accessible to users with only namespace-level permissions.

For more information, see the [documentation on how to understand the placement result][fleet-status].

:::zone-end

## Placement change triggers

The Fleet Manager scheduler prioritizes stability of existing resource placements which can limit the number of changes that cause a resource to be removed and rescheduled.

The following scenarios can trigger placement changes:

* Placement policy changes in the resource placement (`ClusterResourcePlacement` or `ResourcePlacement`) can trigger removal and rescheduling of a resource.
    * Scale out operations (increasing `numberOfClusters` with no other changes) places workloads only on new clusters and doesn't affect existing placements.
* Member cluster changes, including:
    * A new member cluster becoming eligible and meets the placement policy, for example, a `PickAll` policy.
    * A member cluster is removed from the fleet. Depending on the policy, the scheduler attempts to place all affected resources on remaining clusters without affecting existing placements.

Updating the selected resources (i.e. modifying a `Deployment`) or updating the `resourceSelector` in a resource placement causes Fleet Manager to gradually roll out existing placements but **doesn't** trigger rescheduling (i.e. changing picked clusters) of the resource.

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
| **Typical Use Cases** | AI/ML Jobs, individual workloads, specific ConfigMaps/Secrets that need independent placement decisions | Application bundles, entire namespaces, cluster-wide policies |
| **Team Ownership** | Can be managed by namespace owners/developers | Typically managed by platform operators |

Both `ResourcePlacement` and `ClusterResourcePlacement` share the same core capabilities for all other aspects not listed in the differences table.

### Example scenario using ResourcePlacement and ClusterResourcePlacement

`ResourcePlacement` is designed to work in coordination with `ClusterResourcePlacement` (CRP) to provide a complete multi-cluster resource management solution. Understanding this relationship is crucial for effective fleet management.

> [!IMPORTANT]
> `ResourcePlacement` can only place namespace-scoped resources to clusters that already have the target namespace. We recommend using `ClusterResourcePlacement` for namespace establishment.

**Typical workflow**:

1. **Platform Admins**: Use `ClusterResourcePlacement` to deploy namespaces across the fleet.
2. **Application Teams**: Use `ResourcePlacement` to manage specific resources within those established namespaces.

The following examples show how to coordinate CRP and RP:

> [!NOTE]
> The following examples use the `placement.kubernetes-fleet.io/v1beta1` API version. The `selectionScope: NamespaceOnly` field is a preview feature available in v1beta1 and isn't available in the v1 API.

**Platform Admin**: Create the namespace using `ClusterResourcePlacement`:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
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

**Application Team**: manage specific resources within the namespace using `ResourcePlacement`:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
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

When using `ResourcePlacement` with `ClusterResourcePlacement`, follow these best practices:

- **Establish namespaces first**: Always ensure namespaces are deployed via CRP before creating `ResourcePlacement` objects.
- **Monitor dependencies**: Use Fleet monitoring to ensure namespace-level CRPs are healthy before deploying dependent RPs.
- **Coordinate policies**: Align CRP and RP placement policies to avoid conflicts (for example, if CRP places namespace on clusters A, B, C, RP can target any subset of those clusters).
- **Team boundaries**: Use CRP for platform-managed resources (namespaces, RBAC) and RP for application-managed resources (app configs, secrets).

This coordinated approach ensures that `ResourcePlacement` provides the flexibility teams need while maintaining the foundational infrastructure managed by platform operators.

### Resource selection, placement, and rollout

`ResourcePlacement` uses the same placement patterns as `ClusterResourcePlacement`:

- **[Placement policy](#placement-policy)**: `PickAll`, `PickFixed`, and `PickN` policies work identically for both APIs.
- **[Rollout strategy](#configuring-rollout-strategy)**: Control how updates propagate across clusters with the same rolling update mechanisms.
- **[Status and observability](./howto-understand-placement.md)**: Monitor deployment progress using `kubectl describe resourceplacement <name> -n <namespace>`.
- **[Advanced features](./concepts-resource-placement.md)**: Use tolerations, resource overrides, topology spread constraints, and affinity rules.

The key difference is in **resource selection** scope. While `ClusterResourcePlacement` typically selects entire namespaces and their contents, `ResourcePlacement` provides fine-grained control over individual namespace-scoped resources.

:::zone-end

## Next steps

* [Use cluster resource placement to deploy workloads across multiple clusters](./quickstart-resource-propagation.md).
* [Using ResourcePlacement to deploy namespace-scoped resources](./concepts-namespace-scoped-resource-propagation.md).
* [Intelligent cross-cluster Kubernetes resource placement based on member clusters properties](./intelligent-resource-placement.md).
* [Controlling eviction and disruption for cluster resource placement](./concepts-eviction-disruption.md).
* [Defining a rollout strategy for a cluster resource placement](./concepts-rollout-strategy.md).
* [Cluster resource placement FAQs](./faq.md#cluster-resource-placement-faqs).

<!-- LINKS - internal -->
[envelope-object]: ./quickstart-envelope-reserved-resources.md
[fleet-rollout]: ./concepts-rollout-strategy.md
[fleet-tolerations]: ./use-taints-tolerations.md
[fleet-status]: ./howto-understand-placement.md

<!-- LINKS - external -->
[kubefleet-props]: https://kubefleet.dev/docs/how-tos/property-based-scheduling/
[crp-topo]: https://kubefleet.dev/docs/how-tos/topology-spread-constraints/
[vm-sku-name]: /azure/virtual-machines/vm-naming-conventions
