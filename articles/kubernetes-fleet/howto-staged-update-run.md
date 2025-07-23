---
title: "How to use ClusterStagedUpdateRun to orchestrate staged rollouts"
description: Learn how to use ClusterStagedUpdateRun to rollout resources to member clusters in a staged manner and rollback resources to a previous version in Azure Kubernetes Fleet Manager.
ms.topic: how-to
ms.date: 07/18/2025
author: arvindth
ms.author: arvindth
ms.service: azure-kubernetes-fleet-manager
# Customer intent: "As a DevOps engineer, I want to use staged update runs to control how workloads are deployed across multiple clusters, so that I can minimize risk and ensure reliable rollouts through progressive deployment strategies."
---

# Use ClusterStagedUpdateRun to orchestrate staged rollouts across member clusters

Azure Kubernetes Fleet Manager staged update runs provide a controlled approach to deploying workloads across multiple member clusters using a stage-by-stage process. This approach allows you to minimize risk by deploying to subsets of clusters sequentially, with optional wait times and approval gates between stages.

This article shows you how to create and execute staged update runs to deploy workloads progressively and roll back to previous versions when needed.

## Prerequisites

* You need an Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).

* To understand the concepts and terminology used in this article, read the [conceptual overview of staged rollout strategies](./concepts-rollout-strategy.md#staged-update-strategy-preview).

* You must have a Fleet Manager with a hub cluster and three member clusters. If you don't have one, follow the [quickstart][fleet-quickstart] to create a Fleet Manager with a hub cluster. Then, join Azure Kubernetes Service (AKS) clusters as members.

  > [!TIP]
  > Ensure that your AKS member clusters are configured so that you can test placement by using the cluster properties that interest you (location, node count, resources, or cost).

* You need Azure CLI version 2.58.0 or later installed to complete this article. To install or upgrade, see [Install the Azure CLI][azure-cli-install].

* If you don't have the Kubernetes CLI (kubectl) already, you can install it by using this command:

  ```azurecli-interactive
  az aks install-cli
  ```

* You need the `fleet` Azure CLI extension. You can install it by running the following command:

  ```azurecli-interactive
  az extension add --name fleet
  ```

  Run the [`az extension update`][az-extension-update] command to update to the latest version of the extension:

  ```azurecli-interactive
  az extension update --name fleet
  ```

* Authorize kubectl to connect to the Fleet Manager hub cluster:

  ```azurecli-interactive
  az fleet get-credentials --resource-group $GROUP --name $FLEET
  ```

## Set up the demo environment

This tutorial demonstrates staged update runs using a demo fleet environment with three member clusters that have the following labels:

| cluster name | labels                      |
|--------------|-----------------------------|
| member1      | environment=canary, order=2 |
| member2      | environment=staging         |
| member3      | environment=canary, order=1 |

These labels allow us to create stages that group clusters by environment and control the deployment order within each stage.

## Prepare workloads for placement

Next, publish workloads to the hub cluster so that they can be placed onto member clusters.

Create a namespace and configmap for the workload on the hub cluster:

```bash
kubectl create ns test-namespace
kubectl create cm test-cm --from-literal=key=value1 -n test-namespace
```

To deploy the resources, create a ClusterResourcePlacement:

> [!NOTE]
> The `spec.strategy.type` is set to `External` to allow rollout triggered with a `ClusterStagedUpdateRun`.

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterResourcePlacement
metadata:
  name: example-placement
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

All three clusters should be scheduled since we use the `PickAll` policy, but no resources should be deployed on the member clusters yet because we didn't create a `ClusterStagedUpdateRun`.

Verify the placement is scheduled:

```bash
kubectl get crp example-placement
NAME                GEN   SCHEDULED   SCHEDULED-GEN   AVAILABLE   AVAILABLE-GEN   AGE
example-placement   1     True        1                                           51s
```

## Work with resource snapshots

Fleet Manager creates resource snapshots when resources change. Each snapshot has a unique index that you can use to reference specific versions of your resources.

> [!TIP]
> For more information about resource snapshots and how they work, see [Understanding resource snapshots](./howto-understand-placement.md#understanding-resource-snapshots).

### Check current resource snapshots

To check current resource snapshots:

```bash
kubectl get clusterresourcesnapshots --show-labels
NAME                           GEN   AGE   LABELS
example-placement-0-snapshot   1     60s   kubernetes-fleet.io/is-latest-snapshot=true,kubernetes-fleet.io/parent-CRP=example-placement,kubernetes-fleet.io/resource-index=0
```

We only have one version of the snapshot. It's the current latest (`kubernetes-fleet.io/is-latest-snapshot=true`) and has resource-index 0 (`kubernetes-fleet.io/resource-index=0`).

### Create a new resource snapshot

Now modify the configmap with a new value:

```bash
kubectl edit cm test-cm -n test-namespace
```

Update the value from `value1` to `value2`:

```bash
kubectl get configmap test-cm -n test-namespace -o yaml
apiVersion: v1
data:
  key: value2 # value updated here, old value: value1
kind: ConfigMap
metadata:
  creationTimestamp: ...
  name: test-cm
  namespace: test-namespace
  resourceVersion: ...
  uid: ...
```

Now you should see two versions of resource snapshots with index 0 and 1 respectively:

```bash
kubectl get clusterresourcesnapshots --show-labels
NAME                           GEN   AGE    LABELS
example-placement-0-snapshot   1     2m6s   kubernetes-fleet.io/is-latest-snapshot=false,kubernetes-fleet.io/parent-CRP=example-placement,kubernetes-fleet.io/resource-index=0
example-placement-1-snapshot   1     10s    kubernetes-fleet.io/is-latest-snapshot=true,kubernetes-fleet.io/parent-CRP=example-placement,kubernetes-fleet.io/resource-index=1
```

The latest label is set to example-placement-1-snapshot, which contains the latest configmap data:

```bash
kubectl get clusterresourcesnapshots example-placement-1-snapshot -o yaml
apiVersion: placement.kubernetes-fleet.io/v1
kind: ClusterResourceSnapshot
metadata:
  annotations:
    kubernetes-fleet.io/number-of-enveloped-object: "0"
    kubernetes-fleet.io/number-of-resource-snapshots: "1"
    kubernetes-fleet.io/resource-hash: 10dd7a3d1e5f9849afe956cfbac080a60671ad771e9bda7dd34415f867c75648
  creationTimestamp: "2025-07-22T21:26:54Z"
  generation: 1
  labels:
    kubernetes-fleet.io/is-latest-snapshot: "true"
    kubernetes-fleet.io/parent-CRP: example-placement
    kubernetes-fleet.io/resource-index: "1"
  name: example-placement-1-snapshot
  ownerReferences:
  - apiVersion: placement.kubernetes-fleet.io/v1beta1
    blockOwnerDeletion: true
    controller: true
    kind: ClusterResourcePlacement
    name: example-placement
    uid: e7d59513-b3b6-4904-864a-c70678fd6f65
  resourceVersion: "19994"
  uid: 79ca0bdc-0b0a-4c40-b136-7f701e85cdb6
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
      key: value2 # latest value: value2, old value: value1
    kind: ConfigMap
    metadata:
      name: test-cm
      namespace: test-namespace
```

## Deploy a ClusterStagedUpdateStrategy

A `ClusterStagedUpdateStrategy` defines the orchestration pattern that groups clusters into stages and specifies the rollout sequence. It selects member clusters by labels. For our demonstration, we create one with two stages:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterStagedUpdateStrategy
metadata:
  name: example-strategy
spec:
  stages:
    - name: staging
      labelSelector:
        matchLabels:
          environment: staging
      afterStageTasks:
        - type: TimedWait
          waitTime: 1m
    - name: canary
      labelSelector:
        matchLabels:
          environment: canary
      sortingLabelKey: order
      afterStageTasks:
        - type: Approval
```

## Deploy a ClusterStagedUpdateRun to roll out latest change

A `ClusterStagedUpdateRun` executes the rollout of a `ClusterResourcePlacement` following a `ClusterStagedUpdateStrategy`. To trigger the staged update run for our ClusterResourcePlacement (CRP), we create a `ClusterStagedUpdateRun` specifying the CRP name, updateRun strategy name, and the latest resource snapshot index ("1"):

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterStagedUpdateRun
metadata:
  name: example-run
spec:
  placementName: example-placement
  resourceSnapshotIndex: "1"
  stagedRolloutStrategyName: example-strategy
```

The staged update run is initialized and running:

```bash
kubectl get csur example-run
NAME          PLACEMENT           RESOURCE-SNAPSHOT-INDEX   POLICY-SNAPSHOT-INDEX   INITIALIZED   SUCCEEDED   AGE
example-run   example-placement   1                         0                       True                      7s
```

A more detailed look at the status after some time has elapsed:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterStagedUpdateRun
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"placement.kubernetes-fleet.io/v1beta1","kind":"ClusterStagedUpdateRun","metadata":{"annotations":{},"name":"example-run"},"spec":{"placementName":"example-placement","resourceSnapshotIndex":"1","stagedRolloutStrategyName":"example-strategy"}}
  creationTimestamp: "2025-07-22T21:28:08Z"
  finalizers:
  - kubernetes-fleet.io/stagedupdaterun-finalizer
  generation: 1
  name: example-run
  resourceVersion: "21461"
  uid: 7db13885-3230-4892-89b5-a7eb70baac94
spec:
  placementName: example-placement
  resourceSnapshotIndex: "1"
  stagedRolloutStrategyName: example-strategy
status:
  conditions:
  - lastTransitionTime: "2025-07-22T21:28:08Z"
    message: ClusterStagedUpdateRun initialized successfully
    observedGeneration: 1
    reason: UpdateRunInitializedSuccessfully
    status: "True" # the updateRun is initialized successfully
    type: Initialized
  - lastTransitionTime: "2025-07-22T21:29:53Z"
    message: The updateRun is waiting for after-stage tasks in stage canary to complete
    observedGeneration: 1
    reason: UpdateRunWaiting
    status: "False" # the updateRun is still progressing and waiting for approval
    type: Progressing
  deletionStageStatus:
    clusters: [] # no clusters need to be cleaned up
    stageName: kubernetes-fleet.io/deleteStage
  policyObservedClusterCount: 3 # number of clusters to be updated
  policySnapshotIndexUsed: "0"
  stagedUpdateStrategySnapshot: # snapshot of the strategy used for this update run
    stages:
    - afterStageTasks:
      - type: TimedWait
        waitTime: 1m0s
      labelSelector:
        matchLabels:
          environment: staging
      name: staging
    - afterStageTasks:
      - type: Approval
      labelSelector:
        matchLabels:
          environment: canary
      name: canary
      sortingLabelKey: order
  stagesStatus: # detailed status for each stage
  - afterStageTaskStatus:
    - conditions:
      - lastTransitionTime: "2025-07-22T21:29:23Z"
        message: Wait time elapsed
        observedGeneration: 1
        reason: AfterStageTaskWaitTimeElapsed
        status: "True" # the wait after-stage task has completed
        type: WaitTimeElapsed
      type: TimedWait
    clusters:
    - clusterName: member2 # stage staging contains member2 cluster only
      conditions:
      - lastTransitionTime: "2025-07-22T21:28:08Z"
        message: Cluster update started
        observedGeneration: 1
        reason: ClusterUpdatingStarted
        status: "True"
        type: Started
      - lastTransitionTime: "2025-07-22T21:28:23Z"
        message: Cluster update completed successfully
        observedGeneration: 1
        reason: ClusterUpdatingSucceeded
        status: "True" # member2 is updated successfully
        type: Succeeded
    conditions:
    - lastTransitionTime: "2025-07-22T21:28:23Z"
      message: All clusters in the stage are updated and after-stage tasks are completed
      observedGeneration: 1
      reason: StageUpdatingSucceeded
      status: "False"
      type: Progressing
    - lastTransitionTime: "2025-07-22T21:29:23Z"
      message: Stage update completed successfully
      observedGeneration: 1
      reason: StageUpdatingSucceeded
      status: "True" # stage staging has completed successfully
      type: Succeeded
    endTime: "2025-07-22T21:29:23Z"
    stageName: staging
    startTime: "2025-07-22T21:28:08Z"
  - afterStageTaskStatus:
    - approvalRequestName: example-run-canary # ClusterApprovalRequest name for this stage
      conditions:
      - lastTransitionTime: "2025-07-22T21:29:53Z"
        message: ClusterApprovalRequest is created
        observedGeneration: 1
        reason: AfterStageTaskApprovalRequestCreated
        status: "True"
        type: ApprovalRequestCreated
      type: Approval
    clusters:
    - clusterName: member3 # according to the labelSelector and sortingLabelKey, member3 is selected first in this stage
      conditions:
      - lastTransitionTime: "2025-07-22T21:29:23Z"
        message: Cluster update started
        observedGeneration: 1
        reason: ClusterUpdatingStarted
        status: "True"
        type: Started
      - lastTransitionTime: "2025-07-22T21:29:38Z"
        message: Cluster update completed successfully
        observedGeneration: 1
        reason: ClusterUpdatingSucceeded
        status: "True" # member3 update is completed
        type: Succeeded
    - clusterName: member1 # member1 is selected after member3 because of order=2 label
      conditions:
      - lastTransitionTime: "2025-07-22T21:29:38Z"
        message: Cluster update started
        observedGeneration: 1
        reason: ClusterUpdatingStarted
        status: "True"
        type: Started
      - lastTransitionTime: "2025-07-22T21:29:53Z"
        message: Cluster update completed successfully
        observedGeneration: 1
        reason: ClusterUpdatingSucceeded
        status: "True" # member1 update is completed
        type: Succeeded
    conditions:
    - lastTransitionTime: "2025-07-22T21:29:53Z"
      message: All clusters in the stage are updated, waiting for after-stage tasks
        to complete
      observedGeneration: 1
      reason: StageUpdatingWaiting
      status: "False" # stage canary is waiting for approval task completion
      type: Progressing
    stageName: canary
    startTime: "2025-07-22T21:29:23Z"
```

We can see that the TimedWait for staging has elapsed and we also see that the `ClusterApprovalRequest` object was created. We can check the generated ClusterApprovalRequest and see that it's not approved yet

```bash
kubectl get clusterapprovalrequest
NAME                 UPDATE-RUN    STAGE    APPROVED   APPROVALACCEPTED   AGE
example-run-canary   example-run   canary                                 2m39s
```

We can approve the `ClusterApprovalRequest` by creating a json patch file and applying it:

```bash
cat << EOF > approval.json
"status": {
    "conditions": [
        {
            "lastTransitionTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "message": "lgtm",
            "observedGeneration": 1,
            "reason": "lgtm",
            "status": "True",
            "type": "Approved"
        }
    ]
}
EOF
```

```bash
kubectl patch clusterapprovalrequests example-run-canary --type='merge' --subresource=status --patch-file approval.json
```

Then verify that it's approved:

```bash
kubectl get clusterapprovalrequest
NAME                 UPDATE-RUN    STAGE    APPROVED   APPROVALACCEPTED   AGE
example-run-canary   example-run   canary   True       True               3m35s
```

The `ClusterStagedUpdateRun` now is able to proceed and complete:

```bash
kubectl get csur example-run
NAME          PLACEMENT           RESOURCE-SNAPSHOT-INDEX   POLICY-SNAPSHOT-INDEX   INITIALIZED   SUCCEEDED   AGE
example-run   example-placement   1                         0                       True          True        5m28s
```

The `ClusterResourcePlacement` also shows the rollout completed and resources are available on all member clusters:

```
kubectl get crp example-placement
NAME                GEN   SCHEDULED   SCHEDULED-GEN   AVAILABLE   AVAILABLE-GEN   AGE
example-placement   1     True        1               True        1               8m55s
```

The configmap test-cm should be deployed on all three member clusters, with latest data:

```yaml
apiVersion: v1
data:
  key: value2
kind: ConfigMap
metadata:
  ...
  name: test-cm
  namespace: test-namespace
  ...
```

## Deploy a second ClusterStagedUpdateRun to roll back to a previous version

Now suppose the workload admin wants to roll back the configmap change, reverting the value `value2` back to `value1`. Instead of manually updating the configmap from hub, they can create a new ClusterStagedUpdateRun with a previous resource snapshot index, "0" in our context and they can reuse the same strategy:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterStagedUpdateRun
metadata:
  name: example-run-2
spec:
  placementName: example-placement
  resourceSnapshotIndex: "0"
  stagedRolloutStrategyName: example-strategy
```

Let's check the new `ClusterStagedUpdateRun`:

```bash
kubectl get csur -A
NAME            PLACEMENT           RESOURCE-SNAPSHOT-INDEX   POLICY-SNAPSHOT-INDEX   INITIALIZED   SUCCEEDED   AGE
example-run     example-placement   1                         0                       True          True        13m
example-run-2   example-placement   0                         0                       True                      9s
```

After some time has elapsed, we should see the `ClusterApprovalRequest` object created for the new `ClusterStagedUpdateRun`:

```bash
kubectl get clusterapprovalrequest -A
NAME                   UPDATE-RUN      STAGE    APPROVED   APPROVALACCEPTED   AGE
example-run-2-canary   example-run-2   canary                                 75s
example-run-canary     example-run     canary   True       True               14m
```

To approve the new `ClusterApprovalRequest` object, let's reuse the same approval.json file to patch it:
```
kubectl patch clusterapprovalrequests example-run-2-canary --type='merge' --subresource=status --patch-file approval.json
```

Verify if the new object is approved,

```bash
kubectl get clusterapprovalrequest -A                                                                                    
NAME                   UPDATE-RUN      STAGE    APPROVED   APPROVALACCEPTED   AGE
example-run-2-canary   example-run-2   canary   True       True               2m7s
example-run-canary     example-run     canary   True       True               15m
```

The configmap `test-cm` should now be deployed on all three member clusters, with the data reverted to `value1`:

```yaml
apiVersion: v1
data:
  key: value1
kind: ConfigMap
metadata:
  ...
  name: test-cm
  namespace: test-namespace
  ...
```

## Clean up resources

When you're finished with this tutorial, you can clean up the resources you created:

```bash
# Delete the staged update runs
kubectl delete clusterstagedupaterun example-run example-run-2

# Delete the staged update strategy
kubectl delete clusterstagedupdatestrategy example-strategy

# Delete the cluster resource placement
kubectl delete clusterresourceplacement example-placement

# Delete the test namespace (this will also delete the configmap)
kubectl delete namespace test-namespace
```

## Next steps

In this article, you learned how to use ClusterStagedUpdateRun to orchestrate staged rollouts across member clusters. You created staged update strategies, executed progressive rollouts, and performed rollbacks to previous versions.

To learn more about staged update runs and related concepts, see the following resources:

* [Defining a rollout strategy for cluster resource placement](./concepts-rollout-strategy.md)
* [How to understand the status of ClusterResourcePlacement](./howto-understand-placement.md)
* [How to configure monitoring and alerting for update runs](./howto-monitor-update-runs.md)
