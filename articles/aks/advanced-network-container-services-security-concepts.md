---
title: Advanced Container Networking Services for Azure Kubernetes Service (AKS)
description: An overview of Advanced Container Networking Services's Security capabilities Azure Kubernetes Service (AKS).
author: sf-msft
ms.author: samfoo
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: conceptual
ms.date: 07/30/2024
---

# What security features are available on Advanced Network Container Services?

Advanced Container Networking Services (ACNS) contains a class of security features to tackle the complexities of maintaining infrastructure for users looking to tackle these problems at scale. Users with Azure CNI Powered by Cilium have access to these features to improve network security while working in tandem with observability. Security features can add network segmentation controls to prevent lateral attacks. Azure Network Policies can be extended to include entity based policies without knowing their IP addresses.

> [!NOTE]
> Azure CNI Powered by Cilium and Kubernetes version 1.29 is required in order to use security features of Advanced Container Networking Services.

Un

## Security Features

**Traffic Filtering** - Cilium provides the tools to handle the complexity of Domain Name Server (DNS) to IP mappings though Cilium Network Policies. Users can take advantage of default deny policies extended beyond Kubernetes Network Policies.

**HA DNS Proxy** - Avoid failed DNS requests by separating DNS proxy from Cilium Agent. This is especially useful to ensure DNS requests continue to succeed when updating or in the event Cilium Agent is unavailable.

> [!NOTE]
> Cilium supports additional network policy options that are not supported at this time. Unsupported network policies applied to the cluster will be blocked. Blocked network policies may still be allowed to be applied to the cluster, but they will not be enforced by the Cilium Agent.

## Key Benefits

**Scalable** - Control traffic from an Ingress based on DNS pattern matching and labels. Policies can be applied to cases as granular as single workload on a pod to much broader scope through labels. Unlike network policy rules using IP that have to be updated each time the pod IP dynamically changes, FQDN based network policies offers much more flexibility. Avoiding frequent updates which may be error-prone allows for an easier way to manage network policies at scale.

## Next steps

* For more information about Advanced Container Networking Services for Azure Kubernetes Service (AKS), see [What is Advanced Container Networking Services for Azure Kubernetes Service (AKS)?](advanced-container-networking-services-overview.md).

* Explore more of the observability features in Advanced Container Networking Services in [What is Advanced Network Observability?](advanced-network-observability-concepts.md)