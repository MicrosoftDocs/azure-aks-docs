---
title: Security bulletins for Azure Kubernetes Service (AKS)
description: This article provides security/vulnerability related updates and troubleshooting guides for Azure Kubernetes Services (AKS).
ms.date: 10/23/2025
author: bcho
ms.author: bahe
ms.topic: concept-article
ms.subservice: aks-security
# Customer intent: "As a Kubernetes administrator, I want to access updated security bulletins for Azure Kubernetes Service, so that I can address vulnerabilities and ensure the security of my clusters and applications."
---

# Security bulletins for Azure Kubernetes Service (AKS)

This page provides up-to-date information on security vulnerabilities affecting Azure Kubernetes Service(AKS) and its components. This information includes details on:

- Critical Security Advisories – High-impact security vulnerabilities, including zero-day vulnerabilities and other critical CVEs requiring immediate attention, along with mitigation guidance.
- Ongoing Security Investigations – Security issues under review, including CVEs where a patch isn't yet available or further assessment is needed.
- False Positives & Non-Exploitable CVEs – Cases where a reported CVE doesn't impact AKS due to specific configurations, mitigations, or lack of exploitability.

These updates cover security information related to the following AKS components:

- Azure Kubernetes Service (AKS)
- Azure Kubernetes Service Node Image (AKS Node Image)
- Azure Kubernetes Service Addons (AKS add-ons)

---

## AKS-2025-0013  Portworx Half-Blind SSRF in kube-controller-manager

**Published Date**: December 1, 2025

### Description
This bulletin provides an update regarding a recent vulnerability in the Kubernetes kube-controller-manager when using the in-tree Portworx StorageClass. This issue allows authorized users to leak arbitrary information from unprotected endpoints in the control plane’s host network (including link-local or loopback services). 

The in-tree Portworx StorageClass has been disabled by default starting in Kubernetes v1.31 via the CSIMigrationPortworx feature gate. As a result, currently supported versions ≥ v1.32 are not impacted unless the CSIMigrationPortworx feature gate has been manually disabled.

### References

- [CVE-2025-13281](https://github.com/kubernetes/kubernetes/issues/135525)

### Affected Components

#### [**AKS Cluster**](#tab/aks-cluster)

**Affected Versions**

- AKS v1.28-akslts
- AKS v1.29-akslts
- AKS v1.30-akslts

**Resolutions**

- A security patch has been rolled out for the impacted lts versions.
- **No action is required**. The patch will be automatically applied to your cluster during your configured or default [maintenance window](../planned-maintenance.md).

---

## AKS-2025-0012 Runc CVEs - CVE-2025-31133, CVE-2025-52565, CVE-2025-52881

**Published Date**: November 7, 2025

### Description

The bulletin provides an update regarding the recent vulnerabilities (CVE-2025-31133, CVE-2025-52565, CVE-2025-52881) disclosed from runc.

### References

- [CVE-2025-31133](https://github.com/advisories/GHSA-9493-h29p-rfm2)
- [CVE-2025-52565](https://github.com/advisories/GHSA-qw9x-cqr3-wc7r)
- [CVE-2025-52881](https://github.com/advisories/GHSA-cgrx-mc8f-2prm)

### Affected Components

#### [**AKS Node Image**](#tab/aks-node-image)

**Affected Versions**

- Linux node image versions prior to 202511.07.0

**Resolutions**

- Newer node image versions have been rolled out. Upgrade Linux node image version to
  - 202511.07.0
  - or later. You can check the latest node image versions from [AKS release notes][aks-release-notes].

---

## AKS-2025-0011  Malicious NPM Packages used in Supply Chain Attacks

**Published Date**: October 1, 2025

### Description
This bulletin provides an update on Node Package Manager (NPM) packages being compromised. There has been a series of recent NPM supply chain attacks resulting in packages being used to perform malicious activity such as delivering malware or stealing credentials.
The vulnerability **does not** impact Azure Kubernetes Service (AKS), as Node.js is **not used** in any AKS core or managed components.

### References

- [NPM Security Advisories](https://github.com/advisories?query=npm)
- [Ongoing Supply Chain Attack Targets CrowdStrike NPM Packages](https://socket.dev/blog/ongoing-supply-chain-attack-targets-crowdstrike-npm-packages#Compromised-Packages-and-Versions)

### Affected Components

#### [**AKS Cluster**](#tab/aks-cluster)

**Affected Versions**

- None

**Resolutions**

- AKS does not use Node.js in any core or managed components and is not affected by these attacks. **No customer action is required.** 

---

## AKS-2025-0010  Nodes can delete themselves by adding an OwnerReference

**Published Date**: August 15, 2025

### Description
A security issue has been identified in the Kubernetes NodeRestriction admission controller that could allow node users to delete their own node object by patching it with an OwnerReference to a cluster-scoped resource. If the referenced resource or the node object is deleted, Kubernetes garbage collection may remove the node object.
This issue arises because node users are authorized to perform create and patch operations, but not delete. A compromised node could exploit this to recreate its node object with modified taints or labels, potentially influencing pod scheduling and gaining control over workloads

### References

- [CVE-2025-5187](https://github.com/kubernetes/kubernetes/issues/133471)

### Affected Components

#### [**AKS Cluster**](#tab/aks-cluster)

**Affected Versions**

- [All supported Kubernetes versions](../supported-kubernetes-versions.md)

**Resolutions**

- A security patch has been rolled out in 20250720 and 20250808 release. You can check the release status from [AKS release tracker][aks-release-tracker].
- **No action is required**. The patch will be automatically applied to your cluster during your configured or default [maintenance window](../planned-maintenance.md).

---
## AKS-2025-009 Important Security Update for Calico Users

**Published Date**: July 21, 2025

### Description
This bulletin provides an update on the security patching model for Calico in Azure Kubernetes Service (AKS). AKS-managed Calico and Tigera Operator are now fully aligned with upstream [Calico releases](https://github.com/projectcalico/calico/releases) and [Tigera Operator releases](https://github.com/tigera/operator/releases). This means that AKS will no longer independently patch Calico and Tigera operator images but will instead mirror upstream builds directly. 

As a result, CVEs affecting Calico and Tigera Operator will remain unpatched in AKS until a fix is available upstream. This change ensures consistency with upstream behavior and improves transparency in patch timelines.

### References
- [Calico Release](https://github.com/projectcalico/calico/releases)
- [Tigera Operator Release](https://github.com/tigera/operator/releases)

### Affected Components

#### [**AKS Cluster**](#tab/aks-cluster)

**Affected Versions**
- All AKS supported versions using AKS managed Calico

**Resolutions**
- No immediate action is required. Customers are encouraged to monitor upstream Calico releases and the [AKS CVE Status Tracker](https://releases.aks.azure.com/webpage/index.html) for updates.
- If this creates an unreasonable security burden, you may [remove calico](/azure/aks/use-network-policies#uninstall-azure-network-policy-manager-or-calico) by setting network-policy to none.  

---

## AKS-2025-008 Nodes can bypass dynamic resource allocation authorization checks

**Published Date**: June 19, 2025

### Description

A security issue has been identified in Kubernetes related to the DynamicResourceAllocation feature. When enabled, this feature may allow users with pod creation privileges to escalate privileges or access unauthorized resources on the node.

This vulnerability only affects clusters where the DynamicResourceAllocation feature is explicitly enabled.

### References

- [CVE-2025-4563](https://github.com/kubernetes/kubernetes/issues/132151)

### Affected Components

#### [**AKS Cluster**](#tab/aks-cluster)

**Affected Versions**

- None

**Resolutions**

- AKS does not support or enable the `DynamicResourceAllocation` feature in any supported version. AKS clusters are not vulnerable to this issue.
- Although AKS is not affected, the upstream fix will be included in the following AKS cluster versions:
  - AKS 1.32.6
  - AKS 1.33.2
- No customer action is required unless you are preparing for future use of this feature. Customers are encouraged to upgrade to the fixed versions once available.


---

## AKS-2025-007 Important Security Update for Kubernetes Nginx Ingress Controller

**Published Date**: March 24, 2025

### Description
Several security vulnerabilities affecting the Kubernetes nginx ingress controller were disclosed on March 24, 2025: CVE-2025-1098 (High), CVE-2025-1974 (Critical), CVE-2025-1097 (High), CVE-2025-24514 (High), and CVE-2025-24513 (Medium).
The CVEs impact ingress-nginx. (If you don't have ingress-nginx installed on your cluster, you aren't affected.)
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

- If you're using the [Managed NGINX ingress with the application routing add-on](../app-routing.md) on AKS, the patches are getting rolled out to all regions with the AKS v2050316 release. **No action is required**. You can check the release status from [AKS release tracker][aks-release-tracker].

- If you're running your own Kubernetes NGINX Ingress Controller, review the CVEs and mitigate by updating to the latest patch versions (v1.11.5 and v1.12.1).

---

## AKS-2025-006 GitRepo Volume Inadvertent Local Repository Access
 
**Published Date**: March 13, 2025
 
### Description
A security vulnerability was discovered in Kubernetes that could allow a user with create pod permission to exploit gitRepo volumes to access local git repositories belonging to other pods on the same node. This CVE only affects Kubernetes clusters that utilize the in-tree gitRepo volume to clone git repositories from other pods within the same node. Since the in-tree gitRepo volume feature has been deprecated and will not receive security updates from Kubernetes upstream, any cluster still using this feature remains vulnerable.
 
### References
 
- [CVE-2025-1767](https://github.com/kubernetes/kubernetes/issues/130786)
 
 
### Affected Components
 
#### [**AKS Cluster**](#tab/aks-cluster)
 
**Affected Versions**
 
- All AKS cluster versions
 
 
**Resolutions**
 
- Since the in-tree gitRepo volume feature has been deprecated, there is no fix available for the CVE.
 
- To ensure only allowed volume types are allowed, assign Azure built-in policy definition- [Kubernetes cluster pods should only use allowed volume types](https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyDetail.ReactView/id/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F16697877-1118-4fb1-9b65-9898ec2509ec/version/5.2.0/scopes/%5B%22%22%5D) in enforce mode to your AKS clusters that blocks deployments with gitRepo volume usage. You may view the allowed volume types [here](https://github.com/Azure/azure-policy/blob/8c4af2801d999ef960fe9a10a1f04375954c10a7/built-in-policies/policySetDefinitions/Kubernetes/PSPRestrictedStandard.json#L191). For detailed steps on how to enable Azure Policy on your AKS cluster, please review [Secure your Azure Kubernetes Service (AKS) clusters with Azure Policy](../use-azure-policy.md).
---

## AKS-2025-005 Important Security Update for Calico v3.26 Users

**Published Date**: March 24, 2025

### Description

Multiple security issues exist in Calico version 3.26, which is now end of life and no longer receives security fixes. If you're using Calico version 3.26 on AKS Cluster version 1.29.x or earlier, you'll no longer receive security patches for Calico.

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
- Windows version 17763.6775.250214
- Windows version 20348.3091.250214
- Windows version 25398.1369.250214
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

- Windows version 17763.6775.250214
- Windows version 20348.3091.250214
- Windows version 25398.1369.250214
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

- Windows version 17763.6775.250214
- Windows version 20348.3091.250214
- Windows version 25398.1369.250214
- or later

---

## AKS-2025-001 ServerConfig.PublicKeyCallback Issue in golang/crypto

**Published Date**: December 11, 2024

### Description

A security issue was discovered in the ServerConfig.PublicKeyCallback callback, which may be susceptible to an authorization bypass. This vulnerability arises when applications and libraries misuse the connection.serverAuthenticate method. Specifically, the SSH protocol allows clients to inquire about whether a public key is acceptable before proving control of the corresponding private key. This issue can lead to incorrect authorization decisions based on keys that the attacker doesn't actually control

AKS is aware of the vulnerability. However, this CVE isn't exploitable for kubernetes. The vulnerability only affects those users who are using the PublicKeyCallback API. Since golang doesn't use this API in the Kubernetes setup, and the only use of the entire package is within a test suite golang.org/x/crypto isn't vulnerable. The vulnerability is patched in the upcoming Kubernetes release 1.33. 

### References
- [CVE-2024-45337](https://nvd.nist.gov/vuln/detail/CVE-2024-45337)

### Affected Components

#### [**AKS Cluster**](#tab/aks-cluster)

**Affected Versions**

- AKS version 1.32 and earlier

**Resolutions**

Fix **will be available** in AKS cluster version 1.33

---


<!--- enable this section when we are approaching the end of 2025
---

## Archived bulletins

For security bulletins from previous years, see:

- [2025](2025.md)

---
-->

## Next Steps

- Get updates about the CVE mitigation status with [CVE Status][aks-release-tracker].
- Get updates about the latest node images with [AKS release notes][aks-release-notes].
- Learn how to upgrade the AKS node image with [Upgrade Azure Kubernetes Service (AKS) node images][node-image-upgrade].
- Learn how to automatically upgrade node images with [Automatically upgrade node images][auto-upgrade-node-image].
- Learn how to upgrade the Kubernetes version with [Upgrade an AKS cluster][upgrade-cluster].
- Learn about upgrading best practices with [AKS patch and upgrade guidance][upgrade-operators-guide].
- Learn how to to safely upgrade to a consistent node image across multiple clusters with [Azure Kubernetes Fleet Manager][fleet-auto-upgrade].


<!-- LINKS - internal -->
[node-image-upgrade]: ../node-image-upgrade.md
[auto-upgrade-node-image]: ../auto-upgrade-node-image.md
[upgrade-cluster]: ../upgrade-aks-cluster.md
[fleet-auto-upgrade]: ../../kubernetes-fleet/concepts-update-orchestration.md
[upgrade-operators-guide]: /azure/architecture/operator-guides/aks/aks-upgrade-practices

<!-- LINKS - external -->
[aks-release-notes]: https://github.com/Azure/AKS/releases
[aks-release-tracker]: https://releases.aks.azure.com/
