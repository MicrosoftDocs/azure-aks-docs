---
title: AI and ML Workloads in Azure Kubernetes Service (AKS)
description: Learn about running AI and ML workloads in Azure Kubernetes Service (AKS), including guidance for AKS Automatic and AKS Standard.
ms.topic: overview
ms.service: azure-kubernetes-service
ms.date: 06/05/2026
author: schaffererin
ms.author: schaffererin
# Customer intent: As a data scientist, I want to deploy and manage AI and ML workloads on a container orchestration platform, so that I can optimize performance and reduce complexity while leveraging existing tools and frameworks for my applications.
---

# AI and ML workloads in Azure Kubernetes Service (AKS)

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

This article provides an overview of running artificial intelligence (AI) and machine learning (ML) workloads in Azure Kubernetes Service (AKS).

## AKS cluster modes for AI and ML

AKS supports two cluster modes:

- **AKS Automatic**, which provides more preconfigured platform defaults.
- **AKS Standard**, which provides broader direct operator control.

Many workload-level AI and ML practices apply to both cluster modes. The primary differences are in platform ownership and day-2 operations.

| Area | AKS Automatic | AKS Standard |
| ---- | ------------- | ------------- |
| Cluster operations | More preconfigured defaults for production readiness | More explicit operator configuration and lifecycle control |
| Node management and scaling | Managed system node pools and node autoprovisioning are preconfigured | Operators explicitly define and manage node pools and scaling strategy |
| Upgrades | Automatic cluster and node OS image upgrades are preconfigured | Operators choose manual or configured upgrade channels |
| Security baseline | Deployment safeguards and baseline Pod Security Standards are preconfigured in enforce mode | Security and policy controls are optional and explicitly configured |
| Monitoring baseline | Managed Prometheus and Container Insights are default when using Azure CLI or Azure portal creation flows | Monitoring components are optional and enabled explicitly |
| Networking baseline | Managed virtual network defaults and managed ingress and egress patterns in supported configurations | Networking model and ingress and egress patterns are selected explicitly |

For detailed feature comparisons, see [AKS Automatic and AKS Standard feature comparison](./intro-aks-automatic.md#aks-automatic-and-standard-feature-comparison).

## Develop and deploy AI and ML applications with AKS

AKS is an effective platform for deploying and managing containerized AI and ML applications that require scalability, portability, and high availability.

Using AKS for AI and ML enables you to:

- Use high-performance infrastructure for training and inference workloads.
- Integrate with open-source frameworks and existing DevOps processes.
- Improve operational reliability with managed Kubernetes capabilities.
- Strengthen security posture with policy and platform controls.
- Optimize cost by aligning compute resources to workload demand.

For platform strategy:

- Choose AKS Automatic when you want faster setup, more preconfigured production defaults, and reduced operational overhead.
- Choose AKS Standard when you need deeper customization of networking, identity, node pool topology, and upgrade behavior.

## Design and deploy AI and ML workloads on Azure

- [Deploy an application that uses OpenAI on Azure Kubernetes Service (AKS)](./open-ai-quickstart.md)
- [Deploy an AI model on Azure Kubernetes Service (AKS) with the AI toolchain operator add-on](./ai-toolchain-operator.md)
- [Configure and deploy a Ray cluster to accelerate ML workloads on Azure Kubernetes Service (AKS)](./deploy-ray.md)
- [Build and deploy data and machine learning pipelines with Flyte on Azure Kubernetes Service (AKS)](./use-flyte.md)

## Related content

- [What is AKS Automatic?](./intro-aks-automatic.md)
- [MLOps best practices on AKS](./best-practices-ml-ops.md)
