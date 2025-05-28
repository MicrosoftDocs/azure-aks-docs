---
title: Upgrade options for Azure Kubernetes Service (AKS) clusters
description: Learn the different ways to upgrade an Azure Kubernetes Service (AKS) cluster.
ms.topic: concept-article
ms.service: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.date: 02/08/2024
author: schaffererin
ms.author: schaffererin
---

# Upgrade options for Azure Kubernetes Service (AKS) clusters

This article covers the different upgrade options for AKS clusters. To perform a basic Kubernetes version upgrade, see [Upgrade an AKS cluster](./upgrade-aks-cluster.md).

For AKS clusters that use multiple node pools or Windows Server nodes, see [Upgrade a node pool in AKS][nodepool-upgrade]. To upgrade a specific node pool without performing a Kubernetes cluster upgrade, see [Upgrade a specific node pool][specific-nodepool].

## Perform manual upgrades

You can perform manual upgrades to control when your cluster upgrades to a new Kubernetes version. Manual upgrades are useful when you want to test a new Kubernetes version before upgrading your production cluster. You can also use manual upgrades to upgrade your cluster to a specific Kubernetes version that isn't the latest available version.

To perform manual upgrades, see the following articles:

* [Upgrade an AKS cluster](./upgrade-aks-cluster.md)
* [Upgrade the node image](./node-image-upgrade.md)
* [Customize node surge upgrade](./upgrade-aks-cluster.md#customize-node-surge-upgrade)
* [Process node OS updates](./node-updates-kured.md)
* [Upgrade multiple AKS clusters via Azure Kubernetes Fleet Manager](/azure/kubernetes-fleet/update-orchestration)

## Configure automatic upgrades

You can configure automatic upgrades to automatically upgrade your cluster to the latest available Kubernetes version. Automatic upgrades are useful when you want to ensure your cluster is always running the latest Kubernetes version. You can also use automatic upgrades to ensure your cluster is always running a supported Kubernetes version.

To configure automatic upgrades, see the following articles:

* [Automatically upgrade an AKS cluster](./auto-upgrade-cluster.md)
* [Use Planned Maintenance to schedule and control upgrades for your AKS cluster](./planned-maintenance.md)
* [Stop AKS cluster upgrades automatically on API breaking changes (Preview)](./stop-cluster-upgrade-api-breaking-changes.md)
* [Automatically upgrade AKS cluster node operating system images](./auto-upgrade-node-image.md)
* [Apply security updates to AKS nodes automatically using GitHub Actions](./node-upgrade-github-actions.md)

## Special considerations for node pools that span multiple availability zones

AKS uses best-effort zone balancing in node groups. During an upgrade surge, the zones for the surge nodes in Virtual Machine Scale Sets are unknown ahead of time, which can temporarily cause an unbalanced zone configuration during an upgrade. However, AKS deletes surge nodes once the upgrade completes and preserves the original zone balance. If you want to keep your zones balanced during upgrades, you can increase the surge to a multiple of *three nodes*, and Virtual Machine Scale Sets balances your nodes across availability zones with best-effort zone balancing. With best-effort zone balance, the scale set attempts to scale in and out while maintaining balance. However, if for some reason this isn't possible (for example, if one zone goes down, the scale set can't create a new VM in that zone), the scale set allows temporary imbalance to successfully scale in or out.

Persistent volume claims (PVCs) backed by Azure locally redundant storage (LRS) Disks are bound to a particular zone and might fail to recover immediately if the surge node doesn't match the zone of the PVC. If the zones don't match, it can cause downtime on your application when the upgrade operation continues to drain nodes but the PVs are bound to a zone. To handle this case and maintain high availability, configure a [Pod Disruption Budget](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) on your application to allow Kubernetes to respect your availability requirements during the drain operation.

## Optimize for undrainable node behavior (Preview)

You can configure the upgrade process behavior for drain failures. The default upgrade behavior is `Schedule`, which consists of a node drain failure causing the upgrade operation to fail, leaving the undrained nodes in a schedulable state. Alternatively, you can select the `Cordon` behavior, which skips nodes that fail to drain by placing them in a quarantined state, labels them `kubernetes.azure.com/upgrade-status:Quarantined`, and proceeds with upgrading the remaining nodes. This behavior ensures that all nodes are either upgraded or quarantined. This approach allows you to troubleshoot drain failures and gracefully manage the quarantined nodes.

### Set new cordon behavior

You need to use `aks-preview` extension 9.0.0b3 or later to set the new cordon behavior.

1. Install or update the `aks-preview` extension using the [`az extension add`][az-extension-add] or [`az extension update`][az-extension-update] command:

    ```azurecli-interactive
    # Install the aks-preview extension
    az extension add --name aks-preview
    
    # Update the aks-preview extension to the latest version
    az extension update --name aks-preview
    ```

2. Update the node pool undrainable node behavior to `Cordon` using the [`az aks nodepool update`][az-aks-nodepool-update] command.

    ```azurecli-interactive
    az aks nodepool update --cluster-name $CLUSTER_NAME --name $NODE_POOL_NAME --resource-group $RESOURCE_GROUP --max-surge 1 --undrainable-node-behavior Cordon
    ```

    The following example output shows the undrainable node behavior updated:

    ```output  
    "upgradeSettings": {
        "drainTimeoutInMinutes": null,
        "maxSurge": "1",
        "nodeSoakDurationInMinutes": null,
        "undrainableNodeBehavior": "Cordon"
      }
    ```

3. Verify the label on any blocked nodes when there's a drain node failure on upgrade using the `kubectl get` command.

    ```bash
    kubectl get nodes --show-labels=true
    ```

    The blocked nodes are unscheduled for pods and marked with the label `"kubernetes.azure.com/upgrade-status: Quarantined"`. The maximum number of nodes that can be left blocked can't be more than the `Max-Surge` value.

### Resolve undrainable nodes

1. First resolve the underlying issue causing the drain. The following example removes the responsible PDB:

    ```bash
    kubectl delete pdb nginx-pdb
    poddisruptionbudget.policy "nginx-pdb" deleted.
    ```

2. If you're confident the issue is now resolved, you can remove the `"kubernetes.azure.com/upgrade-status: Quarantined"` label placed on undrainable nodes using the `kubectl label` command.

    ```bash
    kubectl label nodes <node-name> <label-key>-
    ```

    Any subsequent `PUT` operations will attempt to reconcile the `Failed Provisioning Status` on the cluster to `Success` first. The quarantined nodes won't be considered for any subsequent put or reconcile. You have to explicitly remove the labels as mentioned previously for any blocked nodes to be considered.

3. You can also delete the blocked node using the [`az aks nodepool delete-machines`][az-aks-nodepool-delete-machines] command. This command is useful if you intend to reduce the node pool footprint by removing nodes left behind in older versions.

    ```azurecli-interactive
    az aks nodepool delete-machines --cluster-name $CLUSTER_NAME --machine-names aks-$NODE_POOL_NAME-test123-vmss000000 --name $NODE_POOL_NAME --resource-group $RESOURCE_GROUP
    ```

4. After you complete this step, you can reconcile the cluster status by performing any update operation without the optional fields as outlined [here](/cli/azure/aks#az-aks-update). Alternatively, you can scale the node pool to the same number of nodes as the count of upgraded nodes. This action ensures the node pool gets to its intended original size. AKS prioritizes the removal of the blocked nodes. This command also restores the cluster provisioning status to `Succeeded`. In the example given, `2` is the total number of upgraded nodes.

    ```azurecli-interactive
    # Update the cluster to restore the provisioning status
    az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

    # Scale the node pool to restore the original size
    az aks nodepool scale --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODE_POOL_NAME --node-count 2 
    ```

## Optimize upgrades to improve performance and minimize disruptions

The combination of [Planned Maintenance Window][planned-maintenance], [Max Surge](./upgrade-aks-cluster.md#customize-node-surge-upgrade), [Pod Disruption Budget][pdb-spec], [node drain timeout][drain-timeout], and [node soak time][soak-time] can significantly increase the likelihood of node upgrades completing successfully by the end of the maintenance window while also minimizing disruptions.

* [Planned Maintenance Window][planned-maintenance] enables service teams to schedule auto-upgrade during a predefined window, typically a low-traffic period, to minimize workload impact. We recommend a window duration of at least *four hours*.
* [Max Surge](./upgrade-aks-cluster.md#customize-node-surge-upgrade) on the node pool allows requesting extra quota during the upgrade process and limits the number of nodes selected for upgrade simultaneously. A higher max surge results in a faster upgrade process. We don't recommend setting it at 100%, as it upgrades all nodes simultaneously, which can cause disruptions to running applications. We recommend a max surge quota of *33%* for production node pools.
* [Max Unavailable (Preview)](./upgrade-aks-cluster.md#customize-unavailable-nodes-during-upgrade-preview) on the node pool allows upgrades to occur by cordoning the existing nodes and draining without adding any surge nodes. A higher max unavailable result in faster upgrade but also causes more workload disruptions for the node pool. This feature is recommended for customers facing capacity constraints due to lack of extra SKU capacity in the region or quota issues.
* [Pod Disruption Budget][pdb-spec] is set for service applications and limits the number of pods that can be down during voluntary disruptions, such as AKS-controlled node upgrades. It can be configured as `minAvailable` replicas, indicating the minimum number of application pods that need to be active, or `maxUnavailable` replicas, indicating the maximum number of application pods that can be terminated, ensuring high availability for the application. Refer to the guidance provided for configuring [Pod Disruption Budgets (PDBs)][pdb-concepts]. PDB values should be validated to determine the settings that work best for your specific service.
* [Node drain timeout][drain-timeout] on the node pool allows you to configure the wait duration for eviction of pods and graceful termination per node during an upgrade. This option is useful when dealing with long running workloads. When the node drain timeout is specified (in minutes), AKS respects waiting on pod disruption budgets. If not specified, the default timeout is 30 minutes.
* [Node soak time][soak-time] helps stagger node upgrades in a controlled manner and can minimize application downtime during an upgrade. You can specify a wait time, preferably as reasonably close to 0 minutes as possible, to check application readiness between node upgrades. If not specified, the default value is 0 minutes. Node soak time works together with the max surge and node drain timeout properties available in the node pool to deliver the right outcomes in terms of upgrade speed and application availability.

|Upgrade settings|Available resources for surging|Expected behavior|
|-|-|-|
| `maxSurge` = `5`   `maxUnavailable` = `0` | 5 nodes available for surging | 5 nodes will be surged to upgrade the node pool. |
| `maxSurge` = `5`   `maxUnavailable` = `0` | 0-4 nodes available for surging | The upgrade operation fails due to not having enough nodes to meet `maxSurge`. |
| `maxSurge` = `0`   `maxUnavailable` = `5` | N/A since no surge nodes are needed | The operation uses 5 nodes from the existing node pool without surging new nodes to upgrade the node pool. |


## Validations used in the upgrade process today
When you initiate an upgrade operation through API, Azure CLI, or Azure portal, Azure Kubernetes Service (AKS) performs a series of pre-upgrade validations before starting the upgrade. These validations ensure the cluster is in a healthy state and can upgrade successfully.
- **API Breaking Changes**: Identifies if there are any deprecated APIs in use that may impact workloads.
- **Kubernetes Upgrade Version**: Ensures the target version is valid (e.g., no jumps greater than three minor versions, no downgrades, and compatibility with the control plane).
- **Incorrect PDB Configuration Validation**: Checks for misconfigured Pod Disruption Budgets (PDBs) such as `maxUnavailable = 0` which does not allow any nodes to be disrupted. 
- **Quota**: Confirms there is sufficient quota for surging nodes required during the upgrade process.
- **Subnet**: Verifies if there are enough allocable IP addresses for the upgrade or if subnet size adjustments are needed.
- **Certificates/Service Principals**: Detects expired certificates or service principals that could impact the upgrade process.

These checks help minimize upgrade failures and provide users with early visibility into potential issues that need resolution before proceeding.


## Next steps

This article listed different upgrade options for AKS clusters. For a detailed discussion of upgrade best practices and other considerations, see [AKS patch and upgrade guidance][upgrade-operators-guide].

<!-- LINKS - external -->
[pdb-spec]: https://kubernetes.io/docs/tasks/run-application/configure-pdb/
[pdb-concepts]:https://kubernetes.io/docs/concepts/workloads/pods/disruptions/#pod-disruption-budgets

<!-- LINKS - internal -->
[drain-timeout]: ./upgrade-aks-cluster.md#set-node-drain-timeout-value
[soak-time]: ./upgrade-aks-cluster.md#set-node-soak-time-value
[nodepool-upgrade]: manage-node-pools.md#upgrade-a-cluster-control-plane-with-multiple-node-pools
[planned-maintenance]: planned-maintenance.md
[specific-nodepool]: node-image-upgrade.md#upgrade-a-specific-node-pool
[upgrade-operators-guide]: /azure/architecture/operator-guides/aks/aks-upgrade-practices

