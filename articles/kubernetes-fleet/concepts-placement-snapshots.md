---
title: "Understanding snapshots for Azure Kubernetes Fleet Manager resource placement"
description: This article describes how Fleet Manager's cluster resource placement and resource placement manage snapshots.
ms.date: 12/04/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: As a Kubernetes administrator, I want to manage and view snapshots of resource placements, so that I can maintain an efficient scheduling history and implement rollback mechanisms during updates.
---

# Understanding snapshots for Azure Kubernetes Fleet Manager resource placement

Fleet Manager keeps a history of the 10 most recently used placement scheduling policies, along with resource versions the placement selected. These policy and resource versions are held as snapshot objects:

- For **ClusterResourcePlacement** (CRP): `ClusterSchedulingPolicySnapshot` and `ClusterResourceSnapshot` (cluster-scoped)
- For **ResourcePlacement** (RP): `SchedulingPolicySnapshot` and `ResourceSnapshot` (namespace-scoped)

In this article, we explore these objects so you can understand them should you wish to work with them.

> [!NOTE]
> If you aren't already familiar with Fleet Manager's resource placement:
> - For cluster-scoped resources, read the [conceptual overview of ClusterResourcePlacement (CRP)][learn-conceptual-crp].
> - For namespace-scoped resources, read the [conceptual overview of ResourcePlacement (RP)][learn-conceptual-rp].

## How resource snapshots are created

Any change to resources covered by the scope of CRP or RP resource selector will automatically trigger the creation of a new resource snapshot within 60 seconds.

## Viewing resource snapshots

You can view the resource snapshots held by Fleet Manager using the following steps when connected to the [Fleet Manager hub cluster][fleet-hub-cluster].

### Viewing ClusterResourceSnapshot (for ClusterResourcePlacement)

For cluster-scoped placements using `ClusterResourcePlacement`, view `ClusterResourceSnapshot` objects.

In this sample, we use an updated ConfigMap, leading to two snapshots.

```bash
kubectl get clusterresourcesnapshots --show-labels
```

We see two snapshots, with the most recent one marked as the latest (`kubernetes-fleet.io/is-latest-snapshot=true`), with a resource-index of 1 (`kubernetes-fleet.io/resource-index=1`).

```output
NAME                           GEN   AGE    LABELS
example-placement-0-snapshot   1     17m    kubernetes-fleet.io/is-latest-snapshot=false,kubernetes-fleet.io/parent-CRP=example-placement,kubernetes-fleet.io/resource-index=0
example-placement-1-snapshot   1     2m2s   kubernetes-fleet.io/is-latest-snapshot=true,kubernetes-fleet.io/parent-CRP=example-placement,kubernetes-fleet.io/resource-index=1
```

We can inspect the contents of the `example-placement-1-snapshot` object as follows.

```bash
kubectl get clusterresourcesnapshots example-placement-1-snapshot -o yaml
```

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourceSnapshot
metadata:
  ...
  labels:
    kubernetes-fleet.io/is-latest-snapshot: "true"
    kubernetes-fleet.io/parent-CRP: example-placement
    kubernetes-fleet.io/resource-index: "1"
  name: example-placement-1-snapshot
  ...
spec:
  selectedResources:
  - apiVersion: v1
    kind: Namespace
    metadata:
      labels:
        kubernetes.io/metadata.name: test-namespace
      name: test-namespace
    spec:
      finalizers:
      - kubernetes
  - apiVersion: v1
    data:
      key: value2
    kind: ConfigMap
    metadata:
      name: test-cm
      namespace: test-namespace
```

### Viewing ResourceSnapshot (for ResourcePlacement)

For namespace-scoped placements using `ResourcePlacement`, view `ResourceSnapshot` objects within the namespace.

> [!NOTE]
> `ResourcePlacement` uses the `placement.kubernetes-fleet.io/v1beta1` API version and is currently in preview.

In this sample, we have a `ResourcePlacement` in the `my-app` namespace with updated ConfigMaps, leading to two snapshots.

```bash
kubectl get resourcesnapshots -n my-app --show-labels
```

We see two snapshots, with the most recent one marked as the latest (`kubernetes-fleet.io/is-latest-snapshot=true`), with a resource-index of 1 (`kubernetes-fleet.io/resource-index=1`).

```output
NAME                               GEN   AGE    LABELS
app-configs-rp-0-snapshot          1     15m    kubernetes-fleet.io/is-latest-snapshot=false,kubernetes-fleet.io/parent-CRP=app-configs-rp,kubernetes-fleet.io/resource-index=0
app-configs-rp-1-snapshot          1     1m3s   kubernetes-fleet.io/is-latest-snapshot=true,kubernetes-fleet.io/parent-CRP=app-configs-rp,kubernetes-fleet.io/resource-index=1
```

We can inspect the contents of the `app-configs-rp-1-snapshot` object as follows.

```bash
kubectl get resourcesnapshots app-configs-rp-1-snapshot -n my-app -o yaml
```

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ResourceSnapshot
metadata:
  ...
  labels:
    kubernetes-fleet.io/is-latest-snapshot: "true"
    kubernetes-fleet.io/parent-CRP: app-configs-rp
    kubernetes-fleet.io/resource-index: "1"
  name: app-configs-rp-1-snapshot
  namespace: my-app
  ...
spec:
  selectedResources:
  - apiVersion: v1
    data:
      config: updated-value
    kind: ConfigMap
    metadata:
      name: app-config
      namespace: my-app
      labels:
        app: my-application
```

## Using resource snapshots

Snapshots can be used as part of staged rollouts managed via update runs as a rollback mechanism. Both `ClusterResourcePlacement` and `ResourcePlacement` support staged rollouts with their respective snapshot types:

- For `ClusterResourcePlacement`: Uses `ClusterResourceSnapshot` objects with `ClusterStagedUpdateRun`
- For `ResourcePlacement`: Uses `ResourceSnapshot` objects with `StagedUpdateRun`

See [Staged rollout strategy][crp-staged-rollouts] for details on how to implement staged rollouts for both resource placement types.

## Modifying the snapshot history limit

To change the number of items held in history, add a `revisionHistoryLimit` field to your placement and provide an integer value. The default value is 10.

### For ClusterResourcePlacement

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: crp-example
spec:
  revisionHistoryLimit: 20   # keep 20 items in history
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

### For ResourcePlacement

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ResourcePlacement
metadata:
  name: rp-example
  namespace: my-app
spec:
  revisionHistoryLimit: 20   # keep 20 items in history
  resourceSelectors:
    - group: ""
      kind: ConfigMap
      version: v1
      labelSelector:
        matchLabels:
          app: my-application
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

## Next steps

* [Define a rollout strategy for a cluster resource placement](./concepts-rollout-strategy.md).
* [Control eviction and disruption for cluster resource placement](./concepts-eviction-disruption.md).
* [Use cluster resource placement to deploy workloads across multiple clusters](./quickstart-resource-propagation.md).
* [Use resource placement to deploy namespace-scoped resources across multiple clusters](./quickstart-namespace-scoped-resource-propagation.md).
* [Intelligent cross-cluster Kubernetes resource placement based on member clusters properties](./intelligent-resource-placement.md).

<!-- LINKS - external -->
[learn-conceptual-crp]: ./concepts-resource-propagation.md
[learn-conceptual-rp]: ./concepts-namespace-scoped-resource-propagation.md
[fleet-hub-cluster]: ./access-fleet-hub-cluster-kubernetes-api.md
[crp-staged-rollouts]: ./concepts-rollout-strategy.md#staged-update-strategy-preview