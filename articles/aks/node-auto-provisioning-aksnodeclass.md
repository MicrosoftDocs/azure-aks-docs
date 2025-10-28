---
title: Configure AKSNodeClass for node auto-provisioning in Azure Kubernetes Service (AKS)
description: Learn how to configure Azure-specific settings for Azure Kubernetes Service (AKS) node auto-provisioning using AKSNodeClass.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 07/25/2025
ms.author: bsoghigian
author: bsoghigian
ms.service: azure-kubernetes-service
# Customer intent: As a cluster operator or developer, I want to configure Azure-specific settings for AKS node auto-provisioning using AKSNodeClass resources, so that I can optimize node provisioning for my workloads while leveraging Azure's capabilities.
---

# Node autoprovisioning AKSNodeClass configuration

This article explains how to configure Azure-specific settings for Azure Kubernetes Service (AKS) [node auto provisioning](node-autoprovision.md) using AKSNodeClass resources.

> [!IMPORTANT]
> Starting on **30 November 2025**, AKS will no longer support or provide security updates for Azure Linux 2.0. Starting on **31 March 2026**, node images will be removed, and you'll be unable to scale your node pools. Migrate to a supported Azure Linux version by [**upgrading your node pools**](/azure/aks/upgrade-aks-cluster) to a supported Kubernetes version or migrating to [`osSku AzureLinux3`](/azure/aks/upgrade-os-version). For more information, see [[Retirement] Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).

## AKSNodeClass overview

AKSNodeClass enables configuration of Azure-specific settings for node auto provisioning. Each NodePool must reference an AKSNodeClass using `spec.template.spec.nodeClassRef`. Multiple NodePools may point to the same AKSNodeClass, allowing you to share common Azure configurations across different node pools.

## Comprehensive AKSNodeClass configuration

Here's a comprehensive example showing all available AKSNodeClass configuration options with their defaults:

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
  # Default: Ubuntu2204
  # Valid values: Ubuntu2204, AzureLinux
  imageFamily: Ubuntu2204

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

## Image family configuration

The `imageFamily` field dictates the default virtual machine (VM) image and bootstrapping logic for nodes provisioned through this AKSNodeClass. If not specified, the default is `Ubuntu2204`. GPUs are supported with both image families on compatible VM sizes.

### Supported image families

- **`Ubuntu2204`** - Ubuntu 22.04 Long Term Support (LTS) is the default Linux distribution for AKS nodes
- **`AzureLinux`** - Azure Linux is Microsoft's alternative Linux distribution for AKS workloads. For more info on Azure Linux, [visit our documentation](/azure/aks/use-azure-linux)

Example configuration:

```yaml
spec:
  imageFamily: AzureLinux
```

## Virtual network subnet configuration

The `vnetSubnetID` field specifies which Azure Virtual Network subnet should be used for provisioning node network interfaces. This field is optional; if not specified, node auto provisioning uses the default subnet configured when initially enabled.

### Subnet ID format

The subnet ID must be in the full Azure Resource Manager format:

```yaml
spec:
  vnetSubnetID: "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Network/virtualNetworks/{vnet-name}/subnets/{subnet-name}"
```

### Default subnet behavior

When `vnetSubnetID` isn't specified, Karpenter automatically uses the default subnet configured during Karpenter installation. This fallback mechanism works as follows:

- **With vnetSubnetID specified**: node auto provisioning provisions nodes in the specified custom subnet
- **Without vnetSubnetID specified**: node auto provisioning provisions nodes in the cluster's default subnet

### Subnet requirements

The specified subnet must:
- Be in the same region as your AKS cluster
- Have sufficient IP addresses available for node provisioning
- Allow cluster communication through appropriate [Network Security Group][network-security-group] rules

## OS disk size configuration

The `osDiskSizeGB` field specifies the size of the OS disk in gigabytes. The default value is 128 GB, and the minimum value is 30 GB.

```yaml
spec:
  osDiskSizeGB: 256  # 256 GB OS disk
```

Consider larger OS disk sizes for workloads that:
- Store significant data locally
- Require extra space for container images
- Have high disk I/O requirements

### Ephemeral OS disk configuration

Node auto provisioning automatically uses ephemeral OS disks when available and suitable for the requested disk size. Ephemeral OS disks provide better performance and lower cost compared to managed disks.

#### How ephemeral disk selection works

The system automatically chooses ephemeral disks when:
- The VM instance type supports ephemeral OS disks
- The ephemeral disk capacity is greater than or equal to the requested `osDiskSizeGB`
- The VM has sufficient ephemeral storage capacity

If these conditions aren't met, the system falls back to using managed disks.

#### Ephemeral disk placement priority

Azure VMs can have different types of ephemeral storage. The system uses this priority order:
1. **NVMe disks** (highest performance)
2. **Cache disks** (balanced performance)
3. **Resource disks** (basic performance)

#### Selecting VMs with ephemeral disk support

You can use node pool requirements to ensure nodes have sufficient ephemeral disk capacity:

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

### Default behavior

The default behavior depends on the network plugin configuration:
- **Azure CNI with standard networking (v1 or NodeSubnet)**: 30 pods per node
- **Azure CNI with overlay networking**: 250 pods per node
- **None (no network plugin)**: 250 pods per node
- **Other configurations**: 110 pods per node (standard Kubernetes default)

### Valid range
- **Minimum**: 10 pods per node
- **Maximum**: 250 pods per node

```yaml
spec:
  maxPods: 50  # Allow up to 50 pods per node
```

With Azure Container Networking Interface (CNI) in standard mode, each pod gets an IP address from the subnet, so the maxPods setting is limited by available subnet IP addresses. With overlay networking, pods use a separate IP space allowing for higher pod density.

## Kubelet configuration

The `kubelet` section allows you to configure various kubelet parameters that affect node behavior. The Azure provider doesn't do anything special; these parameters are typical kubelet arguments.

### CPU management

```yaml
spec:
  kubelet:
    cpuManagerPolicy: "static"  # or "none"
    cpuCFSQuota: true
    cpuCFSQuotaPeriod: "100ms"
```

- `cpuManagerPolicy`: Controls how the kubelet allocates CPU resources. Set to "static" for CPU pinning in latency-sensitive workloads
- `cpuCFSQuota`: Enables CPU Completely Fair Scheduler (CFS) quota enforcement for containers that specify CPU limits
- `cpuCFSQuotaPeriod`: Sets the CPU CFS quota period

### Image garbage collection

```yaml
spec:
  kubelet:
    imageGCHighThresholdPercent: 85
    imageGCLowThresholdPercent: 80
```

These settings control when the kubelet performs garbage collection of container images:
- `imageGCHighThresholdPercent`: Disk usage percentage that triggers image garbage collection
- `imageGCLowThresholdPercent`: Target disk usage percentage after garbage collection

### Topology management

```yaml
spec:
  kubelet:
    topologyManagerPolicy: "best-effort"  # none, restricted, best-effort, single-numa-node
```

The topology manager helps coordinate resource allocation for latency-sensitive workloads across CPU and device (like GPU) resources.

### System configuration

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

- `allowedUnsafeSysctls`: List of permitted unsafe sysctls that pods can use
- `containerLogMaxSize`: Maximum size of container log files before rotation
- `containerLogMaxFiles`: Maximum number of container log files to retain
- `podPidsLimit`: Maximum number of processes allowed in any pod

## Azure resource tags

The `tags` field allows you to specify Azure resource tags that apply to all VM instances created using this AKSNodeClass. Tags are useful for cost tracking, resource organization, and compliance requirements.

```yaml
spec:
  tags:
    Environment: "production"
    Team: "platform"
    Application: "web-service"
    CostCenter: "engineering"
```

### Tag limitations

- Azure resource tags have a limit of 50 tags per resource
- Tag names are case-insensitive but tag values are case-sensitive
- Azure reserves some tag names that can't be used

**Configure kubelet settings carefully**: Test kubelet configuration changes in nonproduction environments first

## Next steps

Learn more about [how to configure Node Pool files][nap-nodepools] for node auto provisioning. 

<!-- LINKS - internal -->

[nap-nodepools]: node-autoprovision-node-pools.md
[nap-disruption-policies]: node-autoprovision-disruption.md
[nap-networking-config]: node-autoprovision-networking.md
[network-security-group]: /azure/virtual-network/network-security-groups-overview
