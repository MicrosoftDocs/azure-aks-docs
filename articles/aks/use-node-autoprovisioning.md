--- 
title: Enable or Disable Node Auto-Provisioning (NAP) in Azure Kubernetes Service (AKS)
description: Learn how to enable or disable node auto-provisioning (NAP) in AKS using the Azure CLI or ARM templates.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.date: 09/29/2025
ms.author: wilsondarko
author: wdarko1
zone_pivot_groups: arm-azure-cli
# Customer intent: As a cluster operator or developer, I want to automatically provision and manage the optimal VM configuration for my AKS workloads, so that I can efficiently scale my cluster while minimizing resource costs and complexities.
---

# Enable or disable node auto-provisioning (NAP) in Azure Kubernetes Service (AKS)

This article explains how to enable or disable node auto-provisioning (NAP) in Azure Kubernetes Service (AKS) using the Azure CLI or Azure Resource Manager (ARM) templates.

## Before you begin

Before you begin, review the [Overview of node auto-provisioning (NAP) in AKS](./node-autoprovision.md) article, which details [how NAP works](./node-autoprovision.md#how-does-node-auto-provisioning-work), [prerequisites](./node-autoprovision.md#prerequisites) and [limitations](./node-autoprovision.md#limitations-and-unsupported-features).

## Enable node auto-provisioning (NAP) on an AKS cluster

The following sections explain how to enable NAP on a new or existing AKS cluster:

### Enable NAP on a new cluster

:::zone pivot="azure-cli"

- Enable node auto-provisioning on a new cluster using the [`az aks create`](/cli/azure/aks#az-aks-create) command with the `--node-provisioning-mode` flag set to `Auto`. The following command also sets the `--network-plugin` to `azure`, `--network-plugin-mode` to `overlay`, and `--network-dataplane` to `cilium`.

    ```azurecli-interactive
    az aks create \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --node-provisioning-mode Auto \
        --network-plugin azure \
        --network-plugin-mode overlay \
        --network-dataplane cilium \
        --generate-ssh-keys
    ```

:::zone-end

:::zone pivot="arm"

1. Create a file named `nap.json` and add the following ARM template configuration with the `properties.nodeProvisioningProfile.mode` field set to `Auto`, which enables NAP. (The default setting is `Manual`.)

    ```JSON
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "metadata": {},
      "parameters": {},
      "resources": [
        {
          "type": "Microsoft.ContainerService/managedClusters",
          "apiVersion": "2025-05-01",
          "sku": {
            "name": "Base",
            "tier": "Standard"
          },
          "name": "napcluster",
          "location": "uksouth",
          "identity": {
            "type": "SystemAssigned"
          },
          "properties": {
            "networkProfile": {
                "networkPlugin": "azure",
                "networkPluginMode": "overlay",
                "networkPolicy": "cilium",
                "networkDataplane":"cilium",
                "loadBalancerSku": "Standard"
            },
            "dnsPrefix": "napcluster",
            "agentPoolProfiles": [
              {
                "name": "agentpool",
                "count": 3,
                "vmSize": "standard_d2s_v3",
                "osType": "Linux",
                "mode": "System"
              }
            ],
            "nodeProvisioningProfile": {
              "mode": "Auto"
            }
          }
        }
      ]
    }
    ```

1. Enable node auto-provisioning on a new cluster using the [`az deployment group create`](/cli/azure/deployment/group#az-deployment-group-create) command with the `--template-file` flag set to the path of the ARM template file.

    ```azurecli-interactive
    az deployment group create --resource-group $RESOURCE_GROUP --template-file ./nap.json
    ```

:::zone-end

:::zone pivot="azure-cli"

### Enable NAP on an existing cluster

- Enable node auto-provisioning on an existing cluster using the [`az aks update`](/cli/azure/aks#az-aks-update) command with the `--node-provisioning-mode` flag set to `Auto`.

    ```azurecli-interactive
    az aks update --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --node-provisioning-mode Auto
    ```

:::zone-end

## Disable node auto-provisioning (NAP) on an AKS cluster

> [!IMPORTANT]
> You can only disable NAP on a cluster if the following conditions are met:
>
> - There are no existing NAP-managed nodes. You can use the `kubectl get nodes -l karpenter.sh/nodepool` command to check for existing NAP-managed nodes.
> - All existing `karpenter.sh/NodePools` have their `spec.limits.cpu` field set to `0`. This action prevents new nodes from being created, but doesn't disrupt currently running nodes.

1. Set the `spec.limits.cpu` field to `0` for every existing `karpenter.sh/NodePool`. For example:

    ```yaml
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default
    spec:
      limits:
        cpu: 0
    ```

    > [!IMPORTANT]
    > If you don't want to ensure that every pod previously running on a NAP node is safely migrated to a non-NAP node before disabling NAP, you can skip steps 2 and 3 and instead use the `kubectl delete node` command for each NAP-managed node. However, **we don't recommend skipping these steps**, as it might leave some pods pending and doesn't honor Pod Disruption Budgets (PDBs).
    >
    > When using the `kubectl delete node` command, be careful to only delete NAP-managed nodes. You can identify NAP-managed nodes using the `kubectl get nodes -l karpenter.sh/nodepool` command.

1. Add the `karpenter.azure.com/disable:NoSchedule` taint to every `karpenter.sh/NodePool`. For example:

   ```yaml
   apiVersion: karpenter.sh/v1
   kind: NodePool
   metadata:
     name: default
   spec:
     template:
       spec:
         ...
         taints:
           - key: karpenter.azure.com/disable,
             effect: NoSchedule
   ```

   This action starts the process of migrating the workloads on the NAP-managed nodes to non-NAP nodes, honoring PDBs and disruption limits. Pods migrate to non-NAP nodes if they can fit. If there isn't enough fixed-size capacity, some node NAP-managed nodes remain.

1. Scale up existing fixed-size `ManagedCluster AgentPools`, or create new fixed-size `AgentPools`, to take the load from the node NAP-managed nodes. As these nodes are added to the cluster, the node NAP-managed nodes are drained, and work is migrated to the fixed-scale nodes.
1. Delete all NAP-managed nodes using the `kubectl get nodes -l karpenter.sh/nodepool` command. If NAP-managed nodes still exist, the cluster likely lacks fixed-scale capacity. In this case, you should add more nodes so the remaining workloads can be migrated.

:::zone pivot="azure-cli"

1. Update the NAP mode to `Manual` using the [`az aks update`](/cli/azure/aks#az-aks-update) Azure CLI command with the `--node-provisioning-mode` flag set to `Manual`.

    ```azurecli-interactive
    az aks update \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --node-provisioning-mode Manual
    ```

:::zone-end

:::zone pivot="arm"

1. Update the `properties.nodeProvisioningProfile.mode` field to `Manual` in your ARM template and redeploy it.

    ```JSON
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "metadata": {},
      "parameters": {},
      "resources": [
        {
          "type": "Microsoft.ContainerService/managedClusters",
          "apiVersion": "2025-05-01",
          "sku": {
            "name": "Base",
            "tier": "Standard"
          },
          "name": "napcluster",
          "location": "uksouth",
          "identity": {
            "type": "SystemAssigned"
          },
          "properties": {
            "networkProfile": {
                "networkPlugin": "azure",
                "networkPluginMode": "overlay",
                "networkPolicy": "cilium",
                "networkDataplane":"cilium",
                "loadBalancerSku": "Standard"
            },
            "dnsPrefix": "napcluster",
            "agentPoolProfiles": [
              {
                "name": "agentpool",
                "count": 3,
                "vmSize": "standard_d2s_v3",
                "osType": "Linux",
                "mode": "System"
              }
            ],
            "nodeProvisioningProfile": {
              "mode": "Auto"
            }
          }
        }
      ]
    }
    ```

:::zone-end

## Next steps

For more information on node auto-provisioning in AKS, see the following articles:

- [Use node auto-provisioning in a custom virtual network](./node-autoprovisioning-custom-vnet.md)
- [Configure networking for node auto-provisioning on AKS](./node-autoprovision-networking.md)
- [Configure node pools for node auto-provisioning on AKS](./node-autoprovision-node-pools.md)
- [Configure disruption policies for node auto-provisioning on AKS](./node-autoprovision-disruption.md)
- [Upgrade node images for node auto-provisioning on AKS](./node-autoprovisioning-upgrade-image.md)
