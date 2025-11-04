---
title: Use Azure Linux with OS Guard (preview) for Azure Kubernetes Service (AKS)
description: Learn about Azure Linux with OS Guard (preview) on Azure Kubernetes Service (AKS), including key features, region availability, and resources to get started.
ms.topic: overview
ms.custom: linux-related-content
ms.date: 10/29/2025
author: florataagen
ms.author: florataagen
ms.service: azure-kubernetes-service
# Customer intent: "As a cloud developer, I want to deploy and manage Azure Linux container with OS Guard on AKS, so that I can ensure reliable and efficient container workloads with reduced maintenance and enhanced security."
---

# Azure Linux with OS Guard (preview) for Azure Kubernetes Service (AKS) overview

This article provides an overview of Azure Linux with OS Guard (preview) on Azure Kubernetes Service (AKS), including key features, region availability, and resources to get started.

## What is Azure Linux with OS Guard?

Azure Linux with OS Guard, is a hardened, immutable variant of Azure Linux. It provides strong runtime integrity, tamper resistance, and enterprise-grade security for container hosts on AKS. OS Guard is built on Azure Linux and adds kernel and runtime features that enforce code integrity, protect the root file system from unauthorized changes, and apply mandatory access controls.

You can deploy Azure Linux with OS Guard node pools in a new cluster, add Azure Linux with OS Guard node pools to your existing Azure Linux or Ubuntu clusters, or migrate your Azure Linux or Ubuntu nodes to Azure Linux with OS Guard nodes.

To learn more about Azure Linux with OS Guard, see the [Azure Linux with OS Guard documentation][os-guard-doc]

## Why use Azure Linux with OS Guard on AKS

Azure Linux with OS Guard on AKS builds on the benefits of [Azure Linux][azurelinux-capabilities] by adding enhanced security features that help protect your container workloads from advanced threats. OS Guard provides:

- **Immutability**: The `/usr` directory is mounted as a read-only volume protected by dm-verity, preventing execution of tampered or untrusted code.
- **Code integrity**: OS Guard integrates the [Integrity Policy Enforcement (IPE) Linux Security Module](https://docs.kernel.org/next/admin-guide/LSM/ipe.html) to ensure that only binaries from trusted, signed volumes are allowed to execute. (**IPE is running in audit mode during Public Preview**.)
- **Mandatory access controls**: OS Guard integrates SELinux to limit which processes can access sensitive resources in the system. (**SELinux is operating in permissive mode during Public Preview**.)
- **Integration with Azure security features**: Native support for [Trusted Launch](/aks/use-trusted-launch) and Secure Boot provides measured boot protections and attestation.
- **Verified container layers**: Container images and layers are validated using signed dm-verity hashes. This ensures that only verified layers are used at runtime, reducing the risk of container escape or tampering.
- **Sovereign Supply Chain Security**: OS Guard inherits Azure Linux’s secure build pipelines, signed Unified Kernel Images (UKIs) and Software Bill of Materials (SBOMs).

Learn more about the [key features of Azure Linux with OS Guard][os-guard-doc].

## Regional availability

Azure Linux with OS Guard is available for use in the same [regions](/aks/quotas-skus-regions) as AKS.

## Get started with Azure Linux with OS Guard on AKS

Get started with Azure Linux with OS Guard on AKS using the following resources:

- [Creating a cluster with Azure Linux with OS Guard][os-guard-quickstart]
- [How to upgrade Azure Linux with OS Guard clusters][os-guard-upgrade]
- [Add an Azure Linux with OS Guard node pool to your existing cluster][os-guard-add-node-pool]
- [Migrate to Azure Linux with OS Guard][os-guard-migrate]
- [Enable telemetry and monitoring on an Azure Linux with OS Guard cluster][os-guard-monitoring]


## Next steps

To learn more about Azure Linux with OS Guard, see the [Azure Linux with OS Guard documentation][os-guard-doc].

<!-- LINKS - Internal -->
[azurelinux-doc]: /azure/azure-linux/intro-azure-linux
[azurelinux-capabilities]: /azure/azure-linux/intro-azure-linux#azure-linux-container-host-key-benefits
[os-guard-doc]: /azure/azure-linux/intro-azure-linux-os-guard
[os-guard-quickstart]: /azure/azure-linux/quickstart-os-guard-azure-cli
[os-guard-upgrade]: /azure/azure-linux/tutorial-azure-linux-os-guard-upgrade
[os-guard-add-node-pool]: /azure/azure-linux/tutorial-azure-linux-os-guard-add-node-pool
[os-guard-migrate]: /azure/azure-linux/tutorial-azure-linux-os-guard-migration
[os-guard-monitoring]: /azure/azure-linux/tutorial-azure-linux-os-guard-telemetry-monitoring

