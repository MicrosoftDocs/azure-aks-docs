---
title: Plan IP addresses for Azure Kubernetes Service (AKS) on Azure Local for multi-rack deployments
description: Plan the IP addresses needed to deploy AKS enabled by Azure Arc clusters on Azure Local (multi-rack), including node IPs, control plane endpoints, and load balancer addresses.
ms.topic: concept-article
ms.date: 09/01/2026
ms.author: sanjanamohan
ms.custom: multi-rack
author: sanjanamsft
---

# IP address planning requirements for Azure Local multi-rack

IP address planning for AKS enabled by Azure Arc involves designing a network that supports applications, node pools, pod networks, service communication, and external access. This article walks you through some key considerations for effective IP address planning, and minimum number of IP addresses required to deploy AKS in production. See the [AKS networking concepts and requirements before reading this article](network-system-requirements.md).

## Simple IP address planning for Kubernetes clusters and applications

In the following scenario walkthrough, you plan for IP addresses from a single network for your Kubernetes clusters and services and _ensure the required number of IP addresses are available in the logical network using IP pools_. This example is the most straightforward and simple scenario for IP address assignment.

| IP address requirement    | Minimum number of IP addresses |
|------------------|---------|
| AKS Arc virtual machine (VM) IPs | Plan for one IP address for every worker node in your Kubernetes cluster. For example, if you want to create three node pools with three nodes in each node pool, you need nine IP addresses in your IP pool. |
| AKS Arc K8s version upgrade IPs | Because AKS Arc performs rolling upgrades, plan for one more IP address for every AKS Arc cluster for Kubernetes version upgrade operations. |
| Control plane IP | Plan for one IP address for every Kubernetes cluster in your environment. For example, if you want to create five clusters in total, plan for five IP addresses, one for each Kubernetes cluster. |
| Load balancer IPs | The number of IP addresses needed depends on your application deployment model. As a starting point, you can plan for one IP address for every Kubernetes service. |

#### Simple formula

```console
IPs per cluster = controlPlaneNodeCount + workerNodeCount + 2 + loadBalancerIPs
```
The **+ 2** accounts for:

- **Control plane IP**: A virtual IP that provides access to the Kubernetes API server.
- **AKS Arc K8s version upgrade IPs**: During rolling upgrades, one more node is temporarily created. This node requires an IP address.

## Example walkthrough for IP address planning for Kubernetes clusters and applications

Jane is an IT administrator just starting with AKS enabled by Azure Arc. Jane wants to deploy one Kubernetes clusters on the Azure Local cluster. Jane also wants to run a voting application on the Kubernetes cluster. This application has three instances of the front-end UI running across the two clusters and one instance of the backend database. The AKS cluster and services are running in a single network, with a single subnet.

- Kubernetes cluster has three control plane nodes and five worker nodes.
- Three instances of the front-end UI (port 443).
- One instance of the backend database (port 80).

Based on the previous table, Jane must plan for a total of 13 IP addresses in Jane's subnet:

- Eight IP addresses for the AKS Arc node VMs in cluster (one IP per K8s node VM).
- One IP addresses for running AKS Arc upgrade operation (one IP address per AKS Arc cluster).
- One IP addresses for the AKS Arc control plane (one IP address per AKS Arc cluster)
- Three IP addresses for the Kubernetes service (one IP address per instance of the front-end UI, since they all use the same port. The backend database can use any one of the three IP addresses as long as it uses a different port).

Continuing with this example, and adding it to the following table, you get:

| Parameter    | Number of IP addresses |
|------------------|---------|
| AKS Arc VMs, K8s version upgrade, and control plane IP  | Plan for 10 IP addresses |
| Load balancer IPs | Three IP address for Kubernetes services, for Jane's voting application. |

Jane must make sure she configures a logical network with an IP pool of at least 13 IP addresses in this example scenario.

## Example CLI commands for IP address planning for Kubernetes clusters and applications

This section describes the set of commands Jane runs for her scenario. First, create a logical network with an IP pool that has at least 13 IP addresses. We created the IP pool with 20 IP addresses to provide the option to scale on day N. For detailed information about parameter options in logical networks, see [`az stack-hci-vm network lnet create`](/cli/azure/stack-hci-vm/network/lnet#az-stack-hci-vm-network-lnet-create):

```azurecli
$ipPoolStart = "10.220.32.18"
$ipPoolEnd = "10.220.32.37"
az stack-hci-vm network lnet create --subscription $subscription --resource-group $resource_group --custom-location $customLocationID --location $location --name $lnetName --ip-allocation-method "Static" --address-prefixes $addressPrefixes --no-gateway --ip-pool-start $ipPoolStart --ip-pool-end $ipPoolEnd --dns-servers $dnsServers --fabric-network-configuration-id $fabricResourceID --vlan $vlan
```

Next, create an AKS Arc cluster with the previous logical network:

```azurecli
az aksarc create -n $aksclustername -g $resource_group --custom-location $customlocationID --vnet-ids $lnetName *--generate-ssh-keys*
```

### LNET considerations for AKS clusters and Arc VMs

Logical networks on Azure Local are used by both AKS clusters and Arc VMs. You can configure logical networks in one of the following two ways:

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

Pod network CIDR is a range of IP addresses used by Kubernetes to assign unique IP addresses to the individual pods running within a Kubernetes cluster. Each pod gets its own IP address within this range, allowing pods to communicate with each other and with services within the cluster. Each pod is assigned an IP address from the pod network CIDR, but this IP address isn't directly routable on the physical network. Instead, it's encapsulated within the network packets and sent through the underlying physical network to reach its destination pod on another node.

AKS provides a default value of 10.244.0.0/16 for the pod network CIDR. AKS does support customizations for the pod network CIDR. You can specify the Pod CIDR. Ensure that the CIDR IP range is large enough to accommodate the maximum number of pods per node and across the Kubernetes cluster.

### Service network CIDR

The Service network CIDR is the range of IP addresses reserved for Kubernetes services like LoadBalancers, ClusterIP, and NodePort within a cluster. Kubernetes supports the following service types:

- ClusterIP: The default service type, which exposes the service within the cluster. The IP assigned from the Service network CIDR is only accessible within the Kubernetes cluster.
- NodePort: Exposes the service on a specific port on each node's IP address. The ClusterIP is still used internally, but external access is through the node IPs and a specific port.
- LoadBalancer: This type creates a cloud-provider-managed load balancer and exposes the service externally. The cloud provider typically manages the external IP assignment, while the internal ClusterIP remains within the service network CIDR.

AKS provides a default value of 10.96.0.0/12 for the service network CIDR. AKS doesn't support customizations for the service network CIDR today.

## Recommendations

- **Use /26 or larger subnets** for production environments to provide room for scaling clusters and adding new ones.
- **Leave the control plane IP empty** for autoallocation. We don't allow specifying the control plane IP today.
- **Plan MetalLB IP ranges** based on the total number of externally exposed services across all clusters on the network.
- **Verify no CIDR overlap** between the pod CIDR, service CIDR, and logical network subnet before creating a cluster.

## Next steps

- [Network requirements for AKS on Azure Local (multi-rack)](network-system-requirements.md)
- [Quickstart: Deploy an AKS cluster using an ARM template](resource-manager-quickstart.md)
- [AKS on Azure Local (multi-rack) cluster architecture](cluster-architecture.md)
