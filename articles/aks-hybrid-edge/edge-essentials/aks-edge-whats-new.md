---
title: What's new in AKS Edge Essentials
description: Learn about what's new in AKS Edge Essentials releases.
ms.topic: overview
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak 
ms.reviewer: sumsmith
ms.lastreviewed: 04/17/2026
ms.custom: edge-essentials

---

# What's new in AKS Edge Essentials

AKS Edge Essentials is a lightweight on-premises Kubernetes implementation of Azure Kubernetes Service (AKS) that automates running containerized applications at scale. This article describes the latest features, enhancements, and updates in AKS Edge Essentials releases.

## Release 1.12.269.0 (April 2026)
The following features and improvements were added in this release:

- **Cross-distribution upgrades supported.** With this release, you can upgrade Kubernetes versions within the same release version. See the upgrade paths table below for supported combinations. In accordance with the upstream Kubernetes lifecycle, we recommend upgrading to or installing K8s/K3s version 1.33.

- **KMS enabled by default on new deployments.** The [KMS provider](aks-edge-howto-secret-encryption.md), generally available since version 1.11.247.0, is now enabled by default when deploying a new cluster on version 1.12.269.0 and later. No additional configuration is required.

### Supported versions for 1.12.269.0
- AKS Edge Essentials Version: 1.12.269.0
- Azure Linux Version: 3.0.20260401
- K8s (upstream Kubernetes) distribution: 1.31.5 (only available as upgrade from 1.11.247.0), 1.32.9 (available as upgrade from 1.11.247.0 or 1.12.267.0), 1.33.5 (available as upgrade from 1.12.268.0 or fresh install)
- K3s distribution: 1.31.6 (only available as upgrade from 1.11.230.0), 1.32.9 (available as upgrade from 1.11.230.0 or 1.12.267.0), 1.33.5 (available as upgrade from 1.12.268.0 or fresh install)
- Json version schema: 1.16

### Available upgrade paths
| Current version | Upgrade path |
| --- | --- |
| 1.11.230.0 k8s/k3s 1.30 | 1.12.267 k8s/k3s 1.31 |
| 1.11.230.0 k8s/k3s 1.31 | 1.12.268 k8s/k3s 1.32 |
| 1.12.267 k8s/k3s 1.31 | 1.12.268 k8s/k3s 1.32 |
| 1.12.268 k8s/k3s 1.32 | 1.12.269 k8s/k3s 1.33 |

Please note that, unlike prior releases, in this release, upgrading from one Kubernetes distribution to another within the same release version **is** supported. To support this, we have released multiple upgrade versions of this release, as noted above.

> [!NOTE]  
> Please ensure 19GB of free disk space before attempting to upgrade to or fresh install an AKS Edge Essentials 1.12 release.

## Release 1.11.247.0 (September 2025)

The following features and improvements were added in this release:

- AKS Edge Essentials version 1.11.247.0 uses Azure Linux 3.0, an upgrade from Azure Linux 2.0, which was the version used in previous releases.
- AKS Edge Essentials now connects to Azure Arc during deployment to decrease the number of steps required. Arc parameters are required in the **aks-edge** configuration file during deployment. AKS Edge Essentials deployment is blocked if Arc parameters are missing or invalid. However, this does not impact offline deployments or volume licensing customers.
- Enabling secret encryption on AKS Edge Essentials clusters with the [KMS provider](aks-edge-howto-secret-encryption.md) is now generally available for AKS Edge Essentials version 1.11.247.0 and later. 

### Supported versions for 1.11.247.0

- AKS Edge Essentials version: 1.11.247.0
- Azure Linux (previously Mariner) Version: 3.0.20250822
- K8s (upstream Kubernetes) distribution: 1.30.5 (only available as an upgrade from 1.10.868.0), 1.31.5
- K3s distribution: 1.30.6 (only available as an upgrade from 1.10.868.0), 1.31.6
- Json version schema: 1.16

### Available upgrade paths

| Current version         | Upgrade path            |
|-------------------------|-------------------------|
| 1.10.868.0 k8s/k3s 1.29 | 1.11.247.0 k8s/k3s 1.30 |
| 1.10.868.0 k8s/k3s 1.30 | 1.11.247.0 k8s/k3s 1.30 |
| 1.10.868.0 k8s/k3s 1.30 | 1.11.247.0 k8s/k3s 1.31 |

> [!NOTE]  
> Upgrading from one Kubernetes distribution to another within the same release version is not supported.

## Release 1.10.868.0 (March 2025)

The following features and improvements were added in this release:

- **Enable secret encryption on AKS Edge Essentials clusters with the Key Management Service (KMS) plugin (preview)**. Following Kubernetes best practices, it's recommended that you encrypt the Kubernetes secret store on clusters. You can enable the KMS plugin in the **aks-edge** config file during deployment. The KMS plugin is set to **disabled** by default during the preview period. For more information about this feature, see the [Key Management Service (KMS) plugin (preview)](aks-edge-howto-secret-encryption.md) documentation.
- **Key Manager for Kubernetes on AKS Edge Essentials (preview)**. [Key manager for Kubernetes](aks-edge-howto-key-manager.md) is an Azure Arc extension that automates the rotation of the signing key used to issue service account tokens. For more information about the Key Manager extension, see [Key manager for Kubernetes](aks-edge-howto-key-manager.md).
- **AKS Edge Essentials now connects to Azure Arc during deployment to decrease the number of required deployment steps.** Arc parameters are now required in the **aks-edge** configuration file during deployment. Starting with the next release, the AKS Edge Essentials deployment will be blocked if Arc parameters are missing or invalid.
- **The Calico CNI + K3s preview has been discontinued**. You must now use Flannel with K3s and Calico with K8s. For more information, see [Single machine deployment](aks-edge-howto-single-node-deployment.md#step-1-single-machine-configuration-parameters).

### Supported versions for 1.10.868.0

The component versions supported in the 1.10.868.0 release are as follows:

- AKS Edge Essentials version: 1.10.868.0
- Mariner version: 2.0.20250207
- K8s (upstream Kubernetes) distribution: 1.29.9 (upgrade only), 1.30.5
- K3s distribution: 1.29.9 (upgrade only), 1.30.6
- JSON version schema: 1.15

## Release 1.9.262.0 (November 2024)

- Updated the Mariner and Windows versions to include CVE fixes between this release and the previous release.

### Supported versions for 1.9.262.0

The component versions supported in the 1.9.262.0 release are as follows:

- AKS Edge Essentials version: 1.9.262.0
- Mariner version: 2.0.20241029
- K8s (upstream Kubernetes) distribution: 1.28.9, 1.29.4
- K3s distribution: 1.28.5, 1.29.6
- JSON version schema: 1.14

## Release 1.8.202.0 (September 2024)

- Upgrade from K3s 1.28.3 (July release) to 1.28.5 (September release), and on K8s from 1.28.3 (July release) to 1.28.9 (September release).
- Upgrade from K3s 1.27.6 (July release) to 1.28.5 (September release), and K3s 1.28.3 (July release) to 1.29.6 (September release)
- Upgrade from K8s from 1.27.6 (July release) to 1.28.9 (September release), and on K8s from 1.28.3 (July release) to 1.29.4 (September release).
- There is a new precheck during install to validate **fdatasync** latency. If disk latency is higher than 10ms, the install process returns a non-blocking warning message.

### Supported versions for 1.8.202.0

The component versions supported in the 1.8.202.0 release are as follows:

- AKS Edge Essentials version: 1.8.202.0
- Mariner version: 2.0.20240731
- K8s (upstream Kubernetes) distribution: 1.28.9, 1.29.4
- K3s distribution: 1.28.5, 1.29.6
- JSON version schema: 1.14

## Next steps

- [AKS Edge Essentials](aks-edge-overview.md)
- [AKS Edge Essentials requirements and support matrix](aks-edge-system-requirements.md)
