---
title: "Defining a rollout strategy for Azure Kubernetes Fleet Manager resource placement"
description: This article describes how to define a rollout strategy for Fleet Manager's cluster resource placement and resource placement.
ms.date: 12/29/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: "As a cloud operations engineer, I want to define a customized rollout strategy for managing resource placements in Fleet Manager, so that I can minimize service interruptions and optimize resource deployment across multiple clusters."
---

# Defining a rollout strategy for Azure Kubernetes Fleet Manager resource placement

During the lifetime of a resource placement (cluster-scoped `ClusterResourcePlacement` or namespace-scoped `ResourcePlacement`), changes might be made which can result in one of the following scenarios:

* New workloads might need to be placed on all picked clusters
* Workloads already placed on a picked cluster might get updated or deleted
* Some clusters picked previously are now unpicked, and workloads must be removed from such clusters
* Some clusters are newly picked, and workloads must be added to them.

Most scenarios can lead to service interruptions as workloads running on member clusters might temporarily become unavailable as Fleet Manager dispatches updated resources. Clusters that are no longer selected lose all placed resources, resulting in lost traffic. If too many new clusters are selected and Fleet Manager places resources on them simultaneously, clusters might become overloaded. The exact interruption pattern might vary depending on the resources placed.

To minimize interruption, Fleet Manager's resource placement APIs allow users to configure a rollout strategy, similar to native Kubernetes deployment, to transition between changes as smoothly as possible.

In this article, we cover the rollout strategy options available for both `ClusterResourcePlacement` and `ResourcePlacement`.

> [!NOTE]
> If you aren't already familiar with Fleet Manager's resource placement concepts, read the [conceptual overview of resource placement][learn-conceptual-crp] before reading this article.

## Default behavior with no explicit strategy

Both `ClusterResourcePlacement` and `ResourcePlacement` don't require you to define a rollout strategy. If you don't specify one, the default behavior is to use a `RollingUpdate` strategy with a `maxSurge` of 25%, `maxUnavailable` of 25%, and `unavailablePeriodSeconds` of 10 seconds.

## Rolling update strategy

An explicit rolling update strategy can be used by adding a `strategy` specification to a `ClusterResourcePlacement` or `ResourcePlacement` as shown. You can define parameters, which control how disruptive the Fleet Manager resource placement is.

### ClusterResourcePlacement example

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: crp-example
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: test-namespace
      version: v1
  policy:
    placementType: PickN
    numberOfClusters: 2
    affinity:
      clusterAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          clusterSelectorTerms:
            - labelSelector:
                matchLabels:
                  fleet.azure.com/location: westus
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 50%
```

### ResourcePlacement example

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ResourcePlacement
metadata:
  name: rp-example
  namespace: test-namespace
spec:
  resourceSelectors:
    - group: "apps"
      kind: Deployment
      name: my-app
      version: v1
  policy:
    placementType: PickN
    numberOfClusters: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 50%
```

### Configuration parameters

Rolling update strategies can be configured with the following parameters:

* **maxUnavailable:** considers a cluster as unavailable if resources aren't successfully applied to the cluster and makes sure that at any time, there are **at least** (N - `maxUnavailable`) number of clusters available. You can set as an absolute number or a percentage. The default is 25% and zero shouldn't be used. Setting this parameter to a lower value results in less interruption during a change but lead to slower rollouts. 

* **maxSurge:** ensures that at any time, there are **at most** (N + `maxSurge`) number of clusters available. You can set as an absolute number or a percentage. The default is 25% and zero shouldn't be used. Setting this parameter to a lower value results in fewer resource placements on more clusters by Fleet Manager, which slows down the rollout process.

* **unavailablePeriodSeconds** allows you to define a time period before resources should be assessed as "ready". The default value is 60 seconds. Fleet Manager only considers newly applied resources on a cluster as "ready" `unavailablePeriodSeconds` seconds after the resources are successfully applied to that cluster. Setting a lower value for this parameter results in faster rollouts. However, we strongly recommend that users set a value that allows the initialization/preparation tasks to be completed.

### How cluster count is determined

Fleet Manager uses the placement type to determine the baseline number of clusters (`N`) to use when calculating `maxUnavailable` or `maxSurge`:

  * **PickFixed**: the number of `clusterNames` specified
  * **PickAll**: the number of clusters picked
  * **PickN**: the `numberOfClusters` value.

If you use a percentage for the parameter, Fleet Manager calculates it against `N` as well.

## Staged update strategy (preview)

The staged update strategy provides fine-grained control over resource rollouts by organizing clusters into sequential stages with configurable progression rules. Unlike the rolling update strategy, staged updates are defined externally using separate custom resources that work together to orchestrate deployments.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

### How staged updates work

Staged updates use different custom resources depending on scope:

**For cluster-scoped placements:**
* **ClusterResourcePlacement** - Configured with `strategy.type: External` to indicate external strategy management
* **ClusterStagedUpdateStrategy** - Defines the stages, cluster selection, and progression rules
* **ClusterStagedUpdateRun** - Executes the clusterStagedUpdateStrategy against a specific `ClusterResourcePlacement` and cluster resource snapshot

**For namespace-scoped placements:**
* **ResourcePlacement** - Configured with `strategy.type: External` to indicate external strategy management
* **StagedUpdateStrategy** - Defines the stages, cluster selection, and progression rules (namespace-scoped)
* **StagedUpdateRun** - Executes the stagedUpdateStrategy against a specific `ResourcePlacement` and resource snapshot (namespace-scoped)

#### ClusterResourcePlacement with external strategy

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterResourcePlacement
metadata:
  name: my-app-placement
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      name: my-app
      version: v1
  policy:
    placementType: PickAll
  strategy:
    type: External  # Rollout is controlled by ClusterStagedUpdateRun, ClusterStagedUpdateStrategy.
```

#### ResourcePlacement with external strategy

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ResourcePlacement
metadata:
  name: my-app-placement
  namespace: my-app
spec:
  resourceSelectors:
    - group: "apps"
      kind: Deployment
      name: my-deployment
      version: v1
  policy:
    placementType: PickAll
  strategy:
    type: External  # Rollout is controlled by StagedUpdateRun, StagedUpdateStrategy.
```

#### ClusterStagedUpdateStrategy (cluster-scoped)

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterStagedUpdateStrategy
metadata:
  name: three-stage-strategy
spec:
  stages:
    - name: staging
      labelSelector:
        matchLabels:
          environment: staging
      afterStageTasks:
        - type: TimedWait
          waitTime: 1h
    - name: canary
      labelSelector:
        matchLabels:
          environment: canary
      sortingLabelKey: name
      afterStageTasks:
        - type: Approval
    - name: production
      labelSelector:
        matchLabels:
          environment: production
      sortingLabelKey: order
      beforeStageTasks:
        - type: Approval
```

#### StagedUpdateStrategy (namespace-scoped)

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: StagedUpdateStrategy
metadata:
  name: three-stage-strategy
  namespace: my-app
spec:
  stages:
    - name: staging
      labelSelector:
        matchLabels:
          environment: staging
      afterStageTasks:
        - type: TimedWait
          waitTime: 1h
      maxConcurrency: 50%  # Update 50% of production clusters at once
    - name: canary
      labelSelector:
        matchLabels:
          environment: canary
      sortingLabelKey: name
      afterStageTasks:
        - type: Approval
      maxConcurrency: 2  # Update 2 clusters concurrently
    - name: production
      labelSelector:
        matchLabels:
          environment: production
      sortingLabelKey: order
      beforeStageTasks:
        - type: Approval
      maxConcurrency: 1  # Sequential updates (default)
```

### Stage configuration

Each stage in the strategy can specify:

* **Label selector** to determine which clusters belong to the stage
* **Sorting order** for clusters within the stage using `sortingLabelKey` (optional - clusters are sorted alphabetically by name if not specified)
* **Before-stage tasks** approval requirement (optional, up to 1 task per stage)
* **After-stage tasks** either timed wait or approval requirement (optional, up to 2 tasks per stage, maximum one of each type)
* **Max concurrency** to determine the maximum number of clusters to update concurrently within the stage (optional) 

#### ClusterStagedUpdateRun (cluster-scoped)

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterStagedUpdateRun
metadata:
  name: my-app-rollout
spec:
  placementName: my-app-placement # ClusterResourcePlacement name the update run is applied to.
  resourceSnapshotIndex: "0" # ClusterResourceSnapshot index of the selected resources to be updated across clusters (optional). If not stated, will use latest resource snapshot.
  stagedRolloutStrategyName: three-stage-strategy # The name of the update strategy to use.
  state: Run # Controls the execution state of the update run.
```

#### StagedUpdateRun (namespace-scoped)

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: StagedUpdateRun
metadata:
  name: my-app-rollout
  namespace: my-app
spec:
  placementName: my-app-placement # ResourcePlacement name the update run is applied to.
  resourceSnapshotIndex: "0" # ResourceSnapshot index of the selected resources to be updated across clusters (optional). If not stated, will use latest resource snapshot.
  stagedRolloutStrategyName: three-stage-strategy # The name of the update strategy to use.
  state: Run # Controls the execution state of the update run. 
```

### Stage progression

Fleet Manager processes stages sequentially:

1. Any configured before-stage tasks execute
2. All clusters in a stage receive updates according to their sort order
3. After all clusters in a stage are successfully updated, any configured after-stage tasks execute
4. The next stage begins only after all previous after stage tasks complete

For approval-based progression, Fleet Manager creates a `ClusterApprovalRequest` (for cluster-scoped placements) or `ApprovalRequest` (for namespace-scoped placements) resource that must be approved before continuing to the next stage.

### Example deployment pattern

The following diagram illustrates a typical three-stage deployment pattern:

:::image type="content" source="./media/concepts-resource-placement/conceptual-rollout-staged-update-strategy.png" alt-text="Three-stage deployment pattern with staging, canary, and production stages with wait times and approval gates." lightbox="./media/concepts-resource-placement/conceptual-rollout-staged-update-strategy.png":::

This pattern allows you to:

* Deploy to staging clusters first for initial validation
* Wait a specified time before proceeding to canary clusters
* Require manual approval before rolling out to production
* Control the order of updates within canary and production stages

### When to use staged updates

Staged update strategies are ideal when you need:

* **Environment-based rollouts** (dev → staging → production)
* **Validation Delays** and **Approval gates** between stages
* **Deterministic ordering** of cluster updates within stages
* **Reusable deployment patterns** across multiple resource placements

For simpler scenarios where percentage-based rollouts suffice, consider using the inline rolling update strategy instead.

> [!NOTE]
> The staged update strategy works identically for both `ClusterResourcePlacement` and `ResourcePlacement`, with the only difference being the scope of the custom resources (cluster-scoped vs namespace-scoped).

> [!TIP]
> To learn how to implement staged update runs step-by-step, see [How to use ClusterStagedUpdateRun to orchestrate staged rollouts](./howto-staged-update-run.md).

## Next steps

* [How to use ClusterStagedUpdateRun to orchestrate staged rollouts](./howto-staged-update-run.md).
* [Controlling eviction and disruption for cluster resource placement](./concepts-eviction-disruption.md).
* [Use cluster resource placement to deploy workloads across multiple clusters](./quickstart-resource-propagation.md).
* [Intelligent cross-cluster Kubernetes resource placement based on member clusters properties](./intelligent-resource-placement.md).

<!-- LINKS - external -->
[learn-conceptual-crp]: ./concepts-resource-propagation.md
