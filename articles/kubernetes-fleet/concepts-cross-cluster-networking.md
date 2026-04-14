---
title: "Cross-cluster networking for Azure Kubernetes Fleet Manager"
description: This article provides a conceptual overview of Cross-cluster networking for Azure Kubernetes Fleet Manager. 
ms.date: 04/14/2026
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: "As a platform engineer, I want to understand the supporting concepts for cross-cluster networking in Azure Kubernetes Fleet Manager, so that I know how and where I can use cross-cluster networking."
---

# Cross-cluster networking for Azure Kubernetes Fleet Manager (preview)

Azure Kubernetes Fleet Manager provides a dedicated cross-cluster networking solution that extends the Kubernetes datapath across multiple clusters. Using cross-cluster networking enables any connected cluster to communicate directly with endpoints on any other connected cluster with full network‑policy enforcement. Using cross-cluster networking allowing clusters to publish services such that any connected cluster can call them as if they were local.

Multiple cross-cluster network profiles can be created in Fleet Manager, with the only restriction being that member clusters can only participate in a single cross-cluster network. 

In this article, we introduce key concepts for cross-cluster networking for Azure Kubernetes Fleet Manager.

[!INCLUDE [preview features note](./includes/preview/preview-callout.md)]

## Prerequisites and limitations

* A cross-cluster network can have up to 255 member clusters.
* Fleet Manager member clusters can only participate in a single cross-cluster network at any time.
* Clusters must run Kubernetes v1.32 or above and have [Advanced Container Networking Services (ACNS)][aks-acns-enabled] with Cilium enabled.
* Clusters must be connected to a [single flat network][flat-network] (virtual network or multiple peered networks).
* Overlay networking with tunnels is not supported.
* Self-managed Cilium multi-cluster can't be deployed at the same time.
* ACNS sets the Cilium version and enabled features. These can't currently be directly modified.

## Foundational concepts

Cross-cluster networking for Azure Kubernetes Fleet Manager provides a Fleet-managed [Cilium multi-cluster][cilium-intro] deployment that removes the overhead of configuring and managing Cilium multi-cluster's data plane components on each member cluster.

When a cluster joins a cross-cluster network, the Cilium agent (cilium-agent) and clustermesh-apiserver are deployed on the cluster's control plane by Fleet Manager. Existing clusters on the same cross-cluster network are updated with the newly added cluster's details and the Cilium agent configures eBPF-based routing to allow pods on each cluster to communicate directly without proxies or gateways.

Each cluster retains its local CIDR IP addressing configuration for pods and service. Local Cilium components are responsible for routing allowing pods in one cluster to reach services in remote clusters as if they were local. 

For traffic flow control, Cilium network policies ([CiliumNetworkPolicy][cilium-network-policy]) can be used to control cross-cluster data flow, allowing administrators to enforce boundaries within the cross-cluster network.

## Defining global services

Kubernetes [Services][kube-services] on any cross-cluster networking member can be made globally available on the cross-cluster network by adding an annotation of `service.cilium.io/global` with the value set to `true`. Deploying the Service with this annotation to multiple cross-cluster networking member clusters transparently load balances requests across those clusters.

You can temporarily remove a cluster from a load balanced global service by adding an annotation of `service.cilium.io/shared` with a value of `false`. Using the approach is useful if you don't wish to completely remove the Service or cluster.   

## Debugging and troubleshooting

The standard Cilium commandline interface (CLI) tools work with cross-cluster networking for Fleet Manager. Some commands such `upgrade` and `clustermesh connect` don't work because they perform actions Fleet Manager is now responsible for.

Here's the high-level steps to getting started with debugging and troubleshooting:

* Install the latest stable Cilium CLI for your operating system from the official [Cilium CLI GitHub repository][cilium-cli-github].
* Select a cross-cluster network member cluster and retrieve its kubeconfig by using the [`az aks get-credentials`][az-aks-get-credentials] command.
* Use the Cilium CLI, passing the cluster context using the `--context` parameter.

The Cilium CLI can manage multiple Cilium versions.

## Updating cross-cluster networking

One reason to adopt cross-cluster networking over installing and running Cilium multi-cluster yourself is that Fleet Manager keeps Cilium's components up to date.

Cross-cluster networking's Cilium component updates are bundled as part of AKS Kubernetes releases. Upgrades are simplified by pre-validation that Cilium components work with the Kubernetes version your cluster runs, ensuring the cross-cluster network remains stable.

This approach means you can use Fleet Manager's [Update Runs and Strategies][fleet-update-runs] to upgrade the control plane of your clusters, defining the order in which clusters are updated.

## Next steps

* [Track availability of this preview][track-preview].


<!-- INTERNAL LINKS -->
[aks-acns-enabled]: ../aks/use-advanced-container-networking-services.md?pivots=cilium
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[fleet-update-runs]: ./concepts-update-orchestration.md
[flat-network]: ../aks/concepts-network-cni-overview.md#flat-networks

<!-- EXTERNAL LINKS -->
[kube-services]: https://kubernetes.io/docs/concepts/services-networking/service/
[cilium-intro]: https://docs.cilium.io/en/stable/network/clustermesh/intro/
[cilium-network-policy]: https://docs.cilium.io/en/latest/security/policy/index.html
[cilium-cli-github]: https://github.com/cilium/cilium-cli
[track-preview]: https://github.com/Azure/AKS/issues/5113