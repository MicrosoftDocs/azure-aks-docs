---
title: Upgrade an Azure Kubernetes Service (AKS) on Azure Local for multi-rack deployments
description: Learn how to upgrade an AKS cluster to a newer Kubernetes version on Azure Local.
ms.topic: overview
ms.date: 09/01/2026
ms.author: sanjanamohan
ms.custom: multi-rack
author: sanjanamsft
---

# Upgrade an Azure Kubernetes Service on Azure Local multi-rack cluster

As part of managing the application and cluster lifecycle, you might want to upgrade to the latest available version of Kubernetes. AKS on Azure Local multi-rack deployments supports upgrades that involve a move to a newer version of Kubernetes.

All upgrades run in a continuous, rolling manner to ensure uninterrupted availability of workloads. When a new Kubernetes worker node with a newer build joins the cluster, the process moves resources from the old node to the new node. After this step completes successfully, the process decommissions and removes the old node from the cluster.

## Before you begin

If you're using the Azure CLI, this article requires Azure CLI version 2.83.0 or later. To find the version, run the `az --version` command. If you need to install or upgrade CLI, see [Install Azure CLI](/cli/azure/install-azure-cli).

## Supported Versions

The supported Kubernetes Versions are:
- 1.31.14
- 1.31.100
- 1.32.10
- 1.32.11
- 1.33.11
- 1.33.12
- 1.34.7
- 1.34.8
- 1.35.4
- 1.35.5
- 1.36.0
- 1.36.1

## Upgrade the Kubernetes version

When you upgrade a supported AKS cluster, you can't skip Kubernetes minor versions. You must perform all upgrades sequentially by minor version number. The system automatically blocks any attempts to skip Kubernetes minor versions. For example, you can't upgrade from **1.30.x** to **1.32.x**.

> [!NOTE]
> If you don't specify a patch version, the cluster automatically upgrades to the latest GA patch for the specified minor version. For example, setting `--kubernetes-version` to **1.33** upgrades the cluster to **1.33.11**.

Use the following command to upgrade your cluster:

```azurecli
az aksarc upgrade \
  --resource-group myResourceGroup \
  --name myAKSCluster \
  --kubernetes-version <KUBERNETES_VERSION>
```

For example, to upgrade a cluster to Kubernetes version 1.34.7, run:

```azurecli
az aksarc upgrade \
  --resource-group myResourceGroup \
  --name myAKSCluster \
  --kubernetes-version 1.34.7
```

Use the `show` command to confirm the upgrade was successful:

```azurecli
az aksarc show --resource-group myResourceGroup --name myAKSCluster
```

The following example output shows that the cluster now runs **1.33.11**:

```output
{
  "extendedLocation": {
    "name": "/subscriptions/<subscription>/resourcegroups/<resource group>/providers/microsoft.extendedlocation/customlocations/<custom location>",
    "type": "CustomLocation"
  },
  "id": "/subscriptions/<subscription>/resourceGroups/<resource group>/providers/Microsoft.Kubernetes/connectedClusters/myAKSCluster/providers/Microsoft.HybridContainerService/provisionedClusterInstances/default",
  "name": "default",
  "properties": {
    "agentPoolProfiles": [
      {
      }
    ],
    "controlPlane": {
      "availabilityZones": null,
      "controlPlaneEndpoint": {
        "hostIp": null,
        "port": null
      },
      "count": 1,
      "linuxProfile": {
        "ssh": {
          "publicKeys": null
        }
      },
      "name": null,
      "nodeImageVersion": null,
      "osSku": "AzureLinux",
      "osType": "Linux",
      "vmSize": "Standard_A4_v2"
    },
    "kubernetesVersion": "1.33.11",
    ...
    "provisioningState": "Succeeded",
    ...
  },
  ...
  "type": "microsoft.hybridcontainerservice/provisionedclusterinstances"
}
```

During an upgrade operation, both the `provisioningState` and `currentState` indicators display an **Upgrading** message to reflect the ongoing process. However, if the operation times out, `provisioningState` shows **Failed**, while `currentState` continues to show **Upgrading** as the upgrade continues in the background. No action is required; the upgrade continues until it's complete.

## Update operating system (OS) version

Currently, AKS on Azure Local for multi-rack deployments doesn't support node-image-only updates across all supported Kubernetes versions. If you need to update the node image, you must upgrade the cluster to the latest Kubernetes version to ensure that all node image updates are incorporated.

> [!IMPORTANT]
> If you try to use the `node-image-only` flag, you receive a message indicating that this feature isn't yet supported.

## Next steps

- [Create AKS clusters](resource-manager-quickstart.md)
