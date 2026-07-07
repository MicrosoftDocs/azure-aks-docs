---
title: Run Ray AI workloads with Kueue on Azure Kubernetes Service (AKS) overview
description: Learn how to run Ray AI workloads with Kueue admission control on Azure Kubernetes Service (AKS), including training, inference, and serving.
ms.topic: overview
ms.service: azure-kubernetes-service
ms.date: 06/26/2026
author: feiskyer
ms.author: peni
ms.custom: 'stateful-workloads'
---

# Run Ray AI workloads with Kueue on Azure Kubernetes Service (AKS) overview

In this article, you learn how to run distributed AI workloads on Azure Kubernetes Service (AKS) using Ray for the compute runtime and Kueue for admission control. This solution covers the full lifecycle from infrastructure provisioning through training, batch inference, and online serving.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## What is Ray?

[Ray](https://docs.ray.io/en/latest/index.html) is an open-source framework for scaling AI and Python applications. It provides a unified runtime for distributed training, hyperparameter tuning, batch inference, and model serving, so you can scale workloads across multiple nodes without rewriting application logic.

Ray simplifies distributed computing by handling scheduling, fault tolerance, and resource management. The framework supports machine learning libraries like PyTorch, TensorFlow, and Hugging Face through integrations such as Ray Train, Ray Data, and Ray Serve. For more information, see the [Ray GitHub repository](https://github.com/ray-project/ray).

## What is KubeRay?

[KubeRay](https://docs.ray.io/en/latest/cluster/kubernetes/getting-started.html) is a Kubernetes operator that manages the lifecycle of Ray clusters. It provides custom resources - `RayJob` for batch workloads and `RayService` for persistent serving endpoints - that automate cluster creation, scaling, and teardown. For more information, see the [KubeRay GitHub repository](https://github.com/ray-project/kuberay).

## What is Kueue?

[Kueue](https://kueue.sigs.k8s.io/) is a Kubernetes-native job queueing controller that manages workload admission based on resource quotas. Instead of letting every submitted job consume resources immediately, Kueue gates admission against defined quotas - jobs that fit run, jobs that don't wait in line. For a detailed overview of Kueue concepts and configuration, see [Kueue overview on AKS](./kueue-overview.md).

## Solution architecture

This solution combines Kueue for admission control with KubeRay for Ray cluster lifecycle management on AKS. Terraform provisions the infrastructure, Helm installs the operators from Microsoft Container Registry (MCR), and workload identity provides secure access to Azure Blob Storage without stored credentials.

The deployment process consists of three modules:

- **Infrastructure** — Terraform provisions the AKS cluster with GPU node pools, installs KubeRay and Kueue operators via Helm, creates Azure Blob Storage, and configures workload identity.
- **Kueue queues** — Kubernetes manifests define ResourceFlavors (CPU and GPU node types), ClusterQueues (quotas and admission policies), and LocalQueues (namespace-scoped submission points).
- **Workloads** — RayJob and RayService manifests submit AI workloads that Kueue admits based on available quota.

Ray workloads start with `suspend: true`. Kueue evaluates quota availability and unsuspends admitted workloads, at which point KubeRay creates the Ray cluster and runs the job.

## Workload examples

| Example | Type | GPUs | Description |
|---------|------|------|-------------|
| [Fine-tune Aurora weather model](./ray-finetune-aurora.md) | RayJob | 1×A100 | LoRA fine-tune of the Microsoft Aurora weather foundation model |
| [Train an LLM](./ray-train-llm.md) | RayJob | 4×A100 | Distributed Qwen2.5-7B LoRA fine-tune with LLaMA-Factory |
| [Run batch inference](./ray-batch-inference.md) | RayJob | 1×A100 | vLLM offline inference with a trained LoRA adapter |
| [Serve a model online](./ray-online-serving.md) | RayService | 1×GPU | Persistent HTTP endpoint with Ray Serve |

## Next step

> [!div class="nextstepaction"]
> [Deploy infrastructure for Ray and Kueue on AKS](./deploy-ray-infrastructure.md)
