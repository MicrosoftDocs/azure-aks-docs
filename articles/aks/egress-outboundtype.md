---
title: Customize cluster egress with outbound types in Azure Kubernetes Service (AKS)
description: Learn how to define a custom egress route in Azure Kubernetes Service (AKS).
author: davidsmatlak
ms.subservice: aks-networking
ms.custom:
ms.author: davidsmatlak
ms.topic: how-to
ms.date: 04/09/2026

# Customer intent: As a cluster operator, I want to configure custom egress paths for my AKS cluster using user-defined routing, so that I can ensure my egress traffic meets specific security and routing requirements without relying on default load balancer setups.
---

# Customize cluster egress with outbound types in Azure Kubernetes Service (AKS)

[!INCLUDE [vm-default-outbound-access-retirement](includes/vm-default-outbound-access-retirement.md)]

You can customize egress for an AKS cluster to fit specific scenarios. By default, AKS creates a Standard Load Balancer to be set up and used for egress. However, the default setup may not meet the requirements of all scenarios if public IPs are disallowed or extra hops are required for egress.

This article covers the various types of outbound connectivity that are available in AKS clusters.

> [!NOTE]
> You can now update the `outboundType` after cluster creation.

> [!IMPORTANT]
> In nonprivate clusters, API server cluster traffic is routed and processed through the clusters outbound type. To prevent API server traffic from being processed as public traffic, consider using a [private cluster][private-cluster], or check out the [API Server VNet Integration][api-server-vnet-integration] feature.

## Limitations

- Setting `outboundType` requires AKS clusters with a `vm-set-type` of `VirtualMachineScaleSets` and `load-balancer-sku` of `Standard`.

## Outbound types in AKS

You can configure an AKS cluster using the following outbound types: load balancer, NAT gateway, or user-defined routes. The outbound type impacts only the egress traffic of your cluster. For more information, see [setting up ingress controllers](ingress-basic.md).

### <a id="outbound-type-of-loadbalancer"></a>Outbound type: Load Balancer

The load balancer is used for egress through an AKS-assigned public IP. An outbound type of `loadBalancer` supports Kubernetes services of type `loadBalancer`, which expect egress out of the load balancer created by the AKS resource provider.

If `loadBalancer` is set, AKS automatically completes the following configuration:

- A public IP address is created for cluster egress.
- The public IP address is assigned to the load balancer resource.
- Backend pools for the load balancer are set up for agent nodes in the cluster.

![Diagram shows ingress I P and egress I P, where the ingress I P directs traffic to a load balancer, which directs traffic to and from an internal cluster and other traffic to the egress I P, which directs traffic to the Internet, M C R, Azure required services, and the A K S Control Plane.](media/egress-outboundtype/outboundtype-lb.png)

For more information, see [using a standard load balancer in AKS](load-balancer-standard.md).

### <a id="outbound type-of-managedNatGateway-or-userAssignedNatGateway"></a>Outbound type: NAT Gateway

If `managedNATGatewayV2` (Preview), `managedNATGateway` or `userAssignedNATGateway` are selected for `outboundType`, AKS relies on [Azure Networking NAT gateway](/azure/virtual-network/nat-gateway/manage-nat-gateway) for cluster egress.

- Select `managedNatGatewayV2` or `managedNatGateway` when using managed virtual networks. AKS provisions a StandardV2 NAT gateway with `managedNATGatewayV2` and a Standard NAT gateway with `managedNATGateway` and attaches it to the cluster subnet. StandardV2 NAT gateway is recommended because it's zone-redundant by default and offers higher bandwidth and throughput. For information see, [StandardV2 NAT Gateway](/azure/nat-gateway/nat-overview#standardv2-nat-gateway).
- Select `userAssignedNATGateway` when using bring-your-own virtual networking. This option requires that you have a NAT gateway created before cluster creation. Both Standard and StandardV2 NAT Gateways are supported.

> [!IMPORTANT]
> The `managedNATGatewayV2` outbound type is currently in PREVIEW.
> See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability.
> 
For more information, see [using NAT gateway with AKS](nat-gateway.md).

### <a id="outbound-type-of-userdefinedrouting"></a>Outbound type: User-Defined Routes

> [!NOTE]
> The `userDefinedRouting` outbound type is an advanced networking scenario and requires proper network configuration.

If `userDefinedRouting` is set, AKS doesn't automatically configure egress paths. The egress setup is completed by you.

You must deploy the AKS cluster into an existing virtual network with a subnet that is configured. Since you're not using a standard load balancer (SLB) architecture, you must establish explicit egress. This architecture requires explicitly sending egress traffic to an appliance like a firewall, gateway, proxy or to allow NAT to be done by a public IP assigned to the standard load balancer or appliance.

For more information, see [configuring cluster egress via user-defined routing](egress-udr.md).

### Outbound type: none

> [!IMPORTANT]
> The `none` outbound type is only available with [Network Isolated Cluster](concepts-network-isolated.md) and requires careful planning to ensure the cluster operates as expected without unintended dependencies on external services. For fully isolated clusters, see [isolated cluster considerations](concepts-network-isolated.md).

If `none` is set, AKS won't automatically configure egress paths. This option is similar to `userDefinedRouting` but does **not** require a default route as part of validation.

The `none` outbound type is supported in both bring-your-own (BYO) virtual network scenarios and managed VNet scenarios. However, you must ensure that the AKS cluster is deployed into a network environment where explicit egress paths are defined if needed. For BYO VNet scenarios, the cluster must be deployed into an existing virtual network with a subnet that is already configured. Since AKS doesn't create a standard load balancer or any egress infrastructure, you must establish explicit egress paths if needed. Egress options can include routing traffic to a firewall, proxy, gateway, or other custom network configurations.

### Outbound type: block (Preview)

> [!IMPORTANT]
> The `block` outbound type is only available with [Network Isolated Cluster](concepts-network-isolated.md) and requires careful planning to ensure no unintended network dependencies exist. For fully isolated clusters, see [isolated cluster considerations](concepts-network-isolated.md).

If `block` is set, AKS configures network rules to **actively block all egress traffic** from the cluster. This option is useful for highly secure environments where outbound connectivity must be restricted.

When using `block`:

- AKS ensures that no public internet traffic can leave the cluster through network security group (NSG) rules. VNet traffic isn't affected.
- You must explicitly allow any required egress traffic through extra network configurations.

The `block` option provides another level of network isolation but requires careful planning to avoid breaking workloads or dependencies.

## Updating `outboundType` after cluster creation

Changing the outbound type after cluster creation deploys or removes resources as required to put the cluster into the new egress configuration.

The following tables show the supported migration paths between outbound types for managed and BYO virtual networks.

### Supported Migration Paths for Managed VNet

Each row shows whether the outbound type can be migrated to the types listed across the top. "Supported" means migration is possible, while "Not Supported" or "N/A" means it isn't. When using a managed virtual network, migration is only supported between managed outbound types - `loadBalancer`, `managedNATGatewayV2`, and `managedNATGateway`. When using a custom/BYO virtual network, migration is only supported between user-defined outbound types - `loadBalancer`, `userAssignedNATGateway` and `userDefinedRouting`.


| From\|To                 | `loadBalancer` | `managedNATGatewayV2` | `managedNATGateway` | `none`        | `block`       |
|--------------------------|----------------|---------------------|-----------------------|---------------|---------------|
| `loadBalancer`           | N/A            | Supported           | Supported             | Supported     | Supported     |
| `managedNATGatewayV2`    | Not Supported  | N/A                 | Not Supported         | Not Supported | Not Supported |
| `managedNATGateway`      | Not Supported  | Supported           | N/A                   | Supported     | Supported     |
| `none`                   | Supported      | Supported           | Supported             | N/A           | Supported     |
| `block`                  | Supported      | Supported           | Supported             | Supported     | N/A           |

### Supported Migration Paths for BYO VNet

| From\|To                 | `loadBalancer` | `userAssignedNATGateway` | `userDefinedRouting` | `none`        | `block`       |
|--------------------------|----------------|--------------------------|----------------------|---------------|---------------|
| `loadBalancer`           | N/A            | Supported                | Supported            | Supported     | Not Supported |
| `userAssignedNATGateway` | Supported      | N/A                      | Supported            | Supported     | Not Supported |
| `userDefinedRouting`     | Supported      | Supported                | N/A                  | Supported     | Not Supported |
| `none`                   | Supported      | Supported                | Supported            | N/A           | Not Supported |

> [!WARNING]
> Migrating the outbound type to `managedNATGatewayV2` `userAssignedNATGateway` or `userDefinedRouting` will change the outbound public IP addresses of the cluster.
> If [Authorized IP ranges](./api-server-authorized-ip-ranges.md) is enabled, ensure new outbound IP range is appended to authorized IP range.

> [!WARNING]
> Changing the outbound type on a cluster is disruptive to network connectivity and results in a change of the cluster's egress IP address. It involves downtime and impact to existing connections. If any firewall rules are configured to restrict traffic from the cluster, you need to update them to match the new egress IP address.

### Update cluster to use a new outbound type

> [!NOTE]
> You must use a version >= 2.56 of Azure CLI to migrate outbound type. Use `az upgrade` to update to the latest version of Azure CLI.

* Update the outbound configuration of your cluster using the [`az aks update`][az-aks-update] command.

### <a id="update-cluster-from-loadbalancer-to-managednatgateway"></a>Update cluster from `loadbalancer` to `managedNATGatewayV2`

```azurecli-interactive
az aks update --resource-group <resourceGroup> --name <clusterName> --outbound-type managedNATGatewayV2 --nat-gateway-managed-outbound-ipv6-count <number of managed outbound ipv6>
```
> [!IMPORTANT]
> The `managedNATGatewayV2` outbound type is currently in PREVIEW.
> See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability. For more information on to register, see [using NAT gateway with AKS](nat-gateway.md).
> 
### Update cluster from `managedNATGateway` to `loadbalancer`

```azurecli-interactive
az aks update --resource-group <resourceGroup> --name <clusterName> \
--outbound-type loadBalancer \
<--load-balancer-managed-outbound-ip-count <number of managed outbound ip>| --load-balancer-outbound-ips <outbound ip ids> | --load-balancer-outbound-ip-prefixes <outbound ip prefix ids> >
```

> [!WARNING]
> Don't reuse an IP address that is already in use in prior outbound configurations.

### Update cluster from managedNATGateway to userDefinedRouting

- Add route `0.0.0.0/0` default route table. Please see [Customize cluster egress with a user-defined routing table in Azure Kubernetes Service (AKS)](egress-udr.md)

```azurecli-interactive
az aks update --resource-group <resourceGroup> --name <clusterName> --outbound-type userDefinedRouting
```

### Update cluster from loadbalancer to userAssignedNATGateway in BYO vnet scenario

- Associate NAT gateway with subnet where the workload is associated with. Refer to [Create a managed or user-assigned NAT gateway](nat-gateway.md)

```azurecli-interactive
az aks update --resource-group <resourceGroup> --name <clusterName> --outbound-type userAssignedNATGateway
```

## Next steps

- [Configure standard load balancing in an AKS cluster](load-balancer-standard.md)
- [Configure NAT gateway in an AKS cluster](nat-gateway.md)
- [Configure user-defined routing in an AKS cluster](egress-udr.md)
- [NAT gateway documentation](./nat-gateway.md)
- [Azure networking UDR overview](/azure/virtual-network/virtual-networks-udr-overview)
- [Manage route tables](/azure/virtual-network/manage-route-table)

<!-- LINKS - internal -->
[api-server-vnet-integration]: api-server-vnet-integration.md
[az-aks-update]: /cli/azure/aks#az-aks-update
[private-cluster]: private-clusters.md
