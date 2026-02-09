---
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 01/29/2026
author: schaffererin
ms.author: schaffererin
---

> [!IMPORTANT]
>
> The [Kubernetes SIG Network](https://github.com/kubernetes/community/blob/master/sig-network/README.md) and the Security Response Committee [announced the upcoming retirement](https://www.kubernetes.dev/blog/2025/11/12/ingress-nginx-retirement/) of the [Ingress NGINX project](https://github.com/kubernetes/ingress-nginx/), with maintenance ending in **March 2026**. There's no immediate action required today for AKS clusters using the [Application Routing add-on with NGINX](/azure/aks/app-routing). Microsoft will provide official support for critical security patches for Application Routing add-on NGINX Ingress resources through **November 2026**.
>
> AKS is aligning with upstream Kubernetes by moving to **[Gateway API](https://gateway-api.sigs.k8s.io) as the long-term standard for ingress and L7 traffic management**. We recommend you start planning your migration path based on your current setup:
>
> - **Application Routing add-on users**: Production workloads remain fully supported through November 2026. AKS will continue evolving the Application Routing add-on with Gateway API alignment. You don't need to move to a different ingress product.
> - **OSS NGINX users** have several options:
>   - Migrate to the [Application Routing add-on with NGINX](/azure/aks/app-routing) to benefit from official support through November 2026 while planning your long-term Gateway API migration.
>   - Migrate to [Application Gateway for Containers](/azure/application-gateway/for-containers/overview), which supports both Ingress API and Gateway API.
> - **Service mesh users**: If you plan to adopt a service mesh, consider the [Istio-based service mesh add-on](/azure/aks/istio-about). Use Istio Ingress today, and plan to migrate to Istio Gateway API support when it becomes GA.