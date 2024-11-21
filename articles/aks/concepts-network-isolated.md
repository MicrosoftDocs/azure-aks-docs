---
title: Network isolated AKS clusters
titleSuffix: Azure Kubernetes Service
description: Learn how network isolated AKS clusters work
author: shashankbarsin
ms.author: shasb
ms.topic: conceptual
ms.date: 11/10/2024
---

# Network isolated Azure Kubernetes Service (AKS) clusters (Preview)

Organizations typically have strict security and compliance requirements to regulate egress (outbound) network traffic from a cluster to eliminate risks of data exfiltration. By default, Azure Kubernetes Service (AKS) clusters have unrestricted outbound internet access. This level of network access allows nodes and services you run to access external resources as needed. If you wish to restrict egress traffic, a limited number of ports and addresses must be accessible to maintain healthy cluster maintenance tasks. 

One solution to securing outbound addresses is using a firewall device that can control outbound traffic based on domain names. Configuring a firewall manually with required egress rules and *FQDNs* is a cumbersome and complicated process.

Another solution, a network isolated AKS cluster (preview), simplifies setting up outbound restrictions for a cluster out of the box. A network isolated AKS cluster reduces the risk of data exfiltration or unintentional exposure of cluster's public endpoints.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## How a network isolated cluster works

The following diagram shows the network communication between dependencies for an AKS network isolated cluster.

:::image type="content" source="media/network-isolated-cluster/network-isolated-cluster-diagram.png" alt-text="Traffic diagram of network isolated AKS cluster.":::

Normally, an AKS cluster pulls system images from the Microsoft Artifact Registry (MAR). A network isolated cluster attempts to pull those images from a private Azure Container Registry (ACR) instance connected to the cluster instead. If the images aren't present, the private ACR pulls them from MAR and serves them via its private endpoint, eliminating the need to enable egress from the cluster to the public MAR endpoint. Thus, a network isolated AKS cluster doesn't require access to any public endpoint.


The following options are supported for a private ACR with network isolated clusters:

* **AKS-managed ACR** - AKS creates, manages, and reconciles an ACR resource in this option. You don't need to assign any permissions or manage the ACR. AKS manages the cache rules, private link, and private endpoint used in the network isolated cluster. An AKS-managed ACR follows the same behavior as other resources (route table, Azure Virtual Machine Scale Sets, etc.) in the infrastructure resource group. **To avoid the risk of cluster components or new node bootstrap failing, do not update or delete the ACR, its cache rules, or its system images.**. The AKS-managed ACR is continuously reconciled so that cluster components and new nodes work as expected.

    > [!NOTE]
    > After you delete an AKS network isolated cluster, related resources such as the AKS-managed ACR, private link, and private endpoint are automatically deleted.

* **Bring your own (BYO) ACR** - The BYO ACR option requires creating an ACR with a private link between the ACR resource and the AKS cluster. See [Connect privately to an Azure container registry using Azure Private Link][container-registry-private-link] to understand how to configure a private endpoint for your registry.

    > [!NOTE]
    > When you delete the AKS cluster, the BYO ACR, private link, and private endpoint aren't deleted automatically. If you add customized images and cache rules to the BYO ACR, they persist after cluster reconciliation, after you disable the feature, or after you delete the AKS cluster.


When creating a network isolated AKS cluster, you can choose one of the following private cluster modes:

* [Private link-based AKS cluster][private-clusters] - The control plane or API server is in an AKS-managed Azure resource group, and your node pool is in your resource group. The server and the node pool can communicate with each other through the Azure Private Link service in the API server virtual network and a private endpoint which is exposed on the subnet of your AKS cluster.
* [API Server VNet Integration (Preview)][api-server-vnet-integration] - A cluster configured with API Server VNet Integration projects the API server endpoint directly into a delegated subnet in the virtual network where AKS is deployed. API Server VNet Integration enables network communication between the API server and the cluster nodes without requiring a private link or tunnel.

## Limitations

* Network isolated clusters are supported on AKS clusters using Kubernetes version 1.30 or higher.
* Only `NodeImage` channel of auto-upgrade for node OS images is supported for network isolated clusters
* Windows node pools are not currently supported.
* Outbound type `block` is currently not supported for bring your own virtual network (BYO-vnet) clusters.
* The following AKS cluster extensions are't not supported yet on network isolated clusters:
    * [Dapr][dapr-overview]
    * [Azure App Configuration][app-config-overview]
    * [Azure Machine Learning][azure-ml-overview]
    * [Flux (GitOps)][gitops-overview]
    * [Azure Container Storage][azure-container-storage]
    * [Azure Backup for AKS][azure-backup-aks]

## Frequently asked questions

### What's the difference between network isolated cluster and Azure Firewall?

A network isolated cluster doesn't require any egress traffic beyond the VNet throughout the cluster bootstrapping process. A network isolated cluster will have outbound type as either `none` or `block`. If the outbound type is set to `none`, then AKS doesn't set up any outbound connections for the cluster, allowing the user to configure them on their own. If the outbound type is set to `block`, then all outbound connections are blocked.

A firewall typically establishes a barrier between a trusted network and an untrusted network, such as the Internet. Azure Firewall, for example, can restrict outbound HTTP and HTTPS traffic based on the FQDN of the destination, giving you fine-grained egress traffic control, but at the same time allows you to provide access to the FQDNs encompassing an AKS cluster’s outbound dependencies (something that NSGs can't do). For example, you can set outbound type of the cluster to `userDefinedRouting` to force outbound traffic through the firewall and then configure FQDN restrictions on outbound traffic.

In summary, while Azure Firewall can be used to define egress restrictions on clusters with outbound requests, network isolated clusters go further on secure-by-default posture by elimintating or blocking the outbound requests altogether.

### Do I need to set up any allowlist endpoints for the network isolated cluster to work?

The cluster creation and bootstrapping stages don't require any outbound traffic from the network isolated cluster. Images required for AKS components and addons are pulled from the private ACR connected to the cluster instead of pulling from Microsoft Artifact Registry (MAR) over public endpoints.

After setting up a network isolated cluster, if you want to enable features or add-ons that need to make outbound requests to their service endpoints, private endpoints can be set up to the services powered by Azure Private Link.

### Can I manually upgrade packages to upgrade node pool image?

Manually upgrading packages based on egress to package repositories isn't supported. Instead, you can [autoupgrade your node OS images][autoupgrade-node-os]. Only `NodeImage` node OS autoupgrade channel is supported for network isolated clusters.

## Next steps

- [Create a network isolated cluster][network-isolated]

<!-- LINKS - Internal -->
[container-registry-private-link]: /azure/container-registry/container-registry-private-link
[private-clusters]: ./private-clusters.md
[api-server-vnet-integration]: ./api-server-vnet-integration.md
[autoupgrade-node-os]: ./auto-upgrade-node-os-image.md
[network-isolated]: ./network-isolated.md

[app-config-overview]: ./azure-app-configuration.md
[azure-ml-overview]: /azure/machine-learning/how-to-attach-kubernetes-anywhere
[dapr-overview]: ./dapr.md
[gitops-overview]: /azure/azure-arc/kubernetes/conceptual-gitops-flux2
[azure-container-storage]: /azure/storage/container-storage/container-storage-introduction
[azure-backup-aks]: /azure/backup/azure-kubernetes-service-backup-overview)
