---
title: Upgrade AKS on Bare Metal on Ubuntu (Preview)
description: Check available Kubernetes patch versions and upgrade an AKS on bare metal cluster on Ubuntu by using Azure CLI.
ms.topic: how-to
ms.date: 09/14/2026
ai-usage: ai-assisted
author: RishiMody
ms.author: rmody
ms.custom: bare-metal
---

# Upgrade an AKS on bare metal cluster on Ubuntu (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

AKS on bare metal supports Kubernetes patch-version upgrades during the Ubuntu public preview. Minor-version upgrades and downgrades aren't supported.

Because the preview uses a single-node cluster, workloads are temporarily unavailable during an upgrade. Schedule the upgrade during a maintenance window and back up important workload data.

## Prerequisites

- An AKS on bare metal cluster on Ubuntu in a `Succeeded` state.
- The public-preview version of the `aksarc` Azure CLI extension.
- A healthy Azure Arc connection from the Ubuntu host.

Update the public extension before you begin:

```azurecli
az extension add --name aksarc --upgrade --allow-preview true
```

## Check available upgrades

The versions supported for new deployments don't necessarily represent valid upgrade paths for an existing cluster. For deployment versions and their full parameter values, see [Supported Kubernetes versions](aks-bare-metal-create-cluster-ubuntu-cli.md#supported-kubernetes-versions).

List the patch versions available for your cluster:

```azurecli
az aksarc get-upgrades \
  --resource-group <resource-group> \
  --name <cluster-name> \
  --output table
```

## Upgrade the cluster

Upgrade to an available patch version:

```azurecli
az aksarc upgrade \
  --resource-group <resource-group> \
  --name <cluster-name> \
  --kubernetes-version <kubernetes-version>
```

## Verify the upgrade

Check the Kubernetes version that Azure reports:

```azurecli
az aksarc show \
  --resource-group <resource-group> \
  --name <cluster-name> \
  --query properties.kubernetesVersion \
  --output tsv
```

Connect to the cluster and verify the node version:

```bash
kubectl get nodes
```

## Next steps

- [Troubleshoot Ubuntu deployments](aks-bare-metal-troubleshoot-ubuntu-deployment.md).
