---
title: Get Started with Azure Kubernetes Application Network for AKS (Preview)
description: Learn how to get started with Azure Kubernetes Application Network for AKS, including prerequisites, creating an Application Network resource, connecting an AKS cluster as a member, and managing resources.
author: kochhars
ms.author: kochhars
ms.service: azure-kubernetes-app-net
ms.topic: get-started
ms.date: 10/30/2026
ai-usage: ai-assisted
---

# Get started with Azure Kubernetes Application Network for AKS (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

This article helps you get started with Azure Kubernetes Application Network for AKS. It provides step-by-step instructions to create an Application Network resource and connect an AKS cluster to it as a member cluster.

> [!NOTE]
> This quickstart creates a public AKS cluster. For an eligible private AKS cluster, follow [Connect private AKS clusters][appnet-private-connectivity] to check availability and choose the subnet and join options. Public clusters can't use the private-connect path.

## Prerequisites

- An Azure subscription. If you don't have one, create a [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).
- Azure CLI version 2.84.0 or later. Check your version using the `az --version` command. To install or update, see [Install Azure CLI](/cli/azure/install-azure-cli).
- For both existing and new AKS clusters, make sure they meet the following requirements. These requirements are validated when you join the cluster as a member:

    - [Istio-based service mesh add-on](/azure/aks/istio-about) (`ServiceMeshProfile`) is **not** enabled. A cluster that already has the Istio add-on enabled can't join an Azure Kubernetes Application Network.
    - [AKS-managed Microsoft Entra integration](/azure/aks/entra-id-control-plane-authentication) is enabled.
    - [OIDC issuer](/azure/aks/use-oidc-issuer) is enabled.
    - [Managed Kubernetes Gateway API installation](/azure/aks/managed-gateway-api) is enabled.
- Verify support for your existing Kubernetes cluster using the [support policy](./supported-versions.md).
- Meet the [network access requirements][appnet-network-access] for your cluster's API server and data plane.

## Network access requirements

Application Network needs connectivity in both directions. Allowing one path doesn't enable the other:

| Connection | Required access |
| --- | --- |
| Application Network managed control plane to the member's Kubernetes API server | For a public API server, permit the Application Network source addresses through any API-server access restrictions. For a private API server, follow the [private-connectivity requirements][appnet-private-connectivity]. |
| Member cluster data plane to its Application Network managed control plane (MCP) | Allow DNS resolution and outbound TLS connections to the member's MCP FQDN on **TCP 443**. These connections carry configuration discovery and workload certificate requests. |

Meet these requirements in addition to the [standard AKS outbound network requirements][aks-outbound-rules].

### Public API-server authorized IP ranges

If a public AKS cluster uses [API-server authorized IP ranges][aks-authorized-ip-ranges], the allowed sources must include Application Network's managed control-plane egress addresses. Application Network uses the **`CloudAppLink`** service tag for these addresses.

> [!IMPORTANT]
> Using a service-tag name in AKS authorized IP ranges requires separate enablement for `Microsoft.ContainerService/EnableServiceTagAuthorizedIPPreview`. Public API Server VNet Integration configurations can have additional service-tag availability requirements. Confirm the supported configuration with the Application Network and AKS teams before using the tag.
>
> AppNet `PublicPreview` or `PrivatePath` registration doesn't enable AKS service-tag support. Don't assume that `CloudAppLink` is available through the standard public service-tag catalog or that the AKS authorized IP ranges setting accepts tag names without this enablement.

When updating authorized IP ranges, retain the existing approved administrator, automation, and cluster egress ranges. An update replaces the configured list; adding Application Network access must not remove those entries. If service-tag entries aren't available for your subscription, obtain the supported source-address configuration from the service team rather than using a guessed CIDR or opening the API server to all sources.

This requirement applies to a **public** API server. It doesn't use `connectivityProfile.privateConnect` or enable the private-connect path for public AKS clusters.

### Data plane outbound access to the MCP

If the member cluster has a firewall, proxy, network policy, or other egress restriction, allow its data plane to resolve and reach the assigned MCP hostname over TLS on TCP 443. This requirement applies to both public and private member clusters. Private connectivity to the Kubernetes API server doesn't replace the data-plane-to-MCP connection.

Use the member's actual hostname, not a copied example, a fixed IP address, or a metrics URL including its scheme and path. See [Get the managed control plane hostname][appnet-mcp-hostname] for the current endpoint discovery method.

Plan this access before onboarding. If initial provisioning is blocked before the assigned endpoint is available, coordinate the hostname and bootstrap access requirements with the Application Network team. Don't treat an empty endpoint as permission to use an unrestricted outbound rule.

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

If you don't have an existing AKS cluster to connect to Azure Kubernetes Application Network, you need to create one. Azure Kubernetes Application Network requires AKS clusters that meet the following requirements:

- [Istio-based service mesh add-on](/azure/aks/istio-about) (`ServiceMeshProfile`) is **not** enabled.
- [AKS-managed Microsoft Entra integration](/azure/aks/entra-id-control-plane-authentication) is enabled.
- [OIDC issuer](/azure/aks/use-oidc-issuer) is enabled.
- [Managed Kubernetes Gateway API installation](/azure/aks/managed-gateway-api) is enabled.

If you have an existing cluster that already meets these requirements, you can skip this step.

1. Create a resource group for your AKS cluster using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --name $AKS_RG --location $LOCATION 
    ```

1. Create an AKS cluster with AKS-managed Microsoft Entra integration, OIDC issuer, and the managed Kubernetes Gateway API add-on enabled using the [`az aks create`][az-aks-create] command with the `--enable-oidc-issuer`, `--enable-aad`, and `--enable-gateway-api` flags. Do **not** enable the Istio service mesh add-on (`--enable-azure-service-mesh`) on this cluster.

    ```azurecli-interactive
    az aks create --name $CLUSTER_NAME --resource-group $AKS_RG --enable-oidc-issuer --enable-aad --enable-gateway-api
    ```

## Create an Azure Kubernetes Application Network resource

1. Create a resource group for your Azure Kubernetes Application Network resource using the [`az group create`][az-group-create] command.

    ```azurecli-interactive
    az group create --name $APPNET_RG --location $LOCATION 
    ```

1. Create an Azure Kubernetes Application Network resource using the [`az appnet create`][az-appnet-create] command.

    > [!NOTE]
    > You can't change an Application Network resource's location, subscription, or resource group after you create it.

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

For multi-cluster deployments, [choose your connectivity topology](./multi-cluster-connectivity.md) before joining members. Network names describe whether members share direct pod-IP connectivity or communicate through east-west gateways.

> [!NOTE]
> You can't change a member's parent Application Network, location, subscription, or resource group after you join it. To change any of these, remove the member and rejoin it with the new values.

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

- After joining the cluster, check member provisioning and view its details by using the [`az appnet member show`][az-appnet-member-show] command. A successful ARM operation alone doesn't verify application traffic or all network paths.

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

### Get the managed control plane hostname

- Read the member's endpoint URL by using the [`az appnet member show`][az-appnet-member-show] command:

    ```azurecli-interactive
    az appnet member show \
        --resource-group $APPNET_RG \
        --appnet-name $APPNET_NAME \
        --member-name $APPNET_MEMBER_NAME \
        --query properties.observabilityProfile.metrics.metricsEndpoint \
        -o tsv
    ```

    `metricsEndpoint` is a read-only metrics URL. Its hostname currently identifies the same MCP endpoint used for configuration discovery and certificate requests. For an FQDN-based egress rule, use only that hostname, without `https://`, a path, or a port suffix, and permit TCP 443.

    Don't set this property in a join or update request. If the returned value is empty during initial or failed provisioning, the endpoint isn't exposed yet. Follow the [bootstrap access guidance][appnet-mcp-egress] rather than inventing a destination.

## List Azure Kubernetes Application Network members

Multiple clusters can join an Azure Kubernetes Application Network.

- List all members of an Azure Kubernetes Application Network using the [`az appnet member list`][az-appnet-member-list] command.

    ```azurecli-interactive
    az appnet member list --resource-group $APPNET_RG --appnet-name $APPNET_NAME --output table
    ```

## Delete Azure Kubernetes Application Network resources

Deleting an Azure Kubernetes Application Network resource automatically removes all of its members, so you don't need to remove members first. Removing a member, whether individually or through this cascade, doesn't delete the corresponding AKS cluster.

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
- [Configure multi-cluster connectivity](./multi-cluster-connectivity.md)
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
[appnet-private-connectivity]: ./private-connectivity.md
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-provider-register]: /cli/azure/provider#az-provider-register
[appnet-network-access]: #network-access-requirements
[aks-outbound-rules]: ../aks/outbound-rules-control-egress.md
[aks-authorized-ip-ranges]: ../aks/api-server-authorized-ip-ranges.md
[appnet-mcp-hostname]: #get-the-managed-control-plane-hostname
[appnet-mcp-egress]: #data-plane-outbound-access-to-the-mcp
