---
title: "Defining a rollout strategy for Azure Kubernetes Fleet Manager cluster resource placement"
description: This article describes how to define a rollout strategy for Fleet Manager's cluster resource placement.
ms.date: 03/11/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: conceptual
---

# Defining a rollout strategy for Azure Kubernetes Fleet Manager cluster resource placement

During the lifetime of a cluster resource placement (CRP), changes may be made to the CRP which can result in one of the following scenarios:

* New workloads may need to be placed on all picked clusters
* Workloads already placed on a picked cluster may get updated or deleted
* Some clusters picked previously are now unpicked, and workloads must be removed from such clusters
* Some clusters are newly picked, and workloads must be added to them.

Most scenarios can lead to service interruptions as workloads running on member clusters may temporarily become unavailable as Fleet Manager dispatches updated resources. Clusters that are no longer selected lose all placed resources, resulting in lost traffic. If too many new clusters are selected and Fleet Manager places resources on them simultaneously, clusters may become overloaded. The exact interruption pattern may vary depending on the resources placed.

To minimize interruption, Fleet Manager's cluster resource placement allows users to configure a rollout strategy, similar to native Kubernetes deployment, to transition between changes as smoothly as possible. 

In this article, we cover the rollout strategy options available for cluster resource placement.

> [!NOTE]
> If you aren't already familiar with Fleet Manager's cluster resource placement (CRP), read the [conceptual overview of resource placement][learn-conceptual-crp] before reading this article.

## Default behavior with no explicit strategy

Cluster resource placements don't require you to define a rollout strategy. If you don't specify one, the default behavior is to use a `RollingUpdate` strategy with a `maxSurge` of 25%, `maxUnavailable` of 25%, and `unavailablePeriodSeconds` of 10 seconds.

## Rolling update strategy

An explicit rolling update strategy can be used by adding a `strategy` specification to a CRP as shown. You can define parameters which control how disruptive the Fleet Manager resource placement is. 

```yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourcePlacement
metadata:
  name: crp-example
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
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 50%
```

Rolling update strategies can be configured with the following parameters:

* **maxUnavailable:** considers a cluster as unavailable if resources haven't been successfully applied to the cluster and makes sure that at any time, there are **at least** (N - `maxUnavailable`) number of clusters available. You can set as an absolute number or a percentage. The default is 25% and zero shouldn't be used. Setting this parameter to a lower value results in less interruption during a change but lead to slower rollouts. 

* **maxSurge:** ensures that at any time, there are **at most** (N + `maxSurge`) number of clusters available. You can set as an absolute number or a percentage. The default is 25% and zero shouldn't be used. Setting this parameter to a lower value results in fewer resource placements on more clusters by Fleet Manager, which slows down the rollout process.

* **unavailablePeriodSeconds** allows you to define a time period before resources should be assessed as "ready". The default value is 60 seconds. Fleet Manager only considers newly applied resources on a cluster as "ready" `unavailablePeriodSeconds` seconds after the resources are successfully applied to that cluster. Setting a lower value for this parameter results in faster rollouts. However, we strongly recommend that users set a value that allows the initialization/preparation tasks to be completed.

### How cluster count is determined

Fleet Manager uses the placement type to determine the baseline number of clusters (`N`) to use when calculating `maxUnavailable` or `maxSurge`:

  * **PickFixed**: the number of `clusterNames` specified
  * **PickAll**: the number of clusters picked
  * **PickN**: the `numberOfClusters` value.

If you use a percentage for the parameter, it's calculated against `N` as well.

## Staged update strategy (preview)

This rollout strategy is defined externally to resource placement using a `ClusterStagedUpdateStrategy` custom resource which is applied by Fleet Manager using a `ClusterStagedUpdateRun`.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

### Defining a staged update strategy

You can build reusable strategies that determine the order in which clusters receive placements by defining selectors used to group clusters into stages. Within a stage, cluster ordering can be controlled, and it's possible to specify optional post-placement soak time and approvals. You can name and order stages to suit your needs. 

The following diagram shows a sample update strategy with three stages and multiple clusters in each stage. Inclusion of clusters in a stage is determined by the `environment` label on the cluster. Labels on clusters determine the ordering of clusters in the canary and production stages. A one hour wait exists between staging and canary, with an approval required to move from canary to production. 

:::image type="content" source="./media/concepts-resource-placement/conceptual-rollout-staged-update-strategy.png" alt-text="A placement staged update strategy containing three stages - staging, canary, and production. Each stage contains multiple clusters, with canary and production apply a sort order on cluster based on labels. There's a 1 hour wait between staging and canary, and an approval is required to transition from canary to production stages." lightbox="./media/concepts-resource-placement/conceptual-rollout-staged-update-strategy.png":::

The staged update strategy in the diagram can be expressed using the following `ClusterStagedUpdateStrategy` definition.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterStagedUpdateStrategy
metadata:
  name: example-staged-strategy
spec:
  stages:
    - name: staging
      labelSelector:
        matchLabels:
          environment: staging
      afterStageTasks:
        - type: TimedWait
          waitTime: 1h
    - name: canary
      labelSelector:
        matchLabels:
          environment: canary
      sortingLabelKey: name
      afterStageTasks:
        - type: Approval
    - name: production
      labelSelector:
        matchLabels:
          environment: production
      sortingLabelKey: order
```

### Using a staged update strategy

1. Configure the cluster resource placement to use a strategy of type `External` as shown. When you submit the CRP to your Fleet hub cluster no placement is undertaken.

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: ClusterResourcePlacement
    metadata:
      name: crp-staged-update-sample
    spec:
      resourceSelectors:
        - group: ""
          kind: Namespace
          name: test-namespace
          version: v1
      policy:
        placementType: PickAll
      strategy:
        type: External
    ```

1. Create a `ClusterStagedUpdateStrategy` (as shown earlier), and submit the Fleet hub cluster.

1. Create a `ClusterStagedUpdateRun`, ensuring to reference both the CRP and strategy to use.

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1beta1
    kind: ClusterStagedUpdateRun
    metadata:
      name: example-staged-update-run
    spec:
      placementName: crp-staged-update-sample
      stagedRolloutStrategyName: example-staged-strategy
    ```

1. Submit the `ClusterStagedUpdateRun` by using `kubectl apply` on the Fleet Manager hub cluster.
 
1. The placement is started and you can observe the rollout occur. 

### Check the status of a staged rollout

Use the following approach to determine the current status of a staged rollout, including time remaining on a `TimedWait` or if any approvals are pending.

```bash
kubectl get clusterStagedUpdateRun example-staged-update-run
```

We can see the staged rollout has been initialized and has been running for 44 seconds.

```output
NAME                        PLACEMENT                  RESOURCE-SNAPSHOT   POLICY-SNAPSHOT   INITIALIZED   SUCCEEDED   AGE
example-staged-update-run   crp-staged-update-sample   1                   0                 True                      44s
```

Determine the detailed status by using the following command.

```bash
kubectl get clusterStagedUpdateRun example-staged-update-run -o yaml
```

This command generates a verbose response that provides context on where the rollout is. The following sample is annotated to explain.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterStagedUpdateRun
metadata:
  ...
  name: example-staged-update-run
  ...
spec:
  placementName: crp-staged-update-sample
  resourceSnapshotIndex: "1"
  stagedRolloutStrategyName: example-staged-strategy
status:
  conditions:
  - lastTransitionTime: ...
    message: ClusterStagedUpdateRun initialized successfully
    observedGeneration: 1
    reason: UpdateRunInitializedSuccessfully
    status: "True"           # the updateRun is initialized successfully
    type: Initialized
  - lastTransitionTime: ...
    message: ""
    observedGeneration: 1
    reason: UpdateRunStarted
    status: "True"
    type: Progressing        # the updateRun is still running
  deletionStageStatus:
    clusters: []             # no clusters need to be cleaned up
    stageName: kubernetes-fleet.io/deleteStage
  policyObservedClusterCount: 3     # number of clusters to be updated
  policySnapshotIndexUsed: "0"
  stagedUpdateStrategySnapshot:     # snapshot of the strategy
    stages:
    - afterStageTasks:
      - type: TimedWait
        waitTime: 1h
      labelSelector:
        matchLabels:
          environment: staging
      name: staging
      sortingLabelKey: name
    - afterStageTasks:
      - type: Approval
      labelSelector:
        matchLabels:
          environment: canary
      name: canary
      sortingLabelKey: order
  stagesStatus:                # detailed status for each stage
  - afterStageTaskStatus:
    - conditions:
      - lastTransitionTime: ...
        message: ""
        observedGeneration: 1
        reason: AfterStageTaskWaitTimeElapsed
        status: "True"         # the wait after-stage task has completed
        type: WaitTimeElapsed
      type: TimedWait
    clusters:
    - clusterName: member-cluster-02    # stage staging contains member-cluster-02 cluster only
      conditions:
      - lastTransitionTime: ...
        message: ""
        observedGeneration: 1
        reason: ClusterUpdatingStarted
        status: "True"
        type: Started
      - lastTransitionTime: ...
        message: ""
        observedGeneration: 1
        reason: ClusterUpdatingSucceeded
        status: "True"                  # member-cluster-02 is updated successfully
        type: Succeeded
    conditions:
    - lastTransitionTime: ...
      message: ""
      observedGeneration: 1
      reason: StageUpdatingWaiting
      status: "False"
      type: Progressing
    - lastTransitionTime: ...
      message: ""
      observedGeneration: 1
      reason: StageUpdatingSucceeded
      status: "True"                    # stage staging has completed successfully
      type: Succeeded
    endTime: ...
    stageName: staging
    startTime: ...
  - afterStageTaskStatus:
    - approvalRequestName: example-staged-update-run-canary # ClusterApprovalRequest name for this stage
      type: Approval
    clusters:
    - clusterName: member-cluster-03         # according the labelSelector and sortingLabelKey, member-cluster-03 is selected first in this stage
      conditions:
      - lastTransitionTime: ...
        message: ""
        observedGeneration: 1
        reason: ClusterUpdatingStarted
        status: "True"
        type: Started
      - lastTransitionTime: ...
        message: ""
        observedGeneration: 1
        reason: ClusterUpdatingSucceeded
        status: "True"                      # member-cluster-03 update is completed
        type: Succeeded
    - clusterName: member-cluster-01        # member-cluster-01 is selected after member-cluster-03 because of order=2 label
      conditions:
      - lastTransitionTime: ...
        message: ""
        observedGeneration: 1
        reason: ClusterUpdatingStarted
        status: "True"                      # member-cluster-01 update has not finished yet
        type: Started
    conditions:
    - lastTransitionTime: ...
      message: ""
      observedGeneration: 1
      reason: StageUpdatingStarted
      status: "True"                        # stage canary is still executing
      type: Progressing
    stageName: canary
```

### Submit approvals for staged updates

When your staged update strategy includes approvals, you need to use the following approach to submit approval responses to continue the staged rollout.

Approval payloads are a JSON object using the following format.

```json
{
    "status":
    {
        "conditions":[
            {
                "type":"Approved",
                "status":"True",
                "reason":"reason for approval",
                "message":"longer message describing approval",
                "lastTransitionTime":"2025-03-12T06:15:21Z",
                "observedGeneration":1
            }
          ]
    }
}
```

1. Check for pending approvals.

    ```bash
    kubectl get clusterapprovalrequest
    ```
      
    his command returns a table displaying the name of the staged update run in `UPDATE-RUN`, along with the stage requiring approval in `STAGE`. The stage name is appended to the name of the update run to form the name of the `ClusterApprovalRequest`.
    
    ```output
    NAME                                 UPDATE-RUN                      STAGE    APPROVED   APPROVALACCEPTED   AGE
    example-staged-update-run-canary     example-staged-update-run       canary                                 2m2s
    ```

1. Submit a patch request to approve.

    ```bash
    kubectl patch clusterapprovalrequests example-staged-update-run-canary --type=merge -p {"status":{"conditions":[{"type":"Approved","status":"True","reason":"tested as OK","message":"lgtm","lastTransitionTime":"'$(date --utc +%Y-%m-%dT%H:%M:%SZ)'","observedGeneration":1}]}} --subresource=status
    ```
    
    A successful submission with advice that the patch has been applied.
    
    ```output
    clusterapprovalrequest.placement.kubernetes-fleet.io/example-staged-update-run-canary patched
    ```

1. You can also confirm the approval was successful by resubmitting the original `clusterapprovalrequest`.

    ```bash
    kubectl get clusterapprovalrequest
    ```

    You can view the approved status in the `APPROVED` column and that it's accepted in the `APPROVALACCEPTED` column.
      
    ```output
    NAME                                 UPDATE-RUN                      STAGE    APPROVED   APPROVALACCEPTED   AGE
    example-staged-update-run-canary     example-staged-update-run       canary   True       True               1m10s
    ```

## Next steps

* [Controlling eviction and disruption for cluster resource placement](./concepts-eviction-disruption.md).
* [Use cluster resource placement to deploy workloads across multiple clusters](./quickstart-resource-propagation.md).
* [Intelligent cross-cluster Kubernetes resource placement based on member clusters properties](./intelligent-resource-placement.md).

<!-- LINKS - external -->
[learn-conceptual-crp]: ./concepts-resource-propagation.md
