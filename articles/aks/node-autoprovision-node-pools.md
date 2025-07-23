---
title: Node autoprovisioning node pools configuration
description: Learn how to configure node pools for Azure Kubernetes Service (AKS) node autoprovisioning, including SKU selectors, limits, and weights.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 06/13/2024
ms.author: bsoghigian
author: bsoghigian
---

# Node autoprovisioning node pools configuration

This article explains how to configure node pools for Azure Kubernetes Service (AKS) node autoprovisioning (NAP), including SKU selectors, resource limits, and priority weights.

## Node pool overview

NodePools set constraints on the nodes that Node Auto Provisioning can create and the pods that can run on those nodes. When you first installed node autoprovisioning, you set up a default NodePool. You can change your NodePool or add other NodePools to Node Auto Provisioning.

Key behaviors of NodePools:
- Node Auto Provisioning won't do anything if there is not at least one NodePool configured
- Each NodePool that is configured is looped through by Node Auto Provisioning
- If Node Auto Provisioning encounters a taint in the NodePool that is not tolerated by a pod, Node Auto Provisioning won't use that NodePool to provision the pod
- If Node Auto Provisioning encounters a startup taint in the NodePool, it will be applied to nodes that are provisioned, but pods do not need to tolerate the taint
- It is recommended to create NodePools that are mutually exclusive. If multiple NodePools are matched, Node Auto Provisioning will use the NodePool with the highest weight

Node autoprovisioning uses VM SKU requirements to decide which virtual machine is best suited for pending workloads. You can configure specific SKU families, virtual machine types, spot vs on-demand instances, multiple architectures, and resource limits.

## Default node pool configuration

### Understanding Default NodePools

AKS creates a default node pool configuration that you can customize:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  disruption:
    consolidationPolicy: WhenUnderutilized
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

As well as a `system-surge` nodepool that will autoscale your systempool nodes. 

The `--node-provisioning-default-pools` flag controls which default Node Auto Provisioning NodePools are created:

- **`Auto`** (default): Creates two standard NodePools for immediate use
- **`None`**: No default NodePools are created - you must define your own

> [!WARNING]
> **Changing from Auto to None**: If you change this setting from `Auto` to `None` on an existing cluster, the default NodePools aren't deleted by default.

The `--node-provisioning-default-pools` flag controls which default Node Auto Provisioning NodePools are created:

- **`Auto`** (default): Creates two standard NodePools for immediate use
- **`None`**: No default NodePools are created - you must define your own

> [!WARNING]
> **Changing from Auto to None**: If you change this setting from `Auto` to `None` on an existing cluster, the default NodePools aren't deleted by default.

## Supported node provisioner requirements

Kubernetes defines the following [Well-Known Labels](https://kubernetes.io/docs/reference/labels-annotations-taints/), and Azure implements them. They are defined at the "spec.requirements" section of the NodePool API.

In addition to the well-known labels from Kubernetes, Node Auto Provisioning supports Azure-specific labels for more advanced scheduling.

### SKU selectors with well known labels

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

### Well-Known Labels

#### Instance Types

- **key**: `node.kubernetes.io/instance-type`
- **key**: `karpenter.azure.com/sku-family`
- **key**: `karpenter.azure.com/sku-name`
- **key**: `karpenter.azure.com/sku-version`

Generally, instance types should be a list and not a single value. Leaving these requirements undefined is recommended, as it maximizes choices for efficiently placing pods.

Most Azure VM sizes are supported with the exclusion of specialized sizes that don't support AKS.

##### SKU Family Examples
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

##### SKU Name Examples
The `karpenter.azure.com/sku-name` selector allows you to specify exact VM SKUs:
```yaml
requirements:
- key: karpenter.azure.com/sku-name
  operator: In
  values:
  - Standard_D4s_v3
  - Standard_F8s_v2
```

##### SKU Version Examples
The `karpenter.azure.com/sku-version` selector targets specific generations:
```yaml
requirements:
- key: karpenter.azure.com/sku-version
  operator: In
  values:
  - "3"  # v3 generation
  - "5"  # v5 generation
```

#### Availability Zones

- **key**: `topology.kubernetes.io/zone`
- **value example**: `eastus-1`
- **value list**: Use `az account list-locations --output table` to see available zones

Node Auto Provisioning can be configured to create nodes in a particular zone. Note that the Availability Zone `eastus-1` for your Azure subscription might not have the same phyisical location as `eastus-1` for another Azure subscription.

#### Architecture

- **key**: `kubernetes.io/arch`
- **values**:
  - `amd64`
  - `arm64`

Node Auto Provisioning supports both `amd64` and `arm64` nodes.

#### Operating System

- **key**: `kubernetes.io/os`
- **values**:
  - `linux`

Node Auto Provisioning supports `linux` operating systems(Ubuntu + AzureLinux). Windows support is coming soon.

#### Capacity Type

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
- [Monitor node autoprovisioning](node-autoprovision-monitoring.md)
- [Learn about networking configuration](node-autoprovision-networking.md)
