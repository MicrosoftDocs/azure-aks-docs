---
title: Upgrade the Azure Kubernetes Service (AKS) cluster control plane
description: Learn how to upgrade the control plane of an Azure Kubernetes Service (AKS) cluster to get the latest Kubernetes version features and security updates.
ms.topic: how-to
ms.subservice: aks-upgrade
ms.service: azure-kubernetes-service
ms.date: 12/09/2025
author: kaarthis
ms.author: schaffererin
# Customer intent: "As a cluster operator, I want to upgrade my AKS cluster control plane so that I can access the latest Kubernetes features and security updates while maintaining control over when my node pools are upgraded."
---

# Upgrade the Azure Kubernetes Service (AKS) cluster control plane

Azure Kubernetes Service (AKS) clusters consist of two main components: the **control plane managed by Azure** and the **node pools where your workloads run**. This article focuses on upgrading the control plane independently, which allows you to adopt new Kubernetes versions for API server features while separately managing node pool upgrades.

## Before you begin

- If you're using the Azure CLI, this article requires Azure CLI version 2.34.1 or later. Use the `az --version` command to find the version. If you need to install or upgrade, see [Install Azure CLI][azure-cli-install].
- If you're using Azure PowerShell, this article requires Azure PowerShell version 5.9.0 or later. Use the `Get-InstalledModule -Name Az` cmdlet to find the version. If you need to install or upgrade, see [Install Azure PowerShell][azure-powershell-install].
- Performing upgrade operations requires the `Microsoft.ContainerService/managedClusters/agentPools/write` RBAC role. For more on Azure RBAC roles, see the [Azure resource provider operations][azure-rp-operations].
- Starting with Kubernetes version 1.30 and 1.27 LTS versions, beta APIs are disabled by default when you upgrade to them.

> [!WARNING]
> Ensure you have sufficient compute quota before upgrading. If quota is low, the upgrade might fail. For more information, see [increase quotas](/azure/azure-portal/supportability/regional-quota-requests).

## Overview of AKS upgrade types

The following table outlines three types of AKS upgrades, highlighting their scope and use cases:

| Upgrade type | Scope | Use case |
|--------------|-------|----------|
| [Control plane only](#upgrade-the-aks-control-plane-only) | API server, etcd, controller manager, scheduler | Test new Kubernetes APIs before upgrading workloads |
| [Full cluster](#upgrade-the-full-aks-cluster) | Control plane and all node pools | Standard upgrade to keep cluster up to date |
| [Node pool only](./upgrade-aks-node-pools-rolling.md) | Specific node pools | Staged rollout after control plane upgrade |

> [!TIP]
> Upgrading the control plane first allows you to validate Kubernetes API compatibility before affecting running workloads. For node pool upgrade strategies, see [Configure rolling upgrades](./upgrade-aks-node-pools-rolling.md).

## Kubernetes version upgrade rules

When you upgrade a supported AKS cluster, you can't skip Kubernetes minor versions. You must perform all upgrades sequentially by minor version number. For example, upgrades between _1.28.x_ -> _1.29.x_ or _1.29.x_ -> _1.30.x_ are allowed. _1.28.x_ -> _1.30.x_ isn't allowed.

The control plane can be up to two minor versions ahead of node pools. For example, if your control plane is at _1.30.x_, your node pools can be at _1.28.x_, _1.29.x_, or _1.30.x_.

## Check for available AKS upgrades

> [!TIP]
> To stay up to date with the latest AKS releases and updates, see the [AKS release tracker][release-tracker].

### [Azure CLI](#tab/azure-cli)

Check for available Kubernetes releases for your AKS cluster using the [`az aks get-upgrades`][az-aks-get-upgrades] command.

```azurecli-interactive
az aks get-upgrades --resource-group <resource-group-name> --name <cluster-name> --output table
```

The following example output shows the current version as _1.28.9_ and lists the available versions under `upgrades`:

```output
Name     ResourceGroup          MasterVersion    Upgrades
-------  ---------------        ---------------  --------------
default  <resource-group-name>  1.28.9           1.29.2, 1.29.4
```

### [Azure PowerShell](#tab/azure-powershell)

Check for available Kubernetes releases for your AKS cluster using the [`Get-AzAksVersion`][get-azaksversion] cmdlet.

```azurepowershell-interactive
Get-AzAksVersion -Location <your-region> | Where-Object OrchestratorVersion
```

### [Azure portal](#tab/azure-portal)

1. Sign in to the [Azure portal](https://portal.azure.com) and navigate to your AKS cluster resource.
1. Under **Settings**, select **Cluster configuration**.
1. For **Kubernetes version**, select **Upgrade version** to see available upgrades.

The Azure portal highlights deprecated APIs between your current version and available target versions.

---

## Upgrade the AKS control plane only

### [Azure CLI](#tab/azure-cli)

1. Upgrade the control plane using the [`az aks upgrade`][az-aks-upgrade] command with the `--control-plane-only` flag. The following example upgrades the control plane to Kubernetes version _1.29.4_:

    ```azurecli-interactive
    az aks upgrade \
        --resource-group <resource-group-name> \
        --name <cluster-name> \
        --kubernetes-version 1.29.4 \
        --control-plane-only
    ```

1. Confirm the control plane upgrade was successful using the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
    az aks show --resource-group <resource-group-name> --name <cluster-name> --output table
    ```

    The following example output shows the control plane now runs _1.29.4_:

    ```output
    Name            Location    ResourceGroup          KubernetesVersion    ProvisioningState    Fqdn
    ------------    ----------  ---------------        -------------------  -------------------  ------------------------------------------------
    <cluster-name>  eastus      <resource-group-name>  1.29.4               Succeeded            <cluster-name>-dns-123abcd4.hcp.eastus.azmk8s.io
    ```

1. Verify the node pool versions remain unchanged using the [`az aks nodepool list`][az-aks-nodepool-list] command.

    ```azurecli-interactive
    az aks nodepool list --resource-group <resource-group-name> --cluster-name <cluster-name> --query "[].{Name:name,Version:orchestratorVersion}" --output table
    ```

    In the output, the node pools should still show the previous Kubernetes version.

### [Azure PowerShell](#tab/azure-powershell)

1. Upgrade the control plane using the [`Set-AzAksCluster`][set-azakscluster] cmdlet with the `-ControlPlaneOnly` parameter. The following example upgrades the control plane to Kubernetes version _1.29.4_:

    ```azurepowershell-interactive
    Set-AzAksCluster -ResourceGroupName <resource-group-name> -Name <cluster-name> -KubernetesVersion 1.29.4 -ControlPlaneOnly
    ```

1. Confirm the upgrade was successful using the [`Get-AzAksCluster`][get-azakcluster] cmdlet.

    ```azurepowershell-interactive
    Get-AzAksCluster -ResourceGroupName <resource-group-name> -Name <cluster-name> |
     Format-Table -Property Name, Location, KubernetesVersion, ProvisioningState
    ```

### [Azure portal](#tab/azure-portal)

1. Sign in to the [Azure portal](https://portal.azure.com) and navigate to your AKS cluster resource.
1. Under **Settings**, select **Cluster configuration**.
1. Select **Upgrade version** > **Control plane only**.
1. Select the desired Kubernetes version > **Save**.

---

## Upgrade the full AKS cluster

> [!NOTE]
> During a full cluster upgrade, AKS upgrades the control plane first, then upgrades each node pool sequentially. For more control over node pool upgrades, see [Configure rolling upgrades](./upgrade-aks-node-pools-rolling.md).

### [Azure CLI](#tab/azure-cli)

Upgrade the full cluster (control plane and all node pools) using the [`az aks upgrade`][az-aks-upgrade] command. The following example upgrades the cluster to Kubernetes version _1.29.4_:

```azurecli-interactive
az aks upgrade \
    --resource-group <resource-group-name> \
    --name <cluster-name> \
    --kubernetes-version 1.29.4
```

### [Azure PowerShell](#tab/azure-powershell)

Upgrade the full cluster (control plane and all node pools) using the [`Set-AzAksCluster`][set-azakscluster] cmdlet. The following example upgrades the cluster to Kubernetes version _1.29.4_:

```azurepowershell-interactive
Set-AzAksCluster -ResourceGroupName <resource-group-name> -Name <cluster-name> -KubernetesVersion 1.29.4
```

### [Azure portal](#tab/azure-portal)

1. Sign in to the [Azure portal](https://portal.azure.com) and navigate to your AKS cluster resource.
1. Under **Settings**, select **Cluster configuration**.
1. Select **Upgrade version** > **Control plane and all node pools**.
1. Select the desired Kubernetes version > **Save**.

---

## Frequently asked questions (FAQs)

### Why were my node pools upgraded when I only upgraded the control plane?

AKS might trigger a rolling node pool upgrade alongside a control plane upgrade to keep the cluster compliant and healthy. This upgrade typically occurs when a previous node upgrade failed or left nodes on mixed versions.

### Can I upgrade node pools before the control plane?

No. The control plane version must always be equal to or greater than any node pool version. You must upgrade the control plane first.

### How long does a control plane upgrade take?

Control plane upgrades typically complete within 5-15 minutes, depending on cluster configuration and Azure region load. Node pool upgrades take longer as they involve draining and reimaging nodes.

## Resolve control plane upgrade issues

### No upgrades available

If `az aks get-upgrades` shows no available upgrades, your cluster might be:

- Already on the latest supported version.
- On an unsupported version that requires migration.

For unsupported versions, create a new cluster with a supported version and migrate your workloads.

### Upgrade failed due to deprecated APIs

Before upgrading, check for deprecated APIs using tools like [kube-no-trouble (kubent)](https://github.com/doitintl/kube-no-trouble):

```bash
kubent
```

Update your manifests to use supported API versions before upgrading.

## Related content

- [Configure rolling upgrades for node pools](./upgrade-aks-node-pools-rolling.md)
- [Configure automatic cluster upgrades](./auto-upgrade-cluster.md)
- [Upgrade node OS images](./node-image-upgrade.md)

<!-- LINKS - internal -->
[azure-cli-install]: /cli/azure/install-azure-cli
[azure-powershell-install]: /powershell/azure/install-az-ps
[az-aks-get-upgrades]: /cli/azure/aks#az-aks-get-upgrades
[az-aks-upgrade]: /cli/azure/aks#az-aks-upgrade
[set-azakscluster]: /powershell/module/az.aks/set-azakscluster
[az-aks-show]: /cli/azure/aks#az-aks-show
[azure-rp-operations]: /azure/role-based-access-control/built-in-roles#containers
[get-azaksversion]: /powershell/module/az.aks/get-azaksversion
[release-tracker]: release-tracker.md
