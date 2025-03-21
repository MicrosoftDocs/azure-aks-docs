---
title: "Understanding snapshots for Azure Kubernetes Fleet Manager cluster resource placement"
description: This article describes how to Fleet Manager's cluster resource placement manages snapshots.
ms.date: 03/20/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: conceptual
---

# Understanding snapshots for Azure Kubernetes Fleet Manager cluster resource placement

Fleet Manager keeps a history of the 10 most recently used placement scheduling policies, along with resource versions the placement selected. These policy and resource versions are held as `ClusterSchedulingPolicySnapshot` and `ClusterResourceSnapshot` objects respectively.

In this article, we explore these objects so you can understand them should you wish to work with them.

> [!NOTE]
> If you aren't already familiar with Fleet Manager's cluster resource placement (CRP), read the [conceptual overview of resource placement][learn-conceptual-crp] before reading this article.

## Viewing resource snapshots

You can view the resource snapshots held by Fleet Manager using the following steps when connected to the [Fleet Manager hub cluster][fleet-hub-cluster].

For this sample we use a ConfigMap resource that we have modified, leading to two snapshots.

```bash
kubectl get clusterresourcesnapshots --show-labels
```

We see two snapshots, with the most recent one marked as the latest (`kubernetes-fleet.io/is-latest-snapshot=true`), with a resource-index of 1 (`kubernetes-fleet.io/resource-index=1`).

```output
NAME                           GEN   AGE    LABELS
example-placement-0-snapshot   1     17m    kubernetes-fleet.io/is-latest-snapshot=false,kubernetes-fleet.io/parent-CRP=example-placement,kubernetes-fleet.io/resource-index=0
example-placement-1-snapshot   1     2m2s   kubernetes-fleet.io/is-latest-snapshot=true,kubernetes-fleet.io/parent-CRP=example-placement,kubernetes-fleet.io/resource-index=1
```

We can inspect the contents of the `example-placement-1-snapshot` snapshot as follows.

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

## Using resource snapshots

Snapshots can be used as part of [CRP staged rollouts][crp-staged-rollouts] managed via update runs as a rollback mechanism

## Modifying the snapshot history limit

To change the number of items held in history, add a `revisionHistoryLimit` field to your CRP and provide an integer value. The default value is 10.

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

## Next steps

* [Defining a rollout strategy for a cluster resource placement](./concepts-rollout-strategy.md).
* [Controlling eviction and disruption for cluster resource placement](./concepts-eviction-disruption.md).
* [Use cluster resource placement to deploy workloads across multiple clusters](./quickstart-resource-propagation.md).
* [Intelligent cross-cluster Kubernetes resource placement based on member clusters properties](./intelligent-resource-placement.md).

<!-- LINKS - external -->
[learn-conceptual-crp]: ./concepts-resource-propagation.md
[fleet-hub-cluster]: ./access-fleet-hub-cluster-kubernetes-api.md
[crp-staged-rollouts]: ./concepts-rollout-strategy.md#staged-update-strategy-preview