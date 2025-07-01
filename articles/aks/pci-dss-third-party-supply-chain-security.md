---
title: AKS regulated cluster for PCI DSS 4.0.1 - Third-party and supply chain security
description: Third-party and supply chain security guidance for AKS clusters for PCI DSS 4.0.1.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: phillipgibson
ms.author: pgibson
ms.custom:
  - pci-dss
  - compliance
---

# Third-party and supply chain security for an AKS regulated cluster for PCI DSS 4.0.1

PCI DSS 4.0.1 expands requirements for managing third-party service providers and supply chain risk. This document provides guidance for managing dependencies, images, and providers in AKS.

## AKS feature support

AKS provides several features to help you meet PCI DSS 4.0.1 third-party and supply chain security requirements:

- **Microsoft Defender for Cloud**: Monitors third-party images and dependencies for vulnerabilities and compliance in AKS clusters.
- **Azure Policy**: Enforces approved image registries and controls deployment of third-party components.
- **Azure Container Registry (ACR) Tasks**: Supports automated image scanning and approval workflows for container images.
- **Azure Monitor**: Tracks provider activity and compliance status for third-party integrations.

## Your responsibilities

- Maintain an up-to-date inventory of all third-party components, images, and service providers used in AKS workloads.
- Enforce vulnerability scanning and approval for all dependencies and images before deployment.
- Monitor provider compliance and security posture using Defender for Cloud and Azure Monitor.
- Document contracts, SLAs, and security requirements for all third-party providers with access to the CDE.
- Regularly review and update supply chain security controls as new risks and dependencies emerge.

## Key practices

- Maintain an inventory of all third-party components and images.
- Enforce vulnerability scanning and approval for all dependencies.
- Monitor provider compliance and security posture.
- Document contracts and SLAs with third-party providers.

## Integrated AKS security context

You should implement third-party and supply chain security as part of a broader security strategy that includes:

- [Security policies](pci-dss-policy.md) for policy and governance.
- [Identity and access management](pci-dss-identity.md) for identity and access management.
- [Monitoring and logging](pci-dss-monitor.md) for monitoring and alerting.

For the latest AKS security features, see the [Azure Kubernetes Service (AKS) documentation](/azure/aks/).

## Related resources

For more information, review the official [PCI DSS 4.0.1 documentation](https://www.pcisecuritystandards.org/).
