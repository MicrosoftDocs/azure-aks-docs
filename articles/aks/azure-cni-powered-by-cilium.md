---
title: Configure Azure CNI Powered by Cilium in Azure Kubernetes Service (AKS)
description: Learn how to create an Azure Kubernetes Service (AKS) cluster with Azure CNI Powered by Cilium.
author: asudbring
ms.author: allensu
ms.subservice: aks-networking
ms.topic: how-to
ms.custom: references_regions, devx-track-azurecli, build-2023
ms.date: 04/06/2025
# Customer intent: As a cloud architect, I want to configure an AKS cluster with Azure CNI Powered by Cilium, so that I can achieve high-performance networking and enhanced security for my containerized applications.
---

# Configure Azure CNI Powered by Cilium in Azure Kubernetes Service (AKS)

> [!div class="nextstepaction"]
> [Deploy and Explore](https://go.microsoft.com/fwlink/?linkid=2321738)

Azure CNI Powered by Cilium combines the robust control plane of Azure CNI with the data plane of [Cilium](https://cilium.io/) to provide high-performance networking and security.

By making use of eBPF programs loaded into the Linux kernel and a more efficient API object structure, Azure CNI Powered by Cilium provides the following benefits:

- Functionality equivalent to existing Azure CNI and Azure CNI Overlay plugins

- Improved Service routing

- More efficient network policy enforcement

- Better observability of cluster traffic

- Support for larger clusters (more nodes, pods, and services)

## IP Address Management (IPAM) with Azure CNI Powered by Cilium

Azure CNI Powered by Cilium can be deployed using two different methods for assigning pod IPs:

- Assign IP addresses from an overlay network (similar to Azure CNI Overlay mode)

- Assign IP addresses from a virtual network (similar to existing Azure CNI with Dynamic Pod IP Assignment)

If you aren't sure which option to select, read ["Choosing a network model to use."](./azure-cni-overlay.md#choosing-a-network-model-to-use)

## Versions

| Kubernetes Version | Minimum Cilium Version |
|--------------------|----------------|
| 1.27 (LTS)         | 1.13.18        |
| 1.28 (End of Life) | 1.13.18        |
| 1.29               | 1.14.19        |
| 1.30 (LTS)         | 1.14.19        |
| 1.31               | 1.16.6         |
| 1.32               | 1.17.0         |
| 1.33               | 1.17.0         |

See [Supported Kubernetes Versions](./supported-kubernetes-versions.md) for more information on AKS versioning and release timelines.

## Network Policy Enforcement

Cilium enforces [network policies to allow or deny traffic between pods](./operator-best-practices-network.md#control-traffic-flow-with-network-policies). With Cilium, you don't need to install a separate network policy engine such as Azure Network Policy Manager or Calico.

## Limitations

Azure CNI powered by Cilium currently has the following limitations:

* Available only for Linux and not for Windows.

* Network policies can't use `ipBlock` to allow access to node or pod IPs. See [frequently asked questions](#frequently-asked-questions) for details and recommended workaround.

* For Cilium versions 1.16 or earlier, multiple Kubernetes services can't use the same host port with different protocols (for example, TCP or UDP) ([Cilium issue #14287](https://github.com/cilium/cilium/issues/14287)).

* Network policies aren't applied to pods using host networking (`spec.hostNetwork: true`) because these pods use the host identity instead of having individual identities.

* Cilium Endpoint Slices are supported in Kubernetes version 1.32 and above. Cilium Endpoint Slices do not support configuration of how Cilium Endpoints are grouped. Priority namespaces through `cilium.io/ces-namespace` is not supported.

## Considerations

To gain capabilities such as observability into your network traffic and security features like Fully Qualified Domain Name (FQDN) based filtering and Layer 7-based network policies on your cluster, consider enabling [Advanced Container Networking services](./advanced-container-networking-services-overview.md) on your clusters.

## Prerequisites

* Azure CLI version 2.48.1 or later. Run `az --version` to see the currently installed version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).

* If using ARM templates or the REST API, the AKS API version must be 2022-09-02-preview or later.

> [!NOTE]
> Previous AKS API versions (2022-09-02preview to 2023-01-02preview) used the field [`networkProfile.ebpfDataplane=cilium`](https://github.com/Azure/azure-rest-api-specs/blob/06dbe269f7d9c709cc225c92358b38c3c2b74d60/specification/containerservice/resource-manager/Microsoft.ContainerService/aks/preview/2022-09-02-preview/managedClusters.json#L6939-L6955). AKS API versions since 2023-02-02preview use the field [`networkProfile.networkDataplane=cilium`](https://github.com/Azure/azure-rest-api-specs/blob/06dbe269f7d9c709cc225c92358b38c3c2b74d60/specification/containerservice/resource-manager/Microsoft.ContainerService/aks/preview/2023-02-02-preview/managedClusters.json#L7152-L7173) to enable Azure CNI Powered by Cilium.
## Create a new AKS Cluster with Azure CNI Powered by Cilium

### Option 1: Assign IP addresses from an overlay network

Use the following commands to create a cluster with an overlay network and Cilium. Replace the values for `<clusterName>`, `<resourceGroupName>`, and `<location>`:

```azurecli-interactive
az aks create \
    --name <clusterName> \
    --resource-group <resourceGroupName> \
    --location <location> \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --pod-cidr 192.168.0.0/16 \
    --network-dataplane cilium \
    --generate-ssh-keys
```

> [!NOTE]
> The `--network-dataplane cilium` flag replaces the deprecated `--enable-ebpf-dataplane` flag used in earlier versions of the aks-preview CLI extension.

### Option 2: Assign IP addresses from a virtual network

Run the following commands to create a resource group and virtual network with a subnet for nodes and a subnet for pods.

```azurecli-interactive
# Create the resource group
az group create --name <resourceGroupName> --location <location>
```

```azurecli-interactive
# Create a virtual network with a subnet for nodes and a subnet for pods
az network vnet create --resource-group <resourceGroupName> --location <location> --name <vnetName> --address-prefixes <address prefix, example: 10.0.0.0/8> -o none
az network vnet subnet create --resource-group <resourceGroupName> --vnet-name <vnetName> --name nodesubnet --address-prefixes <address prefix, example: 10.240.0.0/16> -o none
az network vnet subnet create --resource-group <resourceGroupName> --vnet-name <vnetName> --name podsubnet --address-prefixes <address prefix, example: 10.241.0.0/16> -o none
```

Create the cluster using `--network-dataplane cilium`:

```azurecli-interactive
az aks create \
    --name <clusterName> \
    --resource-group <resourceGroupName> \
    --location <location> \
    --max-pods 250 \
    --network-plugin azure \
    --vnet-subnet-id /subscriptions/<subscriptionId>/resourceGroups/<resourceGroupName>/providers/Microsoft.Network/virtualNetworks/<vnetName>/subnets/nodesubnet \
    --pod-subnet-id /subscriptions/<subscriptionId>/resourceGroups/<resourceGroupName>/providers/Microsoft.Network/virtualNetworks/<vnetName>/subnets/podsubnet \
    --network-dataplane cilium \
    --generate-ssh-keys
```

### Option 3: Assign IP addresses from the Node Subnet

> [!NOTE]
> Azure CLI version 2.69.0 or later is required. Run `az --version` to see the currently installed version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).

Create a cluster using [node subnet](concepts-network-legacy-cni.md#azure-cni-node-subnet) with a Cilium dataplane:

```azurecli-interactive
az aks create \
    --name <clusterName> \
    --resource-group <resourceGroupName> \
    --location <location> \
    --network-plugin azure \
    --network-dataplane cilium \
    --generate-ssh-keys
```

## Frequently asked questions

- **Can I customize Cilium configuration?**

    No, AKS manages the Cilium configuration and it can't be modified. We recommend that customers who require more control use [AKS BYO CNI](./use-byo-cni.md) and install Cilium manually.

- **Can I use `CiliumNetworkPolicy` custom resources instead of Kubernetes `NetworkPolicy` resources?**

    L3 and L4 `CiliumNetworkPolicy` are supported and can be used alongside Kubernetes `NetworkPolicy` resources.

    Customers may use FQDN filtering and Layer 7 Policies as part of the [Advanced Container Networking Services](./advanced-container-networking-services-overview.md) feature bundle.

- **Can I use `ClusterwideCiliumNetworkPolicy`?**

    `ClusterwideCiliumNetworkPolicy` is not supported.

- **Which Cilium features are supported in Azure managed CNI? Which of those require Advanced Container Networking Services?**

    | Supported Feature | w/o ACNS | w/ ACNS |
    | ----------------- | -------- | ------- |
    | Cilium Endpoint Slices | ✔️ | ✔️ |
    | K8s Network Policies | ✔️ | ✔️ |
    | Cilium L3/L4 Network Policies | ✔️ | ✔️ |
    | FQDN Filtering | ❌ | ✔️ |
    | L7 Network Policies (HTTP/gRPC/Kafka) | ❌ | ✔️ |
    | Container Network Observability (Metrics and Flow logs ) | ❌ | ✔️ |

- **Why is traffic being blocked when the `NetworkPolicy` has an `ipBlock` that allows the IP address?**

    A limitation of Azure CNI Powered by Cilium is that a `NetworkPolicy`'s `ipBlock` can't select pod or node IPs.

    For example, this `NetworkPolicy` has an `ipBlock` that allows all egress to `0.0.0.0/0`:
    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: example-ipblock
    spec:
      podSelector: {}
      policyTypes:
        - Egress
      egress:
        - to:
          - ipBlock:
              cidr: 0.0.0.0/0 # This will still block pod and node IPs.
    ```

    However, when this `NetworkPolicy` is applied, Cilium blocks egress to pod and node IPs even though the IPs are within the `ipBlock` CIDR.

    As a workaround, you can add `namespaceSelector` and `podSelector` to select pods. This example selects all pods in all namespaces:
    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: example-ipblock
    spec:
      podSelector: {}
      policyTypes:
        - Egress
      egress:
        - to:
          - ipBlock:
              cidr: 0.0.0.0/0
          - namespaceSelector: {}
          - podSelector: {}
    ```

    > [!NOTE]
    > It isn't currently possible to specify a `NetworkPolicy` with an `ipBlock` to allow traffic to node IPs.
- **Does AKS configure CPU or memory limits on the Cilium `daemonset`?**

    No, AKS doesn't configure CPU or memory limits on the Cilium `daemonset` because Cilium is a critical system component for pod networking and network policy enforcement.

- **Does Azure CNI powered by Cilium use Kube-Proxy?**

    No, AKS clusters created with network dataplane as Cilium don't use Kube-Proxy.
    If the AKS clusters are on [Azure CNI Overlay](./azure-cni-overlay.md) or [Azure CNI with dynamic IP allocation](./configure-azure-cni-dynamic-ip-allocation.md) and are upgraded to AKS clusters running Azure CNI powered by Cilium, new nodes workloads are created without kube-proxy. Older workloads are also migrated to run without kube-proxy as a part of this upgrade process.

## Next steps

Learn more about networking in AKS in the following articles:

* [Upgrade Azure CNI IPAM modes and Dataplane Technology](upgrade-azure-cni.md).

* [Use a static IP address with the Azure Kubernetes Service (AKS) load balancer](static-ip.md)

* [Use an internal load balancer with Azure Container Service (AKS)](internal-lb.md)

* [Create a basic ingress controller with external network connectivity][aks-ingress-basic]

<!-- LINKS - Internal -->
[aks-ingress-basic]: ingress-basic.md