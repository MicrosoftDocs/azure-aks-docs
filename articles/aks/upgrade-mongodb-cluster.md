---
title: Validate MongoDB resiliency during an Azure Kubernetes Service (AKS) node pool upgrade
description: In this article, you learn how to test resiliency of MongoDB cluster on Azure Kubernetes Service (AKS) during node pool upgrade.
ms.topic: how-to
ms.custom: azure-kubernetes-service
ms.date: 01/07/2025
author: schaffererin
ms.author: schaffererin
---

# Validate MongoDB resiliency during an Azure Kubernetes Service (AKS) node pool upgrade

Using the same MongoDB cluster on Azure Kubernetes Service (AKS) that you deployed in the previous article with Locust running, you can validate the resiliency of the MongoDB cluster during an AKS node pool upgrade.

## Upgrade the AKS cluster

In this scenario, you upgrade the AKS cluster to a newer version. Upgrading the cluster makes it unavailable for a short period of time.

1. Get the current AKS cluster version using the [`az aks show`](/cli/azure/aks#az-aks-show) command.

    ```azurecli-interactive
    az aks show --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --query kubernetesVersion
    ```

    Example output:

    ```output
    "1.30"
    ```

2. [Check the available versions for the AKS cluster][check-for-available-aks-cluster-upgrades] using the [`az aks get-upgrades`](/cli/azure/aks#az-aks-get-upgrades) command and decide which version you want to upgrade to.

    ```azurecli-interactive
    az aks get-upgrades --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --output table
    ```

    Example output:

    ```output
    Name     ResourceGroup                     MasterVersion    Upgrades
    -------  --------------------------------  ---------------  --------------
    default  myResourceGroup-rg-australiaeast  1.30.6           1.31.1, 1.31.2
    ```

3. List the node pools in the AKS cluster using the [`az aks nodepool list`](/cli/azure/aks/nodepool#az-aks-nodepool-list) command.

    ```azurecli-interactive
    az aks nodepool list --resource-group $MY_RESOURCE_GROUP_NAME --cluster-name $MY_CLUSTER_NAME --output table
    ```

    Example output:

    ```output
    Name        OsType    KubernetesVersion    VmSize           Count    MaxPods    ProvisioningState    Mode
    ----------  --------  -------------------  ---------------  -------  ---------  -------------------  ------
    systempool  Linux     1.30                 Standard_DS4_v2  1        30         Succeeded            System
    userpool    Linux     1.30                 Standard_DS4_v2  3        30         Succeeded            User
    ```

4. Once you decide your target Kubernetes version, you need to first upgrade the AKS control plane using the [`az aks upgrade`](/cli/azure/aks#az-aks-upgrade) command. In this example, we upgrade to Kubernetes version 1.31.1.

    ```azurecli-interactive
    az aks upgrade --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --kubernetes-version 1.31.1 --control-plane-only --yes
    ```

    :::image type="content" source="media/upgrade-mongodb-cluster/locust-upgrade-control-plane.png" alt-text="Screenshot of a web page showing the Locust test dashboard when upgrading control plane." lightbox="./media/upgrade-mongodb-cluster/locust-upgrade-control-plane.png":::

5. Upgrade the `userpool` node pool to the newer version using the [`az aks nodepool upgrade`](/cli/azure/aks/nodepool#az-aks-nodepool-upgrade) command. Make sure that Locust from the previous article is still running so you can validate the resiliency of the MongoDB cluster during the AKS node pool upgrade.

    ```azurecli-interactive
    az aks nodepool upgrade --resource-group $MY_RESOURCE_GROUP_NAME --cluster-name $MY_CLUSTER_NAME --name userpool --kubernetes-version 1.31.1 --yes
    ```

    This command takes some time to complete. During this time, nodes of the AKS cluster become unavailable as they are upgraded to the newer version. However, the MongoDB cluster continues to serve the requests without any interruption.

6. Verify that the MongoDB cluster continues to serve requests by checking the Locust dashboard and the Mongo Express dashboard.

    :::image type="content" source="media/upgrade-mongodb-cluster/locust-upgrade-continued.png" alt-text="Screenshot of a web page showing the Locust test dashboard when cluster is being upgraded." lightbox="./media/upgrade-mongodb-cluster/locust-upgrade-continued.png":::

7. After the upgrade is complete, you can verify the Kubernetes version of the `userpool` node pool using the [`az aks nodepool list`](/cli/azure/aks/nodepool#az-aks-nodepool-list) command.

    ```azurecli-interactive
    az aks nodepool list --resource-group $MY_RESOURCE_GROUP_NAME --cluster-name $MY_CLUSTER_NAME --output table
    ```

    Example output:

    ```output
    Name        OsType    KubernetesVersion    VmSize           Count    MaxPods    ProvisioningState    Mode
    ----------  --------  -------------------  ---------------  -------  ---------  -------------------  ------
    systempool  Linux     1.30                 Standard_DS4_v2  1        30         Succeeded            System
    userpool    Linux     1.31.1               Standard_DS4_v2  3        30         Succeeded            User
    ```

## Next step

> [!div class="nextstepaction"]
> [Monitor the MongoDB cluster on AKS][aks-mongodb-cluster-observability]

<!-- Internal links -->

[check-for-available-aks-cluster-upgrades]: /azure/aks/upgrade-aks-cluster?tabs=azure-cli#check-for-available-aks-cluster-upgrades
[aks-mongodb-cluster-observability]: ./monitor-aks-mongodb.md
