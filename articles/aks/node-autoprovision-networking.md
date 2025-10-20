---
title: Understand Networking Configurations for Node Auto-Provisioning (NAP) in Azure Kubernetes Service (AKS)
description: Learn about networking configuration requirements and recommendations for AKS clusters using node auto-provisioning (NAP), including supported configurations, subnet behavior, RBAC setup, and CIDR considerations.
ms.topic: overview
ms.custom: devx-track-azurecli
ms.date: 06/13/2024
ms.author: bsoghigian
author: bsoghigian
ms.service: azure-kubernetes-service
# Customer intent: As a cluster operator or developer, I want to understand the networking configuration requirements and recommendations for AKS clusters using node auto-provisioning, so that I can ensure optimal performance, security, and scalability for my workloads.
---

# Overview of networking configurations for node auto-provisioning (NAP) in Azure Kubernetes Service (AKS)

This article provides an overview of networking configuration requirements and recommendations for Azure Kubernetes Service (AKS) clusters using node auto-provisioning (NAP). It covers supported configurations, default subnet behavior, role-based access control (RBAC) setup, and classless inter-domain routing (CIDR) considerations.

## Supported networking configurations for NAP

NAP supports the following networking configurations:

- [Azure CNI Overlay](concepts-network-azure-cni-overlay.md) with [Powered by Cilium](azure-cni-powered-by-cilium.md)
- [Azure CNI Overlay](concepts-network-azure-cni-overlay.md)
- [Azure CNI](configure-azure-cni.md) with [Cilium](azure-cni-powered-by-cilium.md)
- [Azure CNI](configure-azure-cni.md)

We recommend using Azure CNI with [Cilium](azure-cni-powered-by-cilium.md). Cilium provides advanced networking capabilities and is optimized for performance with NAP.

### Unsupported networking configurations

NAP doesn't support the following networking configurations:

- Calico network policy
- Dynamic IP allocation
- Static allocation of classless inter-domain routing (CIDR) blocks

## Default subnet behavior

The `vnetSubnetID` field in AKSNodeClass is optional. When not specified, Karpenter automatically uses the default subnet configured during Karpenter installation via the `--vnet-subnet-id` CLI parameter or `VNET_SUBNET_ID` environment variable.

This default subnet is typically the same subnet specified during AKS cluster creation with the `--vnet-subnet-id` flag in the `az aks create` command. This fallback mechanism works as follows:

- **With vnetSubnetID specified**: Karpenter provisions nodes in the specified custom subnet
- **Without vnetSubnetID specified**: Karpenter provisions nodes in the cluster's default subnet (from `--vnet-subnet-id`)

This approach allows you to have a mix of NodeClasses - some using custom subnets for specific workloads, and others using the cluster's default subnet configuration.

## VNet subnet configuration

You can configure custom subnet identifiers in your AKSNodeClass using the `vnetSubnetID` field:

```yaml
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: custom-networking
spec:
  vnetSubnetID: "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/my-aks-rg/providers/Microsoft.Network/virtualNetworks/my-aks-vnet/subnets/custom-subnet"
```

## RBAC configuration

Custom subnet configurations require Karpenter to have appropriate permissions to read subnet information and join nodes to the specified subnets. There are two recommended approaches for configuring these permissions.

### Approach A: Broad VNet permissions

This approach grants the cluster identity permissions to read and join any subnet within the main VNet and provides network contributor access. It's permissive. Investigate the "Network Contributor" role before applying this approach to your production cluster. 

#### Required permissions

Assign the following roles to your cluster identity at the VNet scope:

```bash
# Get your cluster's managed identity
CLUSTER_IDENTITY=$(az aks show --resource-group <cluster-rg> --name <cluster-name> --query identity.principalId -o tsv)

# Get your VNet resource ID
VNET_ID="/subscriptions/<subscription-id>/resourceGroups/<vnet-rg>/providers/Microsoft.Network/virtualNetworks/<vnet-name>"

# Assign Network Contributor role for subnet read/join operations
az role assignment create \
  --assignee $CLUSTER_IDENTITY \
  --role "Network Contributor" \
  --scope $VNET_ID
```

#### Benefits
- Simplifies permission management
- Eliminates the need to update permissions when adding new subnets
- Works well for single-tenant environments
- Functions when a subscription reaches the maximum number of custom roles

#### Example script
For a complete example of setting up custom networking with Approach A permissions, see this [sample setup script](https://gist.github.com/Bryce-Soghigian/a4259d6224db0c55081718caa7b37268).

#### Considerations
- Provides broader permissions than strictly necessary
- May not meet strict security requirements

### Approach B: Scoped subnet permissions

This approach grants permissions on a per-subnet basis, providing more granular control over which subnets the cluster can access.

#### Required permissions

For each subnet you want to use with Karpenter, assign the following specific permissions:

```bash
# Get your cluster's managed identity
CLUSTER_IDENTITY=$(az aks show --resource-group <cluster-rg> --name <cluster-name> --query identity.principalId -o tsv)

# For each subnet, assign specific subnet permissions
SUBNET_ID="/subscriptions/<subscription-id>/resourceGroups/<vnet-rg>/providers/Microsoft.Network/virtualNetworks/<vnet-name>/subnets/<subnet-name>"

# Create custom role definition for subnet access
cat > subnet-access-role.json << EOF
{
  "Name": "Karpenter Subnet Access",
  "IsCustom": true,
  "Description": "Allows reading subnet information and joining VMs to subnets",
  "Actions": [
    "Microsoft.Network/virtualNetworks/subnets/read",
    "Microsoft.Network/virtualNetworks/subnets/join/action"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/<subscription-id>"
  ]
}
EOF

# Create the custom role (only needed once per subscription)
az role definition create --role-definition subnet-access-role.json

# Assign the custom role to each subnet
az role assignment create \
  --assignee $CLUSTER_IDENTITY \
  --role "Karpenter Subnet Access" \
  --scope $SUBNET_ID
```

#### Alternative: Use built-in roles

If you prefer using built-in roles, you can assign these specific permissions individually:

```bash
# Assign Network Reader role for subnet read access
az role assignment create \
  --assignee $CLUSTER_IDENTITY \
  --role "Network Contributor" \
  --scope $SUBNET_ID \
  --condition "((!(ActionMatches{'Microsoft.Network/virtualNetworks/subnets/write'})) AND (!(ActionMatches{'Microsoft.Network/virtualNetworks/subnets/delete'})))"
```

> **Note**: The condition parameter limits the Network Contributor role to only read and join operations on subnets, excluding write and delete permissions.

#### Benefits
- Follows principle of least privilege
- Provides granular access control
- Ensures better compliance with security policies

#### Example script
For a complete example of setting up custom networking with Approach B permissions, see this [scoped subnet permissions script](https://gist.github.com/Bryce-Soghigian/fc3de3a796b20dbed8fe5d2ca0c85dd4).

## Example AKSNodeClass configurations

### Single custom subnet

```yaml
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: dedicated-workload
spec:
  vnetSubnetID: "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/my-aks-rg/providers/Microsoft.Network/virtualNetworks/my-aks-vnet/subnets/custom-subnet"
```

### Multiple NodeClasses for different subnets

```yaml
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: frontend-nodes
spec:
  vnetSubnetID: "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/my-aks-rg/providers/Microsoft.Network/virtualNetworks/my-aks-vnet/subnets/custom-subnet"
---
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: backend-nodes
spec:
  vnetSubnetID: "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/my-aks-rg/providers/Microsoft.Network/virtualNetworks/my-aks-vnet/subnets/custom-subnet2"
```
## Subnet drift behavior

Karpenter monitors subnet configuration changes and detects drift when the `vnetSubnetID` in an AKSNodeClass is modified. Understanding this behavior is critical when managing custom networking configurations.

### Unsupported configuration path

**Modifying `vnetSubnetID` from one valid subnet to another valid subnet is NOT a supported operation.** This field is mutable solely to provide an escape hatch for correcting invalid or malformed subnet identifiers (IDs) during initial configuration.

### Supported use case: Fix invalid subnet IDs

The `vnetSubnetID` field can be modified only in these scenarios:
- Correcting a malformed subnet ID that prevents node provisioning
- Fixing an invalid subnet reference that causes configuration errors
- Updating a subnet identifier that points to a nonexistent or inaccessible subnet

If you are an advanced networking user and know what you are doing, you can leverage the vnetSubnetID drift feature to migrate from an old subnet to a new subnet. Just know its best effort support

**Support Policy**: Microsoft doesn't provide support for issues arising from subnet to subnet migrations via `vnetSubnetID` modifications. Support tickets related to such operations are declined.

## Understand AKS cluster Classless Inter-Domain Routing (CIDR) ranges

When configuring custom networking with `vnetSubnetID`, you're responsible for understanding and managing your cluster's Classless Inter-Domain Routing (CIDR) ranges to avoid network conflicts. Unlike traditional AKS NodePools created through ARM templates, Karpenter applies custom resource definitions (CRDs) that provision nodes instantly without the extended validation that ARM provides.

### Customer responsibilities

When configuring `vnetSubnetID`, you must:

1. **Verify CIDR Compatibility**: Ensure custom subnets don't conflict with existing cluster Classless Inter-Domain Routing (CIDR) ranges
2. **Plan IP Capacity**: Calculate required IP addresses for expected scaling
3. **Validate Connectivity**: Test network routes and security group rules
4. **Monitor Usage**: Track subnet utilization and plan for growth
5. **Document Configuration**: Maintain records of network design decisions

### Common CIDR conflicts

Be aware of these potential conflicts:

```bash
# Example conflict scenarios:
# Cluster Pod CIDR: 10.244.0.0/16  
# Custom Subnet:   10.244.1.0/24  ❌ CONFLICT

# Service CIDR:    10.0.0.0/16
# Custom Subnet:   10.0.10.0/24   ❌ CONFLICT

# Safe configuration:
# Cluster Pod CIDR: 10.244.0.0/16
# Service CIDR:     10.0.0.0/16  
# Custom Subnet:    10.1.0.0/24   ✅ NO CONFLICT
```
You're responsible for configuring the vnetSubnetID for the node class. ARM validation doesn't verify that the subnet has enough IP addresses and isn't overlapping with any other CIDR ranges.

## Bring your own CNI (BYO CNI) support policy

Karpenter for Azure allows bring-your-own Container Network Interface (CNI) configurations, following the same support policy as Azure Kubernetes Service (AKS). This means that when using a custom CNI, troubleshooting support related to networking is out of scope of any service-level agreement or warranty. 

### Support scope

**Supported**: Karpenter-specific functionality and integration issues when using bring-your-own (BYO) CNI configurations.

**Not Supported**: CNI-specific networking issues, configuration problems, or troubleshooting when using third-party CNI plugins.

### Support policy details

- **Bring-your-own (BYO) CNI is allowed** for use with Karpenter, but follows AKS BYO CNI support boundaries
- **Networking issues** related to the CNI plugin itself are outside the scope of Karpenter support
- **Karpenter-specific problems** (node provisioning, scaling, lifecycle management) are supported regardless of CNI choice
- **CNI configuration and troubleshooting** should be directed to the respective CNI vendor or community

### When to contact support for BYO CNI

**Contact Karpenter Support for**:
- Node provisioning failures with bring-your-own (BYO) CNI
- Karpenter controller issues when using custom CNI
- Integration problems between Karpenter and CNI plugins
- AKSNodeClass configuration issues

**Do NOT contact Karpenter Support for**:
- CNI plugin installation or configuration problems
- Network connectivity issues specific to the CNI
- CNI plugin performance or feature issues
- Troubleshooting CNI-specific networking behavior

## Next steps

- [Enable node autoprovisioning](node-autoprovision.md#enable-node-autoprovisioning)
- [Configure node pools](node-autoprovision-node-pools.md)
- [Learn about Azure CNI Overlay](concepts-network-azure-cni-overlay.md)
- [Learn about Cilium networking](azure-cni-powered-by-cilium.md)

