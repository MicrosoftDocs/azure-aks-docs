---
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 05/22/2026
author: wangyira
ms.author: wangamanda
---

> [!IMPORTANT]
> Starting on AKS 1.36, new AKS Automatic clusters will by default enable [Kubernetes Gateway API via the application routing add-on](../../app-routing-gateway-api.md) instead of [Managed NGINX ingress with the application routing add-on](../../app-routing.md) due to the upstream [Ingress NGINX retirement](https://www.kubernetes.dev/blog/2025/11/12/ingress-nginx-retirement/).
>
> Existing Automatic clusters aren't affected but should begin migration to [Kubernetes Gateway API via the application routing add-on](../../app-routing-gateway-api.md#enable-for-an-existing-cluster).