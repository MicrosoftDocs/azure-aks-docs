---
title: Troubleshoot Azure Kubernetes Service (AKS) Workloads with Natural Language in AKS Desktop (preview)
description: Learn how to use the AI-powered troubleshooting assistant in AKS desktop to diagnose and resolve Kubernetes issues using natural language.
ms.service: azure-kubernetes-service
ms.subservice: aks-developer
author: danielsollondon
ms.reviewer: schaffererin
ms.topic: how-to
ms.date: 04/16/2026
ms.author: danis
ai-usage: ai-assisted
# Customer intent: As a developer, Kubernetes operator, DevOps engineer, or site reliability engineer (SRE), I want to troubleshoot failed Kubernetes resources, find out why they failed, and how to resolve them. I can also ask questions about the AKS cluster and applications that are deployed to understand more about their configurations.
---

# Troubleshoot and understand workloads with natural language in AKS desktop (preview)

The AI Assistant in AKS desktop provides enhanced natural language troubleshooting for AKS workloads. Powered by the Headlamp AI Assistant, it delivers AKS-specific skills, cluster-aware observability, guided troubleshooting workflows, and seamless integration with your existing GitHub Copilot entitlement.

After securely connecting to your cluster, the assistant combines language models with AKS-specific context, logs, events, and metrics to identify issues and recommend resolutions in plain language. This approach allows developers and operators to quickly understand and fix problems without needing deep Kubernetes expertise. This article walks you through how to enable and use the AI Assistant in AKS desktop.

## Prerequisites

Before you enable the AI Assistant in AKS desktop, make sure you have:

- [AKS desktop v0.10.0 or later installed](aks-desktop-overview.md#install-aks-desktop).
- Access to one or more Kubernetes clusters that you want to investigate.
- The AI Assistant plugin enabled in **Settings** > **Plugins**. The plugin is enabled by default.
- One of the following provider configurations:
  - **GitHub Copilot Auto Detect (recommended)**: A GitHub Copilot subscription, [GitHub CLI (`gh`)](https://cli.github.com/) installed on your machine, and GitHub CLI authenticated with your GitHub account.
  - **Another supported AI provider**: Access to a supported provider or OpenAI-compatible endpoint.

## What is the AI Assistant?

The AI Assistant is bundled with AKS desktop and provides a guided experience for diagnosing issues in your cluster. The assistant helps you:

- Run scoped diagnostics that analyze logs, events, and metrics.
- Receive AI-generated summaries with clear reasoning and evidence.
- Preview recommended actions and apply them with confidence.
- Use GitHub Copilot when available for a streamlined setup experience.
- Use cluster-aware observability and AKS-specific skills to bring additional context and best practices into investigations.

## How does the AI Assistant work?

You have two options for enabling the AI Assistant in AKS desktop:

- Use **GitHub Copilot (recommended)**. If GitHub CLI is installed and authenticated with an account that has a GitHub Copilot subscription, AKS desktop can detect and configure GitHub Copilot as the provider.
- **Another supported AI provider**: Manually configure a supported provider or OpenAI-compatible endpoint.

For either option, AKS desktop can provide cluster context and enabled AKS skills to the configured provider.

The AI Assistant runs as part of AKS desktop and doesn't deploy an agent or other workload to your cluster. AKS desktop connects to the selected cluster through the Kubernetes API by using the credentials in your kubeconfig. The assistant is limited to the operations allowed by your Kubernetes RBAC permissions.

## Enable GitHub Copilot (Auto Detect)

1. Install GitHub CLI (`gh`) on your machine and sign in to your GitHub account.
1. In AKS desktop, go to **Settings** > **Plugins** > **AI Assistant**.
1. Select **Auto Detect**.
1. Verify that GitHub Copilot appears as the configured provider.

   :::image type="content" source="./media/aks-desktop-app/aks-desktop-github-copilot-auto-detect.png" alt-text="Screenshot of AKS desktop AI Assistant settings showing the Auto Detect button.":::

## Configure your own AI provider

1. In AKS desktop, go to **Settings** > **Plugins** > **AI Assistant**.
1. Select **Add Provider**.
1. Select the AI provider you want to use.
1. Enter the required configuration information for your provider.
1. Verify that the provider appears in the configured providers list.

   :::image type="content" source="./media/aks-desktop-app/aks-desktop-select-ai-provider.png" alt-text="Screenshot of the AKS desktop provider selection dialog showing the supported AI providers.":::

## Enable Kubernetes API requests for the assistant

The **Kubernetes API Request** setting allows the AI Assistant to make live Kubernetes API requests against your cluster. When enabled, the assistant can query resource state, pod logs, events, and metrics to provide context-aware analysis. If disabled, the assistant can only reason from information you manually provide in the chat.

Read requests can run automatically. Requests that create, update, or delete Kubernetes resources require your approval and are still subject to your Kubernetes RBAC permissions.

1. Go to **Settings** > **Plugins** > **AI Assistant**.
1. Enable the **Kubernetes API Request** toggle.

   :::image type="content" source="./media/aks-desktop-app/aks-desktop-kubernetes-api-request.png" alt-text="Screenshot of AKS desktop AI Tools settings showing Kubernetes API Request enabled.":::

## Enable MCP servers

Model Context Protocol (MCP) servers allow the AI Assistant to connect to external tools and data sources. MCP servers extend the capabilities of the AI Assistant by providing additional context and actions that can be used during troubleshooting and investigation workflows.

AKS desktop supports connections to MCP servers, but MCP servers aren't enabled by default.

MCP servers are optional and aren't required for the AI Assistant's built-in AKS troubleshooting and cluster-aware observability. Configure an MCP server only when you need to connect the AI Assistant to a specific external tool or data source.

### Choose an MCP server

Choose a server based on the capability you need:

- Use Flux Operator MCP to investigate Flux GitOps resources and workflows.
- Use Inspektor Gadget for eBPF tracing and runtime diagnostics.

Before you configure an MCP server in AKS desktop, install the server and confirm that it can run as a local command. If you don't need one of these additional integrations, continue using the AI Assistant without an MCP server.

### Configure an MCP server

1. In AKS desktop, go to **Settings** > **Plugins** > **AI Assistant**.
1. View **MCP Servers**.
1. Turn on **Enable MCP Servers**.
1. Select **Add MCP Server**.
1. Enter the required configuration information for the MCP server.
1. Configure the approval settings for the server.

   :::image type="content" source="./media/aks-desktop-app/aks-desktop-mcp-servers.png" alt-text="Screenshot of AKS desktop MCP Servers settings showing the Enable MCP Servers toggle and Add MCP Server button.":::

### MCP server approvals

When an MCP server performs an action on behalf of the AI Assistant, AKS desktop can require approval before the action is executed. Configure approval settings for each MCP server.

By default, **Auto Approve Actions** is disabled. The AI Assistant displays each requested action in the chat window and requires your approval before the MCP server can execute it.

Enable **Auto Approve Actions** for a specific MCP server to automatically approve requests from that server. When enabled, the AI Assistant can use MCP tools without prompting for approval for each request.

## Enable skill repositories

Skills provide instructions and supporting information for specific tasks. AKS desktop includes an AKS skill from the Azure Skills repository, which is enabled by default. You can enable other skill repositories or add a custom repository.

1. In AKS desktop, go to **Settings** > **Plugins** > **AI Assistant**.
1. Review the list of built-in skill repositories.
1. Use the toggle next to each repository to enable or disable repositories.
1. Select **Add Repository** to add a custom repository.
1. Enter the repository URL and save your changes.

   :::image type="content" source="./media/aks-desktop-app/aks-desktop-azure-skills-repository.png" alt-text="Screenshot of AKS desktop skill settings showing the Azure Skills repository configured with the azure-kubernetes path and enabled.":::

## Proactive diagnosis

Proactive diagnosis is a separate, opt-in feature that's disabled by default. When enabled, it uses one-shot requests through Headlamp's Kubernetes API proxy to poll selected clusters for recent events with a type of `Warning` or `Error` rather than continuously watching the clusters.

The first check occurs shortly after the AI backend is ready, and the scheduler checks once per minute. When qualifying events are found, the assistant diagnoses up to three of the most recent distinct affected workloads sequentially. After a diagnosis cycle completes, a 20-minute cooldown begins before another cycle can run. If no qualifying events are found, no diagnosis cycle starts, so the lightweight event query can run again at the next one-minute check. Successful results are cached to avoid repeatedly diagnosing the same resource.

### Enable proactive diagnosis

1. In AKS desktop, go to **Settings** > **Plugins** > **AI Assistant**.
1. Turn on the **Proactive Diagnosis** toggle.
1. Review detected problems and recommendations surfaced by the AI Assistant.
1. Select a recommendation to investigate or begin troubleshooting.

   :::image type="content" source="./media/aks-desktop-app/aks-desktop-proactive-diagnosis.png" alt-text="Screenshot of AKS desktop AI Assistant settings showing the Proactive Diagnosis toggle.":::

## Disable the AI Assistant

1. Go to **Settings** > **Plugins**.
1. Turn off **AI Assistant**.
1. Select **Save & Apply**.
1. Reload AKS desktop if prompted.

   :::image type="content" source="./media/aks-desktop-app/aks-desktop-disable-ai-assistant.png" alt-text="Screenshot of the AKS desktop plugin list showing the AI Assistant toggle turned off.":::
