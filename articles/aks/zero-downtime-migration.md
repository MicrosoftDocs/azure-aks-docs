---
title: Zero-Downtime Migration to Azure Kubernetes Service (AKS)
description: Migrate existing workloads to Azure Kubernetes Service (AKS) with minimal or zero downtime by using Blue-Green, Canary, and Rolling DNS migration strategies.
author: schaffererin
ms.author: schaffererin
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 07/16/2026
# Customer intent: As a platform engineer or SRE, I want to migrate existing workloads to Azure Kubernetes Service (AKS) with minimal or zero downtime so I can maintain availability during cutover.
---

# Zero-downtime migration to Azure Kubernetes Service (AKS)

This article describes practical, production-focused approaches for migrating existing workloads to Azure Kubernetes Service (AKS) with minimal or zero downtime.

Quick answer: Minimize downtime by running legacy and AKS environments in parallel, shifting traffic progressively (canary or weighted blue-green), handling state with replication or snapshots, and enforcing observability gates with a tested rollback playbook.

Quick runbook:

1. Provision target AKS, certificates, networking, and observability.
1. Deploy the app with readiness and liveness probes, PodDisruptionBudget, and resource requests.
1. Sync data with replication, CSI snapshots, or Velero.
1. Shift traffic progressively (for example, 5% -> 50% -> 100%) by using Traffic Manager, ingress, or service mesh routing.
1. Validate SLO gates and decommission old infrastructure when stability criteria pass.

You learn how to:

- Compare Blue-Green, Canary, and Rolling DNS migration strategies.
- Run a pre-migration readiness checklist with AKS-specific commands.
- Perform a full Blue-Green cluster migration by using AKS and Azure Traffic Manager.
- Migrate persistent data by using CSI snapshots, Azure Files, or Velero.
- Prepare a rollback plan before cutover.

## Migration strategy comparison

Use this comparison to choose a migration approach that fits your risk tolerance, observability maturity, and rollback requirements.

| Strategy | Traffic impact | Rollback speed | Complexity | AKS features and Azure services |
|---|---:|---:|---:|---|
| Blue-Green (cluster or namespace) | Minimal, because traffic switches only when green is healthy | Very fast, by switching traffic back to blue | Medium, because it requires duplicate environments and traffic routing | Azure Traffic Manager, LoadBalancer public IPs, ingress |
| Canary | Very low, because traffic shifts gradually | Fast, by reducing canary weight or scaling down canary pods | Medium-high, because it requires traffic splitting and observability | Ingress (nginx or Gateway API), service mesh (Istio or Linkerd), AKS ingress add-ons |
| Rolling DNS (TTL-based) | Depends on DNS TTL; shorter TTL lowers impact | Medium, because DNS caches can delay rollback | Low, because setup is simple but less precise | Azure DNS, low TTL records, LoadBalancer or ingress |

### Workload decision matrix

Use this table when you need a quick strategy recommendation by workload type.

| Workload type | Recommended strategy | Why | Cost and complexity |
|---|---|---|---|
| Stateless web/API | Canary, then Blue-Green for final cutover | Progressive risk reduction with fast rollback | Medium |
| Stateful database-backed app | Blue-Green plus replicate-and-promote data path | Strongest rollback control and clear failback path | High |
| File-heavy workloads | Blue-Green plus Azure Files copy/snapshot | Easier validation of data parity before switch | Medium-high |
| Long-running jobs/workers | Rolling update or maintenance window with queue draining | Lower user-facing impact, simpler routing | Low-medium |

### Progressive delivery tooling options

- Manual weighted routing (Traffic Manager plus ingress or LoadBalancer): best when you want explicit operator control and simple dependencies.
- Service mesh routing (Istio or Linkerd): best when you need fine-grained routing, retries, and policy controls.
- Argo Rollouts or Flagger: best when you want automated progressive delivery, metric analysis, and automatic rollback.

Use Traffic Manager for global DNS-level weighting and combine it with Argo Rollouts or Flagger when you need automated rollout analysis inside the cluster.

## Before you begin

- Azure CLI version 2.59.0 or later.
- `kubectl` connected to your source cluster.
- AKS permissions to create and manage clusters, networking, and identities.
- A tested application health endpoint, such as `/healthz`.
- A rollback owner and rollback checklist approved before traffic cutover.
- DNS TTL reduction plan prepared at least 24-48 hours before cutover.

### TLS and certificate pre-provisioning

Provision certificates in the green environment before traffic shift. If the current environment terminates TLS, export and import certs into Kubernetes secrets (or configure cert-manager) before you cut over.

```bash
# Example: create a TLS secret in the target namespace
kubectl create secret tls myapp-tls \
  --cert ./tls.crt \
  --key ./tls.key \
  --namespace production
```

If you use ACME (for example, Let's Encrypt), complete domain validation before cutover to avoid HTTPS failures.

## Pre-migration readiness checklist

Run these checks before you migrate. Save all exports in version control or secure storage.

### Export Kubernetes resources from the source cluster

```bash
kubectl --context=current-prod-cluster get all --all-namespaces -o yaml > exports/all-namespaces-all-resources.yaml
kubectl --context=current-prod-cluster get deployments,statefulsets,daemonsets --all-namespaces -o yaml > exports/workloads.yaml
kubectl --context=current-prod-cluster get svc --all-namespaces -o yaml > exports/services.yaml
kubectl --context=current-prod-cluster get configmap,secret --all-namespaces -o yaml > exports/configs-secrets.yaml
kubectl --context=current-prod-cluster get pvc --all-namespaces -o yaml > exports/pvcs.yaml
kubectl --context=current-prod-cluster get ingress --all-namespaces -o yaml > exports/ingress.yaml
```

> [!IMPORTANT]
> Treat exported secret manifests as sensitive data. Store them only in secure systems.

### Validate subscription, quotas, and networking prerequisites

```bash
az account show --query "{name:name, id:id, tenantId:tenantId}" -o table
az configure --defaults location=eastus resource_group=rg-aks-migration
az vm list-usage --location eastus -o table
az network public-ip list --resource-group rg-aks-migration -o table
```

### Validate identity and RBAC requirements

```bash
az aks show --resource-group rg-aks-migration --name existing-aks --query aadProfile
az role assignment list --resource-group rg-aks-migration -o jsonc
az identity list --resource-group rg-aks-migration -o table
```

Confirm the following items before you continue:

- Cluster admin groups and Entra ID integration model.
- Managed identity scopes and role assignments.
- Logging, metrics, and alerting enabled on the target environment.

## Strategy walkthroughs

The next sections provide one complete Blue-Green example and two shorter patterns (Canary and Rolling DNS) you can adapt to your workload.

## Blue-Green cluster migration

In this scenario, production traffic currently serves from a legacy environment at `app.example.com`. You create a new AKS cluster (`aks-green`), deploy the workload, register both old and green endpoints in Azure Traffic Manager, and shift traffic gradually.

For foundational migration guidance, see [Migration overview for Azure Kubernetes Service (AKS)](./aks-migration.md).

### 1. Create the green AKS cluster

```bash
RG=rg-aks-migration
LOCATION=eastus
CLUSTER=aks-green
NODE_COUNT=3

az group create --name $RG --location $LOCATION

az aks create \
  --resource-group $RG \
  --name $CLUSTER \
  --location $LOCATION \
  --node-count $NODE_COUNT \
  --enable-managed-identity \
  --network-plugin azure \
  --load-balancer-sku standard \
  --generate-ssh-keys \
  --enable-addons monitoring \
  --attach-acr <yourACRName> \
  --yes
```

Get cluster credentials:

```bash
az aks get-credentials --resource-group $RG --name $CLUSTER --overwrite-existing
kubectl config use-context $CLUSTER
```

### 2. Deploy the workload with health and disruption controls

Create `manifests/app-deployment.yaml`.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  labels:
    app: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      terminationGracePeriodSeconds: 60
      containers:
      - name: myapp
        image: myregistry.azurecr.io/myapp:green
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /live
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 10
          failureThreshold: 3
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 30"]
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-lb
  labels:
    app: myapp
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
  externalTrafficPolicy: Local
```

`externalTrafficPolicy: Local` preserves source IP but can reduce usable backend endpoints per node. For sticky-session applications, externalize session state (for example, Azure Cache for Redis) before migration to avoid affinity-related outages during traffic shifts.

Create `manifests/pdb.yaml`.

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: myapp-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: myapp
```

Apply resources and verify rollout:

```bash
kubectl apply -f manifests/app-deployment.yaml
kubectl apply -f manifests/pdb.yaml
kubectl rollout status deployment/myapp
kubectl get svc myapp-lb -o wide
```

### 3. Get the green endpoint

```bash
kubectl get svc myapp-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Use the returned IP in the next steps.

### 4. Create an Azure Traffic Manager profile and endpoints

```bash
TM_PROFILE=myapp-tm

az network traffic-manager profile create \
  --name $TM_PROFILE \
  --resource-group $RG \
  --routing-method Weighted \
  --unique-dns-name myapp-tm-$RANDOM \
  --ttl 30 \
  --protocol http \
  --path /healthz \
  --interval 30 \
  --timeout 10
```

Add the old endpoint:

```bash
az network traffic-manager endpoint create \
  --resource-group $RG \
  --profile-name $TM_PROFILE \
  --type externalEndpoints \
  --name old-endpoint \
  --target old.example.com \
  --endpoint-status Enabled \
  --weight 100
```

Add the green endpoint:

```bash
az network traffic-manager endpoint create \
  --resource-group $RG \
  --profile-name $TM_PROFILE \
  --type externalEndpoints \
  --name green-endpoint \
  --target <green-endpoint-ip> \
  --endpoint-status Disabled \
  --weight 0
```

For command details, see [az network traffic-manager profile](/cli/azure/network/traffic-manager/profile) and [az network traffic-manager endpoint](/cli/azure/network/traffic-manager/endpoint).

### 5. Ramp traffic to green

Start with a low weight and observe health and latency.

```bash
az network traffic-manager endpoint update \
  --resource-group $RG \
  --profile-name $TM_PROFILE \
  --name green-endpoint \
  --set properties.endpointStatus=Enabled \
  --weight 10

az network traffic-manager endpoint update \
  --resource-group $RG \
  --profile-name $TM_PROFILE \
  --name old-endpoint \
  --set properties.weight=90
```

Continue through staged shifts, such as `50/50`, then `90/10`, then `100/0` to green.

## Cutover criteria, monitoring gates, and rollback playbook

Define explicit gates before each traffic increase.

### Example gates

- Roll back if HTTP 5xx exceeds 1% for 3 consecutive minutes.
- Roll back if p95 latency exceeds baseline by more than 200 ms for 5 minutes.
- Pause rollout if database replication lag exceeds your RPO threshold.
- Pause rollout if pod restart rate spikes above normal baseline.

### Rollforward sequence

1. Increase traffic weight in small increments.
1. Validate SLO gates and business smoke tests.
1. Continue only if all gates pass for the hold period.

### Rollback sequence

1. Route traffic back to old endpoint immediately.
1. Undo deployment or scale green to zero if needed.
1. Re-validate old environment health and data integrity.

```bash
# Restore old endpoint to 100
az network traffic-manager endpoint update \
  --resource-group $RG \
  --profile-name $TM_PROFILE \
  --name old-endpoint \
  --set properties.weight=100

# Set green endpoint to 0
az network traffic-manager endpoint update \
  --resource-group $RG \
  --profile-name $TM_PROFILE \
  --name green-endpoint \
  --set properties.weight=0

# Optional Kubernetes rollback options
kubectl rollout undo deployment/myapp
kubectl scale deployment myapp --replicas=0
```

### 6. Roll back quickly if needed

If errors increase or SLO thresholds fail:

- Set old endpoint weight back to `100` and green to `0`.
- Pause further rollout and optionally scale down green pods.

```bash
kubectl scale deployment myapp --replicas=0
```

## Canary migration (short walkthrough)

Use canary when you want incremental release control with minimal duplicate infrastructure.

1. Deploy a stable workload and a canary workload.
1. Route a small percentage of traffic to canary.
1. Observe key signals, then increase or roll back.

Example ingress annotations for nginx canary:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 80
```

Increase `canary-weight` in stages as health remains stable.

## Rolling DNS migration (short walkthrough)

Use rolling DNS when DNS switching is your primary traffic control mechanism.

Set DNS TTL to a low value at least 24-48 hours before cutover so caches can age out. After migration stabilizes, restore a higher TTL to reduce query volume and resolver churn.

1. Lower DNS TTL (for example, `30` seconds).
1. Deploy the AKS endpoint.
1. Update DNS A/CNAME records.
1. Observe propagation and health.

Example A record update:

```bash
RG=rg-aks-migration

az network dns record-set a update \
  --resource-group $RG \
  --zone-name example.com \
  --name app \
  --set ttl=30

az network dns record-set a remove-record \
  --resource-group $RG \
  --zone-name example.com \
  --record-set-name app \
  --ipv4-address 13.78.1.2

az network dns record-set a add-record \
  --resource-group $RG \
  --zone-name example.com \
  --record-set-name app \
  --ipv4-address 52.160.1.100
```

## Data migration for persistent volumes

Stateful migration is usually the highest risk area. Choose the data path that matches your storage type and consistency requirements.

### Database strategies

Choose a database migration pattern that aligns with your downtime and consistency requirements.

| Pattern | Pros | Tradeoffs | Typical use |
|---|---|---|---|
| External database (shared) | Simplest app migration path, no DB cutover during app shift | Shared blast radius, potential performance coupling | Existing managed PaaS DB shared by old and new app |
| Replicate and promote | Controlled cutover and rollback point | Operational overhead for replication and promotion | Critical stateful workloads with strict RPO |
| Dual-write (temporary) | Enables near-zero downtime app cutover | Complex reconciliation and idempotency requirements | Event-driven systems with mature data pipelines |

For CDC and migration orchestration, evaluate Azure Database Migration Service and Debezium. Use expand -> migrate -> contract schema changes to keep old and new app versions compatible during transition.

### Azure Disk CSI snapshots

Use CSI snapshots for block volumes when snapshot CRDs and the snapshot controller are installed.

Example `VolumeSnapshotClass`:

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-azuredisk-snapclass
driver: disk.csi.azure.com
deletionPolicy: Delete
```

Example snapshot from an existing PVC:

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: mydata-snapshot
spec:
  volumeSnapshotClassName: csi-azuredisk-snapclass
  source:
    persistentVolumeClaimName: mydata-pvc
```

Example PVC restore from snapshot:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mydata-pvc-restored
spec:
  storageClassName: managed-csi
  dataSource:
    name: mydata-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
```

> [!IMPORTANT]
> Snapshots are usually crash-consistent, not application-consistent. For databases, use replication or application-aware backup and restore.

### Azure Files

For file-based workloads:

- Create snapshot or copy plans for source file shares.
- Copy data with tools such as AzCopy.
- Update StorageClass and PVC configuration for the target share.

Example copy pattern:

```bash
az storage share snapshot --account-name mystorage --name myshare
azcopy copy "https://<src>/myshare" "https://<dest>/myshare" --recursive
```

### Velero backup and restore

Use Velero for cluster resource backup and restore, including PV data when configured with the Azure plugin.

```bash
RG=rg-aks-migration

velero install \
  --provider azure \
  --bucket my-velero-backups \
  --secret-file ./credentials-velero \
  --backup-location-config resourceGroup=$RG,storageAccount=myvelerostorage,subscriptionId=<subscription-id>

velero backup create pre-migration-backup --include-namespaces my-namespace
velero restore create --from-backup pre-migration-backup
```

See [Velero documentation](https://velero.io/docs/) and [Use Azure Disk CSI snapshots with AKS](./create-volume-azure-disk.md).

## Observability and automated rollback

Instrument these signals before any traffic shift:

- HTTP request rate and success rate.
- HTTP 5xx error rate.
- p95 and p99 request latency.
- Pod restart rate and readiness failures.
- Node pressure and pending pod count.
- Database replication lag.
- Queue depth for async workloads.

Example PromQL-style alert conditions:

```promql
# Rollback gate: 5xx error rate over 1%
sum(rate(http_requests_total{status=~"5.."}[3m]))
/
sum(rate(http_requests_total[3m])) > 0.01

# Rollback gate: p95 latency exceeds 200ms over baseline target
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le)) > 0.2
```

Tie alerts to your rollout controller (manual runbook, Argo Rollouts, or Flagger) so gate failures trigger automatic pause or rollback.

## Testing and validation recipes

### Shadow traffic

Mirror a slice of production traffic to green without returning green responses to end users. This validates behavior under realistic load with low user risk.

### Smoke tests

Run business-critical checks after each weight increase, for example:

- Sign-in flow
- Payment or checkout flow
- Read and write API path
- Background job completion

### Load testing

Use tools such as k6, hey, or Azure Load Testing to validate capacity and autoscaling behavior before final cutover.

### Feature flags

Use feature flags to decouple deployment from release. Feature flags can provide a second safety layer when you need to disable risky code paths without redeploying.

## Production cutover checklist

- [ ] Confirm readiness and liveness probes reflect true serving readiness.
- [ ] Validate `preStop` and `terminationGracePeriodSeconds` values under load.
- [ ] Confirm PodDisruptionBudget values for upgrade and eviction events.
- [ ] Confirm autoscaling settings for expected migration traffic spikes.
- [ ] Validate end-to-end health checks through your traffic entry point.
- [ ] Validate logs, metrics, alerts, and synthetic checks before cutover.
- [ ] Confirm rollback owner, rollback trigger criteria, and rollback runbook.
- [ ] Validate NSG, firewall, and health probe rules for new endpoints.
- [ ] Validate TLS termination behavior and CORS settings match old environment.
- [ ] Validate cost plan for temporary blue-green overlap period.

## Rollback checklist

1. Shift traffic to the old endpoint (Traffic Manager weights or DNS rollback).
1. Pause or scale down the green deployment.
1. Restore previous configuration or secrets if needed.
1. Revalidate old environment health before you resume normal operations.

## Next steps

- Review [Migration overview for Azure Kubernetes Service (AKS)](./aks-migration.md).
- Review [AKS production upgrade strategies](./aks-production-upgrade-strategies.md).
- Review [Blue-green node pool upgrades in AKS](./blue-green-node-pool-upgrade.md).
- Review [Azure Traffic Manager documentation](/azure/traffic-manager/traffic-manager-overview).
