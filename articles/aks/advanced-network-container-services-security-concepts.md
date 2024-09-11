---
title: FQDN filtering for enhanced security with Advanced Container Networking Services
description: An overview of Advanced Container Networking Services' Security capabilities using FQDN filtering on Azure Kubernetes Service (AKS).
author: sf-msft
ms.author: samfoo
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: conceptual
ms.date: 07/30/2024
---

# FQDN filtering for enhanced security with Advanced Container Networking Services

## Overview of FQDN filtering

Advanced Container Networking Services (ACNS) offers advanced observability and security features to address the complexities of maintaining microservices infrastructure for users looking to tackle these problems at scale.

Containerized environments present unique security challenges. Traditional network security methods, often reliant on IP-based filtering, can become cumbersome and less effective as IP addresses frequently change. Additionally, understanding network traffic patterns and identifying potential threats can be complex.

FQDN filtering offers an efficient and user-friendly approach for managing network policies. By defining these policies based on domain names rather than IP addresses, organizations can significantly simplify the process of policy management. This approach eliminates the need for frequent updates that are typically required when IP addresses change, as a result reducing the administrative burden and minimizing the risk of configuration errors.

In a Kubernetes cluster, pod IP addresses can change often, which makes it challenging to secure the pods with security policies using IP addresses. FQDN filtering allows you to create pod level policies using domain names rather than IP addresses, which eliminates the need to update policies when an IP address changes.

> [!NOTE]
> Azure CNI Powered by Cilium and Kubernetes version 1.29 or greater is required in order to use security features of Advanced Container Networking Services like FQDN filtering.

## Components of FQDN filtering

**Cilium Agent**: The Cilium Agent is a critical networking component that runs as a DaemonSet within Azure CNI clusters powered by Cilium. It handles networking, load balancing, and network policies for pods in the cluster. For pods with enforced FQDN policies, the Cilium Agent redirects packets to the DNS Proxy for DNS resolution and updates the network policy using the FQDN-IP mappings obtained from the DNS Proxy.

**ACNS DNS Proxy**: ACNS DNS Proxy runs as DaemonSet in Azure CNI powered by Cilium cluster with Advanced Container Networking services enabled. It handles DNS resolution for pods and on successful DNS resolution, it updates Cilium Agent with FQDN to IP mappings.

## How ACNS DNS Proxy ensures high availability

ACNS DNS Proxy running separately from the Cilium Agent ensures that pods continue to have DNS resolution even if the Cilium Agent is down or undergoing an upgrade. Using Kubernetes' maxSurge upgrade feature keeps the DNS Proxy operational during upgrades. This component guarantees that network connectivity for essential customer workloads isn't disrupted by DNS resolution issues.

> [!NOTE]
> High availability applies to DNS name resolution and not policy enforcement. If the Cilium agent goes down, existing policies based on the last resolved IP addresses will still continue to be enforced. However, any IP address changes at this time, even though they are resolved by DNS, will not get updated in the policies until the Cilium agent is back in service.

## How FQDN filtering works

When FQDN Filtering is enabled, DNS requests are first evaluated to determine if they should be allowed after which pods can only access specified domain names based on the network policy. The Cilium Agent marks DNS request packets originating from the pods, redirecting them to the DNS Proxy. This redirection occurs only for pods that are enforcing FQDN policies.

The DNS Proxy then decides whether to forward a DNS request to the DNS server based on the policy criteria. If permitted, the request is sent to the DNS server, and upon receiving the response, the DNS Proxy updates the Cilium Agent with FQDN mappings. This allows the Cilium Agent to update the network policy within the policy engine. The following image illustrates the high-level flow of FQDN Filtering.

:::image type="content" source="./media/how-dns-proxy-works.png" alt-text="Screenshot showing how DNS Proxy works in FQDN filtering.":::

## Key benefits

**Scalable security policy management**: Cluster and security admins don't have to update security policies each time an IP address changes making operations more efficient.

**Enhanced security compliance**: FQDN filtering supports a zero trust security model. Network traffic is restricted to trusted domains only mitigating risks from unauthorized access.

**Resilient Policy enforcement**: The DNS proxy that is implemented with FQDN filtering ensures that DNS resolution continues seamlessly even if the Cilium agent goes down and policies continue to remain enforced. This implementation critically ensures that security and stability are maintained in dynamic and distributed environments.

## Next steps

* Learn how to enable [FQDN Filtering](advanced-network-container-services-security-cli.md) on AKS.

* Explore how the open source community builds [Cilium Network Policies](https://docs.cilium.io/en/latest/security/policy/).

> [!NOTE]
> Cilium supports additional network policy options that are not supported for AKS at this time. Unsupported network policies applied to the cluster will be blocked. Blocked network policies may be applied to the cluster, but they will not be enforced by the Cilium Agent.

* For more information about Advanced Container Networking Services for Azure Kubernetes Service (AKS), see [What is Advanced Container Networking Services for Azure Kubernetes Service (AKS)?](advanced-container-networking-services-overview.md).

* Explore more of the observability features in Advanced Container Networking Services in [What is Advanced Network Observability?](advanced-network-observability-concepts.md).
