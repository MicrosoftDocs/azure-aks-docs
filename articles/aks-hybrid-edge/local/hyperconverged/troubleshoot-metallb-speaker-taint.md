---
title: MetalLB speaker pods don't run on nodes tainted with CriticalAddonsOnly=true:NoSchedule
description: Learn how to troubleshoot MetalLB speaker pods that don't run on nodes tainted with CriticalAddonsOnly=true:NoSchedule.
ms.topic: troubleshooting
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak
ms.reviewer: srikantsarwa
ms.lastreviewed: 08/21/2025
ms.custom: hyperconverged
---

# MetalLB speaker pods don't run on nodes tainted with CriticalAddonsOnly=true:NoSchedule

MetalLB speaker pods don't run on nodes tainted with `CriticalAddonsOnly=true:NoSchedule`. This behavior is expected; such nodes are reserved for critical system pods. However, in some cases, you might require MetalLB speaker pods to be scheduled on these tainted nodes.

## Mitigation

Follow these steps to customize the MetalLB configuration by reinstalling the Arc extension for MetalLB with tolerations for the `CriticalAddonsOnly=true:NoSchedule` taint.

1. Run Azure CLI to get the objectId:

   ```azurecli
   $objID = az ad sp list --filter "appId eq '<app_id>'" --query "[].id" --output tsv
   ```

1. Create a new file named `config.json` and insert the following content:

   ```json
   {
     "k8sRuntimeFpaObjectId": "$objID",
     "metallb.speaker.tolerations[0].key": "CriticalAddonsOnly",
     "metallb.speaker.tolerations[0].operator": "Exists",
     "metallb.speaker.tolerations[0].effect": "NoSchedule"
   }
   ```

1. Install the extension:

   ```azurecli
   az k8s-extension create --cluster-name $clusterName -g $rgName --cluster-type connectedClusters --extension-type microsoft.arcnetworking --config-file config.json -n arcnetworking
   ```

1. When the installation succeeds, MetalLB speaker pods should be scheduled on nodes with the `CriticalAddonsOnly=true:NoSchedule` taint.

> [!NOTE]
> Scheduling MetalLB speaker pods on nodes with this taint should only be done if required for your scenario. These nodes are typically reserved for critical system workloads.

## Next steps

[Troubleshoot issues in AKS Hybrid and Edge](aks-troubleshoot.md)
