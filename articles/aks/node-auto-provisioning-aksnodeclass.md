---
title: Configure AKSNodeClass Resources for Node Auto-Provisioning (NAP) in Azure Kubernetes Service (AKS)
description: Learn how to configure Azure-specific settings for AKS node auto-provisioning using AKSNodeClass resources.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 07/25/2025
ms.author: schaffererin
author: schaffererin
ms.service: azure-kubernetes-service
# Customer intent: As a cluster operator or developer, I want to configure Azure-specific settings for AKS node auto-provisioning using AKSNodeClass resources, so that I can optimize node provisioning for my workloads while leveraging Azure's capabilities.
---

# Configure AKSNodeClass resources for node auto-provisioning (NAP) in Azure Kubernetes Service (AKS)

This article explains how to configure `AKSNodeClass` resources to define Azure-specific settings for node auto-provisioning (NAP) in Azure Kubernetes Service (AKS) using Karpenter. `AKSNodeClass` allows you to customize various aspects of the nodes that Karpenter provisions, such as the virtual machine (VM) image, operating system (OS) disk size, maximum pods per node, and kubelet configurations.

> [!IMPORTANT]
> Starting on **30 November 2025**, AKS will no longer support or provide security updates for Azure Linux 2.0. Starting on **31 March 2026**, node images will be removed, and you'll be unable to scale your node pools. Migrate to a supported Azure Linux version by [**upgrading your node pools**](/azure/aks/upgrade-aks-cluster) to a supported Kubernetes version or migrating to [`osSku AzureLinux3`](/azure/aks/upgrade-os-version). For more information, see [[Retirement] Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).

## Overview of AKSNodeClass resources

`AKSNodeClass` resources enable you to configure Azure-specific settings for NAP. Each [`NodePool` resource](./node-auto-provisioning-node-pools.md) must reference an `AKSNodeClass` using `spec.template.spec.nodeClassRef`. You can have multiple `NodePools` that point to the same `AKSNodeClass`, allowing you to share common Azure configurations across different node pools.

## Image family configuration

The `imageFamily` field dictates the default VM image and bootstrapping logic for nodes provisioned through the `AKSNodeClass`. If you don't specify an image family, the default is `Ubuntu2204`. GPUs are supported with both image families on compatible VM sizes.

### Supported image families

- **`Ubuntu`**: Ubuntu 22.04 Long Term Support (LTS) is the default Linux distribution for AKS nodes.
- **`AzureLinux`**: Azure Linux is Microsoft's alternative Linux distribution for AKS workloads. For more information, see the [Azure Linux documentation](/azure/aks/use-azure-linux)

#### Example image family configuration

The following example configures the `AKSNodeClass` to use the `AzureLinux` image family:

```yaml
spec:
  imageFamily: AzureLinux
```

## Virtual network (VNet) subnet configuration

The `vnetSubnetID` field specifies which Azure VNet subnet should be used for provisioning node network interfaces. This field is optional. If you don't specify a subnet, NAP uses the default subnet configured during Karpenter installation. For more information, see [Subnet configurations for NAP](./node-auto-provisioning-networking.md#subnet-configurations-for-nap).

### Example subnet configuration

The subnet ID must be in the full Azure Resource Manager (ARM) format, as shown in the following example:

```yaml
spec:
  vnetSubnetID: "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Network/virtualNetworks/{vnet-name}/subnets/{subnet-name}"
```

## OS disk size configuration

The `osDiskSizeGB` field specifies the size of the OS disk in gigabytes. The default value is 128 GB, and the minimum value is 30 GB.

Consider larger OS disk sizes for workloads that:

- Store significant data locally.
- Require extra space for container images.
- Have high disk I/O requirements.

### Example OS disk size configuration

```yaml
spec:
  osDiskSizeGB: 256  # 256 GB OS disk
```

## Ephemeral OS disk configuration

NAP automatically uses [Ephemeral OS disks](/azure/virtual-machines/ephemeral-os-disks) when available and suitable for the requested disk size. Ephemeral OS disks provide better performance and lower cost compared to managed disks.

### Ephemeral disk selection criteria

The system automatically chooses Ephemeral disks in the following scenarios:

- The VM instance type supports Ephemeral OS disks.
- The Ephemeral disk capacity is greater than or equal to the requested `osDiskSizeGB`.
- The VM has sufficient ephemeral storage capacity.

If these conditions aren't met, the system falls back to using managed disks.

### Ephemeral disk types and prioritization

Azure VMs can have different types of ephemeral storage. The system uses the following priority order:

- **NVMe disks** (highest performance)
- **Cache disks** (balanced performance)
- **Resource disks** (basic performance)

### Example ephemeral disk configuration

You can use node pool requirements to ensure nodes have sufficient ephemeral disk capacity, as shown in the following example:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: ephemeral-disk-pool
spec:
  template:
    spec:
      requirements:
        - key: karpenter.azure.com/sku-storage-ephemeral-os-maxsize
          operator: Gt
          values: ["128"]  # Require ephemeral disk larger than 128 GB
      nodeClassRef:
        apiVersion: karpenter.azure.com/v1beta1
        kind: AKSNodeClass
        name: my-node-class
---
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: my-node-class
spec:
  osDiskSizeGB: 128  # This will use ephemeral disk if available and large enough
```

This configuration ensures that only VM instance types with ephemeral disks larger than 128 GB are selected, guaranteeing ephemeral disk usage for the specified OS disk size.

## Maximum pods configuration

The `maxPods` field specifies the maximum number of pods that can be scheduled on a node. This setting affects both cluster density and network configuration.

The minimum value for `maxPods` is 10, and the maximum value is 250.

### Default behavior for `maxPods`

The default behavior for `maxPods` depends on the network plugin configuration. The following table summarizes the defaults:

| Network plugin configuration | Default `maxPods` per node |
|------------------------------|----------------------------|
| Azure CNI with standard networking (v1 or NodeSubnet) | 30 |
| Azure CNI with overlay networking | 250 |
| None (no network plugin) | 250 |
| Other configurations | 110 (standard Kubernetes default) |

### Example maximum pods configuration

```yaml
spec:
  maxPods: 50  # Allow up to 50 pods per node
```

## Kubelet configuration

The `kubelet` section allows you to configure various kubelet parameters that affect node behavior. These parameters are typical kubelet arguments, so the Azure provider simply passes them through to the kubelet on the node.

> [!IMPORTANT]
> **Configure kubelet settings carefully**, and test any changes in nonproduction environments first.

### CPU management

The following settings control CPU management behavior for the kubelet:

```yaml
spec:
  kubelet:
    cpuManagerPolicy: "static"  # or "none"
    cpuCFSQuota: true
    cpuCFSQuotaPeriod: "100ms"
```

- `cpuManagerPolicy`: Controls how the kubelet allocates CPU resources. Set to `"static"` for CPU pinning in latency-sensitive workloads.
- `cpuCFSQuota`: Enables CPU Completely Fair Scheduler (CFS) quota enforcement for containers that specify CPU limits.
- `cpuCFSQuotaPeriod`: Sets the CPU CFS quota period.

### Image garbage collection

The following settings control image garbage collection behavior for the kubelet:

```yaml
spec:
  kubelet:
    imageGCHighThresholdPercent: 85
    imageGCLowThresholdPercent: 80
```

These settings control when the kubelet performs garbage collection of container images:

- `imageGCHighThresholdPercent`: Disk usage percentage that triggers image garbage collection.
- `imageGCLowThresholdPercent`: Target disk usage percentage after garbage collection.

### Topology management

The following setting controls the topology manager policy for the kubelet:

```yaml
spec:
  kubelet:
    topologyManagerPolicy: "best-effort"  # none, restricted, best-effort, single-numa-node
```

The topology manager helps coordinate resource allocation for latency-sensitive workloads across CPU and device (like GPU) resources.

### System configuration

The following settings allow you to configure extra system parameters for the kubelet:

```yaml
spec:
  kubelet:
    allowedUnsafeSysctls:
      - "kernel.msg*"
      - "net.ipv4.route.min_pmtu"
    containerLogMaxSize: "50Mi"
    containerLogMaxFiles: 5
    podPidsLimit: 4096
```

- `allowedUnsafeSysctls`: List of permitted unsafe sysctls that pods can use.
- `containerLogMaxSize`: Maximum size of container log files before rotation.
- `containerLogMaxFiles`: Maximum number of container log files to retain.
- `podPidsLimit`: Maximum number of processes allowed in any pod.

## Azure resource tags configuration

You can specify Azure resource tags that apply to all VM instances created using a particular `AKSNodeClass` resource. Tags are useful for cost tracking, resource organization, and compliance requirements.

### Tag limitations

- Azure resource tags have a limit of 50 tags per resource.
- Tag names are case-insensitive but tag values are case-sensitive.
- Azure reserves some tag names that can't be used. For more information, see [Tag guidance and limits](/azure/azure-resource-manager/management/tag-resources#tag-restrictions).

### Example tags configuration

```yaml
spec:
  tags:
    Environment: "production"
    Team: "platform"
    Application: "web-service"
    CostCenter: "engineering"
```

## Comprehensive `AKSNodeClass` configuration example

The following example demonstrates a comprehensive `AKSNodeClass` configuration that includes all the settings discussed in this article:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      nodeClassRef:
        apiVersion: karpenter.azure.com/v1beta1
        kind: AKSNodeClass
        name: comprehensive-example
---
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: comprehensive-example
spec:
  # Image family configuration
  # Default: Ubuntu
  # Valid values: Ubuntu, AzureLinux
  imageFamily: Ubuntu

  # FIPS compliant mode - allows support for FIPS-compliant node images
  # Default: Disabled
  # Valid values: FIPS, Disabled
  fipsMode: Disabled

  # Virtual network subnet configuration (optional)
  # If not specified, uses the default --vnet-subnet-id from Karpenter installation
  vnetSubnetID: "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/my-rg/providers/Microsoft.Network/virtualNetworks/my-vnet/subnets/my-subnet"

  # OS disk size configuration
  # Default: 128 GB
  # Minimum: 30 GB
  osDiskSizeGB: 128

  # Maximum pods per node configuration
  # Default behavior depends on network plugin:
  # - Azure CNI with standard networking: 30 pods
  # - Azure CNI with overlay networking: 250 pods
  # - Other configurations: 110 pods
  # Range: 10-250
  maxPods: 30

  # Azure resource tags (optional)
  # Applied to all VM instances created with this AKSNodeClass
  tags:
    Environment: "production"
    Team: "platform-team"
    Application: "web-service"
    CostCenter: "engineering"

  # Kubelet configuration (optional)
  # All fields are optional with sensible defaults
  kubelet:
    # CPU management policy
    # Default: "none"
    # Valid values: none, static
    cpuManagerPolicy: "static"

    # CPU CFS quota enforcement
    # Default: true
    cpuCFSQuota: true

    # CPU CFS quota period
    # Default: "100ms"
    cpuCFSQuotaPeriod: "100ms"

    # Image garbage collection thresholds
    # imageGCHighThresholdPercent must be greater than imageGCLowThresholdPercent
    # Range: 0-100
    imageGCHighThresholdPercent: 85
    imageGCLowThresholdPercent: 80

    # Topology manager policy
    # Default: "none"
    # Valid values: none, restricted, best-effort, single-numa-node
    topologyManagerPolicy: "best-effort"

    # Allowed unsafe sysctls (optional)
    # Comma-separated list of unsafe sysctls or patterns
    allowedUnsafeSysctls:
      - "kernel.msg*"
      - "net.ipv4.route.min_pmtu"

    # Container log configuration
    # containerLogMaxSize default: "50Mi"
    containerLogMaxSize: "50Mi"
    
    # containerLogMaxFiles default: 5, minimum: 2
    containerLogMaxFiles: 5

    # Pod process limits
    # Default: -1 (unlimited)
    podPidsLimit: 4096
```

## Next steps

For more information on node auto-provisioning in AKS, see the following articles:

- [Use node auto-provisioning in a custom virtual network](./node-auto-provisioning-custom-vnet.md)
- [Configure node pools for node auto-provisioning on AKS](./node-auto-provisioning-node-pools.md)
- [Configure disruption policies for node auto-provisioning on AKS](./node-auto-provisioning-disruption.md)
