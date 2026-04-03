---
title: Troubleshoot SNAT Port Exhaustion for a Standard Load Balancer in Azure Kubernetes Service (AKS)
description: Learn how to troubleshoot SNAT port exhaustion issues for a Standard Load Balancer in Azure Kubernetes Service (AKS).
ms.topic: troubleshooting-general
ms.date: 01/23/2024
ms.author: davidsmatlak
author: davidsmatlak
ms.service: azure-kubernetes-service
# Customer intent: As a cluster operator or developer using AKS with a Standard Load Balancer, I want to troubleshoot SNAT port exhaustion issues to ensure reliable outbound connectivity for my applications.
---

# Troubleshoot SNAT port exhaustion for a Standard Load Balancer in Azure Kubernetes Service (AKS)

If you know that you're starting many outbound TCP or UDP connections to the same destination IP address and port, and you observe failing outbound connections or support notifies you that you're exhausting SNAT ports, you have several general mitigation options. Review these options and decide what's best for your scenario. It's possible that one or more can help manage your scenario. For detailed information, review the [outbound connections troubleshooting guide](/azure/load-balancer/troubleshoot-outbound-connection).

The root cause of SNAT exhaustion is frequently an anti-pattern for how outbound connectivity is established, managed, or configurable timers changed from their default values.

This article helps you troubleshoot SNAT port exhaustion issues when using a Standard Load Balancer in Azure Kubernetes Service (AKS).

## Steps to troubleshoot SNAT port exhaustion

Use the following steps to troubleshoot SNAT port exhaustion:

1. Check if your connections remain idle for a long time and rely on the default idle timeout for releasing that port. If so, the default timeout of 30 minutes might need to be reduced for your scenario.
1. Investigate how your application creates outbound connectivity (for example: code review or packet capture).
1. Determine if this activity is expected behavior or whether the application is misbehaving. Use [metrics](/azure/load-balancer/load-balancer-standard-diagnostics) and [logs](/azure/load-balancer/monitor-load-balancer) in Azure Monitor to substantiate your findings. For example, use the "Failed" category for SNAT connections metric.
1. Evaluate if appropriate [design patterns](#snat-port-exhaustion-design-patterns) are followed.
1. Evaluate if SNAT port exhaustion should be mitigated with [more outbound IP addresses and allocated outbound ports](./configure-load-balancer-standard.md#configure-the-allocated-outbound-ports).

## SNAT port exhaustion design patterns

Take advantage of connection reuse and connection pooling whenever possible. These patterns help you avoid resource exhaustion problems and result in predictable behavior.

- Atomic requests (one request per connection) generally aren't a good design choice. Such anti-patterns limit scale, reduce performance, and decrease reliability. Instead, reuse HTTP/S connections to reduce the numbers of connections and associated SNAT ports. The application scale increases and performance improves because of reduced handshakes, overhead, and cryptographic operation cost when using TLS.
- If you're using out of cluster/custom DNS, or custom upstream servers on coreDNS, keep in mind that DNS can introduce many individual flows at volume when the client isn't caching the DNS resolvers result. Make sure to customize coreDNS first instead of using custom DNS servers and to define a good caching value.
- UDP flows (for example, DNS lookups) allocate SNAT ports during the idle timeout. The longer the idle timeout, the higher the pressure on SNAT ports. Use short idle timeout (for example, 4 minutes).
- Use connection pools to shape your connection volume.
- Never silently abandon a TCP flow and rely on TCP timers to clean up flow. If you don't let TCP explicitly close the connection, state remains allocated at intermediate systems and endpoints, and it makes SNAT ports unavailable for other connections. This pattern can trigger application failures and SNAT exhaustion.
- Don't change OS-level TCP close related timer values without expert knowledge of impact. While the TCP stack recovers, your application performance can be negatively affected when the endpoints of a connection have mismatched expectations. Wishing to change timers is usually a sign of an underlying design problem. Review following recommendations.

## Next steps

To learn more about AKS Standard Load Balancer configuration options, see [Configure your public standard load balancer in AKS](configure-load-balancer-standard.md).
