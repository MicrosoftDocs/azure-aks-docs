---
title: AKS regulated cluster for PCI DSS 4.0.1 - Anti-phishing and social engineering
description: Anti-phishing and social engineering guidance for AKS clusters.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: phillipgibson
ms.author: phillipgibson
ms.custom:
  - pci-dss
  - compliance
---

# AKS regulated cluster for PCI DSS 4.0.1 - Anti-phishing and social engineering

# Anti-Phishing and Social Engineering Controls for PCI DSS 4.0.1 in AKS


PCI DSS 4.0.1 expands requirements for anti-phishing and social engineering protections. This document provides guidance for implementing these controls for AKS admin and developer access.

## AKS Feature Support

- **Microsoft Defender for Cloud**: Provides threat protection, including anti-phishing and social engineering detection, for AKS clusters and integrated Azure resources.
- **Microsoft Entra ID (Azure AD) Conditional Access**: Supports risk-based access policies and can help mitigate phishing attempts by enforcing strong authentication and session controls.
- **Azure Policy**: Enforce security awareness and anti-phishing training requirements for AKS users.
- **Integration with Microsoft 365 Defender**: For organizations using Microsoft 365, anti-phishing and social engineering protections can be extended to email and collaboration tools used by AKS administrators and developers.

## Your Responsibilities

- Ensure all AKS administrators and users complete regular security awareness and anti-phishing training.
- Configure and enforce Conditional Access policies to require MFA and block risky sign-ins.
- Integrate AKS with Microsoft Defender for Cloud and ensure threat detection is enabled for all clusters.
- Document and test incident response procedures for suspected phishing or social engineering attempts targeting AKS resources.
- Regularly review and update anti-phishing controls as new threats emerge.

## Key Practices
- Enforce security awareness training for all AKS users.
- Implement anti-phishing protections in email and collaboration tools.
- Use just-in-time access and approval workflows for privileged actions.
- Document incident response for suspected phishing or social engineering attempts.


## Integrated AKS Security Context

This control should be implemented alongside:
- [AKS PCI Security Awareness Training](./pci-dss-security-awareness-training.md) for user training
- [AKS PCI Identity](./pci-dss-identity.md) for identity and access management
- [AKS PCI Monitoring](./pci-dss-monitor.md) for monitoring and alerting

For the latest AKS security features, see [Azure Kubernetes Service documentation](https://learn.microsoft.com/azure/aks/).

## References
- [PCI DSS 4.0.1 Anti-Phishing](https://www.pcisecuritystandards.org/)

