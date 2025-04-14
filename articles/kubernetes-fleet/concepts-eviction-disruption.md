---
title: "Controlling eviction and disruption budgets for Azure Kubernetes Fleet Manager cluster resource placement"
description: This article describes how to manage evictions and voluntary disruption for workloads placed by Fleet Manager's cluster resource placement.
ms.date: 03/12/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: conceptual
---

# Controlling eviction and disruption budgets for Azure Kubernetes Fleet Manager cluster resource placement (preview)

Administrators using Fleet Manager's cluster resource placement (CRP) can find they need to remove resources previously placed on member clusters, while ensuring that key resource placements aren't disrupted.

In this article, we explore how you can use Fleet Manager's `ClusterResourcePlacementEviction` and `ClusterResourcePlacementDisruptionBudget` objects to achieve these goals. 

> [!NOTE]
> If you aren't already familiar with Fleet Manager's cluster resource placement (CRP), read the [conceptual overview of resource placement][learn-conceptual-crp] before reading this article.

[!INCLUDE [preview features note](./includes/preview/preview-callout-dpbeta.md)]

## Evicting placed resources (preview)

A `ClusterResourcePlacementEviction` object is used to remove resources from a member cluster once the resources are propagated from the Fleet Manager hub cluster.

To successfully evict resources from a cluster, you need to specify:

* The name of the `ClusterResourcePlacement` object which propagated resources to the target cluster.
* The name of the target cluster from which we need to evict resources.

Eviction can be used with cluster resource placement's `PickAll` and `PickN` policies. `PickedFixed` isn't supported as you can edit the target clusters and reapply the CRP.

> [!NOTE]
> Eviction doesn't guarantee that resources aren't propagated to a member cluster again by the Fleet scheduler. You need to apply [taints][fleet-taints] to prevent the Fleet scheduler from picking a specific cluster again.

Consider the following sample CRP.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterResourcePlacement
metadata:
  name: crp-app-sample
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
```

After applying this CRP, we can [inspect the placement status][placement-status] to determine which clusters the resources are deployed to.

Let's say the placement picked two clusters named `member-cluster-01` and `member-cluster-02`, and we determine we didn't want the resources deployed on `member-cluster-02` and wish to remove it.

1. Create a `NoSchedule` taint to block placement requests for the member cluster. You can read more about using taints on the [taints documentation][fleet-taints].

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1beta1
    kind: MemberCluster
    metadata:
      name: member-cluster-02
    spec:
      identity:
        name: fleet-member-agent-cluster-2
        kind: ServiceAccount
        namespace: fleet-system
        apiGroup: ""
      taints:                   
        - key: any-key
          value: any-value
          effect: NoSchedule
    ```

1. Next, create, and apply a `ClusterResourcePlacementEviction`.

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1beta1
    kind: ClusterResourcePlacementEviction
    metadata:
      name: eviction-sample
    spec:
      placementName: crp-app-sample
      clusterName: member-cluster-02
    ```

1. Check the specified resources are removed from `member-cluster-02` cluster:

    ```bash
    kubectl get crpe eviction-sample
    ```
    
    Which results in the following output, with `EXECUTED` showing `True`.
    
    ```output
    NAME            VALID   EXECUTED
    test-eviction   True    True 
    ```
    
Now you understand how to force the removal of placed resources from clusters, let's see how you can protect key resources from eviction.

## Protect against eviction (preview)

The `ClusterResourcePlacementDisruptionBudget` object protects against voluntary disruptions which occur when a `ClusterResourcePlacementEviction` object is applied against a placed resource. [Involuntary disruptions](#involuntary-disruption) aren't protected against.

For the sample cluster resource placement shown earlier in this article, you can define a placement disruption budget object as follows.

The name of the disruption budget must match the CRP.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterResourcePlacementDisruptionBudget
metadata:
  name: crp-app-sample
spec:
  minAvailable: 1
```

You can specify one of the following two mutually exclusive fields in the spec:

- **maxUnavailable:**  the maximum number of clusters in which a placement can be unavailable due to any form of disruptions.
- **minAvailable:** the minimum number of clusters in which placements are available despite any form of disruptions.

Both fields can be either an absolute number of clusters as an integer or as a percentage of the total number of clusters in the fleet.

When specifying a disruption budget for a particular `ClusterResourcePlacement` policy, you can refer to the following support matrix:

| CRP policy   | `minAvailable` (integer) | `minAvailable` (%) | `maxUnavailable` (integer) | `MaxUnavailable` (%) |
|--------------|--------------------------|--------------------|----------------------------|----------------------|
| `PickFixed`  | ❌                       | ❌                | ❌                         | ❌                  |
| `PickAll`    | ✅                       | ❌                | ❌                         | ❌                  |
| `PickN`      | ✅                       | ✅                | ✅                         | ✅                  |

> [!NOTE]
> If you create an invalid disruption budget object for a placement, any eviction attempts fail.

### Validate that eviction is blocked

You can check that a configured disruption budget blocked an eviction as follows. 

```bash
kubectl get crpe eviction-sample
```

Notice the `EXECUTED` field displays `False`, indicating the eviction wasn't applied.

```output
NAME            VALID   EXECUTED
test-eviction   True    False
```

To confirm the disruption budget blocked the eviction, issue the same `kubectl` command and add `-o yaml`. The `message` value shows the disruption budget blocked the eviction.

```yaml
status:
  conditions:
  - lastTransitionTime: "2025-01-21T15:52:29Z"
    message: Eviction is valid
    observedGeneration: 1
    reason: ClusterResourcePlacementEvictionValid
    status: "True"
    type: Valid
  - lastTransitionTime: "2025-01-21T15:52:29Z"
    message: 'Eviction is blocked by specified ClusterResourcePlacementDisruptionBudget,
      availablePlacements: 1, totalPlacements: 1'
    observedGeneration: 1
    reason: ClusterResourcePlacementEvictionNotExecuted
    status: "False"
    type: Executed
```

### Involuntary disruption

Placement disruption budgets **do not protect against involuntary disruption**. Examples of involuntary disruption include: 

* Removal of resources from a member cluster by the Fleet Manager scheduler due to scheduling policy changes.
* Manual deletion of workload resources running on a member cluster (not via eviction or updated CRP).
* Manual deletion of a `ClusterResourceBinding` object which is an internal resource representing the placement of resources on a member cluster.
* Workloads failing to run properly on a member cluster due to misconfiguration or cluster related issues.

## Next steps

* [Use cluster resource placement to deploy workloads across multiple clusters](./quickstart-resource-propagation.md).
* [Intelligent cross-cluster Kubernetes resource placement based on member clusters properties](./intelligent-resource-placement.md)

<!-- LINKS - external -->
[learn-conceptual-crp]: ./concepts-resource-propagation.md
[fleet-taints]: ./use-taints-tolerations.md
[placement-status]: ./quickstart-resource-propagation.md#use-clusterresourceplacement-to-place-resources-onto-member-clusters
