---
title: "Detecting and managing workload drift with Azure Kubernetes Fleet Manager cluster resource placement"
description: This article describes how to use the applyStrategy property to control how Fleet Manager identifies and handles drift in workloads managed by cluster resource placement.
ms.date: 04/11/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: conceptual
---

# Detecting and managing workload drift with Azure Kubernetes Fleet Manager cluster resource placement (preview)

Authorized users can make direct changes at any time to fields on workloads placed on member clusters, causing a variation or _drift_ between the Fleet Manager cluster resource placement (CRP) definition and the placed workload. These drifts can result in issues when a future CRP deployment happens, potentially leading to outages and downtime.

In this article we will look at how you can use a cluster resource placement CRP `applyStrategy` property to determine how Fleet Manager detects and handles these drifts.

> [!NOTE]
> If you aren't already familiar with Fleet Manager's cluster resource placement (CRP), read the [conceptual overview of resource placement][learn-conceptual-crp] before reading this article.

[!INCLUDE [preview features note](./includes/preview/preview-callout-dpbeta.md)]

## Detect differences across a fleet

This section provides an overview of the cluster resource placement `ReportDiff` apply mode, which can be used to evaluate configuration state of placed workload across a fleet at any time. 

Using the `ReportDiff` mode, Fleet Manager checks for configuration differences between the [hub cluster][fleet-hub-cluster] workload definition and corresponding placed workloads on the member clusters, reporting the results in the CRP status.

In the following sample, Fleet Manager will report differences for the namespace `web` for any member cluster onto which it has previously been placed. 

```yml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterResourcePlacement
metadata:
  name: crp-reportdiff-sample
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      version: v1
      labelSelector:
        matchLabels:
          app: web
  policy:
    placementType: PickAll
  strategy:
    applyStrategy:
      type: ReportDiff 
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 100%
      unavailablePeriodSeconds: 1
```

Apply the CRP to your hub cluster.

### Report on drifted clusters

Using a command similar to the following you can determine on which clusters configuration has drifted. The [jq command](https://github.com/jqlang/jq) is used to format the output.

```bash
kubectl get clusterresourceplacement.v1beta1.placement.kubernetes-fleet.io crp-reportdiff-sample -o jsonpath='{.status.placementStatuses}' \
    | jq '[.[] | select (.diffedPlacements != null)] | map({clusterName, diffedPlacements})'
```

The command results in a response containing JSON similar to the following snippet. In this sample we can see that someone has directly overwritten the owner label on this cluster. 

```json
{
    "clusterName": "member-2",
    "diffedPlacements": [
        {
            "firstDiffedObservedTime": "2025-03-19T06:49:54Z",
            "kind": "Namespace",
            "name": "web",
            "observationTime": "2025-03-19T06:50:25Z",
            "observedDiffs": [
                {
                    "path": "/metadata/labels/owner",
                    "valueInHub": "simon",
                    "valueInMember": "chen"
                }
            ],
            "targetClusterObservedGeneration": 0,
            "version": "v1" 
        }
    ]
}
```

Fleet Manager reports the following information about configuration differences:

* `clusterName`: the member cluster on which the differences were detected.
* `diffedPlacements`: a list of differences detected, with the following details:
    * `group`, `kind`, `version`, `namespace`, and `name`: identifying properties of the resource that has configuration differences (not all are shown in the sample).
    * `observationTime`: when the current difference detail was collected.
    * `firstDiffedObservedTime`: when the current difference was first observed (may differ from `observationTime`).
    * `observedDiffs`: the diff details, specifically:
        * `path`: A JSON path ([RFC 6901](https://datatracker.ietf.org/doc/html/rfc6901)) that points to the field with a different value;
        * `valueInHub`: the value at the JSON path as seen from the hub cluster workload definition (the desired state). If this value is absent, the field does not exist in the hub cluster workload definition.
        * `valueInMember`: the value at the JSON path as seen from the member cluster workload (the current state). If this value is absent, the field does not exist on the member cluster.
    * `targetClusterObservedGeneration`: the generation of the member cluster workload.

Important items to note when using `ReportDiff`:

* Fleet Manager will only report differences on resources that have corresponding manifests on the hub cluster. If, for example, a namespace-scoped object has been created on the member cluster but not on the hub cluster, Fleet Manager will ignore the object, even if its owner namespace has been selected for placement.

* No apply operation is run; it is up to you to decide the best way to handle any identified configuration differences.

* Difference reporting is considered successful and complete as soon as Fleet Manager finishes checking all the resources; whether configuration differences are found or not has no effect on the difference reporting success status.

* When a resource change has been applied on the hub cluster, for CRPs of the `ReportDiff` mode, the change will be immediately rolled out to all member clusters (when the rollout strategy is set to RollingUpdate, the default type), as soon as they have completed diff reporting earlier.

## Handle drifted clusters during deployments

Reporting on drifted state across a fleet using [ReportDiff](#detect-differences-across-a-fleet) is a point-in-time activity so it is always possible that configuration has drifted between a check and a deployment.

In this section we look at how you use a `whenToApply` property of an `applyStrategy` in a cluster resource placement (CRP) to explicitly control how Fleet Manager handles drifted workloads when performing placements.  

The `whenToApply` property features two options:

* `Always`: Fleet Manager will periodically apply the workload definition from the hub cluster to matching member clusters, regardless of their drifted status. This is the default behavior for a CRP without an explicit `whenToApply` property.

* `IfNotDrifted`: Fleet Manager will check for drifts periodically; if drifts are found, Fleet Manager will stop applying the hub cluster workload definition and report in the CRP status.

> [!NOTE]
> The presence of drifts will NOT stop Fleet Manager from rolling out newer workload versions. If you choose to edit the workload definition on the hub cluster, Fleet Manager will always apply the new workload definition.

### Define which fields are used for comparison

You can use an optional `comparisonOptions` property to fine-tune how configuration differences are determined by `whenToApply`.

* `partialComparison`: only fields that are present on the hub cluster workload and on the target cluster workload are used for value comparison. Any additional unmanaged fields on the target cluster workload are ignored. This is the default behavior for a CRP without an explicit `comparisonOptions` setting.

* `fullComparison`: all fields on the workload definition on the Fleet hub cluster must be present on the selected member cluster. If the target cluster has any additional unmanaged fields, then it will be considered to have failed comparison.

In the follow sample, if a change is found in either any field (managed or unmanaged) then the CRP should be considered to have failed.

```yml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterResourcePlacement
metadata:
  name: crp-deploy-drift-sample
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      version: v1
      labelSelector:
        matchLabels:
          app: web
  policy:
    placementType: PickAll
  strategy:
    applyStrategy:
      comparisonOption: FullComparison    
      whenToApply: IfNotDrifted
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 100%
      unavailablePeriodSeconds: 1                
```

The following table summarizes the placement behavior depending on the `whenToApply` and `comparisonOption` values selected.

| `whenToApply` setting | `comparisonOption` setting | Field type | Outcome
| -------- | ------- | -------- | ------- 
| `IfNotDrifted` | `partialComparison` | Managed field (hub cluster workload definition) edited on member cluster. | Apply error reported, plus the drift details.
| `IfNotDrifted` | `partialComparison` | Unmanaged field (not present in hub cluster workload definition) is edited/added on member cluster. | Change is ignored and left untouched.
| `IfNotDrifted` | `fullComparison` | Any field is edited/added on member cluster. | Apply error reported, plus the drift details.
| `Always` | `partialComparison` | Managed field (hub cluster workload definition) edited on member cluster. | Change is overwritten.
| `Always` | `partialComparison` | Unmanaged field (not present in hub cluster workload definition) is edited/added on member cluster. | Change is ignored and left untouched.
| `Always` | `fullComparison` |  Any field is edited/added on member cluster. | Managed fields will be overwritten; Drift details reported on unmanaged fields, but not considered as an apply error. 

## Next steps

* [Take over existing workloads with cluster resource placement](./concepts-placement-takeover.md)
* [Defining a rollout strategy for a cluster resource placement](./concepts-rollout-strategy.md).
* [Controlling eviction and disruption for cluster resource placement](./concepts-eviction-disruption.md).
* [Use cluster resource placement to deploy workloads across multiple clusters](./quickstart-resource-propagation.md).
* [Intelligent cross-cluster Kubernetes resource placement based on member clusters properties](./intelligent-resource-placement.md).

<!-- LINKS - external -->
[learn-conceptual-crp]: ./concepts-resource-propagation.md
[fleet-hub-cluster]: ./access-fleet-hub-cluster-kubernetes-api.md
