---
title: Create Node Pools with Unique Subnets in Azure Kubernetes Service (AKS)
description: Learn how to create node pools with unique subnets in Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.date: 09/26/2025
author: schaffererin
ms.author: schaffererin
ms.subservice: aks-nodes
ms.service: azure-kubernetes-service
# Customer intent: As a node pool operator, I want to create node pools with unique subnets in AKS to support logical isolation of workloads.
---

# Create node pools with unique subnets in Azure Kubernetes Service (AKS)

Certain workloads might require splitting cluster nodes into separate pools for logical isolation. Separate subnets dedicated to each node pool in the cluster can help support this isolation, which can address requirements such as having noncontiguous virtual network address space to split across node pools.

In this article, you learn how to create node pools with unique subnets in Azure Kubernetes Service (AKS).

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) version 2.35.0 or later. Run `az version` to find the version. If you need to install or upgrade, see [Install Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli).
- An existing AKS cluster with a system node pool. If you need to create one, see [Create an AKS cluster with a single node pool](./create-node-pools.md#create-an-aks-cluster-with-a-single-node-pool).

## Limitations

- All subnets assigned to node pools must belong to the same virtual network (VNet).
- System pods must have access to all nodes and pods in the cluster to provide critical functionality, such as DNS resolution and tunneling kubectl logs/exec/port-forward proxy.
- If you expand your VNet after creating the cluster, you must update your cluster before adding a subnet outside the original CIDR block. While AKS errors out on the agent pool add, the `aks-preview` Azure CLI extension (version 0.5.66 and higher) now supports running `az aks update` command with only the required `--resource-group $RESOURCE_GROUP --name $CLUSTER_NAME` arguments. This command performs an update operation without making any changes, which can recover a cluster stuck in a failed state.
- In clusters with Kubernetes version less than 1.23.3, kube-proxy SNATs traffic from new subnets, which can cause Azure Network Policy to drop the packets.
- Windows nodes SNAT traffic to the new subnets until the node pool is reimaged.
- Internal load balancers default to one of the node pool subnets.

## Add a node pool with a unique subnet

- Add a node pool with a unique subnet into your existing AKS cluster using the [`az aks nodepool add`](/cli/azure/aks#az_aks_nodepool_add) command and the `--vnet-subnet-id` parameter specified.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group $RESOURCE_GROUP_NAME \
        --cluster-name $CLUSTER_NAME \
        --name $NODE_POOL_NAME \
        --node-count 3 \
        --vnet-subnet-id $SUBNET_RESOURCE_ID
    ```

## Next steps

For more information about node pools in AKS, see [Manage node pools for a cluster in Azure Kubernetes Service (AKS)](./manage-node-pools.md).
