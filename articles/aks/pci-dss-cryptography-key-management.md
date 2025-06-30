---
title: AKS regulated cluster for PCI DSS 4.0.1 - Cryptography and key management
description: Cryptography and key management guidance for AKS clusters under PCI DSS 4.0.1.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: phillipgibson
ms.author: pgibson
ms.custom:
  - pci-dss
  - compliance
---

# Cryptography and key management for an AKS regulated cluster for PCI DSS 4.0.1

This article describes cryptography and key management considerations for an Azure Kubernetes Service (AKS) cluster that's configured in accordance with the Payment Card Industry Data Security Standard (PCI DSS 4.0.1).

## AKS feature support

AKS provides several features to help you meet PCI DSS 4.0.1 cryptography and key management requirements:

- **Azure Key Vault:** Secure storage and management of cryptographic keys, secrets, and certificates. Integrates with AKS for both workload and cluster-level secrets.
- **Managed identities:** Allow AKS workloads to securely access Key Vault without storing credentials in code.
- **TLS enforcement:** AKS supports enforcing TLS 1.2+ for all ingress/egress traffic.
- **Integration with HSM:** Azure Key Vault can be backed by hardware security modules (HSM) for FIPS 140-2 Level 3 compliance.
- **Automated key rotation:** Azure Key Vault supports automated key rotation and alerting.

## Your responsibilities

| PCI DSS v4.0.1 requirement | Your responsibilities in AKS |
|----------------------------|---------------------------|
| 3.5, 3.6, 3.7              | • Store all cryptographic keys in Azure Key Vault. <br> • Enforce access controls using RBAC and managed identities. <br> • Document and automate key rotation. |
| 4.2, 4.3                   | • Ensure all data in transit uses strong cryptography (TLS 1.2+). <br> • Configure AKS ingress controllers and application workloads to require secure protocols. |
| 3.6.4, 3.6.5               | • Document key management procedures, including key generation, distribution, storage, rotation, and destruction. <br> • Regularly review and test key management controls. |

## Integrated AKS security context

You should implement cryptography and key management as part of a broader security strategy that includes:

- [Network security](pci-dss-network.md) for secure networking.
- [Identity and access management](pci-dss-identity.md) for identity and access management.
- [Monitoring and logging](pci-dss-monitor.md) for monitoring and alerting.

For the latest AKS security features, see the [Azure Kubernetes Service (AKS) documentation](/azure/aks/).

## Related resources

For more information, review the official [PCI DSS 4.0.1 documentation](https://www.pcisecuritystandards.org/).
