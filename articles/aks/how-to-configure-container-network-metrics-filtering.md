---
title: Configure container network metrics filtering for Azure Kubernetes Service (AKS)
description: Select workload traffic for network metrics, enable external-IP and destination-port metrics, and verify results on AKS with Cilium.
author: Khushbu-Parekh
ms.author: kparekh
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 11/04/2026
ms.custom: template-how-to-pattern, devx-track-azurecli
---

# Configure container network metrics filtering for Azure Kubernetes Service (AKS)

This article shows you how to collect network metrics for selected workloads on
Azure Kubernetes Service (AKS) with Cilium. Start by filtering flow metrics for
one application, generate test traffic, and check the results. Then use the other
examples to filter specific metric types or enable additional metrics.

You configure filtering with a Kubernetes resource called `ContainerNetworkMetric`.
This resource stores your metric collection settings in the cluster. You define
the settings in a YAML file and apply the file with `kubectl`. It controls which
traffic contributes to metrics; it doesn't allow or block network traffic.

You can filter DNS, TCP, HTTP, flow, and drop metrics individually. You can also
enable the optional world and destination-port metrics. The following sections
explain the settings and show how to apply them.

By the end of the first walkthrough, you have a filter for one application
and a before-and-after check of its flow counter. Optional examples add detail
only when you need it; they're not required to complete the walkthrough.

> [!IMPORTANT]
> Metric settings are shared across the cluster. Back up the existing resource
> and preserve other teams' entries. Adding higher-cardinality metrics can
> increase collection cost. Removing filters can also broaden collection.

## Prerequisites

- An AKS cluster with the Cilium data plane, Kubernetes version 1.32 or later,
  and [Advanced Container Networking Services](advanced-container-networking-services-overview.md)
  enabled. If you need a cluster or still need to set up metric collection, first
  complete [Set up container network metrics](container-network-observability-how-to.md).
- A Prometheus backend that collects your cluster's metrics, and permission to
  query it. Collection must be working before you test filtering.
- Bash, `kubectl`, and access to your cluster. You can use
  [Azure Cloud Shell](/azure/cloud-shell/overview)
  or a local terminal.
- Permission to read, create, and update cluster-wide `ContainerNetworkMetric`
  resources, and to run commands in the test pod.
- An existing, running Linux pod with `curl`, in a namespace you can use for
  testing. The pod must be allowed to connect to your chosen test destination.
  The following steps don't create a workload or change network policies.
- For Azure CLI setup, version **2.85.0** or later and the `aks-preview`
  extension version **20.0.0b4** or later. Check these versions with `az --version` and
  `az extension show --name aks-preview`. For installation instructions, see
  [Install Azure CLI](/cli/azure/install-azure-cli). To install or update the extension, use `az extension add --name aks-preview`
  or `az extension update --name aks-preview`.

The basic flow-metric example doesn't require DNS or HTTP inspection. Those
requirements are described with the protocol-specific examples.

### Connect to the cluster

If `kubectl` is already connected to the correct cluster, skip the Azure CLI
commands in this section. Otherwise, sign in with `az login`, select your subscription,
and set the names of your existing resource group and cluster:

```azurecli
az account set --subscription "<subscription-id>"
RESOURCE_GROUP="<resource-group-name>"
CLUSTER_NAME="<cluster-name>"
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME"
```

Confirm the current cluster and check that it supports metric filtering:

```bash
kubectl config current-context
kubectl explain containernetworkmetric.spec.filters
kubectl explain containernetworkmetric.spec.filters.metric
```

Stop if the context isn't the intended cluster or if either API check fails.
Resolve the connection, permission, or feature-availability issue before continuing.
The installed schema must support the fields and metric names you use. If it
doesn't, check the supported AKS/ACNS release or contact support. Don't install
development CRDs into a managed cluster.

### Configure metric ingestion

Before starting the walkthrough, allow its metric in your monitoring backend.
**You can enable a metric at the agent without Prometheus ingesting it.**

Azure Monitor managed service for Prometheus excludes the following metrics from
default ingestion because of their high cardinality. To ingest them, update the
`networkobservabilityHubble` allow list in the
`ama-metrics-settings-configmap` ConfigMap in `kube-system`.

| Metric | Agent configuration | Managed Prometheus ingestion |
| --- | --- | --- |
| `hubble_flows_processed_total` | Baseline flow metric. Use a `flow` entry in CNM to filter its observations. | Add to the allow list for the first walkthrough. |
| `hubble_flows_to_world_total` | Enable with a `flows-to-world` entry if the service hasn't already enabled it. | Add to the allow list when using the external-destination example. |
| `hubble_port_distribution_total` | Enable with a `port-distribution` entry if the service hasn't already enabled it. | Add to the allow list when using the destination-port example. |

For the first walkthrough, add only `hubble_flows_processed_total`, preserving
any existing allow-list entries. To back up, update, and apply the ConfigMap settings, see
[Allow the metric families in managed Prometheus](container-network-observability-how-to.md#allow-the-metric-families-in-managed-prometheus).
Adding a CNM filter doesn't
update this ConfigMap. Add the other metric names only when you need them;
ingesting these metrics can increase time-series volume and cost.

If you use your own Prometheus deployment, check its scrape and metric keep
rules instead. To learn more, see
[Allow the metric families in your own Prometheus](container-network-observability-how-to.md#allow-the-metric-families-in-your-own-prometheus).

## Configure collection for a workload

The `ContainerNetworkMetric` resource is a single, shared configuration for your
cluster. Set `metadata.name` to `container-network-metric`, exactly as shown in
the following examples. Kubernetes requires this name. You can choose any name for the
YAML file. In that file:

- `spec.filters` lists the metrics you want to configure.
- `metric` identifies a metric type, such as `dns` or `tcp`.
- `includeFilters` selects traffic to count for that metric.
- `excludeFilters` selects traffic not to count for that metric.

Start with include filters to select the application traffic you need. Add
exclude filters only when you want to omit a subset of that selection. Use
exclude-only filters when you want to keep broad collection but remove specific
observations. Exclusions aren't required, but they take precedence when present.

For example, to collect DNS metrics for an application, add a `dns` entry and
select the application's pods in its filters. This changes DNS metric collection
without changing TCP or other metric types, provided you preserve their existing
entries. This resource filters Hubble metrics; it isn't a filter for every
node-level metric exported by the cluster.

For your first configuration, follow the application example below from start to
finish. After that, choose another task:

| Task | Configuration |
| --- | --- |
| **Filter DNS requests and replies for a client** | Use `dns` with source and destination filters. See [Select DNS requests and replies](#select-dns-requests-and-replies). |
| **Filter TCP metrics by workload** | Use `tcp` with pod or label selectors. See [Select workloads by label](#select-workloads-by-label). |
| **Filter HTTP metrics for an application** | Use `httpV2` with workload filters. See [Select HTTP observations for an application](#select-http-observations-for-an-application). |
| **Filter an existing metric by identity** | See [Filter flow metrics by security identity](#filter-flow-metrics-by-security-identity). |
| **Exclude a workload from drop metrics** | Use `drop` with an exclude filter. See [Exclude a workload from drop metrics](#exclude-a-workload-from-drop-metrics). |
| **See external destination IP addresses in metrics** | See [Inspect TCP traffic to external destinations](#inspect-tcp-traffic-to-external-destinations). |
| **See destination ports in metrics** | See [Inspect destination ports](#inspect-destination-ports). |

Filters choose which traffic contributes to each metric. They don't change the
metric's labels, such as source pod or destination IP.

Separate metric entries are independent. If you omit a service-provided metric
from the resource, it remains enabled without a CNM filter for that metric.
The resource isn't an allow list of every metric the cluster can collect.

You can filter `dns`, `tcp`, `httpV2`, `flow`, and `drop` when the service has
enabled those metrics on your cluster. Configuring a filter doesn't establish
that the workload is generating observations for that metric. DNS observations
require a DNS inspection policy and DNS traffic. HTTP observations require L7
enablement, an HTTP inspection policy applied to the workload, and HTTP traffic
through that policy. The resource's filter status doesn't verify these policy
and traffic prerequisites. Adding a filter doesn't turn on inspection.

For HTTP metrics, the case-sensitive configuration name is `httpV2`, not `http`.
The `metric` field chooses which metric to filter. The optional `protocol` field
limits the traffic to `tcp`, `udp`, or `dns`; it doesn't accept `http`.

### Choose the test workload

In the Bash terminal you use for the following commands, set these values.
Replace the pod name and URL. Change `production` if you use a different namespace.
Set `POD_PREFIX` to the beginning of your application's pod names, and choose a
running `CLIENT_POD` whose name starts with that prefix. For example, `checkout-`
matches `checkout-7f6d8b9c5-x2abc`, but not `payments-7f6d8b9c5-x2abc`.

```bash
NAMESPACE="production"
POD_PREFIX="checkout-"
CLIENT_POD="<running-pod-with-curl>"
TEST_URL="https://<approved-host>/"
kubectl get pod -n "$NAMESPACE" "$CLIENT_POD" -o wide
kubectl exec -n "$NAMESPACE" "$CLIENT_POD" -- curl --version
```

Confirm that the pod is running and `curl` is available. For a pod with multiple
containers, add `-c <container-name>` to each `kubectl exec` command.
Keep this terminal open so the variables remain available.

### Check the existing configuration

Read the current configuration before making changes:

```bash
kubectl get containernetworkmetric container-network-metric -o yaml
```

If the command returns `NotFound`, use the [new-resource instructions](#if-the-resource-doesnt-exist).
For any other error, stop and resolve it before continuing.

If the command displays an existing resource, save a copy before making changes:

```bash
kubectl get containernetworkmetric container-network-metric \
  -o yaml > network-metrics-before.yaml
```

> [!IMPORTANT]
> Keep the metric entries and filters you still need. To configure another metric,
> add an entry under `spec.filters`. If that metric already has an entry, update
> that entry instead of adding a duplicate.

For example, if you already filter `dns` and want to enable `flows-to-world`,
keep the `dns` entry and add a `flows-to-world` entry beside it. Don't replace
the DNS configuration with the new example.

### Filter flow metrics for one application

This example counts flow observations that come from the selected application's
pods. Other source pods don't match this filter. It changes only the `flow`
metric. It doesn't enable the optional
metrics or change traffic permissions.

#### If the resource doesn't exist

Run this Bash command to create `network-metrics.yaml`. Bash replaces
`${NAMESPACE}` and `${POD_PREFIX}` with the values you set above:

```bash
cat > network-metrics.yaml <<EOF
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: container-network-metric
spec:
  filters:
    - metric: flow
      includeFilters:
        - name: selected-application
          from:
            namespacedPod: ["${NAMESPACE}/${POD_PREFIX}"]
EOF
```

For these example values, the selector is `production/checkout-`: the namespace
must be exactly `production`, and the pod name must start with `checkout-`.
Keep the pod-name prefix after `/`; omitting it selects every pod in that
namespace. A full pod name also uses prefix matching, not an exact-name comparison.

#### If the resource already exists

Don't run the new-resource command. Copy the backup to a working file:

```bash
cp network-metrics-before.yaml network-metrics.yaml
```

Open the working file in your editor:

1. Keep `apiVersion`, `kind`, `metadata.name`, and `spec`, along with any
   user-managed labels and annotations you need. Remove `status` and
   server-generated metadata such as `resourceVersion`, `uid`,
   `creationTimestamp`, `managedFields`, and the
   `kubectl.kubernetes.io/last-applied-configuration` annotation.
1. Keep the existing entries under `spec.filters`.
1. If there's no `flow` entry, add the entry shown in the following example. Replace
   `production/checkout-` with your namespace and application pod-name prefix.
1. If `flow` already exists, review its include and exclude filters before editing
   it. To restrict it to this application, update that entry rather than adding a
   second `flow` entry. Coordinate any change to existing collection with the
   administrators who depend on it.

For example, an existing configuration might contain only a DNS filter:

```yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: container-network-metric
spec:
  filters:
    - metric: dns
      includeFilters:
        - from:
            namespacedPod: ["production/checkout-"]
```

The complete configuration would look like this after adding the flow filter:

```yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: container-network-metric
spec:
  filters:
    - metric: dns
      includeFilters:
        - from:
            namespacedPod: ["production/checkout-"]
    - metric: flow
      includeFilters:
        - name: selected-application
          from:
            namespacedPod: ["production/checkout-"]
```

Both examples are complete resources. The second keeps the first example's DNS
filter and adds a flow filter. When you edit your own configuration, preserve your
actual DNS settings and any other metric entries. Keep the backup unchanged so
you can refer to it during cleanup.

### Validate and apply the configuration

First, check whether the cluster accepts the YAML without saving changes:

```bash
kubectl apply --dry-run=server -f network-metrics.yaml
```

If the check fails, correct the reported error before continuing. If it succeeds,
apply the file:

```bash
kubectl apply -f network-metrics.yaml
```

View the resource to check its status:

```bash
kubectl get containernetworkmetric container-network-metric -o yaml
```

Wait for the controller to process the change. Look for `status.state: CONFIGURED`
and read `status.warnings`. If the state is `FAILED`, read `status.reason`,
correct the file, and repeat the validation and apply steps. Configuration
acceptance alone doesn't show that the agent is producing metrics; verify that next.

### Generate traffic and verify the result

1. For managed Prometheus, open the receiving **Azure Monitor workspace** in the
   Azure portal and select **Metrics**. Select **Add metric** > **Add with editor**,
   choose that workspace as the scope, enter your PromQL query, and select **Run**.
   See [Metrics explorer with PromQL](/azure/azure-monitor/metrics/metrics-explorer).
   You don't need an Azure Managed Grafana instance.

   If you already use Grafana, you can use **Explore** with your cluster's
   Prometheus data source instead. For your own Prometheus server, use its query
   page. If the backend contains multiple clusters, add your backend's
   cluster-label selector to the query.

1. Before generating traffic, run this query. Replace the source value with
   your namespace and pod name; PromQL doesn't substitute Bash variables.

   ```promql
   hubble_flows_processed_total{source="production/<client-pod>"}
   ```

   Record the values and the time. The query can return multiple series with
   different labels. If no series exists yet, note that as your baseline.

1. In the Bash terminal where you set the workload variables, make one request:

   ```bash
   kubectl exec -n "$NAMESPACE" "$CLIENT_POD" -- \
     curl --fail --show-error --silent --output /dev/null \
       --write-out 'HTTP %{http_code}\n' \
       --connect-timeout 10 --max-time 20 "$TEST_URL"
   ```

   Check for a successful response from your approved endpoint. Resolve request
   failures before using the result to evaluate filtering.

1. Allow time for your configured Prometheus collection interval and ingestion
   delay, then run the same query again. Look for a new series or an increase
   in an existing counter for the test pod. The counter need not increase by
   exactly one: it counts observed flows, not application requests.

This step verifies collection for the selected pod. It doesn't by itself prove that
all other traffic is excluded. Historical series can remain visible after
filters change. To test exclusion, compare counter changes for an unselected
workload while it generates known traffic, rather than expecting its old series
to disappear.

If no new values appear, use [Troubleshoot metric configuration](#troubleshoot-metric-configuration).
The alternative [direct agent check](#check-metrics-directly-at-the-agent)
can help distinguish agent collection from backend collection problems.

## DNS, TCP, HTTP, and drop filtering examples

Each example in this section is a complete `ContainerNetworkMetric` resource. Choose the example that fits your task, replace its workload names or labels, and save it as `network-metrics.yaml`.

> [!IMPORTANT]
> These examples are alternatives, not separate resources to apply one after another. They all update the same cluster-wide configuration. If the resource already exists, keep its other metric entries and filters in your file before applying a change. See the [complete before-and-after example](#if-the-resource-already-exists).

For each change, follow [Validate and apply the configuration](#validate-and-apply-the-configuration). Then use the same before-and-after check described in [Generate traffic and verify the result](#generate-traffic-and-verify-the-result), with traffic appropriate to the metric. Use your own workload names in both the filters and queries.

The selection examples use include filters only. The separate [drop exclusion example](#exclude-a-workload-from-drop-metrics) shows how to keep broad collection while omitting a workload. For combining inclusion with an exception, see the [filter reference](#filter-reference).

### Select workloads by label

This configuration selects TCP metric observations from pods labeled
`app: checkout`. Replace the label with an application-specific label used by
your test workload. You don't need to exclude anything to select the application.

> [!IMPORTANT]
> In the current implementation, multiple label conditions are evaluated
> independently (OR), unlike the usual Kubernetes label-selector AND behavior.
> For example, adding `tier: frontend` would also select pods with that label
> even if they aren't labeled `app: checkout`. This example has no source
> namespace restriction. If needed, add
> `namespacedPod: ["production/"]` under the same `from` field.
> Replace `production` with your namespace. The namespace and label criteria
> must then both match.

```yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: container-network-metric
spec:
  filters:
    - metric: tcp
      includeFilters:
        - from:
            labelSelector:
              matchLabels:
                app: checkout
```

Confirm that the source pod has the selected label:

```bash
kubectl get pod -n "$NAMESPACE" "$CLIENT_POD" --show-labels
```

Generate TCP traffic by using the earlier `curl` command, and then query
`hubble_tcp_flags_total` for the selected cluster and workload.
This metric counts FIN, SYN, SYN-ACK, and RST flags on eligible forwarded or
redirected observations. It doesn't count every TCP packet or unique connection.

### Select DNS requests and replies

Before using this example, configure
[DNS visibility](how-to-apply-fqdn-filtering-policies.md)
by applying a policy with DNS inspection rules to your workload. DNS metric
observations are generated when the workload sends DNS traffic through that
policy. Allowing TCP or UDP port 53 alone doesn't enable inspection. A `dns`
metric filter doesn't apply or validate the required policy.

Use two filters to include DNS traffic in both directions. Replace
`production/client-` with your client's namespace and pod-name prefix.

```yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: container-network-metric
spec:
  filters:
    - metric: dns
      includeFilters:
        - from:
            namespacedPod: ["production/client-"]
          protocol: ["dns"]
        - to:
            namespacedPod: ["production/client-"]
          protocol: ["dns"]
```

The first filter selects traffic sent by the client. The second selects traffic
sent back to it. Either filter can match. Generate a DNS lookup from the selected
pod using its installed DNS client, then inspect `hubble_dns_queries_total` and
`hubble_dns_responses_total` in your metrics backend. Check the client in the
source or destination labels as appropriate.

Changing DNS filters doesn't enable DNS inspection or change other metric types.

### Select HTTP observations for an application

Before using this example, complete [Set up Layer 7 (L7) policies with ACNS](how-to-apply-l7-policies.md?tabs=cilium).
That guide explains how to enable L7 policies on the cluster with
`--acns-advanced-networkpolicies L7` and apply an HTTP policy. FQDN filtering alone
isn't sufficient for this HTTP example.

You generate HTTP metric observations when you apply an HTTP inspection policy
to your workload and HTTP traffic passes through that policy. Enabling L7 on the
cluster alone isn't sufficient. A `httpV2` filter selects those observations;
it doesn't apply the policy or verify that the workload meets these prerequisites.
Generate HTTP traffic and check `hubble_http_requests_total` separately to verify
collection, including your Prometheus ingestion settings.
The TCP example above doesn't require HTTP inspection.

Use the case-sensitive metric name `httpV2`. This example includes observations
from or to pods whose names start with `web-` in the `production` namespace.
Replace these names with your application's namespace and pod-name prefix.
The `httpV2` handler counts HTTP response observations. Its filters use the
observed response's source and destination. The exported source and destination
context labels are then reversed to represent the request direction. Don't
assume that a filter's `from` endpoint is the metric's exported `source` label.

```yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: container-network-metric
spec:
  filters:
    - metric: httpV2
      includeFilters:
        - name: http-from-web
          from:
            namespacedPod: ["production/web-"]
        - name: http-to-web
          to:
            namespacedPod: ["production/web-"]
```

Generate an HTTP request that receives a response through the application's
configured inspection path. Compare `hubble_http_requests_total` before and
after the request, selecting the cluster and workload under investigation.

Adding `httpV2` filters doesn't enable HTTP inspection or decrypt HTTPS traffic.
The HTTPS requests in the optional-metric example demonstrate TCP world and port
metrics, not HTTP metric collection.

### Exclude a workload from drop metrics

This configuration excludes drop observations from pods whose names
start with `load-test-` in the `production` namespace. Replace this selector with
the test workload you want to exclude. Other workloads remain eligible for drop
metric collection.
Use this exclude-only approach when you want to retain broad drop monitoring
but omit load-test observations, rather than select one application.

```yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: container-network-metric
spec:
  filters:
    - metric: drop
      excludeFilters:
        - from:
            namespacedPod: ["production/load-test-"]
```

This configuration doesn't prevent or cause packet drops. It changes which existing drop events
contribute to `hubble_drop_total`. Verify it with known dropped test traffic in
an approved test environment, not by disrupting a production workload.

## Filter flow metrics by security identity

A Cilium security identity is a numeric identifier assigned to an endpoint or
endpoint category. It's not an Azure managed identity or a user identity. You can
use it in a source or destination filter instead of selecting individual IP
addresses. Check that the cluster supports identity filters:

```bash
kubectl explain containernetworkmetric.spec.filters.includeFilters.to.identities
```

The following example restricts flow metrics to TCP traffic going to world
(external) identities from the checkout application. Save it as
`network-metrics.yaml`, replacing `production/checkout-` with your namespace and
application pod-name prefix. If the resource already exists,
keep its other metric entries and update its existing `flow` entry.

```yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: container-network-metric
spec:
  filters:
    - metric: flow
      includeFilters:
        - name: checkout-world-traffic
          from:
            namespacedPod: ["production/checkout-"]
          to:
            identities: [2, 9, 10]
          protocol: ["tcp"]
```

Identity `2` represents world, `9` represents world IPv4, and `10` represents
world IPv6. Listing `2` doesn't automatically include the other two. Some external
destinations have different identities and don't match this filter. The API
accepts numeric values from `0` through `16777215`, not aliases such as `world`.

Validate, apply, and repeat the traffic and query steps from the first example.
Use an approved external destination classified as world. This filter changes
which flows are counted; it doesn't add destination IP labels to the flow metric.
To see external destination IPs, use the optional metric in the following section.

## Enable additional metrics

Use a filtered entry under `spec.filters` to enable `flows-to-world` or
`port-distribution` when the service doesn't already supply the metric. There's no
separate enablement flag in this resource. Each example below is a complete
configuration for one metric. Preserve existing metric entries before applying it.

If the service already enables a metric, CNM filters it without replacing
its existing labels or options. The descriptions below show the service-owned
options used when CNM adds a metric. Inspect the emitted labels when comparing
results on a cluster with an existing configuration.

| Action | Metric added by your CNM entry | Metric already supplied by the service |
| --- | --- | --- |
| Add a filtered entry | Enable and filter the metric. | Filter the metric; preserve its service-provided labels and options. |
| Remove that entry | Disable the metric. | Keep the metric enabled without that entry's filters. |
| Delete CNM | Remove CNM-added metrics. | Restore service-provided collection without any CNM filters. |

To enable both metrics, include both entries under `spec.filters` in the same
resource. The [configuration used for the captured results](#custom-resource-used-for-the-test)
shows both metrics together, with an existing DNS entry preserved.

### Inspect TCP traffic to external destinations

Use this configuration to select TCP traffic from checkout pods in `production`
to destinations with a world identity. Replace `production/checkout-` with your
namespace and application pod-name prefix.

```yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: container-network-metric
spec:
  filters:
    - metric: flows-to-world
      includeFilters:
        - name: checkout-world-egress
          from:
            namespacedPod: ["production/checkout-"]
          to:
            identities: [2, 9, 10]
          protocol: ["tcp"]
          verdict: ["forwarded"]
```

For a metric newly enabled through CNM, the service uses SYN-only counting:
eligible non-reply TCP SYN observations to world destinations. It doesn't count
UDP traffic. This example further restricts observations to forwarded traffic.
Repeated SYN observations can increase the counter more than once for a
connection attempt, so the counter isn't a count of successful connections.

Follow [Validate and apply the configuration](#validate-and-apply-the-configuration),
then repeat the earlier baseline, `curl`, and query steps with this metric.
Use the same `$NAMESPACE`, `$CLIENT_POD`, and `$TEST_URL` values, with a destination
classified as world.

Query `hubble_flows_to_world_total` in Prometheus. For a workspace that contains
multiple clusters, select the cluster under investigation before comparing results.
Replace the source value below with your namespace and pod name:

```promql
hubble_flows_to_world_total{source="production/<client-pod>"}
```

Look for the selected source pod, the destination IP, and new observations from the
test. Source and destination labels come from the service-managed contexts, not
from adding identity filters. A destination assigned a different identity won't
match the example.

### Inspect destination ports

Use this complete configuration to examine TCP and UDP destination ports used
by checkout pods. Replace `production/checkout-` with your namespace and
application pod-name prefix. If you already enabled `flows-to-world` and want to keep it, retain that
entry in this file before applying it.

```yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: container-network-metric
spec:
  filters:
    - metric: port-distribution
      includeFilters:
        - name: checkout-ports
          from:
            namespacedPod: ["production/checkout-"]
          protocol: ["tcp", "udp"]
```

Validate and apply the file using the earlier steps. Record a baseline, generate
TCP traffic with the earlier `curl` command, and inspect the destination ports.
Replace the source value with your namespace and pod name:

```promql
hubble_port_distribution_total{source="production/<client-pod>"}
```

The `protocol` and `port` labels identify the protocol and destination port.
The metric counts forwarded or redirected traffic that the agent identifies as
not being a reply. Dropped traffic and traffic with unknown reply status aren't
counted. A `verdict: ["dropped"]` filter won't change this behavior.

An HTTPS request normally produces TCP/443 observations. UDP/53 observations can
also appear if the pod performs DNS lookups over UDP; cached resolution might not
produce new DNS traffic.

### Check metrics directly at the agent

Use this check if the backend query has no data or you want the terminal
output shown in the following screenshots. It reads metrics directly from the Cilium
agent on the test pod's node. It doesn't verify that Prometheus has collected them.
You need permission to list pods and port-forward in `kube-system`, plus local `curl`.

In the terminal containing your test workload variables, find its node and list
the Cilium pods on that node:

```bash
NODE=$(kubectl get pod -n "$NAMESPACE" "$CLIENT_POD" \
  -o jsonpath='{.spec.nodeName}')
kubectl get pods -n kube-system -l k8s-app=cilium \
  --field-selector "spec.nodeName=$NODE" -o wide
```

Stop if either command fails or no Cilium pod is listed. Set the name returned
by the command, then start the port-forward:

```bash
CILIUM_POD="<cilium-pod-on-the-test-node>"
kubectl -n kube-system port-forward --address 127.0.0.1 \
  "pod/$CILIUM_POD" 19965:9965
```

Leave this terminal running. In a second Bash terminal, set the exact source
label for your test pod and fetch the metrics:

```bash
SOURCE="<namespace>/<client-pod>"
date -u '+Scrape time (UTC): %Y-%m-%dT%H:%M:%SZ'
curl --fail --silent --show-error --max-time 15 \
  http://127.0.0.1:19965/metrics > agent-metrics.prom &&
grep -E '^hubble_(flows_processed|flows_to_world|port_distribution)_total[{]' \
  agent-metrics.prom | grep -F "source=\"$SOURCE\""
```

If `curl` reports an error, check the port-forward and whether the agent exposes
metrics on port 9965. If it succeeds but no matching lines appear, check the
source value, selected agent, metric configuration, and test traffic. Don't
interpret an empty result as proof that filtering works.

Repeat the scrape before and after new traffic to compare counters. Keep the
UTC time and complete labels so you compare the same series.
Press **Ctrl+C** in the first terminal when you finish the port-forward.

### Example configuration and captured results

The following example shows the configuration used to collect both metrics from
the `cnm-capture-client` pod in the `cnm-docs` namespace on a Cilium cluster.
The test generated a DNS lookup and eight HTTPS requests to
`https://www.microsoft.com`. All eight HTTPS requests returned HTTP 200.

#### Custom resource used for the test

This is the complete applied configuration, with server-generated metadata and
status omitted. The existing `dns` entry was kept; the test added
`flows-to-world` and `port-distribution` to the same resource.

```yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkMetric
metadata:
  name: container-network-metric
spec:
  filters:
    - metric: dns
      includeFilters:
        - name: dns-from-demo-client
          from:
            namespacedPod: ["pets/acns-panel-client-"]
        - name: dns-to-demo-client
          to:
            namespacedPod: ["pets/acns-panel-client-"]
    - metric: flows-to-world
      includeFilters:
        - name: cnm-docs-world-egress
          from:
            namespacedPod: ["cnm-docs/cnm-capture-client"]
          to:
            identities: [2, 9, 10]
          protocol: ["tcp"]
          verdict: ["forwarded"]
    - metric: port-distribution
      includeFilters:
        - name: cnm-docs-destination-ports
          from:
            namespacedPod: ["cnm-docs/cnm-capture-client"]
          protocol: ["tcp", "udp"]
```

The world filter selects forwarded TCP observations from the test client to
destinations with a world identity. The port filter selects TCP and UDP
observations from the same client. Pod names in `namespacedPod` are matched as
prefixes; the test used a single pod with this name.

The `dns` entry selects a different workload from an earlier configuration. It
isn't required to enable either optional metric, including UDP/53 observations
in `port-distribution`.

> [!IMPORTANT]
> This example uses the test cluster's pod and namespace names. Replace them with
> your own names before using it. If your cluster already has this resource, add
> or update only the metric entries you need and keep the other settings.

After the controller processed the changes, the resource reported
`status.state: CONFIGURED`. It also warned that each optional metric could
increase the number of time series and the cost of storing them. Both metrics
were also verified in the configuration used by the agent before traffic was
generated. To inspect your resource's state and warnings, run:

```bash
kubectl get containernetworkmetric container-network-metric -o yaml
```

#### World metric result

The following screenshot shows a direct agent scrape at **16:41:33 UTC on
November 2, 2026**. For source `cnm-docs/cnm-capture-client`, the
`hubble_flows_to_world_total` sample shows the documentation address `203.0.113.10`, protocol
`TCP`, verdict `FORWARDED`, and value **8**.

:::image type="content" source="./media/advanced-container-networking-services/hubble-flows-to-world-metric.png" alt-text="Terminal screenshot of hubble_flows_to_world_total showing eight forwarded TCP observations from cnm-docs/cnm-capture-client to the documentation address 203.0.113.10." lightbox="./media/advanced-container-networking-services/hubble-flows-to-world-metric.png":::

*World metric output for the client selected by the `cnm-docs-world-egress`
filter.*

The destination IP in the screenshot and sample description has been replaced
with `203.0.113.10`, an address reserved for documentation. For your own tests,
use an approved, reachable destination rather than this example address.

#### Destination-port result

The following screenshot shows a direct agent scrape at **16:43:28 UTC on
November 2, 2026**, using the same source pod and configuration.

:::image type="content" source="./media/advanced-container-networking-services/hubble-destination-port-metric.png" alt-text="Terminal screenshot of hubble_port_distribution_total showing TCP port 443 with value 52 and two UDP port 53 series with values 24 and 34 for cnm-docs/cnm-capture-client." lightbox="./media/advanced-container-networking-services/hubble-destination-port-metric.png":::

*Destination-port output for the client selected by the
`cnm-docs-destination-ports` filter.*

| Protocol | Destination port | Destination label | Counter value |
| --- | --- | --- | --- |
| TCP | 443 | Empty: no destination pod metadata | 52 |
| UDP | 53 | `kube-system/coredns-5bf45f87d-dqpt2` | 24 |
| UDP | 53 | `kube-system/coredns-5bf45f87d-rljcr` | 34 |

All three series have `traffic_direction="egress"`. The empty destination label
on the TCP/443 series is expected for an external destination without pod metadata.

These cumulative counters count observations, not unique requests or
connections. The test traffic ran from **15:09:13 to 15:09:48 UTC**, before the
screenshots were captured. The timestamps in the screenshots identify the
scrapes, not the traffic interval. Values and destination addresses can differ
in another run.

These screenshots show that the agent produced the metrics. They don't show
whether Azure Monitor received the metrics or Grafana displayed them. Check your Prometheus backend
separately as described in the preceding procedures.

## Filter reference

| Field | Description |
| --- | --- |
| **`spec.filters`** | List of metrics to filter. Include at least one entry. Use each metric name only once. |
| **`metric`** | Metric types covered in this guide: `flow`, `dns`, `drop`, `httpV2`, `tcp`, `flows-to-world`, and `port-distribution`. |
| **`includeFilters`** | Traffic to include for this metric. |
| **`excludeFilters`** | Traffic to exclude for this metric. |
| **`name`** | Optional name for a metric filter. A name alone doesn't select traffic. |
| **`from`, `to`** | Select where traffic comes from or goes to, using `namespacedPod`, `ip`, `labelSelector`, or `identities`. |
| **`labelSelector`** | In the current implementation, separate `matchLabels` entries and `matchExpressions` are alternatives (OR), not combined requirements (AND). See [Select workloads by label](#select-workloads-by-label). |
| **`identities`** | Numeric Cilium identities from `0` through `16777215`. Values in a list are alternatives. |
| **`protocol`** | `tcp`, `udp`, or `dns`. |
| **`verdict`** | `forwarded` or `dropped`. |

Each metric entry needs at least one include or exclude filter. Every filter
must specify traffic-selection criteria, such as a pod name or protocol.

- Within one filter, different populated criteria must match together (AND):
  source and destination selectors, protocol, and verdict. Different selector
  fields on the same endpoint, such as `namespacedPod` and `labelSelector`,
  must also match together. For example,
  `namespacedPod: ["production/checkout-"]` under `from`, together with
  `protocol: ["tcp"]`, selects only TCP traffic from checkout pods in `production`.
- Values within a `namespacedPod`, `ip`, `identities`, `protocol`, or `verdict`
  list are alternatives (OR). For example, `protocol: ["tcp", "udp"]` matches
  either protocol.
- Within each endpoint's `labelSelector`, every `matchLabels` entry and every
  `matchExpressions` item becomes a separate selector. Any one can match (OR).
  Adding another label condition doesn't require both labels.
- With multiple include filters, traffic can match any one of them.
- If traffic matches an exclude filter, it isn't counted even if it also matches
  an include filter.

For example, an include filter for `production/checkout-` and an exclude filter
for `production/checkout-load-test-` selects checkout pods except those whose
names start with `checkout-load-test-`. If you provide only exclude filters, the metric continues to count
other traffic that it normally counts.

For world traffic, identity `2` represents world, `9` represents world IPv4, and `10`
represents world IPv6. Listing `2` doesn't expand to all three. Use the numeric
identity that matches the observed traffic; not every external endpoint necessarily
has a world identity.

For DNS and HTTP metrics, configure protocol inspection separately. A metric
filter alone doesn't make DNS or HTTP details visible.

## Troubleshoot metric configuration

| Symptom | Action |
| --- | --- |
| **The command returns `Forbidden` or a connection error.** | Check your permissions, current Kubernetes context, and cluster connection. These errors don't mean the resource is missing. Resolve the error before changing the configuration. |
| **The API rejects the YAML file.** | Use the resource name `container-network-metric`. Check the metric name and identity range, and include at least one filter that selects traffic. |
| **The resource reports `FAILED`.** | Read `status.reason`. Check for duplicate metric entries or filters without traffic criteria. |
| **A warning mentions cardinality or ingestion cost.** | Additional metrics can create more time series and increase storage costs. Start with a small set of workloads and check how much data is collected. |
| **A warning says a metric isn't in the base configuration.** | Check the cluster's managed metric configuration. This warning isn't a check of whether the workload has the required inspection policy or is generating traffic. |
| **The resource is `CONFIGURED`, but no new observations appear.** | Filter status doesn't verify observation generation. For DNS, apply a DNS inspection policy and generate lookups. For HTTP, enable L7, apply an HTTP inspection policy, and generate HTTP traffic through it. Then check traffic selection, metric-specific counting behavior, and the Prometheus scrape pipeline. |
| **The agent shows samples, but the backend doesn't.** | Check scrape configuration, ingestion delay, cluster selection, and backend label names. An agent scrape doesn't verify backend ingestion. |
| **Old series from excluded workloads are still visible.** | Compare new counter changes during controlled traffic. Filtering doesn't delete historical samples or guarantee immediate removal of existing series. |
| **Label filtering includes more workloads than expected.** | Multiple label entries match independently (OR). Check for pods matching any entry, including in other namespaces. Use one application-specific label condition and combine it with a namespace/pod selector when needed. |
| **An optional metric remains after its entry is removed.** | Check whether the service supplies it. Removing CNM filters doesn't disable a service-provided metric. |
| **World or port counters don't increase.** | Verify destination identity and handler eligibility. World SYN-only counting doesn't include UDP; port distribution doesn't include dropped or reply observations. |

The service manages metric labels. This resource configures filters rather
than custom label sets.

## Restore the previous configuration

If the resource existed before you started, use the saved copy to identify the
settings you changed. Undo only your test changes. Keep any changes that other
administrators made since you saved the copy.

- Removing a `flows-to-world` or `port-distribution` entry disables it only if
  that entry enabled it. A metric already supplied by the service remains enabled.
- Removing a default metric's filter entry restores its default collection behavior.
  It doesn't disable the default metric.

Restore your edits in the working manifest, validate it, and apply it using
[Validate and apply the configuration](#validate-and-apply-the-configuration).
Recheck status and fresh observations. Removing restrictions can increase
collection, so coordinate restoration with the resource's other users.

If you created the resource for this example and no one else now depends on it,
delete it to restore the service's default metric configuration:

```bash
kubectl delete containernetworkmetric container-network-metric
```

Previously collected series remain subject to your backend's retention policy.


## Best practices

* Test filters on a small workload before applying them broadly.
* Review both include and exclude lists; exclusions take precedence.
* Use label or pod selectors for workloads and numeric identities for identity-based selection.
* Review ingestion volume when enabling optional metrics.
* Coordinate changes with other cluster administrators. The resource is shared
  across the cluster, not limited to one namespace.

## Limitations

* Metric filtering requires the Cilium data plane and the prerequisites described earlier in this article.
* Only one `ContainerNetworkMetric` resource is supported per cluster.
* Multiple conditions within one endpoint's `labelSelector` are evaluated as
  alternatives, not as Kubernetes-style AND requirements. This evaluation method applies to
  both include and exclude filters.
* Filters affect new observations; historical data can remain visible.
* The service continues to manage metric dimensions.
* Filters can't make a metric count traffic that its handler excludes.

## Related content

- To learn about container network metrics capabilities, see [Container network metrics overview](container-network-observability-metrics.md).
- To create an AKS cluster with Advanced Container Networking Services, see [Set up Container Network Observability for AKS](container-network-observability-how-to.md).
- For more information, see [Advanced Container Networking Services for AKS](advanced-container-networking-services-overview.md).
