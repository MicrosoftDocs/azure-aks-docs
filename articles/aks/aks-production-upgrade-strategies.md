---
title: Azure Kubernetes Service (AKS) production upgrade strategies
description: Production patterns for upgrading Azure Kubernetes Service (AKS) clusters with minimal downtime and controlled risk.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.date: 08/06/2026
author: schaffererin
ms.author: schaffererin
ms.custom: scenarios, production-ready
---

# Azure Kubernetes Service (AKS) production upgrade strategies

Use these patterns to safely upgrade production Azure Kubernetes Service (AKS) clusters. The guidance is intended for site reliability engineers and platform teams that need to minimize downtime and control upgrade risk.

> [!TIP]
> **Getting started with production upgrades?** AKS Automatic handles most upgrade scenarios automatically with preconfigured upgrade channels, a pod readiness service-level agreement (SLA) of 99.9%, and an uptime SLA of 99.95% included by default. For new production clusters, [create an AKS Automatic cluster](./automatic/quick-automatic-managed-network.md) to benefit from hardened defaults and managed upgrades with availability protections. These SLAs cover qualifying pod-readiness operations and API server availability, not end-to-end application availability. See [Introduction to AKS Automatic](intro-aks-automatic.md) for a full comparison.

## AKS production upgrade strategy overview

- Blue-green deployments for minimal-downtime upgrades.
- Staged fleet upgrades across multiple environments.
- Safe Kubernetes version adoption with validation gates.
- Emergency security patching for rapid response to Common Vulnerabilities and Exposures (CVEs).
- Application resilience patterns that minimize upgrade disruption.
- Migration cutover rollback with rapid traffic reversal to the source environment.

Use these patterns when you need minimal downtime and more customization than AKS Automatic's preconfigured defaults provide.

Select the scenario that best matches your business needs:

- [Do you need an emergency upgrade?](#scenario-4-fastest-security-patch-deployment)
- [Do you have stateful workloads?](stateful-workload-upgrades.md)
- [New to production upgrades?](intro-aks-automatic.md)
- [Are you migrating workloads from another cluster or environment?](#scenario-6-migration-cutover-rollback)

## Kubernetes prerequisites

This article assumes you understand Kubernetes Deployments and Services, including the following concepts:

- **Pod Disruption Budgets (PDBs)**: Limit how many selected pods can be unavailable during voluntary disruptions like node upgrades. With `maxUnavailable: 1`, Kubernetes allows at most one selected pod to be unavailable during a drain.
- **Readiness probes**: Signal when a pod is ready to receive traffic. During upgrades, Kubernetes waits for readiness probes to pass before considering a pod healthy.
- **Liveness probes**: Restart unhealthy pods automatically. During cluster upgrades, these probes ensure failed pods come back quickly.
- **Finalizers**: Custom logic that runs before Kubernetes deletes a resource. Long-running finalizers can block pod termination during drains.

## Choose your strategy

| Your priority | Best pattern | AKS Automatic? | Downtime | Time to complete |
| ------------- | ------------ | -------------- | -------- | ---------------- |
| **Automatic handling (recommended)** | **Preconfigured upgrade channels** | **Yes - default** | Target: less than 2 minutes | Ongoing |
| Minimal downtime | [Blue-green deployment](#scenario-1-minimal-downtime-production-upgrades) | No - AKS Standard | Target: less than 2 minutes | 45–60 minutes |
| Multi-environment safety | [Staged fleet upgrades](#scenario-2-stage-upgrades-across-environments) | Partial - AKS Automatic uses auto-upgrade channels; Azure Kubernetes Fleet Manager can orchestrate upgrades across multiple clusters | Planned windows | 2–4 hours |
| New version safety | [Canary with validation](#scenario-3-safe-kubernetes-version-intake) | Partial - AKS Automatic uses auto-upgrade channels; Azure Kubernetes Fleet Manager can orchestrate upgrades across multiple clusters | Low risk | 3–6 hours |
| Security patches | [Automated patching](#scenario-4-fastest-security-patch-deployment) | Yes - fixed NodeImage channel | Less than 4 hours | 30–90 minutes |
| Application resilience | [Resilient architecture](#scenario-5-application-architecture-for-resilient-upgrades) | Yes - complements default behavior | Minimal impact | Ongoing |
| Migration cutover safety | [Blue-green dual-cluster](#scenario-6-migration-cutover-rollback) | No - AKS Standard | seconds–minutes | Varies by workload size |

---

### Role-based starting points

Use this table to find the AKS production upgrade guidance that matches your role.

| Team role | Recommended upgrade guidance |
| --------- | ---------------------------- |
| **New to production upgrades** | [Introduction to AKS Automatic](intro-aks-automatic.md) |
| **Site reliability engineer or platform engineer** | [AKS Automatic](intro-aks-automatic.md) for most cases, then [Scenario 1](#scenario-1-minimal-downtime-production-upgrades) or [Scenario 2](#scenario-2-stage-upgrades-across-environments) for advanced customization |
| **Database administrator or data engineer** | [Stateful workload patterns](stateful-workload-upgrades.md) |
| **App development** | [Scenario 5](#scenario-5-application-architecture-for-resilient-upgrades) |
| **Security** | [Scenario 4](#scenario-4-fastest-security-patch-deployment) |
| **Migration engineer** | [Scenario 6](#scenario-6-migration-cutover-rollback) |

---

## Scenario 1: Minimal downtime production upgrades

- **Challenge**: "I need to upgrade my production cluster with less than 2 minutes of downtime during business hours."
- **Strategy**: Use blue-green deployment with intelligent traffic shifting. Blue-green deployment runs two identical production environments (blue and green). You deploy to the inactive environment, validate it, then switch traffic. If problems occur, traffic switches back to the active environment. Actual convergence time depends on the selected traffic-routing service, health probes, and client or DNS caching.
- **With AKS Automatic**: Preconfigured automatic upgrade channels and pod readiness SLA handle most of this scenario. However, if you need more control, custom validation gates, or blue-green testing strategies beyond standard automatic upgrades, use the following guidance:

To learn more, see [Blue-green deployment patterns](/azure/architecture/guide/aks/blue-green-deployment-for-aks) and [Azure Traffic Manager configuration](/azure/traffic-manager/traffic-manager-configure-weighted-routing-method).

### Implementation overview (15 minutes)

```bash
# List the Kubernetes versions available in the target region, then select a supported version.
az aks get-versions --location eastus2 --output table

# 1. Create green cluster (parallel to blue)
az aks create --name myaks-green --resource-group myRG \
  --kubernetes-version <supported-kubernetes-version> --enable-cluster-autoscaler \
  --min-count 3 --max-count 10

# 2. Deploy application to green cluster
kubectl config use-context myaks-green
kubectl apply -f ./production-manifests/

# 3. Validate green cluster
# Run your application-specific health checks here
# Examples: API endpoint tests, database connectivity, dependency checks

# 4. Switch traffic (target: less than two minutes, including traffic convergence)
az network traffic-manager endpoint update \
  --resource-group traffic-rg --profile-name prod-tm \
  --name green-endpoint --type azureEndpoints --weight 100
az network traffic-manager endpoint update \
  --resource-group traffic-rg --profile-name prod-tm \
  --name blue-endpoint --type azureEndpoints --weight 0
```

<details>
<summary><strong>Detailed step-by-step guide</strong></summary>

#### Prerequisites

- Secondary cluster capacity planned.
- Application supports horizontal scaling.
- Database connections use connection pooling.
- Health checks configured (`/health`, `/ready`).
- Rollback procedure tested in staging.

#### Step 1: Prepare the blue-green infrastructure

```azurecli-interactive
# Create resource group for green cluster
az group create --name myRG-green --location eastus2

# Create green cluster with same configuration as blue
az aks create \
  --resource-group myRG-green \
  --name myaks-green \
  --kubernetes-version <supported-kubernetes-version> \
  --node-count 3 \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 10 \
  --enable-addons monitoring \
  --generate-ssh-keys
```

#### Step 2: Deploy and validate the green environment

```bash
# Get green cluster credentials
az aks get-credentials --resource-group myRG-green --name myaks-green

# Deploy application stack
# Apply your Kubernetes manifests in order:
kubectl apply -f ./your-manifests/namespace.yaml      # Create namespace
kubectl apply -f ./your-manifests/secrets/           # Deploy secrets
kubectl apply -f ./your-manifests/configmaps/        # Deploy config maps
kubectl apply -f ./your-manifests/deployments/       # Deploy applications
kubectl apply -f ./your-manifests/services/          # Deploy services

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod --all --timeout=300s

# Validate application health
kubectl get pods -A
kubectl logs -l app=my-app --tail=50
```

#### Step 3: Switch traffic and validate convergence

```bash
# Pre-switch validation
GREEN_ENDPOINT_URL=<green-endpoint-url>
API_URL=<application-url>
curl -f "${GREEN_ENDPOINT_URL}/health"
if [ $? -ne 0 ]; then echo "Green health check failed!"; exit 1; fi

# Execute traffic switch
az network dns record-set cname set-record \
  --resource-group myRG-dns \
  --zone-name mycompany.com \
  --record-set-name api \
  --cname myapp-green.eastus2.cloudapp.azure.com

# Immediate validation
sleep 30
curl -f "${API_URL}/health"
```

#### Step 4: Monitor and validate

```bash
# Monitor traffic and errors for 15 minutes
kubectl top nodes
kubectl top pods
kubectl logs -l app=my-app --since=15m | grep ERROR

# Check application metrics
curl "${API_URL}/metrics" | grep http_requests_total
```

</details>

### Troubleshooting

- **Domain Name System (DNS) propagation is slow**: Use low time-to-live (TTL) values before the upgrade, and validate the DNS cache flush.
- **Pods stuck terminating**: Check for finalizers, long shutdown hooks, or PDBs with `maxUnavailable: 0`.
- **Traffic not shifting**: Validate Azure Load Balancer/Azure Traffic Manager configuration and health probes.
- **Rollback fails**: Always keep the blue cluster ready until the green cluster is fully validated and the rollback window passes.

### Frequently asked questions (FAQs)

#### Can I use open-source software tools for validation?

Yes. Use [kube-no-trouble](https://github.com/doitintl/kube-no-trouble) for API checks and [Trivy](https://aquasecurity.github.io/trivy/) for image scanning.

#### What's unique to AKS?

Native integration with Traffic Manager, Azure Kubernetes Fleet Manager, and node image patching helps minimize disruption during upgrades.

### Advanced configuration

For applications with a sub-two-minute downtime target, use session affinity to reduce session disruption during traffic convergence:

```yaml
# Use session affinity during transition
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 300
```

### Success validation

To validate your progress, use the following checklist:

- Application responds within two seconds.
- No 5xx errors are in logs.
- Database connections are stable.
- User sessions are preserved.

### Emergency rollback (if needed)

```bash
# Immediate rollback to blue cluster
az network dns record-set cname set-record \
  --resource-group myRG-dns \
  --zone-name mycompany.com \
  --record-set-name api \
  --cname myapp-blue.eastus2.cloudapp.azure.com
```

**Expected outcome**: Downtime stays within your validated target and rapid traffic rollback capability. Preventing data loss requires workload-specific replication, write coordination, and tested recovery procedures.

---

## Scenario 2: Stage upgrades across environments

- **Challenge**: "I need to safely test upgrades through dev, test, and production with proper validation gates."
- **Strategy**: Use Azure Kubernetes Fleet Manager with staged rollouts.
- **With AKS Automatic**: AKS Automatic clusters use preconfigured auto-upgrade channels by default. Azure Kubernetes Fleet Manager can orchestrate those upgrades across multiple AKS Automatic clusters in your environment, adding centralized validation gates and staged rollout control.

To learn more, see the [Azure Kubernetes Fleet Manager overview](/azure/kubernetes-fleet/overview) and [Update orchestration](/azure/kubernetes-fleet/update-orchestration).

### Prerequisites

```azurecli-interactive
# Install Fleet extension
az extension add --name fleet
az extension update --name fleet

# Create Fleet resource
az fleet create \
  --resource-group fleet-rg \
  --name production-fleet \
  --location eastus
```

### Implementation steps

#### Step 1: Define stage configuration

Create `upgrade-stages.json`:

```json
{
  "stages": [
    {
      "name": "development",
      "groups": [{ "name": "dev-clusters" }],
      "afterStageWaitInSeconds": 1800
    },
    {
      "name": "testing",
      "groups": [{ "name": "test-clusters" }],
      "afterStageWaitInSeconds": 3600
    },
    {
      "name": "production",
      "groups": [{ "name": "prod-clusters" }],
      "afterStageWaitInSeconds": 0
    }
  ]
}
```

#### Step 2: Add clusters to a fleet

```azurecli-interactive
# Add development clusters
az fleet member create \
  --resource-group fleet-rg \
  --fleet-name production-fleet \
  --name dev-east \
  --member-cluster-id "/subscriptions/.../clusters/aks-dev-east" \
  --update-group dev-clusters

# Add test clusters
az fleet member create \
  --resource-group fleet-rg \
  --fleet-name production-fleet \
  --name test-east \
  --member-cluster-id "/subscriptions/.../clusters/aks-test-east" \
  --update-group test-clusters

# Add production clusters
az fleet member create \
  --resource-group fleet-rg \
  --fleet-name production-fleet \
  --name prod-east \
  --member-cluster-id "/subscriptions/.../clusters/aks-prod-east" \
  --update-group prod-clusters
```

#### Step 3: Create and run a staged update

Select a target Kubernetes version that every Fleet member supports in the update run.

```azurecli-interactive
# Create staged update run
az fleet updaterun create \
  --resource-group fleet-rg \
  --fleet-name production-fleet \
  --name supported-version-upgrade \
  --upgrade-type Full \
  --kubernetes-version <supported-kubernetes-version> \
  --node-image-selection Latest \
  --stages upgrade-stages.json

# Start the staged rollout
az fleet updaterun start \
  --resource-group fleet-rg \
  --fleet-name production-fleet \
  --name supported-version-upgrade
```

#### Step 4: Validation gates between stages

After dev stage (30-minute soak):

```bash
# Run automated test suite
./scripts/run-e2e-tests.sh dev-cluster
./scripts/performance-baseline.sh dev-cluster

# Check for any regressions
kubectl get events --sort-by='.lastTimestamp' | grep -i warn
```

After test stage (60-minute soak):

```bash
# Extended testing with production-like load
./scripts/load-test.sh test-cluster 1000-users 15-minutes
./scripts/chaos-engineering.sh test-cluster

# Manual approval gate
echo "Approve production deployment? (y/n)"
read approval
```

### Troubleshooting

- **Stage fails because of quota**: Precheck regional quotas for all clusters in the fleet.
- **Validation scripts fail**: Verify that test scripts are idempotent and return clear success or failure results.
- **Manual approval delays**: Use automation for nonproduction. Require manual only for production.

### Frequently asked questions (FAQs)

#### Can I use open-source software tools for validation?

Yes. Integrate [Sonobuoy](https://sonobuoy.io/) for conformance and [kube-bench](https://github.com/aquasecurity/kube-bench) for security.

#### What's unique to AKS?
Azure Kubernetes Fleet Manager provides staged rollouts and validation gates.

---

## Scenario 3: Safe Kubernetes version intake

- **Challenge**: "I need to adopt a newer supported Kubernetes version without breaking existing workloads or APIs."
- **Strategy**: Use multiphase validation with canary deployment.
- **With AKS Automatic**: AKS Automatic uses the stable channel by default, which limits adoption to N-1 minor version (where N is the latest supported version). This built-in safety gate handles most version intake safely. If you need to test newer versions or custom validation beyond this default, use the following guidance:

To learn more, see [Canary deployments](/azure/architecture/reference-architectures/containers/aks-microservices/aks-microservices-advanced#deployment-strategies) and [API deprecation policies](https://kubernetes.io/docs/reference/using-api/deprecation-policy/).

### Implementation steps

#### Step 1: API deprecation analysis

```bash
# Install kubent after reviewing the installation script
sh -c "$(curl -sSL https://git.io/install-kubent)"

# Scan the cluster selected by your current kubeconfig context
kubent -o json > api-deprecation-report.json

# Review and remediate findings
cat api-deprecation-report.json | jq '.[] | select(.deprecated==true)'
```

To learn more, see the [Kubernetes API deprecation guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/) and [kube-no-trouble documentation](https://github.com/doitintl/kube-no-trouble).

#### Step 2: Create a canary environment

```azurecli-interactive
# Create canary cluster with target version
az aks create \
  --resource-group canary-rg \
  --name aks-canary-target \
  --kubernetes-version <supported-kubernetes-version> \
  --node-count 2 \
  --tier premium \
  --enable-addons monitoring

# Deploy subset of workloads
kubectl apply -f ./canary-manifests/
```

#### Step 3: Progressive workload migration

```bash
# Phase 1: Stateless services (20% traffic)
kubectl patch service api-service -p '{"spec":{"selector":{"version":"canary"}}}'
./scripts/monitor-error-rate.sh 15-minutes

# Phase 2: Background jobs (50% traffic)
kubectl scale deployment batch-processor --replicas=3
./scripts/validate-job-completion.sh

# Phase 3: Critical services (100% traffic)
kubectl patch deployment critical-api -p '{"spec":{"template":{"metadata":{"labels":{"cluster":"canary"}}}}}'
```

#### Step 4: Feature gate validation

```yaml
# Test features and APIs in the target Kubernetes version
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-validation
data:
  test-script: |
    # Test new security features
    kubectl auth can-i create pods --as=service-account:default:test-sa

    # Validate performance improvements
    kubectl top nodes --use-protocol-buffers=true

    # Check the API versions enabled on the canary cluster
    kubectl api-versions
```

### Success metrics

- **API compatibility**: 100% (zero breaking changes)
- **Performance**: No more than 5% regression in key metrics
- **Feature adoption**: New features validated in canary

---

## Scenario 4: Fastest security patch deployment

- **Challenge**: "A critical CVE was announced. I need patches deployed across all clusters within four hours."
- **Strategy**: Use automated node image patching with minimal disruption.
- **With AKS Automatic**: AKS Automatic uses the fixed `NodeImage` channel, which provides weekly node images that include security and bug fixes. You can configure maintenance windows, but you can't change the node OS autoupgrade channel. For AKS Standard clusters that require a different patching cadence, use the following guidance to configure `SecurityPatch` or trigger an immediate node image upgrade:

To learn more, see [Node image upgrade strategies](./upgrade-node-image.md), [Auto-upgrade channels](./auto-upgrade-cluster.md), and [Security patching best practices](/azure/aks/operator-best-practices-cluster-security).

### Implementation steps

#### Step 1: Emergency response preparation

The first command configures the cluster-level node OS autoupgrade channel for an AKS Standard cluster. This channel is separate from the cluster Kubernetes version autoupgrade channel.

```azurecli-interactive
# Configure the cluster-level node OS autoupgrade channel
az aks update \
  --resource-group production-rg \
  --name aks-prod \
  --node-os-upgrade-channel SecurityPatch

# Configure maintenance window for emergency patches
az aks maintenanceconfiguration add \
  --resource-group production-rg \
  --cluster-name aks-prod \
  --name aksManagedNodeOSUpgradeSchedule \
  --schedule-type Weekly \
  --day-of-week Monday \
  --interval-weeks 1 \
  --duration 4 \
  --utc-offset +00:00 \
  --start-time 00:00
```

To learn more, see [Planned maintenance configuration](./planned-maintenance.md) and [Autoupgrade channels](./auto-upgrade-cluster.md#cluster-autoupgrade-channels).

#### Step 2: Automated security scanning

```yaml
# security-scan-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: security-scanner
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: scanner
            image: aquasec/trivy:latest
            command:
            - trivy
            - k8s
            - --report
            - summary
            - cluster
```

#### Step 3: Rapid patch deployment

```azurecli-interactive
# Trigger immediate node image upgrade for security patches
az aks nodepool upgrade \
  --resource-group production-rg \
  --cluster-name aks-prod \
  --name nodepool1 \
  --node-image-only \
  --max-surge 50% \
  --drain-timeout 5

# Monitor patch deployment
watch az aks nodepool show \
  --resource-group production-rg \
  --cluster-name aks-prod \
  --name nodepool1 \
  --query "upgradeSettings"
```

#### Step 4: Compliance validation

```bash
# Verify patch installation
kubectl get nodes -o wide
kubectl describe node | grep "Kernel Version"

# Generate compliance report
./scripts/generate-security-report.sh > security-compliance-$(date +%Y%m%d).json

# Notify security team
curl -X POST "$SLACK_WEBHOOK" -d "{\"text\":\"Security patches deployed to production cluster. Compliance report attached.\"}"
```

### Success metrics

- **Deployment time**: Less than four hours from CVE announcement
- **Coverage**: 100% of nodes patched
- **Downtime**: Less than five minutes per node pool

---

## Scenario 5: Application architecture for resilient upgrades

- **Challenge**: "I want my applications to handle cluster upgrades gracefully without affecting users."
- **Strategy**: Use resilient application patterns with graceful degradation.
- **With AKS Automatic**: These architectural patterns complement AKS Automatic's automatic node repair, pod readiness SLA, and automatic upgrade channels to minimize application impact during upgrades. End-to-end availability still depends on workload design, capacity, probes, PDBs, and dependencies. Implement these patterns on top of AKS Automatic to improve resilience.

To learn more, see [Application reliability patterns](/azure/architecture/framework/resiliency/reliability-patterns), [PDBs](https://kubernetes.io/docs/tasks/run-application/configure-pdb/), and [Health check best practices](/azure/architecture/patterns/health-endpoint-monitoring).

### Implementation steps

#### Step 1: Implement robust health checks

```yaml
# robust-health-checks.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resilient-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: resilient-api
  template:
    metadata:
      labels:
        app: resilient-api
    spec:
      containers:
      - name: api
        image: myapp:latest
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 15"]
```

This deployment runs three `resilient-api` replicas, removes unready pods from service traffic, restarts unhealthy containers, and gives terminating pods 15 seconds to drain.

#### Step 2: Configure Pod Disruption Budgets (PDBs)

```yaml
# optimal-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
spec:
  selector:
    matchLabels:
      app: resilient-api
  maxUnavailable: 1
  # Ensures at least 2 pods remain available during upgrades
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: database-pdb
spec:
  selector:
    matchLabels:
      app: database
  minAvailable: 2
  # Critical: Always keep majority of database pods running
```

These budgets allow at most one `resilient-api` pod to be unavailable and require at least two database pods to remain available during voluntary disruptions.

#### Step 3: Implement a circuit breaker pattern

```javascript
// circuit-breaker.js
const CircuitBreaker = require('opossum');

const options = {
  timeout: 3000,
  errorThresholdPercentage: 50,
  resetTimeout: 30000,
  fallback: () => 'Service temporarily unavailable'
};

const breaker = new CircuitBreaker(callExternalService, options);

// Monitor circuit breaker state during upgrades
breaker.on('open', () => console.log('Circuit breaker opened'));
breaker.on('halfOpen', () => console.log('Circuit breaker half-open'));
```

The circuit breaker opens when at least 50% of requests fail, uses a fallback response, and tests recovery after 30 seconds.

To learn more, see [Circuit breaker pattern](/azure/architecture/patterns/circuit-breaker), [Retry pattern](/azure/architecture/patterns/retry), and [Application resilience](/azure/well-architected/reliability/).

#### Step 4: Database connection resilience

```yaml
# connection-pool-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-config
data:
  database.yml: |
    production:
      adapter: postgresql
      pool: 25
      timeout: 5000
      retry_attempts: 3
      retry_delay: 1000
      connection_validation: true
      validation_query: "SELECT 1"
      test_on_borrow: true
```

This configuration maintains a pool of 25 database connections, validates connections before use, and retries failed connections up to three times.

### Success metrics

- **Error rate**: Less than 0.01% during upgrades
- **Response time**: Less than 10% degradation
- **Recovery time**: Less than 30 seconds after node replacement

---

## Scenario 6: Migration cutover rollback

- **Challenge**: "I'm migrating workloads from a source cluster, VM estate, or on-premises environment into a new AKS cluster. I need rapid traffic rollback to the source if anything goes wrong after cutover."
- **Strategy**: Use a blue-green dual-cluster (source cluster = blue, new AKS cluster = green), or use blue/green inside the new AKS cluster by using node pools. Keep the source environment running and reachable by the same external front door (DNS, Traffic Manager, or load balancer). Perform final cutover by switching traffic to the green endpoints. If anything goes wrong, flip traffic back to blue.
- **With AKS Automatic**: This pattern doesn't apply to AKS Automatic because the source environment is outside AKS. Use AKS Standard for the target cluster so you control the node pool configuration and rollback timing.

> [!NOTE]
> This scenario specifically covers migration cutover rollback, where the source environment is external to the target AKS cluster. For in-cluster version upgrade rollback, see [Scenario 1](#scenario-1-minimal-downtime-production-upgrades).

### Why this works

- Cutover is a single traffic switch operation at the front door or service level.
- The source remains intact as a production fallback. No destructive migration step occurs until you confidently decommission it.
- You can pre-warm caches, validate behavior under real traffic, and cut back immediately when metrics cross abort thresholds.

### Implementation overview

```bash
# variables (replace)
RG="myResourceGroup"
CLUSTER="myAksCluster"
GREEN_POOL="greenpool"
NODE_COUNT=3
VM_SIZE="Standard_DS2_v2"

# Step 1: Create a green node pool in the target AKS cluster
az aks nodepool add \
  --resource-group $RG \
  --cluster-name $CLUSTER \
  --name $GREEN_POOL \
  --node-count $NODE_COUNT \
  --node-vm-size $VM_SIZE \
  --labels pool=green

# Step 2: Get credentials
az aks get-credentials --resource-group $RG --name $CLUSTER

# Step 3: Cutover - patch the Service selector to green pods
kubectl patch svc myapp -n production -p '{"spec":{"selector":{"app":"myapp","version":"green"}}}'

# Rollback - patch selector back to blue
kubectl patch svc myapp -n production -p '{"spec":{"selector":{"app":"myapp","version":"blue"}}}'
```

<details>
<summary><strong>Detailed step-by-step guide</strong></summary>

#### Step 1: Create a green node pool in the target AKS cluster

Add a dedicated node pool so you can pin pods for the green cutover without affecting the rest of the cluster.

```bash
az aks nodepool add \
  --resource-group $RG \
  --cluster-name $CLUSTER \
  --name $GREEN_POOL \
  --node-count $NODE_COUNT \
  --node-vm-size $VM_SIZE \
  --labels pool=green
```

#### Step 2: Get credentials and confirm node labels

```bash
az aks get-credentials --resource-group $RG --name $CLUSTER

# Confirm nodes are in the new pool
kubectl get nodes --show-labels | grep $GREEN_POOL
```

#### Step 3: Deploy the green workload targeted to the green node pool

Use a node selector (or node affinity) that targets the green pool label. AKS labels nodes with `kubernetes.azure.com/agentpool`. Confirm labels on your nodes before deploying.

```yaml
# deployment-green.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-green
  labels:
    app: myapp
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      nodeSelector:
        "kubernetes.azure.com/agentpool": "greenpool"
      containers:
      - name: myapp
        image: myregistry.azurecr.io/myapp:green
        ports:
        - containerPort: 80
```

```bash
kubectl apply -f deployment-green.yaml -n production
kubectl rollout status deploy/myapp-green -n production
```

#### Step 4: Validate green in isolation with telemetry

```bash
# Check pod health
kubectl get pods -l app=myapp,version=green -n production
kubectl logs -l app=myapp,version=green -n production --tail=100

# Example: check cluster CPU (adjust resource ID for your cluster)
az monitor metrics list \
  --resource /subscriptions/<sub>/resourceGroups/$RG/providers/Microsoft.ContainerService/managedClusters/$CLUSTER \
  --metric "CpuUsagePercentage" \
  --interval PT1M
```

Verify application traces, request rates, and error logs in your Log Analytics workspace or Application Insights before proceeding.

#### Step 5: Cutover - switch traffic via the Service selector

If your Service is `type: LoadBalancer`, AKS configures an Azure Load Balancer for that Service. Switching the selector to green moves the load balancer endpoints to green pods, making the cutover nearly instantaneous.

```bash
kubectl patch svc myapp -n production -p '{"spec":{"selector":{"app":"myapp","version":"green"}}}'

# Verify endpoints updated
kubectl get endpoints myapp -n production -o wide
```

#### Step 6: Monitor immediately after cutover

Watch health probes, request success rate, latency percentiles, CPU and memory, and business metrics. Keep an operator in the loop for the defined observation window.

#### Step 7: Rollback - switch selector back to blue

If a rollback is required, restore the Service selector to the original (blue) pods for immediate traffic reversal.

```bash
kubectl patch svc myapp -n production -p '{"spec":{"selector":{"app":"myapp","version":"blue"}}}'

# Verify
kubectl get endpoints myapp -n production -o wide
kubectl rollout status deploy/myapp-blue -n production
```

</details>

### Dual-cluster migrations (source is a separate cluster or VMs)

If the source (blue) environment is a separate cluster or VMs, operate the front door externally and switch endpoints there instead of patching a Service inside the new cluster.

- **Azure Traffic Manager or Front Door**: Flip endpoint priority or weight to route between source and target.
- **DNS cutover**: Maintain the same DNS name and change the A record with a short TTL to the target cluster IP. Account for client and resolver DNS caches when you plan the cutover.
- **External load balancer**: Use backend pools for each cluster and toggle backend pool membership.

### Rollback triggers (go/no-go metrics)

Define explicit triggers that cause an immediate rollback. Tune thresholds to your service-level objectives (SLOs).

| Signal | Example threshold | Action |
| ------ | ----------------- | ------ |
| Error rate | 5-minute error rate > 1–3% above baseline for 5 continuous minutes | Rollback |
| Latency | p95 is more than twice the baseline or exceeds the SLO (for example, p95 is more than 1 second for 3 minutes when the SLO is 500 milliseconds) | Rollback |
| Throughput | Successful requests per minute drop more than 20% from the baseline for 5 minutes | Rollback |
| Resource pressure | Pod OOMKills or node CPU saturation >90% causing request failures | Rollback |
| Business KPI | Payment failures, checkout errors, or other critical business metric degradation | Rollback |

Implement automated alarms in Azure Monitor or Application Insights to notify on-call engineers and optionally trigger runbooks that revert traffic.

### Troubleshooting

- **DNS propagation is slow**: Set short TTLs before cutover and validate DNS cache flush.
- **Pods stuck terminating on source**: Check for finalizers or long shutdown hooks.
- **Traffic not shifting**: Validate Traffic Manager health probes and endpoint configuration.
- **Rollback fails**: Keep the source environment patched and reachable until you formally decommission it.

### Success validation checklist

Before cutover:

- [ ] Source (blue) stays running and reachable.
- [ ] Green environment has identical or compatible service endpoints, secrets, and config.
- [ ] Readiness and liveness probes configured and tested.
- [ ] Monitoring and alerts in place for errors, latency, and resource pressure.
- [ ] Scripted rollback action ready and tested.
- [ ] Stakeholders and on-call notified and on standby.

**Expected outcome**: Rapid traffic rollback and a practiced, metric-driven cutover that keeps the source intact until you choose to decommission it. The achievable recovery time and recovery point depend on traffic convergence, data replication, write coordination, and tested recovery procedures.

### Next steps for migration

- [AKS migration guidance](./aks-migration.md) - start here for migration planning and inventory.
- [Blue-green node pool upgrade patterns for AKS](./blue-green-node-pool-upgrade.md) - node-pool blue/green and zero-risk upgrades.

---

## Monitor AKS production upgrades

Monitor upgrade progress and application health with Azure Monitor managed service for Prometheus metrics, Container insights logs, and Grafana dashboards. To learn more, see the [AKS monitoring overview](./monitor-aks.md), [Container insights](/azure/azure-monitor/containers/container-insights-overview), and [Prometheus metrics](/azure/azure-monitor/essentials/prometheus-metrics-overview).

### With AKS Automatic

AKS Automatic clusters include monitoring enabled by default:

- Managed Prometheus for metric collection
- Container insights for log collection
- Azure Monitor dashboards with Grafana for visualization

Build additional upgrade-specific monitors on top of these defaults.

### Essential metrics to monitor

```yaml
# upgrade-monitoring.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: upgrade-monitoring
spec:
  groups:
  - name: upgrade.rules
    rules:
    - alert: UpgradeInProgress
      expr: kube_node_spec_unschedulable > 0
      for: 1m
      annotations:
        summary: "Node upgrade in progress"

    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.01
      for: 2m
      annotations:
        summary: "High error rate during upgrade"

    - alert: PodEvictionFailed
      expr: increase(kube_pod_container_status_restarts_total[5m]) > 5
      for: 1m
      annotations:
        summary: "Multiple pod restarts detected"
```

### Sample AKS upgrade dashboard signals

The following conceptual JSON groups Prometheus signals for AKS node status and application health. Adapt these signals to Azure Monitor dashboards with Grafana or Azure Managed Grafana; this example isn't an importable dashboard definition.

```json
{
  "dashboard": {
    "title": "AKS Upgrade Dashboard",
    "panels": [
      {
        "title": "Upgrade Progress",
        "targets":
        [
          "kube_node_info",
          "kube_node_status_condition"
        ]
      },
      {
        "title": "Application Health",
        "targets":
        [
          "up{job='kubernetes-pods'}",
          "http_request_duration_seconds"
        ]
      }
    ]
  }
}
```

---

## Troubleshooting guide

To learn more, see the [AKS troubleshooting guide](/azure/aks/troubleshooting), [Node and pod troubleshooting](./node-access.md), and [AKS error code PodDrainFailure](/troubleshoot/azure/azure-kubernetes/create-upgrade-delete/error-code-poddrainfailure).

### Common issues and solutions

| Issue | Symptoms | Solution |
| ----- | -------- | -------- |
| Stuck node drain | Pods won't evict. | Check PDB configuration, increase drain timeout. |
| High error rates | 5xx responses are increasing. | Verify health checks, check resource limits. |
| Slow upgrades | Takes more than 2 hours. | Increase `maxSurge`, optimize container startup. |
| DNS resolution | Service discovery is failing. | Verify `CoreDNS` pods, check service endpoints. |

### Emergency rollback procedures

```bash
# Quick rollback script
#!/bin/bash
echo "Initiating emergency rollback..."

# Route traffic back to the previous cluster endpoint
az network traffic-manager endpoint update \
  --resource-group traffic-rg \
  --profile-name production-tm \
  --name current-endpoint \
  --type azureEndpoints \
  --weight 0

az network traffic-manager endpoint update \
  --resource-group traffic-rg \
  --profile-name production-tm \
  --name previous-endpoint \
  --type azureEndpoints \
  --weight 100

# Verify rollback success
API_URL=<application-url>
curl -f "${API_URL}/health"
echo "Rollback completed in $(date)"
```

---

## Related resources

### AKS Automatic (recommended for new production clusters)

- [Introduction to AKS Automatic](./intro-aks-automatic.md): Features and benefits overview
- [Create an AKS Automatic cluster](./automatic/quick-automatic-managed-network.md): Get started with managed upgrades

### Specialized scenarios

- [Stateful workloads](stateful-workload-upgrades.md): Use PostgreSQL, Redis, and MongoDB upgrade patterns.
- [Upgrade scenarios hub](upgrade-scenarios-hub.md): Choose your upgrade path.
- [Basic AKS upgrades](tutorial-kubernetes-upgrade-cluster.md): Find simple cluster version upgrades.

### Supporting tools

- [Auto-upgrade configuration](auto-upgrade-cluster.md): Use automated upgrade channels.
- [Maintenance windows](planned-maintenance.md): Schedule upgrade windows.
- [Upgrade monitoring](aks-communication-manager.md): Use real-time upgrade alerts.

### Best practices

- [Cluster reliability](best-practices-app-cluster-reliability.md): Design for upgrades.
- [Security guidelines](operator-best-practices-cluster-security.md): Use secure upgrade practices.
- [Support policies](support-policies.md): Understand upgrade support windows.

## Next tasks

### For new production clusters

- Start with AKS Automatic: [Create an AKS Automatic cluster](./automatic/quick-automatic-managed-network.md) to benefit from managed upgrades with built-in availability protections.
- Understand capabilities: Review [Introduction to AKS Automatic](./intro-aks-automatic.md) for full feature details.

### For existing AKS Standard clusters

- **Set up monitoring**: Configure [upgrade notifications](aks-communication-manager.md) before your first upgrade.
- **Practice safely**: Test scenarios in staging by using [cluster snapshots](node-pool-snapshot.md).
- **Automate gradually**: Start with [auto-upgrade channels](auto-upgrade-cluster.md) for nonproduction.
- **Handle stateful data**: Review [stateful workload patterns](stateful-workload-upgrades.md) if you run databases.