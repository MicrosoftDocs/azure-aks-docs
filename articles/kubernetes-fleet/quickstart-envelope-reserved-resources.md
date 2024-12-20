---
title: "Propagate Reserved Resources from an Azure Kubernetes Fleet Manager Hub Cluster to Member Clusters"
description: Learn how to propagate resources by using the ClusterResourcePlacement API without unintended side effects on the hub cluster.
ms.topic: how-to
ms.date: 11/22/2024
author: jamyct
ms.author: jamisontsai
ms.service: azure-kubernetes-fleet-manager
ms.custom:
- devx-track-azurecli
- ignite-2023
- build-2024
---

# Propagate reserved resources from an Azure Kubernetes Fleet Manager hub cluster to member clusters

This article provides an overview of how to use envelope objects to propagate reserved Kubernetes resource types from an Azure Kubernetes Fleet Manager (Kubernetes Fleet) hub cluster to member clusters.

## Use a ConfigMap as an envelope object

You can use a ConfigMap as an envelope object via a Kubernetes Fleet reserved annotation.

To designate a ConfigMap as an envelope object, ensure that it contains the following annotation:

```
metadata:
  annotations:
    kubernetes-fleet.io/envelope-configmap: "true"
```

Here's an example of using ConfigMap as an envelope object:

```
apiVersion: v1
kind: ConfigMap
metadata:
    name: envelope-configmap
    namespace: app
    annotations:
        kubernetes-fleet.io/envelope-configmap: "true"
data:
    resourceQuota.yaml: |
        apiVersion: v1
        kind: ResourceQuota
        metadata:
            name: mem-cpu-demo
            namespace: app
        spec:
            hard:
                requests.cpu: "1"
                requests.memory: 1Gi
                limits.cpu: "2"
                limits.memory: 2Gi
    webhook.yaml: |
        apiVersion: admissionregistration.k8s.io/v1
        kind: MutatingWebhookConfiguration
        metadata:
            creationTimestamp: null
            labels:
                azure-workload-identity.io/system: "true"
            name: azure-wi-webhook-mutating-webhook-configuration
        webhooks:
        - admissionReviewVersions:
          - v1
          - v1beta1
          clientConfig:
              service:
                  name: azure-wi-webhook-webhook-service
                  namespace: app
                  path: /mutate-v1-pod
          failurePolicy: Fail
          matchPolicy: Equivalent
          name: mutation.azure-workload-identity.io
          rules:
          - apiGroups:
              - ""
              apiVersions:
              - v1
              operations:
              - CREATE
              - UPDATE
              resources:
              - pods
          sideEffects: None
```

## Propagate an envelope ConfigMap to member clusters

Apply the preceding example envelope object on your hub cluster. Then, use a `ClusterResourcePlacement` object to propagate the resource from hub to a member cluster named `kind-cluster-1`.

Here's a sample `ClusterResourcePlacement` specification:

```
spec:
    policy:
        clusterNames:
        - kind-cluster-1
        placementType: PickFixed
    resourceSelectors:
    - group: ""
        kind: Namespace
        name: app
        version: v1
    revisionHistoryLimit: 10
    strategy:
        type: RollingUpdate
```

## Retrieve the status of an envelope ConfigMap placement

Here's a sample status that shows the successful placement of an envelope object:

```
status:
conditions:
- lastTransitionTime: "2023-11-30T19:54:13Z"
  message: found all the clusters needed as specified by the scheduling policy
  observedGeneration: 2
  reason: SchedulingPolicyFulfilled
  status: "True"
  type: ClusterResourcePlacementScheduled
- lastTransitionTime: "2023-11-30T19:54:18Z"
  message: All 1 cluster(s) are synchronized to the latest resources on the hub
  cluster
  observedGeneration: 2
  reason: SynchronizeSucceeded
  status: "True"
  type: ClusterResourcePlacementSynchronized
- lastTransitionTime: "2023-11-30T19:54:18Z"
  message: Successfully applied resources to 1 member clusters
  observedGeneration: 2
  reason: ApplySucceeded
  status: "True"
  type: ClusterResourcePlacementApplied
  placementStatuses:
- clusterName: kind-cluster-1
  conditions:
    - lastTransitionTime: "2023-11-30T19:54:13Z"
      message: 'Successfully scheduled resources for placement in kind-cluster-1:
      picked by scheduling policy'
      observedGeneration: 2
      reason: ScheduleSucceeded
      status: "True"
      type: ResourceScheduled
    - lastTransitionTime: "2023-11-30T19:54:18Z"
      message: Successfully Synchronized work(s) for placement
      observedGeneration: 2
      reason: WorkSynchronizeSucceeded
      status: "True"
      type: WorkSynchronized
    - lastTransitionTime: "2023-11-30T19:54:18Z"
      message: Successfully applied resources
      observedGeneration: 2
      reason: ApplySucceeded
      status: "True"
      type: ResourceApplied
      selectedResources:
- kind: Namespace
  name: app
  version: v1
- kind: ConfigMap
  name: envelope-configmap
  namespace: app
  version: v1
```

> [!NOTE]
> The `selectedResources` section specifically displays the propagated envelope object. The status doesn't individually list all the resources that the envelope object contains.

The `selectedResources` section indicates that the namespace app and the ConfigMap named `envelope-configmap` were successfully propagated. You can further verify the successful propagation of resources mentioned within the `envelope-configmap` object by ensuring that the `failedPlacements` section in `placementStatus` for `kind-cluster-1` doesn't appear in the status.

Here's an example where the placement failed. In this example, within the `placementStatus` section for `kind-cluster-1`, the `failedPlacements` section provides details on the resource that failed to apply. The `failedPlacements` section also provides information about the envelope object that contained the resource.

```
status:
conditions:
- lastTransitionTime: "2023-12-06T00:09:53Z"
  message: found all the clusters needed as specified by the scheduling policy
  observedGeneration: 2
  reason: SchedulingPolicyFulfilled
  status: "True"
  type: ClusterResourcePlacementScheduled
- lastTransitionTime: "2023-12-06T00:09:58Z"
  message: All 1 cluster(s) are synchronized to the latest resources on the hub
  cluster
  observedGeneration: 2
  reason: SynchronizeSucceeded
  status: "True"
  type: ClusterResourcePlacementSynchronized
- lastTransitionTime: "2023-12-06T00:09:58Z"
  message: Failed to apply manifests to 1 clusters, please check the `failedPlacements`
  status
  observedGeneration: 2
  reason: ApplyFailed
  status: "False"
  type: ClusterResourcePlacementApplied
  placementStatuses:
- clusterName: kind-cluster-1
  conditions:
    - lastTransitionTime: "2023-12-06T00:09:53Z"
      message: 'Successfully scheduled resources for placement in kind-cluster-1:
      picked by scheduling policy'
      observedGeneration: 2
      reason: ScheduleSucceeded
      status: "True"
      type: ResourceScheduled
    - lastTransitionTime: "2023-12-06T00:09:58Z"
      message: Successfully Synchronized work(s) for placement
      observedGeneration: 2
      reason: WorkSynchronizeSucceeded
      status: "True"
      type: WorkSynchronized
    - lastTransitionTime: "2023-12-06T00:09:58Z"
      message: Failed to apply manifests, please check the `failedPlacements` status
      observedGeneration: 2
      reason: ApplyFailed
      status: "False"
      type: ResourceApplied
      failedPlacements:
    - condition:
      lastTransitionTime: "2023-12-06T00:09:53Z"
      message: 'Failed to apply manifest: namespaces "app" not found'
      reason: AppliedManifestFailedReason
      status: "False"
      type: Applied
      envelope:
      name: envelop-configmap
      namespace: test-ns
      type: ConfigMap
      kind: ResourceQuota
      name: mem-cpu-demo
      namespace: app
      version: v1
      selectedResources:
- kind: Namespace
  name: test-ns
  version: v1
- kind: ConfigMap
  name: envelop-configmap
  namespace: test-ns
  version: v1
```
