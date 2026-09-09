---
title: Use Cluster Health Monitor checker in Azure Kubernetes Service (AKS) (preview)
description: Learn how Cluster Health Monitor in AKS runs continuous control plane and add-on health checks and on-demand node health checks with automatic remediation.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.subservice: aks-monitoring
author: kevinkrp93
ms.author: kevinthomas
ms.date: 09/08/2026
ai-usage: ai-assisted
# Customer intent: As a cluster operator, I want to enable Cluster Health Monitor in AKS so that I can run built-in data plane health checks and use CoreDNS remediation safeguards.
---

# Use Cluster Health Monitor checker in Azure Kubernetes Service (AKS) (preview)

This article shows you how to deploy Cluster Health Monitor in Azure Kubernetes Service (AKS).

Cluster Health Monitor helps you detect AKS managed component issues earlier and improve resilience by enabling automatic remediation for unhealthy CoreDNS pods in specific scenarios. It runs periodic checks for components such as CoreDNS, metrics server, and API server, and exposes results as Prometheus metrics for alerting.

> [!IMPORTANT]
> Cluster Health Monitor is an AKS-managed checker for system components. It doesn't replace Azure Monitor, Managed Prometheus, or your existing monitoring stack.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## Overview

Cluster Health Monitor is an AKS-managed add-on deployed in the `kube-system` namespace. It includes two monitors:

- **Control plane and add-on monitor** runs ongoing in-cluster checks to validate control plane and add-on components that affect cluster operations and upgrade reliability. It evaluates the following signals:
    - **DNS resolution success rate** to detect unhealthy DNS pods that can affect service discovery.
    -  **API server connectivity** to detect failures reaching the control plane from within the cluster.
    - **Metrics server availability** to detect failures in metrics collection.

- **On-Demand Monitor** runs node health checks automatically when a node is provisioned or rebooted. You can also trigger a check manually on any existing node. It evaluates:
    - **Pod scheduling** to confirm a standard pod can be scheduled on the node.
    - **Pod networking** to confirm pods can reach other pods.

These monitors are automatically enabled on AKS Automatic clusters running version 1.34 or later. Cluster Health Monitor exposes check results as Prometheus metrics on port `9800`, so you can scrape and alert on these signals in your existing monitoring pipeline.

> [!NOTE]
> Cluster Health Monitor is automatically enabled on AKS Automatic clusters running Kubernetes 1.34+ and can't be enabled on earlier Kubernetes versions in AKS Automatic.

## Before you begin

- Install the Azure CLI version 2.73.0 or later. Run `az --version` to check your version. To install or upgrade, see [Install Azure CLI][azure-cli-install].
- Install the `aks-preview` Azure CLI extension version 21.0.0b8 or later:

	```azurecli-interactive
	az extension add --name aks-preview
	```

	If you already installed the extension, update it to the latest version.

	```azurecli-interactive
	az extension update --name aks-preview
	```

- Use the AKS preview managed clusters API version 2026.01.02-preview for this feature.

## Enable Cluster Health Monitor

### Enable control plane and add-on monitor

This feature enables in-cluster monitoring of control plane and add-on components. It also remediates unhealthy CoreDNS pods if they stay unhealthy for five minutes. For more information, see [How CoreDNS remediation works](#how-coredns-remediation-works).

To enable control plane and add-on monitor on a new cluster:

```azurecli-interactive
az aks create -g myResourceGroup -n myCluster --enable-continuous-control-plane-and-addon-monitor
```

To enable control plane and add-on monitor on an existing cluster:

```azurecli-interactive
az aks update --resource-group myResourceGroup --name myCluster --enable-continuous-control-plane-and-addon-monitor
```

### Verify control plane and add-on monitor

After you enable the feature, you can verify the deployment status and metric endpoint exposure.

Verify that the Cluster Health Monitor Deployment is running in `kube-system`.

	```bash
	kubectl get deployment -n kube-system  cluster-health-monitor
	```

### Disable control plane and add-on monitor

```azurecli-interactive
az aks update -g myResourceGroup -n myCluster --disable-continuous-control-plane-and-addon-monitor
```

### Understand metrics exposed by the control plane and add-on monitor

Each check returns one of the following statuses:

| Status | Meaning |
| --- | --- |
| `Healthy` | The component is operating normally. |
| `Unhealthy` | The check failed. The error code in the metric indicates the failure reason. |
| `Unknown` | The result is inconclusive, for example during pod startup or when a dependency is unavailable. |

### Error code reference

Cluster Health Monitor exposes metrics on port `9800` on the `cluster-health-monitor` deployment in the `kube-system` namespace. You can scrape these metrics with Prometheus and use them to detect control plane and add-on health issues. When a check reports `Unhealthy`, Cluster Health Monitor includes an error code in the metric labels.

| Checker | Error code | What it indicates |
| --- | --- | --- |
| APIServer | `APIServerCreateError`, `APIServerGetError`, `APIServerDeleteError` | The API server check failed during create, get, or delete operations for the synthetic test resource. |
| APIServer | `APIServerCreateTimeout`, `APIServerGetTimeout`, `APIServerDeleteTimeout` | The API server check exceeded timeout thresholds during create, get, or delete operations. |
| CoreDNS / LocalDNS | `ServiceNotReady`, `PodsNotReady` | DNS infrastructure wasn't ready when the check ran. |
| CoreDNS / LocalDNS | `ServiceError`, `PodError`, `LocalDNSError` | DNS queries failed with non-timeout errors. |
| CoreDNS / LocalDNS | `ServiceTimeout`, `PodTimeout`, `LocalDNSTimeout` | DNS queries timed out. |
| MetricsServer | `MetricsServerUnavailable` | The metrics-server API couldn't be reached or returned an error. |
| MetricsServer | `MetricsServerTimeout` | The metrics-server API request timed out. |

#### How CoreDNS remediation works

The control plane and add-on monitor in Cluster Health Monitor include a CoreDNS remediation capability that restores DNS health while minimizing risk to DNS availability. Before taking action, it evaluates per-pod DNS health check results, how long each pod is unhealthy, the health state of other CoreDNS pods, and recent remediation history.

It deletes an unhealthy CoreDNS pod only when all of the following conditions are true:

- Exactly one CoreDNS pod is continuously unhealthy for at least five minutes.
- At least one other CoreDNS pod is healthy.
- No CoreDNS remediation event fired in the last one hour.

When all conditions are met, it deletes the unhealthy pod. Kubernetes then recreates it. This approach restores DNS capacity while keeping at least one healthy replica serving traffic and avoids repeated remediation cycles during ongoing incidents.

### Enable On-Demand Monitor

To enable On-Demand Monitor on a new cluster:

```azurecli-interactive
az aks create --resource-group myResourceGroup --name myCluster --enable-on-demand-monitor
```

To enable On-Demand Monitor on an existing cluster:

```azurecli-interactive
az aks update --resource-group myResourceGroup --name myCluster --enable-on-demand-monitor
```

### Verify On-Demand Monitor

To verify that On-Demand Monitor is enabled, run:

```bash
kubectl get crd checknodehealths.clusterhealthmonitor.azure.com -o yaml
```

### Disable On-Demand Monitor

```azurecli-interactive
az aks update --resource-group myResourceGroup --name myCluster --disable-on-demand-monitor
```

### Check node health status with On-Demand Monitor

AKS automatically triggers a node health check when a node is provisioned or rebooted. Like the control plane and add-on monitor, On-Demand Monitor reports node health as `Healthy`, `Unhealthy`, or `Unknown`. 

### Manually trigger a node health check

To manually trigger a health check on an existing node, deploy a `CheckNodeHealth` custom resource to your cluster. See the [CheckNodeHealth CRD definition](https://github.com/Azure/cluster-health-monitor/blob/main/manifests/base/checknodehealth-controller/crd.yaml) on GitHub for the resource schema. The custom resource is automatically cleaned up after six hours. Refer to the following example to trigger a health check on a specific node:

```bash
kubectl apply -f - <<'EOF'
apiVersion: clusterhealthmonitor.azure.com/v1alpha1
kind: CheckNodeHealth
metadata:
  name: my-node-check
spec:
  nodeRef:
    name: aks-nodepool1-12345678-vmss000000
EOF
```

To check the health check status, run:

```bash
kubectl get CheckNodeHealth my-node-check -o yaml 
```

```bash
kubectl describe node <node-name> 
```
In the output, look for the `kubernetes.azure.com/NodeHealthy` condition and check its `Status` and `Message` fields.

> [!NOTE]
> Nodes running CoreDNS pods might show a status `Unknown` for this check. The health check validates cross-node connectivity by using a CoreDNS ping and therefore can't run on the node hosting the CoreDNS pod.

#### How node remediation works

When On-Demand Monitor detects an unhealthy node, AKS automatically remediates it. The remediation behavior depends on how the node was provisioned:

- **Node auto-provisioning nodes** are remediated automatically based on [node auto-provisioning's remediation logic](node-auto-provisioning-disruption.md).
- **Other nodes** — AKS progressively increases the scope of remediation: restarting the node after five minutes, reimaging it after 10 minutes, and redeploying the VM after 15 minutes. Each action is attempted once per node provisioning event.

## Next steps

- Review [Configure AKS diagnostics](aks-diagnostics.md).
- Review [Troubleshoot CoreDNS on Azure Kubernetes Service (AKS)](coredns-troubleshoot.md).
- Review [Monitor Azure Kubernetes Service (AKS)](monitor-aks.md).

<!-- LINKS -->
[azure-cli-install]: /cli/azure/install-azure-cli
