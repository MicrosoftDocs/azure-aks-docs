---
title: AKS regulated cluster for PCI DSS 4.0.1 - Anti-phishing and social engineering
description: Anti-phishing and social engineering guidance for AKS clusters under PCI DSS 4.0.1.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: phillipgibson
ms.author: pgibson
ms.custom:
  - pci-dss
  - compliance
---

# Anti-phishing and social engineering for an AKS regulated cluster for PCI DSS 4.0.1

PCI DSS 4.0.1 expands requirements for anti-phishing and social engineering protections. This document provides guidance for implementing these controls for AKS admin and developer access.

## AKS feature support

AKS provides several features to help you meet PCI DSS 4.0.1 anti-phishing and social engineering requirements:

- **Microsoft Defender for Cloud**: Provides threat protection, including anti-phishing and social engineering detection, for AKS clusters and integrated Azure resources.
- **Microsoft Entra ID (Azure AD) Conditional Access**: Supports risk-based access policies and can help mitigate phishing attempts by enforcing strong authentication and session controls.
- **Azure Policy**: Enforce security awareness and anti-phishing training requirements for AKS users.
- **Integration with Microsoft 365 Defender**: For organizations using Microsoft 365, anti-phishing and social engineering protections can be extended to email and collaboration tools used by AKS administrators and developers.

## Your responsibilities

- Ensure all AKS administrators and users complete regular security awareness and anti-phishing training.
- Configure and enforce Conditional Access policies to require MFA and block risky sign-ins.
- Integrate AKS with Microsoft Defender for Cloud and ensure threat detection is enabled for all clusters.
- Document and test incident response procedures for suspected phishing or social engineering attempts targeting AKS resources.
- Regularly review and update anti-phishing controls as new threats emerge.

## Key practices

- Enforce security awareness training for all AKS users.
- Implement anti-phishing protections in email and collaboration tools.
- Use just-in-time access and approval workflows for privileged actions.
- Document incident response for suspected phishing or social engineering attempts.

## Integrated AKS security context

You should implement anti-phishing and social engineering efforts as part of a broader security strategy that includes:

- [Security awareness training](./pci-dss-security-awareness-training.md) for user training.
- [Identity](./pci-dss-identity.md) for identity and access management.
- [Monitoring](./pci-dss-monitor.md) for monitoring and alerting.

For the latest AKS security features, see the [Azure Kubernetes Service (AKS) documentation](/azure/aks/).

## Related resources

For more information, review the official [PCI DSS 4.0.1 documentation](https://www.pcisecuritystandards.org/).
