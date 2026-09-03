---
title: Scale an Azure Kubernetes Service cluster
description: Learn how to scale the number of nodes in a Kubernetes cluster in AKS on Windows Server.
ms.topic: how-to
ms.date: 09/01/2026
author: davidsmatlak
ms.author: davidsmatlak 
ms.custom: windows-server

# Intent: As an IT Pro, I need to learn how to scale the number of nodes in an AKS cluster in order to run control plane nodes and worker nodes.
# Keyword: node count scale clusters control plane nodes
---

# Scale the node count in an Azure Kubernetes Service cluster

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

If the resource needs of your applications change in AKS on Windows Server, you can manually scale a Kubernetes cluster to run a different number of control plane nodes and worker nodes. You must scale the control plane nodes and worker nodes separately.

## Scale control plane nodes

Use the [Set-AksHciCluster](/azure/aks/aksarc/reference/ps/set-akshcicluster) command to scale the control plane nodes. The following example scales the control plane nodes in a cluster named `mycluster` to a node count of 3:

```powershell
Set-AksHciCluster -name mycluster -controlPlaneNodeCount 3
```

## Scale worker nodes in a node pool

Use the [Set-AksHciNodePool](/azure/aks/aksarc/reference/ps/set-akshcinodepool) command to scale the node pool. The following example scales a node pool called `linuxnodepool` in a cluster named `mycluster` to a node count of 3:

```powershell
Set-AksHciNodePool -clustername mycluster -name linuxnodepool -count 3
```

## Next steps

In this article, you learned how to manually scale a Kubernetes cluster to increase or decrease the number of control plane nodes and worker nodes. Next, you can:

- [Deploy a Linux application on a Kubernetes cluster](./deploy-linux-application.md)
- [Deploy a Windows Server application on a Kubernetes cluster](./deploy-windows-application.md)
