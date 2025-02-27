---
title: "Propagate Resources from an Azure Kubernetes Fleet Manager Hub Cluster to Member Clusters"
description: This article provides an overview of how to propagate resources from an Azure Kubernetes Fleet Manager hub cluster to member clusters.
ms.date: 03/28/2024
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.custom:
  - build-2024
ms.topic: how-to
---

# Propagate resources from an Azure Kubernetes Fleet Manager hub cluster to member clusters

This article describes how to propagate resources from an Azure Kubernetes Fleet Manager (Kubernetes Fleet) hub cluster to member clusters.

## Prerequisites

* [!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
* Read the [conceptual overview of resource propagation](./concepts-resource-propagation.md) to understand the concepts and terminology used in this article.
* You need a Kubernetes Fleet resource with a hub cluster and member clusters. If you don't have one, see [Create an Azure Kubernetes Fleet Manager resource and join member clusters by using the Azure CLI](quickstart-create-fleet-and-members.md).
* Member clusters must be labeled appropriately in the hub cluster to match the desired selection criteria. Example labels include region, environment, team, availability zones, node availability, or anything else that you want.
* You need access to the Kubernetes API of the hub cluster. If you don't have access, see [Access the Kubernetes API for an Azure Kubernetes Fleet Manager hub cluster](./access-fleet-hub-cluster-kubernetes-api.md).

## Use the ClusterResourcePlacement API to propagate resources to member clusters

The `ClusterResourcePlacement` API object is created in the hub cluster and is used to propagate resources to member clusters. It specifies the resources to propagate and the placement policy to use when you're selecting member clusters. This example demonstrates how to propagate a namespace to member clusters by using the `ClusterResourcePlacement` API object with a `PickAll` placement policy.

For more information, see [Kubernetes resource placement from hub cluster to member clusters](./concepts-resource-propagation.md) and the [open-source Kubernetes Fleet documentation](https://github.com/Azure/fleet/blob/main/docs/concepts/ClusterResourcePlacement/README.md).

### [Azure CLI](#tab/azure-cli)

1. Create a namespace to place onto the member clusters by using the `kubectl create namespace` command. The following example creates a namespace named `my-namespace`:

    ```bash
    kubectl create namespace my-namespace
    ```

2. Create a `ClusterResourcePlacement` API object in the hub cluster to propagate the namespace to the member clusters and deploy it by using the `kubectl apply -f` command. In the following example, `ClusterResourcePlacement` creates an object named `crp` and uses the `my-namespace` namespace with a `PickAll` placement policy to propagate the namespace to all member clusters:

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: ClusterResourcePlacement
    metadata:
      name: crp
    spec:
      resourceSelectors:
        - group: ""
          kind: Namespace
          version: v1          
          name: my-namespace
      policy:
        placementType: PickAll
    EOF
    ```

3. Check the progress of the resource propagation by using the `kubectl get clusterresourceplacement` command. The following example checks the status of the `ClusterResourcePlacement` object named `crp`:

    ```bash
    kubectl get clusterresourceplacement crp
    ```

    Your output should look similar to the following example:

    ```output
    NAME   GEN   SCHEDULED   SCHEDULEDGEN   APPLIED   APPLIEDGEN   AGE
    crp    2     True        2              True      2            10s
    ```

4. View the details of the `crp` object by using the `kubectl describe crp` command. The following example describes the `ClusterResourcePlacement` object named `crp`:

    ```bash
    kubectl describe clusterresourceplacement crp
    ```

    Your output should look similar to the following example:

    ```output
    Name:         crp
    Namespace:    
    Labels:       <none>
    Annotations:  <none>
    API Version:  placement.kubernetes-fleet.io/v1
    Kind:         ClusterResourcePlacement
    Metadata:
      Creation Timestamp:  2024-04-01T18:55:31Z
      Finalizers:
        kubernetes-fleet.io/crp-cleanup
        kubernetes-fleet.io/scheduler-cleanup
      Generation:        2
      Resource Version:  6949
      UID:               815b1d81-61ae-4fb1-a2b1-06794be3f986
    Spec:
      Policy:
        Placement Type:  PickAll
      Resource Selectors:
        Group:                 
        Kind:                  Namespace
        Name:                  my-namespace
        Version:               v1
      Revision History Limit:  10
      Strategy:
        Type:  RollingUpdate
    Status:
      Conditions:
        Last Transition Time:   2024-04-01T18:55:31Z
        Message:                found all the clusters needed as specified by the scheduling policy
        Observed Generation:    2
        Reason:                 SchedulingPolicyFulfilled
        Status:                 True
        Type:                   ClusterResourcePlacementScheduled
        Last Transition Time:   2024-04-01T18:55:36Z
        Message:                All 3 cluster(s) are synchronized to the latest resources on the hub cluster
        Observed Generation:    2
        Reason:                 SynchronizeSucceeded
        Status:                 True
        Type:                   ClusterResourcePlacementSynchronized
        Last Transition Time:   2024-04-01T18:55:36Z
        Message:                Successfully applied resources to 3 member clusters
        Observed Generation:    2
        Reason:                 ApplySucceeded
        Status:                 True
        Type:                   ClusterResourcePlacementApplied
      Observed Resource Index:  0
      Placement Statuses:
        Cluster Name:  membercluster1
        Conditions:
          Last Transition Time:  2024-04-01T18:55:31Z
          Message:               Successfully scheduled resources for placement in membercluster1 (affinity score: 0, topology spread score: 0): picked by scheduling policy
          Observed Generation:   2
          Reason:                ScheduleSucceeded
          Status:                True
          Type:                  ResourceScheduled
          Last Transition Time:  2024-04-01T18:55:36Z
          Message:               Successfully Synchronized work(s) for placement
          Observed Generation:   2
          Reason:                WorkSynchronizeSucceeded
          Status:                True
          Type:                  WorkSynchronized
          Last Transition Time:  2024-04-01T18:55:36Z
          Message:               Successfully applied resources
          Observed Generation:   2
          Reason:                ApplySucceeded
          Status:                True
          Type:                  ResourceApplied
        Cluster Name:            membercluster2
        Conditions:
          Last Transition Time:  2024-04-01T18:55:31Z
          Message:               Successfully scheduled resources for placement in membercluster2 (affinity score: 0, topology spread score: 0): picked by scheduling policy
          Observed Generation:   2
          Reason:                ScheduleSucceeded
          Status:                True
          Type:                  ResourceScheduled
          Last Transition Time:  2024-04-01T18:55:36Z
          Message:               Successfully Synchronized work(s) for placement
          Observed Generation:   2
          Reason:                WorkSynchronizeSucceeded
          Status:                True
          Type:                  WorkSynchronized
          Last Transition Time:  2024-04-01T18:55:36Z
          Message:               Successfully applied resources
          Observed Generation:   2
          Reason:                ApplySucceeded
          Status:                True
          Type:                  ResourceApplied
        Cluster Name:            membercluster3
        Conditions:
          Last Transition Time:  2024-04-01T18:55:31Z
          Message:               Successfully scheduled resources for placement in membercluster3 (affinity score: 0, topology spread score: 0): picked by scheduling policy
          Observed Generation:   2
          Reason:                ScheduleSucceeded
          Status:                True
          Type:                  ResourceScheduled
          Last Transition Time:  2024-04-01T18:55:36Z
          Message:               Successfully Synchronized work(s) for placement
          Observed Generation:   2
          Reason:                WorkSynchronizeSucceeded
          Status:                True
          Type:                  WorkSynchronized
          Last Transition Time:  2024-04-01T18:55:36Z
          Message:               Successfully applied resources
          Observed Generation:   2
          Reason:                ApplySucceeded
          Status:                True
          Type:                  ResourceApplied
      Selected Resources:
        Kind:     Namespace
        Name:     my-namespace
        Version:  v1
    Events:
      Type    Reason                     Age   From                                   Message
      ----    ------                     ----  ----                                   -------
      Normal  PlacementScheduleSuccess   108s  cluster-resource-placement-controller  Successfully scheduled the placement
      Normal  PlacementSyncSuccess       103s  cluster-resource-placement-controller  Successfully synchronized the placement
      Normal  PlacementRolloutCompleted  103s  cluster-resource-placement-controller  Resources have been applied to the selected clusters
    ````

### [Azure portal](#tab/azure-portal)

1. In the Azure portal, go to your Kubernetes Fleet resource.
1. On the service menu, under **Fleet Resources**, select **Resource placements** > **Create**.
1. Replace the placeholder values with the following YAML, and then select **Add**.

    ```YAML
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: ClusterResourcePlacement
    metadata:
      name: crp
    spec:
      resourceSelectors:
        - group: ""
          kind: Namespace
          version: v1          
          name: my-namespace
      policy:
        placementType: PickAll
    ```

1. Verify that the cluster resource placement was created successfully.

    :::image type="content" source="./media/quickstart-resource-propagation/crp-success-inline.png" lightbox="./media/quickstart-resource-propagation/crp-success.png" alt-text="Screenshot of the Azure portal pane for cluster resource placements, showing a successfully created cluster resource placement.":::

1. To see more details on the placement of an individual cluster resource, select it from the list.

    :::image type="content" source="./media/quickstart-resource-propagation/crp-details-inline.png" lightbox="./media/quickstart-resource-propagation/crp-details.png" alt-text="Screenshot of the Azure portal overview pane for an individual cluster resource placement, showing events and details.":::

1. You can view additional details on the cluster resource placement's snapshots, bindings, works, and scheduling policy snapshots by using the individual tabs. For example, select the **Cluster Resources Snapshots** tab.

    :::image type="content" source="./media/quickstart-resource-propagation/crp-snapshot-inline.png" lightbox="./media/quickstart-resource-propagation/crp-snapshot.png" alt-text="Screenshot of the Azure portal page for a cluster resource placement, with the Cluster Resources Snapshots tab selected.":::

---

## Clean up resources

### [Azure CLI](#tab/azure-cli)

If you no longer want to use the `ClusterResourcePlacement` object, you can delete it by using the `kubectl delete` command. The following example deletes the `ClusterResourcePlacement` object named `crp`:

```bash
kubectl delete clusterresourceplacement crp
```

### [Azure portal](#tab/azure-portal)

If you no longer want to use your cluster resource placement, you can delete it from the Azure portal:

1. On the service menu, under **Fleet Resources**, select **Resource placements**.
1. Select the cluster resource placement objects that you want to delete, and then select **Delete**.
1. On the **Delete** tab, verify that you chose the correct objects. When you're ready, select **Confirm delete** > **Delete**.

---

## Related content

To learn more about resource propagation, see the following resources:

* [Intelligent cross-cluster Kubernetes resource placement based on member clusters' properties](./intelligent-resource-placement.md)
* [Open-source Kubernetes Fleet documentation](https://github.com/Azure/fleet/blob/main/docs/concepts/ClusterResourcePlacement/README.md)
