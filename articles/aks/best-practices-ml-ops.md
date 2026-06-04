---
title: Machine Learning Operations (MLOps) Best Practices in Azure Kubernetes Service (AKS)
description: Learn MLOps best practices for AI and machine learning workflows on Azure Kubernetes Service (AKS), including guidance for AKS Automatic and AKS Standard.
ms.topic: best-practice
ms.service: azure-kubernetes-service
ms.date: 06/04/2026
author: schaffererin
ms.author: schaffererin
# Customer intent: As a machine learning engineer, I want to implement MLOps best practices in my AI workflows on Kubernetes, so that I can ensure consistent, scalable, and secure deployment and management of machine learning models.
---

# Machine learning operations (MLOps) best practices in Azure Kubernetes Service (AKS)

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

This article describes best practices and considerations to keep in mind when using MLOps in AKS. For more information on MLOps, see [Machine learning operations (MLOps) for AI and machine learning workflows][mlops-concepts].

## Choose your AKS mode for MLOps

AKS supports two cluster modes: [**AKS Automatic**](./intro-aks-automatic.md) and **AKS Standard**. Choose AKS Automatic when you want a production-ready baseline with less day-2 platform management. Choose AKS Standard when you need deeper control over cluster infrastructure and platform configuration.

The MLOps practices in this article apply to both modes. However, implementation responsibility differs by mode: AKS Automatic provides more preconfigured defaults, while AKS Standard typically requires more explicit platform configuration and lifecycle ownership.

| Area | AKS Automatic | AKS Standard |
| ---- | ------------- | ------------ |
| Baseline cluster setup | More preconfigured defaults | More explicit setup choices |
| System node pool operations | More service-managed behavior | More operator-managed behavior |
| Security baseline controls | Several controls are preconfigured in common scenarios | Controls are commonly enabled and maintained by operators |
| Networking baseline | Opinionated defaults for common patterns | Broader network configuration flexibility |
| Operations and upgrades | More managed operational behavior | More operator-directed behavior |
| MLOps implementation focus | Validate, govern, and tune defaults | Design and configure platform controls |

## Infrastructure as code (IaC)

[IaC][what-is-iac] enables consistent and reproducible infrastructure provisioning and management for a range of application types. With intelligent application deployments, your IaC implementation might change throughout the AI pipeline, as the compute power and resources needed for inferencing, serving, training, and fine-tuning models can vary. Defining and versioning IaC templates for your AI developer teams can help ensure consistency and cost-effectiveness across job types while demystifying their individual hardware requirements and accelerating the deployment process.

In AKS Automatic, IaC can focus more on workload definitions, policy guardrails, and environment consistency over platform defaults. In AKS Standard, IaC commonly includes more explicit cluster platform settings such as networking, scaling, and operational configuration choices.

## Containerization

Managing your model weights, metadata, and configurations in container images allows for portability, simplified versioning, and reduced storage costs over time. With containerization, you can:

- Leverage existing container images, especially for large language models (LLMs) ranging in millions to billions of parameters in size and stable diffusion models, stored in secure container registries.
- Avoid single point of failure (SPOF) in your pipeline with the use of multiple lightweight containers containing the unique dependencies for each task instead of maintaining one large image.
- Store large text/image datasets outside of your base container image and reference them when needed at runtime.

[Get started with the Kubernetes AI Toolchain Operator][deploy-kaito] to deploy a high performance LLM on AKS in a matter of minutes.

Container supply chain controls remain essential in both modes. Even with preconfigured platform defaults in AKS Automatic, image provenance, scanning, and runtime hardening are still core MLOps responsibilities.

## Model management and versioning

Model management and versioning are essential for tracking changes to your models over time. By versioning your models, you can:

- Maintain consistency across your model containers for ease of deployment in different environments.
- Employ parameter-efficient fine-tuning (PEFT) methods to iterate faster on a subset of model weights and maintain new versions in lightweight containers.

In AKS Automatic, preconfigured platform baselines can simplify environment parity. In AKS Standard, teams often need to enforce parity more explicitly through platform and deployment configuration.

## Automation

Automation is key to reducing manual errors, increasing efficiency, and ensuring consistency across the ML lifecycle. By automating tasks, you can:

- Integrate alerting tools to automatically trigger a vector ingestion flow as new data flows into your application.
- Set model performance thresholds to track degradations and trigger retraining pipelines.

In both AKS modes, include automation for policy validation, configuration drift detection, and release governance in addition to model quality triggers.

## Scalability and resource management

Scalability and resource management are critical for ensuring that your AI pipeline can handle the demands of your application. By optimizing your resource usage, you can:

- Integrate tools that efficiently use your allocated CPU, GPU, and memory resources through distributed computing and multiple levels of parallelism (for example: data, model, and pipeline parallelism).
- Enable autoscaling on your compute resources to support high model request volumes at peak times and scale down in off-peak hours.
- Similar to your traditional applications, plan for disaster recovery by following [AKS resiliency and reliability best practices][resiliency-reliability-best-practices].

AKS Automatic can reduce setup overhead for common scaling and operations patterns, while AKS Standard provides deeper control for custom scaling architectures.

## Security and compliance

Security and compliance are critical for protecting your data and ensuring that your AI pipeline meets regulatory requirements. By implementing security and compliance best practices, you can:

- Integrate scanning for Common Vulnerabilities and Exposures (CVEs) to detect common vulnerabilities on open-source model container images.
  - Use [Microsoft Defender for Containers][defender-for-containers] for model container images stored in your Azure Container Registry.
- Maintain an audit trail of the ingested data, model changes, and metrics to remain compliant with your organizational policies.

In AKS Automatic, preconfigured security defaults improve baseline posture, but model-level, data-level, and pipeline-level security controls remain required.

## Related content

Learn about best practices across other areas of your application deployment and operations on AKS:

- [AKS Automatic and AKS Standard feature comparison](./intro-aks-automatic.md#aks-automatic-and-standard-feature-comparison)
- [Application resiliency and reliability best practices][resiliency-reliability-best-practices]
- [Resource management best practices][resource-management-best-practices]
- [Pod security best practices][pod-security-best-practices]
- [Enforce best practices with Deployment Safeguards][deployment-safeguards]

<!-- LINKS -->
[defender-for-containers]: /azure/defender-for-cloud/defender-for-containers-introduction
[resource-management-best-practices]: ./developer-best-practices-resource-management.md
[pod-security-best-practices]: ./developer-best-practices-pod-security.md
[deployment-safeguards]: ./deployment-safeguards.md
[mlops-concepts]: ./concepts-machine-learning-ops.md
[what-is-iac]: /devops/deliver/what-is-infrastructure-as-code
[deploy-kaito]: ./ai-toolchain-operator.md
[resiliency-reliability-best-practices]: ./ha-dr-overview.md
