---
title: Overview of AKS Automatic Clusters with Managed System Node Pools
description: Learn about the managed system node pools feature for Azure Kubernetes Service (AKS) Automatic clusters, including its key features, benefits, and restrictions.
ms.service: azure-kubernetes-service
ms.subservice: aks-nodes
ms.custom: ignite-2025, build-2026
ms.topic: overview
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 05/22/2026

# Customer intent: As a cluster developer, I want to understand AKS Automatic managed system node pools so that I can evaluate its benefits and limitations for my use case.
---

# Overview of Azure Kubernetes Service (AKS) Automatic clusters with managed system node pools

This overview explains the managed system node pools feature, which is by default enabled on new AKS Automatic clusters and only available in AKS Automatic. Managed system node pools allow you to focus on your applications while AKS manages the underlying infrastructure, including system node pools, to optimize performance and reliability.

To create an AKS Automatic cluster with managed system node pools, see the [Quickstart: Create an Azure Kubernetes Service (AKS) Automatic cluster](./quick-automatic-managed-network.md) quickstart.

## Key features and benefits

The managed system node pools feature allows you to focus on your applications while AKS Automatic ensures that the underlying infrastructure is optimized for performance and reliability. Key features and benefits include:

- **No operational overhead**: AKS provisions, upgrades, and scales the system node pools automatically, eliminating the need for manual intervention.
- **Simplified cluster creation**: You don't need to track or allocate compute quotas for system node pools because AKS handles quotas for you.
- **Cost efficiency**: Virtual machines (VMs) running on system node pools aren't charged to customer subscriptions, allowing you to optimize costs while maintaining high performance.
- **Enhanced performance**: Isolating system workloads from customer applications improves reliability and ensures consistent performance backed by [Services Level Agreements (SLAs)](https://www.microsoft.com/licensing/docs/view/Service-Level-Agreements-SLA-for-Online-Services).
- **Managed system node pool by default**: New automatic clusters that are created enable managed system node pool by default. If you have existing automatic cluster without managed system node pools, you should recreate the cluster and migrate the workloads.
- **Autoscaling and Node repair**: [Cluster autoscaler](../cluster-autoscaler-overview.md) is enabled for system nodes in the managed system node pool. [Node auto-repair](../node-auto-repair.md) is enabled for system nodes in the managed system node pool.

[!INCLUDE [Kubernetes gateway](../includes/aks-automatic/aks-automatic-kubernetes-gateway.md)]

[!INCLUDE [Automatic limitations](../includes/aks-automatic/aks-automatic-limitations.md)]

## Components of managed system node pools

The following table outlines the components managed by AKS in managed system node pools. AKS handles the creation, upgrading, and scaling of the system nodes where these components run.

| Component | Namespace | Deployment |
|-----------|-----------|------------|
| [Workload identity](../workload-identity-overview.md) | `kube-system` | `azure-wi-webhook-controller-manager` |
| [CoreDNS](../dns-concepts.md#coredns-in-azure-kubernetes-service) | `kube-system` | `coredns`, `coredns-autoscaler` |
| [Eraser](../image-cleaner.md) | `kube-system` | `eraser-controller-manager` |
| [Kubernetes Event-driven Autoscaling (KEDA)](../keda-about.md) | `kube-system` | `keda-admission-webhooks`, `keda-operator`, `keda-operator-metrics-apiserver` |
| [Konnectivity](https://kubernetes.io/docs/tasks/extend-kubernetes/setup-konnectivity/) | `kube-system` | `konnectivity-agent`, `konnectivity-agent-autoscaler` |
| [Metrics Server](https://kubernetes-sigs.github.io/metrics-server/) | `kube-system` | `metrics-server` |
| [Vertical Pod Autoscaling (VPA)](../vertical-pod-autoscaler.md) | `kube-system` | `vpa-admission-controller`, `vpa-recommender`, `vpa-updater` |

Other add-ons and extensions run on an `aks-system-surge` node, with scaling handled by [node auto-provisioning (NAP)](../node-auto-provisioning.md). `DaemonSets` run on both managed system node pools and nodes in your subscription, including the `aks-system-surge` nodes.

## Security restrictions for managed system node pools

Since AKS manages the system node pool on your behalf, AKS applies multiple layers of security restrictions through built-in policies, baseline pod security standards, and admission time policies. These restrictions help protect managed system components and preserve the boundary between customer workloads and AKS-managed infrastructure.

| Restriction | What AKS prevents | Why it matters |
|-------------|-------------------|----------------|
| Managed system resource changes | Creating, updating, or deleting resources in AKS-managed system namespaces. | Helps protect AKS-managed components from customer-initiated changes. |
| Interactive access to system pods | Using pod `exec`, `attach`, or `port-forward` against AKS-managed system pods. | Helps prevent direct access to system workloads running on managed system node pools. |
| Managed system node changes | Modifying managed system nodes or labeling regular nodes as managed system nodes. | Helps maintain the boundary between customer-managed nodes and AKS-managed system nodes. |
| Workload placement on managed system nodes | Scheduling or running customer workloads on AKS-managed system nodes, including workloads with reserved tolerations, broad wildcard tolerations, or custom schedulers. | Helps prevent customer workloads from running on dedicated system nodes. |
| Privileged cluster access paths | Granting access to sensitive node proxy permissions. | Reduces paths that could bypass normal controls or escalate access to cluster resources. |
| Protected identity impersonation | Impersonating protected AKS, Kubernetes, or system service account identities. | Helps prevent callers from assuming identities used by trusted system components. |
| AKS-managed security control changes | Modifying AKS-managed security policies and admission controls. | Helps prevent weakening or disabling the controls that protect managed system node pools. |

### Unsupported AKS API operations

The following AKS API operations are **unsupported**:

- Upgrading a managed system node pool.
- Deleting a managed system node pool.
- Stopping a cluster with a managed system node pool.
- Listing agent pools on a cluster doesn't include managed system node pools.

## Next steps

> [!div class="nextstepaction"]
> [Create an Azure Kubernetes Service (AKS) Automatic cluster](./quick-automatic-managed-network.md)
