---
title: API Server Authorized IP Ranges in Azure Kubernetes Service (AKS)
description: Learn how to secure access to the API server in Azure Kubernetes Service (AKS) using authorized IP address ranges to limit access to specific IP addresses and CIDRs.
ms.topic: how-to
ms.custom: devx-track-azurecli, devx-track-azurepowershell, copilot-scenario-highlight
ms.date: 05/19/2024
ms.author: schaffererin
author: schaffererin
ms.service: azure-kubernetes-service
zone_pivot_groups: api-server-authorized-ip-ranges
# Customer intent: As a cluster operator, I want to increase the security of my cluster by limiting access to the API server to only the IP addresses that I specify.
---

# Secure access to the API server using authorized IP address ranges in Azure Kubernetes Service (AKS)

This article shows you how to use API server authorized IP address ranges to limit which IP addresses and CIDRs can access control plane endpoints for your Azure Kubernetes Service (AKS) workloads.

## Prerequisites

- The Azure CLI version 2.0.76 or later installed and configured. Check your version using the `az --version` command. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
- To learn what IP addresses to include when integrating your AKS cluster with Azure DevOps, see [Allowed IP addresses and domain URLs][azure-devops-allowed-network-cfg].

> [!TIP]
> From the Azure portal, you can use Azure Copilot to make changes to the IP addresses that can access your cluster. For more information, see [Work with AKS clusters efficiently using Azure Copilot](/azure/copilot/work-aks-clusters#enable-ip-address-authorization).

## Limitations and considerations

- This feature is only supported on the Standard SKU load balancer for clusters created after October 2019. Any existing clusters on the Basic SKU load balancer with the feature enabled should continue to work properly if the Kubernetes version and control plane are upgraded. However, you can't migrate these clusters to the Standard SKU load balancer.
- You can't use this feature with [private clusters](./private-clusters.md).
- When using this feature with clusters that use [Node public IPs](use-node-public-ips.md), the node pools using the Node public IPs must use public IP prefixes. You must add the public IP prefixes as authorized ranges.
- You can specify up to 200 authorized IP ranges. To go beyond this limit, consider using [API Server VNet Integration][api-server-vnet-integration], which supports up to 2,000 authorized IP ranges.

## Overview of API server authorized IP ranges

The Kubernetes API server exposes underlying Kubernetes APIs and provides the interaction for management tools like `kubectl` and the Kubernetes dashboard. AKS provides a single-tenant cluster control plane with a dedicated API server. The API server is assigned a public IP address by default. You can control access using Kubernetes role-based access control (Kubernetes RBAC) or Azure RBAC.

To secure access to the otherwise publicly accessible AKS control plane / API server, you can enable and use authorized IP ranges. These authorized IP ranges only allow defined IP address ranges to communicate with the API server. Any requests made to the API server from an IP address that isn't part of these authorized IP ranges is blocked. The rules can take up to two minutes to propagate. Allow up to that time when testing the connection.

## Recommended IP ranges to allow

We recommend including the following IP address ranges in your API server authorized IP ranges configuration:

- The cluster egress IP address (firewall, NAT gateway, or other address, depending on your [outbound type][egress-outboundtype]).
- Any range that represents networks that you'll administer the cluster from.

## Create an AKS cluster with API server authorized IP ranges enabled

> [!NOTE]
> When you enable API server authorized IP ranges during cluster creation, both the API server public IP and the outbound public IP of the [Standard SKU load balancer][standard-sku-lb] are automatically allowed by default, in addition to any ranges you specify.
>
> **Special case - `0.0.0.0/32`**: This is a special value that tells AKS to allow only the outbound public IP of the Standard SKU load balancer to access the API server. The `0.0.0.0/32` value acts as a placeholder that:
>
> - Disables the default behavior of allowing extra client IP ranges.
> - Restricts API server access to only the cluster's own outbound IP.
> - Is useful for scenarios where you want the cluster to self-manage but block external access.

When creating a cluster with API server authorized IP ranges enabled, you provide a list of authorized public IP address ranges. When you specify a CIDR range, you must use the network address (first IP address in the range). For example, if you want to allow the range `137.117.106.88` to `137.117.106.95`, you must specify `137.117.106.88/29`.

:::zone pivot="azure-cli"

- Create an AKS cluster with API server authorized IP ranges enabled using the [`az aks create`][az-aks-create] command with the `--api-server-authorized-ip-ranges` parameter. The following example creates a cluster named _myAKSCluster_ in the resource group named _myResourceGroup_ and allows the IP address range `73.140.245.0/24` to access the API server:

    ```azurecli-interactive
    az aks create --resource-group myResourceGroup --name myAKSCluster --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard --api-server-authorized-ip-ranges 73.140.245.0/24 --generate-ssh-keys
    ```

:::zone-end

:::zone pivot="azure-powershell"

- Create an AKS cluster with API server authorized IP ranges enabled using the [`New-AzAksCluster`][new-azakscluster] cmdlet with the `-ApiServerAccessAuthorizedIpRange` parameter. The following example creates a cluster named _myAKSCluster_ in the resource group named _myResourceGroup_ and allows the IP address range `73.140.245.0/24` to access the API server:

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

## Specify outbound IPs for a Standard SKU load balancer

When creating a cluster with API server authorized IP ranges enabled, you can also specify the outbound IP addresses or prefixes for the cluster using the `--load-balancer-outbound-ips` or `--load-balancer-outbound-ip-prefixes` parameters. All IPs provided in the parameters are allowed along with the IPs in the `--api-server-authorized-ip-ranges` parameter.

- Create an AKS cluster with API server authorized IP ranges enabled and specify the outbound IP addresses for the Standard SKU load balancer using the `--load-balancer-outbound-ips` parameter. The following example creates a cluster named _myAKSCluster_ in the resource group named _myResourceGroup_, allows the IP address range `73.140.245.0/24` to access the API server, and specifies two outbound IP addresses for the Standard SKU load balancer. Make sure to replace the placeholders `<public-ip-id-1>` and `<public-ip-id-2>` with the actual resource IDs of your public IP addresses.

    ```azurecli-interactive
    az aks create --resource-group myResourceGroup --name myAKSCluster --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard --api-server-authorized-ip-ranges 73.140.245.0/24 --load-balancer-outbound-ips <public-ip-id-1>,<public-ip-id-2> --generate-ssh-keys
    ```

:::zone-end

## Allow only the outbound public IP of the Standard SKU load balancer

:::zone pivot="azure-cli"

- Create an AKS cluster with API server authorized IP ranges enabled and allow only the outbound public IP of the Standard SKU load balancer using the `--api-server-authorized-ip-ranges` parameter. The following example creates a cluster named _myAKSCluster_ in the resource group named _myResourceGroup_ with API server authorized IP ranges enabled and allows only the outbound public IP of the Standard SKU load balancer:

    ```azurecli-interactive
    az aks create --resource-group myResourceGroup --name myAKSCluster --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard --api-server-authorized-ip-ranges 0.0.0.0/32 --generate-ssh-keys
    ```

:::zone-end

:::zone pivot="azure-powershell"

- Create an AKS cluster with API server authorized IP ranges enabled and allow only the outbound public IP of the Standard SKU load balancer using the `-ApiServerAccessAuthorizedIpRange` parameter. The following example creates a cluster named _myAKSCluster_ in the resource group named _myResourceGroup_ with API server authorized IP ranges enabled and allows only the outbound public IP of the Standard SKU load balancer:

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

- Update an existing cluster's API server authorized IP ranges using the [`az aks update`][az-aks-update] command with the `--api-server-authorized-ip-ranges` parameter. The following example updates API server authorized IP ranges on the cluster named _myAKSCluster_ in the resource group named _myResourceGroup_ and updates the IP address range to `73.140.245.0/24`:

    ```azurecli-interactive
    az aks update --resource-group myResourceGroup --name myAKSCluster --api-server-authorized-ip-ranges 73.140.245.0/24
    ```

## Allow multiple IP address ranges

To allow multiple IP address ranges, you can list several IP addresses, separated by commas.

- Update an existing cluster's API server authorized IP ranges to allow multiple IP address ranges using the [`az aks update`][az-aks-update] command with the `--api-server-authorized-ip-ranges` parameter. The following example updates API server authorized IP ranges on the cluster named _myAKSCluster_ in the resource group named _myResourceGroup_ and allows multiple IP address ranges:

    ```azurecli-interactive
    az aks update --resource-group myResourceGroup --name myAKSCluster --api-server-authorized-ip-ranges 73.140.245.0/24,193.168.1.0/24,194.168.1.0/24
    ```

:::zone-end

:::zone pivot="azure-powershell"

- Update an existing cluster's API server authorized IP ranges using the [`Set-AzAksCluster`][set-azakscluster] cmdlet with the `-ApiServerAccessAuthorizedIpRange` parameter. The following example updates API server authorized IP ranges on the cluster named _myAKSCluster_ in the resource group named _myResourceGroup_ and updates the IP address range to `73.140.245.0/24`:

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

- Disable API server authorized IP ranges using the [`az aks update`][az-aks-update] command and specify an empty range `""` for the `--api-server-authorized-ip-ranges` parameter.

    ```azurecli-interactive
    az aks update --resource-group myResourceGroup --name myAKSCluster --api-server-authorized-ip-ranges ""
    ```

:::zone-end

:::zone pivot="azure-powershell"

- Disable API server authorized IP ranges using the [`Set-AzAksCluster`][set-azakscluster] cmdlet and specify an empty range `''` for the `-ApiServerAccessAuthorizedIpRange` parameter.

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

- Find existing API server authorized IP ranges using the [`az aks show`][az-aks-show] command with the `--query` parameter set to `apiServerAccessProfile.authorizedIpRanges`.

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

- Find existing API server authorized IP ranges using the [`Get-AzAksCluster`][get-azakscluster] cmdlet.

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
1. From the service menu, under **Settings**, select **Networking**. The existing API server authorized IP ranges are listed under **Resource settings**.

    :::image type="content" source="./media/api-server-authorized-ip-ranges/azure-portal-existing-ranges.png" alt-text="Screenshot of the API server authorized IP ranges in the Azure portal.":::

:::zone-end

## Access the API server from your development machine, tooling, or automation

You must add your development machines, tooling, or automation IP addresses to the AKS cluster list of approved IP ranges to access the API server from there.

Another option is to configure a jumpbox with the necessary tooling inside a separate subnet in the firewall's virtual network. This option assumes your environment has a firewall with the respective network and that you added the firewall IPs to authorized ranges. Similarly, if you forced tunneling from the AKS subnet to the firewall subnet, having the jumpbox in the cluster subnet also works.

> [!NOTE]
> The following example adds another IP address to the approved ranges. It still includes the existing IP address. If you don't include your existing IP address, this command replaces it with the new one instead of adding it to the authorized ranges.

:::zone pivot="azure-cli"

1. Retrieve your IP address and set it to an environment variable using the following command:

    ```bash
    # Retrieve your IP address
    CURRENT_IP=$(dig +short "myip.opendns.com" "@resolver1.opendns.com")
    ```

1. Add your IP address to the approved list using the [`az aks update`][az-aks-update] command with the `--api-server-authorized-ip-ranges` parameter. The following example adds your current IP address to the existing API server authorized IP ranges on the cluster named _myAKSCluster_ in the resource group named _myResourceGroup_:

    ```azurecli-interactive
    az aks update --resource-group myResourceGroup --name myAKSCluster --api-server-authorized-ip-ranges $CURRENT_IP/24,73.140.245.0/24
    ```

:::zone-end

:::zone pivot="azure-powershell"

1. Retrieve your IP address and set it to an environment variable using the following command:

    ```bash
    # Retrieve your IP address
    CURRENT_IP=$(dig +short "myip.opendns.com" "@resolver1.opendns.com")
    ```

1. Add your IP address to the approved list using the [`Set-AzAksCluster`][set-azakscluster] cmdlet with the `-ApiServerAccessAuthorizedIpRange` parameter. The following example adds your current IP address to the existing API server authorized IP ranges on the cluster named _myAKSCluster_ in the resource group named _myResourceGroup_:

    ```azurepowershell-interactive
    Set-AzAksCluster -ResourceGroupName myResourceGroup -Name myAKSCluster -ApiServerAccessAuthorizedIpRange '$CURRENT_IP/24,73.140.245.0/24'
    ```

:::zone-end

Another option is to use the following command on Windows systems to get the public IPv4 address:

```azurepowershell-interactive
Invoke-RestMethod http://ipinfo.io/json | Select -exp ip
```

You can also follow the steps in [Find your IP address](https://support.microsoft.com/help/4026518/windows-10-find-your-ip-address) or search on _what is my IP address?_ in an internet browser.

## Related content

To learn more about security in AKS, see the following articles:

- [Use service tags for API server authorized IP ranges in AKS][api-server-service-tags]
- [Security concepts for applications and clusters in AKS][concepts-security]
- [Best practices for cluster security and upgrades in AKS][operator-best-practices-cluster-security].

<!-- LINKS - internal -->
[api-server-vnet-integration]: api-server-vnet-integration.md
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-show]: /cli/azure/aks#az-aks-show
[concepts-security]: concepts-security.md
[egress-outboundtype]: egress-outboundtype.md
[install-azure-cli]: /cli/azure/install-azure-cli
[operator-best-practices-cluster-security]: operator-best-practices-cluster-security.md
[standard-sku-lb]: load-balancer-standard.md
[azure-devops-allowed-network-cfg]: /azure/devops/organizations/security/allow-list-ip-url
[new-azakscluster]: /powershell/module/az.aks/new-azakscluster
[set-azakscluster]: /powershell/module/az.aks/set-azakscluster
[get-azakscluster]: /powershell/module/az.aks/get-azakscluster
[api-server-service-tags]: api-server-service-tags.md
