---
title: AKS regulated cluster for PCI DSS 4.0.1 - Cryptography and key management
description: Cryptography and key management guidance for AKS clusters.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: phillipgibson
ms.author: phillipgibson
ms.custom:
  - pci-dss
  - compliance
---

# AKS regulated cluster for PCI DSS 4.0.1 - Cryptography and key management

# Cryptography and Key Management for PCI DSS 4.0.1 in AKS

PCI DSS 4.0.1 updates requirements for strong cryptography, key management, and algorithm agility. This document provides guidance for implementing cryptographic controls and key management in AKS.


## AKS Feature Support

- **Azure Key Vault:** Secure storage and management of cryptographic keys, secrets, and certificates. Integrates with AKS for both workload and cluster-level secrets.
- **Managed Identities:** Allow AKS workloads to securely access Key Vault without storing credentials in code.
- **TLS enforcement:** AKS supports enforcing TLS 1.2+ for all ingress/egress traffic.
- **Integration with HSM:** Azure Key Vault can be backed by hardware security modules (HSM) for FIPS 140-2 Level 3 compliance.
- **Automated key rotation:** Azure Key Vault supports automated key rotation and alerting.

## Your Responsibilities

| PCI DSS v4.0.1 Requirement | Your Responsibility in AKS |
|----------------------------|---------------------------|
| 3.5, 3.6, 3.7              | Store all cryptographic keys in Azure Key Vault. Enforce access controls using RBAC and managed identities. Document and automate key rotation. |
| 4.2, 4.3                   | Ensure all data in transit uses strong cryptography (TLS 1.2+). Configure AKS ingress controllers and application workloads to require secure protocols. |
| 3.6.4, 3.6.5               | Document key management procedures, including key generation, distribution, storage, rotation, and destruction. Regularly review and test key management controls. |

## Integrated AKS Security Context

This control should be implemented alongside:
- [pci-dss-network.md](network.md) for secure networking
- [pci-dss-identity.md](identity.md) for identity and access management
- [pci-dss-monitor.md](monitor.md) for monitoring and alerting

For the latest AKS security features, see [Azure Kubernetes Service documentation](https://learn.microsoft.com/azure/aks/).

## References
- [PCI DSS 4.0.1 Cryptography](https://www.pcisecuritystandards.org/)

