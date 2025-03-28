---
title: Security bulletins for Azure Kubernetes Service (AKS)
description: This article provides security/vulnerability related updates and troubleshooting guides for Azure Kubernetes Services (AKS).
ms.date: 03/27/2025
author: bahe
ms.author: bahe
ms.topic: conceptual
ms.subservice: aks-security
---

# Security bulletins for Azure Kubernetes Service (AKS)

This page provides up-to-date information on security vulnerabilities affecting Azure Kubernetes Service(AKS) and its components. This includes details on:

- Critical Security Advisories – High-impact security vulnerabilities, including zero-day vulnerabilities and other critical CVEs requiring immediate attention, along with mitigation guidance.
- Ongoing Security Investigations – Security issues under review, including CVEs where a patch is not yet available or further assessment is needed.
- False Positives & Non-Exploitable CVEs – Cases where a reported CVE does not impact AKS due to specific configurations, mitigations, or lack of exploitability.

These updates cover security information related to the following AKS components:

- Azure Kubernetes Service (AKS)
- Azure Kubernetes Service Node Image (AKS Node Image)
- Azure Kubernetes Service Addons (AKS Addons)

---

## AKS-2025-006 Important Security Update for Kubernetes Nginx Ingress Controller

**Published Date**: March 24, 2025

### Description
Several security vulnerabilities affecting the Kubernetes nginx ingress controller were disclosed on March 24, 2025: CVE-2025-1098 (High), CVE-2025-1974 (Critical), CVE-2025-1097 (High), CVE-2025-24514 (High), and CVE-2025-24513 (Medium).
The CVEs impact ingress-nginx. (If you do not have ingress-nginx installed on your cluster, you are not affected.)
You can check for ingress-nginx by running `kubectl get pods --all-namespaces --selector app.kubernetes.io/name=ingress-nginx` .

### References

- [CVE-2025-1098](https://github.com/kubernetes/kubernetes/issues/131008)
- [CVE-2025-1974](https://github.com/kubernetes/kubernetes/issues/131009) 
- [CVE-2025-1097](https://github.com/kubernetes/kubernetes/issues/131007)
- [CVE-2025-24514](https://github.com/kubernetes/kubernetes/issues/131006)
- [CVE-2025-24513](https://github.com/kubernetes/kubernetes/issues/131005)

### Affected Components

#### [**AKS Addons**](#tab/aks-addons)

**Affected Versions**

- < v1.11.0
- v1.11.0 - 1.11.4
- v1.12.0


**Resolutions**

- If you are using the [Managed NGINX ingress with the application routing add-on](../app-routing.md) on AKS, the patches are getting rolled out to all regions with the AKS v2050316 release. **No action is required**. You can check the release status from [AKS release tracker][aks-release-tracker].

- If you are running your own Kubernetes NGINX Ingress Controller, review the CVEs and mitigate by updating to the latest patch versions (v1.11.5 and v1.12.1).

---

## AKS-2025-005 Important Security Update for Calico v3.26 Users

**Published Date**: March 24, 2025

### Description

Multiple security issues have been discovered in Calico version 3.26, which is now end of life and no longer receives security fixes. If you are using Calico version 3.26 on AKS Cluster version 1.29.x or earlier, you will no longer receive security patches for Calico.

### References

- [Calico End of Life](https://endoflife.date/calico)

### Affected Components

#### [**AKS Cluster**](#tab/aks-cluster)

**Affected Versions**

- AKS version 1.29 and earlier


**Resolutions**

Upgrade AKS cluster version to 1.30 or later that uses Calico version 3.28

---

## AKS-2025-004 Issue in ancillary function driver for WinSock in Windows

**Published Date**: February 11, 2025

### Description

A security issue was discovered in the ancillary function driver for WinSock in Windows. This vulnerability allows attackers to exploit network communication flaws, potentially leading to elevation of privilege.

### References
- [CVE-2025-21418](https://nvd.nist.gov/vuln/detail/CVE-2025-21418)

### Affected Components

#### [**AKS Node Image**](#tab/aks-node-image)

**Affected Versions**

- Windows version 17763.6775.250117
- Windows version 20348.3091.250117
- Windows version 25398.1369.250117


**Resolutions**

Upgrade Windows node image version to:
- 17763.6775.250214
- 20348.3091.250214
- 25398.1369.250214
- or later

---

## AKS-2025-003 Elevation of Privilege in Windows Storage

**Published Date**: February 11, 2025

### Description

A security issue was discovered in Windows Storage that allows attackers with low-level access to exploit system flaws and gain higher privileges. This vulnerability can potentially lead to the execution of arbitrary code or access to sensitive data.

### References
- [CVE-2025-21391](https://nvd.nist.gov/vuln/detail/CVE-2025-21391)

### Affected Components

#### [**AKS Node Image**](#tab/aks-node-image)

**Affected Versions**

- Windows version 17763.6775.250117
- Windows version 20348.3091.250117
- Windows version 25398.1369.250117


**Resolutions**

Upgrade Windows node image version to:

- 17763.6775.250214
- 20348.3091.250214
- 25398.1369.250214
- or later

---

## AKS-2025-002 NTLM Hash Disclosure Spoofing

**Published Date**: February 11, 2025

### Description

A security issue was discovered that exposes Windows users' NTLM hashes. This type of vulnerability can lead to pass-the-hash attacks, where a remote attacker captures and later uses a hash to impersonate a user without needing the plain-text password.

### References

- [CVE-2025-21377](https://nvd.nist.gov/vuln/detail/CVE-2025-21377)


### Affected Components

#### [**AKS Node Image**](#tab/aks-node-image)

**Affected Versions**

- Windows version 17763.6775.250117
- Windows version 20348.3091.250117
- Windows version 25398.1369.250117


**Resolutions**

Upgrade Windows node image version to:

- 17763.6775.250214
- 20348.3091.250214
- 25398.1369.250214
- or later

---

## AKS-2025-001 ServerConfig.PublicKeyCallback Issue in golang/crypto

**Published Date**: December 11, 2024

### Description

A security issue was discovered in the ServerConfig.PublicKeyCallback callback, which may be susceptible to an authorization bypass. This vulnerability arises when applications and libraries misuse the connection.serverAuthenticate method. Specifically, the SSH protocol allows clients to inquire about whether a public key is acceptable before proving control of the corresponding private key. This can lead to incorrect authorization decisions based on keys that the attacker does not actually control

AKS is aware of the vulnerability. However, this CVE is not exploitable for kubernetes. The vulnerability only affects those who are using the PublicKeyCallback API. Since golang does not use this API in the Kubernetes setup, and the only use of the entire package is within a test suite golang.org/x/crypto is not vulnerable. The vulnerability will be patched in the upcoming Kubernetes release 1.33. 

### References
- [CVE-2024-45337](https://nvd.nist.gov/vuln/detail/CVE-2024-45337)

### Affected Components

#### [**AKS Cluster**](#tab/aks-cluster)

**Affected Versions**

- AKS version 1.32 and earlier

**Resolutions**

Fix** will be available** in AKS cluster version 1.33

---


<!--- enable this section when we are approaching the end of 2025
---

## Archived bulletins

For security bulletins from previous years, see:

- [2025](2025.md)

---
-->

## Next Steps

- Get updates about the latest node images with [AKS release notes][aks-release-notes].
- Learn how to upgrade the AKS node image with [Upgrade Azure Kubernetes Service (AKS) node images][node-image-upgrade].
- Learn how to automatically upgrade node images with [Automatically upgrade node images][auto-upgrade-node-image].
- Learn how to upgrade the Kubernetes version with [Upgrade an AKS cluster][upgrade-cluster].
- Learn about upgrading best practices with [AKS patch and upgrade guidance][upgrade-operators-guide].


<!-- LINKS - internal -->
[node-image-upgrade]: ../node-image-upgrade.md
[auto-upgrade-node-image]: ../auto-upgrade-node-image.md
[upgrade-cluster]: ../upgrade-aks-cluster.md
[upgrade-operators-guide]: /azure/architecture/operator-guides/aks/aks-upgrade-practices

<!-- LINKS - external -->
[aks-release-notes]: https://github.com/Azure/AKS/releases
[aks-release-tracker]: https://releases.aks.azure.com/https://github.com/Azure/AKS/releases
