---
title: "How to understand the status of ClusterResourcePlacement and ResourcePlacement"
description: Learn how to read and interpret the status fields of ClusterResourcePlacement and ResourcePlacement custom resources in Azure Kubernetes Fleet Manager.
ms.topic: how-to
ms.date: 07/10/2025
author: zhangryan
ms.author: zhangryan
ms.service: azure-kubernetes-fleet-manager
ms.custom: concept-article
---

# How to understand the status of ClusterResourcePlacement and ResourcePlacement

When you are working with Azure Kubernetes Fleet Manager, understanding the status of your `ClusterResourcePlacement` (CRP) resources is crucial for monitoring deployment progress and troubleshooting issues. This article provides a comprehensive guide to interpreting the status fields and conditions that Fleet Manager reports for both cluster-scoped and namespace-scoped placements.

## Prerequisites

* You have a Fleet Manager with a hub cluster and one or more member clusters. If you don't have one, see [Create an Azure Kubernetes Fleet Manager resource and join member clusters](./quickstart-create-fleet-and-members.md).
* You have access to the Fleet Manager hub cluster. For more information, see [Access the Kubernetes API for an Azure Kubernetes Fleet Manager hub cluster](./access-fleet-hub-cluster-kubernetes-api.md).
* You have deployed at least one ClusterResourcePlacement API object to place your resources into the fleet. If you haven't, see [Use cluster resource placement to deploy workloads across multiple clusters](./quickstart-resource-propagation.md).

## Overview of placement status structure

The `ClusterResourcePlacement` object contains not only the descriptive spec about the placement, but also the status of the placement operation. 
The status section provides detailed information about:

* Overall placement status expressed through conditions
* Resources selected by the placement
* Per-cluster placement status expressed through conditions
* `Failed`, `drifted`, and `diffed` placements in each cluster

To view the status of a placement, use the following command:

```bash
kubectl describe clusterresourceplacement <placement-name>
```

Or to get the raw YAML output:

```bash
kubectl get clusterresourceplacement <placement-name> -o yaml
```

## Top-level status fields

The status section contains the following top-level fields:

* **selectedResources**: List of resources selected by the placement
* **conditions**: Array of overall placement conditions
* **observedResourceIndex**: Index of the current resource snapshot
* **placementStatuses**: Per-cluster placement status information

The following sections examine each field in detail.

## Understanding selected resources

The `selectedResources` field lists all resources that the placement selects. This field allows you to check if the expected resources are included in the placement. Here's an example:

```yaml
selectedResources:
- kind: Namespace
  name: test
  version: v1
- kind: ConfigMap
  name: test-config
  namespace: test
  version: v1
  envelope:
    name: example-envelope
    namespace: test
    type: ResourceEnvelope
- kind: Deployment
  name: web-app
  namespace: test
  group: apps
  version: v1
- kind: Service
  name: web-service
  namespace: test
  version: v1
- kind: Secret
  name: app-secrets
  namespace: test
  version: v1
```

Each resource entry includes:

* **group**: API group (empty for core resources)
* **version**: API version (for example, `v1`, `v1beta1`)
* **kind**: Resource kind
* **name**: Resource name
* **namespace**: Namespace (for namespaced resources)
* **envelope**: If a resource is wrapped in an envelope, the envelope metadata is also provided, which includes:
  * **name**: Name of the envelope
  * **namespace**: Namespace of the envelope
  * **type**: Type of the envelope (for example, `ResourceEnvelope`)


## Understanding placement conditions

The `conditions` array provides high-level status information about the entire placement. Each condition follows the Kubernetes common definition, which has the following standard fields:

* **type**: The condition type (described in the following sections)
* **status**: `True`, `False`, or `Unknown`
* **reason**: Short reason code for the condition
* **message**: Human-readable description
* **lastTransitionTime**: When the condition last changed
* **observedGeneration**: Generation of the placement when the condition was set

### ClusterResourcePlacement condition types

The following condition types are available for ClusterResourcePlacement:

#### ClusterResourcePlacementScheduled

Indicates whether the placement is successfully scheduled to target clusters.

- **True**: All required clusters are selected according to the placement policy
- **False**: Scheduling failed (for example, insufficient clusters available)
- **Unknown**: Scheduling decision is pending

```yaml
conditions:
- type: ClusterResourcePlacementScheduled
  status: "True"
  reason: SchedulingPolicyFulfilled
  message: "found all the clusters needed as specified by the scheduling policy"
  lastTransitionTime: "2023-11-10T08:14:52Z"
  observedGeneration: 5
```

#### ClusterResourcePlacementRolloutStarted

Indicates whether the rollout is started across the selected clusters.

- **True**: Resources have started rolling out to scheduled clusters
- **False**: Rollout is not started yet
- **Unknown**: Rollout decision is pending

```yaml
conditions:
- type: ClusterResourcePlacementRolloutStarted
  status: "True"
  reason: RolloutStarted
  message: "All 3 cluster(s) start rolling out the latest resource"
  lastTransitionTime: "2023-11-10T08:15:30Z"
  observedGeneration: 5
```

#### ClusterResourcePlacementOverridden

Indicates whether resource overrides are successfully applied.

- **True**: All applicable overrides are processed
- **False**: Some overrides failed to apply
- **Unknown**: Override processing is pending

```yaml
conditions:
- type: ClusterResourcePlacementOverridden
  status: "True"
  reason: NoOverrideSpecified
  message: "No override rules are configured for the selected resources"
  lastTransitionTime: "2023-11-10T08:15:45Z"
  observedGeneration: 5
```

#### ClusterResourcePlacementWorkSynchronized

Indicates whether work objects are created in the hub cluster's per-cluster namespaces.

- **True**: All work objects are synchronized
- **False**: Work synchronization fails or is incomplete
- **Unknown**: Work synchronization is pending

```yaml
conditions:
- type: ClusterResourcePlacementWorkSynchronized  
  status: "True"
  reason: SynchronizeSucceeded
  message: "All 2 cluster(s) are synchronized to the latest resources on the hub cluster"
  lastTransitionTime: "2023-11-10T08:23:43Z"
  observedGeneration: 5
```

#### ClusterResourcePlacementApplied

Indicates whether all resources are successfully applied to member clusters.

- **True**: All resources applied successfully to all target clusters
- **False**: Some resources failed to apply (check `failedPlacements`)
- **Unknown**: Apply operation is pending

```yaml
conditions:
- type: ClusterResourcePlacementApplied
  status: "True"
  reason: ApplySucceeded
  message: "The selected resources are successfully applied to 3 clusters"
  lastTransitionTime: "2023-11-10T08:16:15Z"
  observedGeneration: 5
```

#### ClusterResourcePlacementAvailable

Indicates whether the placed resources are all available and ready on member clusters.

- **True**: All resources are available on all target clusters
- **False**: Some resources aren't yet available
- **Unknown**: Availability check is pending

```yaml
conditions:
- type: ClusterResourcePlacementAvailable
  status: "True"
  reason: ResourceAvailable
  message: "The selected resources in 3 clusters are available now"
  lastTransitionTime: "2023-11-10T08:16:30Z"
  observedGeneration: 5
```

#### ClusterResourcePlacementDiffReported

Indicates whether configuration differences are reported (when using ReportDiff strategy).

- **True**: Complete diff report is available
- **False**: Diff reporting failed or is incomplete
- **Unknown**: Diff reporting is pending

```yaml
conditions:
- type: ClusterResourcePlacementDiffReported
  status: "True"
  reason: DiffReportComplete
  message: "Configuration differences are reported for all target clusters"
  lastTransitionTime: "2023-11-10T08:16:45Z"
  observedGeneration: 5
```

## Understanding resource snapshots

The `observedResourceIndex` field indicates which snapshot of resources is currently being deployed:

```yaml
observedResourceIndex: "1"
```

Fleet Manager creates resource snapshots when:

* The resource selectors change
* The selected resources are modified

Each snapshot has a unique index. You can view snapshots using:

```bash
kubectl get clusterresourcesnapshot --selector=kubernetes-fleet.io/resource-index=1
```

## Understanding per-cluster placement status

The `placementStatuses` array contains detailed status for each cluster where resources are placed or attempted to be placed:

```yaml
placementStatuses:
- clusterName: aks-member-1
  observedResourceIndex: "1"
  conditions:
    - type: ResourceScheduled
      status: "True"
      reason: ScheduleSucceeded
      message: "Successfully scheduled resources for placement in aks-member-1"
      lastTransitionTime: "2023-11-10T08:14:52Z"
      observedGeneration: 5
    - type: RolloutStarted
      status: "True"
      reason: RolloutStarted
      message: "Detected the new changes on the resources and started the rollout process"
      lastTransitionTime: "2023-11-10T08:15:30Z"
      observedGeneration: 5
    - type: Overridden
      status: "True"
      reason: NoOverrideSpecified
      message: "No override rules are configured for the selected resources"
      lastTransitionTime: "2023-11-10T08:15:45Z"
      observedGeneration: 5
    - type: WorkSynchronized
      status: "True"
      reason: AllWorkSynced
      message: "All of the works are synchronized to the latest"
      lastTransitionTime: "2023-11-10T08:16:00Z"
      observedGeneration: 5
    - type: Applied
      status: "True"
      reason: AllWorkHaveBeenApplied
      message: "All corresponding work objects are applied"
      lastTransitionTime: "2023-11-10T08:16:15Z"
      observedGeneration: 5
    - type: Available
      status: "True"
      reason: ResourceAvailable
      message: "All resources are available on the target cluster"
      lastTransitionTime: "2023-11-10T08:16:30Z"
      observedGeneration: 5
  failedPlacements: []
  driftedPlacements: []
  diffedPlacements: []
- clusterName: aks-member-2
  observedResourceIndex: "1"
  conditions:
    - type: ResourceScheduled
      status: "True"
      reason: ScheduleSucceeded
      message: "Successfully scheduled resources for placement in aks-member-2"
      lastTransitionTime: "2023-11-10T08:14:52Z"
      observedGeneration: 5
    - type: Applied
      status: "False"
      reason: AppliedManifestFailedReason
      message: "Failed to apply some manifests"
      lastTransitionTime: "2023-11-10T08:16:15Z"
      observedGeneration: 5
  failedPlacements:
    - kind: Deployment
      name: web-app
      namespace: test
      version: apps/v1
      condition:
        type: Applied
        status: "False"
        reason: AppliedManifestFailedReason
        message: "Failed to apply manifest: insufficient resources"
        lastTransitionTime: "2023-11-10T08:16:15Z"
```

### Per-cluster condition types

Each cluster's status includes conditions that track the deployment lifecycle:

#### ResourceScheduled

Indicates whether the cluster was successfully selected for placement.

```yaml
- type: ResourceScheduled
  status: "True"
  reason: ScheduleSucceeded
  message: "Successfully scheduled resources for placement in aks-member-1 (affinity score: 0, topology spread score: 0): picked by scheduling policy"
  lastTransitionTime: "2023-11-10T08:14:52Z"
  observedGeneration: 5
```

#### RolloutStarted

Indicates whether the rollout has started on this specific cluster.

```yaml
- type: RolloutStarted
  status: "True"
  reason: RolloutStarted
  message: "Detected new changes on the resources and started the rollout process"
  lastTransitionTime: "2023-11-10T08:15:30Z"
  observedGeneration: 5
```

#### Overridden

Indicates whether resource overrides are applied for this cluster.

```yaml
- type: Overridden
  status: "True"
  reason: NoOverrideSpecified
  message: "No override rules are configured for the selected resources"
  lastTransitionTime: "2023-11-10T08:15:45Z"
  observedGeneration: 5
```

#### WorkSynchronized

Indicates whether work objects are created for this cluster.

```yaml
- type: WorkSynchronized
  status: "True"
  reason: AllWorkSynced
  message: "All of the works are synchronized to the latest"
  lastTransitionTime: "2023-11-10T08:16:00Z"
  observedGeneration: 5
```

#### Applied

Indicates whether all the resources are successfully applied to this cluster.

```yaml
- type: Applied
  status: "True"
  reason: AllWorkHaveBeenApplied
  message: "All corresponding work objects are applied"
  lastTransitionTime: "2023-11-10T08:16:15Z"
  observedGeneration: 5
```

#### Available

Indicates whether all the resources are available and ready on this cluster.

```yaml
- type: Available
  status: "True"
  reason: ResourceAvailable
  message: "All resources are available on the target cluster"
  lastTransitionTime: "2023-11-10T08:16:30Z"
  observedGeneration: 5
```

#### DiffReported

Indicates whether configuration differences are reported for this cluster.

```yaml
- type: DiffReported
  status: "True"
  reason: DiffReportComplete
  message: "Configuration differences are reported for this cluster"
  lastTransitionTime: "2023-11-10T08:16:45Z"
  observedGeneration: 5
```

## Understanding failed placements

When resources fail to apply to a cluster, details are recorded in the `failedPlacements` array:

```yaml
failedPlacements:
- kind: Deployment
  name: my-app
  namespace: default
  version: apps/v1
  condition:
    type: Applied
    status: "False"
    reason: AppliedManifestFailedReason
    message: "Failed to apply manifest: namespaces 'app' not found"
    lastTransitionTime: "2023-12-06T00:09:53Z"
  envelope:
    name: example
    namespace: app
    type: ResourceEnvelope
- kind: Service
  name: my-service
  namespace: default
  version: v1
  condition:
    type: Applied
    status: "False"
    reason: AppliedManifestFailedReason
    message: "Failed to apply manifest: Service 'my-service' is forbidden: User 'system:serviceaccount:fleet-system:fleet-agent' cannot create resource 'services' in API group '' in the namespace 'default'"
    lastTransitionTime: "2023-12-06T00:10:15Z"
- kind: ConfigMap
  name: app-config
  namespace: production
  version: v1
  condition:
    type: Applied
    status: "False"
    reason: AppliedManifestFailedReason
    message: "Failed to apply manifest: configmaps 'app-config' already exists"
    lastTransitionTime: "2023-12-06T00:10:30Z"
```

Each failed placement includes:

* **Resource identification**: group, version, kind, name, namespace
* **condition**: The specific failure condition
* **envelope**: Envelope information (if applicable)

## Understanding drifted placements

Fleet Manager always reports resources that have drifted from their desired state:

```yaml
driftedPlacements:
- kind: Namespace
  name: web
  version: v1
  observationTime: "2025-03-19T06:50:25Z"
  firstDriftedObservedTime: "2025-03-19T06:49:54Z"
  targetClusterObservedGeneration: 12
  observedDrifts:
  - path: "/metadata/labels/owner"
    valueInHub: "simon"
    valueInMember: "chen"
  - path: "/metadata/annotations/purpose"
    valueInHub: "production"
    valueInMember: "testing"
- kind: Deployment
  name: web-app
  namespace: web
  group: apps
  version: v1
  observationTime: "2025-03-19T06:50:25Z"
  firstDriftedObservedTime: "2025-03-19T06:49:54Z"
  targetClusterObservedGeneration: 8
  observedDrifts:
  - path: "/spec/replicas"
    valueInHub: "3"
    valueInMember: "5"
  - path: "/spec/template/spec/containers/0/image"
    valueInHub: "nginx:1.20"
    valueInMember: "nginx:1.21"
- kind: ConfigMap
  name: app-config
  namespace: web
  version: v1
  observationTime: "2025-03-19T06:50:25Z"
  firstDriftedObservedTime: "2025-03-19T06:49:54Z"
  targetClusterObservedGeneration: 5
  observedDrifts:
  - path: "/data/environment"
    valueInHub: "production"
    valueInMember: "staging"
```

Each drifted placement includes:

* **Resource identification**: group, version, kind, name, namespace
* **observationTime**: When the drift was last observed
* **firstDriftedObservedTime**: When drift was first detected
* **targetClusterObservedGeneration**: Generation of the resource on the member cluster
* **observedDrifts**: Detailed list of configuration differences

## Understanding diffed placements

When using the ReportDiff apply strategy, Fleet Manager reports configuration differences:

```yaml
diffedPlacements:
- kind: Service
  name: my-service
  namespace: default
  version: v1
  observationTime: "2025-03-19T06:50:25Z"
  firstDiffedObservedTime: "2025-03-19T06:49:54Z"
  targetClusterObservedGeneration: 8
  observedDiffs:
  - path: "/spec/ports/0/nodePort"
    valueInHub: ""
    valueInMember: "30080"
  - path: "/spec/clusterIP"
    valueInHub: ""
    valueInMember: "10.96.100.200"
- kind: Deployment
  name: web-app
  namespace: default
  group: apps
  version: v1
  observationTime: "2025-03-19T06:50:25Z"
  firstDiffedObservedTime: "2025-03-19T06:49:54Z"
  targetClusterObservedGeneration: 12
  observedDiffs:
  - path: "/status/replicas"
    valueInHub: ""
    valueInMember: "3"
  - path: "/status/readyReplicas"
    valueInHub: ""
    valueInMember: "3"
  - path: "/metadata/generation"
    valueInHub: "1"
    valueInMember: "2"
```

Diffed placements have a similar structure to drifted placements but are used for different scenarios:

* **Drifted placements**: Used when resources are applied but then changed
* **Diffed placements**: Used with ReportDiff strategy or when takeover conditions aren't met

## Monitoring placement progress

To effectively monitor placement progress, check these key indicators:

1. **Resource placed**: Verify `ClusterResourcePlacementWorkSynchronized` is True
2. **Overall health**: Look at the `ClusterResourcePlacementApplied` condition
3. **Per-cluster status**: Review conditions for each target cluster
4. **Failed placements**: Check for any entries in `failedPlacements` arrays


## Complete status example

Here's a comprehensive example showing the complete status of a ClusterResourcePlacement:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterResourcePlacement
metadata:
  name: web-app-placement
  generation: 5
spec:
  resourceSelectors:
  - group: ""
    kind: Namespace
    name: web-app
    version: v1
  - group: apps
    kind: Deployment
    name: web-server
    namespace: web-app
    version: v1
  - group: ""
    kind: Service
    name: web-service
    namespace: web-app
    version: v1
  policy:
    placementType: PickN
    numberOfClusters: 2
    affinity:
      clusterAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          clusterSelectorTerms:
          - matchLabels:
              region: us-west
status:
  conditions:
  - type: ClusterResourcePlacementScheduled
    status: "True"
    reason: SchedulingPolicyFulfilled
    message: "found all the clusters needed as specified by the scheduling policy"
    lastTransitionTime: "2023-11-10T08:14:52Z"
    observedGeneration: 5
  - type: ClusterResourcePlacementRolloutStarted
    status: "True"
    reason: RolloutStarted
    message: "All 2 cluster(s) start rolling out the latest resource"
    lastTransitionTime: "2023-11-10T08:15:30Z"
    observedGeneration: 5
  - type: ClusterResourcePlacementOverridden
    status: "True"
    reason: NoOverrideSpecified
    message: "No override rules are configured for the selected resources"
    lastTransitionTime: "2023-11-10T08:15:45Z"
    observedGeneration: 5
  - type: ClusterResourcePlacementWorkSynchronized
    status: "True"
    reason: SynchronizeSucceeded
    message: "All 2 cluster(s) are synchronized to the latest resources on the hub cluster"
    lastTransitionTime: "2023-11-10T08:16:00Z"
    observedGeneration: 5
  - type: ClusterResourcePlacementApplied
    status: "True"
    reason: ApplySucceeded
    message: "The selected resources are successfully applied to 2 clusters"
    lastTransitionTime: "2023-11-10T08:16:15Z"
    observedGeneration: 5
  - type: ClusterResourcePlacementAvailable
    status: "True"
    reason: ResourceAvailable
    message: "The selected resources in 2 cluster are available now"
    lastTransitionTime: "2023-11-10T08:16:30Z"
    observedGeneration: 5
  observedResourceIndex: "1"
  selectedResources:
  - group: ""
    kind: Namespace
    name: web-app
    version: v1
  - group: apps
    kind: Deployment
    name: web-server
    namespace: web-app
    version: v1
  - group: ""
    kind: Service
    name: web-service
    namespace: web-app
    version: v1
  placementStatuses:
  - clusterName: aks-west-1
    observedResourceIndex: "1"
    conditions:
    - type: ResourceScheduled
      status: "True"
      reason: ScheduleSucceeded
      message: "Successfully scheduled resources for placement in aks-west-1 (affinity score: 0, topology spread score: 0): picked by scheduling policy"
      lastTransitionTime: "2023-11-10T08:14:52Z"
      observedGeneration: 5
    - type: RolloutStarted
      status: "True"
      reason: RolloutStarted
      message: "Detected the new changes on the resources and started the rollout process"
      lastTransitionTime: "2023-11-10T08:15:30Z"
      observedGeneration: 5
    - type: Overridden
      status: "True"
      reason: NoOverrideSpecified
      message: "No override rules are configured for the selected resources"
      lastTransitionTime: "2023-11-10T08:15:45Z"
      observedGeneration: 5
    - type: WorkSynchronized
      status: "True"
      reason: AllWorkSynced
      message: "All of the works are synchronized to the latest"
      lastTransitionTime: "2023-11-10T08:16:00Z"
      observedGeneration: 5
    - type: Applied
      status: "True"
      reason: AllWorkHaveBeenApplied
      message: "All corresponding work objects are applied"
      lastTransitionTime: "2023-11-10T08:16:15Z"
      observedGeneration: 5
    - type: Available
      status: "True"
      reason: ResourceAvailable
      message: "All resources are available on the target cluster"
      lastTransitionTime: "2023-11-10T08:16:30Z"
      observedGeneration: 5
    failedPlacements: []
    driftedPlacements: []
    diffedPlacements: []
  - clusterName: aks-west-2
    observedResourceIndex: "1"
    conditions:
    - type: ResourceScheduled
      status: "True"
      reason: ScheduleSucceeded
      message: "Successfully scheduled resources for placement in aks-west-2 (affinity score: 0, topology spread score: 0): picked by scheduling policy"
      lastTransitionTime: "2023-11-10T08:14:52Z"
      observedGeneration: 5
    - type: RolloutStarted
      status: "True"
      reason: RolloutStarted
      message: "Detected new changes on the resources and started the rollout process"
      lastTransitionTime: "2023-11-10T08:15:30Z"
      observedGeneration: 5
    - type: Overridden
      status: "True"
      reason: NoOverrideSpecified
      message: "No override rules are configured for the selected resources"
      lastTransitionTime: "2023-11-10T08:15:45Z"
      observedGeneration: 5
    - type: WorkSynchronized
      status: "True"
      reason: AllWorkSynced
      message: "All of the works are synchronized to the latest"
      lastTransitionTime: "2023-11-10T08:16:00Z"
      observedGeneration: 5
    - type: Applied
      status: "True"
      reason: AllWorkHaveBeenApplied
      message: "All corresponding work objects are applied"
      lastTransitionTime: "2023-11-10T08:16:15Z"
      observedGeneration: 5
    - type: Available
      status: "True"
      reason: ResourceAvailable
      message: "All resources are available on the target cluster"
      lastTransitionTime: "2023-11-10T08:16:30Z"
      observedGeneration: 5
    failedPlacements: []
    driftedPlacements: []
    diffedPlacements: []
```

This example shows:

- **Successful scheduling**: The placement was able to find two clusters matching the placement policy
- **Successful rollout**: All resources are deployed to both target clusters
- **No overrides**: No resource overrides were configured or needed
- **Synchronized work**: Work objects are created and synchronized
- **Applied resources**: All resources are successfully applied
- **Available resources**: All resources are running and available
- **Clean status**: No failed, drifted, or diffed placements

## Related content

To learn more about resource propagation, see the following resources:
* [Intelligent cross-cluster Kubernetes resource placement based on member clusters' properties](./intelligent-resource-placement.md).
* [Controlling eviction and disruption for cluster resource placement](./concepts-eviction-disruption.md).
* [How to do cluster resource overrides](./cluster-resource-override.md).
* [How to do resource overrides](./resource-override.md).
