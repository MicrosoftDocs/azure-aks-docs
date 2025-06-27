---
title: Node and Pod level Network metrics with Advanced Container Networking Services
description: An overview of Container Network Metrics feature under container network observability in  Azure Kubernetes Service (AKS).
author: shaifaligargmsft
ms.author: shaifaligarg
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: concept-article
ms.date: 05/10/2025
---

# Overview of Container Network Metrics 
Advanced Container Networking Services in Azure Kubernetes Service (AKS) facilitates the collection of comprehensive container network metrics, providing valuable insights into the performance of containerized environments. This capability continuously captures essential metrics at the node and pod levels, including traffic volume, dropped packets, connection states, and DNS resolution times, enabling effective monitoring and optimization of network performance.

The ability to capture these metrics is essential for understanding how containers communicate, how traffic flows between services, and where bottlenecks or disruptions might be occurring. Advanced Container Networking Services integrates seamlessly with monitoring tools like Prometheus and Grafana, providing users with a complete view of networking metrics that can be used for in-depth troubleshooting, network optimization, and performance tuning.

In today’s cloud-native world, maintaining a healthy and efficient network in a dynamic containerized environment is vital to ensuring that applications perform as expected. Without proper visibility into network traffic and its patterns, identifying potential issues or inefficiencies becomes challenging.

### Key benefits 
-    Deep visibility into network performance
-    Enhanced troubleshooting and optimization
-    Proactive anomaly detection
-    Better resource management and scaling
-    Capacity planning and compliance
-    Simplified Metrics Storage and Visualization Options: Choose between:
    * **Azure Managed Prometheus and Grafana**: Azure manages the infrastructure and maintenance, allowing users to focus on configuring metrics and visualizing metrics.
    * **Bring Your Own (BYO) Prometheus and Grafana**: Users deploy and configure their own instances and manage the underlying infrastructure.

## Types of metrics captured

### Node-Level metrics
Understanding the health of your container network at the node-level is crucial for maintaining optimal application performance. These metrics provide insights into traffic volume, dropped packets, number of connections, etc. by node. The metrics are stored in Prometheus format and, as such, you can view them in Grafana.
The following metrics are aggregated per node. All metrics include labels:

* `cluster`
* `instance` (Node name)

#### [**Cilium**](#tab/Cilium)

For Cilium data plane scenarios, Container Network Observability provides metrics only for Linux. Windows is currently not supported.
Cilium exposes several metrics including the following used by Container Network Observability.

| Metric Name                    | Description                  | Extra Labels          |Linux | Windows |
|--------------------------------|------------------------------|-----------------------|-------|---------|
| **cilium_forward_count_total** | Total forwarded packet count | `direction`           | ✅ | ❌ |
| **cilium_forward_bytes_total** | Total forwarded byte count   | `direction`           | ✅ | ❌ |
| **cilium_drop_count_total**    | Total dropped packet count   | `direction`, `reason` | ✅ | ❌ |
| **cilium_drop_bytes_total**    | Total dropped byte count     | `direction`, `reason` | ✅ | ❌ |

#### [**Non-Cilium**](#tab/non-Cilium)

For non-Cilium data plane scenarios, Container Network Observability provides metrics for both Linux and Windows operating systems.
The table below outlines the different metrics generated.

> [!NOTE]
> Due to an identified bug, TCP resets are temporarily not visible. As a result, the networkobservability_tcp_flag_counters metric will not be published during this period. Our team is actively working on resolving this issue, and we provide updates once the fix is implemented. We apologize for any inconvenience and appreciate your patience.

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

---

### Pod-Level metrics (Hubble Metrics)

These Prometheus metrics include source and destination pod information allowing you to pinpoint network-related issues at a granular level. Metrics cover traffic volume, dropped packets, TCP resets, L4/L7 packet flows, etc. There are also DNS metrics (currently only for Non-Cilium data planes), covering DNS errors, and DNS requests missing responses. The following metrics are aggregated per pod (node information is preserved). All metrics include labels:

* `cluster`
* `instance` (Node name)
* `source` or `destination`

For *outgoing traffic*, there will be a `source` label with source pod namespace/name.
For *incoming traffic*, there will be a `destination` label with destination pod namespace/name.

| Metric Name                      | Description                  | Extra Labels          | Linux | Windows |
|----------------------------------|------------------------------|-----------------------|-------|---------|
| **hubble_dns_queries_total**     | Total DNS requests by query  | `source` or `destination`, `query`, `qtypes` (query type) | ✅ | ❌ |
| **hubble_dns_responses_total**   | Total DNS responses by query/response | `source` or `destination`, `query`, `qtypes` (query type), `rcode` (return code), `ips_returned` (number of IPs) | ✅ | ❌ |
| **hubble_drop_total**            | Total dropped packet count | `source` or `destination`, `protocol`, `reason` | ✅ | ❌ |
| **hubble_tcp_flags_total**       | Total TCP packets count by flag. | `source` or `destination`, `flag` | ✅ | ❌ |
| **hubble_flows_processed_total** | Total network flows processed (L4/L7 traffic) | `source` or `destination`, `protocol`, `verdict`, `type`, `subtype` | ✅ | ❌ |

### Limitations

* Pod-level metrics are available only on Linux.
* Cilium data plane is supported starting with Kubernetes version 1.29.
* Metric labels have subtle differences between Cilium and non-Cilium clusters.
* For Cilium based clusters, DNS metrics are only available for pods that have Cilium Network policies (CNP) configured on their clusters.
* Flow logs are not currently available in the air gapped cloud.
* Hubble relay may crash if one of the Hubble node agents goes down and may cause interruptions to Hubble CLI.

### Scale

Azure managed Prometheus and Grafana impose service-specific scale limitations. For more information, see [Scrape Prometheus metrics at scale in Azure Monitor](/azure/azure-monitor/essentials/prometheus-metrics-scrape-scale).


## Pricing
> [!IMPORTANT]
> Advanced Container Networking Services is a paid offering. For more information about pricing, see [Advanced Container Networking Services - Pricing](https://azure.microsoft.com/pricing/details/azure-container-networking-services/).

## Next steps

* To create an AKS cluster with Container Network Observability to capture Metrics, see [Setup Container Network Observability for Azure Kubernetes Service (AKS)](container-network-observability-how-to.md).
* For more information about Advanced Container Networking Services for Azure Kubernetes Service (AKS), see [advanced-container-networking-services-overview](https://azure.microsoft.com/pricing/details/azure-container-networking-services/).
* Explore Container Network Observability features in Advanced Container Networking Services in [What is Container Network Observability?](./advanced-container-networking-services-overview.md#container-network-observability).
* Explore Container Network Security features in Advanced Container Networking Services in [What is Container Network Security?](./advanced-container-networking-services-overview.md#container-network-security).


