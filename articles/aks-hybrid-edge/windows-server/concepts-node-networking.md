---
title: Node virtual machine networking in AKS on Windows Server
description: Learn about virtual machine networking in AKS, including static IP and DHCP networking and load balancers.
author: davidsmatlak
ms.topic: concept-article
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 1/14/2022
ms.custom: windows-server

# Intent: As an IT Pro, I want to learn about virtual machine networking in AKS.
# Keyword: virtual machine networking

---
# Network concepts for deploying AKS nodes

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

You can choose between two IP address assignment models for your networking architecture for AKS on Windows Server. AKS supports [several deployment options](../aks-overview.md) for Azure Kubernetes Service (AKS):

- **Static IP networking**: the virtual network allocates static IP addresses to the Kubernetes cluster API server, Kubernetes nodes, underlying VMs, load balancers, and any Kubernetes services that run on top of the cluster.
- **DHCP networking**: the virtual network allocates dynamic IP addresses to the Kubernetes nodes, underlying VMs, and load balancers using a DHCP server. The Kubernetes cluster API server, and any Kubernetes services you run on top of your cluster, are still allocated static IP addresses.

> [!NOTE]  
> The virtual networking architecture defined here for AKS might be different from the underlying physical networking architecture in a data center.

## Virtual IP pool

A Virtual IP (VIP) pool is set of IP addresses that are mandatory for any deployment in AKS. The VIP pool is a range of reserved IP addresses used to allocate IP addresses to the Kubernetes cluster API server. It guarantees that your applications on Kubernetes services are always reachable. Keep in mind that regardless of the virtual networking model and the address assignment model you choose, you must provide a VIP pool for your AKS host deployment.

The number of IP addresses in the VIP pool depends on the number of workload clusters and Kubernetes services planned for your deployment.

Depending on your networking model, the VIP pool definition differs in the following ways:

- Static IP: if you're using static IP, make sure your virtual IP addresses are from the same subnet provided.
- DHCP: if your network is configured with DHCP, work with your network administrator to exclude the VIP pool IP range from the DHCP scope used for the AKS deployment.

## Kubernetes node VM IP pool

Kubernetes nodes are deployed as specialized virtual machines in AKS. AKS allocates IP addresses to these virtual machines to enable communication between Kubernetes nodes.

- Static IP: you must specify a Kubernetes node VM IP pool range. The number of IP addresses in this range depends on the total number of Kubernetes nodes you plan to use to deploy across your AKS host and workload Kubernetes clusters. Keep in mind that updates consume one to three additional IP addresses during the update.
- DHCP: you don't need to specify a Kubernetes node VM pool, as IP addresses to the Kubernetes nodes are dynamically allocated by the DHCP server on your network.

## Virtual network with static IP networking (recommended)

This networking model creates a virtual network that allocates IP addresses from a statically defined address pool to all objects in your deployment. An added benefit of using static IP networking is that long-lived deployments and application workloads are guaranteed to always be reachable.

Specify the following parameters while defining a virtual network with static IP configurations:

> [!IMPORTANT]
> This version of AKS does not allow any network configuration changes once the AKS host or the workload cluster is deployed. In order to change the networking settings, you must start fresh by removing the workload clusters and uninstalling AKS.

- Name: The name of your virtual network.
- Address prefix: The IP address prefix to use for your subnet.
- Gateway: The IP address of the default gateway for the subnet.
- DNS server: An array of IP addresses pointing to the DNS servers to be used for the subnet. A minimum of one and a maximum of three servers can be provided.
- Kubernetes node VM pool: A continuous range of IP addresses to be used for your Kubernetes node VMs.
- Virtual IP pool: A continuous range of IP addresses to be used for your Kubernetes cluster API server and Kubernetes services.

  > [!NOTE]
  > The VIP pool must be part of the same subnet as the Kubernetes node VM pool.

- vLAN ID: The vLAN ID for the virtual network. If it's omitted, the virtual network is not tagged.

## Virtual network with DHCP networking

This networking model creates a virtual network that allocates IP addresses using DHCP to all objects in the deployment.  

You must specify the following parameters while defining a virtual network with static IP configurations:

- Name: The name of your virtual network.
- Virtual IP pool: The continuous range of IP addresses to be used for your Kubernetes cluster API server and Kubernetes services. 

  > [!NOTE]
  > The VIP pool addresses need to be in the same subnet as the DHCP scope, and must be excluded from the DHCP scope in order to avoid address conflicts.

- vLAN ID: The vLAN ID for the virtual network. If omitted, the virtual network is not tagged.

## Microsoft On-premises Cloud service

Microsoft On-premises Cloud (MOC) is the management stack that enables the virtual machines on Windows Server-based SDDC to be managed in the cloud. MOC consists of:

- A single instance of a highly available `cloud agent` service deployed in the cluster. This agent runs on any one node in the Windows Server cluster and is configured to fail over to another node.
- A `node agent` running on every physical node.

To enable communication with MOC, you must provide the IP address CIDR to be used for the service. The `-cloudserviceCIDR` is a parameter in the [`Set-AksHciConfig`](/azure/aks/aksarc/reference/ps/set-akshciconfig) command that's used to assign the IP address to the cloud agent service and enable high availability of the cloud agent service.

The choice of an IP address for the MOC service depends on the underlying networking model used by your cluster deployment on Windows Server.

> [!NOTE]
> The IP address allocation for the MOC service is independent of your Kubernetes virtual network model. The IP address allocation is dependent on the underlying physical network, and the IP addresses configured for the Windows Server cluster nodes in your data center.

- **Windows Server cluster nodes with a DHCP-based IP address allocation mode**: If your cluster nodes are assigned an IP address from a DHCP server present on the physical network, then you don't need to explicitly provide an IP address to the MOC service, as the MOC service also receives an IP address from the DHCP server.

- **Windows Server cluster nodes with a static IP allocation model**: If your cluster nodes are assigned static IP addresses, then you must explicitly provide an IP address for the MOC cloud service. The IP address for the MOC service must be in the same subnet as the IP addresses of Windows Server cluster nodes. To explicitly assign an IP address for MOC service, use the `-cloudserviceCIDR` parameter in the `Set-AksHciConfig` command. Make sure you enter an IP address in the CIDR format, for example: `10.11.23.45/16`.

## Compare network models

Both DHCP and static IP provide network connectivity on your AKS on Windows Server deployment. However, there are advantages and disadvantages to each. At a high level, the following considerations apply:

**DHCP**
    - Does not guarantee long-lived IP addresses for some resource types in an AKS deployment.
    - Supports expansion of reserved DHCP IP addresses if your deployment gets bigger than you initially anticipated.

**Static IP**
    - Guarantees long-lived IP addresses for all resources in an AKS deployment.
    - Since automatic expansion of Kubernetes node IP pool is not supported, you may not be able to create new clusters if you have exhausted the Kubernetes node IP pool.

The following table compares IP address allocation for resources between static IP and DHCP networking models:

| Capability| Static IP | DHCP |
|-----------|-----------|-----------|
| Kubernetes cluster API server| Assigned statically using VIP pool. | Assigned statically using VIP pool. |
| Kubernetes nodes (on virtual machines) | Assigned using Kubernetes node IP pool. | Assigned dynamically. |
| Kubernetes services | Assigned statically using VIP pool. | Assigned statically using VIP pool. |
| HAProxy load balancer VM | Assigned using Kubernetes node IP pool. | Assigned dynamically. |
| Microsoft On-Premises Cloud Service | Depends on the physical networking configuration for Windows Server cluster nodes. | Depends on the physical networking configuration for Windows Server cluster nodes. |
| VIP pool | Mandatory | Mandatory |
| Kubernetes node VM IP pool | Mandatory | Not supported |

## Minimum IP address reservations for an AKS deployment

Regardless of your deployment model, the number of IP addresses reserved remains the same. This section describes the number of IP addresses you need to reserve based on your AKS deployment model.

### Minimum IP address reservation

At a minimum, you should reserve the following number of IP addresses for your deployment:

| Cluster type  | Control plane node | Worker node | For update operations | Load balancer  |
| ------------- | ------------------ | ---------- | ----------| -------------|
| AKS host |  One IP |  N/A  |  Two IP |  N/A  |
| Workload cluster  |  One IP per node  | One IP per node |  5 IP  |  One IP |

You should also reserve the following number of IP addresses for your VIP pool:

| Resource type  | Number of IP addresses |
| ------------- | ------------------|
| Cluster API server |  1 per cluster |
| Kubernetes services  |  1 per service  |
| Application services | 1 per service planned |

As you can see, the number of required IP addresses is variable depending on the architecture of your AKS deployment, and the number of services you run on your Kubernetes cluster. We recommend reserving a minimum of 256 IP addresses (/24 subnet) for your deployment.

### Walk through an example deployment

Jane is an IT administrator just starting with AKS on Windows Server. She wants to deploy two Kubernetes clusters: Kubernetes cluster A and Kubernetes cluster B on her Windows Server cluster. She also wants to run a voting application on top of her cluster. This application has three instances of the front-end UI running across the two clusters and one instance of the backend database.

- Kubernetes cluster A has 3 control plane nodes and 5 worker nodes.
- Kubernetes cluster B has 1 control plane node and 3 worker nodes.
- 3 instances of the front-end UI (port 443).
- 1 instance of the backend database (port 80).

Based on the previous table, she must reserve:

- 3 IP addresses for the AKS host (one IP for control plane node and two IPs for running update operations).
- 3 IP addresses for the control plane nodes in cluster A (one IP per control plane node).
- 5 IP addresses for the worker nodes in cluster A (one IP per worker node).
- 6 IP addresses additionally for cluster A (five IPs for running update operations and 1 IP for load balancer).
- 1 IP addresses for the control plane nodes in cluster B (one IP per control plane node).
- 3 IP addresses for the worker nodes in cluster B (one IP per worker node).
- 6 IP addresses additionally for cluster B (five IPs for running update operations and 1 IP for load balancer).
- 2 IP addresses for the Kubernetes cluster API servers (one IP per Kubernetes cluster).
- 3 IP addresses for the Kubernetes service (one IP address per instance of the front-end UI, since they all use the same port. The backend database can use any one of the three IP addresses as long as it will use a different port).

As previously explained, Jane requires a total of 32 IP addresses to deploy the cluster. Jane should therefore reserve a /26 subnet for her virtual network.

### Split reserved IP addresses based on a static IP network model

While the total number of reserved IP addresses remains the same, the deployment model determines how these IP addresses are divided among IP groups. The static IP network model has two IP pools:

- **Kubernetes node VM IP pool**: for Kubernetes node VMs and the load balancer VM. This IP pool also includes the IP address required for running update operations.
- **Virtual IP pool**: for the Kubernetes API server and Kubernetes services.

Working with this example, Jane must further divide these IP addresses across VIP pools and Kubernetes node IP pools:

- 5 (two for Kubernetes cluster API server and three for Kubernetes services) out of the 32 IP addresses for her VIP pool.
- 27 (all the IP addresses for her Kubernetes nodes and underlying VMs, the load balancer VMs, and update operations) for her Kubernetes node IP pool.

### Split reserved IP addresses based on a DHCP network model

While the total number of reserved IP addresses remain the same, the deployment model determines how these IP addresses are divided among IP group(s). As discussed in the previous section, the DHCP network model has one IP scope:

- **Virtual IP pool**: for the Kubernetes API server and Kubernetes services

Working with the previous example:

- Jane must reserve a total of 32 IP addresses or a /26 subnet on her DHCP server.
- She must exclude 5 (two for Kubernetes cluster API server and three for Kubernetes services) from the DHCP scope of 32 IP addresses for her VIP pool.

## Ingress controllers

During deployment of a target cluster, a `HAProxy`-based load balancer resource is created. The load balancer is configured to distribute traffic to the pods in your service on a given port. The load balancer only works at layer 4, which indicates that the service is unaware of the actual application; i.e., it can't make any additional routing considerations.

Ingress controllers work at layer 7, and are able to use more intelligent rules to distribute application traffic. A common use of an ingress controller is to route HTTP traffic to different applications based on the inbound URL.

:::image type="content" source="../media/concepts-node-networking/aks-ingress.png" alt-text="Diagram showing ingress traffic flow in an AKS cluster on Windows Server." lightbox="../media/concepts-node-networking/aks-ingress.png":::

## Next steps

This article covers some of the networking concepts for deploying AKS nodes on Windows Server. For more information, see the following articles:

- [Container networking concepts](./concepts-container-networking.md)
- [Cluster and workloads](./kubernetes-concepts.md)
- [Deploy a Kubernetes workload cluster](./kubernetes-walkthrough-powershell.md)
