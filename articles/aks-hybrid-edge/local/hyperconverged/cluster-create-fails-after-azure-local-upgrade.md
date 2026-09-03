---
title: AKS cluster creation fails on Azure Local 2511 or 2512 after upgrade from 2510
description: Learn how to troubleshoot and resolve an issue where new AKS cluster creation fails after upgrading Azure Local from version 2510 to 2511 or 2512.
ms.topic: troubleshooting
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.lastreviewed: 1/26/2026
ms.custom: hyperconverged
---

# AKS cluster creation fails on Azure Local 2511 or 2512 after upgrade from 2510

After you upgrade Azure Local from version 2510 to 2511 or 2512, new AKS cluster creation fails while existing clusters and other operations continue to work normally.

## Overview

AKS Hybrid and Edge on Azure Local supports cluster lifecycle operations including creation, upgrade, and management. When Azure Local is upgraded from version 2510 to 2511 or 2512, a configuration issue with the `HybridAksExtension` prevents new AKS cluster creation. This issue doesn't affect existing AKS clusters or fresh installations of Azure Local 2511 or 2512.

## Symptoms

After upgrading Azure Local from version 2510 to 2511 or 2512, you might observe the following issue when attempting to create new AKS clusters:

- Cluster creation fails with a timeout error:

  ```output
  "message": "Error: Timed out waiting for the operation to complete. Detailed message: AKSAddonsReady: Warning: AddonNotReady: ProviderCSIDriver: AddOn not ready.\n: Timed out CorrelationId: "
  ```

- Failure consistently reproduces only on systems upgraded from 2510.
- No failures observed in host upgrade or existing cluster upgrades.

## Cause

This issue occurs due to a problem with the HybridAksExtension in Azure Local 2511 or 2512. When you upgrade from version 2510 to 2511 or 2512, the system enters a state that prevents new cluster creation. However, existing clusters and other operations continue to work normally.

## Scope and impact

This section describes the upgrade scenarios affected by this issue and the impact on customer environments.

### Affected scenarios

- Azure Local upgraded from version 2510 to 2511.
- Azure Local upgraded from version 2510 to 2512.
- Attempting new AKS cluster creation after the upgrade.

| Azure Local upgrade path | AKS cluster creation result |
| ------------------------ | ------------------------------- |
| Upgrade 2510 → 2511      | ❌ Failure                      |
| Upgrade 2510 → 2512      | ❌ Failure                      |

### Customer impact

- Customers upgrading Azure Local from 2510 to 2511 or 2512 are blocked from creating new AKS clusters.
- Production risk for customers planning post-upgrade cluster expansion.
- Upgrade path continues to work, masking the issue until cluster creation is attempted.

## Confirm the issue

Check if your environment is affected by verifying the HybridAksExtension version.

### Step 1: Check extension version

Run the following commands to check the HybridAksExtension version:

```powershell
az login --use-device-code --tenant <Azure tenant ID>
az account set -s <subscription ID>
$res=get-archcimgmt
az k8s-extension show -g $res.HybridaksExtension.resourceGroup -c $res.ResourceBridge.name --cluster-type appliances --name hybridaksextension
```

### Step 2: Verify issue applicability

You're affected by this issue if the following items apply:

- HybridAksExtension version is 4.0.X (versions prior to 4.0.92).
- Azure Local was upgraded from version 2510 to 2511 or 2512.
- You're attempting to create a new AKS cluster.

## Workaround

To resolve the cluster creation issue, update the HybridAksExtension to the latest version using the following PowerShell commands.

### Update HybridAksExtension to latest version

Run the following PowerShell commands to update the HybridAksExtension to the latest patch version:

```powershell
Install-Module -Name Support.AksArc
Import-Module Support.AksArc
Invoke-SupportAksArcRemediation_HotFix_2511_2512CreateCluster
```

This command updates the extension to version 4.0.92 or later, which resolves the cluster creation issue.

### Verify the fix

After running the remediation commands, verify that the extension is updated:

```powershell
az login --use-device-code --tenant <Azure tenant ID>
az account set -s <subscription ID>
$res=get-archcimgmt
az k8s-extension show -g $res.HybridaksExtension.resourceGroup -c $res.ResourceBridge.name --cluster-type appliances --name hybridaksextension
```

Confirm that the HybridAksExtension version is 4.0.92 or later.

## Resolution

This issue is currently under investigation, and a permanent fix is in progress.

Until the fix is fully validated and released, customers are advised to follow the recommended workaround described in this article. This page is updated as more guidance becomes available.

## Next steps

- If you're planning to upgrade from Azure Local 2510 to 2511 or 2512, apply the mitigation steps before attempting to create new AKS clusters.
- If your environment is already affected, run the remediation commands and verify the extension version before retrying cluster creation.
- Review cluster creation logs for more error details if issues persist.
- If issues persist or if you need assistance, contact Microsoft Support with details about the upgrade path and observed behavior.
