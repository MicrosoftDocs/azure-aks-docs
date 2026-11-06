---
title: Container network logs overview
description: Choose stored or on-demand network logs and customize traffic collection and flow log aggregation with Advanced Container Networking Services for AKS.
author: shaifaligargmsft
ms.author: shaifaligarg
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: overview
ms.date: 11/05/2026
---

# What are container network logs?

Container network logs in [Advanced Container Networking Services](advanced-container-networking-services-overview.md)
for Azure Kubernetes Service (AKS) help you investigate which workloads communicated,
which destinations they reached, and whether traffic was forwarded or dropped.
Use metrics to spot a network problem, then use logs to examine the traffic
involved. A flow verdict alone doesn't establish whether an application request
succeeded.

Depending on the flow type, visibility configuration, and retained aggregation fields, logs can include:

* Source and destination IP addresses, pod names, and service names
* Namespaces, ports, and protocols
* Traffic direction and policy verdicts

With this context, you can correlate network behavior with specific workloads, troubleshoot connectivity, validate security policies, and perform forensic analysis. Container network logs cover Layer 3 (IP), Layer 4 (TCP/UDP), and Layer 7 (HTTP/gRPC) traffic.

For stored logs, **customizable flow log aggregation** helps you balance operational
visibility with data volume and cost. Aggregation summarizes similar observations,
preserving workload communication patterns and counts of forwarded or dropped
observations. Add grouping fields beyond the service defaults to tailor those
summaries to your needs. The volume reduction depends on how much traffic shares
the same grouping values. For more information, see [Flow log aggregation](#flow-log-aggregation).

## Choose a collection mode

| Your goal | Mode | What to configure |
| --- | --- | --- |
| Keep selected traffic records for historical investigations or alerting | **Stored logs** on Cilium | Customize traffic filters and aggregation grouping fields for your needs. Forward the host-local logs to a backend for long-term retention. |
| Inspect live traffic while troubleshooting | **On-demand logs** on supported Cilium and non-Cilium clusters | Connect the Hubble CLI or UI to your ACNS-enabled cluster. A stored-log resource isn't required. |

Start with [Set up container network logs](how-to-configure-container-network-logs.md).
The guide separates collection, optional Azure Monitor forwarding, and verification.

## Stored logs

On a supported Cilium cluster with ACNS enabled, define which traffic to collect
before expecting stored logs. Enabling the service alone doesn't select traffic
or configure long-term retention.

To start collecting logs, define [`ContainerNetworkLog`](how-to-configure-container-network-logs.md#containernetworklog-crd-template)
custom resources that select traffic by namespace, pod, labels, IP address,
numeric Cilium security identity, protocol, or verdict. After the configuration
reaches the agents, nodes observing matching traffic write the selected logs.
Multiple resources can collect traffic at the same time.

Use filters to focus on the flows that matter. Use [flow log aggregation](#flow-log-aggregation)
to summarize those flows, and customize its grouping fields to preserve the
distinctions your investigations need. Together, these controls let you tailor
what you collect and how it is summarized. Review the resulting data volume:
narrower filters can reduce collection, while more grouping fields can increase
the number of records.

### How stored logs mode works

Advanced Container Networking Services uses eBPF technology with Cilium to capture network flows on each node. Once ACNS is enabled and a `ContainerNetworkLog` custom resource is applied, the Cilium agent collects traffic that matches the filter and writes logs in JSON format to `/var/log/acns/hubble/events.log` on each host. Log generation runs entirely inside the cluster and doesn't depend on Azure Monitor.

For production use, we recommend enabling the Azure Monitor add-on. When enabled, Container Insights agents collect host-local logs, apply throttling limits, and send them to a Log Analytics workspace, where you get long-term retention, KQL queries, and the built-in Azure portal and Grafana dashboards. This is the most integrated path and the one most customers should choose.

If your team has an existing observability pipeline, you can instead forward the same host-local logs to any OpenTelemetry-compatible collector or logging service — either alongside Azure Monitor or in place of it.

:::image type="content" source="./media/advanced-container-networking-services/how-container-network-logs-works.png" alt-text="Diagram of how container network logs work." lightbox="./media/advanced-container-networking-services/how-container-network-logs-works.png":::

For more information about throttling and Container Insights, see the [Container Insights documentation](https://aka.ms/ContainerNetworkLogsDoc_CI).

## Using container network logs with or without Azure Monitor

Use Azure Monitor for integrated queries and dashboards, or keep your existing logging pipeline.

| Path | What you get | When to choose it |
|---|---|---|
| **Azure Monitor add-on (recommended)** | Container Insights collects host-local logs into a Log Analytics workspace for retention, KQL queries, and built-in Grafana dashboards in the Azure portal. You don't need a separate Grafana instance. | You want integrated storage, queries, and dashboards. |
| **Host-local files with your own pipeline** | ACNS writes JSON logs to `/var/log/acns/hubble/events.log` on each node. Configure your collector to read, parse, and forward those files. | You already have a centralized observability platform and want network logs to land there. |

Without a forwarding pipeline, logs remain in rotating node-local files and aren't retained for long-term investigations.

## Key capabilities of stored logs mode

Customize your observability to match your needs: choose which traffic to collect
and which details to distinguish when grouping it into stored logs.

* **Customizable filters.** Define [ContainerNetworkLog](how-to-configure-container-network-logs.md#containernetworklog-crd-template)
  custom resources to select traffic by source or destination namespace, pod,
  label, IP address or CIDR range, Cilium security identity, protocol, or verdict.
  Traffic that matches any configured resource's filters is eligible for collection,
  giving you control over what you collect and helping you manage ingestion volume.

* **Customizable flow log aggregation.** Use aggregation to reduce stored log
  volume while retaining the details you need for network investigations.
  By default, aggregation combines flow observations with matching grouping-field
  values into summarized records every 30 seconds. Add grouping fields to retain
  details beyond the service defaults. More grouping fields can produce more
  records, so pair aggregation with targeted filters to balance investigation
  needs with ingestion and storage costs.
  Learn more about [flow log aggregation](#flow-log-aggregation).

* **Log storage options.** ACNS always writes logs locally on each node. From there, you can choose how to consume them:

  * **Host-local files (always on):** Logs are stored on host nodes at `/var/log/acns/hubble`. Files auto-rotate at 50 MB, and older logs are overwritten. Use this directly for short-term, real-time monitoring, or forward the files to any OpenTelemetry-compatible collector or logging service for additional log management.

  * **Azure Monitor (recommended):** Enable the Azure Monitor add-on to collect and store logs in a Log Analytics workspace. You get secure, compliant storage with long-term retention, KQL queries, anomaly detection, historical analysis, and alerting through the managed service for Prometheus. Log generation still runs through the Cilium agent and the `ContainerNetworkLog` CRD; Azure Monitor adds the consumption layer on top.

    The `ContainerNetworkLogs` table uses the **Analytics** tier by default. You can switch to the **Basic** tier for lower ingestion and retention costs while maintaining a similar observability experience. Each tier has a dedicated Azure portal dashboard optimized for its query capabilities. For more information about table plans, see [Log Analytics table plans](/azure/azure-monitor/logs/data-platform-logs#table-plans). To learn how to set the table plan, see [Set the table plan](/azure/azure-monitor/logs/logs-table-plans#set-the-table-plan).

* **Visualization in the Azure portal.** Query and analyze logs in Log Analytics,
  or use the dashboard for your table plan. Review the plan's query and retention
  capabilities before choosing it. For details, see
  [Visualize logs in the Azure portal](#visualize-logs-in-the-azure-portal).

## Visualize logs in the Azure portal

For detailed investigations, open **Monitoring** > **Logs** on your AKS cluster's page in the Azure portal. In the receiving Log Analytics workspace, query the `ContainerNetworkLogs` table.

:::image type="content" source="./media/advanced-container-networking-services/azure-log-analytics.png" alt-text="Screenshot of container network logs in a Log Analytics workspace." lightbox="./media/advanced-container-networking-services/azure-log-analytics.png":::

On your AKS cluster's page in the Azure portal, select **Monitoring** > **Dashboards with Grafana** to view the built-in flow-log dashboards. You don't need an Azure Managed Grafana instance, and there's no additional charge for the dashboards. ACNS and log ingestion and retention charges still apply.

Choose the dashboard that matches your `ContainerNetworkLogs` table plan:

| Dashboard | Path | Table tier |
| --- | --- | --- |
| **Flow Logs - Basic Tier** (ID: 23155) | **Azure** > **Insights** > **Containers** > **Networking** > **Flow Logs - Basic Tier** | Basic |
| **Flow Logs - Analytics Tier** (ID: 23156) | **Azure** > **Insights** > **Containers** > **Networking** > **Flow Logs - Analytics Tier** | Analytics (default) |

Both dashboards show which AKS workloads are communicating with each other, including network requests, responses, drops, and errors. Use the dashboard that matches the table tier configured for your `ContainerNetworkLogs` table.

> [!TIP]
> The `ContainerNetworkLogs` table defaults to the Analytics tier. The Basic tier
> has different query, retention, and pricing capabilities. Compare
> [Log Analytics table plans](/azure/azure-monitor/logs/data-platform-logs#table-plans)
> and use the dashboard for your chosen plan. To change it, see
> [Set the table plan](/azure/azure-monitor/logs/logs-table-plans#set-the-table-plan).

The Azure portal dashboards have the following major components:

* *Network health overview.* Review traffic summaries and forwarded or dropped
  observations, and then use the service dependency graph to identify communication
  paths worth investigating. Protocol-specific details depend on visibility and
  retained fields. Aggregated observation counts aren't unique request counts.

  :::image type="content" source="./media/advanced-container-networking-services/flow-log-stats.png" alt-text="Screenshot of flow logs stats and a service dependency graph." lightbox="./media/advanced-container-networking-services/flow-log-stats.png":::

* *Flow logs and error logs.* The dashboard separates flow logs from error logs into distinct views, so you can focus on errors without sifting through normal traffic. Use the built-in filters to narrow results by protocol, namespace, or verdict. For example, to troubleshoot DNS resolution failures, filter error logs by the DNS protocol.

  :::image type="content" source="./media/advanced-container-networking-services/flow-log-snapshot.png" alt-text="Screenshot of flow logs and error logs." lightbox="./media/advanced-container-networking-services/flow-log-snapshot.png":::

  The details available in the dashboard depend on the collected traffic and
  aggregation configuration. To tailor the detail in your stored logs, see
  [Customize flow log aggregation](#customize-flow-log-aggregation).

  Use the available timestamps and source/destination details to correlate records
  with an investigation. An aggregated record doesn't provide a separate timestamp
  for every observation in its group.

  :::image type="content" source="./media/advanced-container-networking-services/flow-log-filters.png" alt-text="Screenshot of available filters in the Azure portal dashboards." lightbox="./media/advanced-container-networking-services/flow-log-filters.png":::

* *Top namespaces, workloads, and DNS errors.* This section surfaces the most active namespaces, highest-traffic workloads, port usage, and most frequent DNS errors. Use it to identify which workloads generate the most traffic, spot dropped requests, and compare protocol distribution (for example, TCP versus UDP). Unusual patterns here, such as unexpected spikes or unfamiliar destinations, can indicate misconfigurations or security concerns.

  :::image type="content" source="./media/advanced-container-networking-services/top-namespaces.png" alt-text="Screenshot of top namespaces and pod metrics." lightbox="./media/advanced-container-networking-services/top-namespaces.png":::

## Flow log aggregation

Busy workloads can generate many repeated flow observations between the same
endpoints. Storing each observation separately increases the amount of data you
must ingest, retain, and search, even when your immediate question is simply
which workloads communicated and whether their traffic was forwarded or dropped.

**Aggregation provides a lower-volume starting point for historical network
investigations.** Each node combines selected flow observations that share the
same grouping-field values within an aggregation interval. Instead of writing
every observation separately, it writes a summarized record for each group,
including counts of ingress, egress, and unknown-direction observations.

### Example: Before and after aggregation

Consider two client pods, `client-1` and `client-2`, communicating with a `server`
pod over TCP port `80` during one 30-second window. Each pod belongs to a separate
workload of the same name. The following observations illustrate connection setup,
data transfer, and replies.

**Before aggregation: ten observations**

| Source pod | Source port | Destination pod | Destination port | Protocol | TCP flag (simplified) |
| --- | --- | --- | --- | --- | --- |
| client-1 | 12345 | server | 80 | TCP | SYN |
| server | 80 | client-1 | 12345 | TCP | SYN-ACK |
| client-1 | 12345 | server | 80 | TCP | ACK |
| client-1 | 12345 | server | 80 | TCP | PSH |
| server | 80 | client-1 | 12345 | TCP | ACK |
| client-2 | 23456 | server | 80 | TCP | SYN |
| server | 80 | client-2 | 23456 | TCP | SYN-ACK |
| client-2 | 23456 | server | 80 | TCP | ACK |
| client-2 | 23456 | server | 80 | TCP | PSH |
| server | 80 | client-2 | 23456 | TCP | ACK |

For this illustration, one node observes each entry once at the client endpoints:
client-to-server observations are egress, and replies are ingress. All verdicts
are `FORWARDED`, and the other default grouping values are identical within each
group shown below.

**After default aggregation: four summarized records**

| Source workload | Destination workload | TCP destination port | Reply (`is_reply`) | Egress observation count | Ingress observation count |
| --- | --- | --- | --- | --- | --- |
| client-1 | server | 80 | false | 3 | 0 |
| server | client-1 | 12345 | true | 0 | 2 |
| client-2 | server | 80 | false | 3 | 0 |
| server | client-2 | 23456 | true | 0 | 2 |

The ten observations become four records, preserving all ten observations in
their counts. You can still see which workloads communicated, the destination
ports, and the volume observed in each direction without storing every TCP flag
transition separately.

The groups remain separate for these reasons:

* **Different workloads:** source and destination workload metadata are default
  grouping fields.
* **Original traffic and replies:** endpoint values, destination ports, and
  `is_reply` differ, so the two directions don't collapse into one record.
* **Different reply destination ports:** `12345` and `23456` are retained as
  destination ports on reply traffic. Source ports, individual pod names, and
  TCP flags aren't retained by the default grouping configuration.

### Default aggregation settings

Aggregation is enabled by default for stored logs, with a **30-second aggregation
interval** and the default grouping fields listed in the following table.
Within each node's interval, observations with the same values for all grouping
fields are combined into a summarized record.

| Default grouping field | Information retained |
| --- | --- |
| `verdict` | Flow verdict, such as `FORWARDED`, `DROPPED`, or `ERROR`. |
| `is_reply` | Whether the observation is reply traffic. |
| `drop_reason_desc` | Reason the traffic was dropped. |
| `source.namespace` | Source namespace. |
| `destination.namespace` | Destination namespace. |
| `source.workloads` | Source workload metadata, such as Deployment, StatefulSet, or DaemonSet. |
| `destination.workloads` | Destination workload metadata. |
| `source.identity` | Source Cilium security identity, including identity context when workload metadata isn't available. |
| `destination.identity` | Destination Cilium security identity. |
| `l4.TCP.destination_port` | TCP destination port. |
| `l4.UDP.destination_port` | UDP destination port. |
| `l7.http.code` | HTTP response code, when HTTP visibility is configured. |
| `l7.dns.rcode` | DNS response code, when DNS visibility is configured. |
| `IP.ipVersion` | IP version: IPv4 or IPv6. |
| `IP.encrypted` | Whether the flow is encrypted. |
| `source.cluster_name` | Source cluster name. |
| `destination.cluster_name` | Destination cluster name. |

A field can contain a value only when that information is available in the
original flow. Default grouping doesn't enable DNS or HTTP inspection.

These defaults preserve workload communication, destination ports, verdicts,
and response codes. They don't retain every per-flow detail: individual pod
names, source and destination IP addresses, client source ports, DNS query names,
and HTTP URLs aren't in this default list.

**Additional fields extend this list; they don't replace it.**
Use `spec.aggregation.additionalFields` to customize grouping without
removing default fields or changing the 30-second interval. Repeating a default
field doesn't add another copy. Changes affect future records and can't recover
details omitted from historical logs.

### Customize flow log aggregation

Tailor flow log aggregation to your operational and investigation requirements
by choosing additional grouping fields beyond the service defaults. You control
which distinctions your summarized logs preserve, from traffic direction and
DNS request/response type to individual IP addresses, DNS names, or HTTP URLs.
Choose any field supported by your cluster's flow schema to help answer the
questions that matter to you.

Add fields to `spec.aggregation.additionalFields` in a `ContainerNetworkLog`
resource to customize aggregation. The additional fields become *grouping keys*:
flows with different values for those fields are stored in separate groups.

For example, adding the following fields separates observations that would
otherwise share the same aggregation group:

| Investigation | Additional fields | Effect on aggregation |
| --- | --- | --- |
| **What direction does an observation represent?** | `traffic_direction` | Separates ingress and egress observations into different groups when all other grouping values match. |
| **Which DNS records are responses?** | `l7.type` | Separates DNS request and response observations into different groups when all other grouping values match. Requires DNS visibility and the Layer 7 type to be present in the original flow. |

These fields are examples, not an exhaustive allow list.
You can specify valid field paths from
the Hubble `Flow` message in Cilium's [flow.proto definition](https://github.com/cilium/cilium/blob/main/api/v1/flow/flow.proto).
Use fields supported by the Cilium version running on your cluster; the linked
`main` branch can include fields that your cluster doesn't yet support.
The original flow must contain a field's value for it to be retained.

Higher-cardinality fields, such as IP addresses, individual pod names, source
ports, DNS names, and HTTP URLs, are available when you need that level of detail.
Because they can have many distinct values, enabling them can increase log volume
and ingestion and storage costs across the cluster. Before enabling them, assess
the expected volume, cost, and sensitive-data implications. Then monitor usage
to balance the detail you need with your budget.

Logs containing the retained fields are written to
`/var/log/acns/hubble/events.log` on each node that observes matching traffic.
When Azure Monitor forwarding is configured, you can query the collected logs
in Log Analytics by using the columns available in the
[`ContainerNetworkLogs` table](/azure/azure-monitor/reference/tables/containernetworklogs),
including retained properties represented in its dynamic columns. Use the table schema to
identify the column or dynamic property to reference in your query.

### Select traffic by security identity

Use Cilium security identities in source or destination filters to choose which
traffic to log. Combine identity filters with namespace, pod, protocol, or verdict
criteria. For example, select TCP traffic from a namespace to endpoints Cilium
classifies as world.

A security identity is Cilium's classification of an endpoint, not an Azure
managed identity or a user identity. The configuration accepts numeric IDs, not
aliases such as `world`. See the [identity example and values](how-to-configure-container-network-logs.md#filter-logs-by-cilium-security-identity).

Customizable filters and aggregation give you complementary controls: filters
select the flows to collect, while additional grouping fields customize how all
selected flows in the cluster are summarized.

### Understand the scope and cost

Additional fields apply to **all selected stored logs in the cluster**. They aren't
limited to the filters in the resource that requests them.

For example, if one resource requests `l7.type` and another requests
`traffic_direction`, both fields become part of the cluster's grouping configuration.
Deleting the first resource removes its field only if no other valid resource
requests it. Fields supplied by the service remain in place.

| Setting | Scope | Effect |
| --- | --- | --- |
| Include filters | Traffic selected by each log resource | Matching any resource's filter can make a flow eligible for collection. |
| Additional grouping fields | All selected stored logs in the cluster | Contributions from multiple resources are combined and deduplicated. |
| Removing a resource | That resource's contribution | Other resources' filters, shared fields, and managed defaults remain. |

More distinct field values can produce more records. Start with the fields needed
for your investigation, review ingestion volume, and remove temporary additions
when you're finished. Coordinate changes with other teams that collect logs from
the same cluster.

Use [Configure container network logs](how-to-configure-container-network-logs.md)
for complete YAML examples and verification steps.

## On-demand logs

On-demand logs let you inspect flow logs in real time without defining a stored-log
resource or setting up persistent storage. Enable ACNS and connect your Hubble
client first. Use this mode when you need immediate visibility during troubleshooting.

ACNS provides two tools for on-demand capture. To set up either tool, see [Configure on-demand logs mode](how-to-configure-container-network-logs.md#configure-on-demand-logs-mode).

### Hubble CLI

The Hubble CLI lets you query, filter, and analyze flow logs directly from your terminal. It's especially useful when you need fine-grained filters, for example isolating traffic by namespace, pod label, or verdict during an active debugging session.

:::image type="content" source="./media/advanced-container-networking-services/hubble-cli-snapshot.png" alt-text="Screenshot of the Hubble CLI." lightbox="./media/advanced-container-networking-services/hubble-cli-snapshot.png":::

### Hubble UI

The Hubble UI provides a graphical view of service-to-service communication. It's a good fit when you want to visually trace traffic paths, identify which services are communicating, and spot anomalies without writing CLI commands.

:::image type="content" source="./media/advanced-container-networking-services/hubble-ui-snapshot.png" alt-text="Screenshot of the Hubble UI." lightbox="./media/advanced-container-networking-services/hubble-ui-snapshot.png":::

### Key benefits of on-demand logs

* **No stored-log configuration required.** After connecting Hubble to your
  ACNS-enabled cluster, inspect available flows without defining a
  `ContainerNetworkLog` resource.
* **Real-time visibility.** Inspect live traffic and view packet metadata as issues happen.
* **Fast troubleshooting.** Filter flows interactively through the Hubble CLI, or view service maps visually in the Hubble UI.
* **No persistent storage required.** Inspect live flows without setting up historical log storage. ACNS service charges still apply.

## Recommendations for stored logs

1. **Start with one workload and a clear question.** Select the application and
   traffic needed for the investigation. Verify fresh records, review volume,
   and then expand collection if needed. Avoid enabling broad collection simply
   to test that logging works.

1. **Tailor aggregation to your operational needs.** Choose additional grouping
   fields that help answer your questions, and assess their volume and cost impact.
   Coordinate cluster-wide changes with other teams and remove temporary additions
   when the investigation ends. Treat DNS names and URLs as potentially sensitive
   operational data.

1. **Use the pre-built dashboards first.** The built-in Azure portal dashboards cover common use cases like service communication patterns, error rates, and DNS failures. Start there. Add custom panels or Log Analytics queries only if you need visibility the pre-built dashboards don't provide.

1. **Review periodically.** As workloads and traffic patterns change, your filters may need updating. Check data volume and flow coverage periodically to make sure you're still capturing the right traffic at a reasonable cost.

## Limitations

**Data plane and feature requirements:**

* Stored logs mode works only with the Cilium data plane.
* Layer 7 flow logs are captured only when Layer 7 policy support is enabled. For more information, see [Configure a Layer 7 policy](how-to-apply-l7-policies.md).
* DNS flows and metrics are captured only when a Cilium Fully Qualified Domain Name (FQDN) network policy is applied. For more information, see [Configure an FQDN policy](how-to-apply-fqdn-filtering-policies.md).

**Aggregation trade-offs:**

* Additional fields can retain distinctions such as source and destination IP addresses, HTTP URLs, or DNS query names. The original flow must contain the data.
* Fields apply to selected stored logs across the cluster and can increase record counts and ingestion costs.
* Changes affect newly collected data. They don't recover details from historical logs, change the table schema, or provide a timestamp for every event in an aggregated record. Use on-demand logs for real-time per-flow inspection.

**Storage and platform:**

* The host-local file at `/var/log/acns/hubble/` is capped at 50 MB per node and auto-rotates. If you need long-term retention, enable Azure Monitor (recommended) or forward the file to your own logging service.
* The Auxiliary logs table plan isn't supported.

## Pricing

> [!IMPORTANT]
> Advanced Container Networking Services is a paid offering.

For more information about pricing, see [Advanced Container Networking Services - Pricing](https://azure.microsoft.com/pricing/details/azure-container-networking-services/).

## Related content

* [Identify DNS names associated with failures](how-to-configure-container-network-logs.md#aggregation-field-example-2-identify-dns-names-associated-with-failures)

* [Set up container network logs](how-to-configure-container-network-logs.md)
* [Advanced Container Networking Services for AKS](advanced-container-networking-services-overview.md)
* [Container Network Observability](advanced-container-networking-services-overview.md#container-network-observability) in Advanced Container Networking Services
* [Container Network Security](advanced-container-networking-services-overview.md#container-network-security) in Advanced Container Networking Services
