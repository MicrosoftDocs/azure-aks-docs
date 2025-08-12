---
title: Fleet hub cluster overview
description: This article provides an overview on the Azure Kubernetes Fleet Manager hub cluster.
ms.date: 08/01/2025
author: sjwaight
ms.author: simonwaight
ms.service: azure-kubernetes-fleet-manager
ms.topic: concept-article
# Customer intent: As a cloud operations manager, I want to understand how the Azure Kubernetes Fleet Manager manages hub cluster works, so that I can identify Azure resources associated with it and what I can and can't manage.
---

# Fleet Manager hub cluster overview

When enabled, the Fleet Manager hub cluster serves as the central management point for Kubernetes resource propagation across member clusters using [resource placement](./concepts-resource-propagation.md).

## Hub cluster configuration

A Fleet Manager hub cluster is a fully managed Azure Kubernetes Service (AKS) cluster that has the following properties:

- **Cluster name and location:** the hub cluster is always named `hub` and is created in the same Azure region as the Fleet Manager.
- **Azure Resource Group for hub cluster:** the hub cluster AKS resource is created in a managed resource group with the naming format `FL_{fleet_manager_resource_group}_{fleet_manager_name}_{azure_region}`.
- **Azure Resource Group for hub cluster resources:** like any AKS cluster, the hub cluster has Azure resources such as an agent node pool virtual machine scale set and virtual network that are created in a managed resource group with the naming format `MC_FL_{fleet_manager_resource_group}_{fleet_manager_name}_{azure_region}`.
- **Hub cluster node:** The hub cluster has a node pool with a single node running Azure Linux. The node doesn't run any pods and doesn't affect hub cluster performance. When creating a hub cluster from the Azure CLI, you can choose the node Virtual Machine (VM) SKU type by using the `--vm-size` parameter. 
- **Network configuration:** public hub clusters have a public API server, with an associated public IP address. When configured for private access, the API server is only accessible via an Azure virtual network.

## Hub cluster restrictions

The hub cluster has the following restrictions that ensure it functions as required for resource propagation and management:

- **Command Invocation Disabled:** Using command invocation via the Azure CLI ([az aks command invoke][aks-access-private-cluster]) is disabled for hub clusters.
- **Local Authentication Disabled:** Access via admin `kubeconfig` is disabled, ensuring that authentication is exclusively handled through Microsoft Entra ID, enhancing security by centralizing access control. Use [az fleet get-credentials][fleet-get-credentials] to obtain the `kubeconfig` for the hub cluster.
- **Deny Assignments:** Changes to the Azure configuration of the hub cluster and associated resources are blocked through [Azure Deny Assignments][azure-deny-assignments]. The following Deny Assignments are used:
  - `FLRG-DenyAssignments-{guid}`: Applied on the hub cluster resource group, preventing users from modifying the hub cluster.
  - `kubernetes.azure.com/{guid}` (optional): This deny assignment prevents users from modifying the hub cluster AKS resources (Virtual Machine Scale Sets, networks), as described in [AKS node resource group lockdown][aks-nrg-lockdown].
- **Applied Resources not instantiated:** The hub cluster doesn't schedule applied Kubernetes resources onto the hub cluster node. Some Kubernetes resources must be applied using an envelope object to avoid side effects on the hub cluster. For more information about envelope objects, see the [documentation of Envelope Objects](./quickstart-envelope-reserved-resources.md).

## Requirements from customers

In order for Fleet Manager to keep hub clusters up-to-date with the latest patches, ensure that:

- **Subscription has sufficient quota.** one extra VM instance of the hub cluster's node is required during the cluster upgrade process. For more information on increasing quota, see [documentation on quota][quotas-regional-quota-requests].

- **Hub cluster has internet access.** Outbound connectivity is required to install updates. Private hubs on networks with user-defined routing (UDR) or firewall rules might block outbound connectivity. For more information on outbound connectivity, see [documentation on AKS outbound network][aks-outbound-rules-control-egress].

- **No need to manage updates to the Fleet Manager hub cluster.** Microsoft automatically updates the hub cluster to the latest version of Kubernetes or node image as they become available from AKS. Update releases can be tracked on the [AKS Release Tracker][aks-release-status].

## Related content

* [Intelligent cross-cluster Kubernetes resource placement based on member clusters' properties](./intelligent-resource-placement.md).
* [Access Fleet Manager hub cluster Kubernetes API](./access-fleet-hub-cluster-kubernetes-api.md).
* [Fleet Manager Frequently Asked Questions](./faq.md).

<!-- LINKS -->
[aks-nrg-lockdown]: /azure/aks/node-resource-group-lockdown
[aks-outbound-rules-control-egress]: /azure/aks/outbound-rules-control-egress
[aks-access-private-cluster]: /azure/aks/access-private-cluster
[fleet-get-credentials]: /cli/azure/fleet#az-fleet-get-credentials
[quotas-regional-quota-requests]: /azure/quotas/regional-quota-requests
[azure-deny-assignments]: /azure/role-based-access-control/deny-assignments

<!-- LINKS - external -->
[aks-release-status]: https://releases.aks.azure.com
