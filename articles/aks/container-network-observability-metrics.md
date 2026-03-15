---
title: Node and Pod Metrics with Advanced Container Networking Services
description: Get an overview of container network metrics in Advanced Container Networking Services for Azure Kubernetes Service (AKS).
author: shaifaligargmsft
ms.author: shaifaligarg
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: overview
ms.date: 05/10/2025
---

# What is container network metrics?

Advanced Container Networking Services in Azure Kubernetes Service (AKS) facilitates the collection of comprehensive container network metrics to give you valuable insights into the performance of your containerized environment. The capability continuously captures essential metrics at the node level and pod level, including traffic volume, dropped packets, connection states, and Domain Name System (DNS) resolution times for effective monitoring and optimizing network performance.

Capturing these metrics is essential for understanding how containers communicate, how traffic flows between services, and where bottlenecks or disruptions might occur. Advanced Container Networking Services integrates seamlessly with monitoring tools like Prometheus and Grafana to give you a complete view of networking metrics. Use the metrics for in-depth troubleshooting, network optimization, and performance tuning.

In a cloud-native world, maintaining a healthy and efficient network in a dynamic containerized environment is vital to ensuring that applications perform as expected. Without proper visibility into network traffic and its patterns, identifying potential issues or inefficiencies becomes challenging.

[!INCLUDE [azure linux 2.0 retirement](./includes/azure-linux-retirement.md)]

## Key benefits

- Deep visibility into network performance
- Enhanced troubleshooting and optimization
- Proactive anomaly detection
- Better resource management and scaling
- Capacity planning and compliance
- Source-level metrics filtering for cost optimization and noise reduction with [container network metrics filtering](#container-network-metrics-filtering-preview)
- Simplified metrics storage and visualization options. Choose between:

  - **Azure managed service for Prometheus and Azure Managed Grafana**: Azure manages the infrastructure and maintenance, so you can focus on configuring metrics and visualizing metrics.
  - **Bring your own (BYO) Prometheus and Grafana**: You deploy and configure your own instances of Prometheus and Grafana, and you manage the underlying infrastructure.

## Metrics captured

### Node-level metrics

Understanding the health of your container network at the node-level is crucial for maintaining optimal application performance. These metrics provide insights into traffic volume, dropped packets, number of connections, and other data by node. The metrics are stored in Prometheus format, so, you can view them in Grafana.

The following metrics are aggregated per node. All metrics include one of these labels:

- `cluster`
- `instance` (node name)

#### [Cilium](#tab/Cilium)

For Cilium data plane scenarios, Container Network Observability provides metrics only for Linux. Windows is currently not supported.
Cilium exposes several metrics including the following used by Container Network Observability.

| Metric name                    | Description                  | Extra labels          |Linux | Windows |
|--------------------------------|------------------------------|-----------------------|-------|---------|
| **cilium_forward_count_total** | Total forwarded packet count | `direction`           | ✅ | ❌ |
| **cilium_forward_bytes_total** | Total forwarded byte count   | `direction`           | ✅ | ❌ |
| **cilium_drop_count_total**    | Total dropped packet count   | `direction`, `reason` | ✅ | ❌ |
| **cilium_drop_bytes_total**    | Total dropped byte count     | `direction`, `reason` | ✅ | ❌ |

#### [Non-Cilium](#tab/non-Cilium)

For non-Cilium data plane scenarios, Container Network Observability provides metrics for both Linux and Windows operating systems.

Generated metrics are outlined in the following table.

| Metric name | Description | Extra labels | Linux | Windows |
|-------------|-------------|--------------|-------|---------|
| **networkobservability_conntrack_bytes_rx** | Conntrack RX byte count | | ✅ | ❌ |
| **networkobservability_conntrack_bytes_tx** | Conntrack TX byte count | | ✅ | ❌ |
| **networkobservability_conntrack_packets_rx** | Conntrack RX packet count | | ✅ | ❌ |
| **networkobservability_conntrack_packets_tx** | Conntrack TX packet count | | ✅ | ❌ |
| **networkobservability_conntrack_total_connections** | Total conntrack connections | | ✅ | ❌ |
| **networkobservability_dns_request_count** | DNS request count | | ✅ | ❌ |
| **networkobservability_dns_response_count** | DNS response count | | ✅ | ❌ |
| **networkobservability_drop_bytes** | Total dropped byte count | `reason`, `direction` | ✅ | ❌ |
| **networkobservability_drop_count** | Total dropped packet count | `reason`, `direction` | ✅ | ✅ |
| **networkobservability_forward_bytes** | Total forwarded byte count | `direction` | ✅ | ✅ |
| **networkobservability_forward_count** | Total forwarded packet count | `direction` | ✅ | ✅ |
| **networkobservability_infiniband_counter_stats** | InfiniBand counter statistics | `statistic_name`, `device`, `port` | ✅ | ❌ |
| **networkobservability_infiniband_status_params** | InfiniBand status parameters | `statistic_name`, `interface_name` | ✅ | ❌ |
| **networkobservability_interface_stats** | Interface statistics (rx/tx packets, drops, etc.) | `interface_name`, `statistic_name` | ✅ | ❌ |
| **networkobservability_ip_connection_stats** | IP connection statistics | `statistic_name` | ✅ | ❌ |
| **networkobservability_node_apiserver_handshake_latency** | TCP handshake latency to API server | | ✅ | ❌ |
| **networkobservability_node_apiserver_latency** | Node to API server latency | | ✅ | ❌ |
| **networkobservability_node_apiserver_no_response** | No response from API server count | | ✅ | ❌ |
| **networkobservability_node_connectivity_latency_seconds** | Node-to-node connectivity latency | `source_node_name`, `target_node_name` | ✅ | ✅ |
| **networkobservability_node_connectivity_status** | Node-to-node connectivity status (ICMP/HTTP) | `source_node_name`, `target_node_name` | ✅ | ✅ |
| **networkobservability_tcp_connection_remote** | TCP active socket count by remote IP | `address` | ✅ | ❌ |
| **networkobservability_tcp_connection_stats** | TCP connection statistics (e.g., DelayedACKs, TCPKeepAlive, TCPSackFailures) | `statistic_name` | ✅ | ✅ |
| **networkobservability_tcp_flag_gauges** | TCP packet counts by flag | `direction`, `flag` | ❌ | ✅ |
| **networkobservability_tcp_retransmission_count** | TCP retransmission count | | ✅ | ❌ |
| **networkobservability_tcp_state** | TCP active socket count by state | `state` | ✅ | ❌ |
| **networkobservability_udp_connection_stats** | UDP connection statistics | `statistic_name` | ✅ | ❌ |
| **networkobservability_windows_hns_stats** | Windows HNS statistics (packets sent/received) | `direction` | ❌ | ✅ |

---

### Pod-level metrics (Hubble metrics)

These Prometheus metrics include source and destination pod information so that you can pinpoint network-related issues at a granular level. Metrics cover information like traffic volume, dropped packets, TCP resets, and Layer 4/Layer 7 packet flows. DNS metrics like DNS errors and DNS requests missing responses are collected by default for non-Cilium data planes. For Cilium data planes, a Cilium FQDN network policy is required to collect DNS metrics, or customers can also troubleshoot DNS using Hubble CLI and observing real-time logs.

The following table describes the metrics that are aggregated per pod (node information is preserved).

All metrics include labels:

- `cluster`
- `instance` (node name)
- `source` or `destination`

  - For *outgoing traffic*, a `source` label that indicates the source pod namespace and name is applied.

  - For *incoming traffic*, a `destination` label that indicates the destination pod namespace and name is applied.

| Metric name                      | Description                  | Extra Labels          | Linux | Windows |
|----------------------------------|------------------------------|-----------------------|-------|---------|
| **hubble_dns_queries_total**     | Total DNS requests by query  | `source` or `destination`, `query`, `qtypes` (query type) | ✅ | ❌ |
| **hubble_dns_responses_total**   | Total DNS responses by query/response | `source` or `destination`, `query`, `qtypes` (query type), `rcode` (return code), `ips_returned` (number of IPs) | ✅ | ❌ |
| **hubble_drop_total**            | Total dropped packet count | `source` or `destination`, `protocol`, `reason` | ✅ | ❌ |
| **hubble_tcp_flags_total**       | Total TCP packets count by flag | `source` or `destination`, `flag` | ✅ | ❌ |
| **hubble_flows_processed_total** | Total network flows processed (Layer 4/Layer 7 traffic) | `source` or `destination`, `protocol`, `verdict`, `type`, `subtype` | ✅ | ❌ |

---

## Container network metrics filtering (Preview)

Now that you have the ability to collect comprehensive metrics at both node and pod levels, you might find yourself dealing with a significant volume of data. To help reduce noise and optimize storage costs, Container Network Observability introduces **container network metrics filtering**. This feature enables you to filter metrics at the source before they are collected and stored, giving you control over which metrics are most relevant to your specific monitoring and troubleshooting needs. This feature is only available for Cilium clusters.

Container network metrics filtering is particularly valuable in large-scale production environments where the sheer volume of metrics can impact storage costs and query performance. By filtering out unnecessary metrics early in the collection process, you can focus on the data that matters most to your operations while maintaining the visibility you need for effective network monitoring.

The filtering capability supports multiple dimensions including namespace-based filtering to focus on specific applications, pod and label-based filtering for targeted monitoring, and metric-specific filtering to collect only the types of metrics that are essential for your use case. This flexibility allows you to strike the right balance between comprehensive observability and cost-effective operations.

To learn more on how to enable container network metrics filtering, see [How to Configure Container Network Metrics Filtering ](./how-to-configure-container-network-metrics-filtering.md).

### Limitations

* Pod-level metrics are available only on Linux.
* Cilium data plane is supported starting with Kubernetes version 1.29.
* Metric labels have subtle differences between Cilium and non-Cilium clusters.
* For Cilium based clusters, DNS metrics are only available for pods that have Cilium Network policies (CNP) configured on their clusters, or customers can also troubleshoot DNS using Hubble CLI and observing real-time logs.
* Flow logs are not currently available in the air gapped cloud.
* Hubble relay may crash if one of the Hubble node agents goes down and may cause interruptions to Hubble CLI.
* When using Advanced Container Networking Services (ACNS) on non-Cilium data planes, FIPS support isn't available on Ubuntu 20.04 nodes due to kernel restrictions. To enable FIPS in this scenario, you must use an Azure Linux node pool. This limitation is expected to be resolved with the release of Ubuntu 22 FIPS. For updates, see the [AKS issue tracker](https://github.com/Azure/AKS/issues/4857).
* Container network metrics filtering is only available for Cilium Clusters. 

Refer to the FIPS support matrix below:

| Operating System    |  FIPS Support |
|---------------------|---------------|
| Azure Linux 3.0     | Yes           |
| Azure Linux 2.0     | Yes           |
| Ubuntu 20.04        | No            |

This limitation does not apply when ACNS is running on Cilium data planes.

### Scale

The managed service for Prometheus in Azure Monitor and Azure Managed Grafana impose service-specific scale limitations. For more information, see [Scrape Prometheus metrics at scale in Azure Monitor](/azure/azure-monitor/essentials/prometheus-metrics-scrape-scale).

## Pricing

> [!IMPORTANT]
> Advanced Container Networking Services is a paid offering.

For more information about pricing, see [Advanced Container Networking Services - Pricing](https://azure.microsoft.com/pricing/details/azure-container-networking-services/).

## Related content

- To create an AKS cluster by using Container Network Observability to capture metrics, see [Set up Container Network Observability for AKS](container-network-observability-how-to.md).
- Get more information about [Advanced Container Networking Services for AKS](./advanced-container-networking-services-overview.md).
- Explore the [Container Network Observability feature](./advanced-container-networking-services-overview.md#container-network-observability) in Advanced Container Networking Services.
- Explore the [Container Network Security feature](./advanced-container-networking-services-overview.md#container-network-security) in Advanced Container Networking Services.
