---
title: Eviction Pod Autoscaler for Azure Kubernetes Service (AKS) (preview)
description: Learn how to use the Eviction Pod Autoscaler (preview) to automatically manage Pod Disruption Budgets and unblock node drain operations during AKS cluster upgrades.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.custom: azure-kubernetes-service
ms.date: 03/16/2026
author: kaarthis
ms.author: kaarthis
ai-usage: ai-assisted

---

# Use Eviction Pod Autoscaler to resolve PDB drain failures during AKS upgrades (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

AKS cluster upgrades rely on draining nodes, which means evicting pods so that nodes can be reimaged or replaced. [Pod Disruption Budgets (PDBs)](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/#pod-disruption-budgets) protect application availability during this process by limiting how many pods can be unavailable at once. However, PDBs can also block eviction entirely when they're misconfigured or when deployments don't have enough replicas to satisfy the budget. Deployments without any PDB at all have the opposite problem: nothing protects their pods from being evicted simultaneously, which risks downtime during upgrades.

The Eviction Pod Autoscaler addresses both sides of this challenge. It's an AKS extension that:

- **Creates PDBs automatically** for deployments that don't have one, so your workloads are protected during voluntary disruptions.
- **Temporarily scales up replicas** when a PDB blocks pod eviction on a cordoned node, so the disruption budget is satisfied and the drain can proceed.
- **Scales replicas back down** after evictions complete, so you don't pay for extra capacity beyond what the upgrade requires.

The result is that upgrades complete reliably without you having to force-bypass PDB protections or manually resolve quarantined nodes.

## When to use the Eviction Pod Autoscaler

Consider enabling the Eviction Pod Autoscaler when:

- **Deployments lack PDBs.** Pods are evicted without availability guarantees during upgrades, leading to potential downtime.
- **PDBs block node drain.** A PDB with `minAvailable` equal to the replica count (or `maxUnavailable: 0`) prevents any pod from being evicted, causing the upgrade to fail with an error like `Cannot evict pod as it would violate the pod's disruption budget`.
- **Replicas are insufficient for the disruption budget.** The PDB exists and is configured correctly, but the deployment doesn't have enough replicas to absorb even one eviction.
- **You experience frequent upgrade drain failures** and want automated, proactive resolution rather than manual cleanup.

### Identify PDB-related drain failures

Before you enable the Eviction Pod Autoscaler, check whether your cluster is experiencing PDB-related drain failures:

- **Azure Activity Log.** In the Azure portal, open your AKS cluster resource and select **Activity log**. Look for failed upgrade operations with status `Failed` and messages referencing pod disruption budgets or eviction errors.
- **Kubernetes events.** Run the following command to find recent eviction and drain events:

    ```bash
    kubectl get events --sort-by='.lastTimestamp' -A | grep -i "disruption\|evict\|drain"
    ```

    For a full guide on working with Kubernetes events, see [Kubernetes events](events.md).

### How it compares to other options

| Approach | Behavior | Trade-off |
|----------|----------|-----------|
| **Force upgrade** | Bypasses PDB protections entirely | Risk of simultaneous pod eviction and service disruption |
| **Undrainable node behavior** | Cordons and quarantines blocked nodes; upgrade continues on other nodes | Requires manual cleanup of quarantined nodes after upgrade |
| **Overprovisioning** | Run extra replicas permanently | Ongoing cost for capacity that's only needed during upgrades |
| **Eviction Pod Autoscaler** (preview) | Creates PDBs for unprotected deployments and temporarily scales up replicas to satisfy PDB constraints, then scales back down | Requires the extension; adds transient capacity only during drain |

## How it works

The Eviction Pod Autoscaler has two complementary behaviors: **automatic PDB creation** (proactive) and **replica scaling during drain** (reactive).

### Automatic PDB creation

When PDB auto-creation is enabled (`controllerConfig.pdb.create=true`), the Eviction Pod Autoscaler continuously watches for deployments that don't have a PDB. When it finds one in an enabled namespace, it creates a PDB with `minAvailable` set to the deployment's current replica count. This protection ensures that pods aren't evicted simultaneously during voluntary disruptions.

Auto-created PDBs are managed by the Eviction Pod Autoscaler throughout their lifecycle. For details on ownership, cleanup, and how to take manual control, see [PDB ownership and cleanup](#pdb-ownership-and-cleanup).

> [!NOTE]
> The Eviction Pod Autoscaler doesn't depend on KEDA or the Horizontal Pod Autoscaler (HPA). It directly adjusts deployment replica counts during drain operations. If a deployment is also managed by HPA, see [Limitations and considerations](#limitations-and-considerations) for potential interactions.

### Replica scaling during drain

The Eviction Pod Autoscaler monitors your cluster for situations where PDB-protected pods can't be evicted during node drain operations. Here's what happens during a typical upgrade:

1. **AKS cordons a node** as part of the upgrade process, marking it as unschedulable.
1. **The Eviction Pod Autoscaler detects the cordon** and checks whether any PDB-protected pods on that node have zero allowed disruptions.
1. **If the PDB blocks eviction**, the Eviction Pod Autoscaler temporarily scales up the deployment's replica count. The extra replicas are scheduled on other available nodes.
1. **The PDB's allowed disruptions rise above zero**, because the total number of healthy pods now exceeds the PDB's `minAvailable` threshold.
1. **Node drain proceeds normally.** The eviction API can now remove pods from the cordoned node without violating the PDB.
1. **After eviction signals stop and allowed disruptions rise above zero**, the Eviction Pod Autoscaler scales the deployment back to its original replica count. The scale-down happens automatically after a cooldown period — no manual intervention is needed.

> [!NOTE]
> The Eviction Pod Autoscaler only acts on *voluntary disruptions* such as upgrade drains and manual cordon/drain operations. It doesn't respond to node failures, pod crashes, or other involuntary disruptions.

## Prerequisites

Before you install the Eviction Pod Autoscaler, make sure you have the following:

- An AKS cluster running a [supported Kubernetes version](supported-kubernetes-versions.md).
- Azure CLI version 2.64.0 or later. Run `az --version` to check. To install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).
- The `Microsoft.KubernetesConfiguration` provider registered in your subscription.
- Your AKS cluster must use a **managed identity** (not a service principal). Cluster extensions don't work with service-principal-based clusters. For more information, see [AKS cluster extensions](cluster-extensions.md).

### Extension permissions

The Eviction Pod Autoscaler extension requires permissions to read and write Deployments, Pod Disruption Budgets, and Events in the namespaces it manages. The extension installs its own service account and RBAC roles during setup. For the full list of roles and permissions, see the [Eviction Autoscaler repository on GitHub](https://github.com/Azure/eviction-autoscaler).

### Register the configuration provider

If you haven't used Azure Kubernetes extensions before, register the required provider:

```azurecli-interactive
az feature register --namespace Microsoft.KubernetesConfiguration --name Extensions

# Verify registration status
az feature show --namespace Microsoft.KubernetesConfiguration --name Extensions

# After the feature shows "Registered", refresh the provider
az provider register -n Microsoft.KubernetesConfiguration
```

## Install the Eviction Pod Autoscaler

The Eviction Pod Autoscaler is installed as an Azure Kubernetes extension on your AKS cluster. Choose an installation option based on your needs.

### Basic installation

Install the extension with default settings. In this mode, the autoscaler watches for PDB-blocked evictions in the `kube-system` namespace but doesn't automatically create PDBs for unprotected deployments:

```azurecli-interactive
az k8s-extension create \
    --cluster-name <cluster-name> \
    --cluster-type managedClusters \
    --extension-type microsoft.evictionautoscaler \
    --name eviction-autoscaler \
    --resource-group <resource-group-name> \
    --release-train stable \
    --auto-upgrade-minor-version true
```

### Install with automatic PDB creation for specific namespaces

Enable automatic PDB creation and specify which namespaces the autoscaler should protect. This is the **recommended** configuration for most clusters:

```azurecli-interactive
az k8s-extension create \
    --cluster-name <cluster-name> \
    --cluster-type managedClusters \
    --extension-type microsoft.evictionautoscaler \
    --name eviction-autoscaler \
    --resource-group <resource-group-name> \
    --release-train stable \
    --configuration-settings controllerConfig.pdb.create=true controllerConfig.namespaces.actionedNamespaces="{kube-system,production}" \
    --auto-upgrade-minor-version true
```

### Install with cluster-wide protection

Enable automatic PDB creation across all namespaces:

```azurecli-interactive
az k8s-extension create \
    --cluster-name <cluster-name> \
    --cluster-type managedClusters \
    --extension-type microsoft.evictionautoscaler \
    --name eviction-autoscaler \
    --resource-group <resource-group-name> \
    --release-train stable \
    --configuration-settings controllerConfig.pdb.create=true controllerConfig.namespaces.enabledByDefault=true \
    --auto-upgrade-minor-version true
```

> [!TIP]
> You can also install the Eviction Pod Autoscaler by using Helm. For Helm installation instructions and the full set of Helm values, see the [Eviction Autoscaler repository on GitHub](https://github.com/Azure/eviction-autoscaler).

## Configuration options

The following settings control how the Eviction Pod Autoscaler behaves:

| Setting | Description | Default |
|---------|-------------|---------|
| `controllerConfig.pdb.create` | Automatically create PDBs for deployments that don't have one. | `false` |
| `controllerConfig.namespaces.enabledByDefault` | Enable the autoscaler in all namespaces. | `false` |
| `controllerConfig.namespaces.actionedNamespaces` | Comma-separated list of namespaces to enable when `enabledByDefault` is `false`. | `{kube-system}` |

### Common configuration patterns

| Pattern | Settings | Use case |
|---------|----------|----------|
| **Conservative** | `pdb.create=false`, `enabledByDefault=false`, `actionedNamespaces={kube-system}` | You manage PDBs manually and want autoscaling only for system workloads. |
| **Targeted auto-protection** (recommended) | `pdb.create=true`, `enabledByDefault=false`, `actionedNamespaces={production,staging}` | You want automatic PDB creation and autoscaling in specific namespaces. |
| **Cluster-wide protection** | `pdb.create=true`, `enabledByDefault=true` | You want every namespace protected automatically. |
| **Monitoring only** | `pdb.create=false`, `enabledByDefault=true` | You want autoscaling across all namespaces but manage PDBs yourself. |

## Namespace control

The Eviction Pod Autoscaler operates in one of two modes depending on the `enabledByDefault` setting.

### Opt-in mode (default)

When `enabledByDefault` is `false`, only namespaces listed in `actionedNamespaces` are enabled. You can enable additional namespaces individually by adding an annotation:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-namespace
  annotations:
    eviction-autoscaler.azure.com/enable: "true"
```

### Opt-out mode

When `enabledByDefault` is `true`, all namespaces are enabled. You can exclude specific namespaces by adding an annotation:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-excluded-namespace
  annotations:
    eviction-autoscaler.azure.com/enable: "false"
```

### Exclude specific deployments

To prevent the autoscaler from creating a PDB for a specific deployment, add the following annotation to the deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
  annotations:
    eviction-autoscaler.azure.com/pdb-create: "false"
```

> [!NOTE]
> Deployments that already have `maxUnavailable > 0` configured in their existing PDB are automatically skipped, because they already tolerate disruption.

## Automatic PDB creation

When `controllerConfig.pdb.create` is set to `true`, the Eviction Pod Autoscaler creates PDBs for deployments that meet all of the following criteria:

- The deployment doesn't already have a matching PDB.
- The deployment is in an enabled namespace.
- The deployment isn't excluded via the `eviction-autoscaler.azure.com/pdb-create: "false"` annotation.

Auto-created PDBs set `minAvailable` to match the deployment's current replica count (excluding any surge replicas added by the Eviction Pod Autoscaler). This means eviction is blocked until the Eviction Pod Autoscaler scales up the deployment, at which point the extra replicas satisfy the budget and allow drain to proceed.

### PDB ownership and cleanup

PDBs created by the Eviction Pod Autoscaler are marked with an `ownedBy: EvictionAutoScaler` annotation. These controller-owned PDBs are automatically deleted when:

- The parent deployment is deleted.
- The namespace is removed from the Eviction Pod Autoscaler's scope.
- The extension is [removed from the cluster](#remove-the-extension). PDBs with the `ownedBy: EvictionAutoScaler` annotation are cleaned up through Kubernetes garbage collection.

PDBs that you create manually are never modified or deleted by the Eviction Pod Autoscaler.

To take manual control of a PDB that was created by the Eviction Pod Autoscaler, remove the ownership annotation. After you remove this annotation, the Eviction Pod Autoscaler no longer manages that PDB, and you're responsible for updating or deleting it:

```bash
kubectl annotate pdb <pdb-name> -n <namespace> ownedBy-
```

## Verify the installation

After installing the extension, verify that the Eviction Pod Autoscaler is working correctly.

1. **Check that PDBs were created** for deployments in enabled namespaces. Filter for PDBs created by the Eviction Pod Autoscaler:

    ```bash
    kubectl get pdb -A -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,MIN-AVAILABLE:.spec.minAvailable,OWNER:.metadata.annotations.ownedBy | grep EvictionAutoScaler
    ```

2. **Check the eviction autoscaler custom resources**:

    ```bash
    kubectl get evictionautoscalers --all-namespaces
    ```

3. **Test with a node cordon** (optional). In a test or staging environment, cordon a node and verify that the Eviction Pod Autoscaler scales up the deployment and the PDB's allowed disruptions rise above zero:

    ```bash
    # Cordon a node
    NODE=$(kubectl get pods -n <namespace> -l app=<app-label> -o=jsonpath='{.items[0].spec.nodeName}')
    kubectl cordon $NODE

    # Watch for Eviction Pod Autoscaler events
    kubectl get events -n <namespace> --sort-by='.lastTimestamp'

    # Check that the deployment scaled up
    kubectl get pods -n <namespace>

    # Verify PDB allowed disruptions
    kubectl get poddisruptionbudget <pdb-name> -n <namespace> -o yaml

    # After verification, uncordon the node
    kubectl uncordon $NODE
    ```

## Update or remove the extension

### Update configuration

To change configuration settings, delete and recreate the extension with the new settings:

```azurecli-interactive
# Delete the existing extension
az k8s-extension delete \
    --resource-group <resource-group-name> \
    --cluster-name <cluster-name> \
    --cluster-type managedClusters \
    --name eviction-autoscaler \
    --yes

# Recreate with new configuration
az k8s-extension create \
    --cluster-name <cluster-name> \
    --cluster-type managedClusters \
    --extension-type microsoft.evictionautoscaler \
    --name eviction-autoscaler \
    --resource-group <resource-group-name> \
    --release-train stable \
    --configuration-settings controllerConfig.pdb.create=true controllerConfig.namespaces.enabledByDefault=true \
    --auto-upgrade-minor-version true
```

### Remove the extension

To uninstall the Eviction Pod Autoscaler:

```azurecli-interactive
az k8s-extension delete \
    --resource-group <resource-group-name> \
    --cluster-name <cluster-name> \
    --cluster-type managedClusters \
    --name eviction-autoscaler \
    --yes
```

> [!NOTE]
> When you remove the extension, auto-created PDBs (marked with the `ownedBy: EvictionAutoScaler` annotation) are cleaned up automatically. For more details, see [PDB ownership and cleanup](#pdb-ownership-and-cleanup).

## Limitations and considerations

- The Eviction Pod Autoscaler is currently in **preview** and isn't recommended for production workloads.
- Configuration updates require deleting and recreating the extension.
- The Eviction Pod Autoscaler works with **Deployments**. Support for StatefulSets is experimental.
- The Eviction Pod Autoscaler doesn't override or modify existing PDBs. It works alongside them by adjusting replica counts.
- The Eviction Pod Autoscaler doesn't depend on KEDA or the Horizontal Pod Autoscaler (HPA). If a deployment is also managed by HPA, HPA might scale down replicas that the Eviction Pod Autoscaler added during drain. For best results, consider configuring HPA `minReplicas` to account for disruption scenarios.
- The temporary replica scale-up requires available capacity in the cluster. If no nodes have room for the extra pods, consider enabling the [cluster autoscaler](cluster-autoscaler.md) or [node auto-provisioning (NAP)](node-auto-provisioning.md) so that new nodes can be provisioned.

## Troubleshooting

| Symptom | Possible cause | Resolution |
|---------|---------------|------------|
| PDBs aren't created for deployments | `controllerConfig.pdb.create` is `false` (default), or the namespace isn't enabled | Set `pdb.create=true` and verify the namespace is in `actionedNamespaces` or has the opt-in annotation. |
| Upgrade still fails with PDB eviction error | Cluster doesn't have capacity for the extra surge replicas | Enable the [cluster autoscaler](cluster-autoscaler.md) or [node auto-provisioning (NAP)](node-auto-provisioning.md), or add nodes so the scaled-up replicas have somewhere to schedule. |
| Autoscaler doesn't scale up during drain | The deployment's PDB already allows disruptions (`allowedDisruptions > 0`) | The Eviction Pod Autoscaler only acts when the PDB blocks eviction. If `allowedDisruptions` is already above zero, no scale-up is needed. |
| Want to confirm the autoscaler took action | Need to check status | Run `kubectl get evictionautoscalers -n <namespace> -o yaml` and inspect the status fields for scaling events. |
| Want to see Eviction Pod Autoscaler events | Need to inspect scaling or PDB activity | Run `kubectl get events -n <namespace> --sort-by='.lastTimestamp'` and look for events related to the Eviction Pod Autoscaler. |

## Related content

- [Upgrade options and recommendations](upgrade-options.md) — includes Scenario 2: Node drain failures and PDBs, with multiple resolution options.
- [How AKS cluster upgrades work](upgrade-conceptual.md) — explains the step-by-step rolling upgrade process and what happens when a PDB blocks node drain.
- [Pod Disruption Budgets best practices](best-practices-app-cluster-reliability.md#pod-disruption-budgets-pdbs) — guidance on configuring PDBs for high availability.
- [Kubernetes documentation: Pod Disruption Budgets](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/#pod-disruption-budgets) — upstream PDB reference.
- [Eviction Autoscaler on GitHub](https://github.com/Azure/eviction-autoscaler) — source code, Helm charts, and detailed technical reference.
