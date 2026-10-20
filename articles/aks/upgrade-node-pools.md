---
title: Upgrade Node Pools in Azure Kubernetes Service (AKS)
description: Learn how to upgrade a single node pool and how to upgrade the cluster control plane for multiple node pools in Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 07/19/2023
author: schaffererin
ms.author: schaffererin
ms.subservice: aks-nodes
# Customer intent: "As a Kubernetes administrator, I want to upgrade my node pools in AKS so that I can ensure my cluster is running the latest features and security updates."
---

# Upgrade node pools in Azure Kubernetes Service (AKS)

In this article, you learn how to upgrade a single node pool and how to upgrade the cluster control plane for multiple node pools in Azure Kubernetes Service (AKS).

> [!NOTE]
> As a best practice, you should upgrade all node pools in an AKS cluster to the same Kubernetes version. The default behavior of [`az aks upgrade`][az-aks-upgrade] is to upgrade all node pools together with the control plane to achieve this alignment. The ability to upgrade individual node pools lets you perform a rolling upgrade and schedule pods between node pools to maintain application uptime.

## Upgrade a single node pool

> [!NOTE]
> The node pool operating system (OS) image version is tied to the Kubernetes version of the cluster. You only get OS image upgrades following a cluster upgrade.

1. Check for any available upgrades using the [`az aks get-upgrades`][az-aks-get-upgrades] command.

    ```azurecli-interactive
    az aks get-upgrades --resource-group <resource-group-name> --name <cluster-name>
    ```

1. Upgrade a specific node pool using the [`az aks nodepool upgrade`][az-aks-nodepool-upgrade] command.

    ```azurecli-interactive
    az aks nodepool upgrade \
        --resource-group <resource-group-name> \
        --cluster-name <cluster-name> \
        --name <node-pool-name> \
        --kubernetes-version <kubernetes-version> \
        --no-wait
    ```

1. Check the status of your node pool using the [`az aks nodepool list`][az-aks-nodepool-list] command.

    ```azurecli-interactive
    az aks nodepool list --resource-group <resource-group-name> --cluster-name <cluster-name>
    ```

     The following example output shows the node pool is in the _Upgrading_ state:

    ```output
    [
      {
        ...
        "count": 3,
        ...
        "name": "<node-pool-name>",
        "orchestratorVersion": "<kubernetes-version>",
        ...
        "provisioningState": "Upgrading",
        ...
        "vmSize": "Standard_DS2_v2",
        ...
      },
      {
        ...
        "count": 2,
        ...
        "name": "<node-pool-name-2>",
        "orchestratorVersion": "<kubernetes-version-2>",
        ...
        "provisioningState": "Succeeded",
        ...
        "vmSize": "Standard_DS2_v2",
        ...
      }
    ]
    ```

    It takes a few minutes to upgrade the nodes to the specified version. After the upgrade is complete, the node pool's `provisioningState` changes to _Succeeded_.

## Upgrade a cluster control plane with multiple node pools

An AKS cluster has two cluster resource objects with Kubernetes versions associated to them: the cluster control plane Kubernetes version and a node pool with a Kubernetes version.

### Upgrade behavior for the control plane and node pools

The control plane maps to one or many node pools. The behavior of an upgrade operation depends on which Azure CLI command you use and the flags you specify:

- [`az aks upgrade`](/cli/azure/aks#az-aks-upgrade) upgrades the control plane and all node pools in the cluster to the same Kubernetes version.
- [`az aks upgrade`](/cli/azure/aks#az-aks-upgrade) with the `--control-plane-only` flag upgrades only the cluster control plane and leaves all node pools unchanged.
- [`az aks nodepool upgrade`](/cli/azure/aks/nodepool#az-aks-nodepool-upgrade) upgrades only the target node pool with the specified Kubernetes version.

### Validation rules for upgrades

> [!NOTE]
> Kubernetes uses the standard [Semantic Versioning](https://semver.org/) versioning scheme. The version number is expressed as _x.y.z_, where _x_ is the major version, _y_ is the minor version, and _z_ is the patch version. For example, in version _1.12.6_, _1_ is the major version, _12_ is the minor version, and _6_ is the patch version. The Kubernetes version of the control plane and the initial node pool are set during cluster creation. Other node pools have their Kubernetes version set when they are added to the cluster. The Kubernetes versions may differ between node pools and between a node pool and the control plane.

Kubernetes upgrades for a cluster control plane and node pools are validated using the following sets of rules:

- **Rules for valid versions to upgrade node pools**:
  - The node pool version must have the same _major_ version as the control plane.
  - The node pool _minor_ version must be within two _minor_ versions of the control plane version.
  - The node pool version can't be greater than the control `major.minor.patch` version.

- **Rules for submitting an upgrade operation**:
  - You can't downgrade the control plane or a node pool Kubernetes version.
  - If a node pool Kubernetes version isn't specified, the behavior depends on the client. In Azure Resource Manager (ARM) templates, declaration falls back to the existing version defined for the node pool. If nothing is set, it falls back to the control plane version.
  - You can't simultaneously submit multiple operations on a single control plane or node pool resource. You can either upgrade or scale a control plane or a node pool at a given time.

## Next steps: Manage node pools in AKS

To learn more about managing node pools in AKS, see [Manage node pools in Azure Kubernetes Service (AKS)](manage-node-pools.md).
