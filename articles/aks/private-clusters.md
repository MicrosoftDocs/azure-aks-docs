---
title: Create a private Azure Kubernetes Service (AKS) cluster
description: Learn how to create a private Azure Kubernetes Service (AKS) cluster with enhanced security and network control.
ms.topic: how-to
ms.author: schaffererin
author: schaffererin
ms.date: 09/30/2025
ms.custom: references_regions, devx-track-azurecli
ms.service: azure-kubernetes-service
# Customer intent: "As a cloud administrator, I want to deploy a private Azure Kubernetes Service cluster, so that I can ensure secure network traffic and enhanced control over my Kubernetes resources."
---

# Create a private Azure Kubernetes Service (AKS) cluster

This article helps you deploy a private link-based AKS cluster. If you're interested in creating an AKS cluster without required private link or tunnel, see [Create an Azure Kubernetes Service (AKS) cluster with API Server VNet integration][create-aks-cluster-api-vnet-integration].

## Overview of private clusters in AKS

In a private cluster, the control plane or API server has internal IP addresses that are defined in the [RFC1918 - Address Allocation for Private Internet][rfc1918-document] document. By using a private cluster, you can ensure network traffic between your API server and your node pools remains only on the private network.

The control plane or API server is in an AKS-managed Azure resource group, and your cluster or node pool is in your resource group. The server and the cluster or node pool can communicate with each other through the [Azure Private Link service][private-link-service] in the API server virtual network and a private endpoint exposed on the subnet of your AKS cluster.

When you create a private AKS cluster, AKS creates both private and public FQDNs with corresponding DNS zones by default. For detailed DNS configuration options, see [Configure a private DNS zone, private DNS subzone, or custom subdomain](#configure-a-private-dns-zone-private-dns-subzone-or-custom-subdomain-for-a-private-aks-cluster).

## Region availability

Private clusters are available in public regions, Azure Government, and Microsoft Azure operated by 21Vianet regions where [AKS is supported][aks-supported-regions].

## Prerequisites for private AKS clusters

- The Azure CLI version 2.28.0 or higher. Run `az --version` to find the version, and run `az upgrade` to upgrade the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
- If using Azure Resource Manager (ARM) or the Azure REST API, the AKS API version must be _2021-05-01 or higher_.
- To use a custom DNS server, add the Azure public IP address _168.63.129.16_ as the upstream DNS server in the custom DNS server, and make sure to add this public IP address as the _first_ DNS server. For more information about the Azure IP address, see [What is IP address 168.63.129.16?][virtual-networks-168.63.129.16]
  - The cluster's DNS zone should be what you forward to _168.63.129.16_. You can find more information on zone names in [Azure services DNS zone configuration][az-dns-zone].
- Existing AKS clusters enabled with API Server VNet integration can have private cluster mode enabled. For more information, see [Enable or disable private cluster mode on an existing cluster with API Server VNet integration][api-server-vnet-integration].

> [!IMPORTANT]
> Starting on **30 November 2025**, AKS will no longer support or provide security updates for Azure Linux 2.0. Starting on **31 March 2026**, node images will be removed, and you'll be unable to scale your node pools. Migrate to a supported Azure Linux version by [**upgrading your node pools**](/azure/aks/upgrade-aks-cluster) to a supported Kubernetes version or migrating to [`osSku AzureLinux3`](/azure/aks/upgrade-os-version). For more information, see [[Retirement] Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).

## Limitations and considerations for private AKS clusters

- You can't apply IP authorized ranges to the private API server endpoint - they only apply to the public API server.
- [Azure Private Link service limitations][private-link-service] apply to private clusters.
- There's no support for Azure DevOps Microsoft-hosted Agents with private clusters. Consider using [self-hosted agents](/azure/devops/pipelines/agents/agents).
- If you need to enable Azure Container Registry on a private AKS cluster, [set up a private link for the container registry in the cluster virtual network (VNet)][container-registry-private-link] or set up peering between the container registry's virtual network and the private cluster's virtual network.
- Deleting or modifying the private endpoint in the customer subnet causes the cluster to stop functioning.
- Azure Private Link service is supported on Standard Azure Load Balancer only. Basic Azure Load Balancer isn't supported.

## Hub and spoke with custom DNS for private AKS clusters

[Hub and spoke architectures](/azure/architecture/reference-architectures/hybrid-networking/hub-spoke) are commonly used to deploy networks in Azure. In many of these deployments, DNS settings in the spoke VNets are configured to reference a central DNS forwarder to allow for on-premises and Azure-based DNS resolution.

![Private cluster hub and spoke](media/private-clusters/aks-private-hub-spoke.png)

Keep the following considerations in mind when deploying private AKS clusters in hub and spoke architectures with custom DNS:

- When a private cluster is created, a private endpoint (1) and a private DNS zone (2) are created in the cluster-managed resource group by default. The cluster uses an `A` record in the private zone to resolve the IP of the private endpoint for communication to the API server.
- The private DNS zone is linked only to the VNet that the cluster nodes are attached to (3), which means that the private endpoint can only be resolved by hosts in that linked VNet. In scenarios where no custom DNS is configured on the VNet (default), it works without issue as hosts point at _168.63.129.16_ for DNS that can resolve records in the private DNS zone because of the link.
- If you keep the default private DNS zone behavior, AKS tries to link the zone directly to the spoke VNet that hosts the cluster even when the zone is already linked to a hub VNet.
  
  In spoke VNets that use custom DNS servers, this action can fail if the cluster’s managed identity lacks **Network Contributor** on the spoke VNet.

  To prevent the failure, choose **one** of the following supported configurations:

  - **Custom private DNS zone**: Provide a precreated private zone and set `privateDNSZone` / `--private-dns-zone` to its resource ID. Link that zone to the appropriate VNet (for example, the hub VNet) and set `publicDNS` to `false` / use `--disable-public-fqdn`..
  - **Public DNS only**: Disable private zone creation by setting `privateDNSZone` / `--private-dns-zone` to `none` **and** leave `publicDNS` at its default value (`true`) / don't use `--disable-public-fqdn`.

- If you're using [bring your own (BYO) route table with kubenet](./configure-kubenet.md#bring-your-own-subnet-and-route-table-with-kubenet) and BYO DNS with private clusters, cluster creation fails. You need to associate the [`RouteTable`](./configure-kubenet.md#bring-your-own-subnet-and-route-table-with-kubenet) in the node resource group to the subnet after the cluster creation failed to make the creation successful.

Keep the following limitations in mind when using custom DNS with private AKS clusters:

- Setting `privateDNSZone` / `--private-dns-zone` to `none` **and** `publicDNS: false` / `--disable-public-fqdn` at the same time **isn't supported**.
- Conditional forwarding doesn't support subdomains.

## Create a private AKS cluster with default basic networking

1. Create a resource group using the [`az group create`][az-group-create] command. You can also use an existing resource group for your AKS cluster.

    ```azurecli-interactive
    az group create \
        --name <private-cluster-resource-group> \
        --location <location>
    ```

1. Create a private cluster with default basic networking using the [`az aks create`][az-aks-create] command with the `--enable-private-cluster` flag.

    **Key parameters in this command**:

    - `--enable-private-cluster`: Enables private cluster mode.

    ```azurecli-interactive
    az aks create \
        --name <private-cluster-name> \
        --resource-group <private-cluster-resource-group> \
        --load-balancer-sku standard \
        --enable-private-cluster \
        --generate-ssh-keys
    ```

1. [Configure kubectl to connect to the private AKS cluster](#configure-kubectl-to-connect-to-a-private-aks-cluster).

## Create a private AKS cluster with advanced networking

1. Create a resource group using the [`az group create`][az-group-create] command. You can also use an existing resource group for your AKS cluster.

    ```azurecli-interactive
    az group create \
        --name <private-cluster-resource-group> \
        --location <location>
    ```

1. Create a private cluster with advanced networking using the [`az aks create`][az-aks-create] command.

     **Key parameters in this command**:

    - `--enable-private-cluster`: Enables private cluster mode.
    - `--network-plugin azure`: Specifies the Azure CNI networking plugin.
    - `--vnet-subnet-id`: The resource ID of an existing subnet in a virtual network.
    - `--dns-service-ip`: An available IP address within the Kubernetes service address range that will be used for the cluster DNS service.
    - `--service-cidr`: A CIDR notation IP range from which to assign service cluster IPs.

    ```azurecli-interactive
    az aks create \
        --resource-group <private-cluster-resource-group> \
        --name <private-cluster-name> \
        --load-balancer-sku standard \
        --enable-private-cluster \
        --network-plugin azure \
        --vnet-subnet-id <subnet-id> \
        --dns-service-ip 10.2.0.10 \
        --service-cidr 10.2.0.0/24
        --generate-ssh-keys
    ```

1. [Configure kubectl to connect to the private AKS cluster](#configure-kubectl-to-connect-to-a-private-aks-cluster).

## Use custom domains with private AKS clusters

If you want to configure custom domains that can only be resolved internally, see [Use custom domains][use-custom-domains].

## Disable a public FQDN on a private AKS cluster

### Disable a public FQDN on a new cluster

- Disable a public FQDN when creating a private AKS cluster using the [`az aks create`][az-aks-create] command with the `--disable-public-fqdn` flag.

    ```azurecli-interactive
    az aks create \
        --name <private-cluster-name> \
        --resource-group <private-cluster-resource-group> \
        --load-balancer-sku standard \
        --enable-private-cluster \
        --assign-identity <resource-id> \
        --private-dns-zone <private-dns-zone-mode> \
        --disable-public-fqdn \
        --generate-ssh-keys
    ```

### Disable a public FQDN on an existing cluster

- Disable a public FQDN on an existing AKS cluster using the [`az aks update`][az-aks-update] command with the `--disable-public-fqdn` flag.

    ```azurecli-interactive
    az aks update \
        --name <private-cluster-name> \
        --resource-group <private-cluster-resource-group> \
        --disable-public-fqdn
    ```

## Configure a private DNS zone, private DNS subzone, or custom subdomain for a private AKS cluster

You can configure private DNS settings for a private AKS cluster using the Azure CLI (with the `--private-dns-zone` parameter) or an Azure Resource Manager (ARM) template (with the `privateDNSZone` property). The following table outlines the options available for the `--private-dns-zone` parameter / `privateDNSZone` property:

| Setting | Description |
|---------|-------------|
| `system` | The default value when configuring a a private DNS zone. If you omit `--private-dns-zone` / `privateDNSZone`, AKS creates a private DNS zone in the node resource group. |
| `none` | If you set `--private-dns-zone` / `privateDNSZone` to `none`, AKS doesn't create a private DNS zone. |
| `<custom-private-dns-zone-resource-id>` | To use this parameter, you need to create a private DNS zone in the following format for Azure global cloud: `privatelink.<region>.azmk8s.io` or `<subzone>.privatelink.<region>.azmk8s.io`. You need the resource ID of the private DNS zone for future use. You also need a user-assigned identity or service principal with the [Private DNS Zone Contributor][private-dns-zone-contributor-role] and [Network Contributor][network-contributor-role] roles. For clusters using API Server VNet integration, a private DNS zone supports the naming format of `private.<region>.azmk8s.io` or `<subzone>.private.<region>.azmk8s.io`. You **can't change or delete this resource after creating the cluster**, as it can cause performance issues and cluster upgrade failures. You can use `--fqdn-subdomain <subdomain>` with `<custom-private-dns-zone-resource-id>` only to provide subdomain capabilities to `privatelink.<region>.azmk8s.io`. If you're specifying a subzone, there's a 32 character limit for the `<subzone>` name. |

Keep the following considerations in mind when configuring private DNS for a private AKS cluster:

- If the private DNS zone is in a different subscription than the AKS cluster, you need to register the `Microsoft.ContainerServices` Azure provider in both subscriptions.
- If your AKS cluster is configured with an Active Directory service principal, AKS doesn't support using a system-assigned managed identity with custom private DNS zone. The cluster must use [user-assigned managed identity authentication](./use-managed-identity.md).

## Create a private AKS cluster with a private DNS zone

1. Create a private AKS cluster with a private DNS zone using the [`az aks create`][az-aks-create] command.

    **Key parameters in this command**:

    - `--enable-private-cluster`: Enables private cluster mode.
    - `--private-dns-zone [system|none]`: Configures the private DNS zone for the cluster. The default value is `system`.
    - `--assign-identity <resource-id>`: The resource ID of a user-assigned managed identity with the [Private DNS Zone Contributor][private-dns-zone-contributor-role] and [Network Contributor][network-contributor-role] roles.

    ```azurecli-interactive
    az aks create \
        --name <private-cluster-name> \
        --resource-group <private-cluster-resource-group> \
        --load-balancer-sku standard \
        --enable-private-cluster \
        --assign-identity <resource-id> \
        --private-dns-zone [system|none] \
        --generate-ssh-keys
    ```

1. [Configure kubectl to connect to the private AKS cluster](#configure-kubectl-to-connect-to-a-private-aks-cluster).

## Create a private AKS cluster with a custom private DNS zone or private DNS subzone

1. Create a private AKS cluster with a custom private DNS zone or subzone using the [`az aks create`][az-aks-create] command.

    **Key parameters in this command**:

    - `--enable-private-cluster`: Enables private cluster mode.
    - `--private-dns-zone <custom-private-dns-zone-resource-id>|<custom-private-dns-subzone-resource-id>`: The resource ID of a precreated private DNS zone or subzone in the following format for Azure global cloud: `privatelink.<region>.azmk8s.io` or `<subzone>.privatelink.<region>.azmk8s.io`.
    - `--assign-identity <resource-id>`: The resource ID of a user-assigned managed identity with the [Private DNS Zone Contributor][private-dns-zone-contributor-role] and [Network Contributor][network-contributor-role] roles.

    ```azurecli-interactive
    # The custom private DNS zone name should be in the following format: "<subzone>.privatelink.<region>.azmk8s.io"

    az aks create \
        --name <private-cluster-name> \
        --resource-group <private-cluster-resource-group> \
        --load-balancer-sku standard \
        --enable-private-cluster \
        --assign-identity <resource-id> \
        --private-dns-zone [<custom-private-dns-zone-resource-id>|<custom-private-dns-subzone-resource-id>] \
        --generate-ssh-keys
    ```

1. [Configure kubectl to connect to the private AKS cluster](#configure-kubectl-to-connect-to-a-private-aks-cluster).

## Create a private AKS cluster with a custom private DNS zone and custom subdomain

1. Create a private AKS cluster with a custom private DNS zone and subdomain using the [`az aks create`][az-aks-create] command.

    **Key parameters in this command**:

    - `--enable-private-cluster`: Enables private cluster mode.
    - `--private-dns-zone <custom-private-dns-zone-resource-id>`: The resource ID of a precreated private DNS zone in the following format for Azure global cloud: `privatelink.<region>.azmk8s.io`.
    - `--fqdn-subdomain <subdomain>`: The subdomain to use for the cluster FQDN within the custom private DNS zone.
    - `--assign-identity <resource-id>`: The resource ID of a user-assigned managed identity with the [Private DNS Zone Contributor][private-dns-zone-contributor-role] and [Network Contributor][network-contributor-role] roles.

    ```azurecli-interactive
    # The custom private DNS zone name should be in one of the following formats: "privatelink.<region>.azmk8s.io" or "<subzone>.privatelink.<region>.azmk8s.io"

    az aks create \
        --name <private-cluster-name> \
        --resource-group <private-cluster-resource-group> \
        --load-balancer-sku standard \
        --enable-private-cluster \
        --assign-identity <resource-id> \
        --private-dns-zone <custom-private-dns-zone-resource-id> \
        --fqdn-subdomain <subdomain> \
        --generate-ssh-keys
    ```

1. [Configure kubectl to connect to the private AKS cluster](#configure-kubectl-to-connect-to-a-private-aks-cluster).

## Update an existing private AKS cluster from a private DNS zone to public

You can only update from `byo` (bring your own) or `system` to `none`. No other combination of update values is supported.

> [!WARNING]
> When you update a private cluster from `byo` or `system` to `none`, the agent nodes change to use a public FQDN. In an AKS cluster that uses Azure Virtual Machine Scale Sets, a [node image upgrade][node-image-upgrade] is performed to update your nodes with the public FQDN.

- Update a private cluster from `byo` or `system` to `none` using the [`az aks update`][az-aks-update] command with the `--private-dns-zone` parameter set to `none`.

    ```azurecli-interactive
    az aks update \
        --name <private-cluster-name> \
        --resource-group <private-cluster-resource-group> \
        --private-dns-zone none
    ```

## Configure kubectl to connect to a private AKS cluster

To manage a Kubernetes cluster, use the Kubernetes command-line client, [kubectl][kubectl]. `kubectl` is already installed if you use Azure Cloud Shell. To install `kubectl` locally, use the [`az aks install-cli`][az-aks-install-cli] command.

1. Configure `kubectl` to connect to your Kubernetes cluster using the [`az aks get-credentials`][az-aks-get-credentials] command. This command downloads credentials and configures the Kubernetes CLI to use them.

    ```azurecli-interactive
    az aks get-credentials --resource-group <private-cluster-resource-group> --name <private-cluster-name>
    ```

1. Verify the connection to your cluster using the [`kubectl get`][kubectl-get] command. This command returns a list of the cluster nodes.

    ```bash
    kubectl get nodes
    ```

    The command returns output similar to the following:

    ```output
    NAME                                STATUS   ROLES   AGE    VERSION
    aks-nodepool1-12345678-vmss000000   Ready    agent   3h6m   v1.15.11
    aks-nodepool1-12345678-vmss000001   Ready    agent   3h6m   v1.15.11
    aks-nodepool1-12345678-vmss000002   Ready    agent   3h6m   v1.15.11
    ```

## Related content

- [Establish network connectivity to a private AKS cluster][private-cluster-connect]

<!-- LINKS - external -->
[rfc1918-document]: https://tools.ietf.org/html/rfc1918
[aks-supported-regions]: https://azure.microsoft.com/global-infrastructure/services/?products=kubernetes-service
[kubectl]: https://kubernetes.io/docs/reference/kubectl/
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get

<!-- LINKS - internal -->
[private-link-service]: /azure/private-link/private-link-service-overview#limitations
[container-registry-private-link]: /azure/container-registry/container-registry-private-link
[virtual-networks-168.63.129.16]: /azure/virtual-network/what-is-ip-address-168-63-129-16
[use-custom-domains]: coredns-custom.md#use-custom-domains
[create-aks-cluster-api-vnet-integration]: api-server-vnet-integration.md
[install-azure-cli]: /cli/azure/install-azure-cli
[private-dns-zone-contributor-role]: /azure/role-based-access-control/built-in-roles#dns-zone-contributor
[network-contributor-role]: /azure/role-based-access-control/built-in-roles#network-contributor
[az-group-create]: /cli/azure/group#az-group-create
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-dns-zone]: /azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration
[api-server-vnet-integration]: ./api-server-vnet-integration.md#enable-or-disable-private-cluster-mode-on-an-existing-cluster-with-api-server-vnet-integration
[node-image-upgrade]: ./node-image-upgrade.md
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[private-cluster-connect]: ./private-cluster-connect.md
