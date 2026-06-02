---
title: Vertical pod autoscaling in Azure Kubernetes Service (AKS)
description: Learn about vertical pod autoscaling in Azure Kubernetes Service (AKS) using the Vertical Pod Autoscaler (VPA).
ms.topic: overview
ms.custom: devx-track-azurecli
ms.date: 03/24/2026
author: davidsmatlak
ms.author: davidsmatlak

# Customer intent: "As an AKS administrator, I want to implement Vertical Pod Autoscaler so that I can optimize resource allocation for my containers based on usage patterns, enhancing overall cluster efficiency and performance."
---

# Vertical pod autoscaling in Azure Kubernetes Service (AKS)

This article provides an overview of using the Vertical Pod Autoscaler (VPA) in Azure Kubernetes Service (AKS), which is based on the open source [Kubernetes](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler) version.

When configured, the VPA automatically sets resource requests and limits on containers per workload based on past usage. The VPA frees up CPU and Memory for other pods and helps ensure effective utilization of your AKS clusters. The Vertical Pod Autoscaler provides recommendations for resource usage over time. To manage sudden increases in resource usage, use the [Horizontal Pod Autoscaler][horizontal-pod-autoscaling], which scales the number of pod replicas as needed.

## Benefits

The Vertical Pod Autoscaler offers the following benefits:

- Analyzes and adjusts processor and memory resources to _right size_ your applications. VPA isn't only responsible for scaling up, but also for scaling down based on their resource use over time.
- A pod with a scaling mode set to _auto_ or _recreate_ is evicted if it needs to change its resource requests.
- You can set CPU and memory constraints for individual containers by specifying a resource policy.
- Ensures nodes have correct resources for pod scheduling.
- Offers configurable logging of any adjustments made to processor or memory resources made.
- Improves cluster resource utilization and frees up CPU and memory for other pods.

## Limitations and considerations

Consider the following limitations and considerations when using the Vertical Pod Autoscaler:

- VPA supports a maximum of 1,000 pods associated with `VerticalPodAutoscaler` objects per cluster.
- VPA might recommend more resources than available in the cluster, which prevents the pod from being assigned to a node and run due to insufficient resources. You can overcome this limitation by setting the _LimitRange_ to the maximum available resources per namespace, which ensures pods don't ask for more resources than specified. You can also set maximum allowed resource recommendations per pod in a `VerticalPodAutoscaler` object. The VPA can't completely overcome an insufficient node resource issue. The limit range is fixed, but the node resource usage is changed dynamically.
- We don't recommend using VPA with the [Horizontal Pod Autoscaler (HPA)][horizontal-pod-autoscaler-overview], which scales based on the same CPU and memory usage metrics.
- The VPA Recommender only stores up to _eight days_ of historical data.
- VPA doesn't support JVM-based workloads due to limited visibility into actual memory usage of the workload.
- VPA doesn't support running your own implementation of VPA alongside it. Having an extra or customized recommender is supported.
- AKS Windows containers aren't supported.

## VPA overview

The VPA object consists of three components:

- **Recommender**: The Recommender monitors current and past resource consumption, including metric history, Out of Memory (OOM) events, and VPA deployment specs, and uses the information it gathers to provide recommended values for container CPU and Memory requests/limits.
- **Updater**: The Updater monitors managed pods to ensure that their resource requests are set correctly. If not, it removes those pods so that their controllers can recreate them with the updated requests.
- **VPA Admission Controller**: The VPA Admission Controller sets the correct resource requests on new pods either created or recreated by their controller based on the Updater's activity.

### VPA admission controller

The VPA Admission Controller is a binary that registers itself as a _Mutating Admission Webhook_. When a new pod is created, the VPA Admission Controller gets a request from the API server and evaluates if there's a matching VPA configuration or finds a corresponding one and uses the current recommendation to set resource requests in the pod.

A standalone job, `overlay-vpa-cert-webhook-check`, runs outside of the VPA Admission Controller. The `overlay-vpa-cert-webhook-check` job creates and renews the certificates and registers the VPA Admission Controller as a `MutatingWebhookConfiguration`.

### VPA object operation modes

A Vertical Pod Autoscaler resource, most commonly a _deployment_, is inserted for each controller that you want to have automatically computed resource requirements.

There are four modes in which the VPA operates:

- `Recreate`: VPA assigns resource requests during pod creation and updates existing pods by evicting them when the requested resources differ significantly from the new recommendations (respecting the PodDisruptionBudget, if defined). You should only use this mode if you need to ensure that the pods are restarted whenever the resource request changes. Otherwise, we recommend using  `InPlaceOrRecreate` mode, which takes advantage of restart-free updates when possible.
- `InPlaceOrRecreate`: In InPlaceOrRecreate mode, VPA attempts to update Pod resource requests and limits without restarting the Pod when possible. However, if in-place updates can't be performed for a particular resource change, VPA falls back to evicting the Pod (similar to Recreate mode) and allowing the workload controller to create a replacement Pod with updated resources. This mode is available on AKS 1.34+.
  - To try `InPlaceOrRecreate` mode, follow [the step-by-step instructions][inplace-vpa-example].
  - In this mode, the updater applies recommendations in-place using the [Resize Container Resources In-Place feature][resize-container].
  - For more information, see the [In-Place Updates upstream documentation][vpa-upstream-doc].
- `Initial`: VPA only assigns resource requests during pod creation. It doesn't update existing pods. This mode is useful for testing and understanding the VPA behavior without affecting the running pods.
- `Off`: VPA doesn't automatically change the resource requirements of the pods. The recommendations are calculated and can be inspected in the VPA object.

> [!WARNING]
> The `Auto` update mode is deprecated since VPA version 1.4.0 (AKS 1.34+). Auto mode is currently an alias for `Recreate` mode and behaves identically. It was introduced to allow for future expansion of automatic update strategies.

## Deployment pattern for application development

If you're unfamiliar with VPA, we recommend the following deployment pattern during application development to identify its unique resource utilization characteristics, test VPA to verify it's functioning properly, and test alongside other Kubernetes components to optimize resource utilization of the cluster:

1. Set `UpdateMode = "Off"` in your production cluster and run VPA in recommendation mode so you can test and gain familiarity with VPA. `UpdateMode = "Off"` can avoid introducing a misconfiguration that can cause an outage.
1. Establish observability first by collecting actual resource utilization telemetry over a given period of time, which helps you understand the behavior and any signs of issues from container and pod resources influenced by the workloads running on them.
1. Get familiar with the monitoring data to understand the performance characteristics. Based on this insight, set the desired requests/limits accordingly and then in the next deployment or upgrade.
1. Set `updateMode` value to `Recreate`, `InPlaceOrRecreate`, or `Initial` depending on your requirements.

## Next steps

To learn how to set up the Vertical Pod Autoscaler on your AKS cluster, see [Use the Vertical Pod Autoscaler in AKS](./use-vertical-pod-autoscaler.md).

<!-- EXTERNAL LINKS -->
[pod-disruption-budget]: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/
[vpa-upstream-doc]: https://github.com/kubernetes/autoscaler/blob/master/vertical-pod-autoscaler/docs/features.md#in-place-updates-inplaceorrecreate
[resize-container]:https://kubernetes.io/docs/tasks/configure-pod-container/resize-container-resources/
<!-- INTERNAL LINKS -->
[horizontal-pod-autoscaling]: concepts-scale.md#horizontal-pod-autoscaler
[horizontal-pod-autoscaler-overview]: concepts-scale.md#horizontal-pod-autoscaler
[inplace-vpa-example]: use-vertical-pod-autoscaler.md#using-vertical-autoscaler-inplaceorrecreate-mode
