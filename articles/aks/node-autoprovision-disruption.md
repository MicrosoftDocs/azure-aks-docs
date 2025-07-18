---
title: Node autoprovisioning disruption policies
description: Learn how to configure node disruption policies for Azure Kubernetes Service (AKS) node autoprovisioning to optimize resource utilization.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 06/13/2024
ms.author: bsoghigian
author: bsoghigian
---

# Node autoprovisioning disruption policies

This article explains how to configure node disruption policies for Azure Kubernetes Service (AKS) node autoprovisioning (NAP) to optimize resource utilization and cost efficiency.

## Node disruption overview

When the workloads on your nodes scale down, node autoprovisioning uses disruption rules on the node pool specification to decide when and how to remove those nodes and potentially reschedule your workloads to be more efficient. This is primarily done through *consolidation*, which deletes or replaces nodes to bin-pack your pods in an optimal configuration.

Node autoprovisioning can automatically control when it should optimize your nodes based on your specifications, or you can manually remove nodes using `kubectl delete node`.

## Control flow

Karpenter sets a Kubernetes [finalizer](https://kubernetes.io/docs/concepts/overview/working-with-objects/finalizers/) on each node and node claim it provisions. The finalizer blocks deletion of the node object while the Termination Controller taints and drains the node, before removing the underlying NodeClaim.

### Disruption methods

NAP automatically discovers disruptable nodes and spins up replacements when needed. Disruption can be triggered through:

1. **Automated methods**: Expiration, Drift, and Consolidation
2. **Manual methods**: Node deletion via kubectl
3. **External systems**: Delete requests to the node object

## Automated disruption methods

### Expiration

Nodes are marked as expired and disrupted after they have lived a set number of seconds, based on the NodePool's `spec.disruption.expireAfter` value.

```yaml
spec:
  disruption:
    expireAfter: 24h  # Expire nodes after 24 hours
```

### Consolidation

NAP works to actively reduce cluster cost by identifying when:
- Nodes can be removed because they are empty
- Nodes can be removed as their workloads will run on other nodes
- Nodes can be replaced with lower priced variants

Consolidation has three mechanisms performed in order:
1. **Empty Node Consolidation** - Delete entirely empty nodes in parallel
2. **Multi Node Consolidation** - Delete multiple nodes, possibly launching a single replacement
3. **Single Node Consolidation** - Delete any single node, possibly launching a replacement

### Drift

NAP marks nodes as drifted and disrupts nodes that have drifted from their desired specification when NodePool or AKSNodeClass configurations change.

## Disruption configuration

Configure disruption through the NodePool's `spec.disruption` section:

```yaml
spec:
  disruption:
    # Consolidation policy
    consolidationPolicy: WhenUnderutilized | WhenEmpty
    
    # Time to wait after discovering consolidation opportunity
    consolidateAfter: 30s
    
    # Node expiration time
    expireAfter: Never
    
    # Disruption budgets for rate limiting
    budgets:
    - nodes: "20%"
    - nodes: "5"
      schedule: "@daily"
      duration: 10m
```

## Consolidation policies

### WhenUnderutilized

NAP considers all nodes for consolidation and attempts to remove or replace nodes when they are underutilized:

```yaml
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: Never
```

### WhenEmpty

NAP only considers nodes for consolidation that contain no workload pods:

```yaml
spec:
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 30s
```

## Disruption budgets

You can rate limit Karpenter's disruption through the NodePool's `spec.disruption.budgets`. If undefined, Karpenter will default to one budget with `nodes: 10%`. Budgets consider nodes that are actively being deleted for any reason, and will only block Karpenter from disrupting nodes voluntarily through expiration, drift, emptiness, and consolidation.

### Node budgets

When calculating if a budget will block nodes from disruption, Karpenter lists the total number of nodes owned by a NodePool, subtracting out the nodes owned by that NodePool that are currently being deleted and nodes that are NotReady.

If the budget is configured with a percentage value, such as `20%`, Karpenter will calculate the number of allowed disruptions as `allowed_disruptions = roundup(total * percentage) - total_deleting - total_notready`.

For multiple budgets in a NodePool, Karpenter will take the minimum value (most restrictive) of each of the budgets.

### Budget examples

The following NodePool with three budgets defines these requirements:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h # 30 * 24h = 720h
    budgets:
    - nodes: "20%"      # Allow 20% of nodes to be disrupted
    - nodes: "5"        # Cap at maximum 5 nodes
    - nodes: "0"        # Block all disruptions during maintenance window
      schedule: "@daily"
      duration: 10m
```

- The first budget allows 20% of nodes owned by that NodePool to be disrupted
- The second budget acts as a ceiling, only allowing 5 disruptions when there are more than 25 nodes
- The last budget blocks disruptions during the first 10 minutes of each day

### Schedule and duration

**Schedule** uses cronjob syntax with special macros like `@yearly`, `@monthly`, `@weekly`, `@daily`, `@hourly`:

```bash
# ┌───────────── minute (0 - 59)
# │ ┌───────────── hour (0 - 23)
# │ │ ┌───────────── day of the month (1 - 31)
# │ │ │ ┌───────────── month (1 - 12)
# │ │ │ │ ┌───────────── day of the week (0 - 6)
# │ │ │ │ │
# * * * * *
```

**Duration** allows compound durations like `10h5m`, `30m`, or `160h`. Duration and Schedule must be defined together.

### Budget configuration examples

#### Maintenance window budget

Prevent disruptions during business hours:

```yaml
budgets:
- nodes: "0"
  schedule: "0 9 * * 1-5"  # 9 AM Monday-Friday
  duration: 8h             # For 8 hours
```

#### Weekend-only disruptions

Only allow disruptions on weekends:

```yaml
budgets:
- nodes: "50%"
  schedule: "0 0 * * 6"    # Saturday midnight
  duration: 48h            # All weekend
- nodes: "0"               # Block all other times
```

#### Gradual rollout budget

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

## Manual node disruption

### Node deletion

You can manually remove nodes using kubectl:

```bash
# Delete a specific node
kubectl delete node $NODE_NAME

# Delete all NAP-managed nodes
kubectl delete nodes -l karpenter.sh/nodepool

# Delete nodes from a specific nodepool
kubectl delete nodes -l karpenter.sh/nodepool=$NODEPOOL_NAME
```

### NodePool deletion

NodeClaims are owned by the NodePool through an owner reference. NAP will gracefully terminate nodes through cascading deletion when the owning NodePool is deleted.

## Disruption controls

### Pod-level controls

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

This prevents voluntary disruption for:
- Consolidation
- Drift
- Expiration

### Node-level controls

Block NAP from disrupting specific nodes:

```yaml
apiVersion: v1
kind: Node
metadata:
  annotations:
    karpenter.sh/do-not-disrupt: "true"
```

### NodePool-level controls

Disable disruption for all nodes in a NodePool:

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

## Example disruption configurations

### Conservative consolidation with budget

Only remove empty nodes with rate limiting:

```yaml
spec:
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 2m
    expireAfter: Never
    budgets:
    - nodes: "10%"
```

### Aggressive cost optimization with maintenance window

Consolidate underutilized nodes but protect business hours:

```yaml
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: Never
    budgets:
    - nodes: "0"
      schedule: "0 9 * * 1-5"  # Block 9 AM - 5 PM weekdays
      duration: 8h
    - nodes: "25%"             # Allow 25% disruption otherwise
```

### Node rotation with controlled rollout

Daily node rotation with gradual budget increase:

```yaml
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 24h
    budgets:
    - nodes: "2"
      schedule: "0 2 * * *"    # Start with 2 nodes at 2 AM
      duration: 1h
    - nodes: "5"
      schedule: "0 3 * * *"    # Increase to 5 nodes at 3 AM
      duration: 3h
    - nodes: "10%"             # Default to 10% otherwise
```

## Best practices

1. **Start conservative**: Begin with `WhenEmpty` policy and restrictive budgets
2. **Set appropriate buffers**: Use `consolidateAfter` to prevent rapid node cycling
3. **Use maintenance windows**: Configure budgets to protect critical business hours
4. **Monitor impact**: Track the impact of consolidation on your workloads
5. **Test disruption scenarios**: Validate that your workloads handle node disruption gracefully
6. **Implement PDBs**: Use Pod Disruption Budgets alongside NAP budgets for comprehensive protection

## Troubleshooting

### Nodes not being consolidated

- Check if the consolidation policy allows the current node state
- Verify that `consolidateAfter` hasn't been set to `Never`
- Ensure disruption budgets aren't blocking consolidation
- Check for active maintenance windows in budget schedules

### Workloads experiencing disruption

- Implement proper readiness and liveness probes
- Use Pod Disruption Budgets (PDBs)
- Consider increasing `consolidateAfter` timing
- Use the `karpenter.sh/do-not-disrupt` annotation for sensitive workloads
- Review and adjust disruption budgets

### Budget conflicts

- Review overlapping budget schedules
- Ensure percentage and absolute values align with cluster size
- Check for overly restrictive budget combinations

## Next steps

- [Monitor node autoprovisioning events](node-autoprovision-monitoring.md)
- [Configure node pools](node-autoprovision-node-pools.md)
- [Learn about Pod Disruption Budgets](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/)