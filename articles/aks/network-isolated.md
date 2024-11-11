---
title: Network isolated clusters
titleSuffix: Azure Kubernetes Service
description: Learn how to configure an Azure Kubernetes Service (AKS) cluster with outbound and inbound network restrictions.
ms.subservice: aks-networking
author: shashankbarsin
ms.author: shasb
ms.topic: how-to
ms.date: 11/10/2024
zone_pivot_groups: network-isolated-acr-type
---

# Create a network isolated Azure Kubernetes Service (AKS) cluster (Preview)

Organizations typically have strict security and compliance requirements to regulate egress (outbound) network traffic from a cluster to eliminate risks of data exfiltration. By default, Azure Kubernetes Service (AKS) clusters have unrestricted outbound internet access. This level of network access allows nodes and services you run to access external resources as needed. If you wish to restrict egress traffic, a limited number of ports and addresses must be accessible to maintain healthy cluster maintenance tasks. One of the solutions to securing outbound addresses is using a firewall device that can control outbound traffic based on domain names. Configuring a firewall manually with required egress rules and FQDNs is a cumbersome and complicated process.

A network isolated AKS cluster simplifies setting up outbound restrictions for a cluster out of the box, thus reducing the risk of data exfiltration or unintentional exposure of cluster's public endpoints.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]


## Before you begin

Read the conceptual overview of this feature, which provides an explanation of how network isolated clusters work.

[!INCLUDE [azure-cli-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

1. This article requires version 2.63.0 or later of the Azure CLI. If you're using Azure Cloud Shell, the latest version is already installed there.

1. Install the `aks-preview` Azure CLI extension version **9.0.0b2* or later.

    - If you don't already have the `aks-preview` extension, install it using the [`az extension add`][az-extension-add] command.

        ```azurecli-interactive
        az extension add --name aks-preview
        ```

    - If you already have the `aks-preview` extension, update it to make sure you have the latest version using the [`az extension update`][az-extension-update] command.

        ```azurecli-interactive
        az extension update --name aks-preview


1. Register the `NetworkIsolatedClusterPreview` feature flag using the [az feature register][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace Microsoft.ContainerService --name NetworkIsolatedClusterPreview
    ```

    Verify the registration status by using the [az feature show][az-feature-show] command. It takes a few minutes for the status to show *Registered*:

    ```azurecli-interactive
    az feature show --namespace Microsoft.ContainerService --name NetworkIsolatedClusterPreview
    ```

    > [!NOTE]
    > If you choose to create network isolated cluster with API Server VNet Integration configured for private access of the API Server, then you need to repeat the above steps to register `EnableAPIServerVnetIntegrationPreview` feature flag too.

    When the status reflects *Registered*, refresh the registration of the `Microsoft.ContainerService` and `Microsoft.ContainerRegistry` resource providers by using the [az provider register][az-provider-register] command:

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    az provider register --namespace Microsoft.ContainerRegistry
    ```

1. If you're choosing the Bring your own (BYO) Azure Container Registry (ACR)* option, you need to ensure the ACR meets the following requirements
    * [Anonymous pull access][anonymous-pull-access] must be enabled for the ACR.
    * The ACR needs to be of the [Premium SKU service tier][container-registry-skus]


1. (Optional) Set up private connection configuration for addons based on the following guides. This step is only required when using the following add-ons:
  - [CSI secret store (Azure keyvault secrets provider)][csisecretstore]
  - [Azure monitor for containers (Container insights)][azuremonitoring]
  - [Application insights][applicationinsights]
  - [Web application routing][webapplicationrouting]


::: zone pivot="aks-managed-acr"

### Create a network isolated cluster using Private link-based cluster

Create a private link-based network isolated AKS cluster by running the [az aks create][az-aks-create] command with `--bootstrap-artifact-source`, `--enable-private-cluster`, and `--outbound-type` parameters.

`--bootstrap-artifact-source` can be set to either `Direct` or `Cache` corresponding to using direct MCR (NOT network isolated) and private ACR (network isolated) for image pulls respectively

The `--outbound-type` parameter can be set to either `none` or `block`. If the outbound type is set to `none`, then AKS doesn't set up any outbound connections for the cluster, allowing the user to configure them on their own. If the outbound type is set to `block`, then all outbound connections are blocked.

```azurecli-interactive
az aks create --resource-group ${RESOURCE_GROUP} --name ${AKS_NAME}   --kubernetes-version 1.30.3 --bootstrap-artifact-source Cache --outbound-type none  --network-plugin azure --enable-private-cluster
```

### Create a network isolated cluster using API Server VNet integration type cluster

Create a network isolated AKS cluster configured with API Server VNet Integration by running the [az aks create][az-aks-create] command with `--enable-private-cluster`, `--boostrap-registry`, `--enable-apiserver-vnet-integration`, and `--outbound-type` parameters.

```azurecli
az aks create --resource-group ${RESOURCE_GROUP} --name ${AKS_NAME} --kubernetes-version 1.30.3 --bootstrap-artifact-source Cache --outbound-type none --network-plugin azure --enable-apiserver-vnet-integration
```

### Update an existing AKS cluster to network isolated type

To enable the network isolation on an existing AKS cluster, use the [az aks update][az-aks-update] command.

```azurecli-interactive
az aks update --resource-group ${RESOURCE_GROUP} --name ${AKS_NAME} --bootstrap-artifact-source Cache --outbound-type none
```

After the feature is enabled, any newly added nodes can bootstrap successfully without egress. When you enable network isolation on an existing cluster, keep in mind that you need to manually re-image all existing nodes.

```azurecli-interactive
az aks upgrade --resource-group ${RESOURCE_GROUP} --name ${AKS_NAME} --node-image-only
```

>[!IMPORTANT]
> Remember to re-image the cluster's node pools after you enable the network isolation mode for an existing cluster. Otherwise, the feature won't take effect for the cluster.

::: zone-end

::: zone pivot="byo-acr"

## Deploy a network isolated cluster with bring your own ACR

AKS supports bringing your own (BYO) ACR. To support the BYO ACR scenario, an ACR private endpoint and a private DNS zone must also be configured before you create the AKS cluster.

The following steps show how to prepare these resources:

* Custom virtual network and subnets for AKS and ACR.
* ACR, ACR cache rule, private endpoint, and private DNS zone.
* Custom control plane identity and kubelet identity.


### Step 1: Create the virtual network and subnets

The default outbound access for the AKS subnet must be false.

```azurecli-interactive
az network vnet create  --resource-group ${RESOURCE_GROUP} --name ${VNET_NAME} --address-prefixes 192.168.0.0/16

az network vnet subnet create --name ${AKS_SUBNET_NAME} --vnet-name ${VNET_NAME} --resource-group ${RESOURCE_GROUP} --address-prefixes 192.168.1.0/24 --default-outbound-access false

SUBNET_ID=$(az network vnet subnet show --name ${AKS_SUBNET_NAME} --vnet-name ${VNET_NAME} --resource-group ${RESOURCE_GROUP} --query 'id' --output tsv)

az network vnet subnet create --name ${ACR_SUBNET_NAME} --vnet-name ${VNET_NAME} --resource-group ${RESOURCE_GROUP} --address-prefixes 192.168.2.0/24 --private-endpoint-network-policies Disabled
```

### Step 2: Create the ACR and enable artifact cache

1. Create the ACR with the private link and anonymous pull access.

    ```azurecli-interactive
    az acr create --resource-group ${RESOURCE_GROUP} --name ${REGISTRY_NAME} --sku Premium --public-network-enabled false

    az acr update --resource-group ${RESOURCE_GROUP} --name ${REGISTRY_NAME} --anonymous-pull-enabled true

    REGISTRY_ID=$(az acr show --name ${REGISTRY_NAME} -g ${RESOURCE_GROUP}  --query 'id' --output tsv)
    ```

1. Create an ACR cache rule to allow users to cache MCR container images in the new ACR.

    ```azurecli-interactive
    az acr cache create -n acr-cache-rule -r ${REGISTRY_NAME} -g ${RESOURCE_GROUP} --source-repo "mcr.microsoft.com/*" --target-repo "*"
    ```

### Step 3: Create a private endpoint for the ACR

```azurecli-interactive
az network private-endpoint create --name myPrivateEndpoint --resource-group ${RESOURCE_GROUP} --vnet-name ${VNET_NAME} --subnet ${ACR_SUBNET_NAME} --private-connection-resource-id ${REGISTRY_ID} --group-id registry --connection-name myConnection

NETWORK_INTERFACE_ID=$(az network private-endpoint show --name myPrivateEndpoint --resource-group ${RESOURCE_GROUP} --query 'networkInterfaces[0].id' --output tsv)

REGISTRY_PRIVATE_IP=$(az network nic show --ids ${NETWORK_INTERFACE_ID} --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry'].privateIPAddress" --output tsv)

DATA_ENDPOINT_PRIVATE_IP=$(az network nic show --ids ${NETWORK_INTERFACE_ID} --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry_data_$LOCATION'].privateIPAddress" --output tsv)
```

### Step 4: Create a private DNS zone and add records

Create a private DNS zone named `privatelink.azurecr.io`. Add the records for the registry REST endpoint `{REGISTRY_NAME}.azurecr.io`, and the registry data endpoint `{REGISTRY_NAME}.{REGISTRY_LOCATION}.data.azurecr.io`.

```azurecli-interactive
az network private-dns zone create --resource-group ${RESOURCE_GROUP} --name "privatelink.azurecr.io"

az network private-dns link vnet create --resource-group ${RESOURCE_GROUP} --zone-name "privatelink.azurecr.io" --name MyDNSLink --virtual-network ${VNET_NAME} --registration-enabled false

az network private-dns record-set a create --name ${REGISTRY_NAME} --zone-name "privatelink.azurecr.io" --resource-group ${RESOURCE_GROUP}

az network private-dns record-set a add-record --record-set-name ${REGISTRY_NAME} --zone-name "privatelink.azurecr.io" --resource-group ${RESOURCE_GROUP} --ipv4-address ${REGISTRY_PRIVATE_IP}

az network private-dns record-set a create --name ${REGISTRY_NAME}.${LOCATION}.data --zone-name "privatelink.azurecr.io" --resource-group ${RESOURCE_GROUP}

az network private-dns record-set a add-record --record-set-name ${REGISTRY_NAME}.${LOCATION}.data --zone-name "privatelink.azurecr.io" --resource-group ${RESOURCE_GROUP} --ipv4-address ${DATA_ENDPOINT_PRIVATE_IP}
```

### Step 5: Create control plane and kubelet identities

**Control plane identity:**

```azurecli-interactive
az identity create --name ${CLUSTER_IDENTITY_NAME} --resource-group ${RESOURCE_GROUP}

export CLUSTER_IDENTITY_RESOURCE_ID=$(az identity show --name ${CLUSTER_IDENTITY_NAME} --resource-group ${RESOURCE_GROUP} --query 'id' -o tsv)

export CLUSTER_IDENTITY_PRINCIPAL_ID=$(az identity show --name ${CLUSTER_IDENTITY_NAME} --resource-group ${RESOURCE_GROUP} --query 'principalId' -o tsv)
```

**Kubelet identity:**

```azurecli-interactive
az identity create --name ${KUBELET_IDENTITY_NAME} --resource-group ${RESOURCE_GROUP}

export KUBELET_IDENTITY_RESOURCE_ID=$(az identity show --name ${KUBELET_IDENTITY_NAME} --resource-group ${RESOURCE_GROUP} --query 'id' -o tsv)

export KUBELET_IDENTITY_PRINCIPAL_ID=$(az identity show --name ${KUBELET_IDENTITY_NAME} --resource-group ${RESOURCE_GROUP} --query 'principalId' -o tsv)
```

**Grant AcrPull permissions for the Kubelet identity:**

```azurecli-interactive
az role assignment create --role AcrPull --scope ${REGISTRY_ID} --assignee-object-id ${KUBELET_IDENTITY_PRINCIPAL_ID} --assignee-principal-type ServicePrincipal
```

After you configure these resources, you can proceed to create the network isolated AKS cluster with BYO ACR. For private cluster type, you can either choose a private link-based cluster or an API Server VNet integration type cluster.

### Step 6: Create network isolated cluster using the BYO CR

**Private link-based cluster:**

Create a private link-based network isolated cluster that accesses your ACR by running the [az aks create][az-aks-create] command with the required parameters.

```azurecli-interactive
az aks create --resource-group ${RESOURCE_GROUP} --name ${AKS_NAME} --kubernetes-version 1.30.3 --vnet-subnet-id ${SUBNET_ID} --assign-identity ${CLUSTER_IDENTITY_RESOURCE_ID} --assign-kubelet-identity ${KUBELET_IDENTITY_RESOURCE_ID} --bootstrap-artifact-source Cache --bootstrap-container-registry-resource-id ${REGISTRY_ID} --outbound-type none --network-plugin azure --enable-private-cluster
```

**Cluster with API Server VNet integration:**

For a network isolated cluster with API server VNet integration, first create a subnet and assign the correct role with the following commands:

```azurecli-interactive
az network vnet subnet create --name ${APISERVER_SUBNET_NAME} --vnet-name ${VNET_NAME} --resource-group ${RESOURCE_GROUP} --address-prefixes 192.168.3.0/24

export APISERVER_SUBNET_ID=$(az network vnet subnet show --resource-group ${RESOURCE_GROUP} --vnet-name ${VNET_NAME} --name ${APISERVER_SUBNET_NAME} --query id -o tsv)
```

```azurecli-interactive
az role assignment create --scope ${APISERVER_SUBNET_ID} --role "Network Contributor" --assignee-object-id ${CLUSTER_IDENTITY_PRINCIPAL_ID} --assignee-principal-type ServicePrincipal
```

Create a network isolated AKS cluster configured with API Server VNet Integration and access your ACR by running the [az aks create][az-aks-create] command with the required parameters.

```azurecli-interactive
az aks create --resource-group ${RESOURCE_GROUP} --name ${AKS_NAME} --kubernetes-version 1.30.3 --vnet-subnet-id ${SUBNET_ID} --assign-identity ${CLUSTER_IDENTITY_RESOURCE_ID} --assign-kubelet-identity ${KUBELET_IDENTITY_RESOURCE_ID} --bootstrap-artifact-source Cache --bootstrap-container-registry-resource-id ${REGISTRY_ID} --outbound-type none --network-plugin azure --enable-apiserver-vnet-integration --apiserver-subnet-id ${APISERVER_SUBNET_ID}
```

### Update an existing AKS cluster

When creating the private endpoint and private DNS zone for the BYO ACR, use the existing virtual network and subnets of the existing AKS cluster. When you assign the **AcrPull** permission to the kubelet identity, use the existing kubelet identity of the existing AKS cluster.

To enable the network isolated feature on an existing AKS cluster, use the following command:

```azurecli-interactive
az aks update --resource-group ${RESOURCE_GROUP} --name ${AKS_NAME} --bootstrap-artifact-source Cache --bootstrap-container-registry-resource-id ${REGISTRY_ID} --outbound-type none
```

After the network isolated cluster feature is enabled, nodes in the newly added node pool can bootstrap successfully without egress. You must re-image existing node pools so that newly scaled node can bootstrap successfully. When you enable the feature on an existing cluster, you need to manually re-image all existing nodes.

```azurecli-interactive
az aks upgrade --resource-group ${RESOURCE_GROUP} --name ${AKS_NAME} --node-image-only
```

>[!IMPORTANT]
> Remember to re-image the cluster's node pools after you enable the network isolated cluster feature. Otherwise, the feature won't take effect for the cluster.


### Update your ACR ID

You may want to update the resource ID of your own ACR. To identify the ACR resource ID, use the `az aks show` command.

```azurecli-interactive
az aks show --resource-group ${RESOURCE_GROUP} --name ${AKS_NAME}
```

Updating the ACR ID is performed by running the `az aks update` command with the `--bootstrap-artifact-source` and `--bootstrap-container-registry-resource-id` parameters.

```azurecli-interactive
az aks update --resource-group ${RESOURCE_GROUP} --name ${AKS_NAME} --bootstrap-artifact-source Cache --bootstrap-container-registry-resource-id <New BYO ACR resource ID>
```

When you update the ACR ID on an existing cluster, you need to manually re-image all existing nodes.

```azurecli-interactive
az aks upgrade --resource-group ${RESOURCE_GROUP} --name ${AKS_NAME} --node-image-only
```

>[!IMPORTANT]
> Remember to re-image the cluster's node pools after you enable the network isolated cluster feature. Otherwise, the feature won't take effect for the cluster.

::: zone-end

## Validate the network isolated cluster

To validate the network isolated cluster feature, use the `az aks show` command.

```azurecli-interactive
az aks show --resource-group ${RESOURCE_GROUP} --name ${AKS_NAME}
```

The following output shows that the feature is enabled, based on the values of the `outboundType` property (none or blocked) and `artifactSource` property (Cached).

```
"kubernetesVersion": "1.30.3",
"name": "myAKSCluster"
"type": "Microsoft.ContainerService/ManagedClusters"
"properties": {
  ...
  "networkProfile": {
    ...
    "outboundType": "none",
    ...
  },
  ...
  "bootstrapProfile": {
    "artifactSource": "Cache",
    "containerRegistryId": "/subscriptions/my-subscription-id/my-node-resource-group-name/providers/Microsoft.ContainerRegistry/registries/my-registry-name"
  },
  ...
}
```

## Disable network isolated cluster

Disable the network isolated cluster feature by running the `az aks update` command with the `--bootstrap-artifact-source` and `--outbound-type` parameters.

```azurecli-interactive
az aks update --resource-group ${RESOURCE_GROUP} --name ${AKS_NAME} --bootstrap-artifact-source Direct --outbound-type LoadBalancer
```

When you disable the feature on an existing cluster, you need to manually re-image all existing nodes.

```azurecli-interactive
az aks upgrade --resource-group ${RESOURCE_GROUP} --name ${AKS_NAME} --node-image-only
```

>[!IMPORTANT]
> Remember to re-image the cluster's node pools after you disable the network isolated cluster feature. Otherwise, the feature won't take effect for the cluster.

## Next steps

In this article, you learned what ports and addresses to allow if you want to restrict egress traffic for the cluster.

If you want to set up outbound restriction configuration using Azure Firewall, visit [Control egress traffic using Azure Firewall in AKS](limit-egress-traffic.md).

If you want to restrict how pods communicate between themselves and East-West traffic restrictions within cluster see [Secure traffic between pods using network policies in AKS][use-network-policies].


<!-- LINKS - External -->
[microsoft-artifact-registry]: https://mcr.microsoft.com
[microsoft-packages-repository]: https://packages.microsoft.com
[ubuntu-security-repository]: https://security.ubuntu.com
[register-feature-flag]: /azure/azure-resource-manager/management/preview-features?tabs=azure-cli#register-preview-feature
[container-registry-skus]: /azure/container-registry/container-registry-skus
[csisecretstore]: /azure/key-vault/general/private-link-service?tabs=portal
[azuremonitoring]: /azure/azure-monitor/logs/private-link-configure#connect-to-a-private-endpoint
[applicationinsights]: /azure/azure-monitor/logs/private-link-security
[webapplicationrouting]: /azure/cloud-adoption-framework/ready/azure-best-practices/private-link-and-dns-integration-at-scale#private-link-and-dns-integration-in-hub-and-spoke-network-architectures

<!-- LINKS - Internal -->
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-feature-register]: /cli/azure/feature#az_feature_register
[az-feature-show]: /cli/azure/feature#az_feature_show
[az-provider-register]: /cli/azure/provider#az_provider_register
[aks-control-plane-identity]: use-managed-identity.md
[aks-private-link]: private-clusters.md
[azure-acr-rbac-contributor]: /azure/container-registry/container-registry-roles
[container-registry-private-link]: /azure/container-registry/container-registry-private-link
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[az-aks-show]: /cli/azure/aks#az-aks-show
[azure-cni-overlay]: azure-cni-overlay.md
[outbound-rules-control-egress]: outbound-rules-control-egress.md
[anonymous-pull-access]: /azure/container-registry/anonymous-pull-access
[private-clusters]: ./private-clusters.md
[api-server-vnet-integration]: ./api-server-vnet-integration.md
[use-network-policies]: ./use-network-policies.md
