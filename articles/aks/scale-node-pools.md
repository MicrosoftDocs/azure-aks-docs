---
title: Scale Node Pools in Azure Kubernetes Service (AKS)
description: Learn how to manually and automatically scale node pools in Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 07/19/2023
author: schaffererin
ms.author: schaffererin
ms.subservice: aks-nodes
# Customer intent: "As a Kubernetes administrator, I want to scale my node pools in AKS to handle varying workloads efficiently."
---

# Scale node pools in Azure Kubernetes Service (AKS)

As your application workload demands change, you might need to scale the number of nodes in a node pool in Azure Kubernetes Service (AKS). In this article, you learn how to manually and automatically scale node pools in AKS.

## Prerequisites for AKS node pool scaling

- An existing AKS cluster with at least one node pool. If you need to create one, see [Create an AKS cluster with node pools](create-node-pools.md).
- You need the Azure CLI version 2.2.0 or later installed and configured. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).

## Scale a node pool manually

1. Scale the number of nodes in a node pool using the [`az aks nodepool scale`][az-aks-nodepool-scale] command. The `--node-count` flag specifies the desired number of nodes in the node pool. In this example, the node pool is scaled to five nodes.

    ```azurecli-interactive
    az aks nodepool scale \
        --resource-group <resource-group-name> \
        --cluster-name <cluster-name> \
        --name <node-pool-name> \
        --node-count 5 \
        --no-wait
    ```

1. Check the status of your node pools using the [`az aks nodepool list`][az-aks-nodepool-list] command.

    ```azurecli-interactive
    az aks nodepool list --resource-group <resource-group-name> --cluster-name <cluster-name>
    ```

     The following example output shows the node pool is in the _Scaling_ state with a new count of five nodes:

    ```output
    [
      {
        ...
        "count": 5,
        ...
        "name": "<node-pool-name>",
        "orchestratorVersion": "1.15.7",
        ...
        "provisioningState": "Scaling",
        ...
        "vmSize": "Standard_DS2_v2",
        ...
      },
      {
        ...
        "count": 2,
        ...
        "name": "<node-pool-name-2>",
        "orchestratorVersion": "1.15.7",
        ...
        "provisioningState": "Succeeded",
        ...
        "vmSize": "Standard_DS2_v2",
        ...
      }
    ]
    ```

    It takes a few minutes for the scale operation to complete. After the scale operation is complete, the node pool's `provisioningState` changes to _Succeeded_.

## Scale a node pool automatically with the cluster autoscaler

You can use the [cluster autoscaler](./cluster-autoscaler-overview.md) with multiple node pools, and you can enable it on individual node pools and pass unique autoscaling rules to them.

- Enable the cluster autoscaler on an existing node pool using the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--update-cluster-autoscaler` flag. The `--min-count` and `--max-count` flags specify the minimum and maximum number of nodes in the node pool. In this example, the cluster autoscaler is enabled with a minimum count of one node and a maximum count of five nodes:

    ```azurecli-interactive
    az aks nodepool update \
      --resource-group <resource-group-name> \
      --cluster-name <cluster-name> \
      --name <node-pool-name> \
      --update-cluster-autoscaler \
      --min-count 1 \
      --max-count 5
    ```

> [!NOTE]
> If you want to disable the cluster autoscaler on a node pool, use the [`az aks nodepool update`][az-aks-nodepool-update] command with the `--disable-cluster-autoscaler` flag instead of `--update-cluster-autoscaler`.

## Next steps: Manage node pools in AKS

To learn more about managing node pools in AKS, see [Manage node pools in Azure Kubernetes Service (AKS)](manage-node-pools.md).
