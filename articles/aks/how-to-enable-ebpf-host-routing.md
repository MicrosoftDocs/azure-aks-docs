---
title: "Enable eBPF Host Routing with Advanced Container Networking Services"
description: Get started with eBPF Host Routing for Advanced Container Networking Services on your AKS cluster.
author: sf-msft
ms.author: samfoo
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 09/23/2025
ms.custom: template-how-to-pattern, devx-track-azurecli
---

# Enable eBPF Host Routing with Advanced Container Networking Services (Preview)

> [!IMPORTANT]
> eBPF Host Routing with Advanced Container Networking Services is currently in PREVIEW.  
> See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability.

This article shows you how to enable eBPF Host Routing with Advanced Container Networking Services (ACNS) on Azure Kubernetes Service (AKS) clusters.

## Requirements and parameters

| Requirement or parameter | Supported versions or values | Description |
| ------------------------ | ---------------------------- | ----------- |
| Feature flag | `AdvancedNetworkingPerformancePreview` | This feature flag must be registered in your subscription to enable eBPF Host Routing in Azure CNI powered by Cilium AKS clusters. |
| Azure CLI version | 2.71.0 or later | The Azure CLI version must be 2.71.0 or later to support eBPF Host Routing. |
| Kubernetes version | 1.33 or later | The Kubernetes version must be 1.33 or later to support eBPF Host Routing. |
| Node operating system | Azure Linux 3.0 or Ubuntu 24.04 | eBPF Host Routing is supported only on Azure CNI powered by Cilium clusters with Azure Linux 3.0 or Ubuntu 24.04. |
| Dataplane | Azure CNI powered by Cilium | eBPF Host Routing is supported only on AKS clusters that use Azure CNI powered by Cilium. |

Review the [Limitations](./container-network-performance-ebpf-host-routing.md#limitations) section for node requirements and compatibility with existing iptable rules.

### Install the `aks-preview` Azure CLI extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Install or update the Azure CLI preview extension using the [`az extension add`](/cli/azure/extension#az-extension-add) or [`az extension update`](/cli/azure/extension#az-extension-update) command.

 The minimum version of the aks-preview Azure CLI extension is `14.0.0b6`

```azurecli-interactive
# Install the aks-preview extension
az extension add --name aks-preview
# Update the extension to make sure you have the latest version installed
az extension update --name aks-preview
```

### Register the `AdvancedNetworkingPerformancePreview` feature flag

Register the `AdvancedNetworkingPerformancePreview` feature flag using the  [`az feature register`](/cli/azure/feature#az-feature-register) command.

```azurecli-interactive 
az feature register --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingPerformancePreview"
```
Verify successful registration using the [`az feature show`](/cli/azure/feature#az-feature-show) command. It takes a few minutes for the registration to complete.

```azurecli-interactive
az feature show --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingPerformancePreview"
```

Once the feature shows `Registered`, refresh the registration of the `Microsoft.ContainerService` resource provider using the [`az provider register`](/cli/azure/provider#az-provider-register) command.

### Enable Advanced Container Networking Services and eBPF Host Routing

To proceed, you must have an AKS cluster with [Advanced Container Networking Services](./advanced-container-networking-services-overview.md) enabled.

The `az aks create` command with the Advanced Container Networking Services flag, `--enable-acns`, creates a new AKS cluster with all Advanced Container Networking Services features. These features encompass:
* **Container Network Observability:**  Provides insights into your network traffic. To learn more visit [Container Network Observability](./advanced-container-networking-services-overview.md#container-network-observability).

* **Container Network Security:** Offers security features like FQDN filtering. To learn more visit  [Container Network Security](./advanced-container-networking-services-overview.md#container-network-security).

* **Container Network Performance:** Improves latency and throughput for pod network traffic. To learn more visit [Container Network Performance](./advanced-container-networking-services-overview.md#container-network-performance)

Create an Azure resource group for the cluster using the [`az group create`](/cli/azure/group#az-group-create) command.

```azurecli-interactive
export LOCATION="<location>"

az group create --location $LOCATION --name <resourcegroup-name>
```

Create a new AKS cluster with eBPF Host Routing by enabling ACNS through `--enable-acns` and setting the acceleration mode with `--acns-datapath-acceleration-mode BpfVeth`.

```azurecli-interactive
# Set environment variables for the AKS cluster name and resource group. Make sure to replace the placeholders with your own values.
export CLUSTER_NAME="<aks-cluster-name>"
export RESOURCE_GROUP="<resourcegroup-name>"
export LOCATION="<location>"
export OS_SKU="<os-sku>" # Use AzureLinux or Ubuntu2404
 
# Create an AKS cluster
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --network-dataplane cilium \
    --kubernetes-version 1.33 \
    --os-sku $OS_SKU \
    --enable-acns \
    --acns-datapath-acceleration-mode BpfVeth \
    --generate-ssh-keys
```

### Enable eBPF Host Routing with Advanced Container Networking Services on an existing cluster

The [`az aks update`](/cli/azure/aks#az-aks-update) command with the Advanced Container Networking Services flag, `--enable-acns`, updates an existing AKS cluster with `--acns-datapath-acceleration-mode BpfVeth` to enable Advanced Container Networking Services features that includes [Container Network Observability](./advanced-container-networking-services-overview.md#container-network-observability), [Container Network Security](./advanced-container-networking-services-overview.md#container-network-security), and [Container Network Performance](./advanced-container-networking-services-overview.md#container-network-performance).

> [!NOTE]
> Enabling eBPF Host Routing on an existing cluster may disrupt existing connections.

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns \
    --acns-datapath-acceleration-mode BpfVeth
```

## Disabling eBPF Host Routing on an existing cluster

eBPF Host Routing can be disabled independently without affecting other ACNS features. To disable it, set the flag `--acns-datapath-acceleration-mode=None`.

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns \
    --acns-datapath-acceleration-mode None
```

## Related content

* Get more information about [Advanced Container Networking Services for AKS](advanced-container-networking-services-overview.md).
* Explore the [Container Network Observability feature](./advanced-container-networking-services-overview.md#container-network-observability) in Advanced Container Networking Services.
