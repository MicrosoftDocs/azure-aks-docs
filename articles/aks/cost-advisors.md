---
title: Get AKS cost recommendations in Azure Advisor
description: Get AKS cost best practices
author: kaysieyu
ms.author: kaysieyu
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 03/28/2025
---

## About Azure Advisor?
AKS cost recommendations in Azure Advisor follow AKS cost best practices and help you optimize your deployments to achieve cost-efficiency without compromising on reliability. Advisor analyzes your resource configuration and recommends solutions to optimize your AKS cluster.

With Advisor, you can:
* Get proactive, actionable, and personalized best practices recommendations.
* Identify opportunities to reduce your overall Azure spend.
* Get recommendations with proposed actions inline.

Cost is one of five categories that Advisor recommendations can fall into. Others include: reliability, security, performance, and operational excellence. Learn more at: 
[Introduction to Azure Advisor](https://learn.microsoft.com/azure/advisor/advisor-overview).

## Prerequisites
* To access Advisor recommendations you must have one of the following roles: Owner, Contributor, or Reader of a subscription, resource group, or resource.

## AKS cost recommendations
Recommendations are available for all clusters, but only the ones relevant to the cluster configuration and historical usage will be surfaced. There is no action required by the customer to enable Azure Advisor, as it is a provided by default for all Azure services out of box.

AKS cost recommendations include the following:
* Enable Vertical Pod Autoscaler recommendation mode to rightsize resource requests and limits.
* Use Azure Kubernetes Service Cost Analysis.
* Fine-tune the cluster autoscaler profile for rapid scale down and cost savings.
* Consider Spot nodes for workloads that can handle interruptions.

Learn more at [Cost recommendations](https://learn.microsoft.com/azure/advisor/advisor-reference-cost-recommendations#azure-kubernetes-service).


## View the Advisor dashboard
You can view recommendations on the Advisor dashboard in Azure portal. See [Azure Advisor portal basics](https://learn.microsoft.com/azure/advisor/advisor-get-started). 

<!-- TODO: If you only want to look at the recommendations in the cluster context you can do so by navigating to the _Advisor recommendation_ tab in the left-side navigation.  -->
<!-- TODO: add a screenshot of the advisors entry point from cluster page. -->


## Next steps

To learn more about cost optimization in Azure Kubernetes Service (AKS), see the following articles:

- [Best practices for cost optimization in Azure Kubernetes Service (AKS)](./best-practices-cost.md)
- [Understand Azure Kubernetes Service (AKS) usage and costs](./understand-aks-costs.md)
- [Optimize Azure Kubernetes Service (AKS) usage and costs](./optimize-aks-costs.md)
- [Operate cost optimized Azure Kubernetes Service (AKS) at scale](./operate-cost-optimized-scale.md)
