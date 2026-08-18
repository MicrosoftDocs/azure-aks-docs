---
title: Monitor AKS Control Plane Metrics
description: Learn how to monitor Azure Kubernetes Service (AKS) control plane metrics by using Azure Monitor.
ms.date: 09/06/2024
ms.topic: how-to
author: schaffererin
ms.author: sunasing
ms.subservice: aks-monitoring
ms.service: azure-kubernetes-service
# Customer intent: As a Kubernetes administrator, I want to monitor control plane metrics for my Azure Kubernetes Service (AKS) cluster, so that I can ensure operational excellence and maintain the performance and availability of critical control plane components.
---

# Monitor Azure Kubernetes Service control plane metrics

In this article, you learn how to monitor the Azure Kubernetes Service (AKS) control plane by using control plane metrics in Azure Monitor.

AKS supports a subset of control plane metrics free through [Azure Monitor platform metrics](./monitor-aks.md#aks-monitoring-data-metrics-logs-integrations). The control plane metrics feature gives you visibility into the availability and performance of critical control plane components like the API server, etcd, the scheduler, the autoscaler, and the controller manager in AKS. The feature is also fully compatible with the managed service for Prometheus and Azure Managed Grafana. You can use these metrics to maximize overall observability and to maintain operational excellence for your AKS cluster.

## Control plane platform metrics

AKS offers some free control plane metrics for monitoring the API server and etcd. These metrics are automatically collected for all AKS clusters at no cost. You can analyze the metrics by using the [metrics explorer](/azure/azure-monitor/essentials/analyze-metrics) in the Azure portal. You can also create metrics-based alerts by using the metrics data.

To see the full list of supported control plane platform metrics, see the [AKS monitoring reference](./monitor-aks-reference.md#metrics).

## Prerequisites and limitations

* The control plane metrics feature supports only the [managed service for Prometheus](/azure/azure-monitor/essentials/prometheus-metrics-overview) in Azure Monitor.
* [Azure Private Link](/azure/azure-monitor/logs/private-link-security) isn't supported.
* You can customize only the default [`ama-metrics-settings-configmap.yaml`](/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration#configmaps) configmap file. No other customization is supported.
* Your AKS cluster must use [managed identity authentication](use-managed-identity.md).

## Enable control plane metrics on an AKS cluster

Enable control plane metrics by using the managed service for Prometheus add-on when you create a new cluster or update an existing cluster.

> [!NOTE]
> Unlike the metrics that are collected from cluster nodes, control plane metrics are collected by a component that isn't part of the `ama-metrics` add-on. Enabling control plane metrics (for example, by using the `--enable-control-plane-metrics` option) together with the managed service for Prometheus add-on ensures that control plane metrics are collected. AKS clusters that were previously enabled for control plane metrics during preview automatically have `--enable-control-plane-metrics` enabled and continue to collect control plane metrics. After you enable metrics collection, it can take several minutes for the data to appear in the workspace.

### New AKS cluster

Use the [`az aks create`](/cli/azure/aks#az-aks-create) command to enable control plane metrics collection through managed service for Prometheus. To learn how to collect managed service for Prometheus metrics from your AKS cluster, see [Enable Prometheus and Grafana for AKS clusters](/azure/azure-monitor/containers/kubernetes-monitoring-enable#enable-prometheus-and-grafana).


```azurecli
az aks create --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --enable-control-plane-metrics --enable-azure-monitor-metrics
```

### Existing AKS cluster

If your cluster already has the managed service for Prometheus add-on, update the cluster to ensure that it collects control plane metrics by using the [`az aks update`](/cli/azure/aks#az-aks-update) command:

```azurecli
az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --enable-control-plane-metrics
```

## Query control plane metrics

Control plane metrics are stored in an Azure Monitor workspace in the cluster's region. You can query the metrics directly in the workspace or by using the Azure Managed Grafana instance that's connected to the workspace.

1. In the [Azure portal](https://portal.azure.com), go to your AKS cluster resource.

1. On the left menu, select **Monitor** >  **Monitor Settings**.

    :::image type="content" source="media/monitor-control-plane-metrics/azmon-settings.png" alt-text="Screenshot of an example of an Azure Monitor workspace." lightbox="media/monitor-control-plane-metrics/azmon-settings.png":::

1. Go to the Azure Monitor workspace that is linked to the cluster.

    :::image type="content" source="media/monitor-control-plane-metrics/monitor-workspace.png" alt-text="Screenshot of the linked  Azure Monitor workspace." lightbox="media/monitor-control-plane-metrics/monitor-workspace.png":::

1. In the Azure Monitor workspace, under **Managed Prometheus**, query the metrics by using the Prometheus explorer.

    :::image type="content" source="media/monitor-control-plane-metrics/workspace-prometheus-explorer.png" alt-text="Screenshot that shows the Prometheus explorer experience." lightbox="media/monitor-control-plane-metrics/workspace-prometheus-explorer.png":::

> [!NOTE]
> AKS provides dashboard templates to help you view and analyze your control plane telemetry data in real time. If you use Azure Managed Grafana to visualize the data, you can import the following dashboards:
>
> * [API server](https://grafana.com/grafana/dashboards/20331-kubernetes-api-server/)
> * [etcd](https://grafana.com/grafana/dashboards/20330-kubernetes-etcd/)

## Customize control plane metrics

AKS includes a preconfigured set of metrics to collect and store for each component. Metrics for the API server and etcd are collected by default. You can customize the list of metrics that are collected by modifying the [`ama-metrics-settings-configmap.yaml`](https://github.com/Azure/prometheus-collector/blob/main/otelcollector/configmaps/ama-metrics-settings-configmap.yaml) configmap file.

Default targets include the following values:

```yaml
controlplane-metrics: |-
    default-targets-scrape-enabled: |-
      apiserver = true
      cluster-autoscaler = false
      node-auto-provisioning = false
      kube-scheduler = false
      kube-controller-manager = false
      etcd = true
```

All configmap files should be applied to the `kube-system` namespace for any cluster.

> [!NOTE]
> Schema v2 change: The configuration for targets is now separately under cluster-metrics and controlplane-metrics allowing separate control of ingestion volume for cluster-level targets and control plane targets. If you are migrating from v1, replace the configurations to the corresponding sections within cluster-metrics and controlplane-metrics, also note the following:
> - Modify the key name from 'default-scrape-settings-enabled' to 'default-targets-scrape-enabled'
> - For targets within controlplane-metrics section, drop the "controlplane-" prefix
> - Modify minimalingestionprofile = true in the keep-list to minimal-ingestion-profile: |- / enabled = true as its own section

### Customize an ingestion profile

You can customize an ingestion file for collected metrics. For more information, see [Minimal ingestion profile for control plane metrics in managed service for Prometheus](/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration-minimal#minimal-ingestion-for-default-on-targets).

#### Ingest only minimal metrics from default targets

* Set `controlplane-metrics.minimal-ingestion-profile` to `true`, so it ingests only the minimal set of metrics for each of the default targets: `controlplane-apiserver` and `controlplane-etcd`.

#### Ingest all metrics from all targets

1. Download the [`ama-metrics-settings-configmap.yaml`](https://github.com/Azure/prometheus-collector/blob/main/otelcollector/configmaps/ama-metrics-settings-configmap.yaml) configmap file.

1. Rename the configmap file `configmap-controlplane.yaml`.

1. Set `controlplane-metrics.minimal-ingestion-profile` to `false`.

1. Under `controlplane-metrics.default-targets-scrape-enabled`, verify that the targets you want to scrape are set to `true`.

   The targets you can set are:

   * `apiserver`
   * `cluster-autoscaler`
   * `node-auto-provisioning`
   * `kube-scheduler`
   * `kube-controller-manager`
   * `etcd`

1. Apply the configmap file by using the [`kubectl apply`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply) command:

    ```bash
    kubectl apply -f configmap-controlplane.yaml
    ```

After you apply the configuration, it takes several minutes for the metrics from the specified targets that are scraped from the control plane to appear in the Azure Monitor workspace.

#### Ingest more than minimal metrics

Using the `controlplane-metrics.minimal-ingestion-profile` setting helps reduce the ingestion volume of metrics. If set to `true`, only default recording rules, default alerts, and metrics that appear in the default dashboards are collected.

1. Download the [`ama-metrics-settings-configmap.yaml`](https://github.com/Azure/prometheus-collector/blob/main/otelcollector/configmaps/ama-metrics-settings-configmap.yaml) configmap file.

1. Rename the configmap file `configmap-controlplane.yaml`.

1. Set `controlplane-metrics.minimal-ingestion-profile` to `true`.

1. Under `controlplane-metrics.default-targets-scrape-enabled`, verify that the targets you want to scrape are set to `true`.

   The targets you can set are:

   * `apiserver`
   * `cluster-autoscaler`
   * `node-auto-provisioning`
   * `kube-scheduler`
   * `kube-controller-manager`
   * `etcd`

1. Under `controlplane-metrics.default-targets-metrics-keep-list`, specify the list of metrics for the `true` targets.

   For example:

   ```yaml
   apiserver= "apiserver_admission_webhook_admission_duration_seconds|apiserver_longrunning_requests"
   ```

1. Apply the configmap file by using the [`kubectl apply`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply) command:

   ```bash
   kubectl apply -f configmap-controlplane.yaml
   ```

After you apply the configuration, it takes several minutes for the metrics from the specified targets that are scraped from the control plane to appear in the Azure Monitor workspace.

#### Ingest specific metrics from specific targets

1. Download the [`ama-metrics-settings-configmap.yaml`](https://github.com/Azure/prometheus-collector/blob/main/otelcollector/configmaps/ama-metrics-settings-configmap.yaml) configmap file.

1. Rename the configmap file `configmap-controlplane.yaml`.

1. Set `controlplane-metrics.minimal-ingestion-profile` to `false`.

1. Under `controlplane-metrics.default-targets-scrape-enabled`, verify that the targets that you want to scrape are set to `true`.

   The targets you can set are:

   * `apiserver`
   * `cluster-autoscaler`
   * `node-auto-provisioning`
   * `kube-scheduler`
   * `kube-controller-manager`
   * `etcd`

1. Under `controlplane-metrics.default-targets-metrics-keep-list`, specify the list of metrics for the `true` targets.

   For example:

   ```yaml
   apiserver= "apiserver_admission_webhook_admission_duration_seconds|apiserver_longrunning_requests"
   ```

1. Apply the configmap file:

   ```bash
   kubectl apply -f configmap-controlplane.yaml
   ```

After you apply the configuration, it takes several minutes for the metrics from the specified targets that are scraped from the control plane to appear in the Azure Monitor workspace.

## Troubleshoot control plane metrics issues

Make sure that you enable the `--enable-control-plane-metrics` flag and that the `ama-metrics` pods are running.

> [!NOTE]
> The [troubleshooting methods](/azure/azure-monitor/containers/prometheus-metrics-troubleshoot) for the managed service for Prometheus don't apply directly in this scenario. The components that scrape the control plane aren't included in the managed service for Prometheus add-on.

* **Configmap file formatting**: Make sure that you use the correct formatting in the configmap file. Verify that the fields `controlplane-metrics.default-targets-metrics-keep-list`, `controlplane-metrics.minimal-ingestion-profile`, and `controlplane-metrics.default-targets-scrape-enabled` and other fields are correctly populated with their intended values.
* **Isolate the control plane from the data plane**: Start by setting some of the [node-related metrics](/azure/azure-monitor/containers/prometheus-metrics-scrape-default) to `true`, and then verify that the metrics are forwarded to the workspace. Completing these steps helps you determine whether an issue is specific to scraping control plane metrics.
* **A change in the number of events ingested**: After you apply the changes, you can open the metrics explorer in the Azure portal. Go to the Azure Monitor overview pane for the cluster or go to the **Monitoring** section of the selected cluster. Check for an increase or a decrease in the number of events ingested per minute. This information can help you determine whether a specific metric is missing or if all metrics are missing.
* **A specific metric isn't exposed**: In some scenarios, a metric is documented, but it isn't exposed from the target and isn't forwarded to the Azure Monitor workspace. In this case, it's necessary to verify that other metrics are  forwarded to the workspace.
* **Schema v2 change**: The configuration for targets in v2 schema of the configap is now separately under cluster-metrics and controlplane-metrics allowing separate control of ingestion volume for cluster-level targets and control plane targets. If you are migrating from v1, replace the configurations to the corresponding sections within cluster-metrics and controlplane-metrics, also note that the key name from 'default-scrape-settings-enabled' is changed to 'default-targets-scrape-enabled'


  > [!NOTE]
  > If you want to collect the `apiserver_request_duration_seconds` metric or another bucket metric, you must set the entire series in the histogram family:
  >
  > ```yaml
  > apiserver = "apiserver_request_duration_seconds_bucket|apiserver_request_duration_seconds_sum|apiserver_request_duration_seconds_count"
  > ```

* **No access to the Azure Monitor workspace**: When you enable the add-on, you might specify an existing workspace that you can't access. In that scenario, it appears that metrics aren't collected and forwarded. Make sure that you create a new workspace to use to collect metrics when you enable the add-on or when you create the cluster.

## Disable control plane metrics on your AKS cluster

You can disable control plane metrics at any time by using the `--disable-control-plane-metrics` flag or by disabling the managed service for Prometheus add-on.

1. To disable scraping control plane metrics on the AKS cluster, use the [`az aks update`](/cli/azure/aks#az-aks-update) command:

   ```azurecli
   az aks update --disable-control-plane-metrics --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP
   ```

1. Remove the metrics add-on that scrapes Prometheus metrics by using the [`az aks update`](/cli/azure/aks#az-aks-update) command. Note that disabling Prometheus metrics disables metrics collection from other targets in your AKS cluster.

   ```azurecli
   az aks update --disable-azure-monitor-metrics --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP
   ```

## Frequently asked questions

### Can I scrape control plane metrics by using self-hosted Prometheus?

No. Currently, you can't scrape control plane metrics by using self-hosted Prometheus. Self-hosted Prometheus can scrape only a single instance, depending on the load balancer, so the metrics aren't reliable. Often, multiple replicas of the control plane metrics are visible only through the managed service for Prometheus.

### Why isn't the user agent available in the control plane metrics?

In AKS, [control plane metrics](https://kubernetes.io/docs/reference/instrumentation/metrics/) don't have the user agent. The user agent is available only through the control plane logs that you access in [diagnostic settings](/azure/azure-monitor/essentials/diagnostic-settings).

## Related content

* [Monitor AKS](monitor-aks.md)
