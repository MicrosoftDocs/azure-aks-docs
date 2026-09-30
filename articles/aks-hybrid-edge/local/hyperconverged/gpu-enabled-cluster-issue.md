---
title: Troubleshoot issue in which AKS cluster creation fails
description: Learn how to troubleshoot and mitigate an issue that causes AKS cluster creation to fail.
ms.topic: troubleshooting
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.lastreviewed: 05/27/2026
ms.custom: hyperconverged

---

# Troubleshoot AKS cluster creation failure

This article describes an issue in which creating an AKS cluster with a GPU-enabled default node pool fails. This issue occurs when you specify newly added GPU types, including NVIDIA L-series GPUs and NVIDIA RTX 6000 Ada GPUs, as the default node pool.

## Symptoms

The following command causes the AKS cluster creation to fail:

```azurecli
az aksarc create --node-vm-size <GPU_ENABLED_VM_SIZE>
```

## Workaround

Create an AKS cluster with a non-GPU enabled default node pool, then add the needed GPU enabled node pool. 

```azurecli
az aksarc create <default node pool size>
az aksarc nodepool add --node-vm-size <GPU_ENABLED_VM_SIZE>
```

## Verification

Once the fix is done, you should be able to create your cluster. If you still encounter issues, please [reach out to Microsoft Support](#contact-microsoft-support).  

## Contact Microsoft Support

If the problem persists, collect the [AKS cluster logs](get-on-demand-logs.md) before you [create a support request](help-support.md).

## Next steps

- [Use the diagnostic checker tool to identify common environment issues](aks-arc-diagnostic-checker.md)
- [Review AKS on Azure Local architecture](cluster-architecture.md)