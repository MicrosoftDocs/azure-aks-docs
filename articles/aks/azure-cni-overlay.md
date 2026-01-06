---
title: Configure Azure CNI Overlay Networking in Azure Kubernetes Service (AKS)
description: Learn how to configure Azure CNI Overlay networking in Azure Kubernetes Service (AKS), including setup, dual-stack networking, and example workload deployment.
author: davidsmatlak
ms.author: davidsmatlak
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.custom: references_regions, devx-track-azurecli
ms.date: 12/16/2025
zone_pivot_groups: azure-cni-overlay-create-cluster

# Customer intent: "As a Kubernetes administrator, I want to understand how to configure Azure CNI Overlay networking in AKS so that I can efficiently manage IP address allocation and scale my containerized applications without running into address exhaustion issues."
---

# Configure Azure CNI Overlay networking in Azure Kubernetes Service (AKS)

This article explains the setup process, dual-stack networking configuration, and an example workload deployment for Azure CNI Overlay in Azure Kubernetes Service (AKS) clusters. For an overview of Azure CNI Overlay networking, see [Overview of Azure CNI Overlay networking in Azure Kubernetes Service (AKS)](./concepts-network-azure-cni-overlay.md).

[!INCLUDE [azure linux 2.0 retirement](./includes/azure-linux-retirement.md)]

## Prerequisites

- An Azure subscription. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/) before you begin.
- Azure CLI version 2.48.0 or later. To install or upgrade the Azure CLI, see [Install the Azure CLI](/cli/azure/install-azure-cli).
- An existing Azure resource group. If you need to create one, see [Create resource groups](/azure/azure-resource-manager/management/manage-resource-groups-cli#create-resource-groups).

:::zone pivot="aks-cni-overlay-cluster-dual-stack"

For dual-stack networking, you need Kubernetes version 1.26.3 or later.

:::zone-end

:::zone pivot="aks-cni-overlay-cluster"

## Key parameters for Azure CNI Overlay in AKS clusters

The following table describes the key parameters for configuring Azure CNI Overlay networking in AKS clusters:

| Parameter | Description |
| --------- | ----------- |
| `--network-plugin` | Set to `azure` to use Azure Container Networking Interface (CNI) networking. |
| `--network-plugin-mode` | Set to `overlay` to enable Azure CNI Overlay networking. This setting applies only when `--network-plugin=azure`. |
| `--pod-cidr` | Specify a custom pod Classless Inter-Domain Routing (CIDR) block for the cluster. The default is `10.244.0.0/16`. |

The default behavior for network plugins depends on whether you explicitly set `--network-plugin`:

- If you don't specify `--network-plugin`, AKS defaults to Azure CNI Overlay.
- If you specify `--network-plugin=azure` and omit `--network-plugin-mode`, AKS intentionally uses virtual network (node subnet) mode for backward compatibility.

## Create an Azure CNI Overlay AKS cluster

Create an Azure CNI Overlay AKS cluster by using the [`az aks create`][az-aks-create] command with `--network-plugin=azure` and `--network-plugin-mode=overlay`. If you don't specify a value for `--pod-cidr`, AKS assigns the default value of `10.244.0.0/16`.

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

Add a node pool to a different subnet within the same virtual network to control virtual machine (VM) node IP addresses for network traffic to virtual network or peered virtual network resources.

Add a new node pool to the cluster by using the [`az aks nodepool add`](/cli/azure/aks#az_aks_nodepool_add) command and specify the subnet resource ID with the `--vnet-subnet-id` parameter. For example:

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

You can deploy your Azure CNI Overlay AKS clusters in a dual-stack mode with an Azure virtual network. In this configuration, nodes receive both an IPv4 and IPv6 address from the Azure virtual network subnet. Pods receive an IPv4 and IPv6 address from a different address space to the Azure virtual network subnet of the nodes. Network address translation (NAT) is then configured so that the pods can reach resources on the Azure virtual network. The source IP address of the traffic is NAT'd to the node's primary IP address of the same family (*IPv4 to IPv4* and *IPv6 to IPv6*).

> [!NOTE]
> You can also deploy dual-stack networking clusters by using Azure CNI Powered by Cilium. For more information, see [Dual-stack networking with Azure CNI Powered by Cilium](./azure-cni-powered-by-cilium.md#dual-stack-networking-with-azure-cni-powered-by-cilium).

## Dual-stack networking limitations

The following features aren't supported with dual-stack networking:

- [Azure network policies](./use-network-policies.md)
- [Calico network policies](./use-network-policies.md)
- [NAT gateway](./nat-gateway.md)
- [Virtual nodes add-on](./virtual-nodes.md)

## Key parameters for dual-stack networking

The following table describes the key parameters for configuring dual-stack networking in Azure CNI Overlay AKS clusters:

| Parameter | Description |
| --------- | ----------- |
| `--ip-families` | Takes a comma-separated list of IP families to enable on the cluster. Only `ipv4` and `ipv4,ipv6` are supported. |
| `--pod-cidrs` | Takes a comma-separated list of Classless Inter-Domain Routing (CIDR) notation IP ranges to assign pod IPs from. The count and order of ranges in this list must match the value provided to `--ip-families`. If you don't supply any values, the parameter uses the default value of `10.244.0.0/16,fd12:3456:789a::/64`. |
| `--service-cidrs` | Takes a comma-separated list of CIDR notation IP ranges to assign service IPs from. The count and order of ranges in this list must match the value provided to `--ip-families`. If you don't supply any values, the parameter uses the default value of `10.0.0.0/16,fd12:3456:789a:1::/108`. The IPv6 subnet assigned to `--service-cidrs` can be no larger than `/108`. |

## Create an Azure CNI Overlay AKS cluster with dual-stack networking (Linux)

1. Create an Azure resource group for the cluster by using the [`az group create`][az-group-create] command:

    ```azurecli-interactive
    az group create --location $REGION --name $RESOURCE_GROUP
    ```

1. Create a dual-stack AKS cluster by using the [`az aks create`][az-aks-create] command with the `--ip-families` parameter set to `ipv4,ipv6`:

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

1. Install the `aks-preview` extension by using the [`az extension add`][az-extension-add] command:

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension by using the [`az extension update`][az-extension-update] command:

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the `AzureOverlayDualStackPreview` feature flag

1. Register the `AzureOverlayDualStackPreview` feature flag by using the [`az feature register`][az-feature-register] command:

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "AzureOverlayDualStackPreview"
    ```

    It takes a few minutes for the status to show `Registered`.

1. Verify the registration status by using the [`az feature show`][az-feature-show] command:

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "AzureOverlayDualStackPreview"
    ```

1. When the status reflects `Registered`, refresh the registration of the `Microsoft.ContainerService` resource provider by using the [`az provider register`][az-provider-register] command:

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

### Create a dual-stack Azure CNI Overlay AKS cluster and add a Windows node pool

1. Create a cluster with Azure CNI Overlay by using the [`az aks create`][az-aks-create] command:

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

1. Add a Windows node pool to the cluster by using the [`az aks nodepool add`](/cli/azure/aks#az_aks_nodepool_add) command:

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

Deploy dual-stack AKS CNI Overlay clusters with IPv4/IPv6 addresses on virtual machine nodes. This example deploys an NGINX web server and exposes it by using a `LoadBalancer` service with both IPv4 and IPv6 addresses.

> [!NOTE]
> We recommend using the application routing add-on for ingress in AKS clusters. However, for demonstration purposes, this example deploys an NGINX web server without the application routing add-on. For more information about the add-on, see [Managed NGINX ingress with the application routing add-on](app-routing.md).

### Expose the workload by using a `LoadBalancer` service

Expose the NGINX deployment by using either `kubectl` commands or YAML manifests.

> [!IMPORTANT]
> There are currently *two limitations* that pertain to IPv6 services in AKS:
>
> - Azure Load Balancer sends health probes to IPv6 destinations from a link-local address. In *Azure Linux node pools*, you can't route this traffic to a pod, so traffic flowing to IPv6 services deployed with `externalTrafficPolicy: Cluster` fails.
> - You must deploy IPv6 services with `externalTrafficPolicy: Local`, which causes `kube-proxy` to respond to the probe on the node.

#### [kubectl deployment](#tab/kubectl)

1. Expose the NGINX deployment by using the `kubectl expose deployment nginx` command:

    ```bash-interactive
    kubectl expose deployment nginx --name=nginx-ipv4 --port=80 --type=LoadBalancer
    kubectl expose deployment nginx --name=nginx-ipv6 --port=80 --type=LoadBalancer --overrides='{"spec":{"ipFamilies": ["IPv6"]}}'
    ```

    Your output should show the exposed services. For example:

    ```output
    service/nginx-ipv4 exposed
    service/nginx-ipv6 exposed
    ```

1. After the deployment is exposed and the `LoadBalancer` services are fully provisioned, get the IP addresses of the services by using the `kubectl get services` command:

    ```bash-interactive
    kubectl get services
    ```

    Your output should show the services with their assigned IP addresses. For example:

    ```output
    NAME         TYPE           CLUSTER-IP               EXTERNAL-IP         PORT(S)        AGE
    nginx-ipv4   LoadBalancer   10.0.88.78               20.46.24.24         80:30652/TCP   97s
    nginx-ipv6   LoadBalancer   fd12:3456:789a:1::981a   2603:1030:8:5::2d   80:32002/TCP   63s
    ```

1. Get the service IP by using the `kubectl get services` command and set it to an environment variable:

    ```bash-interactive
    SERVICE_IP=$(kubectl get services nginx-ipv6 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    ```

1. Verify functionality by using a `curl` request from an IPv6-capable host. (*Azure Cloud Shell isn't IPv6 capable*.)

    ```bash-interactive
    curl -s "http://[${SERVICE_IP}]" | head -n5
    ```

    Your output should show the HTML for the NGINX welcome page. For example:

    ```html
    <!DOCTYPE html>
    <html>
    <head>
    <title>Welcome to nginx!</title>
    <style>
    ```

#### [YAML deployment](#tab/yaml)

1. Expose the NGINX deployment by using a YAML manifest. The following example creates two `LoadBalancer` services: one for IPv4 and one for IPv6. The IPv6 service is deployed with `externalTrafficPolicy: Local`, which causes `kube-proxy` to respond to the probe on the node.

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

1. After the deployment is exposed and the `LoadBalancer` services are fully provisioned, get the IP addresses of the services by using the `kubectl get services` command:

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

- [Update Azure CNI IPAM mode and data plane technology](./upgrade-azure-cni.md)
- [Expand pod CIDR space in Azure CNI Overlay clusters](./azure-cni-overlay-pod-expand.md)

<!-- LINKS - internal -->
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-group-create]: /cli/azure/group#az-group-create
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
