---
title: Roll Back Node Pool Versions in Azure Kubernetes Service (AKS) (preview)
description: Learn how to roll back node pool versions in Azure Kubernetes Service (AKS) to recover from upgrade issues and maintain cluster stability.
ms.topic: how-to
ms.subservice: aks-upgrade
ms.custom: azure-kubernetes-service
ms.date: 11/06/2024
author: kaarthis
ms.author: kaarthis
ms.reviewer: schaffererin
# Customer intent: "As a Kubernetes administrator, I want to know how to roll back node pool versions in AKS so that I can recover from upgrade issues and maintain cluster stability."
---

# Roll back node pool versions in Azure Kubernetes Service (AKS) (preview)

The node pool version rollback feature in Azure Kubernetes Service (AKS) enables you to recover from unexpected behaviors after Kubernetes upgrades. If issues occur, you can roll back node pools to the previous Kubernetes version and node image combination, ensuring business continuity and minimizing downtime. This article explains when and how to use the rollback feature, its capabilities and limitations, and best practices for post-rollback actions.

## Prerequisites

- Azure CLI version 2.64.0 or higher. Find your version using the `az --version` command. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
- The [`aks-preview` Azure CLI extension](#install-the-aks-preview-azure-cli-extension) installed and updated to the latest version.
- API version `2025-08-02-preview` or later.

### Install the `aks-preview` Azure CLI extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Install or update the `aks-preview` extension using the [`az extension add`](/cli/azure/extension#az-extension-add) and [`az extension update`](/cli/azure/extension#az-extension-update) commands.

```azurecli-interactive
# Install the aks-preview extension
az extension add --name aks-preview

# Update the aks-preview extension
az extension update --name aks-preview
```

## Supported features for node pool version rollback

The node pool version rollback feature supports the following capabilities:

| Feature | Description |
| ------- | ----------- |
| Revert version | Restores both Kubernetes and node image versions to their previous state. |
| Manual trigger, automatic execution | Rollback requires manual initiation, but once triggered, the system automatically handles the entire rollback process without further intervention. |
| Node pool compatibility | Works on all types of node pools including both virtual machine (VM) pools and Virtual Machine Scale Sets (VMSS)-based node pools. |
| Operating system support | Compatible with all operating system (OS) stock keeping units (SKUs) including Ubuntu, Azure Linux, and Windows pools. |
| Simplified process | No snapshot management required. |

## Node pool rollback limitations and considerations

Keep the following limitations in mind when using the node pool rollback feature:

- Limited to version changes only. Other node pool changes aren't reverted.
- No concurrent operations allowed during rollback.
- If configured, you must disable cluster autoupgrade before rollback. Otherwise, the autoupgrade process might automatically upgrade your node pool again after the rollback completes.
- Available only for seven days after upgrade completion.
- Can't perform consecutive rollbacks to go back multiple versions.

Keep the following considerations in mind when using node pool rollback:

| Security implications | Operational considerations |
| --------------------- | ------------------------- |
| • **Vulnerability exposure**: Rolling back removes security patches and updates from the newer version. Therefore, we recommend using rollback only temporarily while resolving issues, then re-upgrading as soon as possible. | • **Service disruption**: Rollback process might cause temporary workload interruptions. <br> • **Resource availability**: Ensure sufficient capacity for the rollback operation. <br> • **Testing requirements**: Plan to fix underlying issues before attempting upgrades again. |

## Why use rollback

Rollback provides a critical recovery mechanism for production environments:

- **Business continuity**: Minimize downtime when upgrades cause unexpected issues
- **Risk mitigation**: Quickly restore known-good configurations without complex recovery procedures
- **Simplified recovery**: Avoid manual intervention or rebuilding clusters from backups

## When to use node pool rollback

Consider rollback as your recovery option in the following scenarios:

- **Upgrade failures occur**: Infrastructure issues, resource constraints, or compatibility problems prevent successful upgrades.
- **Applications break**: Workloads experience critical failures or data corruption with newer Kubernetes versions.
- **Performance degrades**: New versions cause unacceptable latency, throughput issues, or resource consumption.
- **Testing gaps emerge**: Issues surface in production that weren't caught during pre-production testing.

## Node pool rollback workflow

The following diagram illustrates the node pool rollback workflow:

:::image type="content" source="./media/roll-back-node-pool-version/node-pool-rollback.png" alt-text="Diagram showing the node pool rollback workflow." lightbox="./media/roll-back-node-pool-version/node-pool-rollback.png":::

The rollback process restores all nodes in a node pool to their previous version state. Key aspects of the workflow include:

- **All-or-nothing approach**: All nodes must successfully revert to the previous version for the rollback to complete successfully.  If any node fails to roll back, the entire operation fails in order to clearly communicate the state of the cluster, similar to the upgrade operation.
- **Progress tracking**: Monitor rollback status using Azure Activity Log for operation history and the Operation Status API for real-time updates.

## Roll back a node pool version

> [!IMPORTANT]
> Keep the following information in mind when rolling back a node pool version:
>
> - Staying on older versions long-term increases security risks and might eventually prevent upgrades due to version skew limitations. Treat rollback as a temporary recovery mechanism, not a permanent solution.
> - When using the REST API, you can call the [Get Upgrade Profile](/rest/api/aks/managed-clusters/get-upgrade-profile) API first to retrieve the recently used versions. Use this information to specify the target version in your rollback request.

- Roll back a node pool version using the [`az aks nodepool rollback`](/cli/azure/aks/nodepool#az-aks-nodepool-rollback) command. The following example rolls back the node pool named `myNodePool` in the AKS cluster named `myAKSCluster` within the resource group `myResourceGroup`:

    ```azurecli-interactive
    az aks nodepool rollback --name myNodePool --resource-group myResourceGroup --cluster-name myAKSCluster
    ```

## Monitor node pool rollback status

You can use the following methods to monitor the status of a node pool rollback operation and validate a successful rollback:

- Look up [activity logs](./monitor-aks-reference.md) on your cluster.
- Look up specific [upgrade-related events](./upgrade-options.md) on your cluster.
- Subscribe to [AKS events with Azure Event Grid](./quickstart-event-grid.md).
- If you subscribe to an automatic upgrade channel, you can use [AKS Communication Manager](./aks-communication-manager.md) for upgrade notifications.

## Post-rollback best practices

After successfully rolling back your node pool, use the following best practices to ensure stability and security:

- **Investigate the root cause**: Identify why the upgrade failed before attempting another upgrade. Review application logs, resource metrics, and compatibility requirements.
- **Test in non-production**: Validate the newer version in a development or staging environment to reproduce and resolve issues before upgrading production again.
- **Plan your re-upgrade**: Don't stay on the rolled-back version indefinitely. Schedule a re-upgrade to maintain security patches and support:
  - **For critical security issues**: Re-upgrade within days after fixes are validated.
  - **For application compatibility issues**: Re-upgrade within weeks after code adjustments.
  - **Maximum recommended timeframe**: 30 days to avoid accumulating security vulnerabilities.

## Frequently asked questions (FAQs)

### Can I perform other operations during a node pool rollback?

No, the rollback must complete before starting other operations. To perform different operations, abort the rollback first.

### Does node pool rollback revert both Kubernetes version and node image?

Yes, the rollback reverts to the most recently used Kubernetes version and its corresponding node image. If both components changed, the system restores the previous Kubernetes version with the last compatible node image for that version.

### Can I roll back only the node image without changing the node pool version?

Yes, if you performed only a node image update within the last seven days (without upgrading the node pool version), the rollback restores the previous virtual hard disk (VHD) image while maintaining the same Kubernetes version.

### Can I roll back to a version that's out of support?

No, you can't roll back to a Kubernetes version that's no longer supported by AKS. For example, if your node pool was on version 1.27.9 (now out of support) and you upgraded to 1.28.5, you can't roll back to 1.27.9 because it's no longer in the supported version list. Always check the [AKS Kubernetes version support policy](supported-kubernetes-versions.md) to verify version availability.

### Do I need to disable autoupgrade before performing a node pool rollback?

Yes, if your cluster has autoupgrade enabled, you must disable it before performing a rollback. Additionally, if the cluster is included in an [update group in an Azure Kubernetes Fleet Manager autoupgrade profile](/azure/kubernetes-fleet/concepts-update-orchestration), you must remove the cluster from the update group before performing the rollback. Otherwise, the autoupgrade process might automatically upgrade your node pool again after the rollback completes.

## Related content

To learn more about node pool upgrades in AKS, see the following articles:

- [Configure blue-green node pool upgrades in Azure Kubernetes Service (AKS)](./blue-green-node-pool-upgrade.md)
- [Configure rolling upgrades for Azure Kubernetes Service (AKS) node pools](./upgrade-valkey-aks-nodepool.md)
- [Autoupgrade node OS images in Azure Kubernetes Service (AKS)](./auto-upgrade-node-os-image.md)
