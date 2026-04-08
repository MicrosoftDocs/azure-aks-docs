---
title: Container network metrics overview
description: An overview of container network metrics collection and filtering in Advanced Container Networking Services for Azure Kubernetes Service (AKS).
author: shaifaligargmsft
ms.author: shaifaligarg
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: overview
ms.date: 05/10/2025

---

# What are container network metrics?

Every pod, service, and node in a Kubernetes cluster is constantly generating network activity: connections opening, packets being forwarded or dropped, DNS queries resolving or failing. Understanding that activity is essential for debugging, capacity planning, and keeping services healthy. But most monitoring setups fall short in two ways:

* **Not enough visibility.** Node-level aggregates tell you something is wrong, but not *where*. Without pod-level breakdowns that include source and destination context, isolating a failing workload means guessing.
* **Too much data at scale.** A cluster running hundreds of microservices can produce thousands of metric time series per node. Collecting everything drives up storage costs and slows down dashboards.

Container network metrics in [Advanced Container Networking Services](advanced-container-networking-services-overview.md) for Azure Kubernetes Service (AKS) tackle both. The feature captures network metrics at the node level and the pod level across Cilium and non-Cilium data planes, on Linux and Windows. On Cilium clusters, you can go a step further with source-level filtering, which lets you select exactly which namespaces, workloads, and metric types are collected *before* data leaves the node.

The result: actionable network observability on any supported data plane, with optional cost-efficient filtering on Cilium.

[!INCLUDE [azure linux 2.0 retirement](./includes/azure-linux-retirement.md)]

## Key benefits

* **Node and pod-level granularity.** Track traffic volume, drop rates, and connection states at the node level for infrastructure health. Drill down to individual pods with source and destination labels to pinpoint the exact workload causing an issue.

* **Faster troubleshooting.** When a service starts dropping packets or DNS queries fail, pod-level metrics let you isolate the problem to a specific pod, namespace, or protocol in seconds, not hours.

* **Flexible visualization.** Store metrics in Azure Managed Prometheus and visualize in Azure Managed Grafana (fully managed), or bring your own Prometheus and Grafana infrastructure.

* **Scalable by design.** The pipeline handles large, dynamic clusters with hundreds of nodes and thousands of pods without requiring you to choose between comprehensive coverage and manageable data volumes.

* **Targeted observability (Cilium clusters).** On Cilium clusters, source-level filtering lets you define the namespaces, pod labels, or metric types you care about and collect only those. No post-collection trimming required.

* **Cost efficiency (Cilium clusters).** Filtering at the source eliminates irrelevant metric streams before they reach your Prometheus backend, which reduces storage and query costs while keeping dashboards focused.

## How it works

Container network metrics are collected through a straightforward pipeline:

1. **Capture.** eBPF-based agents collect network metrics on every node: traffic volume, dropped packets, TCP connection states, DNS resolution, and Layer 4/Layer 7 flows. Both Cilium and non-Cilium data planes are supported, with Linux and Windows coverage on non-Cilium clusters.
1. **Filter (Cilium clusters only).** On Cilium clusters, source-level filtering can optionally narrow collection by namespace, pod label, or metric type so only relevant data is retained. You can combine filtering dimensions. For example, collect only DNS and drop metrics for pods in your `production` namespace that carry a specific service label. On non-Cilium clusters, all supported metrics are collected by default.
1. **Store and visualize.** Metrics are stored in Prometheus format. Visualize them in Azure Managed Grafana (fully managed) or your own self-managed Prometheus and Grafana infrastructure.

On Cilium clusters where filtering is enabled, your Prometheus backend ingests only the metrics you've chosen, which reduces storage costs, speeds up queries, and keeps dashboards focused.

To configure filtering, see [Configure container network metrics filtering](./how-to-configure-container-network-metrics-filtering.md).

## When to use container network metrics

Container network metrics are designed for teams that need focused, actionable network data rather than raw telemetry. Common scenarios include:

* **Debugging a specific workload.** Use pod-level metrics to isolate packet drops, TCP resets, or DNS failures for a particular service. On Cilium clusters, filtering can narrow collection to just that namespace or pod label, cutting through cluster-wide noise.
* **Monitoring multi-tenant clusters.** Track network health per namespace so each team has visibility into its own traffic patterns. On Cilium clusters, scoped filtering keeps collection limited to tenant-specific namespaces.
* **Capacity planning.** Track forwarded and dropped byte counts per node to identify saturated links or imbalanced workload placement.
* **DNS health monitoring.** Surface DNS query failures and slow resolution times to catch issues before they cascade into application errors.
* **Reducing observability costs at scale.** In large clusters, metrics can generate thousands of time series per node. On Cilium clusters, filtering at the source keeps ingestion volumes predictable and costs manageable.

## Metrics reference

### Node-level metrics

Node-level metrics provide aggregate traffic statistics per node — forwarded and dropped packets, byte counts, and connection states. These metrics are stored in Prometheus format and can be visualized in Grafana.

The following metrics are aggregated per node. All metrics include these labels:

- `cluster`
- `instance` (node name)

#### [Cilium](#tab/Cilium)

For Cilium data plane clusters, node-level metrics are available on Linux only. Cilium exposes the following metrics used by container network metrics:

| Metric name                    | Description                  | Extra labels          | Linux | Windows |
|--------------------------------|------------------------------|-----------------------|-------|---------|
| **cilium_forward_count_total** | Total forwarded packet count | `direction`           | ✅ | ❌ |
| **cilium_forward_bytes_total** | Total forwarded byte count   | `direction`           | ✅ | ❌ |
| **cilium_drop_count_total**    | Total dropped packet count   | `direction`, `reason` | ✅ | ❌ |
| **cilium_drop_bytes_total**    | Total dropped byte count     | `direction`, `reason` | ✅ | ❌ |

#### [Non-Cilium](#tab/non-Cilium)

For non-Cilium data plane scenarios, container network metrics are available for both Linux and Windows.

> [!NOTE]
> Due to a known bug, TCP resets temporarily aren't visible. The **networkobservability_tcp_flag_counters** metric isn't published on Linux at this time.

| Metric name                                    | Description | Extra labels | Linux | Windows |
|------------------------------------------------|-------------|--------------|-------|---------|
| **networkobservability_forward_count**         | Total forwarded packet count | `direction` | ✅ | ✅ |
| **networkobservability_forward_bytes**         | Total forwarded byte count | `direction` | ✅ | ✅ |
| **networkobservability_drop_count**            | Total dropped packet count | `direction`, `reason` | ✅ | ✅ |
| **networkobservability_drop_bytes**            | Total dropped byte count | `direction`, `reason` | ✅ | ✅ |
| **networkobservability_tcp_state**             | TCP active socket count by state | `state` | ✅ | ✅ |
| **networkobservability_tcp_connection_remote** | TCP active socket count by remote IP/port | `address` (IP), `port` | ✅ | ❌ |
| **networkobservability_tcp_connection_stats**  | TCP connection statistics (for example, Delayed ACKs, TCPKeepAlive, TCPSackFailures) | `statistic` | ✅ | ✅ |
| **networkobservability_tcp_flag_counters**     | TCP packet count by flag | `flag` | ❌ | ✅ |
| **networkobservability_ip_connection_stats**   | IP connection statistics | `statistic` | ✅ | ❌ |
| **networkobservability_udp_connection_stats**  | UDP connection statistics | `statistic` | ✅ | ❌ |
| **networkobservability_udp_active_sockets**    | UDP active socket count |  | ✅ | ❌ |
| **networkobservability_interface_stats**       | Interface statistics | InterfaceName, `statistic` | ✅ | ✅ |

---

### Pod-level metrics (Hubble metrics)

Pod-level metrics include source and destination pod information, so you can pinpoint network issues at the individual workload level. These metrics cover traffic volume, dropped packets, TCP resets, and Layer 4/Layer 7 flows.

DNS metrics (query counts, response codes, and errors) are collected by default on non-Cilium data planes. On Cilium data planes, DNS metrics require a Cilium FQDN network policy. You can also troubleshoot DNS in real time by using the Hubble CLI.

The following table describes the metrics that are aggregated per pod (node information is preserved).

All metrics include labels:

- `cluster`
- `instance` (node name)
- `source` or `destination`

  - For *outgoing traffic*, a `source` label indicates the source pod namespace and name.

  - For *incoming traffic*, a `destination` label indicates the destination pod namespace and name.

| Metric name                      | Description                  | Extra labels          | Linux | Windows |
|----------------------------------|------------------------------|-----------------------|-------|---------|
| **hubble_dns_queries_total**     | Total DNS requests by query  | `source` or `destination`, `query`, `qtypes` (query type) | ✅ | ❌ |
| **hubble_dns_responses_total**   | Total DNS responses by query/response | `source` or `destination`, `query`, `qtypes` (query type), `rcode` (return code), `ips_returned` (number of IPs) | ✅ | ❌ |
| **hubble_drop_total**            | Total dropped packet count | `source` or `destination`, `protocol`, `reason` | ✅ | ❌ |
| **hubble_tcp_flags_total**       | Total TCP packet count by flag | `source` or `destination`, `flag` | ✅ | ❌ |
| **hubble_flows_processed_total** | Total network flows processed (Layer 4/Layer 7 traffic) | `source` or `destination`, `protocol`, `verdict`, `type`, `subtype` | ✅ | ❌ |

---

## Limitations

**Platform and data plane:**

* Pod-level metrics are available only on Linux.
* Cilium data plane is supported starting with Kubernetes version 1.29.
* Source-level metrics filtering is available only on Cilium clusters.
* Metric labels have subtle differences between Cilium and non-Cilium clusters.

**DNS metrics:**

* On Cilium clusters, DNS metrics require a Cilium FQDN network policy, or you can use the Hubble CLI for real-time DNS troubleshooting.

**Known issues:**

* If a Hubble node agent goes down, the Hubble relay might crash, which can interrupt Hubble CLI sessions.

**FIPS support (non-Cilium data planes only):**

* FIPS isn't available on Ubuntu 20.04 nodes due to kernel restrictions. Use an Azure Linux node pool instead. This limitation doesn't apply to Cilium data planes. For updates, see the [AKS issue tracker](https://github.com/Azure/AKS/issues/4857).

| Operating system | FIPS support |
|---|---|
| Azure Linux 3.0 | Yes |
| Azure Linux 2.0 | Yes |
| Ubuntu 20.04 | No |

**Scale:**

* The managed service for Prometheus in Azure Monitor and Azure Managed Grafana impose service-specific scale limitations. For more information, see [Scrape Prometheus metrics at scale in Azure Monitor](/azure/azure-monitor/essentials/prometheus-metrics-scrape-scale).

## Pricing

> [!IMPORTANT]
> Advanced Container Networking Services is a paid offering.

For more information about pricing, see [Advanced Container Networking Services - Pricing](https://azure.microsoft.com/pricing/details/azure-container-networking-services/).

## Related content

* [Set up container network metrics](container-network-observability-how-to.md)
* [Configure container network metrics filtering](./how-to-configure-container-network-metrics-filtering.md)
* [Advanced Container Networking Services for AKS](./advanced-container-networking-services-overview.md)
* [Container Network Observability](./advanced-container-networking-services-overview.md#container-network-observability) in Advanced Container Networking Services
* [Container Network Security](./advanced-container-networking-services-overview.md#container-network-security) in Advanced Container Networking Services
