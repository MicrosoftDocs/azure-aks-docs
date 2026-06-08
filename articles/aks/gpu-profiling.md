---
title: Optimize GPU workloads on AKS with profiling (Preview)
description: Learn how to profile GPU workloads with real-time observability and analyze flamegraphs to identify memory hotspots to optimize GPU workloads.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.subservice: aks-developer
ms.date: 06/01/2026
author: mayasingh
ms.author: mayasingh
ai-usage: ai-assisted
# Customer intent: As a platform engineer, I want to profile GPU workloads on AKS, so that I can identify memory allocation hotspots, optimize resource usage, and troubleshoot performance regressions in GPU based workloads.
---

# Optimize GPU workloads on AKS with profiling (Preview)

GPU based workloads such as AI inference services can be memory-intensive and difficult to optimize and debug without deep visibility into what the GPU is actually doing. You might see out-of-memory (OOM) errors, unexpected latency spikes, or rising GPU memory pressure, but traditional Kubernetes metrics don't tell you *where* in the code the memory is being allocated. Profiling helps you understand the exact functions responsible for GPU memory usage.

[!INCLUDE [preview features callout](./includes/preview/preview-callout.md)]

This article walks you through how to use GPU observability on AKS:

1. **Deploy real-time GPU observability agent** — use eBPF-based instrumentation to trace and profile GPU memory allocations.
2. **Read flamegraphs** — learn how to interpret the profiling output to find the exact functions consuming the most GPU memory.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## Deploy advanced GPU observability - GPU memory profiling on AKS

### Prerequisites

- An AKS cluster with at least one GPU-enabled node pool.
- [Azure CLI][install-azure-cli] version 2.72.0 or later installed. Run `az --version` to check.
- [Helm][helm-install] version 3.x or later installed. Run `helm version` to check.
- Azure Monitor (optional, can use your own monitoring setup if preferred)
- Azure Managed Grafana (optional, for visualization)


### Step 1: Install Inspektor Gadget

[Inspektor Gadget](https://inspektor-gadget.io/) is an open source eBPF-based observability framework for Kubernetes. For GPU profiling, it traces CUDA memory allocation calls without requiring code changes, sidecars, or pod restarts.

```bash
helm install -n gadget inspektor-gadget \
  oci://mcr.microsoft.com/microsoft.inspektor-gadget/helmcharts/inspektor-gadget:0.53.0-0 \
  --set gpuObservability.enabled=true \
  --set azureMonitor.enabled=true
```

> [!NOTE]
> This step assumes you have already enabled Azure Monitor on your AKS cluster. If you plan to use your own Prometheus setup, remove `--set azureMonitor.enabled=true`.

Verify that pods are running:

```bash
kubectl get pods -n gadget -l k8s-app=gadget
```

### Step 2: Enable profile visualization with Pyroscope

[Pyroscope](https://pyroscope.io/) is an open source project that lets you visualize and store performance profiles, which are needed for memory optimization and troubleshooting. Run the following command to deploy Pyroscope in your cluster:

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

> [!NOTE]
> If you have an existing Grafana/Pyroscope stack in your cluster, you can skip this step.

Verify that pods are running:

```bash
kubectl get pods -n gadget pyroscope-0
```

### Step 3: Connect Pyroscope to Azure Managed Grafana

> [!TIP]
> You can directly view your workload profiles using `kubectl port-forward -n gadget pyroscope-0 4040:4040` to connect to the Pyroscope UI.

Connecting Pyroscope to Azure Managed Grafana enables you to visualize the GPU profiles in Grafana dashboards. Start by setting up cluster-related environment variables:

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
> These steps are based on [Connect Azure Monitor managed service for Prometheus to Grafana](/azure/azure-monitor/metrics/prometheus-grafana?tabs=azure-managed-grafana).

Export the required variables:

```bash
export AMP_NAME="<your-amp-workspace-name>"
export RESOURCE_GROUP="<your-resource-group>"
```

> [!TIP]
> Run `az resource list --resource-type Microsoft.Monitor/accounts -g $RESOURCE_GROUP -o table` to list Azure Monitor workspace information.

```bash
# Get AMW endpoint
AMP_ENDPOINT=$(az resource show --resource-type Microsoft.Monitor/accounts \
  -n "$AMP_NAME" -g "$RESOURCE_GROUP" \
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
  --definition "$(curl -sSL https://gist.githubusercontent.com/mqasimsarfraz/1f1b7dbacaba37ee295b1dc495137882/raw/36ea17344a1f5b426291a4705da836258ece8c56/AdvancedGPUObservability.json)"
```

Access the dashboard at:

```bash
GRAFANA_URL=$(az grafana show -n "$GRAFANA_NAME" -g "$RESOURCE_GROUP" --query properties.endpoint -o tsv)

echo "${GRAFANA_URL}/d/AdvancedGPUObservability"
```

For more information about reading the flamegraphs shown in Grafana, see [Reading flamegraphs](#reading-flamegraphs).

### Clean up resources

To remove the in-cluster GPU observability stack:

```bash
helm uninstall inspektor-gadget -n gadget
helm uninstall pyroscope -n gadget
kubectl delete namespace gadget
```

## Reading flamegraphs

After profiling data is flowing into Pyroscope and Grafana, you'll see flamegraphs showing which functions consume the most GPU memory. The following sections explain how to read these visualizations.

### What is a flamegraph?

A flamegraph is a visualization of profiled call stacks. Each bar represents a function, and bars are stacked to show the call chain — who called whom. The width of each bar represents the amount of the measured resource (CPU time, GPU memory allocated, and so on) that flows through that function.

**Key rule**: The wider a bar, the more of the measured resource flows through that function.

> [!TIP]
> Use **Expand all groups** in Grafana's flamegraph panel to see the full call stack without collapsing. Use the **Search** box to find specific functions or keywords.

:::image type="content" source="media/gpu-profiling/flamegraph2.png" alt-text="Description of the flamegraph.":::

### Read the symbols

Flamegraph labels follow these conventions:

| Symbol format | Meaning |
|---|---|
| `Foo` → `bar` | `class Foo: method def bar()` |
| `Foo` → `__init__` | Constructor of class `Foo` |
| `bar` (alone) | Standalone `def bar()` function |
| `Foo` → `bar` → `<locals>` → `baz` | Nested function `baz()` inside `Foo.bar()` |
| `<locals>` → `<lambda>` | Anonymous lambda inside a function |
| `<interpreter trampoline>` | CPython overhead — ignore |
| `<unknown>` | Native C/CUDA code — no Python symbol available |

**Examples:**

- `GPUModelRunner` / `_allocate_kv_cache_tensors` — A method on a class. Reads as `class GPUModelRunner: def _allocate_kv_cache_tensors(self)`.
- `LlamaMLP` / `__init__` — A constructor. Called when creating a `LlamaMLP(...)` object.
- `_compile_fx_inner` — A standalone module-level function not inside any class.

### Understand self vs total

This is the most important concept when analyzing flamegraphs.

- **Total** — the resource consumed by a function *plus everything it calls*. A function can have a large total but allocate nothing itself — it's just a call chain.
- **Self** — the resource consumed *directly* by the function, excluding its children. A high self value means this function is where the resource is actually consumed.

Example: GPUModelRunner._allocate_kv_cache_tensors has 55.1 GB self — it's the function that actually calls torch.empty() to create the KV cache tensors.

**Navigation tips:**

- **Leaf nodes** (bars with nothing above them) — their entire width is self. Start here to find allocation hotspots.
- **Wide bar with 0 self** — an orchestrator function that just calls others. Safe to skip when hunting for allocations.
- **Wide bar with high self** — your optimization target.

### Find the biggest resource consumer

Use the following steps to identify hotspots:

1. **Look at the widest bars at the TOP of the graph** — These are leaf functions where memory is actually being allocated, the wider the bar the more it consumes.
1. **Check self vs total** — A wide bar at the bottom with `self: 0` is just a call chain. Follow it upward until you find a bar with high self allocation.
1. **Read the call stack bottom-to-top** — The ordering tells you why the function was called. For example:

    ```
    <unknown>                               → native process entry
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
| Optimization targets | Bars with wide self — that's where the resource is consumed |
| Functions to ignore | Wide bars with 0 self — they just call others |


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
