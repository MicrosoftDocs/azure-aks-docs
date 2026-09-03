---
title: Migrate from Windows Server 2019 to Windows Server 2022
description: Learn how to migrate AKS from Windows Server 2019 to 2022.
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.topic: how-to
ms.reviewer: srikantsarwa
ms.custom: windows-server

---

# Migration guide: Windows Server 2019 to 2022 on AKS

To help ensure Azure remains the best possible experience with the highest standards of safety and reliability, migrate AKS Hybrid and Edge workloads from Windows Server 2019 to Windows Server 2022.

This guide helps you migrate your AKS Hybrid and Edge workloads from Windows Server 2019 to Windows Server 2022. The migration involves updating container images, creating new node pools, and redeploying applications to ensure compatibility with the newer operating system.

## What you'll accomplish

- Update container images to use Windows Server 2022 base images.
- Create new Windows Server 2022 node pools.
- Migrate workloads with zero downtime using rolling deployments.
- Remove legacy Windows Server 2019 infrastructure.

## Prerequisites

Before you begin the migration, ensure you have the following prerequisites in place:

- Azure CLI and `kubectl` installed
- Access to AKS clusters
- Permissions to create and delete node pools

## Step 1: identify affected clusters

To list clusters and check for Windows Server 2019 node pools, run the following commands:

```azurecli
az aksarc list --output table
az aksarc nodepool list --cluster-name <cluster-name> --resource-group <resource-group>
```

## Step 2: update container images

To use Windows Server 2022 base images, run the following command to update Dockerfiles:

```dockerfile
# Change from ltsc2019 to ltsc2022
FROM mcr.microsoft.com/windows/servercore:ltsc2022
```

Next, rebuild and push the images:

```bash
docker build -t myapp:ws2022 .
docker push myregistry.azurecr.io/myapp:ws2022
```

## Step 3: create Windows Server 2022 node pool

Add a new Windows Server 2022 node pool to your AKS cluster:

```azurecli
az aksarc nodepool add \
  --cluster-name <cluster-name> \
  --resource-group <resource-group> \
  --name ws2022pool \
  --os-type Windows \
  --os-sku Windows2022 \
  --node-count 3
```

Verify nodes are ready:

```bash
kubectl get nodes -l kubernetes.io/os=windows
```

## Step 4: update deployment manifests

Add node selectors to target Windows Server 2022:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-windows-app
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/os: windows
        kubernetes.io/os-version: "10.0.20348"  # Windows Server 2022
      containers:
        - name: my-app
          image: myregistry.azurecr.io/myapp:ws2022
```

## Step 5: deploy and verify

Apply the updated deployment:

```bash
kubectl apply -f deployment.yaml
kubectl rollout status deployment/my-windows-app
```

Verify pods are running:

```bash
kubectl get pods -l app=my-windows-app -o wide
kubectl logs deployment/my-windows-app
```

## Step 6: Remove old node pools

Drain nodes:

```bash
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --force
```

Delete the old pool:

```azurecli
az aksarc nodepool delete \
  --cluster-name <cluster-name> \
  --resource-group <resource-group> \
  --name <old-nodepool-name> \
  --yes
```

## Step 7: Validate

Confirm migration success:

```bash
kubectl get deployments --all-namespaces
kubectl get pods --all-namespaces -o wide
kubectl get nodes
```

## Common issues

If you encounter issues during migration, consider the following troubleshooting tips:

**Pods not scheduling:**
- Check node selectors match: `kubectl describe pod <pod-name>`
- Verify node labels: `kubectl describe node <node-name>`

**Image compatibility:**
- Rebuild images with Windows Server 2022 base
- Test in non-production environment first

**Network issues:**
- Verify network policies: `kubectl get networkpolicies`
- Check service endpoints: `kubectl get endpoints`

## Testing checklist

Before production migration:

- Container images build on Windows Server 2022
- Applications start without errors
- Network connectivity verified
- Storage mounts correctly
- Performance acceptable
- Monitoring operational

## Next steps

- [AKS overview](../aks-overview.md)
- [Windows container upgrade guide](/azure/aks/upgrade-windows-2019-2022)
- [Azure Local](/azure/azure-local)
