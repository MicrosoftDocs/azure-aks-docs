---
title: Use the Upgrade Insights API in Azure Kubernetes Service (AKS) (preview)
description: Learn what Upgrade Insights is and how to use its API in Azure Kubernetes Service (AKS) to evaluate upgrade readiness before you upgrade, interpret results, and troubleshoot common issues.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.date: 11/06/2026
author: stgriffi
ms.author: stgriffi
# Customer intent: "As an AKS operator, I want to check whether my cluster is ready for an upgrade before I start it, so that I can find and fix blockers early instead of during the upgrade."
---

# Use the Upgrade Insights API in Azure Kubernetes Service (AKS) (preview)

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

When you upgrade an AKS cluster, unsupported configurations, resource constraints, or other cluster-specific conditions can cause the upgrade to stall or fail partway through. If you discover these issues after the upgrade starts, you might unexpectedly disrupt running workloads and spend time troubleshooting mid-upgrade.

Upgrade Insights helps you check whether a cluster is ready for a specific upgrade *before* you start it. You submit the upgrade you're planning, such as a target Kubernetes version for the control plane, a node pool, or a node image. Upgrade Insights evaluates the cluster against that target and returns any issues it finds. You can fix those issues and re-run the evaluation. Use the result alongside your other upgrade readiness checks before starting the upgrade.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

> [!NOTE]
> Upgrade Insights is available through the `az aks upgrade-insights` and `az aks nodepool upgrade-insights` commands in the `aks-preview` Azure CLI extension, as shown in this article. These commands only evaluate upgrade readiness; they never start an upgrade.

## When to use Upgrade Insights

Use Upgrade Insights when you want to:

- Validate a Kubernetes control plane or node pool upgrade before starting it, so you can fix problems on your own schedule instead of during an active upgrade.
- Check node image upgrade readiness for a node pool.
- Include Upgrade Insights in automation or release pipelines alongside your other upgrade readiness checks.
- Re-validate a cluster after remediating a previously reported issue, without needing to start an upgrade to find out if the fix worked.

## How Upgrade Insights works

Upgrade Insights is a pre-upgrade assessment, not the upgrade itself. Requesting an insight is a dry run: AKS evaluates the proposed upgrade against the current state of your cluster, but doesn't change the cluster, reimage nodes, or move the cluster toward the target version.

Each evaluation you request is stored as an *insight* that you can retrieve later. It records:

- The upgrade you asked AKS to evaluate, such as a target Kubernetes version or node image.
- The evaluation result for that upgrade: `Passed`, `Warning`, or `Failed`.
- Any issues found and recommended actions.

An insight is a snapshot of the cluster when you generated it. Retrieving it later doesn't refresh the evaluation. Generate a new assessment after relevant cluster changes or remediation, and before starting an upgrade.

## Checks performed by Upgrade Insights

Upgrade Insights can report the following checks, depending on the upgrade you evaluate. The example messages summarize possible findings; they aren't exact service messages. Always use the message and recommended action returned for your cluster.

| Check | Example error message (illustrative) | What the check means |
|---|---|---|
| **Control plane:** Kubernetes version support | "The current Kubernetes version is out of support." | The version the cluster is running is outside its support window. |
| **Control plane:** Removed Kubernetes APIs | "APIs in use are removed in the target Kubernetes version." | Workloads or clients might rely on APIs that aren't available after the upgrade. |
| **Control plane:** Component compatibility | "An add-on or system component is incompatible with the target version." | A component might need an update before upgrading Kubernetes. |
| **Node pool:** Pod disruption budget | "A restrictive pod disruption budget prevents node drain." | A PDB might prevent pods from moving off a node during the upgrade. |
| **Node pool:** Subnet IP availability | "The subnet doesn't have enough available IP addresses for surge nodes." | The pool might not be able to create temporary nodes needed for the upgrade. |
| **Node pool:** Compute quota | "The VM quota is insufficient for surge nodes." | The subscription might not have enough quota for temporary upgrade capacity. |
| **Node pool:** Kubernetes version skew | "The node pool's target version is incompatible with the control plane's current version." | A node pool's Kubernetes minor version can't be newer than the control plane's. Upgrade the control plane first, or evaluate both together with `ControlPlaneAndAgentPools`. |
| **Node image:** Image upgrade interval | "The node image hasn't been upgraded within the required interval." | The pool's current node image is older than its required compliance interval. |

## Prerequisites

- Azure CLI installed and signed in.
- Azure CLI version 2.85.0 or later. To install or upgrade, see [Install Azure CLI][install-azure-cli].
- The `aks-preview` Azure CLI extension. Install it with `az extension add --name aks-preview`, or update an existing installation with `az extension update --name aks-preview`.
- The `AKSUpgradeInsightsPreview` feature flag registered on your subscription, and the feature available in your cluster's region. Installing or updating the `aks-preview` extension alone doesn't enable Upgrade Insights.
- Azure RBAC permission on the cluster resource: `Microsoft.ContainerService/managedClusters/generateUpgradeInsights/action` to request an evaluation, and `Microsoft.ContainerService/managedClusters/upgradeInsights/read` to list or show a stored insight.
- `kubectl` configured for your cluster (required only for the workload health checks in [Troubleshoot an assessment](#troubleshoot-an-assessment)).

## Register the preview feature

Register the `AKSUpgradeInsightsPreview` feature flag by using the [`az feature register`][az-feature-register] command:

```azurecli-interactive
az feature register --namespace "Microsoft.ContainerService" --name "AKSUpgradeInsightsPreview"
```

It takes a few minutes for the status to show *Registered*. Verify the registration status by using the [`az feature show`][az-feature-show] command:

```azurecli-interactive
az feature show --namespace "Microsoft.ContainerService" --name "AKSUpgradeInsightsPreview"
```

When the status shows *Registered*, refresh the registration of the `Microsoft.ContainerService` resource provider by using the [`az provider register`][az-provider-register] command:

```azurecli-interactive
az provider register --namespace "Microsoft.ContainerService"
```

## Request an upgrade readiness evaluation

Request an evaluation with `az aks upgrade-insights create` for the control plane alone or together with all node pools, or `az aks nodepool upgrade-insights create` for one node pool's Kubernetes version or node image.

### Request types

Choose the command and `--upgrade-type` based on the upgrade scope:

| Command | `--upgrade-type` | Purpose | Required flags |
|---|---|---|---|
| `az aks upgrade-insights create` | `ControlPlane` | Evaluate control plane Kubernetes upgrade readiness | `--target-kubernetes-ver` |
| `az aks upgrade-insights create` | `ControlPlaneAndAgentPools` (default) | Evaluate the control plane and all node pools together | `--target-kubernetes-ver` |
| `az aks nodepool upgrade-insights create` | `AgentPool` (default) | Evaluate Kubernetes upgrade readiness for one node pool | `--target-kubernetes-ver` |
| `az aks nodepool upgrade-insights create` | `NodeImage` | Evaluate node image readiness for one node pool | None (`--target-node-image-ver` is optional; omit it to evaluate the latest available image) |

### Examples

The examples in this section use these variables for your resource group and cluster name:

```azurecli-interactive
RESOURCE_GROUP=<resource-group>
CLUSTER_NAME=<cluster-name>
```

Replace the example target versions and pool names with values appropriate for your cluster. Check available Kubernetes upgrade versions before you evaluate an upgrade, so you know which target version to request:

```azurecli-interactive
az aks get-upgrades \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --output table
```

Generate a control plane insight:

```azurecli-interactive
az aks upgrade-insights create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --upgrade-type ControlPlane \
  --target-kubernetes-ver 1.37.1 \
  --output yaml
```

The following example output shows the `properties` object's evaluation result:

```output
evaluation:
  evaluatedAt: '2026-11-06T02:25:44Z'
  status: Passed
```

Generate a combined control plane and node pool insight:

```azurecli-interactive
az aks upgrade-insights create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --target-kubernetes-ver 1.37.1 \
  --output yaml
```

The following example output shows the `properties` object's control plane and node pool evaluations, where the control plane has a blocking pod disruption budget and the node pool passed:

```output
controlPlane:
  evaluation:
    detectedIssues:
    - issueType: PDBConstraint
      message: 'The operation is blocked by one or more unsatisfiable Pod Disruption
        Budgets (PDBs) that can prevent node drain. Blocking PDB details: PDB storefront/checkout-api:
        spec.maxUnavailable=0 permits no unavailable replicas and can block voluntary
        pod eviction during node drain (current status.disruptionsAllowed=0). For
        mitigation and more information, see https://aka.ms/aks/UnsatisfiablePDB.'
      severity: Blocking
    evaluatedAt: '2026-11-06T02:25:52Z'
    status: Failed
agentPools:
- agentPoolName: nodepool1
  evaluation:
    evaluatedAt: '2026-11-06T02:25:52Z'
    status: Passed
```

Each issue also includes a `recommendedActions` array with a title, a documentation link, and details for that specific finding, not shown here.

A node pool that's missing from the output, or one marked `NOT EVALUATED`, wasn't assessed. Don't assume it passed; generate a separate assessment for that pool.

Generate one node pool insight:

```azurecli-interactive
az aks nodepool upgrade-insights create \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name userpool1 \
  --target-kubernetes-ver 1.37.1 \
  --output yaml
```

A node pool's target Kubernetes version can't be newer than the control plane's current version; evaluating that combination reports a blocking compatibility issue alongside any other findings. Upgrade the control plane first, or evaluate both together using `ControlPlaneAndAgentPools`, which evaluates both against the requested target version. The following example output shows the `properties` object's evaluation for a pool whose subnet also ran out of surge capacity:

```output
evaluation:
  detectedIssues:
  - issueType: ComponentVersionMismatch
    message: Node pool version 1.37.1 and control plane version 1.36.5 are incompatible.
      Minor version of node pool version 37 is bigger than control plane version 36.
      For more information, please check https://aka.ms/aks/nodepoolmcversionincompatible
    severity: Blocking
  - issueType: SubnetIPExhausted
    message: Pre-allocated IPs 60 exceeds IPs available 59 in Subnet Cidr 10.20.0.0/26,
      Subnet Name snet-nodes. See http://aka.ms/aks/insufficientsubnetsize for troubleshooting
      steps. Surge nodes would also consume the subnet IP space, consider use smaller
      maxSurge or use maxUnavailable (aka.ms/aks/maxUnavailable).
    severity: Blocking
  status: Failed
```

Generate a node image insight:

```azurecli-interactive
az aks nodepool upgrade-insights create \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name userpool1 \
  --upgrade-type NodeImage \
  --output yaml
```

The following example output shows the `properties` object's evaluation result:

```output
evaluation:
  evaluatedAt: '2026-11-06T02:26:02Z'
  status: Passed
```

## Retrieve a stored insight

Every evaluation you request is stored, so you can read it again later without generating a new one. This feature is useful when you want to review a finding from an earlier evaluation during change approval, confirm what was last reported before a scheduled maintenance window, or check readiness status from automation without triggering a new evaluation on every run. Reading a stored insight doesn't refresh it or reflect cluster changes made since it was generated.

A stored insight has limited validity and isn't retrievable indefinitely. It might no longer be returned after it expires, or after relevant cluster or node pool state changes. If a request for a previously generated insight returns `NotFound`, generate a fresh assessment.

List every insight stored for a cluster, including node pool and node image insights:

```azurecli-interactive
az aks upgrade-insights list \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --output yaml
```

The following example output shows the name, scope, and status of two stored insights:

```output
- name: controlPlaneAndAgentPools-1.37.1
  properties:
    upgradeType: ControlPlaneAndAgentPools
    controlPlane:
      evaluation:
        status: Failed
- name: controlPlane-1.37.1
  properties:
    upgradeType: ControlPlane
    evaluation:
      status: Passed
```

Read one insight by name without regenerating it:

```azurecli-interactive
az aks upgrade-insights show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --insight-name controlPlaneAndAgentPools-1.37.1 \
  --output yaml
```

This command returns the same stored result shown earlier in [Request an upgrade readiness evaluation](#request-an-upgrade-readiness-evaluation), without generating a new evaluation.

To read a stored node pool or node image insight, use `az aks nodepool upgrade-insights show` with `--cluster-name` and `--name` for the pool instead.

## Review the findings

The assessment returns a readiness result for each evaluated scope. `Passed` means no issues were reported, `Warning` means there are issues to review, and `Failed` means at least one blocking issue was reported. A successful request isn't the same as a passing readiness result. If a scope has no result, don't assume it passed.

When issues are found, the results contain an array of findings with messages and recommended actions. Review each message, address the affected resources, and generate a new assessment to check whether the issue is resolved. Before upgrading, also check cluster and workload health; a preview assessment isn't a guarantee that an upgrade will succeed.

## Troubleshoot an assessment

### Can't request an assessment

Confirm your identity, subscription context, resource group and cluster name, and node pool name (for pool or node image requests), then retry:

```azurecli-interactive
az account show --output table
az account set --subscription <subscription-id>
```

### Check required permissions

If a command fails with an authorization error, confirm your Azure RBAC role assignment on the cluster includes the required action:

- `Microsoft.ContainerService/managedClusters/generateUpgradeInsights/action` to request an evaluation (`create`).
- `Microsoft.ContainerService/managedClusters/upgradeInsights/read` to list or show a stored insight.

### Check cluster health before regenerating

Check cluster provisioning state:

```azurecli-interactive
az aks show \
  --resource-group ${RESOURCE_GROUP} \
  --name ${CLUSTER_NAME} \
  --query "{provisioningState:provisioningState,powerState:powerState.code,kubernetesVersion:kubernetesVersion}" \
  --output table
```

Validate target upgrade availability:

```azurecli-interactive
az aks get-upgrades \
  --resource-group ${RESOURCE_GROUP} \
  --name ${CLUSTER_NAME} \
  --output table
```

Check node and workload health:

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

If failures continue, open a support request and include:

- Cluster resource ID.
- Region.
- Approximate failure timestamp (UTC).
- Target upgrade version.
- Requested upgrade and any reported issue messages.

## Related content

- [Upgrade options and recommendations for AKS](./upgrade-options.md)
- [How AKS cluster upgrades work](./upgrade-conceptual.md)
- [Use Planned Maintenance to schedule and control upgrades](./planned-maintenance.md)
- [Stop cluster upgrades on API breaking changes](./stop-cluster-upgrade-api-breaking-changes.md)

<!-- LINKS - internal -->
[install-azure-cli]: /cli/azure/install-azure-cli
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register
