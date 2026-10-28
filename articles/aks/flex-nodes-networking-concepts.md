---
title: Networking concepts for flex nodes (preview)
description: Learn how to plan API access, node and pod connectivity, address ranges, and customer-managed networking for flex nodes in AKS.
ms.topic: concept-article
ms.date: 08/28/2026
author: sdesai345
ms.author: sachidesai
ms.subservice: aks-nodes
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
---

# Networking concepts for flex nodes in Azure Kubernetes Service (AKS) (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Flex nodes connect customer-managed Linux host machines to an Azure Kubernetes Service (AKS) cluster. Before you attach a host, plan how it reaches the AKS API server and how nodes, pods, and Kubernetes services communicate across the cluster.

## Understand the flex nodes networking model

Flex nodes use a bring-your-own networking model during public preview. You provide and maintain connectivity between the customer-managed host environment and the AKS cluster.

AKS-managed network plugins, including Azure Container Networking Interface (CNI) and Azure CNI Powered by Cilium, don't run on flex nodes during public preview. You can attach a flex node to an existing cluster that uses one of these plugins, but the plugin's pod networking, network identity, and network policy capabilities don't extend to the flex node.

The end-to-end configuration documented in [Configure networking and create a flex node pool in AKS](./configure-flex-nodes-networking.md) creates an AKS cluster without a built-in network plugin and deploys [Unbounded-Net](https://aka.ms/unbounded/github) networking on both the AKS nodes in Azure and flex nodes. Other compatible customer-managed Container Network Interface (CNI) configurations can have different requirements and support boundaries.

## Understand multi-location pod networking

A standard CNI commonly assumes that cluster nodes already have direct network reachability. Flex nodes can run in a different Azure virtual network, region, data center, edge location, or third-party environment. Pod networking for flex nodes adds the address allocation and routing needed to connect those locations.

Flex nodes thus require a networking configuration that:

- Assigns pod address ranges to nodes without creating duplicate pod IP addresses.
- Configures local pod networking on every participating node.
- Routes pod traffic between AKS-managed nodes and flex nodes.
- Uses an existing Layer 3 path directly when both locations can reach each other's node addresses.
- Supports an encrypted gateway path for topologies that communicate over a public network.

This networking layer has two types of components. A controller manages node placement, pod address allocation, and cross-location routing state. A node agent runs on every participating AKS standard node and flex node to configure local pod networking and routes.

When a new flex node joins the cluster, the networking controller matches its internal IP address to a network location's node CIDR. The node then receives pod addresses from that location's pod CIDR.

## Make two independent network decisions

Plan AKS API exposure and flex node connectivity separately. 

> [!NOTE]
> Choosing a public or private API endpoint doesn't determine how workload traffic moves between nodes and pods.

- AKS API exposure: The first path connects the network administrator and customer-managed flex host to the AKS API server. A public AKS cluster exposes a secured public API endpoint. A private AKS cluster requires private network access and private DNS. 
- Flex node connectivity: This path connects AKS standard nodes, flex nodes, pods, and Kubernetes services. It also provides the callback path from the API server to the flex node for operations such as logs, command execution, and port forwarding.

## Plan nonoverlapping address ranges

Plan separate address ranges for each part of the deployment:

| Address range | Purpose |
| --- | --- |
| **AKS node subnet and site node CIDR** | Addresses that identify AKS standard nodes as members of the AKS site. |
| **AKS pod CIDR** | Address pool from which per-node pod ranges are allocated to AKS standard nodes. |
| **Flex host subnet and site node CIDR** | Addresses that identify customer-managed hosts as members of the flex site. |
| **Flex pod CIDR** | Address pool from which per-node pod ranges are allocated to flex nodes. |
| **Kubernetes service CIDR** | Virtual addresses used by Kubernetes services. |

The AKS node, AKS pod, flex node, flex pod, and Kubernetes service ranges **should not** overlap each other or any network reachable through peering, VPN, or ExpressRoute. Each subnet must be contained within its corresponding site node CIDR. The DNS service IP must be inside the Kubernetes service CIDR.

Azure can detect some address conflicts, but it can't validate every external or routed network. Coordinate the final address plan with your network administrator.

## Flex nodes networking responsibilities

AKS provides the Kubernetes control plane, flex node pool, and machine resources. You're responsible for the external host network and the selected customer-managed multi-location CNI.

Customer responsibilities include:

- Routing between the AKS and flex host networks.
- Virtual network peering, VPN, ExpressRoute, or gateway configuration when required.
- Firewall and network security group rules.
- DNS, proxy, and outbound access configuration.
- Networking controller and node-agent installation, upgrades, health, and compatibility on all participating nodes.
- Validation of node, pod, service, DNS, outbound, and callback connectivity.

## Next steps

- [Plan a flex nodes deployment](plan-flex-nodes-deployment.md).
- [Configure networking and create a flex node pool](configure-flex-nodes-networking.md).
