---
title: AKS regulated cluster for PCI DSS 4.0.1 - Customized approach guidance
description: Customized approach guidance guidance for AKS clusters.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: phillipgibson
ms.author: phillipgibson
ms.custom:
  - pci-dss
  - compliance
---

# AKS regulated cluster for PCI DSS 4.0.1 - Customized approach guidance

# PCI DSS 4.0.1 Customized Approach Guidance for AKS

PCI DSS 4.0.1 introduces the "customized approach" for meeting requirements, allowing organizations to implement alternative controls if they meet the intent and rigor of the standard. This document provides guidance for documenting, justifying, and validating customized controls in Azure Kubernetes Service (AKS) environments.

## When to Use the Customized Approach
- When standard controls are not feasible due to technical or business constraints.
- When leveraging cloud-native or container-specific security features that differ from traditional controls.

## Documentation Requirements
- Clearly describe the alternative control and how it meets the intent of the PCI DSS requirement.
- Provide a risk analysis and justification for the alternative control.
- Include validation and testing procedures.

## Example Template
| Requirement | Standard Control | Customized Control | Rationale | Validation/Test |
|-------------|-----------------|-------------------|-----------|----------------|
| MFA for admin access | Traditional MFA | Azure AD Conditional Access with FIDO2 | Stronger assurance, cloud-native | Review policy, test login |


## Integrated AKS Security Context

This guidance should be used in conjunction with:
- [pci-dss-policy.md](policy.md) for policy and governance
- [pci-dss-identity.md](identity.md) for identity and access management
- [pci-dss-monitor.md](monitor.md) for monitoring and alerting

For the latest AKS security features, see [Azure Kubernetes Service documentation](https://learn.microsoft.com/azure/aks/).

## References
- [PCI DSS 4.0.1 Customized Approach Guidance](https://www.pcisecuritystandards.org/)

