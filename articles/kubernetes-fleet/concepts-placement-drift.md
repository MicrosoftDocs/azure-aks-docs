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

A drift occurs when a non-Fleet agent (e.g., a developer or a controller) makes changes to a field of a Fleet-managed resource directly on the member cluster side without modifying the corresponding resource template created on the hub cluster.

In multi-cluster environments authorized users can make changes to fields on workloads placed by Fleet Managers cluster resource placement (CRP) for a range of reasons. If fleet administrators are unaware of these changes they can result in problems the next time an updated CRP is deployed, returning the modified values to their default state.

In this article we will look at how you can use the `applyStrategy` property in a cluster resource placement to determine how Fleet Manager handles these conflicts .

> [!NOTE]
> If you aren't already familiar with Fleet Manager's cluster resource placement (CRP), read the [conceptual overview of resource placement][learn-conceptual-crp] before reading this article.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## Report differences without deployments

Cover `ReportDiff`.

* As mentioned earlier, with this mode no apply op will be run at all; it is up to the user to decide the best way to handle found configuration differences (if any).

* Diff reporting becomes successful and complete as soon as Fleet finishes checking all the resources; whether configuration differences are found or not has no effect on the diff reporting success status.

* When a resource change has been applied on the hub cluster side, for CRPs of the ReportDiff mode, the change will be immediately rolled out to all member clusters (when the rollout strategy is set to RollingUpdate, the default type), as soon as they have completed diff reporting earlier.

* It is worth noting that Fleet will only report differences on resources that have corresponding manifests on the hub cluster. If, for example, a namespace-scoped object has been created on the member cluster but not on the hub cluster, Fleet will ignore the object, even if its owner namespace has been selected for placement.

```yml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterResourcePlacement
metadata:
  name: work-3
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      version: v1
      # Select all namespaces with the label app=work. 
      labelSelector:
        matchLabels:
          app: web-3
  policy:
    placementType: PickAll
  strategy:
    # For simplicity reasons, the CRP is configured to roll out changes to
    # all member clusters at once. This is not a setup recommended for production
    # use.      
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 100%
      unavailablePeriodSeconds: 1
    applyStrategy:
      type: ReportDiff   
```

## Managing drift during deployments

Cover the `whenToApply` property.

The whenToApply field features two options:

* `Always`: this is the default option 😑. With this setting, Fleet will periodically apply the resource templates from the hub cluster to member clusters, with or without drifts. This is consistent with the behavior before the new drift detection and takeover experience.

* `IfNotDrifted`: this is the new option ✨ provided by the drift detection mechanism. With this setting, Fleet will check for drifts periodically; if drifts are found, Fleet will stop applying the resource templates and report in the CRP status.

```yml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterResourcePlacement
metadata:
  name: work
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      version: v1
      # Select all namespaces with the label app=work. 
      labelSelector:
        matchLabels:
          app: web
  policy:
    placementType: PickAll
  strategy:
    applyStrategy:
      # The default setting is PartialComparison.    
      comparisonOption: FullComparison    
      whenToApply: IfNotDrifted
    # For simplicity reasons, the CRP is configured to roll out changes to
    # all member clusters at once. This is not a setup recommended for production
    # use.      
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 100%
      unavailablePeriodSeconds: 1                
```



## Next steps

* [Take over existing workloads with cluster resource placement](./concepts-placement-takeover.md)
* [Defining a rollout strategy for a cluster resource placement](./concepts-rollout-strategy.md).
* [Controlling eviction and disruption for cluster resource placement](./concepts-eviction-disruption.md).
* [Use cluster resource placement to deploy workloads across multiple clusters](./quickstart-resource-propagation.md).
* [Intelligent cross-cluster Kubernetes resource placement based on member clusters properties](./intelligent-resource-placement.md).

<!-- LINKS - external -->
[learn-conceptual-crp]: ./concepts-resource-propagation.md
[fleet-hub-cluster]: ./access-fleet-hub-cluster-kubernetes-api.md
[crp-staged-rollouts]: ./concepts-rollout-strategy.md#staged-update-strategy-preview