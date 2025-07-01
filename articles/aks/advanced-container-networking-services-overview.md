---
title: Advanced Container Networking Services for the Azure Kubernetes Service (AKS)
description: Discover how  Advanced Container Networking Services empowers your AKS clusters with Container Network Observability and Container Network Security features.
author: Khushbu-Parekh
ms.author: kparekh
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: overview
ms.date: 05/28/2024
---

# What is Advanced Container Networking Services?

Advanced Container Networking Services is a suite of services designed to enhance the networking capabilities of Azure Kubernetes Service (AKS) clusters. The suite addresses challenges in modern containerized applications, such as observability, security, and compliance.

With Advanced Container Networking Services, the focus is on delivering a seamless and integrated experience that enables you to maintain robust security postures and gain deep insights into your network traffic and application performance. This ensures that your containerized applications aren't only secure but also meet or exceed your performance and reliability goals, allowing you to confidently manage and scale your infrastructure.

## What is included in Advanced Container Networking Services?

Advanced Container Networking Services contains features split into two pillars:

 - **Observability**: The inaugural feature of the Advanced Container Networking Services suite bringing the power of Hubble’s control plane to both Cilium and non-Cilium Linux data planes. These features aim to provide visibility into networking and performance.

 - **Security**: For clusters using Azure CNI Powered by Cilium, network policies include fully qualified domain name (FQDN) filtering for tackling the complexities of maintaining configuration.

## Container Network Observability
 
Container network observability in Azure Kubernetes Service (AKS) is a comprehensive feature set within Advanced Container Networking Services, designed to provide deep insights into network traffic and performance across containerized environments. It works seamlessly across both Cilium and non-Cilium data planes, offering flexibility for diverse networking needs. Leveraging eBPF, this feature enhances scalability and performance by identifying potential bottlenecks and network congestion before impacting applications.

Key benefits include compatibility with all Azure CNI variants, detailed visibility into node-level metrics, and Hubble metrics for DNS resolution, pod-to-pod communication, and service interactions. Container Network Logs capture essential metadata such as IPs, ports, and traffic flow, enabling troubleshooting, monitoring, and security enforcement.

Additionally, it integrates with Azure Managed Prometheus and Grafana for simplified metrics storage and visualization. Whether using managed services or user-controlled infrastructure, this observability solution ensures a highly performant, secure, and compliant network environment for AKS workloads.

:::image type="content" source="./media/advanced-container-networking-services/advanced-network-observability.png" alt-text="Diagram of container network observability architecture." lightbox="./media/advanced-container-networking-services/advanced-network-observability.png":::

### Container Network Metrics

This feature collects node-level metrics, including CPU, memory, and network performance, to monitor the health of cluster nodes. For deeper insights, Hubble metrics provide data on DNS resolution times, service-to-service communication, and pod-level network behavior. These metrics enable users to analyze application performance, detect anomalies, and optimize workloads.

To learn more, see [Metrics Overview](container-network-observability-metrics.md) documentation.

### Container Network Logs

Container Network Logs provides detailed insights into traffic within and across clusters by capturing metadata like source/destination IPs, ports, protocols, and flow direction. These logs enable monitoring network behavior, troubleshooting connectivity issues, and enforcing security policies. Persistent and real-time logging options ensure comprehensive, actionable network observability.

To learn more, see [Container Network Logs Overview](container-network-observability-logs.md) documentation.

## Container Network Security

Securing your containerized applications is essential in today's dynamic cloud environments. Advanced Container Networking Services provides features to strengthen your cluster's network security.

### FQDN based filtering 

Enhance egress control with Azure CNI Powered by Cilium's DNS-based policies. Simplify configuration by using domain names (FQDNs) instead of managing dynamic IP addresses.
To learn more, see [FQDN Based Filtering Overview](./container-network-security-fqdn-filtering-concepts.md) documentation.

### Layer 7 (L7) policy (Preview)

Gain granular control over application-level traffic. Implement policies based on protocols like HTTP, gRPC and kafka, securing your applications with deep visibility and fine-grained access control. To learn more, see [L7 Policy Overview](./container-network-security-l7-policy-concepts.md) documentation.

## Pricing
> [!IMPORTANT]
> Advanced Container Networking Services is a paid offering. For more information about pricing, see [Advanced Container Networking Services - Pricing](https://azure.microsoft.com/pricing/details/azure-container-networking-services/).


## Set up Advanced Container Networking Services on your cluster

### Prerequisites

* An Azure account with an active subscription. If you don't have one, create a [free account](https://azure.microsoft.com/free/?WT.mc_id=A261C142F) before you begin.
[!INCLUDE [azure-CLI-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

* The minimum version of Azure CLI required for the steps in this article is 2.71.0. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).

### Install the `aks-preview` Azure CLI extension

Install or update the Azure CLI preview extension using the [`az extension add`](/cli/azure/extension#az_extension_add) or [`az extension update`](/cli/azure/extension#az_extension_update) command.

The minimum version of the aks-preview Azure CLI extension is `14.0.0b6`

```azurecli-interactive
# Install the aks-preview extension
az extension add --name aks-preview
# Update the extension to make sure you have the latest version installed
az extension update --name aks-preview
```

### Register the `AdvancedNetworkingL7PolicyPreview` feature flag

> [!NOTE]
> Container Network Security features only supported on Azure CNI powered by Cilium based clusters.
> 

Register the `AdvancedNetworkingL7PolicyPreview` feature flag using the [`az feature register`](/cli/azure/feature#az_feature_register) command.

```azurecli-interactive 
az feature register --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingL7PolicyPreview"
```
Verify successful registration using the [`az feature show`](/cli/azure/feature#az_feature_show) command. It takes a few minutes for the registration to complete.

```azurecli-interactive
az feature show --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingL7PolicyPreview"
```

### Create a resource group

A resource group is a logical container into which Azure resources are deployed and managed. Create a resource group using the [`az group create`](/cli/azure/group#az_group_create) command.

```azurecli-interactive
# Set environment variables for the resource group name and location. Make sure to replace the placeholders with your own values.
export RESOURCE_GROUP="<resource-group-name>"
export LOCATION="<azure-region>"
# Create a resource group
az group create --name $RESOURCE_GROUP --location $LOCATION
```

### Enable and Disable Advanced Container Networking Services in AKS cluster

#### Create an AKS cluster with Advanced Container Networking Services

The `az aks create` command with the Advanced Container Networking Services flag, `--enable-acns`, creates a new AKS cluster with all Advanced Container Networking Services features. These features encompass:
* **Container Network Observability:**  Provides insights into your network traffic. To learn more visit [Container Network Observability](./advanced-container-networking-services-overview.md#container-network-observability).

* **Container Network Security:** Offers security features like FQDN filtering. To learn more visit  [Container Network Security](./advanced-container-networking-services-overview.md#container-network-security).

##### [**Cilium**](#tab/cilium)

> [!NOTE]
> Clusters with the Cilium data plane support Container Network Observability and Container Network security starting with Kubernetes version 1.29.
>
> When the `--acns-advanced-networkpolicies` parameter is set to "L7", both L7 and FQDN filtering policies are enabled. If you only want to enable FQDN filtering, set the parameter to "FQDN". To disable both features, you can follow the instructions provided in [Disable Container Network Security](./advanced-container-networking-services-overview.md?tabs=cilium#disable-container-network-security).


```azurecli-interactive
# Set an environment variable for the AKS cluster name. Make sure to replace the placeholder with your own value.
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

##### [**Non-Cilium**](#tab/non-cilium)

> [!NOTE]
> [Container Network Security](./advanced-container-networking-services-overview.md#container-network-security) feature isn't available for Non-cilium clusters

```azurecli-interactive
# Set an environment variable for the AKS cluster name. Make sure to replace the placeholder with your own value.
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

The [`az aks update`](/cli/azure/aks#az_aks_update) command with the Advanced Container Networking Services flag, `--enable-acns`, updates an existing AKS cluster with all Advanced Container Networking Services features which includes [Container Network Observability](./advanced-container-networking-services-overview.md#container-network-observability) and the [Container Network Security](./advanced-container-networking-services-overview.md#container-network-security) feature.

##### [**Cilium**](#tab/cilium)

> [!NOTE]
> Clusters with the Cilium data plane support Container Network Observability and Container Network security starting with Kubernetes version 1.29.
>
> When the `--acns-advanced-networkpolicies` parameter is set to "L7", both L7 and FQDN filtering policies are enabled. If you only want to enable FQDN filtering, set the parameter to "FQDN". To disable both features, you can follow the instructions provided in [Disable Container Network Security](./advanced-container-networking-services-overview.md?tabs=cilium#disable-container-network-security).

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns \
    --acns-advanced-networkpolicies <L7/FQDN>
```


##### [**Non-Cilium**](#tab/non-cilium)

> [!NOTE]
> Only clusters with the Cilium data plane support Container Network Security features of Advanced Container Networking Services.

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns
```
---

### Disable Advanced Container Networking Services

The `--disable-acns` flag disables all Advanced Container Networking Services features on an existing AKS cluster which includes Container Network Observability and Container Network Security

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --disable-acns
```

---

### Disable select Advanced Container Networking Services features

#### Disable Container Network Observability 

##### [**Cilium**](#tab/cilium)

To disable Container Network Observability features without affecting other Advanced Container Networking Services features, use `--enable-acns` and `--disable-acns-observability` 

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns \
    --disable-acns-observability 
```

##### [**Non-Cilium**](#tab/non-cilium)

Since only Container Network Observability is the only feature available for non-cilium cluster, you can use --disable-acns  to disable the feature

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --disable-acns 
```

---

### Disable Container Network Security 

To disable Container Network Security features without affecting other Advanced Container Networking Services features, use `--enable-acns`  and  `--disable-acns-security`

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns \
    --disable-acns-security
```
---

## Next steps

* For more information about Container Network Observability and its capabilities, see [What is Container Network Observability?](./advanced-container-networking-services-overview.md#container-network-observability)

* For more information on Container Network Security and its capabilities, see [What  is Container Network Security?](container-network-security-concepts.md)
