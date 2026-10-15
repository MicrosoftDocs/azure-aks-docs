---
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 10/14/2026
author: schaffererin
ms.author: schaffererin
---

> [!CAUTION]
>
> The [Kubernetes SIG Network](https://github.com/kubernetes/community/blob/master/sig-network/README.md) and the Security Response Committee [announced the retirement](https://www.kubernetes.dev/blog/2025/11/12/ingress-nginx-retirement/) of the [Ingress NGINX project](https://github.com/kubernetes/ingress-nginx/), with maintenance that ended in March 2026. Microsoft will provide official support for critical security patches for application routing add-on NGINX Ingress resources through **November 2026**.
>
> AKS aligns with upstream Kubernetes and uses **[Gateway API](https://gateway-api.sigs.k8s.io) as the long-term standard for ingress and L7 traffic management**. Migrate before support ends in November 2026, based on your requirements:
>
> - **Application routing add-on users** and **OSS NGINX users**: Migrate to the [application routing Gateway API implementation](/azure/aks/app-routing-gateway-api) for a Gateway API-based ingress traffic management experience, or to [Application Gateway for Containers](/azure/application-gateway/for-containers/overview), which supports both Ingress API and Gateway API.
> - **Service mesh or advanced ingress requirements**: Consider [Gateway API ingress with the Istio service mesh add-on](/azure/aks/istio-gateway-api). You can use it for ingress without injecting sidecars into your workloads. If you need request header and body size limits, Lua scripts, or rate limiting, review the [Gateway API limitations and alternatives](/azure/aks/app-routing-gateway-api#limitations).
