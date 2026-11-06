---
title: Security bulletins for AKS Hybrid and Edge
description: Security vulnerability advisories and mitigation guidance for AKS Hybrid and Edge.
author: leslielin
ms.author: leslielin
ms.topic: concept-article
ms.date: 11/04/2026
ms.custom: overview
---

# Security bulletins for AKS Hybrid and Edge

This article provides information on security vulnerabilities that affect AKS Hybrid and Edge and its components. This information includes details on:

- **Critical Security Advisories:** High-impact security vulnerabilities, including zero-day vulnerabilities and other critical CVEs that require immediate attention, along with mitigation guidance.
- **Ongoing Security Investigations:** Security issues under review, including CVEs where a patch isn't yet available or further assessment is needed.
- **False Positives & Non-Exploitable CVEs:** Cases where a reported CVE doesn't impact AKS Hybrid and Edge due to specific configurations, mitigations, or lack of exploitability.

> [!NOTE]
> For security bulletins that affect AKS in Azure, see [Security bulletins for Azure Kubernetes Service (AKS)](/azure/aks/security-bulletins/overview).

---

## AKSARC-2026-0001: Advisory and Mitigation Guide for CVE-2026-31431 (Copy Fail)

**Last updated**: November 4, 2026

### Description

This bulletin provides an update on a local privilege escalation (LPE) vulnerability that was publicly disclosed on April 29, 2026. The vulnerability affects the Linux kernel's `algif_aead` module. It has been assigned **CVE-2026-31431** and is referred to as **"Copy Fail"**.

- **CVSS Score**: 7.8 HIGH (`CVSS:3.1/AV:L/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H`)
- **Attack Vector**: Local — requires code execution on the node, for example, from a container
- **Affected Component**: `algif_aead` kernel module (hardware-accelerated cryptographic functions)
- **Canonical Advisory**: [Fixes available for Copy Fail vulnerability](https://ubuntu.com/blog/copy-fail-vulnerability-fixes-available)

### References

- [CVE-2026-31431](https://nvd.nist.gov/vuln/detail/CVE-2026-31431)
- [AKS Advisory](https://github.com/Azure/AKS/issues/5753)

### Affected Components

# [AKS on Azure Local](#tab/azure-local)

**Affected Versions**

- Azure Local 2610 and later include the fix. To apply it, upgrade Azure Local to 2610 or later, and then upgrade each AKS cluster. Linux nodes remain exploitable until you upgrade the cluster or complete the remediation steps in this article.
- Although `algif_aead` isn't loaded by default on AKS nodes, the Linux kernel's module autoloading mechanism (`request_module`) **automatically loads it on demand**. Any process, **including unprivileged containers**, can trigger this mechanism by creating an AF_ALG socket with AEAD type. This condition means:
- **An attacker with code execution in any pod, even non-root, can escalate to root on the node.**
- No special pod privileges, capabilities, or host access are required.

**Resolutions**

Choose one of the following remediation paths.

#### Option A: Patch your Azure Local instance (recommended)

This option applies the fix through Azure Local. After Azure Local has the fix, upgrade each AKS cluster to apply the fix to its nodes.

##### Step 1: Upgrade Azure Local

Upgrade to Azure Local 2610 or later. After you upgrade, skip step 2 and go to step 3 to upgrade each AKS cluster. The fix doesn't apply to existing nodes until you upgrade the cluster.

If you can't upgrade to 2610 yet and your deployment is on version 2601 or earlier, upgrade to 2602 or later, and then continue to step 2.

Before you upgrade Azure Local, ensure each cluster has a supported upgrade path to a Kubernetes version in the target release. For details, see [Supported Kubernetes versions](supported-kubernetes-versions.md#aks-supported-kubernetes-minor-and-patch-versions-per-release). For upgrade guidance, see [Azure Local update documentation](/azure/azure-local/update/about-updates-23h2).

##### Step 2: Run the remediation command

If you're on Azure Local 2610 or later, skip this step because the patch is already included.

1. Install the [AKS Support Tool](/azure/aks/aksarc/support-module) and run `az login` on your Azure Local node.

2. Run the remediation command:

   ```powershell
   Invoke-SupportAksArcRemediation_FixCVE_2026_31431
   ```

   When complete, you see a confirmation message indicating that the update was applied or that no update is needed.

   > [!NOTE]
   > After the command completes, wait 10-15 minutes for the update to download to your Azure Local deployment before you proceed to step 3.

##### Step 3: Upgrade AKS clusters

Upgrade each AKS cluster to apply the fix to its nodes. Use the following table to find the upgrade path for the Azure Local version you're on.

| Current K8s version | Supported versions for Azure Local 2602 | Supported versions for Azure Local 2610 |
|---|---|---|
| 1.30 or earlier | 1.31.12, 1.31.13 | None. Upgrade to 1.32 on Azure Local 2602 before you upgrade to 2610. |
| 1.31.12 | 1.31.13, 1.32.8, 1.32.9 | None. Upgrade to 1.32 on Azure Local 2602 before you upgrade to 2610. |
| 1.31.13 | 1.32.8, 1.32.9 | None. Upgrade to 1.32 on Azure Local 2602 before you upgrade to 2610. |
| 1.32.8 | 1.32.9, 1.33.4, 1.33.5 | 1.32.10, 1.32.11, 1.33.6, 1.33.7 |
| 1.32.9 | 1.33.4, 1.33.5 | 1.32.10, 1.32.11, 1.33.6, 1.33.7 |
| 1.33.4 | 1.33.5 | 1.33.6, 1.33.7, 1.34.3, 1.34.4 |
| 1.33.5 | None | 1.33.6, 1.33.7, 1.34.3, 1.34.4 |

To upgrade your cluster, follow the steps in [Upgrade the Kubernetes version](/azure/aks/aksarc/cluster-upgrade#upgrade-the-kubernetes-version). For the full version list, see [Supported Kubernetes versions](/azure/aks/aksarc/supported-kubernetes-versions#aks-arc-supported-kubernetes-minor-and-patch-versions-per-release).

After the upgrade completes, verify that all nodes are running the new image:

```bash
kubectl get nodes -o wide
```

#### Option B: Self-service mitigation (alternative)

If you can't upgrade Azure Local or your AKS clusters immediately, apply this per-cluster mitigation. This process blocks the vulnerable kernel module from loading without requiring an Azure Local update or Kubernetes upgrade. Apply this mitigation to each existing cluster that needs protection. New clusters also require this mitigation until you complete Option A.

Apply the self-service mitigation described in the [AKS Advisory](https://github.com/Azure/AKS/issues/5753). Once you upgrade your clusters and validate that the kernel includes the fix, you can remove the mitigation by following the cleanup steps in the same advisory.

---

<!-- Additional platform tabs will be added here as fixes become available:
# [AKS on Windows Server](#tab/windows-server)
# [AKS Edge Essentials](#tab/aksee)
# [AKS on SFF Linux](#tab/sff-linux)
-->
