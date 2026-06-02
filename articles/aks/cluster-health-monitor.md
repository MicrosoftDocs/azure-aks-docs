---
title: Use Cluster Health Monitor checker in Azure Kubernetes Service (AKS) (preview)
description: Learn how the Cluster Health Monitor checker in Azure Kubernetes Service (AKS) runs data plane health checks and supports CoreDNS remediation.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-monitoring
author: varora24
ms.author: vaibhavarora
ms.date: 02/19/2026
ai-usage: ai-assisted
# Customer intent: As a cluster operator, I want to enable Cluster Health Monitor in AKS so that I can run built-in data plane health checks and use CoreDNS remediation safeguards.
---

# Use Cluster Health Monitor checker in Azure Kubernetes Service (AKS) (preview)

This article shows you how to deploy Cluster Health Monitor in Azure Kubernetes Service (AKS).

Cluster Health Monitor helps you detect AKS managed component issues earlier and improve resiliency by enabling automatic remediation for unhealthy CoreDNS pods in specific scenarios. It runs periodic checks for components such as CoreDNS, metrics server, and API server, and exposes results as Prometheus metrics for alerting.

> [!IMPORTANT]
> Cluster Health Monitor is an AKS-managed checker for system components. It doesn't replace Azure Monitor, Managed Prometheus, or your existing monitoring stack.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Overview

Cluster Health Monitor is an AKS-managed add-on deployed in the `kube-system` namespace. It runs continuous in-cluster checks to validate critical components that affect cluster operations and upgrade reliability.

The checker evaluates the following signals:

- **DNS resolution success rate** to detect unhealthy DNS pods that can affect service discovery.
- **API server connectivity** to detect failures reaching the control plane from within the cluster.
- **Metrics server availability** to detect failures in metrics collection.

Cluster Health Monitor exposes check results as Prometheus metrics on port `9800`, so you can scrape and alert on these signals in your existing monitoring pipeline.

For DNS-specific checks, Cluster Health Monitor can automatically remediate a CoreDNS pod that it detects as stuck or unhealthy by deleting that pod. Kubernetes then recreates the pod. Cluster Health Monitor applies this remediation only under specific safeguard conditions to reduce disruption. For more information, see [How CoreDNS remediation works](#how-coredns-remediation-works).

## Before you begin

- Install the Azure CLI version 2.73.0 or later. You can run az --version to verify the version. To install or upgrade, see [Install Azure CLI][azure-cli-install].
- Install the `aks-preview` Azure CLI extension version 19.0.0b25 or later:

	```azurecli-interactive
	az extension add --name aks-preview
	```

	If you already installed the extension, update it to the latest version:

	```azurecli-interactive
	az extension update --name aks-preview
	```

- Use the AKS preview managed clusters API version 2026.01.02-preview for this feature.

## Enable Cluster Health Monitor

Cluster Health Monitor enables continuous in-cluster monitoring of control plane and add-on components. For DNS issues, AKS remediates unhealthy CoreDNS pods if they remain unhealthy for five minutes. See [How CoreDNS remediation works](#how-coredns-remediation-works) for more details.

```azurecli-interactive
az aks create -g myResourceGroup -n myCluster --enable-continuous-control-plane-and-addon-monitor
```

## Verify Cluster Health Monitor

After you enable the feature, you can verify the deployment status and metric endpoint exposure.

1. Get cluster credentials:

	```azurecli-interactive
	az aks get-credentials --resource-group ${RESOURCE_GROUP} --name ${CLUSTER_NAME}
	```

1. Verify that the Cluster Health Monitor Deployment is running in `kube-system`:

	```bash
	kubectl get deployment -n kube-system  cluster-health-monitor
	```

## Disable Cluster Health Monitor

To disable Cluster Health Monitor, you can use the following command:

```azurecli-interactive
az aks update -g myResourceGroup -n myCluster --disable-continuous-control-plane-and-addon-monitor
```

## Understand metrics exposed by Cluster Health Monitor

Cluster Health Monitor exposes metrics on port `9800`. You can scrape these metrics with Prometheus and use them to detect add-on health issues.

Each check returns one of the following statuses:

| Status | Meaning |
|---|---|
| `Healthy` | The component is operating normally. |
| `Unhealthy` | The check failed. The error code in the metric indicates the failure reason. |
| `Unknown` | The result is inconclusive, for example during pod startup or when a dependency is unavailable. |

Option 1:
### Error code reference

When a check reports `Unhealthy`, Cluster Health Monitor includes an error code in the metric labels.

| Checker | Error code | What it indicates |
|---|---|---|
| APIServer | `APIServerCreateError`, `APIServerGetError`, `APIServerDeleteError` | The API server check failed during create, get, or delete operations for the synthetic test resource. |
| APIServer | `APIServerCreateTimeout`, `APIServerGetTimeout`, `APIServerDeleteTimeout` | The API server check exceeded timeout thresholds during create, get, or delete operations. |
| CoreDNS / LocalDNS | `ServiceNotReady`, `PodsNotReady` | DNS infrastructure wasn't ready when the check ran. |
| CoreDNS / LocalDNS | `ServiceError`, `PodError`, `LocalDNSError` | DNS queries failed with non-timeout errors. |
| CoreDNS / LocalDNS | `ServiceTimeout`, `PodTimeout`, `LocalDNSTimeout` | DNS queries timed out. |
| MetricsServer | `MetricsServerUnavailable` | The metrics-server API couldn't be reached or returned an error. |
| MetricsServer | `MetricsServerTimeout` | The metrics-server API request timed out. |

## How CoreDNS remediation works

Cluster Health Monitor includes a CoreDNS remediation capability designed to restore DNS health while minimizing risk to DNS availability. Before taking action, Cluster Health Monitor evaluates per-pod DNS health check results, how long each pod has been unhealthy, the health state of other CoreDNS pods, and recent remediation history.

Cluster Health Monitor deletes an unhealthy CoreDNS pod only when all of the following conditions are true:

- Exactly one CoreDNS pod is continuously unhealthy for at least five minutes.
- At least one other CoreDNS pod is healthy.
- No Cluster Health Monitor CoreDNS remediation event fired in the last one hour.

When all conditions are met, Cluster Health Monitor deletes the unhealthy pod. Kubernetes then recreates it. This approach restores DNS capacity while keeping at least one healthy replica serving traffic and avoiding repeated remediation cycles during ongoing incidents.

## Next steps

- Review [Configure AKS diagnostics](aks-diagnostics.md).
- Review [Troubleshoot CoreDNS on Azure Kubernetes Service (AKS)](coredns-troubleshoot.md).
- Review [Monitor Azure Kubernetes Service (AKS)](monitor-aks.md).

<!-- LINKS -->
[azure-cli-install]: /cli/azure/install-azure-cli