---
title: "Use Taints on Member Clusters and Tolerations on Resource Placements in Azure Kubernetes Fleet Manager"
description: Learn how to use taints on MemberCluster resources and tolerations on ClusterResourcePlacement and ResourcePlacement resources in Azure Kubernetes Fleet Manager.
ms.topic: how-to
ms.date: 12/08/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
# Customer intent: "As a Kubernetes administrator, I want to manage taints and tolerations on member clusters and resource placements, so that I can control the propagation of resources in my Kubernetes Fleet environment."
---

# Use taints on member clusters and tolerations on resource placements

This article explains how to add or remove taints on `MemberCluster` resources and tolerations on `ClusterResourcePlacement` and `ResourcePlacement` resources in Azure Kubernetes Fleet Manager.

Taints and tolerations work together to ensure that member clusters receive only specified resources during resource propagation. Taints are applied to `MemberCluster` resources to prevent resources from being propagated to the member cluster. Tolerations are applied to `ClusterResourcePlacement` or `ResourcePlacement` resources to allow resources to be propagated to the member cluster, even if the member cluster has a taint.

## Prerequisites

* [!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
* Read the conceptual overviews for [taints](./concepts-fleet.md#taints) and [tolerations](./concepts-resource-propagation.md#using-tolerations).
* You must have a Fleet Manager with a hub cluster and member clusters. If you don't have this resource, follow [Quickstart: Create an Azure Kubernetes Fleet Manager resource and join member clusters](quickstart-create-fleet-and-members.md).
* You must gain access to the Kubernetes API of the hub cluster by following the steps in [Access the Kubernetes API for an Azure Kubernetes Fleet Manager hub cluster](./access-fleet-hub-cluster-kubernetes-api.md).

> [!NOTE]
> The examples in this article demonstrate both cluster-scoped (`ClusterResourcePlacement`) and namespace-scoped (`ResourcePlacement`) resource placement. Use `ClusterResourcePlacement` for cluster-wide resources and `ResourcePlacement` for namespace-scoped resources within a specific namespace.

## Add a taint to a member cluster

In this example, you add a taint to a `MemberCluster` resource. Then you try to propagate resources to the member cluster using a resource placement with a `PickAll` placement policy. The resources shouldn't be propagated to the member cluster because of the taint.

### [ClusterResourcePlacement](#tab/clusterresourceplacement)

1. Create a namespace to propagate to the member cluster by using the `kubectl create ns` command:

    ```bash
    kubectl create ns test-ns
    ```

2. Create a taint on the `MemberCluster` resource by using the following example code:

    ```yml
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: MemberCluster
    metadata:
      name: kind-cluster-1
    spec:
      identity:
        name: fleet-member-agent-cluster-1
        kind: ServiceAccount
        namespace: fleet-system
        apiGroup: ""
      taints:                    # Add a taint to the member cluster
        - key: test-key1
          value: test-value1
          effect: NoSchedule
    ```

3. Apply the taint to the `MemberCluster` resource by using the `kubectl apply` command. Be sure to replace the file name with the name of your file.

    ```bash
    kubectl apply -f member-cluster-taint.yml
    ```

4. Create a `PickAll` placement policy on the `ClusterResourcePlacement` resource by using the following example code:

    ```yml
    apiVersion: placement.kubernetes-fleet.io/v1beta1
    kind: ClusterResourcePlacement
    metadata:
      name: test-ns
    spec:
      resourceSelectors:
        - group: ""
          kind: Namespace
          version: v1          
          name: test-ns
      policy:
        placementType: PickAll
    ```

5. Apply the `ClusterResourcePlacement` resource by using the `kubectl apply` command. Be sure to replace the file name with the name of your file.

    ```bash
    kubectl apply -f cluster-resource-placement-pick-all.yml
    ```

6. Verify that the resources weren't propagated to the member cluster by checking the details of the `ClusterResourcePlacement` resource via the `kubectl describe` command:

    ```bash
    kubectl describe clusterresourceplacement test-ns
    ```

    Your output should look similar to the following example:

    ```output
    status:
      conditions:
      - lastTransitionTime: "2024-04-16T19:03:17Z"
        message: found all the clusters needed as specified by the scheduling policy
        observedGeneration: 2
        reason: SchedulingPolicyFulfilled
        status: "True"
        type: ClusterResourcePlacementScheduled
      - lastTransitionTime: "2024-04-16T19:03:17Z"
        message: All 0 cluster(s) are synchronized to the latest resources on the hub
          cluster
        observedGeneration: 2
        reason: SynchronizeSucceeded
        status: "True"
        type: ClusterResourcePlacementSynchronized
      - lastTransitionTime: "2024-04-16T19:03:17Z"
        message: There are no clusters selected to place the resources
        observedGeneration: 2
        reason: ApplySucceeded
        status: "True"
        type: ClusterResourcePlacementApplied
      observedResourceIndex: "0"
      selectedResources:
      - kind: Namespace
        name: test-ns
        version: v1
    ```

### [ResourcePlacement](#tab/resourceplacement)

1. To create a namespace on the hub cluster to contain the `ResourcePlacement` resource, run the following command:

    ```bash
    kubectl create ns app-ns
    ```

2. To create resources in the namespace to propagate to the member cluster, run the following command:

    ```bash
    kubectl create configmap app-config -n app-ns --from-literal=env=production
    ```

3. Create a taint on the `MemberCluster` resource by using the following example code:

    ```yml
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: MemberCluster
    metadata:
      name: kind-cluster-1
    spec:
      identity:
        name: fleet-member-agent-cluster-1
        kind: ServiceAccount
        namespace: fleet-system
        apiGroup: ""
      taints:                    # Add a taint to the member cluster
        - key: test-key1
          value: test-value1
          effect: NoSchedule
    ```

4. Apply the taint to the `MemberCluster` resource by using the `kubectl apply` command. Be sure to replace the file name with the name of your file.

    ```bash
    kubectl apply -f member-cluster-taint.yml
    ```

5. Create a `PickAll` placement policy on the `ResourcePlacement` resource by using the following example code:

    ```yml
    apiVersion: placement.kubernetes-fleet.io/v1beta1
    kind: ResourcePlacement
    metadata:
      name: app-config-placement
      namespace: app-ns
    spec:
      resourceSelectors:
        - group: ""
          kind: ConfigMap
          version: v1          
          name: app-config
      policy:
        placementType: PickAll
    ```

6. Apply the `ResourcePlacement` resource by using the `kubectl apply` command. Be sure to replace the file name with the name of your file.

    ```bash
    kubectl apply -f resource-placement-pick-all.yml
    ```

7. Verify that the resources weren't propagated to the member cluster by checking the details of the `ResourcePlacement` resource via the `kubectl describe` command:

    ```bash
    kubectl describe resourceplacement app-config-placement -n app-ns
    ```

    Your output should look similar to the following example:

    ```output
    Status:
      Conditions:
        Last Transition Time:   2024-04-16T19:03:17Z
        Message:                found all the clusters needed as specified by the scheduling policy
        Observed Generation:    2
        Reason:                 SchedulingPolicyFulfilled
        Status:                 True
        Type:                   ResourcePlacementScheduled
        Last Transition Time:   2024-04-16T19:03:17Z
        Message:                All 0 cluster(s) start rolling out the latest resource
        Observed Generation:    2
        Reason:                 RolloutStarted
        Status:                 True
        Type:                   ResourcePlacementRolloutStarted
        Last Transition Time:   2024-04-16T19:03:17Z
        Message:                There are no clusters selected to place the resources
        Observed Generation:    2
        Reason:                 ApplySucceeded
        Status:                 True
        Type:                   ResourcePlacementApplied
      Observed Resource Index:  0
      Selected Resources:
        Kind:       ConfigMap
        Name:       app-config
        Namespace:  app-ns
        Version:    v1
    ```

---

## Remove a taint from a member cluster

In this example, you remove the taint that you created [earlier in this article](#add-a-taint-to-a-member-cluster). This removal should automatically trigger the Fleet Manager scheduler to propagate the resources to the member cluster.

### [ClusterResourcePlacement](#tab/clusterresourceplacement)

1. Open your `MemberCluster` YAML file and remove the taint section.
2. Apply the changes to the `MemberCluster` resource by using the `kubectl apply` command. Be sure to replace the file name with the name of your file.

    ```bash
    kubectl apply -f member-cluster-taint.yml
    ```

3. Verify that the resources were propagated to the member cluster by checking the details of the `ClusterResourcePlacement` resource via the `kubectl describe` command:

    ```bash
    kubectl describe clusterresourceplacement test-ns
    ```

    Your output should look similar to the following example:

    ```output
    status:
      conditions:
      - lastTransitionTime: "2024-04-16T20:00:03Z"
        message: found all the clusters needed as specified by the scheduling policy
        observedGeneration: 2
        reason: SchedulingPolicyFulfilled
        status: "True"
        type: ClusterResourcePlacementScheduled
      - lastTransitionTime: "2024-04-16T20:02:57Z"
        message: All 1 cluster(s) are synchronized to the latest resources on the hub
          cluster
        observedGeneration: 2
        reason: SynchronizeSucceeded
        status: "True"
        type: ClusterResourcePlacementSynchronized
      - lastTransitionTime: "2024-04-16T20:02:57Z"
        message: Successfully applied resources to 1 member clusters
        observedGeneration: 2
        reason: ApplySucceeded
        status: "True"
        type: ClusterResourcePlacementApplied
      observedResourceIndex: "0"
      placementStatuses:
      - clusterName: kind-cluster-1
        conditions:
        - lastTransitionTime: "2024-04-16T20:02:52Z"
          message: 'Successfully scheduled resources for placement in kind-cluster-1 (affinity
            score: 0, topology spread score: 0): picked by scheduling policy'
          observedGeneration: 2
          reason: ScheduleSucceeded
          status: "True"
          type: Scheduled
        - lastTransitionTime: "2024-04-16T20:02:57Z"
          message: Successfully Synchronized work(s) for placement
          observedGeneration: 2
          reason: WorkSynchronizeSucceeded
          status: "True"
          type: WorkSynchronized
        - lastTransitionTime: "2024-04-16T20:02:57Z"
          message: Successfully applied resources
          observedGeneration: 2
          reason: ApplySucceeded
          status: "True"
          type: Applied
      selectedResources:
      - kind: Namespace
        name: test-ns
        version: v1
    ```

### [ResourcePlacement](#tab/resourceplacement)

1. Open your `MemberCluster` YAML file and remove the taint section.
2. Apply the changes to the `MemberCluster` resource by using the `kubectl apply` command. Be sure to replace the file name with the name of your file.

    ```bash
    kubectl apply -f member-cluster-taint.yml
    ```

3. Verify that the resources were propagated to the member cluster by checking the details of the `ResourcePlacement` resource via the `kubectl describe` command:

    ```bash
    kubectl describe resourceplacement app-config-placement -n app-ns
    ```

    Your output should look similar to the following example:

    ```output
    Status:
      Conditions:
        Last Transition Time:   2024-04-16T20:00:03Z
        Message:                found all the clusters needed as specified by the scheduling policy
        Observed Generation:    2
        Reason:                 SchedulingPolicyFulfilled
        Status:                 True
        Type:                   ResourcePlacementScheduled
        Last Transition Time:   2024-04-16T20:02:57Z
        Message:                All 1 cluster(s) start rolling out the latest resource
        Observed Generation:    2
        Reason:                 RolloutStarted
        Status:                 True
        Type:                   ResourcePlacementRolloutStarted
        Last Transition Time:   2024-04-16T20:02:57Z
        Message:                Successfully applied resources to 1 member clusters
        Observed Generation:    2
        Reason:                 ApplySucceeded
        Status:                 True
        Type:                   ResourcePlacementApplied
      Observed Resource Index:  0
      Placement Statuses:
        Cluster Name:  kind-cluster-1
        Conditions:
          Last Transition Time:  2024-04-16T20:02:52Z
          Message:               Successfully scheduled resources for placement in kind-cluster-1 (affinity score: 0, topology spread score: 0): picked by scheduling policy
          Observed Generation:   2
          Reason:                ScheduleSucceeded
          Status:                True
          Type:                  Scheduled
          Last Transition Time:  2024-04-16T20:02:57Z
          Message:               All of the works are synchronized to the latest
          Observed Generation:   2
          Reason:                AllWorkSynced
          Status:                True
          Type:                  WorkSynchronized
          Last Transition Time:  2024-04-16T20:02:57Z
          Message:               All corresponding work objects are applied
          Observed Generation:   2
          Reason:                AllWorkHaveBeenApplied
          Status:                True
          Type:                  Applied
      Selected Resources:
        Kind:       ConfigMap
        Name:       app-config
        Namespace:  app-ns
        Version:    v1
    ```

---

## Add a toleration to a resource placement

In this example, you add a toleration to a resource placement to propagate resources to a member cluster that has a taint. The toleration allows the resources to be propagated to the member cluster.

### [ClusterResourcePlacement](#tab/clusterresourceplacement)

1. Create a namespace to propagate to the member cluster by using the `kubectl create ns` command:

    ```bash
    kubectl create ns test-ns
    ```

2. Create a taint on the `MemberCluster` resource by using the following example code:

    ```yml
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: MemberCluster
    metadata:
      name: kind-cluster-1
    spec:
      identity:
        name: fleet-member-agent-cluster-1
        kind: ServiceAccount
        namespace: fleet-system
        apiGroup: ""
      taints:                    # Add a taint to the member cluster
        - key: test-key1
          value: test-value1
          effect: NoSchedule
    ```

3. Apply the taint to the `MemberCluster` resource by using the `kubectl apply` command. Be sure to replace the file name with the name of your file.

    ```bash
    kubectl apply -f member-cluster-taint.yml
    ```

4. Create a toleration on the `ClusterResourcePlacement` resource by using the following example code:

    ```yml
    apiVersion: placement.kubernetes-fleet.io/v1beta1
    kind: ClusterResourcePlacement
    metadata:
      name: test-ns
    spec:
      policy:
        placementType: PickAll
        tolerations:
          - key: test-key1
            operator: Exists
      resourceSelectors:
        - group: ""
          kind: Namespace
          name: test-ns
          version: v1
      revisionHistoryLimit: 10
      strategy:
        type: RollingUpdate
    ```

5. Apply the `ClusterResourcePlacement` resource by using the `kubectl apply` command. Be sure to replace the file name with the name of your file.

    ```bash
    kubectl apply -f cluster-resource-placement-toleration.yml
    ```

6. Verify that the resources were propagated to the member cluster by checking the details of the `ClusterResourcePlacement` resource via the `kubectl describe` command:

    ```bash
    kubectl describe clusterresourceplacement test-ns
    ```

    Your output should look similar to the following example:

    ```output
    status:
      conditions:
        - lastTransitionTime: "2024-04-16T20:16:10Z"
          message: found all the clusters needed as specified by the scheduling policy
          observedGeneration: 3
          reason: SchedulingPolicyFulfilled
          status: "True"
          type: ClusterResourcePlacementScheduled
        - lastTransitionTime: "2024-04-16T20:16:15Z"
          message: All 1 cluster(s) are synchronized to the latest resources on the hub
            cluster
          observedGeneration: 3
          reason: SynchronizeSucceeded
          status: "True"
          type: ClusterResourcePlacementSynchronized
        - lastTransitionTime: "2024-04-16T20:16:15Z"
          message: Successfully applied resources to 1 member clusters
          observedGeneration: 3
          reason: ApplySucceeded
          status: "True"
          type: ClusterResourcePlacementApplied
      observedResourceIndex: "0"
      placementStatuses:
        - clusterName: kind-cluster-1
          conditions:
            - lastTransitionTime: "2024-04-16T20:16:10Z"
              message: 'Successfully scheduled resources for placement in kind-cluster-1 (affinity
            score: 0, topology spread score: 0): picked by scheduling policy'
              observedGeneration: 3
              reason: ScheduleSucceeded
              status: "True"
              type: Scheduled
            - lastTransitionTime: "2024-04-16T20:16:15Z"
              message: Successfully Synchronized work(s) for placement
              observedGeneration: 3
              reason: WorkSynchronizeSucceeded
              status: "True"
              type: WorkSynchronized
            - lastTransitionTime: "2024-04-16T20:16:15Z"
              message: Successfully applied resources
              observedGeneration: 3
              reason: ApplySucceeded
              status: "True"
              type: Applied
      selectedResources:
        - kind: Namespace
          name: test-ns
          version: v1
    ```

### [ResourcePlacement](#tab/resourceplacement)

1. To create a namespace on the hub cluster to contain the `ResourcePlacement` resource, run the following command:

    ```bash
    kubectl create ns app-ns
    ```

2. To create resources in the namespace to propagate to the member cluster, run the following command:

    ```bash
    kubectl create configmap app-config -n app-ns --from-literal=env=production
    ```

3. Create a taint on the `MemberCluster` resource by using the following example code:

    ```yml
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: MemberCluster
    metadata:
      name: kind-cluster-1
    spec:
      identity:
        name: fleet-member-agent-cluster-1
        kind: ServiceAccount
        namespace: fleet-system
        apiGroup: ""
      taints:                    # Add a taint to the member cluster
        - key: test-key1
          value: test-value1
          effect: NoSchedule
    ```

4. Apply the taint to the `MemberCluster` resource by using the `kubectl apply` command. Be sure to replace the file name with the name of your file.

    ```bash
    kubectl apply -f member-cluster-taint.yml
    ```

5. Create a toleration on the `ResourcePlacement` resource by using the following example code:

    ```yml
    apiVersion: placement.kubernetes-fleet.io/v1beta1
    kind: ResourcePlacement
    metadata:
      name: app-config-placement
      namespace: app-ns
    spec:
      policy:
        placementType: PickAll
        tolerations:
          - key: test-key1
            operator: Exists
      resourceSelectors:
        - group: ""
          kind: ConfigMap
          name: app-config
          version: v1
      revisionHistoryLimit: 10
      strategy:
        type: RollingUpdate
    ```

6. Apply the `ResourcePlacement` resource by using the `kubectl apply` command. Be sure to replace the file name with the name of your file.

    ```bash
    kubectl apply -f resource-placement-toleration.yml
    ```

7. Verify that the resources were propagated to the member cluster by checking the details of the `ResourcePlacement` resource via the `kubectl describe` command:

    ```bash
    kubectl describe resourceplacement app-config-placement -n app-ns
    ```

    Your output should look similar to the following example:

    ```output
    Status:
      Conditions:
        Last Transition Time:   2024-04-16T20:16:10Z
        Message:                found all the clusters needed as specified by the scheduling policy
        Observed Generation:    3
        Reason:                 SchedulingPolicyFulfilled
        Status:                 True
        Type:                   ResourcePlacementScheduled
        Last Transition Time:   2024-04-16T20:16:15Z
        Message:                All 1 cluster(s) start rolling out the latest resource
        Observed Generation:    3
        Reason:                 RolloutStarted
        Status:                 True
        Type:                   ResourcePlacementRolloutStarted
        Last Transition Time:   2024-04-16T20:16:15Z
        Message:                Successfully applied resources to 1 member clusters
        Observed Generation:    3
        Reason:                 ApplySucceeded
        Status:                 True
        Type:                   ResourcePlacementApplied
      Observed Resource Index:  0
      Placement Statuses:
        Cluster Name:  kind-cluster-1
        Conditions:
          Last Transition Time:  2024-04-16T20:16:10Z
          Message:               Successfully scheduled resources for placement in kind-cluster-1 (affinity score: 0, topology spread score: 0): picked by scheduling policy
          Observed Generation:   3
          Reason:                ScheduleSucceeded
          Status:                True
          Type:                  Scheduled
          Last Transition Time:  2024-04-16T20:16:15Z
          Message:               All of the works are synchronized to the latest
          Observed Generation:   3
          Reason:                AllWorkSynced
          Status:                True
          Type:                  WorkSynchronized
          Last Transition Time:  2024-04-16T20:16:15Z
          Message:               All corresponding work objects are applied
          Observed Generation:   3
          Reason:                AllWorkHaveBeenApplied
          Status:                True
          Type:                  Applied
      Selected Resources:
        Kind:       ConfigMap
        Name:       app-config
        Namespace:  app-ns
        Version:    v1
    ```

---

## Related content

* [Open-source KubeFleet documentation](https://kubefleet.dev/docs/how-tos/taints-tolerations/)
