---
title: "Orchestrate staged rollouts with staged update runs"
description: Learn how to use staged update runs to deploy resources to member clusters in stages and roll back to previous versions in Azure Kubernetes Fleet Manager.
ms.topic: how-to
ms.date: 07/18/2025
author: arvindth
ms.author: arvindth
ms.service: azure-kubernetes-fleet-manager
# Customer intent: "As a DevOps engineer, I want to use staged update runs to control how workloads are deployed across multiple clusters, so that I can minimize risk and ensure reliable rollouts through progressive deployment strategies."
---

# Orchestrate staged rollouts across member clusters

Azure Kubernetes Fleet Manager staged update runs provide a controlled approach to deploying workloads across multiple member clusters using a stage-by-stage process. To minimize risk, this approach deploys to targeted clusters sequentially, with optional wait times and approval gates between stages.

This article shows you how to create and execute staged update runs to deploy workloads progressively and roll back to previous versions when needed.

> [!NOTE]
> Azure Kubernetes Fleet Manager provides two approaches for staged updates:
>
> - **Cluster-scoped**: Use `ClusterStagedUpdateRun` with `ClusterResourcePlacement` for fleet administrators managing infrastructure-level changes
> - **Namespace-scoped**: Use `StagedUpdateRun` with `ResourcePlacement` for application teams managing rollouts within their specific namespaces
>
> The examples in this article demonstrate both approaches using tabs. Choose the tab that matches your deployment scope.

## Prerequisites

* You need an Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).

* To understand the concepts and terminology used in this article, read the [conceptual overview of staged rollout strategies](./concepts-rollout-strategy.md#staged-update-strategy-preview).

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

## Configure the demo environment

This demo runs on a Fleet Manager with a hub cluster and three member clusters. If you don't have one, follow the [quickstart][fleet-quickstart] to create a Fleet Manager with a hub cluster. Then, join Azure Kubernetes Service (AKS) clusters as members.

This tutorial demonstrates staged update runs using a demo fleet environment with three member clusters that have the following labels:

| cluster name | labels                      |
|--------------|-----------------------------|
| member1      | environment=canary, order=2 |
| member2      | environment=staging         |
| member3      | environment=canary, order=1 |

To group clusters by environment and control the deployment order within each stage, these labels allow us to create stages.

## Prepare workloads for placement

Publish workloads to the hub cluster so that they can be placed onto member clusters.

### [ClusterResourcePlacement](#tab/clusterresourceplacement)

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

> [!NOTE]
> The `spec.strategy.type` is set to `External` to allow rollout triggered with a `ClusterStagedUpdateRun`.

All three clusters should be scheduled since we use the `PickAll` policy, but no resources should be deployed on the member clusters yet because we didn't create a `ClusterStagedUpdateRun`.

Verify the placement is scheduled:

```bash
kubectl get crp example-placement
```

Your output should look similar to the following example:

```output
NAME                GEN   SCHEDULED   SCHEDULED-GEN   AVAILABLE   AVAILABLE-GEN   AGE
example-placement   1     True        1                                           51s
```

### [ResourcePlacement](#tab/resourceplacement)

To contain the `ResourcePlacement` resource and application resources, create a namespace on the hub cluster:

```bash
kubectl create ns my-app-namespace
kubectl create deployment web-app --image=nginx:1.20 --replicas=3 -n my-app-namespace
kubectl expose deployment web-app --port=80 --target-port=80 -n my-app-namespace
```

To deploy the application, create a namespace-scoped `ResourcePlacement`:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ResourcePlacement
metadata:
  name: web-app-placement
  namespace: my-app-namespace
spec:
  resourceSelectors:
    - group: "apps"
      kind: Deployment
      name: web-app
      version: v1
    - group: ""
      kind: Service
      name: web-app
      version: v1
  policy:
    placementType: PickAll
  strategy:
    type: External
```

> [!NOTE]
> The `spec.strategy.type` is set to `External` to allow rollout triggered with a `StagedUpdateRun`.

All three clusters should be scheduled, but no resources should be deployed on the member clusters yet because we didn't create a `StagedUpdateRun`.

Verify the placement is scheduled:

```bash
kubectl get rp web-app-placement -n my-app-namespace
```

Your output should look similar to the following example:

```output
NAME                GEN   SCHEDULED   SCHEDULED-GEN   AVAILABLE   AVAILABLE-GEN   AGE
web-app-placement   1     True        1                                           45s
```

---

## Work with resource snapshots

Fleet Manager creates resource snapshots when resources change. Each snapshot has a unique index that you can use to reference specific versions of your resources.

> [!TIP]
> For more information about resource snapshots and how they work, see [Understanding resource snapshots](./howto-understand-placement.md#understanding-resource-snapshots).

### Check current resource snapshots

### [ClusterResourcePlacement](#tab/clusterresourceplacement)

To check current resource snapshots:

```bash
kubectl get clusterresourcesnapshots --show-labels
```

Your output should look similar to the following example:

```output
NAME                           GEN   AGE   LABELS
example-placement-0-snapshot   1     60s   kubernetes-fleet.io/is-latest-snapshot=true,kubernetes-fleet.io/parent-CRP=example-placement,kubernetes-fleet.io/resource-index=0
```

We only have one version of the snapshot. It's the current latest (`kubernetes-fleet.io/is-latest-snapshot=true`) and has resource-index 0 (`kubernetes-fleet.io/resource-index=0`).

### [ResourcePlacement](#tab/resourceplacement)

Check the resource snapshots for the namespace-scoped placement:

```bash
kubectl get resourcesnapshots -n my-app-namespace --show-labels
```

Your output should look similar to the following example:

```output
NAME                           GEN   AGE   LABELS
web-app-placement-0-snapshot   1     63s   kubernetes-fleet.io/is-latest-snapshot=true,kubernetes-fleet.io/parent-CRP=web-app-placement,kubernetes-fleet.io/resource-index=0
```

We only have one version of the snapshot. It's the current latest and has resource-index 0.

---

### Create a new resource snapshot

### [ClusterResourcePlacement](#tab/clusterresourceplacement)

Now modify the configmap with a new value:

```bash
kubectl edit cm test-cm -n test-namespace
```

Update the value from `value1` to `value2`:

```bash
kubectl get configmap test-cm -n test-namespace -o yaml
```

Your output should look similar to the following example:

```yaml
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
```

Your output should look similar to the following example:

```output
NAME                           GEN   AGE    LABELS
example-placement-0-snapshot   1     2m6s   kubernetes-fleet.io/is-latest-snapshot=false,kubernetes-fleet.io/parent-CRP=example-placement,kubernetes-fleet.io/resource-index=0
example-placement-1-snapshot   1     10s    kubernetes-fleet.io/is-latest-snapshot=true,kubernetes-fleet.io/parent-CRP=example-placement,kubernetes-fleet.io/resource-index=1
```

The latest label is set to example-placement-1-snapshot, which contains the latest configmap data:

```bash
kubectl get clusterresourcesnapshots example-placement-1-snapshot -o yaml
```

Your output should look similar to the following example:

```yaml
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

### [ClusterResourcePlacement](#tab/clusterresourceplacement)

A `ClusterStagedUpdateStrategy` defines the orchestration pattern that groups clusters into stages and specifies the rollout sequence. It selects member clusters by labels. For our demonstration, we create one with two stages, staging and canary:

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

### [ResourcePlacement](#tab/resourceplacement)

Update the deployment to a new version:

```bash
kubectl set image deployment/web-app web-app=nginx:1.21 -n my-app-namespace
```

Verify the new snapshot is created:

```bash
kubectl get resourcesnapshots -n my-app-namespace --show-labels
```

Your output should look similar to the following example:

```output
NAME                           GEN   AGE    LABELS
web-app-placement-0-snapshot   1     4m3s   kubernetes-fleet.io/is-latest-snapshot=false,kubernetes-fleet.io/parent-CRP=web-app-placement,kubernetes-fleet.io/resource-index=0
web-app-placement-1-snapshot   1     23s    kubernetes-fleet.io/is-latest-snapshot=true,kubernetes-fleet.io/parent-CRP=web-app-placement,kubernetes-fleet.io/resource-index=1
```

---

## Deploy a staged update strategy

### [ClusterResourcePlacement](#tab/clusterresourceplacement)

A `ClusterStagedUpdateStrategy` defines the orchestration pattern that groups clusters into stages and specifies the rollout sequence:

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

### [ResourcePlacement](#tab/resourceplacement)

Create a namespace-scoped `StagedUpdateStrategy`:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: StagedUpdateStrategy
metadata:
  name: app-rollout-strategy
  namespace: my-app-namespace
spec:
  stages:
    - name: staging
      labelSelector:
        matchLabels:
          environment: staging
      afterStageTasks:
        - type: TimedWait
          waitTime: 30s
    - name: canary
      labelSelector:
        matchLabels:
          environment: canary
      sortingLabelKey: order
      afterStageTasks:
        - type: Approval
```

---

## Deploy a staged update run to roll out latest change

### [ClusterResourcePlacement](#tab/clusterresourceplacement)

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
```

Your output should look similar to the following example:

```output
NAME          PLACEMENT           RESOURCE-SNAPSHOT-INDEX   POLICY-SNAPSHOT-INDEX   INITIALIZED   SUCCEEDED   AGE
example-run   example-placement   1                         0                       True                      7s
```

A more detailed look at the status after the one-minute `TimedWait` elapses:

```bash
kubectl get csur example-run -o yaml
```

Your output should look similar to the following example:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterStagedUpdateRun
metadata:
  ...
  name: example-run
  ...
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

We can see that the TimedWait period for staging stage elapses and we also see that the `ClusterApprovalRequest` object for the approval task in canary stage was created. We can check the generated ClusterApprovalRequest and see that no one approved it yet

```bash
kubectl get clusterapprovalrequest
```

Your output should look similar to the following example:

```output
NAME                 UPDATE-RUN    STAGE    APPROVED   APPROVALACCEPTED   AGE
example-run-canary   example-run   canary                                 2m39s
```

### [ResourcePlacement](#tab/resourceplacement)

Create a namespace-scoped staged update run to roll out the new image version:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: StagedUpdateRun
metadata:
  name: web-app-rollout-v1-21
  namespace: my-app-namespace
spec:
  placementName: web-app-placement
  resourceSnapshotIndex: "1"
  stagedRolloutStrategyName: app-rollout-strategy
```

The staged update run is initialized and running:

```bash
kubectl get sur web-app-rollout-v1-21 -n my-app-namespace
```

Your output should look similar to the following example:

```output
NAME                     PLACEMENT           RESOURCE-SNAPSHOT-INDEX   POLICY-SNAPSHOT-INDEX   INITIALIZED   SUCCEEDED   AGE
web-app-rollout-v1-21    web-app-placement   1                         0                       True                      12s
```

After the 30-second `TimedWait` has elapses, check for the approval request:

```bash
kubectl get approvalrequests -n my-app-namespace
```

Your output should look similar to the following example:

```output
NAME                             STAGED-UPDATE-RUN        STAGE    APPROVED   APPROVALACCEPTED   AGE
web-app-rollout-v1-21-canary     web-app-rollout-v1-21    canary                                 45s
```

---

## Approve the staged update run

### [ClusterResourcePlacement](#tab/clusterresourceplacement)

We can approve the `ClusterApprovalRequest` by creating a json patch file and applying it:

```bash
cat << EOF > approval.json
"status": {
    "conditions": [
        {
            "lastTransitionTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "message": "lgtm",
            "observedGeneration": 1,
            "reason": "testPassed",
            "status": "True",
            "type": "Approved"
        }
    ]
}
EOF
```

Submit a patch request to approve using the JSON file created.

```bash
kubectl patch clusterapprovalrequests example-run-canary --type='merge' --subresource=status --patch-file approval.json
```

Then verify that you approved the request:

```bash
kubectl get clusterapprovalrequest
```

Your output should look similar to the following example:

```output
NAME                 UPDATE-RUN    STAGE    APPROVED   APPROVALACCEPTED   AGE
example-run-canary   example-run   canary   True       True               3m35s
```

The `ClusterStagedUpdateRun` now is able to proceed and complete:

```bash
kubectl get csur example-run
```

Your output should look similar to the following example:

```output
NAME          PLACEMENT           RESOURCE-SNAPSHOT-INDEX   POLICY-SNAPSHOT-INDEX   INITIALIZED   SUCCEEDED   AGE
example-run   example-placement   1                         0                       True          True        5m28s
```

### [ResourcePlacement](#tab/resourceplacement)

Approve the request to proceed to the canary stage:

```bash
cat << EOF > approval-ns.json
{
  "status": {
    "conditions": [
      {
        "lastTransitionTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
        "message": "Approved for production rollout",
        "observedGeneration": 1,
        "reason": "ManualApproval",
        "status": "True",
        "type": "Approved"
      }
    ]
  }
}
EOF

kubectl patch approvalrequests web-app-rollout-v1-21-canary -n my-app-namespace \
  --type='merge' --subresource=status --patch-file approval-ns.json
```

Verify the rollout completion:

```bash
kubectl get sur web-app-rollout-v1-21 -n my-app-namespace
```

Your output should look similar to the following example:

```output
NAME                     PLACEMENT           RESOURCE-SNAPSHOT-INDEX   POLICY-SNAPSHOT-INDEX   INITIALIZED   SUCCEEDED   AGE
web-app-rollout-v1-21    web-app-placement   1                         0                       True          True        3m15s
```

---

## Verify the rollout completion

### [ClusterResourcePlacement](#tab/clusterresourceplacement)

The `ClusterResourcePlacement` also shows the rollout completed and resources are available on all member clusters:

```bash
kubectl get crp example-placement
```

Your output should look similar to the following example:

```output
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

### [ResourcePlacement](#tab/resourceplacement)

The `ResourcePlacement` shows the rollout completed and resources are available:

```bash
kubectl get rp web-app-placement -n my-app-namespace
```

Your output should look similar to the following example:

```output
NAME                GEN   SCHEDULED   SCHEDULED-GEN   AVAILABLE   AVAILABLE-GEN   AGE
web-app-placement   1     True        1               True        1               6m22s
```

---

## Deploy a second staged update run to roll back

### [ClusterResourcePlacement](#tab/clusterresourceplacement)

Suppose the workload admin wants to roll back the configmap change, reverting the value `value2` back to `value1`. Instead of manually updating the configmap from hub, they can create a new ClusterStagedUpdateRun with a previous resource snapshot index, "0" in our context and they can reuse the same strategy:

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
kubectl get csur
```

Your output should look similar to the following example:

```output
NAME            PLACEMENT           RESOURCE-SNAPSHOT-INDEX   POLICY-SNAPSHOT-INDEX   INITIALIZED   SUCCEEDED   AGE
example-run     example-placement   1                         0                       True          True        13m
example-run-2   example-placement   0                         0                       True                      9s
```

After the one-minute `TimedWait` elapses, we should see the `ClusterApprovalRequest` object created for the new `ClusterStagedUpdateRun`:

```bash
kubectl get clusterapprovalrequest
```

Your output should look similar to the following example:

```output
NAME                   UPDATE-RUN      STAGE    APPROVED   APPROVALACCEPTED   AGE
example-run-2-canary   example-run-2   canary                                 75s
example-run-canary     example-run     canary   True       True               14m
```

To approve the new `ClusterApprovalRequest` object, let's reuse the same `approval.json` file to patch it:

```bash
kubectl patch clusterapprovalrequests example-run-2-canary --type='merge' --subresource=status --patch-file approval.json
```

Verify if the new object is approved:

```bash
kubectl get clusterapprovalrequest                                                                            
```

Your output should look similar to the following example:

```output
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

### [ResourcePlacement](#tab/resourceplacement)

To roll back to the previous version, create another staged update run referencing the earlier snapshot:

```yaml
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: StagedUpdateRun
metadata:
  name: web-app-rollback-v1-20
  namespace: my-app-namespace
spec:
  placementName: web-app-placement
  resourceSnapshotIndex: "0"
  stagedRolloutStrategyName: app-rollout-strategy
```

To complete the rollback, follow the same monitoring and approval process.

---

## Key differences between approaches

| Aspect | Cluster-Scoped | Namespace-Scoped |
|--------|----------------|------------------|
| **Strategy Resource** | `ClusterStagedUpdateStrategy` | `StagedUpdateStrategy` |
| **Update Run Resource** | `ClusterStagedUpdateRun` | `StagedUpdateRun` |
| **Target Placement** | `ClusterResourcePlacement` | `ResourcePlacement` |
| **Approval Resource** | `ClusterApprovalRequest` (short name: `careq`) | `ApprovalRequest` (short name: `areq`) |
| **Snapshot Resource** | `ClusterResourceSnapshot` | `ResourceSnapshot` |
| **Scope** | Cluster-wide | Namespace-bound |
| **Use Case** | Infrastructure rollouts | Application rollouts |
| **Permissions** | Cluster-admin level | Namespace-level |

## Clean up resources

When you're finished with this tutorial, you can clean up the resources you created:

```bash
# Clean up cluster-scoped resources
kubectl delete csur example-run example-run-2
kubectl delete csus example-strategy
kubectl delete crp example-placement
kubectl delete namespace test-namespace

# Clean up namespace-scoped resources
kubectl delete sur web-app-rollout-v1-21 web-app-rollback-v1-20 -n my-app-namespace
kubectl delete sus app-rollout-strategy -n my-app-namespace
kubectl delete rp web-app-placement -n my-app-namespace
kubectl delete namespace my-app-namespace
```

## Next steps

In this article, you learned how to use staged update runs to orchestrate rollouts across member clusters. You created staged update strategies for both cluster-scoped and namespace-scoped deployments, executed progressive rollouts, and performed rollbacks to previous versions.

To learn more about staged update runs and related concepts, see the following resources:

* [Defining a rollout strategy for cluster resource placement](./concepts-rollout-strategy.md)
* [How to understand the status of ClusterResourcePlacement](./howto-understand-placement.md)
* [How to configure monitoring and alerting for update runs](./howto-monitor-update-runs.md)

<!-- INTERNAL LINKS -->
[fleet-quickstart]: ./quickstart-create-fleet-and-members.md
[azure-cli-install]: /cli/azure/install-azure-cli
[az-extension-update]: /cli/azure/extension#az-extension-update
