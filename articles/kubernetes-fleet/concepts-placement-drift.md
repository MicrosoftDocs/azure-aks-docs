---
title: "Detecting and managing workload drift with Azure Kubernetes Fleet Manager cluster resource placement"
description: This article describes how to use the applyStrategy property to control how Fleet Manager identifies and handles drift in workloads managed cluster resource placement.
ms.date: 04/11/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: conceptual
---

# Detecting and managing workload drift with Azure Kubernetes Fleet Manager cluster resource placement (preview)

In multi-cluster environments a workload can be present one or more cluster that is selected as a deployment target via a cluster resource placement.

In this article we will look at how you can use the `applyStrategy` property in a cluster resource placement to determine how Fleet Manager handles these conflicts .

> [!NOTE]
> If you aren't already familiar with Fleet Manager's cluster resource placement (CRP), read the [conceptual overview of resource placement][learn-conceptual-crp] before reading this article.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## Drift detection

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

## ReportDiff apply strategy

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