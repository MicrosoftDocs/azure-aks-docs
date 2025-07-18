---
title: Node autoprovisioning networking configuration
description: Learn about the networking configuration requirements and recommendations for Azure Kubernetes Service (AKS) node autoprovisioning.
ms.topic: conceptual
ms.custom: devx-track-azurecli
ms.date: 06/13/2024
ms.author: bsoghigian
author: bsoghigian
---

# Node autoprovisioning networking configuration

This article covers the networking configuration requirements and recommendations for Azure Kubernetes Service (AKS) node autoprovisioning (NAP).

## Supported networking configurations

The recommended network configurations for clusters enabled with Node Autoprovisioning are the following:

- [Azure CNI Overlay](concepts-network-azure-cni-overlay.md) with [Powered by Cilium](azure-cni-powered-by-cilium.md)
- [Azure CNI Overlay](concepts-network-azure-cni-overlay.md)
- [Azure CNI](configure-azure-cni.md) with [Powered by Cilium](azure-cni-powered-by-cilium.md)
- [Azure CNI](configure-azure-cni.md)

## Recommended network policy engine

Our recommended network policy engine is [Cilium](azure-cni-powered-by-cilium.md). Cilium provides advanced networking capabilities and is optimized for performance with node autoprovisioning.

## Unsupported networking configurations

The following networking configurations are currently *not* supported with node autoprovisioning:

- **Calico network policy** - Not compatible with NAP
- **Dynamic IP Allocation** - Not supported in preview
- **Static Allocation of CIDR blocks** - Not supported in preview

## Network configuration examples

### Azure CNI Overlay with Cilium (Recommended)

When creating a cluster with node autoprovisioning, use the following network configuration:

```azurecli-interactive
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --node-provisioning-mode Auto \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --network-dataplane cilium \
    --generate-ssh-keys
```

### ARM Template configuration

For ARM template deployments, use the following network profile configuration:

```json
"networkProfile": {
    "networkPlugin": "azure",
    "networkPluginMode": "overlay",
    "networkPolicy": "cilium",
    "networkDataplane": "cilium",
    "loadBalancerSku": "Standard"
}
```

## Network requirements considerations

When planning your networking configuration with node autoprovisioning:

1. **Load Balancer SKU**: Standard Load Balancer is required
2. **Network Security Groups**: Ensure proper NSG rules are configured for your workloads
3. **Private Clusters**: Currently not supported with NAP
4. **Bring Your Own DNS**: Not supported with private clusters in NAP

## Next steps

- [Enable node autoprovisioning](node-autoprovision.md#enable-node-autoprovisioning)
- [Configure node pools](node-autoprovision-node-pools.md)
- [Learn about Azure CNI Overlay](concepts-network-azure-cni-overlay.md)
- [Learn about Cilium networking](azure-cni-powered-by-cilium.md)