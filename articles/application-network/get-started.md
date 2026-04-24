---
title: Get Started with Azure Kubernetes Application Network for AKS (Preview)
description: Learn how to get started with Azure Kubernetes Application Network for AKS, including prerequisites, creating an Application Network resource, connecting an AKS cluster as a member, and managing resources.
author: kochhars
ms.author: kochhars
ms.service: azure-kubernetes-app-net
ms.topic: get-started
ms.date: 11/04/2025
---

# Get started with Azure Kubernetes Application Network for AKS (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

This article helps you get started with Azure Kubernetes Application Network for AKS. It provides step-by-step instructions to create an Application Network resource and connect an AKS cluster to it as a member cluster.

## Prerequisites

- An Azure subscription. If you don't have one, create a [free account](https://azure.microsoft.com/free/).
- Azure CLI version 2.84.0 or later. Check your version using the `az --version` command. To install or update, see [Install Azure CLI](/cli/azure/install-azure-cli).
- If using an existing AKS cluster, make sure [AKS-managed Microsoft Entra integration](/azure/aks/entra-id-control-plane-authentication) and [OIDC issuer](/azure/aks/use-oidc-issuer) are enabled. These features are required for Azure Kubernetes Application Network connectivity and security.
- Verify support for your existing Kubernetes cluster using the [support policy](./supported-versions.md).

## Set environment variables

- Set the following environment variables for your Azure Kubernetes Application Network resource and cluster. You can use an existing cluster or create one in a later step **before** adding it to your Azure Kubernetes Application Network.

    ```bash
    export SUBSCRIPTION=<subscription-id>
    export LOCATION=<location>
    export APPNET_RG=<resource-group-for-appnet-resource>
    export APPNET_NAME=<appnet-name>
    export APPNET_MEMBER_NAME=<appnet-member-name>
    export AKS_RG=<aks-cluster-resource-group>
    export CLUSTER_NAME=<cluster-name>
    ```

## Register the feature for public preview

1. Register the feature for Azure Kubernetes Application Network using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace Microsoft.AppLink --name PublicPreview --subscription $SUBSCRIPTION
    ```

1. Wait for the feature to be registered. You can check the status using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show --namespace Microsoft.AppLink --name PublicPreview --subscription $SUBSCRIPTION
    ```

    The `properties.state` field in the output will show `Registered` when the registration is complete.

1. After the feature is registered, refresh the registration of the Microsoft.AppLink resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.AppLink --subscription $SUBSCRIPTION
    ```

## Install the AppNet CLI extension

- Install the AppNet CLI extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name appnet-preview
    ```

## Set active subscription

- Set the active subscription to the one you want to use for Azure Kubernetes Application Network using the [`az account set`][az-account-set] command.

    ```azurecli-interactive
    az account set --subscription $SUBSCRIPTION 
    ```

## Create an AKS cluster

> [!NOTE]
> Member clusters **don't** need to be in separate resource groups. They can be in the same resource group as the Azure Kubernetes Application Network resource. However, all member clusters must be in the same tenant.

If you don't have an existing AKS cluster to connect to Azure Kubernetes Application Network, you need to create one. Azure Kubernetes Application Network requires AKS clusters with AKS-managed Microsoft Entra integration and OIDC issuer enabled. If you have an existing cluster, you can skip this step.

1. Create a resource group for your AKS cluster using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --name $AKS_RG --location $LOCATION 
    ```

1. Create an AKS cluster with AKS-managed Microsoft Entra integration and OIDC issuer enabled using the [`az aks create`][az-aks-create] command with the `--enable-oidc-issuer` and `--enable-aad` flags.

    ```azurecli-interactive
    az aks create --name $CLUSTER_NAME --resource-group $AKS_RG --enable-oidc-issuer --enable-aad
    ```

## Create an Azure Kubernetes Application Network resource

1. Create a resource group for your Azure Kubernetes Application Network resource using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --name $APPNET_RG --location $LOCATION 
    ```

1. Create an Azure Kubernetes Application Network resource using the [`az appnet create`][az-appnet-create] command.

    ```azurecli-interactive
    az appnet create --resource-group $APPNET_RG --name $APPNET_NAME --location $LOCATION  --identity-type SystemAssigned
    ```

    The creation process might take a few minutes. The `properties.provisioningState` field of the output shows `Succeeded` for a successfully created Azure Kubernetes Application Network.

1. View your Azure Kubernetes Application Network resource using the [`az appnet show`][az-appnet-show] command.

    ```azurecli-interactive
    az appnet show --resource-group $APPNET_RG --name $APPNET_NAME
    ```

## Join an AKS cluster as a member of Azure Kubernetes Application Network

When you join a member cluster to Azure Kubernetes Application Network, you can specify one of the following upgrade modes for that cluster: **fully-managed** or **self-managed**. The upgrade mode determines how minor version upgrades of Azure Kubernetes Application Network are applied to the member cluster. If you don't specify an upgrade mode during member join, it defaults to `SelfManaged`. For more information about upgrade modes, see [Configure upgrades for Azure Kubernetes Application Network members](./upgrades.md).

- Join an AKS cluster as a member of Azure Kubernetes Application Network using the [`az appnet member join`][az-appnet-member-join] command with the `--upgrade-mode` parameter set to either `FullyManaged` or `SelfManaged`. The following example shows how to join a member cluster in `SelfManaged` mode:

    ```azurecli-interactive
    az appnet member join \
        --resource-group $APPNET_RG \
        --appnet-name $APPNET_NAME \
        --member-name $APPNET_MEMBER_NAME \
        --member-resource-id /subscriptions/$SUBSCRIPTION/resourcegroups/$AKS_RG/providers/Microsoft.ContainerService/managedClusters/$CLUSTER_NAME \
        --upgrade-mode SelfManaged
    ```

## Verify member cluster connectivity

- After joining the cluster, you can verify connectivity and view member details using the [`az appnet member show`][az-appnet-member-show] command.

    ```azurecli-interactive
    az appnet member show --resource-group $APPNET_RG --appnet-name $APPNET_NAME --member-name $APPNET_MEMBER_NAME
    ```

    For example, if enrolled in fully-managed mode with `Stable` release channel, the output would look like:

    ```output
    {
      "id": "/subscriptions/$SUBSCRIPTION/resourceGroups/$APPNET_RG/providers/Microsoft.AppLink/appLinks/$APPNET_NAME/appLinkMembers/$APPNET_MEMBER_NAME",
      "location": "myLocation",
      "name": "myMemberName",
      "properties": {
        "clusterType": "AKS",
        "connectivityProfile": {
          "eastWestGateway": {
            "visibility": "Internal"
          }
        },
        "metadata": {
          "resourceId": "/subscriptions/$SUBSCRIPTION/resourcegroups/$AKS_RG/providers/Microsoft.ContainerService/managedClusters/$CLUSTER_NAME"
        },
        "observabilityProfile": {
          "metrics": {
            "metricsEndpoint": "https://myMember-mcp-fqdn.appnet.net"
          }
        },
        "provisioningState": "Succeeded",
        "upgradeProfile": {
          "mode": "FullyManaged",
          "fullyManagedUpgradeProfile": {
            "releaseChannel": "Stable"
          }
        }
      },
      "resourceGroup": "myAppNetRG",
      "type": "microsoft.applink/applinks/applinkmembers"
    }
    ```

## List Azure Kubernetes Application Network members

Multiple clusters can join an Azure Kubernetes Application Network.

- List all members of an Azure Kubernetes Application Network using the [`az appnet member list`][az-appnet-member-list] command.

    ```azurecli-interactive
    az appnet member list --resource-group $APPNET_RG --appnet-name $APPNET_NAME --output table
    ```

## Delete Azure Kubernetes Application Network resources

You must remove all members before you can delete the Azure Kubernetes Application Network resource. Removing a member doesn't delete the corresponding AKS cluster.

### Remove an Azure Kubernetes Application Network member

> [!NOTE]
> Before removing a member, you must remove your workloads from the ambient data plane by removing Istio labels you previously applied, such as `istio.io/use-waypoint`, `istio.io/use-waypoint-namespace`, and `istio.io/dataplane-mode`, from resources.

1. Remove a member from Azure Kubernetes Application Network using the [`az appnet member remove`][az-appnet-member-remove] command.

    ```azurecli-interactive
    az appnet member remove --resource-group $APPNET_RG --appnet-name $APPNET_NAME --member-name $APPNET_MEMBER_NAME
    ```

1. Verify the member has been removed using the [`az appnet member list`][az-appnet-member-list] command.

    ```azurecli-interactive
    az appnet member list --resource-group $APPNET_RG --appnet-name $APPNET_NAME 
    ```

### Delete an Azure Kubernetes Application Network resource

- Delete the Azure Kubernetes Application Network resource using the [`az appnet delete`][az-appnet-delete] command.

    ```azurecli-interactive
    az appnet delete --resource-group $APPNET_RG --appnet-name $APPNET_NAME
    ```

## Related content

To learn more about Azure Kubernetes Application Network, see the following articles:

- [Azure Kubernetes Application Network architecture](./architecture.md)
- [Overview of Azure Kubernetes Application Network observability](./observability.md)
- [Overview of Azure Kubernetes Application Network security](./security.md)

<!--- LINKS --->
[az-account-set]: /cli/azure/account#az-account-set
[az-group-create]: /cli/azure/group#az-group-create
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-appnet-create]: /cli/azure/appnet#az-appnet-create
[az-appnet-show]: /cli/azure/appnet#az-appnet-show
[az-appnet-member-show]: /cli/azure/appnet/member#az-appnet-member-show
[az-appnet-member-list]: /cli/azure/appnet/member#az-appnet-member-list
[az-appnet-member-remove]: /cli/azure/appnet/member#az-appnet-member-remove
[az-appnet-member-join]: /cli/azure/appnet/member#az-appnet-member-join
[az-appnet-delete]: /cli/azure/appnet#az-appnet-delete
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-provider-register]: /cli/azure/provider#az-provider-register
