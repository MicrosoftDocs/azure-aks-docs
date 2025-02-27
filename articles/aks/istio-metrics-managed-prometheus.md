---
title: Collect metrics for Istio service mesh add-on workloads for Azure Kubernetes Service in Azure Managed Prometheus
description: Collect metrics for Istio service mesh add-on workloads for Azure Kubernetes Service in Azure Managed Prometheus
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
author: deveshdama
ms.date: 02/12/2025
ms.author: ddama
---

# Collect metrics for Istio service mesh add-on workloads for Azure Kubernetes Service in Azure Managed Prometheus
This guide explains how to set up and use Azure Managed Prometheus to collect metrics from Istio service mesh add-on workloads on your Azure Kubernetes cluster.

## Prerequisites

- Complete steps to enable the Istio add-on on the cluster as per [documentation][istio-deploy-addon]
  - [Set environment variables][istio-addon-env-vars]
  - [Install Istio add-on][install-istio-add-on]
  - [Enable sidecar injection][enable-sidecar-injection]
  - [Deploy sample application][deploy-sample-application]

- [Deploy an external Istio ingress gateway][istio-deploy-ingress]

## Enable Azure Monitor managed service for Prometheus
Azure Monitor managed service for Prometheus collects data from Azure Kubernetes cluster.
To enable Azure Monitor managed service for Prometheus, you must create an [Azure Monitor workspace][azure-monitor-workspace] to store the metrics:

```azurecli-interactive
export AZURE_MONITOR_WORKSPACE=<azure-monitor-workspace-name>

export AZURE_MONITOR_WORKSPACE_ID=$(az monitor account create \
    --name $AZURE_MONITOR_WORKSPACE \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --query id -o tsv)
```

### Enable Prometheus addon
To collect Prometheus metrics from your Kubernetes cluster, [enable Prometheus addon][kubernetes-enable-monitoring]:

```azurecli-interactive
az aks update --enable-azure-monitor-metrics --name $CLUSTER --resource-group $RESOURCE_GROUP --azure-monitor-workspace-resource-id $AZURE_MONITOR_WORKSPACE_ID
```

### Customize scraping of Prometheus metrics in Azure Monitor managed service
Save the scrape config in a file named `prometheus-config`. This configuration enables pod annotation-based scraping, which allows Prometheus to automatically discover and scrape metrics from pods with specific annotations.

```bash
global: 
  scrape_interval: 30s
scrape_configs: 
- job_name: workload
  scheme: http
  kubernetes_sd_configs:
    - role: endpoints
  relabel_configs:
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
      action: keep
      regex: true
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
      action: replace
      target_label: __metrics_path__
      regex: (.+)
    - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
      action: replace
      regex: ([^:]+)(?::\d+)?;(\d+)
      replacement: $1:$2
      target_label: __address__ 
```

To [enable pod annotation-based scraping][pod-annotation-based-scraping], create configmap `ama-metrics-prometheus-config` that references `prometheus-config` file in `kube-system` namespace.

```bash
kubectl create configmap ama-metrics-prometheus-config --from-file=prometheus-config -n kube-system
```

### Verify Metric Collection
1. Configure access permissions: navigate to your Azure Monitor workspace in Azure portal and create role assignment for yourself to grant 'Monitoring Data Reader' role on the workspace resource.  

2. Generate sample traffic: send a few requests to the product page created earlier, for example:  
     ```bash
     curl -s "http://${GATEWAY_URL_EXTERNAL}/productpage" | grep -o "<title>.*</title>"
     ```

3. View/Query metrics in Azure portal: navigate to Prometheus explorer under your Azure Monitor workspace and [query metrics][prometheus-workbooks]. The example below shows results for query `istio_requests_total`.

    [ ![Diagram that shows sample query execution on prometheus explorer.](./media/aks-istio-addon/managed-prometheus-integration/prometheus-explorer.jpg) ](./media/aks-istio-addon/managed-prometheus-integration/prometheus-explorer.jpg#lightbox)

## Delete resources

If you want to clean up the Istio service mesh and the ingresses (leaving behind the cluster), run the following command:

```azurecli-interactive
az aks mesh disable --resource-group ${RESOURCE_GROUP} --name ${CLUSTER}
```

If you want to clean up all the resources created from the Istio how-to guidance documents, run the following command:

```azurecli-interactive
az group delete --name ${RESOURCE_GROUP} --yes --no-wait
```

<!--- Internal Links --->
[istio-deploy-addon]: istio-deploy-addon.md
[istio-deploy-ingress]: istio-deploy-ingress.md
[istio-addon-env-vars]: istio-deploy-addon.md#set-environment-variables
[install-istio-add-on]: istio-deploy-addon.md#install-istio-add-on
[enable-sidecar-injection]: istio-deploy-addon.md#enable-sidecar-injection
[deploy-sample-application]: istio-deploy-addon.md#deploy-sample-application
[enable-external-ingress-gateway]: istio-deploy-ingress.md#enable-external-ingress-gateway
[azure-monitor-workspace]: /azure/azure-monitor/essentials/azure-monitor-workspace-manage?tabs=cli#create-an-azure-monitor-workspace
[pod-annotation-based-scraping]: /azure/azure-monitor/containers/prometheus-metrics-scrape-configuration
[kubernetes-enable-monitoring]: /azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli#enable-with-cli
[prometheus-workbooks]: /azure/azure-monitor/essentials/prometheus-workbooks