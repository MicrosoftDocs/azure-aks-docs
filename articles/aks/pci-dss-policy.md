---
title: AKS regulated cluster for PCI DSS 4.0.1 - Security policies
description: Security policies guidance for AKS clusters under PCI DSS 4.0.1.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: phillipgibson
ms.author: pgibson
ms.custom:
  - pci-dss
  - compliance
---

# Security policies for an AKS regulated cluster for PCI DSS 4.0.1

This article describes security policy considerations for an Azure Kubernetes Service (AKS) cluster that's configured in accordance with the Payment Card Industry Data Security Standard (PCI DSS 4.0.1).

> This article is part of a series. Read the [introduction](pci-dss-intro.md).

## Maintain an information security policy

### Requirement 12: Maintain an information security policy for all personnel

Microsoft completes an annual PCI DSS assessment using an approved Qualified Security Assessor (QSA). This assessment covers all aspects of infrastructure, development, operations, management, support, and in-scope services. For more information, see [Payment Card Industry (PCI) Data Security Standard (DSS)](/compliance/regulatory/offering-PCI-DSS#use-microsoft-compliance-manager-to-assess-your-risk).

PCI DSS 4.0.1 requires organizations to establish, maintain, and regularly review a comprehensive information security policy. This policy must address roles, responsibilities, acceptable usage, and security objectives for all personnel, including third parties and cloud providers handling cardholder data. The policy should be reviewed at least annually and updated as risks evolve.

**Cloud and container considerations**:

- Define shared responsibility for security between your organization and the cloud/container provider in your policy.
- Ensure policies enforce inventory tracking of assets and services, including ephemeral resources like containers and cloud services.
- Communicate the policy to all personnel and relevant stakeholders, including those managing cloud and container environments.

Here are some general suggestions:

- Maintain thorough and updated documentation about processes and policies. Consider [using Microsoft Purview Compliance Manager to assess your risk](/compliance/regulatory/offering-PCI-DSS#use-microsoft-compliance-manager-to-assess-your-risk).
- In the annual review of the security policy, incorporate new guidance delivered by Microsoft, Kubernetes, and other third-party solutions that are part of your CDE. Use resources such as Microsoft Defender for Cloud, Azure Advisor, [Azure Well-Architected Review](/assessments/), [AKS Azure Security Baseline](/security/benchmark/azure/baselines/aks-security-baseline), and [CIS Azure Kubernetes Service Benchmark](https://www.cisecurity.org/blog/new-release-cis-azure-kubernetes-service-aks-benchmark/).
- When establishing your risk assessment process, align with a published standard where practical, for example [NIST SP 800-53](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final). Map publications from your vendor's published security list, such as the [Microsoft Security Response Center guide](https://msrc.microsoft.com/update-guide), to your risk assessment process.
- Keep up-to-date information about device inventory and personnel access documentation. Use device discovery capabilities, such as Microsoft Defender for Endpoint, and cloud-native inventory tools. For tracking access, use Microsoft Entra logs and cloud IAM logs.
  - [Device discovery](/microsoft-365/security/defender-endpoint/device-discovery)
  - [Entitlement management in Microsoft Entra ID Governance](/entra/id-governance/entitlement-management-reports)
- As part of your inventory management, maintain a list of approved solutions deployed as part of the PCI infrastructure and workload, including VM images, databases, and third-party solutions. Automate this process with a service catalog for self-service deployment using approved solutions in a specific configuration. For more information, see [Establish a service catalog](/azure/cloud-adoption-framework/manage/considerations/platform#establish-a-service-catalog).
- Make sure that a security contact receives Azure incident notifications from Microsoft. These notifications indicate if your resource is compromised and enable your security operations team to rapidly respond to potential security risks. Ensure administrator contact information in the Azure enrollment portal includes contact information that will notify security operations directly or rapidly through an internal process. For details, see [Security operations model](/azure/cloud-adoption-framework/secure/security-operations#security-operations-model).

For more information about planning for operational compliance, see the following resources:

- [Cloud management in the Cloud Adoption Framework](/azure/cloud-adoption-framework/manage/)
- [Governance in the Microsoft Cloud Adoption Framework for Azure](/azure/cloud-adoption-framework/govern/)

## Next steps

Implement targeted risk analysis procedures for custom approaches and security assessments.

> [!div class="nextstepaction"]
> [Implement targeted risk analysis](pci-dss-targeted-risk-analysis.md)
