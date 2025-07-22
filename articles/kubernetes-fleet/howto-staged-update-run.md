---
title: "How to use ClusterStagedUpdateRun"
description: Learn how to use ClusterStagedUpdateRun to rollout resources to member clusters in a staged manner and rollback resources to a previous versionFleet Manager.
ms.topic: how-to
ms.date: 07/18/2025
author: arvindth
ms.author: arvindth
ms.service: azure-kubernetes-fleet-manager
---

## Prerequisites

* You need an Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).

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

* `ClusterStagedUpdateRun` CR is used to deploy resources from hub cluster to member clusters with `ClusterResourcePlacement` (or CRP) in a stage by stage manner. This tutorial is based on a demo fleet environment with 3 member clusters with the following labels: 

    | cluster name | labels                      |
    |--------------|-----------------------------|
    | member1      | environment=canary, order=2 |
    | member2      | environment=staging         |
    | member3      | environment=canary, order=1 |

## Prepare workloads for placement

Next, publish workloads to the hub cluster so that it can be placed onto member clusters:

Create a namespace, configmap for the workload on the hub cluster:

```bash
kubectl create ns test-namespace
kubectl create cm test-cm --from-literal=key=value1 -n test-namespace
```

Now we create a ClusterResourcePlacement to deploy the resources, 

> [!NOTE]
> spec.strategy.type is set to `External` to allow rollout triggered with a `ClusterStagedUpdateRun`.

Create ClusterResourcePlacement to deploy the resources:

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

All three clusters should be scheduled since we use the `PickAll` policy but at the moment no resource should be deployed on the member clusters because we haven't created a `ClusterStagedUpdateRun` yet.

Your output should look similar to the following example:

```bash
kubectl get crp example-placement
NAME                GEN   SCHEDULED   SCHEDULED-GEN   AVAILABLE   AVAILABLE-GEN   AGE
example-placement   1     True        1                                           51s
```

## Check Resource snapshot versions

> [!TIP]
> For more information about resource snapshots and how they work, see [Understanding resource snapshots](./howto-understand-placement.md#understanding-resource-snapshots).

To check current resource snapshots:

```bash
kubectl get clusterresourcesnapshots --show-labels
NAME                           GEN   AGE   LABELS
example-placement-0-snapshot   1     60s   kubernetes-fleet.io/is-latest-snapshot=true,kubernetes-fleet.io/parent-CRP=example-placement,kubernetes-fleet.io/resource-index=0
```

We only have one version of the snapshot. It is the current latest (kubernetes-fleet.io/is-latest-snapshot=true) and has resource-index 0 (kubernetes-fleet.io/resource-index=0).

Now we modify the our configmap with a new value set to value2:

```bash
kubectl edit cm test-cm -n test-namespace

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

now we should see 2 versions of resource snapshots with index 0 and 1 respectively:

```bash
 kubectl get clusterresourcesnapshots --show-labels
NAME                           GEN   AGE    LABELS
example-placement-0-snapshot   1     2m6s   kubernetes-fleet.io/is-latest-snapshot=false,kubernetes-fleet.io/parent-CRP=example-placement,kubernetes-fleet.io/resource-index=0
example-placement-1-snapshot   1     10s    kubernetes-fleet.io/is-latest-snapshot=true,kubernetes-fleet.io/parent-CRP=example-placement,kubernetes-fleet.io/resource-index=1
```

The latest label set to example-placement-1-snapshot which contains the latest configmap data:

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

## Deploy a ClusterStagedUpdateRun to rollout latest change

A `ClusterStagedUpdateRun` executes the rollout of a `ClusterResourcePlacement` following a `ClusterStagedUpdateStrategy`. To trigger the staged update run for our CRP, we create a `ClusterStagedUpdateRun` specifying the CRP name, updateRun strategy name, and the latest resource snapshot index ("1"):

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

A more detailed look at the status after some time has elasped:

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
    status: "True"
    type: Initialized
  - lastTransitionTime: "2025-07-22T21:29:53Z"
    message: The updateRun is waiting for after-stage tasks in stage canary to complete
    observedGeneration: 1
    reason: UpdateRunWaiting
    status: "False"
    type: Progressing
  deletionStageStatus:
    clusters: []
    stageName: kubernetes-fleet.io/deleteStage
  policyObservedClusterCount: 3
  policySnapshotIndexUsed: "0"
  stagedUpdateStrategySnapshot:
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
  stagesStatus:
  - afterStageTaskStatus:
    - conditions:
      - lastTransitionTime: "2025-07-22T21:29:23Z"
        message: Wait time elapsed
        observedGeneration: 1
        reason: AfterStageTaskWaitTimeElapsed
        status: "True"
        type: WaitTimeElapsed
      type: TimedWait
    clusters:
    - clusterName: member2
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
        status: "True"
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
      status: "True"
      type: Succeeded
    endTime: "2025-07-22T21:29:23Z"
    stageName: staging
    startTime: "2025-07-22T21:28:08Z"
  - afterStageTaskStatus:
    - approvalRequestName: example-run-canary
      conditions:
      - lastTransitionTime: "2025-07-22T21:29:53Z"
        message: ClusterApprovalRequest is created
        observedGeneration: 1
        reason: AfterStageTaskApprovalRequestCreated
        status: "True"
        type: ApprovalRequestCreated
      type: Approval
    clusters:
    - clusterName: member3
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
        status: "True"
        type: Succeeded
    - clusterName: member1
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
        status: "True"
        type: Succeeded
    conditions:
    - lastTransitionTime: "2025-07-22T21:29:53Z"
      message: All clusters in the stage are updated, waiting for after-stage tasks
        to complete
      observedGeneration: 1
      reason: StageUpdatingWaiting
      status: "False"
      type: Progressing
    stageName: canary
    startTime: "2025-07-22T21:29:23Z"
```

We can see that the TimedWait for staging has elasped and we also see that the `ClusterApprovalRequest` object has also been created, We can check the generated ClusterApprovalRequest and see that it's not approved yet

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

Then verify it's approved:

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

The `ClusterResourcePlacement` also shows rollout has completed and resources are available on all member clusters:

```
kubectl get crp example-placement
NAME                GEN   SCHEDULED   SCHEDULED-GEN   AVAILABLE   AVAILABLE-GEN   AGE
example-placement   1     True        1               True        1               8m55s
```

The configmap test-cm should be deployed on all 3 member clusters, with latest data:

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