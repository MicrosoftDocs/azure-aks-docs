---
title: Node auto-repair
description: Learn about automatic node repair of Windows and Linux nodes in AKS on Windows Server.
author: davidsmatlak
ms.topic: how-to
ms.custom: linux-related-content, windows-server
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 01/10/2023
ms.reviewer: oadeniji
# Keyword: unhealthy nodes service disruptions node repair auto-repair
---

# Node auto-repair

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

To help minimize service disruptions for clusters, AKS on Windows Server continuously monitors the health state of worker nodes, and performs automatic node repair if issues arise or if they become unhealthy. This article describes how AKS checks for unhealthy nodes and automatically repairs both Windows and Linux nodes. The article also shows how to manually check node health.

## How AKS checks for unhealthy nodes

AKS uses the following rules to determine if a node is unhealthy and needs repair:

- The node reports a **NotReady** status on consecutive checks.
- The node doesn't report any status within 20-30 minutes.

You can manually check the health state of your nodes with `kubectl`, as follows:

```powershell
kubectl get nodes
```

The status of the nodes should look similar to the following output:

```output
NAME              STATUS   ROLES    AGE   VERSION
moc-l2tlqojhk2d   Ready    master   46h   v1.19.7
moc-l8h8i6lxk1h   Ready    <none>   46h   v1.19.7
moc-lqnjufwo2cy   Ready    master   46h   v1.19.7
moc-ltyl8mqy47z   Ready    <none>   47h   v1.19.7
moc-lwn5xnrapnj   Ready    master   47h   v1.19.7
moc-wvt025q406z   Ready    <none>   47h   v1.19.7
```

## How automatic repair works

If AKS identifies an unhealthy node that remains unhealthy for more than 20-30 minutes, it creates and reimages a new node.

It usually takes 20 to 30 minutes to repair the node. If AKS finds multiple unhealthy nodes during a health check, each node is repaired individually before another repair begins.

## Next steps

- [Application availability](app-availability.md)
