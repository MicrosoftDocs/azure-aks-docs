---
title: "Deploy WireGuard Encryption with Advanced Container Networking Services"
description: Get started with WireGuard Encryption Feature for Advanced Container Networking Services on your AKS cluster.
author: josephyostos
ms.author: josephyostos
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 05/02/2024
ms.custom: template-how-to-pattern, devx-track-azurecli
---

# Deploy WireGuard encryption with Advanced Container Networking Services (Preview)
> [!IMPORTANT]
> WireGuard encryption with Advanced Cluster Networking Services is currently in PREVIEW.  
> See the [Supplemental Terms of Use for Microsoft Azure Previews](https://azure.microsoft.com/support/legal/preview-supplemental-terms/) for legal terms that apply to Azure features that are in beta, preview, or otherwise not yet released into general availability.

This article shows you how to deploy WireGuard encryption with Advanced Container Networking Services in Azure Kubernetes Service (AKS) clusters.

## Prerequisites

- An Azure account with an active subscription. If you don't have one, create a [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn) before you begin.
[!INCLUDE [azure-CLI-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

- The minimum version of Azure CLI required for the steps in this article is 2.71.0. To find the version, run `az --version`. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).

- WireGuard encryption is only supported with the Azure CNI powered by Cilium. If you're using any other network plugin, WireGuard encryption isn't supported. See [Configure Azure CNI Powered by Cilium](/azure/aks/azure-cni-powered-by-cilium).
- WireGuard establishes encrypted tunnels over UDP port 51871, which is exposed on each AKS node. Ensure UDP port 51871 is allowed between all node IPs, especially if your environment uses firewalls.

### Install the `aks-preview` Azure CLI extension

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Install or update the Azure CLI preview extension using the [`az extension add`](/cli/azure/extension#az-extension-add) or [`az extension update`](/cli/azure/extension#az-extension-update) command.

 The minimum version of the aks-preview Azure CLI extension is `14.0.0b6`

```azurecli-interactive
# Install the aks-preview extension
az extension add --name aks-preview
# Update the extension to make sure you have the latest version installed
az extension update --name aks-preview
```

### Register the `AdvancedNetworkingWireGuardPreview` feature flag

Register the `AdvancedNetworkingWireGuardPreview` feature flag using the  [`az feature register`](/cli/azure/feature#az-feature-register) command.

```azurecli-interactive 
az feature register --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingWireGuardPreview"
```
Verify successful registration using the [`az feature show`](/cli/azure/feature#az-feature-show) command. It takes a few minutes for the registration to complete.

```azurecli-interactive
az feature show --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingWireGuardPreview"
```

Once the feature shows `Registered`, refresh the registration of the `Microsoft.ContainerService` resource provider using the [`az provider register`](/cli/azure/provider#az-provider-register) command.

### Enable Advanced Container Networking Services and WireGuard

To proceed, you must have an AKS cluster with [Advanced Container Networking Services](./advanced-container-networking-services-overview.md) enabled.

The `az aks create` command with the Advanced Container Networking Services flag, `--enable-acns`, creates a new AKS cluster with all Advanced Container Networking Services features. These features encompass:
* **Container Network Observability:**  Provides insights into your network traffic. To learn more visit [Container Network Observability](./advanced-container-networking-services-overview.md?tabs=cilium#container-network-observability).

* **Container Network Security:** Offers security features like Fully Qualified Domain Name (FQDN) filtering. To learn more visit  [Container Network Security](./advanced-container-networking-services-overview.md?tabs=cilium#container-network-security).




> [!NOTE]
> Clusters with the Cilium data plane support Container Network Observability and Container Network security starting with Kubernetes version 1.29.
> WireGuard is disabled by default even after enabling ACNS. To enable WireGuard set the encryption type by using the flag `--acns-transit-encryption-type wireguard`.


```azurecli-interactive

# Set environment variables for the AKS cluster name and resource group. Make sure to replace the placeholders with your own values.
export CLUSTER_NAME="<aks-cluster-name>"
export RESOURCE_GROUP="<resourcegroup-name>"
 
# Create an AKS cluster
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --location eastus \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --network-dataplane cilium \
    --enable-acns \
    --acns-transit-encryption-type wireguard \
    --generate-ssh-keys
```



## Enable Advanced Container Networking Services and WireGuard on an existing cluster

The [`az aks update`](/cli/azure/aks#az-aks-update) command with the Advanced Container Networking Services flag, `--enable-acns`, updates an existing AKS cluster with all Advanced Container Networking Services features, which includes [Container Network Observability](./advanced-container-networking-services-overview.md?tabs=cilium#container-network-observability) and the [Container Network Security](./advanced-container-networking-services-overview.md?tabs=cilium#container-network-security) feature.

> [!IMPORTANT]
> Enabling WireGuard on an existing cluster will trigger a rollout restart of the Cilium agent across all nodes. For large clusters, this process can take some time and may temporarily impact workloads. It's recommended to plan the update during a maintenance window or low-traffic period to minimise disruption
>


> [!NOTE]
> Only clusters with the Cilium data plane support Container Network Security features of Advanced Container Networking Services. 
>
> WireGuard is disabled by default even after enabling ACNS. To enable WireGuard set the encryption type by using the flag `--acns-transit-encryption-type wireguard`.

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns \
    --acns-transit-encryption-type wireguard
``` 
## Get cluster credentials 

Get your cluster credentials using the [`az aks get-credentials`](/cli/azure/aks#az-aks-get-credentials) command.

```azurecli-interactive
az aks get-credentials --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP
```

## Validate the setup

Validate that WireGuard is enabled successfully using cilium-dbg cli

> [!NOTE]
> It might take a few minutes for WireGuard to be fully enabled and configured across all nodes after activation.

1. Run a bash shell in one of the Cilium pods

```bash
kubectl -n kube-system exec -ti ds/cilium -- bash
``` 

2. Check that WireGuard is enabled

```bash
cilium-dbg encrypt status
```

Expected output:

```
Encryption: Wireguard
Interface: cilium_wg0
        Public key: jikeOvVATORm/1GD0kZLxKhw1lofdsfdgiXWVyVIR3T0=
        Number of peers: 2
```
The number of peers should equal the number of nodes minus one.

## Troubleshooting

When WireGuard encryption is enabled in an AKS cluster using Cilium CNI, you can use the cilium-dbg CLI tool to inspect tunnel status, verify peer connectivity, and debug encryption-related issues.

### Inspect WireGuard peers

You can inspect peer status and configuration on each node using:

```bash
kubectl exec -n kube-system ds/cilium -- cilium-dbg debuginfo --output json | jq .encryption
```

Expected output:

```
{
  "wireguard": {
    "interfaces": [
      {
        "listen-port": 51871,
        "name": "cilium_wg0",
        "peer-count": 1,
        "peers": [
          {
            "allowed-ips": [
              "10.244.1.31/32",
              "10.244.1.206/32",
              "10.224.0.6/32"
            ],
            "endpoint": "10.224.0.6:51871",
            "last-handshake-time": "2025-04-24T11:13:49.102Z",
            "public-key": "3qwZEQLdK5IcFcdXxtr1m8RkDqznPVWEEirJ88+zDyk=",
            "transfer-rx": 2457024,
            "transfer-tx": 15746568
          }
        ],
        "public-key": "jikeOvVATORm/1GD0kZLxKhw1lofdsfdgiXWVyVIR3T0="
      }
    ],
    "node-encryption": "Disabled"
  }
}
```

This output shows the current state of WireGuard encryption on the node.
- listen-port: The UDP port (51871) where this node is listening for encrypted traffic from peers.
- peer-count: The number of remote WireGuard peers configured for this node.
- peers:
  - allowed-ips: list of pod IP addresses routed through the encrypted tunnel to this peer.
  - endpoint: The IP and port of the remote peer's WireGuard interface.
  - last-handshake-time: Timestamp of the most recent successful key exchange with this peer.
  - public-key: The public key of the remote peer.
  - transfer-rx / transfer-tx: The total number of bytes received/transmitted over the tunnel.
- public-key: The local WireGuard interface’s public key.
- node-encryption: Encrypts traffic originating from the node itself or from host-network pods. At present, only pod traffic is encrypted. Node encryption is not yet supported and remains disabled by default.

## Disabling WireGuard on an existing cluster

WireGuard can be disabled independently without affecting other ACNS features. To disable it, set the flag `--acns-transit-encryption-type=none`.

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns \
    --acns-transit-encryption-type none
```

## Known issues

- Packets might be dropped when configuring the WireGuard device leading to connectivity issues. This issue happens when endpoints are added or removed or when node updates occur. In some cases, this issue might lead to failed calls to [sendmsg](https://man7.org/linux/man-pages/man2/sendmsg.2.html) and [sendto](https://man7.org/linux/man-pages/man2/sendto.2.html). For more information, see [GitHub issue 33159](https://github.com/cilium/cilium/issues/33159).