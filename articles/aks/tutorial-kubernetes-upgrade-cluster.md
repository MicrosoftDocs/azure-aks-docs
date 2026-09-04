---
title: Kubernetes on Azure tutorial - Upgrade an Azure Kubernetes Service (AKS) cluster
description: In this Azure Kubernetes Service (AKS) tutorial, you learn how to upgrade an existing AKS cluster to the latest available Kubernetes version.
ms.topic: tutorial
ms.date: 09/04/2026
author: schaffererin
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.subservice: aks-upgrade
ms.custom: mvc, devx-track-azurepowershell
ai-usage: ai-assisted
zone_pivot_groups: azure-portal-cli-powershell
# Customer intent: As a developer or IT pro, I want to learn how to upgrade an Azure Kubernetes Service (AKS) cluster so that I can use the latest version of Kubernetes and features.
---

# Tutorial - Upgrade an Azure Kubernetes Service (AKS) cluster

As part of the application and cluster lifecycle, you might want to upgrade to the latest available version of Kubernetes. You can upgrade your Azure Kubernetes Service (AKS) cluster using the Azure CLI, Azure PowerShell, or the Azure portal.

In this tutorial, you upgrade an AKS cluster. You learn how to:

> [!div class="checklist"]
>
> - Identify current and available Kubernetes versions.
> - Upgrade your Kubernetes nodes.
> - Validate a successful upgrade.

## Before you begin

In previous tutorials, you packaged an application into a container image and uploaded the container image to Azure Container Registry (ACR). You also created an AKS cluster and deployed an application to it. If you haven't completed these steps and want to follow along, start with [Tutorial 1 - Prepare application for AKS][aks-tutorial-prepare-app].

:::zone target="docs" pivot="azure-cli"

If using Azure CLI, this tutorial requires Azure CLI version 2.34.1 or later. Run [`az --version`][az-version] to find the version. If you need to install or upgrade, see [Install Azure CLI][azure-cli-install].

:::zone-end

:::zone target="docs" pivot="azure-powershell"

If using Azure PowerShell, this tutorial requires Azure PowerShell version 5.9.0 or later. Run [`Get-InstalledModule -Name Az`][get-installedmodule] to find the version. If you need to install or upgrade, see [Install Azure PowerShell][azure-powershell-install].

:::zone-end

To upgrade an AKS cluster, you need the [Azure Kubernetes Service Contributor role][aks-contributor-role] or equivalent permissions.

Before you upgrade, review the [AKS release notes][aks-release-notes] for breaking changes and deprecated APIs. Also validate your workload's Pod Disruption Budgets (PDBs), available compute quota, and subnet IP capacity for surge nodes. For more information, see [Upgrade options and recommendations for AKS clusters][aks-upgrade-options].

:::zone target="docs" pivot="azure-cli"

## Get available cluster versions using the Azure CLI

Before you upgrade, check which Kubernetes releases are available for your cluster by using the [`az aks get-upgrades`][az-aks-get-upgrades] command.

```azurecli-interactive
az aks get-upgrades --resource-group myResourceGroup --name myAKSCluster
```

The following example output shows a cluster's current version and lists newer versions under `upgrades`:

```output
  {
    "agentPoolProfiles": null,
    "controlPlaneProfile": {
      "kubernetesVersion": "1.33.7",
      ...
      "upgrades": [
        {
          "isPreview": null,
          "kubernetesVersion": "1.34.10"
        },
        {
          "isPreview": null,
          "kubernetesVersion": "1.34.9"
        }
      ]
    },
    ...
  }
```

:::zone-end

:::zone target="docs" pivot="azure-powershell"

## Get available cluster versions using Azure PowerShell

1. Before you upgrade, check your cluster's current Kubernetes version and region by using the [`Get-AzAksCluster`][get-azakscluster] cmdlet.

    ```azurepowershell-interactive
    Get-AzAksCluster -ResourceGroupName myResourceGroup -Name myAKSCluster |
      Select-Object -Property Name, CurrentKubernetesVersion, Location
    ```

    The following example output shows the cluster's current version and location:

    ```output
    Name              CurrentKubernetesVersion      Location
    ----              ------------------------      --------
    myAKSCluster      1.33.7                        westus2
    ```

1. List the Kubernetes releases available in the region where your cluster resides by using the [`Get-AzAksVersion`][get-azaksversion] cmdlet.

    ```azurepowershell-interactive
    Get-AzAksVersion -Location westus2 | Where-Object OrchestratorVersion
    ```

    The following example output shows the regional versions under `OrchestratorVersion`:

    ```output
    Default     IsPreview     OrchestratorType     OrchestratorVersion
    -------     ---------     ----------------     -------------------
                              Kubernetes               1.34.10
                              Kubernetes               1.34.9
    True                      Kubernetes               1.33.7
    ...
    ```

    To identify potential upgrade targets, compare versions newer than your cluster's current version with the [Kubernetes version upgrade rules][aks-version-upgrade-rules]. This cmdlet lists regional availability and doesn't validate the upgrade path for a specific cluster.

:::zone-end

:::zone target="docs" pivot="azure-portal"

## Get available cluster versions by using the Azure portal

1. Sign in to the [Azure portal](https://portal.azure.com).
1. Navigate to your AKS cluster resource.
1. From the service menu, under **Settings**, select **Upgrades**.
1. By **Kubernetes version**, select **Upgrade version**.

    :::image type="content" source="media/tutorial-kubernetes-upgrade-cluster/upgrade-version.png" alt-text="Screenshot of the Upgrade version option in the Azure portal.":::

1. On the **Upgrade Kubernetes version** page, select the **Kubernetes Version** dropdown to view available Kubernetes versions for upgrade.

    :::image type="content" source="media/tutorial-kubernetes-upgrade-cluster/available-versions.png" alt-text="Screenshot of the Upgrade version screen with available upgrade versions.":::

If no upgrades are available, your cluster might already be on the latest available version or the cluster version might be outside the support window. If the version is unsupported and AKS doesn't offer a recovery upgrade, create a new cluster with a supported Kubernetes version and migrate your workloads. For more information, see [AKS support policies for Kubernetes versions][aks-version-support-policy].

:::zone-end

## AKS cluster upgrade process

AKS nodes are carefully cordoned and drained to minimize any potential disruptions to running applications. During this process, AKS performs the following steps:

- Adds a new buffer node (or as many nodes as configured in [max surge](./upgrade-aks-cluster.md#customize-node-surge-upgrade)) to the cluster that runs the specified Kubernetes version.
- [Cordons and drains][kubernetes-drain] one of the old nodes to minimize disruption to running applications. If you're using max surge, it [cordons and drains][kubernetes-drain] as many nodes at the same time as the number of buffer nodes specified.
- When the old node is fully drained, it's reimaged to receive the new version and becomes the buffer node for the following node to be upgraded.
- This process repeats until all nodes in the cluster have been upgraded.
- At the end of the process, the last buffer node is deleted, maintaining the existing agent node count and zone balance.

[!INCLUDE [alias minor version callout](./includes/aliasminorversion/alias-minor-version-upgrade.md)]

You can either manually upgrade your cluster or configure automatic cluster upgrades. **Configure automatic cluster upgrades to help keep your cluster on a supported version of Kubernetes**.

:::zone target="docs" pivot="azure-cli"

## Manually upgrade cluster using the Azure CLI

Upgrade your cluster by using the [`az aks upgrade`][az-aks-upgrade] command. This example upgrades the cluster to version 1.34.10:

```azurecli-interactive
az aks upgrade \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --kubernetes-version 1.34.10
```

> [!NOTE]
> Supported non-LTS clusters must upgrade sequentially by minor version. For example, to upgrade from _1.33.x_ to _1.35.x_, first upgrade to _1.34.x_. An LTS cluster can skip minor versions when moving to a higher LTS version offered by AKS if the upgrade satisfies version-skew requirements and validation checks. For more information, see [Kubernetes version upgrade rules][aks-version-upgrade-rules].

The following example output shows the result of upgrading. The `kubernetesVersion` value now matches the version specified in the example command:

```output
{
  ...
  "agentPoolProfiles": [
    {
      ...
      "count": 3,
      "currentOrchestratorVersion": "1.34.10",
      "maxPods": 110,
      "name": "nodepool1",
      "nodeImageVersion": "AKSUbuntu-2204gen2containerd-202608.26.0",
      "orchestratorVersion": "1.34.10",
      "osType": "Linux",
      "upgradeSettings": {
        "drainTimeoutInMinutes": null,
        "maxSurge": "10%",
        "nodeSoakDurationInMinutes": null,
        "undrainableNodeBehavior": null
      },
      "vmSize": "Standard_DS2_v2",
      ...
    }
  ],
  ...
  "currentKubernetesVersion": "1.34.10",
  "dnsPrefix": "myAKSClust-myResourceGroup-12ab34",
  "enableRbac": false,
  "fqdn": "myaksclust-myresourcegroup-12ab34-cd56e7fg.hcp.westus2.azmk8s.io",
  "id": "/subscriptions/<Subscription ID>/resourcegroups/myResourceGroup/providers/Microsoft.ContainerService/managedClusters/myAKSCluster",
  "kubernetesVersion": "1.34.10",
  "location": "westus2",
  "name": "myAKSCluster",
  "type": "Microsoft.ContainerService/ManagedClusters"
  ...
}
```

:::zone-end

:::zone target="docs" pivot="azure-powershell"

## Manually upgrade cluster using Azure PowerShell

Upgrade your cluster by using the [`Set-AzAksCluster`][set-azakscluster] cmdlet. This example upgrades the cluster to version 1.34.10:

```azurepowershell-interactive
Set-AzAksCluster -ResourceGroupName myResourceGroup -Name myAKSCluster -KubernetesVersion 1.34.10
```

> [!NOTE]
> Supported non-LTS clusters must upgrade sequentially by minor version. For example, to upgrade from _1.33.x_ to _1.35.x_, first upgrade to _1.34.x_. An LTS cluster can skip minor versions when moving to a higher LTS version offered by AKS if the upgrade satisfies version-skew requirements and validation checks. For more information, see [Kubernetes version upgrade rules][aks-version-upgrade-rules].

The following example output shows the result of upgrading. The `KubernetesVersion` value now matches the version specified in the example cmdlet:

```output
...
ProvisioningState        : Succeeded
MaxAgentPools            : 100
KubernetesVersion        : 1.34.10
CurrentKubernetesVersion : 1.34.10
...
ResourceGroupName        : myResourceGroup
Name                     : myAKSCluster
Type                     : Microsoft.ContainerService/ManagedClusters
Location                 : westus2
Tags                     :
```

:::zone-end

:::zone target="docs" pivot="azure-portal"

## Manually upgrade cluster using the Azure portal

1. In the Azure portal, navigate to your AKS cluster resource.
1. From the service menu, under **Settings**, select **Upgrades**.
1. By **Kubernetes version**, select **Upgrade version**.

    :::image type="content" source="media/tutorial-kubernetes-upgrade-cluster/upgrade-version.png" alt-text="Screenshot of the Upgrade version option in the Azure portal.":::

1. On the **Upgrade Kubernetes version** page, select the **Kubernetes Version** dropdown to view available Kubernetes versions for upgrade.

    :::image type="content" source="media/tutorial-kubernetes-upgrade-cluster/available-versions.png" alt-text="Screenshot of the Upgrade version screen with available upgrade versions.":::

1. Select the Kubernetes version you want to upgrade to, and then select **Save**.

Upgrade duration depends on factors such as the number of nodes, surge settings, workload disruption constraints, drain timeout, and node soak duration. The default drain timeout is 30 minutes per node and can be configured from five minutes to 24 hours. Node soak duration can add zero to 30 minutes per node. For more information, see [Customize node pool surge and unavailable settings][aks-node-pool-upgrade-settings].

:::zone-end

:::zone target="docs" pivot="azure-cli"

## Configure automatic cluster upgrades using the Azure CLI

:::zone-end

:::zone target="docs" pivot="azure-powershell"

## Configure automatic cluster upgrades using Azure PowerShell

:::zone-end

:::zone target="docs" pivot="azure-portal"

## Configure automatic cluster upgrades by using the Azure portal

:::zone-end

AKS Automatic clusters use the `stable` channel, and you don't need to configure a channel. For AKS Standard clusters, select a channel based on your version policy. The `stable` and `rapid` channels advance Kubernetes minor versions and help keep the cluster within the supported version window. The `patch` channel only installs patches for the current minor version and doesn't advance the cluster to a newer minor version.

:::zone target="docs" pivot="azure-cli"

On an AKS Standard cluster, set the autoupgrade channel by using the [`az aks update`][az-aks-update] command. The following example uses the `stable` channel:

```azurecli-interactive
az aks update --resource-group myResourceGroup --name myAKSCluster --auto-upgrade-channel stable
```

:::zone-end

:::zone target="docs" pivot="azure-powershell"

On an AKS Standard cluster, set the autoupgrade channel by using the [`Set-AzAksCluster`][set-azakscluster] cmdlet. The following example uses the `Stable` channel:

```azurepowershell-interactive
Set-AzAksCluster -ResourceGroupName myResourceGroup -Name myAKSCluster -AutoUpgradeChannel Stable
```

:::zone-end

:::zone target="docs" pivot="azure-portal"

1. In the Azure portal, navigate to your AKS cluster resource.
1. From the service menu, under **Settings**, select **Upgrades**.
1. By **Kubernetes version**, select **Upgrade version**.

    :::image type="content" source="media/tutorial-kubernetes-upgrade-cluster/upgrade-version.png" alt-text="Screenshot of the Upgrade version option in the Azure portal.":::

1. For an AKS Standard cluster, on the **Upgrade Kubernetes version** page, select the **Automatic upgrade** dropdown, select **Enabled with stable**, and then select **Save**.

    :::image type="content" source="media/tutorial-kubernetes-upgrade-cluster/enable-patch.png" alt-text="Screenshot of the Upgrade Kubernetes version page showing the automatic upgrade channel options.":::

:::zone-end

For more information, see [Automatically upgrade an Azure Kubernetes Service (AKS) cluster][aks-auto-upgrade].

## Upgrading node images

AKS regularly provides new node images. Linux node images are updated weekly, and Windows node images are updated monthly. We recommend upgrading your node images frequently to use the latest AKS features and security updates. For more information, see [Upgrade node images in Azure Kubernetes Service (AKS)][node-image-upgrade]. To configure automatic node image upgrades, see [Automatically upgrade Azure Kubernetes Service (AKS) cluster node operating system images][auto-upgrade-node-image].

## View upgrade events

> [!NOTE]
> When you upgrade your cluster, the following Kubernetes events might occur on the nodes:
>
> - **Surge**: Create a surge node.
> - **Drain**: Evict pods from the node. AKS allows 30 minutes to drain a node by default. You can configure the drain timeout from five minutes to 24 hours.
> - **Update**: Update of a node has succeeded or failed.
> - **Delete**: Delete a surge node.

Use the [`kubectl get`][kubectl-get] command with a field selector to view AKS upgrader events in the default namespace.

```bash
kubectl get events --field-selector source=upgrader
```

The following example output shows some of the preceding events listed during an upgrade:

```output
LAST SEEN   TYPE      REASON    OBJECT                                   MESSAGE
...
5m          Normal    Drain     node/aks-nodepool1-12345678-vmss000000   Draining node: aks-nodepool1-12345678-vmss000000
5m          Normal    Upgrade   node/aks-nodepool1-12345678-vmss000000   Deleting node aks-nodepool1-12345678-vmss000000 from API server
4m          Normal    Upgrade   node/aks-nodepool1-12345678-vmss000000   Successfully reimaged node: aks-nodepool1-12345678-vmss000000
4m          Normal    Upgrade   node/aks-nodepool1-12345678-vmss000000   Successfully upgraded node: aks-nodepool1-12345678-vmss000000
4m          Normal    Drain     node/aks-nodepool1-12345678-vmss000000   Draining node: aks-nodepool1-12345678-vmss000000
...
```

:::zone target="docs" pivot="azure-cli"

## Validate an upgrade by using the Azure CLI

Confirm the upgrade was successful by using the [`az aks show`][az-aks-show] command.

```azurecli-interactive
az aks show --resource-group myResourceGroup --name myAKSCluster --output table
```

The following example output shows that the AKS cluster runs the target Kubernetes version:

```output
Name          Location    ResourceGroup    KubernetesVersion    CurrentKubernetesVersion  ProvisioningState    Fqdn
------------  ----------  ---------------  -------------------  ------------------------  -------------------  ----------------------------------------------------------------
myAKSCluster  westus2      myResourceGroup  1.34.10              1.34.10                   Succeeded            myaksclust-myresourcegroup-12ab34-cd56e7fg.hcp.westus2.azmk8s.io
```

:::zone-end

:::zone target="docs" pivot="azure-powershell"

## Validate an upgrade by using Azure PowerShell

Confirm the upgrade was successful by using the [`Get-AzAksCluster`][get-azakscluster] cmdlet.

```azurepowershell-interactive
Get-AzAksCluster -ResourceGroupName myResourceGroup -Name myAKSCluster |
  Select-Object -Property Name, Location, KubernetesVersion, ProvisioningState
```

The following example output shows that the AKS cluster runs the target Kubernetes version:

```output
Name             Location     KubernetesVersion     ProvisioningState
----             --------     -----------------     -----------------
myAKSCluster     westus2       1.34.10               Succeeded
```

:::zone-end

:::zone target="docs" pivot="azure-portal"

## Validate an upgrade using the Azure portal

1. In the Azure portal, navigate to your AKS cluster resource.
1. On the **Overview** page, under **Essentials**, check the **Kubernetes version** to confirm the upgrade was successful.

:::zone-end

:::zone target="docs" pivot="azure-cli"

## Delete the cluster using the Azure CLI

:::zone-end

:::zone target="docs" pivot="azure-powershell"

## Delete the cluster using Azure PowerShell

:::zone-end

:::zone target="docs" pivot="azure-portal"

## Delete the cluster by using the Azure portal

:::zone-end

As this tutorial is the last part of the series, you might want to delete your AKS cluster to avoid incurring Azure charges.

:::zone target="docs" pivot="azure-cli"

Remove the resource group, container service, and all related resources by using the [`az group delete`][az-group-delete] command.

```azurecli-interactive
az group delete --name myResourceGroup --yes --no-wait
```

:::zone-end

:::zone target="docs" pivot="azure-powershell"

Remove the resource group, container service, and all related resources by using the [`Remove-AzResourceGroup`][remove-azresourcegroup] cmdlet.

```azurepowershell-interactive
Remove-AzResourceGroup -Name myResourceGroup
```

:::zone-end

:::zone target="docs" pivot="azure-portal"

1. In the Azure portal, navigate to your AKS cluster resource.
1. On the **Overview** page, select **Delete**.
1. On the **Delete cluster confirmation** page, select **Delete**.

:::zone-end

> [!NOTE]
> When you delete the cluster, the Microsoft Entra service principal used by the AKS cluster isn't removed. For steps on how to remove the service principal, see [AKS service principal considerations and deletion][sp-delete]. If you used a managed identity, the identity is managed by the platform and doesn't require that you provision or rotate any secrets.

## Next steps

In this tutorial, you upgraded Kubernetes in an AKS cluster. You learned how to:

> [!div class="checklist"]
>
> - Identify current and available Kubernetes versions.
> - Upgrade your Kubernetes nodes.
> - Validate a successful upgrade.

For more information on AKS, see the [AKS overview][aks-intro]. For guidance on how to create full solutions with AKS, see the [AKS solution guidance][aks-solution-guidance].

<!-- LINKS - external -->
[kubernetes-drain]: https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/
[kubectl-get]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_get/

<!-- LINKS - internal -->
[aks-intro]: ./intro-kubernetes.md
[aks-tutorial-prepare-app]: ./tutorial-kubernetes-prepare-app.md
[az-aks-show]: /cli/azure/aks#az-aks-show
[az-aks-get-upgrades]: /cli/azure/aks#az-aks-get-upgrades
[az-aks-upgrade]: /cli/azure/aks#az-aks-upgrade
[az-version]: /cli/azure/reference-index#az-version
[azure-cli-install]: /cli/azure/install-azure-cli
[az-group-delete]: /cli/azure/group#az-group-delete
[sp-delete]: kubernetes-service-principal.md#considerations-when-using-a-service-principal
[aks-solution-guidance]: /azure/architecture/reference-architectures/containers/aks-start-here?WT.mc_id=AKSDOCSPAGE
[azure-powershell-install]: /powershell/azure/install-az-ps
[get-installedmodule]: /powershell/module/powershellget/get-installedmodule
[get-azakscluster]: /powershell/module/az.aks/get-azakscluster
[get-azaksversion]: /powershell/module/az.aks/get-azaksversion
[set-azakscluster]: /powershell/module/az.aks/set-azakscluster
[remove-azresourcegroup]: /powershell/module/az.resources/remove-azresourcegroup
[aks-auto-upgrade]: ./auto-upgrade-cluster.md
[auto-upgrade-node-image]: ./auto-upgrade-node-image.md
[node-image-upgrade]: ./node-image-upgrade.md
[az-aks-update]: /cli/azure/aks#az-aks-update
[aks-contributor-role]: /azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-contributor-role
[aks-release-notes]: https://github.com/Azure/AKS/releases
[aks-upgrade-options]: ./upgrade-options.md
[aks-version-upgrade-rules]: ./upgrade-aks-control-plane.md#kubernetes-version-upgrade-rules
[aks-version-support-policy]: ./supported-kubernetes-versions.md
[aks-node-pool-upgrade-settings]: ./upgrade-aks-node-pools-rolling.md#configure-rolling-upgrade-settings
