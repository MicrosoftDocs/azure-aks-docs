---
title: Upgrade health gates in Azure Kubernetes Service (AKS) (preview)
description: Learn how to use upgrade health gates to pause or stop AKS node pool upgrades based on workload and infrastructure health signals.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.date: 10/15/2026
author: stevegriffith
ms.author: stgriffi
# Customer intent: As a Kubernetes administrator, I want AKS upgrades to respond to workload health signals so that I can stop an upgrade before an unhealthy change affects more nodes.
---

# Upgrade health gates in Azure Kubernetes Service (AKS) (preview)

Upgrade health gates let Azure Kubernetes Service (AKS) check workload and infrastructure health during an upgrade before continuing to the next node. You define the health policy for a node pool, and a health monitor in the cluster responds to AKS health check requests. If the monitor reports unhealthy, AKS stops the upgrade instead of continuing through the rest of the pool.

This article explains how upgrade health gates work, when to use them, and how to configure a basic upgrade health gate for an AKS node pool.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

> [!IMPORTANT]
> Upgrade health gates are in preview. The Azure CLI and API enablement commands can change before general availability. Review the [AKS preview support policy](./support-policies.md#preview-features-or-feature-flags) before using this feature with production workloads.

## How upgrade health gates work

AKS uses Kubernetes custom resources as the contract between an upgrade operation and your health monitoring system:

- `UpgradeGatePolicy` defines which cluster or node pool targets are gated and which health provider is expected to respond.
- `UpgradeOperation` represents the active AKS upgrade.
- `HealthCheckRequest` asks a health provider to evaluate a specific node, node pool, or cluster scope.
- `HealthSignal` contains the health provider's verdict.

The health provider can be a Microsoft-managed monitor, your own controller, or an observability integration that watches `HealthCheckRequest` resources and writes `HealthSignal` resources. AKS evaluates those signals during the upgrade.

| Health check request scope | `True` signal | `False` signal | `Unknown` or no valid signal |
| --- | --- | --- | --- |
| `Node` | Continue when every matching health provider reports `True` for the node. | Stop the upgrade. | Wait until `nodeTimeout`, then stop the upgrade. |
| `NodePool` | No effect. Node checks continue normally. | Stop the node pool upgrade. | No effect. |
| `Cluster` | No effect. Node checks continue normally. | Stop all gated node pool upgrades in the operation. | No effect. |

Upgrade health gates don't replace your application monitoring. They connect your monitoring to the AKS upgrade workflow so upgrades can stop when health deteriorates.

> [!IMPORTANT]
> A health provider must answer node-scoped health check requests. It can't act only as a circuit breaker at the node pool or cluster level. Once an `UpgradeGatePolicy` covers a node pool, every node in that pool waits for that provider's node-level verdict. If a registered provider never responds to node-scoped requests, the first upgraded node waits for `nodeTimeout` and the upgrade stops, even if the provider is actively answering node pool-scoped or cluster-scoped requests. Node pool-scoped and cluster-scoped requests are optional circuit breakers that supplement node-level checks—they don't replace them.

Use a node pool-scoped or cluster-scoped circuit breaker when your monitoring detects a broader problem, such as a workload error-rate spike during an upgrade, that isn't visible from any single node's health.

## When to use upgrade health gates

Use upgrade health gates when you want AKS to react to health checks such as:

- Application latency or error-rate alerts.
- Workload readiness or crash-loop checks.
- Node-level health checks after a new node is created or reimaged.
- Synthetic tests or smoke tests that run during an upgrade.
- Multi-step validation where an operator or automation approves each upgraded node.

For example, a platform team can gate every upgraded node in the cluster, or gate only the production node pool that hosts a latency-sensitive API. After each matching node is upgraded, the team's health controller evaluates the relevant health signals and writes a `HealthSignal`. AKS continues only when the controller reports the node is healthy.

## Limitations

The following limitations apply during preview:

- Upgrades that you start by using `az aks upgrade` fail if the cluster name contains uppercase letters or underscores (`_`). To upgrade these clusters, upgrade the control plane by using `az aks upgrade --control-plane-only`, and then upgrade each node pool by using `az aks nodepool upgrade`.
- Node pools that use the `VirtualMachines` node pool type aren't gated. Upgrades on these node pools run without health checks, and no error or warning is shown.
- When the Microsoft-managed on-demand monitor is enabled (`--enable-on-demand-monitor`), the gate waits up to one minute for it to report on each new or reimaged node. If the node takes longer to become ready, the upgrade stops. You can't change this timeout. To avoid it, disable the on-demand monitor by using `az aks update --disable-on-demand-monitor` before you upgrade.

## Prerequisites

Before you start, ensure you have:

- An AKS Standard cluster. Upgrade health gates aren't supported on AKS Automatic during preview.
- Node pools that use the Virtual Machine Scale Sets (VMSS) node pool type.
- Azure CLI version 2.85.0 or later. Check your version by using the `az version` command. To install or update, see [Install Azure CLI](/cli/azure/install-azure-cli).
- The `aks-preview` Azure CLI extension version 22.0.0b15 or later. To install or update, see [Install the `aks-preview` CLI extension](#install-the-aks-preview-cli-extension).
- `kubectl` configured for your cluster.
- Permissions to create custom resources in the cluster.
- A health provider that watches `HealthCheckRequest` resources and writes `HealthSignal` resources.

> [!NOTE]
> For early preview testing, you can manually write `HealthSignal` resources to understand the contract. For production-like usage, use a controller or monitoring integration to evaluate health and write signals automatically.

## Enable upgrade health gates on a cluster

### Install the `aks-preview` CLI extension

[!INCLUDE [aks-preview-cli-extension](includes/aks-preview-cli-extension.md)]

### Register the `EnableUpgradeGatePreview` feature flag

1. Register the `EnableUpgradeGatePreview` feature flag in your subscription by using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace Microsoft.ContainerService --name EnableUpgradeGatePreview
    ```

1. Check the registration status by using the [`az feature show`][az-feature-show] command. Wait a few minutes for the status to show *Registered*.

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name EnableUpgradeGatePreview
    ```

1. When the status shows *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider by using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

### Enable upgrade health gates on your cluster

You can enable upgrade health gates at the cluster level, which applies to every node pool, or at the node pool level, which applies only to that pool. A cluster-level opt-in is one-directional: once upgrade health gates are enabled on the cluster, no node pool can opt itself out. The reverse works as intended: a node pool can independently opt in while the cluster-level setting stays disabled.

To enable upgrade health gates for every node pool in the cluster, use the [`az aks update`][az-aks-update] command with the `--enable-upgrade-gate` flag:

```azurecli-interactive
az aks update \
  --resource-group <resource-group> \
  --name <cluster-name> \
  --enable-upgrade-gate
```

Verify the setting is enabled by using the [`az aks show`][az-aks-show] command:

```azurecli-interactive
az aks show \
  --resource-group <resource-group> \
  --name <cluster-name> \
  --query upgradeSettings.upgradeGateSettings
```

Expected output:

```output
{
  "enabled": true
}
```

To enable upgrade health gates for only one node pool, leave the cluster-level setting disabled, and use the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--enable-upgrade-gate` flag:

```azurecli-interactive
az aks nodepool update \
  --resource-group <resource-group> \
  --cluster-name <cluster-name> \
  --name <node-pool-name> \
  --enable-upgrade-gate
```

Verify the node pool setting by using the [`az aks nodepool show`][az-aks-nodepool-show] command:

```azurecli-interactive
az aks nodepool show \
  --resource-group <resource-group> \
  --cluster-name <cluster-name> \
  --name <node-pool-name> \
  --query upgradeSettings.upgradeGateSettings
```

You can also enable upgrade health gates when you create a cluster or add a node pool by passing `--enable-upgrade-gate` to [`az aks create`][az-aks-create] or [`az aks nodepool add`][az-aks-nodepool-add].

After enablement completes, verify the custom resource definitions are installed:

```azurecli-interactive
kubectl get crd \
  upgradegatepolicies.upgrade.aks.io \
  upgradeoperations.upgrade.aks.io \
  healthcheckrequests.health.aks.io \
  healthsignals.health.aks.io
```

Expected output:

```output
NAME                                 CREATED AT
upgradegatepolicies.upgrade.aks.io   <timestamp>
upgradeoperations.upgrade.aks.io     <timestamp>
healthcheckrequests.health.aks.io    <timestamp>
healthsignals.health.aks.io          <timestamp>
```

> [!IMPORTANT]
> Enabling upgrade health gates and applying an `UpgradeGatePolicy` are both required before a node pool is actually gated. Enabling `upgradeGateSettings` without a matching policy has no effect: the pool upgrades at full speed with no health check requests. A policy that targets a pool without `upgradeGateSettings` enabled for that pool also has no effect, even if the policy was applied successfully. Neither condition produces an error or warning, so confirm both the setting and the policy before relying on a gate.

## Create an upgrade gate policy

Create an `UpgradeGatePolicy` that gates a node pool named `nodepool1`. This example uses a provider named `contoso-health`, which should match the `health.aks.io/provider` label used by your health provider's `HealthSignal` resources.

An `UpgradeGatePolicy` can target the whole cluster or a specific node pool. Use `scope: Cluster` to gate every upgraded node in the cluster. Use `scope: NodePool` with a `name` to gate a specific node pool. If both rules match, the node pool rule is more specific and overrides the cluster rule for nodes in that pool.

```yaml
apiVersion: upgrade.aks.io/v1alpha1
kind: UpgradeGatePolicy
metadata:
  name: production-api-gate
spec:
  provider: contoso-health
  rules:
  - target:
      scope: NodePool
      name: nodepool1
    nodeTimeout: 5m
```

The `nodeTimeout` value controls how long AKS waits for that provider's node-level verdict after a node is upgraded. If you omit `nodeTimeout`, the default is one minute. Values are capped at five minutes. The only supported `onFailure` action during preview is `Abort`, which is also the default.

If you also configure a [node soak time](./upgrade-aks-node-pools-rolling.md#customize-node-soak-time), both apply to each node in sequence. AKS drains the node, waits for the soak time, reimages the node, and then waits up to `nodeTimeout` for the node-level health verdict before it moves to the next node. Node pool-scoped and cluster-scoped signals are checked before each node is drained, so a problem your provider detects during the soak period stops the upgrade before the next node is drained. Plan for each node to take up to the soak time plus `nodeTimeout` longer.

To gate every upgraded node in the cluster, use a cluster-scoped rule and omit the node pool name:

```yaml
apiVersion: upgrade.aks.io/v1alpha1
kind: UpgradeGatePolicy
metadata:
  name: cluster-health-gate
spec:
  provider: contoso-health
  rules:
  - target:
      scope: Cluster
    nodeTimeout: 5m
```

Apply the policy:

```azurecli-interactive
kubectl apply -f production-api-gate.yaml
kubectl get upgradegatepolicy production-api-gate
```

The policy applies to upgrades that start after the policy is created. AKS snapshots matching policies at the start of the upgrade operation, so changing or deleting a policy after an upgrade starts doesn't change the gate behavior for that in-progress upgrade.

## Start a gated node pool upgrade

Start the node pool upgrade by using the normal AKS upgrade command.

```azurecli-interactive
az aks nodepool upgrade \
  --resource-group <resource-group> \
  --cluster-name <cluster-name> \
  --name nodepool1 \
  --kubernetes-version <target-version> \
  --yes
```

AKS creates an `UpgradeOperation` and then creates `HealthCheckRequest` resources when health evaluation is required.

Control-plane-only upgrades aren't gated because they don't upgrade nodes. Node pool upgrades, full-cluster upgrades that include node pools, and node image upgrades can be gated. Force upgrade bypasses upgrade health gates for the override window.

Watch the gate resources in another terminal:

```azurecli-interactive
kubectl get upgradeoperation,healthcheckrequest,healthsignal --watch
```

## Respond to a health check request

Your health provider should create a `HealthSignal` with:

- The same provider label as the `UpgradeGatePolicy`.
- An owner reference to the `HealthCheckRequest`.
- A `spec.type` that matches the request scope, such as `NodeHealth`, `NodePoolHealth`, or `ClusterHealth`.
- A status condition that reports `True`, `False`, or `Unknown`.

The following example shows the shape of a healthy response for a request stored in the `HCR_NAME` environment variable:

```azurecli-interactive
HCR_NAME=<health-check-request-name>
HCR_UID=$(kubectl get healthcheckrequest $HCR_NAME -o jsonpath='{.metadata.uid}')

cat <<EOF | kubectl apply -f -
apiVersion: health.aks.io/v1alpha1
kind: HealthSignal
metadata:
  name: ${HCR_NAME}-contoso-health
  labels:
    health.aks.io/provider: contoso-health
  ownerReferences:
  - apiVersion: health.aks.io/v1alpha1
    kind: HealthCheckRequest
    name: $HCR_NAME
    uid: $HCR_UID
    controller: true
    blockOwnerDeletion: true
spec:
  type: NodeHealth
EOF

kubectl patch healthsignal ${HCR_NAME}-contoso-health \
  --subresource=status \
  --type=merge \
  -p "{\"status\":{\"conditions\":[{\"type\":\"Ready\",\"status\":\"True\",\"reason\":\"Healthy\",\"message\":\"Health checks passed\",\"lastTransitionTime\":\"$(date -u +%FT%TZ)\"}]}}"
```

> [!IMPORTANT]
> A signal without the expected provider label or owner reference is ignored. If AKS doesn't receive a valid signal before the timeout, the upgrade stops.

## Validate upgrade behavior

Use the following checks to validate the flow:

```azurecli-interactive
kubectl get upgradeoperation
kubectl get healthcheckrequest
kubectl get healthsignal

az aks nodepool show \
  --resource-group <resource-group> \
  --cluster-name <cluster-name> \
  --name nodepool1 \
  --query "{state:provisioningState,version:currentOrchestratorVersion}" \
  --output table
```

When the upgrade completes successfully, AKS removes the in-progress upgrade and health check resources. The `UpgradeGatePolicy` remains for future upgrades.

If the upgrade stops because a health signal reports unhealthy or times out, the node pool's provisioning state changes to `Failed`. For a full cluster upgrade (`az aks upgrade`), the cluster's provisioning state also changes to `Failed`.

AKS doesn't roll back the nodes that it already upgraded. Those nodes, including any surge node, stay on the new version, and the remaining nodes stay on the previous version. Workloads continue to run on nodes of both versions.

The node pool's `orchestratorVersion` shows the target version even though not every node is upgraded. To see which nodes are on which version, run `kubectl get nodes`.

To finish the upgrade, fix the underlying issue, then rerun the same upgrade command with the same target version. AKS upgrades only the nodes that weren't upgraded yet, and creates a new operation and new health check requests. If you rerun `az aks upgrade` while the cluster is in the `Failed` state, the CLI shows `Cluster currently in failed state. Proceeding with upgrade to existing version <version> to attempt resolution of failed cluster state.` This message is expected.

When an upgrade stops because of a gate, the `az aks nodepool upgrade` or `az aks upgrade` command reports the reason directly in its output, including an `UpgradeAbortAtUpgradeGate` error code, the affected node name, and the health signal's reason. Capture this output if you run upgrades through automation: querying the node pool or operation afterward doesn't currently return the same level of detail.

`HealthCheckRequest` and `HealthSignal` resources are deleted shortly after AKS reaches a verdict, and AKS doesn't retain a history of past verdicts. If you need an audit trail of what your health provider reported and when, have the provider log its own decisions to a durable system, such as your observability platform, before it writes each `HealthSignal`.

## Troubleshoot upgrade health gates

### Health check timed out

```text
Code: UpgradeAbortAtUpgradeGate
SubCode: HealthCheckFailed
Message: Health check failed for reimaged node aks-nodepool1-12345678-vmss000002:
  Health check timeout: provider "contoso-health" did not report a healthy
  verdict for aks-nodepool1-12345678-vmss000002 within 1m0s
```

**Cause:** The provider named in the message didn't report the node healthy within its `nodeTimeout`. Silence, an `Unknown` condition, or a signal AKS couldn't match to the request all count as unhealthy.

**Resolution:** Run `kubectl get upgradegatepolicy -o yaml` to confirm the `nodeTimeout` that applies to this pool, and check whether your health provider is running and can reach the `HealthCheckRequest` in time. AKS reads policies once, at the start of the upgrade, so an edit made after the upgrade started doesn't apply until the next run. Fix or speed up the provider, or raise `nodeTimeout` (up to five minutes), then rerun the same upgrade command with the same target version.

### A health signal reported a node unhealthy

```text
Code: UpgradeAbortAtUpgradeGate
SubCode: HealthCheckFailed
Message: Health check failed for reimaged node aks-nodepool1-12345678-vmss000002:
  Health signal indicates aks-nodepool1-12345678-vmss000002 is unhealthy:
  Ready (Reason: PodsCrashLooping) - 3 pods in CrashLoopBackOff on node
```

**Cause:** A registered health provider wrote a `HealthSignal` with a `False` condition for this node. The reason and message come directly from your provider.

**Resolution:** Fix the condition your provider flagged, then rerun the same upgrade command with the same target version. To get past the gate without fixing the cause, narrow or delete the `UpgradeGatePolicy` covering this pool, or use [force upgrade](#mitigation-options).

### A node pool or cluster check tripped the circuit breaker

```text
Code: UpgradeAbortAtUpgradeGate
SubCode: CircuitBreakerTripped
Message: Upgrade aborted in pool nodepool1 due to a nodepool or cluster scope
  signal report unhealthy: Health signal indicates nodepool1 is unhealthy:
  Ready (Reason: ErrorRateHigh) - 5xx rate above 5% for 5m
```

**Cause:** Unlike the previous error, this message names a node pool or the cluster, not a node. A provider reported the node pool-scoped or cluster-scoped `HealthCheckRequest` unhealthy. A node pool-scoped signal stops only that pool; a cluster-scoped signal stops every gated pool in the operation. Once tripped, the breaker stays latched for the rest of the upgrade—reporting the signal healthy again doesn't resume it.

**Resolution:** Fix what your provider flagged, then rerun the same upgrade command with the same target version.

### The upgrade gate failed to initialize

```text
Code: InitializeUpgradeGateFailed
SubCode: InitializeHealthSignalWatcherFailed
Message: Failed to initialize upgrade gate health signal watcher. Please retry
  the operation. If the issue persists, please contact support.
```

**Cause:** AKS couldn't set up the gate for this upgrade, usually because it couldn't reach or read from the cluster's API server. The gate fails closed, so the upgrade stops.

**Resolution:** Confirm the API server is healthy, confirm the CRDs are installed (`kubectl get crd | grep -E 'upgrade.aks.io|health.aks.io'`), and confirm any admission webhook in the cluster allows `health.aks.io` and `upgrade.aks.io` resources. Retry the upgrade. If it fails repeatedly, contact Azure Support with the operation ID.

### The gate ignored a health signal

If the upgrade didn't wait for your provider, or a `False` signal didn't stop it, check the following:

- **Is the gate enabled for this pool?** Check `upgradeSettings.upgradeGateSettings` with `az aks nodepool show` and `az aks show`. The pool is gated only if the cluster or pool setting is `true` *and* a policy covers it.
- **Does a policy cover this pool?** Run `kubectl get upgradegatepolicy -o yaml`. The pool needs a `NodePool` rule naming it or a `Cluster` rule, and the policy must have existed before the upgrade started.
- **Does the signal's provider label match?** The `health.aks.io/provider` label on your `HealthSignal` must exactly match a policy's `spec.provider`. Check with `kubectl get upgradegatepolicy -o custom-columns='NAME:.metadata.name,PROVIDER:.spec.provider'` and `kubectl get healthsignal -L health.aks.io/provider`. A missing or mismatched label means the signal is ignored.
- **Does the owner reference point to the current `HealthCheckRequest`?** Each upgrade attempt creates a new request with a new UID. Compare `kubectl get healthcheckrequest <hcr-name> -o jsonpath='{.metadata.uid}'` against the `uid` in `kubectl get healthsignal <signal-name> -o jsonpath='{.metadata.ownerReferences}'`. A signal built from a stale UID is silently dropped.
- **Is the verdict in `status.conditions`?** Run `kubectl get healthsignal <signal-name> -o jsonpath='{.spec.type}{.status.conditions}'`. Status must be written through the status subresource (`kubectl patch ... --subresource=status`)—`kubectl apply` alone doesn't set it.

If all of these check out and the gate still didn't behave as expected, contact Azure Support with the operation ID, your `UpgradeGatePolicy`, and the `HealthSignal` YAML.

### Mitigation options

| Goal | Action |
| --- | --- |
| Resume after fixing the cause | Rerun the same upgrade command with the same target version. |
| Give your health provider more time | Raise `nodeTimeout` in the policy, up to five minutes. |
| Get past the gate once | Use [force upgrade](./upgrade-options.md#option-1-force-upgrade-bypass-pdb-constraints), which skips the gate. |
| Stop gating a pool or cluster | Delete or narrow the `UpgradeGatePolicy`, or disable upgrade health gates with `az aks update --disable-upgrade-gate` or `az aks nodepool update --disable-upgrade-gate`. |

## Related content

- [Upgrade options and recommendations for AKS](./upgrade-options.md)
- [Production upgrade strategies for AKS](./aks-production-upgrade-strategies.md)
- [Configure blue-green node pool upgrades](./blue-green-node-pool-upgrade.md)
- [Stop AKS cluster upgrades automatically on API breaking changes](./stop-cluster-upgrade-api-breaking-changes.md)

<!-- LINKS INTERNAL -->

[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-show]: /cli/azure/aks#az-aks-show
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
[az-aks-nodepool-update]: /cli/azure/aks/nodepool#az-aks-nodepool-update
[az-aks-nodepool-show]: /cli/azure/aks/nodepool#az-aks-nodepool-show
