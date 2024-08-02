---
title: Override the resource configuration for Azure Kubernetes Service (AKS) managed add-ons
description: Learn how to override the resource configuration for Azure Kubernetes Service (AKS) managed add-ons.
ms.author: schaffererin
author: schaffererin
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 08/02/2024
---

# Override the resource configuration for Azure Kubernetes Service (AKS) managed add-ons

This article provides an overview of how to override the resource configuration for Azure Kubernetes Service (AKS) managed add-ons with add-on autoscaling (Preview).

## Overview

Enabling the add-on autoscaling in your AKS cluster installs the Vertical Pod Autoscaler (VPA) add-on and VPA custom resources for AKS managed add-ons that support this capability. This feature allows you to manually override the resource CPU and memory requests and limits in Deployments and DaemonSets. You can also override the maximum and minimum allowed CPU and memory and the VPA update mode within VPA custom resources.

VPA maintains the specified limit-to-request ratios and adjusts the limit based on the ratio. For more information, see [VPA limits control](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler#limits-control). The add-on's pod request/limit values are updated based on the VPA custom resources that you define. Changing the resource requests and limits triggers the add-on pod restart process.

AKS updates the add-on pod request/limit values to a reasonable ratio (1:2) and restarts the add-on pod when enabling add-on autoscaling. Currently, the only exception is CoreDNS, which keeps the original resource request/limit values to prevent the CoreDNS pod restart process to avoid availability issues. For more information, see [CoreDNS autoscaling behavior](./coredns-custom.md#coredns-vertical-pod-autoscaling-behavior).

## Prerequisites

* Review the [supported AKS managed add-ons](./addon-autoscaling.md#supported-aks-managed-add-ons) and [limitations](./addon-autoscaling.md#limitations) for this feature.
* You need an AKS cluster enabled with the add-on autoscaling feature. If you don't have one, see [Enable add-on autoscaling on your AKS cluster (Preview)](./addon-autoscaling.md).

## Override resource annotations

| Annotation | Description | Values |
| --- | --- | --- |
| `kubernetes.azure.com/override-requests-limits` | Supports the capability to override the container resource CPU/memory requests/limits in a Deployment or DaemonSet if the value is "enabled". Set the value to "disabled" to return back to AKS provides container policy max/min CPU/memory value. | "enabled" or "disabled" |
| `kubernetes.azure.com/override-min-max` | Supports the capability to override the container policy maximum/minimum allowed CPU/memory value in VPA custom resource if the value is "enabled". Set the value to "disabled" to return back to AKS provides container policy max/min CPU/memory value. | "enabled" or "disabled" |
| `kubernetes.azure.com/override-update-mode` | Supports the capability to override the update policy `updateMode` value in a VPA custom resource if the value is "enabled". Set the value to "disabled" to return back to AKS provides update mode "Initial". | "enabled" or "disabled" |

## Override resource CPU/memory requests/limits

After setting the `kubernetes.azure.com/override-requests-limits` annotation to "enabled" in a Deployment or DaemonSet, you can override the resource CPU/memory requests and limits. The following example shows how to override the resource CPU/memory requests and limits in a Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coredns
  namespace: kube-system
  annotations:
    # update value from "disabled" to "enabled"
    kubernetes.azure.com/override-requests-limits: "enabled"
spec:
  ...
  containers:
  - name: coredns
    resources:
      limits:
        # update cpu limits value won't be reconciled back
        cpu: "3"
        # update memory limits value won't be reconciled back
        memory: "500Mi"
      requests:
        # update cpu requests value won't be reconciled back
        cpu: "100m"
        # update memory requests value won't be reconciled back
        memory: "70Mi"
```

## Override resource maximum/minimum allowed CPU/memory

After setting the `kubernetes.azure.com/override-min-max` annotation to "enabled" in a VPA custom resource, you can override the maximum and minimum allowed CPU and memory values in a VPA custom resource. The following example shows how to override the maximum and minimum allowed CPU and memory values in a VPA custom resource:

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: coredns
  namespace: kube-system
  annotations:
    # update value from "disabled" to "enabled"
    kubernetes.azure.com/override-min-max: "enabled"
spec:
  resourcePolicy:
    containerPolicies:
    - containerName: coredns
      maxAllowed:
        # update maxAllowed cpu value won't be reconciled back
        cpu: 3
        # update maxAllowed memory value won't be reconciled back
        memory: 500Mi
      minAllowed:
        # update minAllowed cpu value won't be reconciled back
        cpu: 10m
        # update minAllowed memory value won't be reconciled back
        memory: 10Mi
  ...
```

## Override resource update mode

After setting the `kubernetes.azure.com/override-update-mode` annotation to "enabled" in a VPA custom resource, you can override the update policy `updateMode` value in a VPA custom resource to "Off" or "Initial" (default). The following example shows how to override the update policy `updateMode` value to "Initial" in a VPA custom resource:

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: coredns
  namespace: kube-system
  annotations:
    # update value from "disabled" to "enabled"
    kubernetes.azure.com/override-update-mode: "enabled"
spec:
  ...
  updatePolicy:
    # update updateMode won't be reconciled back
    updateMode: "Initial"
```

## Disable VPA on a specific AKS managed add-on

To disable VPA on a specific AKS managed add-on, you need to update the VPA custom resource YAML file to set the `kubernetes.azure.com/override-update-mode` annotation to `"enabled"` and the `updateMode` to `"Off"`. With *Off* mode, the VPA only provides CPU and memory recommendations and doesn't apply the changes to the pod.

The following example shows how to disable VPA on the CoreDNS add-on:

```yml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: coredns
  namespace: kube-system
  annotations:
    # Set value to "enabled"
    kubernetes.azure.com/override-update-mode: "enabled"
spec:
  ...
  updatePolicy:
    # Set value to "Off"
    updateMode: "Off"
```

## Troubleshooting

1. Make sure the AKS managed add-on supports the add-on autoscaling feature. For more information, see [Supported AKS managed add-ons](./addon-autoscaling.md#supported-aks-managed-add-ons).
2. Verify that the `kubernetes.azure.com/override-requests-limits` annotation in the Deployment or DaemonSet is set to "enabled".
3. Verify that the `kubernetes.azure.com/override-min-max` annotation in the VPA custom resource is set to "enabled".
4. Verify that the `kubernetes.azure.com/override-update-mode` annotation in the VPA custom resource is set to "enabled".

## Next steps

To further configure cluster resource utilization and free up CPU/memory for AKS managed add-on pods, see [Vertical pod autoscaling in AKS](./vertical-pod-autoscaler.md).
