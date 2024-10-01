---
title: Fleet hub cluster security overview
description: This article provides an overview on how Azure Kubernetes Fleet Manager conducts security and lifecycle management.
ms.date: 10/01/2024
author: yoobinshin
ms.author: yoobinshin
ms.service: kubernetes-fleet
ms.topic: conceptual
---

# Fleet hub cluster security overview

This article provides an overview on how Azure Kubernetes Fleet Manager (Fleet) conducts security and lifecycle management.

A Fleet resource can be created with or without a hub cluster. A [hub cluster](concepts-choosing-fleet) is a managed Azure Kubernetes Service (AKS) cluster that acts as a hub to store and propagate Kubernetes resources. As hub clusters are locked down by denying any user-initiated mutations, Fleet internally manages security to ensure that customers' hub clusters are up-to-date and secure.

## Versions

The security and lifecycle management of a hub cluster involves updating the following three components periodically:

### 1. Node image version

The [node image version](aks-node-image-upgrade) includes newly patched Virtual Hard Disks (VHDs) containing security fixes and bug fixes.

AKS deploys node image version upgrades weekly following Safe Deployment Practices (SDP). Once a new image is released to a region, it can take up to 24 hours for the hub cluster's image to be upgraded.

### 2. Kubernetes patch version (x.y.1)

The [Kubernetes patch version](aks-upgrade-aks-cluster) includes fixes for security vulnerabilities or major bugs.

AKS releases new Kubernetes patch versions after an upstream release of a security patch. The release can be tracked on [AKS Release Status](aks-release-status). Similarly, the AKS release follows SDP and can take up to 24 hours after rollout to be applied to hubs.

### 3. Kubernetes minor version (x.30.y)

The Kubernetes minor version includes new features and improvements.

Upstream releases of new minor versions happen quarterly, and there are no security implications from minor releases. Once AKS releases a new minor version, Fleet conducts conformance testing and begins deploying the minor release on hubs when deemed ready.

## Requirements from customers

In order for Fleet to keep hub clusters up-to-date with the latest security patch, you should ensure they are in the following conditions:

1. **Hubs have sufficient quota.** Sufficient quota is required to install updates. For more information on increasing quota, see [documentation on quota](quotas-regional-quota-requests).
2. **Hubs have internet access.** Outbound connectivity is required to communicate with the API server to install updates. For instance, hubs with user-defined routing tables (UDR) or Firewall might block outbound connectivity. For more information on outbound connectivity, see [documentation on AKS outbound network](aks-outbound-rules-control-egress).

## Security configuration details

In addition to periodic security upgrades, the following configurations are set on hub clusters to harden security:

- Pod workloads can't run on hub clusters.
- Using `command invoke` [with Azure CLI](aks-access-private-cluster) is disabled on hub clusters.
- Hub clusters use Azure Linux for node images, rather than Ubuntu.
- Local authentication (access via admin kubeconfig) is disabled on hub clusters. Disabling local authentication methods improves security by ensuring that AKS clusters exclusively require [Microsoft Entra ID](aks-operator-best-practices-identity) for authentication.


<!-- LINKS -->
[concepts-choosing-fleet]: concepts-choosing-fleet#kubernetes-fleet-resource-with-hub-clusters
[aks-node-image-upgrade]: /azure/aks/node-image-upgrade
[aks-upgrade-aks-cluster]: /azure/aks/upgrade-aks-cluster
[aks-outbound-rules-control-egress]: /azure/aks/outbound-rules-control-egress
[aks-access-private-cluster]: /azure/aks/access-private-cluster
[aks-operator-best-practices-identity]: /azure/aks/operator-best-practices-identity#use-microsoft-entra-id
[quotas-regional-quota-requests]: /azure/quotas/regional-quota-requests

<!-- LINKS - external -->
[aks-release-status]: https://releases.aks.azure.com