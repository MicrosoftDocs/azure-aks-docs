---
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 01/14/2026
author: schaffererin
ms.author: schaffererin
---

> [!IMPORTANT]
> Starting on **March 30, 2026** Azure Kubernetes Service (AKS) no longer supports the `aks-disable-kubelet-serving-certificate-rotation=true` node pool tag to disable Kubelet Serving Certificate Rotation (KSCR). You can create new node pools using this tag, but AKS won't respect it. This behavior means that the node pools will be created with KSCR enabled. For existing node pools, KSCR will be automatically enabled on their next reimage operation. Before this date you can update your node pools using the [`az aks nodepool update`][az-aks-nodepool-update] command with the `aks-disable-kubelet-serving-certificate-rotation=true` tag. To prepare for the removal, you should update your workloads with the correct cert path. For more information, see the [Retirement GitHub issue](https://github.com/Azure/AKS/issues/5539) and the [Azure Updates retirement announcement](MISSING_LINK). To stay informed on announcements and updates, follow the [AKS release notes](https://github.com/Azure/AKS/releases).