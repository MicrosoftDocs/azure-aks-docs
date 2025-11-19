---
title: Concepts - CNI Networking in AKS
description: Learn about CNI networking options in Azure Kubernetes Service (AKS)
ms.topic: concept-article
ms.date: 05/28/2024
author: schaffererin
ms.author: schaffererin

ms.custom: fasttrack-edit
# Customer intent: As a cloud architect, I want to evaluate CNI networking options in Azure Kubernetes Service so that I can choose the most suitable networking model for my cluster's scaling, connectivity, and resource management needs.
---

# Azure Kubernetes Service (AKS) CNI networking overview

Kubernetes uses Container Networking Interface (CNI) plugins to manage networking in Kubernetes clusters. CNI plug-ins are responsible for assigning IP addresses to pods, network routing between pods, Kubernetes Service routing, and more.

Azure Kubernetes Service (AKS) provides multiple CNI plugins that you can use in your clusters, depending on your networking requirements.

## Networking models in AKS

Choosing a CNI plugin for your AKS cluster largely depends on which networking model fits your needs best. Each model has its own advantages and disadvantages that you should consider when planning your AKS cluster.

AKS uses two main networking models:

- **Overlay network**:
  - Conserves IP address space for virtual networks by using logically separate Classless Inter-Domain Routing (CIDR) ranges for pods.
  - Provides maximum cluster scale support.
  - Provides simple management of IP addresses.
  
- **Flat network**:
  - Provides full virtual network connectivity for pods. Pods can be directly reached via their private IP address from connected networks.
  - Requires large, non-fragmented IP address space for virtual networks.

Both networking models have multiple supported options for CNI plugins. The main differences between the models are how pod IP addresses are assigned and how traffic leaves the cluster.

### Overlay networks

Overlay networking is the most common networking model used in Kubernetes. In overlay networks, pods receive an IP address from a private, logically separate CIDR from the Azure virtual network subnet where AKS nodes are deployed. This configuration allows for simpler and often better scalability than the flat network model.

In overlay networks, pods can communicate with each other directly. Traffic that leaves the cluster is Source Network Address Translated (SNAT'd) to the node's IP address. Inbound pod IP traffic is routed through a service, such as a load balancer. The pod IP address is then "hidden" behind the node's IP address. This approach reduces the number of IP addresses required for virtual networks in your clusters.

:::image type="content" source="media/azure-cni-Overlay/azure-cni-overlay.png" alt-text="Diagram that shows two nodes, with three pods each, running in an overlay network. Pod traffic to endpoints outside the cluster is routed via network address translation.":::

For overlay networking, AKS provides the [Azure CNI Overlay][azure-cni-overlay] plugin. We recommend this CNI plugin for most scenarios.

### Flat networks

Unlike an overlay network, a flat network model in AKS assigns IP addresses to pods from a subnet from the same Azure virtual network as the AKS nodes. Traffic that leaves your clusters is not SNAT'd, and the pod IP address is directly exposed to the destination. This approach can be useful for some scenarios, such as when you need to expose pod IP addresses to external services.

:::image type="content" source="media/networking-overview/azure-cni-flat-network-architecture.png" alt-text="Diagram that shows two nodes, with three pods each, running in a flat network model.":::

AKS provides two CNI plugins for flat networking:

- [Azure CNI Pod Subnet][azure-cni-pod-subnet], the recommended CNI plugin for flat networking scenarios.
- [Azure CNI Node Subnet][azure-cni-node-subnet], a legacy CNI model for flat networks. In general, we recommend that you use it only if you *need* a managed virtual network for your cluster.

## Choosing a CNI plugin

When you're choosing a CNI plugin, there are several factors to consider. Each networking model has its own advantages and disadvantages. The best choice for your cluster depends on your specific requirements.

### Use case comparison

| CNI plugin | Networking model | Use case highlights |
|-------------|----------------------|-----------------------|
| Azure CNI Overlay | Overlay | - Best for conserving IPs for virtual networks<br/>- Maximum node count supported by API server plus 250 pods per node<br/>- Simpler configuration<br/> - No direct external pod IP access |
| Azure CNI Pod Subnet | Flat | - Direct external pod access<br/>- Modes for efficient IP usage for virtual networks *or* large cluster scale support (preview) |
| Kubenet (legacy) | Overlay | - Prioritization of IP conservation<br/>- Limited scale<br/>- Manual route management |
| Azure CNI Node Subnet (legacy) | Flat | - Direct external pod access<br/>- Simpler configuration <br/>- Limited scale <br/>- Inefficient use of IPs for virtual networks |

### Feature comparison

| Feature | Azure CNI Overlay | Azure CNI Pod Subnet | Azure CNI Node Subnet (legacy) | Kubenet (legacy) |
|---------|----------------------|--------------------------|--------------------------------------|----------|
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

Depending on the CNI plugin that you use, you can deploy the virtual network resources for your cluster in one of the following ways:

- The Azure platform can automatically create and configure the virtual network resources when you create an AKS cluster, like in Azure CNI Overlay, Azure CNI Node Subnet, and Kubenet.
- You can manually create and configure the virtual network resources and attach to those resources when you create your AKS cluster.

Although capabilities like service endpoints or UDRs are supported, the [support policies for AKS][support-policies] define what changes you can make. For example:

- If you manually create the virtual network resources for an AKS cluster, you're supported when configuring your own UDRs or service endpoints.
- If the Azure platform automatically creates the virtual network resources for your AKS cluster, you can't manually change those AKS-managed resources to configure your own UDRs or service endpoints.

## Prerequisites

When you're planning your network configuration for AKS, keep these requirements and considerations in mind:

- The virtual network for the AKS cluster must allow outbound internet connectivity.
- AKS clusters can't use `169.254.0.0/16`, `172.30.0.0/16`, `172.31.0.0/16`, or `192.0.2.0/24` for address ranges for the Kubernetes service, pods, or cluster virtual networks.
- In bring-your-own-virtual-network scenarios, the cluster identity that the AKS cluster uses must have at least [Network Contributor](/azure/role-based-access-control/built-in-roles#network-contributor) permissions on the subnet within your virtual network. If you want to define a [custom role](/azure/role-based-access-control/custom-roles) instead of using the built-in Network Contributor role, the following permissions are required:
  - `Microsoft.Network/virtualNetworks/subnets/join/action`
  - `Microsoft.Authorization/roleAssignments/write`
  - `Microsoft.Network/virtualNetworks/subnets/read` (needed only if you're defining your own subnets and CIDRs)
- The subnet assigned to the AKS node pool can't be a [delegated subnet][delegated-subnet].
- AKS doesn't apply network security groups (NSGs) to its subnet and doesn't modify any of the NSGs associated with that subnet. If you provide your own subnet and add NSGs associated with that subnet, you must ensure that the security rules in the NSGs allow traffic within the node CIDR range. For more information, see [Azure network security groups overview][aks-network-nsg].

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
[azure-cni-pod-subnet]: concepts-network-azure-cni-pod-subnet.md
[delegated-subnet]: /azure/virtual-network/subnet-delegation-overview
[ip-address-planning]: concepts-network-ip-address-planning.md
[legacy-cni-options]: concepts-network-legacy-cni.md
[support-policies]: support-policies.md
