---
title: Concepts - AKS Legacy Container Networking Interfaces (CNI)
description: Learn about legacy CNI networking options in Azure Kubernetes Service (AKS)
ms.topic: conceptual
ms.date: 05/29/2024
author: schaffererin
ms.author: schaffererin

ms.custom: fasttrack-edit
---

# AKS Legacy Container Networking Interfaces (CNI)

In Azure Kubernetes Service (AKS), while [Azure CNI Overlay][azure-cni-overlay] and [Azure CNI Pod Subnet][azure-cni-pod-subnet] are recommended for most scenarios, Azure CNI Node Subnet is still available and supported. The legacy model offers a different approach to pod IP address management and networking. This article provides an overview of the legacy networking option, detailing its prerequisites, deployment parameters, and key characteristics to help you understand their roles and how they can be used effectively within your AKS clusters.

## Prerequisites

The following prerequisites are required for Azure CNI Node Subnet:

* The virtual network for the AKS cluster must allow outbound internet connectivity.
* AKS clusters can't use `169.254.0.0/16`, `172.30.0.0/16`, `172.31.0.0/16`, or `192.0.2.0/24` for the Kubernetes service address range, pod address range, or cluster virtual network address range.
* The cluster identity used by the AKS cluster must have at least [Network Contributor](/azure/role-based-access-control/built-in-roles#network-contributor) permissions on the subnet within the virtual network. If you want to define a [custom role](/azure/role-based-access-control/custom-roles) instead of using the built-in Network Contributor role, the following permissions are required:

  - `Microsoft.Network/virtualNetworks/subnets/join/action`
  - `Microsoft.Network/virtualNetworks/subnets/read`
  - `Microsoft.Authorization/roleAssignments/write`

* The subnet assigned to the AKS node pool can't be a [delegated subnet](/azure/virtual-network/subnet-delegation-overview).
- AKS doesn't apply Network Security Groups (NSGs) to its subnet and doesn't modify any of the NSGs associated with that subnet. If you provide your own subnet and add NSGs associated with that subnet, make sure the security rules in the NSGs allow traffic within the node CIDR range. For more information, see [Network security groups][aks-network-nsg].

## Azure CNI Node Subnet

With [Azure Container Networking Interface (CNI)][cni-networking], every pod gets an IP address from the subnet and can be accessed directly. Systems in the same virtual network as the AKS cluster see the pod IP as the source address for any traffic from the pod. Systems outside the AKS cluster virtual network see the node IP as the source address for any traffic from the pod. These IP addresses must be unique across your network space and must be planned in advance. Each node has a configuration parameter for the maximum number of pods that it supports. The equivalent number of IP addresses per node are then reserved up front for that node. This approach requires more planning, and often leads to IP address exhaustion or the need to rebuild clusters in a larger subnet as your application demands grow.

With Azure CNI Node Subnet, each pod receives an IP address in the IP subnet and can communicate directly with other pods and services. Your clusters can be as large as the IP address range you specify. However, you must plan the IP address range in advance, and all the IP addresses are consumed by the AKS nodes based on the maximum number of pods they can support. Advanced network features and scenarios such as [virtual nodes][virtual-nodes] or Network Policies (either Azure or Calico) are supported with Azure CNI.  

### Deployment parameters

When you create an AKS cluster, the following parameters are configurable for Azure CNI networking:

**Virtual network**: The virtual network into which you want to deploy the Kubernetes cluster.  You can create a new virtual network or use an existing one. If you want to use an existing virtual network, make sure it's in the same location and Azure subscription as your Kubernetes cluster. For information about the limits and quotas for an Azure virtual network, see [Azure subscription and service limits, quotas, and constraints](/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-resource-manager-virtual-networking-limits).

**Subnet**: The subnet within the virtual network where you want to deploy the cluster. You can add new subnets into the virtual network during the cluster creation process. For hybrid connectivity, the address range shouldn't overlap with any other virtual networks in your environment.

**Azure Network Plugin**: When Azure network plugin is used, the internal LoadBalancer service with "externalTrafficPolicy=Local" can't be accessed from VMs with an IP in clusterCIDR that doesn't belong to AKS cluster.

**Kubernetes service address range**: This parameter is the set of virtual IPs that Kubernetes assigns to internal [services][services] in your cluster. This range can't be updated after you create your cluster. You can use any private address range that satisfies the following requirements:

- Must not be within the virtual network IP address range of your cluster.
- Must not overlap with any other virtual networks with which the cluster virtual network peers.
- Must not overlap with any on-premises IPs.
- Must not be within the ranges `169.254.0.0/16`, `172.30.0.0/16`, `172.31.0.0/16`, or `192.0.2.0/24`.

While it's possible to specify a service address range within the same virtual network as your cluster, we don't recommend it. Overlapping IP ranges can result in unpredictable behavior. For more information, see the [FAQ](#azure-cni-pod-subnet-frequently-asked-questions). For more information on Kubernetes services, see [Services][services] in the Kubernetes documentation.

**Kubernetes DNS service IP address**:  The IP address for the cluster's DNS service. This address must be within the *Kubernetes service address range*. Don't use the first IP address in your address range. The first address in your subnet range is used for the *kubernetes.default.svc.cluster.local* address.

- **Azure CNI**: That same basic _/24_ subnet range can only support a maximum of _8_ nodes in the cluster. This node count can only support up to _240_ pods, with a default maximum of 30 pods per node.

> [!NOTE]
> These maximums don't take into account upgrade or scale operations. In practice, you can't run the maximum number of nodes the subnet IP address range supports. You must leave some IP addresses available for scaling or upgrading operations.

## Virtual network peering and ExpressRoute connections

You can use [Azure virtual network peering][vnet-peering] or [ExpressRoute connections][express-route] with _Azure CNI_ to provide on-premises connectivity. Make sure you plan your IP addresses carefully to prevent overlap and incorrect traffic routing. For example, many on-premises networks use a *10.0.0.0/8* address range that's advertised over the ExpressRoute connection. We recommend creating your AKS clusters in Azure virtual network subnets outside of this address range, such as *172.16.0.0/16*.

For more information, see [Compare network models and their support scopes][network-comparisons].

## Azure CNI Pod Subnet frequently asked questions

- **Can I deploy VMs in my cluster subnet?**

  Yes for Azure CNI Node Subnet, the VMs can be deployed in the same subnet as the AKS cluster. 

- **What source IP do external systems see for traffic that originates in an Azure CNI-enabled pod?**

  Systems in the same virtual network as the AKS cluster see the pod IP as the source address for any traffic from the pod. Systems outside the AKS cluster virtual network see the node IP as the source address for any traffic from the pod.
  But for [Azure CNI dynamic IP allocation][azure-cni-dynamic-ip-allocation], no matter the connection is inside the same virtual network or cross virtual networks, the pod IP is always the source address for any traffic from the pod. This is because the [Azure CNI for dynamic IP allocation][azure-cni-dynamic-ip-allocation] implements [Microsoft Azure Container Networking][github-azure-container-networking] infrastructure, which gives end-to-end experience. Hence, it eliminates the use of [`ip-masq-agent`][ip-masq-agent], which is still used by traditional Azure CNI.  

- **Can I configure per-pod network policies?**

  Yes, Kubernetes network policy is available in AKS. To get started, see [Secure traffic between pods by using network policies in AKS][network-policy].

- **Is the maximum number of pods deployable to a node configurable?**

  With [Azure Container Networking Interface (CNI)][cni-networking], every pod gets an IP address from the subnet and can be accessed directly. Systems in the same virtual network as the AKS cluster see the pod IP as the source address for any traffic from the pod. Systems outside the AKS cluster virtual network see the node IP as the source address for any traffic from the pod. These IP addresses must be unique across your network space and must be planned in advance. Each node has a configuration parameter for the maximum number of pods that it supports. The equivalent number of IP addresses per node are then reserved up front for that node. This approach requires more planning, and often leads to IP address exhaustion or the need to rebuild clusters in a larger subnet as your application demands grow.  

- **Can I deploy VMs in my cluster subnet?**

  Yes. But for [Azure CNI for dynamic IP allocation][configure-azure-cni-dynamic-ip-allocation], the VMs cannot be deployed in pod's subnet. 

- **What source IP do external systems see for traffic that originates in an Azure CNI-enabled pod?**

  Systems in the same virtual network as the AKS cluster see the pod IP as the source address for any traffic from the pod. Systems outside the AKS cluster virtual network see the node IP as the source address for any traffic from the pod.
  
  But for [Azure CNI for dynamic IP allocation][configure-azure-cni-dynamic-ip-allocation], no matter the connection is inside the same virtual network or cross virtual networks, the pod IP is always the source address for any traffic from the pod. This is because the [Azure CNI for dynamic IP allocation][configure-azure-cni-dynamic-ip-allocation] implements [Microsoft Azure Container Networking][github-azure-container-networking] infrastructure, which gives end-to-end experience. Hence, it eliminates the use of [`ip-masq-agent`][ip-masq-agent], which is still used by traditional Azure CNI.  

- **Can I use a different subnet within my cluster virtual network for the *Kubernetes service address range*?**

  It's not recommended, but this configuration is possible. The service address range is a set of virtual IPs (VIPs) that Kubernetes assigns to internal services in your cluster. Azure Networking has no visibility into the service IP range of the Kubernetes cluster. The lack of visibility into the cluster's service address range can lead to issues. It's possible to later create a new subnet in the cluster virtual network that overlaps with the service address range. If such an overlap occurs, Kubernetes could assign a service an IP that's already in use by another resource in the subnet, causing unpredictable behavior or failures. By ensuring you use an address range outside the cluster's virtual network, you can avoid this overlap risk.
  Yes, when you deploy a cluster with the Azure CLI or a Resource Manager template. See [Maximum pods per node][max-pods].

- **Can I use a different subnet within my cluster virtual network for the *Kubernetes service address range*?**

  It's not recommended, but this configuration is possible. The service address range is a set of virtual IPs (VIPs) that Kubernetes assigns to internal services in your cluster. Azure Networking has no visibility into the service IP range of the Kubernetes cluster. The lack of visibility into the cluster's service address range can lead to issues. It's possible to later create a new subnet in the cluster virtual network that overlaps with the service address range. If such an overlap occurs, Kubernetes could assign a service an IP that's already in use by another resource in the subnet, causing unpredictable behavior or failures. By ensuring you use an address range outside the cluster's virtual network, you can avoid this overlap risk.

<!-- LINKS - External -->
[cni-networking]: https://github.com/Azure/azure-container-networking/blob/master/docs/cni.md
[Calico-network-policies]: https://docs.projectcalico.org/v3.9/security/calico-network-policy
[github-azure-container-networking]: https://github.com/Azure/azure-container-networking
[ip-masq-agent]: https://kubernetes.io/docs/tasks/administer-cluster/ip-masq-agent/

<!-- LINKS - Internal -->

[aks-network-nsg]: concepts-network.md#network-security-groups
[azure-cni-dynamic-ip-allocation]: concepts-network-azure-cni-pod-subnet.md#dynamic-ip-allocation-mode
[azure-cni-overlay]: concepts-network-azure-cni-overlay.md
[azure-cni-pod-subnet]: concepts-network-azure-cni-pod-subnet.md
[virtual-nodes]: virtual-nodes-cli.md
[vnet-peering]: /azure/virtual-network/virtual-network-peering-overview
[express-route]: /azure/expressroute/expressroute-introduction
[network-comparisons]: concepts-network-cni-overview.md
[network-policy]: use-network-policies.md
[services]: concepts-network-services.md
[max-pods]: concepts-network-ip-address-planning.md#maximum-pods-per-node
[configure-azure-cni-dynamic-ip-allocation]: configure-azure-cni-dynamic-ip-allocation.md
