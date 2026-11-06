---
title: Set up container network metrics for Azure Kubernetes Service (AKS)
description: Enable container network metrics on AKS, collect them with Prometheus, and view networking dashboards in the Azure portal without creating a Grafana instance.
author: Khushbu-Parekh
ms.author: kparekh
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 11/04/2026
ms.custom: template-how-to-pattern, devx-track-azurecli
# Customer intent: As a Kubernetes administrator, I want to collect network metrics and view ACNS networking dashboards for my AKS cluster, so that I can monitor network health and investigate workload connectivity.
---

# Set up container network metrics for Azure Kubernetes Service (AKS)

Use container network metrics to identify packet drops, investigate DNS behavior,
and find the workloads involved in network issues. This guide enables collection
on Azure Kubernetes Service (AKS), connects it to a Prometheus backend, and shows
you how to view network health in the ACNS Grafana dashboards.

Use Azure Monitor managed service for Prometheus and view networking dashboards
directly in the Azure portal. The portal's Grafana dashboards are available at
no additional dashboard cost; you don't need to create an Azure Managed Grafana
instance. Alternatively, use your own Prometheus and Grafana deployment.
Metric collection is available
across supported Cilium and non-Cilium data planes; pod-level metrics require Linux.
See the [metrics overview](container-network-observability-metrics.md)
for platform coverage and available metrics.

On Cilium clusters, you can then filter individual metrics by workload or security
identity, or enable metrics for external destination IPs and destination ports.
These are optional next steps, not requirements for basic collection.

For example, start with include filters to collect flow metrics from one
application. Add exclude filters only if you need an exception, such as omitting
traffic to a particular destination. To retain broad collection while removing
load-test drop observations, use an exclude-only filter instead. See
[metric filtering examples](how-to-configure-container-network-metrics-filtering.md#dns-tcp-http-and-drop-filtering-examples).

| Step | Outcome |
| --- | --- |
| 1. Enable ACNS and connect to the cluster | Network observability is available on the supported nodes. |
| 2. Choose a collection path | Managed or self-managed Prometheus scrapes the agent metrics. |
| 3. Allow metrics excluded by default, if needed | Prometheus collects the required metrics from the agent's metrics endpoint. |
| 4. Open networking dashboards | You view network health and workload traffic in the Azure portal or your own Grafana deployment. |

For stored logs or real-time Hubble inspection instead of metrics, see
[Set up container network logs](how-to-configure-container-network-logs.md).

> [!IMPORTANT]
> The Azure portal dashboard experience is free. ACNS and metrics ingestion
> and storage can still incur charges. Use an existing supported cluster and
> monitoring resources when possible. Review
> [ACNS pricing](https://azure.microsoft.com/pricing/details/azure-container-networking-services/)
> and your monitoring service's pricing before enabling collection.

## Prerequisites

- An Azure account with an active subscription. If needed, create a
  [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account).
- Bash in [Azure Cloud Shell](/azure/cloud-shell/overview)
  or a local Bash terminal with the [current Azure CLI](/cli/azure/install-azure-cli)
  and `kubectl`. Run `az --version` to check your CLI installation.
- Permissions to create or update the cluster and the monitoring resources you
  choose, and read access to the Azure Monitor workspace holding the metrics.
  For the managed path, review the [Azure Monitor prerequisites](/azure/azure-monitor/containers/kubernetes-monitoring-enable).
- A supported AKS Kubernetes version and node operating system. Don't create
  new node pools on retired Azure Linux 2.0 images. See
  [Upgrade the node operating system](upgrade-os-version.md).
- Running workloads with network activity to populate the workload dashboards.
  An empty cluster won't show application traffic.
- For DNS metrics on Cilium, configure
  [DNS visibility](how-to-apply-fqdn-filtering-policies.md)
  by applying a DNS inspection policy and generating DNS traffic.
  For HTTP metrics, complete [Layer 7 policy configuration](how-to-apply-l7-policies.md):
  enable L7 on the cluster, apply an HTTP inspection policy to the workload,
  and generate HTTP traffic through that policy. Configuring metric filters
  doesn't apply these policies or verify observation generation.
  Neither is required for basic node-level network monitoring.

## Step 1: Enable ACNS and connect to the cluster

Sign in with `az login` if you're using a local CLI. Select your subscription
and set the values used throughout this guide:

```azurecli
az account set --subscription "<subscription-id>"
export RESOURCE_GROUP="<aks-resource-group>"
export CLUSTER_NAME="<aks-cluster-name>"
export LOCATION="<azure-region>"
```

### Use an existing cluster

If ACNS is already enabled, skip the update command. Otherwise, enable it:

```azurecli
az aks update \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" \
    --enable-acns
```

Enabling ACNS doesn't change an existing cluster's data plane. Metric filtering
and the additional metric enablement described later require Cilium. For other
ACNS capabilities and their prerequisites, see the
[ACNS overview](advanced-container-networking-services-overview.md).

### Or create a new cluster

Create the resource group if it doesn't already exist:

```azurecli
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
```

Choose **one** of the following options. These commands use the region's default
AKS Kubernetes version rather than pinning an old release. To choose another
supported version, inspect `az aks get-versions --location "$LOCATION" -o table`
and add `--kubernetes-version` with your selected version.

#### Cilium

Choose Cilium if you plan to use source-level metric filtering or the additional
external-IP and destination-port metrics:

```azurecli
az aks create \
    --name "$CLUSTER_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --generate-ssh-keys \
    --location "$LOCATION" \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --network-dataplane cilium \
    --node-count 2 \
    --pod-cidr 192.168.0.0/16 \
    --enable-acns
```

#### Non-Cilium

This option supports collection of the metrics available for the non-Cilium
data plane. It doesn't provide the Cilium-specific CNM filtering path or
Container Network Security features. For FIPS restrictions, see the
[metrics platform limitations](container-network-observability-metrics.md#limitations).

```azurecli
az aks create \
    --name "$CLUSTER_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --generate-ssh-keys \
    --location "$LOCATION" \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --pod-cidr 192.168.0.0/16 \
    --enable-acns
```

### Get cluster credentials

For either a new or existing cluster, connect and confirm the current context:

```azurecli
az aks get-credentials --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP"
```

```bash
kubectl config current-context
kubectl get nodes
```

Stop if the context isn't the intended cluster or the commands fail. Resolve
connection, permissions, or node readiness issues before continuing.

## Step 2: Choose a collection path

| Path | Choose it when |
| --- | --- |
| [Azure managed Prometheus and portal dashboards](#azure-managed-prometheus-and-portal-dashboards) | You want managed metrics storage and built-in networking dashboards without creating a Grafana instance. |
| [Your own Prometheus and Grafana](#your-own-prometheus-and-grafana) | You already operate a monitoring stack and want to add network metrics to it. |

Configure one path first. If you already collect network metrics successfully,
preserve that setup and proceed to Step 3 or Step 4. Configuring duplicate scrapes
can increase ingestion and distort queries.

### Azure managed Prometheus and portal dashboards

Use an **Azure Monitor workspace** for Prometheus metrics. A **Log Analytics
workspace** stores logs and isn't a substitute for this metrics workspace.

The following example creates an Azure Monitor workspace in the cluster's
resource group. If you already have a workspace, set `AZURE_MONITOR_NAME` to its
name, skip creation, and obtain its ID using its actual resource group.
Use a location supported by Azure Monitor workspaces.

#### Create or select an Azure Monitor workspace

```azurecli
export AZURE_MONITOR_NAME="<azure-monitor-name>"

az resource create \
    --resource-group "$RESOURCE_GROUP" \
    --namespace Microsoft.Monitor \
    --resource-type accounts \
    --name "$AZURE_MONITOR_NAME" \
    --location "$LOCATION" \
    --properties '{}'
```

#### Enable managed Prometheus collection

Obtain the Azure Monitor workspace resource ID:

```azurecli
azuremonitorId=$(az resource show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AZURE_MONITOR_NAME" \
    --resource-type "Microsoft.Monitor/accounts" \
    --query id --output tsv)
```

Check the command for errors and confirm that `azuremonitorId` contains the
intended workspace's resource ID before continuing. Enable scraping:

```azurecli
az aks update \
    --name "$CLUSTER_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --enable-azure-monitor-metrics \
    --azure-monitor-workspace-resource-id "$azuremonitorId"
```

Verify the Azure Monitor metrics pods:

```bash
kubectl get pods -n kube-system -o wide | grep ama-metrics
```

Resolve nonready pods before checking data. Running pods alone don't establish
successful scraping or ingestion. For permission or collection problems, follow
[Enable monitoring on AKS](/azure/azure-monitor/containers/kubernetes-monitoring-enable).

No separate Grafana resource or Grafana link is required for the Azure portal
dashboards. Continue with metric selection, then open the networking dashboards
in Step 4.

### Your own Prometheus and Grafana

Use an existing Prometheus deployment that can discover Kubernetes pods and reach
the agent metrics endpoints. Configure its Kubernetes API authentication, RBAC, and
network access first. The following example covers **Hubble pod-level metrics**;
it doesn't configure node-level Cilium or Retina metrics.

Add this job to your existing `scrape_configs` list, preserving other jobs. If
an operator manages your Prometheus, use its supported configuration
mechanism rather than editing a generated configuration file. Replace
`myAKSCluster` with your cluster label:

```yaml
scrape_configs:
  - job_name: networkobservability-hubble
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_pod_label_k8s_app]
        regex: 'kube-system;(retina|cilium)'
        action: keep
      - source_labels: [__meta_kubernetes_pod_phase]
        regex: Running
        action: keep
      - source_labels: [__meta_kubernetes_pod_ip]
        regex: '([^:]+)'
        replacement: '$1:9965'
        target_label: __address__
      - source_labels: [__meta_kubernetes_pod_ip]
        regex: '(.+:.*)'
        replacement: '[$1]:9965'
        target_label: __address__
      - target_label: cluster
        replacement: myAKSCluster
      - source_labels: [__meta_kubernetes_pod_node_name]
        target_label: instance
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'hubble_dns_queries_total|hubble_dns_responses_total|hubble_drop_total|hubble_tcp_flags_total'
        action: keep
```

Validate the merged configuration with `promtool check config "<prometheus-config-file>"`
if available in your deployment, then reload Prometheus using your normal
operational procedure. In **Targets**, check that targets for
`networkobservability-hubble` are **UP**. Inspect scrape errors if they aren't.
The example assumes the Hubble endpoint is exposed on port `9965`; verify your
deployment's endpoint if it differs.

Connect Grafana to this Prometheus data source. Continue with metric selection
in Step 3, then open the dashboards in Step 4.

## Step 3: Choose which Hubble metrics to ingest

To limit high-cardinality data and ingestion costs, the managed Prometheus
[minimal ingestion profile](/azure/azure-monitor/containers/prometheus-metrics-scrape-default)
doesn't collect these metrics by default:

- `hubble_flows_processed_total`
- `hubble_flows_to_world_total`
- `hubble_port_distribution_total`

If you need any of these three metrics, add their names to your existing collection
configuration. Otherwise, continue to Step 4.

The metrics must be available at the agent's endpoint before they can be ingested.
To enable the optional world or destination-port metrics on Cilium, see
[Configure container network metrics filtering](how-to-configure-container-network-metrics-filtering.md#enable-additional-metrics).

Follow the instructions in the following section for your Prometheus backend.

### Allow the metric families in managed Prometheus

Use your selections to update the `networkobservabilityHubble` allow list in
the `ama-metrics-settings-configmap` ConfigMap in `kube-system`. This change
allows the collector to include these metrics from the agent's Prometheus metrics endpoint.

> [!IMPORTANT]
> Append metric names to the existing value; don't replace it with only the new
> names. Keep existing names and patterns so metrics used by your dashboards and
> alerts continue to be ingested. If the value is already `hubble.*`, no change is
> needed: it includes all Hubble metrics exposed by the agents.

1. If the ConfigMap doesn't exist, create it by using the supported template in
   [Customize Prometheus scraping](/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration).
   If it already exists, back it up before making changes:

   ```bash
   kubectl get configmap ama-metrics-settings-configmap -n kube-system \
     -o yaml > ama-metrics-settings-before.yaml
   ```

   Resolve any error before continuing.

1. Open the ConfigMap for editing. In schema v2, find
   `networkobservabilityHubble` in the `default-targets-metrics-keep-list` section
   under `data.cluster-metrics`. Preserve your ConfigMap's existing schema and
   other settings.

   ```bash
   kubectl edit configmap ama-metrics-settings-configmap -n kube-system
   ```

1. Keep minimal ingestion enabled. Add each additional metric name to the
   **existing** `networkobservabilityHubble` value, separated by `|`.
   For example, if the current value is:

   ```text
   networkobservabilityHubble = "hubble_dns_queries_total|hubble_drop_total"
   ```

   To also ingest flow metrics, change it to:

   ```text
   networkobservabilityHubble = "hubble_dns_queries_total|hubble_drop_total|hubble_flows_processed_total"
   ```

   Use your own existing value as the starting point, not the example value.
   This setting isn't a complete ConfigMap. Collecting more metrics can increase
   ingestion volume and cost.

1. Save and close the editor. Allow the collector to reload the settings, and then
   query each added metric in Prometheus. For the preceding example, query
   `hubble_flows_processed_total` and check for recent samples while relevant
   traffic is flowing. Also query an existing metric, such as
   `hubble_dns_queries_total` if you already collect it, to confirm it still
   receives new samples. Check dashboards and alerts that use these metrics before
   continuing to Step 4.

### Allow the metric families in your own Prometheus

Append additional metric names to the existing job's `metric_relabel_configs`
keep expression, separated by `|`. Keep all existing names and patterns.
For example, if the current expression is
`hubble_dns_queries_total|hubble_drop_total`, add flow metrics as follows:

```yaml
metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'hubble_dns_queries_total|hubble_drop_total|hubble_flows_processed_total'
    action: keep
```

Use your own existing expression as the starting point.
Update the existing keep rule rather than appending a second one; a second keep
rule can discard metrics retained by the first.
Validate and reload the configuration. Query each added metric, such as
`hubble_flows_processed_total`, and an existing metric in Prometheus. Confirm
that both receive recent samples while relevant traffic is flowing, and then
open the networking dashboards in Step 4.

## Step 4: View ACNS networking dashboards

### Azure portal

After enabling Azure Monitor collection, open a networking dashboard:

1. Open your AKS cluster in the Azure portal.
1. Under **Monitoring**, select **Dashboards with Grafana**.
1. Choose a dashboard from the list, and then select the namespace or workload
   and a time range with network activity.

For details, see [Use dashboards with Grafana with AKS](/azure/azure-monitor/visualize/grafana-kubernetes).

### Available networking dashboards

Use the following six **Kubernetes / Networking** dashboards to explore your
cluster's network activity. Import IDs are provided only for customers using
their own Grafana; you don't need them for the built-in Azure portal dashboards.

| Dashboard | Use | Import ID |
| --- | --- | --- |
| Clusters | Node-level network health; requires node-level metrics in addition to the Hubble job. | [18814](https://grafana.com/grafana/dashboards/18814-kubernetes-networking-clusters/) |
| DNS (Cluster) | DNS metrics across a cluster or selected nodes. | [20925](https://grafana.com/grafana/dashboards/20925-kubernetes-networking-dns-cluster/) |
| DNS (Workload) | DNS behavior for a selected workload. | [20926](https://grafana.com/grafana/dashboards/20926-kubernetes-networking-dns-workload/) |
| Drops (Workload) | Observed drops involving a workload. | [20927](https://grafana.com/grafana/dashboards/20927-kubernetes-networking-drops-workload/) |
| Pod Flows (Namespace) | Flow observations involving pods in a namespace. | [20928](https://grafana.com/grafana/dashboards/20928-kubernetes-networking-pod-flows-namespace/) |
| Pod Flows (Workload) | Flow observations involving a workload. | [20929](https://grafana.com/grafana/dashboards/20929-kubernetes-networking-pod-flows-workload/) |

Start with **Clusters** for node-level network health, then open a workload or
namespace dashboard to investigate traffic, drops, or DNS behavior. Allow for
collection delay after enabling monitoring or changing the keep list.

DNS panels require DNS visibility. Pod Flows panels require
`hubble_flows_processed_total` in the keep list configured in Step 3.
An empty panel can mean no matching traffic, missing collection, or an incorrect
time range or selection. It doesn't necessarily mean there's a network problem.

### Optional: Use a separate Grafana deployment

If you already use Azure Managed Grafana, you can
[connect it to the Azure Monitor workspace](/azure/managed-grafana/how-to-connect-azure-monitor-workspace)
and use the **Kubernetes / Networking / ...** dashboards under
**Dashboards > Azure Managed Prometheus**. Azure Managed Grafana is a separate,
paid service, not a prerequisite for the portal dashboards.

For your own Grafana, import the dashboards by using the IDs in the preceding table and select your
Prometheus data source.

## Troubleshoot missing metrics

| Symptom | Check |
| --- | --- |
| Monitoring pods aren't ready or targets are down | Collector health, Kubernetes discovery permissions, and network access to the agent endpoint. |
| Agent has a metric but Prometheus doesn't | Target enablement, keep-list expressions, scrape errors, and ingestion delay. |
| Optional metric is absent at the agent | Cilium/API support, CNM status and warnings, matching traffic, and the metric's counting rules. |
| Grafana shows no data but Prometheus has samples | Data source, access permissions, cluster/workload labels, and time range. |
| DNS or HTTP panels are empty | Protocol visibility and metric availability; scraping doesn't enable inspection. |
| Old series remain after filters change | Compare fresh counter changes. Filters don't delete historical samples. |

## Clean up resources

Restore only your investigation changes to CNM and Prometheus allow lists.
Preserve settings used by other teams and any changes made since your backup.
Removing a CNM entry disables an optional metric only if that entry enabled it;
service-provided metrics remain enabled. Removing filters can broaden collection.
Historical samples remain subject to backend retention.

Delete a resource group **only if you created it exclusively for this exercise**
and no one needs any resource in it. The following command deletes the cluster and all
other resources in that group:

```azurecli
az group delete --name "$RESOURCE_GROUP"
```

## Next steps

* [Choose metrics and understand their limits](container-network-observability-metrics.md).
* [Filter metrics and enable additional metrics on Cilium](how-to-configure-container-network-metrics-filtering.md).
* [Set up stored or on-demand network logs](how-to-configure-container-network-logs.md).
* [Explore Advanced Container Networking Services](advanced-container-networking-services-overview.md).
