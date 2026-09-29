---
title: Understand Networking Configurations for Node Auto-Provisioning (NAP) in Azure Kubernetes Service (AKS)
description: Learn about networking configuration requirements and recommendations for AKS clusters using node auto-provisioning (NAP), including supported configurations, subnet behavior, RBAC setup, and CIDR considerations.
ms.topic: overview
ms.custom: devx-track-azurecli, aks-scaling
ms.date: 09/09/2026
ms.author: schaffererin
author: schaffererin
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: As a cluster operator or developer, I want to understand the networking configuration requirements and recommendations for AKS clusters using node auto-provisioning, so that I can ensure optimal performance, security, and scalability for my workloads.
---

# Overview of networking configurations for node auto-provisioning (NAP) in Azure Kubernetes Service (AKS)

This article provides an overview of networking configuration requirements and recommendations for Azure Kubernetes Service (AKS) clusters using node auto-provisioning (NAP). It covers supported configurations, default subnet behavior, role-based access control (RBAC) setup, and classless inter-domain routing (CIDR) considerations.

For an overview of node auto-provisioning in AKS, see [Overview of node auto-provisioning (NAP) in Azure Kubernetes Service (AKS)](./node-auto-provisioning.md).

## Supported networking configurations for NAP

When evaluating networking support for NAP, consider the IP address management (IPAM) mode, network plugin, network data plane, and network policy. The following table describes the options supported by NAP:

| Configuration layer | Option | NAP support |
| --- | --- | --- |
| IPAM | [Azure CNI Overlay](concepts-network-azure-cni-overlay.md) | Supported |
| IPAM | [Azure CNI Node Subnet](configure-azure-cni.md) | Supported |
| IPAM | Azure CNI Pod Subnet with Dynamic IP Allocation | Not supported |
| Network plugin | Kubenet | Not supported |
| Data plane | [Azure CNI Powered by Cilium](azure-cni-powered-by-cilium.md) | Supported with a supported Azure CNI IPAM mode |
| Network policy | Calico | Not supported |

Use Azure CNI Overlay with the Azure CNI Powered by Cilium data plane. Cilium provides advanced networking capabilities and is optimized for performance with NAP.

## Subnet configurations for NAP

Set the optional `vnetSubnetID` field in an [`AKSNodeClass`](./node-auto-provisioning-aksnodeclass.md) resource to configure the custom subnet that Karpenter uses to provision NAP nodes. If you don't specify `vnetSubnetID`, Karpenter uses the default subnet configured during installation, which is typically the subnet specified by the `--vnet-subnet-id` parameter when you create the AKS cluster.

NAP automatically deploys, configures, and manages Karpenter on your AKS cluster and is based on the open-source [Karpenter](https://karpenter.sh) and [AKS Karpenter provider][aks-karpenter-provider] projects.

`AKSNodeClass` resources on your AKS cluster can each specify a different `vnetSubnetID`, which enables mixed subnet configurations across node pools. Node classes that don't specify `vnetSubnetID` use the cluster's default subnet configuration.

## Subnet drift behavior

Karpenter monitors subnet configuration changes and detects drift when the `vnetSubnetID` in an `AKSNodeClass` is modified. Understanding this behavior is critical when managing custom networking configurations.

For clusters that use a custom virtual network, changing `vnetSubnetID` from one valid subnet to another causes existing nodes associated with the `AKSNodeClass` to drift. Karpenter creates replacement nodes in the new subnet and gracefully disrupts the drifted nodes according to the [`NodePool` disruption budgets](./node-auto-provisioning-disruption.md#disruption-budgets).

Before you change `vnetSubnetID`, ensure that the cluster identity has the required permissions on the new subnet and that the subnet has enough available IP addresses for replacement nodes. Pod disruption budgets and `karpenter.sh/do-not-disrupt` annotations can delay voluntary drift replacement.

> [!IMPORTANT]
> AKS-managed virtual networks don't support custom subnets. Use `vnetSubnetID` only with a custom virtual network that you manage.

## AKS cluster CIDR ranges for NAP

When you configure custom networking with `vnetSubnetID`, you need to understand and manage your cluster's CIDR ranges to avoid network conflicts. Unlike traditional AKS node pools that you create through Azure Resource Manager (ARM) templates, Karpenter applies custom resource definitions (CRDs) that provision nodes instantly without the extended validation that ARM provides.

### CIDR considerations for NAP custom subnet configurations

When configuring `vnetSubnetID`, you must:

- **Verify CIDR compatibility**: Ensure custom subnets don't conflict with existing CIDR ranges.
- **Plan IP capacity**: Calculate required IP addresses for expected scaling.
- **Validate connectivity**: Test network routes and security group rules.
- **Monitor usage**: Track subnet utilization and plan for growth.
- **Document configuration**: Maintain records of network design decisions.

### Common CIDR conflicts

Be aware of the following common CIDR conflict scenarios when using custom subnets with NAP:

The following examples show subnet CIDR ranges that conflict with the cluster pod and service CIDRs, along with a configuration that avoids those conflicts. Use these patterns to validate your subnet ranges before you configure `vnetSubnetID`.

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

## RBAC setup for custom subnet configurations

When using custom subnet configurations with NAP, you need to ensure that Karpenter has the necessary permissions to read subnet information and join nodes to the specified subnets. This requires setting up appropriate RBAC permissions for the cluster's managed identity.

The person running the following commands must have permission to create the required role definition and role assignments, such as the [Role Based Access Control Administrator](/azure/role-based-access-control/built-in-roles/privileged#role-based-access-control-administrator) role. Don't grant role-assignment write permissions to the cluster identity unless it needs to create role assignments for another scenario.

Get the principal ID for the cluster's managed identity. Use the command that corresponds to the cluster identity type:

### [System-assigned identity](#tab/system-assigned-identity)

```azurecli-interactive
CLUSTER_IDENTITY=$(az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --query identity.principalId \
  --output tsv)
```

### [User-assigned identity](#tab/user-assigned-identity)

```azurecli-interactive
CLUSTER_IDENTITY=$(az identity show \
  --resource-group $IDENTITY_RESOURCE_GROUP \
  --name $IDENTITY_NAME \
  --query principalId \
  --output tsv)
```

---

There are two main approaches to setting up these permissions: **Assign broad virtual network (VNet) permissions** or **Assign scoped subnet permissions**.

### [Assign broad virtual network (VNet) permissions](#tab/assign-broad-vnet-permissions)

This approach is the most permissive and grants the cluster identity permissions to read and join any subnet within the main VNet and provides network contributor access.

> [!IMPORTANT]
> The [Network Contributor role](/azure/role-based-access-control/built-in-roles/networking#network-contributor) grants `Microsoft.Network/*`, which allows the cluster identity to create, modify, and delete network resources within the assigned VNet scope. Review this access before using the role in production because NAP requires only subnet read and join permissions for this scenario.

#### Benefits and considerations

The following table outlines the trade-offs of assigning the Network Contributor role at the VNet scope.

| Benefits of broad VNet permissions | Considerations for broad VNet permissions |
|----------|----------------|
| • Simplifies permission management. <br> • Eliminates the need to update permissions when adding new subnets. <br> • Works well for single-tenant environments. <br> • Functions when a subscription reaches the maximum number of custom roles. | • Provides broader permissions than strictly necessary. <br> • Might not meet strict security requirements. |

#### Required permissions

To assign broad VNet permissions, grant the cluster's managed identity the following permissions on the VNet:

```azurecli-interactive
# Get your VNet resource ID
VNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VNET_RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME"

# Assign Network Contributor role for subnet read/join operations
az role assignment create \
  --assignee-object-id $CLUSTER_IDENTITY \
  --assignee-principal-type ServicePrincipal \
  --role "Network Contributor" \
  --scope $VNET_ID
```

For a complete example of setting up custom networking and assigning broad VNet permissions, see the [Custom VNet setup - Most permissive RBAC sample script](https://gist.github.com/Bryce-Soghigian/a4259d6224db0c55081718caa7b37268).

### [Assign scoped subnet permissions](#tab/assign-scoped-subnet-permissions)

This approach grants permissions on a per-subnet basis, providing more granular control over which subnets the cluster can access.

#### Benefits

Assigning scoped subnet permissions offers the following benefits:

- Follows principle of least privilege.
- Provides granular access control.
- Ensures better compliance with security policies.

#### Required permissions

For each subnet you want to use with Karpenter, you need to assign the following specific permissions:

```azurecli-interactive
# For each subnet, assign specific subnet permissions
SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VNET_RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$SUBNET_NAME"

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
  --assignee-object-id $CLUSTER_IDENTITY \
  --assignee-principal-type ServicePrincipal \
  --role "Karpenter Subnet Access" \
  --scope $SUBNET_ID
```

For a complete example of setting up custom networking and assigning scoped subnet permissions, see the [Scoped subnet permissions sample script](https://gist.github.com/Bryce-Soghigian/fc3de3a796b20dbed8fe5d2ca0c85dd4).

---

## Example custom subnet configurations

The following example shows how to configure a custom subnet for NAP nodes using the `vnetSubnetID` field in an `AKSNodeClass` resource:

Set the `spec.vnetSubnetID` field to the full Azure resource ID of the target subnet by using the format `/subscriptions/{subscriptionId}/resourceGroups/{resourceGroup}/providers/Microsoft.Network/virtualNetworks/{vnetName}/subnets/{subnetName}`.

```yaml
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: custom-networking
spec:
  vnetSubnetID: "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/$VNET_RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$SUBNET_NAME"
```

The following example shows how to use multiple node classes with different subnet configurations:

```yaml
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: frontend-nodes
spec:
  vnetSubnetID: "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/$VNET_RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$FRONTEND_SUBNET_NAME"
---
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: backend-nodes
spec:
  vnetSubnetID: "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/$VNET_RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$BACKEND_SUBNET_NAME"
```

## Bring your own CNI (BYO CNI) support policy

Karpenter for Azure allows bring your own Container Network Interface (BYO CNI) configurations, and it follows the same support policy as AKS. BYO CNI doesn't make a configuration that NAP lists as unsupported, such as kubenet or Calico, supported. When you use a custom CNI, troubleshooting support related to networking is out of scope for any service-level agreements or warranties.

### Support scope details

The following outlines what is and isn't supported when using BYO CNI with Karpenter:

- **Supported**: Karpenter-specific functionality and integration issues when using bring-your-own (BYO) CNI configurations.
- **Not supported**: CNI-specific networking issues, configuration problems, or troubleshooting when using third-party CNI plugins.

## Next steps

For more information on node auto-provisioning in AKS, see the following articles:

- [Use node auto-provisioning in a custom virtual network](./node-auto-provisioning-custom-vnet.md)
- [Configure node pools for node auto-provisioning on AKS](./node-auto-provisioning-node-pools.md)
- [Configure disruption policies for node auto-provisioning on AKS](./node-auto-provisioning-disruption.md)

<!-- LINKS -->
[aks-karpenter-provider]: https://github.com/Azure/karpenter-provider-azure
