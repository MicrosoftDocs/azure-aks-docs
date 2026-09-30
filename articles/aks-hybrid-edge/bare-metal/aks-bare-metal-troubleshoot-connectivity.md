---
title: Troubleshoot AKS on Bare Metal Connectivity
description: Resolve Azure Arc proxy, kubeconfig, authentication, authorization, and kubectl issues for AKS on bare metal clusters.
ms.topic: troubleshooting-general
ms.date: 09/14/2026
ai-usage: ai-assisted
author: RishiMody
ms.author: rmody
ms.custom: bare-metal
---

# Troubleshoot cluster connectivity

Use this guidance when you can't connect to an Azure Kubernetes Service (AKS) on bare metal cluster or run `kubectl` commands.

## Azure Arc proxy doesn't connect

1. Confirm that the cluster provisioning state is `Succeeded`.
1. Confirm that the host and connected Kubernetes resources are connected to Azure Arc.
1. Install or update the `connectedk8s` extension.

   ```azurecli
   az extension add --name connectedk8s --upgrade
   ```

1. Sign in again with `az login`, then restart `az connectedk8s proxy`.

Keep the proxy command running in its terminal and run `kubectl` in a second terminal.

## kubectl uses the wrong cluster

Check the current context:

```bash
kubectl config current-context
```

If you downloaded Ubuntu credentials to a separate file, specify that file:

```bash
kubectl --kubeconfig ./aks-ubuntu.kubeconfig get nodes
```

## Authentication or RBAC fails

Confirm that you're signed in with the expected Azure account and subscription:

```azurecli
az account show \
  --query "{subscription:name,user:user.name}" \
  --output table
```

Make sure your account belongs to the Microsoft Entra security group configured for cluster administration.

## The node isn't ready

Check node conditions and recent cluster events:

```bash
kubectl describe node <node-name>
kubectl get events --all-namespaces --sort-by=.lastTimestamp
```

Look for `MemoryPressure`, `DiskPressure`, image pull failures, or network errors.

## Next steps

- [Connect to the cluster](aks-bare-metal-connect-to-cluster.md).
