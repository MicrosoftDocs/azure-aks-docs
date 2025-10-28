---
title: Advanced Container Networking Services Overview
description: Discover how Advanced Container Networking Services gives you insight into your Azure Kubernetes Service (AKS) clusters through the Container Network Observability and Container Network Security features.
author: Khushbu-Parekh
ms.author: kparekh
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: overview
ms.date: 05/28/2024
# Customer intent: "As a cloud engineer, I want to implement Advanced Container Networking Services in my AKS clusters, so that I can enhance network observability and security for my containerized applications, ensuring they are secure, compliant, and perform optimally."
---

# What is Advanced Container Networking Services?

Advanced Container Networking Services is a suite of services designed to enhance the networking capabilities of Azure Kubernetes Service (AKS) clusters. The suite addresses challenges in modern containerized applications, such as observability, security, and compliance.

Advanced Container Networking Services focuses on delivering a seamless and integrated experience that helps you maintain robust security postures and gain deep insights into your network traffic and application performance. It helps ensure that your containerized applications aren't only secure, but also that they meet or exceed your performance and reliability goals. Advanced Container Networking Services helps you confidently manage and scale your infrastructure.

## What is included in Advanced Container Networking Services?

Advanced Container Networking Services offers two key features:

- **Container Network Observability:** The inaugural feature of the Advanced Container Networking Services suite, bringing the power of Hubble’s control plane to both Cilium and non-Cilium Linux data planes. These features aim to provide visibility into networking and performance.

- **Container Network Security:** For clusters that use Azure CNI Powered by Cilium, network policies include Fully Qualified Domain Name (FQDN) filtering for tackling the complexities of maintaining configuration.

- **Container Network Performance:** For clusters that use Azure CNI Powered by Cilium, a suite of networking performance features such as eBPF Host Routing can be enabled to reduce latency and increase throughput.

## Container Network Observability

Container Network Observability in AKS is a comprehensive feature set within Advanced Container Networking Services, designed to provide deep insights into network traffic and performance across containerized environments. It works seamlessly across both Cilium and non-Cilium data planes, offering flexibility for diverse networking needs. The feature uses eBPF to enhance scalability and performance by identifying potential bottlenecks and network congestion before applications are affected.

Key benefits include compatibility with all Container Networking Interface (CNI) variants in Azure, detailed visibility into node-level metrics, and Hubble metrics for Domain Name System (DNS) resolution, pod-to-pod communication, and service interactions. Container network logs capture essential metadata such as IPs, ports, and traffic flow for troubleshooting, monitoring, and security enforcement.

It also integrates with the managed service for Prometheus in Azure Monitor and Azure Managed Grafana for simplified metrics storage and visualization. Whether you use managed services or your own infrastructure, this observability solution helps ensure a highly performant, secure, and compliant network environment for AKS workloads.

:::image type="content" source="./media/advanced-container-networking-services/advanced-network-observability.png" alt-text="Diagram of the Container Network Observability architecture." lightbox="./media/advanced-container-networking-services/advanced-network-observability.png":::

### Container network metrics

This feature collects node-level metrics, including CPU, memory, and network performance, to monitor the health of cluster nodes. For deeper insights, Hubble metrics provide data on DNS resolution times, service-to-service communication, and pod-level network behavior. These metrics help you analyze application performance, detect anomalies, and optimize workloads.

For more information, see the [metrics overview](container-network-observability-metrics.md).

### Container network logs

Container network logs give you detailed insight into traffic within and across clusters by capturing metadata like source and destination IP addresses, ports, protocols, and flow direction. These logs enable monitoring network behavior, troubleshooting connectivity issues, and enforcing security policies. Persistent and real-time logging options ensure comprehensive, actionable network observability.

To learn more, see the [container network logs overview](container-network-observability-logs.md).

## Container Network Security

Securing your containerized applications is essential in today's dynamic cloud environments. Advanced Container Networking Services provides features to strengthen your cluster's network security.

### FQDN-based filtering

Enhance egress control with Azure CNI Powered by Cilium DNS-based policies. Simplify configuration by using FQDNs instead of by managing dynamic IP addresses.

To learn more, see the [FQDN-based filtering overview](./container-network-security-fqdn-filtering-concepts.md).

### Layer 7 policy

Gain granular control over application-level traffic. Implement policies based on protocols like HTTP, gRPC and kafka, securing your applications with deep visibility and fine-grained access control. To learn more, see the [Layer 7 policy overview](./container-network-security-l7-policy-concepts.md) documentation.

## Container Network Performance

Configuration profile utilizing Cilium with eBPF features to optimize throughput, reduce latency, and minimize CPU overhead for containerized workloads in AKS clusters.

### eBPF Host Routing

To learn more, see the [eBPF Host Routing overview](./container-network-performance-ebpf-host-routing.md)

## Pricing

> [!IMPORTANT]
> Advanced Container Networking Services is a paid offering.

For information about pricing, see [Advanced Container Networking Services - Pricing](https://azure.microsoft.com/pricing/details/azure-container-networking-services/).

## Set up Advanced Container Networking Services on your cluster

### Prerequisites

- An Azure account with an active subscription. If you don't have one, create a [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn) before you begin.

[!INCLUDE [azure-CLI-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

- The minimum version of Azure CLI required for the steps in this article is 2.71.0. To find your version, run `az --version`. To install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).

### Install the aks-preview Azure CLI extension

Install or update the Azure CLI preview extension by using the [`az extension add`](/cli/azure/extension#az_extension_add) or [`az extension update`](/cli/azure/extension#az_extension_update) command.

The minimum version of the `aks-preview` Azure CLI extension is `14.0.0b6`.

```azurecli
# Install the aks-preview extension
az extension add --name aks-preview
# Update the extension to make sure you have the latest version installed
az extension update --name aks-preview
```

### Register the AdvancedNetworkingL7PolicyPreview feature flag

> [!NOTE]
> Container Network Security features only supported on Azure CNI powered by Cilium-based clusters.
>

Register the `AdvancedNetworkingL7PolicyPreview` feature flag by using the [`az feature register`](/cli/azure/feature#az_feature_register) command:

```azurecli
az feature register --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingL7PolicyPreview"
```

Verify successful registration by using the [`az feature show`](/cli/azure/feature#az_feature_show) command. Registration takes a few minutes to complete.

```azurecli
az feature show --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingL7PolicyPreview"
```

### Create a resource group

A resource group is a logical container in which Azure resources are deployed and managed. Create a resource group by using the [`az group create`](/cli/azure/group#az_group_create) command:

```azurecli
# Set environment variables for the resource group name and location. Make sure to replace the placeholders with your own values.
export RESOURCE_GROUP="<resource-group-name>"
export LOCATION="<azure-region>"
# Create a resource group
az group create --name $RESOURCE_GROUP --location $LOCATION
```

### Enable and disable Advanced Container Networking Services in an AKS cluster

#### Create an AKS cluster that has Advanced Container Networking Services

The `az aks create` command with the `--enable-acns` Advanced Container Networking Services flag creates a new AKS cluster that has all Advanced Container Networking Services features, including [Container Network Observability](./advanced-container-networking-services-overview.md#container-network-observability) and [Container Network Security](./advanced-container-networking-services-overview.md#container-network-security).

##### [Cilium](#tab/cilium)

> [!NOTE]
> Clusters that have the Cilium data plane support Container Network Observability and Container Network security in Kubernetes version 1.29 and later.
>
> When the `--acns-advanced-networkpolicies` parameter is set to `L7`, both L7 and FQDN filtering policies are enabled. If you want to enable only FQDN filtering, set the parameter to `FQDN`.
>
> To disable both features, complete the steps described in [Disable Container Network Security](./advanced-container-networking-services-overview.md?tabs=cilium#disable-container-network-security).

```azurecli
# Set an environment variable for the AKS cluster name. Make sure you replace the placeholder with your own value.
export CLUSTER_NAME="<aks-cluster-name>"

# Create an AKS cluster
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --network-dataplane cilium \
    --kubernetes-version 1.29 \
    --enable-acns \
    --acns-advanced-networkpolicies <L7/FQDN>
```

##### [Non-Cilium](#tab/non-cilium)

> [!NOTE]
> The [Container Network Security](./advanced-container-networking-services-overview.md#container-network-security) feature isn't available for non-Cilium clusters.

```azurecli
# Set an environment variable for the AKS cluster name. Make sure you replace the placeholder with your own value.
export CLUSTER_NAME="<aks-cluster-name>"

# Create an AKS cluster
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --enable-acns
```

---

### Enable Advanced Container Networking Services on an existing cluster

The [`az aks update`](/cli/azure/aks#az_aks_update) command with the `--enable-acns` flag updates an existing AKS cluster with all Advanced Container Networking Services features, including [Container Network Observability](./advanced-container-networking-services-overview.md#container-network-observability) and [Container Network Security](./advanced-container-networking-services-overview.md#container-network-security).

##### [Cilium](#tab/cilium)

> [!NOTE]
> Clusters that have the Cilium data plane support Container Network Observability and Container Network Security in Kubernetes version 1.29 and later.
>
> When the `--acns-advanced-networkpolicies` parameter is set to `L7`, both Layer 7 and FQDN filtering policies are enabled. If you want to enable only FQDN filtering, set the parameter to `FQDN`.
>
> To disable both features, complete the steps described in [Disable Container Network Security](./advanced-container-networking-services-overview.md?tabs=cilium#disable-container-network-security).

```azurecli
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns \
    --acns-advanced-networkpolicies <L7/FQDN>
```

##### [Non-Cilium](#tab/non-cilium)

> [!NOTE]
> Only clusters that have the Cilium data plane offer the Container Network Security feature of Advanced Container Networking Services.

```azurecli
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns
```

---

### Disable Advanced Container Networking Services

The `--disable-acns` flag disables all Advanced Container Networking Services features on an existing AKS cluster. Container Network Observability and Container Network Security are also disabled.

```azurecli
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --disable-acns
```

---

### Disable Advanced Container Networking Services features

#### Disable Container Network Observability

##### [Cilium](#tab/cilium)

To disable the Container Network Observability feature without affecting other Advanced Container Networking Services features, run:

```azurecli
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns \
    --disable-acns-observability 
```

##### [Non-Cilium](#tab/non-cilium)

Because Container Network Observability is the only feature available for non-Cilium clusters, you can use `--disable-acns` to disable the feature:

```azurecli
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --disable-acns 
```

---

#### Disable Container Network Security

To disable the Container Network Security feature without affecting other Advanced Container Networking Services features, run:

```azurecli
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns \
    --disable-acns-security
```

---

## Related content

- [What is Container Network Observability?](./advanced-container-networking-services-overview.md#container-network-observability)

- [What  is Container Network Security?](container-network-security-concepts.md)
