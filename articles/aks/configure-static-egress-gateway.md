---
title: Configure Static Egress Gateway in Azure Kubernetes Service (AKS)
titleSuffix: Azure Kubernetes Service
description: Learn how to configure Static Egress Gateway in Azure Kubernetes Service (AKS) to manage egress traffic from a constant IP address.
author: asudbring
ms.author: allensu
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 10/18/2024
---

# Configure Static Egress Gateway in Azure Kubernetes Service (AKS)

Static Egress Gateway in AKS provides a streamlined solution for configuring fixed source IP addresses for outbound traffic from your AKS workloads. This feature allows you to route egress traffic through a dedicated "gateway node pool". By using the Static Egress Gateway, you can efficiently manage and control outbound IP addresses and ensure that your AKS workloads can communicate with external systems securely and consistently, using predefined IPs.

This article provides step-by-step instructions to set up a Static Egress Gateway node pool in your AKS cluster, enabling you to configure fixed source IP addresses for outbound traffic from your Kubernetes workloads.


## Limitations and considerations

- Static Egress Gateway isn't supported in clusters with [Azure CNI Pod Subnet][azure-cni-pod-subnet].
- Static Egress Gateway does not support Private IP's assigned to the gateway node pool. The gateway node pool must have a public IP prefix assigned to it.
- Kubernetes network policies won't apply to traffic leaving the cluster through the gateway node pool.
  - This shouldn't affect cluster traffic control as **only** egress traffic from annotated pods **routed to the gateway node pool** are affected.  

- The gateway node pool isn't intended for general-purpose workloads and should be used for egress traffic only.
- Windows node pools can't be used as gateway node pools.
- hostNetwork pods **cannot** be annotated to use the gateway node pool.
- Pods can only use a gateway node pool if they are in the same namespace as the `StaticGatewayConfiguration` resource.

## Create or update an AKS cluster with Static Egress Gateway

Before you can create and manage gateway node pools, you must enable the Static Egress Gateway feature for your AKS cluster. You can do this when creating a new cluster or by updating an existing cluster using `az aks update`.

```azurecli-interactive
az aks create -n <cluster-name> -g <resource-group> --enable-static-egress-gateway
```

## Create a Gateway Node pool

After enabling the feature, create a dedicated gateway node pool. This node pool handles the egress traffic through the specified public IP prefix. The `--gateway-prefix-size` is the size of the public IP prefix to be applied to the gateway node pool nodes. The allowed range is `28`-`31`. 

```azurecli-interactive
az aks nodepool add --cluster-name <cluster-name> \
    --name <nodepool-name> \
    --resource-group <resource-group> \
    --mode gateway \
    --node-count <number-of-nodes> \
    --gateway-prefix-size <prefix-size>
```

> [!NOTE] 
> - The number of nodes must fit within the capacity allowed by the selected prefix size. For example, a /30 prefix supports up to 4 nodes, and at least 2 nodes are required for high availability. Since you can’t adjust the node count dynamically, plan your nodes according to the fixed limit set by the prefix size.
> - You can define the SKU of the VM to use in your gateway node pool with the `--vm-size` parameter. You should understand your specific needs and plan accordingly to ensure the right performance and cost balance.

## Scale the Gateway Node pool (Optional)

If necessary, you can resize the gateway node pool within the limits defined by the prefix size but it doesn't support autoscaling.

```azurecli-interactive
az aks nodepool scale --cluster-name <cluster-name> -n <nodepool-name> --node-count <desired-node-count>
```

## Create a Static Gateway Configuration

Define the gateway configuration by creating a `StaticGatewayConfiguration` custom resource. This configuration specifies which node pool and public IP prefix to use.

```yaml
apiVersion: egressgateway.kubernetes.azure.com/v1alpha1
kind: StaticGatewayConfiguration
metadata:
  name: <gateway-config-name>
  namespace: <namespace>
spec:
  gatewayNodepoolName: <nodepool-name>
  excludeCidrs:  # Optional
  - 10.0.0.0/8
  - 172.16.0.0/12
  - 169.254.169.254/32
  publicIpPrefixId: /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Network/publicIPPrefixes/<prefix-name> # Optional
```

> [!TIP]
> If you don't set `publicIpPrefixId`, a public IP prefix will be created for you automatically. When running `kubectl describe StaticGatewayConfiguration <gateway-config-name> -n <namespace>`, you can see the "Egress Ip Prefix" in the status. This is the newly created public IP prefix. You can also use an existing public IP prefix by specifying its resource ID in the `publicIpPrefixId` argument. You need to grant "Network Contributor" role to AKS cluster's identity in this case.

## Annotate Pods to Use the Gateway Configuration

To route traffic from specific pods through the gateway node pool, annotate the pod template in the deployment configuration.

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

Once deployed, you can monitor the status of your gateway configurations through the AKS cluster. The status section in the `StaticGatewayConfiguration` resource is updated with details such as assigned IPs and WireGuard configurations.

## Delete a Gateway Node pool (Optional)

To remove a gateway node pool, ensure all associated configurations are appropriately handled before deletion.

```azurecli
az aks nodepool delete --cluster-name <cluster-name> -n <nodepool-name>
```

## Disable the Static Egress Gateway Feature (Optional)

If you no longer need the Static Egress Gateway, you can disable the feature and uninstall the operator. Ensure all gateway node pools are deleted first.

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
[azure-cni-pod-subnet]: concepts-network-azure-cni-pod-subnet.md
