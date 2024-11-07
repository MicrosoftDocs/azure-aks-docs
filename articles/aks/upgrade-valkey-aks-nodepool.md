---
title: Validate Valkey resiliency during an AKS node pool upgrade
description: In this article, you learn how to validate the resiliency of the Valkey cluster on Azure Kubernetes during a nodepool upgrade.
ms.topic: how-to
ms.custom: azure-kubernetes-service
ms.date: 10/28/2024
author: schaffererin
ms.author: schaffererin
---

# Validate Valkey resiliency during an AKS node pool upgrade

Using the same Valkey cluster on Azure Kubernetes Service (AKS) that you deployed in the previous article with Locust running, you can validate the resiliency of the Valkey cluster during an AKS node pool upgrade.


## Upgrade the AKS cluster

1. List [the available versions for the AKS cluster][check-for-available-aks-cluster-upgrades] and identify the target version you are upgrading to.

    ```bash
    az aks get-upgrades --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --output table
    ```

2. Upgrade the AKS control plane only. In this example, the target version is 1.30.0:

    ```bash
    az aks upgrade --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --control-plane-only --kubernetes-version 1.30.0
    ```

3. Verify the [Locust client started in the previous article][validate-valkey-cluster] is still running. The Locust dashboard will show the impact of the AKS node pool upgrade on the Valkey cluster.

4. Upgrade the Valkey node pool.

    ```bash
    az aks nodepool upgrade \
        --resource-group $MY_RESOURCE_GROUP_NAME \
        --cluster-name $MY_CLUSTER_NAME \
        --kubernetes-version 1.30.0 \
        --name valkey
    ```

4. While the upgrade process is running, you can monitor the Locust dashboard to see the status of the client requests. Ideally, the dashboard should be similar to the following screenshot:

      :::image type="content" source="media/valkey-stateful-workload/aks-upgrade-impact-valkey-cluster.png" alt-text="Screenshot of a web page showing the Locust test dashboard during the AKS upgrade.":::

   Locust is running with 100 users making 50 requests per second. During the upgrade process, 4 times a master Pod is evicted. You can see that the shard is not available for a few seconds, but the Valkey cluster is still able to respond to requests for the other shards.

<!-- Internal links -->

[check-for-available-aks-cluster-upgrades]: /azure/aks/upgrade-aks-cluster?tabs=azure-cli#check-for-available-aks-cluster-upgrades
[validate-valkey-cluster]: ./validate-valkey-cluster.md
