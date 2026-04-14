---
title: Blue-Green Node Pool Upgrades in Azure Kubernetes Service (AKS) (preview)
description: Perform upgrades of AKS node pools using a blue-green deployment strategy to ensure workload availability during updates.
ms.topic: how-to
ms.subservice: aks-upgrade
ms.custom: azure-kubernetes-service
ms.date: 11/06/2024
author: davidsmatlak
ms.author: davidsmatlak
ms.reviewer: schaffererin
# Customer intent: "As a Kubernetes administrator, I want to perform upgrades of my AKS node pools using a blue-green deployment strategy to ensure workload availability during updates."
---

# Blue-green node pool upgrades in Azure Kubernetes Service (AKS) (preview)

Blue-green upgrades enable you to upgrade your AKS node pools side by side by creating a parallel _green_ node pool with the new configuration while maintaining the existing _blue_ node pool. This strategy allows you to test and validate the new configuration before switching traffic, with the ability to quickly roll back if issues arise.

This article explains when to use blue-green upgrades, how the process works, configuration options, and considerations for using this upgrade strategy.

## When to use blue-green upgrades

> [!NOTE]
> Keep in mind that blue-green upgrades require double the node capacity during the upgrade process, which can lead to increased costs and resource requirements.

Consider blue-green upgrades when:

- You require granular testing and verification of workloads batch by batch.
- You need to validate new node configurations before switching production traffic.
- You want instant rollback capability without reprovisioning nodes.
- You're upgrading critical production workloads that can't tolerate disruption.
- You need to test application compatibility with new Kubernetes versions.

If you're currently using a manual blue-green deployment process for node pool upgrades and want to automate this workflow, consider using AKS blue-green node pool upgrades instead. For more information about the manual blue green upgrade process, see [Manual blue-green node pool upgrades](./how-does-upgrade-happen.md#blue-green-node-pool-upgrades-manual).

## When to use standard rolling upgrades

Standard rolling upgrades might be more appropriate in the following scenarios:

- Development or test environments with downtime tolerance.
- Cost-sensitive deployments where temporary doubling is prohibitive.
- Simple stateless applications with good disruption handling.
- Environments with limited available quota or capacity.

## Prerequisites

- Sufficient quota for doubling node pool capacity.
- Azure CLI version 2.64.0 or higher. Find your version using the `az --version` command. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
- The [`aks-preview` Azure CLI extension](#install-the-aks-preview-azure-cli-extension) installed and updated to the latest version.
- API version `2025-08-02-preview` or later.
- [Cluster autoscaler](./cluster-autoscaler-overview.md) configured (recommended, but not required).

### Install the `aks-preview` Azure CLI extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Install or update the `aks-preview` extension using the [`az extension add`](/cli/azure/extension#az-extension-add) and [`az extension update`](/cli/azure/extension#az-extension-update) commands.

```azurecli-interactive
# Install the aks-preview extension
az extension add --name aks-preview

# Update the aks-preview extension
az extension update --name aks-preview
```

## Supported features for blue-green upgrades

Blue-green upgrades currently support the following features:

- [Kubernetes version upgrades](./upgrade-cluster.md)
- [Node image upgrades](./node-image-upgrade.md)
- [System and user node pools](./use-system-pools.md)
- Manual commit and rollback control
- [Cluster autoscaler](./cluster-autoscaler.md)
- [Availability zones](/azure/reliability/reliability-aks#availability-zone-support)
- [PodDisruptionBudgets](./operator-best-practices-scheduler.md#plan-for-availability-using-pod-disruption-budgets)
- [Autoupgrade channels](./auto-upgrade-cluster.md) and [Planned Maintenance windows](./planned-maintenance.md)
- [AKS Communication Manager](./aks-communication-manager.md)

## Blue-green upgrade limitations and considerations

Blue-green upgrades currently don't support the following features:

- Automated rollback
- [Virtual machine (VM) pools](./virtual-machines-node-pools.md)
- [Max unavailable](./upgrade-cluster.md#customize-unavailable-nodes-during-upgrade) setting
- [Undrainable node behavior](./upgrade-options.md#option-2-handle-undrainable-nodes-honor-pdb) and [maxBlockedNodes](./upgrade-options.md#example-configuration-with-max-blocked-nodes) setting

Keep the following considerations in mind when using blue-green upgrades:

| Resource requirements | Complexity considerations | Time factors |
| --------------------- | ------------------------- | ------------ |
| * Requires double the node capacity during the upgrade process, leading to increased infrastructure costs. <br> * You need extra compute quota in your Azure subscription to accommodate the temporary doubling of nodes. <br> * You might encounter regional capacity limits during peak usage periods. | * Requires careful planning for stateful workloads to ensure data consistency during migration. <br> * Requires extra monitoring for both the blue and green node pools during the transition period. | * Longer overall upgrade duration compared to in-place upgrades. <br> * Validation period adds time before final cutover. |

## Blue-green upgrade workflow

The blue-green upgrade process creates a parallel environment for safe transitions between node pool versions. You can either **upgrade and commit to the new _green_ pool after validation** or **upgrade and roll back to the original _blue_ pool** if you encounter issues.

### Upgrade and commit scenario

The following diagram illustrates the upgrade and commit workflow:

:::image type="content" source="./media/blue-green-node-pool-upgrade/blue-green-upgrade-commit.png" alt-text="Diagram showing the upgrade and commit scenario workflow." lightbox="./media/blue-green-node-pool-upgrade/blue-green-upgrade-commit.png":::

The upgrade and commit process is as follows:

1. **Cordon _blue_ nodes**: Existing _blue_ nodes are marked as unschedulable.
1. **Create _green_ pool**: New _green_ node pool is provisioned with updated configuration.
1. **Parallel operation**: Both _blue_ and _green_ pools run simultaneously.
1. **Gradual migration**: Workloads are progressively drained from _blue_ nodes and rescheduled to _green_ nodes in batches.
1. **Validate _green_ pool**: Monitor and test workloads on the new pool during migration.
1. **Complete transition**: After final validation period, the _blue_ pool is deleted and _green_ becomes primary.

### Upgrade and roll back scenario

The following diagram illustrates the upgrade and roll back workflow:

:::image type="content" source="./media/blue-green-node-pool-upgrade/blue-green-upgrade-roll-back.png" alt-text="Diagram showing the upgrade and roll back scenario workflow." lightbox="./media/blue-green-node-pool-upgrade/blue-green-upgrade-roll-back.png":::

The upgrade and roll back process is as follows:

1. **Cordon _blue_ nodes**: Existing _blue_ nodes are marked as unschedulable.
1. **Create _green_ pool**: New _green_ node pool is provisioned with updated configuration.
1. **Parallel operation**: Both _blue_ and _green_ pools run simultaneously.
1. **Detect issues**: Identify problems during validation on _green_ pool.
1. **Execute rollback**: Uncordon _blue_ nodes, drain _green_ pool, and migrate workloads back to _blue_ nodes.
1. **Restore state**: _Green_ pool is deleted and system returns to original configuration.

## Choose your upgrade strategy

When creating or upgrading an AKS node pool, you can specify the upgrade strategy (`upgradeStrategy`) to use. The available strategies include:

| Strategy | Description |
| -------- | ----------- |
| `Rolling` (default) | Standard rolling upgrade where nodes are updated one by one. |
| `BlueGreen` | Creates a parallel _green_ pool with the new configuration while maintaining the existing _blue_ node pool. |

## Customize blue-green upgrade properties

You can customize the following blue-green upgrade properties (`NodePoolBlueGreenUpgradeSettings`):

| Property | Description | Allowed values | Default value |
| -------- | ----------- | -------------- | ------------- |
| `drainBatchSize` | Number or percentage of nodes to drain in each batch during upgrade. Percentage is calculated from the total number of blue nodes at the start of the upgrade. Fractional nodes are rounded up. | Integer (for example, `5`) or percentage (for example, `50%`). **Must be a non-zero value**. | 10% |
| `drainTimeoutInMinutes` | Maximum time (in minutes) to wait for pods to gracefully terminate on each node before failing the upgrade. Honors pod disruption budgets during this wait time. If exceeded, the upgrade fails. | Integer between `1` and `1440` (24 hours). | 30 minutes |
| `batchSoakDurationInMinutes` | Pause time (in minutes) between draining batches of nodes to allow for observation and validation. | Integer between `0` and `1440` (24 hours). | 15 minutes |
| `finalSoakDurationInMinutes` | Wait time (in minutes) after all nodes are drained before removing old nodes. Provides a final validation period before committing to the upgrade. Rollback operations are only available during this final soak period. Once this period expires and the blue pool is deleted, rollback is no longer possible. | Integer between `0` and `10080` (seven days). | 60 minutes |

## Create a node pool with default blue-green upgrade settings

- Create a node pool with the default blue-green upgrade strategy and settings using the [`az aks nodepool add`](/cli/azure/aks/nodepool#az-aks-nodepool-add) command with the `--upgrade-strategy` parameter set to `bluegreen`. The following example creates a new node pool named `myNodePool` in the AKS cluster `myAKSCluster` within the resource group `myResourceGroup`:

    ```azurecli-interactive
    az aks nodepool add \
        --name myNodePool \
        --cluster-name myAKSCluster \
        --resource-group myResourceGroup \
        --upgrade-strategy bluegreen
    ```

## Create a node pool with custom blue-green upgrade settings

- Create a node pool with custom blue-green upgrade settings using the [`az aks nodepool add`](/cli/azure/aks/nodepool#az-aks-nodepool-add) command with the `--upgrade-strategy` parameter set to `bluegreen` and set any desired custom blue-green upgrade settings. The following example creates a new node pool named `myNodePool` in the AKS cluster `myAKSCluster` within the resource group `myResourceGroup`, with custom blue-green upgrade settings:

    ```azurecli-interactive
    az aks nodepool add \
        --name myNodePool \
        --cluster-name myAKSCluster \
        --resource-group myResourceGroup \
        --upgrade-strategy bluegreen \
        --drain-timeout-bg 5 \
        --batch-soak-duration 5 \
        --drain-batch-size 50% \
        --final-soak-duration 180
    ```

## Start a blue-green upgrade for an existing node pool

> [!IMPORTANT]
> When resuming a paused upgrade, you can update the blue-green settings, but you can't change the upgrade strategy or Kubernetes version.

- Start a blue-green upgrade for an existing node pool using the [`az aks nodepool upgrade`](/cli/azure/aks/nodepool#az-aks-nodepool-upgrade) command with the `--kubernetes-version` parameter set to your desired version. You can start a blue-green upgrade for a node pool already using the blue-green strategy or for a node pool not yet configured with blue-green strategy. The following examples demonstrate both scenarios:

    ```azurecli-interactive
    # Start a blue-green upgrade for an existing node pool already using blue-green strategy
    az aks nodepool upgrade \
        --name myNodePool \
        --cluster-name myAKSCluster \
        --resource-group myResourceGroup \
        --kubernetes-version <kubernetes-version>
    
    # Start a blue-green upgrade for an existing node pool not yet using blue-green strategy
    az aks nodepool upgrade \
        --name myNodePool \
        --cluster-name myAKSCluster \
        --resource-group myResourceGroup \
        --kubernetes-version <kubernetes-version> \
        --upgrade-strategy bluegreen
    ```

## Pause or cancel a blue-green upgrade

- Pause or cancel an ongoing blue-green upgrade using the [`az aks nodepool operation-abort`](/cli/azure/aks/nodepool#az-aks-nodepool-operation-abort) command. The following example pauses or cancels the blue-green upgrade for the node pool named `myNodePool` in the AKS cluster `myAKSCluster` within the resource group `myResourceGroup`:

    ```azurecli-interactive
    az aks nodepool operation-abort \
        --name myNodePool \
        --cluster-name myAKSCluster \
        --resource-group myResourceGroup
    ```

## Roll back a blue-green upgrade

Once an ongoing blue-green upgrade is canceled, the rollback can be initiated using the [`az aks nodepool rollback`](/cli/azure/aks/nodepool#az-aks-nodepool-rollback) command.

The rollback is only available during the final soak period as described in the [finalSoakDurationInMinutes](/azure/aks/blue-green-node-pool-upgrade#customize-blue-green-upgrade-properties) property.

The following example performs a rollback of the blue-green upgrade for the node pool named `myNodePool` in the AKS cluster `myAKSCluster` within the resource group `myResourceGroup`:

```azurecli-interactive
az aks nodepool rollback \
    --name myNodePool \
    --cluster-name myAKSCluster \
    --resource-group myResourceGroup
 ```

## Frequently asked questions (FAQs)

### Do blue-green upgrades support the `maxUnavailable` setting?

No, the `maxUnavailable` setting isn't applicable to blue-green upgrades. _Green_ pools are created by duplicating the entire _blue_ pool, ensuring all nodes remain available during the upgrade process.

### Which Kubernetes versions are compatible with blue-green upgrades?

Blue-green upgrades work with all [AKS-supported Kubernetes versions](./supported-kubernetes-versions.md), including both community-supported versions and [Long Term Support (LTS) versions](./long-term-support.md), so long as you use API version `2025-08-02-preview` or later.

### Can I use the automatic security patch channel with blue-green upgrades?

Yes, as long as the node pool's upgrade strategy is configured to use blue-green. When configured, security patches follow the blue-green upgrade process instead of the default rolling update mechanism.

### What happens to persistent volumes during blue-green upgrades?

Persistent volumes remain accessible. Pods are gracefully drained and rescheduled, maintaining their volume attachments.

### Can I perform blue-green upgrades across multiple node pools simultaneously?

Yes, different node pools can undergo blue-green upgrades in parallel, but each pool can only have one active upgrade. You currently can't control the order of upgrades across multiple pools.

### How do blue-green upgrades handle node-specific configurations like taints and labels?

All node configurations including taints, labels, and annotations are automatically replicated to the _green_ pool.

### What's the cost impact of blue-green upgrades?

You're charged for both node pools during the upgrade window, so make sure you plan for temporary cost doubling during the transition period.

### What happens during a capacity failure?

In the event of a capacity failure when provisioning the _green_ pool, the upgrade fails and the _blue_ pool remains unaffected. You can retry the upgrade once sufficient capacity is available or choose to roll back.

### What happens during rollback?

If the number of green nodes is less than or equal to the number of blue nodes when rollback is initiated, the green nodes are removed, and the blue nodes are uncordoned and revived to resume normal operation.

## Related content

To learn more about node pool upgrades in AKS, see the following articles:

- [Roll back node pool versions in Azure Kubernetes Service (AKS)](./roll-back-node-pool-version.md)
- [Configure rolling upgrades for Azure Kubernetes Service (AKS) node pools](./upgrade-valkey-aks-nodepool.md)
- [Autoupgrade node OS images in Azure Kubernetes Service (AKS)](./auto-upgrade-node-os-image.md)
