---
title: Validate Valkey Resiliency During an Azure Kuberentes Service (AKS) Node Pool Upgrade
description: In this article, you learn how to validate the resiliency of the Valkey cluster on Azure Kubernetes during a nodepool upgrade.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 09/15/2025
author: schaffererin
ms.author: schaffererin
ms.custom: 'stateful-workloads'
# Customer intent: As a Kubernetes administrator, I want to validate the resiliency of the Valkey cluster during a node pool upgrade, so that I can ensure minimal disruption and continued performance of my applications throughout the upgrade process.
---

# Validate Valkey resiliency during an AKS node pool upgrade

Using the same Valkey cluster on Azure Kubernetes Service (AKS) that you deployed in the previous article with Locust running, you can validate the resiliency of the Valkey cluster during an AKS node pool upgrade. This process helps validate that Valkey maintains resiliency during AKS node pool upgrades. Monitoring with Locust ensures visibility into request handling and shard availability, allowing you to confidently manage upgrades with minimal service disruption.

## Upgrade the AKS cluster

1. List [the available versions for the AKS cluster][check-for-available-aks-cluster-upgrades] and identify the target version you're upgrading to using the [`az aks get-upgrades`](/cli/azure/aks#az_aks_get_upgrades) command.

    ```azurecli-interactive
    az aks get-upgrades --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --output table
    ```

1. Upgrade the AKS control plane using the [`az aks upgrade`](/cli/azure/aks#az_aks_upgrade) command. In this example, the target version is 1.33.0.

    ```azurecli-interactive
    az aks upgrade --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --control-plane-only --kubernetes-version 1.33.0
    ```

1. Verify the [Locust client started in the previous article][validate-valkey-cluster] is still running. The Locust dashboard will show the impact of the AKS node pool upgrade on the Valkey cluster.
1. Upgrade the Valkey node pool using the [`az aks nodepool upgrade`](/cli/azure/aks/nodepool#az_aks_nodepool_upgrade) command.

    ```azurecli-interactive
    az aks nodepool upgrade \
        --resource-group $MY_RESOURCE_GROUP_NAME \
        --cluster-name $MY_CLUSTER_NAME \
        --kubernetes-version 1.33.0 \
        --name valkey
    ```

1. While the upgrade process is running, you can monitor the Locust dashboard to see the status of the client requests. Ideally, the dashboard should be similar to the following screenshot:

    :::image type="content" source="media/valkey-stateful-workload/aks-upgrade-impact-valkey-cluster.png" alt-text="Screenshot of a web page showing the Locust test dashboard during the AKS upgrade.":::

    Locust is running with 100 users making 50 requests per second. During the upgrade process, 4 times a master Pod is evicted. You can see that the shard isn't available for a few seconds, but the Valkey cluster is still able to respond to requests for the other shards.

<!-- Internal links -->

[check-for-available-aks-cluster-upgrades]: /azure/aks/upgrade-aks-cluster?tabs=azure-cli#check-for-available-aks-cluster-upgrades
[validate-valkey-cluster]: ./validate-valkey-cluster.md
