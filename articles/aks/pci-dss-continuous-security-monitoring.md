---
title: AKS regulated cluster for PCI DSS 4.0.1 - Continuous security monitoring
description: Continuous security monitoring guidance for AKS clusters under PCI DSS 4.0.1.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: phillipgibson
ms.author: pgibson
ms.custom:
  - pci-dss
  - compliance
---

# Continuous security monitoring for an AKS regulated cluster for PCI DSS 4.0.1

PCI DSS 4.0.1 emphasizes continuous security, monitoring, and threat detection. This document outlines best practices for implementing real-time compliance monitoring and automated alerting in AKS environments.

## AKS feature support

AKS provides several features to help you meet PCI DSS 4.0.1 continuous security monitoring requirements:

- **Azure Monitor**: Provides real-time monitoring, alerting, and log analytics for AKS clusters and workloads.
- **Microsoft Defender for Cloud**: Delivers threat detection, vulnerability management, and compliance reporting for AKS.
- **Azure Policy**: Enables continuous compliance checks and enforcement of security standards.
- **Integration with SIEM/SOAR**: AKS logs and alerts can be integrated with SIEM/SOAR platforms for advanced threat detection and automated response.

## Your responsibilities

- Integrate AKS with Azure Monitor and Microsoft Defender for Cloud for comprehensive monitoring and alerting.
- Automate compliance checks for PCI DSS controls using Azure Policy and custom scripts.
- Enable and review continuous vulnerability scanning for all container images and workloads.
- Document and regularly test incident response and escalation procedures for security events in AKS.
- Ensure monitoring covers ephemeral workloads, network activity, and privilege escalation attempts.

## Key practices

- Integrate AKS with Azure Monitor, Microsoft Defender for Cloud, and SIEM/SOAR solutions.
- Automate compliance checks and alerting for PCI DSS controls.
- Enable continuous vulnerability scanning and threat detection.
- Document incident response and escalation procedures.

## Example integrations

- Azure Policy for continuous compliance.
- Azure Monitor and Log Analytics for real-time alerting.
- Defender for Cloud for threat detection.

## Integrated AKS security context

You should implement continuous security monitoring as part of a broader security strategy that includes:

- [Network security](pci-dss-network.md) for secure networking
- [Identity and access management](pci-dss-identity.md) for identity and access management
- [Security policies](pci-dss-policy.md) for policy and governance

For the latest AKS security features, see the [Azure Kubernetes Service documentation](/azure/aks/).

## Related resources

For more information, review the official [PCI DSS 4.0.1 documentation](https://www.pcisecuritystandards.org/).
