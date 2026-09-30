---
title: Network requirements for AKS on Azure Local for multi-rack deployments
description: Learn about the network requirements for deploying AKS enabled by Azure Arc clusters on Azure Local (multi-rack), including logical network configuration, IP address requirements, and port requirements.
ms.topic: concept-article
ms.date: 09/01/2026
ms.author: sanjanamohan
ms.custom: multi-rack
author: sanjanamsft
---

# Network requirements for AKS on Azure Local (multi-rack)

This article introduces core networking concepts for your VMs and applications in AKS enabled by Azure Arc. The article also describes the required networking prerequisites for creating Kubernetes clusters. We recommend that you work with a network administrator to provide and set up the networking parameters required to deploy AKS enabled by Arc.

In this conceptual article, the following key components are introduced.

- Logical network for AKS Arc VMs and control plane IP
- Load balancer for containerized applications

## Logical networks for AKS Arc VMs and control plane IP

Kubernetes nodes are deployed as specialized virtual machines in AKS enabled by Arc. These VMs are allocated IP addresses to enable communication between Kubernetes nodes. AKS Arc uses Azure Local logical networks to provide IP addresses and networking for the underlying VMs of the Kubernetes clusters. For more information about logical networks, see [Logical networks for Azure Local](/azure/azure-local/multi-rack/multi-rack-create-logical-networks). You must plan for one IP address per AKS cluster node VM in your Azure Local environment.

AKS clusters on Azure Local (multi-rack) require a logical network with the following configuration:

| Requirement | Details |
| ----------- | ------- |
| **Static** | Only LNETs with ip-allocation-type "Static" supported. Assignment of IP addresses to AKS Arc VMs from these known static IP pools is done automatically. |
| **Subnet size** | The subnet must be /28 or larger (minimum 16 addresses). Size the subnet based on the total number of nodes across all clusters you plan to deploy. For more information, see [Plan IP addresses](plan-aks-ip-address.md) for sizing guidance. |
| **Provisioning** | The logical network must be provisioned before creating AKS clusters. |

The following parameters are required in order to use a logical network for AKS Arc cluster create operation:

| [Az CLI logical networks parameter](/azure/azure-local/manage/create-logical-networks?tabs=azurecli) | Description| Required parameter for AKS Arc cluster|
|------------------|---------|-----------|
| `--address-prefixes` | AddressPrefix for the network. Currently only one address prefix is supported. Usage: `--address-prefixes "10.220.32.16/24"`. | ![Supported](media/network-system-requirements/check.png) |
| `--dns-servers`      | Space-separated list of DNS server IP addresses. Usage: `--dns-servers 10.220.32.16 10.220.32.17`. | Optional, but highly recommended |
| `--no-gateway`         | Specify `--no-gateway`. | ![Supported](media/network-system-requirements/check.png) |
| `--ip-allocation-method`         | The IP address allocation method. Supported values are `Static`. Usage: `--ip-allocation-method "Static"`. | ![Supported](media/network-system-requirements/check.png) |
| `--fabric-network-configuration-id`     | Azure Resource Manager resource ID of the Layer 3 Internal Network. | ![Supported](media/network-system-requirements/check.png) |
| `--ip-pool-start`     | If you use MetalLB or any other non-Microsoft load balancer in L2/ARP mode, we highly recommend using IP pools to separate AKS Arc IP requirements from load balancer IPs. This recommendation is to help avoid IP address conflicts that can lead to unintended and hard-to-diagnose failures. This value is the start IP address of your IP pool. The address must be in the range of the address prefix. Usage: `--ip-pool-start "10.220.32.18"`.  | Optional, but highly recommended. |
| `--ip-pool-end`       | If you use MetalLB or any other non-Microsoft load balancer in L2/ARP mode, we highly recommend using IP pools to separate AKS Arc IP requirements from load balancer IPs. This recommendation is to help avoid IP address conflicts that can lead to unintended and hard-to-diagnose failures. This value is the end IP address of your IP pool. The address must be in the range of the address prefix. Usage: `--ip-pool-end "10.220.32.38"`.  | Optional, but highly recommended. |

## IP address requirements

For detailed IP planning guidance and examples, see [Plan IP addresses for AKS on Azure Local (multi-rack)](plan-aks-ip-address.md).

## Control plane IP

Kubernetes uses a control plane to ensure every component in the Kubernetes cluster is kept in the desired state. The control plane also manages and maintains the worker nodes that hold the containerized applications. AKS enabled by Arc deploys the KubeVIP load balancer to ensure that the API server IP address of the Kubernetes control plane is always available. This KubeVIP instance requires a single immutable "control plane IP address" to function correctly.

**Auto-allocation (only supported mode)**: By default, the control plane endpoint IP is automatically allocated from the logical network subnet. We only support system-assigned control plane IPs currently.

> [!NOTE]
> You can't specify the control plane IP because it's system assigned.

## Load balancer IPs for containerized applications

The main purpose of a load balancer is to distribute traffic across multiple nodes in a Kubernetes cluster. This load balancing can help prevent downtime and improve overall performance of application. The _MetalLB extension for Azure Arc enabled Kubernetes_ is a tool that allows you to generate external IPs for your applications and services. Arc-enabled Kubernetes clusters can integrate with MetalLB using the extension for MetalLB for Azure Arc enabled Kubernetes.

You must provide a set of IP addresses to the load balancer service. You have the following options:

- Provide IP addresses for your services from the same subnet as the AKS Arc VMs.
- Use a different network and list of IP addresses if your application needs external load balancing.

Regardless of the option you choose, you must ensure that the IP addresses allocated to the load balancer don't conflict with the IP addresses in the logical network. Conflicting IP addresses can lead to unforeseen failures in your AKS deployment and applications.

For more information about configuring MetalLB, see [Deploy MetalLB load balancer using Azure Arc extension](/azure/aks/aksarc/deploy-metallb).

## Proxy configuration

In Azure Local for multi-rack deployments, users can optionally provide a proxy for workload AKS Arc cluster traffic. For example, customer image pulls from a container registry. This proxy isn't used for any infrastructure or control plane traffic.

The proxy must be set up before you create the AKS Arc cluster and must be reachable from the logical network of the AKS Arc cluster. The proxy endpoint is specified as an

```json
{
  "type": "Microsoft.HybridContainerService/provisionedClusterInstances",
  "apiVersion": "2024-01-01",
  "name": "default",
  "tags": {
    "https-proxy": "https://<proxyIPAddress>:3128"
  },
  ...
}
```

The proxy tag can be updated post-cluster creation, if needed. This proxy applies to all nodes in the cluster. A proxy can't be configured per node pool.

> [!NOTE]
> The proxy endpoint must be an IPv4 address. IPv6 isn't supported.

## Software Defined Networking (SDN)

SDN isn't supported for AKS on Azure Local. Use logical networks without SDN for AKS cluster networking.

## Next steps

- [Plan IP addresses for AKS on Azure Local (multi-rack)](plan-aks-ip-address.md)
- [Quickstart: Deploy an AKS Arc cluster using an Azure Resource Manager template](resource-manager-quickstart.md)
- [AKS on Azure Local (multi-rack) cluster architecture](cluster-architecture.md)
