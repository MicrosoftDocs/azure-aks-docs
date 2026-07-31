---
title: Upgrade the Azure Kubernetes Service (AKS) Cluster Control Plane
description: Learn how to upgrade the control plane of an Azure Kubernetes Service (AKS) cluster to get the latest Kubernetes version features and security updates.
ms.topic: how-to
ms.subservice: aks-upgrade
ms.service: azure-kubernetes-service
ms.date: 07/30/2026
author: schaffererin
ms.author: schaffererin
# Customer intent: "As a cluster operator, I want to upgrade my AKS cluster control plane so that I can access the latest Kubernetes features and security updates while maintaining control over when my node pools are upgraded."
---

# Upgrade the Azure Kubernetes Service (AKS) cluster control plane

Azure Kubernetes Service (AKS) clusters consist of two main components: the **control plane managed by Azure** and the **node pools where your workloads run**. This article focuses on upgrading the control plane independently, which allows you to adopt new Kubernetes versions for API server features while separately managing node pool upgrades.

## Before you begin

- If you're using the Azure CLI, this article requires Azure CLI version 2.34.1 or later. Use the `az --version` command to find the version. If you need to install or upgrade, see [Install Azure CLI][azure-cli-install].
- If you're using Azure PowerShell, this article requires Azure PowerShell version 5.9.0 or later. Use the `Get-InstalledModule -Name Az` cmdlet to find the version. If you need to install or upgrade, see [Install Azure PowerShell][azure-powershell-install].
- To perform upgrade operations, you need the [Azure Kubernetes Service Contributor Role][aks-contributor-role] or equivalent permissions.
- Beta APIs are disabled by default when you upgrade to Kubernetes version 1.30 and 1.27 LTS versions.

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

When you upgrade a supported non-LTS AKS cluster, you can't skip Kubernetes minor versions. You must perform all upgrades sequentially by minor version number. For example, upgrades between _1.28.x_ -> _1.29.x_ or _1.29.x_ -> _1.30.x_ are allowed. _1.28.x_ -> _1.30.x_ isn't allowed.

An LTS cluster can skip minor versions when moving to a higher LTS version offered by AKS, provided the upgrade satisfies version-skew requirements and validation checks. For more information, see [Can I skip multiple AKS versions during a cluster upgrade?][aks-skip-versions].

Starting with Kubernetes 1.28, the control plane can be up to three minor versions ahead of node pools. For example, if your control plane is at _1.35.x_, your node pools can be at _1.32.x_, _1.33.x_, _1.34.x_, or _1.35.x_. For current constraints, see the [AKS version skew policy][aks-version-skew-policy].

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

List the Kubernetes versions available in your region using the [`Get-AzAksVersion`][get-azaksversion] cmdlet.

```azurepowershell-interactive
Get-AzAksVersion -Location <your-region> | Where-Object { $_.OrchestratorVersion }
```

The output lists the Kubernetes versions available in the specified region under `OrchestratorVersion`. To identify potential upgrade targets, compare versions newer than your cluster's current version with the [Kubernetes version upgrade rules](#kubernetes-version-upgrade-rules), because the cmdlet doesn't validate the upgrade path for a specific cluster.

### [Azure portal](#tab/azure-portal)

1. Sign in to the [Azure portal](https://portal.azure.com) and navigate to your AKS cluster resource.
1. Under **Settings**, select **Upgrades**.
1. For **Kubernetes version**, select **Upgrade version** to see available upgrades.

The Azure portal highlights deprecated APIs between your current version and available target versions.

---

## Upgrade the AKS control plane only

> [!IMPORTANT]
> You can't perform a control-plane-only upgrade when [cluster autoupgrade](./auto-upgrade-cluster.md#control-plane-upgrade-constraints) is enabled. Cluster autoupgrade always upgrades the control plane and all node pools together.

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

1. Verify the node pool versions remain unchanged using the [`az aks nodepool list`](/cli/azure/aks/nodepool#az-aks-nodepool-list) command.

    ```azurecli-interactive
    az aks nodepool list --resource-group <resource-group-name> --cluster-name <cluster-name> --query "[].{Name:name,Version:orchestratorVersion}" --output table
    ```

    In the output, the node pools should still show the previous Kubernetes version.

### [Azure PowerShell](#tab/azure-powershell)

1. Upgrade the control plane using the [`Set-AzAksCluster`][set-azakscluster] cmdlet with the `-ControlPlaneOnly` parameter. The following example upgrades the control plane to Kubernetes version _1.29.4_:

    ```azurepowershell-interactive
    Set-AzAksCluster -ResourceGroupName <resource-group-name> -Name <cluster-name> -KubernetesVersion 1.29.4 -ControlPlaneOnly
    ```

1. Confirm the upgrade was successful using the [`Get-AzAksCluster`](/powershell/module/az.aks/get-azakscluster) cmdlet.

    ```azurepowershell-interactive
    Get-AzAksCluster -ResourceGroupName <resource-group-name> -Name <cluster-name> |
     Format-Table -Property Name, Location, KubernetesVersion, ProvisioningState
    ```

### [Azure portal](#tab/azure-portal)

1. Sign in to the [Azure portal](https://portal.azure.com) and navigate to your AKS cluster resource.
1. Under **Settings**, select **Upgrades**.
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
1. Under **Settings**, select **Upgrades**.
1. Select **Upgrade version** > **Control plane and all node pools**.
1. Select the desired Kubernetes version > **Save**.

---

## AKS control plane upgrade frequently asked questions (FAQ)

### Does a control-plane-only upgrade also upgrade node pools?

No. A control-plane-only upgrade doesn't change node pools. [Cluster autoupgrade](./auto-upgrade-cluster.md#control-plane-upgrade-constraints) works differently: it doesn't support control-plane-only upgrades and upgrades the control plane and all node pools together.

### Can I upgrade node pools before the control plane?

No. The control plane version must always be equal to or greater than any node pool version. You must upgrade the control plane first.

### How long does a control plane upgrade take?

Upgrade duration varies based on the cluster state and Azure conditions. Monitor `provisioningState` using [`az aks show`][az-aks-show] or [`Get-AzAksCluster`][get-azakscluster]. The upgrade is complete when the provisioning state is `Succeeded`.

## Resolve control plane upgrade issues

### No upgrades available

For an unsupported cluster, use `az aks get-upgrades` to check whether AKS offers an eligible supported target. If a target is available, perform a full-cluster upgrade. Control-plane-only upgrades aren't supported for this recovery path.

If no target is available, your cluster might already be on the latest supported version. If the cluster is running an unsupported version, create a new cluster with a supported version and migrate your workloads.

### Upgrade failed due to deprecated APIs

Before upgrading, check for deprecated APIs using tools like [kube-no-trouble (kubent)](https://github.com/doitintl/kube-no-trouble):

```bash
kubent
```

The command scans resources accessible through the current kubeconfig context for deprecated Kubernetes API versions. The output groups findings by Kubernetes version and identifies each affected resource by `KIND`, `NAMESPACE`, `NAME`, and `API_VERSION`. Update the source manifest for every listed resource to use a supported API version before upgrading.

## Related content

- [Configure rolling upgrades for node pools](./upgrade-aks-node-pools-rolling.md)
- [Configure automatic cluster upgrades](./auto-upgrade-cluster.md)
- [Configure automatic node OS image upgrades](./auto-upgrade-node-os-image.md)

<!-- LINKS - internal -->
[azure-cli-install]: /cli/azure/install-azure-cli
[azure-powershell-install]: /powershell/azure/install-az-ps
[az-aks-get-upgrades]: /cli/azure/aks#az-aks-get-upgrades
[az-aks-nodepool-list]: /cli/azure/aks/nodepool#az-aks-nodepool-list
[az-aks-upgrade]: /cli/azure/aks#az-aks-upgrade
[set-azakscluster]: /powershell/module/az.aks/set-azakscluster
[az-aks-show]: /cli/azure/aks#az-aks-show
[aks-contributor-role]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-contributor-role
[aks-skip-versions]: /azure/aks/supported-kubernetes-versions#can-i-skip-multiple-aks-versions-during-a-cluster-upgrade
[aks-version-skew-policy]: /azure/aks/supported-kubernetes-versions#what-is-the-allowed-difference-in-versions-between-the-control-plane-and-node-pools
[get-azakscluster]: /powershell/module/az.aks/get-azakscluster
[get-azaksversion]: /powershell/module/az.aks/get-azaksversion
[release-tracker]: release-tracker.md
