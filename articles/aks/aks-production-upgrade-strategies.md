---
title: AKS Production Upgrade Strategies
description: Proven patterns to use for upgrading Azure Kubernetes Service clusters in production with minimal downtime and maximum safety.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.date: 07/11/2025
author: kaarthis
ms.author: kaarthis
ms.custom: scenarios, production-ready
---

# AKS production upgrade strategies

Upgrade your production Azure Kubernetes Service (AKS) clusters safely by using these proven patterns. Each strategy is optimized for specific business constraints and risk tolerance.

## What this article covers

This article provides tested upgrade patterns for production AKS clusters and focuses on:

- Blue-green deployments for zero-downtime upgrades.
- Staged fleet upgrades across multiple environments.
- Safe Kubernetes version adoption with validation gates.
- Emergency security patching for rapid common vulnerabilities and exposures (CVE) response.
- Application resilience patterns for seamless upgrades.

These patterns are best for production environments, site reliability engineers, and platform teams that require minimal downtime and maximum safety.

For more information, see these related articles:

- To get upgrade patterns for AKS clusters with stateful workloads, see [Stateful workload upgrade patterns](stateful-workload-upgrades.md).
- To check for and apply basic upgrades to your AKS cluster, see [Upgrade an Azure Kubernetes Service cluster](upgrade-aks-cluster.md).
- To use the scenario hub to help you choose the right AKS upgrade approach, see [AKS upgrade scenarios: Choose your path](upgrade-scenarios-hub.md).

---

For a quick start, select a link for instructions:

- [Do you need an emergency upgrade?](#scenario-4-fastest-security-patch-deployment)
- [Do you have stateful workloads?](stateful-workload-upgrades.md)

## Choose your strategy

| Your priority | Best pattern | Downtime | Time to complete |
|---------------|-------------|----------|------------------|
| Zero downtime | [Blue-green deployment](#scenario-1-minimal-downtime-production-upgrades) | <2 minutes | 45-60 minutes |
| Multi-environment safety | [Staged fleet upgrades](#scenario-2-stage-upgrades-across-environments) | Planned windows | 2-4 hours |
| New version safety | [Canary with validation](#scenario-3-safe-kubernetes-version-intake) | Low risk | 3-6 hours |
| Security patches | [Automated patching](#scenario-4-fastest-security-patch-deployment) | <4 hours | 30-90 minutes |
| Future-proof apps | [Resilient architecture](#scenario-5-application-architecture-for-seamless-upgrades) | Zero impact | Ongoing |

---

#### Role-based quick start

| Role | Start here |
|------|------------|
| Site reliability engineer/Platform | [Scenario 1](#scenario-1-minimal-downtime-production-upgrades), [Scenario 2](#scenario-2-stage-upgrades-across-environments) |
| Database administrator/Data engineer | [Stateful workload patterns](stateful-workload-upgrades.md) |
| App development | [Scenario 5](#scenario-5-application-architecture-for-seamless-upgrades) |
| Security | [Scenario 4](#scenario-4-fastest-security-patch-deployment) |

---

## Scenario 1: Minimal downtime production upgrades

**Challenge:** "I need to upgrade my production cluster with less than 2 minutes of downtime during business hours."

**Strategy:** Use blue-green deployment with intelligent traffic shifting.

To learn more, see [Blue-green deployment patterns](/azure/architecture/guide/aks/blue-green-deployment-for-aks) and [Azure Traffic Manager configuration](/azure/traffic-manager/traffic-manager-configure-weighted-routing-method).

### Quick implementation (15 minutes)

```bash
# 1. Create green cluster (parallel to blue)
az aks create --name myaks-green --resource-group myRG \
  --kubernetes-version 1.29.0 --enable-cluster-autoscaler \
  --min-count 3 --max-count 10

# 2. Deploy application to green cluster
kubectl config use-context myaks-green
kubectl apply -f ./production-manifests/

# 3. Validate green cluster
# Run your application-specific health checks here
# Examples: API endpoint tests, database connectivity, dependency checks

# 4. Switch traffic (<30-second downtime)
az network traffic-manager endpoint update \
  --profile-name prod-tm --name green-endpoint --weight 100
az network traffic-manager endpoint update \
  --profile-name prod-tm --name blue-endpoint --weight 0
```

<details>
<summary><strong> Detailed step-by-step guide</strong></summary>

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
  --kubernetes-version 1.29.0 \
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

#### Step 3: Traffic switching (critical 30-second window)

```bash
# Pre-switch validation
curl -f https://myapp-green.eastus2.cloudapp.azure.com/health
if [ $? -ne 0 ]; then echo "Green health check failed!"; exit 1; fi

# Execute traffic switch
az network dns record-set cname set-record \
  --resource-group myRG-dns \
  --zone-name mycompany.com \
  --record-set-name api \
  --cname myapp-green.eastus2.cloudapp.azure.com

# Immediate validation
sleep 30
curl -f https://api.mycompany.com/health
```

#### Step 4: Monitor and validate

```bash
# Monitor traffic and errors for 15 minutes
kubectl top nodes
kubectl top pods
kubectl logs -l app=my-app --since=15m | grep ERROR

# Check application metrics
curl https://api.mycompany.com/metrics | grep http_requests_total
```

</details>

### Common pitfalls and FAQs
<details>
<summary><strong>Expand for quick troubleshooting and tips</strong></summary>

- **Domain Name System (DNS) propagation is slow:** Use low time-to-live values before upgrade, and validate the DNS cache flush.
- **Pods stuck terminating:** Check for finalizers, long shutdown hooks, or pod disruption budgets (PDBs) with `maxUnavailable: 0`.
- **Traffic not shifting:** Validate Azure Load Balancer/Azure Traffic Manager configuration and health probes.
- **Rollback fails:** Always keep the blue cluster ready until the green cluster is fully validated.
- **Q: Can I use open-source software tools for validation?**
    - **A:** Yes. Use [kube-no-trouble](https://github.com/doitintl/kube-no-trouble) for API checks and [Trivy](https://aquasecurity.github.io/trivy/) for image scanning.
- **Q: What's unique to AKS?**
    - **A:** Native integration with Traffic Manager, Azure Kubernetes Fleet Manager, and node image patching for zero-downtime upgrades.

</details>

### Advanced configuration

For applications that require <30-second downtime:

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

**Expected outcome:** Less than 2-minute total downtime, zero data loss, and full rollback capability.

```
az aks create \
  --resource-group production-rg \
  --name aks-green-cluster \
  --kubernetes-version 1.29.0 \
  --node-count 3 \
  --tier premium \
  --auto-upgrade-channel patch \
  --planned-maintenance-config ./maintenance-window.json
```

## Verify cluster readiness

```
az aks get-credentials --resource-group production-rg --name aks-green-cluster
kubectl get nodes
```

### Implementation steps

#### Step 1: Deploy the application to a green cluster

```bash
# Deploy application stack
kubectl apply -f ./k8s-manifests/
kubectl apply -f ./monitoring/

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod --all --timeout=300s

# Validate application health
curl -f http://green-cluster-ingress/health
```

#### Step 2: Run traffic shift

```azurecli-interactive
# Update DNS or load balancer to point to green cluster
az network dns record-set a update \
  --resource-group dns-rg \
  --zone-name contoso.com \
  --name api \
  --set aRecords[0].ipv4Address="<green-cluster-ip>"

# Monitor traffic shift (should complete in 60-120 seconds)
watch kubectl top pods -n production
```

#### Step 3: Validate and clean up

```bash
# Verify zero errors in application logs
kubectl logs -l app=api --tail=100 | grep -i error

# Monitor key metrics for 15 minutes
kubectl get events --sort-by='.lastTimestamp' | head -20

# After validation, decommission blue cluster
az aks delete --resource-group production-rg --name aks-blue-cluster --yes
```

### Success metrics

- **Downtime:** <2 minutes (DNS propagation time)
- **Error rate:** 0% during transition
- **Recovery time:** <5 minutes if rollback needed

---

## Scenario 2: Stage upgrades across environments

**Challenge:** "I need to safely test upgrades through dev/test/production with proper validation gates."

**Strategy:** Use Azure Kubernetes Fleet Manager with staged rollouts.

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
  --group dev-clusters

# Add test clusters  
az fleet member create \
  --resource-group fleet-rg \
  --fleet-name production-fleet \
  --name test-east \
  --member-cluster-id "/subscriptions/.../clusters/aks-test-east" \
  --group test-clusters

# Add production clusters
az fleet member create \
  --resource-group fleet-rg \
  --fleet-name production-fleet \
  --name prod-east \
  --member-cluster-id "/subscriptions/.../clusters/aks-prod-east" \
  --group prod-clusters
```

#### Step 3: Create and run a staged update

```azurecli-interactive
# Create staged update run
az fleet updaterun create \
  --resource-group fleet-rg \
  --fleet-name production-fleet \
  --name k8s-1-29-upgrade \
  --upgrade-type Full \
  --kubernetes-version 1.29.0 \
  --node-image-selection Latest \
  --stages upgrade-stages.json

# Start the staged rollout
az fleet updaterun start \
  --resource-group fleet-rg \
  --fleet-name production-fleet \
  --name k8s-1-29-upgrade
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

### Common pitfalls and FAQs
<details>
<summary><strong>Expand for quick troubleshooting and tips</strong></summary>

- **Stage fails because of quota:** Precheck regional quotas for all clusters in the fleet.
- **Validation scripts fail:** Ensure that test scripts are idempotent and have clear pass/fail output.
- **Manual approval delays:** Use automation for nonproduction. Require manual only for production.
- **Q: Can I use open-source software tools for validation?**
  - **A:** Yes. Integrate [Sonobuoy](https://sonobuoy.io/) for conformance and [kube-bench](https://github.com/aquasecurity/kube-bench) for security.
- **Q: What's unique to AKS?**
  - **A:** Azure Kubernetes Fleet Manager enables true staged rollouts and validation gates natively.

</details>

---

## Scenario 3: Safe Kubernetes version intake

**Challenge:** "I need to adopt Kubernetes 1.30 without breaking existing workloads or APIs."

**Strategy:** Use multiphase validation with canary deployment.

To learn more, see [Canary deployments](/azure/architecture/reference-architectures/containers/aks-microservices/aks-microservices-advanced#deployment-strategies) and [API deprecation policies](https://kubernetes.io/docs/reference/using-api/deprecation-policy/).

### Implementation steps

#### Step 1: API deprecation analysis

```bash
# Install and run API deprecation scanner
kubectl apply -f https://github.com/doitintl/kube-no-trouble/releases/latest/download/knt-full.yaml

# Scan for deprecated APIs
kubectl run knt --image=doitintl/knt:latest --rm -it --restart=Never -- \
  -c /kubeconfig -o json > api-deprecation-report.json

# Review and remediate findings
cat api-deprecation-report.json | jq '.[] | select(.deprecated==true)'
```

To learn more, see the [Kubernetes API deprecation guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/) and [kube-no-trouble documentation](https://github.com/doitintl/kube-no-trouble).

#### Step 2: Create a canary environment

```azurecli-interactive
# Create canary cluster with target version
az aks create \
  --resource-group canary-rg \
  --name aks-canary-k8s130 \
  --kubernetes-version 1.30.0 \
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
# Test new Kubernetes 1.30 features
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
    
    # Check new API versions
    kubectl api-versions | grep "v1.30"
```

### Success metrics

- **API compatibility:** 100% (zero breaking changes)
- **Performance:** ≤5% regression in key metrics
- **Feature adoption:** New features validated in canary

---

## Scenario 4: Fastest security patch deployment

**Challenge:** "A critical CVE was announced. I need patches deployed across all clusters within 4 hours."

**Strategy:** Use automated node image patching with minimal disruption.

To learn more, see [Node image upgrade strategies](./node-image-upgrade.md), [Autoupgrade channels](./auto-upgrade-cluster.md), and [Security patching best practices](/azure/aks/operator-best-practices-cluster-security).

### Implementation steps

#### Step 1: Emergency response preparation

```azurecli-interactive
# Set up automated monitoring for security updates
az aks nodepool update \
  --resource-group production-rg \
  --cluster-name aks-prod \
  --name nodepool1 \
  --auto-upgrade-channel SecurityPatch

# Configure maintenance window for emergency patches
az aks maintenance-configuration create \
  --resource-group production-rg \
  --cluster-name aks-prod \
  --config-name emergency-security \
  --week-index First,Second,Third,Fourth \
  --day-of-week Monday,Tuesday,Wednesday,Thursday,Friday \
  --start-hour 0 \
  --duration 4
```

To learn more, see [Planned maintenance configuration](./planned-maintenance.md) and [Autoupgrade channels](./auto-upgrade-cluster.md#configure-autoupgrade-channel).

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

- **Deployment time:** <4 hours from common vulnerabilities and exposures announcement
- **Coverage:** 100% of nodes patched
- **Downtime:** <5 minutes per node pool

---

## Scenario 5: Application architecture for seamless upgrades

**Challenge:** "I want my applications to handle cluster upgrades gracefully without affecting users."

**Strategy:** Use resilient application patterns with graceful degradation.

To learn more, see [Application reliability patterns](/azure/architecture/framework/resiliency/reliability-patterns), [Pod disruption budgets](https://kubernetes.io/docs/tasks/run-application/configure-pdb/), and [Health check best practices](/azure/architecture/patterns/health-endpoint-monitoring).

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
  template:
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

#### Step 2: Configure pod disruption budgets

```yaml
# optimal-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
spec:
  selector:
    matchLabels:
      app: api
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

To learn more, see [Circuit breaker pattern](/azure/architecture/patterns/circuit-breaker), [Retry pattern](/azure/architecture/patterns/retry), and [Application resilience](https://docs.microsoft.com/azure/architecture/framework/resiliency/).

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

### Success metrics

- **Error rate:** <0.01% during upgrades
- **Response time:** <10% degradation
- **Recovery time:** <30 seconds after node replacement

---

## Monitoring and alerting setup

To learn more, see the [AKS monitoring overview](./monitor-aks.md), [Container insights](/azure/azure-monitor/containers/container-insights-overview), and [Prometheus metrics](/azure/azure-monitor/essentials/prometheus-metrics-overview).

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

### Dashboard configuration

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

To learn more, see the [AKS troubleshooting guide](/azure/aks/troubleshooting), [Node and pod troubleshooting](./node-access.md), and [Upgrade error messages](./upgrade-aks-cluster.md#troubleshoot-aks-cluster-upgrade-error-messages).

### Common issues and solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| Stuck node drain | Pods won't evict. | Check PDB configuration, increase drain timeout. |
| High error rates | 5xx responses are increasing. | Verify health checks, check resource limits. |
| Slow upgrades | Takes >2 hours. | Increase `maxSurge`, optimize container startup. |
| DNS resolution | Service discovery is failing. | Verify `CoreDNS` pods, check service endpoints. |

### Emergency rollback procedures

```bash
# Quick rollback script
#!/bin/bash
echo "Initiating emergency rollback..."

# Switch traffic back to previous cluster
az network traffic-manager endpoint update \
  --resource-group traffic-rg \
  --profile-name production-tm \
  --name current-endpoint \
  --target-resource-id "/subscriptions/.../clusters/aks-previous"

# Verify rollback success
curl -f https://api.production.com/health
echo "Rollback completed in $(date)"
```

---

## Related resources

### Specialized scenarios

- [Stateful workloads](stateful-workload-upgrades.md): Use PostgreSQL, Redis, and MongoDB upgrade patterns.
- [Upgrade scenarios hub](upgrade-scenarios-hub.md): Choose your upgrade path.
- [Basic AKS upgrades](upgrade-aks-cluster.md): Find simple cluster version upgrades.

### Supporting tools

- [Autoupgrade configuration](auto-upgrade-cluster.md): Use automated upgrade channels.
- [Maintenance windows](planned-maintenance.md): Schedule upgrade windows.
- [Upgrade monitoring](aks-communication-manager.md): Use real-time upgrade alerts.

### Best practices

- [Cluster reliability](best-practices-app-cluster-reliability.md): Design for upgrades.
- [Security guidelines](operator-best-practices-cluster-security.md): Use secure upgrade practices.
- [Support policies](support-policies.md): Understand upgrade support windows.

## Next tasks

- **Set up monitoring:** Configure [upgrade notifications](aks-communication-manager.md) before your first upgrade.
- **Practice safely:** Test scenarios in staging by using [cluster snapshots](node-pool-snapshot.md).
- **Automate gradually:** Start with [autoupgrade channels](auto-upgrade-cluster.md) for nonproduction.
- **Handle stateful data:** Review [stateful workload patterns](stateful-workload-upgrades.md) if you run databases.

## Related content

- For more help, see [AKS support options](aks-support-help.md) or review [common upgrade scenarios](./upgrade-cluster.md#common-upgrade-scenarios-and-recommendations).
