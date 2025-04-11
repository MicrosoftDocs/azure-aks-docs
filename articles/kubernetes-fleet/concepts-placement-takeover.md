---
title: "Taking over existing workloads with Azure Kubernetes Fleet Manager cluster resource placement"
description: This article describes how to use the whenToTakeOver property to control how Fleet Manager handles existing workloads when placing workloads using cluster resource placement.
ms.date: 04/11/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: conceptual
---

# Taking over existing workloads with Azure Kubernetes Fleet Manager cluster resource placement (preview)

A common scenario as a multi-cluster environment matures is the presence of a specific workload on multiple clusters. These clusters can be added to a fleet to centralize management leading to workload placement conflicts when Fleet Manager's attempts to place a workload onto a cluster where it already exists. 

In this article we will look at how you can use the `whenToTakeOver` property in a CRP to explicitly control how Fleet Manager handles existing workloads when performing placements.

> [!NOTE]
> If you aren't already familiar with Fleet Manager's cluster resource placement (CRP), read the [conceptual overview of resource placement][learn-conceptual-crp] before reading this article.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## Workload take over options

As a first step you must stage the workload on your Fleet Manager [hub cluster][fleet-hub-cluster]. You then define a cluster resource placement (CRP) that specifies the takeover behavior using the `whenToTakeOver` property.

The `whenToTakeOver` property allows the following values:

* `Always`: Fleet Manager applies the corresponding resource template from the hub cluster immediately, and any value differences in managed fields will be overwritten on the target cluster. This is the default behavior for CRP without an explicit `whenToTakeOver` setting.

* `IfNoDiff`: Fleet Manager checks for configuration differences when it finds a pre-existing resource and will only apply the resource template if no configuration differences are found. 

* `Never`: Fleet Manager ignores pre-existing resources and doesn't apply the resource template. Fleet manager considers this an apply error which can be used to check for the presence of pre-existing resources without taking any action.

### Control fields used for comparison

You can use an optional `comparisonOptions` property to fine-tune how configuration differences are calculated by `whenToTakeOver`.

* `partialComparison`: only fields that are present on the resource template on the Fleet hub cluster and on the target cluster workload are used for value comparison. Missing fields on the target cluster workload are acceptable. This is the default behavior for CRP without an explicit `comparisonOptions` setting.

* `fullComparison`: all fields on the resource template on the Fleet hub cluster are considered. If any fields are missing on the target cluster workload, then it will be considered to have failed comparison.

## Check for conflicting workloads

In order to check for existing workloads for a CRP, start by adding an `applyStrategy` with a `whenToTakeOver` value of `Never` as shown in the sample.

```yml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: web-2-crp
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      version: v1 
      labelSelector:
        matchLabels:
          app: web-2
  policy:
    placementType: PickAll
  strategy:
    applyStrategy:
      whenToTakeOver: Never     
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 100%
      unavailablePeriodSeconds: 1            
```

Apply the CRP to your Fleet Manager hub cluster.

```bash
kubectl apply -f web-2-crp.yaml
```

Fleet Manager will attempt to place the workload and when it finds a matching workload on a cluster it will return a `failedPlacement` with the message:

```output
Failed to apply the manifest (error: no ownership of the object in the member cluster; takeover is needed)
```

You can determine the clusters with this issue by using the following process.

TBC

## Safely take over matching workloads

Once you have determined it is safe to proceed with the take over of certain existing workloads you can modify the existing CRP as shown.

This CRP will allow Fleet Manager to apply its resource template over the workload already present on the target cluster where there are no differences between just the hub cluster resource's managed fields and those on the existing workload.

```yml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: web-2-crp
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      version: v1 
      labelSelector:
        matchLabels:
          app: web-2
  policy:
    placementType: PickAll
  strategy:
    applyStrategy:
      whenToTakeOver: IfNoDiff
      comparisonOption: partialComparison
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 100%
      unavailablePeriodSeconds: 1            
```

Apply the CRP to your Fleet Manager hub cluster.

```bash
kubectl apply -f web-2-crp.yaml
```

Fleet Manager will attempt to place the workload, allowing overwriting on clusters that have matching fields. You can check for additional `failedPlacement` messages that will now report failure due to configuraiton differences.

```output
Failed to apply the manifest (error: cannot take over object: configuration differences are found between the manifest object and the corresponding object in the member cluster)
```

You can determine the clusters with this issue by using the following process.

TBC

## Next steps

* [Detect and manage drift for resources placed using cluster resource placement](./concepts-placement-drift.md).
* [Controlling eviction and disruption for cluster resource placement](./concepts-eviction-disruption.md).
* [Defining a rollout strategy for a cluster resource placement](./concepts-rollout-strategy.md).
* [Use cluster resource placement to deploy workloads across multiple clusters](./quickstart-resource-propagation.md).
* [Intelligent cross-cluster Kubernetes resource placement based on member clusters properties](./intelligent-resource-placement.md).

<!-- LINKS - external -->
[learn-conceptual-crp]: ./concepts-resource-propagation.md
[fleet-hub-cluster]: ./access-fleet-hub-cluster-kubernetes-api.md
