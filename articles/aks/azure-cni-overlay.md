---
title: Configure Azure CNI Overlay Networking in Azure Kubernetes Service (AKS)
description: Learn how to configure Azure CNI Overlay networking in Azure Kubernetes Service (AKS), including setup, dual-stack networking, and example workload deployment.
author: davidsmatlak
ms.author: davidsmatlak
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.custom: references_regions, devx-track-azurecli
ms.date: 08/16/2024
# Customer intent: "As a Kubernetes administrator, I want to understand how to configure Azure CNI Overlay networking in AKS so that I can efficiently manage IP address allocation and scale my containerized applications without running into address exhaustion issues."
---

# Configure Azure CNI Overlay networking in Azure Kubernetes Service (AKS)

In this article, you learn how to configure Azure CNI Overlay networking in Azure Kubernetes Service (AKS). It covers the setup process, dual-stack networking configuration, and an example workload deployment. For an overview of Azure CNI Overlay networking, see [Azure Container Networking Interface (CNI) Overlay networking in Azure Kubernetes Service (AKS) overview](./concepts-network-azure-cni-overlay.md).

> [!IMPORTANT]
> Starting on **30 November 2025**, AKS will no longer support or provide security updates for Azure Linux 2.0. Starting on **31 March 2026**, node images will be removed, and you'll be unable to scale your node pools. Migrate to a supported Azure Linux version by [**upgrading your node pools**](/azure/aks/upgrade-aks-cluster) to a supported Kubernetes version or migrating to [`osSku AzureLinux3`](/azure/aks/upgrade-os-version). For more information, see [[Retirement] Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).

## Prerequisites

- An Azure subscription. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/) before you begin.
- Azure CLI version 2.48.0 or later. To install or upgrade Azure CLI, see [Install Azure CLI](/cli/azure/install-azure-cli).
- For dual-stack networking, you need Kubernetes version 1.26.3 or later.

## Create an AKS cluster with Azure CNI Overlay

- Create a cluster with Azure CNI Overlay using the [`az aks create`][az-aks-create] command with the `--network-plugin-mode` set to `overlay`. If you don't specify a pod CIDR, AKS assigns a default space of `viz. 10.244.0.0/16`.

    ```azurecli-interactive
    # Set environment variables>
    CLUSTER_NAME=<your-aks-cluster-name>
    RESOURCE_GROUP=<your-resource-group>
    LOCATION=<your-region>
    
    # Create an AKS cluster with Azure CNI Overlay
    az aks create \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION \
        --network-plugin azure \
        --network-plugin-mode overlay \
        --pod-cidr 192.168.0.0/16 \
        --generate-ssh-keys
    ```

### Add a new node pool to a dedicated subnet

After you created a cluster with Azure CNI Overlay, you can create another node pool and assign the nodes to a new subnet of the same VNet. This approach is useful if you want to control the ingress or egress IPs of the host to/from targets in the same virtual network (VNet) or peered VNets.

- Add a new node pool to the cluster using the [`az aks nodepool add`](/cli/azure/aks#az_aks_nodepool_add) command and specify the subnet resource ID with the `--vnet-subnet-id` parameter. For example:

    ```azurecli-interactive
    # Set environment variables
    CLUSTER_NAME=<your-aks-cluster-name>
    RESOURCE_GROUP=<your-resource-group>
    LOCATION=<your-region>
    NODE_POOL_NAME=<your-nodepool-name>
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    VNET_NAME=<your-vnet-name>
    SUBNET_NAME=<your-subnet-name>
    SUBNET_RESOURCE_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$SUBNET_NAME"
    
    # Add a new node pool to the cluster in the specified subnet
    az aks nodepool add \
      --resource-group $RESOURCE_GROUP \
      --cluster-name $CLUSTER_NAME \
      --name $NODE_POOL_NAME \
      --node-count 1 \
      --mode system \
      --vnet-subnet-id $SUBNET_RESOURCE_ID
    ```

## Create an AKS cluster with Azure CNI Overlay and dual-stack networking

You can deploy your AKS clusters in a dual-stack mode when using Overlay networking and a dual-stack Azure virtual network (VNet). In this configuration, nodes receive both an IPv4 and IPv6 address from the Azure VNet subnet. Pods receive an IPv4 and IPv6 address from a different address space to the Azure VNet subnet of the nodes. Network address translation (NAT) is then configured so that the pods can reach resources on the Azure VNet. The source IP address of the traffic is NAT'd to the node's primary IP address of the same family (_IPv4 to IPv4_ and _IPv6 to IPv6_).

> [!NOTE]
> You can also deploy dual-stack networking clusters with Azure CNI Powered by Cilium. For more information, see [Azure CNI Powered by Cilium dual-stack networking](./azure-cni-powered-by-cilium.md#dual-stack-networking-with-azure-cni-powered-by-cilium).

### Dual-stack networking limitations

The following features aren't supported with dual-stack networking:

- [Azure network policies](./use-network-policies.md)
- [Calico network policies](./use-network-policies.md)
- [NAT Gateway](./nat-gateway.md)
- The [virtual nodes add-on](./virtual-nodes.md)

### Dual-stack networking parameters

The following parameters support dual-stack clusters:

- **`--ip-families`**: Takes a comma-separated list of IP families to enable on the cluster.
  - Only `ipv4` or `ipv4,ipv6` are supported.
- **`--pod-cidrs`**: Takes a comma-separated list of CIDR notation IP ranges to assign pod IPs from.
  - The count and order of ranges in this list must match the value provided to `--ip-families`.
  - If no values are supplied, the default value `10.244.0.0/16,fd12:3456:789a::/64` is used.
- **`--service-cidrs`**: Takes a comma-separated list of CIDR notation IP ranges to assign service IPs from.
  - The count and order of ranges in this list must match the value provided to `--ip-families`.
  - If no values are supplied, the default value `10.0.0.0/16,fd12:3456:789a:1::/108` is used.
  - The IPv6 subnet assigned to `--service-cidrs` can be no larger than a /108.

### [Create a dual-stack AKS cluster with Azure CNI Overlay with Linux node pools](#tab/dual-stack-linux)

1. Create an Azure resource group for the cluster using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    # Set environment variables
    RESOURCE_GROUP=<your-resource-group>
    REGION=<your-region>
    
    # Create a resource group
    az group create --location $REGION --name $RESOURCE_GROUP
    ```

1. Create a dual-stack AKS cluster using the [`az aks create`][az-aks-create] command with the `--ip-families` parameter set to `ipv4,ipv6`.

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

### [Create a dual-stack AKS cluster with Azure CNI Overlay with Windows node pools (preview)](#tab/dual-stack-windows)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

#### Install the `aks-preview` Azure CLI extension

1. Install the `aks-preview` extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension released using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

#### Register the `AzureOverlayDualStackPreview` feature flag

1. Register the `AzureOverlayDualStackPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AzureOverlayDualStackPreview"
    ```

    It takes a few minutes for the status to show _Registered_.

1. Verify the registration status using the [`az feature show`][az-feature-show] command:

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "AzureOverlayDualStackPreview"
    ```

1. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

#### Create a dual-stack AKS cluster with Azure CNI Overlay

- Create a cluster with Azure CNI Overlay using the [`az aks create`][az-aks-create] command.

    ```azurecli-interactive
    # Set environment variables
    CLUSTER_NAME=<your-aks-cluster-name>
    RESOURCE_GROUP=<your-resource-group>
    LOCATION=<your-region>

    # Create an AKS cluster with Azure CNI Overlay and dual-stack networking
    az aks create \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION \
        --network-plugin azure \
        --network-plugin-mode overlay \
        --ip-families ipv4,ipv6 \
        --generate-ssh-keys
    ```

#### Add a Windows node pool to the cluster

- Add a Windows node pool to the cluster using the [`az aks nodepool add`][az-aks-nodepool-add] command.

    ```azurecli-interactive
    # Set environment variable
    WINDOWS_NODE_POOL_NAME=<your-windows-node-pool-name>

    # Add a Windows node pool to the cluster
    az aks nodepool add \
        --resource-group $RESOURCE_GROUP \
        --cluster-name $CLUSTER_NAME \
        --os-type Windows \
        --name $WINDOWS_NODE_POOL_NAME \
        --node-count 2
    ```

---

## Deploy an example workload to the AKS Overlay cluster

Once the cluster is created, you can deploy your workloads. The following sections walk you through an example workload deployment of an NGINX web server exposed via an IPv4 and IPv6 `LoadBalancer` type service.

### Deploy an NGINX web server

We recommend using the application routing add-on for ingress in AKS clusters. However, for demonstration purposes, this example deploys an NGINX web server without the application routing add-on. For more information about the add-on, see [Managed NGINX ingress with the application routing add-on](app-routing.md).

### Expose the workload using a `LoadBalancer` Service

You can expose the NGINX deployment using either `kubectl` commands or YAML manifests.

> [!IMPORTANT]
> There are currently **two limitations** pertaining to IPv6 services in AKS:
>
> - Azure Load Balancer sends health probes to IPv6 destinations from a link-local address. In Azure Linux node pools, you can't route this traffic to a pod, so traffic flowing to IPv6 services deployed with `externalTrafficPolicy: Cluster` fail.
> - You must deploy IPv6 services with `externalTrafficPolicy: Local`, which causes `kube-proxy` to respond to the probe on the node.

#### [kubectl deployment](#tab/kubectl)

1. Expose the NGINX deployment using the `kubectl expose deployment nginx` command.

    ```bash-interactive
    kubectl expose deployment nginx --name=nginx-ipv4 --port=80 --type=LoadBalancer'
    kubectl expose deployment nginx --name=nginx-ipv6 --port=80 --type=LoadBalancer --overrides='{"spec":{"ipFamilies": ["IPv6"]}}'
    ```

    Your output should show the exposed services. For example:

    ```output
    service/nginx-ipv4 exposed
    service/nginx-ipv6 exposed
    ```

1. Once the deployment is exposed and the `LoadBalancer` services are fully provisioned, get the IP addresses of the services using the `kubectl get services` command.

    ```bash-interactive
    kubectl get services
    ```

    Your output should show the services with their assigned IP addresses. For example:

    ```output
    NAME         TYPE           CLUSTER-IP               EXTERNAL-IP         PORT(S)        AGE
    nginx-ipv4   LoadBalancer   10.0.88.78               20.46.24.24         80:30652/TCP   97s
    nginx-ipv6   LoadBalancer   fd12:3456:789a:1::981a   2603:1030:8:5::2d   80:32002/TCP   63s
    ```

1. Get the service IP using the `kubectl get services` command and set it to an environment variable.

    ```bash-interactive
    SERVICE_IP=$(kubectl get services nginx-ipv6 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    ```

1. Verify functionality using a `curl` request from an IPv6 capable host (**Azure Cloud Shell isn't IPv6 capable**).

    ```bash-interactive
    curl -s "http://[${SERVICE_IP}]" | head -n5
    ```

    Your output should show the NGINX welcome page HTML. For example:

    ```html
    <!DOCTYPE html>
    <html>
    <head>
    <title>Welcome to nginx!</title>
    <style>
    ```

#### [YAML deployment](#tab/yaml)

1. Expose the NGINX deployment using the following YAML manifest:

    ```YAML
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

1. Once the deployment is exposed and the `LoadBalancer` services are fully provisioned, get the IP addresses of the services using the `kubectl get services` command.

    ```bash-interactive
    kubectl get services
    ```

    Your output should show the services with their assigned IP addresses. For example:

    ```output
    NAME         TYPE           CLUSTER-IP               EXTERNAL-IP         PORT(S)        AGE
    nginx-ipv4   LoadBalancer   10.0.88.78               20.46.24.24         80:30652/TCP   97s
    nginx-ipv6   LoadBalancer   fd12:3456:789a:1::981a   2603:1030:8:5::2d   80:32002/TCP   63s
    ```

---

## Related content

- To learn how to upgrade existing clusters to Azure CNI Overlay, see [Upgrade Azure CNI IPAM modes and data plane technology](./upgrade-azure-cni.md).
- To learn how to expand your pod CIDR space in Azure CNI Overlay clusters, see [Expand pod CIDR space in Azure CNI Overlay clusters](./azure-cni-overlay-pod-cidr.md).
- To learn how to use AKS with your own Container Network Interface (CNI) plugin, see [Bring your own Container Network Interface (CNI) plugin](./use-byo-cni.md).

<!-- LINKS - internal -->
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-group-create]: /cli/azure/group#az-group-create
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
