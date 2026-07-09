---
title: Optimize GPU workloads on AKS with GPU profiling (Preview)
description: Learn how to profile GPU workloads with real-time observability and analyze flame graphs to identify memory hotspots to optimize GPU workloads.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.subservice: aks-developer
ms.date: 06/01/2026
author: mayasingh17
ms.author: mayasingh
ai-usage: ai-assisted
# Customer intent: As a platform engineer, I want to profile GPU workloads on AKS, so that I can identify memory allocation hotspots, optimize resource usage, and troubleshoot performance regressions in GPU based workloads.
---

# Optimize GPU workloads on Azure Kubernetes Service (AKS) with GPU profiling (Preview)

GPU based workloads such as AI inference services can be memory-intensive and difficult to optimize and debug without deep visibility into what the GPU is actually doing. You might see out-of-memory (OOM) errors, unexpected latency spikes, or rising GPU memory pressure, but traditional Kubernetes metrics don't tell you *where* in the code the memory is being allocated. Profiling helps you understand the exact functions responsible for GPU memory usage.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

This article walks you through how to use GPU observability on AKS:

1. **Deploy real-time GPU observability agent**—use eBPF-based instrumentation to trace and profile GPU memory allocations.
1. **Read flame graphs**—learn how to interpret the profiling output to find the exact functions consuming the most GPU memory.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## Deploy GPU observability - GPU memory profiling on AKS

### Prerequisites

- An AKS cluster with at least one GPU-enabled node pool.
- [Azure CLI][install-azure-cli] version 2.72.0 or later installed. Run `az --version` to check.
- The `k8s-extension` Azure CLI add-on installed. Run `az extension add --name k8s-extension` to install.
- [Helm][helm-install] version 3.x or later installed. Run `helm version` to check.
- Azure Monitor (optional, can use your own monitoring setup if preferred).
- Azure Managed Grafana (optional, for visualization).


### Step 1: Enable GPU profiling via the Inspektor Gadget extension

[Inspektor Gadget](https://inspektor-gadget.io/) is an open source eBPF-based observability framework for Kubernetes. For GPU profiling, it traces Compute Unified Device Architecture (CUDA) memory allocation calls without requiring code changes, sidecars, or pod restarts. Enable GPU profiling on your AKS cluster by running the following extension command:

```bash
az k8s-extension create \
  --extension-type microsoft.inspektorgadget \
  --subscription <your-subscription-id> \
  -g <your-resource-group> \
  -c <your-cluster-name> \
  -t managedClusters \
  --release-train preview \
  -n inspektor-gadget \
  --configuration-settings gpuObservability.enabled=true \
  --configuration-settings azureMonitor.enabled=true \
```

> [!NOTE]
> This step assumes you already enabled Azure Monitor on your AKS cluster. If you plan to use your own Prometheus setup, remove `--configuration-settings azureMonitor.enabled=true`.

Verify that pods are running:

```bash
kubectl get pods -n gadget -l k8s-app=gadget
```

> [!TIP]
> GPU memory profiling captures memory allocation events as they occur. If your workload allocates GPU memory before GPU profiling is enabled, the profiler doesn't capture those allocation events. For workloads such as vLLM that pre-allocate GPU memory during startup, enable GPU profiling before deploying the workload, or restart the workload to capture initial memory allocation paths.

### Step 2: Enable profile visualization with Pyroscope

> [!NOTE]
> If you have an existing Grafana/Pyroscope stack in your cluster, you can skip this step.

[Pyroscope](https://pyroscope.io/) is an open source project that lets you visualize and store performance profiles, which are needed for memory optimization and troubleshooting. Run the following command to deploy a single [Pyroscope instance to your cluster](https://grafana.com/docs/pyroscope/latest/deploy-kubernetes/helm/):

```bash
helm install pyroscope -n gadget \
  oci://ghcr.io/grafana/helm-charts/pyroscope \
  --version 1.15.0 \
  --set pyroscope.image.repository=grafana/pyroscope \
  --set-string pyroscope.image.tag=1.15.0 \
  --set pyroscope.replicaCount=1 \
  --set pyroscope.structuredConfig.self_profiling.disable_push=true \
  --set pyroscope.structuredConfig.storage.backend=filesystem \
  --set pyroscope.service.type=LoadBalancer \
  --set pyroscope.service.port=4040 \
  --set-string pyroscope.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-internal"=true \
  --set-string pyroscope.service.annotations."service\.beta\.kubernetes\.io/azure-pls-create"=true \
  --set-string pyroscope.service.annotations."service\.beta\.kubernetes\.io/azure-pls-name"=pyroscope-pls \
  --set-string pyroscope.service.annotations."service\.beta\.kubernetes\.io/azure-pls-proxy-protocol"=false \
  --set-string pyroscope.service.annotations."service\.beta\.kubernetes\.io/azure-pls-visibility"='*' \
  --set alloy.enabled=false \
  --set minio.enabled=false
```

Verify that pods are running:

```bash
kubectl get pods -n gadget pyroscope-0
```
> [!NOTE]
> If you would like to deploy a highly available Pyroscope setup, refer to the [Pyroscope microservices documentation](https://grafana.com/docs/pyroscope/latest/reference-pyroscope-architecture/deployment-modes/#microservices-mode) for configuration options.

### Step 3: Connect Pyroscope to Azure Managed Grafana

> [!TIP]
> You can directly view your workload profiles using `kubectl port-forward -n gadget pyroscope-0 4040:4040` to connect to the Pyroscope UI.

Connecting Pyroscope to Azure Managed Grafana enables you to visualize the GPU profiles in Grafana dashboards. We need a secure way for AMG to connect to Pyroscope running as a Kubernetes pod, so we'll establish the connection using [Azure Private Link](/azure/private-link/private-link-service-overview). Start by setting up cluster-related environment variables:

```bash
export RESOURCE_GROUP="<your-resource-group>"
export AKS_CLUSTER="<your-aks-cluster-name>"
export LOCATION="<your-aks-cluster-location>"
export GRAFANA_NAME="<your-azure-managed-grafana-name>"
export AKS_NODE_RG=$(az aks show -g "$RESOURCE_GROUP" -n "$AKS_CLUSTER" --query 'nodeResourceGroup' -o tsv)
```

> [!TIP]
> If you don't have an existing Azure Managed Grafana instance, run `az grafana create -n "$GRAFANA_NAME" -g "$RESOURCE_GROUP" --location "$LOCATION" -o none` to create one.

Create a private endpoint to connect Pyroscope to Azure Managed Grafana. Export variables for the private endpoint:

```bash
export PYROSCOPE_PLS="pyroscope-pls"
export PYROSCOPE_MPE="pyroscope-mpe"
export PYROSCOPE_PORT="4040"
```

Create the private link:

> [!NOTE]
> Creating the private link can take a few minutes.

```bash
# Check amg extension version
ver=$(az extension show --name amg --query version -o tsv)
[[ "${ver%%.*}" -ge 3 ]] && MPE="managed-private-endpoint" || MPE="mpe"

# Ensure Pyroscope PLS is present
until az network private-link-service show -n "$PYROSCOPE_PLS" -g "$AKS_NODE_RG" -o none 2>/dev/null; do
  sleep 10
done

# Get the PLS resource ID
PYRO_PLS_ID=$(az network private-link-service show \
  -n "$PYROSCOPE_PLS" -g "$AKS_NODE_RG" --query 'id' -o tsv)

# Create the MPE in Grafana
az grafana $MPE create \
  --workspace-name "$GRAFANA_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$PYROSCOPE_MPE" \
  --private-link-resource-id "$PYRO_PLS_ID" \
  --location "$LOCATION" -o none

# Wait for MPE to be ready
sleep 30

# Find the pending connection created by Grafana
PYRO_CONN=$(az network private-link-service show \
  -n "$PYROSCOPE_PLS" -g "$AKS_NODE_RG" \
  --query "privateEndpointConnections[?privateLinkServiceConnectionState.status=='Pending' && starts_with(name, 'grafana-${GRAFANA_NAME}')].name | [0]" -o tsv)

# Approve it
az network private-link-service connection update \
  --name "$PYRO_CONN" \
  --service-name "$PYROSCOPE_PLS" \
  --resource-group "$AKS_NODE_RG" \
  --connection-status Approved -o none

# Refresh Grafana so it sees the approval
az grafana $MPE refresh \
  --workspace-name "$GRAFANA_NAME" \
  --resource-group "$RESOURCE_GROUP" -o none

echo "Successfully created private-link"
```

Create the data source in Azure Managed Grafana:

```bash
# Check amg extension version
ver=$(az extension show --name amg --query version -o tsv)
[[ "${ver%%.*}" -ge 3 ]] && MPE="managed-private-endpoint" || MPE="mpe"

# Grab the private IP
PYRO_IP=$(az grafana $MPE show \
  --workspace-name "$GRAFANA_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$PYROSCOPE_MPE" \
  --query 'privateLinkServicePrivateIP' -o tsv)

# Prepare Pyroscope URL
export PYROSCOPE_URL="http://${PYRO_IP}:${PYROSCOPE_PORT}"

# Create Pyroscope data source in Grafana
az grafana data-source create -n "$GRAFANA_NAME" -g "$RESOURCE_GROUP" --definition "{
  \"name\": \"local-pyroscope\",
  \"uid\": \"local-pyroscope\",
  \"type\": \"grafana-pyroscope-datasource\",
  \"access\": \"proxy\",
  \"url\": \"${PYROSCOPE_URL}\",
  \"jsonData\": { \"keepCookies\": [\"pyroscope_git_session\"] }
}" -o none

echo "Successfully created local-pyroscope data-source"
```

> [!NOTE]
> If you have an existing Grafana/Pyroscope stack in your cluster, you can skip this step.

Verify the data source has a valid URL:

```bash
az grafana data-source show -n $GRAFANA_NAME --data-source local-pyroscope
```

### Step 4: Connect Grafana to Azure Monitor managed service for Prometheus

> [!NOTE]
> These steps are based on [Connect Azure Monitor managed service for Prometheus to Grafana](/azure/azure-monitor/metrics/prometheus-grafana?tabs=azure-managed-grafana). Make sure Grafana's managed identity has the **Monitoring Data Reader** role on the Azure Monitor workspace, especially if it's in a different resource group or subscription.

Export the required variables:

```bash
export AMP_NAME="<your-amp-workspace-name>"
export AMP_RESOURCE_GROUP="<your-amp-resource-group>"
```

> [!TIP]
> Run `az resource list --resource-type Microsoft.Monitor/accounts -g $AMP_RESOURCE_GROUP -o table` to list Azure Monitor workspace information. The Azure Monitor workspace is often in a different resource group than your AKS cluster and Azure Managed Grafana instance—for example, when Managed Prometheus auto-creates a workspace in a regional `MA_<region>_<…>` resource group, or when a central platform team owns a shared workspace. To search across the subscription instead, omit `-g` and run `az resource list --resource-type Microsoft.Monitor/accounts -o table`.

```bash
# Get AMW endpoint
AMP_ENDPOINT=$(az resource show --resource-type Microsoft.Monitor/accounts \
  -n "$AMP_NAME" -g "$AMP_RESOURCE_GROUP" \
  --query properties.metrics.prometheusQueryEndpoint -o tsv)

# Create Prometheus data source with MSI auth
az grafana data-source create -n "$GRAFANA_NAME" -g "$RESOURCE_GROUP" \
  --definition "{
    \"name\": \"$AMP_NAME\",
    \"type\": \"prometheus\",
    \"access\": \"proxy\",
    \"url\": \"$AMP_ENDPOINT\",
    \"jsonData\": {
      \"httpMethod\": \"POST\",
      \"azureCredentials\": { \"authType\": \"msi\" }
    }
  }"
```

Verify the data source:

```bash
az grafana data-source show -n $GRAFANA_NAME --data-source $AMP_NAME
```

### Step 5: Set up dashboards in Grafana

```bash
az grafana dashboard create \
  -n "$GRAFANA_NAME" \
  -g "$RESOURCE_GROUP" \
  --definition "$(curl -sSL https://raw.githubusercontent.com/inspektor-gadget/grafana-dashboards/refs/heads/main/dashboards/gpu-observability/AdvancedGPUObservability.json)"
```

Access the dashboard at:

```bash
GRAFANA_URL=$(az grafana show -n "$GRAFANA_NAME" -g "$RESOURCE_GROUP" --query properties.endpoint -o tsv)

echo "${GRAFANA_URL}/d/AdvancedGPUObservability"
```

For more information about reading the flame graphs shown in Grafana, see [Reading flame graphs](#reading-flame-graphs).

### Clean up resources

To remove the in-cluster GPU observability stack:

```bash
helm uninstall inspektor-gadget -n gadget
helm uninstall pyroscope -n gadget
kubectl delete namespace gadget
```

## Reading flame graphs

After profiling data is flowing into Pyroscope and Grafana, you'll see flame graphs showing which functions consume the most GPU memory. The following sections explain how to read these visualizations.

### What is a flame graph?

A flame graph is a visualization of profiled call stacks. Each bar represents a function, and bars are stacked to show the call chain, who called whom. The width of each bar represents the amount of the measured resource (CPU time, GPU memory allocated, and so on) that flows through that function.

**Key rule**: The wider a bar, the more of the measured resource flows through that function.

The following sample flame graphs are captured from a vLLM inference workload.

:::image type="content" source="media/gpu-profiling/flame-graph-initial.png" alt-text="Screenshot of the initial collapsed flame graph view in Grafana for a vLLM workload, showing stacked bars that represent GPU memory allocation call stacks." lightbox="media/gpu-profiling/flame-graph-initial.png":::

> [!TIP]
> Use **Expand all groups** in Grafana's flame graph panel to see the full call stack without collapsing. Use the **Search** box to find specific functions or keywords. To prevent the panel from collapsing again, pause the dashboard auto-refresh (set the refresh interval to **Off** in the top-right of the Grafana dashboard) while you inspect the expanded flame graph.

:::image type="content" source="media/gpu-profiling/flame-graph-expanded.png" alt-text="Screenshot of the flame graph in Grafana for a vLLM workload after selecting Expand all groups, showing the full call stack with individual function frames for GPU memory allocations." lightbox="media/gpu-profiling/flame-graph-expanded.png":::

> [!TIP]
> Use **Focus block** to focus on a specific allocation path.

### Read the symbols

Flame graph labels follow these conventions:

| Symbol format | Meaning |
|---|---|
| `Foo` → `bar` | `class Foo: method def bar()` |
| `Foo` → `__init__` | Constructor of class `Foo` |
| `bar` (alone) | Standalone `def bar()` function |
| `<interpreter trampoline>` | CPython overhead—ignore |
| `<raw-address>` e.g `0x7f151` | Native C/CUDA code—no Python symbol available |

**Examples:**

- `GPUModelRunner` / `_allocate_kv_cache_tensors`—A method on a class. Reads as `class GPUModelRunner: def _allocate_kv_cache_tensors(self)`.
- `LlamaMLP` / `__init__`—A constructor. Called when creating a `LlamaMLP(...)` object.
- `_compile_fx_inner`—A standalone module-level function not inside any class.

### Understand self vs total

This understanding is the most important concept when analyzing flame graphs.

- **Total**—the resource consumed by a function *plus everything it calls*. A function can have a large total but allocate nothing itself—it's just a call chain.
- **Self**—the resource consumed *directly* by the function, excluding its children. A high self value means this function is where the resource is actually consumed.

Example: GPUModelRunner._allocate_kv_cache_tensors has 55.1 GB self—it's the function that actually calls torch.empty() to create the KV cache tensors.

**Navigation tips:**

- **Leaf nodes** (bars with nothing above them)—their entire width is self. Start here to find allocation hotspots.
- **Wide bar with 0 self**—an orchestrator function that just calls others. Safe to skip when hunting for allocations.
- **Wide bar with high self**—your optimization target.

### Find the biggest resource consumer

Use the following steps to identify hotspots:

* **Look at the widest bars at the TOP of the graph**—These are leaf functions where memory is actually being allocated, the wider the bar the more it consumes.
* **Check self vs total**—A wide bar at the bottom with `self: 0` is just a call chain. Follow it upward until you find a bar with high self allocation.
* **Read the call stack bottom-to-top**—The ordering tells you why the function was called. For example:
  ```
    <raw-address> e.g 0x7f151               → native code entry
    <interpreter trampoline>                → CPython dispatch
    <module>                                → script top-level
    EngineCoreProc.run_engine_core          → vLLM engine startup
    EngineCore.__init__                     → engine initialization
    EngineCore._initialize_kv_caches        → KV cache setup
    Worker.initialize_from_config           → worker setup
    GPUModelRunner.initialize_kv_cache      → model runner
    GPUModelRunner._allocate_kv_cache_tensors → 💥 actual allocation
  ```

| Goal | What to look for |
|---|---|
| What allocates the most | Widest leaf bar (top of stack) |
| What's responsible for the most | Widest bar (bottom of stack) |
| Optimization targets | Bars with wide self—that's where the resource is consumed |
| Functions to ignore | Wide bars with 0 self—they just call others |


## Next steps

- [Use NVIDIA GPU Operator on AKS](./nvidia-gpu-operator.md)
- [AKS-managed GPU nodes (preview)](./aks-managed-gpu-nodes.md)
- [Monitor AI inference metrics on AKS with the AI toolchain operator](./ai-toolchain-operator-monitoring.md)
- [Grafana Pyroscope documentation](https://grafana.com/docs/pyroscope/latest/)

<!-- Links -->
[install-azure-cli]: /cli/azure/install-azure-cli
[helm-install]: https://helm.sh/docs/intro/install/
[azure-pricing]: https://azure.microsoft.com/pricing/calculator/
[azure-availability]: https://azure.microsoft.com/global-infrastructure/services/?products=kubernetes-service
