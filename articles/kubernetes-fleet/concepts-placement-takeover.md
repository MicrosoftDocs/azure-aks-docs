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

As multi-cluster environment mature the presence of a specific workload on multiple clusters is a common situation. One reason to add clusters to a fleet is to centralize management of workloads to improve visibility and manageability of workloads to ensure consistency. However, adding clusters with pre-existing workloads to a fleet can lead to placement conflicts when Fleet Manager attempts to place a managed workload onto an adopted member cluster. 

In this article, wes look at how to use the `whenToTakeOver` property of an `applyStrategy` in a cluster resource placement (CRP) to explicitly control how Fleet Manager handles existing workloads when performing placements.

> [!NOTE]
> If you aren't already familiar with Fleet Manager's cluster resource placement (CRP), read the [conceptual overview of resource placement][learn-conceptual-crp] before reading this article.

[!INCLUDE [preview features note](./includes/preview/preview-callout-dpbeta.md)]

## Workload take over options

The starting point for workload take over is to deploying the workload manifests onto your Fleet Manager [hub cluster][fleet-hub-cluster]. Once deployed you define a CRP that specifies an explicit takeover behavior using the `whenToTakeOver` property.

The `whenToTakeOver` property allows the following values:

* `Always`: Fleet Manager applies the corresponding workload from the hub cluster immediately, and any value differences in managed fields are overwritten on the target cluster. This behavior is the default for a CRP without an explicit `whenToTakeOver` setting.

* `IfNoDiff`: Fleet Manager checks for configuration differences when it finds a pre-existing workload and only applies the hub cluster workload if no configuration differences are found. 

* `Never`: Fleet Manager ignores pre-existing workloads and doesn't apply the hub cluster workload. Fleet manager still identifies matching workloads and raises an apply error, allowing you to safely check for the presence of pre-existing workloads.

### Define which fields are used for comparison

You can use an optional `comparisonOptions` property to fine-tune how `whenToTakeOver` determines configuration differences.

* `partialComparison`: only fields that are present on the hub cluster workload and on the target cluster workload are used for value comparison. Any extra unmanaged fields on the target cluster workload are ignored. This behavior is the default for a CRP without an explicit `comparisonOptions` setting.

* `fullComparison`: all fields on the workload definition on the Fleet hub cluster must be present on the selected member cluster. If the target cluster has any extra unmanaged fields, then it fails comparison.

## Check for conflicting workloads

In order to check for existing workloads for a CRP, start by adding an `applyStrategy` with a `whenToTakeOver` value of `Never` as shown in the sample.

```yml
apiVersion: placement.kubernetes-fleet.io/v1beta1
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

Fleet Manager attempts to place the workload and when it finds a matching workload on a target member cluster returns a `failedPlacement` response.

You can determine which member clusters failed placement due to a clashing workload using the following command. The [jq command](https://github.com/jqlang/jq) is used to format the output.

```bash
kubectl get clusterresourceplacement.v1beta1.placement.kubernetes-fleet.io web-2-crp -o jsonpath='{.status.placementStatuses}' \
    | jq '[.[] | select (.failedPlacements != null)] | map({clusterName, failedPlacements})'
```

Each cluster that fails placement due to an existing workload returns an entry similar to the following sample.

```json
{
    "clusterName": "member-2",
    "failedPlacements": [
        {
            "condition": {
                "lastTransitionTime": "...",
                "message": "Failed to apply the manifest (error: no ownership of the object in the member cluster; takeover is needed)",
                "reason": "NotTakenOver",
                "status": "False",
                "type": "Applied"
            },
            "kind": "Namespace",
            "name": "web-2",
            "version": "v1"
        }
    ]
}
```

## Safely take over matching workloads

To proceed with the take over of an existing workload you can modify the existing CRP, changing `whenToTakeOver` to `IfNoDiff`.

Fleet Manager applies the hub cluster workload in place of the existing workload on the target cluster where there are no differences between managed fields on both workloads. Extra fields are ignored.

```yml
apiVersion: placement.kubernetes-fleet.io/v1beta1
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

Fleet Manager attempts to place the workload, overwriting target member clusters that have matching fields.

Placements can still fail, so check for extra `failedPlacement` messages. Determine which member clusters failed using the following command. The [jq command](https://github.com/jqlang/jq) is used to format the output.

```bash
kubectl get clusterresourceplacement.v1beta1.placement.kubernetes-fleet.io web-2-crp -o jsonpath='{.status.placementStatuses}' \
    | jq '[.[] | select (.failedPlacements != null)] | map({clusterName, failedPlacements})'
```

Each cluster that failed placement due to a configuration difference returns an entry similar to the following sample.

```json
{
    "clusterName": "member-2",
    "failedPlacements": [
        {
            "condition": {
                "lastTransitionTime": "...",
                "message": "Failed to apply the manifest (error: cannot take over object: configuration differences are found between the manifest object and the corresponding object in the member cluster)",
                "reason": "FailedToTakeOver",
                "status": "False",
                "type": "Applied"
            },
            "kind": "Namespace",
            "name": "work-2",
            "version": "v1"
        }
    ]
}
```

To view which fields are drifted you can use the process detailed in the [report on drifted clusters](./concepts-placement-drift.md#report-on-drifted-clusters) section of the drift detection documentation.

At this point you must decide on how to handle the drift, by either including the member cluster changes into your hub cluster workload definition, or electing to overwrite the member cluster workload by setting the `whenToTakeOver` property to `Always`.

## Next steps

* [Detect and manage drift for resources placed using cluster resource placement](./concepts-placement-drift.md).
* [Controlling eviction and disruption for cluster resource placement](./concepts-eviction-disruption.md).
* [Defining a rollout strategy for a cluster resource placement](./concepts-rollout-strategy.md).
* [Use cluster resource placement to deploy workloads across multiple clusters](./quickstart-resource-propagation.md).
* [Intelligent cross-cluster Kubernetes resource placement based on member clusters properties](./intelligent-resource-placement.md).

<!-- LINKS - external -->
[learn-conceptual-crp]: ./concepts-resource-propagation.md
[fleet-hub-cluster]: ./access-fleet-hub-cluster-kubernetes-api.md
