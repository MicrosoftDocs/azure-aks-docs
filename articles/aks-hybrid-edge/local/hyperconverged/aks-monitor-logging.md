---
title: Monitor and log data
description: Learn how to create and access monitoring and logging data for AKS Hybrid and Edge.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 01/17/2024
ms.reviewer: guanghu
ms.custom: hyperconverged

# Intent: As an IT Pro, I want to learn how to monitor and view logging data for AKS.
# Keyword: monitor and logging data, Prometheus

---

# Monitor and log data

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)], AKS on Azure Local

This article describes how to monitor your AKS Hybrid and Edge deployment using on-premises monitoring. Two types of monitoring and logging solutions are available, as described in the following table:

|      Solution                    |      Azure connectivity                                                               |      Support and service                                                                                                               |      Cost                                                   |
|----------------------------------|---------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------|
|     Container Insights         |     Requires connecting the Kubernetes cluster to Azure using Azure Arc for Kubernetes.    |     Full support and servicing from Microsoft.                                                                                       |     Requires signing up for the Azure Monitor service.    |
|     On-premises monitoring     |     Doesn't require Azure connectivity.                                             |     Supported as open-source software by Microsoft (with no support agreement or SLAs), the community, and/or external vendors.    |     Vendor-dependent.                                       |

You can choose Container Insights or on-premises monitoring, depending on your monitoring use cases. For Container Insights, see [Enable Container Insights](/azure/azure-monitor/containers/kubernetes-monitoring-enable).

## Monitoring solution overview

**Prometheus** is a monitoring and alerting toolkit you can use for monitoring containerized workloads. As part of the Prometheus solution in AKS Hybrid and Edge, the following components are deployed and automatically configured:

- [Prometheus operator](https://github.com/prometheus-operator/prometheus-operator)
- [Prometheus](https://github.com/prometheus/prometheus)
- [Kube state metrics](https://github.com/kubernetes/kube-state-metrics)
- [Node exporter](https://github.com/prometheus/node_exporter)
- [Windows exporter](https://github.com/prometheus-community/windows_exporter)

The deployment is based on the publicly available [Kube-Prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) helm chart, which is extended to support the Windows exporter and secures metrics scraping between Prometheus and agents. Once you deploy the Prometheus solution, the node exporter runs on each Linux node, and the Windows exporter runs on each Windows node.

> [!NOTE]
> Since the Prometheus operator, Prometheus, and Kube state metrics components are only supported on Linux, you must provision at least one Linux node in your Kuberneted cluster to deploy this solution.

The objects and endpoints that the Prometheus solution scrapes include the following items:

- Kube state metrics to collect [various metrics provided by Kubernetes](https://github.com/kubernetes/kube-state-metrics/tree/master/docs#exposed-metrics) 
- Kubernetes API server
- Kubelet
- Node exporter to collect metrics for Linux nodes
- Windows exporter to collect metrics for Windows nodes

## Deploy monitoring solution

Prometheus is an open-source monitoring system with a dimensional data model, flexible query language, efficient time series database and modern alerting approach. Grafana is a tool used to view, query, and visualize metrics on the Grafana dashboards. It can be configured to use Prometheus as the data source. Usually, they are used together for Kubernetes cluster monitoring.

To view the Grafana dashboards available in AKS Hybrid and Edge, see [Grafana dashboards available in AKS](https://github.com/microsoft/AKS-Arc-Apps/blob/main/Monitoring/Grafana.md#grafana-dashboards-available-in-aks-hci).

You can view Microsoft's deployment [guidance on GitHub](https://github.com/microsoft/AKS-Arc-Apps/tree/main/Monitoring) to deploy Prometheus on your Kubernetes cluster and configure Grafana to use Prometheus as data source. You can also follow any publicly available documentation to deploy any specific version of Prometheus or Grafana.

## Next steps

- [Deploy a Linux application on a Kubernetes cluster](../../windows-server/deploy-linux-application.md).
- [Deploy a Windows Server application on a Kubernetes cluster](../../windows-server/deploy-windows-application.md).
- [Kubernetes core concepts](../../windows-server/kubernetes-concepts.md).
