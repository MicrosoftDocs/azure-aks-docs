---
title: Security bulletins for Azure Kubernetes Service (AKS)
description: This article provides security/vulnerability related updates and troubleshooting guides for Azure Kubernetes Services (AKS).
ms.date: 02/03/2025
author: bahe
ms.author: bahe
ms.topic: conceptual
ms.subservice: aks-security
---

# Security bulletins for Azure Kubernetes Service (AKS)

This page describes the security / vulnerability updates information about the components used in Azure Kubernetes Service (AKS):

- Azure Kubernetes Service (AKS)
- Azure Kubernetes Service Node Image (AKS Node Image)
- Azure Kubernetes Service Addons (AKS Addons)

## AKS-2025-002 Nvidia Container Toolkit Issues

**Published Date**: 02/03/2025

### Description

NVIDIA Container Toolkit 1.16.1 or earlier contains a Time-of-check Time-of-Use (TOCTOU) vulnerability when used with default configuration where a specifically crafted container image may gain access to the host file system. This does not impact use cases where CDI is used. A successful exploit of this vulnerability may lead to code execution, denial of service, escalation of privileges, information disclosure, and data tampering.

### References

- [CVE-2024-0132](https://nvd.nist.gov/vuln/detail/cve-2024-0132)
- [CVE-2024-0133](https://nvd.nist.gov/vuln/detail/cve-2024-0133)

### Affected Components

#### [**AKS Node Image**](#tab/aks-node-image)

**Affected Versions**

- Azure Linux 202409.30.0
- Ubuntu 202409.30.0

**Resolutions**

Upgrade AKS node image to 202410.09.0 or later.

---


## AKS-2025-001 Incorrect permissions on Windows containers logs

**Published Date**: 01/03/2025

### Description

A security issue was discovered in Kubernetes clusters with Windows nodes where `BUILTIN\Users` may be able to read container logs and `NT AUTHORITY\Authenticated Users` may be able to modify container logs.

### References

- [CVE-2024-5321](https://nvd.nist.gov/vuln/detail/cve-2024-5321)
- [kubernetes/kubernetes #126161](https://github.com/kubernetes/kubernetes/issues/126161)

### Affected Components

#### [**AKS**](#tab/aks)

**Affected Versions**

- Kubernetes: <= 1.27.15 / <= 1.28.11 / <= 1.29.6 / <= 1.30.2

**Resolutions**

Upgrade AKS cluster Kubernetes version to 1.27.16 / 1.28.12 / 1.29.7 / 1.30.3 or later.

---

## Archived bulletins

For security bulletins from previous years, see:

- [2024](2024.md)
- [2023](2023.md)

---

## Next Steps

- For information about the latest node images, see the [AKS release notes](https://github.com/Azure/AKS/releases).
- Learn how to upgrade the AKS node image with [Upgrade Azure Kubernetes Service (AKS) node images][node-image-upgrade].
- Learn how to automatically upgrade node images with [Automatically upgrade node images][auto-upgrade-node-image].
- Learn how to upgrade the Kubernetes version with [Upgrade an AKS cluster][upgrade-cluster].
- Learn about upgrading best practices with [AKS patch and upgrade guidance][upgrade-operators-guide].


<!-- LINKS - internal -->
[node-image-upgrade]: node-image-upgrade.md
[auto-upgrade-node-image]: auto-upgrade-node-image.md
[upgrade-cluster]: upgrade-aks-cluster.md
[upgrade-operators-guide]: /azure/architecture/operator-guides/aks/aks-upgrade-practices