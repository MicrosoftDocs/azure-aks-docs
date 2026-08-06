---
title: Create a Managed or User-Assigned NAT Gateway for your Azure Kubernetes Service (AKS) Cluster
description: Learn how to create an AKS cluster with managed NAT integration and user-assigned NAT gateway.
ms.topic: how-to
ms.subservice: aks-networking
ms.service: azure-kubernetes-service
ms.date: 07/07/2026
author: schaffererin
ms.author: schaffererin
ms.custom: devx-track-azurecli
---

# Create a managed or user-assigned NAT gateway for your Azure Kubernetes Service (AKS) cluster

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

For most production workloads, AKS Automatic is the recommended production-ready default for AKS. AKS Automatic clusters include a preconfigured managed NAT gateway.

In AKS Standard, you can create or configure a managed NAT gateway when you want AKS-managed outbound connectivity for your cluster. For bring-your-own (BYO) networking scenarios, use a user-assigned NAT gateway.

While you can route egress traffic through an Azure Load Balancer, there are limitations on the number of outbound flows of traffic you can have. Azure NAT Gateway supports up to 64,512 outbound UDP and TCP traffic flows per IP address with a maximum of 16 IP addresses. Three outbound types support NAT gateway: `managedNATGatewayV2` (Preview), `managedNATGateway`, and `userAssignedNATGateway`.

This article shows you how to create an AKS cluster with managed NAT gateway and user-assigned NAT gateway for outbound traffic. It also shows you how to disable OutboundNAT for Windows.

> [!IMPORTANT]
> The `managedNATGatewayV2` outbound type is currently in preview.
> See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability.

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

### Create an AKS cluster with a managed StandardV2 NAT gateway (`managedNATGatewayV2`)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

- Create an AKS cluster with a managed StandardV2 NAT gateway using the [`az aks create`][az-aks-create] command with the `--outbound-type managedNATGateway`, `--nat-gateway-outbound-ips`, `--nat-gateway-outbound-ip-prefixes`, `--nat-gateway-managed-outbound-ip-count`, `--nat-gateway-managed-outbound-ipv6-count`, and `--nat-gateway-idle-timeout` parameters.
- When you configure outbound IPs for a `managedNATgatewayV2`, use **one of the following approaches**. You can't use both Azure-managed and customer-defined outbound IPs.
  - **Azure-managed IPs**: Use `--nat-gateway-managed-ip-outbound-count` and `--nat-gateway-managed-outbound-ipv6-count` to have Azure automatically allocate and manage the outbound public IPs on your behalf.
  - **Customer-defined IPs**: Use `--nat-gateway-outbound-ips` and `--nat-gateway-outbound-ip-prefixes` to bring your own pre-provisioned public IP addresses or prefixes, giving you full control over the specific addresses used for outbound traffic. StandardV2 NAT Gateway requires the use of new StandardV2 public IPs. Existing Standard SKU Public IPs don't work with StandardV2 NAT gateway.

#### Install the `aks-preview` Azure CLI extension

The `managedNATGatewayV2` outbound type is currently in preview. To use this outbound type, install the `aks-preview` Azure CLI extension and register the `ManagedNATGatewayV2Preview` feature flag.

Install or update the Azure CLI preview extension using the [`az extension add`](/cli/azure/extension#az-extension-add) or [`az extension update`](/cli/azure/extension#az-extension-update) command. The minimum version of the `aks-preview` Azure CLI extension is `20.0.0b1`.

```azurecli-interactive
# Install the aks-preview extension
az extension add --name aks-preview

# Update the extension to make sure you have the latest version installed
az extension update --name aks-preview
```

#### Register the `ManagedNATGatewayV2Preview` feature flag

1. Register the `ManagedNATGatewayV2Preview` feature flag using the [`az feature register`](/cli/azure/feature#az-feature-register) command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "ManagedNATGatewayV2Preview"
    ```

1. Verify successful registration using the [`az feature show`](/cli/azure/feature#az-feature-show) command. It takes a few minutes for the registration to complete.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "ManagedNATGatewayV2Preview"
    ```

    Once the feature shows `Registered`, refresh the registration of the `Microsoft.ContainerService` resource provider using the [`az provider register`](/cli/azure/provider#az-provider-register) command.

#### Create an AKS cluster with a managed StandardV2 NAT gateway

The following commands create the required resource group, the public IP and public IP prefix resources to attach to the NAT gateway, and the AKS cluster with a managed StandardV2 NAT gateway.

1. Create a resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    # Set environment variables for resource group, AKS cluster, public IP, and public IP prefix names
    export RANDOM_SUFFIX=$(openssl rand -hex 3)
    export MY_RG="myResourceGroup$RANDOM_SUFFIX"
    export MY_AKS="myNatV2Cluster$RANDOM_SUFFIX"
    export MY_IP="myNatOutboundIP$RANDOM_SUFFIX"
    export MY_IP_PREFIX="myNatOutboundIPPrefix$RANDOM_SUFFIX"

    # Create the resource group
    az group create --name $MY_RG --location "eastus2"
    ```

1. Create a zone redundant IPv4 public IP address and public IP prefix using the [`az network public-ip create`][az-network-public-ip-create] command. Store `$MY_IP` and `$MY_IP_PREFIX` to use as outbound IPs for the managed StandardV2 NAT gateway.

    ```azurecli-interactive
    # Create a zone redundant IPv4 public IP address and store the ID to $MY_IP_ID for later use
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

    # Create a zone redundant IPv4 public IP prefix and store the ID to $MY_IP_PREFIX_ID for later use
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

1. Create the AKS cluster and reference the public IP address (`$MY_IP_ID`) and public IP prefix (`$MY_IP_PREFIX_ID`) using the [`az aks create`][az-aks-create] command with the `--outbound-type managedNATGatewayV2`, `--nat-gateway-outbound-ips`, and `--nat-gateway-outbound-ip-prefixes` parameters.

    ```azurecli-interactive
    az aks create \
        --resource-group $MY_RG \
        --name $MY_AKS \
        --node-count 3 \
        --outbound-type managedNATGatewayV2 \
        --nat-gateway-outbound-ips $MY_IP_ID \
        --nat-gateway-outbound-ip-prefixes $MY_IP_PREFIX_ID \
        --nat-gateway-idle-timeout 4 \
        --generate-ssh-keys
    ```

Update the outbound IPs, outbound IP prefixes, managed outbound IP count, or idle timeout using the [`az aks update`][az-aks-update] command with the `--nat-gateway-outbound-ips`, `--nat-gateway-outbound-ip-prefixes`, `--nat-gateway-managed-outbound-count`, `--nat-gateway-managed-outbound-ipv6-count`, or `--nat-gateway-idle-timeout` parameter. A `managedNATGatewayV2` can't be updated to switch between customer-defined and managed outbound IP addresses after creation. The outbound IP configuration is determined when the StandardV2 NAT gateway is initially created and remains immutable.

### Create an AKS cluster with a managed Standard NAT gateway (`managedNATGateway`)

- Create an AKS cluster with a managed Standard NAT gateway using the `az aks create` command with `--outbound-type managedNATGateway`, `--nat-gateway-managed-outbound-ip-count`, and `--nat-gateway-idle-timeout` parameters. If you want the NAT gateway to operate out of specific availability zone, specify the zone using `--zones`.
- You can't use a managed NAT gateway resource across multiple availability zones. For zone-redundant outbound connectivity, consider using [`managedNATgatewayV2`](#create-an-aks-cluster-with-a-managed-nat-gateway).
- If you don't specify a zone when creating a managed NAT gateway, the NAT gateway is deployed to **no zone** by default. When the NAT gateway is in **no zone**, Azure places the resource in a zone for you. For more information on the non-zonal deployment model, see [non-zonal NAT gateway](/azure/nat-gateway/nat-availability-zones#non-zonal).
  
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
