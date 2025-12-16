---
title: Establish network connectivity to a private Azure Kubernetes Service (AKS) cluster
description: Learn about the options for connecting to a private AKS cluster, including using Azure Cloud Shell, Azure Bastion, virtual network peering, and private endpoints.
ms.topic: how-to
ms.author: schaffererin
author: schaffererin
ms.date: 09/30/2025
ms.service: azure-kubernetes-service
zone_pivot_groups: private-cluster-connect
# Customer intent: "As a cloud administrator, I want to know how to connect to a private AKS cluster so that I can manage it securely."
---

# Establish network connectivity to a private Azure Kubernetes Service (AKS) cluster

In private AKS clusters, the API server endpoint has no public IP address. To manage the API server, you need to use a virtual machine (VM) or container that has access to the virtual network (VNet) of the AKS cluster. There are several options for establishing network connectivity to the private cluster:

- Use an [Azure Cloud Shell][cloud-shell-vnet] instance deployed into a subnet that's connected to the API server for the cluster.
- Use [Azure Bastion][azure-bastion]'s native client tunneling feature (preview).
- Use a VM in a separate network and set up [virtual network peering][virtual-network-peering].
- Use a [private endpoint][private-endpoint-service] connection.
- Create a VM in the same VNet as the AKS cluster using the [`az vm create`][az-vm-create] command with the `--vnet-name` flag.
- Use an [Express Route or VPN][express-route-or-VPN] connection.
- Use the [AKS `command invoke` feature][command-invoke].

## Choose a connectivity option

Azure Cloud Shell and Azure Bastion (preview) are the easiest options. Express Route and VPNs add costs and require extra networking complexity. Virtual network peering requires you to plan your network CIDR ranges to ensure there are no overlapping ranges.

The following table outlines the key differences and limitations of using Azure Cloud Shell and Azure Bastion:

| Option | Azure Cloud Shell | Azure Bastion (preview) |
|--------|-------------------|--------------------------|
| Key differences | • Best for ad-hoc or infrequent use. <br> • Cost-effective, browser-based access. <br> • Comes with preinstalled tools like `az cli` and `kubectl`. | • Persistent, long-running access. <br> • Suited for managing multiple clusters. <br> • Use your own native client tooling. |
| Limitations | • Not supported with AKS Automatic clusters or clusters with network resource group (NRG) lockdown. <br> • You can't have multiple Cloud Shell sessions in different VNets at the same time. | • Not supported with AKS Automatic clusters or clusters with NRG lockdown.|

:::zone pivot="azure-cloud-shell"

## Connect using Azure Cloud Shell

Connecting to a private AKS cluster through Azure Cloud Shell requires completing the following steps:

- **Deploy required resources:** You need to deploy Cloud Shell in a VNet that can reach your private cluster. This step provisions the necessary infrastructure. While Cloud Shell is a free service, using Cloud Shell in a VNet requires some resources that incur cost. For more information, see [Deploy Cloud Shell in a virtual network][cloud-shell-vnet-deploy].
- **Configure the connection:** After you deploy the resources, any user in the subscription that has appropriate permissions on the cluster can configure Cloud Shell to deploy in the VNet to allow a secure connection to the private cluster.

## Deploy required resources

To deploy and configure the required resources, you must have the **Owner** role assignment on the subscription. To view and assign roles, see [List Owners of a Subscription][list-owners-sub].

You can deploy the required resources using the Azure portal or the provided ARM template if you manage infrastructure as code or have organizational policies that require specific resource naming conventions.

You can optionally leave the deployed resources in place for future connections or delete and recreate them as needed.

### Use the Azure portal (preview)

This option creates a separate VNet with the necessary resources for Cloud Shell and configures VNet peering for you.

1. In the [Azure portal](https://portal.azure.com), navigate to your private cluster resource.
1. On the Overview page, select **Connect**.
1. On the **Cloud Shell** tab, under **Prerequisites for private cluster connection**, select **Configure** to deploy the necessary resources.
    - The deployment creates a new resource group named `RG-CloudShell-PrivateClusterConnection-{RANDOM_ID}`.
1. Once the deployment succeeds, under **Set cluster context**, select **Open Cloud Shell**.

:::image type="content" source="./media/access-private-cluster/azure-portal-cloud-shell-connect.png" alt-text="Screenshot of the Azure portal at a private cluster's resource page showing the Connect button with the Cloud Shell tab selected.":::

> [!NOTE]
> If you already configured Cloud Shell in a VNet for a particular cluster, repeating these steps ensures your Cloud Shell user settings are correctly aligned with that VNet.

### Use an ARM template

To have more control over the deployment configuration, use the [provided ARM template][cloud-shell-vnet-deploy].

You can deploy Cloud Shell in the same VNet as your AKS private cluster with a dedicated subnet, or you can deploy in a new VNet and connect via [VNet peering][virtual-network-peering].

## Configure connection to the private cluster

After you [deploy the required resources](#deploy-required-resources), any user in the subscription can configure their Cloud Shell to deploy in the given VNet using the steps in [Configure Cloud Shell to use a virtual network][cloud-shell-vnet-configure].

Ensure the user has appropriate Kubernetes-level access to successfully connect to the private cluster. For more information, see [Access and identity options for Azure Kubernetes Service (AKS)][access-aks].

:::zone-end

:::zone pivot="azure-bastion"

## Connect using Azure Bastion (preview)

Azure Bastion is a fully managed PaaS service that you provision to securely connect to private resources via private IP addresses. To use Bastion's native client tunneling feature, see [Connect to AKS private cluster using Azure Bastion][azure-bastion].

:::zone-end

:::zone pivot="vnet-peering"

## Connect using virtual network (VNet) peering

To use VNet peering, you need to set up a link between the VNet and the private DNS zone. You can set up VNet peering using either the Azure portal or the Azure CLI.

### Use the Azure portal

1. In the [Azure portal](https://portal.azure.com), navigate to your node resource group and select your **private DNS zone resource**.
1. In the service menu, under **DNS Management**, select **Virtual Network Links** > **Add**.
1. On the **Add Virtual Network Link** page, configure the following settings:

   - **Link name**: Enter a name for the virtual network link.
   - **Virtual Network**: Select the virtual network that contains the VM.

1. Select **Create** to create the virtual network link.
1. Navigate to the resource group that contains the virtual network of your AKS cluster and select your **virtual network resource**.
1. In the service menu, under **Settings**, select **Peerings** > **Add**.
1. On the **Add peering** page, configure the following settings:

   - **Peering link name**: Enter a name for the peering link.
   - **Virtual network**: Select the virtual network of the VM.

1. Select **Add** to create the peering link.

For more information, see [Virtual network peering][virtual-network-peering].

### Use the Azure CLI

1. Create a new link to add the virtual network of the VM to the private DNS zone using the [`az network private-dns link vnet create`][az-network-private-dns-link-vnet-create] command.

    ```azurecli-interactive
    az network private-dns link vnet create \
        --name <new-link-name> \
        --resource-group <node-resource-group-name> \
        --zone-name <private-dns-zone-name> \
        --virtual-network <vm-virtual-network-resource-id> \
        --registration-enabled false
    ```

1. Create a peering between the virtual network of the VM and the virtual network of the node resource group using the [`az network vnet peering create`][az-network-vnet-peering-create] command.

    ```azurecli-interactive
    az network vnet peering create \
        --name <new-peering-name-1> \
        --resource-group <vm-virtual-network-resource-group-name> \
        --vnet-name <vm-virtual-network-name> \
        --remote-vnet <node-resource-group-virtual-network-resource-id> \
        --allow-vnet-access
    ```

1. Create a second peering between the virtual network of the node resource group and the virtual network of the VM using the [`az network vnet peering create`][az-network-vnet-peering-create] command.

    ```azurecli-interactive
    az network vnet peering create \
        --name <new-peering-name-2> \
        --resource-group <node-resource-group-name> \
        --vnet-name <node-resource-group-virtual-network-name> \
        --remote-vnet <vm-virtual-network-resource-id> \
        --allow-vnet-access
    ```

1. List the virtual network peerings you created using the [`az network vnet peering list`][az-network-vnet-peering-list] command.

    ```azurecli-interactive
    az network vnet peering list \
        --resource-group <node-resource-group-name> \
        --vnet-name <private-dns-zone-name>
    ```

:::zone-end

:::zone pivot="private-endpoint"

## Use a private endpoint connection

You can set up a private endpoint so that a VNet doesn't need to be peered to communicate with the private cluster. To set up a private endpoint connection, you first create a new private endpoint in the virtual network containing the consuming resources, and then create a link between your virtual network and a new private DNS zone in the same network.

> [!IMPORTANT]
> If the virtual network is configured with custom DNS servers, you need to set up private DNS appropriately for the environment. For more information, see the [Virtual network name resolution documentation][virtual-networks-name-resolution].

### Create a private endpoint resource

1. From the [Azure portal home page](https://portal.azure.com), select **Create a resource**.
1. Search for **Private Endpoint** and select **Create** > **Private Endpoint**.
1. Select **Create**.
1. On the **Basics** tab, configure the following settings:

   - **Project details**

     - **Subscription**: Select the subscription where your private cluster is located.
     - **Resource group**: Select the resource group that contains your virtual network.

   - **Instance details**

     - **Name**: Enter a name for your private endpoint, such as *myPrivateEndpoint*.
     - **Region**: Select the same region as your virtual network.

1. Select **Next: Resource** and configure the following settings:

   - **Connection method**: Select **Connect to an Azure resource in my directory**.
   - **Subscription**: Select the subscription where your private cluster is located.
   - **Resource type**: Select **Microsoft.ContainerService/managedClusters**.
   - **Resource**: Select your private cluster.
   - **Target sub-resource**: Select **management**.

1. Select **Next: Virtual Network** and configure the following settings:

   - **Networking**
     - **Virtual network**: Select your virtual network.
     - **Subnet**: Select your subnet.

1. Select **Next: DNS** > **Next: Tags** and (optionally) set up key-values as needed.
1. Select **Next: Review + create** > **Create**.

Once the resource is created, record the private IP address of the private endpoint for future use.

### Create a private DNS zone

Once you create the private endpoint, create a new private DNS zone with the same name as the private DNS zone created by the private cluster. Remember to create this DNS zone in the VNet containing the consuming resources.

1. In the Azure portal, navigate to your node resource group and select your **private DNS zone resource**.
1. In the service menu, under **DNS Management**, select **Recordsets** and note the following:

   - The name of the private DNS zone, which follows the pattern `*.privatelink.<region>.azmk8s.io`.
   - The name of the `A` record (excluding the private DNS name).
   - The time-to-live (TTL).

1. From the [Azure portal home page](https://portal.azure.com), select **Create a resource**.
1. Search for **Private DNS zone** and select **Create** > **Private DNS zone**.
1. On the **Basics** tab, configure the following settings:

   - **Project details**

     - Select your **Subscription**.
     - Select the **Resource group** where you created the private endpoint.

   - **Instance details**

     - **Name**: Enter the name of the DNS zone retrieved from previous steps.
     - **Region**: Defaults to the location of your resource group.

1. Select **Review + create** > **Create**.

### Create an `A` record

Once the private DNS zone is created, create an `A` record, which associates the private endpoint to the private cluster.

1. Navigate to your private DNS zone resource.
1. In the service menu, under **DNS Management**, select **Recordsets** > **Add**.
1. On the **Add record set** page, configure the following settings:

   - **Name**: Enter the name retrieved from the `A` record in the private cluster's DNS zone.
   - **Type**: Select **A - Address record**.
   - **TTL**: Enter the number from the `A` record in the private cluster's DNS zone.
   - **TTL unit**: Change the dropdown value to match the one in the `A` record from the private cluster's DNS zone.
   - **IP address**: Enter the **IP address of the private endpoint you created**.

1. Select **Add** to create the `A` record.

> [!IMPORTANT]
> When creating the `A` record, only use the name and not the fully qualified domain name (FQDN).

### Link the private DNS zone to the virtual network

Once the `A` record is created, link the private DNS zone to the virtual network that will access the private cluster.

1. Navigate to your private DNS zone resource.
1. In the service menu, under **DNS Management**, select **Virtual Network Links** > **Add**.
1. On the **Add Virtual Network Link** page, configure the following settings:

   - **Link name**: Enter a name for your virtual network link.
   - **Subscription**: Select the subscription where your private cluster is located.
   - **Virtual Network**: Select the virtual network of your private cluster.

1. Select **Create** to create the link.

    It might take a few minutes for the operation to complete. Once the virtual network link is created, you can access it from the **Virtual Network Links** tab you used in step 2.

> [!WARNING]
>
> - If the private cluster is stopped and restarted, the private cluster's original private link service is removed and recreated, which breaks the connection between your private endpoint and the private cluster. To resolve this issue, delete and recreate any user-created private endpoints linked to the private cluster. If the recreated private endpoints have new IP addresses, you also need to update DNS records.
> - If you update the DNS records in the private DNS zone, ensure the host that you're trying to connect from is using the updated DNS records. You can verify this using the `nslookup` command. If you notice the updates aren't reflected in the output, you might need to flush the DNS cache on your machine and try again.

:::zone-end

:::zone pivot="vm-same-vnet"

## Create a VM in the same virtual network

To create a VM in the same VNet as your private AKS cluster, use the [`az vm create`][az-vm-create] command with the `--vnet-name` flag to specify the VNet.

```azurecli-interactive
az vm create \
    --resource-group <resource-group-name> \
    --name <vm-name> \
    --image <image-name> \
    --vnet-name <vm-virtual-network-name> \
    --subnet <subnet-name> \
    --admin-username <admin-username> \
    --admin-password <admin-password>
```

:::zone-end

:::zone pivot="express-route-or-vpn"

## Use an Express Route or VPN connection

To use an Express Route or VPN connection, see [About ExpressRoute virtual network gateways][express-route-or-vpn].

:::zone-end

:::zone pivot="aks-command-invoke"

## Use the AKS `command invoke` feature

To use the AKS `command invoke` feature to connect to a private cluster, see [Access a private cluster using `command invoke`][command-invoke].

:::zone-end

## Related content

For more information about private clusters in AKS, see [Create a private Azure Kubernetes Service (AKS) cluster](./private-clusters.md).

<!-- LINKS - internal -->
[private-endpoint-service]: /azure/private-link/private-endpoint-overview
[virtual-network-peering]: /azure/virtual-network/virtual-network-peering-overview
[express-route-or-vpn]: /azure/expressroute/expressroute-about-virtual-network-gateways
[command-invoke]: ./access-private-cluster.md
[virtual-networks-name-resolution]: /azure/virtual-network/virtual-networks-name-resolution-for-vms-and-role-instances#name-resolution-that-uses-your-own-dns-server
[az-vm-create]: /cli/azure/vm#az-vm-create
[az-network-private-dns-link-vnet-create]: /cli/azure/network/private-dns/link/vnet#az-network-private-dns-link-vnet-create
[az-network-vnet-peering-create]: /cli/azure/network/vnet/peering#az-network-vnet-peering-create
[az-network-vnet-peering-list]: /cli/azure/network/vnet/peering#az-network-vnet-peering-list
[cloud-shell-vnet]: /azure/cloud-shell/vnet/overview
[cloud-shell-vnet-deploy]: /azure/cloud-shell/vnet/deployment
[cloud-shell-vnet-configure]: /azure/cloud-shell/vnet/deployment#5-configure-cloud-shell-to-use-a-virtual-network
[azure-bastion]: /azure/bastion/bastion-connect-to-aks-private-cluster
[list-owners-sub]: /azure/role-based-access-control/role-assignments-list-portal#list-owners-of-a-subscription
[access-aks]: concepts-identity.md
