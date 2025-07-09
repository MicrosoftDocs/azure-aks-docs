---
title: Stateful Workload Upgrade Patterns
description: Zero-downtime upgrade strategies for AKS clusters running databases, caching systems, and message queues with data persistence guarantees.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.date: 07/09/2025
author: kaarthis
ms.author: kaarthis
ms.custom: stateful, databases, zero-downtime
---

# Stateful Workload Upgrade Patterns

Upgrade clusters running databases and stateful applications without data loss using these proven patterns.

> **Quick start:** [Emergency upgrade needed? →](#emergency-upgrade-checklist) | [PostgreSQL cluster? →](#the-ferris-wheel-pattern-postgresql) | [Redis cache? →](#redis-cluster-rolling-replace)

## 🎯 Choose Your Pattern

| Database Type | Upgrade Pattern | Downtime | Complexity | Best For |
|---------------|----------------|----------|------------|----------|
| **PostgreSQL** | [Ferris Wheel](#the-ferris-wheel-pattern-postgresql) | ~30 seconds | Medium | Production DBs |
| **Redis** | [Rolling Replace](#redis-cluster-rolling-replace) | None | Low | Cache layers |
| **MongoDB** | [Stepdown Cascade](#mongodb-replica-set-stepdown) | ~10 seconds | Medium | Document DBs |
| **Elasticsearch** | [Shard Rebalancing](#elasticsearch-shard-rebalancing) | None | High | Search clusters |
| **Any Database** | [Backup-Restore](#universal-backup-restore-pattern) | 2-5 minutes | Low | Simple setups |

## ⚡ Emergency Upgrade Checklist

**Need to upgrade NOW due to security issues?**

1. **Immediate Safety Check** (2 minutes)
   ```bash
   # Verify all replicas are healthy
   kubectl get pods -l tier=database -o wide
   
   # Check replication lag
   ./scripts/check-replica-health.sh
   
   # Ensure recent backup exists
   kubectl get job backup-job -o jsonpath='{.status.completionTime}'
   ```

2. **Choose Emergency Pattern** (1 minute)
   - **PostgreSQL/MySQL**: Use [Ferris Wheel](#the-ferris-wheel-pattern-postgresql) (30 sec downtime)
   - **Redis/Memcached**: Use [Rolling Replace](#redis-cluster-rolling-replace) (zero downtime)
   - **MongoDB/CouchDB**: Use [Stepdown Cascade](#mongodb-replica-set-stepdown) (10 sec downtime)

3. **Execute with Safety Net** (15-30 minutes)
   - Always have tested rollback ready
   - Monitor application metrics during upgrade
   - Keep database team on standby

---

## The Ferris Wheel Pattern: PostgreSQL

> **Best for:** 3-node PostgreSQL clusters with primary/replica setup across availability zones

**Visual Pattern:**
```
Initial: [PRIMARY] [REPLICA-1] [REPLICA-2]
Step 1:  [PRIMARY] [REPLICA-1] [NEW-NODE]  ← Add new node
Step 2:  [REPLICA-1] [NEW-NODE] [REPLICA-2] ← Promote & remove old primary  
Step 3:  [NEW-PRIMARY] [NEW-NODE] [REPLICA-2] ← Complete rotation
```

### ⚡ Quick Implementation (20 minutes)

```bash
# 1. Add new node to cluster
kubectl scale statefulset postgres-cluster --replicas=4

# 2. Wait for new replica to sync
kubectl wait --for=condition=ready pod postgres-cluster-3 --timeout=300s

# 3. Promote new primary and failover (30-second downtime window)
kubectl exec postgres-cluster-3 -- pg_ctl promote -D /var/lib/postgresql/data

# 4. Update service endpoint
kubectl patch service postgres-primary --patch '{"spec":{"selector":{"app":"postgres-cluster","role":"primary","pod":"postgres-cluster-3"}}}'

# 5. Remove old primary node
kubectl delete pod postgres-cluster-0
```

<details>
<summary><strong>📋 Detailed Step-by-Step Guide</strong></summary>

#### Prerequisites Validation

```bash
#!/bin/bash
# pre-upgrade-validation.sh

echo "=== PostgreSQL Cluster Health Check ==="

# Check replication status
kubectl exec postgres-primary-0 -- psql -c "SELECT * FROM pg_stat_replication;"

# Verify sync replication (must show 'sync' state)
SYNC_COUNT=$(kubectl exec postgres-primary-0 -- psql -t -c "SELECT count(*) FROM pg_stat_replication WHERE sync_state='sync';")
if [ "$SYNC_COUNT" -lt 2 ]; then
    echo "ERROR: Need at least 2 synchronous replicas"
    exit 1
fi

# Confirm recent backup exists
LAST_BACKUP=$(kubectl get job postgres-backup -o jsonpath='{.status.completionTime}')
echo "Last backup: $LAST_BACKUP"

# Test failover capability in staging first
echo "✅ Prerequisites validated"
```

#### Step 1: Scale Up with New Node

```bash
# Add new node with upgraded Kubernetes version
kubectl patch statefulset postgres-cluster --patch '{
  "spec": {
    "replicas": 4,
    "template": {
      "spec": {
        "nodeSelector": {
          "kubernetes.io/arch": "amd64",
          "aks-nodepool": "upgraded-pool"
        }
      }
    }
  }
}'

# Monitor new pod startup
kubectl get pods -l app=postgres-cluster -w

# Verify new replica joins cluster
kubectl exec postgres-cluster-3 -- psql -c "SELECT * FROM pg_stat_replication;"
```

#### Step 2: Execute Controlled Failover

```bash
#!/bin/bash
# controlled-failover.sh

echo "=== Starting Controlled Failover ==="

# Ensure minimal replication lag (< 100ms)
LAG=$(kubectl exec postgres-primary-0 -- psql -t -c "SELECT EXTRACT(EPOCH FROM now() - pg_last_xact_replay_timestamp());")
if (( $(echo "$LAG > 0.1" | bc -l) )); then
    echo "ERROR: Replication lag too high ($LAG seconds)"
    exit 1
fi

# Pause application writes (use connection pool drain)
kubectl patch configmap pgbouncer-config --patch '{"data":{"pgbouncer.ini":"[databases]\napp_db = host=postgres-primary port=5432 dbname=appdb pool_mode=statement max_db_connections=0"}}'

# Wait for active transactions to complete
sleep 10

# Promote new primary (this is the 30-second downtime window)
kubectl exec postgres-cluster-3 -- pg_ctl promote -D /var/lib/postgresql/data

# Update service selector to new primary
kubectl patch service postgres-primary --patch '{
  "spec": {
    "selector": {
      "statefulset.kubernetes.io/pod-name": "postgres-cluster-3"
    }
  }
}'

# Resume application writes
kubectl patch configmap pgbouncer-config --patch '{"data":{"pgbouncer.ini":"[databases]\napp_db = host=postgres-primary port=5432 dbname=appdb pool_mode=statement"}}'

echo "✅ Failover completed"
```

#### Step 3: Cleanup and Validation

```bash
# Remove old primary node
kubectl delete pod postgres-cluster-0 --force

# Scale back to 3 replicas
kubectl patch statefulset postgres-cluster --patch '{"spec":{"replicas":3}}'

# Validate cluster health
kubectl exec postgres-cluster-3 -- psql -c "SELECT * FROM pg_stat_replication;"

# Test application connectivity
kubectl run test-db-connection --image=postgres:15 --rm -it -- psql -h postgres-primary -U app_user -d app_db -c "SELECT version();"
```

</details>

### 🔧 Advanced Configuration

For mission-critical databases requiring <10 second downtime:

```yaml
# Use synchronous replication with multiple standbys
# postgresql.conf
synchronous_standby_names = 'ANY 2 (standby1, standby2, standby3)'
synchronous_commit = 'remote_apply'
```

### ✅ Success Validation

- [ ] New primary accepts reads and writes
- [ ] All replicas show healthy replication
- [ ] Application reconnects automatically
- [ ] No data loss detected
- [ ] Backup/restore tested on new primary

### 🚨 Emergency Rollback

```bash
# If issues detected, immediate rollback
kubectl patch service postgres-primary --patch '{
  "spec": {
    "selector": {
      "statefulset.kubernetes.io/pod-name": "postgres-cluster-1"
    }
  }
}'
```

**Expected Outcome:** ~30 seconds downtime, zero data loss, upgraded node running latest Kubernetes

echo "=== Step 2: Failover Primary (Node1 → Node2) ==="

# Stop writes to current primary
kubectl exec postgres-primary-0 -- psql -c "SELECT pg_reload_conf();"
kubectl patch service postgres-primary --patch '{"spec":{"selector":{"statefulset.kubernetes.io/pod-name":"postgres-replica-1-0"}}}'

# Promote replica-1 to primary
kubectl exec postgres-replica-1-0 -- pg_ctl promote -D /var/lib/postgresql/data

# Wait for promotion to complete
kubectl wait --for=condition=ready pod postgres-replica-1-0 --timeout=60s

# Update connection strings
kubectl patch configmap postgres-config --patch '{"data":{"primary-host":"postgres-replica-1-0.postgres"}}'

# Verify new primary is accepting writes
kubectl exec postgres-replica-1-0 -- psql -c "CREATE TABLE upgrade_test (id serial, timestamp timestamp default now());"
kubectl exec postgres-replica-1-0 -- psql -c "INSERT INTO upgrade_test DEFAULT VALUES;"
```

#### Step 3: Upgrade Node1 (Former Primary)

```bash
#!/bin/bash
# upgrade-node1.sh

echo "=== Step 3: Upgrade Node1 (Former Primary) ==="

# Drain Node1 gracefully
kubectl drain aks-nodepool1-12345678-vmss000000 --grace-period=300 --delete-emptydir-data --ignore-daemonsets

# Trigger node upgrade
az aks nodepool upgrade \
    --resource-group production-rg \
    --cluster-name aks-prod \
    --name nodepool1 \
    --kubernetes-version 1.29.0 \
    --max-surge 0 \
    --max-unavailable 1

# Monitor upgrade progress
while kubectl get node aks-nodepool1-12345678-vmss000000 -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "False"; do
    echo "Waiting for node upgrade to complete..."
    sleep 30
done

echo "Node1 upgrade completed"
```

#### Step 4: Rejoin Node1 as Replica

```bash
#!/bin/bash
# rejoin-node1.sh

echo "=== Step 4: Rejoin Node1 as Replica ==="

# Wait for postgres pod to be scheduled on upgraded node
kubectl wait --for=condition=ready pod postgres-primary-0 --timeout=300s

# Reconfigure as replica pointing to new primary (Node2)
kubectl exec postgres-primary-0 -- bash -c "
echo 'standby_mode = on' >> /var/lib/postgresql/data/recovery.conf
echo 'primary_conninfo = \"host=postgres-replica-1-0.postgres port=5432\"' >> /var/lib/postgresql/data/recovery.conf
"

# Restart postgres to apply replica configuration
kubectl delete pod postgres-primary-0
kubectl wait --for=condition=ready pod postgres-primary-0 --timeout=120s

# Verify replication is working
kubectl exec postgres-replica-1-0 -- psql -c "SELECT * FROM pg_stat_replication WHERE application_name='postgres-primary-0';"

echo "Node1 successfully rejoined as replica"
```

#### Step 5: Upgrade Node3 (Replica-2)

```bash
#!/bin/bash
# upgrade-node3.sh

echo "=== Step 5: Upgrade Node3 (Replica-2) ==="

# Similar process for Node3
kubectl drain aks-nodepool1-12345678-vmss000002 --grace-period=300 --delete-emptydir-data --ignore-daemonsets

az aks nodepool upgrade \
    --resource-group production-rg \
    --cluster-name aks-prod \
    --name nodepool1 \
    --kubernetes-version 1.29.0 \
    --max-surge 0 \
    --max-unavailable 1

# Wait for upgrade and pod readiness
kubectl wait --for=condition=ready pod postgres-replica-2-0 --timeout=300s

# Verify all replicas are in sync
kubectl exec postgres-replica-1-0 -- psql -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"
```

#### Step 6: Final Failover (Node2 → Node3)

```bash
#!/bin/bash
# final-failover.sh

echo "=== Step 6: Final Failover and Node2 Upgrade ==="

# Failover primary from Node2 to Node3
kubectl patch service postgres-primary --patch '{"spec":{"selector":{"statefulset.kubernetes.io/pod-name":"postgres-replica-2-0"}}}'
kubectl exec postgres-replica-2-0 -- pg_ctl promote -D /var/lib/postgresql/data

# Upgrade Node2
kubectl drain aks-nodepool1-12345678-vmss000001 --grace-period=300 --delete-emptydir-data --ignore-daemonsets

az aks nodepool upgrade \
    --resource-group production-rg \
    --cluster-name aks-prod \
    --name nodepool1 \
    --kubernetes-version 1.29.0 \
    --max-surge 0 \
    --max-unavailable 1

# Rejoin Node2 as replica
kubectl wait --for=condition=ready pod postgres-replica-1-0 --timeout=300s

echo "All nodes upgraded successfully. PostgreSQL cluster operational."
```

### Validation and Monitoring

```bash
#!/bin/bash
# post-upgrade-validation.sh

echo "=== Post-Upgrade Validation ==="

# Verify cluster topology
kubectl get pods -l app=postgres -o wide

# Check all replicas are connected
kubectl exec postgres-replica-2-0 -- psql -c "SELECT application_name, client_addr, state FROM pg_stat_replication;"

# Validate data integrity
kubectl exec postgres-replica-2-0 -- psql -c "SELECT COUNT(*) FROM upgrade_test;"

# Performance validation
kubectl exec postgres-replica-2-0 -- psql -c "EXPLAIN ANALYZE SELECT * FROM pg_stat_activity;"

echo "Upgrade validation completed successfully"
```

---

## Redis Cluster Rolling Replace

**Scenario:** 6-node Redis cluster (3 masters, 3 replicas) requiring zero downtime.

### Implementation

```bash
#!/bin/bash
# redis-cluster-upgrade.sh

echo "=== Redis Cluster Rolling Upgrade ==="

# Get cluster topology
kubectl exec redis-0 -- redis-cli cluster nodes

# Upgrade replica nodes first (no impact to writes)
for replica in redis-1 redis-3 redis-5; do
    echo "Upgrading replica: $replica"
    
    # Remove replica from cluster temporarily
    REPLICA_ID=$(kubectl exec redis-0 -- redis-cli cluster nodes | grep $replica | cut -d' ' -f1)
    kubectl exec redis-0 -- redis-cli cluster forget $REPLICA_ID
    
    # Drain and upgrade node
    kubectl delete pod $replica
    kubectl wait --for=condition=ready pod $replica --timeout=120s
    
    # Rejoin cluster
    kubectl exec redis-0 -- redis-cli cluster meet $(kubectl get pod $replica -o jsonpath='{.status.podIP}') 6379
    
    echo "Replica $replica upgraded and rejoined"
done

# Upgrade master nodes with failover
for master in redis-0 redis-2 redis-4; do
    echo "Upgrading master: $master"
    
    # Trigger failover to replica
    kubectl exec $master -- redis-cli cluster failover
    
    # Wait for failover completion
    sleep 10
    
    # Upgrade the demoted master (now replica)
    kubectl delete pod $master
    kubectl wait --for=condition=ready pod $master --timeout=120s
    
    echo "Master $master upgraded"
done

echo "Redis cluster upgrade completed"
```

---

## MongoDB Replica Set Stepdown

**Scenario:** 3-member MongoDB replica set requiring coordinated primary stepdown.

### Implementation

```bash
#!/bin/bash
# mongodb-upgrade.sh

echo "=== MongoDB Replica Set Upgrade ==="

# Check replica set status
kubectl exec mongo-0 -- mongo --eval "rs.status()"

# Upgrade secondary members first
for secondary in mongo-1 mongo-2; do
    echo "Upgrading secondary: $secondary"
    
    # Remove from replica set temporarily
    kubectl exec mongo-0 -- mongo --eval "rs.remove('$secondary.mongo:27017')"
    
    # Upgrade pod
    kubectl delete pod $secondary
    kubectl wait --for=condition=ready pod $secondary --timeout=180s
    
    # Re-add to replica set
    kubectl exec mongo-0 -- mongo --eval "rs.add('$secondary.mongo:27017')"
    
    # Wait for sync
    while ! kubectl exec mongo-0 -- mongo --eval "rs.status().members.find(m => m.name.includes('$secondary')).state" | grep -q "2"; do
        echo "Waiting for $secondary to sync..."
        sleep 10
    done
    
    echo "Secondary $secondary upgraded"
done

# Step down primary and upgrade
echo "Stepping down primary: mongo-0"
kubectl exec mongo-0 -- mongo --eval "rs.stepDown(60)"

# Wait for new primary election
sleep 20

# Upgrade former primary
kubectl delete pod mongo-0
kubectl wait --for=condition=ready pod mongo-0 --timeout=180s

echo "MongoDB replica set upgrade completed"
```

---

## Advanced Patterns

### Elasticsearch Shard Rebalancing

```yaml
# elasticsearch-upgrade-policy.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: es-upgrade-config
data:
  upgrade.sh: |
    #!/bin/bash
    # Disable shard allocation
    curl -X PUT "localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
    {
      "persistent": {
        "cluster.routing.allocation.enable": "primaries"
      }
    }'
    
    # Perform rolling upgrade
    for node in es-master-0 es-master-1 es-master-2; do
        kubectl delete pod $node
        kubectl wait --for=condition=ready pod $node --timeout=300s
        
        # Wait for node to rejoin cluster
        while ! curl -s "localhost:9200/_cat/nodes" | grep -q $(kubectl get pod $node -o jsonpath='{.status.podIP}'); do
            sleep 10
        done
    done
    
    # Re-enable shard allocation
    curl -X PUT "localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
    {
      "persistent": {
        "cluster.routing.allocation.enable": null
      }
    }'
```

### Kafka Broker Rotation

```bash
#!/bin/bash
# kafka-upgrade.sh

echo "=== Kafka Cluster Upgrade ==="

# Upgrade brokers one by one
for broker in kafka-0 kafka-1 kafka-2; do
    echo "Upgrading broker: $broker"
    
    # Gracefully shutdown broker
    kubectl exec $broker -- kafka-server-stop.sh
    
    # Wait for partition reassignment
    kubectl exec kafka-0 -- kafka-reassign-partitions.sh \
        --bootstrap-server kafka-0:9092 \
        --verify \
        --reassignment-json-file /tmp/reassignment.json
    
    # Upgrade pod
    kubectl delete pod $broker
    kubectl wait --for=condition=ready pod $broker --timeout=180s
    
    echo "Broker $broker upgraded"
done
```

---

## Monitoring and Alerting

### Custom Metrics for Stateful Workloads

```yaml
# stateful-monitoring.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: postgres-monitoring
spec:
  selector:
    matchLabels:
      app: postgres
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: stateful-upgrade-rules
spec:
  groups:
  - name: postgres.rules
    rules:
    - alert: PostgreSQLReplicationLag
      expr: pg_stat_replication_lag_seconds > 10
      for: 2m
      annotations:
        summary: "PostgreSQL replication lag is high"
    
    - alert: PostgreSQLPrimaryDown
      expr: up{job="postgres-primary"} == 0
      for: 1m
      annotations:
        summary: "PostgreSQL primary is down"
  
  - name: redis.rules  
    rules:
    - alert: RedisClusterDown
      expr: redis_cluster_state != 1
      for: 1m
      annotations:
        summary: "Redis cluster is not healthy"
```

---

## Disaster Recovery Procedures

### Emergency Rollback for PostgreSQL

```bash
#!/bin/bash
# emergency-rollback.sh

echo "=== EMERGENCY ROLLBACK INITIATED ==="

# Restore from latest backup
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: postgres-emergency-restore
spec:
  template:
    spec:
      containers:
      - name: restore
        image: postgres:13
        command:
        - /bin/bash
        - -c
        - |
          pg_restore -h postgres-primary -U postgres -d production /backups/latest.dump
      restartPolicy: Never
EOF

# Monitor restore progress
kubectl logs job/postgres-emergency-restore -f

echo "Emergency rollback completed"
```

---

## Pod Disruption Budget Configurations for Stateful Workloads

### PostgreSQL PDB

```yaml
# postgres-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: postgres-pdb
spec:
  selector:
    matchLabels:
      app: postgres
  minAvailable: 2  # Always keep primary + 1 replica
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: postgres-primary-pdb
spec:
  selector:
    matchLabels:
      app: postgres
      role: primary
  minAvailable: 1  # Never allow primary to be disrupted without coordination
```

### Redis Cluster PDB

```yaml
# redis-cluster-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: redis-masters-pdb
spec:
  selector:
    matchLabels:
      app: redis
      role: master
  minAvailable: 2  # Always keep majority of masters
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: redis-replicas-pdb
spec:
  selector:
    matchLabels:
      app: redis
      role: replica
  maxUnavailable: 1  # Can afford to lose one replica at a time
```

### MongoDB PDB

```yaml
# mongodb-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: mongodb-pdb
spec:
  selector:
    matchLabels:
      app: mongodb
  minAvailable: 2  # Maintain majority for replica set elections
```

---

## AKS-Specific Configurations

### Node Pool Configuration for Stateful Workloads

```azurecli-interactive
# Create dedicated node pool for stateful workloads
az aks nodepool add \
  --resource-group production-rg \
  --cluster-name aks-prod \
  --name stateful-pool \
  --node-count 3 \
  --node-vm-size Standard_D4s_v5 \
  --zones 1 2 3 \
  --max-surge 0 \
  --max-unavailable 1 \
  --node-taints workload=stateful:NoSchedule \
  --labels workload=stateful

# Configure undrainable node behavior for careful orchestration
az aks nodepool update \
  --resource-group production-rg \
  --cluster-name aks-prod \
  --name stateful-pool \
  --undrainable-node-behavior Cordon \
  --max-blocked-nodes 1 \
  --drain-timeout 10
```

### Storage Configuration

```yaml
# persistent-storage.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd-retain
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS
  kind: Managed
  cachingmode: ReadOnly
reclaimPolicy: Retain  # Important: Don't delete data on cluster upgrades
volumeBindingMode: WaitForFirstConsumer
allowedTopologies:
- matchLabelExpressions:
  - key: topology.disk.csi.azure.com/zone
    values:
    - eastus-1
    - eastus-2
    - eastus-3
```

---

## Best Practices Summary

1. **Always upgrade replicas before primaries**
2. **Maintain at least one healthy replica during upgrades**
3. **Use synchronous replication for zero data loss**
4. **Test failover procedures in staging environments**
5. **Monitor replication lag throughout the process**
6. **Have rollback procedures ready and tested**
7. **Use pod disruption budgets appropriate for your topology**
8. **Coordinate upgrades during low-traffic periods**
9. **Use dedicated node pools with appropriate taints/tolerations**
10. **Configure proper storage classes with retain policies**

---

## Automation Scripts

### Automated PostgreSQL Ferris Wheel

```yaml
# postgres-upgrade-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: postgres-ferris-wheel-upgrade
spec:
  template:
    spec:
      serviceAccountName: postgres-upgrade-sa
      containers:
      - name: upgrade-orchestrator
        image: postgres-upgrade-orchestrator:latest
        env:
        - name: CLUSTER_NAME
          value: "aks-prod"
        - name: RESOURCE_GROUP
          value: "production-rg"
        - name: TARGET_VERSION
          value: "1.29.0"
        command:
        - /bin/bash
        - -c
        - |
          # Execute all ferris wheel steps
          /scripts/01-validate-cluster.sh
          /scripts/02-failover-primary.sh
          /scripts/03-upgrade-nodes.sh
          /scripts/04-validate-completion.sh
        volumeMounts:
        - name: upgrade-scripts
          mountPath: /scripts
      volumes:
      - name: upgrade-scripts
        configMap:
          name: postgres-upgrade-scripts
          defaultMode: 0755
      restartPolicy: Never
  backoffLimit: 1
```

---

## Related Resources

### 🎯 Upgrade Strategies
- **[Production Upgrade Strategies →](aks-production-upgrade-strategies.md)** - Blue-green, canary, and emergency patterns
- **[Upgrade Scenarios Hub →](upgrade-scenarios-hub.md)** - Choose your upgrade approach
- **[Basic AKS Upgrades →](upgrade-aks-cluster.md)** - Standard cluster version upgrades

### 💾 Stateful Workload Management
- **[Persistent Volumes →](concepts-storage.md)** - Storage concepts and configuration
- **[Azure Disk CSI →](azure-disk-csi.md)** - High-performance block storage
- **[Azure Files CSI →](azure-files-csi.md)** - Shared file system storage
- **[Backup and Recovery →](ha-dr-overview.md)** - Disaster recovery strategies

### 🔧 Database-Specific Guides
- **[PostgreSQL on AKS →](postgresql-ha-overview.md)** - High-availability PostgreSQL
- **[MongoDB on AKS →](mongodb-overview.md)** - MongoDB cluster management
- **[Redis/Valkey on AKS →](valkey-overview.md)** - In-memory data store patterns

### 📊 Monitoring and Operations
- **[Monitoring AKS →](monitor-aks.md)** - Comprehensive monitoring setup
- **[Container Insights →](monitor-aks-reference.md)** - Application performance monitoring
- **[Upgrade Notifications →](aks-communication-manager.md)** - Real-time upgrade alerts

## Summary

This article provides clear, step-by-step patterns for upgrading stateful workloads on AKS with minimal downtime and no data loss. Use the quick start, checklists, and validation steps to ensure a safe upgrade. Always test in a staging environment before production.

## Next Steps

1. **Assess your data:** Review all stateful workloads and confirm backup and recovery plans.
2. **Test patterns:** Practice upgrade patterns in a staging environment with real data volumes.
3. **Set up monitoring:** Enable database-specific monitoring before starting upgrades.
4. **Automate safely:** Use automation with required validation steps.
5. **Document procedures:** Write clear runbooks for your database configurations.

> **Tip:** For critical databases, always test upgrade procedures with production-like data and network conditions. Consider [Azure Database services](/azure/postgresql/) for applications that require 99.99% uptime.
