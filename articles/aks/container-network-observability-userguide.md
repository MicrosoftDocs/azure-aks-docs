---
title: Advanced Container Network Observability User Guide
description: User guide to explain How to use Advanced Container Networking Services effectively
author: shaifaligargmsft
ms.author: shaifaligarg
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: concept-article
ms.date:  06/05/2024
---

# Advanced Container Networking Services User guide 
As modern containerized applications scale across clusters and clouds, ensuring reliable, efficient, and secure network communication becomes critical. [Advanced Container Networking Services](./container-network-observability-concepts.md) provides robust observability solutions for Kubernetes environments, enabling users to monitor, debug, and optimize their network infrastructure seamlessly. Using eBPF-based technologies like Hubble and Retina, and deep integration with Azure Kubernetes Service (AKS), Advanced Container Networking Services delivers powerful tools for tracking network flows, diagnosing connectivity issues, and resolving complex challenges like Domain Name Server(DNS) failures, packet drops, and network policy violations. Users have the capability to define Prometheus alerts based on metrics, enabling proactive monitoring of the health of the cluster's network and detection of anomalies.

This guide serves as a practical resource to help users navigate Advanced Container Networking Service observability capabilities for addressing real-world networking use cases. Whether troubleshooting DNS resolution problems, optimizing ingress and egress traffic, or ensuring compliance with network policies, this manual demonstrates how to harness Advanced Container Networking Service observability dashboards, flow logs, and visualization tools like Hubble UI and CLI to diagnose and resolve issues effectively. With Advanced Container Networking Service, teams gain the insights they need to maintain high-performing and secure Kubernetes workloads, even in the most dynamic environments. Sample dashboards have been created, bearing names such as "Kubernetes / Networking /." . To know how to set up these dahsboards, refer[link](./container-network-observability-how-to.md)

The suite of dashboards includes:

- Clusters: shows Node-level metrics for your clusters.

- DNS (Cluster): shows DNS metrics on a cluster or selection of Nodes.

- DNS (Workload): shows DNS metrics for the specified workload (for example, Pods of a DaemonSet or Deployment such as CoreDNS).

- Drops (Workload): shows drop to/from the specified workload (for example, Pods of a Deployment or DaemonSet).

- Pod Flows (Namespace): shows L4/L7 packet flows to/from the specified namespace (that is, Pods in the Namespace).

- Pod Flows (Workload): shows L4/L7 packet flows to/from the specified workload (for example, Pods of a Deployment or DaemonSet).

- L7 Flows (Namespace): shows http, Kafka, and gRPC packet flows to/from the specified namespace (i.e. Pods in the Namespace) when a Layer 7 based policy is applied. This is available only for clusters with cilium data plane. 

- L7 Flows (Workload): shows http, Kafka, and gRPC flows to/from the specified workload (for example, Pods of a Deployment or DaemonSet) when a Layer 7 based policy is applied. This is available only for clusters with cilium data plane. 

## Use Case 1: Demystifying Domain Name Server(DNS) issues using Advanced Container Networking Service for Root Cause Analysis (RCA)

DNS issues at the pod level are a common challenge in Kubernetes, often causing failed service discovery, slow application responses, or communication failures between pods. These problems frequently arise from misconfigured DNS policies, limited query capacity, or latency in resolving external domains. For instance, if the CoreDNS service is overloaded or an upstream DNS server stops responding, it may lead to failures in dependent pods.  Resolving these issues requires not just identification but deep visibility into DNS behavior within the cluster.
Let us assume that user has set up a web application in AKS cluster and now that web application isn't reachable. User is receiving DNS errors such as DNS_PROBE_FINISHED_NXDOMAIN or SERVFAIL. These are few errors that DNS server is throwing while resolving web application's address

### Step 1: Investigate DNS Metrics in Grafana Dashboards

We have already created two DNS dashboards to investigate DNS metrics, requests, and responses.

DNS (Cluster): Shows DNS metrics on a cluster or selection of Nodes.

DNS (Workload): Shows DNS metrics for the specified workload (for example, Pods of a DaemonSet or Deployment such as CoreDNS).

1. The starting point for the user would be to check the DNS cluster dashboard to get a snapshot of all DNS activities. It provides a high-level overview of DNS requests and responses. The dashboard below shows what kinds of queries lack responses, the most common query, and the most common response. It also highlights the top DNS errors and the nodes that generate most of those errors. Refer to the following image for a glimpse.

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/dns-clusters-snapshot-combined.png" alt-text="Snapshot of DNS Cluster dashboard." lightbox="./media/advanced-container-networking-services/acnsdashboard/dns-clusters-snapshot-combined.png":::

2. User can also scroll down to find out pods with most DNS request and errors in all namespaces.

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/toppods-with-dns-errors-inworkload.png" alt-text="Snapshot of top pods in all namespaces. " lightbox="./media/advanced-container-networking-services/acnsdashboard/toppods-with-dns-errors-inworkload.png":::

Once the user identifies the pods causing the most DNS issues, they can delve further into the DNS Workload dashboard for a more granular view. By correlating data across various panels within the dashboard, the user can systematically narrow down the root causes of the issues.

3. DNS Requests and Responses: Identify trends like a sudden drop in response rates or an increase in missing responses (as seen in the below panel). A high "Requests Missing Response %" indicates potential upstream DNS server issues or query overload. Here, user can see there's a sudden increase in requests and responses at around 15.22.

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/workload-dns-requests-and-responses.png" alt-text="Diagram of DNS requests and responses in specific workload. " lightbox="./media/advanced-container-networking-services/acnsdashboard/workload-dns-requests-and-responses.png":::

4. Next step is to check for any DNS errors by type. Check for spikes in specific error types (for example, NXDOMAIN for nonexistent domains). In this example, there's a significant increase in Query refused errors, suggesting a mismatch in DNS configurations or unsupported queries.

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/types-of-dnserror-responses.png" alt-text="Diagram of DNS Errors by type. " lightbox="./media/advanced-container-networking-services/acnsdashboard/types-of-dnserror-responses.png":::


5. Use panels like "DNS Response IPs Returned" to ensure that expected responses are being processed. This graph displays the rate of successful DNS queries processed per second. This information is useful for understanding how frequently DNS queries are being successfully resolved for the specified workload.
    - Increased rate: Could indicate a surge in traffic or a potential DNS attack (for example, Distributed Denial of Serbice(DDoS). 
    - Decreased rate: It might signify issue reaching external DNS server, coredns configuration issue, or unreachable workload from coredns.

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/rate-of-IPs-returned-dnsreponses.png" alt-text="Diagram of rate of IPs retuned in DNS responses per second. " lightbox="./media/advanced-container-networking-services/acnsdashboard/rate-of-IPs-returned-dnsreponses.png":::

6. Examining the most frequent DNS queries can help identify patterns in network traffic. This information is useful for understanding workload distribution and detecting any unusual or unexpected query behaviors that may require attention.

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/top-dns-queries-requests.png" alt-text="Diagram of top DNS queries in requests. " lightbox="./media/advanced-container-networking-services/acnsdashboard/top-dns-queries-requests.png":::

7. The following table aids DNS issue root cause analysis by highlighting query types, responses, and error codes like "SERVFAIL(Server Failure)" It identifies problematic queries, patterns of failures, or misconfigurations. By observing trends in return codes and response rates, users can pinpoint specific nodes, workloads, or queries causing DNS disruptions or anomalies. For example, users can see that for AAAA(IPV6) records, there's no error, but for A(IPV4) record example.com, there's a server failure. Sometimes, the DNS server might be configured to prioritize IPv6 over IPv4. This can lead to situations where IPv6 addresses are returned correctly, but IPv4 addresses face issues

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/dns-response-table.png" alt-text="Diagram of DNS response table. " lightbox="./media/advanced-container-networking-services/acnsdashboard/dns-response-table.png":::

8. Finally, when it's confirmed that there's a DNS issue, the following graph identifies the top ten destinations causing DNS errors in a cluster. Users can use this to prioritize troubleshooting specific endpoints, detect misconfigurations, or investigate network issues. By focusing on the most problematic destinations, users can efficiently address critical DNS failures.

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/top-pods-with-dnserrors-inworkload.png" alt-text="Diagram of top pods with most DNS errors. " lightbox="./media/advanced-container-networking-services/acnsdashboard/top-pods-with-dnserrors-inworkload.png":::

### Step 2: Debugging DNS Resolution of a Pod with Hubble flow logs

To dig deeper, we can leverage the Hubble CLI tool to inspect flows in real time. The below snapshot shows how we can filter traffic using namespace and type. From the above step, user would have list of pods that causes most DNS errors, so user can use following command to see DNS flows on each pod.

```azurecli-interactive
hubble observe --dns --pod <pod-name>
```

This command filters DNS-related traffic for the specified pod, showing details like DNS queries, responses, and latency.

**Example output- See below Hubble logs. Here we can see query is getting refused.**

:::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/hubble-dns-response-combined.png" alt-text="Diagram of one of the command for hubble CLI. " lightbox="./media/advanced-container-networking-services/acnsdashboard/hubble-dns-response-combined.png":::


Hubble logs provide detailed insights into DNS queries and their responses, which can assist in diagnosing and troubleshooting DNS-related issues. Each log entry includes information such as the query type (for example, A or AAAA), the queried domain name, the DNS response code (for example, "Query Refused," "Non-Existent Domain," or "Server Failure"), and the source and destination of the DNS request. To troubleshoot DNS issues, users should:
1.	Identify the Query Status: Examine the DNS Answer RCode field for responses like Query Refused or Server Failure, which indicates issues with the DNS server or configuration.
2.	Verify the Queried Domain: Ensure the domain name listed (for example, example.com) is correct and exists. For "Non-Existent Domain" errors, confirm the domain is valid and resolvable.
3.	Track Forwarding Behavior: Look at forwarding details to understand whether the query was successfully forwarded to the DNS server or endpoint. Disruptions in this process could indicate networking or configuration problems.
4.	Analyze Timestamps: Use timestamps to correlate specific DNS issues with other events in your system for a comprehensive diagnosis.
5.	Cross-Check IDs: Match the ID fields for requests and responses to ensure continuity and check for anomalies in query processing.
By systematically reviewing this information, users can pinpoint the root cause of DNS issues, such as incorrect configurations, unreachable DNS servers, or invalid domains


### Step 3: Visualize Dependencies Using Hubble Service Graphs

The Hubble UI service graph complements CLI insights by visualizing DNS-related traffic and dependencies. Filtering the service graph for DNS traffic on the affected nodes reveals:
- Which pods or services are sending high volumes of DNS queries.
- The flow of traffic to CoreDNS or external DNS services.
- Dropped packets  flows, often marked in red.

:::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/hubble-ui-servicemap.png" alt-text="Diagram of Hubble UI service map. " lightbox="./media/advanced-container-networking-services/acnsdashboard/hubble-ui-servicemap.png":::

With the combined capabilities of the grafana dashboards, Hubble CLI, and Hubble UI, users can swiftly identify DNS issues and perform root cause analysis (RCA) with efficiency and precision.

## Use Case 2: Identifying packet drops at cluster and pod level due to misconfigured network policy or network connectivity issues.

Connectivity and network policy enforcement challenges are common in containerized environments. These issues often stem from misconfigured Kubernetes network policies, incompatible Container Network Interface (CNI) plugins, overlapping IP ranges, or network connectivity degradation. Such problems can disrupt application functionality, resulting in service outages and degraded user experiences.

When a packet drop occurs, eBPF programs capture the event and generate metadata about the packet, including the drop reason and its location. This data is processed by a user space program, which parses the information and converts it into Prometheus metrics. These metrics offer critical insights into the root causes of packet drops, enabling administrators to identify and resolve issues such as network policy misconfigurations effectively.

In addition to policy enforcement issues, network connectivity problems can cause packet drops due to factors like TCP errors or retransmissions. Administrators can debug these issues by analyzing TCP retransmission tables and error logs, which help identify degraded network links or bottlenecks. By leveraging these detailed metrics and debugging tools, teams can ensure smooth network operations, reduce downtime, and maintain optimal application performance. Let us assume, a microservices-based application where the front-end pod can't communicate with a back-end pod due to an overly restrictive network policy blocking ingress traffic.

### Step 1: Investigate Drop Metrics in Grafana Dashboards

1. If there are packet drops, begin your investigation with the Dashboard Pod Flows (Namespace). This dashboard has panels that assist in identifying namespaces with the highest drops and then pods within those namespaces that have the highest drops. For example, Review the Heatmap of Outgoing Drops for top source pods or top destination pods to identify which pods are most affected; brighter colours indicate higher rates of drops. Compare across time to detect patterns or spikes in specific pods. Refer to the following snapshot of that dashboard:

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/pod-flow-snapshot.png" alt-text="Diagram of snapshot of Pod flows(Namespace) dashboard. " lightbox="./media/advanced-container-networking-services/acnsdashboard/pod-flow-snapshot.png":::

2. Once the top pods with highest drops are identified, user can checkout Drops (Workload) Dashboard. Refer following image - Users can leverage this dashboard to diagnose network connectivity issues by identifying patterns in outgoing traffic drops from specific pods. The visualizations highlight which pods are experiencing the most drops, the rate of those drops, and the reasons behind them—such as policy denials. By correlating spikes in drop rates with specific pods or timeframes, users can pinpoint misconfigurations, overloaded services, or policy enforcement problems that may be disrupting connectivity, enabling faster troubleshooting and resolution.

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/workload-snapshot-for-dropped-packets.png" alt-text="Diagram of Workload snapshot of dropped packets." lightbox="./media/advanced-container-networking-services/acnsdashboard/workload-snapshot-for-dropped-packets.png":::

3. Analyze Workload Snapshot: Look at the following Workload Snapshot panel to identify pods with outgoing packet drops. Focus on the metrics "Max Outgoing Drops" and "Min Outgoing Drops" to understand the severity of the issue (e.g., 1.93 packets/sec in this example). Prioritize investigating pods with consistently high packet drop rates.

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/workload-snapshot-with-metrics.png" alt-text="Diagram of Workload snapshot of pod flow metrics. " lightbox="./media/advanced-container-networking-services/acnsdashboard/workload-snapshot-with-metrics.png":::

4. Examine Dropped Traffic by Reason: Use the Dropped Incoming/Outgoing Traffic by Reason graph to identify the root cause of the drops. In this case, the reason is policy denied, indicating misconfigured network policies blocking outgoing traffic. Check if any specific time interval shows a spike in drops to narrow down when the issue started.

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/dropped-traffic-byreason.png" alt-text="Diagram of Dropped Incoming traffic by reason." lightbox="./media/advanced-container-networking-services/acnsdashboard/dropped-traffic-byreason.png":::

5.  Utilize Heatmap for Source/Destination Pods: Review the Heatmap of Outgoing Drops for Top Source Pods or top destination pods to identify which pods are most affected. Brighter colors indicate higher rates of drops. Compare across time to detect patterns or spikes in specific pods.

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/heatmap-of-droppakets-at-destinationpod.png" alt-text="Diagram of heatmap of incoming drops for top destination pods." lightbox="./media/advanced-container-networking-services/acnsdashboard/heatmap-of-droppakets-at-destinationpod.png":::

6. Investigate Stacked Outgoing Drops: Use the Stacked (Total) Outgoing/Incoming Drops by Source Pod chart to compare drop rates across affected pods. Identify if specific pods consistently show higher drops (e.g., kapinger-bad-6659b89fd8-zjb9k at 26.8 p/s). Here p/s refers to drop packet per second. Cross-reference these pods with their workloads, labels, and network policies to diagnose potential misconfigurations.

:::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/total-outgoing-drops-by-sourcepods.png" alt-text="Diagram of Hubble UI service map ." lightbox="./media/advanced-container-networking-services/acnsdashboard/total-outgoing-drops-by-sourcepods.png":::

By combining these insights, the user can pinpoint specific pods, time intervals, and misconfigured policies responsible for packet drops, enabling targeted troubleshooting and policy corrections.

### Step 2: Investigate with Hubble CLI

Using Hubble CLI, user can identify packet drops caused by misconfigured network policies with detailed, real-time data. Hubble CLI provides granular, real-time insights into dropped packets. By observing traffic, focusing on policy denied drops, and analyzing patterns, user can identify the misconfigured network policies and validate fixes.

:::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/hubblecli-logs-for-drop-flow.png" alt-text="Diagram of Hubble UI service map. " lightbox="./media/advanced-container-networking-services/acnsdashboard/hubblecli-logs-for-drop-flow.png":::

### Step 3: Observe the Hubble UI

Another useful tool is the Hubble UI, which provides a visual representation of traffic flows within a namespace. For example, in the agnhost namespace, the UI displays interactions between pods within the same namespace, pods in other namespaces, and even packets originating from outside the cluster. Additionally, the interface highlights dropped packets and provides detailed information, such as the source and destination pod names, along with pod and namespace labels. This data can be instrumental in reviewing the network policies applied in the cluster, allowing administrators to swiftly identify and address any misconfigured or problematic policies. Refer following image –

:::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/hubbleui-for-drop-flow.png" alt-text="Diagram of Hubble UI service map for dropped packets. " lightbox="./media/advanced-container-networking-services/acnsdashboard/hubbleui-for-drop-flow.png":::

## Use Case 3: Identifying Traffic Imbalances within Workloads and Namespaces

Traffic imbalances occur when certain pods or services within a workload or namespace handle a disproportionately high volume of network traffic compared to others. This can lead to resource contention, degraded performance for overloaded pods, and underutilization of others. Such imbalances often arise due to misconfigured services, uneven traffic distribution by load balancers, or unanticipated usage patterns.

**Example:**

Consider an online retail platform running on an AKS cluster. The platform consists of multiple microservices, including a product search service, a user authentication service, and an order processing service, all deployed within the same namespace. During a seasonal sale, the product search service experiences a surge in traffic, while the other services remain idle. The load balancer inadvertently directs more requests to a subset of pods within the product search deployment, leading to congestion and increased latency for search queries. Meanwhile, other pods in the same deployment are underutilized. To learn how to deploy application with microservices in AKS cluster ,refer [Deploy AKS store demo application on AKS](./tutorial-kubernetes-prepare-app.md)

Without observability, it is challenging to identify which pods or namespaces are overloaded or underutilized. Advanced container networking services can help by monitoring real-time traffic patterns at the pod level. They provide metrics on bandwidth usage, request rates, and latency, making it easy to pinpoint imbalances.

### Step 1. Investigate Pod traffic by Grafana dashboard.

1. Start by exploring Pod flow(workload) dashboard. Workload Snapshot displays various statistics such as "Outgoing Traffic", "Incoming Traffic", "Outgoing Drops", and "Incoming Drops".

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/workloadsnapshot-for-pod-traffic.png" alt-text="Diagram of workload snapshot for pod traffic. " lightbox="./media/advanced-container-networking-services/acnsdashboard/workloadsnapshot-for-pod-traffic.png":::

2. Then examine the fluctuations in traffic for each trace type. Significant variations in the blue and green lines indicate changes in traffic volume for applications and services, which could contribute to congestion. By identifying periods with high traffic, user can pinpoint times of congestion and investigate further. Additionally, compare the outgoing and incoming traffic patterns. If there's a significant imbalance between outgoing and incoming traffic, it could indicate network congestion or bottlenecks. Monitoring these trends can help identify areas where traffic is accumulating and causing congestion.
    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/outgoing-traffic-by-trace-type.png" alt-text="Diagram of outgoing traffic by trace type." lightbox="./media/advanced-container-networking-services/acnsdashboard/outgoing-traffic-by-trace-type.png":::

3. The heatmaps represent traffic flow metrics at the pod level within a Kubernetes cluster. The left heatmap shows outgoing traffic from the top 10 source pods, while the right displays incoming traffic to the top 10 destination pods. Color intensity indicates traffic volume, with darker shades representing higher traffic. Consistent patterns highlight pods generating or receiving significant traffic, such as default/tcp-client-0, which may act as a central node.
The following heatmap indication higher traffic is receiving and coming out of the single pod. If the same pod (e.g., default/tcp-client-0) appears in both heatmaps with high traffic intensity, it might suggest that it's both sending and receiving a large volume of traffic, potentially acting as a central node in the workload. Variations in intensity across pods may indicate uneven traffic distribution, with some pods handling disproportionately more traffic than others.
   
     :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/heatmap-outgoing-and-incoming-traffic.png" alt-text="Diagram of heatmap of outgoing traffic at source pods and incoming traffic at destination pods." lightbox="./media/advanced-container-networking-services/acnsdashboard/heatmap-outgoing-and-incoming-traffic.png":::

4. Monitoring TCP reset traffic is crucial for understanding network behavior, troubleshooting issues, enforcing security, and optimizing application performance. It provides valuable insights into how connections are managed and terminated, allowing network and system administrators to maintain a healthy, efficient, and secure environment. These metrics reveal how many pods are actively involved in sending or receiving TCP RST packets, which can signal unstable connections or misconfigured pods causing network congestion. High rates of resets indicate that pods might be overwhelmed by connection attempts or experiencing resource contention.

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/tcp-reset-metrics.png" alt-text="Diagram of TCP reset metrics." lightbox="./media/advanced-container-networking-services/acnsdashboard/tcp-reset-metrics.png":::

5. Heatmap of Outgoing TCP RST by Top Source Pods: This heatmap shows which source pods are generating the most TCP RST packets and when the activity spikes. For below heatmap, if pets/rabbitmq-0 consistently shows high outgoing resets during peak traffic hours, it may indicate that the application or its underlying resources (CPU, memory) are overloaded. Solution could be - Optimize the pod's configuration, scale resources, or distribute traffic evenly across replicas.

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/heatmap-outgoing-tcpreset-sourcepods.png" alt-text="Diagram of heatmap of outgoing TCP reset by source pods." lightbox="./media/advanced-container-networking-services/acnsdashboard/heatmap-outgoing-tcpreset-sourcepods.png":::

6. Heatmap of Incoming TCP RST by Top Destination Pods: This heatmap identifies destination pods receiving the most TCP RST packets, pointing to potential bottlenecks or connection issues at these pods. If pets/mongodb-0 is frequently receiving RST packets, it could be an indicator of overloaded database connections or faulty network configurations. Solution: Increase database capacity, implement rate limiting, or investigate upstream workloads causing excessive connections.
   
      :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/heatmap-incoming-tcpreset-destination.png" alt-text="Diagram of heatmap of incoming TCP reset by top destination pods. " lightbox="./media/advanced-container-networking-services/acnsdashboard/heatmap-incoming-tcpreset-destination.png":::

7. Stacked (Total) Outgoing TCP RST by Source Pod:  This graph provides an aggregated view of outgoing resets over time, highlighting trends or anomalies.
    
    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/stacked-outgoing-tcpreset-by-sourcepods.png" alt-text="Snapshot of Stacked(total) outgoing TCP reset by source pod." lightbox="./media/advanced-container-networking-services/acnsdashboard/stacked-outgoing-tcpreset-by-sourcepods.png":::

8. Stacked (Total) Incoming TCP RST by Destination Pod: This graph aggregates incoming resets, showing how network congestion affects destination pods. For example, A sustained increase in resets for pets/rabbitmq-0 may indicate that this service is unable to handle incoming traffic effectively, leading to timeouts.
    
    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/stacked-incoming-tcpreset-by-destinationpods.png" alt-text="Snapshot of Total Incoming TCP reset by destination pods." lightbox="./media/advanced-container-networking-services/acnsdashboard/stacked-incoming-tcpreset-by-destinationpods.png":::

By correlating data across these graphs, user can:

- Pinpoint the pods responsible for high TCP reset packet rates.

- Identify time frames and workloads with significant traffic imbalances.

- Implement scaling, traffic balancing, or resource optimization strategies to mitigate congestion.

- Verify the effectiveness of applied changes by observing reduced RST rates in subsequent monitoring sessions.

## Use case 4: Real time monitoring of cluster’s network health and performance.

Presenting a cluster's network health metrics at a high level is essential for ensuring the overall stability and performance of the system. High-level metrics provide a quick and comprehensive view of the cluster’s network performance, allowing administrators to easily identify potential bottlenecks, failures, or inefficiencies without delving into granular details. These metrics, such as latency, throughput, packet loss, and error rates, offer a snapshot of the cluster’s health, enabling proactive monitoring and rapid troubleshooting. We have a sample dashboard that represents overall health of the cluster. “Kubernetes / Networking / Clusters”. Let’s dig deeper into the overall dashboard.

1. Identifying Network Bottlenecks: By analyzing the "Bytes Forwarded" and "Packets Forwarded" graphs, users can identify if there are any sudden drops or spikes indicating potential bottlenecks or congestion in the network.
    
    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/fleet-view.png" alt-text="Fleet view of overall health of cluster." lightbox="./media/advanced-container-networking-services/acnsdashboard/fleet-view.png":::

2. Detecting Packet Loss: The "Packets Dropped" and "Bytes Dropped" sections help in identifying if there's significant packet loss occurring within specific clusters, which could indicate issues like faulty hardware or misconfigured network settings.
        
    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/bytes-andpackets-dropped-by-cluster.png" alt-text="Diagram of bytes and packets dropped by cluster." lightbox="./media/advanced-container-networking-services/acnsdashboard/bytes-andpackets-dropped-by-cluster.png":::



3. Monitoring Traffic Patterns: Users can monitor traffic patterns over time to understand normal versus abnormal behavior, which helps in proactive         troubleshooting before issues escalate. By comparing max and min ingress/egress bytes and packets, users can analyse performance trends and determine if certain times of day or specific workloads are causing performance degradation.
    
    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/egress-ingress-packets-traffic-metrics.png" alt-text="Diagram of egress ingress packets traffic metrics. " lightbox="./media/advanced-container-networking-services/acnsdashboard/egress-ingress-packets-traffic-metrics.png":::

4. Diagnosing Drop Reasons: The "Bytes Dropped by Reason" and "Packets Dropped by Reason" sections help in understanding the specific reasons for packet drops, such as policy denials or unknown protocols. This information is crucial for addressing the root cause of network issues.
 
   :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/bytes-drooped-by-reason.png" alt-text="Diagram of bytes drooped by reason." lightbox="./media/advanced-container-networking-services/acnsdashboard/bytes-drooped-by-reason.png":::

5. Node-Specific Analysis: The "Bytes Dropped by Node" and "Packets Dropped by Node" graphs provide insights into which nodes are experiencing the most packet drops. This helps in pinpointing problematic nodes and taking corrective actions to improve network performance.
    
    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/bytes-and-packets-dropped-by-node.png" alt-text="Diagram of bytes and packets dropped by different node." lightbox="./media/advanced-container-networking-services/acnsdashboard/bytes-and-packets-dropped-by-node.png":::

6. Distribution of TCP connections: The graph here signifies the distribution of TCP connections across different states. For instance, if the graph shows an unusually high number of connections in the SYN_SENT state, it may indicate that the cluster nodes are having trouble establishing connections, due to network latency or misconfiguration. On the other hand, a considerable number of connections in the TIME_WAIT state could suggest that connections are not being properly released, potentially leading to resource exhaustion.
   
    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/distribution-of-tcp-connections-by-state.png" alt-text="Diagram of tcp connection by state. " lightbox="./media/advanced-container-networking-services/acnsdashboard/distribution-of-tcp-connections-by-state.png":::

## Use Case 5 - Diagnosing Application-level network issues with Advanced Container Networking Services

L7 traffic observability addresses critical application-layer networking issues by providing deep visibility into HTTP, gRPC, and Kafka traffic. These insights help detect problems such as high error rates (for example, 4xx client-side or 5xx server-side errors), unexpected traffic drops, latency spikes, uneven traffic distribution across pods, and misconfigured network policies. These issues frequently arise in complex microservice architectures where dependencies between services are intricate, and resource allocation is dynamic. For example, sudden increases in dropped Kafka messages or delayed gRPC calls may signal bottlenecks in message processing or network congestion.

Imagine an e-commerce platform deployed in a Kubernetes cluster, where the frontend service relies on several backend microservices, including a payment gateway (gRPC), a product catalog (HTTP), and an order processing service that communicates through Kafka. Recently, users have reported increased checkout failures and slow page load times. Let us dig deeper how to perform RCA of this issue using our pre-configured dashboard for L7 traffic which can be found as “Kubernetes/Networking/L7(namespaces)” and Kubernetes/Networking/L7(Workload)”

1. Identifying patterns of dropped and forwarded HTTP requests: In the given graph, the outgoing HTTP traffic is segmented by the verdict, highlighting whether requests are "forwarded" or "dropped." For the e-commerce platform, this graph can help identify potential bottlenecks or failures in the checkout process. If there is a noticeable increase in dropped HTTP flows, it may indicate issues such as misconfigured network policies, resource constraints, or connectivity problems between the frontend and backend services. By correlating this graph with specific timeframes of user complaints, administrators can pinpoint whether these drops align with checkout failure.

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/outgoing-http-traffic-by-verdict.png" alt-text="Diagram of outgoing http traffic by verdict." lightbox="./media/advanced-container-networking-services/acnsdashboard/outgoing-http-traffic-by-verdict.png":::

2. Following section presents a line graph depicting the rate of outgoing HTTP requests over time, categorized by their status codes (e.g., 200, 403). Users can use this graph to identify spikes in error rates (e.g., 403 Forbidden errors), which may indicate issues with authentication or access control. By correlating these spikes with specific time intervals, users can investigate and resolve the underlying problems, such as misconfigured security policies or server-side issues.
   
    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/outgoing-http-requests-method-and-count.png" alt-text="Diagram of outgoing http requests method and count." lightbox="./media/advanced-container-networking-services/acnsdashboard/outgoing-http-requests-method-and-count.png":::

3. This section provides a heatmap indicating which pods have outgoing HTTP requests that resulted in 4xx errors. Users can use this heatmap to quickly identify problematic pods and investigate the reasons for the errors. By addressing these issues at the pod level, users can improve the overall performance and reliability of their L7 traffic.
     
    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/heatmap-httprequests-return-4xxerror.png" alt-text="Diagram of http requests that retuned 4xx errors." lightbox="./media/advanced-container-networking-services/acnsdashboard/heatmap-httprequests-return-4xxerror.png":::

4. Use the following graph to check which pods receive the most traffic. This helps identify overburdened pods.
   - The first graph, titled "Outgoing HTTP Requests for Top 10 Source Pods in default," shows a stable number of outgoing HTTP requests over time for the top ten source pods. The line remains almost flat, indicating consistent traffic without significant spikes or drops.
   - The second graph, titled "Heatmap of Dropped Outgoing HTTP Requests for Top 10 Source Pods in default," uses colour coding to represent the number of dropped requests. Darker colours indicate higher numbers of dropped requests, while lighter colours indicate fewer or no dropped requests. The alternating dark and light bands suggest periodic patterns in request drops.
   These graphs provide customers with valuable insights into their network traffic and performance. The first graph helps customers understand the consistency and volume of their outgoing HTTP traffic, which is crucial for monitoring and maintaining optimal network performance. The second graph allows customers to identify patterns or periods when there are issues with dropped requests, which can be crucial for troubleshooting network problems or optimizing performance.

    :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/http-requests-for-top-sourcepods.png" alt-text="Diagram of http requests for top source pods." lightbox="./media/advanced-container-networking-services/acnsdashboard/http-requests-for-top-sourcepods.png":::

### Key Factors to Focus on During Root Cause Analysis for L7 traffic:

1. **Traffic Patterns and Volume**: Analyze traffic trends to identify surges, drops, or imbalance in traffic distribution. Overloaded nodes or services may lead to bottlenecks or dropped requests.

   :::image type="content" source="./media/advanced-container-networking-services/acnsdashboard/l7-traffic-grafana.png" alt-text="Diagram of l7 traffic grafana ." lightbox="./media/advanced-container-networking-services/acnsdashboard/l7-traffic-grafana.png":::

2. **Error Rates**: Track trends in 4xx (invalid requests) and 5xx (backend failures) errors. Persistent errors indicate client misconfigurations or server-side resource constraints.

3. **Dropped Requests**: Investigate drops at specific pods or nodes. Drops often signal connectivity issues or policy-related denials.

4. **Policy Enforcement and Configuration**: Evaluate network policies, service discovery mechanisms, and load balancing settings for misconfigurations.

5. **Heatmaps and Flow Metrics**: Use visualizations like heatmaps to quickly identify error-heavy pods or traffic anomalies.

## Conclusion

In conclusion, Advanced Container Networking Services provide a robust framework for real-time monitoring and troubleshooting of cluster network health and performance. By leveraging the comprehensive set of metrics and visual dashboards, users can swiftly identify network bottlenecks, detect packet loss, monitor traffic patterns, and diagnose drop reasons. The node-specific analysis further aids in pinpointing problematic nodes, allowing for targeted interventions to enhance network stability. With these tools at their disposal, administrators can ensure optimal performance and proactive management of their cluster networks, leading to a more resilient and efficient system.

## Next Steps
* For more information about Advanced Container Networking Services for Azure Kubernetes Service (AKS), see [What is Advanced Container Networking Services for Azure Kubernetes Service (AKS)?](advanced-container-networking-services-overview.md).
