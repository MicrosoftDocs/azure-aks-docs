---
title: Create a managed or user-assigned NAT gateway for your Azure Kubernetes Service (AKS) cluster
description: Learn how to create an AKS cluster with managed NAT integration and user-assigned NAT gateway.
ms.topic: how-to
ms.date: 04/15/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.custom: devx-track-azurecli
---

# Create a managed or user-assigned NAT gateway for your Azure Kubernetes Service (AKS) cluster

While you can route egress traffic through an Azure Load Balancer, there are limitations on the number of outbound flows of traffic you can have. Azure NAT Gateway allows up to 64,512 outbound UDP and TCP traffic flows per IP address with a maximum of 16 IP addresses. There are three outbound types that support NAT gateway - `managedNATGatewayV2` (Preview), `managedNATGateway`, and `userAssignedNATGateway`. 

In a managed NAT gateway model, AKS manages the NAT gateway to provide outbound connectivity for your cluster nodes. AKS supports two managed NAT gateway options: the newer `managedNATGatewayV2` and the original `managedNATGateway`. `managedNATgatewayV2` uses StandardV2 NAT gateway which is **zone-redundant by default**, providing continued outbound connectivity even if one availability zone goes down. Unlike Standard NAT gateway, you don't need to specify a zone -zone redundancy is built in automatically. StandardV2 NAT gateway also supports IPv6, higher throughput, and flow logs. For more details, see [StandardV2 NAT gateway SKU](/azure/nat-gateway/nat-overview#standardv2-nat-gateway).

> [!IMPORTANT]
> The `managedNATGatewayV2` outbound type is currently in PREVIEW.
> See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability.

`userAssignedNATGateway` is a customer managed NAT gateway resource that you configure independently of AKS and is needed when using bring-your-own virtual networking.

This article shows you how to create an Azure Kubernetes Service (AKS) cluster with a managed NAT gateway and a user-assigned NAT gateway for egress traffic. It also shows you how to disable OutboundNAT on Windows.

## Before you begin

* Make sure you're using the latest version of [Azure CLI][az-cli].
* Make sure you're using Kubernetes version 1.20.x or above.
* Managed NAT gateway is incompatible with custom virtual networks.

> [!IMPORTANT]
> In non-private clusters, API server cluster traffic is routed and processed through the clusters outbound type. To prevent API server traffic from being processed as public traffic, consider using a [private cluster][private-cluster], or check out the [API Server VNet Integration][api-server-vnet-integration] feature.

## <a name="create-an-aks-cluster-with-a-managed-nat-gateway"></a>Create an AKS cluster with a `managedNATgatewayV2`

* Create an AKS cluster with a managed StandardV2 NAT gateway using the [`az aks create`][az-aks-create] command with the `--outbound-type managedNATGateway`, `--nat-gateway-outbound-ips`, `--nat-gateway-outbound-ip-prefixes`, `--nat-gateway-managed-outbound-ip-count`, `--nat-gateway-managed-outbound-ipv6-count`, and `--nat-gateway-idle-timeout` parameters.
* When configuring outbound IPs for a `managedNATgatewayV2`, you must use **one of the following approaches** — you cannot use both Azure-managed and customer-defined outbound IPs:
    - **Azure-managed IPs** — Use `--nat-gateway-managed-ip-outbound-count` and/or `--nat-gateway-managed-outbound-ipv6-count` to have Azure automatically allocate and manage the outbound public IPs on your behalf.
    - **Customer-defined IPs** — Use `--nat-gateway-outbound-ips` and/or `--nat-gateway-outbound-ip-prefixes` to bring your own pre-provisioned public IP addresses or prefixes, giving you full control over the specific addresses used for outbound traffic. StandardV2 NAT Gateway requires the use of new StandardV2 Public IPs. Existing Standard SKU Public IPs don't work with StandardV2 NAT Gateway.

The following table describes each outbound IP parameter and when to use it:

| Parameter | Input | IP Version | Who manages the public IPs |
|---|---|---|---|
| `--nat-gateway-managed-outbound-ip-count` | Value in the range of [1, 16]. Desired number of outbound IPv4s for NAT gateway outbound connection. | IPv4 | Azure |
| `--nat-gateway-managed-outbound-ipv6-count` | Value in the range of [1, 16]. Desired number of outbound IPv6s for NAT gateway outbound connection. | IPv6 | Azure |
| `--nat-gateway-outbound-ips` | Comma-separated public IP resource IDs for NAT gateway outbound connection. | IPv4 or IPv6 | Customer |
| `--nat-gateway-outbound-ip-prefixes` | Comma-separated public IP prefix resource IDs for NAT gateway outbound connection. | IPv4 or IPv6 | Customer |

`managedNATGatewayV2` outbound type is currently in Preview, to use this outbound type, the following steps are needed to install the `aks-preview` Azure CLI extension and register the `ManagedNATGatewayV2Preview` feature flag.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

1. Install or update the Azure CLI preview extension using the [`az extension add`](/cli/azure/extension#az-extension-add) or [`az extension update`](/cli/azure/extension#az-extension-update) command.

    The minimum version of the aks-preview Azure CLI extension is `20.0.0b1`.
    ```azurecli-interactive
    # Install the aks-preview extension
    az extension add --name aks-preview
    # Update the extension to make sure you have the latest version installed
    az extension update --name aks-preview
    ```

2. Register the `ManagedNATGatewayV2Preview` feature flag

    Register the `ManagedNATGatewayV2Preview` feature flag using the [`az feature register`](/cli/azure/feature#az-feature-register) command.
    
    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "ManagedNATGatewayV2Preview"
    ```
    
    Verify successful registration using the [`az feature show`](/cli/azure/feature#az-feature-show) command. It takes a few minutes for the registration to complete.
    
    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "ManagedNATGatewayV2Preview"
    ```
    
    Once the feature shows `Registered`, refresh the registration of the `Microsoft.ContainerService` resource provider using the [`az provider register`](/cli/azure/provider#az-provider-register) command.
    
    
    The following commands create the required resource group, the public IP and public IP prefix resources to attach to the NAT gateway, and the AKS cluster with a managed StandardV2 NAT gateway.

1. Create a resource group using the [`az group create`][az-group-create] command.
   
    ```azurecli-interactive
    export RANDOM_SUFFIX=$(openssl rand -hex 3)
    export MY_RG="myResourceGroup$RANDOM_SUFFIX"
    export MY_AKS="myNatV2Cluster$RANDOM_SUFFIX"
    export MY_IP="myNatOutboundIP$RANDOM_SUFFIX"
    export MY_IP_PREFIX="myNatOutboundIPPrefix$RANDOM_SUFFIX"
    az group create --name $MY_RG --location "eastus2"
    ```
2. Create a zone redundant IPv4 public IP address and public IP prefix using the [`az network public-ip create`][az-network-public-ip-create] command. Store `$MY_IP` and `$MY_IP_PREFIX` to use as outbound IPs for the managed StandardV2 NAT gateway.

    ```azurecli-interactive
    export MY_IP_ID=$(az network public-ip create \
        --resource-group $MY_RG \
        --name $MY_IP \
        --location eastus2 \
        --sku StandardV2 \
        --allocation-method Static \
        --version IPv4 \
        --zone 1 2 3 \
        --query id \
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
3. Create the AKS cluster and reference the public IP address (`$MY_IP_ID`) and public IP prefix (`$MY_IP_PREFIX_ID`).
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
    
Update the outbound IPs, outbound IP prefixes, managed outbound IP count, or idle timeout using the `az aks update` command with the `--nat-gateway-outbound-ips`, `--nat-gateway-outbound-ip-prefixes`, `--nat-gateway-managed-outbound-count`, `--nat-gateway-managed-outbound-ipv6-count`, or `--nat-gateway-idle-timeout` parameter. A `managedNATGatewayV2` can't be updated to switch between customer-defined and managed outbound IP addresses after creation. The outbound IP configuration is determined when the StandardV2 NAT Gateway is initially created and remains immutable.


## Create an AKS cluster with a `managedNATgateway`

* Create an AKS cluster with a managed Standard NAT gateway using the `az aks create` command with `--outbound-type managedNATGateway`. `--nat-gateway-managed-outbound-ip-count`, and `--nat-gateway-idle-timeout` parameters. If you want the NAT gateway to operate out of specific availability zone, specify the zone using `--zones`.

* A managed NAT gateway resource can't be used across multiple availability zones. For zone-redundant outbound connectivity, consider using #create-an-aks-cluster-with-a-managed-nat-gateway-v2.
* If no zone is specified when creating a managed NAT gateway, then NAT gateway is deployed to "no zone" by default. When NAT gateway is placed in **no zone**, Azure places the resource in a zone for you. For more information on non-zonal deployment model, see [non-zonal NAT gateway](/azure/nat-gateway/nat-availability-zones#non-zonal).
  
## <a name="create-an-aks-cluster-with-a-user-assigned-nat-gateway"></a>Create an AKS cluster with a `userAssignedNatGateway`

This configuration requires bring-your-own networking (via [Azure CNI][byo-vnet-azure-cni]) and that the NAT gateway is preconfigured on the subnet. Both Standard and StandardV2 NAT gateways are supported for this `outbound-type`. The following commands create the required resources to deploy a StandardV2 NAT gateway resource for your AKS cluster.

1. Create a resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    export RANDOM_SUFFIX=$(openssl rand -hex 3)
    export MY_RG="myResourceGroup$RANDOM_SUFFIX"
    az group create --name $MY_RG --location southcentralus
    ```

2. Create a managed identity for network permissions and store the ID to `$IDENTITY_ID` for later use.

    ```azurecli-interactive
    export IDENTITY_NAME="myNatClusterId$RANDOM_SUFFIX"
    export IDENTITY_ID=$(az identity create \
        --resource-group $MY_RG \
        --name $IDENTITY_NAME \
        --location southcentralus \
        --query id \
        --output tsv)
    ```

    Results:

    ```output
    /xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroupxxx/providers/Microsoft.ManagedIdentity/userAssignedIdentities/myNatClusterIdxxx
    ```

3. Create a StandardV2 public IP for the NAT gateway using the [`az network public-ip create`][az-network-public-ip-create] command. A StandardV2 NAT gateway requires a StandardV2 public IP address.

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

4. Create the StandardV2 NAT gateway using the [`az network nat gateway create`][az-network-nat-gateway-create] command.

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

   > [!Important]
   > To ensure zone-redundancy, it's recommended to deploy a StandardV2 NAT gateway resource, which spans across multiple availability zones in a region. This ensures continued outbound connectivity even if a single zone fails. For more details on StandardV2 NAT gateway and its benefits, see [StandardV2 NAT Gateway](/azure/nat-gateway/nat-overview#standardv2-nat-gateway). 
   > By comparison, a Standard NAT gateway resource provides resiliency only within the availability zone in which it's deployed.


5. Create a virtual network using the [`az network vnet create`][az-network-vnet-create] command.

    ```azurecli-interactive
    export VNET_NAME="myVnet$RANDOM_SUFFIX"
    az network vnet create \
        --resource-group $MY_RG \
        --name $VNET_NAME \
        --location southcentralus \
        --address-prefixes 172.16.0.0/20 
    ```

6. Create a subnet in the virtual network using the NAT gateway and store the ID to `$SUBNET_ID` for later use.

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

   
7. Create an AKS cluster using the subnet with the NAT gateway and the managed identity using the [`az aks create`][az-aks-create] command.

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

## Disable OutboundNAT for Windows

Windows OutboundNAT can cause certain connection and communication issues with your AKS pods. An example issue is node port reuse. In this example, Windows OutboundNAT uses ports to translate your pod IP to your Windows node host IP, which can cause an unstable connection to the external service due to a port exhaustion issue.

Windows enables OutboundNAT by default. You can now manually disable OutboundNAT when creating new Windows agent pools.

### Prerequisites

* Existing AKS cluster with v1.26 or above. If you're using Kubernetes version 1.25 or older, you need to [update your deployment configuration][upgrade-kubernetes].

### Limitations

* You can't set cluster outbound type to LoadBalancer. You can set it to NAT Gateway or UDR:
  * [NAT Gateway](./nat-gateway.md): NAT Gateway can automatically handle NAT connection and is more powerful than Standard Load Balancer. You might incur extra charges with this option.
  * [UDR (UserDefinedRouting)](./limit-egress-traffic.md): You must keep port limitations in mind when configuring routing rules.
  * If you need to switch from a load balancer to NAT Gateway, you can either add a NAT gateway into the VNet or run [`az aks upgrade`][aks-upgrade] to update the outbound type.

> [!NOTE]
> UserDefinedRouting has the following limitations:
>
> * SNAT by Load Balancer (must use the default OutboundNAT) has "64 ports on the host IP".
> * SNAT by Azure Firewall (disable OutboundNAT) has 2496 ports per public IP.
> * SNAT by NAT Gateway (disable OutboundNAT) has 64512 ports per public IP.
> * If the Azure Firewall port range isn't enough for your application, you need to use NAT Gateway.
> * Azure Firewall doesn't SNAT with Network rules when the destination IP address is in a private IP address range per [IANA RFC 1918 or shared address space per IANA RFC 6598](/azure/firewall/snat-private-range).

### Manually disable OutboundNAT for Windows

* Manually disable OutboundNAT for Windows when creating new Windows agent pools using the [`az aks nodepool add`][az-aks-nodepool-add] command with the `--disable-windows-outbound-nat` flag.

    > [!NOTE]
    > You can use an existing AKS cluster, but you might need to update the outbound type and add a node pool to enable `--disable-windows-outbound-nat`.

    The following command adds a Windows node pool to an existing AKS cluster, disabling OutboundNAT.

    ```shell
      export WIN_NODEPOOL_NAME="win$(head -c 1 /dev/urandom | xxd -p)"
      az aks nodepool add \
        --resource-group $MY_RG \
        --cluster-name $MY_AKS \
        --name $WIN_NODEPOOL_NAME \
        --node-count 3 \
        --os-type Windows \
        --disable-windows-outbound-nat
    ```

    Results:

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

## Next steps

For more information on Azure NAT Gateway, see [Azure NAT Gateway][nat-docs].

<!-- LINKS - internal -->
[api-server-vnet-integration]: api-server-vnet-integration.md
[byo-vnet-azure-cni]: configure-azure-cni.md
[byo-vnet-kubenet]: configure-kubenet.md
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
