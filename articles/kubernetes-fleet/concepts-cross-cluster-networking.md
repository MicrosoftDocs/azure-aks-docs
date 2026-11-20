---
title: "Cross-cluster networking for Azure Kubernetes Fleet Manager"
description: This article provides a conceptual overview of Cross-cluster networking for Azure Kubernetes Fleet Manager. 
ms.date: 11/03/2026
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: "As a platform engineer, I want to understand the supporting concepts for cross-cluster networking in Azure Kubernetes Fleet Manager, so that I know how and where I can use cross-cluster networking."
---

# Cross-cluster networking for Azure Kubernetes Fleet Manager

**Applies to**: :heavy_check_mark: Fleet Manager :heavy_check_mark: Fleet Manager with hub cluster

Azure Kubernetes Fleet Manager provides a dedicated cross-cluster networking solution that extends the Kubernetes datapath across multiple clusters. By using cross-cluster networking, any connected cluster can communicate directly with endpoints on any other connected cluster with full network‑policy enforcement. By using cross-cluster networking, clusters can publish services such that any connected cluster can call them as if they were local.

You can create multiple cross-cluster network profiles in Fleet Manager, with the only restriction being that member clusters can only participate in a single cross-cluster network.

In this article, we introduce key concepts for cross-cluster networking for Azure Kubernetes Fleet Manager.

## Prerequisites and limitations

* A cross-cluster network can have up to 255 member clusters.
* Fleet Manager member clusters can only participate in a single cross-cluster network at any time.
* Clusters must have [Advanced Container Networking Services (ACNS)][aks-acns-enabled] with Cilium enabled.
* Clusters must be connected to the same virtual network or peered virtual networks.
* To use cross-cluster networking with pod subnets, clusters must run Kubernetes v1.32 or above.
* To use cross-cluster networking with overlay networking, clusters must run Kubernetes v1.36 or above.
* Azure CNI overlay cross-cluster networks can't expose global services via external load balancers due to overlay network routing limitations.
* A single cross-cluster network can host only clusters using either pod subnet or overlay networking. You can't currently mix network types.
* Pod-to-pod communication on clusters using overlay networking requires the `clustermesh.cilium.io/global` annotation to be set on the Namespaces of those pods and that pod CIDRs in each member cluster don't overlap.
* When using overlay networking, a NodePort service won't work when its backend is in another cluster.
* You can't deploy self-managed Cilium multicluster at the same time.
* ACNS sets the Cilium version and enabled features. You can't currently directly modify these settings.

## Foundational concepts

Cross-cluster networking for Azure Kubernetes Fleet Manager provides a Fleet-managed [Cilium multicluster][cilium-intro] deployment that removes the overhead of configuring and managing Cilium multicluster's data plane components on each member cluster.

When a cluster joins a cross-cluster network, Fleet Manager deploys the Cilium agent (cilium-agent) and clustermesh-apiserver on the cluster's control plane. Fleet Manager updates existing clusters on the same cross-cluster network with the newly added cluster's details and the Cilium agent configures eBPF-based routing to allow pods on each cluster to communicate directly without proxies or gateways.

Each cluster retains its local CIDR IP addressing configuration for pods and service. Local Cilium components are responsible for routing, allowing pods in one cluster to reach services in remote clusters as if they were local.

For traffic flow control, use Cilium network policies ([CiliumNetworkPolicy][cilium-network-policy]) to control cross-cluster data flow. By using these policies, administrators can enforce boundaries within the cross-cluster network.

## Defining global services

Kubernetes [Services][kube-services] on any cross-cluster networking member can be made globally available on the cross-cluster network when **both** of the following conditions are met:

* The Namespace containing the Service has the annotation `clustermesh.cilium.io/global` with a value of `true`.
* The Service has the annotation `service.cilium.io/global` with a value of `true`.

Deploying a Service with these annotations to multiple cross-cluster networking member clusters transparently load balances requests across those clusters.

You can temporarily remove a Service from a load balanced global service by removing the `service.cilium.io/global` annotation (or setting it to `false`) on that Service. To stop sharing every Service in a Namespace from a given cluster, remove the `clustermesh.cilium.io/global` annotation on the Namespace (or set it to `false`) on that cluster.

> [!NOTE]
> Fleet Manager's managed Cilium multicluster installation sets `clustermesh-default-global-namespace: false`, which differs from the Cilium default. This setting improves scalability by limiting the amount of state (CiliumEndpoints, CiliumIdentities, and Services) synchronized across clusters to only those resources in Namespaces with the `clustermesh.cilium.io/global` annotation set to a value of `true`. As a result, explicit opt-in is required per Namespace by setting that annotation.

## Debugging and troubleshooting

The standard Cilium command-line interface (CLI) tools work with cross-cluster networking for Fleet Manager. Some commands such as `upgrade` and `clustermesh connect` don't work because they perform actions that Fleet Manager is now responsible for.

Here's the high-level steps to getting started with debugging and troubleshooting:

* Install the latest stable Cilium CLI for your operating system from the official [Cilium CLI GitHub repository][cilium-cli-github].
* Select a cross-cluster network member cluster and retrieve its kubeconfig by using the [`az aks get-credentials`][az-aks-get-credentials] command.
* Use the Cilium CLI, passing the cluster context by using the `--context` parameter.

The Cilium CLI can manage multiple Cilium versions.

## Updating cross-cluster networking components

One reason to adopt cross-cluster networking over installing and running Cilium multicluster yourself is that Fleet Manager keeps Cilium's components up to date.

Cross-cluster networking's Cilium component updates are bundled as part of AKS Kubernetes releases. Upgrades are simplified by prevalidation that Cilium components work with the Kubernetes version your cluster runs, ensuring the cross-cluster network remains stable.

This approach means you can use Fleet Manager's [Update Runs and Strategies][fleet-update-runs] to upgrade the control plane of your clusters, defining the order in which clusters are updated.

### Certificate authority rotation

Fleet Manager automatically rotates the certificate authority (CA) for all members included in a cross-cluster network. This process includes generation of the new CA and distribution of the newly signed leaf certificates to all the connected member clusters. This rotation is triggered automatically by Fleet Manager without any manual customer configuration needed, ensuring effortless certificate management with no disruption in cross-cluster connectivity.

## Next steps

* [How to: Configure and use Fleet Manager Cross Cluster Connectivity][howto-configure-cross-cluster]

<!-- INTERNAL LINKS -->
[aks-acns-enabled]: ../aks/use-advanced-container-networking-services.md?pivots=cilium
[howto-configure-cross-cluster]: ./howto-configure-use-cross-cluster-networking.md
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[fleet-update-runs]: ./concepts-update-orchestration.md

<!-- EXTERNAL LINKS -->
[kube-services]: https://kubernetes.io/docs/concepts/services-networking/service/
[cilium-intro]: https://docs.cilium.io/en/stable/network/clustermesh/intro/
[cilium-network-policy]: https://docs.cilium.io/en/latest/security/policy/index.html
[cilium-cli-github]: https://github.com/cilium/cilium-cli
