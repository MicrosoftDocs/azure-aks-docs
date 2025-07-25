---
title: API Server VNet Integration in Azure Kubernetes Service (AKS)
description: Learn how to create an Azure Kubernetes Service (AKS) cluster with API Server VNet Integration
author: asudbring
ms.author: allensu
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 05/19/2023
ms.custom: references_regions, devx-track-azurecli
# Customer intent: As a cloud architect, I want to configure an Azure Kubernetes Service cluster with API Server VNet Integration, so that I can ensure secure, private communication between the API server and cluster nodes without requiring external links or tunnels.
---

# Create an Azure Kubernetes Service cluster with API Server VNet Integration 

An Azure Kubernetes Service (AKS) cluster configured with API Server VNet Integration projects the API server endpoint directly into a delegated subnet in the VNet where AKS is deployed. API Server VNet Integration enables network communication between the API server and the cluster nodes without requiring a private link or tunnel. The API server is available behind an internal load balancer VIP in the delegated subnet, which the nodes are configured to utilize. By using API Server VNet Integration, you can ensure network traffic between your API server and your node pools remains on the private network only.

## API server connectivity

The control plane or API server is in an AKS-managed Azure subscription. Your cluster or node pool is in your Azure subscription. The server and the virtual machines that make up the cluster nodes can communicate with each other through the API server VIP and pod IPs that are projected into the delegated subnet.

API Server VNet Integration is supported for public or private clusters. You can add or remove public access after cluster provisioning. Unlike non-VNet integrated clusters, the agent nodes always communicate directly with the private IP address of the API server internal load balancer (ILB) IP without using DNS. All node to API server traffic is kept on private networking, and no tunnel is required for API server to node connectivity. Out-of-cluster clients needing to communicate with the API server can do so normally if public network access is enabled. If public network access is disabled, you should follow the same private DNS setup methodology as standard [private clusters](private-clusters.md).

## Prerequisites

- You must have Azure CLI version 2.73.0 or later installed. You can check your version using the `az --version` command.

## Limited availability

> [!IMPORTANT]
> **API Server VNet Integration has limited availability and capacity in certain regions.**  
> When creating or updating a cluster with API Server VNet Integration enabled, you may receive the following error:
>
> **`API Server VNet Integration is currently unavailable in region (_region_) due to high demand and limited capacity. AKS is actively expanding support for this feature. Check for other available regions at aka.ms/AksVnetIntegration.`**
>
> This message indicates that the selected region has temporarily reached capacity for API Server VNet Integration.
>
> **To proceed**, you can:
> - Retry your request at a later time, as capacity may become available.
> - Select an alternate region where this feature is currently supported.

API Server VNet Integration is available in the following regions: 

australiacentral, australiacentral2, australiaeast, australiasoutheast, brazilsouth, brazilsoutheast, canadacentral, canadaeast, centralindia, centraluseuap, eastasia, eastus2euap, francecentral, francesouth, germanynorth, germanywestcentral, indonesiacentral, israelcentral, italynorth, japaneast, japanwest, jioindiacentral, jioindiawest, koreacentral, koreasouth, mexicocentral, newzealandnorth, northcentralus, northeurope, norwayeast, norwaywest, polandcentral, southafricanorth, southafricawest, southcentralus, southeastasia, southeastus, southindia, spaincentral, swedencentral, swedensouth, switzerlandnorth, switzerlandwest, taiwannorth, taiwannorthwest, uaecentral, uaenorth, uksouth, ukwest, westcentralus, westeurope, westus, westus2, westus3

## Create an AKS cluster with API Server VNet Integration using managed VNet

You can configure your AKS clusters with API Server VNet Integration in managed VNet or bring-your-own VNet mode. You can create them as public clusters (with API server access available via a public IP) or private clusters (where the API server is only accessible via private VNet connectivity). You can also toggle between a public and private state without redeploying your cluster.

### Create a resource group

* Create a resource group using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --location westus2 --name <resource-group>
    ```

### Deploy a public cluster

* Deploy a public AKS cluster with API Server VNet integration for managed VNet using the [`az aks create`][az-aks-create] command with the `--enable-api-server-vnet-integration` flag.

    ```azurecli-interactive
    az aks create --name <cluster-name> \
        --resource-group <resource-group> \
        --location <location> \
        --network-plugin azure \
        --enable-apiserver-vnet-integration \
        --generate-ssh-keys
    ```

### Deploy a private cluster

* Deploy a private AKS cluster with API Server VNet integration for managed VNet using the [`az aks create`][az-aks-create] command with the `--enable-api-server-vnet-integration` and `--enable-private-cluster` flags.

    ```azurecli-interactive
    az aks create --name <cluster-name> \
        --resource-group <resource-group> \
        --location <location> \
        --network-plugin azure \
        --enable-private-cluster \
        --enable-apiserver-vnet-integration \
        --generate-ssh-keys
    ```

## Create a private AKS cluster with API Server VNet Integration using bring-your-own VNet

When using bring-your-own VNet, you must create and delegate an API server subnet to `Microsoft.ContainerService/managedClusters`, which grants the AKS service permissions to inject the API server pods and internal load balancer into that subnet. You can't use the subnet for any other workloads, but you can use it for multiple AKS clusters located in the same virtual network. The minimum supported API server subnet size is a */28*.

The cluster identity needs permissions to both the API server subnet and the node subnet. Lack of permissions at the API server subnet can cause a provisioning failure.

> [!WARNING]
> An AKS cluster reserves at least 9 IPs in the subnet address space. Running out of IP addresses may prevent API server scaling and cause an API server outage.

### Create a resource group

* Create a resource group using the [`az group create`][az-group-create] command.

```azurecli-interactive
az group create --location <location> --name <resource-group>
```

### Create a virtual network

1. Create a virtual network using the [`az network vnet create`][az-network-vnet-create] command.

    ```azurecli-interactive
    az network vnet create --name <vnet-name> \
    --resource-group <resource-group> \
    --location <location> \
    --address-prefixes 172.19.0.0/16
    ```

2. Create an API server subnet using the [`az network vnet subnet create`][az-network-vnet-subnet-create] command.

    ```azurecli-interactive
    az network vnet subnet create --resource-group <resource-group> \
    --vnet-name <vnet-name> \
    --name <apiserver-subnet-name> \
    --delegations Microsoft.ContainerService/managedClusters \
    --address-prefixes 172.19.0.0/28
    ```

3. Create a cluster subnet using the [`az network vnet subnet create`][az-network-vnet-subnet-create] command.

    ```azurecli-interactive
    az network vnet subnet create --resource-group <resource-group> \
    --vnet-name <vnet-name> \
    --name <cluster-subnet-name> \
    --address-prefixes 172.19.1.0/24
    ```

### Create a managed identity and give it permissions on the virtual network

1. Create a managed identity using the [`az identity create`][az-identity-create] command.

    ```azurecli-interactive
    az identity create --resource-group <resource-group> --name <managed-identity-name> --location <location>
    ```

2. Assign the Network Contributor role to the API server subnet using the [`az role assignment create`][az-role-assignment-create] command.

    ```azurecli-interactive
    az role assignment create --scope <apiserver-subnet-resource-id> \
    --role "Network Contributor" \
    --assignee <managed-identity-client-id>
    ```

3. Assign the Network Contributor role to the cluster subnet using the [`az role assignment create`][az-role-assignment-create] command.

    ```azurecli-interactive
    az role assignment create --scope <cluster-subnet-resource-id> \
    --role "Network Contributor" \
    --assignee <managed-identity-client-id>
    ```

### Deploy a public cluster

* Deploy a public AKS cluster with API Server VNet integration using the [`az aks create`][az-aks-create] command with the `--enable-api-server-vnet-integration` flag.

    ```azurecli-interactive
    az aks create --name <cluster-name> \
        --resource-group <resource-group> \
        --location <location> \
        --network-plugin azure \
        --enable-apiserver-vnet-integration \
        --vnet-subnet-id <cluster-subnet-resource-id> \
        --apiserver-subnet-id <apiserver-subnet-resource-id> \
        --assign-identity <managed-identity-resource-id> \
        --generate-ssh-keys
    ```

### Deploy a private cluster

* Deploy a private AKS cluster with API Server VNet integration using the [`az aks create`][az-aks-create] command with the `--enable-api-server-vnet-integration` and `--enable-private-cluster` flags.

    ```azurecli-interactive
    az aks create --name <cluster-name> \
    --resource-group <resource-group> \
    --location <location> \
    --network-plugin azure \
    --enable-private-cluster \
    --enable-apiserver-vnet-integration \
    --vnet-subnet-id <cluster-subnet-resource-id> \
    --apiserver-subnet-id <apiserver-subnet-resource-id> \
    --assign-identity <managed-identity-resource-id> \
    --generate-ssh-keys
    ```

## Convert an existing AKS cluster to API Server VNet Integration

> [!WARNING]
> **API Server VNet Integration is a one-way, capacity-sensitive feature.**
>
> - **Manual restart required.**  
>   After enabling API Server VNet Integration using `az aks update --enable-apiserver-vnet-integration`, you must immediately restart the cluster for the change to take effect. This restart is not automated. Delaying the restart increases the risk of capacity becoming unavailable, which can prevent the API server from starting.
>
> - **Capacity is validated, but not reserved.**  
>   AKS validates regional capacity when you enable the feature on an existing cluster, but this validation does not reserve capacity. If the restart is delayed and capacity becomes unavailable in the meantime, the cluster may fail to start after a stop or restart. Clusters that enabled this feature before general availability (GA), or that have not yet restarted since enablement, will not undergo capacity validation.
>
> - **Feature cannot be disabled.**  
>   Once enabled, the feature is permanent. You cannot disable API Server VNet Integration.

This upgrade performs a node-image version upgrade on all node pools and restarts all workloads while they undergo a rolling image upgrade.

> [!WARNING]
> Converting a cluster to API Server VNet Integration results in a change of the API Server IP address, though the hostname remains the same. If the IP address of the API server has been configured in any firewalls or network security group rules, those rules may need to be updated.

* Update your cluster to API Server VNet Integration using the [`az aks update`][az-aks-update] command with the `--enable-apiserver-vnet-integration` flag.

    ```azurecli-interactive
    az aks update --name <cluster-name> \
    --resource-group <resource-group> \
    --enable-apiserver-vnet-integration \
    --apiserver-subnet-id <apiserver-subnet-resource-id>
    ```

## Enable or disable private cluster mode on an existing cluster with API Server VNet Integration

AKS clusters configured with API Server VNet Integration can have public network access/private cluster mode enabled or disabled without redeploying the cluster. The API server hostname doesn't change, but public DNS entries are modified or removed if necessary.

> [!NOTE]
> `--disable-private-cluster` is currently in preview. For more information, see [Reference and support levels][ref-support-levels].

### Enable private cluster mode

* Enable private cluster mode using the [`az aks update`][az-aks-update] command with the `--enable-private-cluster` flag.

    ```azurecli-interactive
    az aks update --name <cluster-name> \
    --resource-group <resource-group> \
    --enable-private-cluster
    ```

### Disable private cluster mode

* Disable private cluster mode using the [`az aks update`][az-aks-update] command with the `--disable-private-cluster` flag.

    ```azurecli-interactive
    az aks update --name <cluster-name> \
    --resource-group <resource-group> \
    --disable-private-cluster
    ```

## Connect to cluster using kubectl

* Configure `kubectl` to connect to your cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group <resource-group> --name <cluster-name>
    ```

## Expose the API server through Private Link

You can expose the API server endpoint of a private cluster with API Server VNet Integration using Azure Private Link. The following steps show how to create a Private Link Service (PLS) in the cluster VNet and connect to it from another VNet or subscription using a Private Endpoint.

### Create an API Server VNet Integration Private cluster

* Create a private AKS cluster with API Server VNet Integration using the [`az aks create`][az-aks-create] command with the `--enable-api-server-vnet-integration` and `--enable-private-cluster` flags.

    ```azurecli-interactive
    az aks create --name <cluster-name> \
        --resource-group <resource-group> \
        --location <location> \
        --enable-private-cluster \
        --enable-apiserver-vnet-integration
    ```



## NSG security rules

All traffic within the VNet is allowed by default. But if you have added NSG rules to restrict traffic between different subnets, ensure that the NSG security rules permit the following types of communication:

| Destination           | Source              | Protocol | Port         | Use                                                                                                                                                                                     |
|-----------------------|---------------------|----------|--------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| APIServer Subnet CIDR | Cluster Subnet      | TCP      | 443 and 4443 | Required to enable communication between Nodes and the API server.                                                                                                                      |
| APIServer Subnet CIDR | Azure Load Balancer | TCP      | 9988         | Required to enable communication between Azure Load Balancer and the API server. You can also enable all communications between the Azure Load Balancer and the API Server Subnet CIDR. |

## Next steps

For associated best practices, see [Best practices for network connectivity and security in AKS][operator-best-practices-network].

<!-- LINKS - internal -->
[operator-best-practices-network]: operator-best-practices-network.md
[az-group-create]: /cli/azure/group#az-group-create
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-network-vnet-create]: /cli/azure/network/vnet#az-network-vnet-create
[az-network-vnet-subnet-create]: /cli/azure/network/vnet/subnet#az-network-vnet-subnet-create
[az-identity-create]: /cli/azure/identity#az-identity-create
[az-role-assignment-create]: /cli/azure/role/assignment#az-role-assignment-create
[ref-support-levels]: /cli/azure/reference-types-and-status
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials

