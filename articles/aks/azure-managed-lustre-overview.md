---
title: Use the Azure Managed Lustre CSI Driver with Azure Kubernetes Service
description: Learn how to use an Azure Managed Lustre storage system with your Kubernetes containers in Azure Kubernetes Service (AKS).
ms.topic: overview
ms.subservice: aks-storage
ms.date: 10/30/2026
author: pauljewellmsft
ms.author: akashdubey
ms.reviewer: brianl
ms.custom: sfi-image-nochange

# Intent: As an IT pro, I want to be able to use a Lustre file system with the apps I've deployed on Kubernetes.
# Keyword:

---

# Use the Azure Managed Lustre CSI driver with Azure Kubernetes Service

Use the Azure Managed Lustre Container Storage Interface (CSI) driver to connect [Azure Managed Lustre](/azure/azure-managed-lustre) storage to workloads in [Azure Kubernetes Service (AKS)](/azure/aks/). Workloads use storage classes, persistent volumes, and persistent volume claims to access the file system.

Use these AKS guides to install the driver and manage volumes:

| Task | Guide |
| --- | --- |
| Install the driver | [Install the Azure Managed Lustre CSI driver](azure-managed-lustre-install.md) |
| Connect an existing file system | [Static provisioning](azure-managed-lustre-static-provisioning.md) |
| Create a file system for a claim | [Dynamic provisioning](azure-managed-lustre-dynamic-provisioning.md) |
| Upgrade or remove the driver | [Upgrade or uninstall the Azure Managed Lustre CSI driver](azure-managed-lustre-uninstall.md) |

> [!IMPORTANT]
> The AKS enable and disable options are preview features supplied by `aks-preview`. Follow the installation guide for CLI prerequisites. Don't install another copy of the CSI driver alongside the managed extension.

This section provides compatibility, networking, and provisioning reference information for AKS. For file system creation and management, see the [Azure Managed Lustre documentation](/azure/azure-managed-lustre). The default installation and lifecycle guides describe Helm and script procedures. The alternative AKS CLI option has dedicated [installation](azure-managed-lustre-install-cli-preview.md) and [upgrade/uninstall](azure-managed-lustre-upgrade-uninstall-cli-preview.md) pages. Both options are in preview.

## Supported Kubernetes and AKS versions

The Azure Lustre CSI Driver for Kubernetes is compatible with [AKS](/azure/aks/). Other Kubernetes installations aren't currently supported.

Version 0.6.0 requires Kubernetes 1.29 or later because the node plugin uses a native sidecar container.

> [!IMPORTANT]
> Version 0.6.0 provides images for Ubuntu 22.04 (`Ubuntu2204`), Ubuntu 24.04 (`Ubuntu2404`), and Azure Linux 3 (`AzureLinux3`) node pools. The Jammy DaemonSet also targets Ubuntu 20.04 (`Ubuntu2004`) Confidential VM node pools as a deprecated compatibility path. Windows node pools aren't supported.

The Azure Lustre CSI Driver for Kubernetes is compatible with [Azure Managed Lustre](/azure/azure-managed-lustre). Other Lustre installations aren't currently supported.

### Azure Lustre CSI Driver versions

The following table describes upstream CSI driver releases, including v0.6.0. It isn't a catalog of managed-extension versions and doesn't mean the AKS enable command pins version 0.6.0. Use the AKS installation guide to inspect the installed extension version, and confirm the corresponding driver release before applying version-specific requirements.

Version 0.6.0 uses separate node images for Ubuntu 22.04 (Jammy), Ubuntu 24.04 (Noble), and Azure Linux 3. Kubernetes schedules the appropriate driver pod by using the `kubernetes.azure.com/os-sku-effective` node label. Jammy and Azure Linux 3 node images support amd64; Noble supports amd64 and arm64.

The controller uses the Noble image, which supports amd64 and arm64.

| Driver version | Image | AKS node OS SKU | Supported k8s version | Lustre client version | Dynamic Provisioning |
| --- | --- | --- | --- | --- | --- |
| v0.6.0 (Jammy) | mcr.microsoft.com/oss/v2/kubernetes-csi/azurelustre-csi:v0.6.0-jammy | `Ubuntu2204`; `Ubuntu2004` Confidential VM node pools | 1.29+ | 2.15.8 | ✅ |
| v0.6.0 (Noble) | mcr.microsoft.com/oss/v2/kubernetes-csi/azurelustre-csi:v0.6.0-noble | `Ubuntu2404` | 1.29+ | 2.17.0 | ✅ |
| v0.6.0 (Azure Linux 3) | mcr.microsoft.com/oss/v2/kubernetes-csi/azurelustre-csi:v0.6.0-azurelinux3 | `AzureLinux3` | 1.29+ | 2.17.0 | ✅ |
| v0.4.0 (Jammy) | mcr.microsoft.com/oss/v2/kubernetes-csi/azurelustre-csi:v0.4.0-jammy | `Ubuntu2204`; `Ubuntu2004` Confidential VM node pools | 1.21+ | 2.15.7 | ✅ |
| v0.4.0 (Noble) | mcr.microsoft.com/oss/v2/kubernetes-csi/azurelustre-csi:v0.4.0-noble | `Ubuntu2404` | 1.21+ | 2.16.1 | ✅ |
| v0.3.1 | mcr.microsoft.com/oss/v2/kubernetes-csi/azurelustre-csi:v0.3.1 | Ubuntu Linux | 1.21+ | 2.15.7 | ✅ |
| v0.3.0 | mcr.microsoft.com/oss/v2/kubernetes-csi/azurelustre-csi:v0.3.0 | Ubuntu Linux | 1.21+ | 2.15.5 | ✅ |
| v0.2.0 | mcr.microsoft.com/oss/v2/kubernetes-csi/azurelustre-csi:v0.2.0 | Ubuntu Linux | 1.21+ | 2.15.5 | ❌ |
| v0.1.18 | mcr.microsoft.com/oss/kubernetes-csi/azurelustre-csi:v0.1.18 | Ubuntu Linux | 1.21+ | 2.15.5 | ❌ |
| v0.1.17 | mcr.microsoft.com/oss/kubernetes-csi/azurelustre-csi:v0.1.17 | Ubuntu Linux | 1.21+ | 2.15.5 | ❌ |
| v0.1.15 | mcr.microsoft.com/oss/kubernetes-csi/azurelustre-csi:v0.1.15 | Ubuntu Linux | 1.21+ | 2.15.4 | ❌ |
| v0.1.14 | mcr.microsoft.com/oss/kubernetes-csi/azurelustre-csi:v0.1.14 | Ubuntu Linux | 1.21+ | 2.15.3 | ❌ |
| v0.1.13 | mcr.microsoft.com/oss/kubernetes-csi/azurelustre-csi:v0.1.13 | Ubuntu Linux | 1.21+ | 2.15.4 | ❌ |
| v0.1.12 | mcr.microsoft.com/oss/kubernetes-csi/azurelustre-csi:v0.1.12 | Ubuntu Linux | 1.21+ | 2.15.3 | ❌ |
| v0.1.11 | mcr.microsoft.com/oss/kubernetes-csi/azurelustre-csi:v0.1.11 | Ubuntu Linux | 1.21+ | 2.15.1 | ❌ |
| v0.1.10 | mcr.microsoft.com/oss/kubernetes-csi/azurelustre-csi:v0.1.10 | Ubuntu Linux | 1.21+ | 2.15.2 | ❌ |

For a complete list of all driver releases and their changelog, see the [Azure Lustre CSI driver releases page](https://github.com/kubernetes-sigs/azurelustre-csi-driver/releases).

> [!NOTE]
> Version 0.6.0 requires AKS node pools that report the `kubernetes.azure.com/os-sku-effective` label, in addition to the Kubernetes version requirement shown in the table.

## Prerequisites

- An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).
- A terminal environment with the Azure CLI tools installed. See [Get started with the Azure CLI](/cli/azure/get-started-with-azure-cli).
- [kubectl](https://kubernetes.io/docs/reference/kubectl), the Kubernetes management tool, installed in your terminal environment. See [Quickstart: Deploy an Azure Kubernetes Service (AKS) cluster by using the Azure CLI](/azure/aks/learn/quick-kubernetes-deploy-cli#connect-to-the-cluster).
- The tools and access required by [Install the Azure Managed Lustre CSI driver](azure-managed-lustre-install.md#prerequisites). Additional CLI extensions are required only for the preview AKS CLI option.
- An AKS cluster that meets the [compatibility requirements](#supported-kubernetes-and-aks-versions).
- For static provisioning, an existing Azure Managed Lustre deployment. Dynamic provisioning creates the file system. See the [Azure Managed Lustre documentation](/azure/azure-managed-lustre).
- **Network connectivity** between your AKS cluster and Azure Managed Lustre virtual network. See [Plan network architecture for AKS with Azure Managed Lustre](azure-managed-lustre-network-planning.md) for configuration options.
- Sufficient subnet IP addresses and the inbound and outbound access described in [Azure Managed Lustre network prerequisites](/azure/azure-managed-lustre/amlfs-prerequisites#network-prerequisites). New private subnets need an explicit outbound connection, such as a NAT gateway.
- Network access required for the extension and its driver images and client packages. AKS nodes need access to MCR, `packages.microsoft.com`, and their node image's OS package repositories.
- Appropriate nodes for the controller deployment, plus eligible nodes for your Lustre workloads. For nodes with custom taints that restrict pod scheduling, see the [node pool guidance](https://github.com/kubernetes-sigs/azurelustre-csi-driver/blob/v0.6.0/docs/install-csi-driver.md#node-pool-taints-and-tolerations).

## Provisioning methods

The Azure Lustre CSI Driver supports dynamic and static provisioning.

### Dynamic provisioning (available in v0.3.0+)

Dynamic provisioning allows the CSI driver to automatically create Azure Managed Lustre file systems on demand when persistent volume claims are created.

> [!NOTE]
> Dynamic provisioning is available starting with Azure Lustre CSI Driver version 0.3.0. For more information, see the [v0.3.0 release notes](https://github.com/kubernetes-sigs/azurelustre-csi-driver/releases/tag/v0.3.0).

For the walkthrough, see [Dynamically provision Azure Managed Lustre volumes for AKS](azure-managed-lustre-dynamic-provisioning.md). For identity permissions and file system settings, see the [dynamic provisioning reference](azure-managed-lustre-dynamic-provisioning-reference.md).

### Static provisioning

Static provisioning uses an existing Azure Managed Lustre file system. This method involves:
- Creating storage classes that reference existing Lustre clusters
- Specifying the Lustre Management Service (MGS) IP address, which clients use to retrieve file system configuration
- Suitable for scenarios where you have preexisting Lustre infrastructure

For existing file system requirements and the walkthrough, see [Statically provision Azure Managed Lustre volumes for AKS](azure-managed-lustre-static-provisioning.md).

## Install the CSI driver

Install the driver once for either provisioning method. Follow [Install the Azure Managed Lustre CSI driver](azure-managed-lustre-install.md) for Helm, script, and alternative AKS CLI installation instructions. Don't install a second driver over an existing installation.

## Upgrade the CSI driver

Follow [Upgrade the CSI driver](azure-managed-lustre-uninstall.md#upgrade-the-csi-driver) for Helm or script installations. For the preview AKS CLI option, see [Upgrade an AKS CLI installation (preview)](azure-managed-lustre-upgrade-uninstall-cli-preview.md#upgrade-an-aks-cli-installation-preview). Re-enabling a successfully installed extension doesn't upgrade or reinstall it.

## Uninstall the driver

Use the [uninstall procedure matching your installation method](azure-managed-lustre-uninstall.md#choose-the-matching-uninstall-method). Stop workloads and let volumes unmount before removing the driver. Keep volume and data cleanup separate from driver removal, and follow the additional volume-cleanup requirements for the preview AKS CLI option.

## Troubleshooting

To troubleshoot issues with the Azure Lustre CSI Driver, see the [v0.6.0 CSI driver troubleshooting guide](https://github.com/kubernetes-sigs/azurelustre-csi-driver/blob/v0.6.0/docs/csi-debug.md) in the GitHub repository.

Common issues include:

- **Network connectivity problems** - verify virtual network peering or subnet configuration between AKS and Azure Managed Lustre.
- **Incorrect configuration** - verify the MGS IP address in your storage class.
- **Pod scheduling issues** - verify that the node's effective OS SKU is `Ubuntu2204`, `Ubuntu2404`, `AzureLinux3`, or `Ubuntu2004` for a Confidential VM node pool. Check node architecture and taints too.
- **No v0.6.0 node pod on an AKS node** - verify that the `kubernetes.azure.com/os-sku-effective` label is present and matched by the Jammy, Noble, or Azure Linux 3 DaemonSet.
- **A DaemonSet has zero desired pods** - this condition is expected if no eligible nodes match that flavor. Confirm that every intended workload node has a CSI node pod.
- **Upgrade rollout timeout** - inspect the DaemonSet status, affected pod events, and both `lustre-loader` and `azurelustre` container logs before retrying.
- **Unexpected driver or client version** - capture the installed extension and driver versions before requesting support. Don't change the extension-managed chart or images directly.
- **Resource ownership conflicts** - identify any existing Helm, script, or differently named extension installation. Don't install a second driver or remove live storage resources as a recovery shortcut.
- **Image pull or Lustre client installation failures** - verify node egress to `mcr.microsoft.com` and `packages.microsoft.com`.
- **Permission issues during dynamic provisioning** - check the identity that the CSI controller uses against the [dynamic provisioning permission requirements](azure-managed-lustre-dynamic-provisioning-reference.md#permissions).

For provisioning-specific issues, see [Dynamic provisioning troubleshooting](azure-managed-lustre-dynamic-provisioning-reference.md#troubleshooting) or [Static provisioning troubleshooting](azure-managed-lustre-static-provisioning.md#troubleshooting).

For additional troubleshooting resources, see:

- [Troubleshoot Azure Managed Lustre CSI driver extension errors](/troubleshoot/azure/azure-kubernetes/extensions/troubleshoot-azurelustre-csi-extension-errors)
- [Azure Managed Lustre troubleshooting](/azure/azure-managed-lustre/troubleshoot-deployment)
- [Azure Lustre CSI Driver GitHub repository](https://github.com/kubernetes-sigs/azurelustre-csi-driver)

## Image security

The installation method determines the driver's namespace and how it manages resources. Don't assume that a managed extension uses the namespace from a Helm or script installation example.

Namespace placement alone doesn't establish image authenticity or define the supported policy configuration. Follow the guidance in [AKS Image Integrity](image-integrity.md). Don't change extension-managed images or add policy exclusions solely to make installation succeed.

Identify the deployed images before using version-specific verification commands. The [v0.6.0 image-verification reference](azure-managed-lustre-image-security.md) doesn't establish the version of a managed extension or verify all of its component images.

## Related content

- [Plan network architecture for AKS with Azure Managed Lustre](azure-managed-lustre-network-planning.md).
- [Install the Azure Managed Lustre CSI driver](azure-managed-lustre-install.md).
- [Statically provision volumes on AKS](azure-managed-lustre-static-provisioning.md).
- [Dynamically provision volumes on AKS](azure-managed-lustre-dynamic-provisioning.md).
- [Upgrade or uninstall the Azure Managed Lustre CSI driver](azure-managed-lustre-uninstall.md).
- [Export data from Azure Managed Lustre to Blob Storage](/azure/azure-managed-lustre/export-data)
- [Azure Lustre CSI Driver GitHub repository](https://github.com/kubernetes-sigs/azurelustre-csi-driver)
