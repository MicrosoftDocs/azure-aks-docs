---
title: Upgrade options and recommendations for Azure Kubernetes Service (AKS) clusters
description: Learn about upgrade options for Azure Kubernetes Service (AKS) clusters, including scenario-based recommendations for common upgrade challenges.
ms.topic: conceptual
ms.service: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.date: 07/09/2025
author: kaarthis
ms.author: kaarthis
ms.custom: scenarios
---

# Upgrade options and recommendations for Azure Kubernetes Service (AKS) clusters
This article gives you a technical foundation for AKS cluster upgrades, covering upgrade options and common scenarios. For in-depth guidance tailored to your needs, use the scenario-based navigation paths at the end of this article.

## 📖 What This Article Covers

This **technical reference** provides comprehensive AKS upgrade fundamentals:
- **Manual vs. automated upgrade options** and when to use each
- **Common upgrade scenarios** with specific recommendations
- **Optimization techniques** for performance and minimal disruption
- **Troubleshooting guidance** for capacity, drain failures, and timing issues
- **Validation processes** and pre-upgrade checks

**Best for:** Understanding upgrade mechanics, troubleshooting issues, optimizing upgrade settings, technical implementation details.

**Related guides:** [Production strategies](aks-production-upgrade-strategies.md) • [Stateful workloads](stateful-workload-upgrades.md) • [Scenario hub](upgrade-scenarios-hub.md)

---

> **New to AKS upgrades?** Start with our [Upgrade Scenarios Hub](upgrade-scenarios-hub.md) for guided, scenario-based assistance.

## 🎯 Quick Navigation

| Your Situation | Recommended Path |
|----------------|------------------|
| **Production cluster needing upgrade** | [Production Upgrade Strategies](aks-production-upgrade-strategies.md) |
| **Database/stateful workloads** | [Stateful Workload Patterns](stateful-workload-upgrades.md) |
| **First-time upgrade or basic cluster** | [Basic AKS cluster upgrade](./upgrade-aks-cluster.md) |
| **Multiple environments or fleet** | [Upgrade Scenarios Hub](upgrade-scenarios-hub.md) |
| **Node pools or Windows nodes** | [Node pool upgrades][nodepool-upgrade] |
| **Specific node pool only** | [Single node pool upgrade][specific-nodepool] |

## Upgrade options

### Perform manual upgrades

Manual upgrades let you control when your cluster upgrades to a new Kubernetes version. Useful for testing or targeting a specific version.

* [Upgrade an AKS cluster](./upgrade-aks-cluster.md)
* [Upgrade multiple AKS clusters via Azure Kubernetes Fleet Manager](/azure/kubernetes-fleet/update-orchestration)
* [Upgrade the node image](./node-image-upgrade.md)
* [Customize node surge upgrade](./upgrade-aks-cluster.md#customize-node-surge-upgrade)
* [Process node OS updates](./node-updates-kured.md)

### Configure automatic upgrades

Automatic upgrades keep your cluster on a supported version and up to date. This is when you want to set and forget. 

* [Automatically upgrade an AKS cluster](./auto-upgrade-cluster.md)
* [Automatically upgrade multiple AKS clusters via Azure Kubernetes Fleet Manager](/azure/kubernetes-fleet/update-automation)
* [Use Planned Maintenance to schedule and control upgrades](./planned-maintenance.md)
* [Stop AKS cluster upgrades automatically on API breaking changes (Preview)](./stop-cluster-upgrade-api-breaking-changes.md)
* [Automatically upgrade AKS cluster node operating system images](./auto-upgrade-node-image.md)
* [Apply security updates to AKS nodes automatically using GitHub Actions](./node-upgrade-github-actions.md)

### Special considerations for node pools spanning multiple availability zones

AKS uses best-effort zone balancing in node groups. During an upgrade surge, the zones for surge nodes in Virtual Machine Scale Sets are unknown ahead of time, which can temporarily cause an unbalanced zone configuration. AKS deletes surge nodes after the upgrade and restores the original zone balance. To keep zones balanced, set surge to a multiple of three nodes. PVCs using Azure LRS disks are zone-bound and may cause downtime if surge nodes are in a different zone. Use a [Pod Disruption Budget](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) to maintain high availability during drains.

### Optimize upgrades to improve performance and minimize disruptions

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
> Before upgrading, check for API breaking changes and review the [AKS release notes](https://github.com/Azure/AKS/releases) to avoid disruptions.

## Validations used in the upgrade process

AKS performs pre-upgrade validations to ensure cluster health:

* **API breaking changes:** Detects deprecated APIs.
* **Kubernetes upgrade version:** Ensures valid upgrade path.
* **PDB configuration:** Checks for misconfigured PDBs (e.g., `maxUnavailable=0`).
* **Quota:** Confirms enough quota for surge nodes.
* **Subnet:** Verifies sufficient IP addresses.
* **Certificates/Service Principals:** Detects expired credentials.

These checks help minimize upgrade failures and provide early visibility into issues.

## Common upgrade scenarios and recommendations

### Scenario 1: Capacity constraints

If your cluster is limited by SKU or regional capacity, upgrades might fail when surge nodes can't be provisioned. This is common with specialized SKUs (like GPU nodes) or in regions with limited resources. Errors such as `SKUNotAvailable`, `AllocationFailed`, or `OverconstrainedAllocationRequest` might occur if `maxSurge` is set too high for available capacity.

#### Recommendations to prevent or resolve

* Use `maxUnavailable` to upgrade using existing nodes instead of surging new ones. [Learn more](./upgrade-aks-cluster.md#customize-unavailable-nodes-during-upgrade).
* Lower `maxSurge` to reduce extra capacity needs. [Learn more](./upgrade-aks-cluster.md#customize-node-surge-upgrade).
* For security-only updates, use security patch reimages that don't require surge nodes. [Learn more](./node-updates-kured.md).

### Scenario 2: Node drain failures and PDBs

Upgrades require draining nodes (evicting pods). Drains can fail if:

* Pods are slow to terminate (long shutdown hooks or persistent connections).
* Strict [Pod Disruption Budgets (PDBs)](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/) block pod evictions.

Example error message:

```output
Code: UpgradeFailed
Message: Drain node ... failed when evicting pod ... failed with Too Many Requests error. This is often caused by a restrictive Pod Disruption Budget (PDB) policy. See https://aka.ms/aks/debugdrainfailures. Original error: Cannot evict pod as it would violate the pod's disruption budget. PDB debug info: ... blocked by pdb ... with 0 unready pods.
```

#### Recommendations to prevent or resolve

* Set `maxUnavailable` in PDBs to allow at least one pod to be evicted.
* Increase pod replicas so the disruption budget can tolerate evictions.
* Use `undrainableNodeBehavior` to allow upgrades to proceed even if some nodes can't be drained:
  * **Schedule (Default):** Node and surge replacement may be deleted, reducing capacity.
  * **Cordon (Recommended):** Node is cordoned and labeled as `kubernetes.azure.com/upgrade-status=Quarantined`.
    * Example command:

        ```azurecli-interactive
        az aks nodepool update \
          --resource-group <resource-group-name> \
          --cluster-name <cluster-name> \
          --name <node-pool-name> \
          --undrainable-node-behavior Cordon
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

#### Max Blocked Nodes Allowed (Preview)

* **[Preview]** The Max Blocked Nodes Allowed feature lets you specify how many nodes that fail to drain (blocked nodes) can be tolerated during upgrades or similar operations. This feature only works if the undrainable node behavior property is set; otherwise, the command will return an error.

> [!NOTE]
> If you do not explicitly set Max Blocked Nodes Allowed, it defaults to the value of [Max Surge](./upgrade-aks-cluster.md#customize-node-surge-upgrade). If Max Surge is not set, the default is typically 10%, so Max Blocked Nodes Allowed also defaults to 10%.

**Prerequisites**

- Azure CLI `aks-preview` extension version 18.0.0b9 or later is required to use this feature.

  Example command:

  ```azurecli-interactive
  az aks nodepool update \
    --cluster-name jizenMC1 \
    --name nodepool1 \
    --resource-group jizenTestMaxBlockedNodesRG \
    --max-surge 1 \
    --undrainable-node-behavior Cordon \
    --max-blocked-nodes 2 \
    --drain-timeout 5
  ```
* Extend drain timeout if workloads need more time (default is *30 minutes*).
* Test PDBs in staging, monitor upgrade events, and use blue-green deployments for critical workloads. [Learn more](/azure/architecture/guide/aks/blue-green-deployment-for-aks).

**Verifying undrainable nodes**

* The blocked nodes are unscheduled for pods and marked with the label `"kubernetes.azure.com/upgrade-status: Quarantined"`.
* Verify the label on any blocked nodes when there's a drain node failure on upgrade:

    ```bash
    kubectl get nodes --show-labels=true
    ```

**Resolving undrainable nodes**

1. Remove the responsible PDB:

    ```bash
    kubectl delete pdb <pdb-name>
    ```

1. Remove the `kubernetes.azure.com/upgrade-status: Quarantined` label:

    ```bash
    kubectl label nodes <node-name> <label-name>
    ```

1. Optionally, delete the blocked node:

    ```azurecli-interactive
    az aks nodepool delete-machines --cluster-name <cluster-name> --machine-names <machine-name> --name <node-pool-name> --resource-group <resource-group-name>
    ```

1. After you complete this step, you can reconcile the cluster status by performing any update operation without the optional fields as outlined [here](/cli/azure/aks#az-aks-update). Alternatively, you can scale the node pool to the same number of nodes as the count of upgraded nodes. This action ensures the node pool gets to its intended original size. AKS prioritizes the removal of the blocked nodes. This command also restores the cluster provisioning status to `Succeeded`. In the example given, `2` is the total number of upgraded nodes.

    ```azurecli-interactive
    # Update the cluster to restore the provisioning status
    az aks update --resource-group <resource-group-name> --name <cluster-name>

    # Scale the node pool to restore the original size
    az aks nodepool scale --resource-group <resource-group-name> --cluster-name <cluster-name> --name <node-pool-name> --node-count 2
    ```

### Scenario 3: Slow upgrades

Upgrades can be delayed by conservative settings or node-level issues, impacting your ability to stay current with patches and improvements.

Common causes of slow upgrades include:

* Low `maxSurge` or `maxUnavailable` values (limits parallelism).
* High soak times (long waits between node upgrades).
* Drain failures (see [Node drain failures](#scenario-2-node-drain-failures-and-pdbs)]).

#### Recommendations to prevent or resolve

* For production: `maxSurge=33%`, `maxUnavailable=1`.
* For dev/test: `maxSurge=50%`, `maxUnavailable=2`.
* Use OS Security Patch for fast, targeted patching (avoids full node reimaging).
* Enable `undrainableNodeBehavior` to avoid upgrade blockers.

### Scenario 4: IP exhaustion

Surge nodes require additional IPs. If the subnet is near capacity, node provisioning can fail (e.g., `Error: SubnetIsFull`). This is common with Azure CNI, high `maxPods`, or large node counts.

#### Recommendations to prevent or resolve

* Ensure your subnet has enough IPs for all nodes, surge nodes, and pods:
  * Formula: `Total IPs = (Number of nodes + maxSurge) * (1 + maxPods)`
* Reclaim unused IPs or expand the subnet (e.g., from /24 to /22).
* Lower `maxSurge` if subnet expansion isn't possible:

    ```azurecli-interactive
    az aks nodepool update \
      --resource-group <resource-group-name> \
      --cluster-name <cluster-name> \
      --name <node-pool-name> \
      --max-surge 10%
    ```

* Monitor IP usage with Azure Monitor or custom alerts.
* Reduce `maxPods` per node, clean up orphaned load balancer IPs, and plan subnet sizing for high-scale clusters.

---

## Now Choose Your Upgrade Path

This article provided the technical foundation - now select your scenario-based path:

### 🚀 Ready to Execute?

| If you have... | Then go to... |
|----------------|---------------|
| **Production environment** | [Production Upgrade Strategies](aks-production-upgrade-strategies.md) - Battle-tested patterns for zero-downtime upgrades |
| **Databases or stateful apps** | [Stateful Workload Patterns](stateful-workload-upgrades.md) - Safe upgrade patterns for data persistence |
| **Multiple environments** | [Upgrade Scenarios Hub](upgrade-scenarios-hub.md) - Decision tree for complex setups |
| **Basic cluster** | [Upgrade an AKS cluster](./upgrade-aks-cluster.md) - Step-by-step cluster upgrade |

### 🔍 Still Deciding?

Visit the [Upgrade Scenarios Hub](upgrade-scenarios-hub.md) for a guided decision tree that considers your:
- Downtime tolerance
- Environment complexity  
- Risk profile
- Timeline constraints

## Next steps

* Review [AKS patch and upgrade guidance][upgrade-operators-guide] for best practices and planning tips before starting any upgrade.
* Always check for [API breaking changes](https://aka.ms/aks/breakingchanges) and validate your workloads' compatibility with the target Kubernetes version.
* Test upgrade settings (such as `maxSurge`, `maxUnavailable`, and PDBs) in a staging environment to minimize production risk.
* Monitor upgrade events and cluster health throughout the process.

<!-- LINKS - external -->
[pdb-spec]: https://kubernetes.io/docs/tasks/run-application/configure-pdb/
[pdb-concepts]: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/#pod-disruption-budgets

<!-- LINKS - internal -->
[drain-timeout]: ./upgrade-aks-cluster.md#set-node-drain-timeout-value
[soak-time]: ./upgrade-aks-cluster.md#set-node-soak-time-value
[nodepool-upgrade]: manage-node-pools.md#upgrade-a-cluster-control-plane-with-multiple-node-pools
[planned-maintenance]: planned-maintenance.md
[specific-nodepool]: node-image-upgrade.md#upgrade-a-specific-node-pool
[upgrade-operators-guide]: /azure/architecture/operator-guides/aks/aks-upgrade-practices
