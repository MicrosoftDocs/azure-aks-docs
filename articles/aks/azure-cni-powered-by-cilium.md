---
title: Configure Azure CNI Powered by Cilium in Azure Kubernetes Service (AKS)
description: Learn how to create an Azure Kubernetes Service (AKS) cluster with Azure CNI Powered by Cilium. This networking configuration is the default for AKS Automatic clusters and available as an option for AKS Standard clusters.
author: schaffererin
ms.author: schaffererin
ms.subservice: aks-networking
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.custom: references_regions, devx-track-azurecli, build-2023
ms.date: 08/05/2026
# Customer intent: As a cloud architect, I want to configure an AKS cluster with Azure CNI Powered by Cilium, so that I can achieve high-performance networking and enhanced security for my containerized applications.
---

# Configure Azure CNI Powered by Cilium in Azure Kubernetes Service (AKS)

> [!div class="nextstepaction"]
> [Deploy and Explore](https://go.microsoft.com/fwlink/?linkid=2321738)

Azure CNI Powered by Cilium combines the robust control plane of Azure Container Networking Interface (CNI) with the data plane of [Cilium](https://cilium.io/) to provide high-performance networking and security.

> [!TIP]
> **AKS Automatic** uses Azure CNI Overlay powered by Cilium as its **default virtual network** - it's preconfigured on every AKS Automatic cluster with no extra setup required. If you're using AKS Standard and want this configuration, follow the steps in this article. For more information, see [What is Azure Kubernetes Service Automatic?](intro-aks-automatic.md)

Azure CNI Powered by Cilium provides the following benefits by making use of eBPF programs loaded into the Linux kernel and a more efficient API object structure:

- Functionality equivalent to existing Azure CNI and Azure CNI Overlay plugins
- Improved service routing
- More efficient network policy enforcement
- Better observability of cluster traffic
- Support for larger clusters (more nodes, pods, and services)

## IP Address Management (IPAM) with Azure CNI Powered by Cilium

> [!NOTE]
> If you're using **AKS Automatic**, the overlay network option is the default and is preconfigured for you. The following configuration options apply to **AKS Standard** clusters only.

You can use Azure CNI Powered by Cilium with three IP address management (IPAM) options:

- [Azure CNI Overlay](./concepts-network-azure-cni-overlay.md)
- [Azure CNI Pod Subnet](./concepts-network-azure-cni-pod-subnet.md)
- [Azure CNI Node Subnet](./concepts-network-legacy-cni.md#azure-cni-node-subnet), a legacy option

For most scenarios, use Azure CNI Overlay. If you need direct access to pod IP addresses from connected networks, use Azure CNI Pod Subnet. For more information, see [Choose an IPAM option for AKS](./concepts-network-cni-overview.md#choose-an-ipam-option-for-aks).

## Supported Kubernetes and Cilium versions

The following table shows the minimum Cilium version for each Kubernetes version. These version requirements apply to both AKS Automatic and AKS Standard clusters using Azure CNI Powered by Cilium.

| Kubernetes version | Minimum Cilium version |
| ------------------ | ---------------------- |
| 1.31 (LTS) | 1.16.16 |
| 1.32 (LTS) | 1.17.9 |
| 1.33 (LTS) | 1.17.9 |
| 1.34 | 1.18.6 |
| 1.35 | 1.18.6 |
| 1.36 | 1.18.9 |

For more information on AKS versioning and release timelines, see [Supported Kubernetes Versions](./supported-kubernetes-versions.md).

## Network policy enforcement with Cilium

Cilium enforces [network policies to allow or deny traffic between pods](./operator-best-practices-network.md#control-traffic-flow-with-network-policies). With Cilium, you don't need to install a separate network policy engine such as Azure Network Policy Manager or Calico.

## Local Redirect Policy (LRP)

Local Redirect Policy (LRP) redirects pod traffic destined for an IP address and port or a Kubernetes service to a backend pod on the same node.

LRP is supported from Kubernetes v1.29 and above. For LRP to work with Advanced Container Networking Services (ACNS) - FQDN Filtering, the Cilium Network Policy egress labels need to match with node-local DNS cache pod labels.

The following `CiliumLocalRedirectPolicy` redirects DNS traffic sent to the `kube-dns` service to node-local DNS cache pods on the same node. If your cluster uses a different DNS service name or namespace, update `serviceName` and `namespace` to match your cluster.

```yaml
apiVersion: cilium.io/v2
kind: CiliumLocalRedirectPolicy
metadata:
  name: dns-to-nodelocal
  namespace: kube-system
spec:
  redirectFrontend:
    serviceMatcher:
      serviceName: kube-dns
      namespace: kube-system
  redirectBackend:
    localEndpointSelector:
      matchLabels:
        k8s-app: node-local-dns
    toPorts:
      - port: "53"
        name: dns
        protocol: UDP
      - port: "53"
        name: dns-tcp
        protocol: TCP
```

The following snippet shows the `toEndpoints` label selector in the `CiliumNetworkPolicy` egress rule, which must match the labels on the node-local DNS cache pods.

```yaml
...
- matchLabels:
    io.kubernetes.pod.namespace: kube-system
    k8s-app: node-local-dns
```

## Limitations

Azure CNI Powered by Cilium currently has the following limitations:

- Available only for Linux and not for Windows.
- Network policies can't use `ipBlock` to allow access to node or pod IPs. For details and recommended workarounds, see [frequently asked questions](#frequently-asked-questions).
- For Cilium versions 1.16 or earlier, multiple Kubernetes services can't use the same host port with different protocols (for example, TCP or UDP) ([Cilium issue #14287](https://github.com/cilium/cilium/issues/14287)).
- Network policies aren't applied to pods using host networking (`spec.hostNetwork: true`) because these pods use the host identity instead of having individual identities.
- Outbound Network Sercutity Group (NSG) rules that block internet or Azure service access may prevent Cilium diagnostic logs from being exported. Customers using restrictive outbound policies should allow egress to the Azure Monitor service tag to ensure proper telemetry, diagnostics, and troubleshooting data collection.
- Cilium Endpoint Slices are supported in Kubernetes version 1.32 and above. Cilium Endpoint Slices don't support configuration of how Cilium Endpoints are grouped. Priority namespace through `cilium.io/ces-namespace` isn't supported.
- Cilium uses Cilium identities as a unique identity for provisioning endpoints, so high-churning workloads such as Spark jobs generate high count of Cilium identities. To avoid workloads hitting Cilium identity limits (65535), excluding Spark job's labels like `!spark-app-name` and `!spark-app-selector` in the Cilium configmap can significantly reduce Cilium identity generation. For more details on Cilium identity exclusion rules, check [the official Cilium label documentation](https://docs.cilium.io/en/stable/operations/performance/scalability/identity-relevant-labels/#excluding-labels).

## Enable Advanced Container Networking Services for observability and security

To gain capabilities such as observability into your network traffic and security features like Fully Qualified Domain Name (FQDN) based filtering and Layer 7 based network policies on your cluster, consider enabling [Advanced Container Networking services](./advanced-container-networking-services-overview.md) on your clusters.

This recommendation applies to both AKS Automatic and AKS Standard clusters. If you're using AKS Automatic, the base networking is already preconfigured. Enabling ACNS adds container network observability and FQDN filtering. Other ACNS features, including L7 network policies, WireGuard encryption, mTLS encryption, and eBPF Host Routing, require additional configuration. Some features also have version, operating system, or preview requirements. For more information, see the [feature support table](#which-cilium-features-does-azure-cni-powered-by-cilium-support-which-features-require-advanced-container-networking-services).

## Cluster configuration by AKS cluster mode

The steps required to use Azure CNI Powered by Cilium depend on your AKS cluster mode: AKS Automatic or AKS Standard.

### AKS Automatic clusters

Azure CNI Overlay powered by Cilium is the default virtual network for AKS Automatic clusters. This configuration is fully managed - you don't need to provision a virtual network, select a CNI plugin, or specify a data plane. AKS Automatic also preconfigures LocalDNS, a managed NAT gateway for egress, and the application routing add-on for ingress.

No configuration steps are required. If you want to add advanced observability or security features on top of the existing networking, see Advanced Container Networking Services.

### AKS Standard clusters

On AKS Standard, Azure CNI Powered by Cilium is an optional networking configuration. Use the steps in this article to create a cluster with the Cilium data plane. You can choose from overlay, virtual network, or node subnet IP assignment modes.

## Prerequisites

The required Azure CLI version varies by IP assignment method:

| IP assignment method | Required Azure CLI version |
| -------------------- | -------------------------- |
| [Overlay network](#option-1-assign-ip-addresses-from-an-overlay-network) | 2.48.1 or later |
| [Virtual network](#option-2-assign-ip-addresses-from-a-virtual-network) | 2.48.1 or later |
| [Node subnet](#option-3-assign-ip-addresses-from-the-node-subnet) | 2.69.0 or later |

Run `az --version` to see the currently installed version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).

- Review the [AKS CNI networking prerequisites](./concepts-network-cni-overview.md#aks-cni-networking-prerequisites). Unless you use a network isolated cluster, the virtual network must allow outbound connectivity to required endpoints. Address ranges can't overlap reserved AKS ranges or connected networks, and node subnets can't be delegated.
- To use customer-managed subnets, the cluster identity needs Network Contributor permissions, or equivalent custom permissions, on the subnets. The user creating the cluster must have permission to create the required role assignments. If you associate network security groups with the subnets, ensure that their rules allow the required node and pod traffic.

## Create a new AKS Cluster with Azure CNI Powered by Cilium

The following sections use the [`az aks create`][az-aks-create] command to create an AKS Standard cluster and assign IP addresses. If you're using AKS Automatic, this configuration is already applied - no cluster creation steps are required for networking.

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

The `--network-dataplane cilium` flag replaces the deprecated `--enable-ebpf-dataplane` flag used in earlier versions of the aks-preview CLI extension.

### Option 2: Assign IP addresses from a virtual network

Run the following commands to create a resource group and virtual network with a subnet for nodes and a subnet for pods.

```azurecli-interactive
# Create the resource group
az group create --name <resourceGroupName> --location <location>
```

```azurecli-interactive
# Create a virtual network with a subnet for nodes and a subnet for pods
az network vnet create \
  --resource-group <resourceGroupName> \
  --location <location> \
  --name <vnetName> \
  --address-prefixes <address prefix, example: 10.0.0.0/8> \
  -o none
az network vnet subnet create \
  --resource-group <resourceGroupName> \
  --vnet-name <vnetName> \
  --name nodesubnet \
  --address-prefixes <address prefix, example: 10.240.0.0/16> \
  -o none
az network vnet subnet create \
  --resource-group <resourceGroupName> \
  --vnet-name <vnetName> \
  --name podsubnet \
  --address-prefixes <address prefix, example: 10.241.0.0/16> \
  -o none
```

Create the cluster using the [`az aks create`](/cli/azure/aks#az_aks_create) command with `--network-dataplane cilium` to specify the Cilium data plane. Replace the values for `<clusterName>`, `<resourceGroupName>`, `<location>`, `<subscriptionId>`, and `<vnetName>`, and ensure that the `--vnet-subnet-id` and `--pod-subnet-id` values point to the correct subnets created in the previous step.

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

Create a cluster using [node subnet](concepts-network-legacy-cni.md#azure-cni-node-subnet) with a Cilium data plane:

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

### Is Azure CNI Powered by Cilium available on AKS Automatic clusters?

Yes. Azure CNI Overlay powered by Cilium is the **default virtual network** on every AKS Automatic cluster and requires no configuration. AKS Automatic also preconfigures LocalDNS and a managed NAT gateway for egress. If you want additional observability or security features such as FQDN filtering, L7 network policies, or Wireguard encryption, you can enable Advanced Container Networking Services on your AKS Automatic cluster.

### Can I use `CiliumNetworkPolicy` custom resources instead of Kubernetes `NetworkPolicy` resources?

L3 and L4 `CiliumNetworkPolicy` are supported and can be used alongside Kubernetes `NetworkPolicy` resources.

Customers might use FQDN filtering and Layer 7 policies as part of the [Advanced Container Networking Services](./advanced-container-networking-services-overview.md) feature bundle.

### Can I use `CiliumClusterwideNetworkPolicy`?

Yes, Azure CNI Powered by Cilium supports `CiliumClusterwideNetworkPolicy`.  

The following sample policy allows ingress traffic on TCP port 80 to pods with the label `role: backend` from pods with the label `role: frontend`.

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: "l4-rule-ingress-backend-frontend"
spec:
  endpointSelector:
    matchLabels:
      role: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            role: frontend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
```

### Which Cilium features does Azure CNI Powered by Cilium support? Which features require Advanced Container Networking Services?

| Supported feature | Without ACNS | With ACNS | Requirements and configuration |
| ----------------- | ------------ | --------- | ------------------------------ |
| Cilium Endpoint Slices | Supported ✔️ | Supported ✔️ | Requires Kubernetes 1.32 or later. |
| Kubernetes Network Policies | Supported ✔️ | Supported ✔️ | None. |
| Local Redirect Policy | Supported ✔️ | Supported ✔️ | Requires Kubernetes 1.29 or later. |
| Cilium L3/L4 Network Policies | Supported ✔️ | Supported ✔️ | None. |
| Cilium Clusterwide Network Policy | Supported ✔️ | Supported ✔️ | None. |
| FQDN filtering | Not supported ❌ | Supported ✔️ | Requires Kubernetes 1.29 or later. Enabled by default with ACNS. |
| L7 network policies (HTTP/gRPC/Kafka) | Not supported ❌ | Supported ✔️ | Requires Kubernetes 1.29 or later and the `L7` advanced network policy option. |
| Container Network Observability (metrics and flow logs) | Not supported ❌ | Supported ✔️ | Enabled with ACNS. |
| WireGuard encryption | Not supported ❌ | Supported ✔️ | Requires explicit WireGuard configuration and UDP port 51871 between nodes. |
| mTLS encryption | Not supported ❌ | Supported in preview | Requires Kubernetes 1.34 or later, Cilium 1.18 or later, preview registration, and explicit mTLS configuration. |
| eBPF Host Routing | Not supported ❌ | Supported ✔️ | Requires Kubernetes 1.33 or later, Azure CLI 2.71 or later, Azure Linux 3.0 or Ubuntu 24.04, and explicit `BpfVeth` configuration. |

For feature-specific setup instructions and limitations, see [Advanced Container Networking Services](./advanced-container-networking-services-overview.md).

### Can the Cilium ConfigMap be modified?

Only [label exclusion](https://docs.cilium.io/en/stable/operations/performance/scalability/identity-relevant-labels/#excluding-labels) is supported for Azure CNI Powered by Cilium. This ConfigMap exists in the `kube-system` namespace as `cilium-config`. Addition of labels persists across cluster restarts, upgrades, and reconciliation. Changes to other values in the ConfigMap are not supported.

### Why is traffic being blocked when the `NetworkPolicy` has an `ipBlock` that allows the IP address?

A limitation of Azure CNI Powered by Cilium is that a `NetworkPolicy` `ipBlock` can't select pod or node IPs.

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

Even with `cidr: 0.0.0.0/0`, Cilium blocks egress to pod and node IPs because `ipBlock` can't select those addresses.

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

It isn't currently possible to specify a `NetworkPolicy` with an `ipBlock` to allow traffic to node IPs.

### Does AKS configure CPU or memory limits on the Cilium `daemonset`?

No, AKS doesn't configure CPU or memory limits on the Cilium `daemonset` because Cilium is a critical system component for pod networking and network policy enforcement.

### Does Azure CNI Powered by Cilium use kube-proxy?

No, AKS clusters created with network data plane as Cilium don't use `kube-proxy`.

This behavior applies to all Kubernetes versions supported by Azure CNI Powered by Cilium, with no separate AKS version constraint. The data plane upgrade is supported only on Linux clusters and requires node auto-provisioning (NAP) to be disabled during the update.

If you upgrade AKS clusters on [Azure CNI Overlay](./azure-cni-overlay.md) or [Azure CNI with dynamic IP allocation](./configure-azure-cni-dynamic-ip-allocation.md) to AKS clusters running Azure CNI Powered by Cilium, workloads on new nodes are created without `kube-proxy`. Workloads on existing nodes are also migrated to run without `kube-proxy` as a part of this upgrade process.

### **Is AKS Local DNS supported with Azure CNI Powered by Cilium?**

Yes, network policies must explicitly allow pod egress to the LocalDNS IP address.

The following policy allows egress to the LocalDNS CIDR `169.254.10.0/24` on UDP and TCP port 53 and to the `host` entity on the same ports.

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "allow-azure-dns-egress"
  namespace: default
spec:
  endpointSelector:
    matchLabels: {} # This selects ALL pods in the namespace
  egress:
    - toCIDR:
        - 169.254.10.0/24
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
            - port: "53"
              protocol: TCP
    - toEntities:
        - host
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
            - port: "53"
              protocol: TCP
```

## Dual-stack networking with Azure CNI Powered by Cilium

You must have Kubernetes version 1.29 or greater. This applies to both AKS Automatic and AKS Standard clusters.

You can deploy your dual-stack AKS clusters with Azure CNI Powered by Cilium. This feature also allows you to control your IPv6 traffic with the Cilium Network Policy engine.

### Set up Overlay clusters with Azure CNI Powered by Cilium

Create a cluster with Azure CNI Overlay using the [`az aks create`][az-aks-create] command. Make sure to use the argument `--network-dataplane cilium` to specify the Cilium data plane.

```azurecli-interactive
clusterName="myOverlayCluster"
resourceGroup="myResourceGroup"
location="westcentralus"

az aks create \
  --name $clusterName \
  --resource-group $resourceGroup \
  --location $location \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --network-dataplane cilium \
  --ip-families ipv4,ipv6 \
  --generate-ssh-keys
```

## Related content

For more information about AKS networking and AKS Automatic, see the following resources:

- [What is AKS Automatic?](intro-aks-automatic.md)
- [Quickstart: Create an AKS Automatic cluster](./automatic/quick-automatic-managed-network.md)
- [Upgrade Azure CNI IPAM modes and data plane technology](update-azure-cni.md).
- [Use a static IP address with the Azure Kubernetes Service (AKS) load balancer](static-ip.md)
- [Use an internal load balancer with Azure Kubernetes Service (AKS)](internal-lb.md)
- [Ingress concepts for Azure Kubernetes Service (AKS)](concepts-network-ingress.md)

<!-- LINKS - Internal -->
[az-aks-create]: /cli/azure/aks#az-aks-create
