---
title: Overview of AKS Automatic Clusters with Managed System Node Pools (Preview)
description: Learn about the managed system node pools (preview) feature for Azure Kubernetes Service (AKS) Automatic clusters, including its key features, benefits, and restrictions.
author: schaffererin
ms.service: azure-kubernetes-service
ms.custom: ignite-2025
ms.topic: overview
ms.date: 11/12/2025
ms.author: schaffererin
# Customer intent: As a cluster developer, I want to understand the managed system node pools feature for AKS Automatic clusters so that I can evaluate its benefits and limitations for my use case.
---

# Managed system node pools (preview) on Azure Kubernetes Service (AKS) Automatic clusters

In this article, you learn about the managed system node pools (preview) feature for [Azure Kubernetes Service (AKS) Automatic clusters](../intro-aks-automatic.md). With this feature, AKS automatically manages system node pools in your cluster, including configuration, scaling, and maintenance.

To create an AKS Automatic cluster with managed system node pools, see the [Create an Azure Kubernetes Service (AKS) Automatic cluster with managed system node pools (preview)](./aks-automatic-managed-system-node-pools.md) quickstart.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Key features and benefits

The managed system node pools feature allows you to focus on your applications while AKS Automatic ensures that the underlying infrastructure is optimized for performance and reliability. Key features and benefits include:

- **No operational overhead**: AKS provisions, upgrades, and scales the system node pools automatically, eliminating the need for manual intervention.
- **Simplified cluster creation**: You don't need to track or allocate compute quotas for system node pools, as AKS handles this for you.
- **Cost efficiency**: Virtual machines (VMs) running on system node pools aren't charged to customer subscriptions, allowing you to optimize costs while maintaining high performance.
- **Enhanced performance**: Isolating system workloads from customer applications improves reliability and ensures consistent performance backed by [Services Level Agreements (SLAs)](https://www.microsoft.com/licensing/docs/view/Service-Level-Agreements-SLA-for-Online-Services).

## Components of managed system node pools

The following table outlines the components managed by AKS in managed system node pools. AKS handles the creation, upgrading, and scaling of the system nodes where these components run.

| Component | Namespace | Deployment(s) |
|-----------|-----------|------------|
| [Azure Monitor](/azure/azure-monitor/containers/kubernetes-monitoring-enable) | `kube-system` | `ama-logs`, `ama-metrics`, `ama-metrics-ksm`, `ama-metrics-operator-targets` |
| [Workload identity](../workload-identity-overview.md) | `kube-system` | `azure-wi-webhook-controller-manager` |
| [CoreDNS](../dns-concepts.md#coredns-in-azure-kubernetes-service) | `kube-system` | `coredns`, `coredns-autoscaler` |
| [Eraser](../image-cleaner.md) | `kube-system` | `eraser-controller-manager` |
| [Kubernetes Event-driven Autoscaling (KEDA)](../keda-about.md) | `kube-system` | `keda-admission-webhooks`, `keda-operator`, `keda-operator-metrics-apiserver` |
| [Konnectivity](https://kubernetes.io/docs/tasks/extend-kubernetes/setup-konnectivity/) | `kube-system` | `konnectivity-agent`, `konnectivity-agent-autoscaler` |
| [Metrics Server](https://kubernetes-sigs.github.io/metrics-server/) | `kube-system` | `metrics-server` |
| [Vertical Pod Autoscaling (VPA)](../vertical-pod-autoscaler.md) | `kube-system` | `vpa-admission-controller`, `vpa-recommender`, `vpa-updater` |

Other add-ons and extensions run on an `aks-system-surge` node, with scaling handled by [node auto-provisioning (NAP)](../node-auto-provisioning.md). `DaemonSets` run on both managed system node pools and nodes in your subscription, including the `aks-system-surge` nodes.

## Managed system node pool restrictions

Since AKS manages the system node pool on your behalf, AKS applies multiple layers of security restrictions through built-in policies, baseline pod security standards, and admission time policies. These controls help protect your cluster infrastructure, prevent unauthorized access to critical resources, and enforce security best practices. Understanding these restrictions helps you design applications that work within managed system node pool security boundaries while maintaining high security standards.

### Restrictions that prevent changing system resources on the managed system node pool

The following operations are denied for objects and pods running on the managed system node pool:

- All create, update, and delete operations.
- All pod `exec` and `attach` operations.

### Restrictions that prevent running workloads on the managed system node pool

The following workload specifications are denied when scheduled on a managed system node pool:

- Workloads tolerating `CriticalAddonsOnly` and other forms of wildcard tolerations.
- Workloads that specify custom schedulers.

### Unsupported AKS API operations

The following AKS API operations are **unsupported**:

- Upgrading a managed system node pool.
- Deleting a managed system node pool.
- Stopping a cluster with a managed system node pool.
- Listing agent pools on a cluster doesn't include managed system node pools.

## Next steps

> [!div class="nextstepaction"]  
> [Create an AKS Automatic cluster with managed system node pools (preview)](./aks-automatic-managed-system-node-pools.md)  
