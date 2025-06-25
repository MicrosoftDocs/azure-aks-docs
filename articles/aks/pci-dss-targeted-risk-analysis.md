---
title: AKS regulated cluster for PCI DSS 4.0.1 - Targeted risk analysis
description: Targeted risk analysis guidance for AKS clusters.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: phillipgibson
ms.author: pgibson
ms.custom:
  - pci-dss
  - compliance
---

# AKS regulated cluster for PCI DSS 4.0.1 - Targeted risk analysis

# Targeted Risk Analysis for PCI DSS 4.0.1 in AKS


PCI DSS 4.0.1 introduces targeted risk analysis for certain requirements. This document outlines how to perform and document risk analysis for AKS workloads.

## AKS Feature Support

- **Azure Policy**: Supports risk-based policy enforcement and can help automate risk analysis for AKS resources.
- **Microsoft Defender for Cloud**: Provides risk assessment, security recommendations, and compliance tracking for AKS clusters.
- **Azure Monitor**: Enables tracking of risk indicators and audit events for ongoing risk analysis.

## Your Responsibilities

- Identify which PCI DSS requirements in your AKS environment allow for targeted risk analysis (e.g., key rotation, access reviews).
- Document the risk analysis process, findings, and mitigation steps for each applicable requirement.
- Use Azure Policy and Defender for Cloud to automate risk identification and mitigation where possible.
- Regularly review and update risk analysis documentation as the AKS environment and threat landscape evolve.

## Key Steps
- Identify requirements that allow for targeted risk analysis.
- Document the risk analysis process, findings, and mitigation steps.
- Review and update risk analysis regularly.

## Example Template
| Requirement | Risk Identified | Mitigation | Review Date |
|-------------|----------------|-----------|-------------|
| Key rotation frequency | Key compromise | Automated rotation | 2025-06-01 |


## Integrated AKS Security Context

This analysis should be performed alongside:
- [pci-dss-policy.md](policy.md) for policy and governance
- [pci-dss-identity.md](identity.md) for identity and access management
- [pci-dss-monitor.md](monitor.md) for monitoring and alerting

For the latest AKS security features, see [Azure Kubernetes Service documentation](https://learn.microsoft.com/azure/aks/).

## References
- [PCI DSS 4.0.1 Targeted Risk Analysis](https://www.pcisecuritystandards.org/)

