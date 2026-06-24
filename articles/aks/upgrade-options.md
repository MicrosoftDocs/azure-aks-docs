---
title: Upgrade Options and Recommendations for Azure Kubernetes Service (AKS) Clusters
description: Learn about upgrade options for Azure Kubernetes Service (AKS) clusters, including scenario-based recommendations and why AKS Automatic is the recommended production-ready default for most workloads.
ms.topic: concept-article
ms.service: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.date: 06/22/2026
author: kaarthis
ms.author: kaarthis
ms.custom: scenarios
# Customer intent: "As a cloud administrator, I want to evaluate various upgrade options for Azure Kubernetes Service clusters so that I can implement a strategy that minimizes disruptions and ensures that my workloads remain updated and compliant with best practices."
---

# Upgrade options and recommendations for Azure Kubernetes Service (AKS) clusters

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

For most production workloads, AKS Automatic is the recommended default cluster experience. It provides production-ready defaults for cluster and node lifecycle operations, including managed upgrade behavior, built-in safeguards, and reduced operational overhead.

AKS Standard remains available for scenarios where you need deeper manual control over upgrade mechanics, networking choices, or node pool behavior.

This article gives you a technical foundation for AKS upgrades by covering upgrade options, common scenarios, and recommendations for both AKS Automatic and AKS Standard.

## What this article covers

This technical reference covers:

- Why AKS Automatic is the recommended production-ready default for most workloads.
- How upgrade behavior differs between AKS Automatic and AKS Standard.
- Manual versus automated upgrade paths, and when to use each.
- Common upgrade scenarios with specific recommendations.
- Optimization techniques for performance and minimal disruption.
- Validation processes and pre-upgrade checks.

For related guidance:

- For AKS Automatic overview and defaults, see [Introduction to Azure Kubernetes Service (AKS) Automatic](./intro-aks-automatic.md).
- For production-oriented AKS upgrade strategy details, see [AKS production upgrade strategies](aks-production-upgrade-strategies.md).
- For stateful workload upgrade patterns, see [Stateful workload upgrade patterns](stateful-workload-upgrades.md).
- For scenario-led guidance, see [AKS upgrade scenarios: Choose your path](upgrade-scenarios-hub.md).
- If you're new to AKS upgrades, start with the [upgrade scenarios hub](upgrade-scenarios-hub.md) for guided assistance.

## Quick navigation

| Your situation | Recommended path |
| -------------- | ---------------- |
| New or existing production workload with no special customization requirements | [Create an AKS Automatic cluster](./automatic/quick-automatic-managed-network.md) |
| Production cluster with strict custom upgrade controls | [Production upgrade strategies](aks-production-upgrade-strategies.md) |
| Database or stateful workloads | [Stateful workload patterns](stateful-workload-upgrades.md) |
| First-time AKS Standard upgrade | [Basic AKS cluster upgrade](./upgrade-aks-cluster.md) |
| Multiple environments or fleet operations | [Upgrade scenarios hub](upgrade-scenarios-hub.md) |
| Node pools or Windows nodes in AKS Standard | [Node pool upgrades][nodepool-upgrade] |
| Specific node pool only | [Single node pool upgrade][specific-nodepool] |

## Upgrade operating models

### AKS Automatic (recommended production default)

AKS Automatic is designed for production-ready operation by default. For upgrades, AKS Automatic provides:

- Managed system node pools.
- Automatic cluster upgrade behavior with platform-managed defaults.
- Automatic node OS image upgrade behavior with security-focused cadence.
- Built-in checks for deprecated Kubernetes APIs.
- Planned maintenance schedule support.

Use AKS Automatic when you want to minimize manual upgrade orchestration and keep production clusters aligned to supported versions with less effort.

### AKS Standard (advanced control model)

AKS Standard gives you direct control over upgrade sequencing and tuning. You choose and manage:

- Manual or automatic upgrade configuration.
- Upgrade channel selection.
- Node pool and surge behavior.
- Operational procedures around maintenance windows and workload disruption budgets.

Use AKS Standard when your environment requires customization that goes beyond AKS Automatic defaults.

## Upgrade options

### Perform manual upgrades

Applies primarily to AKS Standard, or to specialized operational workflows.

Manual upgrades let you control when your cluster upgrades to a new Kubernetes version. These upgrades are useful for testing, staged rollouts, and targeted version adoption.

- [Upgrade an AKS cluster](./upgrade-aks-cluster.md)
- [Upgrade multiple AKS clusters via Azure Kubernetes Fleet Manager](/azure/kubernetes-fleet/update-orchestration)
- [Upgrade the node image](./node-image-upgrade.md)
- [Customize node surge upgrade](./upgrade-aks-cluster.md#customize-node-surge-upgrade)
- [Process node OS updates](./node-updates-kured.md)

### Configure automatic upgrades

For AKS Standard, automatic upgrades help keep clusters on supported versions while preserving control over policy and scheduling. In AKS Automatic, upgrade automation and guardrails are already part of the default operating model.

- [Automatically upgrade an AKS cluster](./auto-upgrade-cluster.md)
- [Automatically upgrade multiple AKS clusters via Azure Kubernetes Fleet Manager](/azure/kubernetes-fleet/update-automation)
- [Use planned maintenance to schedule and control upgrades](./planned-maintenance.md)
- [Stop AKS cluster upgrades automatically on API breaking changes (preview)](./stop-cluster-upgrade-api-breaking-changes.md)
- [Automatically upgrade AKS cluster node operating system images](./auto-upgrade-node-image.md)
- [Apply security updates to AKS nodes automatically by using GitHub actions](./node-upgrade-github-actions.md)

### Special considerations for node pools that span multiple availability zones

AKS uses best-effort zone balancing in node pools. During an upgrade surge, the zones for surge nodes in virtual machine scale sets are unknown ahead of time, which can temporarily cause an unbalanced zone configuration. AKS deletes surge nodes after the upgrade and restores the original zone balance.

To keep zones balanced, set surge to a multiple of three nodes. Persistent volume claims that use Azure locally redundant storage disks are zone bound and might cause downtime if surge nodes are in a different zone. Use a [pod disruption budget (PDB)](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) to maintain high availability during drains.

### Optimize upgrades to improve performance and minimize disruptions

Combine [planned maintenance window][planned-maintenance], [max surge](./upgrade-aks-cluster.md#customize-node-surge-upgrade), [PDB][pdb-spec], [node drain timeout][drain-timeout], and [node soak time][soak-time] to increase the likelihood of successful, low-disruption upgrades.

#### AKS Automatic

In AKS Automatic, platform-level upgrade behavior is preconfigured. Focus your tuning on workload resilience and capacity readiness:

- Validate pod disruption budgets and replica counts.
- Ensure quota and subnet capacity for expected growth.
- Set planned maintenance schedules aligned to low-traffic periods.
- Monitor upgrade events and critical workload readiness.

#### AKS Standard

In AKS Standard, tune upgrade controls directly:

- [Planned maintenance window][planned-maintenance]: Schedule auto-upgrade during low-traffic periods. Use at least four hours.
- [Max surge](./upgrade-aks-node-pools-rolling.md#set-max-surge-value): Higher values speed upgrades but might disrupt workloads. Use 33% for production.
- [Max unavailable](./upgrade-aks-node-pools-rolling.md#customize-unavailable-nodes): Use when capacity is limited.
- [Pod disruption budget][pdb-spec]: Set to limit pods down during upgrades. Validate for your service.
- [Node drain timeout][drain-timeout]: Configure pod eviction wait duration. The default is 30 minutes.
- [Node soak time][soak-time]: Stagger upgrades to minimize downtime. The default is 0 minutes.

| Upgrade settings | How extra nodes are used | Expected behavior |
| ---------------- | ------------------------ | ----------------- |
| `maxSurge=5`, `maxUnavailable=0` | 5 surge nodes | Five nodes are surged for upgrade. |
| `maxSurge=5`, `maxUnavailable=0` | 0-4 surge nodes | Upgrade fails because of insufficient surge nodes. |
| `maxSurge=0`, `maxUnavailable=5` | N/A | Five existing nodes are drained for upgrade. |

> [!NOTE]
> Before you upgrade, check for API breaking changes and review the [AKS release notes](https://github.com/Azure/AKS/releases) to avoid disruptions.

## Validations used in the upgrade process

AKS performs pre-upgrade validations to ensure cluster health:

- **API breaking changes:** Detects deprecated APIs.
- **Kubernetes upgrade version:** Ensures a valid upgrade path.
- **PDB configuration:** Checks for misconfigured PDBs (for example, `maxUnavailable=0`).
- **Quota:** Confirms enough quota for surge nodes.
- **Subnet:** Verifies sufficient IP addresses.
- **Certificates/service principals:** Detects expired credentials.
- **Managed Resource Lock Check:** Checks for resource locks applied to the managed cluster resource group.

These checks apply across AKS. In AKS Automatic, they're integrated into the managed upgrade path; in AKS Standard, they're part of your operational workflow.

## Common upgrade scenarios and recommendations

### Scenario 1: Capacity constraints

If your cluster is limited by product tier or regional capacity, upgrades might fail when surge nodes can't be provisioned. This situation is common with specialized product tiers (like GPU nodes) or in regions with limited resources. Errors such as `SKUNotAvailable`, `AllocationFailed`, or `OverconstrainedAllocationRequest` might occur if `maxSurge` is set too high for available capacity.

#### AKS Automatic guidance

- Keep planned maintenance windows in place.
- Validate subscription quota and subnet headroom before expected upgrade periods.
- Keep workload scaling and disruption budgets aligned to maintenance windows.

#### AKS Standard guidance

- Use `maxUnavailable` to upgrade by using existing nodes instead of surging new ones. For more information, see [Customize unavailable nodes during upgrade](./upgrade-aks-node-pools-rolling.md#customize-unavailable-nodes).
- Lower `maxSurge` to reduce extra capacity needs. For more information, see [Customize node surge upgrade](./upgrade-aks-node-pools-rolling.md#customize-node-surge).
- For security-only updates, use security patch reimages that don't require surge nodes. For more information, see [Apply security and kernel updates to Linux nodes in Azure Kubernetes Service](./node-updates-kured.md).

### Scenario 2: Node drain failures and PDBs

Upgrades require draining nodes (evicting pods). Drains can fail when pods are slow to terminate or strict [Pod Disruption Budgets (PDBs)](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/) block pod evictions.

Example error:

```output
Code: UpgradeFailed
Message: Drain node ... failed when evicting pod ... Cannot evict pod as it would violate the pod's disruption budget.
```

#### AKS Automatic guidance

- Treat PDB and replica strategy as the primary reliability controls.
- Validate disruption budgets in staging before production rollout.
- Keep critical workloads configured for rolling eviction success.

#### AKS Standard guidance

##### Option 1: Force upgrade, bypass PDB constraints

> [!WARNING]
> Force upgrade bypasses Pod Disruption Budget (PDB) constraints and might cause service disruption by draining all pods simultaneously. Before using this option, first try to fix PDB misconfigurations (review the PDB minAvailable/maxUnavailable settings, ensure adequate pod replicas, verify PDBs aren't blocking all evictions).

Use force upgrade only when PDBs prevent critical upgrades and can't be resolved. This action overrides PDB protections and can potentially cause complete service unavailability during the upgrade.

**Requirements**: Azure CLI 2.79.0+ or AKS API version 2025-09-01+

```azurecli-interactive
az aks upgrade \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --kubernetes-version $KUBERNETES_VERSION \
  --enable-force-upgrade \
  --upgrade-override-until yyyy-mm-ddT13:00:00Z
```

> [!NOTE]
>
> - The `upgrade-override-until` parameter defines when validation bypass ends (must be a future date/time)
> - If not specified, the window defaults to three days from current time
> - The `Z` indicates UTC/GMT time zone

> [!WARNING]
> When force upgrade is enabled, it takes precedence over all other drain configurations. The undrainable node behavior settings (Option 2) aren't applied when force upgrade is active.

##### Option 2: Handle undrainable nodes while honoring PDBs

Use this conservative approach to honor PDBs while preventing upgrade failures.

Configure undrainable node behavior:

```azurecli-interactive
az aks nodepool update \
  --resource-group <resource-group-name> \
  --cluster-name <cluster-name> \
  --name <node-pool-name> \
  --undrainable-node-behavior Cordon \
  --max-blocked-nodes 2 \
  --drain-timeout 30
```

Behavior options:

- **Schedule (default)**: Deletes blocked node and surges replacement.
- **Cordon (recommended)**: Cordons node and labels it as `kubernetes.azure.com/upgrade-status=Quarantined`.

Max blocked nodes (preview):

- Specifies how many nodes that fail to drain are tolerated
- Requires `undrainable-node-behavior` to be set
- Defaults to `maxSurge` value (typically 10%) if not specified

###### Prerequisites for max blocked nodes

The Azure CLI `aks-preview` extension version 18.0.0b9 or later is required to use the max blocked nodes feature.

```azurecli-interactive
# Install or update the aks-preview extension
az extension add --name aks-preview
az extension update --name aks-preview
```

###### Example configuration with max blocked nodes

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

##### Option 3: Automatic PDB management (preview)

Use the [automatic PDB management](automatic-pod-disruption-budget-management.md) extension to proactively resolve PDB-blocked drains without bypassing PDB protections or requiring manual cleanup of quarantined nodes. Automatic PDB management detects when a PDB blocks eviction on a cordoned node and temporarily scales up the deployment's replicas so the disruption budget is satisfied. After the drain completes, it scales replicas back to their original count.

Automatic PDB management can also automatically create PDBs for deployments that don't have one, ensuring your workloads are protected during upgrade drains. For installation and configuration details, see [Manage Pod Disruption Budgets automatically during AKS upgrades](automatic-pod-disruption-budget-management.md).

###### Recommendations to prevent drain failures

- Set `maxUnavailable` in PDBs to allow at least one pod eviction
- Increase pod replicas to meet disruption budget requirements
- Extend drain timeout if workloads need more time. (The default is *30 minutes*.)
- Use [automatic PDB management](automatic-pod-disruption-budget-management.md) to automate PDB creation and replica scaling during drain operations.
- Test PDBs in staging, monitor upgrade events, and use blue-green deployments for critical workloads. For more information, see [Blue-green deployment of AKS clusters](/azure/architecture/guide/aks/blue-green-deployment-for-aks).

###### Verify undrainable nodes

- The blocked nodes are unscheduled for pods and marked with the label `"kubernetes.azure.com/upgrade-status: Quarantined"`.
- Verify the label on any blocked nodes when there's a drain node failure on upgrade:

    ```bash
    kubectl get nodes --show-labels=true
    ```

###### Resolve undrainable nodes

1. Remove the responsible PDB:

    ```bash
    kubectl delete pdb <pdb-name>
    ```

1. Remove the `kubernetes.azure.com/upgrade-status: Quarantined` label:

    ```bash
    kubectl label nodes <node-name> kubernetes.azure.com/upgrade-status-
    ```

1. Optionally, delete the blocked node:

    ```azurecli-interactive
    az aks nodepool delete-machines --cluster-name <cluster-name> --machine-names <machine-name> --name <node-pool-name> --resource-group <resource-group-name>
    ```

1. After you finish this step, you can reconcile the cluster status by performing any update operation without the optional fields as outlined in [`az aks`](/cli/azure/aks#az-aks-update). Alternatively, you can scale the node pool to the same number of nodes as the count of upgraded nodes. This action ensures that the node pool gets to its intended original size. AKS prioritizes the removal of the blocked nodes. This command also restores the cluster provisioning status to `Succeeded`. In the following example, `2` is the total number of upgraded nodes.

    ```azurecli-interactive
    # Update the cluster to restore the provisioning status
    az aks update --resource-group <resource-group-name> --name <cluster-name>

    # Scale the node pool to restore the original size
    az aks nodepool scale --resource-group <resource-group-name> --cluster-name <cluster-name> --name <node-pool-name> --node-count 2
    ```

### Scenario 3: Slow upgrades

Conservative settings or node-level issues can delay upgrades, which affects your ability to stay current with patches and improvements.

Common causes of slow upgrades include:

- Low `maxSurge` or `maxUnavailable` values (limits parallelism).
- High soak times (long waits between node upgrades).
- Drain failures (see [Node drain failures](#scenario-2-node-drain-failures-and-pdbs)).

#### AKS Automatic guidance

- Keep maintenance schedules current.
- Monitor upgrade event health and workload readiness.
- Resolve blocking PDB or capacity problems quickly to avoid prolonged lag.

#### AKS Standard guidance

- Use `maxSurge=33%`, `maxUnavailable=1` for production.
- Use `maxSurge=50%`, `maxUnavailable=2` for dev/test.
- Use OS Security Patch for fast, targeted patching (avoids full node reimaging).
- Enable `--undrainable-node-behavior` to avoid upgrade blockers.

### Scenario 4: IP exhaustion

Surge nodes require more IPs. If the subnet is near capacity, node provisioning can fail (for example, `Error: SubnetIsFull`). This scenario is common with Azure Container Networking Interface, high `maxPods`, or large node counts.

#### AKS Automatic guidance

- Validate subnet and capacity plans before production expansion.
- Monitor network utilization as part of routine operations.

#### AKS Standard guidance

- Ensure that your subnet has enough IPs for all nodes, surge nodes, and pods. The formula is `Total IPs = (Number of nodes + maxSurge) * (1 + maxPods)`.
- Reclaim unused IPs or expand the subnet (for example, from /24 to /22).
- Lower `maxSurge` if subnet expansion isn't possible.

    ```azurecli-interactive
    az aks nodepool update \
      --resource-group <resource-group-name> \
      --cluster-name <cluster-name> \
      --name <node-pool-name> \
      --max-surge 10%
    ```

- Monitor IP usage with Azure Monitor or custom alerts.
- Reduce `maxPods` per node, clean up orphaned load balancer IPs, and plan subnet sizing for high-scale clusters.

## Frequently asked questions

### Should I use AKS Automatic or AKS Standard for production upgrades?

For most production workloads, use AKS Automatic. It's designed as the production-ready default with managed upgrade behavior and built-in guardrails.

Use AKS Standard when you need advanced manual control over upgrade sequencing, infrastructure choices, or node pool operations.

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

- Managed operational paths in AKS Automatic for lower upgrade overhead.
- Native Azure integration with Azure Traffic Manager, Azure Load Balancer, and networking.
- Azure Kubernetes Fleet Manager for coordinated multicluster upgrades.
- Automatic node image patching without manual node management.
- Built-in validation for quota, networking, and credentials.
- Azure support for upgrade-related issues.

## Choose your upgrade path

This article provided you with a technical foundation. Now select your scenario-based path.

### Ready to execute?

| If you have... | Then go to... |
| -------------- | ------------- |
| Production workload and no special customization constraints | [Create an AKS Automatic cluster](./automatic/quick-automatic-managed-network.md) |
| Production environment with advanced custom upgrade needs| [Production upgrade strategies](aks-production-upgrade-strategies.md) |
| Databases or stateful apps | [Stateful workload patterns](stateful-workload-upgrades.md) |
| Multiple environments | [Upgrade scenarios hub](upgrade-scenarios-hub.md) |
| Basic AKS Standard cluster | [Upgrade an AKS cluster](./upgrade-aks-cluster.md) |

### Still deciding?

Use the [upgrade scenarios hub](upgrade-scenarios-hub.md) for a guided decision tree that considers your:

- Downtime tolerance
- Environment complexity
- Risk profile
- Timeline constraints

## Final recommendations

- Use [AKS Automatic](./intro-aks-automatic.md) for most production workloads.
- Review [AKS patch and upgrade guidance][upgrade-operators-guide] for best practices and planning tips before you start any upgrade.
- Always check for [API breaking changes](https://aka.ms/aks/breakingchanges) and validate your workload's compatibility with the target Kubernetes version.
- Test upgrade settings (such as `maxSurge`, `maxUnavailable`, and PDBs) in a staging environment to minimize production risk.
- Monitor upgrade events and cluster health throughout the process.

<!-- LINKS - external -->
[pdb-spec]: https://kubernetes.io/docs/tasks/run-application/configure-pdb/

<!-- LINKS - internal -->
[drain-timeout]: ./upgrade-aks-cluster.md#set-node-drain-timeout-value
[soak-time]: ./upgrade-aks-cluster.md#set-node-soak-time-value
[nodepool-upgrade]: upgrade-node-image.md
[planned-maintenance]: planned-maintenance.md
[specific-nodepool]: upgrade-node-image.md#upgrade-a-specific-node-pool
[upgrade-operators-guide]: /azure/architecture/operator-guides/aks/aks-upgrade-practices
