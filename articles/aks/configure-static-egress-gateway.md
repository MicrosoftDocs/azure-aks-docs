---
title: Configure Static Egress Gateway in Azure Kubernetes Service (AKS)
titleSuffix: Azure Kubernetes Service
description: Learn how to configure Static Egress Gateway in Azure Kubernetes Service (AKS) to manage egress traffic from a constant IP address.
author: davidsmatlak
ms.author: davidsmatlak
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 10/27/2026
ai-usage: ai-assisted
# Customer intent: As a Kubernetes administrator, I want to configure a Static Egress Gateway in my AKS cluster, so that I can manage egress traffic with fixed source IP addresses for secure and consistent communication with external systems.
---

# Configure Static Egress Gateway in Azure Kubernetes Service (AKS)

Static Egress Gateway in AKS provides a streamlined solution for configuring fixed source IP addresses for outbound traffic from your AKS workloads. This feature allows you to route egress traffic through a dedicated "gateway node pool". By using the Static Egress Gateway, you can efficiently manage and control outbound IP addresses and ensure that your AKS workloads can communicate with external systems securely and consistently, using predefined IPs.

This article provides step-by-step instructions to set up a Static Egress Gateway node pool in your AKS cluster, enabling you to configure fixed source IP addresses for outbound traffic from your Kubernetes workloads.


## Limitations and considerations

- Static Egress Gateway isn't supported in clusters with [Azure CNI Pod Subnet][azure-cni-pod-subnet].
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
> If you don't set `publicIpPrefixId`, a public IP prefix is created for you automatically. Run `kubectl describe StaticGatewayConfiguration <gateway-config-name> -n <namespace>` to see the assigned prefix in the **Egress Ip Prefix** status field.

### Use your own public IP prefix

To use an existing public IP prefix, set `spec.publicIpPrefixId` to its Azure resource ID.

#### Grant Azure access to the cluster identity

Grant the AKS cluster identity the **Network Contributor** role at the existing public IP prefix's resource scope.

#### Authorize the namespace on the prefix

Ask the prefix administrator to set the Azure resource tag `kube-egress-gateway-allowed-namespaces` to the Kubernetes namespaces approved to use the prefix. The tag accepts comma- or semicolon-separated namespace names. For example, `team-a,team-b` authorizes configurations in those two namespaces. The value `*` authorizes all namespaces; use explicit namespace names when access should be limited.

Set the tag:

```azurecli-interactive
PREFIX_ID=$(az network public-ip prefix show \
    --resource-group <prefix-resource-group> \
    --name <prefix-name> \
    --query id \
    --output tsv)

az tag update \
    --resource-id "$PREFIX_ID" \
    --operation Merge \
    --tags "kube-egress-gateway-allowed-namespaces=team-a,team-b"
```

Replace `team-a,team-b` with the complete list of approved namespaces, including any existing entries that should remain authorized. The merge operation preserves other resource tags, but replaces the value of this tag.

> [!IMPORTANT]
> Permission to modify this tag grants control over namespace authorization. Limit tag changes to trusted administrators. The tag doesn't grant Azure access to the cluster identity or Kubernetes access to create `StaticGatewayConfiguration` resources; configure those permissions separately.

This tag applies only when you supply an existing public IP prefix through `spec.publicIpPrefixId`. It isn't required for automatically created public IP prefixes or private IP configurations with `spec.provisionPublicIps: false`.

### Static private IP support

> [!IMPORTANT]
> Static private IP support requires clusters running Kubernetes version 1.34 or later.

If you must keep egress traffic on private addresses, enable private IP support on the gateway node pool. Use the same `az aks nodepool add` command and set the node pool to use the VirtualMachines VM set type while disabling public IP provisioning:

```azurecli-interactive
az aks nodepool add --cluster-name <cluster-name> \
  --name <nodepool-name> \
  --resource-group <resource-group> \
  --mode gateway \
  --node-count <number-of-nodes> \
  --vm-set-type VirtualMachines \
  --gateway-prefix-size <prefix-size>
```

In this configuration, the `provisionPublicIps=false` setting keeps the private IPs allocated to the gateway nodes for the lifetime of the `StaticGatewayConfiguration`. When you run `kubectl describe StaticGatewayConfiguration <gateway-config-name> -n <namespace>`, the `egressIpPrefix` field shows a comma-separated list of those static private IPs. You continue to use the same APIs and manifests for the rest of the workflow, including the `StaticGatewayConfiguration` resource and the pod annotations.

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

### Check BYO prefix authorization warnings

A Kubernetes Warning event with reason `BYOPrefixAuthorizationRequired` on a `StaticGatewayConfiguration` indicates that its BYO prefix doesn't authorize the configuration's namespace.

View events for a configuration:

```bash
kubectl describe staticgatewayconfiguration <gateway-config-name> -n <namespace>
```

List authorization warnings in a namespace:

```bash
kubectl get events -n <namespace> \
    --field-selector involvedObject.kind=StaticGatewayConfiguration,reason=BYOPrefixAuthorizationRequired
```

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

## Next steps

* [Deploy egress gateways for the Istio service mesh add-on][istio-egress-gateway]

<!-- LINKS - Internal -->
[az-provider-register]: /cli/azure/provider#az-provider-register
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[azure-cni-pod-subnet]: concepts-network-azure-cni-pod-subnet.md
[istio-egress-gateway]: istio-deploy-egress.md
