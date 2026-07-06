---
title: Azure Kubernetes Service (AKS) Free, Standard, and Premium Pricing Tiers
description: Learn about the Free, Standard, and Premium pricing tiers for Azure Kubernetes Service (AKS) cluster management, including when to use each tier and how to create or update clusters using Azure CLI.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 07/06/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.custom: references_regions, devx-track-azurecli, aks-cost
# Customer intent: As an Azure user, I want to understand the different pricing tiers for AKS cluster management so that I can choose the right tier for my workloads and budget.
---

# Cluster management pricing tiers for Azure Kubernetes Service (AKS)

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

Manage your Azure Kubernetes Service (AKS) clusters using AKS pricing tiers. This article explains the differences between these tiers, when to use each tier, and how to create or update AKS clusters using Azure CLI.

## About AKS pricing tiers

AKS offers three pricing tiers for cluster management:

- Free
- Standard
- Premium

SKU and tier relationship:

- Base SKU clusters can use any of the three pricing tiers: Free, Standard, or Premium.
- Automatic SKU clusters are preconfigured to use the Standard tier during cluster creation.

## AKS Automatic production default

For most production workloads, AKS Automatic is the recommended production-ready default experience for AKS.

AKS Automatic clusters are preconfigured with:

- Standard tier cluster management
- Support for up to 5,000 nodes
- Cluster uptime SLA coverage
- Pod readiness SLA coverage, where 99.9% of qualifying pod readiness operations complete within five minutes

For platform-level details, see [What is Azure Kubernetes Service (AKS) Automatic?](./intro-aks-automatic.md)

## AKS pricing tiers comparison

The following table compares Free, Standard, and Premium pricing tiers for AKS cluster management:

| Tier | When to use | Supported cluster types | Pricing | Feature comparison |
| ---- | ----------- | ----------------------- | ------- | ------------------ |
| Free | Development and test environments, learning, evaluation, and non-production workloads. | Development clusters or small-scale test environments. Recommended for clusters with fewer than 10 nodes. | Free cluster management. Pay as you go for consumed resources. | Includes all current AKS features. Supports up to 1,000 nodes. No financially backed uptime SLA. |
| Standard | Production workloads requiring uptime SLA coverage. Enterprise workloads. Default and preconfigured tier for Automatic SKU clusters. | Enterprise-grade or production workloads with up to 5,000 nodes. | Pay as you go for consumed resources. See [Standard tier pricing details](https://azure.microsoft.com/pricing/details/kubernetes-service/). | Uptime SLA enabled by default. Higher reliability profile. Includes all current AKS features. Supports up to 5,000 nodes. |
| Premium | Production workloads requiring uptime SLA plus 24-month [Long Term Support (LTS)][long-term-support] Kubernetes version support. Regulated environments requiring extended maintenance windows. | Enterprise-grade or production workloads with up to 5,000 nodes. | Pay as you go for consumed resources. See [Premium tier pricing details](https://azure.microsoft.com/pricing/details/kubernetes-service/). | Includes all current AKS features plus [Microsoft maintenance beyond community support][long-term-support]. |

## Uptime SLA terms and conditions

Standard and Premium tiers include uptime SLA by default:

- **With availability zones**: 99.95% availability of the Kubernetes API server
- **Without availability zones**: 99.9% availability of the Kubernetes API server
- **Free tier**: best-effort uptime (no financially backed SLA)

AKS Automatic clusters are preconfigured with Standard tier and include both cluster uptime SLA and pod readiness SLA coverage.

For more information, see the [AKS SLA](https://azure.microsoft.com/support/legal/sla/kubernetes-service/v1_1/).

## Region availability

The following table outlines AKS pricing tier availability by region:

| Region type | Available pricing tiers |
| ----------- | ----------------------- |
| Public regions and Azure Government regions where [AKS is supported](https://azure.microsoft.com/global-infrastructure/services/?products=kubernetes-service) | Free, Standard, Premium |
| [Private AKS clusters][private-clusters] in all public regions where AKS is supported | Free, Standard, Premium |

## Prerequisites

- Azure CLI version 2.47.0 or later. To check your current version, run az --version. To install or upgrade, see [Install Azure CLI][install-azure-cli].
- An existing resource group, or permission to create one. To learn more, see [Manage resource groups by using Azure CLI][manage-resource-group-cli].

## Create a resource group

Create a resource group using the [`az group create`][manage-resource-group-cli] command.

```azurecli-interactive
# Set environment variables
export REGION=<your-region>
export RESOURCE_GROUP=<your-resource-group-name>

# Create the resource group
az group create --name $RESOURCE_GROUP --location $REGION
```

Example output:

```output
{
  "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/"<your-resource-group-name>",
  "location": "<your-region>",
  "managedBy": null,
  "name": "<your-resource-group-name>",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null,
  "type": "Microsoft.Resources/resourceGroups"
}
```

## Create an AKS cluster in the Free tier

Create an AKS cluster in the Free tier using the [`az aks create`][az-aks-create] command with the `--tier` parameter set to `free`.

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<your-resource-group-name>
export CLUSTER_NAME=<your-aks-cluster-name>

# Create the AKS cluster
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --tier free \
    --generate-ssh-keys
```

Example output:

```output
{
  ...
  "sku": {
    "name": "Base",
    "tier": "Free"
  },
  ...
}
```

## Create an AKS cluster in the Standard tier

Create an AKS cluster in the Standard tier using the [`az aks create`][az-aks-create] command with the `--tier` parameter set to `standard`.

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<your-resource-group-name>
export CLUSTER_NAME=<your-aks-cluster-name>

# Create the AKS cluster
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --tier standard \
    --generate-ssh-keys
```

Example output:

```output
{
  ...
  "sku": {
    "name": "Base",
    "tier": "Standard"
  },
  ...
}
```

## Create an AKS cluster in the Premium tier

> [!IMPORTANT]
> When you create a cluster in the Premium tier, you must also enable the [LTS plan][long-term-support] by setting the `--k8s-support-plan` parameter to `AKSLongTermSupport`. Enable or disable LTS and the Premium tier together.

Create an AKS cluster in the Premium tier using the [`az aks create`][az-aks-create] command with the `--tier` parameter set to `premium` and the `--k8s-support-plan` parameter set to `AKSLongTermSupport`.

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<your-resource-group-name>
export CLUSTER_NAME=<your-aks-cluster-name>

# Create the AKS cluster
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --tier premium \
    --k8s-support-plan AKSLongTermSupport \
    --generate-ssh-keys
```

Example output:

```output
{
  ...
  "sku": {
    "name": "Base",
    "tier": "Premium"
  },
  "supportPlan": "AKSLongTermSupport",
  ...
}
```

## Update an existing cluster from the Standard tier to the Free tier

Update an existing cluster from the Standard tier to the Free tier using the [`az aks update`][az-aks-create] command with the `--tier` parameter set to `free`.

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<your-resource-group-name>
export CLUSTER_NAME=<your-aks-cluster-name>

# Update the AKS cluster
az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --tier free
```

<!-- expected_similarity=0.3 -->

Example output:

```output
{
  ...
  "sku": {
    "name": "Base",
    "tier": "Free"
  },
  ...
}
```

## Update an existing cluster from the Free tier to the Standard tier

Update an existing cluster from the Free tier to the Standard tier using the [`az aks update`][az-aks-create] command with the `--tier` parameter set to `standard`.

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<your-resource-group-name>
export CLUSTER_NAME=<your-aks-cluster-name>

# Update the AKS cluster
az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --tier standard
```

<!-- expected_similarity=0.3 -->

Example output:

```output
{
  ...
  "sku": {
    "name": "Base",
    "tier": "Standard"
  },
  ...
}
```

## Update an existing cluster to or from the Premium tier

> [!IMPORTANT]
> [Updating existing clusters to or from the Premium tier][long-term-support-update] requires changing the support plan.

### Update an existing cluster to the Premium tier

Update an existing cluster to the Premium tier using the [`az aks update`][az-aks-create] command with the `--tier` parameter set to `premium` and the `--k8s-support-plan` parameter set to `AKSLongTermSupport`.

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<your-resource-group-name>
export CLUSTER_NAME=<your-aks-cluster-name>

# Update the AKS cluster
az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --tier premium --k8s-support-plan AKSLongTermSupport
```

<!-- expected_similarity=0.3 -->

Example output:

```output
{
  ...
  "sku": {
    "name": "Base",
    "tier": "Premium"
  },
  "supportPlan": "AKSLongTermSupport",
  ...
}
```

### Update an existing cluster from the Premium tier to the Free or Standard tier

To update an existing cluster from the Premium tier to the Free or Standard tier, use the [`az aks update`][az-aks-create] command. Set the `--tier` parameter to `free` or `standard` and the `--k8s-support-plan` parameter to `KubernetesOfficial`. The following example shows how to update to the Free tier.

```azurecli-interactive
# Set environment variables
export RESOURCE_GROUP=<your-resource-group-name>
export CLUSTER_NAME=<your-aks-cluster-name>

# Update the AKS cluster
az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --tier free --k8s-support-plan KubernetesOfficial
```

Example output:

```output
{
  ...
  "sku": {
    "name": "Base",
    "tier": "Free"
  },
  "supportPlan": "KubernetesOfficial",
  ...
}
```

## Related content

- [What is Azure Kubernetes Service (AKS) Automatic?](intro-aks-automatic.md)
- [Create an AKS Automatic cluster](./automatic/quick-automatic-managed-network.md)
- [Configure availability zones in AKS][availability-zones]
- [Limit Network Traffic with Azure Firewall in AKS](limit-egress-traffic.md)

<!---LINKS--->

[manage-resource-group-cli]: /azure/azure-resource-manager/management/manage-resource-groups-cli
[availability-zones]: ./reliability-availability-zones-configure.md
[az-aks-create]: /cli/azure/aks?#az-aks-create
[private-clusters]: private-clusters.md
[long-term-support]: long-term-support.md
[long-term-support-update]: long-term-support.md#enable-lts-on-an-existing-cluster
[install-azure-cli]: /cli/azure/install-azure-cli
