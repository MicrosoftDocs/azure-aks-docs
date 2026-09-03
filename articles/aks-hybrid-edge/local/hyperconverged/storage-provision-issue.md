---
title: Troubleshoot issue in which storage provisioning fails
description: Learn how to troubleshoot and mitigate an issue that occurs when storage provisioning fails.
ms.topic: troubleshooting
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.reviewer: rcheeran
ms.lastreviewed: 07/23/2025
ms.custom: hyperconverged

---

# Troubleshoot storage provisioning issue during cluster and node pool creation

This article describes an issue in which new AKS nodes are created on a single storage path/volume of the Azure Local cluster, breaking the expected round-robin distribution among volumes. Over time, this might cause insufficient disk space on that path, potentially resulting in deployment failures.

## Symptoms

During cluster creation or node pool creation and scale operations, you might see the following error message:

```output
The system failed to create <Azure resource name>: There is not enough space on the disk.
```

## Cause

The issue is caused by a recent regression introduced in Azure Local, version 2506.

## Mitigation

This issue was fixed in AKS on [Azure Local, version 2507](/azure/azure-local/whats-new?view=azloc-2507&preserve-view=true#features-and-improvements-in-2507). However, this mitigation works only when you create new Azure Local instances with version 2507. Upgrading from Azure Local versions 2506 to 2507 does not resolve the issue.

### Workaround for Azure Local version 2506

This issue only affects clusters in Azure Local version 2506. Install the [support module](support-module.md) and run the commands provided in this module.

First, run the following command to check for known issues in your AKS environment:

```powershell
Test-SupportAksArcKnownIssues
```

Then, run the following command to fix this known issue on your deployment. This command finds all available fixes for the current version, and installs those fixes:

```powershell
Invoke-SupportAksArcRemediation
```

## Verification

Once the fix is done, you should be able to create your clusters and node pools. If you still encounter issues, please [reach out to Microsoft Support](#contact-microsoft-support).  

## Contact Microsoft Support

If the problem persists, collect the [AKS cluster logs](get-on-demand-logs.md) before you [create a support request](help-support.md).

## Next steps

- [Use the diagnostic checker tool to identify common environment issues](aks-arc-diagnostic-checker.md)
- [Review AKS on Azure Local architecture](cluster-architecture.md)
