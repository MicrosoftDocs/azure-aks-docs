---
title: Configure and View Azure Kubernetes Application Network Metrics (Preview)
description: Learn how to configure and view Azure Kubernetes Application Network metrics in Azure Monitor, including data plane metrics from your workloads and Azure Kubernetes Application Network components.
author: kochhars
ms.author: kochhars
ms.service: azure-kubernetes-app-net
ms.topic: how-to
ms.date: 11/04/2025
---

# Configure and view Azure Kubernetes Application Network metrics (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Azure Kubernetes Application Network provides comprehensive metrics for your workloads and the Azure Kubernetes Application Network data plane components (ZTunnel, Istio CNI, and Waypoint) through Azure Monitor metrics. This article explains how to configure and view these metrics in Azure Monitor.

## Limitations

Control plane metrics aren't currently supported. However, data plane metrics are available, and you can use them to monitor the health and performance of your workloads and Azure Kubernetes Application Network components.

## Data plane metrics

Data plane metrics include metrics from your workloads/applications and the `appnet-system` namespace. Azure Kubernetes Application Network currently only provides support for **data plane metrics**.

## Configure data plane metrics

### Workspace configuration options for data plane metrics

When you enable Prometheus metrics collection for Azure Kubernetes Application Network member clusters, you have the following options for workspace configuration:

- Use an existing Azure Monitor workspace.
- Omit the workspace resource ID and use the default workspace created for your resource group.
- Create a new Azure Monitor workspace.

### Enable data plane metrics collection

#### [Use an existing Azure Monitor workspace](#tab/use-existing-workspace)

1. Enable Prometheus metrics collection on your Azure Kubernetes Application Network member cluster using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--azure-monitor-workspace-resource-id` parameter set to your existing workspace ID. If Azure Monitor Metrics is already enabled on your member cluster, you can skip to the next step.

    ```azurecli-interactive
    az aks update --enable-azure-monitor-metrics \
      --name $CLUSTER_NAME \
      --resource-group $AKS_RG \
      --azure-monitor-workspace-resource-id $WORKSPACE_ID
    ```

1. Create and apply the following ConfigMap in the `kube-system` namespace using the `kubectl apply` command. This ConfigMap enables scraping of Ztunnel, Istio CNI, waypoint, and your application/workloads.

    ```bash
    kubectl apply -f - <<EOF
    kind: ConfigMap
    apiVersion: v1
    metadata:
      name: ama-metrics-settings-configmap
      namespace: kube-system
    data:
      schema-version: v1
      config-version: ver1
      prometheus-collector-settings: |-
        cluster_alias = ""
        https_config = true
      default-scrape-settings-enabled: |-
        ztunnel = true
        istio-cni = true
      pod-annotation-based-scraping: |-
        podannotationnamespaceregex = ".*"
      default-targets-metrics-keep-list: |-
        ztunnel = ""
        istio-cni = ""
        minimalingestionprofile = true
      default-targets-scrape-interval-settings: |-
        ztunnel = "30s"
        istio-cni = "30s"
        podannotations = "30s"
      debug-mode: |-
        enabled = false
    EOF
    ```

1. Add annotations to the applications pods you want to scrape.

     - `prometheus.io/scrape: "true"` is required to indicate that the pod should be scraped.
     - `prometheus.io/path` is optionally used to indicate the path where metrics are hosted. If omitted, it defaults to `/metrics`.
     - `prometheus.io/port` is optionally used to indicate the port where metrics are hosted. If omitted, Prometheus will use the container's declared ports from the pod spec. For containers with no declared ports, Prometheus creates a port-free target (IP only), which requires proper relabeling configuration to work with port annotations. It is recommended to explicitly specify the port to ensure reliable scraping.

    The following sample defines annotations for a pod that is hosting metrics at `<pod IP>:15020/metrics`

    ```bash
    prometheus.io/scrape: "true"
    prometheus.io/port: "15020"
    prometheus.io/path: "/metrics"
    ```

    It might take a few minutes for the AMA metrics ReplicaSet to load this configuration.

#### [Use the default workspace](#tab/use-default-workspace)

1. Enable Prometheus metrics collection on your Azure Kubernetes Application Network member cluster using the [`az aks update`](/cli/azure/aks#az-aks-update) command. If Azure Monitor Metrics is already enabled on your member cluster, you can skip to the next step.

    ```azurecli-interactive
    az aks update --enable-azure-monitor-metrics \
      --name $CLUSTER_NAME \
      --resource-group $AKS_RG \
    ```

1. Create and apply the following ConfigMap in the `kube-system` namespace using the `kubectl apply` command. This ConfigMap enables scraping of Ztunnel, Istio CNI, waypoint, and your application/workloads.

    ```bash
    kubectl apply -f - <<EOF
    kind: ConfigMap
    apiVersion: v1
    metadata:
      name: ama-metrics-settings-configmap
      namespace: kube-system
    data:
      schema-version: v1
      config-version: ver1
      prometheus-collector-settings: |-
        cluster_alias = ""
        https_config = true
      default-scrape-settings-enabled: |-
        ztunnel = true
        istio-cni = true
      pod-annotation-based-scraping: |-
        podannotationnamespaceregex = ".*"
      default-targets-metrics-keep-list: |-
        ztunnel = ""
        istio-cni = ""
        minimalingestionprofile = true
      default-targets-scrape-interval-settings: |-
        ztunnel = "30s"
        istio-cni = "30s"
        podannotations = "30s"
      debug-mode: |-
        enabled = false
    EOF
    ```

1. Add annotations to the applications pods you want to scrape.

     - `prometheus.io/scrape: "true"` is required to indicate that the pod should be scraped.
     - `prometheus.io/path` is optionally used to indicate the path where metrics are hosted. If omitted, it defaults to `/metrics`.
     - `prometheus.io/port` is optionally used to indicate the port where metrics are hosted. If omitted, Prometheus will use the container's declared ports from the pod spec. For containers with no declared ports, Prometheus creates a port-free target (IP only), which requires proper relabeling configuration to work with port annotations. It is recommended to explicitly specify the port to ensure reliable scraping.

    The following sample defines annotations for a pod that is hosting metrics at `<pod IP>:15020/metrics`

    ```bash
    prometheus.io/scrape: "true"
    prometheus.io/port: "15020"
    prometheus.io/path: "/metrics"
    ```

    It might take a few minutes for the AMA metrics ReplicaSet to load this configuration.

#### [Create a new Azure Monitor workspace](#tab/create-new-workspace)

1. Create a new Azure Monitor workspace using the [`az monitor account create`](/cli/azure/monitor/account#az-monitor-account-create) command.

    ```azurecli-interactive
    az monitor account create --name $AMW_NAME --resource-group $AKS_RG --location $LOCATION
    ```

1. Enable Prometheus metrics collection on your Azure Kubernetes Application Network member cluster using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--azure-monitor-workspace-resource-id` parameter set to your existing workspace ID.

    ```azurecli-interactive
    az aks update --enable-azure-monitor-metrics \
      --name $CLUSTER_NAME \
      --resource-group $AKS_RG \
      --azure-monitor-workspace-resource-id $WORKSPACE_ID
    ```

1. Create and apply the following ConfigMap in the `kube-system` namespace using the `kubectl apply` command. This ConfigMap enables scraping of Ztunnel, Istio CNI, waypoint, and your application/workloads.

    ```bash
    kubectl apply -f - <<EOF
    kind: ConfigMap
    apiVersion: v1
    metadata:
      name: ama-metrics-settings-configmap
      namespace: kube-system
    data:
      schema-version: v1
      config-version: ver1
      prometheus-collector-settings: |-
        cluster_alias = ""
        https_config = true
      default-scrape-settings-enabled: |-
        ztunnel = true
        istio-cni = true
      pod-annotation-based-scraping: |-
        podannotationnamespaceregex = ".*"
      default-targets-metrics-keep-list: |-
        ztunnel = ""
        istio-cni = ""
        minimalingestionprofile = true
      default-targets-scrape-interval-settings: |-
        ztunnel = "30s"
        istio-cni = "30s"
        podannotations = "30s"
      debug-mode: |-
        enabled = false
    EOF
    ```

1. Add annotations to the applications pods you want to scrape.

     - `prometheus.io/scrape: "true"` is required to indicate that the pod should be scraped.
     - `prometheus.io/path` is optionally used to indicate the path where metrics are hosted. If omitted, it defaults to `/metrics`.
     - `prometheus.io/port` is optionally used to indicate the port where metrics are hosted. If omitted, Prometheus will use the container's declared ports from the pod spec. For containers with no declared ports, Prometheus creates a port-free target (IP only), which requires proper relabeling configuration to work with port annotations. It is recommended to explicitly specify the port to ensure reliable scraping.

    The following sample defines annotations for a pod that is hosting metrics at `<pod IP>:15020/metrics`

    ```bash
    prometheus.io/scrape: "true"
    prometheus.io/port: "15020"
    prometheus.io/path: "/metrics"
    ```

    It might take a few minutes for the AMA metrics ReplicaSet to load this configuration.

---

## View data plane metrics

1. Navigate to your Azure Monitor workspace in the Azure portal to query the metrics using PromQL.
1. Generate some traffic, then select queries from the [exposed metrics](#list-of-metrics-exposed) to view metrics. For example, you can run the following query to view the total number of requests handled by waypoint:

    ```promql
    # ztunnel
    istio_xds_connection_terminations_total
    
    # waypoint
    istio_requests_total
    
    # istio-cni
    istio_cni_install_ready
    ```

    The following screenshot shows results for the sample queries:

    :::image type="content" source="./media/metrics/prometheus-query.png" alt-text="Screenshot of the results of the queries to view the total number of requests handled by waypoint." lightbox="./media/metrics/prometheus-query.png":::

### List of metrics exposed

| Component | Metrics exposed |
| --------- | --------------- |
| **ZTunnel** | `istio_build`<br>`istio_xds_connection_terminations_total`<br>`istio_xds_message_total`<br>`istio_xds_message_bytes_total`<br>`istio_tcp_connections_opened_total`<br>`istio_tcp_connections_closed_total`<br>`istio_tcp_received_bytes_total`<br>`istio_tcp_sent_bytes_total`<br>`istio_on_demand_dns`<br>`istio_dns_requests_total`<br>`istio_dns_upstream_requests`<br>`istio_dns_upstream_failures`<br>`istio_dns_upstream_request_duration_seconds`<br>`workload_manager_active_proxy_count`<br>`workload_manager_pending_proxy_count`<br>`workload_manager_proxies_started_total`<br>`workload_manager_proxies_stopped_total` |
| **Istio CNI** | `istio_cni_install_ready`<br>`istio_cni_installs_total`<br>`nodeagent_reconcile_events_total`<br>`ztunnel_connected` |
| **Waypoint** | `istio_build`<br>`istio_request_bytes_bucket`<br>`istio_request_bytes_count`<br>`istio_request_bytes_sum`<br>`istio_request_duration_milliseconds_bucket`<br>`istio_request_duration_milliseconds_count`<br>`istio_request_duration_milliseconds_sum`<br>`istio_requests_total`<br>`istio_response_bytes_bucket`<br>`istio_response_bytes_count`<br>`istio_response_bytes_sum` |

### Access metrics directly from waypoint proxies

Aside from the Istio request/response metrics, waypoint proxies also emit Envoy metrics.

- To find a complete list of metrics emitted by waypoint, you can port-forward to a waypoint proxy in your namespace and list the metrics using following commands:

    ```bash
    # Port-forward to waypoint proxy
    kubectl port-forward -n <namespace> deployment/waypoint 15020:15020 &
    
    # List metrics exposed by waypoint
    curl http://localhost:15020/stats/prometheus | grep -v '^#' | grep -v '^$' | awk -F'{' '{print $1}' | sort -u
    ```

### Visualize metrics with Grafana in Azure portal

1. Import the [Istio community dashboards](https://grafana.com/orgs/istio/dashboards).
1. Generate traffic for your member cluster, and then navigate to your Azure Monitor workspace in the Azure portal.
1. Select **Monitoring** > **Dashboards with Grafana**.

    The following screenshots show examples of importing the [Istio Ztunnel Dashboard](https://grafana.com/grafana/dashboards/21306-istio-ztunnel-dashboard/):

    :::image type="content" source="./media/metrics/import-dashboard.png" alt-text="Screenshot showing the import dashboard option in the Azure Monitor workspace in Azure portal." lightbox="./media/metrics/import-dashboard.png":::

    :::image type="content" source="./media/metrics/ztunnel-import.png" alt-text="Screenshot showing the review options for importing the Ztunnel dashboard in Azure portal." lightbox="./media/metrics/ztunnel-import.png":::

    :::image type="content" source="./media/metrics/visualize-ztunnel-dashboard.png" alt-text="Screenshot showing Ztunnel dashboard visualizations in a Grafana Dashboard in Azure portal." lightbox="./media/metrics/visualize-ztunnel-dashboard.png":::

If you want to configure Azure Managed Grafana instead of Dashboards with Grafana, see [Create an Azure Managed Grafana workspace using the Azure CLI](/azure/managed-grafana/quickstart-managed-grafana-cli).

## Related content

For more information about Azure Kubernetes Application Network observability and monitoring, see the following articles:

- [Overview of Azure Kubernetes Application Network observability](./observability.md)
- [Monitor logs in Azure Kubernetes Application Network](./logs.md)
