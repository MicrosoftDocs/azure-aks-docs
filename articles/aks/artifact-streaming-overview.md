---
title: Overview of Artifact Streaming on Azure Kubernetes Service (AKS)
description: Learn about Artifact Streaming on Azure Kubernetes Service (AKS) with Azure Container Registry (ACR), including how it works, benefits, and use cases.
author: allyford
ms.author: allyford
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.topic: overview
ms.date: 05/05/2026
ms.subservice: aks-nodes
---

# Overview of Artifact Streaming on Azure Kubernetes Service (AKS)

This article provides an overview of Artifact Streaming on Azure Kubernetes Service (AKS) with Azure Container Registry (ACR). Artifact Streaming streams container images from ACR to AKS, so you only pull the necessary layers for the initial pod startup. This feature reduces the time it takes to deploy your workloads.

## How does Artifact Streaming work?

In a standard container startup, Kubernetes downloads all image layers before the workload starts. This process can take time for large images or when starting multiple pods.

Artifact Streaming on AKS changes this behavior by retrieving only the layers required for the initial pod startup. The runtime retrieves the remaining data later as needed. This capability uses [OverlayBD](https://github.com/containerd/overlaybd), which converts container image layers into a virtual block device. The runtime can access data at the block level instead of downloading the full image. By using this approach, you retrieve only the blocks that are accessed during startup and runtime. If an application uses only part of the image, only that portion is pulled.

> [!NOTE]
> Artifact Streaming on AKS **only supports image pulls by tag**.
>
> Artifact Streaming works by resolving image pulls by tag to a streaming variant of the image. If you use digest for image pulls, you can't use Artifact Streaming.

## Benefits and use cases

With Artifact Streaming on AKS, you can:

- **Deploy containerized applications across multiple regions**: Stream container images from a single Azure container registry to AKS clusters in different regions. This approach reduces the time and resources required to replicate images.
- **Reduce time to pod readiness**: Start pods before the full image is downloaded, which can reduce time to pod readiness (especially for large images).
- **Improve scaling efficiency**: Support large-scale deployments by reducing startup delays when creating or scaling multiple pods.
- **Optimize startup for large images**: Improve initialization time for workloads that don't require all image layers at startup, such as containerized stateful workloads (like Java or C# applications) or workloads with dependencies baked into the image that aren't needed immediately at pod startup.

## Considerations

Keep the following considerations in mind when using Artifact Streaming on AKS:

- Read-heavy images that need to read the file on startup don't benefit from Artifact Streaming. If you have a pod that needs access to a large file (>30 GB), mount it as a volume instead of building it as a layer. If your pod requires that file to start, it congests the node.
- You can start Artifact Streaming for specific repositories or tags in new or existing container registries.
- You can store both the original and the streaming artifact in the ACR by starting Artifact Streaming.
- You can access the original and the streaming artifact even after turning off Artifact Streaming for repositories or artifacts.
- If you enable Artifact Streaming and Soft Delete and you delete a repository or artifact, both the original and Artifact Streaming versions are deleted. However, only the original version is available on the Soft Delete portal.

## Related content

To get started with using Artifact Streaming on AKS, see [Enable Artifact Streaming on Azure Kubernetes Service (AKS) with Azure Container Registry (ACR)](./artifact-streaming.md).
