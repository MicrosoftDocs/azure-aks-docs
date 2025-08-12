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

# Stateful workload upgrade patterns

Upgrade clusters that run databases and stateful applications without data loss by using these proven patterns.

## What this article covers

This article provides database-specific upgrade patterns for Azure Kubernetes Service (AKS) clusters with stateful workloads, such as:

- PostgreSQL Ferris wheel pattern for ~30-second downtime.
- Redis rolling replacement for zero-downtime cache upgrades.
- MongoDB step-down cascades for replica set safety.
- Emergency upgrade checklists for security responses.
- Validation and rollback procedures for data protection.

These patterns are best for use by database administrators for applications with persistent data and mission-critical stateful services.

For more information, see these related articles:

- To upgrade your production AKS clusters, see [AKS production upgrade strategies](aks-production-upgrade-strategies.md).
- To check for and apply basic upgrades to your AKS cluster, see [Upgrade an Azure Kubernetes Service cluster](upgrade-aks-cluster.md).
- To use the scenario hub to help you choose the right AKS upgrade approach, see [AKS upgrade scenarios: Choose your path](upgrade-scenarios-hub.md).

---

For a quick start, select a link for instructions:

- [Do you need an emergency upgrade?](#emergency-upgrade-checklist)
- [Do you need help with a PostgreSQL cluster?](#the-ferris-wheel-pattern-postgresql)
- [Do you need a Redis cache rolling replace?](#redis-cluster-rolling-replace)

## Choose your pattern

| Database type | Upgrade pattern | Downtime | Complexity | Best for |
|---------------|----------------|--------------------------|------------|----------|
| PostgreSQL | [Ferris wheel](#the-ferris-wheel-pattern-postgresql) | ~30-second downtime | Medium | Production databases |
| Redis | [Rolling replace](#redis-cluster-rolling-replace) | None | Low | Cache layers |
| MongoDB | [Step-down cascade](#mongodb-replica-set-step-down) | ~10-second downtime | Medium | Document databases |
| Elasticsearch | Shard rebalancing *(coming soon)* | None | High | Search clusters |
| Any database | Backup-restore *(coming soon)* | 2-minute to 5-minute downtime | Low | Simple setups |

## Emergency upgrade checklist

Do you need to upgrade now because of security issues?

1. Run the following commands for an immediate safety check (two minutes):

   ```bash
   # Verify all replicas are healthy
   kubectl get pods -l tier=database -o wide
   # Check replication lag
   ./scripts/check-replica-health.sh
   # Ensure recent backup exists
   kubectl get job backup-job -o jsonpath='{.status.completionTime}'
   ```

1. Choose an emergency pattern (one minute):

   - **PostgreSQL/MySQL:** Use [Ferris wheel](#the-ferris-wheel-pattern-postgresql) (30-second downtime).
   - **Redis/Memcached:** Use [Rolling replace](#redis-cluster-rolling-replace) (zero downtime).
   - **MongoDB/CouchDB:** Use [Step-down cascade](#mongodb-replica-set-step-down) (10-second downtime).

1. Run with a safety net (15-minute to 30-minute window):

   - Always test rollback procedures in advance.
   - Monitor application metrics during the upgrade.
   - Keep the database team on standby.

---

## The Ferris wheel pattern: PostgreSQL

This pattern is best for 3-node PostgreSQL clusters with primary/replica setup across availability zones.

Visual pattern:

```
Initial: [PRIMARY] [REPLICA-1] [REPLICA-2]
Step 1:  [PRIMARY] [REPLICA-1] [NEW-NODE]  ← Add new node
Step 2:  [REPLICA-1] [NEW-NODE] [REPLICA-2] ← Promote & remove old primary  
Step 3:  [NEW-PRIMARY] [NEW-NODE] [REPLICA-2] ← Complete rotation
```

### Quick implementation (20 minutes)

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
<summary><strong>Detailed step-by-step guide</strong></summary>

#### Prerequisites validation

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

#### Step 1: Scale up with a new node

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

#### Step 2: Run a controlled failover

```bash
#!/bin/bash
# controlled-failover.sh

echo "=== Starting Controlled Failover ==="
# Ensure minimal replication lag (< 0.1-second)
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

#### Step 3: Clean up and validate

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

### Advanced configuration

For mission-critical databases that require a <10-second downtime:

```yaml
# Use synchronous replication with multiple standbys
# postgresql.conf
synchronous_standby_names = 'ANY 2 (standby1, standby2, standby3)'
synchronous_commit = 'remote_apply'
```

### Success validation

To validate your progress, use the following checklist:

- New primary accepts reads and writes.
- All replicas show healthy replication.
- Application reconnects automatically.
- No data loss detected.
- Backup/restore tested on new primary.

### Emergency rollback

##### For immediate issues (<2 minutes)

Redirect traffic to the previous primary:

   ```bash
   kubectl patch service postgres-primary --patch '{
     "spec": {
       "selector": {
         "statefulset.kubernetes.io/pod-name": "postgres-cluster-1"
       }
     }
   }'
   ```

##### For comprehensive failover recovery (5-10 minutes)

1. Stop writes to the current primary:
   ```bash
   kubectl exec postgres-primary-0 -- psql -c "SELECT pg_reload_conf();"
   ```

1. Redirect service to a healthy replica:
   ```bash
   kubectl patch service postgres-primary --patch '{"spec":{"selector":{"statefulset.kubernetes.io/pod-name":"postgres-replica-1-0"}}}'
   ```

1. Promote a replica to the new primary:
   ```bash
   kubectl exec postgres-replica-1-0 -- pg_ctl promote -D /var/lib/postgresql/data
   kubectl wait --for=condition=ready pod postgres-replica-1-0 --timeout=60s
   ```

1. Update connection strings:
   ```bash
   kubectl patch configmap postgres-config --patch '{"data":{"primary-host":"postgres-replica-1-0.postgres"}}'
   ```

1. Verify that the new primary accepts writes:
   ```bash
   kubectl exec postgres-replica-1-0 -- psql -c "CREATE TABLE upgrade_test (id serial, timestamp timestamp default now());"
   kubectl exec postgres-replica-1-0 -- psql -c "INSERT INTO upgrade_test DEFAULT VALUES;"
   ```

**Expected outcome:** Approximately 30-second downtime, zero data loss, and an upgraded node that runs the current version of Kubernetes.

#### Step 3: Upgrade Node1 (former primary)

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

#### Step 4: Rejoin Node1 as a replica

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

#### Step 6: Final failover (Node2 → Node3)

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

### Validation and monitoring

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

## Redis cluster rolling replace

In this scenario, a six-node Redis cluster (three primaries and three replicas) requires zero downtime.

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

## MongoDB replica set step-down

In this scenario, a three-member MongoDB replica set requires coordinated primary step-down.

### Implementation

```bash
#!/bin/bash
# MongoDB upgrade script

Echo "=== MongoDB Replica Set Upgrade ==="

# Check replica set status
kubectl exec mongo-0 --mongo --eval "rs.status()"
```
