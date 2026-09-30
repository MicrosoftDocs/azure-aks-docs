---
title: Monitor control plane metrics
description: Learn how to enable and query control plane metrics from AKS on Azure Local.
ms.date: 09/01/2026
ms.topic: how-to
author: davidsmatlak
ms.author: davidsmatlak
ms.reviewer: haojiehang
ms.custom: hyperconverged

---

# Monitor control plane metrics

[!INCLUDE [hci-applies-to-23h2](../../includes/hci-applies-to-23h2.md)]

This article describes how to enable and query control plane metrics from AKS on Azure Local. The workflow is as follows:

- Enable Managed Prometheus extension
- Enable control plane metrics
- (Optional) view metrics in Grafana

Control plane metrics provide critical visibility into the availability and performance of Kubernetes control plane components, such as the API server, scheduler, or controller manager. You can use these metrics to maximize observability and maintain operational excellence for your cluster.

## Prerequisites

Before you begin, make sure the following prerequisites are met:

- A running AKS on Azure Local instance.
- Install the latest version of the **aksarc**, **connectedk8s**, and **k8s-extension** CLI extensions.
- [Download and install **kubectl**](https://kubernetes.io/docs/tasks/tools/) on your development machine.  
- [Understand the basics of Prometheus Query Language](https://prometheus.io/docs/prometheus/latest/querying/examples/).
- [Understand the basics of Kubernetes system component metrics](https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/).

## Enable Managed Prometheus extension

Azure Monitor collects and aggregates important metrics from your AKS running on Azure Local instance. In addition to [platform metrics](kubernetes-monitor-metrics.md#metrics) collected from your cluster, you can view granular Kubernetes metrics using the managed Prometheus extension. This extension collects Prometheus metrics from your deployment and stores them in an Azure Monitor workspace in Azure. Once they are ingested, you can analyze them in Metrics Explorer or use prebuilt dashboards in Azure Managed Grafana.

### Step 1: Install the managed Prometheus extension

You can install the extension either from the Azure portal, or using CLI.

# [Azure portal](#tab/azureportal)

Go to your Kubernetes instance, then select **Monitoring > Insights > Monitor Settings**:

:::image type="content" source="../../media/control-plane-metrics/monitor-settings.png" alt-text="Screenshot of portal showing monitor settings." lightbox="../../media/control-plane-metrics/monitor-settings.png":::

#### [Azure CLI](#tab/azurecli)

The following command installs the managed Prometheus extension with a default Azure Monitor workspace:

```azurecli
az k8s-extension create --name azuremonitor-metrics --cluster-name <cluster-name> --resource-group <resource-group> --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers.Metrics
```

---

See the [guidance for the managed Prometheus extension onboarding](/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli#enable-prometheus-and-grafana).

### Step 2: Verify extension and metrics pod deployment

To verify the extension installation, you can run `az connectedk8s proxy` to connect to the cluster and use **kubectl** to list the metrics pods. The pods should start with the name **ama-metrics-** and are in a running state.

```azurecli
kubectl get pods -n kube-system
```

The output of the command is similar to the following:

```output
NAME READY STATUS RESTARTS AGE
akshci-telemetry-5df56fd5-s5wtm 1/1 Running 1 (37h ago) 44d
ama-logs-nqf9h 3/3 Running 0 5h29m
ama-logs-pvvb2 3/3 Running 2 (5h21m ago) 5h29m
ama-logs-rs-86bc9dd898-4p7pv 2/2 Running 0 5h29m
**ama-metrics-98bb54876-dndrh** 2/2 Running 2 (3h33m ago) 5h30m
**ama-metrics-ksm-6544c98f5f-ph6sp** 1/1 Running 0 5h30m
**ama-metrics-node-6dl7p** 2/2 Running 2 (3h33m ago) 5h30m
**ama-metrics-node-ztwzt** 2/2 Running 1 (3h33m ago) 5h30m
….
```

## Enable control plane metrics with custom configuration

After you enable the extension, you can view Prometheus Metrics from [targets scraped by default](/azure/azure-monitor/containers/prometheus-metrics-scrape-default#targets-scraped-by-default) in the Azure Monitor workspace. The [default ON targets](/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration-minimal#minimal-ingestion-for-default-on-targets) include kubelet, kube-state-metrics, node-exporter, etc. To get started with kubelet metrics, use the PromQL below:

```bash
kubelet_running_pods{cluster="<cluster_name>", instance="<instance_name>", job="kubelet"}
```

:::image type="content" source="../../media/control-plane-metrics/metrics.png" alt-text="Screenshot showing metrics query." lightbox="../../media/control-plane-metrics/metrics.png":::

To view control plane metrics such as APIServer and ETCD, you can customize the scraping of Prometheus metrics by applying the config maps to your cluster. The metrics pods pick up the config maps and pods restart in 2-3 minutes. Follow these steps to enable.

### Step 1: connect to Kubernetes

Connect to your cluster using `az connectedk8s proxy` and run `kubectl get pods -A` to make sure you're connected.

### Step 2: download the configuration files and review the content

Managed Prometheus uses an [agent-based solution](https://github.com/Azure/prometheus-collector) to collect Prometheus metrics and send them to the Azure Monitor workspace. There are two configuration files to download and review: **ama-metrics-settings-configmap.yaml** and **ama-metrics-prometheus-config-configmap.yaml**. For more information about customizing metrics scraping using configuration files, see [Customize scraping of Prometheus metrics](/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration).

- To enable **APIServer** metrics, modify the value of `apiserver` under the default OFF targets and set it to **true** in **ama-metrics-settings-configmap.yaml**. For the list of metrics, see [minimal ingestion for default OFF targets](/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration-minimal#minimal-ingestion-for-default-off-targets).
- To enable metrics from components not listed under default OFF targets such as **ETCD, Controller Manager, Kube Scheduler**, add a new scraping job in **ama-metrics-prometheus-config-configmap.yaml**.

[You can download](https://github.com/Azure/aksArc/tree/main/scripts/ControlPlaneMetrics) these two configuration files to your local machine and review the content before going to the next step.

### Step 3: apply custom configuration files

Run the following commands to apply the changes, then wait several minutes for the metrics pods to restart.

```bash
kubectl apply -f ama-metrics-settings-configmap.yaml
kubectl apply -f ama-metrics-prometheus-config-configmap.yaml
```

### Step 4: query metrics in Azure Monitor workspace

Go to the linked **Azure Monitor Workspace > Metric Explorer** and use PromQL to validate that the metrics are ingested. In the following sample query, it shows a stable kube-scheduler metrics `scheduler_schedule_attempts_total` from a specific Kubernetes cluster.

:::image type="content" source="../../media/control-plane-metrics/metrics-ingested.png" alt-text="Screenshot of portal showing metrics ingestion." lightbox="../../media/control-plane-metrics/metrics-ingested.png":::

## View metrics in Grafana

Metrics Explorer is convenient for metrics validation. To operationalize Kubernetes monitoring with Azure Monitor, it's recommended that you monitor the metrics using Azure Managed Grafana.

### Step 1: install Azure Managed Grafana

[Follow these instructions](/azure/managed-grafana/how-to-connect-azure-monitor-workspace) to create a Grafana workspace, link to an Azure Monitor workspace, and view the metrics in Grafana dashboards. You can view the dashboard under **Monitoring > Insights > Monitor Settings**. Multiple instances can be linked to the same Azure Monitor workspace, so make sure to choose the right dashboard.

### Step 2: import a prebuilt dashboard for control plane metrics

[Download the API server dashboard ](https://grafana.com/grafana/dashboards/20331-kubernetes-api-server/) to your local machine, copy the JSON content, then import it to the managed Grafana dashboard.

:::image type="content" source="../../media/control-plane-metrics/dashboards.png" alt-text="Screenshot showing metrics dashboard." lightbox="../../media/control-plane-metrics/dashboards.png":::

### Step 3: view metrics in the dashboard

Ensure that the data source and cluster names are correct. You can view the metrics in Grafana and customize them as needed.

:::image type="content" source="../../media/control-plane-metrics/metrics-status.png" alt-text="Screenshot showing control plane metrics status." lightbox="../../media/control-plane-metrics/metrics-status.png":::

## Next steps

- [AKS monitoring data reference](kubernetes-monitor-metrics.md)
- [Prometheus scrape configuration](/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration)
