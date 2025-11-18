---
title: "Use Azure Kubernetes Fleet Manager ResourcePlacement to deploy namespace-scoped resources across multiple clusters (preview)"
titleSuffix: Azure Kubernetes Fleet Manager
description: This article describes how to use Azure Kubernetes Fleet Manager ResourcePlacement to deploy namespace-scoped resources across clusters in a fleet.
ms.date: 11/13/2025
author: weiweng
ms.author: weiweng
ms.service: azure-kubernetes-fleet-manager
ms.topic: how-to
# Customer intent: As an application developer, I want to deploy specific namespace-scoped resources across a fleet of clusters using ResourcePlacement, so that I can manage individual workloads and configurations independently within shared namespaces.
---

# Use Azure Kubernetes Fleet Manager ResourcePlacement to deploy namespace-scoped resources across multiple clusters (preview)

This article describes how to use Azure Kubernetes Fleet Manager `ResourcePlacement` to deploy namespace-scoped resources across clusters in a fleet.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## Prerequisites

* [!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
* Read the [conceptual overview of namespace-scoped resource placement](./concepts-namespace-scoped-resource-propagation.md) to understand the concepts and terminology used in this article.
* You need a Fleet Manager with a hub cluster and member clusters. If you don't have one, see [Create an Azure Kubernetes Fleet Manager resource and join member clusters by using the Azure CLI](quickstart-create-fleet-and-members.md).
* You need access to the Kubernetes API of the hub cluster. If you don't have access, see [Access the Kubernetes API for an Azure Kubernetes Fleet Manager hub cluster](./access-fleet-hub-cluster-kubernetes-api.md).

## Establish the namespace across member clusters

Before you can use `ResourcePlacement` to deploy namespace-scoped resources, the target namespace must exist on the member clusters. This example shows how to create a namespace on the hub cluster and propagate it to member clusters using `ClusterResourcePlacement`.

> [!NOTE]
> The following example uses the `placement.kubernetes-fleet.io/v1beta1` API version. The `selectionScope: NamespaceOnly` field is a preview feature available in v1beta1 and isn't available in the stable v1 API.

### [Azure CLI](#tab/azure-cli)

1. Create a namespace on the hub cluster:

    ```bash
    kubectl create namespace my-app
    ```

2. Create a `ClusterResourcePlacement` object to propagate the namespace to all member clusters. Save the following YAML to a file named `namespace-crp.yaml`:

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1beta1
    kind: ClusterResourcePlacement
    metadata:
      name: my-app-namespace
    spec:
      resourceSelectors:
        - group: ""
          kind: Namespace
          name: my-app
          version: v1
          selectionScope: NamespaceOnly
      policy:
        placementType: PickAll
    ```

3. Apply the `ClusterResourcePlacement` to the hub cluster:

    ```bash
    kubectl apply -f namespace-crp.yaml
    ```

4. Verify that the namespace was propagated successfully:

    ```bash
    kubectl get clusterresourceplacement my-app-namespace
    ```

    Your output should look similar to the following example:

    ```output
    NAME                GEN   SCHEDULED   SCHEDULED-GEN   AVAILABLE   AVAILABLE-GEN   AGE
    my-app-namespace    1     True        1               True        1               15s
    ```

---

## Use ResourcePlacement to place namespace-scoped resources

The `ResourcePlacement` object is created within a namespace on the hub cluster and is used to propagate specific namespace-scoped resources to member clusters. This example demonstrates how to propagate ConfigMaps to specific member clusters using the `ResourcePlacement` object with a `PickFixed` placement policy.

For more information, see [namespace-scoped resource placement using Azure Kubernetes Fleet Manager ResourcePlacement](./concepts-namespace-scoped-resource-propagation.md).

### [Azure CLI](#tab/azure-cli)

1. Create ConfigMaps in the namespace on the hub cluster. These ConfigMaps will be propagated to the selected member clusters:

    ```bash
    kubectl create configmap app-config \
      --from-literal=environment=production \
      --from-literal=log-level=info \
      -n my-app
    
    kubectl create configmap feature-flags \
      --from-literal=new-ui=enabled \
      --from-literal=api-v2=disabled \
      -n my-app
    ```

2. Create a `ResourcePlacement` object to propagate the ConfigMaps. Save the following YAML to a file named `app-configs-rp.yaml`:

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1beta1
    kind: ResourcePlacement
    metadata:
      name: app-configs
      namespace: my-app
    spec:
      resourceSelectors:
        - group: ""
          kind: ConfigMap
          version: v1
          name: app-config
        - group: ""
          kind: ConfigMap
          version: v1
          name: feature-flags
      policy:
        placementType: PickFixed
        clusterNames:
          - membercluster1
          - membercluster2
    ```

    > [!NOTE]
    > Replace `membercluster1` and `membercluster2` with the actual names of your member clusters. You can list available member clusters using `kubectl get memberclusters`.

3. Apply the `ResourcePlacement` to the hub cluster:

    ```bash
    kubectl apply -f app-configs-rp.yaml
    ```

4. Check the progress of the resource propagation:

    ```bash
    kubectl get resourceplacement app-configs -n my-app
    ```

    Your output should look similar to the following example:

    ```output
    NAME          GEN   SCHEDULED   SCHEDULED-GEN   AVAILABLE   AVAILABLE-GEN   AGE
    app-configs   1     True        1               True        1               20s
    ```

5. View the details of the placement object:

    ```bash
    kubectl describe resourceplacement app-configs -n my-app
    ```

    Your output should look similar to the following example:

    ```output
    Name:         app-configs
    Namespace:    my-app
    Labels:       <none>
    Annotations:  <none>
    API Version:  placement.kubernetes-fleet.io/v1beta1
    Kind:         ResourcePlacement
    Metadata:
      Creation Timestamp:  2025-11-13T22:08:12Z
      Finalizers:
        kubernetes-fleet.io/crp-cleanup
        kubernetes-fleet.io/scheduler-cleanup
      Generation:        1
      Resource Version:  12345
      UID:               cec941f1-e48a-4045-b5dd-188bfc1a830f
    Spec:
      Policy:
        Cluster Names:
          membercluster1
          membercluster2
        Placement Type:  PickFixed
      Resource Selectors:
        Group:                 
        Kind:                  ConfigMap
        Name:                  app-config
        Version:               v1
        Group:                 
        Kind:                  ConfigMap
        Name:                  feature-flags
        Version:               v1
      Revision History Limit:  10
      Strategy:
        Type:  RollingUpdate
    Status:
      Conditions:
        Last Transition Time:   2025-11-13T22:08:12Z
        Message:                found all cluster needed as specified by the scheduling policy, found 2 cluster(s)
        Observed Generation:    1
        Reason:                 SchedulingPolicyFulfilled
        Status:                 True
        Type:                   ResourcePlacementScheduled
        Last Transition Time:   2025-11-13T22:08:12Z
        Message:                All 2 cluster(s) start rolling out the latest resource
        Observed Generation:    1
        Reason:                 RolloutStarted
        Status:                 True
        Type:                   ResourcePlacementRolloutStarted
        Last Transition Time:   2025-11-13T22:08:13Z
        Message:                No override rules are configured for the selected resources
        Observed Generation:    1
        Reason:                 NoOverrideSpecified
        Status:                 True
        Type:                   ResourcePlacementOverridden
        Last Transition Time:   2025-11-13T22:08:13Z
        Message:                Works(s) are succcesfully created or updated in 2 target cluster(s)' namespaces
        Observed Generation:    1
        Reason:                 WorkSynchronized
        Status:                 True
        Type:                   ResourcePlacementWorkSynchronized
        Last Transition Time:   2025-11-13T22:08:13Z
        Message:                The selected resources are successfully applied to 2 cluster(s)
        Observed Generation:    1
        Reason:                 ApplySucceeded
        Status:                 True
        Type:                   ResourcePlacementApplied
        Last Transition Time:   2025-11-13T22:08:13Z
        Message:                The selected resources in 2 cluster(s) are available now
        Observed Generation:    1
        Reason:                 ResourceAvailable
        Status:                 True
        Type:                   ResourcePlacementAvailable
      Observed Resource Index:  0
      Placement Statuses:
        Cluster Name:  membercluster1
        Conditions:
          Last Transition Time:   2025-11-13T22:08:12Z
          Message:                Successfully scheduled resources for placement in "membercluster1": picked by scheduling policy
          Observed Generation:    1
          Reason:                 Scheduled
          Status:                 True
          Type:                   Scheduled
          Last Transition Time:   2025-11-13T22:08:12Z
          Message:                Detected the new changes on the resources and started the rollout process
          Observed Generation:    1
          Reason:                 RolloutStarted
          Status:                 True
          Type:                   RolloutStarted
          Last Transition Time:   2025-11-13T22:08:13Z
          Message:                No override rules are configured for the selected resources
          Observed Generation:    1
          Reason:                 NoOverrideSpecified
          Status:                 True
          Type:                   Overridden
          Last Transition Time:   2025-11-13T22:08:13Z
          Message:                All of the works are synchronized to the latest
          Observed Generation:    1
          Reason:                 AllWorkSynced
          Status:                 True
          Type:                   WorkSynchronized
          Last Transition Time:   2025-11-13T22:08:13Z
          Message:                All corresponding work objects are applied
          Observed Generation:    1
          Reason:                 AllWorkHaveBeenApplied
          Status:                 True
          Type:                   Applied
          Last Transition Time:   2025-11-13T22:08:13Z
          Message:                All corresponding work objects are available
          Observed Generation:    1
          Reason:                 AllWorkAreAvailable
          Status:                 True
          Type:                   Available
        Observed Resource Index:  0
        Cluster Name:             membercluster2
        Conditions:
          Last Transition Time:   2025-11-13T22:08:12Z
          Message:                Successfully scheduled resources for placement in "membercluster2": picked by scheduling policy
          Observed Generation:    1
          Reason:                 Scheduled
          Status:                 True
          Type:                   Scheduled
          Last Transition Time:   2025-11-13T22:08:12Z
          Message:                Detected the new changes on the resources and started the rollout process
          Observed Generation:    1
          Reason:                 RolloutStarted
          Status:                 True
          Type:                   RolloutStarted
          Last Transition Time:   2025-11-13T22:08:13Z
          Message:                No override rules are configured for the selected resources
          Observed Generation:    1
          Reason:                 NoOverrideSpecified
          Status:                 True
          Type:                   Overridden
          Last Transition Time:   2025-11-13T22:08:13Z
          Message:                All of the works are synchronized to the latest
          Observed Generation:    1
          Reason:                 AllWorkSynced
          Status:                 True
          Type:                   WorkSynchronized
          Last Transition Time:   2025-11-13T22:08:13Z
          Message:                All corresponding work objects are applied
          Observed Generation:    1
          Reason:                 AllWorkHaveBeenApplied
          Status:                 True
          Type:                   Applied
          Last Transition Time:   2025-11-13T22:08:13Z
          Message:                All corresponding work objects are available
          Observed Generation:    1
          Reason:                 AllWorkAreAvailable
          Status:                 True
          Type:                   Available
        Observed Resource Index:  0
      Selected Resources:
        Kind:       ConfigMap
        Name:       app-config
        Namespace:  my-app
        Version:    v1
        Kind:       ConfigMap
        Name:       feature-flags
        Namespace:  my-app
        Version:    v1
    Events:
      Type    Reason                     Age   From                            Message
      ----    ------                     ----  ----                            -------
      Normal  PlacementRolloutStarted       37s   placement-controller  Started rolling out the latest resources
      Normal  PlacementOverriddenSucceeded  36s   placement-controller  Placement has been successfully overridden
      Normal  PlacementWorkSynchronized     36s   placement-controller  Work(s) have been created or updated successfully for the selected cluster(s)
      Normal  PlacementApplied              36s   placement-controller  Resources have been applied to the selected cluster(s)
      Normal  PlacementAvailable            36s   placement-controller  Resources are available on the selected cluster(s)
      Normal  PlacementRolloutCompleted     36s   placement-controller  Placement has finished the rollout process and reached the desired status
    ```

---

## Verify resources on member clusters

You can verify that the ConfigMaps were successfully propagated to the member clusters.

### [Azure CLI](#tab/azure-cli)

1. Get the credentials for one of your member clusters:

    ```bash
    az aks get-credentials --resource-group <resource-group> --name membercluster1
    ```

2. Verify that the namespace exists:

    ```bash
    kubectl get namespace my-app
    ```

3. Verify that the ConfigMaps exist in the namespace:

    ```bash
    kubectl get configmap -n my-app
    ```

    Your output should show both ConfigMaps:

    ```output
    NAME             DATA   AGE
    app-config       2      2m
    feature-flags    2      2m
    ```

4. View the contents of a ConfigMap:

    ```bash
    kubectl describe configmap app-config -n my-app
    ```

---

## Clean up resources

### [Azure CLI](#tab/azure-cli)

If you no longer want to use the `ResourcePlacement` objects, you can delete them using the `kubectl delete` command:

```bash
kubectl delete resourceplacement app-configs -n my-app
```

To also remove the namespace `ClusterResourcePlacement`:

```bash
kubectl delete clusterresourceplacement my-app-namespace
```

To remove the namespace and all resources within it from the hub cluster:

```bash
kubectl delete namespace my-app
```

---

## Related content

To learn more about namespace-scoped resource placement, see the following resources:

* [Using ResourcePlacement to deploy namespace-scoped resources](./concepts-namespace-scoped-resource-propagation.md)
* [Using ClusterResourcePlacement to deploy cluster-scoped resources](./concepts-resource-propagation.md)
* [Understanding resource placement status output](./howto-understand-placement.md)
* [Use overrides to customize namespace-scoped resources](./resource-override.md)
* [Defining a rollout strategy for resource placement](./concepts-rollout-strategy.md)
* [Cluster resource placement FAQs](./faq.md#cluster-resource-placement-faqs)
