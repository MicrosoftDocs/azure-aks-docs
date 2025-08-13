---
title: Node Autoprovisioning Node Pools Configuration
description: Learn how to configure node pools for Azure Kubernetes Service (AKS) node autoprovisioning, including SKU selectors, limits, and weights.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 07/25/2025
ms.author: bsoghigian
author: bsoghigian
---

# Node auto provisioning node pools configuration

This article explains how to configure node pools for Azure Kubernetes Service (AKS) node auto provisioning (NAP), including SKU selectors, resource limits, and priority weights.

## Node pool overview

NodePools set constraints on the nodes that Node Auto Provisioning creates and the pods that run on those nodes. When you first install node autoprovisioning, a default NodePool is created. You can modify this NodePool or add more NodePools.

Key behaviors of NodePools:
- Node auto provisioning requires at least one NodePool to function
- Node auto provisioning evaluates each configured NodePool
- Node auto provisioning skips NodePools with taints not tolerated by a pod
- Node Auto Provisioning applies startup taints to provisioned nodes but doesn't require pod toleration
- Node Auto Provisioning works best with mutually exclusive NodePools. When multiple NodePools match, the one with highest weight is used

Node autoprovisioning uses virtual machine (VM) Stock Keeping Unit (SKU) requirements to select the best virtual machine for pending workloads. Configure SKU families, VM types, spot or on-demand instances, architectures, and resource limits.

## Default node pool configuration

### Understand default NodePools

AKS creates a default node pool configuration that you can customize:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    expireAfter: Never
  template:
    spec:
      nodeClassRef:
        name: default

      # Requirements that constrain the parameters of provisioned nodes.
      # These requirements are combined with pod.spec.affinity.nodeAffinity rules.
      # Operators { In, NotIn, Exists, DoesNotExist, Gt, and Lt } are supported.
      # https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#operators
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values:
        - amd64
      - key: kubernetes.io/os
        operator: In
        values:
        - linux
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - on-demand
      - key: karpenter.azure.com/sku-family
        operator: In
        values:
        - D
```

A `system-surge` node pool is also created to autoscale system pool nodes.

### Control default NodePool creation

The `--node-provisioning-default-pools` flag controls the default Node Auto Provisioning NodePools that are created:

- **`Auto`** (default): Creates two standard NodePools for immediate use
- **`None`**: No default NodePools are created - you must define your own

> [!WARNING]
> **Changing from Auto to None**: If you change this setting from `Auto` to `None` on an existing cluster, the default NodePools aren't deleted automatically. You must manually delete them if desired.

## Comprehensive NodePool example

The following example demonstrates all available NodePool configuration options with detailed comments:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  # Template section that describes how to template out NodeClaim resources that Karpenter will provision
  # Karpenter will consider this template to be the minimum requirements needed to provision a Node using this NodePool
  # It will overlay this NodePool with Pods that need to schedule to further constrain the NodeClaims
  # Karpenter will provision to launch new Nodes for the cluster
  template:
    metadata:
      # Labels are arbitrary key-values that are applied to all nodes
      labels:
        billing-team: my-team

      # Annotations are arbitrary key-values that are applied to all nodes
      annotations:
        example.com/owner: "my-team"
    spec:
      nodeClassRef:
        apiVersion: karpenter.azure.com/v1beta1
        kind: AKSNodeClass
        name: default

      # Provisioned nodes will have these taints
      # Taints may prevent pods from scheduling if they are not tolerated by the pod.
      taints:
        - key: example.com/special-taint
          effect: NoSchedule

      # Provisioned nodes will have these taints, but pods do not need to tolerate these taints to be provisioned by this
      # NodePool. These taints are expected to be temporary and some other entity (e.g. a DaemonSet) is responsible for
      # removing the taint after it has finished initializing the node.
      startupTaints:
        - key: example.com/another-taint
          effect: NoSchedule

      # Requirements that constrain the parameters of provisioned nodes.
      # These requirements are combined with pod.spec.topologySpreadConstraints, pod.spec.affinity.nodeAffinity, pod.spec.affinity.podAffinity, and pod.spec.nodeSelector rules.
      # Operators { In, NotIn, Exists, DoesNotExist, Gt, and Lt } are supported.
      # https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#operators
      requirements:
        - key: "karpenter.azure.com/sku-family"
          operator: In
          values: ["D", "E", "F"]
          # minValues here enforces the scheduler to consider at least that number of unique sku-family to schedule the pods.
          # This field is ALPHA and can be dropped or replaced at any time 
          minValues: 2
        - key: "karpenter.azure.com/sku-name"
          operator: In
          values: ["Standard_D2s_v3","Standard_D4s_v3","Standard_E2s_v3","Standard_E4s_v3","Standard_F2s_v2","Standard_F4s_v2"]
          minValues: 5
        - key: "karpenter.azure.com/sku-cpu"
          operator: In
          values: ["2", "4", "8", "16"]
        - key: "karpenter.azure.com/sku-version"
          operator: Gt
          values: ["2"]
        - key: "topology.kubernetes.io/zone"
          operator: In
          values: ["eastus-1", "eastus-2"]
        - key: "kubernetes.io/arch"
          operator: In
          values: ["arm64", "amd64"]
        - key: "karpenter.sh/capacity-type"
          operator: In
          values: ["spot", "on-demand"]

      # ExpireAfter is the duration the controller will wait
      # before terminating a node, measured from when the node is created. This
      # is useful to implement features like eventually consistent node upgrade,
      # memory leak protection, and disruption testing.
      expireAfter: 720h

      # TerminationGracePeriod is the maximum duration the controller will wait before forcefully deleting the pods on a node, measured from when deletion is first initiated.
      # 
      # Warning: this feature takes precedence over a Pod's terminationGracePeriodSeconds value, and bypasses any blocked PDBs or the karpenter.sh/do-not-disrupt annotation.
      # 
      # This field is intended to be used by cluster administrators to enforce that nodes can be cycled within a given time period.
      # When set, drifted nodes will begin draining even if there are pods blocking eviction. Draining will respect PDBs and the do-not-disrupt annotation until the TGP is reached.
      # 
      # Karpenter will preemptively delete pods so their terminationGracePeriodSeconds align with the node's terminationGracePeriod.
      # If a pod would be terminated without being granted its full terminationGracePeriodSeconds prior to the node timeout,
      # that pod will be deleted at T = node timeout - pod terminationGracePeriodSeconds.
      # 
      # The feature can also be used to allow maximum time limits for long-running jobs which can delay node termination with preStop hooks.
      # If left undefined, the controller will wait indefinitely for pods to be drained.
      terminationGracePeriod: 30s

  # Disruption section which describes the ways in which Karpenter can disrupt and replace Nodes
  # Configuration in this section constrains how aggressive Karpenter can be with performing operations
  # like rolling Nodes due to them hitting their maximum lifetime (expiry) or scaling down nodes to reduce cluster cost
  disruption:
    # Describes which types of Nodes Karpenter should consider for consolidation
    # If using 'WhenEmptyOrUnderutilized', Karpenter will consider all nodes for consolidation and attempt to remove or replace Nodes when it discovers that the Node is underutilized and could be changed to reduce cost
    # If using `WhenEmpty`, Karpenter will only consider nodes for consolidation that contain no workload pods
    consolidationPolicy: WhenEmptyOrUnderutilized | WhenEmpty

    # The amount of time Karpenter should wait after discovering a consolidation decision
    # This value can currently only be set when the consolidationPolicy is 'WhenEmpty'
    # You can choose to disable consolidation entirely by setting the string value 'Never' here
    consolidateAfter: 30s

    # Budgets control the speed Karpenter can scale down nodes.
    # Karpenter will respect the minimum of the currently active budgets, and will round up
    # when considering percentages. Duration and Schedule must be set together.
    budgets:
    - nodes: 10%
    # On Weekdays during business hours, don't do any deprovisioning.
    - schedule: "0 9 * * mon-fri"
      duration: 8h
      nodes: "0"

  # Resource limits constrain the total size of the pool.
  # Limits prevent Karpenter from creating new instances once the limit is exceeded.
  limits:
    cpu: "1000"
    memory: 1000Gi

  # Priority given to the NodePool when the scheduler considers which NodePool
  # to select. Higher weights indicate higher priority when comparing NodePools.
  # Specifying no weight is equivalent to specifying a weight of 0.
  weight: 10
```

## Supported node provisioner requirements

Kubernetes defines [Well-Known Labels](https://kubernetes.io/docs/reference/labels-annotations-taints/) that Azure implements. Define these labels in the "spec.requirements" section of the NodePool API.

In addition to the well-known labels from Kubernetes, Node Auto Provisioning supports Azure-specific labels for more advanced scheduling.

### SKU selectors with well-known labels

| Selector | Description | Example |
|--|--|--|
| karpenter.azure.com/sku-family | VM SKU Family | D, F, L etc. |
| karpenter.azure.com/sku-name | Explicit SKU name | Standard_A1_v2 |
| karpenter.azure.com/sku-version | SKU version (without "v", can use 1) | 1 , 2 |
| karpenter.sh/capacity-type | VM allocation type (Spot / On Demand) | spot or on-demand |
| karpenter.azure.com/sku-cpu | Number of CPUs in VM | 16 |
| karpenter.azure.com/sku-memory | Memory in VM in MiB | 131072 |
| karpenter.azure.com/sku-gpu-name | GPU name | A100 |
| karpenter.azure.com/sku-gpu-manufacturer | GPU manufacturer | nvidia |
| karpenter.azure.com/sku-gpu-count | GPU count per VM | 2 |
| karpenter.azure.com/sku-networking-accelerated | Whether the VM has accelerated networking | [true, false] |
| karpenter.azure.com/sku-storage-premium-capable | Whether the VM supports Premium IO storage | [true, false] |
| karpenter.azure.com/sku-storage-ephemeralos-maxsize | Size limit for the Ephemeral OS disk in Gb | 92 |
| topology.kubernetes.io/zone | The Availability Zone(s) | [uksouth-1,uksouth-2,uksouth-3] |
| kubernetes.io/os | Operating System (Linux only during preview) | linux |
| kubernetes.io/arch | CPU architecture (AMD64 or ARM64) | [amd64, arm64] |

### Well-known labels

#### Instance types

- **key**: `node.kubernetes.io/instance-type`
- **key**: `karpenter.azure.com/sku-family`
- **key**: `karpenter.azure.com/sku-name`
- **key**: `karpenter.azure.com/sku-version`

Generally, instance types should be a list and not a single value. Leaving these requirements undefined is recommended, as it maximizes choices for efficiently placing pods.

Most Azure VM sizes are supported with the exclusion of specialized sizes that don't support AKS.

##### SKU family examples
The `karpenter.azure.com/sku-family` selector allows you to target specific VM families:
- **D-series**: General-purpose VMs with balanced CPU-to-memory ratio
- **F-series**: Compute-optimized VMs with high CPU-to-memory ratio
- **E-series**: Memory-optimized VMs for memory-intensive applications
- **L-series**: Storage-optimized VMs with high disk throughput
- **N-series**: GPU-enabled VMs for compute-intensive workloads

Example configuration:
```yaml
requirements:
- key: karpenter.azure.com/sku-family
  operator: In
  values:
  - D
  - F
```

##### SKU name examples
The `karpenter.azure.com/sku-name` selector allows you to specify the exact VM instance type:
```yaml
requirements:
- key: karpenter.azure.com/sku-name
  operator: In
  values:
  - Standard_D4s_v3
  - Standard_F8s_v2
```

##### SKU version examples
The `karpenter.azure.com/sku-version` selector targets specific generations:
```yaml
requirements:
- key: karpenter.azure.com/sku-version
  operator: In
  values:
  - "3"  # v3 generation
  - "5"  # v5 generation
```

#### Availability zones

- **key**: `topology.kubernetes.io/zone`
- **value example**: `eastus-1`
- **value list**: Use `az account list-locations --output table` to see available zones

Node Auto Provisioning can be configured to create nodes in a particular zone. The Availability Zone `eastus-1` for your Azure subscription might not have the same physical location as `eastus-1` for another Azure subscription.

#### Architecture

- **key**: `kubernetes.io/arch`
- **values**:
  - `amd64`
  - `arm64`

Node Auto Provisioning supports both `amd64` and `arm64` nodes.

#### Operating system

- **key**: `kubernetes.io/os`
- **values**:
  - `linux`

Node Auto Provisioning supports `linux` operating systems(Ubuntu + AzureLinux). Windows support is coming soon.

#### Capacity type

- **key**: `karpenter.sh/capacity-type`
- **values**:
  - `spot`
  - `on-demand`

Node Auto Provisioning prioritizes Spot offerings if the NodePool allows Spot and on-demand instances.

## Node pool limits

By default, node autoprovisioning attempts to schedule your workloads within the Azure quota you have available. You can also specify the upper limit of resources that is used by a node pool, specifying limits within the node pool spec.

```yaml
spec:
  # Resource limits constrain the total size of the cluster.
  # Limits prevent Node Auto Provisioning from creating new instances once the limit is exceeded.
  limits:
    cpu: "1000"
    memory: 1000Gi
```

## Node pool weights

When you have multiple node pools defined, it's possible to set a preference of where a workload should be scheduled. Define the relative weight on your Node pool definitions.

```yaml
spec:
  # Priority given to the node pool when the scheduler considers which to select. 
  # Higher weights indicate higher priority when comparing node pools.
  # Specifying no weight is equivalent to specifying a weight of 0.
  weight: 10
```

## Example node pool configurations

### GPU-enabled node pool

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: gpu-pool
spec:
  weight: 20
  limits:
    cpu: "500"
    memory: 500Gi
  template:
    spec:
      nodeClassRef:
        name: default
      requirements:
      - key: karpenter.azure.com/sku-gpu-manufacturer
        operator: In
        values:
        - nvidia
      - key: karpenter.azure.com/sku-gpu-count
        operator: Gt
        values:
        - "0"
```

### Spot instance node pool

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: spot-pool
spec:
  weight: 5
  template:
    spec:
      nodeClassRef:
        name: default
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - spot
        - on-demand # Spot nodepools with on-demand configured will fallback to on-demand capacity
      - key: karpenter.azure.com/sku-family
        operator: In
        values:
        - D
        - F
```



## Next steps

- [Configure node disruption policies](node-autoprovision-disruption.md)
- [Learn about networking configuration](node-autoprovision-networking.md)
- [Configure AKSNodeClass settings](node-autoprovision-aksnodeclass.md)
