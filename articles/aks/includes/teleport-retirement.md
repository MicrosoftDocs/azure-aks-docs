---
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 01/14/2026
author: schaffererin
ms.author: schaffererin
---

> [!IMPORTANT]
> Starting on **July 15, 2025**, Azure Kubernetes Service (AKS) no longer supports [Teleport (preview)](https://github.com/Azure/acr/blob/main/docs/teleport/aks-getting-started.md) on AKS. After this date, AKS node pools with Teleport enabled might experience breakage and node provisioning failures. Azure Container Registry removed the Teleport API, meaning that any nodes with Teleport enabled will pull images from Azure Container Registry like any other AKS node without Teleport. Migrate to [Artifact Streaming (preview)](/azure/aks/artifact-streaming) or update your node pools to set `--aks-custom-headers EnableACRTeleport=false`. For more information on this retirement, see [aka.ms/aks/teleport-retirement](https://aka.ms/aks/teleport-retirement).