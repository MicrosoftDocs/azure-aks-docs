---
title: Get Azure Kubernetes Service (AKS) cost recommendations in Azure Advisor
description: Learn how to get Azure Kubernetes Service (AKS) cost recommendations using Azure Advisor.
author: kaysieyu
ms.author: kaysieyu
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 03/28/2025
---

# Get Azure Kubernetes Service (AKS) cost recommendations in Azure Advisor

AKS cost recommendations in Azure Advisor follow AKS cost best practices and help you optimize your deployments to achieve cost-efficiency without compromising on reliability. Advisor analyzes your resource configuration and recommends solutions to optimize your AKS cluster.

With Advisor, you can:

* Get proactive, actionable, and personalized best practices recommendations.
* Identify opportunities to reduce your overall Azure spend.
* Get recommendations with proposed actions inline.

Cost is one of five categories that Advisor recommendations can fall into. Other categories include reliability, security, performance, and operational excellence. For more information, see the
[Introduction to Azure Advisor](/azure/advisor/advisor-overview).


## Prerequisites

* To access Advisor recommendations you must have one of the following roles: Owner, Contributor, or Reader of a subscription, resource group, or resource.

## AKS cost recommendations

Recommendations are available for all clusters, but only the ones relevant to the cluster configuration and historical usage will be surfaced. There is no action required by the customer to enable Azure Advisor, as it is a provided by default for all Azure services out of box.

AKS cost recommendations include the following:

* Enable Vertical Pod Autoscaler recommendation mode to rightsize resource requests and limits.
* Use Azure Kubernetes Service Cost Analysis.
* Fine-tune the cluster autoscaler profile for rapid scale down and cost savings.

For more information, see [Cost recommendations](/azure/advisor/advisor-reference-cost-recommendations#azure-kubernetes-service).

### Enable Vertical Pod Autoscaler recommendation mode to rightsize resource requests and limits

Setting the correct request and limit values is difficult given the required amount of resources can vary greatly across workloads. Managing this at scale across hundreds or thousands of pods is an even greater challenge. Vertical Pod Autoscaler (VPA) automatically adjusts CPU and memory requests and limits for your pods based on historical workload usage patterns to improve resource utilization. 

If you don't want VPA to automatically adjust the values and want additional control, VPA recommendation only mode provides suggested values without making automatic changes. This enables you to review and implement suggested values manually, which can prevent potential disruptions and ensure better control over resource allocation. VPA recommendation mode is a great option to help prevent over-provisioning, a major driver of unnecessary spend.

For more information, see [Vertical pod autoscaling in Azure Kubernetes Service (AKS)](./vertical-pod-autoscaler.md#vpa-overview).

### Use Azure Kubernetes Service cost analysis

AKS cost analysis add-on provides detailed insights into the cost of resources used by your AKS cluster. View costs broken down by Kubernetes constructs like clusters and namespaces. This feature helps you identify cost drivers, track historical trends, identify anomalies and clusters or workloads with optimization opportunities. Having cost monitoring in place is an easy way to get visibility into cluster spend and take action to achieve significant cost savings. 

> [!NOTE]
> This recommendation is only available for public cloud clusters running in Enterprise or MCA type subscriptions.

For more information, see [Azure Kubernetes Service (AKS) cost analysis](./cost-analysis.md).


### Fine-tune the cluster autoscaler profile for rapid scale down and cost savings

The cluster autoscaler profile is a set of parameters that control the behavior of the cluster autoscaler, which automatically adjusts the number of nodes in a cluster based on workload demand. Tuning these settings allows greater control over autoscaler behavior to optimize resource allocation for specific scenarios. A rapid scale down configuration means more aggressive node scale, which means less idle node costs. 

For more information, see [Use the cluster autoscaler in Azure Kubernetes Service (AKS)](./cluster-autoscaler.md#configure-cluster-autoscaler-profile-for-aggressive-scale-down).



## View the Advisor dashboard

You can view recommendations on the Advisor dashboard in Azure portal. For more information, see [Azure Advisor portal basics](/azure/advisor/advisor-get-started). 



## Next steps

To learn more about cost optimization in Azure Kubernetes Service (AKS), see the following articles:

- [Best practices for cost optimization in Azure Kubernetes Service (AKS)](./best-practices-cost.md)
- [Understand Azure Kubernetes Service (AKS) usage and costs](./understand-aks-costs.md)
- [Optimize Azure Kubernetes Service (AKS) usage and costs](./optimize-aks-costs.md)
- [Operate cost optimized Azure Kubernetes Service (AKS) at scale](./operate-cost-optimized-scale.md)
