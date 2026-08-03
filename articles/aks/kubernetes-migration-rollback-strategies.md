---
title: Rollback Strategies for Kubernetes Migration on Azure Kubernetes Service (AKS)
description: Guidance on rollback strategies for Kubernetes migration on Azure Kubernetes Service (AKS)
ms.topic: overview
ms.date: 07/10/2026
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.custom: aks-migration
ms.collection: 
 - migration
ai-usage: ai-assisted
# Customer intent: As a customer performing a Kubernetes migration on AKS, I want to understand how to roll back changes safely if something goes wrong.
---

# Rollback strategies for Kubernetes migration on Azure Kubernetes Service (AKS)

When a Kubernetes migration fails at any stage — traffic cutover, data sync, or infrastructure swap — well-prepared rollback strategies let you revert to your source environment with minimal downtime and clear remediation steps. This guide focuses on practical, AKS-specific rollback patterns for traffic, application, data, and infrastructure layers, with command snippets you can copy and adapt.

See the [AKS migration guide](./aks-migration.md) for full migration planning and prerequisites.

## Quick scenario opener

You’ve provisioned an AKS cluster, synced workloads, and performed a traffic cutover. One of the following happens:

- Latency or errors spike after cutover.
- Database replication lag exceeds acceptable thresholds.
- A control-plane or node-pool regression appears.
- A deployment introduced a severe bug.

Use the layer-appropriate rollback strategy below instead of a full "tear-down and revert" unless absolutely necessary. Layered rollbacks let you limit blast radius and shorten recovery time.

## 1 — Traffic-level rollback

Goal: move user traffic off the target AKS cluster back to the old environment (or to a passive endpoint) without waiting for long DNS TTLs.

When to use: fatal application errors after cutover, critical performance regressions, or discovery of data divergence that requires users to hit the source until fixes are applied.

Options:

- Azure Traffic Manager (weighted routing failover)
- Azure Front Door (origin/backend failover)
- DNS TTL lowering as pre-cutover insurance (set low TTL so you can revert quickly)

Example CLI snippets

- Azure Traffic Manager: change endpoint weight so source becomes primary

    ```azurecli-interactive
    az network traffic-manager endpoint update \
      --resource-group myResourceGroup \
      --profile-name myTrafficProfile \
      --name source-endpoint \
      --type azureEndpoints \
      --weight 100
    ```

- Azure Front Door (Standard/Premium): disable a backend via the REST API (safe, direct way to take an origin out of rotation)

    ```rest
    az rest --method PATCH \
      --uri "https://management.azure.com/subscriptions/<SUB>/resourceGroups/<RG>/providers/Microsoft.Network/frontDoors/<FRONTDOOR>/backendPools/<POOL>/backends/<BACKEND_ID>?api-version=2020-05-01" \
      --body '{"enabledState":"Disabled"}'
    ```

- Lower DNS TTL before cutover (prepare): update an A record TTL to 60 seconds so post-cutover rollbacks propagate quickly

    ```azurecli-interactive
    az network dns record-set a update \
      --resource-group myDnsRG \
      --zone-name example.com \
      --name '@' \
      --set ttl=60
    ```

Operational tips

- Pre-configure weighted Traffic Manager profiles or Front Door backend pools so you only change a single value at cutover or rollback.
- Test DNS and CDN caches; TTL changes help but don't guarantee instant global switch.
- Have a documented runbook that lists the exact endpoints and who can perform the change.

## 2 — Application-level rollback

Goal: revert application code/config in the cluster quickly without touching networking or storage.

When to use: a bad deployment, incorrect configuration, or traffic-level rollback is undesired but code needs to be reverted.

Options:

- Helm rollback to a prior revision
- GitOps revert (Argo CD or Flux) to pin the application back to a good commit/revision

Example CLI snippets

- Helm rollback (safe, single-release rollback)

    ```bash
    # inspect history
    helm history my-release -n my-namespace
    
    # rollback to revision 2
    helm rollback my-release 2 -n my-namespace
    ```

- Argo CD: set the app to a specific revision and sync

    ```bash
    # set desired revision (commit SHA or tag) then sync
    argocd app set my-app --revision <commit-sha>
    argocd app sync my-app
    ```

- Flux (GitOps): revert the commit in Git, push, then reconcile

    ```bash
    # on your Git repo tracked by Flux
    git revert <bad-commit-sha>
    git push origin main
    
    # tell Flux to fetch and apply (use your repo and kustomization names)
    flux reconcile source git my-repo --namespace flux-system
    flux reconcile kustomization my-app --namespace apps
    ```

Operational tips

- Keep Helm release history depth configured so you can rollback multiple revisions.
- For Argo CD, enable app rollback protection policies and require manual approval for production syncs if appropriate.
- For Flux, the authoritative source is Git — always revert in Git and promote the revert through your normal CI/CD pipeline.

## 3 — Data and storage rollback

Goal: recover or re-attach storage to a prior known-good state, or stop reads/writes to an out-of-sync target DB while you restore.

When to use: corruption, accidental deletes, failed migration that left target data inconsistent, or unacceptable replication lag.

Options:

- Azure managed disk (snapshot) snapshots and disk restore
- Velero backup/restore for Kubernetes resources and persistent volume snapshots
- Use replication lag as a go/no-go gate (monitor and abort if lag > threshold)

Example CLI snippets

- Create a managed disk snapshot (AKS node or persistent disk)

    ```azurecli-interactive
    az snapshot create \
      --resource-group myResourceGroup \
      --name mySnapshot \
      --source /subscriptions/<SUB>/resourceGroups/myResourceGroup/providers/Microsoft.Compute/disks/myDisk
    ```

- Create a new disk from a snapshot (to attach or replace a PVC-backed disk)

    ```azurecli-interactive
    az disk create \
      --resource-group myResourceGroup \
      --name myDiskRestored \
      --source /subscriptions/<SUB>/resourceGroups/myResourceGroup/providers/Microsoft.Compute/snapshots/mySnapshot
    ```

- Velero: take a backup before migration and restore if needed

    ```bash
    # create a backup (namespaces or entire cluster)
    velero backup create pre-migration-backup --include-namespaces default,apps
    
    # restore from backup
    velero restore create --from-backup pre-migration-backup
    ```

- Check replication lag (example using Azure Monitor metrics — metric name depends on DB type; adapt to your server)

    ```azurecli-interactive
    az monitor metrics list \
      --resource /subscriptions/<SUB>/resourceGroups/<RG>/providers/Microsoft.DBforPostgreSQL/servers/<serverName> \
      --metric "ReplicationLag" \
      --interval PT1M \
      --output table
    # Note: metric names vary by service. Confirm the metric name for your database (e.g., Azure Database for PostgreSQL, MySQL, or SQL).
    ```

Operational tips

- Take a final consistent backup/snapshot immediately before cutover; label it with timestamp and migration identifier.
- Test restores regularly in a sandbox so you know the approximate RTO/RPO.
- If replication lag is your gate, define clear numeric thresholds (e.g., >30s or >5% of RPO) and automate alerts tied into your go/no-go checklist.

## 4 — Infrastructure-level rollback

Goal: roll back cluster or node-pool changes (blue-green node pools), or restore infrastructure IaC state when provisioning changes cause regressions.

When to use: node regressions, kernel or CNI regressions, or when the new node pool or cluster-level changes introduced instability.

Options:

- Blue-green node pool failback (keep the old node pool available, cordon/drain new pool)
- Terraform state rollback (restore previous state file or use backend versioning)

Example CLI snippets

- Blue-green node pool failback using kubectl (cordon/drain new nodes, uncordon old ones)

    ```bash
    # cordon new nodes so they stop receiving new pods
    kubectl cordon aks-newpool-123 -n kube-system
    
    # drain new nodes, evicting pods to the old pool (ignore daemonsets, delete local state as needed)
    kubectl drain aks-newpool-123 --ignore-daemonsets --delete-local-data --timeout=10m
    
    # make sure old nodes are schedulable
    kubectl uncordon aks-oldpool-01
    ```

- Terraform: pull a prior state and push it back (example workflow — test on a non-production backend first)

    ```terraform
    # pull current state to a file (backup)
    terraform state pull > current.tfstate
    
    # assume you have a saved 'before-migration.tfstate' from pre-migration; push it to restore remote state
    terraform state push before-migration.tfstate
    ```

Operational tips

- For blue-green node pools, keep the previous node pool around and ready; never delete until the migration is fully validated.
- Prefer restoring Terraform state from the backend's object versioning (for example Azure Storage blob versioning) rather than pushing state files unless you understand the consequences.
- If you must rebuild infrastructure, follow an IaC-driven restore with a known-good module and variables to avoid configuration drift.

## Rollback decision table

Use this table to decide which rollback layer to use first. In many incidents, you should escalate from less-disruptive to more-disruptive layers (traffic → app → data → infra).

| Rollback layer | AKS tool / mechanism | Rollback time estimate | When to use |
| -------------- | -------------------- | ---------------------- | ----------- |
| Traffic routing | Azure Traffic Manager / Front Door / DNS TTL | Minutes (propagation + health checks) | Critical user-facing failures after cutover; prefer if code is fine but traffic should return to old environment. |
| Helm rollback | Helm (helm rollback) | Seconds–minutes per release | Regression introduced by a Helm release or broken chart values; quick when release history exists. |
| GitOps revert | Argo CD / Flux via Git revert & sync | Minutes–tens of minutes (depends on CI and sync) | When manifest changes are the cause and you follow GitOps workflow; safest single source-of-truth revert. |
| Volume snapshot | Azure managed disk snapshots / Velero | Minutes–hours (snapshot creation fast; restore and attach may take longer) | Data corruption, accidental deletes, or when PVs must be restored to a known-good point. |
| Blue-green node pool failback | kubectl cordon/drain, node pool retention | Minutes–hours (pod rescheduling time) | Node-level regressions, kernel/CNI issues, or when node-pool images are incompatible. |

## Runbook checklist for any rollback decision

1. Stop new changes: disable CI/CD pipelines and block auto-sync so you don’t re-introduce the bad state.
1. Communicate: page the stakeholders and post the rollback decision and ETA in your incident channel.
1. Verify health and metrics: confirm user-facing errors, latency, error-rate, and DB replication status.
1. Choose minimal-impact rollback layer first (prefer traffic or app rollback).
1. Execute the rollback steps and monitor closely.
1. If rollback fails or uncovers additional issues, escalate to data or infra rollbacks and follow your incident management process.
1. After successful rollback, run a root-cause analysis (RCA) and bake changes into your migration plan.

## Cross-links and next steps

- [AKS migration guide](./aks-migration.md)
- [AKS production upgrade strategies (canary and blue-green patterns)](./aks-production-upgrade-strategies.md)
- [Blue-green node pool upgrade details](./blue-green-node-pool-upgrade.md)
