---
title: eBFP Host Routing with Advanced Container Networking Services (ACNS)
description: An overview of eBPF Host Routing on Advanced Container Networking Services with Azure Kubernetes Service (AKS).
author: sf-msft
ms.author: samfoo
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: concept-article
ms.date:  09/23/2025
---

# Overview of eBPF Host Routing (Public Preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

As containerized workloads scale across distributed environments, the need for high-performance, low-latency networking becomes critical. eBPF Host Routing is a performance-focused feature within [Advanced Container Networking Services (ACNS)](advanced-container-networking-services-overview.md) that uses extended Berkeley Packet Filter (eBPF) technology to optimize traffic flow in Kubernetes clusters. Legacy routing on Kubernetes hosts introduces overhead in the form of iptables and netfilter rule processing in the host network namespace. eBPF Host Routing has benefits over legacy host routing by:

 - Implementing the routing logic in eBPF programs.
 - Allowing Cilium to make routing decisions without invoking iptables or the host stack.

This direct path reduces the number of hops and processing layers, resulting in faster packet delivery.

## Key benefits

Reduced latency - Bypassing iptables in host results in lower pod-to-pod latency

Increased throughput - Compared to legacy routing, significant improvements can be observed for pod-to-pod traffic between nodes

Reduced CPU usage - Due to removing iptables-based SNAT and routing logic, a modest reduction of CPU usage

Use cases for eBPF Host Routing are performance-critical workloads such as high-throughput microservices, real-time services, or AI/ML workloads. Ensure deployment environment meets the requirements before enabling.

## Components of eBPF Host Routing

**`iptables blocker`** - An init container that prevents any future installation of iptables rules in the host network namespace (such rules will be bypassed when eBPF host routing is enabled).

**`iptables monitor`** - Checks whether any user-installed iptables rules are already present in the host network namespace. If yes, this init container prevents Cilium agent from starting until the rules are removed.

**`IP Masquerade Agent`** - When eBPF Host Routing is active, Cilium takes over SNAT responsibilities using BPF-based masquerading thus making ip-masq-agent technically redundant. This agent remains running to maintain consistent behavior if eBPF Host Routing is later disabled; however, its iptables rules are ignored while eBPF Host Routing is active.

## Considerations

Enabling eBPF Host Routing causes iptables rules in the host network namespace to be bypassed. Hence, AKS attempts to detect and block enablement of eBPF Host Routing on clusters where iptables rules are in use in the host network namespace.

 - On clusters with eBPF host routing enabled, AKS blocks attempts to install iptables rules in the host network namespace. Trying to bypass this block may cause the cluster to be inoperational.

 - eBPF host routing is currently incompatible with nodes running OSes other than Ubuntu 24.04, or Azure Linux 3.0. eBPF host routing is currently also not supported with Confidential VMs and Pod Sandboxing

## Limitations

 - eBPF Host Routing can only be enabled for all nodes in a cluster. Hybrid node scenarios aren't supported.

 - Windows nodes aren't supported by Azure CNI Powered by Cilium, and by extension, eBPF Host Routing.

 - Istio add-on can't be used along with eBPF Host Routing enabled clusters.

 - Dual stack networking isn't supported.

## Pricing

> [!IMPORTANT]
> Advanced Container Networking Services is a paid offering. For more information about pricing, see [Advanced Container Networking Services - Pricing](https://azure.microsoft.com/pricing/details/azure-container-networking-services/).

## Next steps

- Learn how to enable [eBPF Host Routing](./how-to-enable-ebpf-host-routing.md) on AKS.

- For more information about Advanced Container Networking Services for Azure Kubernetes Service (AKS), see [What is Advanced Container Networking Services for Azure Kubernetes Service (AKS)?](advanced-container-networking-services-overview.md).

- Explore Container Network Observability features in Advanced Container Networking Services in [What is Container Network Observability?](container-network-observability-metrics.md).
