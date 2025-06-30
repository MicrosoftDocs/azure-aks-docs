---
title: AKS regulated cluster for PCI DSS 4.0.1 - Enhanced MFA implementation
description: Enhanced multifactor authentication (MFA) implementation guidance for AKS clusters under PCI DSS 4.0.1.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: phillipgibson
ms.author: pgibson
ms.custom:
  - pci-dss
  - compliance
---

# Enhanced multifactor authentication (MFA) for an AKS regulated cluster for PCI DSS 4.0.1

PCI DSS 4.0.1 expands MFA requirements for all access to the CDE and cloud admin access. This document provides guidance for implementing and enforcing MFA in AKS environments.

## AKS feature support

AKS provides several features to help you meet PCI DSS 4.0.1 MFA requirements:

- **Microsoft Entra ID (Azure AD) integration**: Enables centralized identity management and MFA enforcement for AKS cluster access.
- **Conditional access policies**: Allow you to require MFA for all privileged roles and access paths to AKS resources.
- **Azure Policy**: Can be used to audit and enforce MFA requirements for AKS administrators.
- **Just-in-Time (JIT) access**: Supported via Microsoft Entra Privileged Identity Management (PIM) for time-limited privileged access.

## Your responsibilities

- Enable Microsoft Entra ID integration for all AKS clusters in scope for PCI DSS.
- Configure Conditional Access policies to require MFA for all administrative and privileged access to AKS (API, CLI, portal).
- Document and test MFA enforcement for all access paths, including third-party tools and automation.
- Regularly review and update MFA policies to address new threats and changes in the AKS environment.

## Key requirements

- Enforce MFA for all administrative access to AKS clusters (API, CLI, portal).
- Integrate with Azure AD Conditional Access and identity providers.
- Document MFA policy and enforcement mechanisms.

## Implementation steps

1. Enable Azure AD integration for AKS.
2. Configure Conditional Access policies requiring MFA for all privileged roles.
3. Test and document MFA enforcement for all access paths.

## Integrated AKS security context

You should implement MFA as part of a broader security strategy that includes:

- [Identity and access management](pci-dss-identity.md) for identity and access management
- [Security policies](pci-dss-policy.md) for policy and governance
- [Monitoring and logging](pci-dss-monitor.md) for monitoring and alerting

For the latest AKS security features, see the [Azure Kubernetes Service (AKS) documentation](/azure/aks/).

## Related resources

For more information, review the official [PCI DSS 4.0.1 documentation](https://www.pcisecuritystandards.org/).
