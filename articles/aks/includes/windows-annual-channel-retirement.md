---
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 02/05/2026
author: schaffererin
ms.author: schaffererin
---

> [!IMPORTANT]
> Starting on **May 15, 2026**, AKS no longer supports Windows Server Annual Channel (Preview). AKS will no longer produce new Windows Server Annual Channel node images or provide security patches. You won't be able to create new node pools with Windows Server Annual Channel. On **May 15, 2027**, AKS will remove all existing Windows Server Annual Channel node images, which will cause scaling and remediation (reimage and redeploy) operations to fail. To avoid disruption, we recommend migrating to the [Long Term Servicing Channel (LTSC)](/azure/aks/upgrade-windows-os).
>
> - Windows Server Annual Channel uses Windows Server 2022 base images, which will run on Windows Server 2022 and Windows Server 2025.
> - If you're using [Host Process Containers (HPC)](../use-windows-hpc.md) or running other privileged containers for administration purposes, you'll need to do additional testing.
>
> For more information on this retirement, see the [Retirement GitHub issue](https://aka.ms/aks/windows-annual-channel-retirement). To stay informed on announcements and updates, follow the [AKS release notes](https://github.com/Azure/AKS/releases).