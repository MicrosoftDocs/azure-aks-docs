---
title: Advanced Container Networking Services (ACNS) for the Azure Kubernetes Service (AKS)
description: Discover how  Advanced Container Networking Services (ACNS) empowers your AKS clusters with Container Network Observability and Container Network Security features.
author: Khushbu-Parekh
ms.author: kparekh
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: overview
ms.date: 05/28/2024
---

# What is Advanced Container Networking Services (ACNS)?

Advanced Container Networking Services is a suite of services built to significantly enhance the operational capabilities of your Azure Kubernetes Service (AKS) clusters. The suite is comprehensive and is designed to address the multifaceted and intricate needs of modern containerized applications. With capabilities tailored for observability, security, and compliance, customers can unlock a new approach to managing container networking.

With Advanced Container Networking Services, the focus is on delivering a seamless and integrated experience that empowers you to maintain robust security postures, ensure comprehensive compliance and gain deep insights into your network traffic and application performance. This ensures that your containerized applications are not only secure and compliant but also meet or exceed your performance and reliability goals, allowing you to confidently manage and scale your infrastructure.

## What is included in Advanced Container Networking Services?

Advanced Container Networking Services contains features split into two pillars:

 - **Observability**: The inaugural feature of the Advanced Container Networking Services suite bringing the power of Hubble’s control plane to both Cilium and non-Cilium Linux data planes. These features aim to provide visibility into networking and performance.

 - **Security**: For clusters using Azure CNI Powered by Cilium, network policies include fully qualified domain name (FQDN) filtering for tackling the complexities of maintaining configuration.

## Container Network Observability
 Container Network Observability equips you with next-level monitoring and diagnostics tools, providing unparalleled visibility into your containerized workloads. It unlocks Hubble metrics, Hubble’s command line interface (CLI) and the Hubble user interface (UI) on your AKS clusters providing deep, actionable insights into your containerized workloads. It allows you to precisely detect and determine the root causes of network-related issues in AKS through its next-level monitoring and diagnostics tools. These features ensure that your containerized applications are secure and compliant in order to empower you to confidently manage your infrastructure.

For more information about Container Network Observability, see [What is Container Network Observability?](container-network-observability-concepts.md).

## Container Network Security

Container Network Security features within Advanced Container Networking Services enable greater control over network security policies for ease of use when implementing across clusters. Clusters using Azure CNI Powered by Cilium have access to DNS-based policies. The ease of use compared to IP-based policies allows restricting egress access to external services using domain names. Configuration management becomes simplified by using FQDN rather than dynamically changing IPs.

## Pricing
> [!IMPORTANT]
> Advanced Container Networking Services is a paid offering. For more information about pricing, see [Advanced Container Networking Services - Pricing](https://azure.microsoft.com/pricing/details/azure-container-networking-services/)
## Next steps

* For more information about Container Network Observability and its capabilities, see [What is Container Network Observability?](advanced-network-observability-concepts.md).

* For more information on Container Network Security and its capabilities, see [What  is Container Network Security?](advanced-network-container-services-security-concepts.md)