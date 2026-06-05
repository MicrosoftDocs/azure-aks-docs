---
title: Concepts - Machine Learning Operations (MLOps) for AI and Machine Learning Workflows in AKS
description: Learn about MLOps and how to apply it to AI and machine learning workflows on Azure Kubernetes Service (AKS), including AKS Automatic and AKS Standard considerations.
ms.topic: concept-article
ms.date: 06/04/2026
ms.service: azure-kubernetes-service
author: schaffererin
ms.author: schaffererin
# Customer intent: As a machine learning engineer, I want to implement MLOps practices in my AI workflows, so that I can automate the model lifecycle and enhance collaboration between teams for faster and more reliable deployments.
---

# Concepts - Machine learning operations (MLOps) for AI and machine learning workflows

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

In this article, you learn about machine learning operations (MLOps), including what types of practices and tools are involved, and how it can simplify and speed up your AI and machine learning workflows on Azure Kubernetes Service (AKS).

## AKS cluster modes for MLOps

AKS supports two cluster modes: [**AKS Automatic**](./intro-aks-automatic.md) and **AKS Standard**. Choose AKS Automatic when you want a production-ready baseline with less day-2 platform management. Choose AKS Standard when you need deeper control over cluster infrastructure and platform configuration.

The MLOps lifecycle concepts in this article apply to both modes. However, implementation responsibility differs by mode: AKS Automatic provides more preconfigured defaults, while AKS Standard typically requires more explicit platform configuration and lifecycle ownership.

| Area | AKS Automatic | AKS Standard |
| ---- | ------------- | ------------ |
| Baseline cluster setup | More preconfigured defaults | More explicit setup choices |
| System node pool operations | More service-managed behavior | More operator-managed behavior |
| Security baseline controls | Several controls are preconfigured in common scenarios | Controls are commonly enabled and maintained by operators |
| Networking baseline | Opinionated defaults for common patterns | Broader network configuration flexibility |
| Operations and upgrades | More managed operational behavior | More operator-directed behavior |
| MLOps implementation focus | Validate, govern, and tune defaults | Design and configure platform controls |

## What is MLOps?

Machine learning operations (MLOps) encompasses practices that facilitate collaboration between data scientists, IT operations, and business stakeholders, ensuring that machine learning models are developed, deployed, and maintained efficiently. MLOps applies DevOps principles to machine learning projects, aiming to automate and streamline the end-to-end machine learning lifecycle. This lifecycle includes training, packaging, validating, deploying, monitoring, and retraining models.

MLOps requires multiple roles and tools to work together effectively. Data scientists focus on tasks related to training the model, which is referred to as the **inner loop**. Machine learning engineers and IT operations teams handle the **outer loop**, where they apply DevOps practices to package, validate, deploy, and monitor models. When the model needs fine-tuning or retraining, the process loops back to the inner loop.

These lifecycle steps are consistent across AKS cluster modes. The main difference is how much platform setup and operational configuration your teams manage directly.

### MLOps pipeline

Your MLOps pipeline may leverage various tools and microservices that are deployed sequentially or in parallel. Below are examples of key components in your pipeline that benefit from implementing the following best practices to reduce overhead and allow for faster iteration:

- Unstructured data store for new data flowing into your application
- Vector database to store and query structured, pre-processed data
- Data ingestion and indexing framework
- Vector ingestion and/or model retraining workflows
- Metrics collection and alerting tools (tracking model performance, volume of ingested data, etc.)
- Lifecycle management tools

These pipeline components are relevant for both AKS Automatic and AKS Standard. Mode choice primarily affects platform ownership boundaries rather than pipeline intent.

## DevOps and MLOps

DevOps is a combination of tools and practices that enable you to create robust and reproducible applications. The goal of using DevOps is to quickly deliver value to your end users. Creating, deploying, and monitoring robust and reproducible models to deliver value to end users is the primary goal of MLOps.

There are _three_ processes that are essential to MLOps:

- **Machine learning workloads** for which a data scientist is responsible, including exploratory data analysis (EDA), feature engineering, and model training and tuning.
- **Software development practices** including planning, developing, testing, and packaging the model for deployment.
- **Operational aspects of deploying and maintaining the model in production**, including releasing, configuring resources, and monitoring the model.

In AKS Automatic, teams can often spend less effort on common platform setup and more on policy, quality, and model lifecycle orchestration. In AKS Standard, teams typically perform more explicit platform design and configuration.

### DevOps principles that apply to MLOps

MLOps leverages several principles from DevOps to enhance the machine learning lifecycle, such as _automation_, _continuous integration and delivery (CI/CD)_, _source control_, _Agile planning_, and _infrastructure as code (IaC)_.

#### Automation

By automating tasks, you can reduce manual errors, increase efficiency, and ensure consistency across the ML lifecycle. Automation can be applied to various stages, including data collection, model training, deployment, and monitoring. Through automation, you can also apply proactive measures in the AI pipeline to ensure data compliance with your organization's policies.

For example, your pipeline can automate:

- Model tuning/retraining at regular time intervals or when a certain amount of new data is collected in your application.
- Detection of performance degradation to kickstart fine-tuning or retraining on a different subset of data.
- Common Vulnerabilities and Exposures (CVEs) scanning on base container images pulled from external container registries to ensure safe security practices.

In both AKS cluster modes, include automation for policy validation, configuration drift detection, and release governance in addition to model quality triggers.

#### Continuous integration (CI)

Continuous integration covers the _creating_ and _verifying_ aspects of the model development process. The goal of CI is to create the code and to verify the quality of the code and the model before deployment. This includes testing on a range of sample data sets to ensure that the model performs as expected and meets quality standards.

In MLOps, CI might involve:

- Refactoring exploratory code in Jupyter notebooks into Python or R scripts.
- Validating new input data for missing or error values.
- Unit testing and integration testing in the end-to-end pipeline.

To perform linting and unit testing, you can use automation tools like Azure Pipelines in Azure DevOps or GitHub Actions.

In AKS Automatic, CI commonly validates artifacts against expected platform defaults. In AKS Standard, CI often validates assumptions against explicitly configured platform settings.

#### Continuous delivery (CD)

Continuous delivery involves the steps needed to safely deploy a model in production. The first step is to package and deploy the model in _pre-production environments_, such as dev and test environments. Portability of the parameters, hyperparameters, and other model artifacts is an important aspect to maintain as you promote the code through these environments. This portability is especially important when it comes to large language models (LLMs) and stable diffusion models. Once the model passes the unit tests and quality assurance (QA) tests, you can approve it for deployment in the _production environment_.

Promotion practices are similar in both AKS cluster modes, but AKS Standard pipelines often include more infrastructure-specific validation before release.

#### Source control

Source control, or _version control_, is essential for managing changes to code and models. In an ML system, this refers to data versioning, code versioning, and model versioning, which allow cross-functional teams to collaborate effectively and track changes over time. Using a Git-based source control system, like [**Azure Repos**](https://azure.microsoft.com/products/devops/repos/#:~:text=Overview.%20Free%20private%20Git%20repositories,%20pull%20requests,%20and?msockid=182ea2d5e1ff6eb61ccbb1b8e5ff608a) in Azure DevOps or a **GitHub repository**, enables you to programmatically maintain a history of changes, revert to previous versions, and manage branches for different experiments.

#### Agile planning

Agile planning involves isolating work into _sprints_, which are short time frames for completing specific tasks. This approach allows teams to adapt to changes quickly and deliver incremental improvements to the model. Model training can be an ongoing process, and Agile planning can help scope the project and enable better team alignment.

You can use tools like [**Azure Boards**](/azure/devops/boards/get-started/what-is-azure-boards) in Azure DevOps or **GitHub issues** to manage your Agile planning.

#### Infrastructure as code (IaC)

You use infrastructure as code to repeat and automate the infrastructure needed to train, deploy, and serve your models. In an ML system, IaC helps simplify and define the appropriate Azure resources needed for the specific job type in code, and the code is maintained in a repository. This allows you to version control your infrastructure and make changes for resource optimization, cost-effectiveness, etc. as needed.

In AKS Automatic, IaC commonly emphasizes workload definitions, governance controls, and environment consistency. In AKS Standard, IaC often includes broader explicit cluster and platform configuration.

## Related content

Check out the following articles to learn about best practices for MLOps in your intelligent applications on AKS:

- [Machine learning operations best practices on AKS][mlops-best-practices]
- [AKS Automatic and AKS Standard feature comparison](./intro-aks-automatic.md#aks-automatic-and-standard-feature-comparison)
- [Deploy an AI model with AI toolchain operator][deploy-kaito]
- [Resource management best practices on AKS][resource-management-best-practices]
- [Enforce pod security on your AKS cluster as an app developer][pod-security-best-practices]

<!-- LINKS -->
[mlops-best-practices]: ./best-practices-ml-ops.md
[deploy-kaito]: ./ai-toolchain-operator.md
[resource-management-best-practices]: ./developer-best-practices-resource-management.md
[pod-security-best-practices]: ./developer-best-practices-pod-security.md