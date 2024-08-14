---
title: Configure Static Egress Gateway in Azure Kubernetes Service (AKS) - Preview
titleSuffix: Azure Kubernetes Service
description: Learn how to configure Static Egress Gateway in Azure Kubernetes Service (AKS) manage egress traffic from a constant IP address.
author: asudbring
ms.author: allensu
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 08/12/2024
---

# Configure Static Egress Gateway in Azure Kubernetes Service (AKS)

Static Egress Gateway in AKS provides a streamlined solution for configuring fixed source IP addresses for outbound traffic from your AKS workloads. This feature allows you to route egress traffic through a dedicated “gateway nodepool”. By using the Static Egress Gateway, you can efficiently manage and control outbound IP addresses and ensure that your AKS workloads can communicate with external systems securely and consistently, using predefined IPs.

This article provides step-by-step instructions to set up a Static Egress Gateway nodepool in your AKS cluster, enabling you to configure fixed source IP addresses for outbound traffic from your Kubernetes workloads.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Limitations and considerations

- Static Egress Gateway is not supported in clusters with [Azure CNI Pod Subnet][azure-cni-pod-subnet].
- Kubernetes network policies will not apply to traffic leaving the cluster through the gateway nodepool.
  - This should not impact cluster traffic control as **only** egress traffic from annotated pods are affected.
- The gateway nodepool is not intended for general-purpose workloads and should be used for egress traffic only.
- Windows nodepools cannot be used as gateway nodepools.
- hostNetwork pods **cannot** be annotated to use the gateway nodepool.

## Before you begin

- If using the Azure CLI, you need the `aks-preview` extension. See [Install the `aks-preview` Azure CLI extension](#install-the-aks-preview-azure-cli-extension).

### Install the `aks-preview` Azure CLI extension

1. Install the `aks-preview` extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

2. Update to the latest version of the extension using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the `StaticEgressGatewayPreview` feature flag

1. Register the `StaticEgressGatewayPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "StaticEgressGatewayPreview"
    ```

    It takes a few minutes for the status to show *Registered*.

2. Verify the registration status using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "StaticEgressGatewayPreview"
    ```

3. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

## Create or update an AKS cluster with Static Egress Gateway

Before you can create and manage gateway nodepools, you must enable the Static Egress Gateway feature for your AKS cluster. You can do this when creating a new cluster or by updating an existing cluster using `az aks update`.

```azurecli-interactive
az aks create -n <cluster-name> -g <resource-group> --enable-static-egress-gateway
```

## Create a Gateway Nodepool

After enabling the feature, create a dedicated gateway nodepool. This nodepool will handle the egress traffic through the specified public IP prefix.

```azurecli-interactive
az aks nodepool create --cluster-name <cluster-name> -n <nodepool-name> --mode gateway --node-count <number-of-nodes> --gateway-prefix-size <prefix-size>
```

> [!NOTE] 
> The number of nodes **must** align with the selected prefix size. For example, a `/30` prefix allows up to 4 nodes.

## Scale the Gateway Nodepool (Optional)

If necessary, you can resize the gateway nodepool within the limits defined by the prefix size.

```azurecli-interactive
az aks nodepool scale --cluster-name <cluster-name> -n <nodepool-name> --node-count <desired-node-count>
```

## Create a Static Gateway Configuration

Define the gateway configuration by creating a `StaticGatewayConfiguration` custom resource. This configuration specifies which nodepool and public IP prefix to use.

```yaml
apiVersion: v1alpha1
kind: staticgatewayconfiguration.sgw.kubernetes.azure.com
metadata:
  name: <gateway-config-name>
  namespace: <namespace>
spec:
  gatewayNodePoolName: <nodepool-name>
  exceptionCidrs:
  - 10.0.0.0/8
  - 172.16.0.0/12
  publicIpPrefixId: /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Network/publicIPPrefixes/<prefix-name>
```

> [!TIP]
> You can use an existing public IP prefix by specifying its resource ID, or let the system create one for you.

## Annotate Pods to Use the Gateway Configuration

To route traffic from specific pods through the gateway nodepool, annotate the pod template in the deployment configuration.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <deployment-name>
  namespace: <namespace>
spec:
  template:
    metadata:
      annotations:
        kubernetes.azure.com/static-gateway-configuration: <gateway-config-name>
```

> [!NOTE]
> The CNI plugin on each node will automatically configure the pod to route its traffic through the selected gateway nodepool.

## Monitor and Manage Gateway Configurations

Once deployed, you can monitor the status of your gateway configurations through the AKS cluster. The status section in the `StaticGatewayConfiguration` resource will be updated with details such as assigned IPs and WireGuard configurations.

## Delete a Gateway Nodepool (Optional)

To remove a gateway nodepool, ensure all associated configurations are appropriately handled before deletion.

```azurecli
az aks nodepool delete --cluster-name <cluster-name> -n <nodepool-name>
```

## Disable the Static Egress Gateway Feature (Optional)

If you no longer need the Static Egress Gateway, you can disable the feature and uninstall the operator. Ensure all gateway nodepools are deleted first.

```azurecli
az aks update -n <cluster-name> -g <resource-group> --disable-static-egress-gateway
```

By following these steps, you can effectively set up and manage Static Egress Gateway configurations in your AKS cluster, enabling controlled and consistent egress traffic from your workloads.

<!-- LINKS - Internal -->
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[azure-cni-pod-subnet]: concepts-network-azure-cni-pod-subnet.md