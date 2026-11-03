---
title: Plan network architecture for AKS with Azure Managed Lustre CSI Driver
description: Learn how to plan the network architecture for connecting Azure Kubernetes Service (AKS) to an Azure Managed Lustre file system using the CSI driver.
ms.topic: concept-article
ms.subservice: aks-storage
ms.date: 10/30/2026
author: pauljewellmsft
ms.author: akashdubey
ms.reviewer: brianl
ms.custom: sfi-image-nochange

# Intent: As an IT pro, I want to understand the network architecture options for connecting AKS to Azure Managed Lustre.
# Keyword:

---

# Plan network architecture for AKS with Azure Managed Lustre

Before deploying the Azure Lustre CSI Driver for Kubernetes, you need to plan the network configuration between your Azure Kubernetes Service (AKS) cluster and your Azure Managed Lustre file system. This article covers the supported network types and architecture options for connecting AKS to Azure Managed Lustre.

This network plan applies to Helm and script installations and to the alternative AKS CLI option in preview. The driver doesn't replace the network connectivity requirements or create the virtual network and subnet used for a dynamically provisioned file system. After preparing the network, follow [Install the Azure Managed Lustre CSI driver](azure-managed-lustre-install.md).

## Determine the network type to use with AKS

AKS supports multiple networking models, each with different capabilities and use cases. All networking models work with the Azure Lustre CSI Driver for Kubernetes, but they have different requirements for virtual networking and cluster setup.

For comprehensive information about choosing the right networking model for your specific requirements, see [Azure Kubernetes Service Container Network Interface (CNI) networking overview](/azure/aks/concepts-network-cni-overview).

When creating an AKS cluster in the Azure portal, you'll see the networking options described in the following sections.

### Recommended options

**Azure CNI Overlay (Recommended)**
- Conserves VNet IP address space by using logically separate CIDR ranges for pods
- Supports maximum cluster scale (5000 nodes and 250 pods per node)
- Simple IP address management
- Best choice for most scenarios

**Azure CNI Pod Subnet**
- Pods get full VNet connectivity and can be directly reached via their private IP address
- Requires larger, non-fragmented VNet IP address space
- Choose this if you need direct external access to pod IPs

### Legacy options (not recommended for new deployments)

**Azure CNI Node Subnet (Legacy)**
- Limited scale and inefficient use of VNet IPs
- Only recommended if you specifically need a managed VNet for your cluster. See [AKS Legacy Container Networking Interfaces (CNI)](/azure/aks/concepts-network-legacy-cni)

**Kubenet (Retiring)**
- Retiring March 31, 2028. For more information, see [AKS use Kubenet](/azure/aks/configure-kubenet).
- Limited scale and requires manual route management
- Plan to migrate to Azure CNI Overlay before the retirement date

For detailed information on networking models, see [Azure Kubernetes Service CNI networking overview](/azure/aks/concepts-network-cni-overview).

## Determine the network architecture for interconnectivity of AKS and Azure Managed Lustre

Azure Managed Lustre operates within a private virtual network. Your AKS instance must have network connectivity to the Azure Managed Lustre virtual network. There are two common ways to configure the networking between Azure Managed Lustre and AKS:

- Install AKS in its own virtual network and create a virtual network peering with the Azure Managed Lustre virtual network.
- Use the **Bring your own Azure virtual network** option in AKS to install AKS in a new subnet on the Azure Managed Lustre virtual network.

> [!NOTE]
> Don't install AKS in the same subnet as Azure Managed Lustre.

### Peering AKS and Azure Managed Lustre virtual networks

Virtual network peering lets you separate network management into different privileged roles. It also provides flexibility because you can peer networks across Azure subscriptions or regions. Coordinate the two networks to avoid overlapping IP address spaces.

![Diagram that shows two virtual networks, one for Azure Managed Lustre and one for AKS, with a peering arrow connecting them.](media/azure-managed-lustre/subnet-access-option-2.png)

### Installing AKS in a subnet on the Azure Managed Lustre virtual network

The option to install the AKS cluster in the Azure Managed Lustre virtual network with the **Bring your own Azure virtual network** feature in AKS can be advantageous in scenarios where one team manages networking for both services. You need to create an extra subnet, sized to meet your AKS networking requirements, in the Azure Managed Lustre virtual network.

The AKS control-plane identity needs permissions on the AKS subnet. See [AKS identity role assignments](managed-identity-overview.md#control-plane-managed-identity-role-assignments) when using your own virtual network.

![Diagram that shows an Azure Managed Lustre virtual network with two subnets, one for the Lustre file system and one for AKS.](media/azure-managed-lustre/subnet-access-option-1.png)

## Related content

- [Azure Lustre CSI driver overview](azure-managed-lustre-overview.md)
- [Install the Azure Managed Lustre CSI driver](azure-managed-lustre-install.md).
- [Dynamically provision Azure Managed Lustre volumes](azure-managed-lustre-dynamic-provisioning.md).
- [Use static provisioning with the Azure Lustre CSI driver](azure-managed-lustre-static-provisioning.md)
- [Virtual network peering](/azure/virtual-network/virtual-network-peering-overview)
- [Azure Kubernetes Service CNI networking overview](/azure/aks/concepts-network-cni-overview)
