---
title: Azure Kubernetes Service (AKS) Free, Standard, and Premium Pricing Tiers
description: Learn about the Free, Standard, and Premium pricing tiers for Azure Kubernetes Service (AKS) cluster management, including when to use each tier and how to create or update clusters using Azure CLI.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 06/07/2024
author: schaffererin
ms.author: schaffererin
ms.custom: references_regions, devx-track-azurecli
# Customer intent: As an Azure user, I want to understand the different pricing tiers for AKS cluster management so that I can choose the right tier for my workloads and budget.
---

# Free, Standard, and Premium pricing tiers for Azure Kubernetes Service (AKS) cluster management

Manage your Azure Kubernetes Service (AKS) clusters using AKS pricing tiers. This article explains the differences between these tiers, when to use each tier, and how to create or update AKS clusters using Azure CLI.

## About AKS pricing tiers

AKS offers three pricing tiers for cluster management: the **Free tier**, the **Standard tier**, and the **Premium tier**.

**SKU and tier relationship**:

- **Base SKU clusters**: Can use any of the three pricing tiers (Free, Standard, or Premium).
- **Automatic SKU clusters**: Must use the Standard tier (automatically selected during cluster creation).

## AKS pricing tiers comparison

The following table compares the Free, Standard, and Premium pricing tiers for AKS cluster management:

| Tier | When to use | Supported cluster types | Pricing | Feature comparison |
| ---- | ----------- | ----------------------- | ------- | ------------------ |
| Free | • Development/testing environments. <br> • Learning and evaluation scenarios. <br> • Non-production workloads. | • Development clusters or small scale testing environments. <br> • Clusters with fewer than 10 nodes. | • Free cluster management. <br> • Pay-as-you-go for resources you consume. | • Recommended for clusters with fewer than 10 nodes, but can support up to 1,000 nodes. <br> • Includes all current AKS features. |
| Standard | • Production workloads requiring 99.9-99.95% API server uptime. <br> • Workloads needing financial service level agreement (SLA) coverage. | • Default tier for Automatic SKU clusters. <br> <br> • Enterprise-grade or production workloads. <br> • Clusters with up to 5,000 nodes. | • Pay-as-you-go for resources you consume. <br> • [Standard tier cluster management pricing details](https://azure.microsoft.com/pricing/details/kubernetes-service/). | • Uptime SLA is enabled by default. <br> • Greater cluster reliability. <br> • Supports up to 5,000 nodes in a cluster. <br> • Includes all current AKS features. |
| Premium | • Production workloads requiring 99.9-99.95% API server uptime. <br> • Workloads requiring 24-month [Long Term Support (LTS)][long-term-support] Kubernetes version support. <br> • Regulated environments requiring extended maintenance. | • Enterprise-grade or production workloads. <br> • Clusters with up to 5,000 nodes. | • Pay-as-you-go for resources you consume. <br> • [Premium tier cluster management pricing details](https://azure.microsoft.com/pricing/details/kubernetes-service/). | • Includes all current AKS features. <br> • [Microsoft maintenance past community support][long-term-support]. |

## Uptime SLA terms and conditions

Standard and Premium tiers include Uptime SLA by default:

- **With availability zones**: 99.95% availability of the Kubernetes API server
- **Without availability zones**: 99.9% availability of the Kubernetes API server
- **Free tier**: Best-effort uptime (no SLA guarantee)

For more information, see the [SLA](https://azure.microsoft.com/support/legal/sla/kubernetes-service/v1_1/).

## Region availability

The following tables outline the availability of AKS pricing tiers by region:

| Region type | Available pricing tiers |
| ----------- | ----------------------- |
| Public regions and Azure Government regions where [AKS is supported](https://azure.microsoft.com/global-infrastructure/services/?products=kubernetes-service) | - Free tier <br> - Standard tier <br> - Premium tier |
| [Private AKS clusters][private-clusters] in all public regions where AKS is supported | - Free tier <br> - Standard tier <br> - Premium tier |

## Prerequisites

- You need [Azure CLI](/cli/azure/install-azure-cli) version 2.47.0 or later. Find the current version using the `az --version` command. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].
- You can create your cluster in an existing resource group or create a new one. To learn more about resource groups and working with them, see [managing resource groups using the Azure CLI][manage-resource-group-cli].

## Create a resource group

- Create a resource group using the [`az group create`][manage-resource-group-cli] command.

    ```azurecli-interactive
    # Set environment variables
    export REGION=<your-region>
    export RESOURCE_GROUP=<your-resource-group-name>

    # Create the resource group
    az group create --name $RESOURCE_GROUP --location $REGION
    ```

    Results:

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

- Create an AKS cluster in the Free tier using the [`az aks create`][az-aks-create] command with the `--tier` parameter set to `free`.

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

    Results:

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

- Create an AKS cluster in the Standard tier using the [`az aks create`][az-aks-create] command with the `--tier` parameter set to `standard`.

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

    Results:

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
> When creating a cluster in the Premium tier, you must also enable the [LTS plan][long-term-support] by setting the `--k8s-support-plan` parameter to `AKSLongTermSupport`. You should enable/disable LTS and the Premium tier together.

- Create an AKS cluster in the Premium tier using the [`az aks create`][az-aks-create] command with the `--tier` parameter set to `premium` and the `--k8s-support-plan` parameter set to `AKSLongTermSupport`.

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

    Results:

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

- Update an existing cluster from the Standard tier to the Free tier using the [`az aks update`][az-aks-create] command with the `--tier` parameter set to `free`.

    ```azurecli-interactive
    # Set environment variables
    export RESOURCE_GROUP=<your-resource-group-name>
    export CLUSTER_NAME=<your-aks-cluster-name>

    # Update the AKS cluster
    az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --tier free
    ```

    <!-- expected_similarity=0.3 -->

    Results:

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

- Update an existing cluster from the Free tier to the Standard tier using the [`az aks update`][az-aks-create] command with the `--tier` parameter set to `standard`.

    ```azurecli-interactive
    # Set environment variables
    export RESOURCE_GROUP=<your-resource-group-name>
    export CLUSTER_NAME=<your-aks-cluster-name>

    # Update the AKS cluster
    az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --tier standard
    ```

    <!-- expected_similarity=0.3 -->

    Results:

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

- Update an existing cluster to the Premium tier using the [`az aks update`][az-aks-create] command with the `--tier` parameter set to `premium` and the `--k8s-support-plan` parameter set to `AKSLongTermSupport`.

    ```azurecli-interactive
    # Set environment variables
    export RESOURCE_GROUP=<your-resource-group-name>
    export CLUSTER_NAME=<your-aks-cluster-name>

    # Update the AKS cluster
    az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --tier premium --k8s-support-plan AKSLongTermSupport
    ```

    <!-- expected_similarity=0.3 -->

    Results:

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

- Update an existing cluster from the Premium tier to the Free or Standard tier using the [`az aks update`][az-aks-create] command with the `--tier` parameter set to `free` or `standard` and the `--k8s-support-plan` parameter set to `KubernetesOfficial`. The following example shows updating to the Free tier.

    ```azurecli-interactive
    # Set environment variables
    export RESOURCE_GROUP=<your-resource-group-name>
    export CLUSTER_NAME=<your-aks-cluster-name>

    # Update the AKS cluster
    az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --tier free --k8s-support-plan KubernetesOfficial
    ```

    Results:

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

## Update an existing cluster from the Base SKU to the Automatic SKU

> [!IMPORTANT]
> Make sure all the [AKS Automatic features](./intro-aks-automatic.md) are enabled on your cluster before updating.

- Update an existing cluster from the Base SKU to the Automatic SKU using the [`az aks update`][az-aks-create] command with the `--sku` parameter set to `Automatic`.

    ```azurecli-interactive
    # Set environment variables
    export RESOURCE_GROUP=<your-resource-group-name>
    export CLUSTER_NAME=<your-aks-cluster-name>

    # Update the AKS cluster
    az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --sku Automatic
    ```

    Results:

    ```output
    {
      ...
      "sku": {
        "name": "Automatic",
        "tier": "Standard"
      },
      ...
    }
    ```

## Update an existing cluster from the Automatic SKU to the Base SKU

- Update an existing cluster from the Automatic SKU to the Base SKU using the [`az aks update`][az-aks-create] command with the `--sku` parameter set to `Base`.

    ```azurecli-interactive
    # Set environment variables
    export RESOURCE_GROUP=<your-resource-group-name>
    export CLUSTER_NAME=<your-aks-cluster-name>

    # Update the AKS cluster
    az aks update --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --sku Base
    ```

    Results:

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

## Related content

- Use [availability zones][availability-zones] to increase high availability with your AKS cluster workloads.
- [Limit egress traffic](limit-egress-traffic.md) on AKS clusters to meet security and compliance requirements.

<!---LINKS--->

[manage-resource-group-cli]: /azure/azure-resource-manager/management/manage-resource-groups-cli
[availability-zones]: ./availability-zones.md
[az-aks-create]: /cli/azure/aks?#az-aks-create
[private-clusters]: private-clusters.md
[long-term-support]: long-term-support.md
[long-term-support-update]: long-term-support.md#enable-lts-on-an-existing-cluster
[install-azure-cli]: /cli/azure/install-azure-cli
