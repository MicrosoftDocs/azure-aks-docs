---
title: Machine learning operations (MLOps) best practices in Azure Kubernetes Service (AKS)
description: Learn about best practices for machine learning operations (MLOps) and how you can use them with your AI and machine learning workflows on Azure Kubernetes Service (AKS).
ms.topic: best-practice
ms.service: azure-kubernetes-service
ms.date: 10/07/2024
author: schaffererin
ms.author: schaffererin
---

# Machine learning operations (MLOps) best practices in Azure Kubernetes Service (AKS)

This article describes best practices and considerations to keep in mind when using MLOps in AKS. For more information on MLOps, see [Machine learning operations (MLOps) for AI and machine learning workflows][mlops-concepts].

## Infrastructure as code (IaC)

[IaC][what-is-iac] enables consistent and reproducible infrastructure provisioning and management for a range of application types. With intelligent application deployments, your IaC implementation might change throughout the AI pipeline, as the compute power and resources needed for inferencing, serving, training, and fine-tuning models can vary. Defining and versioning IaC templates for your AI developer teams can help ensure consistency and cost-effectiveness across job types while demystifying their individual hardware requirements and accelerating the deployment process.

## Containerization

Managing your model weights, metadata, and configurations in container images allows for portability, simplified versioning, and reduced storage costs over time. With containerization, you can:

* Leverage existing container images, especially for large language models (LLMs) ranging in millions to billions of parameters in size and stable diffusion models, stored in secure container registries.
* Avoid single point of failure (SPOF) in your pipeline with the use of multiple lightweight containers containing the unique dependencies for each task instead of maintaining one large image.
* Store large text/image datasets outside of your base container image and reference them when needed at runtime.

[Get started with the Kubernetes AI Toolchain Operator][deploy-kaito] to deploy a high performance LLM on AKS in a matter of minutes.

## Model management and versioning

Model management and versioning are essential for tracking changes to your models over time. By versioning your models, you can:

* Maintain consistency across your model containers for ease of deployment in different environments.
* Employ parameter-efficient fine-tuning (PEFT) methods to iterate faster on a subset of model weights and maintain new versions in lightweight containers.

## Automation

Automation is key to reducing manual errors, increasing efficiency, and ensuring consistency across the ML lifecycle. By automating tasks, you can:

* Integrate alerting tools to automatically trigger a vector ingestion flow as new data flows into your application.
* Set model performance thresholds to track degradations and trigger retraining pipelines.

## Scalability and resource management

Scalability and resource management are critical for ensuring that your AI pipeline can handle the demands of your application. By optimizing your resource usage, you can:

* Integrate tools that efficiently use your allocated CPU, GPU, and memory resources through distributed computing and multiple levels of parallelism (for example: data, model, and pipeline parallelism).
* Enable autoscaling on your compute resources to support high model request volumes at peak times and scale down in off-peak hours.
* Similar to your traditional applications, plan for disaster recovery by following [AKS resiliency and reliability best practices][resiliency-reliability-best-practices].

## Security and compliance

Security and compliance are critical for protecting your data and ensuring that your AI pipeline meets regulatory requirements. By implementing security and compliance best practices, you can:

* Integrate common vulnerability and exposure (CVE) scanning to detect common vulnerabilities on open-source model container images.
  * Use [Microsoft Defender for Containers][defender-for-containers] for model container images stored in your Azure Container Registry.
* Maintain an audit trail of the ingested data, model changes, and metrics to remain compliant with your organizational policies.

## Next steps

Learn about best practices across other areas of your application deployment and operations on AKS:
	
* [Application resiliency and reliability best practices][resiliency-reliability-best-practices]
* [Resource management best practices][resource-management-best-practices]
* [Pod security best practices][pod-security-best-practices]
* [Enforce best practices with Deployment Safeguards][deployment-safeguards]

<!-- LINKS -->
[defender-for-containers]: /azure/defender-for-cloud/defender-for-containers-introduction
[resource-management-best-practices]: ./developer-best-practices-resource-management.md
[pod-security-best-practices]: ./developer-best-practices-pod-security.md
[deployment-safeguards]: ./deployment-safeguards.md
[mlops-concepts]: ./concepts-machine-learning-ops.md
[what-is-iac]: /devops/deliver/what-is-infrastructure-as-code
[deploy-kaito]: ./ai-toolchain-operator.md
[resiliency-reliability-best-practices]: ./ha-dr-overview.md
