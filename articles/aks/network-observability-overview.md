---
title: What is Azure Kubernetes Service (AKS) Network Observability?
description: An overview of network observability for Azure Kubernetes Service (AKS).
author: asudbring
ms.author: allensu
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: overview
ms.date: 06/20/2023
---

# What is Azure Kubernetes Service (AKS) Network Observability?

Kubernetes is a powerful tool for managing containerized applications. As containerized environments grow in complexity, it can be difficult to identify and troubleshoot networking issues in a Kubernetes cluster.

Network observability is an important part of maintaining a healthy and performant Kubernetes cluster. By collecting and analyzing data about network traffic, you can gain insights into how your cluster is operating and identify potential problems before they cause outages or performance degradation.

:::image type="content" source="./media/network-observability-overview/network-observability-components.png" alt-text="Diagram of Network Observability components.":::

## Overview of Network Observability add-on in AKS

Networking Observability add-on operates seamlessly on Non-Cilium and Cilium data-planes. It empowers customers with enterprise-grade capabilities for DevOps and SecOps. This solution offers a centralized way to monitor network issues in your cluster for cluster network administrators, cluster security administrators, and DevOps engineers.

When the Network Observability add-on is enabled, it allows for the collection and conversion of useful metrics into Prometheus format, which can then be visualized in Grafana.
Azure has offerings for managed [Prometheus](/azure/azure-monitor/essentials/prometheus-metrics-overview) and [Grafana](/azure/azure-monitor/visualize/grafana-plugin).

* **Azure managed Prometheus and Grafana:** A managed service provided by Azure, taking care of the infrastructure and maintenance of Prometheus and Grafana, allowing you to focus on configuring and visualizing your metrics.

* **Multi CNI Support:** Network Observability add-on supports both Azure CNI and Kubenet network plugins.

## Metrics

Network Observability add-on currently only supports node level metrics.
Cilium and Non-Cilium dataplanes have different metrics, yet the Grafana dashboard works for seamlessly for both.

All metrics have the following labels:
- `cluster`
- `instance` (Node name)

### [**Non-Cilium**](#tab/non-cilium)

On Non-Cilium dataplane, the Network Observability add-on provides metrics in both Linux and Windows platforms.
The below table outlines the different metrics generated.

| Metric Name                                    | Description | Extra Labels | Linux | Windows |
|------------------------------------------------|-------------|--------------|-------|---------|
| **networkobservability_forward_count**         | Total forwarded packet count | `direction` | ✅ | ✅ |
| **networkobservability_forward_bytes**         | Total forwarded byte count | `direction` | ✅ | ✅ |
| **networkobservability_drop_count**            | Total dropped packet count | `direction`, `reason` | ✅ | ✅ |
| **networkobservability_drop_bytes**            | Total dropped byte count | `direction`, `reason` | ✅ | ✅ |
| **networkobservability_tcp_state**             | TCP currently active socket count by TCP state. | `state` | ✅ | ✅ |
| **networkobservability_tcp_connection_remote** | TCP currently active socket count by remote IP/port. | `address` (IP), `port` | ✅ | ❌ |
| **networkobservability_tcp_connection_stats**  | TCP connection statistics. (ex: Delayed ACKs, TCPKeepAlive, TCPSackFailures) | `statistic` | ✅ | ✅ |
| **networkobservability_tcp_flag_counters**     | TCP packets count by flag. | `flag` | ❌ | ✅ |
| **networkobservability_ip_connection_stats**   | IP connection statistics. | `statistic` | ✅ | ❌ |
| **networkobservability_udp_connection_stats**  | UDP connection statistics. | `statistic` | ✅ | ❌ |
| **networkobservability_udp_active_sockets**    | UDP currently active socket count |  | ✅ | ❌ |
| **networkobservability_interface_stats**       | Interface statistics. | InterfaceName, `statistic` | ✅ | ✅ |

### [**Cilium**](#tab/cilium)

Cilium currently only supports Linux nodes.
It exposes several metrics including the following for network observability.

| Metric Name                    | Description                  | Extra Labels          |
|--------------------------------|------------------------------|-----------------------|
| **cilium_forward_count_total** | Total forwarded packet count | `direction`           |
| **cilium_forward_bytes_total** | Total forwarded byte count   | `direction`           |
| **cilium_drop_count_total**    | Total dropped packet count   | `direction`, `reason` |
| **cilium_drop_bytes_total**    | Total dropped byte count     | `direction`, `reason` |

---

## Limitations

* Pod level metrics aren't supported.

## Scale

Certain scale limitations apply when you use Azure managed Prometheus and Grafana. For more information, see [Scrape Prometheus metrics at scale in Azure Monitor](/azure/azure-monitor/essentials/prometheus-metrics-scrape-scale)

## Next steps

- For more information about Azure Kubernetes Service (AKS), see [What is Azure Kubernetes Service (AKS)?](/azure/aks/intro-kubernetes).

- To create an AKS cluster with Network Observability and Azure managed Prometheus and Grafana, see [Setup Network Observability for Azure Kubernetes Service (AKS) - Azure managed Prometheus and Grafana](advanced-network-observability-cli.md).
