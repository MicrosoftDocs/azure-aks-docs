---
title: Create a managed or user-assigned NAT gateway for your Azure Kubernetes Service (AKS) cluster
description: Learn how to create an AKS cluster with managed NAT integration and user-assigned NAT gateway.
ms.topic: how-to
ms.date: 06/03/2024
author: davidsmatlak
ms.author: davidsmatlak
ms.custom: devx-track-azurecli
---

# Create a managed or user-assigned NAT gateway for your Azure Kubernetes Service (AKS) cluster

While you can route egress traffic through an Azure Load Balancer, there are limitations on the number of outbound flows of traffic you can have. Azure NAT Gateway allows up to 64,512 outbound UDP and TCP traffic flows per IP address with a maximum of 16 IP addresses.

This article shows you how to create an Azure Kubernetes Service (AKS) cluster with a managed NAT gateway and a user-assigned NAT gateway for egress traffic. It also shows you how to disable OutboundNAT on Windows.

## Before you begin

* Make sure you're using the latest version of [Azure CLI][az-cli].
* Make sure you're using Kubernetes version 1.20.x or above.
* Managed NAT gateway is incompatible with custom virtual networks.

> [!IMPORTANT]
> In non-private clusters, API server cluster traffic is routed and processed through the clusters outbound type. To prevent API server traffic from being processed as public traffic, consider using a [private cluster][private-cluster], or check out the [API Server VNet Integration][api-server-vnet-integration] feature.

## Create an AKS cluster with a managed NAT gateway

* Create an AKS cluster with a new managed NAT gateway using the [`az aks create`][az-aks-create] command with the `--outbound-type managedNATGateway`, `--nat-gateway-managed-outbound-ip-count`, and `--nat-gateway-idle-timeout` parameters. If you want the NAT gateway to operate out of a specific availability zone, specify the zone using `--zones`.
* If no zone is specified when creating a managed NAT gateway, then NAT gateway is deployed to "no zone" by default. When NAT gateway is placed in **no zone**, Azure places the resource in a zone for you. For more information on non-zonal deployment model, see [non-zonal NAT gateway](/azure/nat-gateway/nat-availability-zones#non-zonal).
* A managed NAT gateway resource can't be used across multiple availability zones.

The following commands first create the required resource group, then the AKS cluster with a managed NAT gateway.

```azurecli-interactive
export RANDOM_SUFFIX=$(openssl rand -hex 3)
export MY_RG="myResourceGroup$RANDOM_SUFFIX"
export MY_AKS="myNatCluster$RANDOM_SUFFIX"
az group create --name $MY_RG --location "eastus2"
```

Results:

```output
{
  "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroupxxx",
  "location": "eastus2",
  "managedBy": null,
  "name": "myResourceGroupxxx",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null,
  "type": "Microsoft.Resources/resourceGroups"
}
```

```azurecli-interactive
az aks create \
    --resource-group $MY_RG \
    --name $MY_AKS \
    --node-count 3 \
    --outbound-type managedNATGateway \
    --nat-gateway-managed-outbound-ip-count 2 \
    --nat-gateway-idle-timeout 4 \
    --generate-ssh-keys
```

Results:

<!-- expected_similarity=0.3 -->

```output
{
  "aadProfile": null,
  "agentPoolProfiles": [
    {
      ...
      "name": "nodepool1",
      ...
      "provisioningState": "Succeeded",
      ...
    }
  ],
  "dnsPrefix": "myNatClusterxxx-dns-xxx",
  "fqdn": "myNatClusterxxx-dns-xxx.xxxxx.xxxxxx.cloudapp.azure.com",
  "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/myResourceGroupxxx/providers/Microsoft.ContainerService/managedClusters/myNatClusterxxx",
  "name": "myNatClusterxxx",
  ...
  "resourceGroup": "myResourceGroupxxx",
  ...
  "provisioningState": "Succeeded",
  ...
  "type": "Microsoft.ContainerService/ManagedClusters"
}
```

* Update the outbound IP address or idle timeout using the [`az aks update`][az-aks-update] command with the `--nat-gateway-managed-outbound-ip-count` or `--nat-gateway-idle-timeout` parameter.

The following example updates the NAT gateway managed outbound IP count for the AKS cluster to 5.

```azurecli-interactive
az aks update \
    --resource-group $MY_RG \
    --name $MY_AKS \
    --nat-gateway-managed-outbound-ip-count 5
```

Results: 

<!-- expected_similarity=0.3 -->

```output
{
  "aadProfile": null,
  "agentPoolProfiles": [
    {
      ...
      "name": "nodepool1",
      ...
      "provisioningState": "Succeeded",
      ...
    }
  ],
  "dnsPrefix": "myNatClusterxxx-dns-xxx",
  "fqdn": "myNatClusterxxx-dns-xxx.xxxxx.xxxxxx.cloudapp.azure.com",
  "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/myResourceGroupxxx/providers/Microsoft.ContainerService/managedClusters/myNatClusterxxx",
  "name": "myNatClusterxxx",
  ...
  "resourceGroup": "myResourceGroupxxx",
  ...
  "provisioningState": "Succeeded",
  ...
  "type": "Microsoft.ContainerService/ManagedClusters"
}
```

## Create an AKS cluster with a user-assigned NAT gateway

This configuration requires bring-your-own networking (via [Kubenet][byo-vnet-kubenet] or [Azure CNI][byo-vnet-azure-cni]) and that the NAT gateway is preconfigured on the subnet. The following commands create the required resources for this scenario.

1. Create a resource group using the [`az group create`][az-group-create] command.

    ```shell
    export RANDOM_SUFFIX=$(openssl rand -hex 3)
    export MY_RG="myResourceGroup$RANDOM_SUFFIX"
    az group create --name $MY_RG --location southcentralus
    ```

    Results:

    ```output
    {
      "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroupxxx",
      "location": "southcentralus",
      "managedBy": null,
      "name": "myResourceGroupxxx",
      "properties": {
        "provisioningState": "Succeeded"
      },
      "tags": null,
      "type": "Microsoft.Resources/resourceGroups"
    }
    ```

2. Create a managed identity for network permissions and store the ID to `$IDENTITY_ID` for later use.

    ```shell
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

3. Create a public IP for the NAT gateway using the [`az network public-ip create`][az-network-public-ip-create] command.

    ```shell
    export PIP_NAME="myNatGatewayPip$RANDOM_SUFFIX"
    az network public-ip create \
        --resource-group $MY_RG \
        --name $PIP_NAME \
        --location southcentralus \
        --sku standard
    ```

    Results:

    ```output
    {
      "publicIp": {
        "ddosSettings": null,
        "dnsSettings": null,
        "etag": "W/\"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\"",
        "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroupxxx/providers/Microsoft.Network/publicIPAddresses/myNatGatewayPipxxx",
        "ipAddress": null,
        "ipTags": [],
        "location": "southcentralus",
        "name": "myNatGatewayPipxxx",
        ...
        "provisioningState": "Succeeded",
        ...
        "sku": {
          "name": "Standard",
          "tier": "Regional"
        },
        "type": "Microsoft.Network/publicIPAddresses",
        ...
      }
    }
    ```

4. Create the NAT gateway using the [`az network nat gateway create`][az-network-nat-gateway-create] command.

    ```shell
    export NATGATEWAY_NAME="myNatGateway$RANDOM_SUFFIX"
    az network nat gateway create \
        --resource-group $MY_RG \
        --name $NATGATEWAY_NAME \
        --location southcentralus \
        --public-ip-addresses $PIP_NAME
    ```

    Results:

    ```output
    {
      "etag": "W/\"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\"",
      "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroupxxx/providers/Microsoft.Network/natGateways/myNatGatewayxxx",
      "location": "southcentralus",
      "name": "myNatGatewayxxx",
      "provisioningState": "Succeeded",
      "publicIpAddresses": [
        {
          "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroupxxx/providers/Microsoft.Network/publicIPAddresses/myNatGatewayPipxxx"
        }
      ],
      ...
      "type": "Microsoft.Network/natGateways"
    }
    ```

   > [!Important]
   > A single NAT gateway resource can't be used across multiple availability zones. To ensure zone-resiliency, it is recommended to deploy a NAT gateway resource to each availability zone and assign to subnets containing AKS clusters in each zone. For more information on this deployment model, see [NAT gateway for each zone](/azure/nat-gateway/nat-availability-zones#zonal-nat-gateway-resource-for-each-zone-in-a-region-to-create-zone-resiliency).
   > If no zone is configured for NAT gateway, the default zone placement is "no zone", in which Azure places NAT gateway into a zone for you.

5. Create a virtual network using the [`az network vnet create`][az-network-vnet-create] command.

    ```shell
    export VNET_NAME="myVnet$RANDOM_SUFFIX"
    az network vnet create \
        --resource-group $MY_RG \
        --name $VNET_NAME \
        --location southcentralus \
        --address-prefixes 172.16.0.0/20 
    ```

    Results:

    ```output
    {
      "newVNet": {
        "addressSpace": {
          "addressPrefixes": [
            "172.16.0.0/20"
          ]
        },
        ...
        "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroupxxx/providers/Microsoft.Network/virtualNetworks/myVnetxxx",
        "location": "southcentralus",
        "name": "myVnetxxx",
        "provisioningState": "Succeeded",
        ...
        "type": "Microsoft.Network/virtualNetworks",
        ...
      }
    }
    ```

6. Create a subnet in the virtual network using the NAT gateway and store the ID to `$SUBNET_ID` for later use.

    ```shell
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

    Results:

    ```output
    /xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroupxxx/providers/Microsoft.Network/virtualNetworks/myVnetxxx/subnets/myNatClusterxxx
    ```

7. Create an AKS cluster using the subnet with the NAT gateway and the managed identity using the [`az aks create`][az-aks-create] command.

    ```shell
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

    Results:

    ```output
    {
      "aadProfile": null,
      "agentPoolProfiles": [
        {
          ...
          "name": "nodepool1",
          ...
          "provisioningState": "Succeeded",
          ...
        }
      ],
      "dnsPrefix": "myNatClusterxxx-dns-xxx",
      "fqdn": "myNatClusterxxx-dns-xxx.xxxxx.xxxxxx.cloudapp.azure.com",
      "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/myResourceGroupxxx/providers/Microsoft.ContainerService/managedClusters/myNatClusterxxx",
      "name": "myNatClusterxxx",
      ...
      "resourceGroup": "myResourceGroupxxx",
      ...
      "provisioningState": "Succeeded",
      ...
      "type": "Microsoft.ContainerService/ManagedClusters"
    }
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
[az-group-create]: /cli/azure/group#az_group_create
[az-network-public-ip-create]: /cli/azure/network/public-ip#az_network_public_ip_create
[az-network-nat-gateway-create]: /cli/azure/network/nat/gateway#az_network_nat_gateway_create
[az-network-vnet-create]: /cli/azure/network/vnet#az_network_vnet_create
[az-aks-nodepool-add]: /cli/azure/aks/nodepool#az_aks_nodepool_add
