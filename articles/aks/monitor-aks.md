---
title: Monitor Azure Kubernetes Service (AKS)
description: Learn how to monitor Azure Kubernetes Service (AKS) clusters using built-in monitoring capabilities and integrating with other Azure services for detailed insights into health and performance.
ms.date: 09/06/2024
ms.custom: horz-monitor, copilot-scenario-highlight
ms.topic: overview
ms.service: azure-kubernetes-service
author: xuhongl
ms.author: xuhliu
ms.subservice: aks-monitoring
#Customer intent: As a cloud administrator, I want to implement comprehensive monitoring for Azure Kubernetes Service (AKS) so that I can ensure performance and reliability in my critical applications and manage resource utilization effectively.
---

# Monitor Azure Kubernetes Service (AKS)

AKS monitoring requires multiple levels of observability across platform metrics, Prometheus metrics, activity logs, resource logs, and container insights. AKS provides built-in monitoring capabilities and integrates with Azure Monitor, Container insights, managed service for Prometheus, and Azure Managed Grafana for comprehensive cluster health and performance monitoring.

> [!TIP]
> You can use Azure Copilot to configure monitoring on your AKS clusters in the Azure portal. For more information, see [Work with AKS clusters efficiently using Azure Copilot](/azure/copilot/work-aks-clusters#configure-monitoring-on-clusters).

[!INCLUDE [horz-monitor-insights](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-insights.md)]

## AKS monitoring data: metrics, logs, integrations

AKS generates the same kinds of monitoring data as other Azure resources as described in [Monitor data from Azure resources](/azure/azure-monitor/essentials/monitor-azure-resource#monitoring-data-from-azure-resources). For detailed information on the metrics and logs created by AKS, see the [AKS monitoring data reference](monitor-aks-reference.md).

[Other Azure services and features](#integrations) collect other data and enable other analysis options as shown in the following diagram and table.

:::image type="content" source="media/monitor-aks/aks-monitor-data-v2.png" alt-text="Diagram of monitoring data that is collected from AKS." lightbox="media/monitor-aks/aks-monitor-data-v2.png" border="false":::

| Source | Description |
|:---|:---|
| Platform metrics | [Platform metrics](monitor-aks-reference.md#metrics) are automatically collected for AKS clusters at no cost. You can analyze these metrics using the [metrics explorer](/azure/azure-monitor/essentials/analyze-metrics) or use them to create [metric alerts](/azure/azure-monitor/alerts/alerts-types#metric-alerts).  |
| Prometheus metrics | When you [enable metric scraping](/azure/azure-monitor/containers/kubernetes-monitoring-enable#enable-prometheus-and-grafana) for your cluster, the [managed service for Prometheus](/azure/azure-monitor/essentials/prometheus-metrics-overview) in Azure Monitor collects [Prometheus metrics](/azure/azure-monitor/containers/prometheus-metrics-scrape-default) and stores them in an [Azure Monitor workspace](/azure/azure-monitor/essentials/azure-monitor-workspace-overview). Analyze these metrics using [prebuilt dashboards](/azure/azure-monitor/visualize/grafana-plugin#use-out-of-the-box-dashboards) in [Azure Managed Grafana](/azure/managed-grafana/overview) and with [Prometheus alerts](/azure/azure-monitor/alerts/prometheus-alerts). |
| Activity logs | The Azure Monitor [activity log](monitor-aks-reference.md) automatically collects some data for AKS clusters at no cost. These log files track information like when a cluster is created or changes are made to a cluster configuration. To analyze activity log data with your other log data, [send activity log data to a Log Analytics workspace](/azure/azure-monitor/essentials/activity-log#send-to-log-analytics-workspace). |
| Resource logs | Control plane logs for AKS are implemented as resource logs. [Create a diagnostic setting](#aks-control-plane-resource-logs) to [send the logs to a Log Analytics workspace](/azure/azure-monitor/logs/log-analytics-workspace-overview). In the workspace, you can analyze the logs using queries and set up alerts based on log information. |
| Container insights | Container insights collects various logs and performance data from a cluster and stores them in a [Log Analytics workspace](/azure/azure-monitor/logs/log-analytics-workspace-overview) and in [Azure Monitor metrics](/azure/azure-monitor/essentials/data-platform-metrics). Analyze data like `stdout` and `stderr` streams using views and workbooks in Container insights or [Log Analytics](/azure/azure-monitor/logs/log-analytics-overview) and the [metrics explorer](/azure/azure-monitor/essentials/analyze-metrics). |
| Application Insights | [Application Insights](/azure/azure-monitor/app/app-insights-overview), a feature of Azure Monitor, collects logs, metrics, and distributed traces. The telemetry is stored in a [Log Analytics workspace](/azure/azure-monitor/logs/log-analytics-overview) for analysis in the Azure portal. To enable Application Insights with code changes, see [Enable Azure Monitor OpenTelemetry](/azure/azure-monitor/app/opentelemetry-overview). To enable Application Insights without code changes, see [AKS autoinstrumentation](/azure/azure-monitor/app/kubernetes-codeless). For more information on instrumentation, learn about [data collection basics](/azure/azure-monitor/app/opentelemetry-overview). |

[!INCLUDE [horz-monitor-resource-types](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-resource-types.md)]

For more information about resource types in AKS, see the [AKS monitoring data reference](monitor-aks-reference.md).

[!INCLUDE [horz-monitor-data-storage](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-data-storage.md)]

[!INCLUDE [horz-monitor-platform-metrics](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-platform-metrics.md)]

For a list of metrics you can collect for AKS, see the [AKS monitoring data reference](monitor-aks-reference.md#metrics).

Metrics play an important role in monitoring clusters, identifying issues, and optimizing performance in AKS clusters. Platform metrics are captured using the out-of-the-box metrics server installed in the `kube-system` namespace, which periodically scrapes metrics from all AKS nodes served by kubelet. You should also enable managed service for Prometheus metrics to collect container metrics and Kubernetes object metrics, including object deployment state.

You can view the [list of default managed service for Prometheus metrics](/azure/azure-monitor/containers/prometheus-metrics-scrape-default).

For more information, see [Collect managed service for Prometheus metrics from an AKS cluster](/azure/azure-monitor/containers/kubernetes-monitoring-enable#enable-prometheus-and-grafana). 

<a name="integrations"></a>

[!INCLUDE [horz-monitor-custom-metrics](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-non-monitor-metrics.md)]

You can use the following Azure services and Azure Monitor features to monitor your AKS clusters. You enable these features when you create an AKS cluster.

In the Azure portal, use the **Integrations** tab, or use the Azure CLI, Terraform, or Azure Policy. In some cases, you can onboard your cluster to a monitoring service or feature after you create the cluster. Each service or feature might incur cost, so see the pricing information for each component before you enable it.

| Service or feature | Description |
|:---|:---|
| [Container insights](/azure/azure-monitor/containers/container-insights-overview) | Uses a containerized version of the [Azure Monitor Agent](/azure/azure-monitor/agents/agents-overview) to collect `stdout` and `stderr` logs and Kubernetes events from each node in your cluster. The feature supports a [variety of monitoring scenarios for AKS clusters](/azure/azure-monitor/containers/container-insights-overview). You can enable monitoring for an AKS cluster when it's created using the [Azure CLI](../aks/learn/quick-kubernetes-deploy-cli.md), [Azure Policy](/azure/azure-monitor/containers/container-insights-enable-aks-policy), the Azure portal, or Terraform. If you don't enable Container insights when you create your cluster, see [Enable Container insights for AKS cluster](/azure/azure-monitor/containers/container-insights-enable-aks) for other options to enable it.<br><br>Container insights stores most of its data in a [Log Analytics workspace](/azure/azure-monitor/logs/log-analytics-workspace-overview). You typically use the same Log Analytics workspace as the [resource logs](monitor-aks-reference.md#resource-logs) for your cluster. For guidance on how many workspaces you should use and where to locate them, see [Design a Log Analytics workspace architecture](/azure/azure-monitor/logs/workspace-design). |
| [Managed service for Prometheus in Azure Monitor](/azure/azure-monitor/essentials/prometheus-metrics-overview) | [Prometheus](https://prometheus.io/) is a cloud-native metrics solution from the Cloud Native Computing Foundation. It's the most common tool to use to collect and analyze metric data from Kubernetes clusters. The managed service for Prometheus in Azure Monitor is a fully managed Prometheus-compatible monitoring solution. If you don't enable the managed service for Prometheus when you create your cluster, see [Collect Prometheus metrics from an AKS cluster](/azure/azure-monitor/containers/kubernetes-monitoring-enable#enable-prometheus-and-grafana) for other options to enable it.<br><br>The managed service for Prometheus in Azure Monitor stores its data in an [Azure Monitor workspace](/azure/azure-monitor/essentials/azure-monitor-workspace-overview) that is [linked to a Grafana workspace](/azure/azure-monitor/essentials/azure-monitor-workspace-manage#link-a-grafana-workspace). You can use Azure Managed Grafana to analyze the data. |
| [Azure Managed Grafana](/azure/managed-grafana/overview) | A fully managed implementation of [Grafana](https://grafana.com/). Grafana is an open-source data visualization platform commonly used to present Prometheus data. Multiple predefined Grafana dashboards are available for monitoring Kubernetes and full-stack troubleshooting. If you don't enable Azure Managed Grafana when you create your cluster, see [Link a Grafana workspace](/azure/azure-monitor/essentials/azure-monitor-workspace-manage#link-a-grafana-workspace). You can link it to your Azure Monitor workspace so that it can access Prometheus metrics from your cluster. |

### AKS control plane metrics monitoring (preview)

> **Prerequisites and scope**: This preview feature is available for AKS clusters running Kubernetes 1.27 or later and requires the managed service for Prometheus to be enabled on your cluster. The feature currently supports Linux and Windows node pools but is not compatible with Virtual Machine Availability Sets (VMAS).

AKS also exposes metrics from critical control plane components like the API server, etcd, and the scheduler through the managed service for Prometheus in Azure Monitor. Currently, this feature is in preview. For more information, see [Monitor AKS control plane metrics](./control-plane-metrics-monitor.md). A subset of control plane metrics for the API server and etcd are available free through [Azure Monitor platform metrics](monitor-aks-reference.md#metrics). These metrics are collected by default. You can use the metrics to create alerts.

[!INCLUDE [horz-monitor-resource-logs](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-resource-logs.md)]

For the available resource log categories, their associated Log Analytics tables, and log schemas for AKS, see the [AKS monitoring data reference](monitor-aks-reference.md#resource-logs).

### AKS control plane resource logs

> **Prerequisites**: Requires a Log Analytics workspace in the same subscription as your AKS cluster. Resource logs incur ingestion and retention costs in the destination workspace. For cost optimization, use resource-specific mode and configure Basic logs tier for audit tables.

Control plane logs for AKS clusters are implemented as [resource logs](/azure/azure-monitor/essentials/resource-logs) in Azure Monitor. Resource logs aren't collected and stored until you create a diagnostic setting to route them to at least one location. You typically send resource logs to a Log Analytics workspace, where most data for Container insights is stored.

To learn how to create a diagnostic setting using the Azure portal, the Azure CLI, or Azure PowerShell, see [Create diagnostic settings](/azure/azure-monitor/essentials/diagnostic-settings). When you create a diagnostic setting, you specify which categories of logs to collect. The categories for AKS are listed in the [AKS monitoring data reference](monitor-aks-reference.md#resource-logs).

> [!WARNING]
> You can incur substantial cost when you collect resource logs for AKS, particularly for _kube-audit_ logs. Consider the following recommendations to reduce the amount of data collected:
>
> - Disable `kube-audit` logging when not required.
> - Enable collection from `kube-audit-admin`, which excludes the `get` and `list` audit events.
> - Enable resource-specific logs as described in this article, and configure the **AKSAudit** table as [Basic logs](/azure/azure-monitor/logs/logs-table-plans).
>
> For more monitoring recommendations, see [Monitor AKS clusters using Azure services and cloud-native tools](/azure/azure-monitor/containers/monitor-kubernetes). For strategies to reduce your monitoring costs, see [Cost optimization and Azure Monitor](/azure/azure-monitor/best-practices-cost).

AKS supports either [Azure diagnostics mode](/azure/azure-monitor/essentials/resource-logs#azure-diagnostics-mode) or [resource-specific mode](/azure/azure-monitor/essentials/resource-logs#resource-specific) for resource logs. Azure diagnostics mode sends all data to the [AzureDiagnostics table](/azure/azure-monitor/reference/tables/azurediagnostics). Resource-specific mode specifies the tables in the Log Analytics workspace where the data is sent. It also sends data to [`AKSAudit`](/azure/azure-monitor/reference/tables/aksaudit), [`AKSAuditAdmin`](/azure/azure-monitor/reference/tables/aksauditadmin), and [`AKSControlPlane`](/azure/azure-monitor/reference/tables/akscontrolplane) as shown in the table in [Resource logs](monitor-aks-reference.md#resource-logs).

We recommend that you use resource-specific mode for AKS for the following reasons:

- Data is easier to query because it's in individual tables that are dedicated to AKS.
- Resource-specific mode supports configuration as [Basic logs](/azure/azure-monitor/logs/logs-table-plans) for significant cost savings.

For more information on the difference between collection modes, including how to change an existing setting, see [Select the collection mode](/azure/azure-monitor/essentials/resource-logs#select-the-collection-mode).

> [!NOTE]
> You can configure diagnostic settings using the Azure CLI. This approach isn't guaranteed to be successful because it doesn't check for the cluster's provisioning state. After you change diagnostic settings, check to be sure that the cluster reflects the setting changes.
>
> ```azurecli-interactive
> az monitor diagnostic-settings create --name AKS-Diagnostics --resource /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myresourcegroup/providers/Microsoft.ContainerService/managedClusters/my-cluster --logs '[{"category": "kube-audit","enabled": true}, {"category": "kube-audit-admin", "enabled": true}, {"category": "kube-apiserver", "enabled": true}, {"category": "kube-controller-manager", "enabled": true}, {"category": "kube-scheduler", "enabled": true}, {"category": "cluster-autoscaler", "enabled": true}, {"category": "cloud-controller-manager", "enabled": true}, {"category": "guard", "enabled": true}, {"category": "csi-azuredisk-controller", "enabled": true}, {"category": "csi-azurefile-controller", "enabled": true}, {"category": "csi-snapshot-controller", "enabled": true}]'  --workspace /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/myresourcegroup/providers/microsoft.operationalinsights/workspaces/myworkspace --export-to-resource-specific true
> ```

#### AKS resource log queries and examples

> **Query scope requirements**: When you select **Logs** on an AKS cluster menu, Log Analytics opens with the query scope set to the current cluster. Log queries include data only from that resource. To run queries that include data from other clusters or Azure services, select **Logs** from the **Azure Monitor** menu.

If the [diagnostic settings for your cluster](monitor-aks-reference.md#resource-logs) use Azure diagnostics mode, the resource logs for AKS are stored in the [AzureDiagnostics](/azure/azure-monitor/reference/tables/azurediagnostics) table. Identify logs via the **Category** column. For a description of each category, see [AKS reference resource logs](monitor-aks-reference.md).

| Description | Mode | Log query |
|:---|:---|:---|
| Count logs for each category | Azure diagnostics mode | `AzureDiagnostics`<br>\| `where ResourceType == "MANAGEDCLUSTERS"`<br>\| `summarize count() by Category` |
| All API server logs | Azure diagnostics mode | `AzureDiagnostics`<br>\| `where Category == "kube-apiserver"` |
| All kube-audit logs in a time range | Azure diagnostics mode | `let starttime = datetime("2023-02-23");`<br>`let endtime = datetime("2023-02-24");`<br>`AzureDiagnostics`<br>\| `where TimeGenerated between(starttime..endtime)`<br>\| `where Category == "kube-audit"`<br>\| `extend event = parse_json(log_s)`<br>\| `extend HttpMethod = tostring(event.verb)`<br>\| `extend User = tostring(event.user.username)`<br>\| `extend Apiserver = pod_s`<br>\| `extend SourceIP = tostring(event.sourceIPs[0])`<br>\| `project TimeGenerated, Category, HttpMethod, User, Apiserver, SourceIP, OperationName, event` |
| All audit logs | Resource-specific mode | `AKSAudit` |
| All audit logs excluding the `get` and `list` audit events | Resource-specific mode | `AKSAuditAdmin` |
| All API server logs | Resource-specific mode | `AKSControlPlane`<br>\| `where Category == "kube-apiserver"` |

To access a set of prebuilt queries in the Log Analytics workspace, see the [Log Analytics queries interface](/azure/azure-monitor/logs/queries#queries-interface), and select the **Kubernetes Services** resource type. For a list of common queries for Container insights, see [Container insights queries](/azure/azure-monitor/containers/container-insights-log-query).

### AKS data plane Container insights logs

> **Prerequisites and configuration requirements**: Container insights requires a Log Analytics workspace for log storage and supports both managed identity and legacy authentication methods. For new clusters, managed identity authentication is recommended. Data collection can be customized using Azure Monitor Data Collection Rules (DCRs) to control costs and reduce ingestion volume.

Container insights collects various types of telemetry data from containers and AKS clusters to help you monitor, troubleshoot, and gain insights into your containerized applications running in your AKS clusters. For a list of tables and their detailed descriptions used by Container insights, see the [Azure Monitor table reference](/azure/azure-monitor/logs/manage-logs-tables). All the tables are available for [log queries](/azure/azure-monitor/logs/log-query-overview).

Use [cost optimization settings](/azure/azure-monitor/containers/container-insights-cost-config) to customize and control the metrics data collected through the Container insights agent. This feature supports the data collection settings for individual table selection, data collection intervals, and namespaces to exclude the data collection through [Azure Monitor Data Collection Rules (DCRs)](/azure/azure-monitor/essentials/data-collection-rule-overview). These settings control the volume of ingestion and reduce the monitoring costs of Container insights. You can customize Container insights collected data in the Azure portal using the following options. Selecting any options other than **All (Default)** makes the Container insights experience unavailable.

| Grouping | Tables | Notes |
| --- | --- | --- |
| All (Default) | All standard Container insights tables | Required to enable the default Container insights visualizations. |
| Performance | Perf, InsightsMetrics | N/A |
| Logs and events | ContainerLog or ContainerLogV2, KubeEvents, KubePodInventory | Recommended if you enabled managed service for Prometheus metrics. |
| Workloads, Deployments, and HPAs | InsightsMetrics, KubePodInventory, KubeEvents, ContainerInventory, ContainerNodeInventory, KubeNodeInventory, KubeServices | N/A |
| Persistent Volumes | InsightsMetrics, KubePVInventory | N/A |

The **Logs and events** grouping captures the logs from the **ContainerLog** or **ContainerLogV2**, **KubeEvents**, and **KubePodInventory** tables, but not the metrics. The recommended path to collect metrics is to enable the [managed service for Prometheus](/azure/azure-monitor/essentials/prometheus-metrics-overview) from your AKS cluster and use [Azure Managed Grafana](/azure/managed-grafana/overview) for data visualization. For more information, see [Manage an Azure Monitor workspace](/azure/azure-monitor/essentials/azure-monitor-workspace-manage).

#### ContainerLogV2 schema

> **Compatibility and configuration requirements**: ContainerLogV2 schema is recommended for new Container insights deployments using managed identity authentication via Azure Resource Manager (ARM) templates, Bicep, Terraform, Azure Policy, or the Azure portal. The schema is compatible with Basic logs tier for cost savings and doesn't affect analytics or alerts functionality. For more information about how to enable ContainerLogV2 through either the cluster's DCR or configmap, see [Enable the ContainerLogV2 schema](/azure/azure-monitor/containers/container-insights-logs-schema?tabs=configure-portal#enable-the-containerlogv2-schema).

Container insights in Azure Monitor provides a recommended schema for container logs, _ContainerLogV2_. The format includes the following fields for common queries to view data related to AKS and Azure Arc-enabled Kubernetes clusters:

- **ContainerName**
- **PodName**
- **PodNamespace**

[!INCLUDE [horz-monitor-activity-log](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-activity-log.md)]

## View AKS container logs, events, and pod metrics in real time

> **Prerequisites and setup requirements**: Live data feature requires Container insights to be enabled on your cluster and uses direct Kubernetes API access. For private clusters, access requires a computer in the same private network as the cluster. Authentication follows the Kubernetes RBAC model and requires appropriate cluster permissions.

You can view AKS container logs, events, and pod metrics using the _live data_ feature in Container insights and troubleshoot issues in real time with direct access to `kubectl logs -c`, `kubectl get` events, and `kubectl top pods`.

> [!NOTE]
> AKS uses [Kubernetes cluster-level logging architectures](https://kubernetes.io/docs/concepts/cluster-administration/logging/#cluster-level-logging-architectures). The container logs are located at `/var/log/containers` on the node. To access a node, see [Connect to AKS cluster nodes](./node-access.md).

To learn how to set up this feature, see [Configure live data in Container insights](/azure/azure-monitor/containers/container-insights-livedata-setup). The feature directly accesses the Kubernetes API. For more information about the authentication model, see the [Kubernetes API](https://kubernetes.io/docs/concepts/overview/kubernetes-api/).

### View AKS resource live logs

> **Private cluster network requirements**: To access logs from a private cluster, you must use a computer that's in the same private network as the cluster.

1. In the [Azure portal](https://portal.azure.com/), go to your AKS cluster.
1. Under **Kubernetes resources**, select **Workloads**.
1. For **Deployment**, **Pod**, **Replica Set**, **Stateful Set**, **Job**, or **Cron Job**, select a value, and then select **Live Logs**.
1. Select a resource log to view.

    The following example shows the logs for a pod resource:

    :::image type="content" source="./media/container-insights-live-data/live-data-deployment.png" alt-text="Screenshot that shows the deployment of live logs." lightbox="./media/container-insights-live-data/live-data-deployment.png":::

### View container live logs using Container insights

> **Authentication and data streaming**: After successful authentication, if data can be retrieved, it begins streaming to the **Live Logs** tab. Log data appears in a continuous stream. Alternative log access is available through **View Logs in Log Analytics** for historical analysis.

You can view real-time log data as the container engine generates it on the **Cluster**, **Nodes**, **Controllers**, or **Containers** tab.

1. In the [Azure portal](https://portal.azure.com/), go to your AKS cluster.
1. Under **Monitoring**, select **Insights**.
1. On the **Cluster**, **Nodes**, **Controllers**, or **Containers** tab, select a value.
1. On the **Overview** pane for the resource, select **Live Logs**.

    The following image shows the logs for a container resource:

    :::image type="content" source="./media/container-insights-live-data/container-live-logs.png" alt-text="Screenshot that shows the container Live Logs option to view data." lightbox="./media/container-insights-live-data/container-live-logs.png":::

### View container live events using Container insights

> **Event streaming and access**: Real-time event data streams as the container engine generates it. Events include pod creation, deletion, scaling operations, and error conditions. Historical event data is accessible via **View Events in Log Analytics**.

You can view real-time event data as the container engine generates it on the **Cluster**, **Nodes**, **Controllers**, or **Containers** tab.

1. In the [Azure portal](https://portal.azure.com/), go to your AKS cluster.
1. Under **Monitoring**, select **Insights**.
1. Select the **Cluster**, **Nodes**, **Controllers**, or **Containers** tab, and then select an object.
1. On the resource **Overview** pane, select **Live Events**.

    After successful authentication, if data can be retrieved, it begins streaming to the **Live Events** tab. The following image shows the events for a container resource:

    :::image type="content" source="./media/container-insights-live-data/container-live-events.png" alt-text="Screenshot that shows the container Live Events option to view data." lightbox="./media/container-insights-live-data/container-live-events.png":::

### View pod live metrics using Container insights

> **Metrics scope and availability**: Live metrics are available for pod resources on the **Nodes** or **Controllers** tabs. Metrics include CPU usage, memory consumption, network I/O, and filesystem statistics. Historical metrics are accessible through **View Events in Log Analytics**.

You can view real-time metrics data as the container engine generates it on the **Nodes** or **Controllers** tab by selecting a pod resource.

1. In the [Azure portal](https://portal.azure.com/), go to your AKS cluster.
1. Under **Monitoring**, select **Insights**.
1. Select the **Nodes** or **Controllers** tab, and then select a pod object.
1. On the resource **Overview** pane, select **Live Metrics**.

    After successful authentication, if data can be retrieved, it begins streaming to the **Live Metrics** tab. The following image shows the metrics for a pod resource:

    :::image type="content" source="./media/container-insights-live-data/pod-live-metrics.png" alt-text="Screenshot that shows the pod Live Metrics option to view data." lightbox="./media/container-insights-live-data/pod-live-metrics.png":::

    [!INCLUDE [horz-monitor-analyze-data](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-analyze-data.md)]

    [!INCLUDE [horz-monitor-external-tools](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-external-tools.md)]

### Monitor AKS clusters in the Azure portal

The **Monitoring** tab on the **Overview** pane for your AKS cluster resource offers a quick way to start viewing monitoring data in the Azure portal. This tab includes graphs with common metrics for the cluster separated by node pool. You can select any of these graphs to further analyze the data in the [metrics explorer](/azure/azure-monitor/essentials/metrics-getting-started).

The **Monitoring** tab also includes links to the [Azure managed service for Prometheus](#integrations) and [Container insights](#integrations) for the cluster. You can enable these tools on the **Monitoring** tab. You might also see a banner at the top of the pane that recommends other features to improve monitoring for your cluster.

> [!TIP]
> To access monitoring features for all AKS clusters in your subscription, on the Azure portal home page, select **Azure Monitor**.

[!INCLUDE [horz-monitor-kusto-queries](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-kusto-queries.md)]

[!INCLUDE [horz-monitor-alerts](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-alerts.md)]

[!INCLUDE [horz-monitor-insights-alerts](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-recommended-alert-rules.md)]

### Configure Prometheus metrics-based alerts

> **Download and configuration requirements**: Alert rules are available as downloadable ARM templates or Bicep files. Before configuring alerts, ensure the managed service for Prometheus is enabled on your cluster and an Azure Monitor workspace is properly linked to your AKS cluster.

When you [enable collection of the managed service for Prometheus metrics](#integrations) for your cluster, you can download a collection of [recommended managed service for Prometheus alert rules](/azure/azure-monitor/containers/container-insights-metric-alerts#enable-prometheus-alert-rules).

The download includes the following rules:

| Level | Alerts |
|:---|:---|
| Cluster level | `KubeCPUQuotaOvercommit`<br>`KubeMemoryQuotaOvercommit`<br>`KubeContainerOOMKilledCount`<br>`KubeClientErrors`<br>`KubePersistentVolumeFillingUp`<br>`KubePersistentVolumeInodesFillingUp`<br>`KubePersistentVolumeErrors`<br>`KubeContainerWaiting`<br>`KubeDaemonSetNotScheduled`<br>`KubeDaemonSetMisScheduled`<br>`KubeQuotaAlmostFull` |
| Node level | `KubeNodeUnreachable`<br>`KubeNodeReadinessFlapping` |
| Pod level | `KubePVUsageHigh`<br>`KubeDeploymentReplicasMismatch`<br>`KubeStatefulSetReplicasMismatch`<br>`KubeHpaReplicasMismatch`<br>`KubeHpaMaxedOut`<br>`KubePodCrashLooping`<br>`KubeJobStale`<br>`KubePodContainerRestart`<br>`KubePodReadyStateLow`<br>`KubePodFailedState`<br>`KubePodNotReadyByController`<br>`KubeStatefulSetGenerationMismatch`<br>`KubeJobFailed`<br>`KubeContainerAverageCPUHigh`<br>`KubeContainerAverageMemoryHigh`<br>`KubeletPodStartUpLatencyHigh` |

For more information, see [Create log alerts from Container insights](/azure/azure-monitor/containers/container-insights-log-alerts) and [Query logs from Container insights](/azure/azure-monitor/containers/container-insights-log-query).

[Log alerts](/azure/azure-monitor/alerts/alerts-unified-log) can measure two types of information to help you monitor diverse scenarios:

- [Result count](/azure/azure-monitor/alerts/alerts-unified-log#result-count): Counts the number of rows returned by the query. Use this information to work with events like Windows event logs, syslog events, and application exceptions.
- [Calculation of a value](/azure/azure-monitor/alerts/alerts-unified-log#calculation-of-a-value): Makes a calculation based on a numeric column. Use this information to include diverse resources. An example is CPU percentage.

Most log queries compare a `DateTime` value to the present time using the `now` operator and going back one hour. To learn how to build log-based alerts, see [Create log alerts from Container insights](/azure/azure-monitor/containers/container-insights-log-alerts).

### AKS alert rules

The following table lists some suggested alert rules for AKS. These alerts are only examples. You can set alerts for any metric, log entry, or activity log entry listed in the [AKS monitoring data reference](monitor-aks-reference.md).

| Condition | Description  |
|:---|:---|
| **CPU Usage Percentage** > **95** | Alerts when the average CPU usage across all nodes exceeds the threshold. |
| **Memory Working Set Percentage** > **100** | Alerts when the average working set across all nodes exceeds the threshold. |

[!INCLUDE [horz-monitor-advisor-recommendations](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-advisor-recommendations.md)]

[!INCLUDE [horz-monitor-insights-alerts](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-insights-alerts.md)]

## AKS node network metrics monitoring

> **Version and enablement requirements**: In Kubernetes version 1.29 and later, node network metrics are enabled by default for all clusters that have Azure Monitor enabled. For earlier Kubernetes versions, you must manually enable network monitoring through cluster configuration. This feature requires Azure Monitor or Container insights to be configured on your cluster.

Node network metrics are crucial for maintaining a healthy and performant Kubernetes cluster. By collecting and analyzing data about network traffic, you can gain valuable insights about your cluster's operation and identify potential issues before they lead to outages or performance loss.

The following node network metrics are enabled by default and are aggregated per node. All metrics include the labels cluster and instance (node name). You can easily view these metrics using the Managed Grafana dashboard under **Azure Managed Prometheus** > **Kubernetes** > **Networking** > **Clusters**.

### AKS node network metrics by data plane type

All metrics include these labels:

- `cluster`
- `instance` (node name)

#### [Cilium](#tab/cilium)

> **OS support and limitations**: For Cilium data plane scenarios, the Container Network Observability feature provides metrics only for Linux node pools. Currently, Windows isn't supported for Container Network Observability metrics. Ensure your cluster has Linux node pools for full Cilium metrics availability.

For Cilium data plane scenarios, the Container Network Observability feature provides metrics only for Linux. Currently, Windows isn't supported for Container Network Observability metrics.

Cilium exposes several metrics that Container Network Observability uses:

| Metric name                    | Description                  | Extra labels          |Linux | Windows |
|--------------------------------|------------------------------|-----------------------|-------|---------|
| `cilium_forward_count_total` | Total forwarded packet count | `direction`           | Supported ✅ | Unsupported ❌ |
| `cilium_forward_bytes_total` | Total forwarded byte count   | `direction`           | Supported ✅ | Unsupported ❌ |
| `cilium_drop_count_total`    | Total dropped packet count   | `direction`, `reason` | Supported ✅ | Unsupported ❌ |
| `cilium_drop_bytes_total`    | Total dropped byte count     | `direction`, `reason` | Supported ✅ | Unsupported ❌ |

#### [Non-Cilium](#tab/non-cilium)

> **OS support and known limitations**: For non-Cilium data plane scenarios, Container Network Observability provides metrics for both Linux and Windows operating systems. However, due to an identified bug, TCP resets temporarily aren't visible, so the `networkobservability_tcp_flag_counters` metrics aren't published for Linux nodes. We're actively working to resolve this issue.

For non-Cilium data plane scenarios, Container Network Observability provides metrics for both Linux and Windows operating systems.

The following table outlines the generated metrics:

| Metric name                                    | Description | Extra labels | Linux | Windows |
|------------------------------------------------|-------------|--------------|-------|---------|
| `networkobservability_forward_count`         | Total forwarded packet count | `direction` | Supported ✅ | Supported ✅ |
| `networkobservability_forward_bytes`         | Total forwarded byte count | `direction` | Supported ✅ | Supported ✅ |
| `networkobservability_drop_count`            | Total dropped packet count | `direction`, `reason` | Supported ✅ | Supported ✅ |
| `networkobservability_drop_bytes`            | Total dropped byte count | `direction`, `reason` | Supported ✅ | Supported ✅ |
| `networkobservability_tcp_state`             | TCP currently active socket count by TCP state | `state` | Supported ✅ | Supported ✅ |
| `networkobservability_tcp_connection_remote` | TCP currently active socket count by remote IP/port | `address` (IP), `port` | Supported ✅ | Unsupported ❌ |
| `networkobservability_tcp_connection_stats`  | TCP connection statistics (example: Delayed ACKs, TCPKeepAlive, TCPSackFailures) | `statistic` | Supported ✅ | Supported ✅ |
| `networkobservability_tcp_flag_counters`     | TCP packets count by flag | `flag` | Unsupported ❌ | Supported ✅ |
| `networkobservability_ip_connection_stats`   | IP connection statistics | `statistic` | Supported ✅ | Unsupported ❌ |
| `networkobservability_udp_connection_stats`  | UDP connection statistics | `statistic` | Supported ✅ | Unsupported ❌ |
| `networkobservability_udp_active_sockets`    | UDP currently active socket count | N/A | Supported ✅ | Unsupported ❌ |
| `networkobservability_interface_stats`       | Interface statistics | InterfaceName, `statistic` | Supported ✅ | Supported ✅ |

---

### Disable AKS node network metrics collection

You can disable network metrics collection on specific nodes by adding the label `networking.azure.com/node-network-metrics=disabled` to those nodes.

> [!NOTE]
> Retina has an `operator: "Exists"` `effect: NoSchedule` toleration, so it bypasses `NoSchedule` taints. Therefore, labels are used instead of taints to control scheduling.
>
> If the cluster is `autoprovisioning/autoscaling` nodes, you need to manually enable the flag on each node.

> [!IMPORTANT]
> This feature isn't applicable if Advanced Container Networking Services (ACNS) is enabled on your cluster.

To disable metrics collection on a node:

```bash
kubectl label node <node-name> networking.azure.com/node-network-metrics=disabled
```

For detailed pod-level and DNS metrics, see [Advanced Container Networking Services](advanced-container-networking-services-overview.md).

## Related content

- For a reference of the metrics, logs, and other important values created for AKS, see the [AKS monitoring data reference](monitor-aks-reference.md).
- For general details on monitoring Azure resources, see [Monitor Azure resources using Azure Monitor](/azure/azure-monitor/essentials/monitor-azure-resource).
- For detailed monitoring of the complete Kubernetes stack, see [Monitor Kubernetes clusters using Azure services and cloud native tools](/azure/azure-monitor/containers/monitor-kubernetes).
- For collecting metrics data from Kubernetes clusters, see [Managed service for Prometheus in Azure Monitor](/azure/azure-monitor/essentials/prometheus-metrics-overview).
- For collecting logs in Kubernetes clusters, see [Azure Monitor features for Kubernetes monitoring](/azure/azure-monitor/containers/container-insights-overview).
- For data visualization, see [Azure Workbooks](/azure/azure-monitor/visualize/workbooks-overview) and [Monitor your Azure services in Grafana](/azure/azure-monitor/visualize/grafana-plugin).
