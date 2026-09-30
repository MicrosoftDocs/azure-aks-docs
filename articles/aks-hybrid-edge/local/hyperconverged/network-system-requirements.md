---
title: AKS Hybrid and Edge network requirements
description: Learn about AKS network prerequisites.
ms.topic: overview
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.reviewer: srikantsarwa
ms.lastreviewed: 08/12/2025
ms.custom: hyperconverged
---

# AKS Hybrid and Edge network requirements

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

This article introduces core networking concepts for your VMs and applications in AKS Hybrid and Edge. The article also describes the required networking prerequisites for creating Kubernetes clusters. We recommend that you work with a network administrator to provide and set up the networking parameters required to deploy AKS Hybrid and Edge.

In this conceptual article, the following key components are introduced. These components need a static IP address in order for the AKS cluster and applications to create and operate successfully:

- Logical network for AKS VMs and control plane IP
- Load balancer for containerized applications

## Logical networks for AKS VMs and control plane IP

Kubernetes nodes are deployed as specialized virtual machines in AKS Hybrid and Edge. These VMs are allocated IP addresses to enable communication between Kubernetes nodes. AKS uses Azure Local logical networks to provide IP addresses and networking for the underlying VMs of the Kubernetes clusters. For more information about logical networks, see [Logical networks for Azure Local](/azure/azure-local/manage/create-logical-networks?tabs=azurecli). You must plan to reserve one IP address per AKS cluster node VM in your Azure Local environment.

> [!NOTE]
> Static IP is the only supported mode for assigning an IP address to AKS VMs. This is because Kubernetes requires the IP address assigned to a Kubernetes node to be constant throughout the lifecycle of the Kubernetes cluster.
> Software defined virtual networks and SDN related features are currently not supported on AKS on Azure Local.

The following parameters are required in order to use a logical network for AKS cluster create operation:

| [Az CLI logical networks parameter](/azure/azure-local/manage/create-logical-networks?tabs=azurecli) | Description| Required parameter for AKS cluster|
|------------------|---------|-----------|
| `--address-prefixes` | AddressPrefix for the network. Currently only 1 address prefix is supported. Usage: `--address-prefixes "10.220.32.16/24"`. | ![Supported](../../media/aks-hybrid-networks/check.png) |
| `--dns-servers`      | Space-separated list of DNS server IP addresses. Usage: `--dns-servers 10.220.32.16 10.220.32.17`. | ![Supported](../../media/aks-hybrid-networks/check.png) |
| `--gateway`         | Gateway. The gateway IP address must be within the scope of the address prefix. Usage: `--gateway 10.220.32.16`. | ![Supported](../../media/aks-hybrid-networks/check.png) |
| `--ip-allocation-method`         | The IP address allocation method. Supported values are "Static". Usage: `--ip-allocation-method "Static"`. | ![Supported](../../media/aks-hybrid-networks/check.png) |
| `--vm-switch-name`     | The name of the VM switch. Usage: `--vm-switch-name "vm-switch-01"`. | ![Supported](../../media/aks-hybrid-networks/check.png) |
| `--ip-pool-start`     | If you use MetalLB or any other third party load balancer in L2/ARP mode, we highly recommend using IP pools to separate AKS IP requirements from load balancer IPs. This recommendation is to help avoid IP address conflicts that can lead to unintended and hard-to-diagnose failures. This value is the start IP address of your IP pool. The address must be in the range of the address prefix. Usage: `--ip-pool-start "10.220.32.18"`.  | Optional, but highly recommended. |
| `--ip-pool-end`       | If you use MetalLB or any other third party load balancer in L2/ARP mode, we highly recommend using IP pools to separate AKS IP requirements from load balancer IPs. This recommendation is to help avoid IP address conflicts that can lead to unintended and hard-to-diagnose failures. This value is the end IP address of your IP pool. The address must be in the range of the address prefix. Usage: `--ip-pool-end "10.220.32.38"`.  | Optional, but highly recommended. |

### Control plane IP

Kubernetes uses a control plane to ensure every component in the Kubernetes cluster is kept in the desired state. The control plane also manages and maintains the worker nodes that hold the containerized applications. AKS Hybrid and Edge deploys the KubeVIP load balancer to ensure that the API server IP address of the Kubernetes control plane is always available. This KubeVIP instance requires a single immutable "control plane IP address" to function correctly. AKS automatically chooses a control plane IP for you from the logical network passed during the Kubernetes cluster create operation.

You also have the option of passing a control plane IP. In such cases, the control plane IP must be within the scope of the address prefix of the logical network. You must ensure that the control plane IP address does not overlap with anything else, including Arc VM logical networks, infrastructure network IPs, load balancers, etc. Overlapping IP addresses can lead to unexpected failures for both the AKS cluster and any other place the IP address is being used. You must plan to reserve one IP address per Kubernetes cluster in your environment.

## Load balancer IPs for containerized applications

The main purpose of a load balancer is to distribute traffic across multiple nodes in a Kubernetes cluster. This load balancing can help prevent downtime and improve overall performance of applications. AKS supports the following options to deploy a load balancer for your Kubernetes cluster:

- [Deploy extension for MetalLB for Azure Arc enabled Kubernetes](deploy-load-balancer-portal.md).
- Bring your own third party load balancer.

Whether you choose the Arc extension for MetalLB, or bring your own load balancer, you must provide a set of IP addresses to the load balancer service. You have the following options:

- Provide IP addresses for your services from the same subnet as the AKS VMs.
- Use a different network and list of IP addresses if your application needs external load balancing.

Regardless of the option you choose, you must ensure that the IP addresses allocated to the load balancer don't conflict with the IP addresses in the logical network. Conflicting IP addresses can lead to unforeseen failures in your AKS deployment and applications.

## Proxy settings

Proxy settings in AKS are inherited from the underlying infrastructure system. The functionality to set individual proxy settings for Kubernetes clusters and change proxy settings isn't supported yet. For more information on how to set proxy correctly, see [proxy requirements for Azure Local](/azure/azure-local/manage/configure-proxy-settings-23h2).

> [!WARNING]
> You cannot update incorrect proxy settings after you deploy Azure Local. If the proxy is misconfigured, you must redeploy Azure Local.

## Firewall URL exceptions

Firewall requirements for AKS have been consolidated with Azure Local firewall requirements. See [Azure Local firewall requirements](/azure/azure-local/concepts/firewall-requirements) for list of URLs that need to be allowed to successfully deploy AKS.

## DNS server settings

You need to ensure that the DNS server of the logical network can resolve the FQDN of the Azure Local cluster. DNS name resolution is required for all Azure Local nodes to be able to communicate with the AKS VM nodes.

## Network port and cross-VLAN requirements

When you deploy Azure Local, you allocate a contiguous block of at least [six static IP addresses on your management network's subnet](/azure/azure-local/deploy/deploy-via-portal#specify-network-settings), omitting addresses already used by the physical machines. These IPs are used by Azure Local and internal infrastructure (Arc Resource Bridge) for Arc VM management and AKS. If your management network that provides IP addresses to Arc Resource Bridge related Azure Local services are on a different VLAN than the logical network you used to create AKS clusters, you need to ensure that the following ports are opened to successfully create and operate an AKS cluster. 

| Destination Port | Destination | Source | Description | Bi-directional cross VLAN networking notes |
|------------------|-------------|--------|-------------|----------------|
| 22 | Logical network used for AKS VMs | IP addresses in management network | Required to collect logs for troubleshooting. | If you use separate VLANs, IP addresses in management network used for Azure Local and Arc Resource Bridge need to access the AKS cluster VMs on this port, and vice-versa.|
| 6443 | Logical network used for AKS VMs | IP addresses in management network | Required to communicate with Kubernetes APIs. | If you use separate VLANs, IP addresses in management network used for Azure Local and Arc Resource Bridge need to access the AKS cluster VMs on this port, and vice-versa.|
| 55000 | Cluster IP address | Logical network used for AKS VMs | Cloud Agent gRPC server | If you use separate VLANs, the AKS VMs need to access the IP addresses in management network used for cloud agent IP and cluster IP on this port, and vice-versa. |
| 65000 | Cluster IP address | Logical network used for AKS VMs | Cloud Agent gRPC authentication | If you use separate VLANs, the AKS VMs need to access the IP addresses in management network used for cloud agent IP and cluster IP on this port, and vice-versa. |

## Use Azure Arc gateway (preview) with Azure Local

If you use [Arc gateway](/azure/azure-local/deploy/deployment-azure-arc-gateway-overview) to deploy your Azure Local cluster infrastructure, make sure that connectivity between the AKS subnet and the cluster IP is allowed on port **40343**, as follows:

| Destination port | Destination                     | Source                          | Description                                                                 | Bi-directional cross-VLAN networking notes |
|------------------|---------------------------------|---------------------------------|-----------------------------------------------------------------------------|--------------------------------------------|
| **40343**        | Cluster IP address |  Logical network used for AKS VMs | Required only when the Azure Local cluster is configured with Arc Gateway for outbound connectivity. | If you use separate VLANs or subnets, ensure that the AKS VMs can reach the Azure Local cluster IP address on port **40343**, and vice versa. |

### Retrieve the Azure Local cluster IP address

You can run the following PowerShell commands on the cluster to get the IP address of the Azure Local cluster:

```powershell
Get-ClusterResource -Name "Cluster IP Address" | Get-ClusterParameter -Name Address | Select-Object -Property Value
```

## Next steps

[IP address planning and considerations for Kubernetes clusters and applications](aks-hci-ip-address-planning.md)
