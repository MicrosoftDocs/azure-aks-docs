---
title: Enable AKSLocalDNS in Azure Kubernetes Service (AKS)
description: Learn how to improve your DNS lookup latency using AKSLocalDNS, enabling and modifying the endpoints as required by your application
ms.subservice: aks-networking
author: vaibhavarora
ms.topic: how-to
ms.date: 06/05/2025
ms.author: vaibhavarora

# Customer intent
As a cluster operator or developer, I want to improve my DNS lookup latency and CoreDNS reliability.
---

# Enable AKS LocalDNS in Azure Kubernetes Service (Preview)

## Overview

AKS LocalDNS is an advanced feature that improves Domain Name System (DNS) resolution performance and reliability in Azure Kubernetes Service (AKS) clusters. LocalDNS deploys a DNS proxy on each node. This proxy reduces DNS query latency and lowers reliance on the cluster’s CoreDNS pods. LocalDNS is especially helpful for large clusters or environments with high DNS query volumes, where cluster DNS can become a bottleneck.

When you enable LocalDNS, AKS installs a local DNS cache on each node as a systemd service. Pods on the node send DNS queries to this local cache, which resolves them directly. This setup reduces network hops and speeds up DNS responses. Local resolution also helps prevent issues with conntrack table exhaustion, because fewer connections are tracked at the node level. LocalDNS can serve cached responses during upstream DNS outages, which keeps pod traffic running for a set period.

### Key Capabilities

- **DNS resolution:**  
    Each AKS node runs a `localdns` systemd service. Workloads on the node send DNS queries to this service, which resolves them locally. This reduces network hops and speeds up DNS lookups.

- **Customizable DNS forwarding:**  
    You can use `kubeDNSOverrides` and `vnetDNSOverrides` to control DNS behavior in the cluster.

- **Reduced conntrack table exhaustion:**  
    Pods send DNS queries to the `localdns` service on the same node. This approach doesn't create new entries in the conntrack table. It helps reduce [conntrack races](https://github.com/kubernetes/kubernetes/issues/56903) and prevents User Datagram Protocol (UDP) connections from filling up the table, which can cause dropped or rejected connections.

- **TCP upgrades:**  
    The connection from the `localdns` cache to the cluster’s CoreDNS service uses Transmission Control Protocol (TCP). TCP allows for connection rebalancing and removes conntrack table entries when the server closes the connection. This is an improvement over UDP connections, which have a default 30-second timeout. Applications don't need changes, because the `localdns` service still listens for UDP traffic.

- **Failover and caching:**  
    The local DNS proxy includes failover and caching features. Options like `serveStale`, `cacheDurationInSeconds`, and `forwardPolicy` help maintain DNS availability and performance, even during upstream DNS outages or high load.

- **Protocol control:**  
    You can set the DNS query protocol (such as PreferUDP or ForceTCP) for each domain. This flexibility lets you optimize DNS traffic for specific domains or meet network requirements.

By using AKS LocalDNS, you get faster and more reliable DNS resolution for your workloads, reduce the risk of DNS-related outages, and gain more control over DNS traffic in your AKS environment.

## Before you begin
* This article assumes that you have an existing AKS cluster with Kubernetes versions 1.33+. If you need an AKS cluster, you can create one using [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* This article requires version 2.74.0 or later of the Azure CLI. If you're using Azure Cloud Shell, the latest version is already installed there.
* This article requires the `aks-preview` Azure CLI extension version 9.0.0b4 or later

## Setting up the `localdnsconfig` file
In order to set up localDNS in your cluster, you need to build a config file called `localdnsconfig.json`. This file includes the required plugins and support for domains specific rules. 
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


## Enable AKSLocalDNS
You can enable AKSLocalDNS for new and existing clusters at a cluster or node pool level.

### Enable localDNS in a new cluster

```console
az aks create --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
 ```

> [!IMPORTANT]
> If enabling localDNS at cluster create, the configuration will only apply to the nodes in the initial node pools. For node pools added in the future, please enable localDNS on each as outlined in the following sections

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

These changes require nodes to be reimaged for the changes to apply. This can cause disruption to the pods currently running in the cluster.

## Verify if localDNS is enabled
Once LocalDNS is enabled, you can verify its operation by running DNS queries from pods in the specified node pool and inspecting the `SERVER` field in the responses to confirm LocalDNS addresses are returned (169.254.10.10 or 169.254.10.11)

## Disable localDNS
To disable localDNS, you need to update the `localdnsconfig.json` file to use `"mode":"Disabled"`. Once the file is updated, you can apply the configuration to the cluster/node pool to enable the change.

### Disable localDNS in an existing cluster

```console
az aks update --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
```

### Disable localDNS in an existing node pool

```console
az aks nodepool update --name mynodepool1 --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
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