---
title: Container network metrics overview
description: An overview of container network metrics collection and filtering in Advanced Container Networking Services for Azure Kubernetes Service (AKS).
author: shaifaligargmsft
ms.author: shaifaligarg
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: overview
ms.date: 05/10/2025
ai-usage: ai-assisted

---

# What are container network metrics?

Every pod, service, and node in a Kubernetes cluster is constantly generating network activity: connections opening, packets being forwarded or dropped, DNS queries resolving or failing. Understanding that activity is essential for debugging, capacity planning, and keeping services healthy. But most monitoring setups fall short in two ways:

* **Not enough visibility.** Node-level aggregates tell you something is wrong, but not *where*. Without pod-level breakdowns that include source and destination context, isolating a failing workload means guessing.
* **Too much data at scale.** A cluster running hundreds of microservices can produce thousands of metric time series per node. Collecting everything drives up storage costs and slows down dashboards.

Container network metrics in [Advanced Container Networking Services](advanced-container-networking-services-overview.md) for Azure Kubernetes Service (AKS) tackle both. The feature collects network metrics at the node level and the pod level across supported Cilium and non-Cilium data planes, on Linux and Windows.

On Cilium clusters, you can go a step further with source-level filtering, which lets you select exactly which namespaces, workloads, and metric types are collected *before* data leaves the node.

Container metrics filtering is a pre-ingestion control for observability data. Instead of collecting every available metric and filtering later in dashboards or queries, you define what to collect at the source. This keeps high-value metrics for the workloads you care about and avoids ingesting low-value or noisy time series.

The result: actionable network observability on any supported data plane, with optional cost-efficient filtering on Cilium.

Container network metrics give you deep workload-level visibility for troubleshooting and planning, while source-level filtering on Cilium helps keep observability costs proportional to business-critical workloads.

## Collection and filtering at a glance

Use this table to quickly understand where broad collection is available and where fine-grained filtering is available:

| Capability | Cilium clusters | Non-Cilium clusters |
|---|---|---|
| Node-level metric collection | ✅ | ✅ |
| Pod-level metric collection | ✅ (Linux) | ✅ (Linux) |
| Source-level filtering by namespace, pod label, and metric type | ✅ | ❌ |
| Cost control through pre-ingestion filtering | ✅ | ❌ |

[!INCLUDE [azure linux 2.0 retirement](./includes/azure-linux-retirement.md)]

## Key benefits

* **Node and pod-level granularity.** Track traffic volume, drop rates, and connection states at the node level for infrastructure health. Drill down to individual pods with source and destination labels to pinpoint the exact workload causing an issue.

* **Faster troubleshooting.** When a service starts dropping packets or DNS queries fail, pod-level metrics let you isolate the problem to a specific pod, namespace, or protocol in seconds, not hours.

* **Flexible visualization.** Store metrics in Azure Managed Prometheus and visualize in Azure Managed Grafana (fully managed), or bring your own Prometheus and Grafana infrastructure.

* **Scalable by design.** The pipeline handles large, dynamic clusters with hundreds of nodes and thousands of pods without requiring you to choose between comprehensive coverage and manageable data volumes.

* **Targeted observability (Cilium clusters).** On Cilium clusters, source-level filtering lets you define the namespaces, pod labels, or metric types you care about and collect only those. No post-collection trimming required.

* **Lower metrics ingestion costs (Cilium clusters).** Because filtering happens at the source on each node, unwanted metric time series are never scraped, transmitted, or ingested into your Prometheus backend. You pay only for the metrics you actually need. In large clusters where unfiltered collection can produce thousands of time series per node, source-level filtering can significantly reduce Azure Managed Prometheus ingestion and storage costs.

## How it works

:::image type="content" source="./media/advanced-container-networking-services/advanced-network-observability.png" alt-text="Diagram of the Container Network Observability architecture." lightbox="./media/advanced-container-networking-services/advanced-network-observability.png":::

The agent stack on each node depends on the data plane, as shown in the diagram.

**Linux Cilium nodes** use a layered eBPF-based stack: eBPF kernel hooks capture raw traffic data, Cilium processes it, and Hubble exposes it as Prometheus-format metrics. Because Hubble sits between the node and the scrape endpoint, source-level filtering runs at this layer — you select which namespaces, pod labels, and metric types are exported before data leaves the node.

**Linux non-Cilium nodes** use eBPF kernel hooks feeding into Microsoft Retina, with a Hubble layer on top for flow inspection. Microsoft Retina handles metric collection and exports node-level and pod-level metrics in Prometheus format.

From all paths, metrics are scraped in Prometheus format and ingested into Azure Managed Prometheus or your own Prometheus backend, then visualized in Azure Managed Grafana or your own Grafana stack.

To get started, [Set up container network metrics](container-network-observability-how-to.md), and then [configure container network metrics filtering](./how-to-configure-container-network-metrics-filtering.md) for Cilium clusters.

## When to use container network metrics

Container network metrics are designed for teams that need focused, actionable network data rather than raw telemetry. Common scenarios include:

* **Debugging a specific workload.** Use pod-level metrics to isolate packet drops, TCP resets, or DNS failures for a particular service. On Cilium clusters, filtering can narrow collection to just that namespace or pod label, cutting through cluster-wide noise.
* **Monitoring multi-tenant clusters.** Track network health per namespace so each team has visibility into its own traffic patterns. On Cilium clusters, scoped filtering keeps collection limited to tenant-specific namespaces.
* **Capacity planning.** Track forwarded and dropped byte counts per node to identify saturated links or imbalanced workload placement.
* **DNS health monitoring.** Surface DNS query failures and slow resolution times to catch issues before they cascade into application errors.
* **Reducing observability costs at scale.** In large clusters, unfiltered collection can generate thousands of time series per node. On Cilium clusters, source-level filtering removes unwanted series before ingestion so costs stay aligned with the workloads and metric types you choose.

## How to choose what to collect (Cilium clusters)

Use this rollout model to balance visibility and cost:

1. Start with broad collection in a nonproduction namespace to establish a baseline.
1. Keep packet drop, DNS, and TCP state metrics for critical namespaces.
1. Scope high-cardinality flow metrics to business-critical workloads only.
1. Review Prometheus ingestion trends and refine filters weekly.

This approach helps you keep high-value metrics while controlling time-series growth and ingestion costs.

## Before you review the metrics tables

Keep these points in mind:

* Node-level metrics are available across supported Cilium and non-Cilium data planes.
* Pod-level metrics are available on Linux.
* Source-level filtering is available on Cilium clusters only.
* On Cilium clusters, DNS metrics require a Cilium FQDN network policy.

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
