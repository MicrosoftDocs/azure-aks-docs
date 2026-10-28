---
title: Troubleshoot an Application using Insights in AKS Desktop (preview)
description: Learn how to troubleshoot Kubernetes applications in AKS desktop using the built-in Insights feature powered by Inspektor Gadget.
ms.service: azure-kubernetes-service
ms.subservice: aks-developer
author: danielsollondon
ms.reviewer: schaffererin
ms.topic: how-to
ms.date: 04/16/2026
ms.author: danis
# Customer intent: As a developer, platform engineer, SRE, or Kubernetes operator, I want to troubleshoot an application running in Azure Kubernetes Service (AKS) using AKS desktop, so I can identify DNS issues, understand network traffic between pods, and explore running processes to spot unexpected or resource-heavy activity through a UI with a few clicks.
---

# Troubleshoot an application using AKS desktop Insights (preview)

AKS desktop includes an integrated troubleshooting suite called **Insights**, powered by [Inspektor Gadget](https://inspektor-gadget.io/), an open-source eBPF (extended Berkeley Packet Filter)-based debugging tool. Without modifying your code or restarting anything, it lets you understand network traffic between pods, trace DNS failures, and explore running processes to spot unexpected or resource-heavy activity, all through an intuitive UI with a few clicks.

This article walks you through enabling Insights and using it to diagnose common application issues in your AKS cluster.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Prerequisites

- **AKS desktop** installed and signed in to your AKS cluster. See [Set up an AKS cluster for AKS desktop](aks-desktop-install-cluster-setup.md) or [Deploy applications with AKS Automatic using AKS desktop](aks-desktop-quickstart-auto.md).
- **Cluster admin** or equivalent Role-Based Access Control (RBAC) permissions on the target AKS cluster. Installing Inspektor Gadget requires creating a `ClusterRole`, `ClusterRoleBinding`, and a privileged `DaemonSet`.
- Your cluster nodes must run **Linux** with kernel version **≥ 5.4**. Windows node pools aren't supported.
- If your cluster uses Azure Policy or OPA Gatekeeper with restricted pod security, add an exemption for the `gadget` namespace to allow privileged pods.
- The target cluster must be an AKS Standard cluster.

## Enable Insights in AKS desktop

1. Launch the AKS Desktop application and ensure you're signed in and connected to your AKS cluster.
1. From the left-hand navigation, select **Settings**.
1. From the Settings menu, select **Plugins**.
1. Locate the **Insights** plugin in the list, and select the **Enable** toggle.

    :::image type="content" source="./media/aks-desktop-app/aks-desktop-enable-insights-plugin.png" alt-text="Screenshot of enabling the Insights plugin in AKS desktop.":::

## Access Insights for your Project

In the left-hand navigation, select the **Project** you want to use Insights with. The **Insights** tab will now be visible in the Project view.

:::image type="content" source="./media/aks-desktop-app/aks-desktop-project-insights-tab.png" alt-text="Screenshot of the Insights tab in AKS desktop.":::

## Deploy Inspektor Gadget to the cluster

On the Insights tab, you're prompted to deploy **Inspektor Gadget** to your cluster if it isn't already installed.

1. Select **Deploy Inspektor Gadget**. AKS desktop deploys the Inspektor Gadget DaemonSet to the `gadget` namespace on your cluster.
1. Wait for the deployment to complete. A status indicator confirms when Inspektor Gadget is ready.

## View Insights data

Once Inspektor Gadget is deployed, the Insights tab populates with live observability data from your cluster. See [What you can do with Insights](#what-you-can-do-with-insights) for the full set of capabilities.

:::image type="content" source="./media/aks-desktop-app/aks-desktop-insights-overview.png" alt-text="Screenshot of the Insights overview screen in AKS desktop.":::

## What you can do with Insights

### Performance troubleshooting with Processes

The Processes view shows you every running process across your cluster's pods in real time, along with CPU, memory, and disk I/O usage. Use it to:

- Identify which pods are consuming excessive CPU or memory.
- Spot abnormal block I/O activity, for example, unusually high disk reads or writes that can indicate a misconfigured app, a runaway log writer, or a storage bottleneck.
- Detect unexpected processes that shouldn't be running in a container.

:::image type="content" source="./media/aks-desktop-app/aks-desktop-insights-process.png" alt-text="Screenshot of the Insights Processes view in AKS desktop showing per-pod CPU, memory, and I/O metrics.":::

### Network visibility with Trace Transmission Control Protocol (TCP)

Trace TCP captures live TCP connection events at the kernel level using eBPF, without a proxy or sidecar. Use it to:

- See which pods are opening outbound connections and to which destination IPs and ports.
- Detect unexpected or unauthorized connections that might indicate a misconfiguration or security issue.
- Correlate network anomalies with specific pods or workloads.

:::image type="content" source="./media/aks-desktop-app/aks-desktop-insights-tcp-trace.png" alt-text="Screenshot of the Insights Trace TCP view in AKS desktop showing live pod-to-pod and external TCP connections.":::

> [!NOTE]
> You must stop the trace when finished, select the red stop button in the top-right of the trace.

### Solve DNS issues with Trace DNS

Trace DNS captures every DNS query and response made by pods in your cluster. Use it to:

- Identify DNS queries that are failing to resolve, a common cause of pod-to-service connectivity failures.
- Measure DNS latency to determine whether CoreDNS (the in-cluster DNS server) or an upstream DNS resolver is slow.
- Check the health of CoreDNS and whether external DNS resolution is working correctly.

:::image type="content" source="./media/aks-desktop-app/aks-desktop-insights-dns-trace.png" alt-text="Screenshot of the Insights Trace DNS view in AKS desktop showing DNS queries, responses, and latency per pod.":::

> [!NOTE]
> You must stop the trace when finished, select the red stop button in the top-right of the trace.

## Uninstall Inspektor Gadget

Remove Inspektor Gadget from your cluster by deleting the `gadget` namespace. This removes all Insights data and functionality, so only do this when you no longer need any of the Insights features.

```bash
kubectl delete ns gadget
```

> [!WARNING]
> This command removes all resources in the `gadget` namespace, not only those created by Inspektor Gadget.

## Troubleshooting issues with Insights

The following table outlines common issues you might encounter when using Insights along with their resolutions:

| Issue | Resolution |
| ----- | ---------- |
| **Insights tab isn't visible** | Ensure the Insights plugin is enabled. Go to **Settings** > **Plugins** and toggle **Insights** on. |
| **Deployment of Inspektor Gadget fails** | Verify you have sufficient RBAC permissions to create DaemonSets and ClusterRoles in the cluster. |
| **No data appears after deployment** | Confirm the cluster nodes are running a supported Linux kernel (≥ 5.4). Check the Inspektor Gadget pod logs for errors. |

## Related content

- [Inspektor Gadget on GitHub](https://github.com/inspektor-gadget/inspektor-gadget)
- [Inspektor Gadget desktop on GitHub](https://github.com/inspektor-gadget/ig-desktop)
- [Configure an AKS cluster for AKS desktop](./aks-desktop-install-cluster-setup.md)
- [AKS desktop overview](./aks-desktop-overview.md)
