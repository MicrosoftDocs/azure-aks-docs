---
title: Observability Overview of Azure Kubernetes Application Network (Preview)
description: Learn about the observability features available for Azure Kubernetes Application Network, including supported metrics, logs, and tracing capabilities, as well as workspace options for monitoring.
author: kochhars
ms.author: kochhars
ms.service: azure-kubernetes-app-net
ms.topic: overview
ms.date: 11/04/2025
---

# Overview of Azure Kubernetes Application Network observability (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Azure Kubernetes Application Network leverages [Azure Monitor](/azure/azure-monitor/fundamentals/overview) for comprehensive observability of member clusters. This article provides an overview of the observability features available for Azure Kubernetes Application Network, including supported metrics, logs, and tracing capabilities.

## Observability features

Azure Kubernetes Application Network member observability infrastructure includes the following features:

| Feature | Workspace type | Description |
| ------- | -------------- | ----------- |
| [**Managed Prometheus**](/azure/azure-monitor/metrics/prometheus-metrics-overview) | [Azure Monitor workspace](/azure/azure-monitor/metrics/azure-monitor-workspace-overview) | Stores Prometheus metrics scraped from your cluster. |
| [**Container logging**](/azure/azure-monitor/containers/container-insights-log-query) | [Log Analytics workspace](/azure/azure-monitor/logs/log-analytics-workspace-overview) | Stores container logs and control plane logs. |
| [**Dashboards with Grafana**](/azure/azure-monitor/visualize/visualize-grafana-overview) | [Azure Monitor workspace](/azure/azure-monitor/metrics/azure-monitor-workspace-overview) | Links to your Azure Monitor workspace to visualize Prometheus metrics in Grafana dashboards. |

## Workspace options for Azure Kubernetes Application Network observability

You can create new workspaces or use existing ones. If you don't specify a workspace ID during onboarding, a default workspace will be created in your resource group. You can onboard workspaces for [metrics](./metrics.md) or [logs](./logs.md). For more information about workspace options, see [Create workspaces](/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli#create-workspaces).

## Observability limitations

Azure Kubernetes Application Network currently doesn't support tracing or control plane metrics.

## Related content

To learn how to configure observability for your Azure Kubernetes Application Network members, see the following articles:

- [Configure and view Azure Kubernetes Application Network metrics](./metrics.md)
- [Monitor logs in Azure Kubernetes Application Network](./logs.md)
