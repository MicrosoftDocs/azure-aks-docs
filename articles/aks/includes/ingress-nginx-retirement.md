---
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 01/29/2026
author: schaffererin
ms.author: schaffererin
---

> [!IMPORTANT]
> The [Kubernetes SIG Network](https://github.com/kubernetes/community/blob/master/sig-network/README.md) and the Security Response Committee [announced the upcoming retirement](https://www.kubernetes.dev/blog/2025/11/12/ingress-nginx-retirement/) of the [Ingress NGINX project](https://github.com/kubernetes/ingress-nginx/), with maintenance ending in **March 2026**. There's no immediate action required today for AKS clusters using the [Application Routing add-on with NGINX](/azure/aks/app-routing) to manage Ingress NGINX resources. Microsoft will provide official support for critical security patches for Application Routing add-on Ingress NGINX resources through **November 2026**.
>
> AKS is aligning with upstream Kubernetes by moving to **Gateway API as the long-term standard for ingress and L7 traffic management**. We recommend you start planning your migration using one of the following options:
>
> - **Immediate production migration (GA)**: Migrate production workloads to [Application Gateway for Containers](/azure/application-gateway/for-containers/overview).
> - **Transitional migration**: If you're currently running OSS NGINX, migrate to the [Application Routing add-on with NGINX](/azure/aks/app-routing), and continue operating with official support through November 2026 while you plan your long-term migration to a GA Gateway API solution.
> - **Service mesh migration**: If you plan to adopt a service mesh, migrate to the [Open Service Mesh (OSM) add-on](/azure/aks/open-service-mesh-about). Use Istio Ingress today, and plan to migrate to Istio Gateway API support when it becomes GA.