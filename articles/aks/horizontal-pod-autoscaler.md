---
title: Horizontal Pod Autoscaling (HPA) on Azure Kubernetes Service (AKS)
description: Guidance on when and why to use the Kubernetes Horizontal Pod Autoscaler (HPA) on Azure Kubernetes Service (AKS), how it works, when not to use it, comparison with Vertical Pod Autoscaler (VPA), and step‑by‑step configuration and operational notes for AKS.
ms.topic: overview
ms.service: azure-kubernetes-service
ms.date: 07/23/2026
author: schaffererin
ms.author: schaffererin
ai-usage: ai-assisted
---

# When should I use Horizontal Pod Autoscaling (HPA) in Kubernetes?

**Short answer**: Use HPA when your workload can run multiple identical replicas and demand fluctuates — scale on CPU/memory, application metrics (RPS/latency), or external queue/backlog metrics. Don’t use HPA for single‑replica stateful services or when the real bottleneck is node capacity or downstream limits (DB connections, third‑party rate limits).

**TL;DR**:

- Use HPA for horizontally partitionable workloads where per-pod or external metrics reflect load.
- Use resource/custom/external metrics (CPU, RPS, queue depth); combine with Cluster Autoscaler for node capacity.
- Use KEDA for event-driven scale-to-zero or external scalers; use VPA in recommendation mode for request sizing.

**Quick decision checklist (Yes/No)**:

- Is the workload stateless or partitionable across many replicas? (Yes → HPA candidate)
- Can you observe load as a per-pod or external metric (CPU, requests/sec, queue depth)? (Yes → HPA appropriate)
- Can the cluster schedule more pods (Cluster Autoscaler or spare capacity)? (Yes → proceed; if No, enable node autoscaling)
- Do downstream services (DB pools, third‑party APIs) limit concurrency? (Yes → add throttling/connection pooling or prefer vertical scaling)

**Decision matrix (workload → best metric → recommended scaler)**:

| Workload type | Best metric to target | Recommended scaler |
| --- | --- | --- |
| Web/API (stateless) | CPU or RPS per pod | HPA (+VPA recommendation + Cluster Autoscaler) |
| Background queue worker | Queue length or messages/sec | HPA via external metrics or KEDA (KEDA supports scale-to-zero) |
| Single-instance DB or stateful app | N/A (not horizontally partitionable) | VPA or manual scaling |
| Batch/Ephemeral event workers | Event backlog | KEDA or HPA with external metrics |

---

## How HPA works (simple control loop & important fields)

- Components: the HPA controller (control plane) + metric providers (metrics-server for resource metrics, custom/external metrics API via adapters or KEDA).
- Control loop (high level): HPA controller polls the metrics API → computes desiredReplicas from each configured metric → takes the largest computed desiredReplicas → applies min/max and behavior (policies/stabilization) → updates spec.replicas on the target resource → repeat. See the [Kubernetes HPA docs](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/) for details.
- Formula (how desired replicas are calculated): desiredReplicas = ceil(current_total / target_per_pod). The controller computes a desiredReplicas for each configured metric, then uses the largest value before applying min/max and behavior (this metric-precedence behavior is documented in the [HPA docs](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/)).
- Important autoscaling/v2 fields: minReplicas, maxReplicas, metrics (Resource, Pods, Object, External), behavior (scaleUp/scaleDown policies and stabilizationWindowSeconds).
- Use behavior to limit rate-of-change and avoid flapping; stabilizationWindowSeconds is a key knob for scaleDown smoothing.

### Example behavior snippet (autoscaling/v2)

```yml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 0
    policies:
      - type: Percent
        value: 100
        periodSeconds: 60
  scaleDown:
    stabilizationWindowSeconds: 300
    policies:
      - type: Pods
        value: 1
        periodSeconds: 60
```

---

## When to use HPA (by metric type / common use cases)

1. CPU / memory (Resource metrics)
   - Use HPA when per-pod CPU or memory utilization correlates with capacity needs and pods define correct resource requests. Typical for web APIs and stateless microservices.
   - Practical starting point: target average CPU utilization in the 60–80% range and tune by load testing. HPA computes utilization from pod requests, so requests must be set.
1. Custom in-cluster metrics (Prometheus / custom metrics)
   - Use HPA when app-level signals (requests/sec, latency, queue consumers/pod) better represent load than CPU.
   - Expose metrics with Prometheus + prometheus-adapter (custom.metrics.k8s.io) or another custom metrics provider and target those metrics in HPA.
1. External metrics (queues, cloud backlogs)
   - Use HPA (via external metrics API) or KEDA when scaling should react to external signals like queue length (RabbitMQ, Azure Service Bus), Event Hubs, or cloud monitoring metrics.
   - If you need scale-to-zero or tight event-driven behavior, prefer KEDA — it natively integrates external scalers and supports scale-to-zero ([KEDA docs](https://keda.sh/docs/latest/)).

## When NOT to use HPA

- Single-replica stateful services (databases, in-pod unique state): HPA is not appropriate unless you can shard/partition safely.
- When the bottleneck is at the node level (GPU, disk I/O, node CPU) rather than per-pod: prefer node pool autoscaling or vertical scaling.
- When downstream systems (DB connection pools, caches, third‑party APIs) have strict concurrency limits: scaling pods without increasing downstream capacity can worsen failures — see "Downstream & operational considerations" below.
- If you require scale-to-zero, plain HPA cannot achieve that; use KEDA or an external controller.

---

## Multiple metrics, precedence, and an example

- If you configure multiple metrics, the HPA controller computes a desiredReplicas value for each metric independently and then selects the largest desiredReplicas as the basis for scaling. After that, minReplicas/maxReplicas and behavior policies are applied (source: [Kubernetes HPA docs](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/)).
- Example: CPU target computes 5 replicas, requests/sec target computes 12 replicas → HPA will pick 12 (then min/max and behavior policies may modify the final applied change).
- To avoid sudden overshoot, combine a percent-based scaleUp policy and a reasonable scaleDown stabilizationWindowSeconds (see behavior snippet above).

---

## HPA vs VPA vs Cluster Autoscaler vs KEDA (short guidance)

- HPA: horizontally scales replicas based on metrics. Best for partitionable workloads.
- VPA: adjusts pod resource requests/limits (vertical). Best for non-parallelizable workloads or to set sensible defaults.
- Cluster Autoscaler (or Karpenter): scales nodes to satisfy scheduling requests (node-level capacity). Use when pods remain Pending due to lack of nodes.
- KEDA: event-driven autoscaler that integrates external triggers and supports scale-to-zero for event workloads.

Common pattern: use VPA in recommendation mode to set baseline requests, HPA to scale replicas, and Cluster Autoscaler (or Karpenter) to provide node capacity. Use KEDA when you need scale-to-zero or direct integration with external event sources.

Note: managed Kubernetes offerings (AKS/GKE/EKS) may preinstall metrics providers or provide integrated autoscaler features. [AKS Cluster Autoscaler docs](./cluster-autoscaler-overview.md)

---

## Downstream & operational considerations (common gotchas)

- Database connection pools: increasing replicas increases simultaneous connections. Mitigate with connection pooling (e.g., PgBouncer), limiting per-pod concurrency, or increasing DB pool size before scaling pods.
- API rate limits and third-party quotas: ensure downstream systems can handle the request volume that scaled pods produce; consider client-side throttling.
- PodDisruptionBudgets (PDBs): PDBs don’t prevent HPA scaling up, but can affect maintenance operations and drain behavior; ensure scaling policies align with PDBs.
- Startup and warm-up effects: initContainers, cache warm-up, or long cold starts can skew metrics and cause oscillation — use readiness/startup probes and stabilization windows.
- Recommended operational approach: set conservative scaling rates, tune requests/limits and probes, test in non-prod, and add SLO-aware throttling if downstream systems are a bottleneck.

---

## Configuration checklist & safe rollout steps

Ensure metrics and RBAC:

- Deploy metrics-server for resource metrics (or use managed provider).
- Deploy Prometheus + prometheus-adapter for custom metrics (custom.metrics.k8s.io) if needed.
- For external/event scalers, consider KEDA.

Write HPA (autoscaling/v2) with:

- minReplicas and maxReplicas,
- explicit metrics and behavior (scaleUp/scaleDown policies),
- readiness and startup probes on pods,
- sensible resource requests so resource metrics are meaningful.

Safe testing checklist (how to test HPA safely):

1. Test in a non-production namespace/cluster with similar node sizes and autoscaling enabled.
1. Start with conservative min/max replicas and gentle scaleUp policies (e.g., max 100% growth/minute).
1. Run gradual load tests, monitor desiredReplicas vs currentReplicas and Pending pods.
1. Iterate on requests/limits, readiness probes, and behavior policies before increasing aggressiveness.

AKS & node autoscaling notes:

- AKS and other cloud offerings may preinstall metrics-server or offer managed autoscaler integration. Example AKS CLI to enable cluster autoscaler: `az aks nodepool update --resource-group myRG --cluster-name myAKS --name node-pool1 --enable-cluster-autoscaler --min-count 1 --max-count 5`

Karpenter note: Karpenter is an alternative node-autoscaling approach focused on fast provisioning; consider it when rapid node provisioning is required.

---

## Working YAML examples

CPU-based HPA (autoscaling/v2):

```yml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapi-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapi
  minReplicas: 3
  maxReplicas: 12
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Pods
          value: 1
          periodSeconds: 60
```

HPA using a Prometheus-exposed custom metric (via prometheus-adapter):

```yml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-requests-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "100"
```

See [prometheus-adapter docs](https://github.com/kubernetes-sigs/prometheus-adapter) for mapping queries

KEDA ScaledObject (Azure Service Bus) — supports scale-to-zero:

```yml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: sb-queue-scaledobject
  namespace: workers
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: event-worker
  minReplicaCount: 0
  maxReplicaCount: 20
  pollingInterval: 30
  cooldownPeriod: 300
  triggers:
    - type: azure-servicebus
      metadata:
        queueName: orders-queue
        queueLength: "50"
      authenticationRef:
        name: keda-azure-credentials
```

[KEDA docs](https://keda.sh/docs/latest/)

---

## Observability, alerts & SRE examples

Suggested alerts (copyable Prometheus examples — adjust metric names to your export setup):

1. Alert when HPA desired > current for > 5m (scheduling capacity problem)

    ```yml
    alert: HPAUnschedulable
    expr: (kube_hpa_status_desired_replicas - kube_hpa_status_current_replicas) > 0
    for: 5m
    labels:
      severity: page
    annotations:
      summary: "HPA desired replicas exceed current replicas for >5m (possible scheduling issue)"
    ```

1. Alert on pending pods in a namespace

    ```yml
    alert: PodsPendingHigh
    expr: sum(kube_pod_status_phase{phase="Pending", namespace="production"}) > 3
    for: 2m
    labels:
      severity: ticket
    annotations:
      summary: "High number of Pending pods in production"
    ```

1. Alert on frequent scaling (flapping)

    ```yml
    alert: HPAFlapping
    expr: increase(kube_hpa_status_replicas_last_transition_count[10m]) > 5
    for: 0m
    labels:
      severity: warning
    annotations:
      summary: "Frequent HPA scaling events detected"
    ```

Instrument dashboards showing:

- HPA: currentReplicas, desiredReplicas, lastScaleTime, metric values used by HPA
- Pod health: Pending pods, FailedScheduling events, pod restart counts
- Downstream: DB connection usage, error rates, external API error/429 rates

---

## Operational & debugging commands (quick reference)

- List HPAs: `kubectl get hpa -n`
- Describe HPA (look for current/current metrics, desiredReplicas, lastScaleTime, events): `kubectl describe hpa -n`
- Fields to inspect in describe output: currentReplicas, desiredReplicas, metrics (current/target values), lastScaleTime, events (errors from metrics provider or scaling failures)
- View resource usage (requires metrics-server): `kubectl top pods -n`
- Check Pending pods and scheduling failures: `kubectl get pods -n  | grep Pending`, `kubectl describe pod -n` (look for FailedScheduling)
- Check metrics provider logs: `kubectl logs -n kube-system deploy/metrics-server`, `kubectl logs -n deploy/prometheus-adapter`
- Apply HPA manifest: `kubectl apply -f hpa.yaml`

Quick troubleshooting tips:

- HPA reports desiredReplicas > currentReplicas and pods remain Pending → likely insufficient node capacity; enable Cluster Autoscaler or increase node pool.
- HPA shows metric errors in events → check adapter RBAC/config and metrics provider logs.
- HPA scaling too fast/slow → tune behavior policies (percent/pods limits) and stabilization windows.

---

## Recommended tuning defaults & heuristics

- CPU target: start around 60% averageUtilization (common range 60–80%) and tune per workload.
- minReplicas: at least 1 for availability; use KEDA if you require minReplicas: 0.
- maxReplicas: set based on capacity planning and cost; ensure Cluster Autoscaler limits permit adding nodes up to needed capacity.
- stabilizationWindowSeconds: scaleDown ≈ 300s (5 min) is a common starting point to avoid rapid downsizing; adjust per workload.
- scaling policies: cap percent increases per period (e.g., allow max 100% growth per minute) to avoid overwhelming downstream systems.
- Readiness/startup probes: always define them so pods don't receive traffic until fully ready.

Note: specific controller timing defaults and exact behavior can vary across Kubernetes versions and distributions — check the [HPA docs](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/) for your cluster version

---

## Common pitfalls & checklist before enabling HPA

- Pod resource requests missing or incorrect → resource-based HPA targets will be misleading.
- No metrics provider (metrics-server/prometheus-adapter/KEDA) → HPA cannot read metrics.
- Cluster has no node capacity and Cluster Autoscaler not enabled → pods will remain Pending.
- Mixing HPA & VPA: avoid having both controllers actively change resource requests — run VPA in recommendation mode and have HPA scale replicas.
- Startup spikes (initContainers, cold caches) without probes → adjust stabilization windows or warm instances manually.
- RBAC misconfiguration: ensure metrics adapters and HPA controller have required permissions to read metrics.

---

## Quick FAQ

Q: What are the benefits of HPA?
A: Automatically adapt replica count to changing load, improve utilization and cost, and maintain latency targets when used with the right metrics and node autoscaling.

Q: How does HPA compute desired replicas?
A: It reads configured metrics, computes desiredReplicas = ceil(current_total / target_per_pod) for each metric, takes the largest computed value, then applies min/max and behavior policies (source: [HPA docs](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/)).

Q: Can HPA scale to zero?
A: No — plain HPA cannot scale to zero. Use KEDA for scale-to-zero behavior ([KEDA docs](https://keda.sh/docs/latest/)).

Q: How to scale on queue length or RPS?
A: Expose queue length/RPS as an external or custom metric (Prometheus adapter or external metrics API) or use KEDA for event-driven scaling.

---

## References

- [Kubernetes HPA concept](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/)
- [Kubernetes HPA walkthrough/tasks](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [Prometheus adapter (custom metrics)](https://github.com/kubernetes-sigs/prometheus-adapter)
- [KEDA (event-driven autoscaling)](https://keda.sh/docs/latest/)
- [AKS Cluster Autoscaler docs](./cluster-autoscaler-overview.md)
