---
title: "Define reusable Kubernetes resource placement rollout strategies using Azure Kubernetes Fleet Manager"
description: Learn how to create and manage reusable Azure Kubernetes Fleet Manager resource placement staged update strategies to control rollout sequence, approvals, and pauses across member clusters.
ms.topic: how-to
ms.date: 07/28/2026
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
# Customer intent: "As a DevOps engineer, I want to use staged update runs to control how workloads are deployed across multiple clusters, so that I can minimize risk and ensure reliable rollouts through progressive deployment strategies."
zone_pivot_groups: azure-portal-azure-cli
---

# Define reusable Azure Kubernetes Fleet Manager resource placement rollout strategies

**Applies to:** :heavy_check_mark: Fleet Manager with hub cluster

Platform administrators can control how Azure Kubernetes Fleet Manager rolls out resource placement updates to Fleet-managed clusters by defining staged update strategies made up of stages and groups. Within each stage and group, they can configure approvals and timed pauses to enforce governance and reduce rollout risk. Because the strategy is defined as a reusable resource, you can manage it independently from individual update runs and apply it consistently across different placements.

This article explains how to create and manage Azure Kubernetes Fleet Manager resource placement staged update strategies by using groups and stages.

You can complete the steps in this article using either the Azure portal or the Azure CLI.

> [!NOTE]
> You can use Fleet Manager's resource placement with AKS and Azure Arc-enabled Kubernetes clusters.

## Before you begin

* [!INCLUDE [free trial note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
* Read the [conceptual overview of resource placement](./concepts-resource-placement.md) to understand the concepts and terminology used in this article.
* You need a Fleet Manager with a hub cluster and member clusters. If you don't have one, see [Create an Azure Kubernetes Fleet Manager resource and join member clusters by using the Azure CLI](quickstart-create-fleet-and-members.md). You must label member clusters appropriately. 
* You need access to the Kubernetes API of the hub cluster. If you don't have access, see [Access the Kubernetes API for an Azure Kubernetes Fleet Manager hub cluster](./access-fleet-hub-cluster-kubernetes-api.md).

## Create a staged update strategy

For this article, create a cluster-scoped rollout strategy that consists of two stages - staging and canary. There's a one-hour wait time after the staging stage, with a before-stage approval for canary.

Creating namespace-scoped strategies (`StagedUpdateStrategy`) for use with namespace-scope placement (`ResourcePlacement`) is a similar experience, except you must select the hub cluster namespace from which the staged resources are distributed. 

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

1. Save the following YAML as `crp-two-stages-strategy.yaml`.

    ```yaml
    apiVersion: placement.kubernetes-fleet.io/v1
    kind: ClusterStagedUpdateStrategy
    metadata:
      name: two-stages-strategy
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
          beforeStageTasks:
            - type: Approval
    ```

1. Apply the placement manifest to the Fleet Manager hub cluster. 

    ```bash
    kubectl apply -f crp-two-stages-strategy.yaml
    ```

1. Check the status of the strategy resource.

    ```bash
    kubectl get clusterstagedupdatestrategy two-stages-strategy
    ```
    
    Your output should look similar to the following.
    
    ```output
    NAME                  AGE
    two-stages-strategy   47m
    ```

:::zone-end

:::zone target="docs" pivot="azure-portal"

1. In the Azure portal, go to your Fleet Manager.

1. On the service menu, under **Fleet Resources**, select **Resource placements** > **Staged rollout strategies**, and then select **Create**.

    > [!NOTE]
    > If you don't see **Fleet Resources**, your Fleet Manager doesn't have a hub cluster. For further information on how to add one, see [upgrade hub cluster type](./upgrade-hub-cluster-type.md).

1. Enter a name for the strategy.

1. Select the **Strategy scope**, choosing either **Cluster-scoped** or **Namespace-scoped**.

    * For **Namespace-scoped**, select the existing **Namespace** on the Fleet Manager hub cluster where the Kubernetes resources to distribute are staged. 

1. Select **Create Stage** and enter:
    * **Stage name** - name the stage - it must be unique across all stage names in the strategy.
    * **(Optional) Stage approvals** - select this option if you want to wait for an approval before this stage starts or after it completes.
    * **(Optional) Wait after stage** - select this option if you want to define a pause before moving to the next stage.
    * **(Optional) Wait duration** - select a predefined duration, or enter a custom value in seconds.
    * **Cluster label selector** - choose an existing member cluster label to use to select clusters for this stage.
    * **(Optional) Cluster ordering label** - choose an existing member cluster label to use to order the clusters within the stage.
    * **(Optional) Stage concurrency** - set how many clusters should be updated concurrently in the current stage.

    :::image type="content" source="./media/howto-placement-strategies/fleet-placement-create-strategy-add-stage.png" alt-text="A screenshot of the Azure portal showing a new stage being added to an Azure Kubernetes Fleet Manager placement staged rollout strategy." lightbox="./media/howto-placement-strategies/fleet-placement-create-strategy-add-stage.png":::

    > [!NOTE]
    > The maximum number of stages in each strategy is **31**.

1. Repeat until you add all stages to the strategy. Select **Create** to create the strategy. 

    :::image type="content" source="./media/howto-placement-strategies/fleet-placement-create-strategy-pending-create.png" alt-text="A screenshot of the Azure portal showing an Azure Kubernetes Fleet Manager placement staged rollout strategy with two stages that is pending creation." lightbox="./media/howto-placement-strategies/fleet-placement-create-strategy-pending-create.png":::

1. The page refreshes and the list displays the newly created strategy.

    :::image type="content" source="./media/howto-placement-strategies/fleet-placement-create-strategy-list-view.png" alt-text="A screenshot of the Azure portal showing a list of Azure Kubernetes Fleet Manager placement staged rollout strategies." lightbox="./media/howto-placement-strategies/fleet-placement-create-strategy-list-view.png":::

:::zone-end

## Next steps

In this article, you learned how to define reusable staged rollout strategies for Azure Kubernetes Fleet Manager resource placement. You configured strategy scope, created rollout stages, and added stage controls such as approvals, wait times, label selectors, ordering labels, and concurrency settings.

To learn more about controlling resource rollouts and related concepts, see the following resources:

* [Control cluster order for resource placement](./howto-staged-update-run.md)
* [Understand status fields and conditions for Fleet Manager resource placement](./howto-understand-placement.md)
* [View agent logs in Azure Kubernetes Fleet Manager](./view-fleet-agent-logs.md)

<!-- LINKS --->
[az-fleet-get-credentials]: /cli/azure/fleet#az-fleet-get-credentials
[az-account-set]: /cli/azure/account#az-account-set