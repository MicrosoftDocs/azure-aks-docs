---
title: About the CLI Agent for Azure Kubernetes Service (AKS)
description: Learn about the CLI Agent for Azure Kubernetes Service (AKS) and its features, best practices, security considerations, how to get started, and more.
ms.topic: overview
ms.date: 10/20/2025
author: aritragho
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-monitoring
# Customer intent: As a cluster administrator or SRE, I want to use the AI-powered CLI Agent for AKS to efficiently troubleshoot my AKS clusters and get intelligent cluster insights, so that I can quickly diagnose and resolve issues.
---

# About the CLI Agent for Azure Kubernetes Service (AKS) (preview)

This article provides an overview of the CLI Agent for Azure Kubernetes Service (AKS), an AI-powered troubleshooting and insights tool that brings advanced diagnostics directly to your terminal. This feature is designed to help AKS administrators or developers quickly diagnose, understand, and resolve complex issues without needing deep Kubernetes expertise or memorizing command syntax.

## CLI Agent for AKS overview

The CLI Agent for AKS provides the `az aks agent` command group, which allows you to ask natural language questions about your cluster's health, configuration, and issues.

### Get cluster information, configurations and insights

The CLI Agent for AKS enables you to quickly gather detailed information about your AKS clusters, including:

- Comprehensive cluster status and configuration details.
- Real-time cluster metrics and health information.
- Intelligent analysis of cluster state and potential issues.
- Proactive recommendations based on cluster configuration and workload patterns.

### Troubleshoot advanced AKS, Kubernetes, and health issues

The CLI Agent for AKS leverages AI to help you troubleshoot complex issues by providing:

- AI-powered diagnostics that analyze complex cluster problems.
- Intelligent issue detection across AKS control plane, node pools, and workloads.
- Automated root cause analysis for networking, storage, and security issues.
- Guided troubleshooting workflows with step-by-step remediation suggestions.
- Integration with Microsoft's extensive Kubernetes troubleshooting knowledge base.

## Best practices for using the CLI Agent for AKS

To maximize the effectiveness of the CLI Agent for AKS, consider the following best practices:

- **Start with broad diagnostic queries**: Begin with general questions like "What's wrong with my cluster?" and let the AI guide you to specific issues.
- **Use descriptive problem statements**: Provide context about symptoms you're observing for better AI analysis.
- **Review AI recommendations carefully**: Always understand the suggested solutions before implementing them.
- **Leverage historical analysis**: Ask about patterns and trends in cluster behavior over time.
- **Provide feedback**: Help improve the AI by providing feedback on the accuracy and usefulness of diagnostic responses.
- **Use alongside traditional monitoring**: Complement AI insights with Azure Monitor and other observability tools.

## Security considerations

Keep the following security considerations in mind when using the CLI Agent for AKS:

- Ensure proper RBAC permissions are configured.
- Use Azure AD integration for authentication.
- Follow the principle of least privilege.
- Audit command usage through Azure activity logs.

## Get started with the CLI Agent for AKS

To start using the CLI Agent for AKS or to learn more, refer to the following resources:

- [Install and use the CLI Agent for AKS](./cli-agent-for-aks-install.md)
- [CLI Agent for AKS frequently asked questions (FAQ)](./cli-agent-for-aks-faq.yml)
- [Troubleshoot the CLI Agent for AKS](./cli-agent-for-aks-troubleshoot.md)
