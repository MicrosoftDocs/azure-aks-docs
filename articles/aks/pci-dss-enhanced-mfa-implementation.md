---
title: AKS regulated cluster for PCI DSS 4.0.1 - Enhanced MFA implementation
description: Enhanced mfa implementation guidance for AKS clusters.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: phillipgibson
ms.author: pgibson
ms.custom:
  - pci-dss
  - compliance
---

# AKS regulated cluster for PCI DSS 4.0.1 - Enhanced MFA implementation

PCI DSS 4.0.1 expands MFA requirements for all access to the CDE and cloud admin access. This document provides guidance for implementing and enforcing MFA in AKS environments.

## AKS Feature Support

- **Microsoft Entra ID (Azure AD) Integration**: Enables centralized identity management and MFA enforcement for AKS cluster access.
- **Conditional Access Policies**: Allow you to require MFA for all privileged roles and access paths to AKS resources.
- **Azure Policy**: Can be used to audit and enforce MFA requirements for AKS administrators.
- **Just-in-Time (JIT) Access**: Supported via Microsoft Entra Privileged Identity Management (PIM) for time-limited privileged access.

## Your Responsibilities

- Enable Microsoft Entra ID integration for all AKS clusters in scope for PCI DSS.
- Configure Conditional Access policies to require MFA for all administrative and privileged access to AKS (API, CLI, portal).
- Document and test MFA enforcement for all access paths, including third-party tools and automation.
- Regularly review and update MFA policies to address new threats and changes in the AKS environment.

## Key Requirements
- Enforce MFA for all administrative access to AKS clusters (API, CLI, portal).
- Integrate with Azure AD Conditional Access and identity providers.
- Document MFA policy and enforcement mechanisms.

## Implementation Steps
1. Enable Azure AD integration for AKS.
2. Configure Conditional Access policies requiring MFA for all privileged roles.
3. Test and document MFA enforcement for all access paths.


## Integrated AKS Security Context

This control should be implemented alongside:
- [Identity and access management](pci-dss-identity.md) for identity and access management
- [Security policies](pci-dss-policy.md) for policy and governance
- [Monitoring and logging](pci-dss-monitor.md) for monitoring and alerting

For the latest AKS security features, see [Azure Kubernetes Service documentation](/azure/aks/).

## References
- [PCI DSS 4.0.1 MFA Requirements](https://www.pcisecuritystandards.org/)

