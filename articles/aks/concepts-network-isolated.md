---
title: Concepts - Network isolated clusters
titleSuffix: Azure Kubernetes Service
description: Learn about network isolated clusters
author: shashankbarsin
ms.author: shasb
ms.topic: conceptual
ms.date: 11/10/2024
---

# Network isolated AKS clusters (Preview)

Organizations typically have strict security and compliance requirements to regulate egress (outbound) network traffic from a cluster to eliminate risks of data exfiltration. By default, AKS clusters have unrestricted outbound internet access. This level of network access allows nodes and services you run to access external resources as needed. If you wish to restrict egress traffic, a limited number of ports and addresses must be accessible to maintain healthy cluster maintenance tasks. One of the solution to securing outbound addresses is using a firewall device that can control outbound traffic based on domain names. Configuring a firewall manually with required egress rules and FQDNs is a cumbersome and complicated process.

A network isolated AKS cluster simplifies the set up of a cluster that doesn't require any outbound or inbound network traffic outside its virtual network, thus reducing the risk of data exfiltration or unintentional exposure of cluster's public endpoints.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## How a network isolated cluster works

The following diagram shows the network communication between dependencies for an AKS network isolated cluster.

:::image type="content" source="media/network-isolated-cluster/network-isolated-cluster-diagram.png" alt-text="Traffic diagram of network isolated AKS cluster.":::

Normally, an AKS cluster pulls system images from the Microsoft Artifact Registry (MAR). A network isolated cluster will attempt to pull those images from a private Azure Container Registry (ACR) instance connected to the cluster instead. If the images are not present, the private ACR will pull them from MAR and serve them via its private endpoint. This eliminates the need to enable egress from the cluster to the public MAR endpoint. Thus, a network isolated AKS cluster doesn't require public access to any of these endpoints.


The following options are supported for private ACR with network isolated clusters:

* **AKS-managed ACR**: An AKS-managed ACR is completely created and managed by the AKS cluster. You don't need to assign any permissions or manage the ACR. The cache rules, private link, and private endpoint used by the network isolated cluster are also managed by the AKS. An AKS-managed ACR follows the same behavior as other resources (route table, Azure Virtual Machine Scale Sets, etc.) in the infrastructure resource group. **You should not update/delete the ACR, its cache rules, or its system images to avoid the risk of cluster components or new node boostrap failing**. In the case of AKS-managed ACR, the ACR is continuously reconciled so that cluster components and new nodes work as expected.

    > [!NOTE]
    > After you delete an AKS network isolated cluster, related resources such as the AKS-managed ACR, private link, and private endpoint are automatically deleted.

* **Bring your own (BYO) ACR**: Bring your own (BYO) ACR option requires creating an ACR with a private link between the ACR resource and the AKS cluster. See [Connect privately to an Azure container registry using Azure Private Link][container-registry-private-link] to understand how to configure a private endpoint for your registry.

    > [!NOTE]
    > When you delete the AKS cluster, the BYO ACR, private link, and private endpoint aren't deleted automatically. If you add customized images and cache rules to the BYO ACR, they are persisted after cluster reconciliation, after you disable the feature, or after you delete the AKS cluster.


When creating network isolated AKS cluster, you can choose one of the following private cluster modes:

* [Private link-based AKS cluster][private-clusters]: The control plane or API server is in an AKS-managed Azure resource group, and your cluster or node pool is in your resource group. The server and the cluster or node pool can communicate with each other through the Azure Private Link service in the API server virtual network and a private endpoint that's exposed on the subnet of your AKS cluster
* [API Server Vnet Integration (Preview)][api-server-vnet-integration]: A cluster configured with API Server VNet Integration projects the API server endpoint directly into a delegated subnet in the virtual network where AKS is deployed. API Server VNet Integration enables network communication between the API server and the cluster nodes without requiring a private link or tunnel.

## Frequently asked questions

### What's the difference between network isolated cluster and Azure Firewall?

A network isolated cluster does not require any egress traffic beyond the VNet through cluster bootstrapping by its nature. While Azure Firewall helps restrict ingress and egress traffic between the cluster and external networks per the firewall configurations.

### Do I need to set up any allowlist endpoints for the network isolated cluster to work?

No, you don't need to set up any network rules for network isolated cluster as it does not require any outbound traffic during the node bootstrapping stage.

### Can I manually upgrade packages to upgrade node pool image?

No, we don't support any arbitrary repository in network isolated cluster, instead you can [auto-upgrade your node OS images][auto-upgrade-node-os]. Only `NodeImage` node OS auto-upgrade channels is supported for network isolated clusters.

## Next steps

- [Create a network isolated cluster][network-isolated]



<!-- LINKS - Internal -->
[container-registry-private-link]: /azure/container-registry/container-registry-private-link
[private-clusters]: ./private-clusters.md
[api-server-vnet-integration]: ./api-server-vnet-integration.md
[auto-upgrade-node-os]: ./auto-upgrade-node-os-image.md
[network-isolated]: ./network-isolated.md