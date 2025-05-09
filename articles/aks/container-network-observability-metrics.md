---
title: Node and Pod level Network metrics with Advanced Container Networking Services (ACNS)
description: An overview of Metric capture feature under container network observability in  Azure Kubernetes Service (AKS).
author: Khushbu-Parekh
ms.author: kparekh
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: concept-article
ms.date: 05/10/2024
---

# What is Container Network Observability?

Container Network Observability is a feature of the [Advanced Container Networking Services](advanced-container-networking-services-overview.md) suite. It equips you with next-level monitoring and diagnostics tools, providing unparalleled visibility into your containerized workloads. These tools empower you to pinpoint and troubleshoot network issues with ease, ensuring optimal performance for your applications.

Container Network Observability is compatible with all Linux workloads seamlessly integrating with Hubble regardless of whether the underlying data plane is Cilium or non-Cilium (both are supported) ensuring flexibility for your container networking needs.

:::image type="content" source="./media/advanced-container-networking-services/advanced-network-observability.png" alt-text="Diagram of Container Network Observability.":::

> [!NOTE]
> For Cilium data plane scenarios, Container Network Observability is available beginning with Kubernetes version 1.29.
> Container Network Observability is supported on all Linux distributions including Azure Linux beginning with version 2.0.

## Features of Container Network Observability

Container Network Observability offers the following capabilities to monitor network-related issues in your cluster:

* **Node-Level Metrics:** Understanding the health of your container network at the node-level is crucial for maintaining optimal application performance. These metrics provide insights into traffic volume, dropped packets, number of connections, etc. by node. The metrics are stored in Prometheus format and, as such, you can view them in Grafana.

* **Hubble Metrics (DNS and Pod-Level Metrics):** These Prometheus metrics include source and destination pod information allowing you to pinpoint network-related issues at a granular level. Metrics cover traffic volume, dropped packets, TCP resets, L4/L7 packet flows, etc. There are also DNS metrics (currently only for Non-Cilium data planes), covering DNS errors and DNS requests missing responses.

* **Hubble Flow Logs:** Flow logs provide deep visibility into your cluster's network activity. All communications to and from pods are logged allowing you to investigate connectivity issues over time. Flow logs help answer questions such as: did the server receive the client's request? What is the round-trip latency between the client's request and server's response?

  * **Hubble CLI:** The Hubble Command-Line Interface (CLI) can retrieve flow logs across the entire cluster with customizable filtering and formatting.

  * **Hubble UI:** Hubble UI is a user-friendly browser-based interface for exploring cluster network activity. It creates a service-connection graph based on flow logs, and displays flow logs for the selected namespace. Users are responsible for provisioning and managing the infrastructure required to run Hubble UI.

## Key Benefits of Container Network Observability

* **CNI-Agnostic**: Supported on all Azure CNI variants including kubenet.

* **Cilium and Non-Cilium**: Provides a uniform, seamless experience across both Cilium and non-Cilium data planes.

* **eBPF-Based Network Observability:** Leverages eBPF (extended Berkeley Packet Filter) for performance and scalability to identify potential bottlenecks and congestion issues before they impact application performance. Gain insights into key network health indicators, including traffic volume, dropped packets, and connection information.

* **Deep Visibility into Network Activity:** Understand how your applications are communicating with each other through detailed network flow logs.

* **Simplified Metrics Storage and Visualization Options**: Choose between:
  * **Azure Managed Prometheus and Grafana**: Azure manages the infrastructure and maintenance, allowing users to focus on configuring metrics and visualizing metrics.
  * **Bring Your Own (BYO) Prometheus and Grafana**: Users deploy and configure their own instances and manage the underlying infrastructure.

## Metrics

### Node-Level Metrics

The following metrics are aggregated per node. All metrics include labels:

* `cluster`
* `instance` (Node name)

#### [**Cilium**](#tab/cilium)

For Cilium data plane scenarios, Container Network Observability provides metrics only for Linux, Windows is currently not supported.
Cilium exposes several metrics including the following used by Container Network Observability.

| Metric Name                    | Description                  | Extra Labels          |Linux | Windows |
|--------------------------------|------------------------------|-----------------------|-------|---------|
| **cilium_forward_count_total** | Total forwarded packet count | `direction`           | ✅ | ❌ |
| **cilium_forward_bytes_total** | Total forwarded byte count   | `direction`           | ✅ | ❌ |
| **cilium_drop_count_total**    | Total dropped packet count   | `direction`, `reason` | ✅ | ❌ |
| **cilium_drop_bytes_total**    | Total dropped byte count     | `direction`, `reason` | ✅ | ❌ |

#### [**Non-Cilium**](#tab/non-cilium)

For non-Cilium data plane scenarios, Container Network Observability provides metrics for both Linux and Windows operating systems.
The table below outlines the different metrics generated.

> [!NOTE]
> Due to an identified bug, TCP resets are temporarily not visible. As a result, the networkobservability_tcp_flag_counters metric will not be published during this period. Our team is actively working on resolving this issue, and we will provide updates once the fix is implemented. We apologize for any inconvenience and appreciate your patience.

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

### Pod-Level Metrics (Hubble Metrics)

The following metrics are aggregated per pod (node information is preserved). All metrics include labels:

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
* Metric labels may have subtle differences between Cilium and non-Cilium clusters.
* For Cilium based clusters, DNS metrics are only available for pods that have Cilium Network policies (CNP) configured on their clusters.
* Flow logs are not currently available in the air gapped cloud.
* Hubble relay may crash if one of the hubble node agents goes down and may cause interruptions to Hubble CLI.

### Scale

Azure managed Prometheus and Grafana impose service-specific scale limitations. For more information, see [Scrape Prometheus metrics at scale in Azure Monitor](/azure/azure-monitor/essentials/prometheus-metrics-scrape-scale).


## Pricing
> [!IMPORTANT]
> Advanced Container Networking Services is a paid offering. For more information about pricing, see [Advanced Container Networking Services - Pricing](https://azure.microsoft.com/pricing/details/azure-container-networking-services/).

## Next steps

* To create an AKS cluster with Container Network Observability, see [Setup Container Network Observability for Azure Kubernetes Service (AKS)](container-network-observability-how-to.md).


