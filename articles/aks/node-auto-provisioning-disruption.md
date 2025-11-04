---
title: Configure Disruption Policies for Node Auto-Provisioning (NAP) Nodes in Azure Kubernetes Service (AKS)
description: Learn how to configure node disruption policies for node auto-provisioning (NAP) nodes in Azure Kubernetes Service (AKS) to optimize resource utilization.
ms.topic: overview
ms.custom: devx-track-azurecli
ms.date: 07/25/2025
ms.author: schaffererin
author: schaffererin
ms.service: azure-kubernetes-service
# Customer intent: As a cluster operator or developer, I want to understand and configure disruption policies for my AKS clusters using node auto-provisioning, so that I can effectively manage and maintain the health and security of my cluster nodes.
---

# Configure node disruption policies for node auto-provisioning (NAP) nodes in Azure Kubernetes Service (AKS)

This article explains how to configure node disruption policies for Azure Kubernetes Service (AKS) node auto-provisioning (NAP) nodes and details how disruption works to optimize resource utilization and cost efficiency.

NAP optimizes your cluster by:

- Removing or replacing underutilized nodes.
- Consolidating workloads to reduce costs.
- Respecting disruption budgets and maintenance windows.
- Providing manual control when needed.

## Before you begin

- Read the [Overview of node auto-provisioning (NAP) in AKS](./node-auto-provisioning.md) article, which details [how NAP works](./node-auto-provisioning.md#how-does-node-auto-provisioning-work).
- Read the [Overview of networking configurations for node auto-provisioning (NAP) in Azure Kubernetes Service (AKS)](./node-auto-provisioning-networking.md).

## How does node disruption work for NAP nodes?

Karpenter sets a Kubernetes [finalizer](https://kubernetes.io/docs/concepts/overview/working-with-objects/finalizers/) on each node and node claim it provisions. The finalizer blocks the deletion of the node object, while the Termination Controller taints and drains the node before removing the underlying node claim.

When the workloads on your nodes scale down, NAP uses disruption rules on the node pool specification to decide when and how to remove those nodes and potentially reschedule your workloads for efficiency.

## Node disruption methods

NAP automatically discovers nodes eligible for disruption and spins up replacements when needed. You can trigger disruption through automated methods like _Expiration_, _Consolidation_, and _Drift_, manual methods, or external systems.

## Expiration

Expiration allows you to set a maximum age for your NAP nodes. Nodes are marked as expired and disrupted after reaching the age you specify for the node pool's `spec.disruption.expireAfter` value.

### Example expiration configuration

The following example shows how to set the expiration time for NAP nodes to 24 hours:

```yaml
spec:
  disruption:
    expireAfter: 24h  # Expire nodes after 24 hours
```

## Consolidation

NAP works to actively reduce cluster cost by identifying when nodes can be removed because they're empty or underutilized, or when nodes can be replaced with lower priced variants. This process is called _Consolidation_. NAP primarily uses Consolidation to delete or replace nodes for optimal pod placement.

NAP performs the following types of consolidation in order to optimize resource utilization:

- **Empty node consolidation**: Deletes any empty nodes in parallel.
- **Multi-node consolidation**: Deletes multiple nodes, possibly launching a single replacement.
- **Single-node consolidation**: Deletes any single node, possibly launching a replacement.

You can trigger consolidation through the `spec.disruption.consolidationPolicy` field in the node pool specification using the `WhenEmpty`, or `WhenEmptyOrUnderUtilized` settings. You can also set the `consolidateAfter` field, which is a time-based condition that determines how long NAP waits after discovering a consolidation opportunity before disrupting the node.

### Example consolidation configuration

The following example shows how to configure NAP to consolidate nodes when they're empty, and to wait 30 seconds after discovering a consolidation opportunity before disrupting the node:

```yaml
  disruption:
    # Describes which types of nodes NAP should consider for consolidation
    # `WhenEmptyOrUnderUtilized`: NAP considers all nodes for consolidation and attempts to remove or replace nodes when it discovers that the node is empty or underutilized and could be changed to reduce cost
    # `WhenEmpty`: NAP only considers nodes for consolidation that don't contain any workload pods
    
    consolidationPolicy: WhenEmpty

    # The amount of time NAP should wait after discovering a consolidation decision
    # Currently, you can only set this value when the consolidation policy is `WhenEmpty`
    # You can choose to disable consolidation entirely by setting the string value `Never`
    consolidateAfter: 30s
```

## Drift

Drift handles changes to the `NodePool`/`AKSNodeClass` resources. Values in the `NodeClaimTemplateSpec`/`AKSNodeClassSpec` are reflected in the same way that they're set. A `NodeClaim` is detected as _drifted_ if the values in the associated `NodePool`/`AKSNodeClass` don't match the values in the `NodeClaim`. Similar to the upstream `deployment.spec.template` relationship to pods, Karpenter annotates the associated `NodePool`/`AKSNodeClass` with a hash of the `NodeClaimTemplateSpec` to check for drift. Karpenter removes the `Drifted` status condition in the following scenarios:

- The `Drift` feature gate isn't enabled but the `NodeClaim` is drifted.
- The `NodeClaim` isn't drifted, but has the status condition.

Karpenter or the cloud provider interface might discover [special cases](#special-cases-on-drift) triggered by `NodeClaim`/`Instance`/`NodePool`/`AKSNodeClass` changes.

### Special cases on drift

In special cases, drift can correspond to multiple values and must be handled differently. Drift on resolved fields can create cases where drift occurs without changes to Custom Resource Definitions (CRDs), or where CRD changes don't result in drift.

For example, if a `NodeClaim` has `node.kubernetes.io/instance-type: Standard_D2s_v3`, and requirements change from `node.kubernetes.io/instance-type In [Standard_D2s_v3]` to `node.kubernetes.io/instance-type In [Standard_D2s_v3, Standard_D4s_v3]`, the `NodeClaim` isn't drifted because its value is still compatible with the new requirements. Conversely, if a `NodeClaim` uses a `NodeClaim` `imageFamily`, but the `spec.imageFamily` field changes, Karpenter detects the `NodeClaim` as _drifted_ and rotates the node to meet that specification.

> [!IMPORTANT]
> Karpenter monitors subnet configuration changes and detects drift when the `vnetSubnetID` in an `AKSNodeClass` is modified. Understanding this behavior is critical when managing custom networking configurations. For more information, see [Subnet drift behavior](./node-auto-provisioning-networking.md#subnet-drift-behavior).

For more information, see [Drift Design](https://github.com/aws/karpenter-core/blob/main/designs/drift.md).

## Termination grace period

You can set a termination grace period for NAP nodes using the `spec.template.spec.terminationGracePeriod` field in the node pool specification. This setting allows you to configure how long Karpenter waits for pods to terminate gracefully. This setting takes precedence over a pod's `terminationGracePeriodSeconds` and bypasses `PodDisruptionBudgets` and the `karpenter.sh/do-not-disrupt` annotation.

### Example termination grace period configuration

The following example shows how to set a termination grace period of 30 seconds for NAP nodes:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      terminationGracePeriod: 30s
```

## Disruption budgets

You can rate limit Karpenter's disruption by modifying the `spec.disruption.budgets` field in the node pool specification. If you leave this setting undefined, Karpenter defaults to one budget with `nodes: 10%`. Budgets consider nodes that are being deleted for any reason, and they only block Karpenter from voluntary disruptions through expiration, drift, emptiness, and consolidation.

When calculating if a budget blocks nodes from disruption, Karpenter counts the total nodes owned by a node pool and then subtracts nodes that are being deleted and nodes that are `NotReady`. If the budget is configured with a percentage value, such as `20%`, Karpenter calculates the number of allowed disruptions as `allowed_disruptions = roundup(total * percentage) - total_deleting - total_notready`. For multiple budgets in a node pool, Karpenter takes the minimum (most restrictive) value of each of the budgets.

### Schedule and duration fields

When using budgets, you can optionally set the `schedule` and `duration` fields to create time-based budgets. These fields allow you to define maintenance windows or specific timeframes when disruption limits are stricter.

- **Schedule** uses cron job syntax with special macros like `@yearly`, `@monthly`, `@weekly`, `@daily`, `@hourly`.
- **Duration** allows compound durations like `10h5m`, `30m`, or `160h`. Duration and Schedule must be defined together.

#### Schedule and duration examples

##### Maintenance window budget

Prevent disruptions during business hours:

```yaml
budgets:
- nodes: "0"
  schedule: "0 9 * * 1-5"  # 9 AM Monday-Friday
  duration: 8h             # For 8 hours
```

##### Weekend-only disruptions

Only allow disruptions on weekends:

```yaml
budgets:
- nodes: "50%"
  schedule: "0 0 * * 6"    # Saturday midnight
  duration: 48h            # All weekend
- nodes: "0"               # Block all other times
```

##### Gradual rollout budget

Allow increasing disruption rates:

```yaml
budgets:
- nodes: "1"
  schedule: "0 2 * * *"    # 2 AM daily
  duration: 2h
- nodes: "3"
  schedule: "0 4 * * *"    # 4 AM daily
  duration: 4h
```

### Budget configuration examples

The following `NodePool` specification has three budgets configured:

- The first budget allows 20% of nodes owned by the node pool to be disrupted at once.
- The second budget acts as a ceiling, only allowing five disruptions when there are more than 25 nodes.
- The last budget blocks disruptions during the first 10 minutes of each day.

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    expireAfter: 720h # 30 * 24h = 720h
    budgets:
    - nodes: "20%"      # Allow 20% of nodes to be disrupted
    - nodes: "5"        # Cap at maximum 5 nodes
    - nodes: "0"        # Block all disruptions during maintenance window
      schedule: "@daily" # Scheduled daily
      duration: 10m # Duration of 10 minutes
```

## Manual node disruption

You can manually disrupt NAP nodes using `kubectl` or by deleting `NodePool` resources.

### Remove nodes with kubectl

You can manually remove nodes using the `kubectl delete node` command. You can delete specific nodes, all NAP-managed nodes, or nodes from a specific node pool by using labels, for example:

```bash
# Delete a specific node
kubectl delete node $NODE_NAME

# Delete all NAP-managed nodes
kubectl delete nodes -l karpenter.sh/nodepool

# Delete nodes from a specific nodepool
kubectl delete nodes -l karpenter.sh/nodepool=$NODEPOOL_NAME
```

### Delete `NodePool` resources

The `NodePool` owns `NodeClaims` through an owner reference. NAP gracefully terminates nodes through cascading deletion when you delete the associated `NodePool`.

## Control disruption using annotations

You can block or disable disruption for specific pods, nodes, or entire node pools using annotations.

### Pod controls

Block NAP from disrupting certain pods by setting the `karpenter.sh/do-not-disrupt: "true"` annotation:

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    metadata:
      annotations:
        karpenter.sh/do-not-disrupt: "true"
```

This annotation prevents voluntary disruption for Expiration, Consolidation, and Drift. However, it doesn't prevent disruption from external systems or manual disruption through `kubectl` or `NodePool` deletion.

### Node controls

Block NAP from disrupting specific nodes:

```yaml
apiVersion: v1
kind: Node
metadata:
  annotations:
    karpenter.sh/do-not-disrupt: "true"
```

### Node pool controls

Disable disruption for all nodes in a `NodePool`:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      annotations:
        karpenter.sh/do-not-disrupt: "true"
```

## Next steps

For more information on node auto-provisioning in AKS, see the following articles:

- [Configure networking for node auto-provisioning on AKS](./node-auto-provisioning-networking.md)
- [Configure node pools for node auto-provisioning on AKS](./node-auto-provisioning-node-pools.md)
- [Create a node auto-provisioning cluster in a custom virtual network in AKS](./node-auto-provisioning-custom-vnet.md)
