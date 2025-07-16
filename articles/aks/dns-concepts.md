---
title: DNS in Azure Kubernetes Service (AKS)
description: Learn how DNS operates in AKS and how to boost performance and reliability with LocalDNS caching.
ms.subservice: aks-networking
author: vaibhavarora
ms.topic: concept-article
ms.date: 07/31/2025
ms.author: vaibhavarora

# Customer intent: As a cluster operator or developer, I want to understand the defaults for DNS resolution in AKS and how I can use LocalDNS to improve my DNS resolution performance.
---
# DNS Resolution in Azure Kubernetes Service (AKS)

Domain Name System (DNS) resolution is a critical component in Azure Kubernetes Service (AKS), enabling pods and services to communicate using human-readable names instead of IP addresses. AKS provides built-in DNS services to ensure seamless name resolution for both internal cluster resources and external endpoints. Understanding how DNS works in AKS helps cluster operators and developers ensure reliable connectivity, optimize performance, and troubleshoot networking issues effectively.

## CoreDNS in Azure Kubernetes Service

[CoreDNS][coreDNS] is the default DNS service in Azure Kubernetes Service (AKS), providing internal name resolution and service discovery for workloads running in the cluster. It operates as a set of pods in the kube-system namespace and is tightly integrated with Kubernetes networking.

When a pod in AKS issues a DNS query—such as resolving the name of another service—the request is routed to the CoreDNS pods. These pods process the query and return the appropriate IP address or forward the request to an upstream DNS server for external domains.

This architecture ensures a balance between flexibility and operational safety in a managed environment. For details on how to customize CoreDNS in AKS, refer to the [CoreDNS customization guide](./coredns-custom.md).

For information on the CoreDNS project, see [the CoreDNS upstream project page][coreDNS].

## LocalDNS in Azure Kubernetes Service (Preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

> [!NOTE]
> This document provides an overview of what LocalDNS is and its benefits in AKS. It doesn't include setup instructions. For guidance on enabling and configuring LocalDNS, see the [LocalDNS how-to guide](./localdns-custom.md).

### Overview

LocalDNS is an advanced feature in Azure Kubernetes Service (AKS) that deploys a Domain Name System (DNS) proxy on each node to provide highly resilient, low-latency DNS resolution. By handling DNS queries locally, this proxy reduces traffic to the CoreDNS addon pods, improving overall DNS reliability and performance in the cluster. LocalDNS is especially beneficial in large clusters or environments with high DNS query volumes, where centralized DNS resolution can become a bottleneck.

When LocalDNS is enabled, AKS deploys a local DNS cache as a `systemd` service on each node. Pods on the node send their DNS queries to this local cache, enabling faster resolution by reducing network hops. This approach also minimizes `conntrack` table usage, lowering the risk of table exhaustion. Additionally, if upstream DNS becomes unavailable, LocalDNS can continue serving cached responses for a configurable duration, helping maintain pod connectivity and service reliability.

![Diagram that shows LocalDNS architecture.](./media/dns-concepts/local-dns-diagram.png)

### Key capabilities

- **Reduced DNS resolution latency:**
  Each AKS node runs a LocalDNS `systemd` service. Workloads running on the node send DNS queries to this service, which resolves them locally, reducing network hops and speeding up DNS lookups.

- **Customizable DNS behavior:**
  You can use `kubeDNSOverrides` and `vnetDNSOverrides` to control DNS behavior in the cluster.

- **Avoid conntrack races and conntrack table exhaustion:**
  Pods send DNS queries to the LocalDNS service on the same node without creating new `conntrack` table entries. Skipping the connection tracking helps reduce [conntrack races](https://github.com/kubernetes/kubernetes/issues/56903) and avoids User Datagram Protocol (UDP) DNS entries from filling up `conntrack` tables. This optimization prevents dropped and rejected connections caused by `conntrack` table exhaustion and race conditions.

- **Connection upgraded to TCP:**
    The connection from the `localdns` cache to the cluster’s CoreDNS service uses Transmission Control Protocol (TCP). TCP allows for connection rebalancing and removes `conntrack` table entries when the server closes the connection (in contrast to UDP connections, which have a default 30-second timeout). Applications don't need changes, because the `localdns` service still listens for UDP traffic.

- **Caching:**
  The LocalDNS cache plugin can be configured with serveStale and Time to Live (TTL) settings. `serveStale`, `serveStaleDurationInSeconds`, and `cacheDurationInSeconds` parameters can be configured to achieve DNS resiliency, even during an upstream DNS outage.

- **Protocol control:**
  You can set the DNS query protocol (such as PreferUDP or ForceTCP) for each domain. This flexibility lets you optimize DNS traffic for specific domains or meet network requirements.

### Other benefits and considerations

| Benefits | Considerations |
|----------|----------------|
| **Better scalability**: Reduces load on centralized CoreDNS pods | **Minimal resource overhead**: Uses a small amount of CPU and memory on each node |
| **Seamless integration**: Does not require changes to existing application connections |  **Configuration changes**: Updates require node image upgrades, which can cause temporary disruptions |
| **Block invalid search domains**: Prevents invalid DNS queries at the node level |

By using LocalDNS, you get faster and more reliable DNS resolution for your workloads, reduce the risk of DNS-related outages, and gain more control over DNS traffic in your AKS environment.

## Next steps

To learn how to enable LocalDNS and configure its settings in your AKS cluster, see the [LocalDNS how-to guide](./localdns-custom.md).

To learn more about core network concepts, see [Network concepts for applications in AKS][concepts-network].

<!-- LINKS - external -->
[coreDNS]: https://coredns.io/

<!-- LINKS - internal -->
[concepts-network]: concepts-network.md
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md