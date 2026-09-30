---
title: Overview of MetalLB for Kubernetes clusters
description: Learn the basic concepts of MetalLB load balancing for AKS Hybrid and Edge Kubernetes clusters.
ms.topic: concept-article
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.reviewer: xinyuhe
ms.lastreviewed: 04/02/2024
ms.custom: hyperconverged
---

# Overview of MetalLB for Kubernetes clusters

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

When you set up your AKS cluster, you need a way to make your services accessible outside the cluster. The `LoadBalancer` type is ideal for this accessibility, but the external IP remains pending. The *MetalLB extension for Azure Arc enabled Kubernetes* is a tool that allows you to generate external IPs for your applications and services. Arc-enabled Kubernetes clusters can integrate with [MetalLB](https://metallb.universe.tf/configuration/) using the extension for MetalLB for Azure Arc enabled Kubernetes.

To make your services accessible outside the cluster, MetalLB needs IP addresses. MetalLB takes care of assigning and releasing these addresses as needed when you create services, but it only distributes IPs that are in its configured pools. When MetalLB assigns an external IP address to a service, it informs the network outside the cluster that this IP belongs to the cluster. This communication is done using standard network protocols like Address Resolution Protocol (ARP) or Border Gateway Protocol (BGP).

- Layer 2 mode (ARP): In layer 2 mode, one K8s node in the cluster takes ownership of the service, and uses standard address discovery protocols (ARP for IPv4) to make those IPs reachable on the local network. From the LAN's point of view, the announcing machine simply has multiple IP addresses.
- BGP: In BGP mode, all machines in the cluster establish BGP peering sessions with nearby routers that you control, and the machines tell those routers how to forward traffic to the service IPs. Using BGP enables true load balancing across multiple nodes, and fine-grained traffic control due to BGP policy mechanisms.

MetalLB has two components:

- Controller: responsible for allocating IP for each service of `type=loadbalancer`.
- Speaker: responsible for advertising the IP using `ARP` or `BGP` protocol. To satisfy the high availability (HA) requirement, the speaker deployment is a daemonset.

> [!NOTE]
>
> - Speaker pods use the host network; i.e., their IP is the node IP, so that they can directly send broadcast messages via the host network interface.
> - The controller pod is a normal pod that lives in any node in the cluster.

:::image type="content" source="../../media/load-balancer-overview/metallb-architecture.png" alt-text="MetalLB Architecture" lightbox="../../media/load-balancer-overview/metallb-architecture.png":::

- In ARP mode, one of the speaker pods is selected as the leader. It then advertises the IP using an ARP broadcast message, binding the IP with the MAC address of the node it lives in. Thus, all traffic first hits one node, and then kube-proxy spreads it evenly to all the backend pods of the service.
- In BGP mode, all cluster nodes establish connections with all BGP peers created in the **BGP Peers** tab. Typically a BGP peer is a TOR switch. In order to broadcast the BGP routing information, the BGP peers must be configured so that they recognize the IP and ASN of cluster nodes. When you use BGP with ECMP (Equal-Cost MultiPath), traffic hits evenly across all nodes, and therefore achieves true load balancing.

## Compare MetalLB L2 (ARP) and BGP modes

The choice between L2 and BGP mode with MetalLB depends on your specific requirements, network infrastructure, and deployment scenarios:

| Aspect                      | MetalLB in L2 (ARP) mode          | MetalLB in BGP mode            |
|-----------------------------|----------------------------------|----------------------------------|
| Overview | In layer 2 mode, one K8s node assumes the responsibility of advertising a service to the local network. From the network perspective, it looks like the K8s node has multiple IP addresses assigned to its network interface. | In BGP mode, each K8s node in your cluster establishes a BGP peering session with your network routers, and uses that peering session to advertise the IPs of external cluster services. |
| IP address assignment       | MetalLB IP address pools must be in the same subnet as the K8s nodes.   | MetalLB IP address pools can be in a different network than the K8s nodes. |
| Configuration complexity    | Low. Since you're providing IP addresses in the same network as your Kubernetes nodes, you only need to specify an IP CIDR or IP pool while setting up MetalLB. | High. Configuring BGP requires knowledge of BGP protocol and an understanding of your network infrastructure. |
| Scalability                 | Limited to Layer 2 networks, suitable for small to medium-sized K8s deployments. | Suitable for complex network topologies and large-scale K8s deployments. |
| Compatibility with infrastructure network | Works with any network, but can cause ARP flooding in large K8s clusters, since a single IP is used for all services, and the service's ingress bandwidth is limited to the bandwidth of a single node. | Requires BGP support in the network infrastructure. |
| Traffic engineering         | Limited control over traffic routing. | Fine-grained control over traffic routing using BGP attributes. |
| External connectivity       | Requires more configuration for external connectivity. | Provides seamless connectivity with external networks using BGP routing. |

## FAQ

### Can a MetalLB instance be reused across AKS clusters?

No, MetalLB can't be reused across AKS clusters. MetalLB lives as pods in a Kubernetes cluster, and load balancers are custom resources (CRs). You must install the MetalLB Arc **k8s-extension** using Azure CLI, the Azure portal or Azure Resource Manager templates, and create load balancers for every AKS cluster.

## Next steps

[Deploy MetalLB using Azure portal](deploy-load-balancer-portal.md)
