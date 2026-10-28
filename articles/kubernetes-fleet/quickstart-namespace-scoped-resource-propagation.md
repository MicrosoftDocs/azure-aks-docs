---
title: "Use Azure Kubernetes Fleet Manager ResourcePlacement to deploy namespace-scoped resources across multiple clusters"
titleSuffix: Azure Kubernetes Fleet Manager
description: This article describes how to use Azure Kubernetes Fleet Manager ResourcePlacement to deploy namespace-scoped resources across clusters in a fleet.
ms.date: 07/28/2026
author: weiweng
ms.author: weiweng
ms.service: azure-kubernetes-fleet-manager
ms.topic: how-to
zone_pivot_groups: azure-portal-azure-cli
# Customer intent: As an application developer, I want to deploy specific namespace-scoped resources across a fleet of clusters using ResourcePlacement, so that I can manage individual workloads and configurations independently within shared namespaces.
---

# Use Azure Kubernetes Fleet Manager ResourcePlacement to deploy namespace-scoped resources across multiple clusters

**Applies to:** :heavy_check_mark: Fleet Manager with hub cluster

Azure Kubernetes Fleet Manager `ResourcePlacement` enables you to distribute and synchronize individual namespace-scoped resources - such as ConfigMaps, Deployments, and Services - across specific clusters in your fleet without propagating an entire namespace. This approach gives you fine-grained control over what gets deployed where, simplifying multi-cluster configuration management and reducing manual overhead. This article walks through using `ResourcePlacement` to distribute namespace-scoped resources to member clusters.

To distribute cluster-scoped resources or a namespace and all its child resources, see [Use Azure Kubernetes Fleet Manager resource placement to deploy cluster-scoped resources across multiple clusters](./quickstart-resource-propagation.md).

You can complete the steps in this article using either the Azure portal or the Azure CLI.

> [!NOTE]
> You can use Fleet Manager's resource placement with AKS and Azure Arc-enabled Kubernetes clusters.

## Before you begin

* [!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
* Read the [conceptual overview of namespace-scoped resource placement](./concepts-namespace-scoped-resource-propagation.md) to understand the concepts and terminology used in this article.
* You need a Fleet Manager with a hub cluster and member clusters. If you don't have one, see [Create an Azure Kubernetes Fleet Manager resource and join member clusters by using the Azure CLI](quickstart-create-fleet-and-members.md).
* You need access to the Kubernetes API of the hub cluster. If you don't have access, see [Access the Kubernetes API for an Azure Kubernetes Fleet Manager hub cluster](./access-fleet-hub-cluster-kubernetes-api.md).

## Establish the namespace across member clusters

Before you can use `ResourcePlacement` to deploy namespace-scoped resources, the target namespace must exist on the member clusters. 

Let's see how to create a namespace on the Fleet Manager hub cluster and distribute it to member clusters by using a `ClusterResourcePlacement`. You ensure only the namespace is distributed by adding `selectionScope: NamespaceOnly` to the `resourceSelector`.

:::zone target="docs" pivot="azure-cli"

1. Set the following environment variables for your subscription ID, resource group, and Kubernetes Fleet resource:

    ```bash
    export SUBSCRIPTION_ID=<subscription-id>
    export GROUP=<resource-group-name>
    export FLEET=<fleet-name>
    ```

1. Set the default Azure subscription by using the [`az account set`][az-account-set] command:

    ```azurecli-interactive
    az account set \
        --subscription ${SUBSCRIPTION_ID}
    ```

1. Get the kubeconfig file of the Kubernetes Fleet hub cluster by using the [`az fleet get-credentials`][az-fleet-get-credentials] command:

    ```azurecli-interactive
    az fleet get-credentials \
        --resource-group ${GROUP} \
        --name ${FLEET}
    ```
    
    Your output should look similar to the following.
    
    ```output
    Merged "hub" as current context in /home/fleet/.kube/config
    ```
    
    > [!NOTE]
    > If you receive an error of type `InvalidHubOperation` with the message indicating the fleet is hubless, add a hub cluster. For further information, see [upgrade hub cluster type](./upgrade-hub-cluster-type.md).

1. Create a namespace on the hub cluster:

    ```bash
    kubectl create namespace test-app
    ```

1. Save the following YAML as `crp-distribute-namespace-only.yaml`.

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: ClusterResourcePlacement
    metadata:
      name: distribute-test-app-namespace
    spec:
      resourceSelectors:
        - group: ""
          kind: Namespace
          name: test-app
          version: v1
          selectionScope: NamespaceOnly
      policy:
        placementType: PickAll
    ```

1. Apply the placement manifest to the Fleet Manager hub cluster. 

    ```bash
    kubectl apply -f crp-distribute-namespace-only.yaml
    ```

    > [!NOTE]
    > The namespace rollout begins immediately when you apply the resource placement by using an implicit `RollingUpdate` strategy. To learn how to have additional controls over the rollout, see [defining a rollout strategy for resource placement](./concepts-rollout-strategy.md).

1. Verify that the namespace was distributed successfully:

    ```bash
    kubectl get clusterresourceplacement distribute-test-app-namespace
    ```

    Your output should look similar to the following example:

    ```output
    NAME                            GEN   SCHEDULED   SCHEDULED-GEN   AVAILABLE   AVAILABLE-GEN   AGE
    distribute-test-app-namespace   1     True        1               True        1               2m45s
    ```

:::zone-end

:::zone target="docs" pivot="azure-portal"

1. In the Azure portal, go to your Fleet Manager.

1. On the service menu, under **Fleet Resources**, select **Namespaces** > **+ Create**.

    > [!NOTE]
    > If you don't see **Fleet Resources**, your Fleet Manager doesn't have a hub cluster. For further information on how to add one, see [upgrade hub cluster type](./upgrade-hub-cluster-type.md).

1. In the menu, select **Namespace**, enter a **Name**, and then select **Create**.

    :::image type="content" source="./media/quickstart-resource-propagation/fleet-placement-create-namespace.png" lightbox="./media/quickstart-resource-propagation/fleet-placement-create-namespace.png" alt-text="Screenshot of the Azure portal showing a namespace called test-app being created on the Fleet Manager hub cluster.":::

    After a few moments, the page refreshes and the namespace appears in the list of namespaces on the Fleet Manager hub cluster. It's now ready to host any resources you want to distribute across member clusters.

1. On the service menu, under **Fleet Resources**, select **Resource placements** > **+ Create**.

1. On the **Basics** tab, configure the following options:

    - In **Placement details**, enter a name for the placement.
    - Under **Resource details**, enter the Group Version Kind (GVK) and name of the resource to distribute. In this sample, use the following values.

        ```yaml
        group: ""
        kind: Namespace
        version: v1          
        name: test-app
        selectionScope: NamespaceOnly
        ```

    - In **Member cluster selection**, choose **All clusters**.
    - For **Rollout**, leave the **Rolling update** strategy selected.
    
    :::image type="content" source="./media/quickstart-resource-propagation/fleet-placement-create-placement-basics-tab.png" lightbox="./media/quickstart-resource-propagation/fleet-placement-create-placement-basics-tab.png" alt-text="Screenshot of the Azure portal showing the completed Basics tab for cluster-scoped resource placement for a namespace called test-app.":::

1. Select **Next** to review the resulting `ClusterResourcePlacement` manifest. You can modify the manifest if required, validate by using the **Validate (dry run)** option, or select **Review + create** to proceed to final confirmation.

    :::image type="content" source="./media/quickstart-resource-propagation/fleet-placement-create-placement-review-yaml-tab.png" lightbox="./media/quickstart-resource-propagation/fleet-placement-create-placement-review-yaml-tab.png" alt-text="Screenshot of the Azure portal showing the Review YAML tab with a passed dry run validation for cluster-scoped resource placement for a namespace called test-app.":::

1. Select **Create** to start the distribution of the namespace immediately.

    :::image type="content" source="./media/quickstart-resource-propagation/fleet-placement-create-placement-review-create.png" lightbox="./media/quickstart-resource-propagation/fleet-placement-create-placement-review-create.png" alt-text="Screenshot of the Azure portal showing the Review and create tab for a cluster-scoped resource placement for a namespace called test-app.":::

    > [!NOTE]
    > The namespace resource rollout starts as soon as you apply the resource placement by using the selected `RollingUpdate` strategy. For more information about how to control the rollout, see [defining a rollout strategy for resource placement](./concepts-rollout-strategy.md).

1. The page refreshes and the **Resource placements** list displays the newly created placement. It shows the number of clusters selected and whether the fleet scheduler can fulfill the placement policy.

    :::image type="content" source="./media/quickstart-resource-propagation/fleet-placement-create-placement-list-view.png" lightbox="./media/quickstart-resource-propagation/fleet-placement-create-placement-list-view.png" alt-text="Screenshot of the Azure portal showing the resource placements list with a single resource placement called distribute-test-app.":::

1. View the rollout status of the placement by selecting the placement name in the list. Select individual clusters to view the resource rollout on that cluster.

    :::image type="content" source="./media/quickstart-resource-propagation/fleet-placement-create-placement-rollout-details.png" lightbox="./media/quickstart-resource-propagation/fleet-placement-create-placement-rollout-details.png" alt-text="Screenshot of the Azure portal showing the detailed rollout information of a resource placement called distribute-test-app.":::

On the selected Kubernetes clusters, you find the namespace deployed.

:::zone-end

## Distribute namespace-scoped resources to member clusters

Use the simple scenario of deploying two `ConfigMap` resources across selected clusters in the fleet. You must create the `ResourcePlacement` in the namespace as the resources to distribute.

:::zone target="docs" pivot="azure-cli"

1. Create two `ConfigMap` resources in the namespace on the hub cluster.

    ```bash
    kubectl create configmap app-config \
      --from-literal=environment=production \
      --from-literal=log-level=info \
      -n test-app
    
    kubectl create configmap feature-flags \
      --from-literal=new-ui=enabled \
      --from-literal=api-v2=disabled \
      -n test-app
    ```

1. Create a `ResourcePlacement` to propagate the ConfigMaps. Save the following YAML to a file named `app-configs-rp.yaml`:

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1beta1
    kind: ResourcePlacement
    metadata:
      name: distribute-app-configs
      namespace: test-app
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
    > Replace `membercluster1` and `membercluster2` with the actual names of your member clusters. Use `kubectl get memberclusters` to list available member clusters.

1. Apply the `ResourcePlacement` to the hub cluster:

    ```bash
    kubectl apply -f app-configs-rp.yaml
    ```

1. Check the progress of the resource propagation:

    ```bash
    kubectl get resourceplacement distribute-app-configs -n test-app
    ```

    Your output should look similar to the following.

    ```output
    NAME                     GEN   SCHEDULED   SCHEDULED-GEN   AVAILABLE   AVAILABLE-GEN   AGE
    distribute-app-configs   1     True        1               True        1               3m14s
    ```

1. View the details of the placement.

    ```bash
    kubectl describe resourceplacement distribute-app-configs -n test-app
    ```

    Your output should look similar to the following.

    ```output
    Name:         distribute-app-configs
    Namespace:    test-app
    Labels:       <none>
    Annotations:  <none>
    API Version:  placement.kubernetes-fleet.io/v1
    Kind:         ResourcePlacement
    Metadata:
      Creation Timestamp:  2026-07-24T05:18:56Z
      Finalizers:
        kubernetes-fleet.io/crp-cleanup
        kubernetes-fleet.io/scheduler-cleanup
      Generation:        1
      Resource Version:  1306099
      UID:               3a7b7f54-9ef0-4a2d-b8a6-62258ed63f78
    Spec:
      Policy:
        Cluster Names:
          aks-place-member-01-fm
          aks-place-member-02-fm
        Placement Type:  PickFixed
      Resource Selectors:
        Group:
        Kind:                  ConfigMap
        Name:                  app-config
        Selection Scope:       NamespaceWithResources
        Version:               v1
        Group:
        Kind:                  ConfigMap
        Name:                  feature-flags
        Selection Scope:       NamespaceWithResources
        Version:               v1
      Revision History Limit:  10
      Status Reporting Scope:  ClusterScopeOnly
      Strategy:
        Type:  RollingUpdate
    Status:
      Conditions:
        Last Transition Time:   2026-07-24T05:18:56Z
        Message:                found all cluster needed as specified by the scheduling policy, found 2 cluster(s)
        Observed Generation:    1
        Reason:                 SchedulingPolicyFulfilled
        Status:                 True
        Type:                   ResourcePlacementScheduled
        Last Transition Time:   2026-07-24T05:18:56Z
        Message:                All 2 cluster(s) start rolling out the latest resource
        Observed Generation:    1
        Reason:                 RolloutStarted
        Status:                 True
        Type:                   ResourcePlacementRolloutStarted
        Last Transition Time:   2026-07-24T05:18:56Z
        Message:                No override rules are configured for the selected resources
        Observed Generation:    1
        Reason:                 NoOverrideSpecified
        Status:                 True
        Type:                   ResourcePlacementOverridden
        Last Transition Time:   2026-07-24T05:18:56Z
        Message:                Works(s) are successfully created or updated in 2 target cluster(s)' namespaces
        Observed Generation:    1
        Reason:                 WorkSynchronized
        Status:                 True
        Type:                   ResourcePlacementWorkSynchronized
        Last Transition Time:   2026-07-24T05:18:56Z
        Message:                The selected resources are successfully applied to 2 cluster(s)
        Observed Generation:    1
        Reason:                 ApplySucceeded
        Status:                 True
        Type:                   ResourcePlacementApplied
        Last Transition Time:   2026-07-24T05:18:56Z
        Message:                The selected resources in 2 cluster(s) are available now
        Observed Generation:    1
        Reason:                 ResourceAvailable
        Status:                 True
        Type:                   ResourcePlacementAvailable
      Observed Resource Index:  0
      Placement Statuses:
        Cluster Name:  aks-place-member-01-fm
        Conditions:
          Last Transition Time:   2026-07-24T05:18:56Z
          Message:                Successfully scheduled resources for placement in "aks-place-member-01-fm": picked by scheduling policy
          Observed Generation:    1
          Reason:                 Scheduled
          Status:                 True
          Type:                   Scheduled
          Last Transition Time:   2026-07-24T05:18:56Z
          Message:                Detected the new changes on the resources and started the rollout process
          Observed Generation:    1
          Reason:                 RolloutStarted
          Status:                 True
          Type:                   RolloutStarted
          Last Transition Time:   2026-07-24T05:18:56Z
          Message:                No override rules are configured for the selected resources
          Observed Generation:    1
          Reason:                 NoOverrideSpecified
          Status:                 True
          Type:                   Overridden
          Last Transition Time:   2026-07-24T05:18:56Z
          Message:                All of the works are synchronized to the latest
          Observed Generation:    1
          Reason:                 AllWorkSynced
          Status:                 True
          Type:                   WorkSynchronized
          Last Transition Time:   2026-07-24T05:18:56Z
          Message:                All corresponding work objects are applied
          Observed Generation:    1
          Reason:                 AllWorkHaveBeenApplied
          Status:                 True
          Type:                   Applied
          Last Transition Time:   2026-07-24T05:18:56Z
          Message:                All corresponding work objects are available
          Observed Generation:    1
          Reason:                 AllWorkAreAvailable
          Status:                 True
          Type:                   Available
        Observed Resource Index:  0
        Cluster Name:             aks-place-member-02-fm
        Conditions:
          Last Transition Time:   2026-07-24T05:18:56Z
          Message:                Successfully scheduled resources for placement in "aks-place-member-02-fm": picked by scheduling policy
          Observed Generation:    1
          Reason:                 Scheduled
          Status:                 True
          Type:                   Scheduled
          Last Transition Time:   2026-07-24T05:18:56Z
          Message:                Detected the new changes on the resources and started the rollout process
          Observed Generation:    1
          Reason:                 RolloutStarted
          Status:                 True
          Type:                   RolloutStarted
          Last Transition Time:   2026-07-24T05:18:56Z
          Message:                No override rules are configured for the selected resources
          Observed Generation:    1
          Reason:                 NoOverrideSpecified
          Status:                 True
          Type:                   Overridden
          Last Transition Time:   2026-07-24T05:18:56Z
          Message:                All of the works are synchronized to the latest
          Observed Generation:    1
          Reason:                 AllWorkSynced
          Status:                 True
          Type:                   WorkSynchronized
          Last Transition Time:   2026-07-24T05:18:56Z
          Message:                All corresponding work objects are applied
          Observed Generation:    1
          Reason:                 AllWorkHaveBeenApplied
          Status:                 True
          Type:                   Applied
          Last Transition Time:   2026-07-24T05:18:56Z
          Message:                All corresponding work objects are available
          Observed Generation:    1
          Reason:                 AllWorkAreAvailable
          Status:                 True
          Type:                   Available
        Observed Resource Index:  0
      Selected Resources:
        Kind:       ConfigMap
        Name:       app-config
        Namespace:  test-app
        Version:    v1
        Kind:       ConfigMap
        Name:       feature-flags
        Namespace:  test-app
        Version:    v1
    Events:
      Type    Reason                        Age   From                  Message
      ----    ------                        ----  ----                  -------
      Normal  PlacementRolloutStarted       4m3s  placement-controller  Started rolling out the latest resources
      Normal  PlacementOverriddenSucceeded  4m3s  placement-controller  Placement has been successfully overridden
      Normal  PlacementWorkSynchronized     4m3s  placement-controller  Work(s) have been created or updated successfully for the selected cluster(s)
      Normal  PlacementApplied              4m3s  placement-controller  Resources have been applied to the selected cluster(s)
      Normal  PlacementAvailable            4m3s  placement-controller  Resources are available on the selected cluster(s)
      Normal  PlacementRolloutCompleted     4m3s  placement-controller  Placement has finished the rollout process and reached the desired status
    ```

:::zone-end

:::zone target="docs" pivot="azure-portal"

1. In the Azure portal, go to your Fleet Manager.

1. On the service menu, under **Fleet Resources**, select **Namespaces**.

    > [!NOTE]
    > If you don't see **Fleet Resources**, your Fleet Manager doesn't have a hub cluster. For further information on how to add one, see [upgrade hub cluster type](./upgrade-hub-cluster-type.md).

1. At the top of the namespace list, select **+ Create** > **Apply a YAML**, and use the following samples. 

    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: app-config
      namespace: test-app
    data:
      environment: production
      log-level: info
    ```

    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: feature-flags
      namespace: test-app
    data:
      new-ui: enabled
      api-v2: disabled
    ```

    Copy and paste the samples and apply them one at a time as shown in the following image.

    :::image type="content" source="./media/quickstart-resource-propagation/fleet-placement-namespace-apply-yaml.png" lightbox="./media/quickstart-resource-propagation/fleet-placement-namespace-apply-yaml.png" alt-text="Screenshot of the Azure portal showing the Apply with YAML dialog populated with a ConfigMap ready to be applied to the Fleet Manager hub cluster.":::

    The two ConfigMap resources are now ready to distribute to member clusters by using a `ResourcePlacement`.

1. On the service menu, under **Fleet Resources**, select **Resource placements** > **+ Create**.

1. On the **Basics** tab, configure the following options:

    - In **Placement details**, enter a name for the placement.
    - Under **Resource details**:
        - Set **Scope** as **Namespace-scoped**. 
        - For **Namespace**, select the `test-app` namespace.
        - Enter the Group Version Kind (GVK) and name of the resource to distribute. In this sample, use the following values.
    
          ```yaml
          group: ""
          kind: ConfigMap
          version: v1
          name: app-config
          ```

    - In **Member cluster selection**, for **Placement type**, select **Select specific clusters**.
    - Select **Select member clusters**, choose the member clusters that receive the resources, and then select **Select**.
    
    :::image type="content" source="./media/quickstart-resource-propagation/fleet-placement-create-placement-namespace-select-members.png" lightbox="./media/quickstart-resource-propagation/fleet-placement-create-placement-namespace-select-members.png" alt-text="Screenshot of the Azure portal showing the select member clusters dialog box for a PickFixed placement.":::

    - For **Rollout**, leave the **Rolling update** strategy selected.
    
    :::image type="content" source="./media/quickstart-resource-propagation/fleet-placement-create-placement-namespace-basics-tab.png" lightbox="./media/quickstart-resource-propagation/fleet-placement-create-placement-namespace-basics-tab.png" alt-text="Screenshot of the Azure portal showing the completed Basics tab for namespace-scoped resource placement for two configmap resources.":::

1. Select **Next** to review the resulting `ResourcePlacement` manifest.

1. Add the second ConfigMap to distribute to the `resourceSelectors` section in the YAML dialog.
    
    ```yaml
    group: ""
    kind: ConfigMap
    version: v1
    name: feature-flags
    ```

1. Before proceeding, validate the modified YAML by using the **Validate (dry run)** option. Select **Review + create** to proceed to final confirmation.

    :::image type="content" source="./media/quickstart-resource-propagation/fleet-placement-create-placement-namespace-review-yaml-tab.png" lightbox="./media/quickstart-resource-propagation/fleet-placement-create-placement-namespace-review-yaml-tab.png" alt-text="Screenshot of the Azure portal showing the Review YAML tab with a passed dry run validation for namespace-scoped resource placement for two configmap resources.":::

1. Select **Create** to start the distribution of the namespace immediately.

    :::image type="content" source="./media/quickstart-resource-propagation/fleet-placement-create-placement-namespace-review-create.png" lightbox="./media/quickstart-resource-propagation/fleet-placement-create-placement-namespace-review-create.png" alt-text="Screenshot of the Azure portal showing the Review and create tab for a namespace-scoped resource placement for two configmap resources.":::

    > [!NOTE]
    > The resource rollout begins immediately when you apply the resource placement by using the selected `RollingUpdate` strategy. To learn how to have additional controls over the rollout, see [defining a rollout strategy for resource placement](./concepts-rollout-strategy.md).

1. The page refreshes and the **Resource placements** list displays the newly created placement. It shows the number of clusters selected and whether the fleet scheduler can fulfill the placement policy.

    :::image type="content" source="./media/quickstart-resource-propagation/fleet-placement-create-placement-namespace-list-view.png" lightbox="./media/quickstart-resource-propagation/fleet-placement-create-placement-namespace-list-view.png" alt-text="Screenshot of the Azure portal showing the resource placements list with two resource placements. Our namespace-scope placement is listed and is called distribute-app-configs.":::

1. View the rollout status of the placement by selecting the placement name in the list. Select individual clusters to view the resource rollout on that cluster.

    :::image type="content" source="./media/quickstart-resource-propagation/fleet-placement-create-placement-namespace-rollout-details.png" lightbox="./media/quickstart-resource-propagation/fleet-placement-create-placement-rollout-details.png" alt-text="Screenshot of the Azure portal showing the detailed rollout information of a namespace-scoped resource placement called distribute-app-configs.":::

:::zone-end

You can confirm the distributed resources are present on member clusters by directly connecting to the member clusters and inspecting the `test-app` namespace to view the two `ConfigMap` resources.

## Delete the placement to remove resources

When you delete the resource placement on the Fleet Manager hub cluster, you remove the distributed resources from selected member clusters.

:::zone target="docs" pivot="azure-cli"

1. To remove the ConfigMap resources, delete the `ResourcePlacement` on the Fleet Manager hub cluster.

    ```bash
    kubectl delete resourceplacement distribute-app-configs
    ```

1. To remove the namespace from member clusters, delete the `ClusterResourcePlacement`.

    ```bash
    kubectl delete clusterresourceplacement distribute-test-app-namespace
    ```

:::zone-end

:::zone target="docs" pivot="azure-portal"

1. On the service menu, under **Fleet Resources**, select **Resource placements**.
1. In the resource placements list, select the placement and select **Delete**.
1. On **Delete**, verify that you chose the correct placement. When you're ready, select **Confirm delete** > **Delete**.

    :::image type="content" source="./media/quickstart-resource-propagation/fleet-placement-delete-placement.png" lightbox="./media/quickstart-resource-propagation/fleet-placement-delete-placement.png" alt-text="Screenshot of the Azure portal showing a resource placement called distribute-test-app being deleted.":::

1. The page refreshes and the placement no longer appears in the list. The resources are removed from member clusters.
1. Repeat this process to remove the namespace that you placed as the first step.

:::zone-end

## Related content

To learn more about resource placement, see the following resources:

* [Deploy cluster-scoped resources across multiple clusters](./quickstart-resource-propagation.md).
* [Understanding resource placement status output](./howto-understand-placement.md).
* [Intelligent cross-cluster Kubernetes resource placement based on member clusters' properties](./intelligent-resource-placement.md).
* [Controlling eviction and disruption for cluster resource placement](./concepts-eviction-disruption.md).
* [Defining a rollout strategy for a cluster resource placement](./concepts-rollout-strategy.md).
* [Cluster resource placement FAQs](./faq.md#cluster-resource-placement-faqs).
* [Open-source KubeFleet ResourcePlacement documentation](https://kubefleet.dev/docs/concepts/rp/).

<!-- LINKS --->
[az-fleet-get-credentials]: /cli/azure/fleet#az-fleet-get-credentials
[az-account-set]: /cli/azure/account#az-account-set