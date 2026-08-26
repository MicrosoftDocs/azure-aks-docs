---
title: API Server Authorized IP Ranges in Azure Kubernetes Service (AKS)
description: Learn how to secure access to the API server in Azure Kubernetes Service (AKS) using authorized IP address ranges to limit access to specific IP addresses and CIDRs.
ms.topic: how-to
ms.custom: devx-track-azurecli, devx-track-azurepowershell, copilot-scenario-highlight
ms.date: 08/03/2026
ms.author: davidsmatlak
author: davidsmatlak
ms.service: azure-kubernetes-service
ms.subservice: aks-security
zone_pivot_groups: api-server-authorized-ip-ranges
# Customer intent: As a cluster operator, I want to increase the security of my cluster by limiting access to the API server to only the IP addresses that I specify.
---

# Secure access to the API server using authorized IP address ranges in Azure Kubernetes Service (AKS)

This article shows you how to use API server authorized IP address ranges to limit which IP addresses and CIDRs can access control plane endpoints for your Azure Kubernetes Service (AKS) workloads.

## Prerequisites

- Azure CLI version 2.0.76 or later. To check your version, run `az --version`. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
- The latest version of Azure PowerShell. For installation instructions, see [Install Azure PowerShell][install-azure-powershell].
- To learn what IP addresses to include when integrating your AKS cluster with Azure DevOps, see [Allowed IP addresses and domain URLs][azure-devops-allowed-network-cfg].

> [!TIP]
> In the Azure portal, use Azure Copilot to change the IP addresses that can access your cluster. For more information, see [Work with AKS clusters efficiently using Azure Copilot](/azure/copilot/work-aks-clusters#enable-ip-address-authorization).

## Limitations and considerations

- AKS supports this feature only with the Standard SKU load balancer. AKS no longer supports the Basic SKU load balancer. If you have an existing cluster that uses the Basic SKU, [migrate to the Standard SKU][upgrade-basic-load-balancer]. The migration requires downtime and has additional prerequisites.
- You can't use this feature with [private clusters](./private-clusters.md).
- For clusters that use [Node public IPs](use-node-public-ips.md), each node pool with public IPs must use public IP prefixes. Add those prefixes as authorized ranges.
- You can specify up to 200 authorized IP ranges. To go beyond this limit, consider using [API Server VNet Integration][api-server-vnet-integration], which supports up to 2,000 authorized IP ranges.

## Overview of API server authorized IP ranges

The Kubernetes API server exposes the underlying Kubernetes APIs. Management tools such as `kubectl` and the Kubernetes dashboard interact with the cluster through this API server. AKS provides a single-tenant control plane with a dedicated API server and assigns the server a public IP address by default. You can control access by using Kubernetes role-based access control (Kubernetes RBAC) or Azure RBAC.

To secure the otherwise publicly accessible AKS control plane API server, enable authorized IP ranges. Authorized IP ranges allow only defined IP address ranges to communicate with the API server. The API server blocks requests from IP addresses that aren't included in the authorized ranges. The rules can take up to two minutes to propagate. Wait up to two minutes before testing the connection.

## Recommended IP ranges to allow

We recommend including the following IP address ranges in your API server authorized IP ranges configuration:

- The cluster egress IP address (firewall, NAT gateway, or other address, depending on your [outbound type][egress-outboundtype]).
- The IP address ranges for networks that you use to administer the cluster.

## Create an AKS cluster with API server authorized IP ranges enabled

> [!NOTE]
> When you enable API server authorized IP ranges during cluster creation, AKS adds the API server public IP and the outbound public IP of the [Standard SKU load balancer][standard-sku-lb] to the list of authorized IP ranges by default, in addition to any ranges you specify.
>
> **Special case - `0.0.0.0/32`**: The `0.0.0.0/32` placeholder tells AKS to allow only the outbound public IP of the Standard SKU load balancer to access the API server. The placeholder has the following behaviors:
>
> | Behavior | Description |
> |---|---|
> | Extra client IP ranges | Disables the default behavior of allowing extra client IP ranges. |
> | API server access | Restricts API server access to only the cluster's own outbound IP. |
> | Self-management | Lets the cluster self-manage while blocking external access. |

To create a cluster with API server authorized IP ranges enabled, provide a list of authorized public IP address ranges. For a CIDR range, use the network address, which is the first IP address in the range. For example, to allow the range `137.117.106.88` to `137.117.106.95`, specify `137.117.106.88/29`.

:::zone pivot="azure-cli"

Use the [`az aks create`][az-aks-create] command with the `--api-server-authorized-ip-ranges` parameter to create an AKS cluster with API server authorized IP ranges enabled. The following example creates a cluster named _myAKSCluster_ in the resource group named _myResourceGroup_ and allows the IP address range `73.140.245.0/24` to access the API server:

```azurecli-interactive
az aks create --resource-group myResourceGroup --name myAKSCluster --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard --api-server-authorized-ip-ranges 73.140.245.0/24 --generate-ssh-keys
```

:::zone-end

:::zone pivot="azure-powershell"

Use the [`New-AzAksCluster`][new-azakscluster] cmdlet with the `-ApiServerAccessAuthorizedIpRange` parameter to create an AKS cluster with API server authorized IP ranges enabled. The following example creates a cluster named _myAKSCluster_ in the resource group named _myResourceGroup_ and allows the IP address range `73.140.245.0/24` to access the API server:

```azurepowershell-interactive
New-AzAksCluster -ResourceGroupName myResourceGroup -Name myAKSCluster -NodeVmSetType VirtualMachineScaleSets -LoadBalancerSku Standard -ApiServerAccessAuthorizedIpRange '73.140.245.0/24' -GenerateSshKey
```

:::zone-end

:::zone pivot="azure-portal"

1. From the [Azure portal home page](https://portal.azure.com/#home), select **Create a resource** > **Containers** > **Azure Kubernetes Service (AKS)**.
1. Configure the cluster settings as needed.
1. In the **Networking** section under **Public access**, select **Set authorized IP ranges**.
1. For **Specify IP ranges**, enter the IP address ranges you want to authorize to access the API server.
1. Configure the rest of the cluster settings as needed.
1. When you're ready, select **Review + create** > **Create** to create the cluster.

:::zone-end

:::zone pivot="azure-cli"

## Specify outbound IPs for a Standard SKU load balancer using Azure CLI

When you create a cluster with API server authorized IP ranges enabled, you can also specify its outbound IP addresses or prefixes by using the `--load-balancer-outbound-ips` or `--load-balancer-outbound-ip-prefixes` parameters. AKS allows these IP addresses in addition to the IP addresses in the `--api-server-authorized-ip-ranges` parameter.

Use the `--load-balancer-outbound-ips` parameter to create an AKS cluster with API server authorized IP ranges enabled and specify the outbound IP addresses for the Standard SKU load balancer. The following example creates a cluster named _myAKSCluster_ in the resource group named _myResourceGroup_, allows `73.140.245.0/24` to access the API server, and specifies two outbound IP addresses for the Standard SKU load balancer. Replace `<public-ip-id-1>` and `<public-ip-id-2>` with the resource IDs of your public IP addresses.

```azurecli-interactive
az aks create --resource-group myResourceGroup --name myAKSCluster --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard --api-server-authorized-ip-ranges 73.140.245.0/24 --load-balancer-outbound-ips <public-ip-id-1>,<public-ip-id-2> --generate-ssh-keys
```

:::zone-end

## Allow only the outbound public IP of the Standard SKU load balancer

:::zone pivot="azure-cli"

Use the `--api-server-authorized-ip-ranges` parameter to create an AKS cluster that allows only the outbound public IP of the Standard SKU load balancer to access the API server. The following example creates a cluster named _myAKSCluster_ in the resource group named _myResourceGroup_:

```azurecli-interactive
az aks create --resource-group myResourceGroup --name myAKSCluster --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard --api-server-authorized-ip-ranges 0.0.0.0/32 --generate-ssh-keys
```

:::zone-end

:::zone pivot="azure-powershell"

Use the `-ApiServerAccessAuthorizedIpRange` parameter to create an AKS cluster that allows only the outbound public IP of the Standard SKU load balancer to access the API server. The following example creates a cluster named _myAKSCluster_ in the resource group named _myResourceGroup_:

```azurepowershell-interactive
New-AzAksCluster -ResourceGroupName myResourceGroup -Name myAKSCluster -NodeVmSetType VirtualMachineScaleSets -LoadBalancerSku Standard -ApiServerAccessAuthorizedIpRange '0.0.0.0/32' -GenerateSshKey
```

:::zone-end

:::zone pivot="azure-portal"

1. From the [Azure portal home page](https://portal.azure.com/#home), select **Create a resource** > **Containers** > **Azure Kubernetes Service (AKS)**.
1. Configure the cluster settings as needed.
1. In the **Networking** section under **Public access**, select **Set authorized IP ranges**.
1. For **Specify IP ranges**, enter `0.0.0.0/32`. This setting allows only the outbound public IP of the Standard SKU load balancer.
1. Configure the rest of the cluster settings as needed.
1. When you're ready, select **Review + create** > **Create** to create the cluster.

:::zone-end

## Update the API server authorized IP ranges on an existing cluster

:::zone pivot="azure-cli"

Use the [`az aks update`][az-aks-update] command with the `--api-server-authorized-ip-ranges` parameter to update a cluster's API server authorized IP ranges. The following example sets the authorized range to `73.140.245.0/24` for the cluster named _myAKSCluster_ in the resource group named _myResourceGroup_:

```azurecli-interactive
az aks update --resource-group myResourceGroup --name myAKSCluster --api-server-authorized-ip-ranges 73.140.245.0/24
```

## Allow multiple IP address ranges using Azure CLI

To allow multiple IP address ranges, separate them with commas.

Use the [`az aks update`][az-aks-update] command with the `--api-server-authorized-ip-ranges` parameter to authorize multiple IP address ranges. The following example updates the cluster named _myAKSCluster_ in the resource group named _myResourceGroup_:

```azurecli-interactive
az aks update --resource-group myResourceGroup --name myAKSCluster --api-server-authorized-ip-ranges 73.140.245.0/24,193.168.1.0/24,194.168.1.0/24
```

:::zone-end

:::zone pivot="azure-powershell"

Use the [`Set-AzAksCluster`][set-azakscluster] cmdlet with the `-ApiServerAccessAuthorizedIpRange` parameter to update a cluster's API server authorized IP ranges. The following example sets the authorized range to `73.140.245.0/24` for the cluster named _myAKSCluster_ in the resource group named _myResourceGroup_:

```azurepowershell-interactive
Set-AzAksCluster -ResourceGroupName myResourceGroup -Name myAKSCluster -ApiServerAccessAuthorizedIpRange '73.140.245.0/24'
```

:::zone-end

:::zone pivot="azure-portal"

1. Navigate to the Azure portal and select the AKS cluster you want to update.
1. From the service menu, under **Settings**, select **Networking**.
1. Under **Resource settings**, select **Manage**.
1. On the **Authorized IP ranges** page, update the **Authorized IP ranges** as needed.
1. When you're done, select **Save**.

:::zone-end

## Disable API server authorized IP ranges on an existing cluster

:::zone pivot="azure-cli"

To disable API server authorized IP ranges, use the [`az aks update`][az-aks-update] command and specify an empty range `""` for the `--api-server-authorized-ip-ranges` parameter.

```azurecli-interactive
az aks update --resource-group myResourceGroup --name myAKSCluster --api-server-authorized-ip-ranges ""
```

:::zone-end

:::zone pivot="azure-powershell"

To disable API server authorized IP ranges, use the [`Set-AzAksCluster`][set-azakscluster] cmdlet and specify an empty range `''` for the `-ApiServerAccessAuthorizedIpRange` parameter.

```azurepowershell-interactive
Set-AzAksCluster -ResourceGroupName myResourceGroup -Name myAKSCluster -ApiServerAccessAuthorizedIpRange ''
```

:::zone-end

:::zone pivot="azure-portal"

1. Navigate to the Azure portal and select the AKS cluster you want to update.
1. From the service menu, under **Settings**, select **Networking**.
1. Under **Resource settings**, select **Manage**.
1. On the **Authorized IP ranges** page, deselect the **Set authorized IP ranges** checkbox.
1. Select **Save**.

:::zone-end

## Find existing API server authorized IP ranges

:::zone pivot="azure-cli"

To find existing API server authorized IP ranges, use the [`az aks show`][az-aks-show] command with the `--query` parameter set to `apiServerAccessProfile.authorizedIpRanges`.

```azurecli-interactive
az aks show --resource-group myResourceGroup --name myAKSCluster --query apiServerAccessProfile.authorizedIpRanges
```

Example output:

```output
[
    "73.140.245.0/24"
]
```

:::zone-end

:::zone pivot="azure-powershell"

To find existing API server authorized IP ranges, use the [`Get-AzAksCluster`][get-azakscluster] cmdlet.

```azurepowershell-interactive
Get-AzAksCluster -ResourceGroupName myResourceGroup -Name myAKSCluster | Select-Object -ExpandProperty ApiServerAccessProfile
```

Example output:

```output
AuthorizedIPRanges: {73.140.245.0/24}
...
```

:::zone-end

:::zone pivot="azure-portal"

1. Navigate to the Azure portal and select your AKS cluster.
1. From the service menu, under **Settings**, select **Networking**.

    The **Resource settings** section on the **Networking** page displays the currently configured authorized IP ranges.

    :::image type="content" source="./media/api-server-authorized-ip-ranges/azure-portal-existing-ranges.png" alt-text="Screenshot showing authorized IP ranges under Resource settings in the Azure portal.":::

:::zone-end

## Access the API server from your development machine, tooling, or automation

To access the API server from a development machine, tool, or automation system, add its public IP address to the cluster's authorized IP ranges.

Alternatively, configure a jumpbox with the necessary tooling in a separate subnet in the firewall's virtual network, and add the firewall IP addresses to the authorized ranges. If the AKS cluster subnet uses forced tunneling through the firewall, you can instead place that jumpbox in the AKS cluster subnet.

> [!NOTE]
> The following example preserves the existing authorized range and adds another IP address. If you omit an existing IP address, the command replaces it with the new range.

:::zone pivot="azure-cli"

1. Run the following command to retrieve your IP address and set it as an environment variable:

    ```bash
    # Retrieve your IP address
    CURRENT_IP=$(dig +short "myip.opendns.com" "@resolver1.opendns.com")
    ```

1. Use the [`az aks update`][az-aks-update] command with the `--api-server-authorized-ip-ranges` parameter to add your IP address to the authorized ranges. The following example adds your current IP address to the existing ranges on the cluster named _myAKSCluster_ in the resource group named _myResourceGroup_:

    ```azurecli-interactive
    az aks update --resource-group myResourceGroup --name myAKSCluster --api-server-authorized-ip-ranges $CURRENT_IP/32,73.140.245.0/24
    ```

:::zone-end

:::zone pivot="azure-powershell"

1. Run the following command to retrieve your IP address and set it as an environment variable:

    ```azurepowershell-interactive
    # Retrieve your IP address
    $CURRENT_IP = (Invoke-RestMethod -Uri 'https://ipinfo.io/json').ip
    ```

1. Use the [`Set-AzAksCluster`][set-azakscluster] cmdlet with the `-ApiServerAccessAuthorizedIpRange` parameter to add your IP address to the authorized ranges. The following example adds your current IP address to the existing ranges on the cluster named _myAKSCluster_ in the resource group named _myResourceGroup_:

    ```azurepowershell-interactive
    Set-AzAksCluster -ResourceGroupName myResourceGroup -Name myAKSCluster -ApiServerAccessAuthorizedIpRange "$CURRENT_IP/32", '73.140.245.0/24'
    ```

:::zone-end

For another way to identify your IP address, see [Find your IP address](https://support.microsoft.com/help/4026518/windows-10-find-your-ip-address) or search for _what is my IP address?_ in a web browser.

## Related content

To learn more about security in AKS, see the following articles:

- [Use service tags for API server authorized IP ranges in AKS][api-server-service-tags]
- [Security concepts for applications and clusters in AKS][concepts-security]
- [Best practices for cluster security and upgrades in AKS][operator-best-practices-cluster-security]

<!-- LINKS - internal -->
[api-server-vnet-integration]: api-server-vnet-integration.md
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-show]: /cli/azure/aks#az-aks-show
[concepts-security]: concepts-security.md
[egress-outboundtype]: egress-outboundtype.md
[install-azure-cli]: /cli/azure/install-azure-cli
[install-azure-powershell]: /powershell/azure/install-azure-powershell
[operator-best-practices-cluster-security]: operator-best-practices-cluster-security.md
[standard-sku-lb]: load-balancer-standard.md
[azure-devops-allowed-network-cfg]: /azure/devops/organizations/security/allow-list-ip-url
[new-azakscluster]: /powershell/module/az.aks/new-azakscluster
[set-azakscluster]: /powershell/module/az.aks/set-azakscluster
[get-azakscluster]: /powershell/module/az.aks/get-azakscluster
[api-server-service-tags]: api-server-service-tags.md
[upgrade-basic-load-balancer]: upgrade-basic-load-balancer-on-aks.md
