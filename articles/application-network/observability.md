---
title: Observability Overview of Azure Kubernetes Application Network (Preview)
description: Learn about the observability features available for Azure Kubernetes Application Network, including supported metrics, logs, and tracing capabilities, as well as workspace options for monitoring.
author: kochhars
ms.author: kochhars
ms.service: azure-kubernetes-app-net
ms.topic: overview
ms.date: 10/30/2026
ai-usage: ai-assisted
---

# Overview of Azure Kubernetes Application Network observability (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Azure Kubernetes Application Network uses [Azure Monitor][azure-monitor] to provide comprehensive observability for member clusters. This article gives an overview of the observability features available for Azure Kubernetes Application Network, including supported metrics, logs, and tracing capabilities.

## Observability features

Azure Kubernetes Application Network member observability infrastructure includes the following features:

| Feature | Workspace type | Description |
| ------- | -------------- | ----------- |
| [**Managed Prometheus**][azure-monitor-prometheus] | [Azure Monitor workspace][azure-monitor-workspace] | Stores Prometheus metrics scraped from your cluster. |
| [**Data plane logs**][appnet-data-plane-logs] | [Log Analytics workspace][log-analytics-workspace] | Stores application and in-cluster component logs collected through Container Insights. |
| [**Control plane logs**][appnet-control-plane-logs] | [Log Analytics workspace][log-analytics-workspace] | Stores Istiod logs collected through a diagnostic setting on the Application Network member resource. |
| [**Dashboards with Grafana**][azure-monitor-grafana] | [Azure Monitor workspace][azure-monitor-workspace] | Links to your Azure Monitor workspace to visualize Prometheus metrics in Grafana dashboards. |

## Workspace options for Azure Kubernetes Application Network observability

You can create new workspaces or use existing ones. Configure the Azure Monitor workspace when you enable [metrics collection][appnet-metrics], and configure the Log Analytics workspace when you enable Container Insights or create a member diagnostic setting for [logs][appnet-logs]. For more information about workspace options, see [Create workspaces][azure-monitor-create-workspaces].

Configure metrics collection, data plane log collection, and control plane diagnostic logs separately. A workspace alone doesn't enable collection. Envoy access logs also require a Telemetry configuration and traffic through the relevant proxy.

## Observability limitations

Azure Kubernetes Application Network currently doesn't support tracing or control plane metrics.

## Related content

To learn how to configure observability for your Azure Kubernetes Application Network members, see the following articles:

- [Configure and view Azure Kubernetes Application Network metrics][appnet-metrics]
- [Monitor logs in Azure Kubernetes Application Network][appnet-logs]

<!--- LINKS --->
[azure-monitor]: /azure/azure-monitor/fundamentals/overview
[azure-monitor-prometheus]: /azure/azure-monitor/metrics/prometheus-metrics-overview
[azure-monitor-workspace]: /azure/azure-monitor/metrics/azure-monitor-workspace-overview
[log-analytics-workspace]: /azure/azure-monitor/logs/log-analytics-workspace-overview
[azure-monitor-grafana]: /azure/azure-monitor/visualize/visualize-grafana-overview
[azure-monitor-create-workspaces]: /azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli#create-workspaces
[appnet-data-plane-logs]: ./logs.md#enable-data-plane-logs
[appnet-control-plane-logs]: ./logs.md#enable-control-plane-logs
[appnet-metrics]: ./metrics.md
[appnet-logs]: ./logs.md
