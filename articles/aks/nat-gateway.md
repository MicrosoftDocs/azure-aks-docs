---
title: Create a Managed or User-Assigned NAT Gateway for your Azure Kubernetes Service (AKS) Cluster
description: Learn how to create an AKS cluster with managed NAT integration and user-assigned NAT gateway.
ms.topic: how-to
ms.subservice: aks-networking
ms.service: azure-kubernetes-service
ms.date: 08/25/2026
author: schaffererin
ms.author: schaffererin
ms.custom: devx-track-azurecli
ai-usage: ai-assisted
---

# Create a managed or user-assigned NAT gateway for your Azure Kubernetes Service (AKS) cluster

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

For most production workloads, AKS Automatic is the recommended production-ready default for AKS. AKS Automatic clusters include a preconfigured managed NAT gateway.

In AKS Standard, you can create or configure a managed NAT gateway when you want AKS-managed outbound connectivity for your cluster. For bring-your-own (BYO) networking scenarios, use a user-assigned NAT gateway.

While you can route egress traffic through an Azure Load Balancer, there are limitations on the number of outbound flows of traffic you can have. Azure NAT Gateway supports up to 64,512 outbound UDP and TCP traffic flows per IP address with a maximum of 16 IP addresses. Two outbound types support NAT gateway: `managedNATGateway` and `userAssignedNATGateway`.

This article shows you how to create an AKS cluster with managed NAT gateway and user-assigned NAT gateway for outbound traffic. It also shows you how to disable OutboundNAT for Windows.

> [!NOTE]
> Starting with API version 2026-06-01, `outboundType: managedNATGateway` defaults to StandardV2 NAT Gateway which shows as `natGatewayProfile.sku: StandardV2` instead of the `managedNATGatewayV2` outbound type used during preview. Preview API versions `2026-01-02-preview` through `2026-05-02-preview` continue to accept `managedNATGatewayV2` for around one year, which gives you time to move to `managedNATGateway` with an explicit `sku`. For deprecation dates of the preview APIs, see the [AKS Preview API life cycle documentation](concepts-preview-api-life-cycle.md).
>

## Prerequisites

AKS Automatic clusters include a preconfigured managed NAT gateway. The steps in this article are primarily for AKS Standard and custom networking scenarios.

- Make sure you're using the latest version of [Azure CLI][az-cli].
- Make sure you're using Kubernetes version 1.20.x or later.
- Managed NAT gateway isn't compatible with custom virtual networks.

> [!IMPORTANT]
> In non-private clusters, API server cluster traffic is routed and processed through the cluster's outbound type. To prevent API server traffic from being processed as public traffic, consider using a [private cluster][private-cluster], or check out the [API Server VNet Integration][api-server-vnet-integration] feature.

## Managed NAT gateway in AKS

AKS Automatic uses managed NAT gateway as part of its preconfigured production-ready default. Use this section if you're working with AKS Standard or if you need to understand how managed NAT gateway behaves in an AKS cluster.

Managed NAT gateway is the AKS-managed outbound option. AKS creates and manages the NAT gateway to provide outbound connectivity for your cluster nodes.

Use managed NAT gateway when you want:

- AKS-managed outbound connectivity with less operational overhead.
- A production-friendly default outbound path.
- Simpler egress management than a customer-managed NAT gateway deployment.
- A standard AKS networking model without bringing your own NAT gateway resource.

## Create an AKS cluster with a managed NAT gateway

### Outbound IP parameters

The following table describes each outbound IP parameter and when to use it:

| Parameter | Input | IP version | Who manages the public IPs |
| --------- | ----- | ---------- | -------------------------- |
| `--nat-gateway-managed-outbound-ip-count` | Value in the range of [1, 16]. Desired number of outbound IPv4s for NAT gateway outbound connection. | IPv4 | Azure |
| `--nat-gateway-managed-outbound-ipv6-count` | Value in the range of [1, 16]. Desired number of outbound IPv6s for NAT gateway outbound connection. | IPv6 | Azure |
| `--nat-gateway-outbound-ips` | Comma-separated public IP resource IDs for NAT gateway outbound connection. | IPv4 or IPv6 | Customer |
| `--nat-gateway-outbound-ip-prefixes` | Comma-separated public IP prefix resource IDs for NAT gateway outbound connection. | IPv4 or IPv6 | Customer |

### Choose a managed NAT gateway SKU

Starting with API version `2026-06-01`, `managedNATGateway` supports the `StandardV2` and `Standard` SKUs through `networkProfile.natGatewayProfile.sku`. StandardV2 is the default for new clusters in supported regions when the request uses this API version or later. Requests that use an earlier API version retain the existing Standard behavior.

| Scenario | Behavior |
| --- | --- |
| New cluster with no SKU specified | Defaults to `StandardV2` where available. AKS validates regional availability before applying the default. In regions where StandardV2 isn't available, AKS uses `Standard`. |
| Existing Standard cluster | Continues to use that NAT gateway resource. API version `2026-06-01` and later returns the read-only `natGatewayProfile.sku` property as `Standard`. |
| Upgrade from Standard to StandardV2 | Set `networkProfile.natGatewayProfile.sku` to `StandardV2`. |
| Downgrade from StandardV2 to Standard | Not supported. |

StandardV2 NAT Gateway is recommended because it's zone-redundant by default and offers higher bandwidth and throughput. StandardV2 requires StandardV2 public IP addresses and prefixes. Existing Standard SKU public IP resources aren't compatible with StandardV2 NAT Gateway. Review the [key limitations of StandardV2 NAT Gateway](/azure/nat-gateway/nat-overview#key-limitations-of-standardv2) for the current list of unsupported regions.

The StandardV2 public IP requirement applies only to the NAT gateway's outbound IPs. The AKS-managed load balancer that serves `type: LoadBalancer` Services remains a Standard load balancer and requires Standard public IPs. If you preprovision tagged public IP inventory, plan for both SKUs: StandardV2 for NAT gateway egress and Standard for inbound Services.

#### Managed NAT gateway SKU capabilities

The `managedNATGateway` outbound type supports different capabilities depending on the value of `networkProfile.natGatewayProfile.sku`.

| Capability | `StandardV2` | `Standard` |
| --- | --- | --- |
| Default for new clusters | Default where available unless the customer explicitly selects `Standard`. | Used when explicitly selected or when StandardV2 isn't available in the region. |
| Availability zone behavior | Zone-redundant by default. | Zonal or nonzonal, depending on the cluster configuration. |
| Azure-managed outbound IPv4 addresses | Supported. | Supported. |
| Azure-managed outbound IPv6 addresses | Supported. | Not supported. |
| Customer-defined outbound IP addresses and prefixes | Supported with StandardV2 public IP addresses and prefixes. | Not supported for an AKS-managed NAT gateway. |

### Create an AKS cluster

Create an AKS cluster by running the [`az aks create`][az-aks-create] command with the `--outbound-type managedNATGateway` parameter. AKS defaults to StandardV2 SKU in supported regions and Standard SKU in unsupported regions.

```azurecli-interactive
az aks create \
    --resource-group <resource-group> \
    --name <cluster-name> \
    --location <location> \
    --outbound-type managedNATGateway \
    --nat-gateway-managed-outbound-ip-count 1 \
    --generate-ssh-keys
```

> [!IMPORTANT]
> You can upgrade an existing managed Standard NAT gateway to StandardV2, but you can't downgrade a managed StandardV2 NAT gateway to Standard.

### Configure outbound IPs for a managed StandardV2 NAT gateway

In regions that have `StandardV2` available, configure outbound addresses by using **one** of the following approaches. You can't combine Azure-managed and customer-defined outbound IP configuration.

#### Use Azure-managed IPs

Use `managedOutboundIPProfile` to have AKS allocate and manage the outbound public IPv4 and IPv6 addresses.

```json
{
  "properties": {
    "networkProfile": {
      "outboundType": "managedNATGateway",
      "natGatewayProfile": {
          "managedOutboundIPProfile": {
          "count": 1,
          "countIPv6": 1
        }
      }
    }
  }
}
```

#### Use customer-defined IPs and prefixes

Use `outboundIPs` and `outboundIPPrefixes` to provide precreated public IP addresses or prefixes. These resources must use the StandardV2 SKU. Existing Standard SKU public IP addresses and prefixes aren't compatible with a StandardV2 NAT gateway.

1. Create a zone-redundant StandardV2 public IP address and public IP prefix.

    ```azurecli-interactive
    export MY_IP_ID=$(az network public-ip create \
        --resource-group $MY_RG \
        --name $MY_IP \
        --location eastus2 \
        --sku StandardV2 \
        --allocation-method Static \
        --version IPv4 \
        --zone 1 2 3 \
        --query publicIp.id \
        --output tsv)

    export MY_IP_PREFIX_ID=$(az network public-ip prefix create \
        --resource-group $MY_RG \
        --name $MY_IP_PREFIX \
        --location eastus2 \
        --length 31 \
        --sku StandardV2 \
        --version IPv4 \
        --zone 1 2 3 \
        --query id \
        --output tsv)
    ```

1. Deploy a managed NAT gateway outbound type in a region that supports StandardV2 NAT Gateway and reference the public IP address and prefix in the AKS cluster configuration.

    ```json
    {
      "properties": {
        "networkProfile": {
          "outboundType": "managedNATGateway",
          "natGatewayProfile": {
            "outboundIPs": {
              "publicIPs": [
                "<standard-v2-public-ip-resource-id>"
              ]
            },
            "outboundIPPrefixes": {
              "publicIPPrefixes": [
                "<standard-v2-public-ip-prefix-resource-id>"
              ]
            }
          }
        }
      }
    }
   ```

The outbound IP ownership model is determined when the StandardV2 NAT gateway is initially created. You can change individual outbound IP resources within the selected model, but you can't switch an existing NAT gateway between Azure-managed and customer-defined outbound IPs. You also can't change the NAT gateway SKU. Downgrading from StandardV2 to Standard isn't supported.
  
### Create an AKS cluster with a `userAssignedNatGateway`

This configuration requires bring-your-own networking (via [Azure CNI][byo-vnet-azure-cni]) and that the NAT gateway is preconfigured on the subnet. Both Standard and StandardV2 NAT gateways are supported for this `outbound-type`. The following commands create the required resources to deploy a StandardV2 NAT gateway resource for your AKS cluster.

1. Create a resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    # Set environment variables for resource group, AKS cluster, public IP, and public IP prefix names
    export RANDOM_SUFFIX=$(openssl rand -hex 3)
    export MY_RG="myResourceGroup$RANDOM_SUFFIX"

    # Create the resource group
    az group create --name $MY_RG --location southcentralus
    ```

1. Create a managed identity for network permissions and store the ID in `$IDENTITY_ID` for later use.

    ```azurecli-interactive
    export IDENTITY_NAME="myNatClusterId$RANDOM_SUFFIX"
    export IDENTITY_ID=$(az identity create \
        --resource-group $MY_RG \
        --name $IDENTITY_NAME \
        --location southcentralus \
        --query id \
        --output tsv)
    ```

    Example output:

    ```output
    /xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroupxxx/providers/Microsoft.ManagedIdentity/userAssignedIdentities/myNatClusterIdxxx
    ```

1. Create a StandardV2 public IP for the NAT gateway using the [`az network public-ip create`][az-network-public-ip-create] command. A StandardV2 NAT gateway requires a StandardV2 public IP address.

    ```azurecli-interactive
    export PIP_NAME="myNatGatewayPip$RANDOM_SUFFIX"
    az network public-ip create \
        --resource-group $MY_RG \
        --name $PIP_NAME \
        --location southcentralus \
        --allocation-method Static \
        --version IPv4 \
        --zone 1 2 3 \
        --sku standard-v2
    ```

1. Create the StandardV2 NAT gateway using the [`az network nat gateway create`][az-network-nat-gateway-create] command.

    ```azurecli-interactive
    export NATGATEWAY_NAME="myNatGateway$RANDOM_SUFFIX"
    az network nat gateway create \
        --resource-group $MY_RG \
        --name $NATGATEWAY_NAME \
        --location southcentralus \
        --public-ip-addresses $PIP_NAME \
        --sku StandardV2
        --idle-timeout 4
    ```

    > [!IMPORTANT]
   > To ensure zone redundancy, deploy a StandardV2 NAT gateway resource, which spans across multiple availability zones in a region. This configuration ensures continued outbound connectivity even if a single zone fails. For more details on StandardV2 NAT gateway and its benefits, see [StandardV2 NAT Gateway](/azure/nat-gateway/nat-overview#standardv2-nat-gateway). 
   > By comparison, a Standard NAT gateway resource provides resiliency only within the availability zone in which you deploy it.

1. Create a virtual network using the [`az network vnet create`][az-network-vnet-create] command.

    ```azurecli-interactive
    export VNET_NAME="myVnet$RANDOM_SUFFIX"
    az network vnet create \
        --resource-group $MY_RG \
        --name $VNET_NAME \
        --location southcentralus \
        --address-prefixes 172.16.0.0/20 
    ```

1. Create a subnet in the virtual network using the NAT gateway and store the ID to `$SUBNET_ID` for later use.

    ```azurecli-interactive
    export SUBNET_NAME="myNatCluster$RANDOM_SUFFIX"
    export SUBNET_ID=$(az network vnet subnet create \
        --resource-group $MY_RG \
        --vnet-name $VNET_NAME \
        --name $SUBNET_NAME \
        --address-prefixes 172.16.0.0/22 \
        --nat-gateway $NATGATEWAY_NAME \
        --query id \
        --output tsv)
    ```

1. Create an AKS cluster using the subnet with the NAT gateway and the managed identity using the [`az aks create`][az-aks-create] command.

    ```azurecli-interactive
    export AKS_NAME="myNatCluster$RANDOM_SUFFIX"
    az aks create \
        --resource-group $MY_RG \
        --name $AKS_NAME \
        --location southcentralus \
        --network-plugin azure \
        --vnet-subnet-id $SUBNET_ID \
        --outbound-type userAssignedNATGateway \
        --assign-identity $IDENTITY_ID \
        --generate-ssh-keys
    ```

## Production considerations

When you use managed NAT gateway in production, plan for outbound traffic behavior, API server access, and workload resiliency.

- Use AKS Automatic when you want the recommended production-ready default for most AKS workloads.
- Use managed NAT gateway in AKS Standard when you want AKS-managed outbound connectivity without bringing your own NAT gateway.
- Use a private cluster or API Server VNet Integration when you want to reduce exposure of API server traffic.
- Review outbound IP requirements before you go live.
- If your workloads depend on fixed outbound addresses, validate that managed NAT gateway meets those requirements before deployment.
- If you need to manage NAT independently of AKS, use a user-assigned NAT gateway.

## Disable OutboundNAT for Windows

Windows OutboundNAT can cause certain connection and communication issues with your AKS pods. An example issue is node port reuse. In this example, Windows OutboundNAT uses ports to translate your pod IP to your Windows node host IP, which can cause an unstable connection to the external service due to a port exhaustion issue.

Windows enables OutboundNAT by default. You can now manually disable OutboundNAT when creating new Windows agent pools.

### Prerequisites and limitations

- You need an existing AKS cluster with v1.26 or later. If you're using Kubernetes version 1.25 or older, [update your deployment configuration][upgrade-kubernetes].
- You can't set the cluster outbound type to LoadBalancer. You can set it to NAT Gateway or UDR:
  - [NAT Gateway](./nat-gateway.md): NAT Gateway automatically handles NAT connections and is more powerful than Standard Load Balancer. You might incur extra charges by using this option.
  - [UDR (UserDefinedRouting)](./limit-egress-traffic.md): You must keep port limitations in mind when configuring routing rules.
  - To switch from a load balancer to NAT Gateway, you can either add a NAT gateway into the VNet or run [`az aks upgrade`][aks-upgrade] to update the outbound type.

> [!NOTE]
> UserDefinedRouting has the following limitations:
>
> - SNAT by Load Balancer (must use the default OutboundNAT) has 64 ports on the host IP.
> - SNAT by Azure Firewall (disable OutboundNAT) has 2,496 ports per public IP.
> - SNAT by NAT Gateway (disable OutboundNAT) has 64,512 ports per public IP.
> - If the Azure Firewall port range isn't enough for your application, you need to use NAT Gateway.
> - Azure Firewall doesn't SNAT with Network rules when the destination IP address is in a private IP address range per [IANA RFC 1918 or shared address space per IANA RFC 6598](/azure/firewall/snat-private-range).

### Manually disable OutboundNAT for Windows

- Manually disable OutboundNAT for Windows when creating new Windows agent pools using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--disable-windows-outbound-nat` flag.

    > [!NOTE]
    > You can use an existing AKS cluster, but you might need to update the outbound type and add a node pool to enable `--disable-windows-outbound-nat`.

    ```azurecli-interactive
    export WIN_NODEPOOL_NAME="win$(head -c 1 /dev/urandom | xxd -p)"
    az aks nodepool add \
        --resource-group $MY_RG \
        --cluster-name $MY_AKS \
        --name $WIN_NODEPOOL_NAME \
        --node-count 3 \
        --os-type Windows \
        --disable-windows-outbound-nat
    ```

    Example output:

    <!-- expected_similarity=0.3 -->

    ```output
    {
      "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroupxxx/providers/Microsoft.ContainerService/managedClusters/myNatClusterxxx/agentPools/mynpxxx",
      "name": "mynpxxx",
      "osType": "Windows",
      "provisioningState": "Succeeded",
      "resourceGroup": "myResourceGroupxxx",
      "type": "Microsoft.ContainerService/managedClusters/agentPools"
    }
    ```

## Related content

For more information on Azure NAT Gateway and AKS Automatic, see the following articles:

- [Azure NAT Gateway][nat-docs]
- [What is AKS Automatic?](./intro-aks-automatic.md)
- [Create an AKS Automatic cluster](./automatic/quick-automatic-managed-network.md)

<!-- LINKS - internal -->
[api-server-vnet-integration]: api-server-vnet-integration.md
[byo-vnet-azure-cni]: configure-azure-cni.md
[private-cluster]: private-clusters.md
[upgrade-kubernetes]:tutorial-kubernetes-upgrade-cluster.md

<!-- LINKS - external-->
[nat-docs]: /azure/virtual-network/nat-gateway/nat-overview
[az-cli]: /cli/azure/install-azure-cli
[aks-upgrade]: /cli/azure/aks#az-aks-update
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-group-create]: /cli/azure/group#az-group-create
[az-network-public-ip-create]: /cli/azure/network/public-ip#az-network-public-ip-create
[az-network-nat-gateway-create]: /cli/azure/network/nat/gateway#az-network-nat-gateway-create
[az-network-vnet-create]: /cli/azure/network/vnet#az-network-vnet-create
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az-aks-nodepool-add
