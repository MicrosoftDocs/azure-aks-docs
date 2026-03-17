---
title: Vertical pod autoscaling in Azure Kubernetes Service (AKS)
description: Learn about vertical pod autoscaling in Azure Kubernetes Service (AKS) using the Vertical Pod Autoscaler (VPA).
ms.topic: overview
ms.custom: devx-track-azurecli
ms.date: 09/28/2023
author: davidsmatlak
ms.author: davidsmatlak

# Customer intent: "As an AKS administrator, I want to implement Vertical Pod Autoscaler so that I can optimize resource allocation for my containers based on usage patterns, enhancing overall cluster efficiency and performance."
---

# Vertical pod autoscaling in Azure Kubernetes Service (AKS)

This article provides an overview of using the Vertical Pod Autoscaler (VPA) in Azure Kubernetes Service (AKS), which is based on the open source [Kubernetes](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler) version.

When configured, the VPA automatically sets resource requests and limits on containers per workload based on past usage. The VPA frees up CPU and Memory for other pods and helps ensure effective utilization of your AKS clusters. The Vertical Pod Autoscaler provides recommendations for resource usage over time. To manage sudden increases in resource usage, use the [Horizontal Pod Autoscaler][horizontal-pod-autoscaling], which scales the number of pod replicas as needed.

## Benefits

The Vertical Pod Autoscaler offers the following benefits:

* Analyzes and adjusts processor and memory resources to *right size* your applications. VPA isn't only responsible for scaling up, but also for scaling down based on their resource use over time.
* Can apply resource updates using:
  * **In-place updates (when supported by the cluster)** to minimize disruption
  * **Pod eviction and recreation** when in-place updates are not available or applicable
* You can set CPU and memory constraints for individual containers by specifying a resource policy.
* Ensures nodes have correct resources for pod scheduling.
* Offers configurable logging of any adjustments made to processor or memory resources made.
* Improves cluster resource utilization and frees up CPU and memory for other pods.

## Limitations and considerations

Consider the following limitations and considerations when using the Vertical Pod Autoscaler:

* VPA supports a maximum of 1,000 pods associated with `VerticalPodAutoscaler` objects per cluster.
* VPA might recommend more resources than available in the cluster, which prevents the pod from being assigned to a node and run due to insufficient resources. You can overcome this limitation by setting the *LimitRange* to the maximum available resources per namespace, which ensures pods don't ask for more resources than specified. You can also set maximum allowed resource recommendations per pod in a `VerticalPodAutoscaler` object. The VPA can't completely overcome an insufficient node resource issue. The limit range is fixed, but the node resource usage is changed dynamically.
* We don't recommend using VPA with the [Horizontal Pod Autoscaler (HPA)][horizontal-pod-autoscaler-overview], which scales based on the same CPU and memory usage metrics.
* The VPA Recommender only stores up to *eight days* of historical data.
* VPA doesn't support JVM-based workloads due to limited visibility into actual memory usage of the workload.
* VPA doesn't support running your own implementation of VPA alongside it. Having an extra or customized recommender is supported.
* AKS Windows containers aren't supported.

## VPA overview

The VPA object consists of three components:

* **Recommender**: The Recommender monitors current and past resource consumption, including metric history, Out of Memory (OOM) events, and VPA deployment specs, and uses the information it gathers to provide recommended values for container CPU and Memory requests/limits.
* **Updater**: The Updater monitors managed pods to ensure that their resource requests match the latest VPA recommendations. When differences are detected, it applies updates using:
  * **In-place resource resizing** (when supported by the cluster and workload), minimizing disruption
  * **Pod eviction and recreation** when in-place updates are not supported or applicable, allowing controllers to recreate pods with updated resource requests
* **VPA Admission Controller**: The VPA Admission Controller sets the correct resource requests on new pods either created or recreated by their controller based on the Updater's activity.

### VPA admission controller

The VPA Admission Controller is a binary that registers itself as a *Mutating Admission Webhook*. When a new pod is created, the VPA Admission Controller gets a request from the API server and evaluates if there's a matching VPA configuration or finds a corresponding one and uses the current recommendation to set resource requests in the pod.

A standalone job, `overlay-vpa-cert-webhook-check`, runs outside of the VPA Admission Controller. The `overlay-vpa-cert-webhook-check` job creates and renews the certificates and registers the VPA Admission Controller as a `MutatingWebhookConfiguration`.

## VPA object operation modes

A Vertical Pod Autoscaler (VPA) resource is created for each workload controller (such as a Deployment or StatefulSet) for which you want resource requests to be automatically computed and optionally applied.

VPA supports the following update modes:
* **Auto**:  
  VPA assigns resource requests during pod creation and updates existing pods to match the latest recommendations.  
  This mode is currently equivalent to `Recreate` and updates pods by evicting and recreating them with updated resource requests.  
  Note: `Auto` mode is deprecated. For clusters that support in-place resource resizing, consider using `InPlaceOrRecreate` to minimize disruption. When using eviction-based updates, configure a PodDisruptionBudget to control disruption.
* **InPlaceOrRecreate**:  
  VPA assigns resource requests during pod creation and updates existing pods to match the latest recommendations. Updates are applied using:
  * **In-place resource resizing** when supported by the Kubernetes version, container runtime, and workload configuration, minimizing disruption
  * **Pod eviction and recreation** when in-place updates are not possible
  This mode is recommended for minimizing disruption in clusters that support in-place vertical scaling. When eviction is required, configure a PodDisruptionBudget to control disruption.
* **Recreate**:  
  VPA assigns resource requests during pod creation and **always updates existing pods via eviction and recreation**, even if in-place resizing is supported.  
  This mode is useful when workloads require a full restart to correctly apply new resource settings.
* **Initial**:  
  VPA assigns resource requests only during pod creation and does not update running pods.  
  This mode is useful for validating recommendations on new pods without impacting existing workloads.
* **Off**:  
  VPA does not automatically apply resource changes. Recommendations are still calculated and can be inspected in the VPA object.  
  This mode is recommended for:
  * initial evaluation of VPA behavior
  * production environments where manual control over updates is required
## Deployment pattern for application development

If you're unfamiliar with VPA, we recommend the following deployment pattern to understand your workloads’ resource usage and safely test VPA in a Kubernetes cluster:
1. **Start with `UpdateMode = "Off"`** in your cluster.  
   Run VPA in recommendation mode to gather data without affecting running pods. This avoids misconfigurations that could cause service disruptions.
2. **Collect and analyze telemetry** on CPU and memory usage over a representative period.  
   Establish observability to understand actual resource utilization patterns and identify any potential issues.
3. **Validate and set resource requests/limits** based on observed metrics.  
   Apply recommendations incrementally and monitor application behavior to ensure stability.
4. **Choose an appropriate update mode** for your workload:
   * `Initial` – applies resource requests only at pod creation; safe for testing new pods without affecting existing ones.
   * `Recreate` – updates existing pods via eviction and recreation; use when workloads require a full restart to apply changes.
   * `InPlaceOrRecreate` – preferred when supported; attempts in-place updates first to minimize disruption, falling back to eviction if necessary.
> **Tip:** Avoid using the deprecated `Auto` mode; it behaves the same as `Recreate` and is scheduled for removal in future Kubernetes versions.

## Next steps

To learn how to set up the Vertical Pod Autoscaler on your AKS cluster, see [Use the Vertical Pod Autoscaler in AKS](./use-vertical-pod-autoscaler.md).

<!-- EXTERNAL LINKS -->
[pod-disruption-budget]: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/

<!-- INTERNAL LINKS -->
[horizontal-pod-autoscaling]: concepts-scale.md#horizontal-pod-autoscaler
[horizontal-pod-autoscaler-overview]: concepts-scale.md#horizontal-pod-autoscaler
