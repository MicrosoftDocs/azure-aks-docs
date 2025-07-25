---
title: Configure Azure CNI Overlay networking in Azure Kubernetes Service (AKS)
description: Learn how to configure Azure CNI Overlay networking in Azure Kubernetes Service (AKS), including deploying an AKS cluster into an existing virtual network and subnets.
author: asudbring
ms.author: allensu
ms.subservice: aks-networking
ms.topic: how-to
ms.custom: references_regions, devx-track-azurecli
ms.date: 08/16/2024
# Customer intent: "As a Kubernetes administrator, I want to understand how to configure Azure CNI Overlay networking in AKS so that I can efficiently manage IP address allocation and scale my containerized applications without running into address exhaustion issues."
---

# Configure Azure CNI Overlay networking in Azure Kubernetes Service (AKS)

The traditional [Azure Container Networking Interface (CNI)](./configure-azure-cni.md) assigns a VNet IP address to every pod. It assigns this IP address from a pre-reserved set of IPs on every node *or* a separate subnet reserved for pods. This approach requires IP address planning and could lead to address exhaustion, which introduces difficulties scaling your clusters as your application demands grow.

With Azure CNI Overlay, the cluster nodes are deployed into an Azure Virtual Network (VNet) subnet. Pods are assigned IP addresses from a private CIDR logically different from the VNet hosting the nodes. Pod and node traffic within the cluster use an Overlay network. Network Address Translation (NAT) uses the node's IP address to reach resources outside the cluster. This solution saves a significant amount of VNet IP addresses and enables you to scale your cluster to large sizes. An extra advantage is that you can reuse the private CIDR in different AKS clusters, which extends the IP space available for containerized applications in Azure Kubernetes Service (AKS).

## Overview of Overlay networking

In Overlay networking, only the Kubernetes cluster nodes are assigned IPs from subnets. Pods receive IPs from a private CIDR provided at the time of cluster creation. Each node is assigned a `/24` address space carved out from the same CIDR. Extra nodes created when you scale out a cluster automatically receive `/24` address spaces from the same CIDR. Azure CNI assigns IPs to pods from this `/24` space.

A separate routing domain is created in the Azure Networking stack for the pod's private CIDR space, which creates an Overlay network for direct communication between pods. There's no need to provision custom routes on the cluster subnet or use an encapsulation method to tunnel traffic between pods, which provides connectivity performance between pods on par with VMs in a VNet. Workloads running within the pods are not even aware that network address manipulation is happening.

:::image type="content" source="media/azure-cni-Overlay/azure-cni-overlay.png" alt-text="A diagram showing two nodes with three pods each running in an Overlay network. Pod traffic to endpoints outside the cluster is routed via NAT.":::

Communication with endpoints outside the cluster, such as on-premises and peered VNets, happens using the node IP through NAT. Azure CNI translates the source IP (Overlay IP of the pod) of the traffic to the primary IP address of the VM, which enables the Azure Networking stack to route the traffic to the destination. Endpoints outside the cluster can't connect to a pod directly. You have to publish the pod's application as a Kubernetes Load Balancer service to make it reachable on the VNet.

You can provide outbound (egress) connectivity to the internet for Overlay pods using a [Standard SKU Load Balancer](./egress-outboundtype.md#outbound-type-of-loadbalancer) or [Managed NAT Gateway](./nat-gateway.md). You can also control egress traffic by directing it to a firewall using [User Defined Routes on the cluster subnet](./egress-outboundtype.md#outbound-type-of-userdefinedrouting).

You can configure ingress connectivity to the cluster using an ingress controller, such as Application Gateway for Containers, NGINX, or Application Routing Add-on.

## Differences between Kubenet and Azure CNI Overlay

Like Azure CNI Overlay, Kubenet assigns IP addresses to pods from an address space logically different from the VNet, but it has scaling and other limitations. The below table provides a detailed comparison between Kubenet and Azure CNI Overlay. If you don't want to assign VNet IP addresses to pods due to IP shortage, we recommend using Azure CNI Overlay.

| Area                         | Azure CNI Overlay                                            | Kubenet                                                                       |
|------------------------------|--------------------------------------------------------------|-------------------------------------------------------------------------------|
| Cluster scale                | 5000 nodes and 250 pods/node                                 | 400 nodes and 250 pods/node                                                   |
| Network configuration        | Simple - no extra configurations required for pod networking | Complex - requires route tables and UDRs on cluster subnet for pod networking |
| Pod connectivity performance | Performance on par with VMs in a VNet                        | Extra hop adds latency                                                  |
| Kubernetes Network Policies  | Azure Network Policies, Calico, Cilium                       | Calico                                                                        |
| OS platforms supported       | Linux and Windows Server 2022, 2019                          | Linux only                                                                    |

## IP address planning

- **Cluster Nodes**: When setting up your AKS cluster, make sure your VNet subnets have enough room to grow for future scaling. You can assign each node pool to a dedicated subnet. A `/24`subnet can fit up to 251 nodes since the first three IP addresses are reserved for management tasks.
- **Pods**: The Overlay solution assigns a `/24` address space for pods on every node from the private CIDR that you specify during cluster creation. The `/24` size is fixed and can't be increased or decreased. You can run up to 250 pods on a node. When planning the pod address space, ensure the private CIDR is large enough to provide `/24` address spaces for new nodes to support future cluster expansion.
  - When planning IP address space for pods, consider the following factors:
    - The same pod CIDR space can be used on multiple independent AKS clusters in the same VNet.
    - Pod CIDR space must not overlap with the cluster subnet range.
    - Pod CIDR space must not overlap with directly connected networks (like VNet peering, ExpressRoute, or VPN). If external traffic has source IPs in the podCIDR range, it needs translation to a non-overlapping IP via SNAT to communicate with the cluster.
- **Kubernetes service address range**: The size of the service address CIDR depends on the number of cluster services you plan to create. It must be smaller than `/12`. This range shouldn't overlap with the pod CIDR range, cluster subnet range, and IP range used in peered VNets and on-premises networks.
- **Kubernetes DNS service IP address**: This IP address is within the Kubernetes service address range that's used by cluster service discovery. Don't use the first IP address in your address range, as this address is used for the `kubernetes.default.svc.cluster.local` address.

> [!IMPORTANT]
> The private CIDR ranges available for the Pod CIDR are defined in [RFC 1918](https://tools.ietf.org/html/rfc1918). While we don't block the use of public IP ranges, they are considered out of Microsoft's support scope. We recommend using private IP ranges for pod CIDR.

## Network security groups

Pod to pod traffic with Azure CNI Overlay isn't encapsulated, and subnet [network security group][nsg] rules are applied. If the subnet NSG contains deny rules that would impact the pod CIDR traffic, make sure the following rules are in place to ensure proper cluster functionality (in addition to all [AKS egress requirements][aks-egress]):

- Traffic from the node CIDR to the node CIDR on all ports and protocols
- Traffic from the node CIDR to the pod CIDR on all ports and protocols (required for service traffic routing)
- Traffic from the pod CIDR to the pod CIDR on all ports and protocols (required for pod to pod and pod to service traffic, including DNS)

Traffic from a pod to any destination outside of the pod CIDR block utilizes SNAT to set the source IP to the IP of the node where the pod runs.

If you wish to restrict traffic between workloads in the cluster, we recommend using [network policies][aks-network-policies].

## Maximum pods per node

You can configure the maximum number of pods per node at the time of cluster creation or when you add a new node pool. The default for Azure CNI Overlay is 250. The maximum value you can specify in Azure CNI Overlay is 250, and the minimum value is 10. The maximum pods per node value configured during creation of a node pool applies to the nodes in that node pool only.

## Choosing a network model to use

Azure CNI offers two IP addressing options for pods: The traditional configuration that assigns VNet IPs to pods and Overlay networking. The choice of which option to use for your AKS cluster is a balance between flexibility and advanced configuration needs. The following considerations help outline when each network model might be the most appropriate.

**Use Overlay networking when**:

- You would like to scale to a large number of pods, but have limited IP address space in your VNet.
- Most of the pod communication is within the cluster.
- You don't need advanced AKS features, such as virtual nodes.

**Use the traditional VNet option when**:

- You have available IP address space.
- Most of the pod communication is to resources outside of the cluster.
- Resources outside the cluster need to reach pods directly.
- You need AKS advanced features, such as virtual nodes.

## Limitations with Azure CNI Overlay

Azure CNI Overlay has the following limitations:

- Virtual Machine Availability Sets (VMAS) aren't supported for Overlay.
- You can't use [DCsv2-series](/azure/virtual-machines/dcv2-series) virtual machines in node pools. To meet Confidential Computing requirements, consider using [DCasv5 or DCadsv5-series confidential VMs](/azure/virtual-machines/dcasv5-dcadsv5-series) instead.
- In case you are using your own subnet to deploy the cluster, the names of the subnet, VNET and resource group which contains the VNET, must be 63 characters or less. This comes from the fact that these names will be used as labels in AKS worker nodes, and are therefore subjected to [Kubernetes label syntax rules](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set).  

## Set up Overlay clusters

> [!NOTE]
> You must have CLI version 2.48.0 or later to use the `--network-plugin-mode` argument. For Windows, you must have the latest aks-preview Azure CLI extension installed and can follow the instructions below.

Create a cluster with Azure CNI Overlay using the [`az aks create`][az-aks-create] command. Make sure to use the argument `--network-plugin-mode` to specify an overlay cluster. If the pod CIDR isn't specified, then AKS assigns a default space: `viz. 10.244.0.0/16`.

```azurecli-interactive
clusterName="myOverlayCluster"
resourceGroup="myResourceGroup"
location="westcentralus"

az aks create \
    --name $clusterName \
    --resource-group $resourceGroup \
    --location $location \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --pod-cidr 192.168.0.0/16 \
    --generate-ssh-keys
```

## Add a new nodepool to a dedicated subnet

After you have created a cluster with Azure CNI Overlay, you can create another nodepool and assign the nodes to a new subnet of the same VNet.
This approach can be useful if you want to control the ingress or egress IPs of the host from/ towards targets in the same VNET or peered VNets.

```azurecli-interactive
clusterName="myOverlayCluster"
resourceGroup="myResourceGroup"
location="westcentralus"
nodepoolName="newpool1"
subscriptionId=$(az account show --query id -o tsv)
vnetName="yourVnetName"
subnetName="yourNewSubnetName"
subnetResourceId="/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Network/virtualNetworks/$vnetName/subnets/$subnetName"
az aks nodepool add --resource-group $resourceGroup --cluster-name $clusterName \
  --name $nodepoolName --node-count 1 \
  --mode system --vnet-subnet-id $subnetResourceId
```


## Dual-stack Networking

You can deploy your AKS clusters in a dual-stack mode when using Overlay networking and a dual-stack Azure virtual network. In this configuration, nodes receive both an IPv4 and IPv6 address from the Azure virtual network subnet. Pods receive both an IPv4 and IPv6 address from a logically different address space to the Azure virtual network subnet of the nodes. Network address translation (NAT) is then configured so that the pods can reach resources on the Azure virtual network. The source IP address of the traffic is NAT'd to the node's primary IP address of the same family (IPv4 to IPv4 and IPv6 to IPv6).

### Prerequisites

  - You must have Azure CLI 2.48.0 or later installed.
  - Kubernetes version 1.26.3 or greater.

### Limitations

The following features aren't supported with dual-stack networking:
  - Azure network policies
  - Calico network policies
  - NAT Gateway
  - Virtual nodes add-on

## Deploy a dual-stack AKS cluster

The following attributes are provided to support dual-stack clusters:

* **`--ip-families`**: Takes a comma-separated list of IP families to enable on the cluster.
  * Only `ipv4` or `ipv4,ipv6` are supported.
* **`--pod-cidrs`**: Takes a comma-separated list of CIDR notation IP ranges to assign pod IPs from.
  * The count and order of ranges in this list must match the value provided to `--ip-families`.
  * If no values are supplied, the default value `10.244.0.0/16,fd12:3456:789a::/64` is used.
* **`--service-cidrs`**: Takes a comma-separated list of CIDR notation IP ranges to assign service IPs from.
  * The count and order of ranges in this list must match the value provided to `--ip-families`.
  * If no values are supplied, the default value `10.0.0.0/16,fd12:3456:789a:1::/108` is used.
  * The IPv6 subnet assigned to `--service-cidrs` can be no larger than a /108.

### Create a dual-stack AKS cluster

1. Create an Azure resource group for the cluster using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --location <region> --name <resourceGroupName>
    ```

2. Create a dual-stack AKS cluster using the [`az aks create`][az-aks-create] command with the `--ip-families` parameter set to `ipv4,ipv6`.

    ```azurecli-interactive
    az aks create \
        --location <region> \
        --resource-group <resourceGroupName> \
        --name <clusterName> \
        --network-plugin azure \
        --network-plugin-mode overlay \
        --ip-families ipv4,ipv6 \
        --generate-ssh-keys
    ```

## Create an example workload

Once the cluster has been created, you can deploy your workloads. This article walks you through an example workload deployment of an NGINX web server.

### Deploy an NGINX web server

The application routing addon is the recommended way for ingress in an AKS cluster. For more information about the application routing addon and an example of how to deploy an application with the addon, see [Managed NGINX ingress with the application routing add-on](app-routing.md).

## Expose the workload via a `LoadBalancer` type service

> [!IMPORTANT]
> There are currently **two limitations** pertaining to IPv6 services in AKS.
>
> - Azure Load Balancer sends health probes to IPv6 destinations from a link-local address. In Azure Linux node pools, this traffic can't be routed to a pod, so traffic flowing to IPv6 services deployed with `externalTrafficPolicy: Cluster` fail. IPv6 services must be deployed with `externalTrafficPolicy: Local`, which causes `kube-proxy` to respond to the probe on the node.
> - Prior to Kubernetes version 1.27, only the first IP address for a service will be provisioned to the load balancer, so a dual-stack service only receives a public IP for its first-listed IP family. To provide a dual-stack service for a single deployment, please create two services targeting the same selector, one for IPv4 and one for IPv6. This is no longer a limitation in kubernetes 1.27 or later.

# [kubectl](#tab/kubectl)

1. Expose the NGINX deployment using the `kubectl expose deployment nginx` command.

    ```bash-interactive
    kubectl expose deployment nginx --name=nginx-ipv4 --port=80 --type=LoadBalancer'
    kubectl expose deployment nginx --name=nginx-ipv6 --port=80 --type=LoadBalancer --overrides='{"spec":{"ipFamilies": ["IPv6"]}}'
    ```

    You receive an output that shows the services have been exposed.

    ```output
    service/nginx-ipv4 exposed
    service/nginx-ipv6 exposed
    ```

2. Once the deployment is exposed and the `LoadBalancer` services are fully provisioned, get the IP addresses of the services using the `kubectl get services` command.

    ```bash-interactive
    kubectl get services
    ```

    ```output
    NAME         TYPE           CLUSTER-IP               EXTERNAL-IP         PORT(S)        AGE
    nginx-ipv4   LoadBalancer   10.0.88.78               20.46.24.24         80:30652/TCP   97s
    nginx-ipv6   LoadBalancer   fd12:3456:789a:1::981a   2603:1030:8:5::2d   80:32002/TCP   63s
    ```

3. Verify functionality via a command-line web request from an IPv6 capable host. Azure Cloud Shell isn't IPv6 capable.

    ```bash-interactive
    SERVICE_IP=$(kubectl get services nginx-ipv6 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    curl -s "http://[${SERVICE_IP}]" | head -n5
    ```

    ```html
    <!DOCTYPE html>
    <html>
    <head>
    <title>Welcome to nginx!</title>
    <style>
    ```

# [YAML](#tab/yaml)

1. Expose the NGINX deployment using the following YAML manifest.

    ```yml
    ---
    apiVersion: v1
    kind: Service
    metadata:
      labels:
        app: nginx
      name: nginx-ipv4
    spec:
      externalTrafficPolicy: Cluster
      ports:
     - port: 80
        protocol: TCP
        targetPort: 80
      selector:
        app: nginx
      type: LoadBalancer
    ---
    apiVersion: v1
    kind: Service
    metadata:
      labels:
        app: nginx
      name: nginx-ipv6
    spec:
      externalTrafficPolicy: Cluster
      ipFamilies:
     - IPv6
      ports:
     - port: 80
        protocol: TCP
        targetPort: 80
      selector:
        app: nginx
      type: LoadBalancer
    ```

2. Once the deployment is exposed and the `LoadBalancer` services are fully provisioned, get the IP addresses of the services using the `kubectl get services` command.

    ```bash-interactive
    kubectl get services
    ```

    ```output
    NAME         TYPE           CLUSTER-IP               EXTERNAL-IP         PORT(S)        AGE
    nginx-ipv4   LoadBalancer   10.0.88.78               20.46.24.24         80:30652/TCP   97s
    nginx-ipv6   LoadBalancer   fd12:3456:789a:1::981a   2603:1030:8:5::2d   80:32002/TCP   63s
    ```

---

## Dual-stack networking with Azure CNI Powered by Cilium

You can deploy your dual-stack AKS clusters with Azure CNI Powered by Cilium. This also allows you to control your IPv6 traffic with the Cilium Network Policy engine.

### Prerequisites

* You must have Kubernetes version 1.29 or greater. 

### Set up Overlay clusters with Azure CNI Powered by Cilium

Create a cluster with Azure CNI Overlay using the [`az aks create`][az-aks-create] command. Make sure to use the argument `--network-dataplane cilium` to specify the Cilium dataplane.

```azurecli-interactive
clusterName="myOverlayCluster"
resourceGroup="myResourceGroup"
location="westcentralus"

az aks create \
    --name $clusterName \
    --resource-group $resourceGroup \
    --location $location \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --network-dataplane cilium \
    --ip-families ipv4,ipv6 \
    --generate-ssh-keys
```

For more information on Azure CNI Powered by Cilium, see [Azure CNI Powered by Cilium][azure-cni-powered-by-cilium].

## Dual-stack networking Windows nodepools - (Preview)

You can deploy your dual-stack AKS clusters with Windows nodepools.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

### Install the aks-preview Azure CLI extension

* Install the aks-preview extension using the [`az extension add`][az-extension-add] command.

    ```azurecli
    az extension add --name aks-preview
    ```

* Update to the latest version of the extension released using the [`az extension update`][az-extension-update] command.

    ```azurecli
    az extension update --name aks-preview
    ```

### Register the 'AzureOverlayDualStackPreview' feature flag

1. Register the `AzureOverlayDualStackPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AzureOverlayDualStackPreview"
    ```

    It takes a few minutes for the status to show *Registered*.

2. Verify the registration status using the [`az feature show`][az-feature-show] command:

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "AzureOverlayDualStackPreview"
    ```

3. When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

### Set up an Overlay cluster

Create a cluster with Azure CNI Overlay using the [`az aks create`][az-aks-create] command.

```azurecli-interactive
clusterName="myOverlayCluster"
resourceGroup="myResourceGroup"
location="westcentralus"

az aks create \
    --name $clusterName \
    --resource-group $resourceGroup \
    --location $location \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --ip-families ipv4,ipv6 \
    --generate-ssh-keys
```

### Add a Windows nodepool to the cluster

Add a Windows nodepool to the cluster using the [`az aks nodepool add`][az-aks-nodepool-add] command.

```azurecli-interactive
az aks nodepool add \
    --resource-group $resourceGroup \
    --cluster-name $clusterName \
    --os-type Windows \
    --name winpool1 \
    --node-count 2
```

## Next steps

To learn how to upgrade existing clusters to Azure CNI overlay, see [Upgrade Azure CNI IPAM modes and Dataplane Technology](upgrade-azure-cni.md).

To learn how to utilize AKS with your own Container Network Interface (CNI) plugin, see [Bring your own Container Network Interface (CNI) plugin](use-byo-cni.md).

<!-- LINKS - internal -->
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[aks-egress]: limit-egress-traffic.md
[aks-network-policies]: use-network-policies.md
[nsg]: /azure/virtual-network/network-security-groups-overview
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[azure-cni-powered-by-cilium]: azure-cni-powered-by-cilium.md
