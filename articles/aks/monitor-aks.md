---
title: Monitor Azure Kubernetes Service (AKS)
description: Start here to learn how to monitor Azure Kubernetes Service (AKS) as it supports your critical applications and business processes. 
ms.date: 09/06/2024
ms.custom: horz-monitor
ms.topic: conceptual
author: xuhongl
ms.author: xuhliu
ms.subservice: aks-monitoring
---

# Monitor Azure Kubernetes Service (AKS)

[!INCLUDE [horz-monitor-intro](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-intro.md)]

> [!IMPORTANT]
> Kubernetes is a complex distributed system with many moving parts. Monitoring at multiple levels is required. Although AKS is a managed Kubernetes service, the same rigor around monitoring at multiple levels is still required. This article provides high level information and best practices for monitoring an AKS cluster.

- For detailed monitoring of the complete Kubernetes stack, see [Monitor Kubernetes clusters using Azure services and cloud native tools](/azure/azure-monitor/containers/monitor-kubernetes).
- For collecting metric data from Kubernetes clusters, see [Azure Monitor managed service for Prometheus](/azure/azure-monitor/essentials/prometheus-metrics-overview).
- For collecting logs in Kubernetes clusters, see [Azure Monitor features for Kubernetes monitoring](/azure/azure-monitor/containers/container-insights-overview).
- For data visualization, see [Azure Workbooks](/azure/azure-monitor/visualize/workbooks-overview) and [Monitor your Azure services in Grafana](/azure/azure-monitor/visualize/grafana-plugin).

[!INCLUDE [horz-monitor-insights](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-insights.md)]

Azure Monitor Container insights collect custom metrics for nodes, pods, containers, and persistent volumes. For more information, see [Metrics collected by Container insights](/azure/azure-monitor/containers/container-insights-custom-metrics).

[Azure Monitor Application Insights](/azure/azure-monitor/app/app-insights-overview) is used for application performance monitoring (APM). To enable Application Insights with code changes, see [Enable Azure Monitor OpenTelemetry](/azure/azure-monitor/app/opentelemetry-overview). To enable Application Insights without code changes, see [AKS autoinstrumentation](/azure/azure-monitor/app/kubernetes-codeless). For more details on instrumentation, see [data collection basics](/azure/azure-monitor/app/opentelemetry-overview).

## Monitoring data

AKS generates the same kinds of monitoring data as other Azure resources that are described in [Monitoring data from Azure resources](/azure/azure-monitor/essentials/monitor-azure-resource#monitoring-data-from-azure-resources). See [Monitoring AKS data reference](monitor-aks-reference.md) for detailed information on the metrics and logs created by AKS. [Other Azure services and features](#integrations) collect other data and enable other analysis options as shown in the following diagram and table.

:::image type="content" source="media/monitor-aks/aks-monitor-data-v2.png" alt-text="Diagram of collection of monitoring data from AKS." lightbox="media/monitor-aks/aks-monitor-data-v2.png" border="false":::

| Source | Description |
|:---|:---|
| Platform metrics | [Platform metrics](monitor-aks-reference.md#metrics) are automatically collected for AKS clusters at no cost. You can analyze these metrics with [metrics explorer](/azure/azure-monitor/essentials/analyze-metrics) or use them for [metric alerts](/azure/azure-monitor/alerts/alerts-types#metric-alerts).  |
| Prometheus metrics | When you [enable metric scraping](/azure/azure-monitor/containers/kubernetes-monitoring-enable#enable-prometheus-and-grafana) for your cluster, [Azure Monitor managed service for Prometheus](/azure/azure-monitor/essentials/prometheus-metrics-overview) collects [Prometheus metrics](/azure/azure-monitor/containers/prometheus-metrics-scrape-default) and stores them in an [Azure Monitor workspace](/azure/azure-monitor/essentials/azure-monitor-workspace-overview). Analyze them with [prebuilt dashboards](/azure/azure-monitor/visualize/grafana-plugin#use-out-of-the-box-dashboards) in [Azure Managed Grafana](/azure/managed-grafana/overview) and with [Prometheus alerts](/azure/azure-monitor/alerts/prometheus-alerts). |
| Activity logs | [Activity log](monitor-aks-reference.md) is collected automatically for  AKS clusters at no cost. These logs track information such as when a cluster is created or has a configuration change. To analyze it with your other log data, send the [Activity log to a Log Analytics workspace](/azure/azure-monitor/essentials/activity-log#send-to-log-analytics-workspace). |
| Resource logs | Control plane logs for AKS are implemented as resource logs. [Create a diagnostic setting](#aks-control-planeresource-logs) to send them to [Log Analytics workspace](/azure/azure-monitor/logs/log-analytics-workspace-overview) where you can analyze and alert on them with log queries in [Log Analytics](/azure/azure-monitor/logs/log-analytics-overview). |
| Container insights | Container insights collect various logs and performance data from a cluster including stdout/stderr streams and store them in a [Log Analytics workspace](/azure/azure-monitor/logs/log-analytics-workspace-overview) and [Azure Monitor Metrics](/azure/azure-monitor/essentials/data-platform-metrics). Analyze this data with views and workbooks included with Container insights or with [Log Analytics](/azure/azure-monitor/logs/log-analytics-overview) and [metrics explorer](/azure/azure-monitor/essentials/analyze-metrics). |
| Application insights | [Azure Monitor Application Insights](/azure/azure-monitor/app/app-insights-overview) collects logs, metrics, and distributed traces. This telemetry is stored in a [Log Analytics workspace](/azure/azure-monitor/logs/log-analytics-overview) for analysis in the Azure portal. |

[!INCLUDE [horz-monitor-resource-types](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-resource-types.md)]

For more information about the resource types for AKS, see [Azure Kubernetes Service monitoring data reference](monitor-aks-reference.md).

[!INCLUDE [horz-monitor-data-storage](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-data-storage.md)]

[!INCLUDE [horz-monitor-platform-metrics](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-platform-metrics.md)]

For a list of available metrics for AKS, see [Azure Kubernetes Service monitoring data reference](monitor-aks-reference.md#metrics).

Metrics play an important role in cluster monitoring, identifying issues, and optimizing performance in the AKS clusters. Platform metrics are captured using the out of the box metrics server installed in kube-system namespace, which periodically scrapes metrics from all Kubernetes nodes served by Kubelet. You should also enable Azure Managed Prometheus metrics to collect container metrics and Kubernetes object metrics, such as object state of Deployments. For more information, see [Collect Prometheus metrics from an AKS cluster](/azure/azure-monitor/containers/kubernetes-monitoring-enable#enable-prometheus-and-grafana).

- [List of default Prometheus metrics](/azure/azure-monitor/containers/prometheus-metrics-scrape-default)

AKS also exposes metrics from critical Control Plane components such as API server, ETCD, Scheduler through Azure Managed Prometheus. This feature is currently in preview. For more information, see [Monitor Azure Kubernetes Service (AKS) control plane metrics (preview)](./monitor-control-plane-metrics.md).

<a name="integrations"></a>
[!INCLUDE [horz-monitor-custom-metrics](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-non-monitor-metrics.md)]

The following Azure services and features of Azure Monitor can be used for extra monitoring of your Kubernetes clusters. You can enable these features during AKS cluster creation from the Integrations tab in the Azure portal, Azure CLI, Terraform, Azure Policy, or onboard your cluster to them later. Each of these features might incur cost, so refer to the pricing information for each before you enabled them.

| Service / Feature | Description |
|:---|:---|
| [Container insights](/azure/azure-monitor/containers/container-insights-overview) | Uses a containerized version of the [Azure Monitor agent](/azure/azure-monitor/agents/agents-overview) to collect stdout/stderr logs, and Kubernetes events from each node in your cluster. The feature supports a [variety of monitoring scenarios for AKS clusters](/azure/azure-monitor/containers/container-insights-overview). You can enable monitoring for an AKS cluster when it's created by using [Azure CLI](../aks/learn/quick-kubernetes-deploy-cli.md), [Azure Policy](/azure/azure-monitor/containers/container-insights-enable-aks-policy), the Azure portal, or Terraform. If you don't enable Container insights when you create your cluster, see [Enable Container insights for Azure Kubernetes Service (AKS) cluster](/azure/azure-monitor/containers/container-insights-enable-aks) for other options to enable it.<br><br>Container insights store most of its data in a [Log Analytics workspace](/azure/azure-monitor/logs/log-analytics-workspace-overview), and you typically use the same log analytics workspace as the [resource logs](monitor-aks-reference.md#resource-logs) for your cluster. See [Design a Log Analytics workspace architecture](/azure/azure-monitor/logs/workspace-design) for guidance on how many workspaces you should use and where to locate them. |
| [Azure Monitor managed service for Prometheus](/azure/azure-monitor/essentials/prometheus-metrics-overview) | [Prometheus](https://prometheus.io/) is a cloud-native metrics solution from the Cloud Native Compute Foundation. It's the most common tool used for collecting and analyzing metric data from Kubernetes clusters. Azure Monitor managed service for Prometheus is a fully managed Prometheus-compatible monitoring solution in Azure. If you don't enable managed Prometheus when you create your cluster, see [Collect Prometheus metrics from an AKS cluster](/azure/azure-monitor/containers/kubernetes-monitoring-enable#enable-prometheus-and-grafana) for other options to enable it.<br><br>Azure Monitor managed service for Prometheus stores its data in an [Azure Monitor workspace](/azure/azure-monitor/essentials/azure-monitor-workspace-overview), which is [linked to a Grafana workspace](/azure/azure-monitor/essentials/azure-monitor-workspace-manage#link-a-grafana-workspace) so that you can analyze the data with Azure Managed Grafana. |
| [Azure Managed Grafana](/azure/managed-grafana/overview) | Fully managed implementation of [Grafana](https://grafana.com/), which is an open-source data visualization platform commonly used to present Prometheus data. Multiple predefined Grafana dashboards are available for monitoring Kubernetes and full-stack troubleshooting. If you don't enable managed Grafana when you create your cluster, see [Link a Grafana workspace](/azure/azure-monitor/essentials/azure-monitor-workspace-manage#link-a-grafana-workspace). You can link it to your Azure Monitor workspace so it can access Prometheus metrics for your cluster. |

### Monitor AKS control plane metrics (preview)

AKS also exposes metrics from critical Control Plane components such as API server, ETCD, Scheduler through Azure Managed Prometheus. This feature is currently in preview. For more information, see [Monitor Azure Kubernetes Service (AKS) control plane metrics (preview)](./control-plane-metrics-monitor.md).

[!INCLUDE [horz-monitor-resource-logs](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-resource-logs.md)]

For the available resource log categories, their associated Log Analytics tables, and the log schemas for AKS, see [Azure Kubernetes Service monitoring data reference](monitor-aks-reference.md#resource-logs).

### AKS control plane/resource logs

Control plane logs for AKS clusters are implemented as [resource logs](/azure/azure-monitor/essentials/resource-logs) in Azure Monitor. Resource logs aren't collected and stored until you create a diagnostic setting to route them to one or more locations. You typically send them to a Log Analytics workspace, which is where most of the data for Container insights is stored.

See [Create diagnostic settings](/azure/azure-monitor/essentials/diagnostic-settings) for the detailed process for creating a diagnostic setting using the Azure portal, CLI, or PowerShell. When you create a diagnostic setting, you specify which categories of logs to collect. The categories for AKS are listed in [AKS monitoring data reference](monitor-aks-reference.md#resource-logs).

> [!IMPORTANT]
> There can be substantial cost when collecting resource logs for AKS, particularly for *kube-audit* logs. Consider the following recommendations to reduce the amount of data collected:
>
> - Disable kube-audit logging when not required.
> - Enable collection from *kube-audit-admin*, which excludes the get and list audit events. 
> - Enable resource-specific logs as described here and configure `AKSAudit` table as [basic logs](/azure/azure-monitor/logs/logs-table-plans).
>
> See [Monitor Kubernetes clusters using Azure services and cloud native tools](/azure/azure-monitor/containers/monitor-kubernetes) for further recommendations and [Cost optimization and Azure Monitor](/azure/azure-monitor/best-practices-cost) for further strategies to reduce your monitoring costs.

AKS supports either [Azure diagnostics mode](/azure/azure-monitor/essentials/resource-logs#azure-diagnostics-mode) or [resource-specific mode](/azure/azure-monitor/essentials/resource-logs#resource-specific) for resource logs. This mode specifies the tables in the Log Analytics workspace where the data is sent. Azure diagnostics mode sends all data to the [AzureDiagnostics table](/azure/azure-monitor/reference/tables/azurediagnostics), while resource-specific mode sends data to [AKS Audit](/azure/azure-monitor/reference/tables/aksaudit), [AKS Audit Admin](/azure/azure-monitor/reference/tables/aksauditadmin), and [AKS Control Plane](/azure/azure-monitor/reference/tables/akscontrolplane) as shown in the table at [Resource logs](monitor-aks-reference.md#resource-logs).

Resource-specific mode is recommended for AKS for the following reasons:

- Data is easier to query because it's in individual tables dedicated to AKS.
- Supports configuration as [basic logs](/azure/azure-monitor/logs/logs-table-plans) for significant cost savings.

For more information on the difference between collection modes including how to change an existing setting, see [Select the collection mode](/azure/azure-monitor/essentials/resource-logs#select-the-collection-mode).

> [!NOTE]
> It is also possible to configure Diagnostic settings through the CLI. In these cases, it is not guaranteed to work successfully as it doesn't check for the cluster's provisioning state. Please make sure to check the diagnostic settings of the cluster to reflect after configuring it.
>
> ```azurecli
> az monitor diagnostic-settings create --name AKS-Diagnostics --resource /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myresourcegroup/providers/Microsoft.ContainerService/managedClusters/my-cluster --logs '[{"category": "kube-audit","enabled": true}, {"category": "kube-audit-admin", "enabled": true}, {"category": "kube-apiserver", "enabled": true}, {"category": "kube-controller-manager", "enabled": true}, {"category": "kube-scheduler", "enabled": true}, {"category": "cluster-autoscaler", "enabled": true}, {"category": "cloud-controller-manager", "enabled": true}, {"category": "guard", "enabled": true}, {"category": "csi-azuredisk-controller", "enabled": true}, {"category": "csi-azurefile-controller", "enabled": true}, {"category": "csi-snapshot-controller", "enabled": true}]'  --workspace /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/myresourcegroup/providers/microsoft.operationalinsights/workspaces/myworkspace --export-to-resource-specific true
> ```

#### Sample log queries

> [!IMPORTANT]
> When you select **Logs** from the menu for an AKS cluster, Log Analytics is opened with the query scope set to the current cluster. This means that log queries will only include data from that resource. If you want to run a query that includes data from other clusters or data from other Azure services, select **Logs** from the **Azure Monitor** menu. See [Log query scope and time range in Azure Monitor Log Analytics](/azure/azure-monitor/logs/scope) for details.

If the [diagnostic setting for your cluster](monitor-aks-reference.md#resource-logs) uses Azure diagnostics mode, the resource logs for AKS are stored in the [AzureDiagnostics](/azure/azure-monitor/reference/tables/azurediagnostics) table. You can distinguish different logs with the **Category** column. For a description of each category, see [AKS reference resource logs](monitor-aks-reference.md).

| Description | Log query |
|:---|:---|
| Count logs for each category<br>(Azure diagnostics mode) | AzureDiagnostics<br>\| where ResourceType == "MANAGEDCLUSTERS"<br>\| summarize count() by Category |
| All API server logs<br>(Azure diagnostics mode) | AzureDiagnostics<br>\| where Category == "kube-apiserver" |
| All kube-audit logs in a time range<br>(Azure diagnostics mode) | let starttime = datetime("2023-02-23");<br>let endtime = datetime("2023-02-24");<br>AzureDiagnostics<br>\| where TimeGenerated between(starttime..endtime)<br>\| where Category == "kube-audit"<br>\| extend event = parse_json(log_s)<br>\| extend HttpMethod = tostring(event.verb)<br>\| extend User = tostring(event.user.username)<br>\| extend Apiserver = pod_s<br>\| extend SourceIP = tostring(event.sourceIPs[0])<br>\| project TimeGenerated, Category, HttpMethod, User, Apiserver, SourceIP, OperationName, event |
| All audit logs<br>(resource-specific mode) | AKSAudit |
| All audit logs excluding the get and list audit events  <br>(resource-specific mode) | AKSAuditAdmin |
| All API server logs<br>(resource-specific mode) | AKSControlPlane<br>\| where Category == "kube-apiserver" |

To access a set of prebuilt queries in the Log Analytics workspace, see the [Log Analytics queries interface](/azure/azure-monitor/logs/queries#queries-interface) and select resource type **Kubernetes Services**. For a list of common queries for Container insights, see [Container insights queries](/azure/azure-monitor/containers/container-insights-log-query).

### AKS data plane/Container Insights logs

Container Insights collect various types of telemetry data from containers and Kubernetes clusters to help you monitor, troubleshoot, and gain insights into your containerized applications running in your AKS clusters. For a list of tables and their detailed descriptions used by Container insights, see the [Azure Monitor table reference](/azure/azure-monitor/logs/manage-logs-tables). All these tables are available for [log queries](/azure/azure-monitor/logs/log-query-overview).

[Cost optimization settings](/azure/azure-monitor/containers/container-insights-cost-config) allow you to customize and control the metrics data collected through the container insights agent. This feature supports the data collection settings for individual table selection, data collection intervals, and namespaces to exclude the data collection through [Azure Monitor Data Collection Rules (DCR)](/azure/azure-monitor/essentials/data-collection-rule-overview). These settings control the volume of ingestion and reduce the monitoring costs of container insights. Container insights Collected Data can be customized through the Azure portal, using the following options. Selecting any options other than **All (Default)** leads to the container insights experience becoming unavailable.

| Grouping | Tables | Notes |
| --- | --- | --- |
| All (Default) | All standard container insights tables | Required for enabling the default container insights visualizations |
| Performance | Perf, InsightsMetrics | |
| Logs and events | ContainerLog or ContainerLogV2, KubeEvents, KubePodInventory | Recommended if you enabled managed Prometheus metrics |
| Workloads, Deployments, and HPAs | InsightsMetrics, KubePodInventory, KubeEvents, ContainerInventory, ContainerNodeInventory, KubeNodeInventory, KubeServices | |
| Persistent Volumes | InsightsMetrics, KubePVInventory | |

The **Logs and events** grouping captures the logs from the _ContainerLog_ or _ContainerLogV2_, _KubeEvents_, _KubePodInventory_ tables, but not the metrics. The recommended path to collect metrics is to enable [Azure Monitor managed service Prometheus for Prometheus](/azure/azure-monitor/essentials/prometheus-metrics-overview) from your AKS cluster and to use [Azure Managed Grafana](/azure/managed-grafana/overview) for data visualization. For more information, see [Manage an Azure Monitor workspace](/azure/azure-monitor/essentials/azure-monitor-workspace-manage).

#### ContainerLogV2 schema

Azure Monitor Container Insights provides a schema for container logs known as ContainerLogV2, which is the recommended option. This format includes the following fields to facilitate common queries for viewing data related to AKS and Azure Arc-enabled Kubernetes clusters:

- ContainerName
- PodName
- PodNamespace

In addition, this schema is compatible with [Basic Logs](/azure/azure-monitor/logs/logs-table-plans?tabs=portal-1#set-the-table-plan) data plan, which offers a low-cost alternative to standard analytics logs. The Basic log data plan lets you save on the cost of ingesting and storing high-volume verbose logs in your Log Analytics workspace for debugging, troubleshooting, and auditing. It doesn't affect costs for analytics and alerts. For more information, see [Manage tables in a Log Analytics workspace](/azure/azure-monitor/logs/manage-logs-tables?tabs=azure-portal).

ContainerLogV2 is the recommended approach and is the default schema for customers onboarding container insights with Managed Identity Auth using ARM, Bicep, Terraform, Policy, and Azure portal. For more information about how to enable ContainerLogV2 through either the cluster's Data Collection Rule (DCR) or ConfigMap, see [Enable the ContainerLogV2 schema](/azure/azure-monitor/containers/container-insights-logs-schema?tabs=configure-portal#enable-the-containerlogv2-schema).

[!INCLUDE [horz-monitor-activity-log](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-activity-log.md)]

## View Azure Kubernetes Service (AKS) container logs, events, and pod metrics in real time

In this section, you learn how to use the *live data* feature in Container Insights to view Azure Kubernetes Service (AKS) container logs, events, and pod metrics in real time. This feature provides direct access to `kubectl logs -c`, `kubectl get` events, and `kubectl top pods` to help you troubleshoot issues in real time.

> [!NOTE]
> AKS uses [Kubernetes cluster-level logging architectures](https://kubernetes.io/docs/concepts/cluster-administration/logging/#cluster-level-logging-architectures). The container logs are located inside `/var/log/containers` on the node. To access a node, see [Connect to Azure Kubernetes Service (AKS) cluster nodes](./node-access.md).

For help with setting up the *live data* feature, see [Configure live data in Container Insights](/azure/azure-monitor/containers/container-insights-livedata-setup). This feature directly accesses the Kubernetes API. For more information about the authentication model, see [Kubernetes API](https://kubernetes.io/docs/concepts/overview/kubernetes-api/).

### View AKS resource live logs

> [!NOTE]
> To access logs from a private cluster, you need to be on a machine on the same private network as the cluster.

1. In the [Azure portal](https://portal.azure.com/), navigate to your AKS cluster.
1. Under **Kubernetes resources**, select **Workloads**.
1. Select the *Deployment*, *Pod*, *Replica Set*, *Stateful Set*, *Job*, or *Cron Job* that you want to view logs for, and then select **Live Logs**.
1. Select the resource you want to view logs for.

   The following example shows the logs for a *Pod* resource:

   :::image type="content" source="./media/container-insights-live-data/live-data-deployment.png" alt-text="Screenshot that shows the deployment of live logs." lightbox="./media/container-insights-live-data/live-data-deployment.png":::

### View live logs

You can view real time log data as the container engine generates it on the *Cluster*, *Nodes*, *Controllers*, or *Containers*.

1. In the [Azure portal](https://portal.azure.com/), navigate to your AKS cluster.
1. Under **Monitoring**, select **Insights**.
1. Select the *Cluster*, *Nodes*, *Controllers*, or *Containers* tab, and then select the object you want to view logs for.
1. On the resource **Overview**, select **Live Logs**.

   > [!NOTE]
   > To view the data from your Log Analytics workspace, select **View Logs in Log Analytics**. To learn more about viewing historical logs, events, and metrics, see [How to query logs from Container Insights](/azure/azure-monitor/containers/container-insights-log-query).

   After successful authentication, if data can be retrieved, it begins streaming to the Live Logs tab. You can view log data here in a continuous stream. The following image shows the logs for a *Container* resource:

   :::image type="content" source="./media/container-insights-live-data/container-live-logs.png" alt-text="Screenshot that shows the container Live Logs view data option." lightbox="./media/container-insights-live-data/container-live-logs.png":::

### View live events

You can view real-time event data as the container engine generates it on the *Cluster*, *Nodes*, *Controllers*, or *Containers*.

1. In the [Azure portal](https://portal.azure.com/), navigate to your AKS cluster.
1. Under **Monitoring**, select **Insights**.
1. Select the *Cluster*, *Nodes*, *Controllers*, or *Containers* tab, and then select the object you want to view events for.
1. On the resource **Overview** page, select **Live Events**.

   > [!NOTE]
   > To view the data from your Log Analytics workspace, select **View Events in Log Analytics**. To learn more about viewing historical logs, events, and metrics, see [How to query logs from Container Insights](/azure/azure-monitor/containers/container-insights-log-query).

   After successful authentication, if data can be retrieved, it begins streaming to the Live Events tab. The following image shows the events for a *Container* resource:

   :::image type="content" source="./media/container-insights-live-data/container-live-events.png" alt-text="Screenshot that shows the container Live Events view data option." lightbox="./media/container-insights-live-data/container-live-events.png":::

### View metrics

You can view real-time metrics data as the container engine generates it on the *Nodes* or *Controllers* by selecting a *Pod* resource.

1. In the [Azure portal](https://portal.azure.com/), navigate to your AKS cluster.
1. Under **Monitoring**, select **Insights**.
1. Select the *Nodes* or *Controllers* tab, and then select the *Pod* object you want to view metrics for.
1. On the resource **Overview** page, select **Live Metrics**.

   > [!NOTE]
   > To view the data from your Log Analytics workspace, select **View Events in Log Analytics**. To learn more about viewing historical logs, events, and metrics, see [How to query logs from Container Insights](/azure/azure-monitor/containers/container-insights-log-query).

   After successful authentication, if data can be retrieved, it begins streaming to the Live Metrics tab. The following image shows the metrics for a *Pod* resource:

   :::image type="content" source="./media/container-insights-live-data/pod-live-metrics.png" alt-text="Screenshot that shows the pod Live Metrics view data option." lightbox="./media/container-insights-live-data/pod-live-metrics.png":::

[!INCLUDE [horz-monitor-analyze-data](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-analyze-data.md)]

[!INCLUDE [horz-monitor-external-tools](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-external-tools.md)]

### Monitoring overview page in Azure portal

The **Monitoring** tab on the **Overview** page for your AKS cluster resource offers a quick way to start viewing monitoring data in the Azure portal. This tab includes graphs with common metrics for the cluster separated by node pool. You can select any of these graphs to further analyze the data in the [metrics explorer](/azure/azure-monitor/essentials/metrics-getting-started).

The **Monitoring** tab also includes links to [Managed Prometheus](#integrations) and [Container Insights](#integrations) for the cluster. If you need to enable these tools, you can enable them here. You might also see a banner at the top of the screen recommending that you enable other features to improve monitoring of your cluster.

> [!TIP]
> You can access monitoring features for all AKS clusters in your subscription by selecting **Azure Monitor** on the Azure portal home page.

[!INCLUDE [horz-monitor-kusto-queries](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-kusto-queries.md)]

[!INCLUDE [horz-monitor-alerts](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-alerts.md)]

[!INCLUDE [horz-monitor-insights-alerts](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-recommended-alert-rules.md)]

### Prometheus metrics based alerts

When you [enable collection of Prometheus metrics](#integrations) for your cluster, you can download a collection of [recommended Prometheus alert rules](/azure/azure-monitor/containers/container-insights-metric-alerts#enable-prometheus-alert-rules). This download includes the following rules:

| Level | Alerts |
|:---|:---|
| Cluster level | KubeCPUQuotaOvercommit<br>KubeMemoryQuotaOvercommit<br>KubeContainerOOMKilledCount<br>KubeClientErrors<br>KubePersistentVolumeFillingUp<br>KubePersistentVolumeInodesFillingUp<br>KubePersistentVolumeErrors<br>KubeContainerWaiting<br>KubeDaemonSetNotScheduled<br>KubeDaemonSetMisScheduled<br>KubeQuotaAlmostFull |
| Node level | KubeNodeUnreachable<br>KubeNodeReadinessFlapping |
| Pod level | KubePVUsageHigh<br>KubeDeploymentReplicasMismatch<br>KubeStatefulSetReplicasMismatch<br>KubeHpaReplicasMismatch<br>KubeHpaMaxedOut<br>KubePodCrashLooping<br>KubeJobStale<br>KubePodContainerRestart<br>KubePodReadyStateLow<br>KubePodFailedState<br>KubePodNotReadyByController<br>KubeStatefulSetGenerationMismatch<br>KubeJobFailed<br>KubeContainerAverageCPUHigh<br>KubeContainerAverageMemoryHigh<br>KubeletPodStartUpLatencyHigh |

See [How to create log alerts from Container Insights](/azure/azure-monitor/containers/container-insights-log-alerts) and [How to query logs from Container Insights](/azure/azure-monitor/containers/container-insights-log-query).
[Log alerts](/azure/azure-monitor/alerts/alerts-unified-log) can measure two different things, which can be used to monitor in different scenarios:

- [Result count](/azure/azure-monitor/alerts/alerts-unified-log#result-count): Counts the number of rows returned by the query and can be used to work with events such as Windows event logs, Syslog, and application exceptions.
- [Calculation of a value](/azure/azure-monitor/alerts/alerts-unified-log#calculation-of-a-value): Makes a calculation based on a numeric column and can be used to include any number of resources. An example is CPU percentage.

Depending on the alerting scenario required, log queries need to be created comparing a DateTime to the present time by using the `now` operator and going back one hour. To learn how to build log-based alerts, see [Create log alerts from Container insights](/azure/azure-monitor/containers/container-insights-log-alerts).

### AKS alert rules

The following table lists some suggested alert rules for AKS. These alerts are just examples. You can set alerts for any metric, log entry, or activity log entry listed in the [Azure Kubernetes Service monitoring data reference](monitor-aks-reference.md).

| Condition | Description  |
|:---|:---|
| CPU Usage Percentage > 95 | Fires when the average CPU usage across all nodes exceeds the threshold. |
| Memory Working Set Percentage > 100 | Fires when the average working set across all nodes exceeds the threshold. |

[!INCLUDE [horz-monitor-advisor-recommendations](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-advisor-recommendations.md)]

[!INCLUDE [horz-monitor-insights-alerts](~/reusable-content/ce-skilling/azure/includes/azure-monitor/horizontals/horz-monitor-insights-alerts.md)]

## Node Network Metrics

Node Network Metrics are crucial for maintaining a healthy and performant Kubernetes cluster. By collecting and analyzing data about network traffic, you can gain valuable insights into your cluster's operation and identify potential issues before they lead to outages or performance degradation.

Starting with Kubernetes version 1.29, node network metrics are enabled by default for all clusters with Azure Monitor enabled.

The following node network metrics are enabled by default and are aggregated per node. All metrics include the labels cluster and instance (node name). These metrics can be easily visualized using the Managed Grafana dashboard, accessible under Azure Managed Prometheus > Kubernetes > Networking > Clusters.

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

For detailed Pod-level and DNS metrics, explore our [Advanced Container Networking services](advanced-container-networking-services-overview.md) offering.

## Related content

- See [Azure Kubernetes Service monitoring data reference](monitor-aks-reference.md) for a reference of the metrics, logs, and other important values created for AKS.
- See [Monitoring Azure resources with Azure Monitor](/azure/azure-monitor/essentials/monitor-azure-resource) for general details on monitoring Azure resources.
