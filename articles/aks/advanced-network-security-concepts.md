---
title: Advanced Network Security - Advanced Container Networking Services for Azure Kubernetes Service (AKS)
description: An overview of Advanced Container Networking Services'a Advanced Network Security capabilities Azure Kubernetes Service (AKS).
author: sf-msft
ms.author: samfoo
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: conceptual
ms.date: 07/30/2024
---

# What is Advanced Network Security?

Advanced Network Security is a subset of Advanced Container Networking Services. Users with Azure CNI Powered by Cilium have access to more security capabilities. It provides a bundle of features to improve network security while working in tandem with observability. Features provided in Advanced Network Security can add network segmentation controls to prevent lateral attacks. Azure Network Policies can be extended to include entity based policies without knowing their IP addresses.

> [!NOTE]
> A managed Cilium data plane is required for Advanced Networking Security. Advanced Network Security is available beginning with Kubernetes version 1.29.

## Features of Advanced Network Security

**Traffic Filtering** - Cilium provides the tools to handle the complexity of DNS to IP mappings though Cilium Network Policies. Users can take advantage of default deny policies extended beyond Kubernetes Network Policies.

**HA DNS Proxy** - Avoid a mode of DNS failure by separating DNS proxy from Cilium Agent. This is especially useful to ensure DNS requests continue to succeed when updating or rolling out Cilium Agent.

> [!NOTE]
> A Cilium data plane is required for Advanced Networking Security. Advanced Network Security is available beginning with Kubernetes version 1.29.

## Key Benefits of Advanced Network Security

**Ease of Use** - Control traffic from an Ingress based on DNS pattern matching and labels.

**Robust** - Advanced Network Security aims to be a highly granular solution for rules defined between between Layer 3, 4, and 7 of the OSI model.

## Next steps

* For more information about Advanced Container Networking Services for Azure Kubernetes Service (AKS), see [What is Advanced Container Networking Services for Azure Kubernetes Service (AKS)?](advanced-container-networking-services-overview.md).