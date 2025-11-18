---
title: Use Advanced Container Networking Services for diagnosing and resolving network issues
description: This article walks you through how to use Advanced Container Networking Services for diagnosing and resolving network issues in Azure Kubernetes Service (AKS).
author: shaifaligargmsft
ms.author: shaifaligarg
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: concept-article
ms.date: 05/28/2025
---

# Use Advanced Container Networking Services for diagnosing and resolving network issues

This guide helps you navigate [Advanced Container Networking Services (ACNS)](./advanced-container-networking-services-overview.md#container-network-observability) as the primary solution for addressing real-world networking use cases in Azure Kubernetes Service (AKS). Whether troubleshooting DNS resolution problems, optimizing ingress and egress traffic, or ensuring compliance with network policies, this manual demonstrates how to harness ACNS observability dashboards, [Container Network Logs](./container-network-observability-logs.md), [Container Network Metrics](./container-network-observability-metrics.md), and visualization tools to diagnose and resolve issues effectively.

**Advanced Container Networking Services is Microsoft's comprehensive, enterprise-grade network observability and security platform** that provides the most advanced features for monitoring, analyzing, and troubleshooting network traffic in your AKS clusters. It includes pre-built Grafana dashboards, real-time metrics, detailed logs, and AI-powered insights that help you gain deep visibility into network performance, quickly identify issues, and optimize your container networking environment with full Microsoft support.

## Overview of Advanced Container Networking Services dashboards

We created sample dashboards for Advanced Container Networking Services to help you visualize and analyze network traffic, DNS requests, and packet drops in your Kubernetes clusters. These dashboards are designed to provide insights into network performance, identify potential issues, and assist in troubleshooting. To learn how to set up these dashboards, see [Set up Container Network Observability for Azure Kubernetes Service (AKS) - Azure managed Prometheus and Grafana](./container-network-observability-how-to.md).

The suite of dashboards includes:

-  **Flow Logs**: Shows network traffic flows between pods, namespaces, and external endpoints.
-  **Flow Logs (External Traffic)**: Shows network traffic flows between pods and external endpoints.
-  **Clusters**: Shows node-level metrics for your clusters.
- **DNS (Cluster)**: Shows DNS metrics on a cluster or selection of nodes.
- **DNS (Workload)**: Shows DNS metrics for the specified workload (for example, Pods of a DaemonSet or Deployment such as CoreDNS).
- **Drops (Workload)**: Shows drops to/from the specified workload (for example, Pods of a Deployment or DaemonSet).
- **Pod Flows (Namespace)**: Shows L4/L7 packet flows to/from the specified namespace (that is, Pods in the Namespace).
- **Pod Flows (Workload)**: Shows L4/L7 packet flows to/from the specified workload (for example, Pods of a Deployment or DaemonSet).
- **L7 Flows (Namespace)**: Shows HTTP, Kafka, and gRPC packet flows to/from the specified namespace (i.e. Pods in the Namespace) when a Layer 7 based policy is applied. *This is available only for clusters with Cilium data plane*.
- **L7 Flows (Workload)**: Shows HTTP, Kafka, and gRPC flows to/from the specified workload (for example, Pods of a Deployment or DaemonSet) when a Layer 7 based policy is applied. *This is available only for clusters with Cilium data plane*.



## Use case 1: Interpret domain name server (DNS) issues for root cause analysis (RCA)

DNS issues at the pod level can cause failed service discovery, slow application responses, or communication failures between pods. These problems frequently arise from misconfigured DNS policies, limited query capacity, or latency in resolving external domains. For instance, if the CoreDNS service is overloaded or an upstream DNS server stops responding, it might lead to failures in dependent pods. Resolving these issues requires not just identification but deep visibility into DNS behavior within the cluster.

> Let's say you've set up a web application in an AKS cluster, and now that web application is unreachable. You're receiving DNS errors, such as `DNS_PROBE_FINISHED_NXDOMAIN` or `SERVFAIL`, while the DNS server resolves the web application's address.

### Step 1: Investigate DNS metrics in Grafana dashboards

We've already created two DNS dashboards to investigate DNS metrics, requests, and responses: **DNS (Cluster)**, which shows DNS metrics on a cluster or selection of nodes, and **DNS (Workload)**, which shows DNS metrics for a specific workload (for example, Pods of a DaemonSet or Deployment such as CoreDNS).

1. Check the **DNS Cluster** dashboard to get a snapshot of all DNS activities. This dashboard provides a high-level overview of DNS requests and responses, such as what kinds of queries lack responses, the most common query, and the most common response. It also highlights the top DNS errors and the nodes that generate most of those errors.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/dns-clusters-snapshot-combined.png" alt-text="Snapshot of DNS Cluster dashboard." lightbox="./media/advanced-container-networking-services/acns-dashboard/dns-clusters-snapshot-combined.png":::

2. Scroll down to find out pods with most DNS request and errors in all namespaces.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/top-pods-with-dns-errors-in-all-namespaces.png" alt-text="Snapshot of top pods in all namespaces. " lightbox="./media/advanced-container-networking-services/acns-dashboard/top-pods-with-dns-errors-in-all-namespaces.png":::

    Once you identify the pods causing the most DNS issues, you can delve further into the **DNS Workload** dashboard for a more granular view. By correlating data across various panels within the dashboard, you can systematically narrow down the root causes of the issues.

3. The **DNS Requests** and **DNS Responses** sections allow you to identify trends, like a sudden drop in response rates or an increase in missing responses. A high *Requests Missing Response %* indicates potential upstream DNS server issues or query overload. In the following screenshot of the sample dashboard, you can see there's a sudden increase in requests and responses at around 15.22.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/workload-dns-requests-and-responses.png" alt-text="Diagram of DNS requests and responses in specific workload. " lightbox="./media/advanced-container-networking-services/acns-dashboard/workload-dns-requests-and-responses.png":::

4. Check for any DNS errors by type, and check for spikes in specific error types (for example, `NXDOMAIN` for nonexistent domains). In this example, there's a significant increase in *Query refused errors*, suggesting a mismatch in DNS configurations or unsupported queries.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/types-of-dns-error-responses.png" alt-text="Diagram of DNS Errors by type. " lightbox="./media/advanced-container-networking-services/acns-dashboard/types-of-dns-error-responses.png":::

5. Use sections like **DNS Response IPs Returned** to ensure that expected responses are being processed. This graph displays the rate of successful DNS queries processed per second. This information is useful for understanding how frequently DNS queries are being successfully resolved for the specified workload.

   - An **increased rate** might indicate a surge in traffic or a potential DNS attack (for example, *Distributed Denial of Service (DDoS)*).
   - A **decreased rate** might signify issues reaching the external DNS server, a CoreDNS configuration issue, or an unreachable workload from CoreDNS.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/rate-of-ips-returned-dns-responses.png" alt-text="Diagram of rate of IPs retuned in DNS responses per second. " lightbox="./media/advanced-container-networking-services/acns-dashboard/rate-of-ips-returned-dns-responses.png":::

6. Examining the most frequent DNS queries can help identify patterns in network traffic. This information is useful for understanding workload distribution and detecting any unusual or unexpected query behaviors that might require attention.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/top-dns-queries-requests.png" alt-text="Diagram of top DNS queries in requests. " lightbox="./media/advanced-container-networking-services/acns-dashboard/top-dns-queries-requests.png":::

7. The **DNS Response Table** helps you with DNS issue root cause analysis by highlighting query types, responses, and error codes like *SERVFAIL (Server Failure)*. It identifies problematic queries, patterns of failures, or misconfigurations. By observing trends in return codes and response rates, you can pinpoint specific nodes, workloads, or queries causing DNS disruptions or anomalies.

    In the following example, you can see that for *AAAA (IPV6)* records, there's no error, but there's a server failure with an *A (IPV4)* record. Sometimes, the DNS server might be configured to prioritize IPv6 over IPv4. This can lead to situations where IPv6 addresses are returned correctly, but IPv4 addresses face issues.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/dns-response-table.png" alt-text="Diagram of DNS response table. " lightbox="./media/advanced-container-networking-services/acns-dashboard/dns-response-table.png":::

8. When it's confirmed that there's a DNS issue, the following graph identifies the top ten endpoints causing DNS errors in a specific workload or namespace. You can use this to prioritize troubleshooting specific endpoints, detect misconfigurations, or investigate network issues.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/top-pods-with-dns-errors-in-workload.png" alt-text="Diagram of top pods with most DNS errors. " lightbox="./media/advanced-container-networking-services/acns-dashboard/top-pods-with-dns-errors-in-workload.png":::

### Step 2: Analyze DNS resolution issues with Container Network Logs

1. Container Network Logs provide detailed insights into DNS queries and their responses in both stored and on-demand modes. With Container Network Logs, you can analyze DNS-related traffic for specific pods, showing details like DNS queries, responses, error codes, and latency. To view DNS flows in your Log Analytics workspace, use the following KQL query:

    ```kusto
    RetinaNetworkFlowLogs
    | where TimeGenerated between (datetime(<start-time>) .. datetime(<end-time>))
    | where Layer4.UDP.destination_port == 53
    | where Layer7.type == "REQUEST" 
    | where Reply == false or isnull(Reply)
    | project TimeGenerated, SourcePodName, DestinationPodName, Layer7.dns.query, Layer7.dns.qtypes, Verdict, TrafficDirection, AdditionalFlowData.Summary, NodeName, SourceNamespace, DestinationNamespace
    | order by TimeGenerated desc
    ```

    Replace `<start-time>` and `<end-time>` with your desired time range in the format `2025-08-12T00:00:00Z`.

    Container Network Logs provide comprehensive insights into DNS queries and their responses, which can help diagnosing and troubleshooting DNS-related issues. Each log entry includes information such as the query type (for example, *A* or *AAAA*), the queried domain name, the DNS response code (for example, *Query Refused*, *Non-Existent Domain*, or *Server Failure*), and the source and destination of the DNS request.

2. **Identify the query status**: Examine the **Verdict** field for responses like *DROPPED* or *FORWARDED*, which indicates issues with network connectivity or policy enforcement.
3. **Verify the source and destination**: Ensure the pod names listed in the **SourcePodName** and **DestinationPodName** fields are correct and the communication path is expected.
4. **Track traffic patterns**: Look at the **Verdict** field to understand whether requests were forwarded or dropped. Disruptions in forwarding might indicate networking or configuration problems.
5. **Analyze timestamps**: Use the **TimeGenerated** field to correlate specific DNS issues with other events in your system for a comprehensive diagnosis.
6. **Filter by pods and namespaces**: Use fields like **SourcePodName**, **DestinationPodName**, and **SourceNamespace** to focus on specific workloads experiencing issues.

### Step 3: Visualize DNS traffic with Container Network Logs dashboards

Container Network Logs provides rich visualization capabilities through Azure portal dashboards and Azure Managed Grafana. The service dependency graph and flow logs visualization complement the detailed log analysis by providing visual insights into DNS-related traffic and dependencies:

- **Service dependency graphs**: Visualize which pods or services are sending high volumes of DNS queries and their relationships
- **Flow logs dashboards**: Monitor DNS request patterns, error rates, and response times in real-time
- **Traffic flow analysis**: Identify dropped DNS packets and communication paths to CoreDNS or external DNS services

 :::image type="content" source="./media/advanced-container-networking-services/dns-flow-log-snapshot.png" alt-text="Screenshot of flow logs and error logs." lightbox="./media/advanced-container-networking-services/dns-flow-log-snapshot.png":::


You can access these visualizations through:
- **Azure portal**: Navigate to your AKS cluster → Insights → Networking → Flow Logs
- **Azure Managed Grafana**: Use the pre-configured "Flow Logs" and "Flow Logs (External Traffic)" dashboards


With the combined capabilities of Grafana dashboards, Container Network Logs stored mode for historical analysis, and on-demand logs for real-time troubleshooting, you can identify DNS issues and perform root cause analysis effectively.

## Use case 2: Identify packet drops at cluster and pod level due to misconfigured network policy or network connectivity issues

Connectivity and network policy enforcement issues often stem from misconfigured Kubernetes network policies, incompatible Container Network Interface (CNI) plugins, overlapping IP ranges, or network connectivity degradation. Such problems can disrupt application functionality, resulting in service outages and degraded user experiences.

When a packet drop occurs, eBPF programs capture the event and generate metadata about the packet, including the drop reason and its location. This data is processed by a user space program, which parses the information and converts it into Prometheus metrics. These metrics offer critical insights into the root causes of packet drops, enabling administrators to identify and resolve issues such as network policy misconfigurations effectively.

In addition to policy enforcement issues, network connectivity problems can cause packet drops due to factors like TCP errors or retransmissions. Administrators can debug these issues by analyzing TCP retransmission tables and error logs, which help identify degraded network links or bottlenecks. By leveraging these detailed metrics and debugging tools, teams can ensure smooth network operations, reduce downtime, and maintain optimal application performance.

> Let's say you have a microservices-based application where the frontend pod can't communicate with a backend pod due to an overly restrictive network policy blocking ingress traffic.

### Step 1: Investigate drop metrics in Grafana Dashboards

1. If there are packet drops, begin your investigation with the **Pod Flows (Namespace)** dashboard. This dashboard has panels that assist in identifying namespaces with the highest drops and then pods within those namespaces that have the highest drops. For example, let's review the **Heatmap of Outgoing Drops for Top Source Pods** or for **Top Destination Pods** to identify which pods are most affected. Brighter colors indicate higher rates of drops. Compare across time to detect patterns or spikes in specific pods.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/pod-flow-snapshot.png" alt-text="Diagram of snapshot of Pod flows(Namespace) dashboard. " lightbox="./media/advanced-container-networking-services/acns-dashboard/pod-flow-snapshot.png":::

2. Once the top pods with highest drops are identified, go to **Drops (Workload)** dashboard. You can use this dashboard to diagnose network connectivity issues by identifying patterns in outgoing traffic drops from specific pods. The visualizations highlight which pods are experiencing the most drops, the rate of those drops, and the reasons behind them, such as policy denials. By correlating spikes in drop rates with specific pods or timeframes, you can pinpoint misconfigurations, overloaded services, or policy enforcement problems that might be disrupting connectivity.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/workload-snapshot-for-dropped-packets.png" alt-text="Diagram of Workload snapshot of dropped packets." lightbox="./media/advanced-container-networking-services/acns-dashboard/workload-snapshot-for-dropped-packets.png":::

3. Review the **Workload Snapshot** section to identify pods with outgoing packet drops. Focus on **Max Outgoing Drops** and **Min Outgoing Drops** metrics to understand the severity of the issue (this example shows 1.93 packets/sec). Prioritize investigating pods with consistently high packet drop rates.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/workload-snapshot-with-metrics.png" alt-text="Diagram of Workload snapshot of pod flow metrics. " lightbox="./media/advanced-container-networking-services/acns-dashboard/workload-snapshot-with-metrics.png":::

4. Use the **Dropped Incoming/Outgoing Traffic by Reason** graph to identify the root cause of the drops. In this example, the reason is policy denied, indicating misconfigured network policies blocking outgoing traffic. Check if any specific time interval shows a spike in drops to narrow down when the issue started.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/dropped-traffic-by-reason.png" alt-text="Diagram of Dropped Incoming traffic by reason." lightbox="./media/advanced-container-networking-services/acns-dashboard/dropped-traffic-by-reason.png":::

5. Use the **Heatmap of Incoming Drops for Top Source/Destination Pods** to identify which pods are most affected. Brighter colors indicate higher rates of drops. Compare across time to detect patterns or spikes in specific pods.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/heatmap-of-drop-packets-at-destination-pod.png" alt-text="Diagram of heatmap of incoming drops for top destination pods." lightbox="./media/advanced-container-networking-services/acns-dashboard/heatmap-of-drop-packets-at-destination-pod.png":::

6. Use the **Stacked (Total) Outgoing/Incoming Drops by Source Pod** chart to compare drop rates across affected pods. Identify if specific pods consistently show higher drops (for example, kapinger-bad-6659b89fd8-zjb9k at 26.8 p/s). Here, p/s refers to drop packet per second. Cross-reference these pods with their workloads, labels, and network policies to diagnose potential misconfigurations.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/total-outgoing-drops-by-source-pods.png" alt-text="Diagram of total outgoing drops by source pods. " lightbox="./media/advanced-container-networking-services/acns-dashboard/total-outgoing-drops-by-source-pods.png":::

### Step 2: Analyze packet drops with Container Network Logs

Container Network Logs provides comprehensive insights into packet drops caused by misconfigured network policies with detailed, real-time and historical data. You can analyze dropped packets by examining specific drop reasons, patterns, and affected workloads.

Use the following KQL query in your Log Analytics workspace to identify packet drops:

```kusto
RetinaNetworkFlowLogs
| where TimeGenerated between (datetime(<start-time>) .. datetime(<end-time>))
| where Verdict == "DROPPED" 
| summarize DropCount = count() by SourcePodName, DestinationPodName, SourceNamespace, bin(TimeGenerated, 5m)
| order by TimeGenerated desc, DropCount desc
```

For real-time analysis of dropped packets, you can also filter by specific pods or namespaces:

```kusto
RetinaNetworkFlowLogs
| where TimeGenerated between (datetime(<start-time>) .. datetime(<end-time>))
| where Verdict == "DROPPED" 
| where SourceNamespace == "<namespace-name>"
| project TimeGenerated, SourcePodName, DestinationPodName, SourceNamespace, DestinationNamespace, Verdict, TrafficDirection
| order by TimeGenerated desc
```

Replace `<start-time>` and `<end-time>` with your desired time range in the format `2025-08-12T00:00:00Z`.

Container Network Logs provides granular insights into dropped packets, helping you identify misconfigured network policies and validate fixes. The logs include detailed information about drop reasons, affected pods, and traffic patterns that can guide your troubleshooting efforts.


### Step 3: Visualize packet drops with Container Network Logs dashboards

Container Network Logs provides visual representation of traffic flows and dropped packets through Azure portal dashboards and Azure Managed Grafana. The Flow Logs dashboards display interactions between pods within the same namespace, pods in other namespaces, and traffic from outside the cluster.

Key visualization features include:
- **Drop analysis by reason**: Identify why packets are being dropped (policy denied, connection tracking, etc.)
- **Traffic flow maps**: Visual representation of allowed and denied traffic flows
- **Namespace and pod-level insights**: Detailed views of source and destination relationships
- **Time-series analysis**: Historical trends of packet drops and their causes

 :::image type="content" source="./media/advanced-container-networking-services/top-namespaces.png" alt-text="Screenshot of top namespaces and pod metrics." lightbox="./media/advanced-container-networking-services/top-namespaces.png":::

This data is instrumental in reviewing network policies applied in the cluster, allowing administrators to swiftly identify and address any misconfigured or problematic policies through comprehensive log analysis and visual representations.

## Use case 3: Identify traffic imbalances within workloads and namespaces

Traffic imbalances occur when certain pods or services within a workload or namespace handle a disproportionately high volume of network traffic compared to others. This can lead to resource contention, degraded performance for overloaded pods, and underutilization of others. Such imbalances often arise due to misconfigured services, uneven traffic distribution by load balancers, or unanticipated usage patterns. Without observability, it's challenging to identify which pods or namespaces are overloaded or underutilized. Advanced Container Networking Services can help by monitoring real-time traffic patterns at the pod level, providing metrics on bandwidth usage, request rates, and latency, making it easy to pinpoint imbalances.

> Let's say you have an online retail platform running on an AKS cluster. The platform consists of multiple microservices, including a product search service, a user authentication service, and an order processing service that communicates through Kafka. During a seasonal sale, the product search service experiences a surge in traffic, while the other services remain idle. The load balancer inadvertently directs more requests to a subset of pods within the product search deployment, leading to congestion and increased latency for search queries. Meanwhile, other pods in the same deployment are underutilized.

### Step 1. Investigate pod traffic by Grafana dashboard

1. View the **Pod Flows (Workload)** dashboard. The **Workload Snapshot** displays various statistics such as outgoing and incoming traffic, and outgoing and incoming drops.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/workload-snapshot-for-pod-traffic.png" alt-text="Diagram of workload snapshot for pod traffic. " lightbox="./media/advanced-container-networking-services/acns-dashboard/workload-snapshot-for-pod-traffic.png":::

2. Examine the fluctuations in traffic for each trace type. Significant variations in the blue and green lines indicate changes in traffic volume for applications and services, which might contribute to congestion. By identifying periods with high traffic, you  can pinpoint times of congestion and investigate further. Additionally, compare the outgoing and incoming traffic patterns. If there's a significant imbalance between outgoing and incoming traffic, it might indicate network congestion or bottlenecks.
    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/outgoing-traffic-by-trace-type.png" alt-text="Diagram of outgoing traffic by trace type." lightbox="./media/advanced-container-networking-services/acns-dashboard/outgoing-traffic-by-trace-type.png":::

3. The heatmaps represent traffic flow metrics at the pod level within a Kubernetes cluster. The **Heatmap of Outgoing Traffic for Top Source Pods** shows outgoing traffic from the top 10 source pods, while the **Heatmap of Incoming Traffic for Top Destination Pods** displays incoming traffic to the top 10 destination pods. Color intensity indicates traffic volume, with darker shades representing higher traffic. Consistent patterns highlight pods generating or receiving significant traffic, such as *default/tcp-client-0*, which might act as a central node.

    The following heatmap indication higher traffic is receiving and coming out of the single pod. If the same pod (e.g., *default/tcp-client-0*) appears in both heatmaps with high traffic intensity, it might suggest that it's both sending and receiving a large volume of traffic, potentially acting as a central node in the workload. Variations in intensity across pods might indicate uneven traffic distribution, with some pods handling disproportionately more traffic than others.

     :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/heatmap-outgoing-and-incoming-traffic.png" alt-text="Diagram of heatmap of outgoing traffic at source pods and incoming traffic at destination pods." lightbox="./media/advanced-container-networking-services/acns-dashboard/heatmap-outgoing-and-incoming-traffic.png":::

4. Monitoring TCP reset traffic is crucial for understanding network behavior, troubleshooting issues, enforcing security, and optimizing application performance. It provides valuable insights into how connections are managed and terminated, allowing network and system administrators to maintain a healthy, efficient, and secure environment. These metrics reveal how many pods are actively involved in sending or receiving TCP RST packets, which can signal unstable connections or misconfigured pods causing network congestion. High rates of resets indicate that pods might be overwhelmed by connection attempts or experiencing resource contention.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/tcp-reset-metrics.png" alt-text="Diagram of TCP reset metrics." lightbox="./media/advanced-container-networking-services/acns-dashboard/tcp-reset-metrics.png":::

5. The **Heatmap of Outgoing TCP RST by Top Source Pods** shows which source pods are generating the most TCP RST packets and when the activity spikes. For the following example heatmap, if *pets/rabbitmq-0* consistently shows high outgoing resets during peak traffic hours, it might indicate that the application or its underlying resources (CPU, memory) are overloaded. The solution could be to optimize the pod's configuration, scale resources, or distribute traffic evenly across replicas.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/heatmap-outgoing-tcp-reset-source-pods.png" alt-text="Diagram of heatmap of outgoing TCP reset by source pods." lightbox="./media/advanced-container-networking-services/acns-dashboard/heatmap-outgoing-tcp-reset-source-pods.png":::

6. The **Heatmap of Incoming TCP RST by Top Destination Pods** identifies destination pods receiving the most TCP RST packets, pointing to potential bottlenecks or connection issues at these pods. If *pets/mongodb-0* is frequently receiving RST packets, it might be an indicator of overloaded database connections or faulty network configurations. The solution could be to increase database capacity, implement rate limiting, or investigate upstream workloads causing excessive connections.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/heatmap-incoming-tcp-reset-destination.png" alt-text="Diagram of heatmap of incoming TCP reset by top destination pods. " lightbox="./media/advanced-container-networking-services/acns-dashboard/heatmap-incoming-tcp-reset-destination.png":::

7. The **Stacked (Total) Outgoing TCP RST by Source Pod** graph provides an aggregated view of outgoing resets over time, highlighting trends or anomalies.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/stacked-outgoing-tcp-reset-by-source-pods.png" alt-text="Snapshot of Stacked(total) outgoing TCP reset by source pod." lightbox="./media/advanced-container-networking-services/acns-dashboard/stacked-outgoing-tcp-reset-by-source-pods.png":::

8. The **Stacked (Total) Incoming TCP RST by Destination Pod** graph aggregates incoming resets, showing how network congestion affects destination pods. For example, a sustained increase in resets for *pets/rabbitmq-0* might indicate that this service is unable to handle incoming traffic effectively, leading to timeouts.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/stacked-incoming-tcp-reset-by-destination-pods.png" alt-text="Snapshot of Total Incoming TCP reset by destination pods." lightbox="./media/advanced-container-networking-services/acns-dashboard/stacked-incoming-tcp-reset-by-destination-pods.png":::

### Analyzing traffic imbalances with Container Network Logs

In addition to using Grafana dashboards, you can use Container Network Logs to analyze traffic patterns and identify imbalances through KQL queries:

```kusto
// Identify pods with high traffic volume (potential imbalances)
RetinaNetworkFlowLogs
| where TimeGenerated between (datetime(<start-time>) .. datetime(<end-time>))
| extend TCP = parse_json(Layer4).TCP
| extend SourcePort = TCP.source_port, DestinationPort = TCP.destination_port
| summarize TotalConnections = count() by SourcePodName, SourceNamespace
| top 10 by TotalConnections desc
```

```kusto
// Analyze TCP reset patterns to identify connection issues
RetinaNetworkFlowLogs
| where TimeGenerated between (datetime(<start-time>) .. datetime(<end-time>))
| extend TCP = parse_json(Layer4).TCP
| extend Flags = TCP.flags
| where Flags contains "RST"
| summarize ResetCount = count() by SourcePodName, DestinationPodName, bin(TimeGenerated, 5m)
| order by TimeGenerated desc, ResetCount desc
```

Replace `<start-time>` and `<end-time>` with your desired time range in the format `2025-08-12T00:00:00Z`.

These queries help identify traffic imbalances and connection issues that might not be immediately visible in the dashboard visualizations.

## Use case 4: Real time monitoring of cluster's network health and performance

Presenting a cluster's network health metrics at a high level is essential for ensuring the overall stability and performance of the system. High-level metrics provide a quick and comprehensive view of the cluster’s network performance, allowing administrators to easily identify potential bottlenecks, failures, or inefficiencies without delving into granular details. These metrics, such as latency, throughput, packet loss, and error rates, offer a snapshot of the cluster’s health, enabling proactive monitoring and rapid troubleshooting.

> We have a sample dashboard that represents overall health of the cluster: **Kubernetes / Networking / Clusters**. Let’s dig deeper into the overall dashboard.

1. **Identify network bottlenecks**: By analyzing the **Bytes Forwarded** and **Packets Forwarded** graphs, you can identify if there are any sudden drops or spikes indicating potential bottlenecks or congestion in the network.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/fleet-view.png" alt-text="Diagram of Fleet view of overall health of cluster." lightbox="./media/advanced-container-networking-services/acns-dashboard/fleet-view.png":::

2. **Detect packet loss**: The **Packets Dropped** and **Bytes Dropped** sections help in identifying if there's significant packet loss occurring within specific clusters, which could indicate issues like faulty hardware or misconfigured network settings.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/bytes-and-packets-dropped-by-cluster.png" alt-text="Diagram of bytes and packets dropped by cluster." lightbox="./media/advanced-container-networking-services/acns-dashboard/bytes-and-packets-dropped-by-cluster.png":::

3. **Monitor traffic patterns**: You can monitor traffic patterns over time to understand normal versus abnormal behavior, which helps in proactive troubleshooting. By comparing max and min ingress/egress bytes and packets, you can analyze performance trends and determine if certain times of day or specific workloads are causing performance degradation.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/egress-ingress-packets-traffic-metrics.png" alt-text="Diagram of egress ingress packets traffic metrics. " lightbox="./media/advanced-container-networking-services/acns-dashboard/egress-ingress-packets-traffic-metrics.png":::

4. **Diagnose drop reasons**: The **Bytes Dropped by Reason** and **Packets Dropped by Reason** sections help in understanding the specific reasons for packet drops, such as policy denials or unknown protocols.

   :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/bytes-dropped-by-reason.png" alt-text="Diagram of bytes drooped by reason." lightbox="./media/advanced-container-networking-services/acns-dashboard/bytes-dropped-by-reason.png":::

5. **Node-specific analysis**: The **Bytes Dropped by Node** and **Packets Dropped by Node** graphs provide insights into which nodes are experiencing the most packet drops. This helps in pinpointing problematic nodes and taking corrective actions to improve network performance.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/bytes-and-packets-dropped-by-node.png" alt-text="Diagram of bytes and packets dropped by different node." lightbox="./media/advanced-container-networking-services/acns-dashboard/bytes-and-packets-dropped-by-node.png":::

6. **Distribution of TCP connections**: The graph here signifies the distribution of TCP connections across different states. For instance, if the graph shows an unusually high number of connections in the `SYN_SENT` state, it might indicate that the cluster nodes are having trouble establishing connections due to network latency or misconfiguration. On the other hand, a considerable number of connections in the `TIME_WAIT` state might suggest that connections aren't being properly released, potentially leading to resource exhaustion.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/distribution-of-tcp-connections-by-state.png" alt-text="Diagram of tcp connection by state. " lightbox="./media/advanced-container-networking-services/acns-dashboard/distribution-of-tcp-connections-by-state.png":::

## Use case 5: Diagnose application-level network issues

L7 traffic observability addresses critical application-layer networking issues by providing deep visibility into HTTP, gRPC, and Kafka traffic. These insights help detect problems such as high error rates (for example, 4xx client-side or 5xx server-side errors), unexpected traffic drops, latency spikes, uneven traffic distribution across pods, and misconfigured network policies. These issues frequently arise in complex microservice architectures where dependencies between services are intricate, and resource allocation is dynamic. For example, sudden increases in dropped Kafka messages or delayed gRPC calls might signal bottlenecks in message processing or network congestion.

> Let's say you have an e-commerce platform deployed in a Kubernetes cluster, where the frontend service relies on several backend microservices, including a payment gateway (gRPC), a product catalog (HTTP), and an order processing service that communicates through Kafka. Recently, users have reported increased checkout failures and slow page load times. Let's dig deeper into how to perform RCA of this issue using our preconfigured dashboards for L7 traffic: **Kubernetes/Networking/L7 (Namespaces)** and **Kubernetes/Networking/L7 (Workload)**.

1. Identify patterns of dropped and forwarded HTTP requests. In the following graph, the outgoing HTTP traffic is segmented by the verdict, highlighting whether requests are "forwarded" or "dropped." For the e-commerce platform, this graph can help identify potential bottlenecks or failures in the checkout process. If there's a noticeable increase in dropped HTTP flows, it might indicate issues such as misconfigured network policies, resource constraints, or connectivity problems between the frontend and backend services. By correlating this graph with specific timeframes of user complaints, administrators can pinpoint whether these drops align with checkout failure.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/outgoing-http-traffic-by-verdict.png" alt-text="Diagram of outgoing http traffic by verdict." lightbox="./media/advanced-container-networking-services/acns-dashboard/outgoing-http-traffic-by-verdict.png":::

2. The following line graph depicts the rate of outgoing HTTP requests over time, categorized by their status codes (for example, *200*, *403*). You can use this graph to identify spikes in error rates (for example, *403 Forbidden* errors), which might indicate issues with authentication or access control. By correlating these spikes with specific time intervals, you can investigate and resolve the underlying problems, such as misconfigured security policies or server-side issues.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/outgoing-http-requests-method-and-count.png" alt-text="Diagram of outgoing http requests method and count." lightbox="./media/advanced-container-networking-services/acns-dashboard/outgoing-http-requests-method-and-count.png":::

3. This following heatmap indicates which pods have outgoing HTTP requests that resulted in 4xx errors. You can use this heatmap to quickly identify problematic pods and investigate the reasons for the errors. By addressing these issues at the pod level, you can improve the overall performance and reliability of their L7 traffic.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/heatmap-http-requests-return-4xx-error.png" alt-text="Diagram of http requests that retuned 4xx errors." lightbox="./media/advanced-container-networking-services/acns-dashboard/heatmap-http-requests-return-4xx-error.png":::

4. Use the following graphs to check which pods receive the most traffic. This helps identify overburdened pods.

   - **Outgoing HTTP Requests for Top 10 Source Pods in default** shows a stable number of outgoing HTTP requests over time for the top ten source pods. The line remains almost flat, indicating consistent traffic without significant spikes or drops.
   - **Heatmap of Dropped Outgoing HTTP Requests for Top 10 Source Pods in default** uses color coding to represent the number of dropped requests. Darker colors indicate higher numbers of dropped requests, while lighter colors indicate fewer or no dropped requests. The alternating dark and light bands suggest periodic patterns in request drops.

   These graphs provide you with valuable insights into their network traffic and performance. The first graph helps you understand the consistency and volume of their outgoing HTTP traffic, which is crucial for monitoring and maintaining optimal network performance. The second graph allows you to identify patterns or periods when there are issues with dropped requests, which can be crucial for troubleshooting network problems or optimizing performance.

    :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/http-requests-for-top-source-pods.png" alt-text="Diagram of http requests for top source pods." lightbox="./media/advanced-container-networking-services/acns-dashboard/http-requests-for-top-source-pods.png":::

### Key factors to focus on during root cause analysis for L7 traffic

1. **Traffic patterns and volume**: Analyze traffic trends to identify surges, drops, or imbalance in traffic distribution. Overloaded nodes or services might lead to bottlenecks or dropped requests.

   :::image type="content" source="./media/advanced-container-networking-services/acns-dashboard/l7-traffic-grafana.png" alt-text="Diagram of l7 traffic grafana. " lightbox="./media/advanced-container-networking-services/acns-dashboard/l7-traffic-grafana.png":::

2. **Error rates**: Track trends in 4xx (invalid requests) and 5xx (backend failures) errors. Persistent errors indicate client misconfigurations or server-side resource constraints.
3. **Dropped requests**: Investigate drops at specific pods or nodes. Drops often signal connectivity issues or policy-related denials.
4. **Policy enforcement and configuration**: Evaluate network policies, service discovery mechanisms, and load balancing settings for misconfigurations.
5. **Heatmaps and flow metrics**: Use visualizations like heatmaps to quickly identify error-heavy pods or traffic anomalies.

### Analyzing L7 traffic with Container Network Logs

Container Network Logs provides comprehensive L7 traffic analysis capabilities through both stored logs and visual dashboards. Use the following KQL queries to analyze HTTP, gRPC, and other application-layer traffic:

```kusto
// Analyze HTTP response codes and error rates
RetinaNetworkFlowLogs
| where TimeGenerated between (datetime(<start-time>) .. datetime(<end-time>))
| where FlowType == "L7_HTTP"
| extend HTTP = parse_json(Layer4).HTTP
| extend StatusCode = HTTP.status_code
| summarize RequestCount = count() by StatusCode, SourcePodName, bin(TimeGenerated, 5m)
| order by TimeGenerated desc
```

```kusto
// Identify pods with high HTTP 4xx or 5xx error rates
RetinaNetworkFlowLogs
| where TimeGenerated between (datetime(<start-time>) .. datetime(<end-time>))
| where FlowType == "L7_HTTP"
| extend HTTP = parse_json(Layer4).HTTP
| extend StatusCode = tostring(HTTP.status_code)
| where StatusCode startswith "4" or StatusCode startswith "5"
| summarize ErrorCount = count(), UniqueErrors = dcount(StatusCode) by SourcePodName, DestinationPodName
| top 10 by ErrorCount desc
```

```kusto
// Monitor gRPC traffic and response times
RetinaNetworkFlowLogs
| where TimeGenerated between (datetime(<start-time>) .. datetime(<end-time>))
| where FlowType == "L7_GRPC"
| extend GRPC = parse_json(Layer4).GRPC
| extend Method = GRPC.method
| summarize RequestCount = count() by SourcePodName, DestinationPodName, Method
| order by RequestCount desc
```

Replace `<start-time>` and `<end-time>` with your desired time range in the format `2025-08-12T00:00:00Z`.

These queries complement the visual dashboards by providing detailed insights into application-layer performance, error patterns, and traffic distribution across your microservices architecture.

## Network Observability included with Azure Monitoring

When you enable Azure Monitor managed service for Prometheus on an AKS cluster, basic node network monitoring metrics are collected by default through the `networkobservabilityRetina` target. This provides:

- **Basic node-level network metrics**: Essential network traffic visibility at the node level
- **Default Prometheus targets**: Network observability metrics automatically scraped by Azure Monitor
- **Azure Monitor integration**: Seamless integration with Azure Monitor; metrics are automatically collected and can be visualized in Grafana
- **No additional setup required**: Automatically enabled when Azure Monitor managed Prometheus is configured
- **Microsoft support**: Supported as part of Azure Monitor and AKS

**Note**: This requires Azure Monitor managed service for Prometheus to be enabled on your AKS cluster, which may have associated costs.

**Getting started**: Enable Azure Monitor managed service for Prometheus on your AKS cluster through Azure portal or CLI. Network observability metrics will be automatically collected and available for visualization in Azure Managed Grafana.

## Network observability with Retina OSS

While Advanced Container Networking Services (ACNS) is a paid offering that provides comprehensive network observability capabilities, Microsoft also supports **Network observability with Retina OSS**, an open-source network observability platform that provides essential network monitoring capabilities.

**Retina OSS** is the open-source observability platform available at [retina.sh](https://retina.sh/) and [GitHub](https://github.com/microsoft/retina). It provides:

- **eBPF-based network observability**: Leverages eBPF technologies to collect insights with minimal overhead
- **Deep traffic analysis with Kubernetes context**: Comprehensive capture and analysis of network traffic flows with full Kubernetes integration
- **Advanced metrics collection**: Layer 4 metrics, DNS metrics, and distributed packet capture capabilities
- **Plugin-based extensibility**: Customize and extend functionality through a plugin architecture
- **Prometheus-compatible metrics**: Export comprehensive network metrics in Prometheus format with configurable metric modes
- **Distributed packet capture**: On-demand packet captures across multiple nodes for deep troubleshooting
- **Platform and CNI agnostic**: Works with any Kubernetes cluster (AKS, Arc-enabled, on-premises), any OS (Linux/Windows), and any CNI
- **Community support**: Open-source with community-driven support and contributions
- **Self-managed**: Complete control over deployment and configuration
- **Hubble integration**: Integrates with Cilium's Hubble for additional network insights

**Getting started**: Deploy Retina OSS using Helm charts or Kubernetes manifests from the [official Retina repository](https://github.com/microsoft/retina). Set up Prometheus and Grafana to visualize metrics, configure deep traffic analysis with Kubernetes context, enable distributed packet capture for advanced troubleshooting, and customize functionality using the plugin-based architecture for specific use cases.

### Comparison of network observability offerings

| Offering | Support | Cost | Management | Deployment | Use Cases |
|----------|---------|------|------------|------------|-----------|
| **Advanced Container Networking Services (ACNS)** | Microsoft enterprise support | Paid Azure service | Fully managed by Microsoft | One-click Azure integration | **Managed enterprise observability**: Pod-level network flows, pod-level metrics, DNS metrics, persistent stored logs, Layer 7 traffic analysis, network security policy enforcement, compliance reporting, advanced Grafana dashboards, AI-powered insights |
| **Network Observability (Azure Monitor)** | Microsoft support as part of Azure Monitor | Included with Azure Monitor managed Prometheus (Azure Monitor costs apply) | Fully managed by Microsoft | Automatic when Azure Monitor managed Prometheus is enabled | **Node network monitoring**: Cluster and node-level network metrics only, no pod-level visibility, no stored logs, no DNS analysis - suitable for basic infrastructure monitoring and users who want minimal network observability without additional configuration |
| **Retina OSS** | Community support | Free and open-source | Self-managed | Manual setup via Helm/manifests on any Kubernetes cluster | **Unmanaged advanced observability**: Real-time packet captures, custom metrics collection, eBPF-based deep network analysis, Hubble integration, multi-cloud deployments, custom observability pipelines, advanced debugging with tcpdump/Wireshark integration, and development/testing environments |

## Learn More

To get started with network observability in AKS:

### Advanced Container Networking Services (ACNS)
- **Set up Container Network Logs**: Learn how to configure [Container Network Logs for comprehensive network observability](./how-to-configure-container-network-logs.md)
- **Explore Advanced Container Networking Services**: For more information about the complete platform, see [What is Advanced Container Networking Services for Azure Kubernetes Service (AKS)?](advanced-container-networking-services-overview.md)
- **Configure monitoring**: Set up [Azure Managed Grafana integration](./how-to-configure-container-network-logs.md#visualization-in-grafana-dashboards) for advanced visualizations
- **Learn about network security**: Explore [Container Network Security features](./advanced-container-networking-services-overview.md#container-network-security) for policy enforcement and threat detection

### Network Observability (Azure Monitor)
- **Azure Monitor integration**: Set up [Azure Monitor for containers](/azure/azure-monitor/containers/container-insights-overview) to view basic network metrics

### Retina OSS
- **Official documentation**: Visit [retina.sh](https://retina.sh/) for comprehensive documentation and guides
- **GitHub repository**: Access the [Microsoft Retina GitHub repository](https://github.com/microsoft/retina) for installation guides, examples, and community support
- **Community support**: Join the [Retina community discussions](https://github.com/microsoft/retina/discussions) for help and best practices
