---
title: Configure Node Pools for Node Auto-Provisioning (NAP) in Azure Kubernetes Service (AKS)
description: This article shows you how to configure node pools for Node Auto-Provisioning (NAP) in Azure Kubernetes Service (AKS), including SKU selectors, limits, and weights.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 07/25/2025
ms.author: schaffererin
author: schaffererin
ms.service: azure-kubernetes-service
# Customer intent: As a cluster operator or developer, I want to configure node pools for my AKS clusters using node auto-provisioning, so that I can optimize resource allocation and cost efficiency for my workloads.
---

# Configure node pools for node auto-provisioning (NAP) in Azure Kubernetes Service (AKS)

This article explains how to configure node pools for node auto-provisioning (NAP) in Azure Kubernetes Service (AKS), including SKU selectors, resource limits, and priority weights. It also provides examples to help you get started.

## Overview of node pools in NAP

NAP uses virtual machine (VM) SKU requirements to decide the best VMs for pending workloads. You can configure:

- SKU families and specific instance types.
- Resource limits and priorities.
- Spot or on-demand instances.
- Architecture and capabilities requirements.

The `NodePool` resource sets constraints on the nodes that NAP creates and the pods that run on those nodes. When you first install NAP, it creates a [default `NodePool`](#review-default-node-pool-configuration). You can modify this node pool or create extra node pools to suit your workload requirements.

## Key behaviors of `NodePools` in NAP

When configuring `NodePools` for NAP, keep the following behaviors in mind:

- NAP requires at least one `NodePool` to function.
- NAP evaluates each configured `NodePool`.
- NAP skips `NodePools` with taints not tolerated by a pod.
- NAP applies startup taints to provisioned nodes but doesn't require pod toleration.
- NAP works best with mutually exclusive `NodePools`. When multiple `NodePools` match, it uses the one with highest weight.

## Review default node pool configuration

When you enable NAP on a new AKS cluster, it creates a default `NodePool` named `default` with the following configuration:

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

It also creates a `system-surge` node pool to autoscale system pool nodes.

## Control configuration of default node pool during cluster creation

When you [create a new AKS cluster enabled with NAP using the Azure CLI](./use-node-auto-provisioning.md#enable-nap-on-a-new-cluster), you can include the `--node-provisioning-default-pools` flag to control the configuration of the default NAP `NodePool`.

The `--node-provisioning-default-pools` flag controls the default NAP `NodePool` configuration and accepts the following values:

- **`Auto`** (default): Creates two standard `NodePools` for immediate use.
- **`None`**: Doesn't create any `NodePools`. You must define your own.

> [!WARNING]
> **Changing from `Auto` to `None`**: If you change the setting from `Auto` to `None` on an existing cluster, the default `NodePools` aren't deleted automatically. You must delete them manually if you no longer need them.

## Node pool configuration options

The following sections outline various configuration options for `NodePools` in NAP, including [well-known labels and SKU selectors](#well-known-labels-and-sku-selectors), [node pool limits](#node-pool-limits), and [node pool weights](#node-pool-weights).

### Well-known labels and SKU selectors

Kubernetes defines [well-known labels](https://kubernetes.io/docs/reference/labels-annotations-taints/) that Azure implements. You can define these labels in the `spec.requirements` section of the `NodePool` API. NAP also supports Azure-specific labels for more advanced scheduling.

| Selector | Description | Example |
|--|--|--|
| `karpenter.azure.com/sku-family` | VM SKU family | D, F, L, etc. |
| `karpenter.azure.com/sku-name` | Explicit SKU name | Standard_A1_v2 |
| `karpenter.azure.com/sku-version` | SKU version (without "v", can use 1) | 1, 2 |
| `karpenter.sh/capacity-type` | VM allocation type (Spot / On Demand) | Spot or on-demand |
| `karpenter.azure.com/sku-cpu` | Number of CPUs in VM | 16 |
| `karpenter.azure.com/sku-memory` | Memory in VM in MiB | 131072 |
| `karpenter.azure.com/sku-gpu-name` | GPU name | A100 |
| `karpenter.azure.com/sku-gpu-manufacturer` | GPU manufacturer | nvidia |
| `karpenter.azure.com/sku-gpu-count` | GPU count per VM | 2 |
| `karpenter.azure.com/sku-networking-accelerated` | Whether the VM has accelerated networking | [true, false] |
| `karpenter.azure.com/sku-storage-premium-capable` | Whether the VM supports Premium IO storage | [true, false] |
| `karpenter.azure.com/sku-storage-ephemeralos-maxsize` | Size limit for the Ephemeral operating system (OS) disk in Gb | 92 |
| `topology.kubernetes.io/zone` | Availability zone(s) | [uksouth-1,uksouth-2,uksouth-3] |
| `kubernetes.io/os` | Operating system (Linux only during preview) | linux |
| `kubernetes.io/arch` | CPU architecture (AMD64 or ARM64) | [amd64, arm64] |

> [!NOTE]
> Generally, instance types should be a list and not a single value. We recommend leaving these requirements undefined to maximize choices for efficiently placing pods. Most Azure VM sizes are supported with the exclusion of specialized sizes that don't support AKS.

#### SKU family examples

The `karpenter.azure.com/sku-family` selector allows you to target specific VM families.

| Family | Description |
|--------|-------------|
| D-series | General-purpose VMs with balanced CPU-to-memory ratio |
| F-series | Compute-optimized VMs with high CPU-to-memory ratio |
| E-series | Memory-optimized VMs for memory-intensive applications |
| L-series | Storage-optimized VMs with high disk throughput |
| N-series | GPU-enabled VMs for compute-intensive workloads |

Example configuration using SKU family:

```yaml
requirements:
- key: karpenter.azure.com/sku-family
  operator: In
  values:
  - D
  - F
```

#### SKU name examples

The `karpenter.azure.com/sku-name` selector allows you to specify the exact VM instance type.

```yaml
requirements:
- key: karpenter.azure.com/sku-name
  operator: In
  values:
  - Standard_D4s_v3
  - Standard_F8s_v2
```

#### SKU version examples

The `karpenter.azure.com/sku-version` selector targets specific generations of VM SKUs.

```yaml
requirements:
- key: karpenter.azure.com/sku-version
  operator: In
  values:
  - "3"  # v3 generation
  - "5"  # v5 generation
```

#### Availability zone example

The `topology.kubernetes.io/zone` selector allows you to specify the availability zones for your nodes.

```yaml
requirements:
- key: topology.kubernetes.io/zone
  operator: In
  values:
  - eastus-1
  - eastus-2
```

> [!NOTE]
> You can find available zones for your region using the `az account list-locations --output table` Azure CLI command.

#### Architecture example

The `kubernetes.io/arch` selector allows you to specify the CPU architecture for your nodes. NAP supports both `amd64` and `arm64` nodes.

```yaml
requirements:
- key: kubernetes.io/arch
  operator: In
  values:
  - amd64
  - arm64
```

#### OS example

The `kubernetes.io/os` selector allows you to specify the operating system for your nodes. Currently, NAP supports an OS type of `linux`.

```yaml
requirements:
- key: kubernetes.io/os
  operator: In
  values:
  - linux
```

#### Capacity type example

The `karpenter.sh/capacity-type` selector allows you to specify whether to use spot or on-demand instances. NAP prioritizes spot instances if both are allowed.

```yaml
requirements:
- key: karpenter.sh/capacity-type
  operator: In
  values:
  - spot
  - on-demand
```

### Node pool limits

By default, NAP attempts to schedule your workloads within the Azure quota you have available. You can also specify the upper limit of resources that a node pool uses by specifying limits within the node pool spec. For example:

```yaml
spec:
  # Resource limits constrain the total size of the cluster.
  # Limits prevent Node Auto Provisioning from creating new instances once the limit is exceeded.
  limits:
    cpu: "1000"
    memory: 1000Gi
```

### Node pool weights

When you have multiple node pools defined, you can set a preference of where a workload should be scheduled by defining the relative weight in your node pool definitions. For example:

```yaml
spec:
  # Priority given to the node pool when the scheduler considers which to select. 
  # Higher weights indicate higher priority when comparing node pools.
  # Specifying no weight is equivalent to specifying a weight of 0.
  weight: 10
```

## Comprehensive example of all `NodePool` configuration options

The following example demonstrates all available `NodePool` configuration options with detailed comments included for clarity:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  # Template section that describes how to template out NodeClaim resources that Karpenter provisions
  # Karpenter considers this template to be the minimum requirements needed to provision a Node using this NodePool
  # It overlays this NodePool with Pods that need to schedule to further constrain the NodeClaims
  # Karpenter provisions to launch new Nodes for the cluster
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

## Next steps

For more information on node auto-provisioning in AKS, see the following articles:

- [Configure networking for node auto-provisioning on AKS](./node-auto-provisioning-networking.md)
- [Configure disruption policies for node auto-provisioning on AKS](./node-auto-provisioning-disruption.md)
- [Create a node auto-provisioning cluster in a custom virtual network in AKS](./node-auto-provisioning-custom-vnet.md)
