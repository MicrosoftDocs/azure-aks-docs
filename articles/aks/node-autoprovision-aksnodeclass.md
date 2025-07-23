---
title: Node autoprovisioning AKSNodeClass configuration
description: Learn how to configure Azure-specific settings for Azure Kubernetes Service (AKS) node autoprovisioning using AKSNodeClass.
ms.topic: how-to
ms.custom: devx-track-azurecli
ms.date: 06/13/2024
ms.author: bsoghigian
author: bsoghigian
---

# Node autoprovisioning AKSNodeClass configuration

This article explains how to configure Azure-specific settings for Azure Kubernetes Service (AKS) node autoprovisioning using AKSNodeClass resources.

## AKSNodeClass overview

AKSNodeClass enables configuration of Azure-specific settings for node autoprovisioning. Each NodePool must reference an AKSNodeClass using `spec.template.spec.nodeClassRef`. Multiple NodePools may point to the same AKSNodeClass, allowing you to share common Azure configurations across different node pools.

## Basic AKSNodeClass configuration

Here's a basic example showing how to configure an AKSNodeClass:

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
        name: default
---
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: default
spec:
  # Optional, configures the VM image family to use
  imageFamily: Ubuntu2204

  # Optional, configures the VNET subnet to use for node network interfaces
  vnetSubnetID: "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/my-rg/providers/Microsoft.Network/virtualNetworks/my-vnet/subnets/my-subnet"

  # Optional, configures the OS disk size in GB
  osDiskSizeGB: 128

  # Optional, configures the maximum number of pods per node
  maxPods: 30

  # Optional, propagates tags to underlying Azure resources
  tags:
    team: team-a
    app: team-a-app
```

## Image family configuration

The `imageFamily` field dictates the default virtual machine (VM) image and bootstrapping logic for nodes provisioned through this AKSNodeClass. If not specified, the default is `Ubuntu2204`. GPUs are supported with both image families on compatible VM sizes.

### Supported image families

- **`Ubuntu2204`** - Ubuntu 22.04 Long Term Support (LTS) is the default Linux distribution for AKS nodes
- **`AzureLinux`** - Azure Linux is Microsoft's alternative Linux distribution for AKS workloads

Example configuration:

```yaml
spec:
  imageFamily: AzureLinux
```

## Virtual network subnet configuration

The `vnetSubnetID` field specifies which Azure Virtual Network subnet should be used for provisioning node network interfaces. This field is optional; if not specified, Karpenter uses the default subnet configured in the Karpenter installation.

### Subnet ID format

The subnet ID must be in the full Azure Resource Manager format:

```yaml
spec:
  vnetSubnetID: "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Network/virtualNetworks/{vnet-name}/subnets/{subnet-name}"
```

### Default subnet behavior

When `vnetSubnetID` isn't specified, Karpenter automatically uses the default subnet configured during Karpenter installation. This fallback mechanism works as follows:

- **With vnetSubnetID specified**: Karpenter provisions nodes in the specified custom subnet
- **Without vnetSubnetID specified**: Karpenter provisions nodes in the cluster's default subnet

### Subnet requirements

The specified subnet must:
- Be in the same region as your AKS cluster
- Have sufficient IP addresses available for node provisioning
- Allow cluster communication through appropriate Network Security Group rules

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

## Maximum pods configuration

The `maxPods` field specifies the maximum number of pods that can be scheduled on a node. This setting affects both cluster density and network configuration.

### Default behavior

The default behavior depends on the network plugin configuration:
- **Azure CNI with standard networking**: Default is 30 pods per node
- **Azure CNI with overlay networking**: Default is 250 pods per node  
- **Default**: Default is 110 pods per node

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

- [Configure node pools](node-autoprovision-node-pools.md)
- [Configure disruption policies](node-autoprovision-disruption.md)
- [Learn about networking configuration](node-autoprovision-networking.md)
