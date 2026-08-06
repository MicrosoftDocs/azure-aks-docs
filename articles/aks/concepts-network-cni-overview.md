---
title: Concepts - CNI Networking in Azure Kubernetes Service (AKS)
description: Learn about CNI networking in AKS, including overlay and flat network models, IP address management (IPAM) options, and how to choose the right networking model for your cluster.
ms.topic: overview
ms.date: 07/10/2026
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.custom: fasttrack-edit
# Customer intent: As a cloud architect, I want to evaluate CNI networking options in Azure Kubernetes Service so that I can choose the most suitable networking model for my cluster's scaling, connectivity, and resource management needs.
---

# Azure Kubernetes Service (AKS) CNI networking overview

Kubernetes uses Container Networking Interface (CNI) plugins to manage networking in Kubernetes clusters. CNI plugins handle assigning IP addresses to pods, routing network traffic between pods, routing Kubernetes service traffic, and more.

Azure Kubernetes Service (AKS) provides multiple CNI networking configurations that you can use in your clusters, depending on your networking requirements. When you plan pod networking, you choose an IP address management (IPAM) option and a routing and transport technology for the network data plane.

## Networking models in AKS

Choosing an IPAM option for your AKS cluster largely depends on which networking model fits your needs best. Each model has its own advantages and disadvantages that you should consider when planning your AKS cluster.

AKS uses two main networking models:

- **Overlay network**:
  - Conserves IP address space for virtual networks (VNets) by using logically separate Classless Inter-Domain Routing (CIDR) ranges for pods.
  - Provides maximum cluster scale support.
  - Provides simple management of IP addresses.
  
- **Flat network**:
  - Provides full VNet connectivity for pods. Pods can be directly reached via their private IP address from connected networks.
  - Requires large, non-fragmented IP address space for VNets.

Both networking models support multiple IPAM options. The main differences between the models are how you assign pod IP addresses and how traffic leaves the cluster.

For Azure CNI, the IPAM option is separate from the network data plane. You can use the Azure CNI Powered by Cilium data plane with Azure CNI Overlay, Azure CNI Pod Subnet, or Azure CNI Node Subnet. For more information about IPAM and data-plane options, see [Plan pod networking for AKS][plan-pod-networking].

### Overlay networks

Overlay networking in AKS assigns pod IP addresses from a separate pod CIDR that's distinct from the node subnet in the VNet. This configuration allows for simpler and often better scalability than the flat network model.

In overlay networks, pods can communicate with each other directly. Traffic that leaves the cluster is Source Network Address Translated (SNAT'd) to the node's IP address. Inbound pod IP traffic is routed through a service, such as a load balancer. The pod IP address is then "hidden" behind the node's IP address. This approach reduces the number of IP addresses required for virtual networks in your clusters.

:::image type="content" source="media/azure-cni-Overlay/azure-cni-overlay.png" alt-text="Diagram that shows two nodes, with three pods each, running in an overlay network. Pod traffic to endpoints outside the cluster is routed via network address translation.":::

For overlay networking, AKS provides [Azure CNI Overlay][azure-cni-overlay]. Use this IPAM option for most scenarios.

### Flat networks

Unlike an overlay network, a flat network model in AKS assigns IP addresses to pods from a subnet in the same Azure virtual network as the AKS nodes. For private network traffic, the source IP address that a destination sees depends on the IPAM option. Azure CNI Pod Subnet preserves the pod IP address across connected virtual networks. With Azure CNI Node Subnet, destinations in the cluster virtual network see the pod IP address, but destinations outside the cluster virtual network see the node IP address. When internet egress is enabled, the cluster's [configured outbound method][egress-outbound-type] determines the public source IP address that internet destinations see.

:::image type="content" source="media/networking-overview/azure-cni-flat-network-architecture.png" alt-text="Diagram that shows two nodes, with three pods each, running in a flat network model.":::

AKS provides two Azure CNI IPAM options for flat networking:

- [Azure CNI Pod Subnet][azure-cni-pod-subnet], the recommended IPAM option for flat networking scenarios.
- [Azure CNI Node Subnet][azure-cni-node-subnet], a legacy CNI model for flat networks. In general, we recommend that you use it only if you need a managed virtual network for your cluster.

## Choose an IPAM option for AKS

When choosing an IPAM option, consider several factors. Each networking model has its own advantages and disadvantages. The best choice for your cluster depends on your specific requirements.

### Use case comparison

| IPAM option | Networking model | Use case highlights |
| ---------- | ---------------- | ------------------- |
| Azure CNI Overlay | Overlay | • Best for conserving IPs for virtual networks <br> • Maximum node count supported by API server plus 250 pods per node <br> • Simpler configuration <br> • No direct external pod IP access |
| Azure CNI Pod Subnet | Flat | • Direct external pod access <br> • Modes for efficient IP usage for virtual networks _or_ large cluster scale support (preview) |
| Kubenet (legacy) | Overlay | • Retires on March 31, 2028; [migrate to Azure CNI Overlay][update-azure-cni] before the retirement date <br> • Prioritization of IP conservation <br> • Limited scale <br> • Manual route management |
| Azure CNI Node Subnet (legacy) | Flat | • Direct external pod access <br> • Simpler configuration <br> • Limited scale <br> • Inefficient use of IPs for virtual networks |

### Feature comparison

| Feature | Azure CNI Overlay | Azure CNI Pod Subnet | Azure CNI Node Subnet (legacy) | Kubenet (legacy) |
| ------- | ----------------- | -------------------- | ------------------------------ | ---------------- |
| Deployment of a cluster in an existing or new virtual network | Supported | Supported | Supported | Supported with manual user-defined routes (UDRs) |
| Connectivity between pod and virtual machine (VM), with the VM in the same virtual network or a peered virtual network | Pod initiated | Both ways | Both ways | Pod initiated |
| On-premises access via virtual private network (VPN) and Azure ExpressRoute | Pod initiated | Both ways | Both ways | Pod initiated |
| Access to service endpoints | Supported | Supported | Supported | Supported |
| Exposure of services via load balancer | Supported | Supported | Supported | Supported |
| Exposure of services via Azure Application Gateway ingress controller | Supported | Supported | Supported | Supported |
| Exposure of services via Application Gateway for Containers | Supported | Supported | Supported | Not Supported |
| Windows node pools | Supported | Supported | Supported | Not supported |
| Default Azure DNS and private zones | Supported | Supported | Supported | Supported |
| Sharing of virtual network subnets across multiple clusters | Supported | Supported | Supported | Not supported |

### Support scope between network models

Depending on the IPAM option that you use, you can deploy the virtual network resources for your cluster in one of the following ways:

- The Azure platform can automatically create and configure the virtual network resources when you create an AKS cluster.
- You can manually create and configure the virtual network resources and attach to those resources when you create your AKS cluster.

Although capabilities like service endpoints or UDRs are supported, the [support policies for AKS][support-policies] define what changes you can make. For example:

- If you manually create the virtual network resources for an AKS cluster, you're supported when configuring your own UDRs or service endpoints.
- If the Azure platform automatically creates the virtual network resources for your AKS cluster, you can't manually change those AKS-managed resources to configure your own UDRs or service endpoints.

## AKS CNI networking prerequisites

When you're planning your network configuration for AKS, keep these requirements and considerations in mind:

- Unless you use a [network isolated cluster][network-isolated-cluster], the virtual network for the AKS cluster must allow outbound internet connectivity to required endpoints. Network isolated clusters can bootstrap without outbound internet connectivity.
- AKS address ranges have the following restrictions:

    | Reserved CIDR range | Applies to | Condition |
    | --- | --- | --- |
    | `169.254.0.0/16` | Kubernetes service, pod, and cluster virtual network address ranges | All AKS clusters |
    | `192.0.2.0/24` | Kubernetes service, pod, and cluster virtual network address ranges | All AKS clusters |
    | `172.30.0.0/16` | Kubernetes service, pod, and cluster virtual network address ranges | All AKS clusters |
    | `172.31.0.0/16` | Kubernetes service, pod, and cluster virtual network address ranges | All AKS clusters |

    AKS rejects pod CIDRs that overlap a reserved range during cluster creation or update. For example, `172.16.0.0/12` isn't valid because the range includes `172.30.0.0/16` and `172.31.0.0/16`.

- In scenarios where you bring your own virtual network, the cluster identity that the AKS cluster uses must have at least [Network Contributor](/azure/role-based-access-control/built-in-roles#network-contributor) permissions on the subnet within your virtual network.
- If you define a [custom role](/azure/role-based-access-control/custom-roles) instead of using the built-in Network Contributor role, include the following permissions:

    | Permission | When required |
    | --- | --- |
    | `Microsoft.Network/virtualNetworks/subnets/join/action` | Always when using a custom role |
    | `Microsoft.Authorization/roleAssignments/write` | Always when using a custom role |
    | `Microsoft.Network/virtualNetworks/subnets/read` | Only when defining your own subnets and CIDRs |

- The subnet assigned to the AKS node pool can't be a [delegated subnet][delegated-subnet].
- AKS doesn't apply network security groups (NSGs) to its subnet and doesn't modify any of the NSGs associated with that subnet. If you provide your own subnet and add NSGs associated with that subnet, you must ensure that the security rules in the NSGs allow traffic within the node CIDR range. With Azure CNI Overlay, if an NSG deny rule affects pod CIDR traffic, you must also allow traffic from the node CIDR to the pod CIDR and from the pod CIDR to the pod CIDR on all ports and protocols. For more information, see [Network security groups with Azure CNI Overlay][azure-cni-overlay-nsg].
- Container Network Service (CNS) is a node local service within Azure Kubernetes Service CNI networking which allocates, tracks and programs networking for pods. This component sends telemetry (metrics and logs) by default out of the cluster to a Microsoft managed Application Insights endpoint to enable faster troubleshooting of any pod networking IP address assignment issues.

## Related content

- [Azure CNI Overlay][azure-cni-overlay]
- [Azure CNI Pod Subnet][azure-cni-pod-subnet]
- [Legacy CNI options][legacy-cni-options]
- [IP address planning for your clusters][ip-address-planning]

<!-- LINKS - External -->

<!-- LINKS - Internal -->
[aks-network-nsg]: /azure/virtual-network/network-security-groups-overview
[azure-cni-node-subnet]: concepts-network-legacy-cni.md#azure-cni-node-subnet
[azure-cni-overlay]: concepts-network-azure-cni-overlay.md
[azure-cni-overlay-nsg]: concepts-network-azure-cni-overlay.md#network-security-groups
[azure-cni-pod-subnet]: concepts-network-azure-cni-pod-subnet.md
[delegated-subnet]: /azure/virtual-network/subnet-delegation-overview
[egress-outbound-type]: egress-outboundtype.md
[ip-address-planning]: concepts-network-ip-address-planning.md
[legacy-cni-options]: concepts-network-legacy-cni.md
[network-isolated-cluster]: concepts-network-isolated.md
[plan-pod-networking]: plan-pod-networking.md
[support-policies]: support-policies.md
[update-azure-cni]: update-azure-cni.md
