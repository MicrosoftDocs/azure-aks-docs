---
title: Container Network Logs with Advanced Container Networking Services
description: An overview of Container Network Logs capabilities on Azure Kubernetes Service (AKS).
author: shaifaligargmsft
ms.author: shaifaligarg
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: concept-article
ms.date:  05/16/2025
---

# What is Container Network Logs (Preview)?

Container Network Logs for Azure Kubernetes Service (AKS) in [Advanced Container Networking Services](advanced-container-networking-services-overview.md) provides deep visibility into network traffic within the cluster. The logs capture essential metadata, including source and destination IP addresses, pod and service names, ports, protocols, and traffic direction for detailed insight into network behavior. Container Network Logs captures Layer 3 (IP), Layer 4 (TCP/UDP), and Layer 7 (HTTP/gRPC/Kafka) traffic to give you effective connectivity monitoring, troubleshooting, network topology visualization, and security policy enforcement. Choose from two modes: stored logs and on-demand logs.

## Stored logs

This mode ensures continuous log generation and collection on the AKS cluster when you enable Advanced Container Networking Services and set up custom filters. Log collection is disabled by default. To enable log collection, you define *custom resources* to specify the types of traffic to monitor, such as namespaces, pods, services, or protocols. This feature remains active until you explicitly disable it. This mode supports extended log retention, but it also supports traffic filtering. For reduced storage cost and easier analysis, you can collect and retain logs that are relevant to you. Define a custom resource to use traffic filtering.

### How stored logs mode works

Advanced Container Networking Services uses eBPF technology with Cilium to fetch logs from nodes. To start collecting logs, you define one or more custom resources to specify the types of traffic to monitor. Custom resources give you fine-grained control, ensuring that only relevant traffic is captured. The Cilium agent, running on each node, collects the network traffic that matches the criteria set in the custom resources. The logs are stored in JSON format on the host, providing a structured and accessible format for further use. Alternatively, if the Azure Monitoring add-on is enabled, agents for Container insights collects the logs from the host, applies the default throttling limits, and sends them to the  Log Analytics workspace. The system aggregates and stores log efficiently to give you visibility into network traffic for monitoring, troubleshooting, and helping enforce security.

:::image type="content" source="./media/advanced-container-networking-services/how-container-network-logs-works.png" alt-text="Diagram of how container network logs work." lightbox="./media/advanced-container-networking-services/how-container-network-logs-works.png":::

To read more about throttling and Container insights, see the [Container insights documentation](https://aka.ms/ContainerNetworkLogsDoc_CI).

### Key capabilities of stored logs mode

- Customizable filters: Logging is configurable via defining custom resources of type [RetinaNetworkFlowLog](./how-to-configure-container-network-logs.md#retinanetworkflowlog-template). With these custom resources, users can apply granular filters by namespace, pod, service, port, protocol, verdict, or traffic direction (ingress/egress). This flexibility ensures precise data collection tailored to specific use cases, logs only relevant traffic, and optimizes storage usage for better performance, compliance, and efficient troubleshooting.

- Log storage options: There are two primary storage options for Container Network Logs: managed storage and unmanaged storage.

  - Unmanaged storage: When a custom resource is applied to enabled collection of logs, network flow logs are stored locally on the host nodes at the fixed mount location /var/log/acns/hubble. However, this storage location is temporary, as the node itself isn't a persistent storage solution. Additionally, once the log files reach a size of 50 MB, they're automatically rotated, which means older logs are overwritten. This storage solution is suitable for real-time monitoring but doesn't support long-term storage or retention. For users seeking more log management capabilities, non-Microsoft logging services such as an OpenTelemetry collector can be integrated. These options provide flexibility to manage logs outside of the Azure ecosystem and is useful for customers who already use specific log management platforms.

  - Managed storage: For long-term retention and advanced analytics, it's recommended to configure Azure monitoring within your AKS cluster to collect and store logs in an Azure Log Analytics workspace. This setup not only ensures secure and compliant log storage but also enables powerful capabilities such as anomaly detection, performance tuning, and historical data analysis. Using historical logs, users can identify trends, baseline behaviors, and proactively address recurring issues.

    For example, with the managed service for Prometheus, you can configure alerts on both metrics and logs for real-time monitoring and rapid detection of outliers.

    Workspace used for logs storage is the same, which is configured during onboarding. In context of supported plans for storage for this feature, both Analytics and Basic table plans are supported. For more detailed information on table plans, refer to the ([Azure Monitor Logs Documentation](/azure/azure-monitor/logs/data-platform-logs))

- Simple visualization in Azure log analytics and Grafana dashboards: By presenting logs and data in grafana, dashboards simplify complex information, facilitate faster data comprehension, and enable quicker decision-making.

### Visualization of logs in the Azure portal

You can visualize, query, and analyze flow logs in the Azure portal in the Log Analytics workspace for your cluster.

:::image type="content" source="./media/advanced-container-networking-services/azure-log-analytics.png" alt-text="Screenshot of container network logs in a Log Analytics workspace." lightbox="./media/advanced-container-networking-services/azure-log-analytics.png":::

### Visualization of logs in Grafana dashboards

- Access in Azure Managed Grafana instances.

  To simplify the analysis of logs, we provide preconfigured two Azure Managed Grafana dashboards. You can find them as:

  - **Azure / Insights / Containers / Networking / Flow Logs** - This dashboard provides visualizations into which Kubernetes workloads are communicating with each other, including network requests, responses, drops, and errors. Currently, user has to import grafana dashboards with user ID to fetch flow logs dashboard in Azure portal. We understand it's is an interim solution.

    :::image type="content" source="./media/advanced-container-networking-services/container-network-logs-dashboard.png" alt-text="Screenshot of Flow log Grafana dashboard in grafana instance." lightbox="./media/advanced-container-networking-services/container-network-logs-dashboard.png":::

  - **Azure / Insights / Containers / Networking / Flow Logs (External Traffic)** - This dashboard provides visualizations into which Kubernetes workloads are sending/receiving communications from outside a Kubernetes cluster, including network requests, responses, drops, and errors.

    :::image type="content" source="./media/advanced-container-networking-services/container-network-logs-dashboard-external.png" alt-text="Screenshot of Flow log (external) Grafana dashboard in grafana instance." lightbox="./media/advanced-container-networking-services/container-network-logs-dashboard-external.png":::

    For more information, see [Set up Azure Managed Grafana with Advanced Container Networking Services](./how-to-configure-container-network-logs.md#visualization-using-azure-managed-grafana).

- Access in the Azure portal via the **Dashboards with Grafana** option.

  :::image type="content" source="./media/advanced-container-networking-services/grafana-dashboard-in-monitor-resource.png" alt-text="Screenshot of grafana dashboards in Azure monitor." lightbox="./media/advanced-container-networking-services/grafana-dashboard-in-monitor-resource.png":::

The dashboards have the following major components:

- *A comprehensive overview of network health.*

  You see key metrics, like total flow logs, unique requests, dropped requests, and forwarded requests for quick anomaly detection and efficient troubleshooting. The dashboard categorizes statistics by protocol and behavior, including DNS dropped requests, HTTP 2xx responses, Layer 4 request and response rates, and dropped request counts. A service dependency graph visualizes application or cluster interactions, highlighting traffic flow, bottlenecks, and dependencies for performance optimization.

  :::image type="content" source="./media/advanced-container-networking-services/flow-log-stats.png" alt-text="Screenshot of flow log stats and a service dependency graph." lightbox="./media/advanced-container-networking-services/flow-log-stats.png":::

- *Flow logs and error logs for quick analysis.*

  You can filter flow logs for root-cause analysis. For example, for Domain Name Service (DNS) issues, filter error logs by the DNS protocol.

  :::image type="content" source="./media/advanced-container-networking-services/flow-log-snapshot.png" alt-text="Screenshot of flow logs and error logs." lightbox="./media/advanced-container-networking-services/flow-log-snapshot.png":::

  Separating sections of flow logs and error logs helps you more quickly analyze issues. You can quickly identify and address errors without sifting through unrelated information to improve efficiency in troubleshooting and debugging processes.

  Use clear labels and timestamps for each log entry to more easily pinpoint specific events or errors in the system or processes.

  :::image type="content" source="./media/advanced-container-networking-services/flow-log-filters.png" alt-text="Screenshot of filters available." lightbox="./media/advanced-container-networking-services/flow-log-filters.png":::

- *Top namespaces, workloads, and DNS errors.*

  Network flow log visualization is vital for monitoring and analyzing communication in a Kubernetes cluster. It gives you insight into namespaces, workloads, and port and query usage, and it helps you identify trends, detect bottlenecks, and diagnose issues. Spot significant network activity, view drop requests, and assess protocol distribution (for example, TCP versus UDP). This overview section of the dashboard supports cluster health, resource optimization, and security by detecting and displaying unusual traffic patterns.

  :::image type="content" source="./media/advanced-container-networking-services/top-namespaces.png" alt-text="Screenshot of top namespaces and pod metrics." lightbox="./media/advanced-container-networking-services/top-namespaces.png":::

## On-demand

Advanced Container Networking Services offers on-demand capture of network flow logs. Use the Hubble CLI and Hubble UI for real-time visibility without prior configuration or persistent storage. On-demand mode for for logs is in general availibility(GA).

### Hubble CLI

The command-line interface provides a flexible and interactive way to query, filter, and analyze flow logs directly from the terminal. Users can execute real-time commands to inspect traffic flows, view packet metadata, and troubleshoot network issues without leaving their operational environment.

:::image type="content" source="./media/advanced-container-networking-services/hubble-cli-snapshot.png" alt-text="Screenshot of Hubble CLI." lightbox="./media/advanced-container-networking-services/hubble-cli-snapshot.png":::

### Hubble UI

The web-based interface offers an intuitive and visual platform for monitoring. With features like live traffic dashboards, flow summaries, and searchable logs, users can easily track service-to-service communication, detect anomalies, and gain insights into cluster activity.

Together, these tools provide real-time visibility and actionable insights, enabling faster troubleshooting and improved network management.

:::image type="content" source="./media/advanced-container-networking-services/hubble-ui-snapshot.png" alt-text="Screenshot of Hubble UI." lightbox="./media/advanced-container-networking-services/hubble-ui-snapshot.png":::

## Key benefits

- **Faster issue resolution**: With detailed and actionable insights into network traffic, customers can identify and resolve connectivity or performance issues more quickly, minimizing downtime, and disruptions.
- **Optimized operational efficiency**: Aggregated and efficiently stored logs reduce data management overhead, allowing teams to focus on analysis and decision-making instead of managing large volumes of raw data.
- **Enhanced application reliability**: By monitoring service-to-service communication and detecting anomalies, customers can proactively address potential issues, ensuring a smoother and more reliable application experience.
- **Improved decision-making**: Visualizing network patterns in Azure Managed Grafana and applying service maps provides customers with clear insights into their application’s network behavior, aiding in better infrastructure planning and optimization.
- **Cost savings**: Efficient log aggregation and customizable logging scopes reduce storage and data ingestion costs, providing a cost-effective solution for long-term network monitoring.
- **Streamlined compliance and security**: Persistent and comprehensive logs support audit trails, regulatory compliance, and quick identification of suspicious traffic, helping customers maintain a secure and compliant environment.

## Pricing

> [!IMPORTANT]
> Advanced Container Networking Services is a paid offering.

For more information about pricing, see [Advanced Container Networking Services - Pricing](https://azure.microsoft.com/pricing/details/azure-container-networking-services/).

## Related content

- Learn how to set up [Container Network Logs](how-to-configure-container-network-logs.md).
- Get more information about [Advanced Container Networking Services for AKS](./advanced-container-networking-services-overview.md).
- Explore [Container Network Observability features](./advanced-container-networking-services-overview.md#container-network-observability).
- Explore [Container Network Security features](./advanced-container-networking-services-overview.md#container-network-security).
