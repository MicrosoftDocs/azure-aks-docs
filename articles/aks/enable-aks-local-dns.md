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

AKS LocalDNS is an advanced feature designed to optimize DNS resolution performance and reliability within Azure Kubernetes Service (AKS) clusters. By deploying a local DNS proxy on each node, AKS LocalDNS significantly reduces DNS query latency and minimizes reliance on the cluster CoreDNS pods. This architecture is especially advantageous for large-scale clusters or environments with high DNS query volumes, where cluster DNS can become a bottleneck.

When you enable the AKS LocalDNS feature, AKS deploys local cache on each node as a systemd service allowing for DNS queries from pods to be resolved locally on the node. This reduces network hops and improving overall query response times. This local resolution also helps prevent issues related to conntrack table exhaustion, as fewer connections are tracked at the node level. Additionally, the feature allows for stale-cache responses, improving resiliency during upstream DNS outages as the local cache will continue to serve pod traffic for a set period of time. 

### Key Capabilities

- **DNS resolution:**  
    Each AKS node runs a dedicated `localdns` systemd service, enabling DNS queries from workloads on the node to be resolved locally. This reduces network hops and improves response times for DNS lookups.

- **Customizable DNS forwarding:**
    Supports `kubeDNSOverrides` and `vnetDNSOverrides` for better control on DNS behavior in the cluster

- **Reduced Conntrack table exhaustion:**
    Pods will reach out to the `localdns` service running on the same node which does not create a new entry in the conntrack table. This helps reduce [conntrack races](https://github.com/kubernetes/kubernetes/issues/56903) and mitigates the issue of UDP connections filling up the table leading to dropped/rejected connections when the table gets exhausted.

- **Upgrades to TCP:**
    The connection from the `localdns` cache to the cluster coreDNS service has been upgraded to TCP allowing for rebalancing of every connection. This delivers reliability improvements as the conntrack table entry is removed when the connection is closed on the server side. This is an improvement compared to UDP connections which have a default 30s timeout. This however does not require any changes in the application since the localdns service listens for UDP traffic.

- **Failover and caching:**  
    The local DNS proxy includes robust failover mechanisms and caching capabilities. Features like `serveStale`, `cacheDurationInSeconds`, and `forwardPolicy` help maintain DNS availability and performance, even during upstream DNS outages or high load scenarios.

- **Protocol control:**  
    You can configure the DNS query protocol (such as PreferUDP or ForceTCP) on a per-domain basis. This flexibility allows you to optimize DNS traffic for specific domains or comply with network requirements.

By leveraging AKS LocalDNS, you can achieve faster, more reliable DNS resolution for your workloads, reduce the risk of DNS-related outages, and gain greater control over DNS traffic within your AKS environment.

## Before you begin
* This article assumes that you have an existing AKS cluster with Kubernetes versions 1.33+. If you need an AKS cluster, you can create one using [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* This article requires version 2.74.0 or later of the Azure CLI. If you're using Azure Cloud Shell, the latest version is already installed there.
* This article requires the `aks-preview` Azure CLI extension version 9.0.0b4 or later

## Setting up the `localdnsconfig` file
In order to set up localdns in your cluster, you need to build a config file called `localdnsconfig.json`. This file includes the required plugins and support for domains specific rules. 
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

### Enable localdns in a new cluster

```console
az aks create --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
 ```

> [!IMPORTANT]
> If enabling localdns at cluster create, the configuration will only apply to the nodes in the initial node pools. For node pools added in the future, please enable localdns on each as outlined in the following sections

### Enable localdns in an existing cluster

```console
az aks update --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
```
     
### Enable localdns in a new node pool

```console
az aks nodepool add --name mynodepool1 --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
```
     
### Enable localdns in an existing node pool

```console
az aks nodepool update --name mynodepool1 --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
```

These changes require nodes to be reimaged for the changes to apply. This can cause disruption to the pods currently running in the cluster.

## Verify if localdns is enabled
Once LocalDNS is enabled, you can verify its operation by running DNS queries from pods in the specified node pool and inspecting the `SERVER` field in the responses to confirm LocalDNS addresses are returned ( 169.254.10.10 or 169.254.10.11 )

## Disable localdns
To disable localdns, you need to update the `localdnsconfig.json` file to use `"mode":"Disabled"`. Once the file is updated, you can apply the configuration to the cluster/node pool to enable the change.

### Disable localdns in an existing cluster

```console
az aks update --cluster-name myAKSCluster --resource-group myResourceGroup --localdns-config ./localdnsconfig.json
```

### Disable localdns in an existing node pool

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