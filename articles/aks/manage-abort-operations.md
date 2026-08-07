---
title: Abort an AKS long-running operation
description: Learn how to abort a long-running Azure resource operation on an Azure Kubernetes Service (AKS) managed cluster or node pool.
ms.topic: how-to
ms.date: 08/06/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.service: azure-kubernetes-service
ms.subservice: aks-nodes
ms.custom: devx-track-azurecli
# Customer intent: As a cloud administrator managing an Azure Kubernetes Service (AKS) cluster, I want to abort long-running operations on node pools or clusters, so that I can regain control and ensure operational efficiency without being hindered by stalled tasks.
---

# Abort a long-running operation on an Azure Kubernetes Service (AKS) cluster

Azure resource operations on an AKS managed cluster or node pool, such as create, upgrade, and scale operations, can take longer than expected. You can inspect the progress of these operations and abort the latest running operation to regain control of the managed cluster or node pool. The commands in this article don't inspect or terminate Kubernetes workload deployments or processes running inside pods.

Use the [`az aks operation show-latest`](/cli/azure/aks/operation#az-aks-operation-show-latest) command to show the status of the latest operation on a managed cluster:

```azurecli-interactive
az aks operation show-latest \
    --resource-group myResourceGroup \
    --name myCluster
```

The following output is an example:

```bash
{
  "endTime": null,
  "error": null,
  "id": "/subscriptions/<subscription-id>/resourcegroups/myResourceGroup/providers/Microsoft.ContainerService/managedClusters/contoso/operations/<operation-id>",
  "name": "<operation-id>",
  "operations": null,
  "percentComplete": 1.0,
  "resourceGroup": "myResourceGroup",
  "resourceId": null,
  "startTime": "2024-06-12T18:16:21+00:00",
  "status": "InProgress"
}
```

The output includes the following operation details:

- `percentComplete`: The reported completion percentage for the operation.
- `startTime`: The time when the operation started.
- `status`: The current operation status, such as `InProgress`.

Use the [`az aks operation show`](/cli/azure/aks/operation#az-aks-operation-show) command and the operation ID from the preceding output to show a specific operation:

```azurecli-interactive
az aks operation show \
    --resource-group myResourceGroup \
    --name myCluster \
    --operation-id "<operation-id>"
```

Allow operations to complete gracefully when possible. You can abort the latest operation before it reaches a terminal state if the operation is stuck or failing, or if you started it in error. The ability to abort the latest running operation is generally available through the [Azure REST API](/rest/api/azure/) and the [Azure CLI](/cli/azure/).

## Before you begin

- Azure CLI version 2.85.0 or later. Run `az --version` to find the version, and run `az upgrade` to upgrade the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
- The `aks-preview` extension, which provides the `az aks operation` commands. The extension installs automatically the first time you run an `az aks operation` command. To install it manually, run `az extension add --name aks-preview`. If the extension is already installed, update it with `az extension update --name aks-preview`.

## Abort a long-running operation on AKS

### [Azure CLI](#tab/azure-cli)

Use [`az aks nodepool operation-abort`](/cli/azure/aks/nodepool#az-aks-nodepool-operation-abort) to cancel the latest running operation on a node pool. Use [`az aks operation-abort`](/cli/azure/aks#az-aks-operation-abort) to cancel the latest running operation on a managed cluster.

The following example cancels an operation on a node pool in a specified cluster:

```azurecli-interactive
az aks nodepool operation-abort \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name myNodePool
```

The following example cancels an operation on a specified cluster:

```azurecli-interactive
az aks operation-abort \
    --name myAKSCluster \
    --resource-group myResourceGroup
```

### [Azure REST API](#tab/azure-rest)

Use the Azure REST API to cancel the latest running operation on a node pool or managed cluster.

The following example cancels the latest running operation on a specified node pool:

```rest
POST https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/managedclusters/{resourceName}/agentPools/{agentPoolName}/abort?api-version=2025-08-01
```

For more information, see [Agent Pools - Abort Latest Operation](/rest/api/aks/agent-pools/abort-latest-operation?view=rest-aks-2025-08-01&preserve-view=true).

The following example cancels the latest running operation on a specified managed cluster:

```rest
POST https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/managedclusters/{resourceName}/abort?api-version=2025-08-01
```

For more information, see [Managed Clusters - Abort Latest Operation](/rest/api/aks/managed-clusters/abort-latest-operation?view=rest-aks-2025-08-01&preserve-view=true).

A successful cancel request returns `202 Accepted` when cancellation continues asynchronously or `204 No Content` when no response body is needed. If the original operation finishes before AKS can cancel it, the request returns `409 Conflict`.

---

After AKS accepts the cancel request, the operation progresses through the following statuses:

| Operation status | Meaning |
| --- | --- |
| `Canceling` | AKS is canceling the operation. |
| `Canceled` | AKS finished canceling the operation. |

Use the following command to check the latest managed cluster operation:

```azurecli-interactive
az aks operation show-latest \
    --resource-group myResourceGroup \
    --name myAKSCluster
```

To check the latest operation on a node pool, include the `--nodepool-name` parameter:

```azurecli-interactive
az aks operation show-latest \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --nodepool-name myNodePool
```

Canceling an operation doesn't by itself roll back changes that AKS applied before cancellation.

## Next steps

For more information about monitoring the performance and health of your Kubernetes cluster and container workloads, see [Container insights](/azure/azure-monitor/containers/container-insights-overview).

<!-- LINKS - internal -->
[install-azure-cli]: /cli/azure/install-azure-cli
