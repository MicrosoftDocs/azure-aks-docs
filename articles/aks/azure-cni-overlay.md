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
zone_pivot_groups: azure-cni-overlay-create-cluster
# Customer intent: "As a Kubernetes administrator, I want to understand how to configure Azure CNI Overlay networking in AKS so that I can efficiently manage IP address allocation and scale my containerized applications without running into address exhaustion issues."
---

# Configure Azure CNI Overlay networking in Azure Kubernetes Service (AKS)

This article covers the setup process, dual-stack networking configuration, and an example workload deployment for Azure CNI Overlay AKS clusters. For an overview of Azure CNI Overlay networking, see [Azure Container Networking Interface (CNI) Overlay networking in Azure Kubernetes Service (AKS) overview](./concepts-network-azure-cni-overlay.md).

> [!IMPORTANT]
> Starting on **30 November 2025**, AKS will no longer support or provide security updates for Azure Linux 2.0. Starting on **31 March 2026**, node images will be removed, and you'll be unable to scale your node pools. Migrate to a supported Azure Linux version by [**upgrading your node pools**](/azure/aks/upgrade-aks-cluster) to a supported Kubernetes version or migrating to [`osSku AzureLinux3`](/azure/aks/upgrade-os-version). For more information, see [[Retirement] Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).

## Prerequisites

- An Azure subscription. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/) before you begin.
- Azure CLI version 2.48.0 or later. To install or upgrade Azure CLI, see [Install Azure CLI](/cli/azure/install-azure-cli).
- An existing Azure resource group. If you need to create one, see [Create Azure resource groups](/azure/azure-resource-manager/management/manage-resource-groups-cli#create-resource-groups).

:::zone pivot="aks-cni-overlay-cluster-dual-stack"

- For dual-stack networking, you need Kubernetes version 1.26.3 or later.

:::zone-end

:::zone pivot="aks-cni-overlay-cluster"

## Key parameters for Azure CNI Overlay AKS clusters

The following table describes the key parameters for configuring Azure CNI Overlay networking in AKS clusters:

| Parameter | Description |
|-----------|-------------|
| `--network-plugin` | Set to `azure` to use Azure CNI networking. |
| `--network-plugin-mode` | Set to `overlay` to enable Azure CNI Overlay networking. |
| `--pod-cidr` | Specify a custom pod CIDR block for the cluster. The default is `10.244.0.0/16`. |

## Create an Azure CNI Overlay AKS cluster

- Create an Azure CNI Overlay AKS cluster using the [`az aks create`][az-aks-create] command with the `--network-plugin-mode` set to `overlay`. If you don't specify a value for `--pod-cidr`, AKS assigns the default value of `10.244.0.0/16`.

    ```azurecli-interactive
    az aks create \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --location $REGION \
        --network-plugin azure \
        --network-plugin-mode overlay \
        --pod-cidr 192.168.0.0/16 \
        --generate-ssh-keys
    ```

## Add a new node pool to a dedicated subnet

Add a node pool to a different subnet within the same VNet to control VM node IP addresses for network traffic to VNet or peered VNet resources.

- Add a new node pool to the cluster using the [`az aks nodepool add`](/cli/azure/aks#az_aks_nodepool_add) command and specify the subnet resource ID with the `--vnet-subnet-id` parameter. For example:

    ```azurecli-interactive
    az aks nodepool add \
      --resource-group $RESOURCE_GROUP \
      --cluster-name $CLUSTER_NAME \
      --name $NODE_POOL_NAME \
      --node-count 1 \
      --mode system \
      --vnet-subnet-id $SUBNET_RESOURCE_ID
    ```

:::zone-end

:::zone pivot="aks-cni-overlay-cluster-dual-stack"

## About Azure CNI Overlay AKS clusters with dual-stack networking

You can deploy your Azure CNI Overlay AKS clusters in a dual-stack mode with an Azure virtual network (VNet). In this configuration, nodes receive both an IPv4 and IPv6 address from the Azure VNet subnet. Pods receive an IPv4 and IPv6 address from a different address space to the Azure VNet subnet of the nodes. Network address translation (NAT) is then configured so that the pods can reach resources on the Azure VNet. The source IP address of the traffic is NAT'd to the node's primary IP address of the same family (_IPv4 to IPv4_ and _IPv6 to IPv6_).

> [!NOTE]
> You can also deploy dual-stack networking clusters with Azure CNI Powered by Cilium. For more information, see [Azure CNI Powered by Cilium dual-stack networking](./azure-cni-powered-by-cilium.md#dual-stack-networking-with-azure-cni-powered-by-cilium).

## Dual-stack networking limitations

The following features aren't supported with dual-stack networking:

- [Azure network policies](./use-network-policies.md)
- [Calico network policies](./use-network-policies.md)
- [NAT Gateway](./nat-gateway.md)
- The [virtual nodes add-on](./virtual-nodes.md)

## Key parameters for dual-stack networking

The following table describes the key parameters for configuring dual-stack networking in Azure CNI Overlay AKS clusters:

| Parameter | Description |
|-----------|-------------|
| `--ip-families` | Takes a comma-separated list of IP families to enable on the cluster. Only `ipv4` or `ipv4,ipv6` are supported. |
| `--pod-cidrs` | Takes a comma-separated list of CIDR notation IP ranges to assign pod IPs from. The count and order of ranges in this list must match the value provided to `--ip-families`. If no values are supplied, the default value of `10.244.0.0/16,fd12:3456:789a::/64` is used. |
| `--service-cidrs` | Takes a comma-separated list of CIDR notation IP ranges to assign service IPs from. The count and order of ranges in this list must match the value provided to `--ip-families`. If no values are supplied, the default value of `10.0.0.0/16,fd12:3456:789a:1::/108` is used. The IPv6 subnet assigned to `--service-cidrs` can be no larger than a /108. |

## Create an Azure CNI Overlay AKS cluster with dual-stack networking (Linux)

1. Create an Azure resource group for the cluster using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --location $REGION --name $RESOURCE_GROUP
    ```

1. Create a dual-stack AKS cluster using the [`az aks create`][az-aks-create] command with the `--ip-families` parameter set to `ipv4,ipv6`.

    ```azurecli-interactive
    az aks create \
        --location $REGION \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --network-plugin azure \
        --network-plugin-mode overlay \
        --ip-families ipv4,ipv6 \
        --generate-ssh-keys
    ```

## Create an Azure CNI Overlay AKS cluster with dual-stack networking (Windows)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Before you create an Azure CNI Overlay AKS cluster with dual-stack networking with Windows node pools, you need to install the `aks-preview` Azure CLI extension and register the `AzureOverlayDualStackPreview` feature flag in your subscription.

### Install the `aks-preview` Azure CLI extension

1. Install the `aks-preview` extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension released using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the `AzureOverlayDualStackPreview` feature flag

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

### Create a dual-stack Azure CNI Overlay AKS cluster and add a Windows node pool

1. Create a cluster with Azure CNI Overlay using the [`az aks create`][az-aks-create] command.

    ```azurecli-interactive
    az aks create \
        --name $CLUSTER_NAME \
        --resource-group $RESOURCE_GROUP \
        --location $REGION \
        --network-plugin azure \
        --network-plugin-mode overlay \
        --ip-families ipv4,ipv6 \
        --generate-ssh-keys
    ```

1. Add a Windows node pool to the cluster using the [`az aks nodepool add`][az-aks-nodepool-add] command.

    ```azurecli-interactive
    az aks nodepool add \
        --resource-group $RESOURCE_GROUP \
        --cluster-name $CLUSTER_NAME \
        --os-type Windows \
        --name $WINDOWS_NODE_POOL_NAME \
        --node-count 2
    ```

---

:::zone-end

## Deploy an example workload to the Azure CNI Overlay AKS cluster

Deploy dual-stack AKS CNI Overlay clusters with IPv4/IPv6 addresses on VM nodes. This example deploys an NGINX web server and exposes it using a `LoadBalancer` Service with both IPv4 and IPv6 addresses.

> [!NOTE]
> We recommend using the application routing add-on for ingress in AKS clusters. However, for demonstration purposes, this example deploys an NGINX web server without the application routing add-on. For more information about the add-on, see [Managed NGINX ingress with the application routing add-on](app-routing.md).

### Expose the workload using a `LoadBalancer` Service

Expose the NGINX deployment using either `kubectl` commands or YAML manifests.

> [!IMPORTANT]
> There are currently **two limitations** pertaining to IPv6 services in AKS:
>
> - Azure Load Balancer sends health probes to IPv6 destinations from a link-local address. In **Azure Linux node pools**, you can't route this traffic to a pod, so traffic flowing to IPv6 services deployed with `externalTrafficPolicy: Cluster` fail.
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

1. Expose the NGINX deployment using a YAML manifest. The following example creates two `LoadBalancer` services: one for IPv4 and one for IPv6. The IPv6 service is deployed with `externalTrafficPolicy: Local`, which causes `kube-proxy` to respond to the probe on the node.

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
      externalTrafficPolicy: Local # Deploying the IPv6 service with `externalTrafficPolicy: Local`, which causes `kube-proxy` to respond to the probe on the node
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

To learn more about Azure CNI Overlay networking on AKS, see the following articles:

<<<<<<< HEAD
- [Upgrade Azure CNI IPAM modes and data plane technology](./upgrade-azure-cni.md)
- [Expand pod CIDR space in Azure CNI Overlay clusters](./azure-cni-overlay-pod-cidr.md)
=======
### Prerequisites

* You must have Kubernetes version 1.29 or greater.

### Set up Overlay clusters with Azure CNI Powered by Cilium

Create a cluster with Azure CNI Overlay using the [`az aks create`][az-aks-create] command. Make sure to use the argument `--network-dataplane cilium` to specify the Cilium data plane.

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

## Dual-stack networking Windows node pools - (Preview)

You can deploy your dual-stack AKS clusters with Windows node pools.

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

### Add a Windows node pool to the cluster

Add a Windows node pool to the cluster using the [`az aks nodepool add`][az-aks-nodepool-add] command.

```azurecli-interactive
az aks nodepool add \
    --resource-group $resourceGroup \
    --cluster-name $clusterName \
    --os-type Windows \
    --name winpool1 \
    --node-count 2
```

## Pod CIDR Expansion - (Preview)

You can expand your Pod CIDR space on AKS Overlay clusters with Linux nodes only. The operation uses `az aks update`, and allows expansions without recreating your AKS cluster.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

### Limitations

 - Windows nodes and hybrid node scenarios aren't supported.
 - This feature is currently only supported with Kubernetes version 1.33.
 - Only expansion is allowed without changing the base IP. Shrinking or changing the Pod CIDR returns an error.
 - Adding discontinuous Pod CIDR isn't supported. The new Pod CIDR must be a larger superset that completely contains the original range.
 - IPv6 Pod CIDR expansion isn't supported.
 - Changing multiple Pod CIDR blocks via `--pod-cidrs` isn't supported.
 - If an [Azure Availability Zone](./availability-zones.md) is down during the expansion operation, new nodes may appear as unready. These nodes are expected to reconcile once the Availability Zone is up.

### Register the `EnableAzureCNIOverlayPodCIDRExpansion` feature flag

Register the `EnableAzureCNIOverlayPodCIDRExpansion` feature flag using the  [`az feature register`](/cli/azure/feature#az_feature_register) command.

```azurecli-interactive
az feature register --namespace Microsoft.ContainerService --name EnableAzureCNIOverlayPodCIDRExpansion
```

Verify successful registration using the [`az feature show`](/cli/azure/feature#az_feature_show) command. It takes a few minutes for the registration to complete.

```azurecli-interactive
az feature show --namespace "Microsoft.ContainerService" --name "EnableAzureCNIOverlayPodCIDRExpansion"
```

Once the feature shows `Registered`, refresh the registration of the `Microsoft.ContainerService` resource provider using the [`az provider register`](/cli/azure/provider#az_provider_register) command.

###  Expand Pod CIDR on an Overlay cluster - Preview

Starting from a Pod CIDR block of `10.244.0.0/18`, the `az aks update` operation allows expanding the Pod CIDR space.

```azurecli-interactive
az aks update \
    --name $clusterName \
    --resource-group $resourceGroup \
    --pod-cidr 10.244.0.0/16
```

> [!NOTE]
> Although the update command may successfully complete and show the new Pod CIDR in the network profile, make sure to validate the new cluster state through the `NodeNetworkConfig`.

### Validate new Pod CIDR Block

Verify the state of the upgrade operation by checking the `NodeNetworkConfig` to view the state.

```bash-interactive
kubectl get nnc -A -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.networkContainers[0].subnetAddressSpace}{"\n"}{end}'
```

```output
aks-nodepool1-13347454-vmss000000 10.244.0.0/16
aks-nodepool1-13347454-vmss000001 10.244.0.0/16
aks-nodepool1-13347454-vmss000002 10.244.0.0/16
```

## Next steps

To learn how to upgrade existing clusters to Azure CNI overlay, see [Upgrade Azure CNI IPAM modes and Dataplane Technology](update-azure-cni.md).

To learn how to utilize AKS with your own Container Network Interface (CNI) plugin, see [Bring your own Container Network Interface (CNI) plugin](use-byo-cni.md).
>>>>>>> 15863aba3d30950d64e4ec193756a4f1991c4b33

<!-- LINKS - internal -->
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-group-create]: /cli/azure/group#az-group-create
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
