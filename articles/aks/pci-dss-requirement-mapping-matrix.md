---
title: AKS regulated cluster for PCI DSS 4.0.1 - Requirement mapping matrix
description: Requirement mapping matrix guidance for AKS clusters.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: phillipgibson
ms.author: pgibson
ms.custom:
  - pci-dss
  - compliance
---

# Requirement mapping matrix for an AKS regulated cluster for PCI DSS 4.0.1

This document provides a mapping of AKS controls and documentation to PCI DSS 4.0.1 requirements, including customized approaches where applicable.

## AKS PCI DSS 4.0.1 requirement mapping matrix

| PCI DSS 4.0.1 requirement | AKS control | Customized approach |
|--------------------------|---------------------|--------------------|
| MFA for admin access     | [Enhanced MFA implementation](./pci-dss-enhanced-mfa-implementation.md) | Yes (if using Azure AD Conditional Access) |
| Continuous monitoring    | [Continuous security and monitoring](./pci-dss-continuous-security-monitoring.md) | No |
| Key management           | [Cryptography and key management](./pci-dss-cryptography-key-management.md) | No |
| Third-party management   | [Third-party and supply chain security](./pci-dss-third-party-supply-chain-security.md) | No |
| Security awareness       | [Security awareness and training](./pci-dss-security-awareness-training.md) | No |

## Integrated AKS security context

You should leverage the requirement mapping matrix as part of a broader security strategy that includes:

- [Security policies](pci-dss-policy.md) for policy and governance.
- [Identity and access management](pci-dss-identity.md) for identity and access management.
- [Monitoring and logging](pci-dss-monitor.md) for monitoring and alerting.

## Next steps

Review the complete summary of PCI DSS 4.0.1 implementation on AKS and next steps for compliance.

> [!div class="nextstepaction"]
> [Review summary and next steps](pci-dss-summary.md)

## Related resources

For more information, review the official [PCI DSS 4.0.1 documentation](https://www.pcisecuritystandards.org/).

For the latest AKS security features, see the [Azure Kubernetes Service (AKS) documentation](/azure/aks/).
