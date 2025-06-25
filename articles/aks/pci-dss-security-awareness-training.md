---
title: AKS regulated cluster for PCI DSS 4.0.1 - Security awareness training
description: Security awareness training guidance for AKS clusters.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: phillipgibson
ms.author: pgibson
ms.custom:
  - pci-dss
  - compliance
---

# AKS regulated cluster for PCI DSS 4.0.1 - Security awareness training

# Security Awareness and Training for PCI DSS 4.0.1 in AKS


PCI DSS 4.0.1 requires ongoing security awareness and training for all personnel. This document provides a checklist for required training for AKS operators and developers.

## AKS Feature Support

- **Azure Policy**: Enforce mandatory security awareness training for all AKS users and administrators.
- **Microsoft Defender for Cloud**: Provides security recommendations and can help track compliance with training requirements.
- **Microsoft Entra ID (Azure AD)**: Integrates with learning management systems and can be used to track user training completion.

## Your Responsibilities

- Develop and deliver annual PCI DSS and security awareness training for all AKS users, including developers and administrators.
- Ensure training covers phishing, social engineering, secure coding, container security, and incident response.
- Maintain records of training completion and attendance for all AKS personnel.
- Periodically review and update training content to address new threats and changes in the AKS environment.

## Training Checklist
- Annual PCI DSS and security awareness training
- Phishing and social engineering awareness
- Secure coding and container security best practices
- Incident response and reporting procedures

## Documentation
- Maintain records of training completion and attendance.


## Integrated AKS Security Context

This control should be implemented alongside:
- [pci-dss-anti-phishing-social-engineering.md](anti-phishing-social-engineering.md) for anti-phishing controls
- [pci-dss-identity.md](identity.md) for identity and access management
- [pci-dss-monitor.md](monitor.md) for monitoring and alerting

For the latest AKS security features, see [Azure Kubernetes Service documentation](https://learn.microsoft.com/azure/aks/).

## References
- [PCI DSS 4.0.1 Security Awareness](https://www.pcisecuritystandards.org/)

