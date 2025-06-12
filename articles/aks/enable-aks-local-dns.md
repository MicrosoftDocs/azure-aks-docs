---
title: Enable LocalDNS in Azure Kubernetes Service (AKS)
description: Learn how to improve your DNS resolution performance and resiliency in AKS using localDNS.
ms.subservice: aks-networking
author: vaibhavarora
ms.topic: how-to
ms.date: 06/05/2025
ms.author: vaibhavarora

# Customer intent
As a cluster operator or developer, I want to improve my DNS resolution performance and resiliency for my AKS cluster.
---

# Enable LocalDNS in Azure Kubernetes Service (Preview)

## Overview

LocalDNS is an advanced feature that improves Domain Name System (DNS) resolution performance and reliability in Azure Kubernetes Service (AKS) clusters. LocalDNS deploys a DNS proxy on each node. This proxy reduces DNS query latency and lowers reliance on the cluster’s CoreDNS pods. LocalDNS is especially helpful for large clusters or environments with high DNS query volumes, where cluster DNS can become a bottleneck.

When you enable LocalDNS, AKS installs a localDNS cache on each node as a systemd service. Pods on the node send DNS queries to this local cache, which resolves them directly. This setup reduces network hops and speeds up DNS responses. Local resolution also helps prevent issues with conntrack table exhaustion, because fewer connections are tracked at the node level. LocalDNS can serve cached responses during upstream DNS outages, which keep pod traffic running for a set period.

<!-- Add architecture diagram for LocalDNS here -->

### Key Capabilities

- **DNS resolution:**  
    Each AKS node runs a `localdns` systemd service. Workloads on the node send DNS queries to this service, which resolves them locally. This setup reduces network hops and speeds up DNS lookups.

- **Customizable DNS forwarding:**  
    You can use `kubeDNSOverrides` and `vnetDNSOverrides` to control DNS behavior in the cluster.

- **Reduced conntrack table exhaustion:**  
    Pods send DNS queries to the `localdns` service on the same node. This approach doesn't create new entries in the conntrack table. It helps reduce [conntrack races](https://github.com/kubernetes/kubernetes/issues/56903) and prevents User Datagram Protocol (UDP) connections from filling up the table, which can cause dropped or rejected connections.

- **TCP upgrades:**  
    The connection from the `localdns` cache to the cluster’s CoreDNS service uses Transmission Control Protocol (TCP). TCP allows for connection rebalancing and removes conntrack table entries when the server closes the connection (in contrast to UDP connections, which have a default 30-second timeout). Applications don't need changes, because the `localdns` service still listens for UDP traffic.

- **Failover and caching:**  
    The local DNS proxy includes failover and caching features. Options like `serveStale`, `cacheDurationInSeconds`, and `forwardPolicy` help maintain DNS availability and performance, even during upstream DNS outages or high load.

- **Protocol control:**  
    You can set the DNS query protocol (such as PreferUDP or ForceTCP) for each domain. This flexibility lets you optimize DNS traffic for specific domains or meet network requirements.

By using LocalDNS, you get faster and more reliable DNS resolution for your workloads, reduce the risk of DNS-related outages, and gain more control over DNS traffic in your AKS environment.

## Before you begin
* This article assumes that you have an existing AKS cluster with Kubernetes versions 1.33+. If you need an AKS cluster, you can create one using [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* This article requires version 2.74.0 or later of the Azure CLI. If you're using Azure Cloud Shell, the latest version is already installed there.
* This article requires the `aks-preview` Azure CLI extension version 9.0.0b4 or later

## Enable LocalDNS
To modify the coreDNS plugins and to add custom server blocks, refer to [Configuring LocalDNS](#configure-localdnsconfigjson).

### Enable localDNS in a new cluster

```console
az aks create --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
 ```

> [!IMPORTANT]
> When you enable localDNS during cluster create, the configuration will only apply to the nodes in the initial node pools. For future node pools, enable localDNS on each as outlined in the following sections

### Enable localDNS in an existing cluster

```console
az aks update --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
```
     
### Enable localDNS in a new node pool

```console
az aks nodepool add --name mynodepool1 --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
```
     
### Enable localDNS in an existing node pool

```console
az aks nodepool update --name mynodepool1 --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
```

> [!IMPORTANT]
> Enabling localDNS on a node pool will trigger a reimage operation on the nodes for the new setting to take effect.

## Verify if localDNS is enabled
Once LocalDNS is enabled, you can verify its operation by running DNS queries from pods in the specified node pool and inspecting the `SERVER` field in the responses to confirm LocalDNS addresses are returned (169.254.10.10 or 169.254.10.11)

## Disable localDNS
To disable localDNS, you need to update the `localdnsconfig.json` file to use `"mode":"Disabled"`. Once the file is updated, you can apply the configuration to the node pool to update with the change.

### Disable localDNS in a node pool

```console
az aks nodepool update --name mynodepool1 --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
```

## Current Limitations
* This configuration is only supported on Linux node pools
* Currently, you require Kubernetes versions 1.33+ to use the localdns feature

## Configure `localdnsconfig.json`
With localDNS, you can define custom server blocks and can use supported plugins as outlined in the table below. To set them up in your node pool, you need to create a `localdnsconfig.json` file with the configurations.

### Setting `Mode` for localDNS
```json
{
  "localDNSProfile":{
    "mode":"Preferred"
  }
}
```
The `mode` for localDNS specified if localDNS is enabled or not. It allows three values:
* `Required`: In this mode, LocalDNS is enforced, but it fails when incompatible. If any settings like node pool type do not meet the requirement for localDNS, it will automatically 
* `Preferred`: 
* `Disabled`: 

### Defining a Server Block in localDNS
With localDNS, you can use the following list of default server blocks or you can define your own (eg: bing.com). localDNS will match the queries to the most specific server block based on the exact domain being queried and not just partial matches. 
* `vNetDNSOverrides`: addresses queries from pods using dnsPolicy: default or from the kubelet agent running on the node.
* `kubeDNSOverrides`: addresses queries from pods with dnsPolicy: ClusterFirst.
### Supported Plugins
| Plugin                        | Description                                                                                   | Allwed Inputs                      | Documentation Link                                    |
|-------------------------------|-----------------------------------------------------------------------------------------------|------------------------------------|-------------------------------------------------------|
| `queryLogging`                | Define the logging level for DNS queries.                                                     | `Error` `Log`                      | [Log Plugin](https://coredns.io/plugins/log/)         |
| `protocol`                    | Sets the protocol used for DNS queries (UDP/TCP preference).                                  | `PreferUDP` `ForceTCP`             | [Forward Plugin](https://coredns.io/plugins/forward/) |
| `forwardDestination`          | Specifies the DNS server to forward queries to.                                               | `VnetDNS` `ClusterCoreDNS`         | [Forward Plugin](https://coredns.io/plugins/forward/) |
| `forwardPolicy`               | Determines the policy to use when selecting the upstream DNS server. Default is `random`      | `random` `round_robin` `Sequential`| [Forward Plugin](https://coredns.io/plugins/forward/) |
| `maxConcurrent`               | Maximum number of concurrent DNS queries handled by the proxy.                                | Integer (default:`1000`)           | [Forward Plugin](https://coredns.io/plugins/forward/) |
| `cacheDurationInSeconds`      | Maximum TTL in seconds for which DNS responses are cached                                     | Integer (default:`3600`)           | [Cache Plugin](https://coredns.io/plugins/cache)      |
| `serveStaleDurationInSeconds` | Duration (in seconds) to serve stale DNS responses if upstream is unavailable.                | Integer (default:`3600`)           | [Cache Plugin](https://coredns.io/plugins/cache)      |
| `serveStale`                  | Policy for serving stale DNS responses during upstream failures.                              | `Verify` `immediate`               | [Cache Plugin](https://coredns.io/plugins/cache)      |

### Sample `localdnsconfig.json` file
```json
{
  "localDNSProfile": {
    "mode": "Preferred",
    "vnetDNSOverrides": {
      ".": {
        "queryLogging": "Error",
        "protocol": "PreferUDP",
        "forwardDestination": "VnetDNS",
        "forwardPolicy": "Sequential"
        "maxConcurrent": 1000,
        "cacheDurationInSeconds": 3600,
        "serveStaleDurationInSeconds": 3600,
        "serveStale": "Verify",
      }
      "cluster.local": {
        "queryLogging": "Error",
        "protocol": "ForceTCP",
        "forwardDestination": "ClusterCoreDNS",
        "forwardPolicy": "Sequential"
        "maxConcurrent": 1000,
        "cacheDurationInSeconds": 3600,
        "serveStaleDurationInSeconds": 3600,
        "serveStale": "Verify",
      }
    },
    "kubeDNSOverrides": {
      ".": {
        "queryLogging": "Error",
        "protocol": "PreferUDP",
        "forwardDestination": "ClusterCoreDNS",
        "forwardPolicy": "Sequential"
        "maxConcurrent": 1000,
        "cacheDurationInSeconds": 3600,
        "serveStaleDurationInSeconds": 3600,
        "serveStale": "Verify",
      }
      "cluster.local": {
        "queryLogging": "Error",
        "protocol": "ForceTCP",
        "forwardDestination": "ClusterCoreDNS",
        "forwardPolicy": "Sequential"
        "maxConcurrent": 1000,
        "cacheDurationInSeconds": 3600,
        "serveStaleDurationInSeconds": 3600,
        "serveStale": "Verify",
      }
    }
  }
}
```


## Next steps
For information on the CoreDNS project, see [the CoreDNS upstream project page][coredns].

To learn more about core network concepts, see [Network concepts for applications in AKS][concepts-network].

<!-- LINKS - external -->
[coredns]: https://coredns.io/
[corednsk8s]: https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/#coredns
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[kubectl-rollout]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#rollout
[coredns hosts]: https://coredns.io/plugins/hosts/
[coredns-troubleshooting]: https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/
[cluster-proportional-autoscaler]: https://github.com/kubernetes-sigs/cluster-proportional-autoscaler
[cluster-proportional-autoscaler-control-patterns]: https://github.com/kubernetes-sigs/cluster-proportional-autoscaler#control-patterns-and-configmap-formats

<!-- LINKS - internal -->
[concepts-network]: concepts-network.md
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md