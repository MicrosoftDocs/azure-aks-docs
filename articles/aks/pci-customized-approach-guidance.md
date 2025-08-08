---
title: AKS Regulated Cluster for PCI DSS 4.0.1 - Customized Approach Guidance
description: Customized approach guidance for AKS clusters under PCI DSS 4.0.1.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: schaffererin
ms.author: schaffererin
ms.custom:
  - pci-dss
  - compliance
---

# Customized approach guidance for an AKS regulated cluster for PCI DSS 4.0.1

PCI DSS 4.0.1 introduces the "customized approach" for meeting requirements, allowing organizations to implement alternative controls if they meet the intent and rigor of the standard. This document provides guidance for documenting, justifying, and validating customized controls in Azure Kubernetes Service (AKS) environments.

## When to use the customized approach

The customized approach is appropriate when:

- When standard controls aren't feasible due to technical or business constraints.
- When leveraging cloud-native or container-specific security features that differ from traditional controls.

## Documentation requirements

- Clearly describe the alternative control and how it meets the intent of the PCI DSS requirement.
- Provide a risk analysis and justification for the alternative control.
- Include validation and testing procedures.

## Example template

| Requirement | Standard Control | Customized Control | Rationale | Validation/Test |
|-------------|-----------------|-------------------|-----------|----------------|
| MFA for admin access | Traditional MFA | Azure AD Conditional Access with FIDO2 | Stronger assurance, cloud-native | Review policy, test login |

## Integrated AKS security context

You should implement the customized approach as part of a broader security strategy that includes:

- [Security policies](pci-policy.md) for policy and governance.
- [Identity and access management](pci-identity.md) for identity and access management.
- [Monitoring and logging](pci-monitor.md) for monitoring and alerting.

For the latest AKS security features, see the [Azure Kubernetes Service (AKS) documentation](/azure/aks/).

## Next steps

Review the complete mapping of PCI DSS requirements to AKS implementations and controls.

> [!div class="nextstepaction"]
> [Review requirement mapping matrix](pci-requirement-mapping-matrix.md)

## Related resources

For more information, review the official [PCI DSS 4.0.1 documentation](https://www.pcisecuritystandards.org/).
