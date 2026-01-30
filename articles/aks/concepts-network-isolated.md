---
title: Network isolated AKS clusters
titleSuffix: Azure Kubernetes Service
description: Learn how network isolated AKS clusters work
author: charleswool
ms.author: yuewu2
ms.topic: concept-article
ms.date: 07/08/2025

# Customer intent: "As a Kubernetes administrator, I want to configure a network isolated AKS cluster, so that I can enhance security by eliminating egress traffic and reducing risks of data exfiltration while managing my cluster's dependencies privately."
---

# Network isolated Azure Kubernetes Service (AKS) clusters 

Organizations typically have strict security and compliance requirements to regulate egress (outbound) network traffic from a cluster to eliminate risks of data exfiltration. By default, standard SKU Azure Kubernetes Service (AKS) clusters have unrestricted outbound internet access. This level of network access allows nodes and services you run to access external resources as needed. If you wish to restrict egress traffic, a limited number of ports and addresses must be accessible to maintain healthy cluster maintenance tasks. The conceptual document on [outbound network and fully qualified domain name (FQDN) rules for AKS clusters][outbound-rules] provides a list of required endpoints for the AKS cluster and its optional add-ons and features.

One common solution to restricting outbound traffic from the cluster is to use a [firewall device][aks-firewall] to restrict traffic based on firewall rules. Firewall is applicable when your application requires outbound access, but when outbound requests have to be inspected and secured. Configuring a firewall manually with required egress rules and *FQDNs* is a cumbersome process especially if your only requirement is to create an isolated AKS cluster with no outbound dependencies for the cluster bootstrapping.

To reduce risk of data exfiltration, network isolated cluster allows for bootstrapping the AKS cluster without any outbound network dependencies, even for fetching cluster components/images from Microsoft Artifact Registry (MAR). The cluster operator could incrementally set up allowed outbound traffic for each scenario they want to enable.

## How a network isolated cluster works

The following diagram shows the network communication between dependencies for a network isolated cluster.

:::image type="content" source="media/network-isolated-cluster/network-isolated-cluster-diagram.png" alt-text="Traffic diagram of network isolated AKS cluster.":::

AKS clusters fetch artifacts required for the cluster and its features or add-ons from the Microsoft Artifact Registry (MAR). This image pull allows AKS to provide newer versions of the cluster components and to also address critical security vulnerabilities. A network isolated cluster attempts to pull those images and binaries from a private Azure Container Registry (ACR) instance connected to the cluster instead of pulling from MAR. If the images aren't present, the private ACR pulls them from MAR and serves them via its private endpoint, eliminating the need to enable egress from the cluster to the public MAR endpoint.


The following two options are supported for a private ACR associated with network isolated clusters:

* **AKS-managed ACR** - AKS creates, manages, and reconciles an ACR resource in this option. There's nothing you need to do.

    > [!NOTE]
    > The AKS-managed ACR resource is created in your subscription.
    > If you delete the cluster with AKS-managed ACR for bootstrap artifact source. Related resources such as the AKS-managed ACR, private link, and private endpoint are also automatically deleted.
    > If you change outbound type on a cluster to any type other than `none` or `block` with `--bootstrap-artifact-source` retained as `Cache`. Then the related resources are not deleted.

* **Bring your own (BYO) ACR** - The BYO ACR option requires creating an ACR with a private link between the ACR resource and the AKS cluster. See [Connect privately to an Azure container registry using Azure Private Link][container-registry-private-link] to understand how to configure a private endpoint for your registry. You also need to assign permissions and manage the cache rules, private link, and private endpoint used in the cluster. 

    > [!NOTE]
    > When you delete the AKS cluster or after you disable the feature. The BYO ACR, private link, and private endpoint aren't deleted automatically. If you add customized images and cache rules to the BYO ACR, they persist after cluster reconciliation.

To create a network isolated cluster, you need to first ensure network traffic between your API server and your node pools remains only on the private network, you can choose one of the following private cluster modes:

* [Private link-based cluster][private-clusters] - The control plane or API server is in an AKS-managed Azure resource group, and your node pool is in your resource group. The server and the node pool can communicate with each other through the Azure Private Link service in the API server virtual network and a private endpoint which is exposed on the subnet of your AKS cluster.
* [API Server VNet Integration configured cluster][api-server-vnet-integration] - A cluster configured with API Server VNet Integration projects the API server endpoint directly into a delegated subnet in the virtual network where AKS is deployed. API Server VNet Integration enables network communication between the API server and the cluster nodes without requiring a private link or tunnel.

You also need to ensure the egress path for your AKS cluster are controlled and limited, you can choose one of the following network outbound types:

* [Outbound type of `none`][outbound-type-none] - If `none` is set. AKS doesn't automatically configure egress paths and a default route is not required. It is supported in both bring-your-own (BYO) virtual network scenarios and managed virtual network scenarios. For bring your own virtual network scenario, you must establish explicit egress paths if needed.
* [Outbound type of `block` (preview)][outbound-type-block] -If `block` is set. AKS configures network rules to actively block all egress traffic from the cluster. This option is useful for highly secure environments where outbound connectivity must be restricted. It is supported in managed virtual network scenario. You can also achieve similar effect by blocking all egress traffic by adding [network security group (NSG)][nsg] rules with `none` in bring-your-own virtual network scenario.

> [!NOTE]
> Outbound type of `none` is generally available. 
> Outbound type `block` is in preview.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Limitations

*  `Unmanaged` channel is not supported.
* Windows node pools are not yet supported.
* kubenet networking is not supported.
* BYO ACR [Domain Name Label (DNL)](https://learn.microsoft.com/azure/container-registry/container-registry-get-started-portal?tabs=azure-cli#configure-domain-name-label-dnl-option) is not supported.

> [!Caution]
> If you are using [Node Public IP][node-public-ip] in network isolated AKS clusters, it will allow outbound traffic with outbound type `none`.

## Using features, add-ons, and extensions requiring egress

For network isolated clusters with BYO ACR:
* If you want to use any AKS feature or add-on that requires outbound network access in network isolated clusters with outbound type `none` , [this document][outbound-rules-control-egress] contains the outbound network requirements for each feature. Also, this doc enumerates the features or add-ons that support private link integration for secure connection from within the cluster's virtual network. It is recommended to set up private endpoints to access these features. For example, you can set up [private endpoint based ingestion][azmontoring-private-link] to use Managed Prometheus (Azure Monitor workspace) and Container insights (Log Analytics workspace) in network isolated clusters. If a private link integration is not available for any of these features. Then you can set up the cluster with a [user-defined routing table and an Azure Firewall][aks-firewall] based on the network rules and application rules that required for that feature.
* If you are using [Azure Container Storage Interface (CSI) driver][csi-driver] for Azure Files and Blob storage, you must create a custom storage class with "networkEndpointType: privateEndpoint", see examples in [Azure Files storage classes][custom-storage-class-file] and [Azure Blob storage classes][custom-storage-class-blob].
* The following AKS cluster extensions aren't supported yet on network isolated clusters:
    * [Dapr][dapr-overview]
    * [Azure App Configuration][app-config-overview]
    * [Azure Machine Learning][azure-ml-overview]
    * [Flux (GitOps)][gitops-overview]
    * [Azure Backup for AKS][azure-backup-aks]

## Frequently asked questions

### What's the difference between network isolated cluster and Azure Firewall?

A network isolated cluster doesn't require any egress traffic beyond the VNet throughout the cluster bootstrapping process. A network isolated cluster has outbound type as either `none` or `block`. If the outbound type is set to `none`, then AKS doesn't set up any outbound connections for the cluster, allowing the user to configure them on their own. If the outbound type is set to `block`, then all outbound connections are blocked.

A firewall typically establishes a barrier between a trusted network and an untrusted network, such as the Internet. Azure Firewall, for example, can restrict outbound HTTP and HTTPS traffic that's based on the destination. It gives you fine-grained control of egress traffic, but at the same time allows you to provide access to the FQDNs encompassing an AKS cluster’s outbound dependencies. This is something that NSGs can't do. For example, you can set outbound type of the cluster to `userDefinedRouting` to force outbound traffic through the firewall and then configure FQDN restrictions on outbound traffic. There are many cases where you still want a firewall. Such as you have outbound traffic anyway from your application or you want to control, inspect, and secure the cluster traffic both egress and ingress.

In summary, while Azure Firewall can be used to define egress restrictions on clusters with outbound requests, network isolated clusters go further on secure-by-default posture by eliminating or blocking the outbound requests altogether.

### Do I need to set up any allowlist endpoints for the network isolated cluster to work?

The cluster creation and bootstrapping stages don't require any outbound traffic from the network isolated cluster. Images required for AKS components and addons are pulled from the private ACR connected to the cluster instead of pulling from Microsoft Artifact Registry (MAR) over public endpoints.

After setting up a network isolated cluster. If you want to enable features or add-ons that need to make outbound requests to their service endpoints, you can set up private endpoints to the services powered by Azure Private Link.

### Can I manually upgrade packages to upgrade node pool image?

Manually upgrading packages based on egress to package repositories is not recommended. Instead, you can [manually upgrade][manual-upgrade] or [autoupgrade your node OS images][autoupgrade-node-os]. Only `NodeImage` and `None` upgrade channels are currently supported for network isolated clusters.

### What if I change the outbound type other than `none` or `block`, does that still make a network isolated cluster?

The only supported outbound types for a network isolated cluster are outbound type `none` and `block`. If you use any other outbound type, the cluster may still pull artifacts from the private ACR associated, however that may generate egress traffic.


## Next steps

- [Create a network isolated cluster][network-isolated]

<!-- LINKS - Internal -->

[private-clusters]: ./private-clusters.md
[api-server-vnet-integration]: ./api-server-vnet-integration.md
[autoupgrade-node-os]: ./auto-upgrade-node-os-image.md
[network-isolated]: ./network-isolated.md
[outbound-rules]: ./outbound-rules-control-egress.md
[app-config-overview]: ./azure-app-configuration.md
[dapr-overview]: ./dapr.md
[csi-driver]: ./azure-files-csi.md
[node-public-ip]: ./use-node-public-ips.md
[outbound-rules-control-egress]: ./outbound-rules-control-egress.md
[aks-firewall]: ./limit-egress-traffic.md
[azure-cni]: ./configure-azure-cni.md
[csi-files]: ./azure-files-csi.md
[csi-blob]: ./azure-blob-csi.md
[csi-disks]: ./azure-disk-csi.md
[manual-upgrade]: ./node-image-upgrade.md

<!-- LINKS - External -->
[container-registry-private-link]: /azure/container-registry/container-registry-private-link
[azure-ml-overview]: /azure/machine-learning/how-to-attach-kubernetes-anywhere
[gitops-overview]: /azure/azure-arc/kubernetes/conceptual-gitops-flux2
[azure-container-storage]: /azure/storage/container-storage/container-storage-introduction
[azure-backup-aks]: /azure/backup/azure-kubernetes-service-backup-overview
[custom-storage-class-blob]: /azure/aks/azure-csi-blob-storage-provision?tabs=mount-nfs%2Csecret#storage-class-parameters-for-dynamic-persistent-volumes
[custom-storage-class-file]: /azure/aks/azure-csi-files-storage-provision#dynamically-provision-a-volume
[azmontoring-private-link]: /azure/azure-monitor/containers/kubernetes-monitoring-private-link
[outbound-type-none]: /azure/aks/egress-outboundtype#outbound-type-of-none
[outbound-type-block]: /azure/aks/egress-outboundtype#outbound-type-of-block-preview
[nsg]: /azure/virtual-network/network-security-groups-overview
