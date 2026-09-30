---
author: davidsmatlak
ms.author: davidsmatlak
ms.service: azure-kubernetes-service-hybrid
ms.custom: linux-related-content
ms.topic: include
ms.date: 09/01/2026
ms.lastreviewed: 10/24/2022
# Guidance to ensure Helm charts install on Linux nodes in a cluster with a mix of Linux and Windows nodes
---

Helm is intended to run on Linux nodes. If your cluster has Windows Server nodes, you must ensure that Helm pods are scheduled to run only on Linux nodes. You must also ensure that any Helm charts you install are scheduled to run on the correct nodes. The commands in this article use [node selectors](../windows-server/adapt-apps-mixed-os-clusters.md#node-selectors) to make sure pods are scheduled to the correct nodes, but not all Helm charts expose a node selector. You can also use other options, such as [taints](../windows-server/adapt-apps-mixed-os-clusters.md#taints-and-tolerations), on your cluster.
