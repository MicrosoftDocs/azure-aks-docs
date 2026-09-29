---
title: IP address planning for AKS Hybrid and Edge
description: Learn about how to plan for IP addresses and reservation, to deploy AKS in production.
ms.topic: concept-article
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.reviewer: srikantsarwa
ms.lastreviewed: 10/08/2024
ms.custom: hyperconverged
---

# IP address planning requirements

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

IP address planning for AKS Hybrid and Edge involves designing a network that supports applications, node pools, pod networks, service communication, and external access. This article walks you through some key considerations for effective IP address planning, and minimum number of IP addresses required to deploy AKS in production. See the [AKS networking concepts and requirements](network-system-requirements.md) before reading this article.

## Simple IP address planning for Kubernetes clusters and applications

In the following scenario walkthrough, you reserve IP addresses from a single network for your Kubernetes clusters and services. This example is the most straightforward and simple scenario for IP address assignment.

| IP address requirement    | Minimum number of IP addresses | How and where to make this reservation |
|------------------|---------|---------------|
| AKS VM IPs | Reserve one IP address for every worker node in your Kubernetes cluster. For example, if you want to create 3 node pools with 3 nodes in each node pool, you need 9 IP addresses in your IP pool. | Reserve IP addresses through IP pools in the Arc VM logical network. |
| AKS K8s version upgrade IPs | Because AKS performs rolling upgrades, reserve one IP address for every AKS cluster for Kubernetes version upgrade operations. | Reserve IP addresses through IP pools in the Arc VM logical network. |
| Control plane IP | Reserve one IP address for every Kubernetes cluster in your environment. For example, if you want to create 5 clusters in total, reserve 5 IP addresses, one for each Kubernetes cluster. | Reserve IP addresses through IP pools in the Arc VM logical network. |
| Load balancer IPs | The number of IP addresses reserved depends on your application deployment model. As a starting point, you can reserve one IP address for every Kubernetes service. | Reserve IP addresses in the same subnet as the Arc VM logical network, but outside the IP pool. |

### Example walkthrough for IP address reservation for Kubernetes clusters and applications

Jane is an IT administrator just starting with AKS Hybrid and Edge. Jane wants to deploy two Kubernetes clusters: Kubernetes cluster A and Kubernetes cluster B on the Azure Local cluster. Jane also wants to run a voting application on top of cluster A. This application has three instances of the front-end UI running across the two clusters and one instance of the backend database. All the AKS clusters and services are running in a single network, with a single subnet.

- Kubernetes cluster A has 3 control plane nodes and 5 worker nodes.
- Kubernetes cluster B has 1 control plane node and 3 worker nodes.
- 3 instances of the front-end UI (port 443).
- 1 instance of the backend database (port 80).

Based on the previous table, Jane must reserve a total of 19 IP addresses in Jane's subnet:

- 8 IP addresses for the AKS node VMs in cluster A (one IP per K8s node VM).
- 4 IP addresses for the AKS node VMs in cluster B (one IP per K8s node VM).
- 2 IP addresses for running AKS upgrade operation (one IP address per AKS cluster).
- 2 IP addresses for the AKS control plane (one IP address per AKS cluster)
- 3 IP addresses for the Kubernetes service (one IP address per instance of the front-end UI, since they all use the same port. The backend database can use any one of the three IP addresses as long as it uses a different port).

Continuing with this example, and adding it to the following table, you get:

| Parameter    | Number of IP addresses | How and where to make this reservation |
|------------------|---------|---------------|
| AKS VMs, K8s version upgrade and control plane IP  | Reserve 16 IP addresses | Make this reservation through IP pools in the Azure Local logical network. |
| Load balancer IPs | 3 IP address for Kubernetes services, for Jane's voting application. | These IP addresses are used when you install a load balancer on cluster A. You can use the MetalLB Arc extension, or bring your own 3rd party load balancer. Ensure that this IP is in the same subnet as the Arc logical network, but outside the IP pool defined in the Arc VM logical network. |

#### Example CLI commands for IP address reservation for Kubernetes clusters and applications

This section describes the set of commands Jane runs for her scenario. First, create a logical network with an IP pool that has at least 16 IP addresses. We created the IP pool with 20 IP addresses to provide the option to scale on day N. For detailed information about parameter options in logical networks, see [az stack-hci-vm network lnet create](/cli/azure/stack-hci-vm/network/lnet#az-stack-hci-vm-network-lnet-create):

```azurecli
$ipPoolStart = "10.220.32.18"
$ipPoolEnd = "10.220.32.37"
az stack-hci-vm network lnet create --subscription $subscription --resource-group $resource_group --custom-location $customLocationID --name $lnetName --vm-switch-name $vmSwitchName --ip-allocation-method "Static" --address-prefixes $addressPrefixes --gateway $gateway --dns-servers $dnsServers --ip-pool-start $ipPoolStart --ip-pool-end $ipPoolEnd
```

Next, create an AKS cluster with the previous logical network:

```azurecli
az aksarc create -n $aksclustername -g $resource_group --custom-location $customlocationID --vnet-ids $lnetName --aad-admin-group-object-ids $aadgroupID --generate-ssh-keys
```

Now you can enable MetalLB load balancer with an IP pool of 3 IP addresses, in the same subnet as the Arc VM logical network. You can add more IP pools later if your application needs an increase. For detailed requirements, see the [MetalLB Arc extension overview](load-balancer-overview.md).

```azurecli
az k8s-runtime load-balancer create --load-balancer-name $lbName --resource-uri subscriptions/$subscription/resourceGroups/$resource_group/providers/Microsoft.Kubernetes/connectedClusters/metallb-demo --addresses 10.220.32.47-10.220.32.49 --advertise-mode ARP
```

### LNET considerations for AKS clusters and Arc VMs

Logical networks on Azure Local are used by both AKS clusters and Arc VMs. You can configure logical networks in one of the following 2 ways:

- Share a logical network between AKS and Arc VMs.
- Define separate logical networks for AKS clusters and Arc VMs.

Sharing a logical network between AKS and Arc VMs on Azure Local offers the benefit of streamlined communication, cost savings, and simplified network management. However, this approach also introduces potential challenges such as resource contention, security risks, and complexity in troubleshooting.

| Criteria                              | Sharing a logical network                                  | Defining separate logical networks     |
|-------------------------------------------|----------------------------------------------------------------|----------------------------------------------------------------|
| **Configuration complexity** | Simpler configuration with a single network, reducing setup complexity. | More complex setup, as you need to configure multiple logical networks for VMs and AKS clusters.
| **Scalability**              | Potential scalability limitations as both Arc VMs and AKS clusters share network resources. | More scalable since network resources are separated and can scale independently. |
| **Network policy management**  | Easier to manage with one set of network policies, but harder to isolate workloads. | Easier to isolate workloads, as separate policies can be applied per logical network. |
| **Security considerations**    | Increased risk of cross-communication vulnerabilities if not properly segmented.  | Better security as each network can be segmented and isolated more strictly. |
| **Impact of network failures** | A failure in the shared network can affect both AKS and Arc VMs simultaneously.   | A failure in one network affects only the workloads within that network, reducing overall risk. |

## IP address range allocation for pod CIDR and service CIDR

This section describes the IP address ranges used by Kubernetes for pod and service communication within a cluster. These IP address ranges are defined during the AKS cluster creation process and are used to assign unique IP addresses to pods and services within the cluster.

### Pod network CIDR

Pod network CIDR is a range of IP addresses used by Kubernetes to assign unique IP addresses to the individual pods running within a Kubernetes cluster. Each pod gets its own IP address within this range, allowing pods to communicate with each other and with services within the cluster. In AKS, pod IP addresses are assigned via *Calico CNI in VXLAN* mode. Calico VXLAN helps create *Overlay networks*, where the IP addresses of pods (from the pod network CIDR) are virtualized and tunneled through the physical network. In this mode, each pod is assigned an IP address from the pod network CIDR, but this IP address is not directly routable on the physical network. Instead, it is encapsulated within the network packets and sent through the underlying physical network to reach its destination pod on another node.

AKS provides a default value of 10.244.0.0/16 for the pod network CIDR. AKS does support customizations for the pod network CIDR. You can set your own value using the [--pod-cidr](/cli/azure/aksarc#az-aksarc-create) parameter when creating the AKS cluster. Ensure that the CIDR IP range is large enough to accommodate the maximum number of pods per node and across the Kubernetes cluster.

### Service network CIDR

The Service network CIDR is the range of IP addresses reserved for Kubernetes services like LoadBalancers, ClusterIP, and NodePort within a cluster. Kubernetes supports the following service types:

- ClusterIP: The default service type, which exposes the service within the cluster. The IP assigned from the Service network CIDR is only accessible within the Kubernetes cluster.
- NodePort: Exposes the service on a specific port on each node's IP address. The ClusterIP is still used internally, but external access is through the node IPs and a specific port.
- LoadBalancer: This type creates a cloud-provider-managed load balancer and exposes the service externally. The cloud provider typically manages the external IP assignment, while the internal ClusterIP remains within the service network CIDR.

AKS provides a default value of 10.96.0.0/12 for the service network CIDR. AKS does not support customizations for the service network CIDR today.

## Next steps

[Create logical networks for Kubernetes clusters on Azure Local](aks-networks.md)
