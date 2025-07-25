---
title: "Defining a rollout strategy for Azure Kubernetes Fleet Manager cluster resource placement"
description: This article describes how to define a rollout strategy for Fleet Manager's cluster resource placement.
ms.date: 06/10/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: "As a cloud operations engineer, I want to define a customized rollout strategy for managing cluster resource placements in Fleet Manager, so that I can minimize service interruptions and optimize resource deployment across multiple clusters."
---

# Defining a rollout strategy for Azure Kubernetes Fleet Manager cluster resource placement

During the lifetime of a cluster resource placement (CRP), changes may be made to the CRP which can result in one of the following scenarios:

* New workloads may need to be placed on all picked clusters
* Workloads already placed on a picked cluster may get updated or deleted
* Some clusters picked previously are now unpicked, and workloads must be removed from such clusters
* Some clusters are newly picked, and workloads must be added to them.

Most scenarios can lead to service interruptions as workloads running on member clusters may temporarily become unavailable as Fleet Manager dispatches updated resources. Clusters that are no longer selected lose all placed resources, resulting in lost traffic. If too many new clusters are selected and Fleet Manager places resources on them simultaneously, clusters may become overloaded. The exact interruption pattern may vary depending on the resources placed.

To minimize interruption, Fleet Manager's cluster resource placement allows users to configure a rollout strategy, similar to native Kubernetes deployment, to transition between changes as smoothly as possible. 

In this article, we cover the rollout strategy options available for cluster resource placement.

> [!NOTE]
> If you aren't already familiar with Fleet Manager's cluster resource placement (CRP), read the [conceptual overview of resource placement][learn-conceptual-crp] before reading this article.

## Default behavior with no explicit strategy

Cluster resource placements don't require you to define a rollout strategy. If you don't specify one, the default behavior is to use a `RollingUpdate` strategy with a `maxSurge` of 25%, `maxUnavailable` of 25%, and `unavailablePeriodSeconds` of 10 seconds.

## Rolling update strategy

An explicit rolling update strategy can be used by adding a `strategy` specification to a CRP as shown. You can define parameters which control how disruptive the Fleet Manager resource placement is. 

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

Rolling update strategies can be configured with the following parameters:

* **maxUnavailable:** considers a cluster as unavailable if resources haven't been successfully applied to the cluster and makes sure that at any time, there are **at least** (N - `maxUnavailable`) number of clusters available. You can set as an absolute number or a percentage. The default is 25% and zero shouldn't be used. Setting this parameter to a lower value results in less interruption during a change but lead to slower rollouts. 

* **maxSurge:** ensures that at any time, there are **at most** (N + `maxSurge`) number of clusters available. You can set as an absolute number or a percentage. The default is 25% and zero shouldn't be used. Setting this parameter to a lower value results in fewer resource placements on more clusters by Fleet Manager, which slows down the rollout process.

* **unavailablePeriodSeconds** allows you to define a time period before resources should be assessed as "ready". The default value is 60 seconds. Fleet Manager only considers newly applied resources on a cluster as "ready" `unavailablePeriodSeconds` seconds after the resources are successfully applied to that cluster. Setting a lower value for this parameter results in faster rollouts. However, we strongly recommend that users set a value that allows the initialization/preparation tasks to be completed.

### How cluster count is determined

Fleet Manager uses the placement type to determine the baseline number of clusters (`N`) to use when calculating `maxUnavailable` or `maxSurge`:

  * **PickFixed**: the number of `clusterNames` specified
  * **PickAll**: the number of clusters picked
  * **PickN**: the `numberOfClusters` value.

If you use a percentage for the parameter, it's calculated against `N` as well.

## Staged update strategy (preview)

The staged update strategy provides fine-grained control over resource rollouts by organizing clusters into sequential stages with configurable progression rules. Unlike the rolling update strategy, staged updates are defined externally using separate custom resources that work together to orchestrate deployments.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

### How staged updates work

Staged updates use three custom resources:

* **ClusterResourcePlacement** - Configured with `strategy.type: External` to indicate external strategy management
* **ClusterStagedUpdateStrategy** - Defines the stages, cluster selection, and progression rules
* **ClusterStagedUpdateRun** - Executes the clusterStagedUpdateStrategy against a specific CRP and resource snapshot

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

#### ClusterStagedUpdateStrategy

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
```

Each stage in the strategy can specify:

* **Label selector** to determine which clusters belong to the stage
* **Sorting order** for clusters within the stage using `sortingLabelKey` (optional - clusters are sorted alphabetically by name if not specified)
* **After-stage tasks** either timed wait or approval requirement (optional, up to 2 tasks per stage, maximum one of each type)

#### ClusterStagedUpdateRun

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterStagedUpdateRun
metadata:
  name: my-app-rollout
spec:
  placementName: my-app-placement # ClusterResourcePlacement name the update run is applied to.
  resourceSnapshotIndex: "0" # Resource snapshot index of the selected resources to be updated across clusters.
  stagedRolloutStrategyName: three-stage-strategy # The name of the update strategy to use.
```

### Stage progression

Fleet Manager processes stages sequentially:

1. All clusters in a stage receive updates according to their sort order
2. After all clusters in a stage are successfully updated, any configured after-stage tasks execute
3. The next stage begins only after all previous after stage tasks complete

For approval-based progression, Fleet Manager creates a `ClusterApprovalRequest` resource that must be approved before continuing to the next stage.

### Example deployment pattern

The following diagram illustrates a typical three-stage deployment pattern:

:::image type="content" source="./media/concepts-resource-placement/conceptual-rollout-staged-update-strategy.png" alt-text="A placement staged update strategy containing three stages - staging, canary, and production. Each stage contains multiple clusters, with canary and production apply a sort order on cluster based on labels. There's a 1 hour wait between staging and canary, and an approval is required to transition from canary to production stages." lightbox="./media/concepts-resource-placement/conceptual-rollout-staged-update-strategy.png":::

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
* **Reusable deployment patterns** across multiple cluster resource placements

For simpler scenarios where percentage-based rollouts suffice, consider using the inline rolling update strategy instead.

> [!TIP]
> To learn how to implement staged update runs step-by-step, see [How to use ClusterStagedUpdateRun to orchestrate staged rollouts](./howto-staged-update-run.md).

## Next steps

* [How to use ClusterStagedUpdateRun to orchestrate staged rollouts](./howto-staged-update-run.md).
* [Controlling eviction and disruption for cluster resource placement](./concepts-eviction-disruption.md).
* [Use cluster resource placement to deploy workloads across multiple clusters](./quickstart-resource-propagation.md).
* [Intelligent cross-cluster Kubernetes resource placement based on member clusters properties](./intelligent-resource-placement.md).

<!-- LINKS - external -->
[learn-conceptual-crp]: ./concepts-resource-propagation.md
[placement-snapshots]: ./concepts-placement-snapshots.md
