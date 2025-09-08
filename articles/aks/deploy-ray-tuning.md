---
title: Deploy a Ray Cluster for Tuning with BlobFuse on Azure Kubernetes Service (AKS)
description: In this article, you deploy a Ray cluster for tuning with BlobFuse on Azure Kubernetes Service (AKS).
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 7/17/2025
author: fhryo-msft
ms.author: fryu
ms.custom: 'stateful-workloads'
---

# Configure and deploy a Ray cluster for tuning with BlobFuse on Azure Kubernetes Service (AKS)

In this article, you configure and deploy a Ray cluster on Azure Kubernetes Service (AKS) using KubeRay, with BlobFuse providing scalable storage. You'll learn how to set up the cluster, integrate BlobFuse for high-throughput data access, and use Ray to run distributed tuning or training jobs. The guide also covers monitoring results on the Ray Dashboard and managing resources efficiently.

## Overview

Ray is an open-source framework for distributed computing and machine learning workloads. When deployed on Azure Kubernetes Service (AKS), Ray enables scalable hyperparameter tuning, training, and inference across multiple nodes. Integrating BlobFuse as a persistent storage backend allows Ray jobs to efficiently read and write large datasets, which is especially critical for tuning workloads that require rapid access to training data, intermediate results, and model checkpoints.

High throughput from BlobFuse is essential for tuning jobs because these workloads often involve many parallel tasks, each reading and writing data simultaneously. BlobFuse provides POSIX-compliant, high-performance access to Azure Blob Storage, minimizing I/O bottlenecks and ensuring that distributed Ray tasks can complete faster. This results in more efficient resource utilization and accelerates the overall tuning process.

This solution leverages KubeRay to orchestrate Ray clusters on AKS, with BlobFuse providing scalable and performant storage. The architecture supports robust data management, fast I/O, and seamless scaling, enabling data scientists and engineers to optimize model development and tuning workflows in the cloud.

## Deployment architecture

The following diagram shows a Ray cluster deployed on AKS, with persistent volumes provisioned using BlobFuse. BlobFuse connects Azure Blob Storage to the cluster, enabling fast, POSIX-compliant access to large datasets. This architecture ensures high throughput for distributed tuning jobs, allowing multiple Ray workers to efficiently read and write data in parallel, which accelerates model training and hyperparameter optimization.

:::image type="content" source="./media/deploy-ray-tuning/ray-cluster-architecture.png" alt-text="Ray cluster architecture on Azure Kubernetes Service with BlobFuse":::

*Figure 1: Ray cluster deployed on AKS with BlobFuse providing scalable, high-throughput storage for distributed tuning jobs.*

## Storage considerations

When deploying Ray clusters for distributed tuning on AKS, choosing the right storage backend is critical for performance and scalability. The main options are Azure Disks, Azure Files, and BlobFuse (Azure Blob Storage):

| Storage Option      | Scalability         | Performance (Throughput) | Access Mode         | Cost Efficiency      | Suitability for Distributed Tuning Jobs |
|---------------------|---------------------|--------------------------|---------------------|---------------------|-----------------------------------------|
| **Azure Disks**     | Limited (per node)  | High (single node)       | Single/Shared node  | Higher for large data| Not ideal (limited concurrent access)   |
| **Azure Files**     | Moderate            | Moderate                 | Multi-node (shared) | Moderate            | Usable, but might bottleneck at scale     |
| **BlobFuse/Blobs**  | High (cloud scale)  | High (parallel access)   | Multi-node (shared) | Cost-effective      | Best (scalable, high throughput, parallel access) |

**Recommendation:**  
BlobFuse (Azure Blob Storage) is the preferred option for Ray clusters running distributed tuning jobs on AKS. It offers cloud-scale concurrency, high throughput for parallel reads/writes, and cost-effective storage, making it ideal for data-intensive machine learning workloads.

## Deploy Ray clusters for tuning with BlobFuse

### Prerequisites

* Review the [Ray cluster on AKS overview](./ray-overview.md) to understand the components and deployment process.
* An Azure subscription. If you don't have an Azure subscription, you can create a free account [here](https://azure.microsoft.com/free/).
* The Azure CLI installed on your local machine. You can install it using the instructions in [How to install the Azure CLI](/cli/azure/install-azure-cli).
* The [Azure Kubernetes Service Preview extension](/azure/aks/draft#install-the-aks-preview-azure-cli-extension) installed.
* [Helm](https://helm.sh/docs/intro/install/) installed.
* [Terraform client tools](https://developer.hashicorp.com/terraform/install) or [OpenTofu](https://opentofu.org/) installed. This article uses Terraform, but the modules used should be compatible with OpenTofu.

### Deploy the Ray sample automatically

If you want to deploy the complete Ray sample non-interactively, you can use the `deploy.sh` script in the GitHub repository ([https://github.com/Azure-Samples/aks-ray-sample](https://github.com/Azure-Samples/aks-ray-sample)). This script completes the steps outlined in the [Ray deployment process section](./ray-overview.md#ray-deployment-process).

1. Clone the GitHub repo locally and change to the root of the repo using the following commands:

    ```bash
    git clone https://github.com/Azure-Samples/aks-ray-sample
    cd aks-ray-sample/sample-tuning-setup/terraform
    ```

1. Deploy the complete sample using the following commands:

    ```bash
    chmod +x deploy.sh
    ./deploy.sh
    ```

1. Once the deployment completes, review the output of the logs and the resource group in the Azure portal to see the infrastructure that was created.

### Clean up resources

To clean up the resources created in this guide, you can delete the Azure resource group that contains the AKS cluster.

## Next steps

To learn more about AI and machine learning workloads on AKS, see the following articles:

* [Deploy an application that uses OpenAI on Azure Kubernetes Service (AKS)](./open-ai-quickstart.md)
* [Build and deploy data and machine learning pipelines with Flyte on Azure Kubernetes Service (AKS)](./use-flyte.md)
* [Deploy an AI model on Azure Kubernetes Service (AKS) with the AI toolchain operator](./ai-toolchain-operator.md)