---
title: Upgrade Options and Recommendations for Azure Kubernetes Service (AKS) Clusters
description: Learn about upgrade options for Azure Kubernetes Service (AKS) clusters, including scenario-based recommendations for common upgrade challenges.
ms.topic: concept-article
ms.service: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.date: 07/09/2025
author: kaarthis
ms.author: kaarthis
ms.custom: scenarios
# Customer intent: "As a cloud administrator, I want to evaluate various upgrade options for Azure Kubernetes Service clusters so that I can implement a strategy that minimizes disruptions and ensures that my workloads remain updated and compliant with best practices."
---

# Upgrade options and recommendations for Azure Kubernetes Service (AKS) clusters

This article gives you a technical foundation for Azure Kubernetes Service (AKS) cluster upgrades by covering upgrade options and common scenarios. For in-depth guidance tailored to your needs, use the scenario-based navigation paths at the end of this article.

## What this article covers

This technical reference provides comprehensive AKS upgrade fundamentals on:

- Manual versus automated upgrade options and when to use each.
- Common upgrade scenarios with specific recommendations.
- Optimization techniques for performance and minimal disruption.
- Troubleshooting guidance for capacity, drain failures, and timing issues.
- Validation processes and pre-upgrade checks.

This hub is best for helping you to understand upgrade mechanics, troubleshoot issues, optimize upgrade settings, and learn about technical implementation.

For more information, see these related articles:

- To upgrade your production AKS clusters, see [AKS production upgrade strategies](aks-production-upgrade-strategies.md).
- To get upgrade patterns for AKS clusters with stateful workloads, see [Stateful workload upgrade patterns](stateful-workload-upgrades.md).
- To use the scenario hub to help you choose the right AKS upgrade approach, see [AKS upgrade scenarios: Choose your path](upgrade-scenarios-hub.md).

---

If you're new to AKS upgrades, start with the [upgrade scenarios hub](upgrade-scenarios-hub.md) for guided, scenario-based assistance.

## Quick navigation

| Your situation | Recommended path |
|----------------|------------------|
| Production cluster needs an upgrade | [Production upgrade strategies](aks-production-upgrade-strategies.md) |
| Database/stateful workloads | [Stateful workload patterns](stateful-workload-upgrades.md) |
| First-time upgrade or basic cluster | [Basic AKS cluster upgrade](./upgrade-aks-cluster.md) |
| Multiple environments or fleet | [Upgrade scenarios hub](upgrade-scenarios-hub.md) |
| Node pools or Windows nodes | [Node pool upgrades][nodepool-upgrade] |
| Specific node pool only | [Single node pool upgrade][specific-nodepool] |

## Upgrade options

### Perform manual upgrades

Manual upgrades let you control when your cluster upgrades to a new Kubernetes version. These upgrades are useful for testing or targeting a specific version:

* [Upgrade an AKS cluster](./upgrade-aks-cluster.md)
* [Upgrade multiple AKS clusters via Azure Kubernetes Fleet Manager](/azure/kubernetes-fleet/update-orchestration)
* [Upgrade the node image](./node-image-upgrade.md)
* [Customize node surge upgrade](./upgrade-aks-cluster.md#customize-node-surge-upgrade)
* [Process node OS updates](./node-updates-kured.md)

### Configure automatic upgrades

Automatic upgrades keep your cluster on a supported version and up to date. Use these upgrades when you want to automate your settings:

* [Automatically upgrade an AKS cluster](./auto-upgrade-cluster.md)
* [Automatically upgrade multiple AKS clusters via Azure Kubernetes Fleet Manager](/azure/kubernetes-fleet/update-automation)
* [Use planned maintenance to schedule and control upgrades](./planned-maintenance.md)
* [Stop AKS cluster upgrades automatically on API breaking changes (preview)](./stop-cluster-upgrade-api-breaking-changes.md)
* [Automatically upgrade AKS cluster node operating system images](./auto-upgrade-node-image.md)
* [Apply security updates to AKS nodes automatically by using GitHub actions](./node-upgrade-github-actions.md)

### Special considerations for node pools that span multiple availability zones

AKS uses best-effort zone balancing in node groups. During an upgrade surge, the zones for surge nodes in virtual machine scale sets are unknown ahead of time, which can temporarily cause an unbalanced zone configuration. AKS deletes surge nodes after the upgrade and restores the original zone balance. 

To keep zones balanced, set surge to a multiple of three nodes. Persistent volume claims that use Azure locally redundant storage disks are zone bound and might cause downtime if surge nodes are in a different zone. Use a [pod disruption budget (PDB)](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) to maintain high availability during drains.

### Optimize upgrades to improve performance and minimize disruptions

Combine [planned maintenance window][planned-maintenance], [max surge](./upgrade-aks-cluster.md#customize-node-surge-upgrade), [PDB][pdb-spec], [node drain timeout][drain-timeout], and [node soak time][soak-time] to increase the likelihood of successful, low-disruption upgrades:

* [Planned maintenance window][planned-maintenance]: Schedule auto-upgrade during low-traffic periods. We recommend at least four hours.
* [Max surge](./upgrade-aks-node-pools-rolling.md#set-max-surge-value): Higher values speed upgrades but might disrupt workloads. We recommend 33% for production.
* [Max unavailable](./upgrade-aks-node-pools-rolling.md#customize-unavailable-nodes): Use when capacity is limited.
* [Pod disruption budget][pdb-spec]: Set to limit pods down during upgrades. Validate for your service.
* [Node drain timeout][drain-timeout]: Configure pod eviction wait duration. The default is 30 minutes.
* [Node soak time][soak-time]: Stagger upgrades to minimize downtime. The default is 0 minutes.

|Upgrade settings|How extra nodes are used|Expected behavior|
|-|-|-|
| `maxSurge=5`, `maxUnavailable=0` | 5 surge nodes | Five nodes are surged for upgrade. |
| `maxSurge=5`, `maxUnavailable=0` | 0-4 surge nodes | Upgrade fails because of insufficient surge nodes. |
| `maxSurge=0`, `maxUnavailable=5` | N/A | Five existing nodes are drained for upgrade. |

> [!NOTE]
> Before you upgrade, check for API breaking changes and review the [AKS release notes](https://github.com/Azure/AKS/releases) to avoid disruptions.

## Validations used in the upgrade process

AKS performs pre-upgrade validations to ensure cluster health:

* **API breaking changes:** Detects deprecated APIs.
* **Kubernetes upgrade version:** Ensures a valid upgrade path.
* **PDB configuration:** Checks for misconfigured PDBs (for example, `maxUnavailable=0`).
* **Quota:** Confirms enough quota for surge nodes.
* **Subnet:** Verifies sufficient IP addresses.
* **Certificates/service principals:** Detects expired credentials.

These checks help to minimize upgrade failures and provide early visibility into issues.

## Common upgrade scenarios and recommendations

### Scenario 1: Capacity constraints

If your cluster is limited by product tier or regional capacity, upgrades might fail when surge nodes can't be provisioned. This situation is common with specialized product tiers (like GPU nodes) or in regions with limited resources. Errors such as `SKUNotAvailable`, `AllocationFailed`, or `OverconstrainedAllocationRequest` might occur if `maxSurge` is set too high for available capacity.

#### Recommendations to prevent or resolve

* Use `maxUnavailable` to upgrade by using existing nodes instead of surging new ones. For more information, see [Customize unavailable nodes during upgrade](./upgrade-aks-cluster.md#customize-unavailable-nodes-during-upgrade).
* Lower `maxSurge` to reduce extra capacity needs. For more information, see [Customize node surge upgrade](./upgrade-aks-cluster.md#customize-node-surge-upgrade).
* For security-only updates, use security patch reimages that don't require surge nodes. For more information, see [Apply security and kernel updates to Linux nodes in Azure Kubernetes Service](./node-updates-kured.md).

### Scenario 2: Node drain failures and PDBs

Upgrades require draining nodes (evicting pods). Drains can fail when pods are slow to terminate or strict [Pod Disruption Budgets (PDBs)](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/) block pod evictions.

Example error:
```output
Code: UpgradeFailed
Message: Drain node ... failed when evicting pod ... Cannot evict pod as it would violate the pod's disruption budget.
```
#### Option 1: Force upgrade (bypass PDB)
> [!WARNING]
> Force upgrade bypasses Pod Disruption Budget (PDB) constraints and may cause service disruption by draining all pods simultaneously. Before using this option, first try to fix PDB misconfigurations (review the PDB minAvailable/maxUnavailable settings, ensure adequate pod replicas, verify PDBs aren't blocking all evictions).

Use force upgrade only when PDBs prevent critical upgrades and cannot be resolved. This will override PDB protections and potentially cause complete service unavailability during the upgrade.

**Requirements:** Azure CLI 2.79.0+ or AKS API version 2025-09-01+

```azurecli-interactive
az aks upgrade \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --kubernetes-version $KUBERNETES_VERSION \
  --enable-force-upgrade \
  --upgrade-override-until 2023-10-01T13:00:00Z
```

> [!NOTE]
> - The `upgrade-override-until` parameter defines when validation bypass ends (must be a future date/time)
> - If not specified, the window defaults to 3 days from current time
> - The 'Z' indicates UTC/GMT time zone

> [!WARNING]
> When force upgrade is enabled, it takes precedence over all other drain configurations. The undrainable node behavior settings (Option 2) will not be applied when force upgrade is active.

#### Option 2: Handle undrainable nodes (honor PDB)

Use this conservative approach to honor PDBs while preventing upgrade failures.

**Configure undrainable node behavior:**

```azurecli-interactive
az aks nodepool update \
  --resource-group <resource-group-name> \
  --cluster-name <cluster-name> \
  --name <node-pool-name> \
  --undrainable-node-behavior Cordon \
  --max-blocked-nodes 2 \
  --drain-timeout 30
```

**Behavior options:**
- **Schedule (default):** Deletes blocked node and surges replacement
- **Cordon (recommended):** Cordons node and labels it as `kubernetes.azure.com/upgrade-status=Quarantined`

**Max blocked nodes (preview):**
- Specifies how many nodes that fail to drain are tolerated
- Requires `undrainable-node-behavior` to be set
- Defaults to `maxSurge` value (typically 10%) if not specified

##### Prerequisites for max blocked nodes

- The Azure CLI `aks-preview` extension version 18.0.0b9 or later is required to use the max blocked nodes feature.

  ```azurecli-interactive
  # Install or update the aks-preview extension
  az extension add --name aks-preview
  az extension update --name aks-preview
  ```

##### Example configuration with max blocked nodes

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

#### Recommendations to prevent drain failures

* Set `maxUnavailable` in PDBs to allow at least one pod eviction
* Increase pod replicas to meet disruption budget requirements
* Extend drain timeout if workloads need more time. (The default is *30 minutes*.)
* Test PDBs in staging, monitor upgrade events, and use blue-green deployments for critical workloads. For more information, see [Blue-green deployment of AKS clusters](/azure/architecture/guide/aks/blue-green-deployment-for-aks).

##### Verify undrainable nodes

* The blocked nodes are unscheduled for pods and marked with the label `"kubernetes.azure.com/upgrade-status: Quarantined"`.
* Verify the label on any blocked nodes when there's a drain node failure on upgrade:

    ```bash
    kubectl get nodes --show-labels=true
    ```

##### Resolve undrainable nodes

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

1. After you finish this step, you can reconcile the cluster status by performing any update operation without the optional fields as outlined in [az aks](/cli/azure/aks#az-aks-update). Alternatively, you can scale the node pool to the same number of nodes as the count of upgraded nodes. This action ensures that the node pool gets to its intended original size. AKS prioritizes the removal of the blocked nodes. This command also restores the cluster provisioning status to `Succeeded`. In the following example, `2` is the total number of upgraded nodes.

    ```azurecli-interactive
    # Update the cluster to restore the provisioning status
    az aks update --resource-group <resource-group-name> --name <cluster-name>

    # Scale the node pool to restore the original size
    az aks nodepool scale --resource-group <resource-group-name> --cluster-name <cluster-name> --name <node-pool-name> --node-count 2
    ```

### Scenario 3: Slow upgrades

Conservative settings or node-level issues can delay upgrades, which affects your ability to stay current with patches and improvements.

Common causes of slow upgrades include:

* Low `maxSurge` or `maxUnavailable` values (limits parallelism).
* High soak times (long waits between node upgrades).
* Drain failures (see [Node drain failures](#scenario-2-node-drain-failures-and-pdbs)).

#### Recommendations to prevent or resolve

* Use `maxSurge=33%`, `maxUnavailable=1` for production.
* Use `maxSurge=50%`, `maxUnavailable=2` for dev/test.
* Use OS Security Patch for fast, targeted patching (avoids full node reimaging).
* Enable `undrainableNodeBehavior` to avoid upgrade blockers.

### Scenario 4: IP exhaustion

Surge nodes require more IPs. If the subnet is near capacity, node provisioning can fail (for example, `Error: SubnetIsFull`). This scenario is common with Azure Container Networking Interface, high `maxPods`, or large node counts.

#### Recommendations to prevent or resolve

* Ensure that your subnet has enough IPs for all nodes, surge nodes, and pods. The formula is `Total IPs = (Number of nodes + maxSurge) * (1 + maxPods)`.
* Reclaim unused IPs or expand the subnet (for example, from /24 to /22).
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

## Frequently asked questions

### Can I use open-source tools for validation?

Yes. Many open-source tools integrate well with AKS upgrade processes:

- [kube-no-trouble (kubent)](https://github.com/doitintl/kube-no-trouble): Scans for deprecated APIs before upgrades.
- [Trivy](https://aquasecurity.github.io/trivy/): Security scanning for container images and Kubernetes configurations.
- [Sonobuoy](https://sonobuoy.io/): Kubernetes conformance testing and cluster validation.
- [kube-bench](https://github.com/aquasecurity/kube-bench): Security benchmark checks against Center for Internet Security standards.
- [Polaris](https://github.com/FairwindsOps/polaris): Validation of Kubernetes best practices.
- [kubectl-neat](https://github.com/itaysk/kubectl-neat): Clean up Kubernetes manifests for validation.

### How do I validate API compatibility before upgrading?

Run deprecation checks by using tools like kubent:

```bash
# Install and run API deprecation scanner
kubectl apply -f https://github.com/doitintl/kube-no-trouble/releases/latest/download/knt-full.yaml

# Check for deprecated APIs in your cluster
kubectl run knt --image=doitintl/knt:latest --rm -it --restart=Never -- \
  -c /kubeconfig -o json > api-deprecation-report.json

# Review findings
cat api-deprecation-report.json | jq '.[] | select(.deprecated==true)'
```

### What makes AKS upgrades different from other Kubernetes platforms?

AKS provides several unique advantages:

- Native Azure integration with Azure Traffic Manager, Azure Load Balancer, and networking.
- Azure Kubernetes Fleet Manager for coordinated multicluster upgrades.
- Automatic node image patching without manual node management.
- Built-in validation for quota, networking, and credentials.
- Azure support for upgrade-related issues.

## Choose your upgrade path

This article provided you with a technical foundation. Now select your scenario-based path.

### Ready to execute?

| If you have... | Then go to... |
|----------------|---------------|
| Production environment | [Production upgrade strategies](aks-production-upgrade-strategies.md): Battle-tested patterns for zero-downtime upgrades |
| Databases or stateful apps | [Stateful workload patterns](stateful-workload-upgrades.md): Safe upgrade patterns for data persistence |
| Multiple environments | [Upgrade scenarios hub](upgrade-scenarios-hub.md): Decision tree for complex setups |
| Basic cluster | [Upgrade an AKS cluster](./upgrade-aks-cluster.md): Step-by-step cluster upgrade |

### Still deciding?

Use the [upgrade scenarios hub](upgrade-scenarios-hub.md) for a guided decision tree that considers your:

- Downtime tolerance
- Environment complexity
- Risk profile
- Timeline constraints

## Next tasks

* Review [AKS patch and upgrade guidance][upgrade-operators-guide] for best practices and planning tips before you start any upgrade.
* Always check for [API breaking changes](https://aka.ms/aks/breakingchanges) and validate your workload's compatibility with the target Kubernetes version.
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
