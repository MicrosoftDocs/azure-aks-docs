---
title: "Controlling eviction and disruption budgets for Azure Kubernetes Fleet Manager cluster resource placement"
description: This article describes how to manage evictions and voluntary disruption for workloads placed by Fleet Manager's cluster resource placement.
ms.date: 10/09/2026
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: As a Kubernetes administrator, I want to manage the eviction and disruption budgets of resources in my cluster, so that I can ensure key workloads remain stable while removing unnecessary resources as needed.
---

# Controlling eviction and disruption for Azure Kubernetes Fleet Manager cluster resource placement

**Applies to:** :heavy_check_mark: Fleet Manager with hub cluster

Administrators who use Fleet Manager's cluster resource placement (CRP) might need to remove resources that they previously placed on member clusters. They also need to ensure that they don't disrupt key resource placements.

This article explains how to use Fleet Manager's `ClusterResourcePlacementEviction` and `ClusterResourcePlacementDisruptionBudget` objects to achieve these goals. 

> [!NOTE]
> If you're not already familiar with Fleet Manager's cluster resource placement (CRP), read the [conceptual overview of resource placement][learn-conceptual-crp] before reading this article.

## Evict placed resources

A `ClusterResourcePlacementEviction` object is used to remove resources from a member cluster once the resources are propagated from the Fleet Manager hub cluster.

To successfully evict resources from a cluster, you need to specify:

* The name of the `ClusterResourcePlacement` object which propagated resources to the target cluster.
* The name of the target cluster from which we need to evict resources.

Eviction can be used with cluster resource placement's `PickAll` and `PickN` policies. `PickedFixed` isn't supported as you can edit the target clusters and reapply the CRP.

> [!NOTE]
> Eviction doesn't guarantee that resources aren't propagated to a member cluster again by the Fleet scheduler. You need to apply [taints][fleet-taints] to prevent the Fleet scheduler from picking a specific cluster again.

Consider the following sample CRP.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
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
    apiVersion: placement.kubernetes-fleet.io/v1
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
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: ClusterResourcePlacementEviction
    metadata:
      name: eviction-sample
    spec:
      placementName: crp-app-sample
      clusterName: member-cluster-02
    ```

1. Check that the specified resources are removed from the `member-cluster-02` cluster:

    ```bash
    kubectl get crpe eviction-sample
    ```
    
    Which results in the following output, with `EXECUTED` showing `True`.
    
    ```output
    NAME            VALID   EXECUTED
    test-eviction   True    True 
    ```
    
Now that you understand how to force the removal of placed resources from clusters, let's see how you can protect key resources from eviction.

## Protect against eviction

The `ClusterResourcePlacementDisruptionBudget` object protects against voluntary disruptions that occur when you apply a `ClusterResourcePlacementEviction` object to a placed resource. It doesn't protect against [involuntary disruptions](#involuntary-disruption).

For the sample cluster resource placement shown earlier in this article, you can define a placement disruption budget object as follows.

The name of the disruption budget must match the CRP.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacementDisruptionBudget
metadata:
  name: crp-app-sample
spec:
  minAvailable: 1
```

Specify one of the following two mutually exclusive fields in the spec:

- **maxUnavailable:**  the maximum number of clusters in which a placement can be unavailable due to any form of disruptions.
- **minAvailable:** the minimum number of clusters in which placements are available despite any form of disruptions.

Both fields can be either an absolute number of clusters as an integer or a percentage of the total number of clusters in the fleet.

When specifying a disruption budget for a particular `ClusterResourcePlacement` policy, refer to the following support matrix:

| CRP policy   | `minAvailable` (integer) | `minAvailable` (%) | `maxUnavailable` (integer) | `MaxUnavailable` (%) |
|--------------|--------------------------|--------------------|----------------------------|----------------------|
| `PickFixed`  | ❌                       | ❌                | ❌                         | ❌                  |
| `PickAll`    | ✅                       | ❌                | ❌                         | ❌                  |
| `PickN`      | ✅                       | ✅                | ✅                         | ✅                  |

> [!NOTE]
> If you create an invalid disruption budget object for a placement, any eviction attempts fail.

### Validate that eviction is blocked

Check that a configured disruption budget blocked an eviction. 

```bash
kubectl get crpe eviction-sample
```

The `EXECUTED` field displays `False`, which means the eviction wasn't applied.

```output
NAME            VALID   EXECUTED
test-eviction   True    False
```

To confirm the disruption budget blocked the eviction, run the same `kubectl` command and add `-o yaml`. The `message` value shows the disruption budget blocked the eviction.

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

Placement disruption budgets **don't protect against involuntary disruption**. Examples of involuntary disruption include: 

* The Fleet Manager scheduler removes resources from a member cluster due to scheduling policy changes.
* You manually delete workload resources running on a member cluster (not through eviction or updated CRP).
* You manually delete a `ClusterResourceBinding` object, which is an internal resource that represents the placement of resources on a member cluster.
* Workloads don't run properly on a member cluster due to misconfiguration or cluster-related issues.

## Next steps

* [Use cluster resource placement to deploy workloads across multiple clusters](./quickstart-resource-propagation.md).
* [Intelligent cross-cluster Kubernetes resource placement based on member clusters properties](./intelligent-resource-placement.md)

<!-- LINKS - external -->
[learn-conceptual-crp]: ./concepts-resource-placement.md
[fleet-taints]: ./use-taints-tolerations.md
[placement-status]: ./howto-understand-placement.md
