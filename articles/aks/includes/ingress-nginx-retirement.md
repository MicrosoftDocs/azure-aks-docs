---
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 01/29/2026
author: schaffererin
ms.author: schaffererin
---

> [!CAUTION]
>
> The [Kubernetes SIG Network](https://github.com/kubernetes/community/blob/master/sig-network/README.md) and the Security Response Committee [announced the upcoming retirement](https://www.kubernetes.dev/blog/2025/11/12/ingress-nginx-retirement/) of the [Ingress NGINX project](https://github.com/kubernetes/ingress-nginx/), with maintenance ending in **March 2026**. There's no immediate action required today for AKS clusters using the [application routing add-on with NGINX](/azure/aks/app-routing). Microsoft will provide official support for critical security patches for application routing add-on NGINX Ingress resources through **November 2026**.
>
> AKS is aligning with upstream Kubernetes by moving to **[Gateway API](https://gateway-api.sigs.k8s.io) as the long-term standard for ingress and L7 traffic management**. We recommend you start planning your migration path based on your current setup:
>
> - **Application routing add-on users**: Production workloads remain fully supported through November 2026. Migrate to the [application routing Gateway API implementation](/azure/aks/app-routing-gateway-api) for a Gateway API-based ingress traffic management experience.
> - **OSS NGINX users** have several options:
>   - Migrate to the [application routing add-on with NGINX](/azure/aks/app-routing) to benefit from official support through November 2026 while planning your long-term Gateway API migration.
>   - Migrate to the [application routing Gateway API implementation](/azure/aks/app-routing-gateway-api) for a Gateway API-based ingress traffic management experience.
>   - Migrate to [Application Gateway for Containers](/azure/application-gateway/for-containers/overview), which supports both Ingress API and Gateway API.
> - **Service mesh or advanced ingress requirements**: Consider [Gateway API ingress with the Istio service mesh add-on](/azure/aks/istio-gateway-api). You can use it for ingress without injecting sidecars into your workloads. If you need request header and body size limits, Lua scripts, or rate limiting, review the [Gateway API limitations and alternatives](/azure/aks/app-routing-gateway-api#limitations).
