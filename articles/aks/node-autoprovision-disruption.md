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

## Example disruption configuration

Here's a typical disruption configuration for a NodePool that balances cost optimization with stability:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  disruption:
    # Consolidate underutilized nodes to optimize costs
    consolidationPolicy: WhenEmptyOrUnderutilized
    
    # Wait 30 seconds before consolidating
    consolidateAfter: 30s
    
    # Replace nodes every 7 days to get fresh instances
    expireAfter: 168h
    
    # Rate limit disruptions
    budgets:
    - nodes: "10%"        # Allow 10% of nodes to be disrupted at once
    - nodes: "0"          # Block all disruptions during business hours
      schedule: "0 9 * * 1-5"
      duration: 8h
```

## Node disruption overview

When the workloads on your nodes scale down, node autoprovisioning uses disruption rules on the node pool specification to decide when and how to remove those nodes and potentially reschedule your workloads to be more efficient. Node autoprovisioning primarily uses *consolidation* to delete or replace nodes for optimal pod placement.

Node autoprovisioning can automatically control when it should optimize your nodes based on your specifications, or you can manually remove nodes using `kubectl delete node`.

## Control flow

Karpenter sets a Kubernetes [finalizer](https://kubernetes.io/docs/concepts/overview/working-with-objects/finalizers/) on each node and node claim it provisions. The finalizer blocks deletion of the node object while the Termination Controller taints and drains the node, before removing the underlying NodeClaim.

### Disruption methods

NAP automatically discovers nodes eligible for disruption and spins up replacements when needed. Disruption can be triggered through:

1. **Automated methods**: Expiration, Drift, and Consolidation
2. **Manual methods**: Node deletion via kubectl
3. **External systems**: Delete requests to the node object

## Automated disruption methods

### Expiration

Nodes are marked as expired and disrupted after reaching the age specified in the NodePool's `spec.disruption.expireAfter` value.

```yaml
spec:
  disruption:
    expireAfter: 24h  # Expire nodes after 24 hours
```

### Consolidation

NAP works to actively reduce cluster cost by identifying when:
- Nodes can be removed because they're empty
- Nodes can be removed as their workloads run on other nodes
- Nodes can be replaced with lower priced variants

Consolidation has three mechanisms performed in order:
1. **Empty Node Consolidation** - Delete entirely empty nodes in parallel
2. **Multi Node Consolidation** - Delete multiple nodes, possibly launching a single replacement
3. **Single Node Consolidation** - Delete any single node, possibly launching a replacement

### Drift

Drift handles changes to the NodePool/AKSNodeClass. For Drift, values in the NodePool/AKSNodeClass are reflected in the NodeClaimTemplateSpec/AKSNodeClassSpec in the same way that they're set. A NodeClaim is detected as drifted if the values in its owning NodePool/AKSNodeClass don't match the values in the NodeClaim. Similar to the upstream `deployment.spec.template` relationship to pods, Karpenter annotates the owning NodePool and AKSNodeClass with a hash of the NodeClaimTemplateSpec to check for drift. Some special cases are discovered either from Karpenter or through the CloudProvider interface, triggered by NodeClaim/Instance/NodePool/AKSNodeClass changes.

#### Special Cases on Drift

In special cases, drift can correspond to multiple values and must be handled differently. Drift on resolved fields can create cases where drift occurs without changes to Custom Resource Definitions (CRDs), or where CRD changes don't result in drift. For example, if a NodeClaim has `node.kubernetes.io/instance-type: Standard_D2s_v3`, and requirements change from `node.kubernetes.io/instance-type In [Standard_D2s_v3]` to `node.kubernetes.io/instance-type In [Standard_D2s_v3, Standard_D4s_v3]`, the NodeClaim isn't drifted because its value is still compatible with the new requirements. Conversely, if a NodeClaim is using a NodeClaim imageFamily, but the `spec.imageFamily` field is changed, Karpenter detects the NodeClaim as drifted and rotates the node to meet that specification

##### NodePool
| Fields         |
|----------------|
| spec.template.spec.requirements   |

##### AKSNodeClass

Some example cases:

| Fields                        |
|-------------------------------|
| spec.vnetSubnetID             |
| spec.imageFamily              |

###### VNet Subnet ID Drift

**⚠️ Important**: The `spec.vnetSubnetID` field can trigger drift detection, but modifying this field from one valid subnet to another valid subnet is **NOT a supported operation**. This field is mutable solely to provide an escape hatch for correcting invalid or malformed subnet identifiers during initial configuration.

Unlike traditional AKS NodePools created through ARM templates, Karpenter applies custom resource definitions (CRDs) that provision nodes instantly without the extended validation that ARM provides. **Customers are responsible for understanding their cluster's Classless Inter-Domain Routing (CIDR) ranges and ensuring no conflicts occur when configuring `vnetSubnetID`.**

**Validation Differences**: 
- **ARM Template NodePools**: Include comprehensive Classless Inter-Domain Routing (CIDR) conflict detection and network validation
- **Karpenter CRDs**: Apply changes instantly without automatic validation - requires customer due diligence

**Customer Responsibility**: Before modifying `vnetSubnetID`, verify:
- Custom subnets don't conflict with cluster Pod CIDR, Service CIDR, or Docker Bridge CIDR
- Sufficient IP address capacity for scaling requirements  
- Proper network connectivity and routing configuration

**Supported Use Case**: Fixing invalid subnet identifiers (IDs) only
- Correcting malformed subnet references that prevent node provisioning
- Updating subnet identifiers that point to nonexistent or inaccessible subnets

**Unsupported Use Case**: Subnet migration between valid subnets
- Moving nodes between subnets for network reorganization
- Changing subnet configurations for capacity or performance reasons

**Support Policy**: Microsoft doesn't provide support for issues arising from subnet to subnet migrations via `vnetSubnetID` modifications.

#### Behavioral Fields

Behavioral Fields are treated as over-arching settings on the NodePool to dictate how Karpenter behaves. These fields don't correspond to settings on the NodeClaim or instance. Users set these fields to control Karpenter's Provisioning and disruption logic. Since these fields don't map to a desired state of NodeClaims, __behavioral fields are not considered for Drift__.

##### NodePool

| Fields              |
|---------------------|
| spec.weight         |
| spec.limits         |
| spec.disruption.*   |

Read the [Drift Design](https://github.com/aws/karpenter-core/blob/main/designs/drift.md) for more.

To enable the drift feature flag, refer to the Feature Gates section in the settings documentation.

Karpenter adds the `Drifted` status condition on NodeClaims if the NodeClaim is drifted from its owning NodePool. Karpenter also removes the `Drifted` status condition if either:
1. The `Drift` feature gate isn't enabled but the NodeClaim is drifted, Karpenter removes the status condition.
2. The NodeClaim isn't drifted, but has the status condition, Karpenter removes it.

## Disruption configuration

Configure disruption through the NodePool's `spec.disruption` section:

```yaml
spec:
  disruption:
    # Consolidation policy
    consolidationPolicy: WhenEmptyOrUnderutilized | WhenEmpty
    
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

### WhenEmptyOrUnderutilized

NAP considers all nodes for consolidation and attempts to remove or replace nodes when they're underutilized or empty

```yaml
spec:
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
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

## Termination Grace Period
Configure how long Karpenter waits for pods to terminate gracefully.
This setting takes precedence over a pod's terminationGracePeriodSeconds and bypasses PodDisruptionBudgets and the karpenter.sh/do-not-disrupt annotation

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

You can rate limit Karpenter's disruption through the NodePool's `spec.disruption.budgets`. If undefined, Karpenter defaults to one budget with `nodes: 10%`. Budgets consider nodes that are being deleted for any reason. They only block Karpenter from voluntary disruptions through expiration, drift, emptiness, and consolidation.

### Node budgets

When calculating if a budget blocks nodes from disruption, Karpenter counts the total nodes owned by a NodePool. It then subtracts nodes that are being deleted and nodes that are NotReady.

If the budget is configured with a percentage value, such as `20%`, Karpenter calculates the number of allowed disruptions as `allowed_disruptions = roundup(total * percentage) - total_deleting - total_notready`.

For multiple budgets in a NodePool, Karpenter takes the minimum value (most restrictive) of each of the budgets.

### Budget examples

The following NodePool with three budgets defines these requirements:

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
      schedule: "@daily"
      duration: 10m
```

- The first budget allows 20% of nodes owned by that NodePool to be disrupted
- The second budget acts as a ceiling, only allowing five disruptions when there are more than 25 nodes
- The last budget blocks disruptions during the first 10 minutes of each day

### Schedule and duration

**Schedule** uses cron job syntax with special macros like `@yearly`, `@monthly`, `@weekly`, `@daily`, `@hourly`.
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

The NodePool owns NodeClaims through an owner reference. NAP gracefully terminates nodes through cascading deletion when the owning NodePool is deleted.

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

This annotation prevents voluntary disruption for:
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

## Next steps

- [Configure node pools](node-autoprovision-node-pools.md)
- [Learn about networking configuration](node-autoprovision-networking.md)
- [Learn about Pod Disruption Budgets](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/)
