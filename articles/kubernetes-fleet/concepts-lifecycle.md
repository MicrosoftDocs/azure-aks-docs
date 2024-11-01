---
title: Fleet hub cluster overview
description: This article provides an overview on how Azure Kubernetes Fleet Manager conducts lifecycle management.
ms.date: 10/03/2024
author: yoobinshin
ms.author: yoobinshin
ms.service: azure-kubernetes-fleet-manager
ms.topic: conceptual
---

# Fleet hub cluster overview

This article provides an overview on how Azure Kubernetes Fleet Manager (Fleet) conducts hub cluster lifecycle management.

A Fleet resource can be created with or without a hub cluster. A [hub cluster][concepts-choosing-fleet] is a managed Azure Kubernetes Service (AKS) cluster that acts as a hub to store and propagate Kubernetes resources. As hub clusters are locked down, preventing user-initiated configuration changes, the Fleet service manages keeping them up-to-date.

## Hub cluster lifecycle management

The lifecycle management of a hub cluster involves updating the following three components periodically:

### 1. Node image version

The [node image version][aks-node-image-upgrade] includes newly released Virtual Hard Disks (VHDs) containing security fixes and bug fixes.

AKS releases node image version upgrades weekly. The release involves gradual region deployment, which can take up to 10 days to reach all regions. Once a new image is available in a region, there can typically be a delay of up to 24 hours before the upgrade is applied to hubs.

### 2. Kubernetes patch version (x.y.1)

The [Kubernetes patch version][aks-upgrade-aks-cluster] includes fixes for security vulnerabilities or major bugs.

AKS releases new Kubernetes patch versions after an upstream release of a security patch. The release can be tracked on [AKS Release Status][aks-release-status]. Similarly, the release can take up to 10 days to reach all regions, and it can take up to 24 hours for the upgrade to be applied to hubs.

### 3. Kubernetes minor version (x.30.y)

The Kubernetes minor version includes new features and improvements.

Upstream releases of new minor versions happen approximately quarterly, and are independent of fixes for security vulnerabilities. Once AKS releases a new minor version, Fleet conducts conformance testing and begins deploying the minor release on hubs when deemed ready.

## Requirements from customers

In order for Fleet to keep hub clusters up-to-date with the latest patches, ensure that the hub clusters meet the following conditions:

1. **Hubs have sufficient quota.** Additional quota sufficient for one extra VM instance of the hub cluster's node Virtual Machine (VM) SKU type is briefly required during the upgrade process. For more information on increasing quota, see [documentation on quota][quotas-regional-quota-requests].
2. **Hubs have internet access.** Outbound connectivity is required to install updates. For instance, hubs with user-defined routing tables (UDR) or firewall rules might block outbound connectivity. For more information on outbound connectivity, see [documentation on AKS outbound network][aks-outbound-rules-control-egress].

## Hub cluster configuration details

In Azure Kubernetes Fleet Manager, hub clusters serve as the central management point for multiple member clusters. Here’s a detailed overview of their functionality and security measures:

- **Definition and Functionality:**
    - A hub cluster is a managed Azure Kubernetes Service (AKS) cluster that orchestrates and propagates Kubernetes resources across member clusters.
    - It is responsible for managing periodic component upgrades, ensuring that all clusters within the fleet are up-to-date with the latest security patches and features.

- **Managed by Microsoft:**
    - Hub clusters are managed by Microsoft, meaning users do not have the ability to create or deploy applications directly on these clusters. This restriction helps maintain a stable and secure environment.

- **Protections Against Modifications:**
    - To prevent unauthorized changes, several protections are in place:
        - **Command Invocation Disabled:** Using command invocation with Azure CLI is disabled on hub clusters, preventing users from executing commands that could alter the cluster’s configuration.
        - **Local Authentication Disabled:** Access via admin kubeconfig is disabled, ensuring that authentication is exclusively handled through Microsoft Entra ID. This enhances security by centralizing access control.

- **Envelope ConfigMap:**
    - An **envelope ConfigMap** is utilized to manage configurations without causing side effects on the hub cluster. This approach allows for the safe propagation of settings to member clusters while maintaining the integrity of the hub cluster’s environment.
      These configurations collectively enhance the security and stability of hub clusters, ensuring they function effectively as the backbone of Azure Kubernetes Fleet Manager.

In addition to managing periodic component upgrades, the Fleet service sets the following configurations on hub clusters to harden security:

- Using `command invoke` [with Azure CLI][aks-access-private-cluster] is disabled on hub clusters.
- Hub clusters use Azure Linux for node images.
- Local authentication (access via admin kubeconfig) is disabled on hub clusters. Disabling local authentication methods improves security by ensuring that AKS clusters exclusively require [Microsoft Entra ID][aks-operator-best-practices-identity] for authentication.


<!-- LINKS -->
[concepts-choosing-fleet]: /azure/kubernetes-fleet/concepts-choosing-fleet#kubernetes-fleet-resource-with-hub-clusters
[aks-node-image-upgrade]: /azure/aks/node-image-upgrade
[aks-upgrade-aks-cluster]: /azure/aks/upgrade-aks-cluster
[aks-outbound-rules-control-egress]: /azure/aks/outbound-rules-control-egress
[aks-access-private-cluster]: /azure/aks/access-private-cluster
[aks-operator-best-practices-identity]: /azure/aks/operator-best-practices-identity#use-microsoft-entra-id
[quotas-regional-quota-requests]: /azure/quotas/regional-quota-requests

<!-- LINKS - external -->
[aks-release-status]: https://releases.aks.azure.com