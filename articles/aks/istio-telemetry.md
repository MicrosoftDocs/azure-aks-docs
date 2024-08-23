---
title: Istio-based service mesh add-on telemetry
description: Configure telemetry for Istio-based service mesh add-on for Azure Kubernetes Service.
ms.topic: article
ms.service: azure-kubernetes-service
ms.date: 08/14/2024
ms.author: nshankar
author: niranjanshankar
ms.custom: devx-track-azurecli
---

# Telemetry for Istio-based service mesh add-on for Azure Kubernetes Service

Istio can [generate metrics, distributed traces, and access logs][istio-telemetry-overview] for all workloads in the mesh. The Istio-based service mesh add-on for Azure Kubernetes Service (AKS) provides telemetry customization options through the [shared MeshConfig][istio-meshconfig] and the Istio Telemetry API `v1` for Istio add-on minor revisions `asm-1-22` and higher.

> [!NOTE]
> While the [Istio MeshConfig][istio-meshconfig] also provides options for configuring telemetry globally across the mesh, the Telemetry API offers more granular control over telemetry settings on a per-service or per-workload basis. As the Istio community continues to invest in the Telemetry API, it is now the preferred method for telemetry configuration, with the MeshConfig considered more of a legacy approach. Therefore, we strongly encourage migrating to the Telemetry API for telemetry customization for the Istio add-on. 

## Telemetry API

Telemetry API `v1` is available for the Istio add-on for minor revisions `asm-1-22` and higher.

### Configure Telemetry resources

The following example demonstrates how Envoy access logging can be enabled across the mesh for the Istio add-on via the Telemetry API using `asm-1-22` (adjust the revision as needed). For guidance on other Telemetry API customizations for the add-on, see the [Telemetry API support scope][support-scope-section] section and the [Istio documentation][istio-telemetry-api].

#### Deploy sample applications

Label the namespace for sidecar injection: 

```azurecli-interactive
kubectl label ns default istio.io/rev=asm-1-22
```

Deploy the `sleep` application and set the `SOURCE_POD` environment variable: 

```azurecli-interactive
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.22/samples/sleep/sleep.yaml
export SOURCE_POD=$(kubectl get pod -l app=sleep -o jsonpath={.items..metadata.name})
```

Then, deploy the `httpbin` application:

```azurecli-interactive
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.22/samples/httpbin/httpbin.yaml
```

#### Enable Envoy access logging with the Istio Telemetry API

Deploy the following Istio `v1` Telemetry API resource to enable Envoy access logging for the entire mesh:

```azurecli-interactive
cat <<EOF | kubectl apply -n aks-istio-system -f -
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: mesh-logging-default
spec:
  accessLogging:
  - providers:
    - name: envoy
EOF
```

#### Test access logs

Send a request from `sleep` to `httpbin`:

```azurecli-interactive
kubectl exec "$SOURCE_POD" -c sleep -- curl -sS -v httpbin:8000/status/418
```

Verify that access logs are visible for the `sleep` pod:

```azurecli-interactive
kubectl logs -l app=sleep -c istio-proxy
```

You should see the following output:

```bash
[2024-08-13T00:31:47.690Z] "GET /status/418 HTTP/1.1" 418 - via_upstream - "-" 0 135 12 11 "-" "curl/8.9.1" "cdecaca5-5964-48f3-b42d-f474dfa623d5" "httpbin:8000" "10.244.0.13:8080" outbound|8000||httpbin.default.svc.cluster.local 10.244.0.12:53336 10.0.112.220:8000 10.244.0.12:42360 - default
```

Now, verify that access logs are visible for the `httpbin` pod:

```azurecli-interactive
kubectl logs -l app=httpbin -c istio-proxy
```

You should see the following output:

```bash
[2024-08-13T00:31:47.696Z] "GET /status/418 HTTP/1.1" 418 - via_upstream - "-" 0 135 2 1 "-" "curl/8.9.1" "cdecaca5-5964-48f3-b42d-f474dfa623d5" "httpbin:8000" "10.244.0.13:8080" inbound|8080|| 127.0.0.6:55401 10.244.0.13:8080 10.244.0.12:53336 outbound_.8000_._.httpbin.default.svc.cluster.local default
```
### Telemetry API support scope

For the Istio service mesh add-on for AKS, Telemetry API fields are classified as `allowed`, `supported`, and `blocked` values. For more information about the Istio add-on's support policy for features and mesh configurations, see the Istio add-on [support policy document][istio-support-policy].

The following Telemetry API configurations are either `allowed` or `supported` for the Istio add-on. Any field not included in this table is `blocked`. 

| **Telemetry API Field** | **Supported/Allowed** | **Notes** |
|-------------------------|-----------------------|-----------|
| `accessLogging.match` | Supported | - |
| `accessLogging.disabled` | Supported | - |
| `accessLogging.providers` | Allowed | The default `envoy` access log provider is supported. For a managed experience for log collection and querying, see [Azure Monitor Container Insights Log Analytics][az-monitor-container-insights]. Third-party or open-source log collection and analytics solutions are `allowed` but unsupported. |
| `metrics.overrides` | Supported | - |
| `metrics.providers` | Allowed | Metrics collection with [Azure Monitor Managed Prometheus][az-monitor-metrics] is supported. Third-party or open-source metrics scraping solutions are `allowed` but unsupported. |
| `tracing.*` | Allowed | All tracing configurations are `allowed` but unsupported. |

<!-- LINKS - External -->
[istio-telemetry-overview]: https://istio.io/latest/docs/concepts/observability/
[istio-telemetry-api]: https://istio.io/latest/docs/reference/config/telemetry/
[istio-feature-status]: https://istio.io/latest/docs/releases/feature-stages/#feature-phase-definition
[istio-releases]: https://istio.io/latest/news/releases/

<!-- LINKS - internal -->
[istio-meshconfig]: ./istio-meshconfig.md
[support-scope-section]: #telemetry-api-support-scope
[istio-support-policy]: ./istio-support-policy.md#allowed-supported-and-blocked-customizations
[az-monitor-container-insights]: /azure/azure-monitor/containers/container-insights-overview
[az-monitor-metrics]: /azure/azure-monitor/containers/kubernetes-monitoring-enable
