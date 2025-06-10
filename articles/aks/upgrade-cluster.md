---
title: Upgrade options for Azure Kubernetes Service (AKS) clusters
description: Learn the different ways to upgrade an Azure Kubernetes Service (AKS) cluster.
ms.topic: concept-article
ms.service: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.date: 02/08/2024
author: kaarthis
ms.author: kaarthis
---

# Upgrade options for Azure Kubernetes Service (AKS) clusters

This article covers upgrade options for AKS clusters and provides scenario-based recommendations for common upgrade challenges. For a basic Kubernetes version upgrade, see [Upgrade an AKS cluster](./upgrade-aks-cluster.md).

For clusters with multiple node pools or Windows Server nodes, see [Upgrade a node pool in AKS][nodepool-upgrade]. To upgrade a specific node pool without a full cluster upgrade, see [Upgrade a specific node pool][specific-nodepool].

## Scenario 1: Capacity constraints
If your cluster is limited by SKU or regional capacity, upgrades may fail when surge nodes can't be provisioned. This is common with specialized SKUs (like GPU nodes) or in regions with limited resources. Errors such as SKUNotAvailable, AllocationFailed, or OverconstrainedAllocationRequest may occur if `maxSurge` is set too high for available capacity.

**Recommendations:**
- Use `maxUnavailable` to upgrade using existing nodes instead of surging new ones. [Learn more](./upgrade-aks-cluster.md#customize-unavailable-nodes-during-upgrade)
- Lower `maxSurge` to reduce extra capacity needs. [Learn more](./upgrade-aks-cluster.md#customize-node-surge-upgrade)
- For security-only updates, use security patch reimages that do not require surge nodes. [Learn more](./node-updates-kured.md)

## Scenario 2: Node drain failures and PDBs
Upgrades require draining nodes (evicting pods). Drains can fail if:
- Pods are slow to terminate (long shutdown hooks or persistent connections)
- Strict [Pod Disruption Budgets (PDBs)](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/) block pod evictions

**Example Error:**
```
Code: UpgradeFailed
Message: Drain node ... failed when evicting pod ... failed with Too Many Requests error. This is often caused by a restrictive Pod Disruption Budget (PDB) policy. See https://aka.ms/aks/debugdrainfailures. Original error: Cannot evict pod as it would violate the pod's disruption budget. PDB debug info: ... blocked by pdb ... with 0 unready pods.
```

**How to prevent or resolve:**
- Set `maxUnavailable` in PDBs to allow at least one pod to be evicted.
- Increase pod replicas so the disruption budget can tolerate evictions.
- Use `undrainableNodeBehavior` to allow upgrades to proceed even if some nodes cannot be drained:
  - **Default (Schedule):** Node and surge replacement may be deleted, reducing capacity.
  - **Recommended (Cordon):** Node is cordoned and labeled as `kubernetes.azure.com/upgrade-status=Quarantined`.
  - Configure with:
    ```powershell
    az aks nodepool update \
      --resource-group <RESOURCE_GROUP> \
      --cluster-name <CLUSTER_NAME> \
      --name <NODEPOOL_NAME> \
      --undrainable-node-behavior Cordon
    ```
  - The following example output shows the undrainable node behavior updated:
    ```output  
    "upgradeSettings": {
        "drainTimeoutInMinutes": null,
        "maxSurge": "1",
        "nodeSoakDurationInMinutes": null,
        "undrainableNodeBehavior": "Cordon"
      }
    ```
- Extend drain timeout if workloads need more time (default is 30 minutes).
- Test PDBs in staging, monitor upgrade events, and use blue-green deployments for critical workloads. [More info](https://learn.microsoft.com/en-us/azure/architecture/guide/aks/blue-green-deployment-for-aks)

**Verifying undrainable nodes:**
- The blocked nodes are unscheduled for pods and marked with the label `"kubernetes.azure.com/upgrade-status: Quarantined"`.
- Verify the label on any blocked nodes when there's a drain node failure on upgrade:
    ```bash
    kubectl get nodes --show-labels=true
    ```

**Resolving undrainable nodes:**
1. Remove the responsible PDB:
    ```bash
    kubectl delete pdb <pdb-name>
    ```
2. Remove the kubernetes.azure.com/upgrade-status: Quarantined label:
    ```bash
    kubectl label nodes <node-name> <label-name>
    ```
3. Optionally, delete the blocked node:
    ```powershell
    az aks nodepool delete-machines --cluster-name $CLUSTER_NAME --machine-names <machine-name> --name $NODEPOOL_NAME --resource-group $RESOURCE_GROUP
    ```
4. After you complete this step, you can reconcile the cluster status by performing any update operation without the optional fields as outlined [here](/cli/azure/aks#az-aks-update). Alternatively, you can scale the node pool to the same number of nodes as the count of upgraded nodes. This action ensures the node pool gets to its intended original size. AKS prioritizes the removal of the blocked nodes. This command also restores the cluster provisioning status to `Succeeded`. In the example given, `2` is the total number of upgraded nodes.
    ```azurecli-interactive
    # Update the cluster to restore the provisioning status
    az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

    # Scale the node pool to restore the original size
    az aks nodepool scale --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --name $NODE_POOL_NAME --node-count 2 
    ```

## Scenario 3: Slow upgrades
Upgrades can be delayed by conservative settings or node-level issues, impacting your ability to stay current with patches and improvements.

**Common causes:**
- Low `maxSurge` or `maxUnavailable` values (limits parallelism)
- High soak times (long waits between node upgrades)
- Drain failures (see above)

**Recommendations:**
- For production: `maxSurge=33%`, `maxUnavailable=1`
- For dev/test: `maxSurge=50%`, `maxUnavailable=2`
- Use OS Security Patch for fast, targeted patching (avoids full node reimaging)
- Enable `undrainableNodeBehavior` to avoid upgrade blockers

## Scenario 4: IP exhaustion
Surge nodes require additional IPs. If the subnet is near capacity, node provisioning can fail (e.g., `Error: SubnetIsFull`). This is common with Azure CNI, high `maxPods`, or large node counts.

**Recommendations:**
- Ensure your subnet has enough IPs for all nodes, surge nodes, and pods:
  - Formula: `Total IPs = (Number of nodes + maxSurge) * (1 + maxPods)`
- Reclaim unused IPs or expand the subnet (e.g., from /24 to /22)
- Lower `maxSurge` if subnet expansion is not possible:
    ```powershell
    az aks nodepool update \
      --resource-group <RESOURCE_GROUP> \
      --cluster-name <CLUSTER_NAME> \
      --name <NODEPOOL_NAME> \
      --max-surge 10%
    ```
- Monitor IP usage with Azure Monitor or custom alerts
- Reduce `maxPods` per node, clean up orphaned load balancer IPs, and plan subnet sizing for high-scale clusters

---

## Perform manual upgrades

Manual upgrades let you control when your cluster upgrades to a new Kubernetes version. Useful for testing or targeting a specific version.

* [Upgrade an AKS cluster](./upgrade-aks-cluster.md)
* [Upgrade the node image](./node-image-upgrade.md)
* [Customize node surge upgrade](./upgrade-aks-cluster.md#customize-node-surge-upgrade)
* [Process node OS updates](./node-updates-kured.md)
* [Upgrade multiple AKS clusters via Azure Kubernetes Fleet Manager](/azure/kubernetes-fleet/update-orchestration)

## Configure automatic upgrades

Automatic upgrades keep your cluster on a supported version and up to date. This is when you want to set and forget. 

* [Automatically upgrade an AKS cluster](./auto-upgrade-cluster.md)
* [Use Planned Maintenance to schedule and control upgrades](./planned-maintenance.md)
* [Stop AKS cluster upgrades automatically on API breaking changes (Preview)](./stop-cluster-upgrade-api-breaking-changes.md)
* [Automatically upgrade AKS cluster node operating system images](./auto-upgrade-node-image.md)
* [Apply security updates to AKS nodes automatically using GitHub Actions](./node-upgrade-github-actions.md)

## Special considerations for node pools spanning multiple availability zones

AKS uses best-effort zone balancing in node groups. During an upgrade surge, the zones for surge nodes in Virtual Machine Scale Sets are unknown ahead of time, which can temporarily cause an unbalanced zone configuration. AKS deletes surge nodes after the upgrade and restores the original zone balance. To keep zones balanced, set surge to a multiple of three nodes. PVCs using Azure LRS disks are zone-bound and may cause downtime if surge nodes are in a different zone. Use a [Pod Disruption Budget](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) to maintain high availability during drains.

## Optimize upgrades to improve performance and minimize disruptions

Combine [Planned Maintenance Window][planned-maintenance], [Max Surge](./upgrade-aks-cluster.md#customize-node-surge-upgrade), [Pod Disruption Budget][pdb-spec], [node drain timeout][drain-timeout], and [node soak time][soak-time] to increase the likelihood of successful, low-disruption upgrades.

* [Planned Maintenance Window][planned-maintenance]: Schedule auto-upgrade during low-traffic periods (recommend at least four hours)
* [Max Surge](./upgrade-aks-cluster.md#customize-node-surge-upgrade): Higher values speed upgrades but may disrupt workloads; 33% is recommended for production
* [Max Unavailable](./upgrade-aks-cluster.md#customize-unavailable-nodes-during-upgrade): Use when capacity is limited
* [Pod Disruption Budget][pdb-spec]: Set to limit pods down during upgrades; validate for your service
* [Node drain timeout][drain-timeout]: Configure pod eviction wait duration (default 30 minutes)
* [Node soak time][soak-time]: Stagger upgrades to minimize downtime (default 0 minutes)

|Upgrade settings|How extra nodes are used|Expected behavior|
|-|-|-|
| `maxSurge=5`, `maxUnavailable=0` | 5 surge nodes | 5 nodes surged for upgrade |
| `maxSurge=5`, `maxUnavailable=0` | 0-4 surge nodes | Upgrade fails due to insufficient surge nodes |
| `maxSurge=0`, `maxUnavailable=5` | N/A | 5 existing nodes drained for upgrade |

> [!NOTE]
> Before upgrading, check for API breaking changes and review the [AKS release notes](https://learn.microsoft.com/en-us/azure/aks/release-notes) to avoid disruptions.

## Validations used in the upgrade process
AKS performs pre-upgrade validations to ensure cluster health:
- **API Breaking Changes:** Detects deprecated APIs
- **Kubernetes Upgrade Version:** Ensures valid upgrade path
- **PDB Configuration:** Checks for misconfigured PDBs (e.g., `maxUnavailable=0`)
- **Quota:** Confirms enough quota for surge nodes
- **Subnet:** Verifies sufficient IP addresses
- **Certificates/Service Principals:** Detects expired credentials

These checks help minimize upgrade failures and provide early visibility into issues.

## Next steps

- Review [AKS patch and upgrade guidance][upgrade-operators-guide] for best practices and planning tips before starting any upgrade.
- Always check for [API breaking changes](https://aka.ms/aks/breakingchanges) and validate your workloads' compatibility with the target Kubernetes version.
- Test upgrade settings (such as `maxSurge`, `maxUnavailable`, and PDBs) in a staging environment to minimize production risk.
- Monitor upgrade events and cluster health throughout the process.

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

