---
title: AKS regulated cluster for PCI DSS 4.0.1 - Security awareness training
description: Security awareness training guidance for AKS clusters under PCI DSS 4.0.1.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: phillipgibson
ms.author: pgibson
ms.custom:
  - pci-dss
  - compliance
---

# Security awareness training for an AKS regulated cluster for PCI DSS 4.0.1

PCI DSS 4.0.1 requires ongoing security awareness and training for all personnel. This document provides a checklist for required training for AKS operators and developers.

## AKS feature support

AKS provides several features to help you meet PCI DSS 4.0.1 security awareness training requirements:

- **Azure Policy**: Enforce mandatory security awareness training for all AKS users and administrators.
- **Microsoft Defender for Cloud**: Provides security recommendations and can help track compliance with training requirements.
- **Microsoft Entra ID (Azure AD)**: Integrates with learning management systems and can be used to track user training completion.

## Your responsibilities

- Develop and deliver annual PCI DSS and security awareness training for all AKS users, including developers and administrators.
- Ensure training covers phishing, social engineering, secure coding, container security, and incident response.
- Maintain records of training completion and attendance for all AKS personnel.
- Periodically review and update training content to address new threats and changes in the AKS environment.

## Training checklist

- Annual PCI DSS and security awareness training.
- Phishing and social engineering awareness.
- Secure coding and container security best practices.
- Incident response and reporting procedures.

## Documentation

- Maintain records of training completion and attendance.

## Integrated AKS security context

You should implement security awareness training as part of a broader security strategy that includes:

- [Anti-phishing and social engineering](pci-dss-anti-phishing-social-engineering.md) for anti-phishing controls.
- [Identity and access management](pci-dss-identity.md) for identity and access management.
- [Monitoring and logging](pci-dss-monitor.md) for monitoring and alerting.

For the latest AKS security features, see the [Azure Kubernetes Service (AKS) documentation](/azure/aks/).

## Related resources

For more information, review the official [PCI DSS 4.0.1 documentation](https://www.pcisecuritystandards.org/).
