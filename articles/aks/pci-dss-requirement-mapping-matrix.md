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

# AKS regulated cluster for PCI DSS 4.0.1 - Requirement mapping matrix

# PCI DSS 4.0.1 Requirement Mapping Matrix for AKS

This document provides a mapping of AKS controls and documentation to PCI DSS 4.0.1 requirements, including customized approaches where applicable.

| PCI DSS 4.0.1 Requirement | AKS Control/Document | Customized Approach | Notes |
|--------------------------|---------------------|--------------------|-------|
| MFA for admin access     | Enhanced MFA Implementation | Yes (if using Azure AD Conditional Access) |  |
| Continuous monitoring    | Continuous Security and Monitoring | No |  |
| Key management           | Cryptography and Key Management | No |  |
| Third-party management   | Third-Party and Supply Chain Security | No |  |
| Security awareness       | Security Awareness and Training | No |  |


## Integrated AKS Security Context

This mapping should be used in conjunction with:
- [pci-dss-policy.md](policy.md) for policy and governance
- [pci-dss-identity.md](identity.md) for identity and access management
- [pci-dss-monitor.md](monitor.md) for monitoring and alerting

For the latest AKS security features, see [Azure Kubernetes Service documentation](https://learn.microsoft.com/azure/aks/).

