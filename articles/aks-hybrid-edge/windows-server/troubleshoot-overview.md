---
title: Troubleshooting overview for Azure Kubernetes Service on Windows Server
description: An overview for troubleshooting issues encountered when using Azure Kubernetes Service on Windows Server.
author: davidsmatlak
ms.topic: troubleshooting
ms.date: 09/01/2026
ms.author: davidsmatlak
ms.lastreviewed: 07/27/2026
ms.reviewer: srikantsarwa
ms.custom: windows-server

# Intent: As an IT Pro, I want to learn how to troubleshoot issues with my AKS on Windows Server deployment
# Keyword: troubleshooting

---

# Troubleshooting overview

This overview describes how to find solutions for issues you encounter when using Azure Kubernetes Service (AKS) on Windows Server. Known issues and errors topics are organized by functional area. You can use the links provided in this topic to find the solutions and workarounds to resolve them.

For some troubleshooting operations, you might need to use a secure SSH connection to access Windows or Linux worker nodes. An SSH connection provides secure access to the nodes for maintenance, log collection, and troubleshooting. For more information, see [Connect with SSH to Windows or Linux worker nodes for maintenance and troubleshooting](ssh-connection.md).

## View logs to troubleshoot an issue

Logs are an important method to collect and review data from many sources that can provide insights into your environment for troubleshooting purposes. AKS on Windows Server includes [PowerShell cmdlets to collect and view logs](/azure/aks/aksarc/view-logs), and you can also [collect and review kubelet logs](/azure/aks/aksarc/get-kubelet-logs).

> [!NOTE]
> If you can't resolve the problem, [open a support issue](../local/hyperconverged/help-support.md).

## Next steps

- To monitor the health, performance, and resources of control plane nodes and workloads, use the AKS on Windows Server [on-premises monitoring](monitor-logging.md) solution.
- To monitor Azure Arc-enabled Kubernetes clusters, see [Azure Monitor Container Insights](/azure/azure-monitor/containers/container-insights-enable-arc-enabled-clusters?toc=/azure/azure-arc/kubernetes/toc.json)
